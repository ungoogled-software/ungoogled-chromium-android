#!/usr/bin/env bash
#
# Build / refresh the F-Droid repository (index format v1, signed index-v1.jar)
# from a signed release APK, so the project can be installed via the F-Droid
# client (2.0.x) from this GitHub repository.
#
# The F-Droid 2.0 client does not read the classic index-v1.1.xml; it only
# accepts a signed JAR index (entry.jar v2 or index-v1.jar v1) and verifies the
# JAR signature. We emit v1 (index-v1.jar): the client tries v2 first, gets a
# 404, then falls back to v1. The repo signing key is the same keystore used to
# sign the release APK/AAB (see build/release.sh); the client uses trust-on-
# first-use, so users do not need to paste a certificate.
#
# Environment:
#   UGC_KEYSTORE          path to the release JKS keystore (required)
#   UGC_KEYSTORE_PASSFILE path to a file containing the keystore+key password (required)
#   UGC_APK               path to the signed release APK to publish (required)
#   UGC_PACKAGE           applicationId / package name (default: read from the APK via aapt2)
#   UGC_REPO_DIR          target repo dir, relative to the git root (default fdroid/repo)
#   UGC_REPO_NAME         repository display name (default "Ungoogled Chromium")
#   UGC_APP_NAME          app display name fallback; the APK's own label is preferred
#                         (default "Ungoogled Chromium")
#   UGC_LICENSE           SPDX license id recorded in the index (default "GPL-3.0 AND BSD-3-Clause")
#   UGC_REPO_ADDRESS      address recorded in the index (default the GitHub repo)
#   UGC_KEEP              number of versions to keep before pruning (default 3)
#
# Required on PATH: aapt2, keytool, jarsigner, jar, sha256sum, md5sum, od, unzip,
#   python3, and (for WebP launcher icons) one of: magick, convert, dwebp
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

: "${UGC_KEYSTORE:?UGC_KEYSTORE is not set}"
: "${UGC_KEYSTORE_PASSFILE:?UGC_KEYSTORE_PASSFILE is not set}"
: "${UGC_APK:?UGC_APK is not set}"
UGC_PACKAGE="${UGC_PACKAGE:-}"   # empty => derive from the APK in section 1
UGC_REPO_DIR="${UGC_REPO_DIR:-fdroid/repo}"
UGC_REPO_NAME="${UGC_REPO_NAME:-Ungoogled Chromium}"
UGC_APP_NAME="${UGC_APP_NAME:-Ungoogled Chromium}"
UGC_LICENSE="${UGC_LICENSE:-GPL-3.0 AND BSD-3-Clause}"
UGC_REPO_ADDRESS="${UGC_REPO_ADDRESS:-https://github.com/ungoogled-software/ungoogled-chromium-android}"
UGC_KEEP="${UGC_KEEP:-3}"
ALIAS="${UGC_KEYSTORE_ALIAS:-key0}"

[ -f "$UGC_KEYSTORE" ]     || { echo "FATAL: keystore not found: $UGC_KEYSTORE"; exit 1; }
[ -f "$UGC_KEYSTORE_PASSFILE" ] || { echo "FATAL: passfile not found: $UGC_KEYSTORE_PASSFILE"; exit 1; }
[ -f "$UGC_APK" ]          || { echo "FATAL: APK not found: $UGC_APK"; exit 1; }
for tool in aapt2 keytool jarsigner jar sha256sum md5sum od unzip python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FATAL: required tool not on PATH: $tool"; exit 1; }
done

REPO_DIR="$ROOT/$UGC_REPO_DIR"
ICON_DIR="$REPO_DIR/icons"
mkdir -p "$ICON_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# Keystore password is handed to keytool/jarsigner via `-storepass:file` /
# `-keypass:file`, so it never appears on a command line or in the process
# environment. Normalize it (trailing newline stripped) into a private temp
# file inside $WORK (0700 dir; file 0600); $WORK is removed on exit.
PASSFILE="$WORK/pass"
printf '%s' "$(<"$UGC_KEYSTORE_PASSFILE")" > "$PASSFILE"
chmod 600 "$PASSFILE"

# ---------------------------------------------------------------------------
# 1. Extract APK metadata via aapt2
# ---------------------------------------------------------------------------
BADGE="$WORK/badging.txt"
aapt2 dump badging "$UGC_APK" > "$BADGE"

VERSION_CODE="$(sed -nE "s/.*versionCode='([0-9]+)'.*/\1/p" "$BADGE" | head -1)"
VERSION_NAME="$(sed -nE "s/.*versionName='([^']*)'.*/\1/p"       "$BADGE" | head -1)"
# aapt2 emits `minSdkVersion:'N'`; legacy aapt used `sdkVersion:'N'` (fallback).
MIN_SDK="$(sed -nE    "s/.*minSdkVersion:'([0-9]+)'.*/\1/p"     "$BADGE" | head -1)"
[ -n "$MIN_SDK" ] || MIN_SDK="$(sed -nE "s/.*sdkVersion:'([0-9]+)'.*/\1/p" "$BADGE" | head -1)"
TARGET_SDK="$(sed -nE  "s/.*targetSdkVersion:'([0-9]+)'.*/\1/p" "$BADGE" | head -1)"
NATIVE_CODE="$(sed -nE "s/.*native-code: '([^']*)'.*/\1/p"       "$BADGE" | head -1)"
APP_LABEL="$(sed -nE "s/^application-label: '?([^']*)'?$/\1/p"   "$BADGE" | head -1)"
PKG_NAME="$(sed -nE  "s/^package: name='([^']*)'.*/\1/p"         "$BADGE" | head -1)"

: "${VERSION_CODE:?could not read versionCode from APK via aapt2}"
: "${VERSION_NAME:?could not read versionName from APK via aapt2}"
[ -n "$TARGET_SDK" ] || TARGET_SDK="$MIN_SDK"
# Prefer the APK's own display name (aapt2 application-label); fall back to config.
APP_NAME="${APP_LABEL:-$UGC_APP_NAME}"
# Package name defaults to the APK's own (aapt2 'package: name='); an explicit
# UGC_PACKAGE (e.g. from the workflow) still overrides it.
UGC_PACKAGE="${UGC_PACKAGE:-$PKG_NAME}"
: "${UGC_PACKAGE:?could not determine package name (aapt2 'package: name=' missing)}"

# `|| true`: grep exits 1 on no match, which would otherwise trip `set -o pipefail`.
PERMS="$(grep -oE "uses-permission: name='[^']*'" "$BADGE" | sed -E "s/uses-permission: name='//; s/'$//" | sort -u || true)"
FEATURES="$(grep -oE "uses-feature: name='[^']*'" "$BADGE"  | sed -E "s/uses-feature: name='//; s/'$//" | sort -u || true)"

APK_NAME="${UGC_PACKAGE}_${VERSION_CODE}.apk"
ICON_NAME="${UGC_PACKAGE}_${VERSION_CODE}.png"
REPO_ICON="repo.png"
echo "package=$UGC_PACKAGE"
echo "  versionCode=$VERSION_CODE versionName=$VERSION_NAME"
echo "  minSdk=${MIN_SDK:-?} targetSdk=${TARGET_SDK:-?} native=${NATIVE_CODE:-?}"
echo "  apkName=$APK_NAME"
echo "  name=$APP_NAME license=$UGC_LICENSE"

# ---------------------------------------------------------------------------
# 2. Hash + size of the APK
# ---------------------------------------------------------------------------
HASH="$(sha256sum "$UGC_APK" | awk '{print $1}')"
SIZE="$(stat -c %s "$UGC_APK")"

# ---------------------------------------------------------------------------
# 3. signer + sig, derived from the keystore's signing certificate.
#    release.sh already verifies the APK is signed with this keystore, so the
#    APK signer == the keystore cert.
#      signer = sha256(DER cert) as lowercase hex
#      sig    = md5( ascii-hex(DER cert) ) as lowercase hex   (legacy field)
# ---------------------------------------------------------------------------
keytool -exportcert -keystore "$UGC_KEYSTORE" -alias "$ALIAS" \
  -storepass:file "$PASSFILE" -file "$WORK/cert.der" >/dev/null 2>&1
[ -s "$WORK/cert.der" ] || { echo "FATAL: could not export cert for alias $ALIAS"; exit 1; }
CERT_SIZE="$(wc -c < "$WORK/cert.der")"
[ "$CERT_SIZE" -ge 256 ] || { echo "FATAL: signing cert too small ($CERT_SIZE < 256 bytes)"; exit 1; }
SIGNER="$(sha256sum "$WORK/cert.der" | awk '{print $1}')"
CERT_HEX="$(od -An -v -tx1 "$WORK/cert.der" | tr -d ' \n')"
SIG="$(printf '%s' "$CERT_HEX" | md5sum | awk '{print $1}')"
echo "  signer=$SIGNER"

# ---------------------------------------------------------------------------
# 4. Copy the APK into the repo (LFS-tracked via .gitattributes)
# ---------------------------------------------------------------------------
cp -f "$UGC_APK" "$REPO_DIR/$APK_NAME"

# ---------------------------------------------------------------------------
# 5. Icon: taken from the release APK (never hand-crafted).
#    aapt2 reports the launcher icon as `application: ... icon='res/PATH'`:
#      - PATH is .png/.webp  -> a raster launcher icon; extract it directly.
#      - PATH is .xml        -> an adaptive icon; parse the AXML for the
#        foreground drawable id, resolve it to the highest-density file via
#        `aapt2 dump resources`, and extract that file.
#    The result is normalised to a real PNG (PNG is copied; WebP is converted).
# ---------------------------------------------------------------------------
ICON_REF="$(sed -nE "s/^application:.* icon='([^']*)'.*/\1/p" "$BADGE" | head -1)"
[ -n "$ICON_REF" ] || { echo "FATAL: aapt2 badging has no launcher icon in $UGC_APK"; exit 1; }

# Convert an image ($1) to PNG ($2) using whichever tool is available.
to_png() {
  if   command -v magick  >/dev/null 2>&1; then magick  "$1" "$2"
  elif command -v convert >/dev/null 2>&1; then convert "$1" "$2"
  elif command -v dwebp   >/dev/null 2>&1; then dwebp -o "$2" "$1"
  else return 1; fi
}
# Write an apk-internal image file ($1) as a real PNG ($2). A PNG is copied;
# anything else (Chromium's WebP) must be converted. Fails if no conversion is
# possible, so we never ship a non-PNG file named .png.
icon_to_png() {
  local f="$WORK/$1"
  [ -f "$f" ] || return 1
  local m; m="$(head -c4 "$f" | od -An -tx1 | tr -d ' \n')"
  if [ "$m" = "89504e47" ]; then cp -f "$f" "$2"
  else to_png "$f" "$2"; fi
}
# Resolve an adaptive-icon foreground drawable id ($1) to the highest-density
# file path inside the APK (last `(file)` entry in the resource block).
fg_file_for() {
  aapt2 dump resources "$UGC_APK" 2>/dev/null | awk -v id="$1" '
    $1=="resource" && $2==id { inb=1; file=""; next }
    inb && $1=="resource"    { inb=0; exit }
    inb && $2=="(file)"      { file=$3 }
    END { if (file != "") print file }' || true
}
# Minimal AXML adaptive-icon parser: prints the foreground drawable resource id.
AXML_FG="$WORK/axml_fg.py"
cat > "$AXML_FG" <<'PYEOF'
import struct, sys
d = open(sys.argv[1], "rb").read()
u16 = lambda o: struct.unpack_from("<H", d, o)[0]
u32 = lambda o: struct.unpack_from("<I", d, o)[0]
if u16(0) != 3: sys.exit(1)
off = 8
sp = u32(off + 4); sc = u32(off + 8)
fl = u32(off + 16); ss = u32(off + 20)
utf8 = bool(fl & (1 << 8)); sb = off + ss; so = off + 28
def gs(i):
    if i is None or i < 0 or i >= sc: return None
    p = so + 4 * i; pos = sb + u32(p)
    if utf8:
        n = d[pos]
        if n & 0x80: n = ((n & 0x7f) << 8) | d[pos + 1]; pos += 2
        else: pos += 1
        b = d[pos]
        if b & 0x80: b = ((b & 0x7f) << 8) | d[pos + 1]; pos += 2
        else: pos += 1
        return d[pos:pos + b].decode("utf-8", "replace")
    n = u16(pos)
    if n & 0x8000: n = ((n & 0x7fff) << 16) | u16(pos + 2); pos += 4
    else: pos += 2
    return d[pos:pos + 2 * n].decode("utf-16-le", "replace")
off = 8 + sp; fg = None
while off + 8 <= len(d):
    ct = u16(off); cs = u32(off + 4)
    if cs == 0: break
    if ct == 0x0102:
        el = gs(u32(off + 20)); ac = u16(off + 28); ap = off + 36
        if el == "foreground":
            for _ in range(ac):
                if gs(u32(ap + 4)) == "drawable": fg = hex(u32(ap + 16))
                ap += 20
    off += cs
if fg: print(fg)
PYEOF

# Decide which apk-internal file holds the launcher icon.
icon_src_path() {
  case "$ICON_REF" in
    *.xml)
      ( cd "$WORK" && unzip -o -q "$UGC_APK" "$ICON_REF" ) || return 1
      local fg; fg="$(python3 "$AXML_FG" "$WORK/$ICON_REF" 2>/dev/null || true)"
      [ -n "$fg" ] || return 1
      fg_file_for "$fg"
      ;;
    *) printf '%s\n' "$ICON_REF" ;;
  esac
}

ICON_SRC="$(icon_src_path || true)"
[ -n "$ICON_SRC" ] || { echo "FATAL: could not resolve a launcher icon file in $UGC_APK (icon=$ICON_REF)"; exit 1; }
( cd "$WORK" && unzip -o -q "$UGC_APK" "$ICON_SRC" ) || { echo "FATAL: cannot extract $ICON_SRC from $UGC_APK"; exit 1; }
icon_to_png "$ICON_SRC" "$ICON_DIR/$ICON_NAME" \
  || { echo "FATAL: could not produce a PNG icon from $ICON_SRC (need magick/convert/dwebp)"; exit 1; }
[ -s "$ICON_DIR/$ICON_NAME" ] || { echo "FATAL: produced icon is empty"; exit 1; }
cp -f "$ICON_DIR/$ICON_NAME" "$ICON_DIR/$REPO_ICON"
echo "  icon=$ICON_NAME (from $ICON_REF -> $ICON_SRC)"

# ---------------------------------------------------------------------------
# 6. Bump the repo version counter (monotonic int for the index)
# ---------------------------------------------------------------------------
VER_FILE="$ROOT/fdroid/.repo_version"
mkdir -p "$(dirname "$VER_FILE")"
if [ -f "$VER_FILE" ]; then REPO_VERSION="$(($(cat "$VER_FILE") + 1))"; else REPO_VERSION=1; fi
printf '%s' "$REPO_VERSION" > "$VER_FILE"
TIMESTAMP="$(date +%s)"

# ---------------------------------------------------------------------------
# 7. Write index-v1.json
# ---------------------------------------------------------------------------
jesc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# newline-separated list -> JSON string array
json_str_array() {
  local out="" line
  # `|| [ -n "$line" ]` keeps a final line that has no trailing newline
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    line=${line//\\/\\\\}; line=${line//\"/\\\"}
    [ -n "$out" ] && out+=", "
    out+="\"$line\""
  done
  printf '[%s]' "$out"
}

PERMS_JSON="$(printf '%s\n' "$PERMS" | json_str_array)"
FEATURES_JSON="$(printf '%s\n' "$FEATURES" | json_str_array)"
NATIVE_JSON="$(printf '%s' "$NATIVE_CODE" | tr ' ' '\n' | json_str_array)"
MIN_SDK_JSON="$( [ -n "$MIN_SDK" ] && printf '%s' "$MIN_SDK" || printf 'null' )"
TARGET_SDK_JSON="$( [ -n "$TARGET_SDK" ] && printf '%s' "$TARGET_SDK" || printf 'null' )"

cat > "$REPO_DIR/index-v1.json" <<EOF
{
  "repo": {
    "timestamp": $TIMESTAMP,
    "version": $REPO_VERSION,
    "name": "$(jesc "$UGC_REPO_NAME")",
    "icon": "$REPO_ICON",
    "address": "$(jesc "$UGC_REPO_ADDRESS")",
    "description": "$(jesc "Self-hosted, experimental F-Droid repository for the Android build of ungoogled-chromium (Google Chromium, sans dependency on Google web services). Generated automatically from this project's release builds.")"
  },
  "apps": [
    {
      "packageName": "$UGC_PACKAGE",
      "name": "$(jesc "$APP_NAME")",
      "license": "$(jesc "$UGC_LICENSE")",
      "icon": "$ICON_NAME"
    }
  ],
  "packages": {
    "$UGC_PACKAGE": [
      {
        "apkName": "$APK_NAME",
        "hash": "$HASH",
        "hashType": "sha256",
        "minSdkVersion": $MIN_SDK_JSON,
        "targetSdkVersion": $TARGET_SDK_JSON,
        "packageName": "$UGC_PACKAGE",
        "sig": "$SIG",
        "signer": "$SIGNER",
        "size": $SIZE,
        "uses-permission": $PERMS_JSON,
        "nativecode": $NATIVE_JSON,
        "versionCode": $VERSION_CODE,
        "versionName": "$(jesc "$VERSION_NAME")",
        "features": $FEATURES_JSON
      }
    ]
  }
}
EOF
python3 -c "import json; json.load(open('$REPO_DIR/index-v1.json'))" || { echo "FATAL: index-v1.json is not valid JSON"; exit 1; }
echo "  wrote index-v1.json (repo version=$REPO_VERSION timestamp=$TIMESTAMP)"

# ---------------------------------------------------------------------------
# 8. Build + sign index-v1.jar (must contain index-v1.json with a digest attr)
# ---------------------------------------------------------------------------
JARSTAGE="$WORK/jarstage"
mkdir -p "$JARSTAGE"
cp "$REPO_DIR/index-v1.json" "$JARSTAGE/index-v1.json"
( cd "$JARSTAGE" && jar cMf "$WORK/index-v1-unsigned.jar" index-v1.json )
jarsigner -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore "$UGC_KEYSTORE" -storepass:file "$PASSFILE" -keypass:file "$PASSFILE" \
  -signedjar "$REPO_DIR/index-v1.jar" "$WORK/index-v1-unsigned.jar" "$ALIAS" >/dev/null
jarsigner -verify "$REPO_DIR/index-v1.jar" >/dev/null || { echo "FATAL: index-v1.jar failed to verify"; exit 1; }

# F-Droid v1 verifier only allows SHA-1/SHA-256 digests on the index entry.
BAD_DIGESTS="$(unzip -p "$REPO_DIR/index-v1.jar" META-INF/MANIFEST.MF \
  | grep -oiE '(SHA[0-9]+-[0-9]*-Digest|MD5-Digest)' | sort -u \
  | grep -vE '^(SHA-256-Digest|SHA1-Digest|SHA-1-Digest)$' || true)"
if [ -n "$BAD_DIGESTS" ]; then
  echo "FATAL: manifest has digests the F-Droid client rejects: $BAD_DIGESTS"
  exit 1
fi
echo "  wrote signed index-v1.jar (alias $ALIAS)"

# ---------------------------------------------------------------------------
# 9. Prune old versions (keep the newest UGC_KEEP by versionCode)
# ---------------------------------------------------------------------------
mapfile -t APKS < <(ls "$REPO_DIR/${UGC_PACKAGE}_"*.apk 2>/dev/null || true)
if [ "${#APKS[@]}" -gt "$UGC_KEEP" ]; then
  for apk in "${APKS[@]}"; do
    vc="$(basename "$apk" .apk | awk -F'_' '{print $NF}')"
    printf '%s\t%s\n' "$vc" "$apk"
  done | sort -rn | awk -F'\t' -v keep="$UGC_KEEP" 'NR>keep {print $2}' \
    | while IFS= read -r old; do
        oldvc="$(basename "$old" .apk | awk -F'_' '{print $NF}')"
        echo "  pruning $(basename "$old")"
        rm -f "$old" "$ICON_DIR/${UGC_PACKAGE}_${oldvc}.png"
      done
fi

echo "=== F-Droid repo updated ==="
echo "  base: ${UGC_REPO_ADDRESS} (serve $UGC_REPO_DIR/ at <host>/fdroid/repo)"
ls -la "$REPO_DIR"

#!/usr/bin/env bash
# Sign and assemble release assets from a finished per-arch build.
#   build/release.sh <arch> [out-dir]      e.g. build/release.sh arm64 out/Default
#   env: UGC_KEYSTORE, UGC_KEYSTORE_ALIAS (default key0), UGC_KEYSTORE_PASSFILE
set -eu
cd "$(dirname "$0")/.."
ARCH="${1:?usage: build/release.sh <arch> [out-dir]}"
OUT="src/${2:-out/Default}"   # build.sh:217 builds into out/Default; pass a second arg to override

. ./.build_config
VERSION=$(grep -o 'android_override_version_name="[^"]*"' "$OUT/args.gn" 2>/dev/null | cut -d'"' -f2 || true)
[ -n "$VERSION" ] || VERSION="$chromium_version"
REL="releases/${VERSION}-${ungoogled_chromium_android_revision}"
mkdir -p "$REL"
REPO=$(pwd)

AAB_IN=$(find "$OUT/apks" -maxdepth 1 -name "ChromePublic.aab" | head -1)
APK_IN=$(find "$OUT/apks" -maxdepth 1 -name "ChromePublic.apk" | head -1)

if [ -z "$APK_IN" ] && [ -n "$AAB_IN" ]; then
    echo "no ChromePublic.apk - deriving a universal APK from the bundle"
    BUNDLETOOL="src/build/android/gyp/bundletool.py"
    AAPT2="src/third_party/android_build_tools/aapt2/cipd/aapt2"
    [ -f "$BUNDLETOOL" ] && [ -x "$AAPT2" ] || { echo "FATAL: bundletool or aapt2 missing"; exit 1; }
    _apks="$OUT/apks/ChromePublic.apks"
    rm -f "$_apks"
    python3 "$BUNDLETOOL" build-apks --aapt2 "$AAPT2" --bundle "$AAB_IN" \
        --output "$_apks" --mode=universal || exit $?
    unzip -o -q -j "$_apks" universal.apk -d "$OUT/apks" || exit $?
    mv "$OUT/apks/universal.apk" "$OUT/apks/ChromePublic.apk"
    rm -f "$_apks"
    APK_IN="$OUT/apks/ChromePublic.apk"
fi
[ -n "$APK_IN" ] || { echo "FATAL: no ChromePublic.apk and no bundle to derive one from"; exit 1; }

KS="${UGC_KEYSTORE:-}"
KS_ALIAS="${UGC_KEYSTORE_ALIAS:-key0}"
KS_PASSFILE="${UGC_KEYSTORE_PASSFILE:-}"
APKSIGNER="${APKSIGNER:-$(ls src/third_party/android_sdk/public/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)}"
[ -x "${APKSIGNER:-}" ] || APKSIGNER=$(ls "$HOME"/android-sdk/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)
_TREE_JDK="src/third_party/jdk/current/bin"
if [ -x "$_TREE_JDK/java" ]; then
    JAVA_HOME="$(cd "$_TREE_JDK/.." && pwd)"
    export JAVA_HOME
    export PATH="$JAVA_HOME/bin:$PATH"
fi
KEYTOOL="${KEYTOOL:-$([ -x "$_TREE_JDK/keytool" ] && echo "$_TREE_JDK/keytool" || command -v keytool)}"
JARSIGNER="${JARSIGNER:-$([ -x "$_TREE_JDK/jarsigner" ] && echo "$_TREE_JDK/jarsigner" || command -v jarsigner)}"
echo "  apksigner: $APKSIGNER"
echo "  jarsigner: $JARSIGNER" 

if [ -n "$KS" ] && [ -f "$KS" ] && [ -n "$KS_PASSFILE" ] && [ -f "$KS_PASSFILE" ]; then
    PW=$(cat "$KS_PASSFILE")

    "$APKSIGNER" sign --ks "$KS" --ks-key-alias "$KS_ALIAS" \
        --ks-pass "pass:$PW" --key-pass "pass:$PW" \
        --in "$APK_IN" --out "$REL/ChromePublic_${ARCH}.apk"

    FP=$("$APKSIGNER" verify --print-certs "$REL/ChromePublic_${ARCH}.apk" 2>/dev/null \
         | grep -m1 "certificate SHA-256 digest" | awk '{print $NF}' \
         | sed 's/../&:/g; s/:$//' | tr 'a-f' 'A-F')
    KFP=$("$KEYTOOL" -list -keystore "$KS" -alias "$KS_ALIAS" -storepass "$PW" -v 2>/dev/null \
          | grep -m1 "SHA256:" | awk '{print $2}')
    [ "$FP" = "$KFP" ] || { echo "FATAL: signed APK cert != keystore (apk=$FP key=$KFP)"; exit 1; }
    echo "signed APK as $KS_ALIAS ($KFP)"

    if [ -n "$AAB_IN" ]; then
        "$JARSIGNER" -sigalg SHA256withRSA -digestalg SHA-256 \
            -keystore "$KS" -storepass "$PW" -keypass "$PW" \
            -signedjar "$REL/ChromePublic_${ARCH}.aab" "$AAB_IN" "$KS_ALIAS" >/dev/null
        "$JARSIGNER" -verify "$REL/ChromePublic_${ARCH}.aab" >/dev/null \
            || { echo "FATAL: .aab signature did not verify"; exit 1; }
        echo "signed bundle"
    else
        echo "WARN: no ChromePublic.aab in $OUT/apks (bundle target not built?)"
    fi
else
    echo "WARN: no keystore supplied, copying build output as-is."
    echo "      UGC_KEYSTORE:          ${KS:-<unset>}$([ -n "$KS" ] && { [ -f "$KS" ] && echo '' || echo '  (file not found)'; })"
    echo "      UGC_KEYSTORE_PASSFILE: ${KS_PASSFILE:-<unset>}$([ -n "$KS_PASSFILE" ] && { [ -f "$KS_PASSFILE" ] && echo '' || echo '  (file not found)'; })"
    cp "$APK_IN" "$REL/ChromePublic_${ARCH}.apk"
    [ -n "$AAB_IN" ] && cp "$AAB_IN" "$REL/ChromePublic_${ARCH}.aab"
fi

WV_IN=$(find "$OUT/apks" -maxdepth 1 -name "SystemWebView64.apk" | head -1)
[ -n "$WV_IN" ] || WV_IN=$(find "$OUT/apks" -maxdepth 1 -name "SystemWebView.apk" | head -1)
if [ -n "$WV_IN" ]; then
    if [ -n "$KS" ] && [ -f "$KS" ] && [ -n "$KS_PASSFILE" ] && [ -f "$KS_PASSFILE" ]; then
        "$APKSIGNER" sign --ks "$KS" --ks-key-alias "$KS_ALIAS" \
            --ks-pass "pass:$PW" --key-pass "pass:$PW" \
            --in "$WV_IN" --out "$REL/SystemWebView_${ARCH}.apk"
        WFP=$("$APKSIGNER" verify --print-certs "$REL/SystemWebView_${ARCH}.apk" 2>/dev/null \
              | grep -m1 "certificate SHA-256 digest" | awk '{print $NF}' \
              | sed 's/../&:/g; s/:$//' | tr 'a-f' 'A-F')
        [ "$WFP" = "$KFP" ] || { echo "FATAL: signed WebView cert != keystore (apk=$WFP key=$KFP)"; exit 1; }
        echo "signed SystemWebView as $KS_ALIAS ($KFP)"
    else
        cp "$WV_IN" "$REL/SystemWebView_${ARCH}.apk"
    fi
fi
MAP=$(find "$OUT" -maxdepth 2 \( -name "ChromePublic.apk.mapping" -o -name "ChromePublic.aab.mapping" \) | head -1)
if [ -n "$MAP" ]; then cp "$MAP" "$REL/ChromePublic_${ARCH}.apk.mapping"; else echo "WARN: no R8 mapping found"; fi

rm -f "$REL/ChromePublic_${ARCH}_symbols.zip"
if [ -d "$OUT/lib.unstripped" ]; then
    ( cd "$OUT/lib.unstripped" && \
      unzip -Z1 "$REPO/$REL/ChromePublic_${ARCH}.apk" "lib/*" 2>/dev/null | xargs -rn1 basename | sort -u | \
      while read -r so; do [ -f "$so" ] && echo "$so"; done | \
      zip -q "$REPO/$REL/ChromePublic_${ARCH}_symbols.zip" -@ ) || true
fi
[ -f "$REL/ChromePublic_${ARCH}_symbols.zip" ] || echo "WARN: no unstripped .so found, symbols archive skipped"

( cd "$REL"
  [ -f sha256sums.txt ] && grep -v -e "  ChromePublic_${ARCH}[._]" -e "  SystemWebView_${ARCH}[._]" sha256sums.txt > sha256sums.new || :
  for _f in "ChromePublic_${ARCH}.apk" "ChromePublic_${ARCH}.aab" \
            "ChromePublic_${ARCH}.apk.mapping" "ChromePublic_${ARCH}_symbols.zip" \
            "SystemWebView_${ARCH}.apk"; do
      [ -f "$_f" ] && sha256sum "$_f"
  done >> sha256sums.new
  sort -k2 sha256sums.new -o sha256sums.txt
  rm -f sha256sums.new )

echo "=== assembled $REL ($ARCH) ==="
ls -lh "$REL" | sed 's/^/  /'

DN=$("$APKSIGNER" verify --print-certs "$REL/ChromePublic_${ARCH}.apk" 2>/dev/null \
     | grep -m1 "certificate DN" | cut -d: -f2- | sed 's/^ *//')
SHA=$("$APKSIGNER" verify --print-certs "$REL/ChromePublic_${ARCH}.apk" 2>/dev/null \
      | grep -m1 "certificate SHA-256 digest" | awk '{print $NF}')
case "$DN" in
    *"Android Debug"*|"") echo "=== SIGNING: DEBUG-SIGNED — DO NOT PUBLISH ===" ;;
    *)                    echo "=== SIGNING: release key ===" ;;
esac
echo "  signer DN:  ${DN:-<none — apk is unsigned>}"
echo "  cert SHA256: ${SHA:-n/a}"

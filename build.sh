#!/usr/bin/env bash
set -eu -o pipefail

source .build_config

# Show env
pwd
whoami
echo $PATH
echo $HOME

# Argument parser from https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash/29754866#29754866
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

OPTIONS=dlipra:t:
LONGOPTS=debug,local-sdk,install-deps,prepare-only,resume,arch:,target:

! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    exit 2
fi
eval set -- "$PARSED"

ARCH=- TARGET=- DEBUG=n LOCAL_SDK=n INSTALL_DEPS=n PREPARE_ONLY=n RESUME=n

while true; do
    case "$1" in
        -d|--debug)
            DEBUG=y
            shift
            ;;
        -l|--local-sdk)
            LOCAL_SDK=y
            shift
            ;;
        -i|--install-deps)
            INSTALL_DEPS=y
            shift
            ;;
        -p|--prepare-only)
            PREPARE_ONLY=y
            shift
            ;;
        -r|--resume)
            RESUME=y
            shift
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

if [[ "$ARCH" != "arm64" ]] && [[ "$ARCH" != "arm" ]] && [[ "$ARCH" != "x86" ]]; then
    echo "Wrong architecture"
    exit 4
fi

if [[ "$TARGET" != "chrome_modern_target" ]] && [[ "$TARGET" != "trichrome_chrome_apk_target" ]] && [[ "$TARGET" != "webview_target" ]] && [[ "$TARGET" != "trichrome_webview_target" ]] && [[ "$TARGET" != "all" ]]; then
    echo "Wrong target"
    exit 5
fi

# 64-bit TriChrome
if [[ "$ARCH" == "arm64" ]]; then
  if [[ "$TARGET" == "trichrome_chrome_apk_target" ]]; then
    TARGET_EXPANDED=${trichrome_chrome_64_apk_target}
  elif [[ "$TARGET" == "trichrome_webview_target" ]]; then
    TARGET_EXPANDED=${trichrome_webview_64_target}
  else
    TARGET_EXPANDED=${!TARGET}
  fi
else
  TARGET_EXPANDED=${!TARGET}
fi

echo "arch: $ARCH, target: $TARGET, target expanded: ${TARGET_EXPANDED}, debug: $DEBUG, local sdk: $LOCAL_SDK"

path_modified=false

function prepare_repos {
  git config --global http.lowSpeedLimit 1000
  git config --global http.lowSpeedTime 900

  declare -a arr=("depot_tools" "src" "ungoogled-chromium" ".cipd")
  for dname in "${arr[@]}"
  do
    if [[ -d "$dname" ]]
    then
      echo "Removing $dname"
      rm -rf "$dname"
    fi
  done

  path_modified=false

  ## Clone ungoogled-chromium repo
  git clone https://github.com/ungoogled-software/ungoogled-chromium.git -b ${ungoogled_chromium_version}-${ungoogled_chromium_revision} \
   || return $?

  CHROMIUM_SOURCE="${CHROMIUM_SOURCE:-https://chromium.googlesource.com/chromium/src.git}"
  mkdir -p src
  pushd src
  git init -q
  git remote add origin "${CHROMIUM_SOURCE}" 2>/dev/null || git remote set-url origin "${CHROMIUM_SOURCE}"
  case "${CHROMIUM_SOURCE}" in
    *github.com*) _alt="https://chromium.googlesource.com/chromium/src.git" ;;
    *)            _alt="https://github.com/chromium/chromium.git" ;;
  esac
  git fetch --depth 1 --no-tags "${CHROMIUM_SOURCE}" \
      "+refs/tags/${chromium_version}:refs/tags/${chromium_version}" \
    || { echo "primary source failed, falling back to ${_alt}"
         git remote set-url origin "${_alt}"
         git fetch --depth 1 --no-tags "${_alt}" \
             "+refs/tags/${chromium_version}:refs/tags/${chromium_version}"; } \
    || { popd; return 1; }
  git checkout -q "${chromium_version}" || { popd; return 1; }
  popd

  ## Fetch depot-tools
  depot_tools_commit=$(grep 'depot_tools.git' src/DEPS | cut -d\' -f8)
  mkdir -p depot_tools
  pushd depot_tools
  git init
  git remote add origin https://chromium.googlesource.com/chromium/tools/depot_tools.git
  git fetch --depth 1 --no-tags origin "${depot_tools_commit}" || return $?
  git reset --hard FETCH_HEAD
  popd
  OLD_PATH=$PATH
  export PATH="$(pwd -P)/depot_tools:$PATH"
  export PYTHONPATH="$(pwd -P)/depot_tools${PYTHONPATH:+:$PYTHONPATH}"
  path_modified=true
  pushd src/third_party
  ln -s ../../depot_tools
  popd

  git config --global http.lowSpeedTime 120
  DEPOT_TOOLS_UPDATE=0 gclient sync -D --no-history --nohooks --shallow
  _sync_rc=$?
  git config --global http.lowSpeedTime 900
  [ $_sync_rc -eq 0 ] || return $_sync_rc

  ( src/third_party/node/update_npm_deps ) || return $?
  ROLLUP_VER=$(grep '"version"' src/third_party/devtools-frontend/src/node_modules/rollup/package.json | head -1 | cut -d'"' -f4)
  _rollup_dest="src/third_party/devtools-frontend/src/node_modules/@rollup/rollup-linux-x64-gnu"
  if [ ! -f "${_rollup_dest}/rollup.linux-x64-gnu.node" ]; then
    curl -sL "https://registry.npmjs.org/@rollup/rollup-linux-x64-gnu/-/rollup-linux-x64-gnu-${ROLLUP_VER}.tgz" -o /tmp/rollup-native.tgz || return $?
    rm -rf "${_rollup_dest}"; mkdir -p "${_rollup_dest}"
    tar xzf /tmp/rollup-native.tgz -C "${_rollup_dest}" --strip-components=1 || return $?
  fi
  [ -f "${_rollup_dest}/rollup.linux-x64-gnu.node" ] || { echo "FATAL: rollup native module missing"; return 1; }

  python3 src/build/util/lastchange.py -o src/build/util/LASTCHANGE
  python3 src/tools/download_optimization_profile.py --newest_state=src/chrome/android/profiles/newest.txt --local_state=src/chrome/android/profiles/local.txt --output_name=src/chrome/android/profiles/afdo.prof --gs_url_base=chromeos-prebuilt/afdo-job/llvm || return $?
  python3 src/tools/download_optimization_profile.py --newest_state=src/chrome/android/profiles/arm.newest.txt --local_state=src/chrome/android/profiles/arm.local.txt --output_name=src/chrome/android/profiles/arm.afdo.prof --gs_url_base=chromeos-prebuilt/afdo-job/llvm || return $?
  python3 src/build/util/lastchange.py -m GPU_LISTS_VERSION --revision-id-only --header src/gpu/config/gpu_lists_version.h
  python3 src/build/util/lastchange.py -m SKIA_COMMIT_HASH -s src/third_party/skia --header src/skia/ext/skia_commit_hash.h
  python3 src/build/util/lastchange.py -m DAWN_COMMIT_HASH -s src/third_party/dawn --revision src/gpu/webgpu/DAWN_VERSION --header src/gpu/webgpu/dawn_commit_hash.h
  python3 src/tools/clang/scripts/update.py
  python3 src/build/linux/sysroot_scripts/install-sysroot.py --arch=amd64
  python3 src/build/linux/sysroot_scripts/install-sysroot.py --arch=i386
  python3 src/v8/tools/builtins-pgo/download_profiles.py download --depot-tools "$(pwd -P)/depot_tools" --check-v8-revision --quiet || return $?
  cp misc/UnindexedRules src/third_party/subresource-filter-ruleset/data
}

function reverse_change {
  if [ "$path_modified" = true ] ; then
    export PATH=$OLD_PATH
    path_modified=false
  fi
}

output_folder="out/Default"
uc_keystore="$PWD/../uc_keystore/uc-release-key.keystore"
stamp_file="src/${output_folder}/.build-stamp"

build_fingerprint() {
  printf '%s\n' "${chromium_version}-${ungoogled_chromium_android_revision}"
  ( cat patches/series; find patches -name '*.patch' -type f | sort | xargs cat ) | sha256sum | cut -d' ' -f1
  cat build.sh .build_config .gclient android_flags.gn android_flags.release.gn \
      android_flags.debug.gn 2>/dev/null | sha256sum | cut -d' ' -f1
}

if [ "$RESUME" = y ]; then
    if [ ! -f "$stamp_file" ] || [ ! -f "src/out/Default/args.gn" ] || [ ! -d "src/third_party" ]; then
        echo "FATAL: --resume but the build tree is incomplete."
        echo "  stamp:      $([ -f "$stamp_file" ] && echo present || echo MISSING)"
        echo "  args.gn:    $([ -f src/out/Default/args.gn ] && echo present || echo MISSING)"
        echo "  src tree:   $([ -d src/third_party ] && echo present || echo MISSING)"
        echo "  If these vanished between runs, actions/checkout wiped them: its default"
        echo "  clean:true runs 'git clean -ffdx', and -x deletes gitignored paths like /src/."
        echo "  The workflow sets clean: false to prevent this. Start a clean build (resume: no)."
        exit 7
    fi
    want=$(build_fingerprint | sha256sum | cut -d' ' -f1)
    have=$(grep -m1 '^fingerprint ' "$stamp_file" | awk '{print $2}')
    if [ "$want" != "$have" ]; then
        echo "FATAL: inputs changed since this build was stamped - resuming would mix old and new objects."
        echo "  stamped:  $have"
        echo "  current:  $want"
        echo "  Start a clean build instead (resume: no)."
        exit 8
    fi
    echo "=== resuming verified build ==="
    cat "$stamp_file"
    printf 'session    %s  run %s  resumed at %s objects\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${GITHUB_RUN_NUMBER:-local}" \
        "$(find src/out/Default -name '*.o' 2>/dev/null | wc -l)" >> "$stamp_file"
else
    # Run preparation
    for i in $(seq 1 10); do prepare_repos && s=0 && break || s=$? && reverse_change && sleep 120; done; (exit $s)
fi

if [ "$INSTALL_DEPS" = y ]; then
    export DEBIAN_FRONTEND=noninteractive
    if ! command -v apt-get >/dev/null 2>&1; then
        echo "FATAL: --install-deps needs apt. Chromium's own build/install-build-deps.py"
        echo "  installs via apt-get and supports Debian/Ubuntu only, so there is nothing"
        echo "  to call on this system."
        echo "  Install the packages listed in README.md by hand (dnf/pacman lists are there),"
        echo "  then run again without --install-deps. Everything after this step is distro-agnostic."
        exit 9
    fi
    if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        echo "FATAL: --install-deps needs root or passwordless sudo, or it will hang on a password prompt."
        echo "  run it by hand:  ( cd src && ./build/install-build-deps.sh --no-prompt --android --unsupported )"
        echo "  or allow apt:    echo 'USER ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/dpkg' | sudo tee /etc/sudoers.d/chromium-deps"
        exit 6
    fi
    apt-get -qq install -y lsb-release file 2>/dev/null \
        || sudo -n apt-get -qq install -y lsb-release file
    ( cd src && ./build/install-build-deps.sh --no-prompt --android --unsupported ) || exit $?
fi

dependencies=(patch ccache zip python3)
missing=()
for dependency in "${dependencies[@]}"; do
    command -v "$dependency" >/dev/null 2>&1 || missing+=("$dependency")
done
if [ ${#missing[@]} -ne 0 ]; then
    echo "FATAL: missing required tools: ${missing[*]}"
    echo "  Install them with your package manager (per-distro lists are in README.md)."
    exit 10
fi

if [ "$RESUME" != y ]; then
  ## Run ungoogled-chromium scripts
  patch -p1 --ignore-whitespace -i patches/Other/ungoogled-main-repo-fix.patch --no-backup-if-mismatch
  # Remove the cache file if exists
  cache_file="domsubcache.tar.gz"
  if [[ -f ${cache_file} ]] ; then
      rm ${cache_file}
  fi

  # Ignore the pruning error
  python3 ungoogled-chromium/utils/prune_binaries.py src ungoogled-chromium/pruning.list --keep-contingent-paths || true
  python3 ungoogled-chromium/utils/patches.py apply src ungoogled-chromium/patches
  python3 ungoogled-chromium/utils/domain_substitution.py apply -r ungoogled-chromium/domain_regex.list -f ungoogled-chromium/domain_substitution.list -c ${cache_file} src

  # Additional Source Patches
  ## Extra fixes for Chromium source
  python3 ungoogled-chromium/utils/patches.py apply src patches
  ## Second pruning list
  pruning_list_2="pruning_2.list"
  python3 ungoogled-chromium/utils/prune_binaries.py src ${pruning_list_2} --keep-contingent-paths || true
  ## Second domain substitution list
  substitution_list_2="domain_sub_2.list"
  # Remove the cache file if exists
  cache_file="domsubcache.tar.gz"
  if [[ -f ${cache_file} ]] ; then
      rm ${cache_file}
  fi
  python3 ungoogled-chromium/utils/domain_substitution.py apply -r ungoogled-chromium/domain_regex.list -f ${substitution_list_2} -c ${cache_file} src

  psa_dat="src/components/privacy_sandbox/privacy_sandbox_attestations/preload/privacy-sandbox-attestations.dat"
  [[ -f ${psa_dat} ]] || : > ${psa_dat}

  ( cd src && git checkout HEAD -- \
      components/signin/public/base/signin_pref_names.h \
      components/signin/public/base/signin_pref_names.cc \
      components/safe_browsing/core/common/safe_browsing_prefs.h \
      components/safe_browsing/core/common/safe_browsing_prefs.cc 2>/dev/null ) || true

  ## Configure output folder
  export PATH=$OLD_PATH  # remove depot_tools from PATH
  pushd src
  mkdir -p "${output_folder}"
  if [ "$DEBUG" = n ] ; then
      cat ../ungoogled-chromium/flags.gn ../android_flags.gn ../android_flags.release.gn > "${output_folder}"/args.gn
      if [ -f ../../uc_keystore/keystore.gn ]; then
          cat ../../uc_keystore/keystore.gn >> "${output_folder}"/args.gn
      fi
  else
      cat ../android_flags.gn ../android_flags.debug.gn > "${output_folder}"/args.gn
  fi
  printf '\ntarget_cpu="'"$ARCH"'"\n' >> "${output_folder}"/args.gn
  # Trichrome doesn't forward version_name to base in bundle
  printf '\nandroid_override_version_name="'"${chromium_version}"'"\n' >> "${output_folder}"/args.gn

  buildtools/linux64/gn gen "${output_folder}" --fail-on-unused-args
  popd

  { echo "build      $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "version    ${chromium_version}-${ungoogled_chromium_android_revision}"
    echo "commit     $(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "fingerprint $(build_fingerprint | sha256sum | cut -d' ' -f1)"
    echo "session    $(date -u +%Y-%m-%dT%H:%M:%SZ)  run ${GITHUB_RUN_NUMBER:-local}  clean start"
  } > "$stamp_file"
fi

if [ "$PREPARE_ONLY" = y ]; then
    cat "$stamp_file"
    echo "prepare complete, stopping before ninja"
    exit 0
fi

## Set compiler flags
export AR=${AR:=llvm-ar}
export NM=${NM:=llvm-nm}
export CC=${CC:=clang}
export CXX=${CXX:=clang++}
export CCACHE_CPP2=yes
export CCACHE_SLOPPINESS=time_macros

## Build
case "${NINJA_JOBS:-0}" in
    ''|*[!0-9]*) NINJA_JOBS=0 ;;
esac
if [ "${NINJA_JOBS:-0}" -eq 0 ]; then
    NINJA_JOBS=$(nproc)
fi

ninja_build() {
  _dir="$1"
  shift
  if [ -z "${NINJA_TIMEOUT:-}" ]; then
    "$ninja_bin" ${NINJA_JOBS:+-j ${NINJA_JOBS}} -C "$_dir" "$@"
    return
  fi
  _rc=0
  timeout -k 5m -s INT "$NINJA_TIMEOUT" \
    "$ninja_bin" ${NINJA_JOBS:+-j ${NINJA_JOBS}} -C "$_dir" "$@" || _rc=$?
  if [ "$_rc" = 124 ] || [ "$_rc" = 137 ]; then
    echo "ninja reached the ${NINJA_TIMEOUT} budget with work remaining"
    echo "status=running" >> "${GITHUB_OUTPUT:-/dev/null}"
    exit 0
  fi
  return $_rc
}
apk_out_folder="apk_out"
mkdir -p "${apk_out_folder}"
pushd src
ninja_bin="third_party/ninja/ninja"
if [[ "$TARGET" != "all" ]]; then
  if [ "${TARGET_EXPANDED}" = "${chrome_modern_target}" ]; then
    if [[ "$ARCH" == "arm64" ]]; then
      ninja_build "${output_folder}" "${TARGET_EXPANDED}" chrome_public_apk system_webview_64_apk
    elif [[ "$ARCH" == "arm" ]]; then
      ninja_build "${output_folder}" "${TARGET_EXPANDED}" chrome_public_apk system_webview_apk
    else
      ninja_build "${output_folder}" "${TARGET_EXPANDED}" chrome_public_apk
    fi
  else
    ninja_build "${output_folder}" "${TARGET_EXPANDED}"
  fi
  if [[ "$TARGET" == "trichrome_chrome_bundle_target" ]] || [[ "$TARGET" == "chrome_modern_target" ]] || [[ "$TARGET" == "trichrome_chrome_apk_target" ]] || [[ "$TARGET" == "trichrome_webview_target" ]]; then
    if [ -f "$uc_keystore" ]; then
      ../bundle_generate_apk.sh -o "${output_folder}" -a "${ARCH}" -t "${TARGET_EXPANDED}"
    fi
  fi
  if [[ "$TARGET" != "webview_target" ]]; then
    _apk_src="${output_folder}/apks/release"
    [ -d "${_apk_src}" ] || _apk_src="${output_folder}/apks"
    find "${_apk_src}" -maxdepth 1 -iname "*.apk" -exec cp -f {} ../"${apk_out_folder}" \;
  else
    find ${output_folder}/apks -iname "*.apk" -exec cp -f {} ../"${apk_out_folder}" \;
  fi
else
  ninja_build "out/Default" "$chrome_modern_target"
  if [ -f "$uc_keystore" ]; then
    ../bundle_generate_apk.sh -o "${output_folder}" -a "${ARCH}" -t "$chrome_modern_target"
  fi
  ninja_build "out/Default" "$webview_target"
  ninja_build "out/Default" "$trichrome_webview_target"
  find ${output_folder}/apks/release -iname "*.apk" -exec cp -f {} ../"${apk_out_folder}" \;

  # arm64+TriChrome needs to be run separately, otherwise it will fail
  if [[ "$ARCH" != "arm64" ]]; then
    ninja_build "${output_folder}" "$trichrome_chrome_apk_target"
    find ${output_folder}/apks/release -iname "*.apk" -exec cp -f {} ../"${apk_out_folder}" \;
  fi
fi
popd

printf 'session    %s  run %s  BUILD COMPLETE\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${GITHUB_RUN_NUMBER:-local}" >> "$stamp_file"
echo "status=completed" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "=== build provenance ==="
cat "$stamp_file"

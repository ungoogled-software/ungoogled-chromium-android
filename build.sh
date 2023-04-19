#!/usr/bin/env bash
set -eu -o pipefail

# Required packages: passwd protobuf java-1.8.0-openjdk-headless java-1.8.0-openjdk-devel gperf wget rsync tar unzip gnupg2 curl maven yasm npm gn ninja-build nodejs git clang lld llvm flex bison libdrm-devel nss-devel dbus-devel libstdc++-static libatomic-static krb5-devel glib2 glib2-devel glibc.i686 glibc-devel.i686 fakeroot-libs.i686 libgcc.i686 libtool-ltdl.i686 libtool-ltdl-devel.i686

source .build_config

# Show env
pwd
env
whoami
echo $PATH
echo $HOME

# Argument parser from https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash/29754866#29754866
# -allow a command to fail with !’s side effect on errexit
# -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

OPTIONS=dla:t:
LONGOPTS=debug,local-sdk,arch:,target:

# -regarding ! and PIPESTATUS see above
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

ARCH=- TARGET=- DEBUG=n LOCAL_SDK=n

# now enjoy the options in order and nicely split until we see --
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
patch_applied=false

function prepare_repos {
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
  patch_applied=false

  ## Clone ungoogled-chromium repo
  git clone https://github.com/ungoogled-software/ungoogled-chromium.git -b ${ungoogled_chromium_version}-${ungoogled_chromium_revision} \
   || git clone https://github.com/wchen342/ungoogled-chromium.git -b ${ungoogled_chromium_version}-${ungoogled_chromium_revision} \
   || return $?

  ## Clone chromium repo
  git clone --depth 1 --no-tags https://chromium.googlesource.com/chromium/src.git -b ${chromium_version} || return $?

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
  path_modified=true
  pushd src/third_party
  ln -s ../../depot_tools
  popd
  # Replace ninja with system one
  pushd src/third_party/depot_tools
  rm ninja
  ln -s /usr/bin/ninja
  popd

  ## Sync files
  # third_party/android_deps and some other overrides doesn't work
  gclient.py sync --nohooks --no-history --shallow --revision=${chromium_version} || return $?

  ## Fix repos
  libsync_commit=$(grep 'libsync\.git' src/DEPS | cut -d\' -f10)
  mkdir src/third_party/libsync/src
  pushd src/third_party/libsync/src
  git init
  git remote add origin https://chromium.googlesource.com/aosp/platform/system/core/libsync.git
  git fetch --depth 1 --no-tags origin "${libsync_commit}" || return $?
  git reset --hard FETCH_HEAD
  popd

  fontconfig_commit=$(grep 'fontconfig\.git' src/DEPS | cut -d\' -f10)
  mkdir src/third_party/fontconfig/src
  pushd src/third_party/fontconfig/src
  git init
  git remote add origin https://chromium.googlesource.com/external/fontconfig.git
  git fetch --depth 1 --no-tags origin "${fontconfig_commit}" || return $?
  git reset --hard FETCH_HEAD
  popd

  # update node
  pushd src && patch -p1 --ignore-whitespace -i ../patches/Other/python3-dict-changed-size-during-iteration.patch --no-backup-if-mismatch && popd
  mkdir -p src/third_party/node/linux/node-linux-x64/bin
  ln -s /usr/bin/node src/third_party/node/linux/node-linux-x64/bin/
  ( src/third_party/node/update_npm_deps ) || return $?
  # Remove bundled jdk
  pushd src && patch -p1 --ignore-whitespace -i ../patches/Other/remove-jdk.patch --no-backup-if-mismatch && popd
  rm -rf src/third_party/jdk
  mkdir -p src/third_party/jdk/current/bin
  ln -s /usr/bin/java src/third_party/jdk/current/bin/
  ln -s /usr/bin/javac src/third_party/jdk/current/bin/
  ln -s /usr/bin/javap src/third_party/jdk/current/bin/
  mkdir -p src/third_party/jdk/current/lib
  ln -s $(find /usr/lib/jvm -type d -iname 'java-11-openjdk-*.x86_64')/lib/jrt-fs.jar src/third_party/jdk/current/lib/
  # jre
  mkdir -p src/third_party/jdk/extras/java_8 && pushd src/third_party/jdk/extras/java_8
  ln -s /usr/lib/jvm/jre-1.8.0 jre
  popd

  # Link to system llvm tools
  pushd src/buildtools/linux64
  ln -s /usr/bin/clang-format
  popd

  ## Hooks
  python src/build/util/lastchange.py -o src/build/util/LASTCHANGE
  python src/tools/download_optimization_profile.py --newest_state=src/chrome/android/profiles/newest.txt --local_state=src/chrome/android/profiles/local.txt --output_name=src/chrome/android/profiles/afdo.prof --gs_url_base=chromeos-prebuilt/afdo-job/llvm || return $?
  python src/build/util/lastchange.py -m GPU_LISTS_VERSION --revision-id-only --header src/gpu/config/gpu_lists_version.h
  python src/build/util/lastchange.py -m SKIA_COMMIT_HASH -s src/third_party/skia --header src/skia/ext/skia_commit_hash.h
  # Prebuilt toolchains. There are certain Android-specific files not included in common linux distributions.
  python src/tools/clang/scripts/update.py
  python src/build/linux/sysroot_scripts/install-sysroot.py --arch=i386
  python src/build/linux/sysroot_scripts/install-sysroot.py --arch=amd64
  patch_applied=true
  # Needed for an ad-block list ised in webview
  # gsutils still needs python2. Avoid it.
  cp misc/UnindexedRules src/third_party/subresource-filter-ruleset/data
}


function reverse_change {
  if [ "$path_modified" = true ] ; then
    export PATH=$OLD_PATH
    path_modified=false
  fi
  if [ "$patch_applied" = true ] ; then
    patch -p1 --ignore-whitespace -R -i patches/Other/gs-download-use-normal-python.patch --no-backup-if-mismatch
    patch_applied=false
  fi
}

# Run preparation
for i in $(seq 1 10); do prepare_repos && s=0 && break || s=$? && reverse_change && sleep 120; done; (exit $s)

## Run ungoogled-chromium scripts
# Patch prune list and domain substitution
# Some pruned binaries are excluded since they will cause android build to fail
patch -p1 --ignore-whitespace -i patches/Other/ungoogled-main-repo-fix.patch --no-backup-if-mismatch
# Remove the cache file if exists
cache_file="domsubcache.tar.gz"
if [[ -f ${cache_file} ]] ; then
    rm ${cache_file}
fi

# Ignore the pruning error
python3 ungoogled-chromium/utils/prune_binaries.py src ungoogled-chromium/pruning.list || true
python3 ungoogled-chromium/utils/patches.py apply src ungoogled-chromium/patches
python3 ungoogled-chromium/utils/domain_substitution.py apply -r ungoogled-chromium/domain_regex.list -f ungoogled-chromium/domain_substitution.list -c ${cache_file} src


## Compile third-party binaries
# eu-strip is re-compiled with -Wno-error
patch -p1 --ignore-whitespace -i patches/Other/eu-strip-build-script.patch --no-backup-if-mismatch
pushd src/buildtools/third_party/eu-strip
for i in $(seq 1 5); do ./build.sh && s=0 && break || s=$? && sleep 60; done; (exit $s)
popd
# Some of the support libraries can be grabbed from maven https://android.googlesource.com/platform/prebuilts/maven_repo/android/+/master/com/android/support/

## Prepare Android SDK/NDK
SDK_NAME="android-sdk_user-12.0.0_r13_linux-x86"
SDK_VERSION_CODE="12"

# Create symbol links to sdk folders
# The rebuild sdk has a different folder structure from the checked out version, so it is easier to create symbol links
# TODO: update sdk-tools to 29.0.0
DIRECTORY="src/third_party/android_sdk/public"
if [[ -d "$DIRECTORY" ]]; then
  find $DIRECTORY -mindepth 1 -maxdepth 1 -not -name cmdline-tools -exec rm -rf '{}' \;
fi
pushd ${DIRECTORY}
mkdir build-tools && ln -s ../../../../../android-sdk/${SDK_NAME}/build-tools/android-${SDK_VERSION_CODE} build-tools/31.0.0
mkdir platforms
ln -s ../../../../../android-sdk/${SDK_NAME}/platforms/android-${SDK_VERSION_CODE} platforms/android-31
ln -s ../../../../android-sdk/${SDK_NAME}/platform-tools platform-tools
ln -s ../../../../android-sdk/${SDK_NAME}/tools tools
popd

# remove ndk folders
DIRECTORY="src/third_party/android_ndk"
gn_file="BUILD.gn"
mkdir "ndk_temp"
cp -a "${DIRECTORY}/${gn_file}" ndk_temp
cp -ar "${DIRECTORY}/toolchains/llvm/prebuilt/linux-x86_64" ndk_temp    # Need libgcc.a, readelf, libatomic, etc. that's not in NDK prebuilt
pushd "${DIRECTORY}"
cd ..
rm -rf android_ndk
ln -s ../../android-ndk/android-ndk-r23 android_ndk
popd

mkdir android-sdk
mkdir android-ndk
pushd android-rebuilds
unzip -qqo ${SDK_NAME}.zip -d ../android-sdk && rm -f ${SDK_NAME}.zip && s=0 || s=$? && (exit $s)
unzip -qqo sdk-repo-linux-tools-26.1.1.zip -d ../android-sdk/${SDK_NAME} && rm -f sdk-repo-linux-tools-26.1.1.zip && s=0 || s=$? && (exit $s)
unzip -qqo android-ndk-r23-linux-x86_64.zip -d ../android-ndk && rm -f android-ndk-r23-linux-x86_64.zip && s=0 || s=$? && (exit $s)
popd

# Move ndk files into place
cp -a "ndk_temp/${gn_file}" android-ndk/android-ndk-r23
cp -ar "ndk_temp/linux-x86_64" android-ndk/android-ndk-r23/toolchains/llvm/prebuilt
rm -rf "ndk_temp"

# Additional Source Patches
## Extra fixes for Chromium source
python3 ungoogled-chromium/utils/patches.py apply src patches
## Second pruning list
pruning_list_2="pruning_2.list"
python3 ungoogled-chromium/utils/prune_binaries.py src ${pruning_list_2} || true
## Second domain substitution list
substitution_list_2="domain_sub_2.list"
# Remove the cache file if exists
cache_file="domsubcache.tar.gz"
if [[ -f ${cache_file} ]] ; then
    rm ${cache_file}
fi
python3 ungoogled-chromium/utils/domain_substitution.py apply -r ungoogled-chromium/domain_regex.list -f ${substitution_list_2} -c ${cache_file} src


## Configure output folder
export PATH=$OLD_PATH  # remove depot_tools from PATH
pushd src
output_folder="out/Default"
mkdir -p "${output_folder}"
if [ "$DEBUG" = n ] ; then
    cat ../ungoogled-chromium/flags.gn ../android_flags.gn ../android_flags.release.gn > "${output_folder}"/args.gn
    cat ../../uc_keystore/keystore.gn >> "${output_folder}"/args.gn
else
    cat ../android_flags.gn ../android_flags.debug.gn > "${output_folder}"/args.gn
fi
printf '\ntarget_cpu="'"$ARCH"'"\n' >> "${output_folder}"/args.gn
# Trichrome doesn't forward version_name to base in bundle
printf '\nandroid_override_version_name="'"${chromium_version}"'"\n' >> "${output_folder}"/args.gn

gn gen "${output_folder}" --fail-on-unused-args
popd


## Set compiler flags
export AR=${AR:=llvm-ar}
export NM=${NM:=llvm-nm}
export CC=${CC:=clang}
export CXX=${CXX:=clang++}
export CCACHE_CPP2=yes
export CCACHE_SLOPPINESS=time_macros

## Build
apk_out_folder="apk_out"
mkdir "${apk_out_folder}"
pushd src
if [[ "$TARGET" != "all" ]]; then
  ninja -C "${output_folder}" "${TARGET_EXPANDED}"
  if [[ "$TARGET" == "trichrome_chrome_bundle_target" ]] || [[ "$TARGET" == "chrome_modern_target" ]] || [[ "$TARGET" == "trichrome_chrome_apk_target" ]] || [[ "$TARGET" == "trichrome_webview_target" ]]; then
    ../bundle_generate_apk.sh -o "${output_folder}" -a "${ARCH}" -t "${TARGET_EXPANDED}"
  fi
  if [[ "$TARGET" != "webview_target" ]]; then
    find ${output_folder}/apks/release -iname "*.apk" -exec cp -f {} ../"${apk_out_folder}" \;
  else
    find ${output_folder}/apks -iname "*.apk" -exec cp -f {} ../"${apk_out_folder}" \;
  fi
else
  ninja -C out/Default "$chrome_modern_target"
  ../bundle_generate_apk.sh -o "${output_folder}" -a "${ARCH}" -t "$chrome_modern_target"
  ninja -C out/Default "$webview_target"
  ninja -C out/Default "$trichrome_webview_target"
  find ${output_folder}/apks/release -iname "*.apk" -exec cp -f {} ../"${apk_out_folder}" \;

  # arm64+TriChrome needs to be run separately, otherwise it will fail
  if [[ "$ARCH" != "arm64" ]]; then
    ninja -C "${output_folder}" "$trichrome_chrome_apk_target"
#    ../bundle_generate_apk.sh -o "${output_folder}" -a "${ARCH}" -t "$trichrome_chrome_bundle_target"
    find ${output_folder}/apks/release -iname "*.apk" -exec cp -f {} ../"${apk_out_folder}" \;
  fi
fi
popd

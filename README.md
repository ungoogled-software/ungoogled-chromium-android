# ungoogled-chromium-android

Please see [CHANGELOG](CHANGELOG.md) for latest updates.

*A lightweight approach to removing Google web service dependency*

*Note: this is an **Android** build.*

**Help is welcome!**

For more information on `ungoogled-chromium`, please visit the original repo: [ungoogled-software/ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium).

## Content Overview

* [Objectives](#objectives)
* [Differences from ungoogled-chromium](#differences-from-ungoogled-chromium)
* [Limitations](#limitations)
* [Platforms and Versions](#platforms-and-versions)
* [F-Droid](#f-droid)
* [Building Instructions](#building-instructions)
* [Reporting and Contributing](#reporting-and-contributing)
* [Extensions](#extensions)
* [Credits](#credits)
* [Related Projects](#related-projects)
* [License](#license)

## Objectives

In descending order of significance (i.e. most important objective first):

1. **ungoogled-chromium is Google Chromium, sans dependency on Google web services**.
2. **ungoogled-chromium retains the default Chromium experience as closely as possible**. Unlike other Chromium forks that have their own visions of a web browser, ungoogled-chromium is essentially a drop-in replacement for Chromium.
3. **ungoogled-chromium features tweaks to enhance privacy, control, and transparency**. However, almost all of these features must be manually activated or enabled. For more details, see [Feature Overview](https://github.com/ungoogled-software/ungoogled-chromium#feature-overview).

## Differences from ungoogled-chromium

*These are the differences between a Linux build of ungoogled-chromium and ungoogled-chromium-android.*

* Disable/Remove Android specific functionalities:
   * Contextual search
   * Home page, off by default
   * Location, falling back to the system provider
   * New Tab Page suggested sites
   * Offline indicator
   * Safe Browsing, compiled out along with its lookups
   * Terms-of-Service prompt and metrics opt-out
   * Unnecessary account permissions
* Android specific enhancements:
   * Add flag to always send `save-data` in header
   * Add flag to clear browsing data on exit
   * Add flag to disable WebRTC. This flag is enabled by default.
   * Rename the package to `org.ungoogled.chromium`, so it can be installed alongside Chrome
* Borrowed from Bromite:
   * Always incognito mode
   * Disable DRM media preprovisioning which leaks connections
   * Disable updater pings
   * DNS-over-https where the network supports it
   * Restore the flag to disable the pull-to-refresh effect
   * WebGL flag
* Borrowed from Cromite:
   * Bookmark import/export options
   * Clear open tabs between sessions
   * Exit menu item
   * Force tablet UI
   * Proxy configuration
* Borrowed from Vanadium:
   * Ask before playing protected media
   * Disable article suggestions, background sync and sensor access
   * Disable autofill server communication
   * Disable media router and media remoting
   * Disable metrics
   * Disable seed-based field trials, variations fetching and WebView variations
   * Disable showing popular sites
   * Disable the first run welcome page
   * Disable using Play services fonts
   * Enable split cache and strict site isolation
   * Various compiling time enhancements
* All Google play and Google service related blobs are removed. This includes Firebase, GCM (Google Cloud Messaging), GMS (Google Mobile Services) and bridge to Google Play.
* Releases are built for `arm` and `arm64`, plus an `.aab` for `arm64`. There is no `x86` or `x64` build.

## Limitations

The enhancements included in ungoogled-chromium **are not to be considered useful for journalists, people living in countries with freedom limitations, and those who are facing government-level adversaries**. Please look at tools specifically developed for these purposes, for example [Tor Browser](https://www.torproject.org/download/) in such cases.

## Platforms and Versions

Pre-built apks are named as `{BUILD_TARGET}_{CPU_ARCH}.apk`, where:
* `{BUILD_TARGET}` is `ChromePublic` (previously `ChromeModernPublic` from previous maintainer wchen342), for API >= 29 (Android 10), browser only.
* `{CPU_ARCH}` is one of `arm` (armeabi-v7a), `arm64` (arm64-v8a).
* Previous maintainer also built `Trichrome`, `SystemWebView`, `x86` for releases. My builds are currently done local rather than automating through github; if there's enough people requesting further builds I can spend the time to set this up.
* The [ungoogled-chromium wiki](https://ungoogled-software.github.io/ungoogled-chromium-wiki/), [Cromite documentation](https://github.com/uazo/cromite/tree/master/docs), [Vanadium](https://github.com/GrapheneOS/Vanadium) and the [Bromite wiki](https://github.com/bromite/bromite/wiki) can also be helpful.

## F-Droid

We trialed hosting a self-hosted [F-Droid](https://f-droid.org) repo from this
repository, but unfortunately without success. The client needs the signed index
**and** the ~367 MB APK served as a direct HTTP `200` (no redirect). There are
the following hurdles:

1. **Git branch + Git LFS** — the ~367 MB APK exceeds git's 100 MB per-file
   limit, so it *requires* Git LFS; but this is a *fork*, and GitHub forks can't
   store new LFS objects.
2. **Release assets** — every download URL `302`-redirects to a CDN, and the
   F-Droid client sets `followRedirects = false` (only a `404` is tolerated), so
   the repo can't live in release assets.
3. **Serving the APKs directly** — the only workable route, but it requires an
   external service to operate; GitHub's direct file hosts
   (`raw.githubusercontent.com`, Pages, jsDelivr) only serve git-tracked files
   (~100 MB cap) and can't deliver the APK.

Install the [release APKs](#platforms-and-versions) directly (sideload) instead.

## Building Instructions
*This build uses the SDK/NDK/JDK from the gclient checkout. [Android rebuilds](https://github.com/wchen342/android-rebuilds), used by earlier versions, is no longer maintained.*

* Clone this repository
* Make sure you have enough disk space and memory to build chromium
* enter repo directory and run `./build.sh`.

Build time dependencies:

<details>
  <summary>required packages</summary>

  **Debian**

  ```
      bison
      bzip2
      clang
      curl
      default-jdk
      file
      flex
      git
      gnupg2
      gperf
      lib32gcc-s1
      lib32stdc++6
      libc6-dev-i386
      libc6-i386
      libdbus-1-dev
      libdrm-dev
      libexpat1-dev
      libglib2.0-dev
      libkrb5-dev
      libnss3-dev
      libxkbcommon-dev
      lld
      llvm
      lsb-release
      make
      nodejs
      npm
      patch
      perl
      python3
      rsync
      tar
      unzip
      uuid-dev
      wget
      yasm
  ```

  **Fedora**

  ```
      bison
      bzip2
      clang
      curl
      dbus-devel
      expat-devel
      file
      flex
      git
      glib2-devel
      glibc-devel.i686
      glibc.i686
      gnupg2
      gperf
      java-latest-openjdk-devel
      krb5-devel
      libdrm-devel
      libgcc.i686
      libstdc++.i686
      libuuid-devel
      libxkbcommon-devel
      lld
      llvm
      make
      nodejs
      npm
      nss-devel
      patch
      perl
      python3
      redhat-lsb-core
      rsync
      tar
      unzip
      wget
      yasm
  ```

  **Arch**

  ```
      bison
      bzip2
      clang
      curl
      dbus
      expat
      file
      flex
      git
      glib2
      gnupg
      gperf
      jdk-openjdk
      krb5
      lib32-gcc-libs
      lib32-glibc
      libdrm
      libxkbcommon
      lld
      llvm
      lsb-release
      make
      nodejs
      npm
      nss
      patch
      perl
      python
      rsync
      tar
      unzip
      util-linux
      wget
      yasm
  ```

  The `lib32-*` packages require the `multilib` repository, which is disabled by default —
  uncomment the `[multilib]` section in `/etc/pacman.conf` and run `pacman -Sy` first.
</details>

*Builds are untested on other distros besides Debian.*

For a more customized building process, see building instructions from [the original repo](https://github.com/ungoogled-software/ungoogled-chromium/blob/master/docs/building.md) or [Cromite](https://github.com/uazo/cromite/blob/master/docs/HOW_TO_BUILD.md).

## Reporting and Contributing

* For reporting issues and contacting, see [SUPPORT](SUPPORT.md)
* Bug reports and code contributions are welcomed.

## Extensions

*The extension support version has been discontinued.* The last version is `88.0.4324.182`. It will still be available for downloading, but no new version will be released.

The extension patches can be found at [chromium-android-extension](https://github.com/wchen342/chromium-android-extension). Anyone interested is welcomed to fork and keeps working on it.

*Re-supporting extensions is being worked on, since many Android browsers now carry extension support.*

## Credits

* [The Chromium Project](https://www.chromium.org/)
* [ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium)
* [xsmile's fork](https://github.com/xsmile/ungoogled-chromium/tree/android)
* [Bromite](https://github.com/bromite/bromite)
* [Cromite](https://github.com/uazo/cromite)
* [Vanadium](https://github.com/GrapheneOS/Vanadium)
* [Unobtainium](https://gitlab.com/thermatk/Unobtainium)
* [Kiwi Browser](https://github.com/kiwibrowser)
* [dvalter's patches](https://github.com/dvalter/chromium-android-ext-dev)

## Related Projects

* [Cromite](https://github.com/uazo/cromite) (Bromite successor)
* [Vanadium](https://github.com/GrapheneOS/Vanadium) (Browser for GrapheneOS)
* [Bromite](https://github.com/bromite/bromite) (Discontinued Android build)

## License

See [LICENSE](LICENSE.md).

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
* [Building Instructions](#building-instructions)
* [Reporting and Contributing](#reporting-and-contributing)
* [Extensions](#extensions)
* [F-droid Repository](#f-droid-repository)
* [Credits](#credits)
* [Related Projects](#related-projects)
* [Sponsors](#sponsors)
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
   * Lite mode
   * Offline indicator
   * Prefetch
   * Home page links
   * Unnecessary account permissions
* Android specific enhancements:
   * Add `Startpage.com` and `Qwant.com` as search engine options
   * Add new folder button in bookmark manager
   * Add back flags to enable deprecated TLS warnings
   * Add flag to enable update notifications (disabled by default and will only send a single `GET` request to my server periodically)
   * Add flags to always send `save-data` flag in header
   * Add flags to force tablet UI and desktop mode
   * Add flag to disable WebRTC. This flag is enabled by default.
* Borrowed from Bromite:
   * Always incognito mode
   * Bookmark import/export options
   * Clear open tabs between sessions
   * Disable DRM media preprovisioning which leaks connections
   * DNS-over-https by default
   * Exit menu item
   * Proxy configuration
   * WebGL flag
* Borrowed from Vanadium:
  * Disable seed-based field trials
  * Disable media router
  * Disable metrics
  * Enable user-agent freeze
  * Enable split cache, partitioning connections, strict site isolation
  * Various compiling time enhancements
* All Google play and Google service related blobs are removed. This includes Firebase, GCM (Google Cloud Messaging), GMS (Google Mobile Services) and bridge to Google Play. 
* Releases are built for `arm`, `arm64` and `x86`. There is no `x86_64` build.

## Limitations

The enhancements included in ungoogled-chromium **are not to be considered useful for journalists, people living in countries with freedom limitations, and those who are facing government-level adversaries**. Please look at tools specifically developed for these purposes, for example [Tor Browser](https://www.torproject.org/download/) in such cases.

## Platforms and Versions

Pre-built apks are named as `{BUILD_TARGET}_{CPU_ARCH}.apk`, where:
* `{BUILD_TARGET}` is one of `ChromeModernPublic`, `Trichrome`, `SystemWebview`.
  * `ChromeModernPublic` is for API >= 21 (Android 5.0) and only contains the browser.
  * `Trichrome` is for API >= 29 (Android 10) and only contains the browser. *Note: `Trichrome` has two apks, you need to install both for ungoogled-chromium to work.*
  * `SystemWebview` is for >= API 21 (Android 5.0) and only contains the webview.
* `{CPU_ARCH}` is one of `x86`, `arm` (armeabi-v7a), `arm64` (arm64-v8a).
* Please also read this [important note](https://chromium.googlesource.com/chromium/src/+/HEAD/android_webview/docs/build-instructions.md#Important-notes-for-N_P) about Webview on Android N-P.
* The [Bromite Wiki](https://github.com/bromite/bromite/wiki/Installing-SystemWebView) can also be helpful.

## Building Instructions
*This build is built using [Android rebuilds](https://github.com/wchen342/android-rebuilds) instead of SDK/NDK binaries from Google.*

* Clone this repository
* Make sure you have enough disk space and memory to build chromium
* enter repo directory and run `./build.sh`.

Build time dependencies (*package names as in Fedora 33. Other distributions may have different package names*):

<details>
  <summary>required packages</summary>
  
  ```
      bison
      bzip2
      clang
      curl
      dbus-devel
      expat-devel
      fakeroot-libs.i686
      flex
      git
      glib2
      glib2-devel
      glibc.i686
      glibc-devel.i686
      gnupg2
      gperf
      java-1.8.0-openjdk-devel
      java-1.8.0-openjdk-headless
      java-11-openjdk
      java-11-openjdk-devel
      java-11-openjdk-headless
      krb5-devel
      libatomic-static
      libdrm-devel
      libgcc.i686
      libstdc++-static
      libtool-ltdl.i686
      libtool-ltdl-devel.i686
      libuuid-devel
      libxkbcommon-devel
      lld
      llvm
      make
      maven
      ninja-build
      nodejs
      npm
      nss-devel
      passwd
      patch
      perl
      protobuf
      python2.7
      python3
      rsync
      tar
      unzip
      yasm
      wget
  ```
</details>

For a more customized building process, see building instructions from [the original repo](https://github.com/ungoogled-software/ungoogled-chromium/blob/master/docs/building.md).

## Reporting and Contributing

* For reporting issues and contacting, see [SUPPORT](SUPPORT.md)
* Bug reports and code contributions are welcomed.

## Extensions

*The extension support version has been discontinued.* The last version is `88.0.4324.182`. It will still be available for downloading, but no new version will be released.

The extension patches can be found at [chromium-android-extension](https://github.com/wchen342/chromium-android-extension). Anyone interested is welcomed to fork and keeps working on it.

## Credits

* [The Chromium Project](https://www.chromium.org/)
* [ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium)
* [xsmile's fork](https://github.com/xsmile/ungoogled-chromium/tree/android)
* [Bromite](https://github.com/bromite/bromite)
* [Kiwi Browser](https://github.com/kiwibrowser)
* [dvalter's patches](https://github.com/dvalter/chromium-android-ext-dev)

## Related Projects

* [Bromite](https://github.com/bromite/bromite) (Another build for Android. Has some own features.)

## License

See [LICENSE](LICENSE.md).

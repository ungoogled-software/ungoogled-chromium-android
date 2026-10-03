# 154.0.8037.92-1
* Upstream update
* Fixed chrome://proxy settings not applying to websites

# 152.0.7977.82-1
* Upstream update
* Added patches for extensions & misc crash fixes

# 150.0.7871.114-1
* Upstream update (v99.0.4844.51-1 to v150.0.7871.114)
* Refreshed patches from bromite, cromite (bromite successor), & vanadium; doing my best to mirror the previous maintainers philosophy and patch structure
* Fixed patches from cromite to work with newer chromium versions
* Note: *apk signatures* are changed as future updates will be done by a new maintainer using a different keystore.

# 99.0.4844.51-1
* Add clear data on exit flag
* Add flag to disable WebRTC until a UI can be implemented (See [discussion](https://github.com/ungoogled-software/ungoogled-chromium-android/discussions/116)). This flag is enabled by default
* Add a fix for Note9 on Android 8 (Thanks to @uazo)

# 97.0.4692.71-1
* Upstream update

# 96.0.4664.110-1
* Upstream update

# 96.0.4664.93-1
* Upstream update

# 96.0.4664.45-1
* Re-enable bookmark import-export
* Disable offline indicator
* Add extra Vanadium enhancements:
  * Enable user-agent freeze
  * Enable split cache, partitioning connections, strict site isolation
  * Other compiling time enhancements

# 95.0.4638.74-1
* Upstream update

# 95.0.4638.54-1
* Remove FloC setting

# 94.0.4606.81-1
* Now using Android SDK 12 r02

# 94.0.4606.71-1
* Bookmark import-export is disabled (again)
* Now built with Android SDK rebuilt from s-beta-5 (Android 12 beta) and NDK r23. If you want to know how they are built, see [here](https://github.com/wchen342/android-rebuilds).
* For some reason the aforementioned public version of Android 12 SDK doesn't have new APIs in them, so they are removed (for now). Will re-investigate when formal version of SDK 12 release.

# 94.0.4606.61-1
* Re-enable proxy settings and bookmark import-export

# 94.0.4606.54-1
* Upstream update

# 93.0.4577.82-1
* Proxy settings and bookmark import-export are temporarily disabled

# 93.0.4577.63-1
* Build script can now run with python3
* disable play service fonts

# 92.0.4515.159-1
* Upstream update

# 92.0.4515.107-1
* Remove DeviceOrientation API related flags. See [bromite/bromite/issues/1204](https://github.com/bromite/bromite/issues/1204).
* Remove FireBase dependencies and move to a separate patch

# 91.0.4472.164-1
* Upstream security fixes
* Fix update notification flag
* Add always incognito mode

# 91.0.4472.114-2
* Add back 64-bit Trichrome

# 91.0.4472.114-1
* Upstream security fixes

# 91.0.4472.77-1
* Trichrome is temporarily rolled back to 32-bit. If it works fine 64-bit will be added back next version.
* Trichrome `apk` support can end any time due to Google decided to remove the ability of not using split modules, as well as stripe the ability of building `apk`s directly for some time now. After that, you will have to manually install an `aab` file using `bundletool` and a specific `aapt2` file. I will try to keep fixing it as long as I can but it can stop working any time from now on.
  * Adding to their recent move of limiting APIs, I reflect [the call from Fedora chromium package maintainer](https://src.fedoraproject.org/rpms/chromium/blob/c4e9feabf040cc2f0c4bac40e8d06fbaf8923c33/f/chromium.spec#_178) that at this point, if you really value _free software as in freedom_, you would be better off use something else instead, like `Fennec F-Droid`.

# 90.0.4430.212-1
* Upstream security fixes

# 90.0.4430.93-1
* Add 64-bit webview for Trichrome
* Disable inline update by default
* Remove "Safety Check" and proactive help
* Disable TFLite

# 89.0.4389.114-2
* Fix Trichrome

# 89.0.4389.114-1
* Upstream security fixes
* Use 64-bit targets for arm64

# 89.0.4389.90-1
* Upstream security fixes

# 89.0.4389.82-1
* ungoogled-chromium version update

# 89.0.4389.72-1
* Include several enhancements from Vanadium
* Add proxy settings, disable AMP on sites

# 88.0.4324.182-2
* Add fix for DoH
* Change description for WebGL flag
* Add GPC (Global Privacy Control) support (Warning: turning this on may *increase* your browser's fingerprint!)
* Add separate `arm64` and `x86` F-Droid repo

# 88.0.4324.182-1
* Upstream important security fix
  <details>
    <summary>CVE list</summary>

      [1138143] High CVE-2021-21149: Stack overflow in Data Transfer.
      [1172192] High CVE-2021-21150: Use after free in Downloads.
      [1165624] High CVE-2021-21151: Use after free in Payments.
      [1166504] High CVE-2021-21152: Heap buffer overflow in Media.
      [1155974] High CVE-2021-21153: Stack overflow in GPU Process.
      [1173269] High CVE-2021-21154: Heap buffer overflow in Tab Strip.
      [1175500] High CVE-2021-21155: Heap buffer overflow in Tab Strip.
      [1177341] High CVE-2021-21156: Heap buffer overflow in V8.
      [1170657] Medium CVE-2021-21157: Use after free in Web Sockets.
  </details>

# 88.0.4324.152-3
* Extension version only:
  * Fix two bugs related to uninitialized web contents upon restoring the browser activity

# 88.0.4324.152-2
* Extension version only:
  * Add extension icons to app menu. It is now possible to open the extension popups from main menu. *Note: not all functionalities are working.*
  * Known issue: the icons will not be visible the first time menu is opened after installation or a cold start.
  * Extensions that are known to work:
    * [NoScript](https://noscript.net/)
    * [Privacy Badger](https://privacybadger.org/)
    * [HTTPS Everywhere](https://www.eff.org/https-everywhere)
    * [Decentraleyes](https://decentraleyes.org/)
    * [Cookie AutoDelete](https://github.com/Cookie-AutoDelete/Cookie-AutoDelete)
    * [uBlock Origin](https://github.com/gorhill/uBlock) (*except for logger window*)
    * [uMatrix](https://github.com/gorhill/uMatrix)
    * [ClearURLs](https://gitlab.com/KevinRoebert/ClearUrls)

# 88.0.4324.152-1
* Upstream important security fix
  * [1170176] High CVE-2021-21148: Heap buffer overflow in V8. Reported by Mattias Buelens on 2021-01-24
* Due to increasing problems with webview and build time, I will now release the main browser and webviews separately. In case of any problems occur with the builds, the main browser will take precedence. 

# 88.0.4324.146-1
* Upstream important security fix
  * [1169317] Critical CVE-2021-21142: Use after free in Payments . Reported by Khalil Zhani on 2021-01-21
  * [1163504] High CVE-2021-21143: Heap buffer overflow in Extensions. Reported by Allen Parker & Alex Morgan of MU on 2021-01-06
  * [1163845] High CVE-2021-21144: Heap buffer overflow in Tab Groups. Reported by Leecraso and Guang Gong of 360 Alpha Lab on 2021-01-07
  * [1154965] High CVE-2021-21145: Use after free in Fonts. Reported by Anonymous on 2020-12-03
  * [1161705] High CVE-2021-21146: Use after free in Navigation. Reported by Alison Huffman and Choongwoo Han of Microsoft Browser Vulnerability Research on 2020-12-24
  * [1162942] Medium CVE-2021-21147: Inappropriate implementation in Skia. Reported by Roman Starkov on 2021-01-04
* Fix webview build

# 88.0.4324.104-1
* Now using SDK 30 (Android 11)
* Fix gradle generation
* Add option to enable `save-data` header
* Add option to force desktop mode
* Add option to force tablet UI

# 87.0.4280.141-2
* Extension version only:
  * HTTPS Everywhere can now open options page correctly
  * Decentraleyes is now functional and [can pass their test](https://decentraleyes.org/test)
  * Fix a bug that prevents uBlock Origin from functioning after restart
  * Extension page no longer needs manual refresh after installation or switching on/off.
  * Potentially fix a bug with developer mode loading on Android 10+
  * Known problem: extensions will not work on the first tab from a cold start (e.g. when you have restarted the device). Close the tab and open a new one fixes the problem.
* Every new file created in the patchset is now marked with GNU GPL notice

# 87.0.4280.141-1
* Prevent Google connections from DRM preprovisioning ([ungoogled-chromium/issues/1297](https://github.com/Eloston/ungoogled-chromium/issues/1297))
* Remove sites on new page

# 87.0.4280.88-1
* Add DoH patch back
* There is a problem about [leaking connections](https://github.com/Eloston/ungoogled-chromium/issues/1297). It is being investigated.

# 86.0.4240.111-1
* Custom DoH setting is removed since it is supported natively.
* `ChromeModernPublic` is also generated from bundle file now since Google removed the `apk` target.
* Add a fix for android-sdk building tools thanks to @Niek
* Other minor fixes.
* Note: *apk signatures are changed* as I lost access to my `keystore` file during my move, so it is normal to see `Wrong signature` while installing. GPG keys for signing binary releases are still valid.

# 85.0.4183.121-1
* Upstream update

# 85.0.4183.83-1
* All versions:
  * Update building targets. Now the two versions will be one for Android 5.0+ and one for Android 10+. Note that `Trichrome` produce two apks, you need to install both.
  * Remove Google related UI elements.
  * Remove first run screen.
  * Fix safe browsing error for v85.

# 84.0.4147.125-1
* All versions:
  * The package names are now `org.ungoogled.chromium.stable`/`org.ungoogled.chromium.extensions.stable` due to [#53](https://git.droidware.info/wchen342/ungoogled-chromium-android/issues/53) / [#24](https://github.com/ungoogled-software/ungoogled-chromium-android/issues/24).
  * Fix [#26](https://github.com/ungoogled-software/ungoogled-chromium-android/issues/26).
  * Disable Google homepage by default when first installed.

# 84.0.4147.105-1
* Upstream update

# 84.0.4147.89-2
* All versions:
  * The apks are now signed with a custom signing key, instead of the default debug key coming with chromium source code. This will prevent miraculous attacks which debug keys are used to install miraculous apks. *Note: this is a breaking change. You will need to uninstall the current version on your phone!*
* Add import/export bookmarks
* Users on Android KitKat: API level 19-20 are deprecated by Chromium team. See [this link](https://groups.google.com/a/chromium.org/forum/m/#!topic/chromium-dev/ypAS49lvN1M).

# 84.0.4147.89-1
* Interval of checking update is now fixed to once every 2 days
* Extension version:
  * Fix a possible cause of [#51](https://git.droidware.info/wchen342/ungoogled-chromium-android/issues/51)
  * Add extension removal prompt

# 83.0.4103.116-2
* Fix bug with update notification keeps sending pings

# 83.0.4103.116-1
* Add update notification (resolve [#22](https://git.droidware.info/wchen342/ungoogled-chromium-android/issues/22)). Note: this is disabled by default since it will ping my server at [uc.droidware.info](https://uc.droidware.info). To enable, change `#enable-inline-update-flow` to `Enabled`.
  * Update: the functionality currently has a bug that will make it send continuous bursts of requests to my server. Please DO NOT enable it for now. This will be fixed in the next version.
* Reverse the removal of flags `#enable-process-sharing-with-default-site-instances` and `#enable-process-sharing-with-strict-site-instances`.
* Extension version:
  * [`chromium-webstore`](https://github.com/NeverDecaf/chromium-web-store) is now bundled with extension version
  * Resolve [#45](https://git.droidware.info/wchen342/ungoogled-chromium-android/issues/45)

# 83.0.4103.106-1
* Extension version:
  * Fix a bug preventing non Android 10 phones from installing extensions from url
* Website for `ungoogled-chromium-android` is now online at [https://uc.droidware.info](https://uc.droidware.info).

# 83.0.4103.97-1
* Extension version:
  * Add direct install through url
* Update [README#Limitations](https://git.droidware.info/wchen342/ungoogled-chromium-android#user-content-limitations), [README#Reporting and Contributing](https://git.droidware.info/wchen342/ungoogled-chromium-android#user-content-reporting-and-contributing), [README#Extensions](https://git.droidware.info/wchen342/ungoogled-chromium-android#user-content-extensions) and [SUPPORT](https://git.droidware.info/wchen342/ungoogled-chromium-android/src/branch/master/SUPPORT.md).

# 83.0.4103.61-1
* Add extension-support version
  * This version is highly experimental and is not intended for daily usage yet! See [README#Extensions](https://git.droidware.info/wchen342/ungoogled-chromium-android#user-content-extensions)
  * Extension removal is not implemented yet
  * The package will have a name `org.ungoogled.chromium.extensions`
* Resolve [#20](https://github.com/wchen342/ungoogled-chromium-android/issues/20), [#23](https://github.com/wchen342/ungoogled-chromium-android/issues/23)
* Partially resolve [#19](https://github.com/wchen342/ungoogled-chromium-android/issues/19), [#21](https://github.com/wchen342/ungoogled-chromium-android/issues/21)
* Add migration for WebRTC

# 81.0.4044.138-1
* Fix a crash with incognito tab
* Minor fix for extension patches. From next release, `chrome`/`arm` target will include a beta version with extension support.

# 81.0.4044.129-1
* Fix a bug with bookmark add new folder activity.
* Add new fix of [#9](https://github.com/wchen342/ungoogled-chromium-android/issues/9).

# 81.0.4044.113-1
* Resolve [#9](https://github.com/wchen342/ungoogled-chromium-android/issues/9), [#16](https://github.com/wchen342/ungoogled-chromium-android/issues/16).
* Initial attempt to add extensions (not working yet)

# 80.0.3987.122-1
* This is an important security release that fix three vulnerabilities. All previous versions should update as soon as possible.
  * [1044570] High: Integer overflow in ICU. Reported by André Bargull (with thanks to Jeff Walden from Mozilla) on 2020-01-22
  * [1045931] High CVE-2020-6407: Out of bounds memory access in streams. Reported by Sergei Glazunov of Google Project Zero on 2020-01-27
  * [1053604] High CVE-2020-6418: Type confusion in V8. Reported by Clement Lecigne of Google's Threat Analysis Group on 2020-02-18 (_actively exploited in the wild_)
* Fix video crash on Android P on certain machines

# 80.0.3987.106-1
* Port some privacy related functionality from `Bromite`, including:
  * flag to disable WebGL
  * flag to disable motion sensors
  * exit button and do not persist option
  * use blank page as homepage
  * setting for DNS-over-HTTPS (DoH)
  * flag to disable pull-to-refresh
* Disable contextual search in native code instead of Java
* Disable lite mode prompt
* Disable download articles over Wi-fi
* Build time change (not affecting users):
  * Exclude unit tests from domain substitution
  * Using system JDK instead of bundled one. Requires both Java-8 and Java-10 on Arch Linux.
  * Now build with SDK 29

# 79.0.3945.117-2
* Add ChromePublic target (API 19)
* Fix build failure for safe browsing
* Update `README`

# 79.0.3945.117-1
* Update NDK to r20b
* Remove split installer dependencies (Google Play), disable DFM
* Other source fixes
* Known issue: ~~some pages, including `chrome://flags`, `chrome://gpu` are not working~~ (Fixed)

# 78.0.3904.97-1
* Update scripts and patches to new version
* Merge patches from Bromite and Unobtainium
* New dependencies: nodejs binaries, lib files from ndk

# 77.0.3865.90-1
* Update patches to new version
* Update GN to latest commit
* Minor fixes

# 76.0.3809.132-1
* No change

# 76.0.3809.100-1
* Change default setting of contextual search to false

# 76.0.3809.87-1
* Add WebView builds
* Since `aapt` no longer works, bundled `aapt2` will be used until a rebuild of SDK 29 exists
* Minor bug fixes

# 75.0.3770.142-2
* Remove all Google Play related libraries
* Uncheck "Send statistics" on first run

# 75.0.3770.142-1
* Fix [#3](https://github.com/wchen342/ungoogled-chromium-android/issues/3)
* Disable resource obfuscation
* Add arm build

# 75.0.3770.100-1
* Change package name to avoid conflict with chromium

# 75.0.3770.80-1
* Reduce downloaded dependencies on gclient sync
* Prune more binaries
* Build gcm-client, eu-strip, closure-compiler from source; change error-prone to Maven version
* Domain substitution on all non-binary files

# 74.0.3729.169-1
* First release

# F-Droid repository

This directory contains a self-hosted [F-Droid](https://f-droid.org) repository so
Ungoogled Chromium can be installed through the F-Droid client directly from this
GitHub repository — no separate F-Droid data repo or build farm required.

## Add it to F-Droid

In the F-Droid client, use **Add repository** (or *More → Repositories → +*) and enter:

```
https://raw.githubusercontent.com/ungoogled-software/ungoogled-chromium-android/master/fdroid/repo
```

The app should then appear as **Ungoogled Chromium** and update on every release.

> Requires the **F-Droid client 2.0.x**. The classic 1.x client used a different
> (`index-v1.1.xml`) index format and is not targeted here.

## How it works

On every release (tag push), the `fdroid` job in
[`.github/workflows/build-hosted.yml`](../.github/workflows/build-hosted.yml) runs
after the GitHub release is created and does the following:

1. Takes the release-signed **arm64** APK from the build artifact.
2. Extracts metadata (package name, version, SDK levels, permissions, ABIs)
   and the launcher icon — including adaptive icons, whose WebP foreground is
   resolved and converted to PNG — with `aapt2`.
3. Writes `repo/index-v1.json` and builds a **signed** `repo/index-v1.jar`
   (the F-Droid 2.0 index is a signed JAR; plain XML/JSON is rejected).
4. Copies the APK into the repo and keeps only the newest `UGC_KEEP` (default 3)
   versions, pruning older ones.
5. Commits the changes to `master` and pushes (APKs are stored in Git LFS).
6. Verifies the APK is actually served (not an LFS pointer) by re-fetching it
   over `raw.githubusercontent.com` and checking the length/signature.

### Signing

The index JAR is signed with the **same keystore used to sign the release APKs**
(the `KEYSTORE_B64` / `KEYSTORE_PASS` GitHub secrets, alias `key0`) — the exact
`jarsigner` invocation already used for the `.aab` in
[`build/release.sh`](../build/release.sh). The F-Droid client uses
trust-on-first-use for the repository's signing certificate, so users do not need
to paste a fingerprint.

## Layout

```
fdroid/repo/
  index-v1.json            # index data (generated)
  index-v1.jar             # signed index the client actually downloads (generated)
  icons/
    repo.png               # repository icon
    org.ungoogled.chromium.stable_<versionCode>.png
  org.ungoogled.chromium.stable_<versionCode>.apk   # Git LFS
```

The client resolves files relative to the base URL above:
`<base>/index-v1.jar`, `<base>/icons/...`, `<base>/org.ungoogled.chromium.stable_<versionCode>.apk`.

## Regenerating / troubleshooting

- The index is fully generated; do not edit `fdroid/repo/*` by hand.
- To rebuild for a specific tag, run the `release build` workflow via
  **Actions → dispatch** with that tag as the release name.
- If an APK appears as a ~130-byte file (an LFS pointer) instead of the real APK,
  Git LFS was not resolved — the `fdroid` job's final step will fail loudly in that case.

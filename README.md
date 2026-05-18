# download

Public landing page for distributing the FARMIS Android APK to farmers in Papua New Guinea.

**Live URL:** https://farmis-app.github.io/download/

The APK is hosted as a **GitHub Release asset**, not committed to this repo (it's 132 MB, over the 100 MB push limit). The download button on the landing page uses the evergreen redirect:

```
https://github.com/Farmis-App/download/releases/latest/download/farmis.apk
```

## Shipping a new version

1. Build the release APK and rename it to `farmis.apk` (same name every time — the evergreen URL depends on it):
   ```
   cd ../farmis-all/android && ./gradlew assembleRelease && cd ..
   cp android/app/build/outputs/apk/release/app-release.apk /tmp/farmis.apk
   ```
2. Draft a new release: `gh release create vX.Y.Z /tmp/farmis.apk --title "FARMIS vX.Y.Z" --notes "..."` (leave "Set as latest release" enabled, which is the default).
3. Edit `index.html`: update the `Version 0.1.0` line and the `132 MB` size if either changed. Commit and push.
4. The download link in `index.html` does not need to change.

## Tok Pisin

The install steps include a Tok Pisin translation. It is a starting draft — please have a native speaker review before printing posters.

## Caveats

- GitHub Releases is public. Anyone with the URL can download.
- Google Play Protect will warn on side-loaded APKs; the install instructions tell users to expect this.
- For longer-term distribution consider Firebase App Distribution or the Play Store.

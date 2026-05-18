# download

Public landing page for distributing the FARMIS Android APK to farmers in Papua New Guinea.

**Live URL:** https://farmis-app.github.io/download/

The APK is hosted as a **GitHub Release asset**, not committed to this repo (it's 132 MB, over the 100 MB push limit). The download button on the landing page uses the evergreen redirect:

```
https://github.com/Farmis-App/download/releases/latest/download/farmis.apk
```

## Shipping a new version

Use the release script:

```
./scripts/release-apk.sh <version>
```

It bumps versions in `farmis-all/`, builds the APK, uploads it as a GitHub Release, and updates `index.html`. Full instructions, options, and troubleshooting are in [RELEASING.md](RELEASING.md).

## Tok Pisin

The install steps include a Tok Pisin translation. It is a starting draft — please have a native speaker review before printing posters.

## Caveats

- GitHub Releases is public. Anyone with the URL can download.
- Google Play Protect will warn on side-loaded APKs; the install instructions tell users to expect this.
- For longer-term distribution consider Firebase App Distribution or the Play Store.

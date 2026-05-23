## FARMIS v1.0.3

**Important: if you have FARMIS v1.0.1 or v1.0.2 installed, please uninstall the old version before installing this one.**

This release re-signs the app with FARMIS's permanent production key, in preparation for the Google Play Store listing. There are no feature changes vs. v1.0.2 — same app, same 45 MB, same arm64-v8a build.

Android blocks in-place upgrades when an app's signing certificate changes, so v1.0.3 is a one-time reinstall. Every release from v1.0.4 onward will install over the previous version normally.

### How to upgrade

1. Open Android **Settings → Apps → FARMIS → Uninstall**.
2. Download `farmis.apk` from this page.
3. Tap the file to install. Allow "install from unknown source" if prompted.
4. Open FARMIS and continue as before.

Full install instructions, including Tok Pisin walkthrough: https://farmis-app.github.io/download/

### Why the change

Google Play requires every release to be signed with a production key. v1.0.1 and v1.0.2 were signed with a temporary development key as we were preparing distribution — this version uses the permanent FARMIS key that will sign every future release.

### Technical details

- arm64-v8a only, ~45 MB
- Hermes engine, ProGuard + resource shrinking
- Signing cert SHA-256:
  `c0:ec:bf:a0:28:40:cd:e4:35:2e:38:7c:cf:6b:5a:39:ea:a5:17:cf:fe:ab:d5:60:d3:8e:51:20:64:db:93:3c`

# Releasing a new FARMIS APK

This page documents the release process for the FARMIS Android APK. The whole flow is automated by [`scripts/release-apk.sh`](scripts/release-apk.sh).

## Prerequisites

- `gh` CLI installed and authenticated with push access to `Farmis-App/download`
  ```
  gh auth status
  ```
- `python3` on PATH (used for safe JSON edits)
- Sibling checkout of the app repo at `../farmis-all` (i.e. both repos live side-by-side under the same parent directory)
- Android release signing configured locally (see next section)

## One-time signing setup

The release build is signed with a **production keystore**. Lose this keystore and you can never publish updates from the same signing identity again — back it up to two independent locations (encrypted USB, password manager, off-site backup).

### 1. Generate the keystore

Run this once on the release machine:

```bash
keytool -genkeypair -v \
  -keystore ~/farmis-release.keystore \
  -alias farmis \
  -keyalg RSA -keysize 2048 -validity 10000
```

You'll be prompted for:

- a store password (used to unlock the keystore file)
- a key password (used to unlock the `farmis` alias — keep it the same as the store password for simplicity)
- your name, org, city, country (this is the certificate distinguished name; can be anything sensible)

### 2. Tell Gradle about it

Add these four lines to `~/.gradle/gradle.properties` (the user-level file — **never** put them in the repo's `gradle.properties`):

```properties
FARMIS_UPLOAD_STORE_FILE=/Users/macbookpro/farmis-release.keystore
FARMIS_UPLOAD_KEY_ALIAS=farmis
FARMIS_UPLOAD_STORE_PASSWORD=<store password from step 1>
FARMIS_UPLOAD_KEY_PASSWORD=<key password from step 1>
```

`farmis-all/android/app/build.gradle` reads those four properties at build time. If any are missing the build fails with a clear error.

### 3. Back the keystore up

Copy `~/farmis-release.keystore` and the passwords to **at least two** separate secure locations (encrypted external drive, 1Password/Bitwarden vault, off-site backup). Without them you cannot publish another update — Android refuses to install upgrades signed with a different key.

### 4. Smoke-test once

```bash
cd ../farmis-all/android
SENTRY_DISABLE_AUTO_UPLOAD=true ./gradlew assembleRelease
```

The build should succeed and produce a properly signed APK at `app/build/outputs/apk/release/app-release.apk`. To verify the signature:

```bash
~/Library/Android/sdk/build-tools/*/apksigner verify --print-certs \
  app/build/outputs/apk/release/app-release.apk
```

You should see a certificate that matches the DN you entered in step 1 (not the well-known `androiddebugkey` CN).

## ⚠️ Migrating users from the debug-signed v1.0.1 / v1.0.2

The first two FARMIS releases were debug-signed. Once you switch to the production keystore, **anyone with v1.0.1 or v1.0.2 installed must uninstall the old version before installing the new one** — Android blocks in-place upgrades when the signing certificate changes.

Add a clear note to the v1.0.3 release notes and consider mentioning it on the landing page banner. Subsequent updates (v1.0.4+) will upgrade in place normally.

## Release a new version

From the root of this repo:

```bash
./scripts/release-apk.sh 1.0.3
```

Replace `1.0.3` with the new semver. **No leading `v`** — the script adds it for the tag.

What happens:

1. Sanity checks (gh auth, files present, tag not already used, release signing configured)
2. Bumps `versionName` in `farmis-all/app.json`, `package.json`, `android/app/build.gradle`
3. Increments `versionCode` by 1 in `build.gradle`
4. Runs `./gradlew assembleRelease bundleRelease` to produce both an APK and an AAB
5. Uploads the APK to GitHub as `vX.Y.Z` on `Farmis-App/download`, renamed to `farmis.apk`
6. Updates `index.html` (version label + APK size)
7. Prints next-step commands: AAB path for Play, APK path for Uptodown, and `git` commits for both repos

The script intentionally does **not** auto-commit, auto-push, or auto-upload to Play / Uptodown.

## Options

| Flag | Effect |
|---|---|
| `--notes "..."` | Inline release notes (default: auto-generated) |
| `--notes-file path` | Read release notes from a file |
| `--skip-build` | Skip the gradle build and use the existing `app-release.apk` / `.aab` |
| `-h`, `--help` | Show usage |

## Google Play Console submission

Play requires an **AAB** (App Bundle), not an APK. The release script produces one at:

```
../farmis-all/android/app/build/outputs/bundle/release/app-release.aab
```

### First-time submission

1. Create a Google Play Console account ($25 one-time, [play.google.com/console](https://play.google.com/console)).
2. Create a new app: name "Farmis", default language English (United States) or English (Australia), free, app (not game).
3. Complete the **App content** declarations: privacy policy URL, app access, ads, content rating, target audience, data safety, government apps section.
4. Add the store listing: short description, long description, screenshots (min 2, recommended 8, 320–3840 px on each side), feature graphic (1024×500), app icon (Play extracts from the AAB).
5. Under **Release → Production → Create new release**:
   - Opt in to **Play App Signing** when prompted (Google manages the actual app signing key; your local keystore becomes the "upload key").
   - Upload `app-release.aab`.
   - Add release notes.
   - Save → Review → Start rollout.

First review typically takes 1–7 days. Subsequent updates are usually approved within hours.

### Subsequent releases

After the script publishes the GitHub release:

1. Open the app in [Play Console](https://play.google.com/console).
2. **Release → Production → Create new release** (or use an internal/closed testing track first).
3. Upload `app-release.aab` from the path printed by the script.
4. Paste release notes (the same text used for the GitHub release works).
5. Save → Review → Start rollout.

## Uptodown submission

Uptodown accepts signed **APKs** directly. There is no fee.

### First-time submission

1. Register as a developer at [en.uptodown.com/android/developers](https://en.uptodown.com/android/developers).
2. Click **Upload an app** and pick `farmis.apk` (either the local file or the GitHub release asset).
3. Fill in the listing: title, description (English + optional translations), category (Education / Reference / Tools), tags, screenshots, icon (extracted from the APK), website URL (`https://farmis.ai`), developer email.
4. Submit. Uptodown moderation typically takes a few hours to a day.

### Subsequent releases

1. Sign in to the developer dashboard.
2. Open the FARMIS app entry → **Update app**.
3. Upload the new `farmis.apk` (the evergreen URL `https://github.com/Farmis-App/download/releases/latest/download/farmis.apk` always points at the most recent release).
4. Add changelog text.
5. Submit.

## After the script runs (git commits)

The script prints exact commands; the gist is:

```bash
# In the app repo — record the version bump
cd ../farmis-all
git add app.json package.json android/app/build.gradle
git commit -m "chore: bump to v1.0.3"
git push

# In this repo — record the landing page update
cd -
git add index.html
git commit -m "release: v1.0.3"
git push
```

Verify the evergreen URL serves the new APK:

```
curl -sIL https://github.com/Farmis-App/download/releases/latest/download/farmis.apk | grep -E "HTTP/|location|content-length"
```

## Recovery

**Gradle build failed mid-run.** Version files in `farmis-all/` are already bumped. Either:

- Fix the build error and re-run with `--skip-build` after manually rebuilding, or
- Reset the version files and start over:
  ```
  cd ../farmis-all
  git checkout app.json package.json android/app/build.gradle
  ```

**Wrong version or bad release uploaded.** Delete and re-run:

```
gh release delete vX.Y.Z --repo Farmis-App/download --yes --cleanup-tag
```

**Released a debug-signed APK by mistake.** Verify with `apksigner verify --print-certs` (see step 4 above). If the cert CN is `androiddebugkey`, delete the release immediately, fix signing setup, and re-release. Don't push debug-signed builds to Play or Uptodown — Play rejects them outright and Uptodown listings become unmaintainable.

**Lost the keystore.** Catastrophic for Play if you didn't opt in to Play App Signing — you cannot publish updates. With Play App Signing you can request a key reset from Google support, but it requires reverifying ownership and may take weeks. For Uptodown and direct download you'd have to publish under a new app identity (different package name).

## Platform notes

The script uses BSD `sed -i ''` and `stat -f%z`, so it's macOS-only as written. To run on Linux, swap to `sed -i` (no empty string) and `stat -c%s`.

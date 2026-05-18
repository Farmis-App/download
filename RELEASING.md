# Releasing a new FARMIS APK

This page documents the release process for the FARMIS Android APK. The whole flow is automated by [`scripts/release-apk.sh`](scripts/release-apk.sh).

## Prerequisites

- `gh` CLI installed and authenticated with push access to `Farmis-App/download`
  ```
  gh auth status
  ```
- `python3` on PATH (used for safe JSON edits)
- Sibling checkout of the app repo at `../farmis-all` (i.e. both repos live side-by-side under the same parent directory)
- Android release signing configured locally — `./gradlew assembleRelease` must work without prompts (keystore + credentials in `farmis-all/android/gradle.properties` or `~/.gradle/gradle.properties`)

## Release a new version

From the root of this repo:

```
./scripts/release-apk.sh 1.0.2
```

Replace `1.0.2` with the new semver. **No leading `v`** — the script adds it for the tag.

What happens:

1. Sanity checks (gh auth, files present, tag not already used)
2. Bumps `versionName` in `farmis-all/app.json`, `package.json`, `android/app/build.gradle`
3. Increments `versionCode` by 1 in `build.gradle`
4. Runs `./gradlew assembleRelease` (this is the slow step — several minutes)
5. Uploads the APK to GitHub as `vX.Y.Z` on `Farmis-App/download`, renamed to `farmis.apk`
6. Updates `index.html`:
   - `<p class="version">Version …</p>` label
   - `… MB · Android only` size string
7. Prints the `git add` / `commit` / `push` commands for both repos

The script intentionally does **not** auto-commit or auto-push. Review the diffs first, then run the printed commands.

## Options

| Flag | Effect |
|---|---|
| `--notes "..."` | Inline release notes (default: auto-generated) |
| `--notes-file path` | Read release notes from a file |
| `--skip-build` | Skip the gradle build and use the existing `app-release.apk` |
| `-h`, `--help` | Show usage |

Examples:

```bash
# With custom inline notes
./scripts/release-apk.sh 1.0.2 --notes "Fixes offline crash; adds Tok Pisin translations."

# Notes from a file
./scripts/release-apk.sh 1.0.2 --notes-file ./release-notes-1.0.2.md

# Reuse an APK already built (e.g. by `farmis-all/android && ./gradlew assembleRelease`)
./scripts/release-apk.sh 1.0.2 --skip-build
```

## After the script runs

The script prints exact commands; the gist is:

```bash
# In the app repo — record the version bump
cd ../farmis-all
git add app.json package.json android/app/build.gradle
git commit -m "chore: bump to v1.0.2"
git push

# In this repo — record the landing page update
cd -
git add index.html
git commit -m "release: v1.0.2"
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

Then re-run the script (it refuses to overwrite an existing tag, so cleanup is required first).

**APK size in `index.html` looks wrong.** The script reads it from the file via `stat -f%z` and converts to MB (integer division). Edit manually if you want a different unit or rounding.

## Platform notes

The script uses BSD `sed -i ''` and `stat -f%z`, so it's macOS-only as written. To run on Linux, swap to `sed -i` (no empty string) and `stat -c%s`.

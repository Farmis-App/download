Cut a new FARMIS release using farmis-download/scripts/release-apk.sh.

Steps:
1. Read current version from farmis-all/package.json and list commits in farmis-all since the last v* tag.
2. Pick the next semver bump: patch for fixes/polish only, minor for new user-facing
   features or new modules, major for breaking changes. State your choice in one line.
3. Draft release notes to /tmp/farmis-<version>-notes.md, grouped by module
   (Recipes, Nutrition, HDDS, WASH, Crops, UI polish, etc.), user-facing language,
   no commit hashes.
4. Run: farmis-download/scripts/release-apk.sh <version> --notes-file /tmp/farmis-<version>-notes.md
   in the background (build takes ~10 min). Don't poll — wait for the completion notification.
5. After it finishes, verify:
   - APK uploaded to https://github.com/Farmis-App/download/releases/tag/v<version>
   - APK size < 100 MB (hard requirement; abort and report if exceeded)
   - app-info.tsx APP_VERSION, app.json, package.json, build.gradle versionName/versionCode
     all reflect the new version
6. Report the GH release URL, APK size, AAB path for Play Console, and ask before
   committing/pushing the version bumps in farmis-all and farmis-download.

Don't ask confirmation questions before step 4 — draft and execute. Only stop if
signing isn't configured, the working tree is dirty in an unexpected way, or the
build fails.

#!/usr/bin/env bash
# Release a new FARMIS APK to Farmis-App/download.
#
# Usage:
#   scripts/release-apk.sh <version> [--notes "..."] [--notes-file path] [--skip-build]
#
#   <version>     Semantic version, no leading "v" (e.g. 1.0.3)
#   --notes       Inline release notes (default: auto-generated)
#   --notes-file  Read release notes from a file
#   --skip-build  Skip gradle build (use existing app-release.apk + .aab)
#
# Performs, in order:
#   1. Sanity checks (gh auth, paths, tag uniqueness, release signing configured)
#   2. Bumps versionName in farmis-all/app.json, package.json, android build.gradle
#   3. Increments android versionCode
#   4. Builds APK (for Uptodown / direct download) and AAB (for Play) via gradlew
#   5. Uploads APK as v<version> release on Farmis-App/download
#   6. Updates index.html (version label + APK size)
#   7. Prints next-step commands (Play AAB, Uptodown APK, git push)

set -euo pipefail

REPO="Farmis-App/download"

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LANDING_REPO="$( cd "$SCRIPT_DIR/.." && pwd )"
APP_REPO="$( cd "$LANDING_REPO/../farmis-all" && pwd )"
ANDROID_DIR="$APP_REPO/android"
APK_OUT="$ANDROID_DIR/app/build/outputs/apk/release/app-release.apk"
AAB_OUT="$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
INDEX="$LANDING_REPO/index.html"

usage() {
  sed -n '2,12p' "$0" | sed 's|^# \{0,1\}||'
  exit "${1:-1}"
}

[[ $# -lt 1 ]] && usage
case "$1" in -h|--help) usage 0 ;; esac

VERSION="$1"; shift
SKIP_BUILD=0
NOTES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes)       NOTES="$2"; shift 2 ;;
    --notes-file)  NOTES="$(cat "$2")"; shift 2 ;;
    --skip-build)  SKIP_BUILD=1; shift ;;
    -h|--help)     usage 0 ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must be semver like 1.0.2 (no leading v)" >&2
  exit 1
fi

TAG="v$VERSION"

if [[ -z "$NOTES" ]]; then
  NOTES="FARMIS $TAG — Android APK release.

Install instructions: https://farmis-app.github.io/download/

Built from app version $VERSION."
fi

# --- Sanity checks ---
command -v gh   >/dev/null || { echo "Error: gh CLI not installed" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Error: python3 required" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Error: gh not authenticated" >&2; exit 1; }

[[ -f "$APP_REPO/app.json" ]]   || { echo "Error: $APP_REPO/app.json not found" >&2; exit 1; }
[[ -f "$APP_REPO/package.json" ]] || { echo "Error: $APP_REPO/package.json not found" >&2; exit 1; }
[[ -f "$ANDROID_DIR/app/build.gradle" ]] || { echo "Error: $ANDROID_DIR/app/build.gradle not found" >&2; exit 1; }
[[ -f "$INDEX" ]] || { echo "Error: $INDEX not found" >&2; exit 1; }

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Error: release $TAG already exists on $REPO" >&2
  exit 1
fi

echo "→ Preparing FARMIS $TAG"
echo "  App repo:     $APP_REPO"
echo "  Landing repo: $LANDING_REPO"

# --- Signing pre-flight (run BEFORE version bumps so a fail doesn't dirty the repo) ---
GRADLE_PROPS="${HOME}/.gradle/gradle.properties"
SIGNING_OK=0
if [[ -n "${FARMIS_UPLOAD_STORE_FILE:-}" ]]; then
  SIGNING_OK=1
elif [[ -f "$GRADLE_PROPS" ]] && grep -qE '^[[:space:]]*FARMIS_UPLOAD_STORE_FILE=' "$GRADLE_PROPS"; then
  SIGNING_OK=1
fi
if [[ $SIGNING_OK -eq 0 ]]; then
  echo "Error: release signing not configured." >&2
  echo "  Set FARMIS_UPLOAD_STORE_FILE (and the matching password/alias/key vars)" >&2
  echo "  in $GRADLE_PROPS or your shell env. See RELEASING.md → 'One-time signing setup'." >&2
  exit 1
fi

# --- Bump versions ---
CURRENT_VERSION_CODE=$(grep -E '^\s*versionCode\s+[0-9]+' "$ANDROID_DIR/app/build.gradle" | awk '{print $2}' | head -1)
NEW_VERSION_CODE=$((CURRENT_VERSION_CODE + 1))

echo "→ Bumping versionName → $VERSION, versionCode $CURRENT_VERSION_CODE → $NEW_VERSION_CODE"

# build.gradle (macOS BSD sed)
sed -i '' -E "s/(versionName[[:space:]]+)\"[^\"]+\"/\1\"$VERSION\"/" "$ANDROID_DIR/app/build.gradle"
sed -i '' -E "s/(versionCode[[:space:]]+)[0-9]+/\1$NEW_VERSION_CODE/" "$ANDROID_DIR/app/build.gradle"

# app.json + package.json (JSON-safe edits via python)
python3 - "$APP_REPO/app.json" "$VERSION" <<'PYEOF'
import json, sys
path, version = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
if isinstance(data.get("expo"), dict):
    data["expo"]["version"] = version
elif "version" in data:
    data["version"] = version
else:
    raise SystemExit(f"No version key found in {path}")
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

python3 - "$APP_REPO/package.json" "$VERSION" <<'PYEOF'
import json, sys
path, version = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
data["version"] = version
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

# --- Build APK + AAB ---
# SENTRY_DISABLE_AUTO_UPLOAD=true skips source-map upload (no auth token configured).
# To enable Sentry uploads, set SENTRY_AUTH_TOKEN in your env and unset this var.
if [[ $SKIP_BUILD -eq 0 ]]; then
  echo "→ Building release APK + AAB (gradlew assembleRelease bundleRelease) — can take several minutes..."
  ( cd "$ANDROID_DIR" && SENTRY_DISABLE_AUTO_UPLOAD=true ./gradlew assembleRelease bundleRelease )
else
  echo "→ Skipping build (--skip-build); using existing artifacts"
fi

[[ -f "$APK_OUT" ]] || { echo "Error: $APK_OUT not found" >&2; exit 1; }
[[ -f "$AAB_OUT" ]] || { echo "Error: $AAB_OUT not found" >&2; exit 1; }

TMP_APK="/tmp/farmis.apk"
cp "$APK_OUT" "$TMP_APK"
APK_SIZE_MB=$(( $(stat -f%z "$TMP_APK") / 1024 / 1024 ))
AAB_SIZE_MB=$(( $(stat -f%z "$AAB_OUT") / 1024 / 1024 ))
echo "→ APK ready: $TMP_APK (${APK_SIZE_MB} MB)"
echo "→ AAB ready: $AAB_OUT (${AAB_SIZE_MB} MB) — upload manually to Google Play Console"

# --- Publish release ---
echo "→ Creating release $TAG on $REPO"
gh release create "$TAG" "$TMP_APK" \
  --repo "$REPO" \
  --title "FARMIS $TAG" \
  --notes "$NOTES"

# --- Update landing page ---
echo "→ Updating $INDEX (version label + APK size)"
sed -i '' -E "s|<p class=\"version\">Version [0-9]+\.[0-9]+\.[0-9]+</p>|<p class=\"version\">Version $VERSION</p>|" "$INDEX"
sed -i '' -E "s|>[0-9]+ MB &middot; Android only<|>${APK_SIZE_MB} MB \&middot; Android only<|" "$INDEX"

rm -f "$TMP_APK"

cat <<EOF

✓ Release $TAG published
  https://github.com/$REPO/releases/tag/$TAG
  Evergreen URL: https://github.com/$REPO/releases/latest/download/farmis.apk

Next steps for store distribution:

  • Google Play Console — upload the AAB:
      $AAB_OUT
    (Internal testing → closed testing → production. See RELEASING.md.)

  • Uptodown — upload the APK:
      $APK_OUT  (or the GitHub release asset)
    https://en.uptodown.com/android/developers

Commit & push the version bumps and landing page changes:

  # app repo
  git -C "$APP_REPO" add app.json package.json android/app/build.gradle
  git -C "$APP_REPO" commit -m "chore: bump to v$VERSION"
  git -C "$APP_REPO" push

  # landing repo
  git -C "$LANDING_REPO" add index.html
  git -C "$LANDING_REPO" commit -m "release: v$VERSION"
  git -C "$LANDING_REPO" push
EOF

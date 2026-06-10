#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Consoled release helper.
#
#   ./scripts/release.sh 1.1.3
#
# What it DOES automatically (all local, all reversible — no network, no git):
#   1. Bumps MARKETING_VERSION to the version you pass, and increments
#      CURRENT_PROJECT_VERSION (the build number Sparkle compares to detect updates).
#   2. Clean Release build.
#   3. Packages dist/Consoled-<ver>.dmg   (human download)
#      and       dist/Consoled-<ver>.zip  (Sparkle auto-update artifact).
#   4. If Sparkle is set up: EdDSA-signs the .zip and prepends a new <item> to
#      appcast.xml (the update feed). If not, it skips this with a notice.
#
# What it does NOT do (it PRINTS these for you to run, so you stay in control):
#   - git add/commit/tag/push
#   - gh release create  (publishing to GitHub)
#
# Requires: Xcode CLT. For auto-updates also: Sparkle integrated + `gh` CLI.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── config ──────────────────────────────────────────────────────────────────
REPO_SLUG="warrun/consoled"           # GitHub owner/repo (used in appcast URLs)
PROJECT="Consoled.xcodeproj"
SCHEME="Consoled"
APP="Consoled"                         # product name (Consoled.app)
PBXPROJ="$PROJECT/project.pbxproj"
APPCAST="appcast.xml"                  # tracked in the repo root
# ──────────────────────────────────────────────────────────────────────────────

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "usage: $0 <marketing-version>   e.g. $0 1.1.3" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "▸ Consoled release $VERSION"

# 1. Version bumps ─────────────────────────────────────────────────────────────
# Marketing (human) version → what you passed.
sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION;/" "$PBXPROJ"
# Build number (Sparkle uses this to decide "newer") → current + 1.
CUR_BUILD="$(grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed 's/[^0-9]//g')"
NEW_BUILD=$(( CUR_BUILD + 1 ))
sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD;/" "$PBXPROJ"
# Keep the copyright year current (shown in the About panel via NSHumanReadableCopyright).
YEAR="$(date +%Y)"
sed -i '' "s/INFOPLIST_KEY_NSHumanReadableCopyright = .*/INFOPLIST_KEY_NSHumanReadableCopyright = \"Copyright © $YEAR Warrun Lewis\";/" "$PBXPROJ"
echo "  version $VERSION  ·  build $NEW_BUILD  ·  © $YEAR"

# 2. Clean Release build ───────────────────────────────────────────────────────
rm -rf build dist && mkdir -p dist
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -derivedDataPath build CODE_SIGN_IDENTITY="-" build >/dev/null
APP_PATH="build/Build/Products/Release/$APP.app"
BUILT_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
[[ "$BUILT_VER" == "$VERSION" ]] || { echo "version mismatch: built $BUILT_VER" >&2; exit 1; }
echo "  built $APP.app ($BUILT_VER, build $NEW_BUILD)"

# 3. DMG (human) + ZIP (updater) ───────────────────────────────────────────────
mkdir -p dist/dmg && cp -R "$APP_PATH" dist/dmg/ && ln -s /Applications dist/dmg/Applications
for v in /Volumes/Consoled*; do hdiutil detach "$v" >/dev/null 2>&1 || true; done
hdiutil create -volname "Consoled $VERSION" -srcfolder dist/dmg -ov -format UDZO \
    "dist/$APP-$VERSION.dmg" >/dev/null
rm -rf dist/dmg
ditto -c -k --keepParent "$APP_PATH" "dist/$APP-$VERSION.zip"
ZIP_LEN="$(stat -f%z "dist/$APP-$VERSION.zip")"
echo "  packaged dist/$APP-$VERSION.dmg  +  dist/$APP-$VERSION.zip ($ZIP_LEN bytes)"

# 4. Sparkle: sign the zip + update the appcast (skipped if not set up) ─────────
SIGN_UPDATE="$(command -v sign_update || true)"
if [[ -z "$SIGN_UPDATE" ]]; then
    SIGN_UPDATE="$(/usr/bin/find build/SourcePackages/artifacts -name sign_update 2>/dev/null | head -1 || true)"
fi
if [[ -n "$SIGN_UPDATE" && -f "$APPCAST" ]]; then
    SIG_LINE="$("$SIGN_UPDATE" "dist/$APP-$VERSION.zip")"   # e.g. sparkle:edSignature="…" length="…"
    ITEM="$(mktemp)"
    cat > "$ITEM" <<EOF
        <item>
            <title>Consoled $VERSION</title>
            <sparkle:version>$NEW_BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:releaseNotesLink>https://github.com/$REPO_SLUG/releases/tag/v$VERSION</sparkle:releaseNotesLink>
            <pubDate>$(date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
            <enclosure url="https://github.com/$REPO_SLUG/releases/download/v$VERSION/$APP-$VERSION.zip" $SIG_LINE type="application/octet-stream"/>
        </item>
EOF
    # Insert the new item right after the marker so newest is first.
    sed -i '' "/<!-- INSERT NEW RELEASES BELOW -->/r $ITEM" "$APPCAST"
    rm -f "$ITEM"
    echo "  signed + added <item> to $APPCAST"
    SPARKLE_OK=1
else
    echo "  ⚠ Sparkle not set up (no sign_update / no $APPCAST) — skipped appcast."
    echo "    See RELEASING.md → One-time setup. DMG + git steps below still apply."
    SPARKLE_OK=0
fi

# 5. The commands for YOU to run (review, then paste) ───────────────────────────
cat <<EOF

──────────────── run these to publish ────────────────
git add -A
git commit -m "Consoled $VERSION"
git tag -a "v$VERSION" -m "Consoled $VERSION"
git push origin main
git push origin "v$VERSION"
gh release create "v$VERSION" \\
    "dist/$APP-$VERSION.dmg" \\$( [[ "$SPARKLE_OK" == 1 ]] && printf '\n    "dist/%s-%s.zip" \\' "$APP" "$VERSION" )
    --title "Consoled $VERSION" --notes "See changelog. (Unsigned build: first launch needs right-click → Open.)"
───────────────────────────────────────────────────────
EOF
[[ "$SPARKLE_OK" == 1 ]] && echo "appcast.xml is committed above, so raw.githubusercontent serves the new feed."

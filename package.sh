#!/bin/bash
# Builds a release disk image for people who just want to download the app:
#   ./package.sh   ->   build/NotchIsland.dmg   (Apple Silicon + Intel, music support included)
# Upload build/NotchIsland.dmg to a GitHub release; install.sh downloads it from the latest release.
set -euo pipefail
cd "$(dirname "$0")"

# Music support is part of the release, so fetch the adapter if it is not there yet
if [[ ! -d Vendor/mediaremote-adapter/src ]]; then
    git clone --depth 1 https://github.com/ungive/mediaremote-adapter.git Vendor/mediaremote-adapter
fi

UNIVERSAL=1 ./build.sh

APP=build/NotchIsland.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
lipo "$APP/Contents/MacOS/NotchIsland" -verify_arch arm64 x86_64
codesign --verify --deep --strict "$APP"

# Disk image: the app next to a shortcut to /Applications, so installing is a single drag
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/notchisland-dmg.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto --norsrc --noextattr "$APP" "$STAGE/NotchIsland.app"
ln -s /Applications "$STAGE/Applications"

DMG=build/NotchIsland.dmg
rm -f "$DMG"
hdiutil create -volname "NotchIsland $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
echo "Created $DMG (version $VERSION, $(du -h "$DMG" | cut -f1 | xargs))"

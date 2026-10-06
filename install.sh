#!/bin/bash
# One-line install of the latest NotchIsland release:
#   curl -fsSL https://raw.githubusercontent.com/silky-itt/NotchIsland/main/install.sh | bash
# Downloads NotchIsland.dmg from the latest GitHub release, copies the app to /Applications and starts it.
set -euo pipefail

URL="${NOTCHISLAND_DMG_URL:-https://github.com/silky-itt/NotchIsland/releases/latest/download/NotchIsland.dmg}"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/notchisland-install.XXXXXX")
MOUNT="$TMP/mount"
cleanup() {
    hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

if [[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]]; then
    echo "NotchIsland needs macOS 14 (Sonoma) or later." >&2
    exit 1
fi

echo "Downloading NotchIsland..."
curl -fL --progress-bar "$URL" -o "$TMP/NotchIsland.dmg"

mkdir -p "$MOUNT"
hdiutil attach "$TMP/NotchIsland.dmg" -mountpoint "$MOUNT" -nobrowse -quiet

pkill -x NotchIsland 2>/dev/null && sleep 0.5 || true
rm -rf /Applications/NotchIsland.app
ditto "$MOUNT/NotchIsland.app" /Applications/NotchIsland.app
# Downloaded with curl, so there is normally no quarantine flag; clear it anyway so macOS opens the app directly
xattr -dr com.apple.quarantine /Applications/NotchIsland.app 2>/dev/null || true

open /Applications/NotchIsland.app
echo "NotchIsland is installed and running. Right-click the notch for Settings."

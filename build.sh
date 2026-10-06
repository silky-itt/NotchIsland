#!/bin/bash
# Builds a Release version and packages it as build/NotchIsland.app
#   ./build.sh           build
#   ./build.sh install   build + copy to /Applications + relaunch (needed for "Launch at Login")
#   UNIVERSAL=1 ./build.sh   Apple Silicon + Intel binary (used by package.sh for releases)
set -euo pipefail
cd "$(dirname "$0")"

if [[ "${UNIVERSAL:-}" == 1 ]]; then
    ARCHS=(arm64 x86_64)
    swift build -c release --arch arm64 --arch x86_64
    PRODUCT=.build/apple/Products/Release/NotchIsland
else
    ARCHS=(arm64)
    swift build -c release
    PRODUCT=.build/release/NotchIsland
fi

# Assemble and sign in a temp dir outside ~/Desktop: iCloud/File Provider keeps re-adding extended
# attributes (FinderInfo...) to folders there, and codesign refuses to sign a bundle that has them.
OUT=build/NotchIsland.app
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/notchisland.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/NotchIsland.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$PRODUCT" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"   # regenerate with: swift Tools/make-icon.swift

# --- Music: mediaremote-adapter (optional) ---
# If the source is in Vendor/mediaremote-adapter, build the framework and bundle it into the app.
# Without it the app still runs; only the music block says the adapter is missing.
ADAPTER_SRC=Vendor/mediaremote-adapter
if [[ -d "$ADAPTER_SRC/src" ]]; then
    # Proper versioned framework layout, so the bundle can be code-signed and verified
    FW=.build/adapter/MediaRemoteAdapter.framework
    BIN="$FW/Versions/A/MediaRemoteAdapter"
    # Rebuild when the sources changed or the binary lacks an architecture we need
    if [[ ! -f "$BIN" || -n "$(find "$ADAPTER_SRC/src" -newer "$BIN" -name '*.m' | head -1)" ]] \
        || ! lipo "$BIN" -verify_arch "${ARCHS[@]}" 2>/dev/null; then
        echo "Building MediaRemoteAdapter.framework (${ARCHS[*]})..."
        ARCH_FLAGS=()
        for arch in "${ARCHS[@]}"; do ARCH_FLAGS+=(-arch "$arch"); done
        rm -rf "$FW"
        mkdir -p "$FW/Versions/A/Resources"
        clang -dynamiclib -fobjc-arc -fvisibility=default -O2 "${ARCH_FLAGS[@]}" -mmacosx-version-min=14.0 \
            -I"$ADAPTER_SRC/include" -I"$ADAPTER_SRC/src" \
            "$ADAPTER_SRC"/src/adapter/*.m "$ADAPTER_SRC"/src/private/MediaRemote.m "$ADAPTER_SRC"/src/utility/*.m \
            -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
            -install_name @rpath/MediaRemoteAdapter.framework/MediaRemoteAdapter \
            -o "$BIN"
        cat > "$FW/Versions/A/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
    <key>CFBundleName</key><string>MediaRemoteAdapter</string>
    <key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
    <key>CFBundlePackageType</key><string>FMWK</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>0.1.0</string>
</dict></plist>
PLIST
        ln -s A "$FW/Versions/Current"
        ln -s Versions/Current/MediaRemoteAdapter "$FW/MediaRemoteAdapter"
        ln -s Versions/Current/Resources "$FW/Resources"
    fi
    ditto "$FW" "$APP/Contents/Frameworks/MediaRemoteAdapter.framework"
    cp "$ADAPTER_SRC/bin/mediaremote-adapter.pl" "$APP/Contents/Resources/"
else
    echo "⚠️  $ADAPTER_SRC not found -> skipping music support"
fi

# --- Code signing ---
xattr -cr "$APP"
# Prefer the Apple Development certificate so permissions (Calendar...) are not asked again after every build.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')
IDENTITY=${IDENTITY:--}
if [[ -d "$APP/Contents/Frameworks/MediaRemoteAdapter.framework" ]]; then
    codesign --force --sign "$IDENTITY" "$APP/Contents/Frameworks/MediaRemoteAdapter.framework"
fi
codesign --force --sign "$IDENTITY" "$APP"
echo "Signed with: $IDENTITY"

# Keep a copy in build/ for convenience (without extended attributes)
rm -rf "$OUT"
mkdir -p build
ditto --norsrc --noextattr "$APP" "$OUT"
echo "Created $OUT"

if [[ "${1:-}" == "install" ]]; then
    pkill -x NotchIsland || true
    sleep 0.5
    rm -rf /Applications/NotchIsland.app
    ditto --norsrc --noextattr "$APP" /Applications/NotchIsland.app
    open /Applications/NotchIsland.app
    echo "Installed to /Applications and relaunched"
fi

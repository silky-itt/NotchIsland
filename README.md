# NotchIsland

A "Dynamic Island" for the notch of a MacBook, written in SwiftUI + AppKit. It sits over the notch, expands when you hover it, and stays light on memory (about 14 MB, plus about 6.5 MB for the music helper process).

## Features

- **Expands on hover** (delay adjustable), click, two-finger swipe, or when you drag a file onto it
- **Now playing**: Spotify, YouTube and other browser audio, with artwork, controls and a progress bar
- **Volume and brightness HUD** beside the notch, with percentage (optionally hides the macOS bars)
- **Bluetooth** connect / disconnect, **charging** indicator
- **Calendar**: today's remaining events, or the next one within 7 days
- **Shelf**: drop files and images (from Finder, browsers, screenshots or the clipboard); click it to see everything on it
- **Pet cat** next to the notch that dances to music
- **Settings** window (right-click the notch), optional transparent collapsed notch

## Requirements

macOS 14 or later, Xcode command line tools / Swift 5.9+.

## Build

```sh
# Music support uses mediaremote-adapter (BSD-3-Clause), which is not included here:
git clone --depth 1 https://github.com/ungive/mediaremote-adapter.git Vendor/mediaremote-adapter

./build.sh            # builds build/NotchIsland.app
./build.sh install    # also copies it to /Applications and relaunches (needed for "Launch at Login")
```

Without `Vendor/mediaremote-adapter` the app still works; only the music block is unavailable.
`build.sh` signs with an Apple Development certificate if you have one, otherwise ad hoc.

Other scripts: `./measure.sh` (RAM / CPU against a budget), `./dev.sh` (rebuild and relaunch on save), `swift Tools/make-icon.swift` (regenerates the app icon).

## Notes

- Hiding the macOS volume/brightness bars is optional and off by default; it needs Accessibility permission.
- The brightness HUD uses a private macOS framework (DisplayServices). If a macOS update removes it, only that HUD is lost.
- Memory notes: EventKit is only touched while the island is open, and cover art is decoded straight from the raw bytes to avoid large temporary copies.

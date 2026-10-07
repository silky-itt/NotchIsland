# NotchIsland

A "Dynamic Island" for the notch of your MacBook, written in SwiftUI + AppKit. It sits over the notch, expands when you hover it, and stays light on memory (about 14 MB, plus about 6.5 MB for the music helper process).

## Features

- **Expands on hover** (delay adjustable), click, two-finger swipe, or when you drag a file onto it
- **Now playing**: Spotify, YouTube and other browser audio, with artwork, controls and a progress bar
- **Volume and brightness HUD** beside the notch, with percentage (can optionally hide the macOS bars)
- **Bluetooth** connect / disconnect and a **charging** indicator
- **Calendar**: today's remaining events, or the next one within 7 days
- **Shelf**: drop files and images (from Finder, browsers, screenshots or the clipboard); click it to see everything on it
- **Pet** next to the notch (cat, dog, bunny, panda, frog, fox, penguin, chick, ghost, robot or slime) that dances to music
- **Stays put** under the real notch while you swipe between desktops
- **Settings** window, plus an optional transparent collapsed notch and a thin outline around it

## Download (easiest)

> **Not available yet.** No ready-made version has been published so far. Until one appears under [Releases](https://github.com/silky-itt/NotchIsland/releases), use [Build it yourself](#build-it-yourself) below.

Needs **macOS 14 (Sonoma) or later**, on Apple Silicon or Intel. Music support is included.

**Option A: one line in Terminal (recommended).** Open **Terminal** (press `⌘ Space`, type "Terminal", press Enter), paste this and press Enter:

```sh
curl -fsSL https://raw.githubusercontent.com/silky-itt/NotchIsland/main/install.sh | bash
```

It downloads the latest version, puts it in Applications and starts it. Run the same line again to update.

**Option B: download the disk image.**

1. Download `NotchIsland.dmg` from the [latest release](https://github.com/silky-itt/NotchIsland/releases/latest).
2. Open it and drag **NotchIsland** onto **Applications**.
3. Open NotchIsland from Applications. The first time, macOS says it cannot verify the developer (the app is free and not registered with Apple). Click **Done**, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**. You only do this once.

The island appears at the notch and the app starts by itself when you log in. Right-click the notch for **Settings…**.

## Build it yourself

If you prefer, you can build the app from the source code on your own Mac. It takes about five minutes and no programming knowledge.

**You need:** a Mac running **macOS 14 (Sonoma) or later**. A MacBook with a notch looks best; on other Macs a notch-sized island is drawn at the top centre of the screen.

### 1. Install the tools (once)

Open **Terminal** (press `⌘ Space`, type "Terminal", press Enter) and run:

```sh
xcode-select --install
```

A window appears; click **Install** and wait until it finishes. (If it says the tools are already installed, continue.) This gives you `git` and the Swift compiler.

### 2. Download the code

```sh
git clone https://github.com/silky-itt/NotchIsland.git
cd NotchIsland
```

### 3. Add music support (optional but recommended)

Showing what is playing uses a small open-source helper, [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3-Clause), which is not included in this repository:

```sh
git clone --depth 1 https://github.com/ungive/mediaremote-adapter.git Vendor/mediaremote-adapter
```

Skip this step and everything still works, except the music block.

### 4. Build and install

```sh
./build.sh install
```

This builds the app, copies it to `/Applications/NotchIsland.app` and starts it. You will see the island appear at the notch. (The first build downloads nothing and may take a minute.)

> If macOS asks to allow **Calendar** or **Bluetooth**, click Allow: they are only used to show your next event and Bluetooth connections.

### 5. Using it

| What you want | What to do |
|---|---|
| Open the island | Hover the notch for a moment (about 0.3 s), click it, or swipe down with two fingers on it |
| Close it | Move the pointer away, or swipe up with two fingers |
| Open **Settings** | **Right-click the notch** (the black body of the notch itself) and choose **Settings…** |
| Quit the app | Right-click the notch and choose **Quit NotchIsland** |
| Put files on the shelf | Drag files or images onto the notch, or press the paste button on the shelf |
| See everything on the shelf | Click the shelf area inside the open island |
| Control music | Use the buttons in the open island; click the app name to jump to the player |

In **Settings** you can change the hover delay, turn individual panels and indicators on or off, pick or hide the pet, switch to a transparent notch, and choose whether the app starts when you log in.

### Updating

```sh
cd NotchIsland
git pull
./build.sh install
```

### Uninstalling

1. Right-click the notch and choose **Quit NotchIsland**.
2. Delete `/Applications/NotchIsland.app`.
3. Optional clean-up:
   ```sh
   defaults delete com.thanhnam.NotchIsland
   rm -rf ~/Library/Application\ Support/NotchIsland
   ```
4. If you enabled "Launch at login", remove NotchIsland from **System Settings → General → Login Items**.

### Troubleshooting

- **`git: command not found` or `swift: command not found`**: repeat step 1.
- **The music block says "mediaremote-adapter is not bundled"**: do step 3, then run `./build.sh install` again.
- **Nothing is shown when music plays**: macOS only exposes what a player publishes; most players and browser tabs (YouTube, Spotify Web) do. macOS cannot tell which browser tab is playing, so clicking the app name only opens the browser.
- **macOS asks for permissions again after every rebuild**: without an Apple Development certificate the app is signed "ad hoc", which macOS treats as a new app each time. Signing with your own Apple ID in Xcode avoids it.
- **I cannot click a menu bar item next to the notch**: the island only reacts over the notch body; the areas beside it let clicks through. If something still gets in the way, please open an issue.
- **The macOS volume/brightness bars appear next to the island's indicator**: that is the default. You can turn on hiding them in Settings; it needs **Accessibility** permission.

## For developers

```sh
./build.sh            # builds build/NotchIsland.app
./build.sh install    # also copies it to /Applications and relaunches (needed for "Launch at Login")
./package.sh          # release disk image build/NotchIsland.dmg (Apple Silicon + Intel, music included)
./measure.sh          # RAM / CPU against a budget (add --quick to skip the hover leak check)
./dev.sh              # rebuild and relaunch whenever a .swift file is saved
swift Tools/make-icon.swift   # regenerates the app icon
```

- Your own pets: put JSON files in `~/Library/Application Support/NotchIsland/Pets` (Settings → Open Folder), then reopen the app. Format: `{"title": "…", "base": [15 to 48 rows, each as long as there are rows], "blink": {"5": "row"}, "happy": {"5": "row"}, "colors": {"O": "#F2A65A"}}`; see `PetSprites.swift` for the grid rules and the shared colours. They stay on your Mac and are never part of a release.
- Publishing a release: bump the version in `Resources/Info.plist`, run `./package.sh`, then `gh release create v<version> build/NotchIsland.dmg`. Keep the asset name `NotchIsland.dmg`: `install.sh` and the download link use it.
- Open `Package.swift` in Xcode to use SwiftUI previews (`Sources/NotchIsland/Expanded/Previews.swift`).
- The brightness HUD uses a private macOS framework (DisplayServices). If a macOS update removes it, only that HUD is lost.
- Hiding the macOS volume/brightness bars is optional and off by default; it works by intercepting those keys with an event tap.
- Memory: EventKit is only touched while the island is open, and cover art is decoded straight from the raw bytes to avoid large temporary copies.

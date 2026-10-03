#!/bin/bash
# Design loop: save a .swift file -> automatically builds debug and relaunches the app (a few seconds).
# Stop with Ctrl-C. Not true hot reload: the app restarts every time.
set -uo pipefail
cd "$(dirname "$0")"

snapshot() { find Sources Resources -type f \( -name '*.swift' -o -name '*.plist' \) -exec stat -f '%m %N' {} + | sort | md5; }

run() {
    pkill -x NotchIsland 2>/dev/null; sleep 0.3
    echo "▶︎ Build..."
    if swift build 2>&1 | grep -E "error:|Compiling|Build complete" | tail -5 | grep -q "Build complete"; then
        .build/debug/NotchIsland &
        echo "✅ Running (debug). Right-click the notch -> Demo (debug) to try the HUDs."
    else
        swift build 2>&1 | grep -E "error:" | head -10
        echo "❌ Build failed — fix it and save again, the build will resume."
    fi
}

trap 'pkill -x NotchIsland 2>/dev/null; exit 0' INT TERM
last=""
while true; do
    current=$(snapshot)
    if [[ "$current" != "$last" ]]; then last=$current; run; fi
    sleep 1
done

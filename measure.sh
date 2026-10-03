#!/bin/bash
# Measures NotchIsland RAM/CPU and warns if it exceeds the budget.
#   ./measure.sh            measure at idle + a hover step to check for leaks
#   ./measure.sh --quick    idle measurement only
#   BUDGET_MB=40 ./measure.sh   change the RAM budget (default 50 MB)
set -uo pipefail
cd "$(dirname "$0")"

BUDGET_MB=${BUDGET_MB:-50}
LEAK_THRESHOLD_MB=2   # RAM growth above this after hovering -> suspect a leak
CPU_IDLE_MAX=1.0      # max acceptable CPU % at idle
QUICK=false
[[ "${1:-}" == "--quick" ]] && QUICK=true

APP=build/NotchIsland.app
warnings=0

# Gets the value (MB) of a line in `footprint` output, e.g. "phys_footprint: 11 MB"
footprint_mb() {
    local pid=${2:-$PID}
    footprint "$pid" 2>/dev/null | awk -v key="$1:" '
        $1 == key {
            v = $2; u = $3
            if (u == "KB") v = v / 1024
            else if (u == "GB") v = v * 1024
            else if (u == "B") v = v / 1048576
            printf "%.1f", v; exit
        }'
}

# Average CPU over a few seconds (skips the first top sample, which is always 0)
cpu_idle() {
    top -l 4 -s 1 -pid "$PID" -stats cpu | grep -E '^[0-9.]+$' | tail -3 \
        | awk '{ s += $1 } END { printf "%.1f", (NR ? s / NR : 0) }'
}

over() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'; }

# --- Make sure the app is running ---
# Prefer the packaged app (Release) over a Debug build running from Xcode
PID=$(pgrep -f "NotchIsland.app/Contents/MacOS/NotchIsland" | head -1)
[[ -z "$PID" ]] && PID=$(pgrep -x NotchIsland | head -1)
if [[ -z "$PID" ]]; then
    [[ -d "$APP" ]] || ./build.sh || exit 1
    echo "App is not running -> opening $APP..."
    open "$APP"; sleep 3
    PID=$(pgrep -x NotchIsland | head -1)
    [[ -z "$PID" ]] && { echo "❌ Could not open the app"; exit 1; }
fi
echo "NotchIsland PID $PID — RAM budget: ${BUDGET_MB} MB"
echo

# --- Step 1: idle ---
echo "⏳ Measuring at idle (about 4 seconds, do not hover the notch)..."
idle_mb=$(footprint_mb phys_footprint)
cpu=$(cpu_idle)
echo "   RAM:  ${idle_mb} MB"
# The music process (perl + mediaremote-adapter) is a child process, counted separately
ADAPTER_PID=$(pgrep -P "$PID" perl | head -1)
if [[ -n "$ADAPTER_PID" ]]; then
    adapter_mb=$(footprint_mb phys_footprint "$ADAPTER_PID")
    idle_mb=$(awk -v a="$idle_mb" -v b="$adapter_mb" 'BEGIN { printf "%.1f", a + b }')
    echo "   Music process RAM: ${adapter_mb} MB  → total: ${idle_mb} MB"
fi
echo "   CPU:  ${cpu}%"

if over "$idle_mb" "$BUDGET_MB"; then
    echo "   ⚠️  RAM exceeds the ${BUDGET_MB} MB budget"; warnings=$((warnings + 1))
fi
if over "$cpu" "$CPU_IDLE_MAX"; then
    echo "   ⚠️  Idle CPU > ${CPU_IDLE_MAX}% — a timer or animation may be running in the background"
    warnings=$((warnings + 1))
fi

# --- Step 2: hover to check for leaks ---
if ! $QUICK && [[ -t 0 ]]; then
    echo
    echo "👉 Move the pointer in and out of the notch about 20 times, then move it away and press Enter."
    read -r
    sleep 2   # wait for the collapse animation to finish
    after_mb=$(footprint_mb phys_footprint)
    [[ -n "${adapter_mb:-}" ]] && after_mb=$(awk -v a="$after_mb" -v b="$(footprint_mb phys_footprint "$ADAPTER_PID")" 'BEGIN { printf "%.1f", a + b }')
    delta=$(awk -v a="$after_mb" -v b="$idle_mb" 'BEGIN { printf "%.1f", a - b }')
    echo "   RAM after hovering: ${after_mb} MB (change: ${delta} MB)"
    if over "$delta" "$LEAK_THRESHOLD_MB"; then
        echo "   ⚠️  RAM grew > ${LEAK_THRESHOLD_MB} MB — possible leak."
        echo "      Run it once or twice more; if it keeps growing, check with Instruments → Leaks."
        warnings=$((warnings + 1))
    fi
fi

peak_mb=$(footprint_mb phys_footprint_peak)
echo
echo "   Peak RAM since launch: ${peak_mb} MB"
if over "$peak_mb" "$BUDGET_MB"; then
    echo "   ⚠️  Peak RAM exceeds the budget"; warnings=$((warnings + 1))
fi

echo
if (( warnings == 0 )); then
    echo "✅ OK — within budget"
else
    echo "❌ $warnings warning(s)"
    exit 1
fi

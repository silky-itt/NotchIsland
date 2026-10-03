import SwiftUI

/// Icon + battery %, shown in the top-right corner when expanded.
struct BatteryIndicator: View {
    @Environment(BatteryMonitor.self) private var battery

    var body: some View {
        if battery.hasBattery {
            HStack(spacing: 4) {
                Text("\(battery.level)%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                Image(systemName: symbol)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(tint, .white.opacity(0.9))
                    .font(.system(size: 14))
            }
            .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var symbol: String {
        if battery.isCharging { return "battery.100percent.bolt" }
        switch battery.level {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var tint: Color {
        if battery.isCharging || battery.isPluggedIn { return .green }
        return battery.level <= 20 ? .red : .white
    }
}

/// Shown on both sides of the notch for a few seconds when charging starts.
struct ChargingActivity {
    struct Leading: View {
        var body: some View {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        }
    }

    struct Trailing: View {
        @Environment(BatteryMonitor.self) private var battery

        var body: some View {
            Text("\(battery.level)%")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.green)
        }
    }
}

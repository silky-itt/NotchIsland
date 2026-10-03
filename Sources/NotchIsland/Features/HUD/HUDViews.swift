import SwiftUI

/// Content on both sides of the notch for each kind of HUD event.
enum HUDActivity {
    /// Width of each side (pt) per kind
    static func sideWidth(for event: HUDModel.Event) -> CGFloat {
        if case .device = event.kind { return 96 }
        return 52   // volume / brightness: just an icon and a number
    }

    struct Leading: View {
        let event: HUDModel.Event

        var body: some View {
            Image(systemName: symbol, variableValue: event.value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }

        private var symbol: String {
            switch event.kind {
            case .volume(let muted): return muted || event.value == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill"
            case .brightness: return "sun.max.fill"
            case .device(let name, _): return name.contains("AirPods") ? "airpods" : "headphones"
            }
        }
    }

    struct Trailing: View {
        let event: HUDModel.Event
        @AppStorage(Settings.Key.showPercentage) private var showPercentage = Settings.Default.showPercentage

        var body: some View {
            switch event.kind {
            case .volume(let muted):
                level(value: muted ? 0 : event.value, label: muted ? "Muted" : nil)
            case .brightness:
                level(value: event.value, label: nil)
            case .device(let name, let connected):
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: connected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(connected ? .green : .secondary)
                        .font(.system(size: 11))
                }
            }
        }
    }
}

extension HUDActivity.Trailing {
    /// Compact: only the number (the icon on the other side already shows the level).
    /// With the percentage turned off, a small level bar is shown instead.
    @ViewBuilder
    fileprivate func level(value: Double, label: String?) -> some View {
        if showPercentage {
            Text(label ?? "\(Int((value * 100).rounded()))%")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
        } else {
            LevelBar(value: value)
        }
    }
}

private struct LevelBar: View {
    let value: Double

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.25))
            .frame(width: 30, height: 4)
            .overlay(alignment: .leading) {
                Capsule().fill(.white).frame(width: 30 * value)
            }
            .animation(.linear(duration: 0.08), value: value)
    }
}

import Foundation
import Observation

/// Short events shown on both sides of the notch (volume, brightness, Bluetooth devices) that fade away on their own.
@Observable
@MainActor
final class HUDModel {
    enum Kind: Hashable {
        case volume(muted: Bool)
        case brightness
        case device(name: String, connected: Bool)
    }

    struct Event: Equatable {
        let kind: Kind
        /// 0...1, used for volume / brightness
        let value: Double
    }

    private(set) var event: Event?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(_ kind: Kind, value: Double = 0) {
        guard Settings.isHUDEnabled(for: kind) else { return }
        event = Event(kind: kind, value: min(max(value, 0), 1))
        #if DEBUG
        fputs("NotchIsland HUD: \(kind) \(value)\n", stderr)
        #endif
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            event = nil
        }
    }
}

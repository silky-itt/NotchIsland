import AppKit
import EventKit
import Observation
import SwiftUI

/// Remaining events today, or, when today has nothing left, the next upcoming event within the next 7 days.
///
/// Memory: EventKit is heavy and its caches only grow, so it is touched only while the island is open.
/// Each read uses a short-lived `EKEventStore` that is released straight afterwards; nothing about the
/// calendar stays resident while the notch is collapsed, and no observers keep the app awake.
@Observable
@MainActor
final class CalendarMonitor {
    enum Access { case notDetermined, granted, denied }

    struct Event: Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let color: Color
    }

    private(set) var access: Access = Access.current()
    private(set) var events: [Event] = []
    /// True when today has nothing left and `events` holds the next upcoming event instead
    private(set) var isShowingUpcoming = false

    @ObservationIgnored private let maxEvents = 3
    /// How far ahead to look for the next event when today is empty
    @ObservationIgnored private let lookAheadDays = 7

    func requestAccess() async {
        switch access {
        case .granted:
            return
        case .denied:
            // Once denied, macOS will not ask again -> open the permission settings directly
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
        case .notDetermined:
            _ = try? await EKEventStore().requestFullAccessToEvents()
            access = Access.current()
            reload()
        }
    }

    /// Reads the events. Called each time the island opens, so the data is always current.
    func reload() {
        access = Access.current()
        guard access == .granted else {
            events = []
            return
        }

        let now = Date()
        let calendar = Calendar.current
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
              let horizon = calendar.date(byAdding: .day, value: lookAheadDays, to: endOfDay)
        else { return }

        // Everything EventKit allocates lives inside this scope
        let result: (events: [Event], upcoming: Bool) = autoreleasepool {
            let store = EKEventStore()
            func fetch(_ start: Date, _ end: Date) -> [EKEvent] {
                store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            }

            let today = fetch(now, endOfDay)
                .filter { $0.endDate > now }
                .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
            if !today.isEmpty {
                return (today.prefix(maxEvents).map(Self.makeEvent), false)
            }
            // Nothing left today: show the nearest upcoming event instead
            let next = fetch(endOfDay, horizon).min { $0.startDate < $1.startDate }
            return (next.map { [Self.makeEvent($0)] } ?? [], next != nil)
        }
        events = result.events
        isShowingUpcoming = result.upcoming
    }

    /// Called when the island closes: nothing needs to stay in memory.
    func clear() {
        events = []
    }

    private static func makeEvent(_ event: EKEvent) -> Event {
        Event(
            id: event.calendarItemIdentifier + "\(event.startDate.timeIntervalSince1970)",
            title: event.title ?? "(No title)",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            color: Color(nsColor: event.calendar.color)
        )
    }
}

private extension CalendarMonitor.Access {
    static func current() -> Self {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
}

import SwiftUI

struct CalendarView: View {
    @Environment(CalendarMonitor.self) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: calendar.isShowingUpcoming ? "Next" : "Today", systemImage: "calendar")

            switch calendar.access {
            case .granted:
                if calendar.events.isEmpty {
                    Placeholder(text: "No events in the next 7 days")
                } else {
                    ForEach(calendar.events) { event in
                        EventRow(event: event, showsDate: calendar.isShowingUpcoming)
                    }
                }
            case .notDetermined, .denied:
                Button {
                    Task { await calendar.requestAccess() }
                } label: {
                    Text(calendar.access == .denied ? "Open Calendar permission settings" : "Allow Calendar access")
                        .font(.system(size: 11))
                        .underline()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .onAppear { calendar.reload() }
        .onDisappear { calendar.clear() }
    }
}

private struct EventRow: View {
    let event: CalendarMonitor.Event
    /// Upcoming events are not today, so they also show which day
    let showsDate: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.color)
                .frame(width: 3, height: showsDate ? 38 : 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                if showsDate {
                    Text(dayText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Text(timeText)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    /// "Tomorrow" or e.g. "Tue, 7 Oct"
    private var dayText: String {
        if Calendar.current.isDateInTomorrow(event.start) { return "Tomorrow" }
        return event.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "en_GB")))
    }

    private var timeText: String {
        if event.isAllDay { return "All day" }
        let start = event.start.formatted(date: .omitted, time: .shortened)
        let end = event.end.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}

import SwiftUI
import WidgetKit

struct TripCountdownEntry: TimelineEntry {
    let date: Date
    let nextTrip: Trip?
}

struct TripCountdownProvider: TimelineProvider {
    private let calendar = Calendar.schengen

    func placeholder(in context: Context) -> TripCountdownEntry {
        TripCountdownEntry(
            date: .now,
            nextTrip: Trip(
                startDate: calendar.date(byAdding: .day, value: 12, to: .now) ?? .now,
                endDate: calendar.date(byAdding: .day, value: 18, to: .now) ?? .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TripCountdownEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripCountdownEntry>) -> Void) {
        let now = Date.now
        let nextUpdate = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60)

        completion(Timeline(entries: [entry(at: now)], policy: .after(nextUpdate)))
    }

    private func entry(at date: Date) -> TripCountdownEntry {
        let today = CalendarDay(date, calendar: calendar)
        let trip = TripStore.load()
            .filter { $0.end >= today }
            .min { $0.start < $1.start }
        return TripCountdownEntry(date: date, nextTrip: trip)
    }
}

struct TripCountdownWidgetView: View {
    var entry: TripCountdownProvider.Entry
    @Environment(\.widgetFamily) private var family

    private let calendar = Calendar.schengen

    private var today: CalendarDay { CalendarDay(entry.date, calendar: calendar) }

    private var countdown: Int? {
        entry.nextTrip.map { max(0, today.days(to: $0.start)) }
    }

    private func remainingDays(for trip: Trip) -> Int {
        max(1, today.days(to: trip.end) + 1)
    }

    private func isCurrent(_ trip: Trip) -> Bool {
        trip.status(on: today) == .current
    }

    var body: some View {
        Group {
            if let trip = entry.nextTrip, let countdown {
                countdownContent(trip: trip, days: countdown)
            } else {
                emptyContent
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.19, blue: 0.48), Color(red: 0.08, green: 0.45, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .foregroundStyle(.white)
    }

    private func countdownContent(trip: Trip, days: Int) -> some View {
        let current = isCurrent(trip)
        let displayedDays = current ? remainingDays(for: trip) : days

        return VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 8) {
            HStack {
                Text(current ? "TRIP IN PROGRESS" : "NEXT SCHENGEN TRIP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Image(systemName: "airplane.departure")
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(displayedDays)")
                    .font(.system(size: family == .systemSmall ? 46 : 52, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                Text(displayedDays == 1 ? "DAY" : "DAYS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Text(current ? "remaining, including today" : "until your next trip")
                .font(.caption.weight(.semibold))

            Group {
                if current {
                    Text("Ends \(trip.endDate.formatted(.dateTime.day().month(.abbreviated).year()))")
                } else {
                    Text(trip.startDate.formatted(.dateTime.day().month(.abbreviated).year()))
                }
            }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))

            if family != .systemSmall, let countries = trip.countries.title {
                Text(countries)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
            Spacer()
            Text("Your next EU trip")
                .font(.headline)
            Text("Plan a trip in Easy Schengen to start the countdown.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

struct EasySchengenCountdownWidget: Widget {
    let kind = "EasySchengenCountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TripCountdownProvider()) { entry in
            TripCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Next EU Trip")
        .description("Count down the days until your next Schengen trip.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct EasySchengenWidgetBundle: WidgetBundle {
    var body: some Widget {
        EasySchengenCountdownWidget()
    }
}

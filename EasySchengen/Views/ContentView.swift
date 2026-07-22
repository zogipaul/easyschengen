import SwiftUI

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceModeRawValue = AppearanceMode.dark.rawValue

    @State private var trips: [Trip]
    @State private var visibleMonth = Date.now
    @State private var editorContext: TripEditorContext?

    private let calendar = Calendar.schengen

    init() {
        _trips = State(initialValue: TripStore.load())
    }

    var body: some View {
        let calculator = SchengenCalculator(trips: trips, calendar: calendar)
        let summary = calculator.summary()

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(summary: summary)
                    if let nextTrip = nextUpcomingTrip {
                        UpcomingTripHero(
                            trip: nextTrip,
                            today: calendar.startOfDay(for: .now),
                            calendar: calendar
                        ) {
                            editorContext = .edit(nextTrip)
                        }
                    }
                    summaryGrid(summary: summary)
                    calendarPanel(calculator: calculator, summary: summary)
                    tripsSection
                }
                .padding(20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Easy Schengen")
            .inlineNavigationTitleWhenAvailable()
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Menu {
                        Picker("Appearance", selection: $appearanceModeRawValue) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.symbol)
                                    .tag(mode.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: appearanceMode.symbol)
                    }
                    .accessibilityLabel("Appearance")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorContext = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add trip")
                }
            }
            .sheet(item: $editorContext) { context in
                TripEditorView(context: context, existingTrips: trips) { trip in
                    upsert(trip)
                } onDelete: { trip in
                    delete(trip)
                }
            }
            .onChange(of: trips) { _, newTrips in
                TripStore.save(newTrips)
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .dark
    }

    private var nextUpcomingTrip: Trip? {
        let today = calendar.startOfDay(for: .now)
        return trips
            .filter { calendar.startOfDay(for: $0.startDate) > today }
            .min { $0.startDate < $1.startDate }
    }

    private func header(summary: SchengenSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Easy Schengen")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("90/180 day planner")
                        .font(.title)
                        .fontWeight(.bold)
                }
            }

            Text("Plan past and future stays, then see your used days, open days, and current latest possible exit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let latestTripEnd = summary.latestTripEnd {
                Label("Latest trip ends \(latestTripEnd.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar.badge.clock")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private func summaryGrid(summary: SchengenSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryCard(
                title: "Available today",
                value: "\(summary.availableToday)",
                detail: "days left",
                symbol: "checkmark.circle.fill",
                tint: .available
            )

            SummaryCard(
                title: "Used now",
                value: "\(summary.usedToday)",
                detail: "of 90 days",
                symbol: "clock.fill",
                tint: .trip
            )

            SummaryCard(
                title: "Last day",
                value: summary.lastContinuousDay?.formatted(.dateTime.day().month(.abbreviated)) ?? "None",
                detail: "if staying from today",
                symbol: "flag.checkered",
                tint: .lastDay
            )

            SummaryCard(
                title: "Trips",
                value: "\(trips.count)",
                detail: "planned ranges",
                symbol: "map.fill",
                tint: .ink
            )
        }
    }

    private func calendarPanel(calculator: SchengenCalculator, summary: SchengenSummary) -> some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Previous month")

                Spacer()

                Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)

                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Next month")
            }

            CalendarMonthView(
                month: visibleMonth,
                today: summary.today,
                calculator: calculator,
                lastContinuousDay: summary.lastContinuousDay,
                nextPossibleEntryDate: summary.nextPossibleEntryDate
            ) { date in
                editorContext = .newTrip(startDate: date)
            }

            LegendView(nextPossibleEntryDate: summary.nextPossibleEntryDate)
        }
        .sectionSurface()
    }

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trips")
                    .font(.headline)

                Spacer()

                Button {
                    editorContext = .new
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            let sortedTrips = trips.sortedForDisplay()
            let currentTrips = sortedTrips.filter { TripStatus.status(for: $0, today: calendar.startOfDay(for: .now)) == .current }
            let upcomingTrips = sortedTrips.filter { TripStatus.status(for: $0, today: calendar.startOfDay(for: .now)) == .upcoming }
            let pastTrips = sortedTrips.filter { TripStatus.status(for: $0, today: calendar.startOfDay(for: .now)) == .past }.reversed()

            if sortedTrips.isEmpty {
                ContentUnavailableView(
                    "No trips yet",
                    systemImage: "calendar.badge.plus",
                    description: Text("Add a past or future Schengen stay to start calculating your 90/180 allowance.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    TripGroup(title: "Current", trips: Array(currentTrips), today: calendar.startOfDay(for: .now), calendar: calendar) { trip in
                        editorContext = .edit(trip)
                    }

                    TripGroup(title: "Upcoming", trips: Array(upcomingTrips), today: calendar.startOfDay(for: .now), calendar: calendar) { trip in
                        editorContext = .edit(trip)
                    }

                    TripGroup(title: "Past", trips: Array(pastTrips), today: calendar.startOfDay(for: .now), calendar: calendar) { trip in
                        editorContext = .edit(trip)
                    }
                }
            }
        }
        .sectionSurface()
    }

    private func upsert(_ trip: Trip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        } else {
            trips.append(trip)
        }
        trips = trips.sortedForDisplay()
    }

    private func delete(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
    }

    private func moveMonth(by value: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }
}

private enum TripStatus: String {
    case past = "Past"
    case current = "Current"
    case upcoming = "Upcoming"

    static func status(for trip: Trip, today: Date, calendar: Calendar = .schengen) -> TripStatus {
        let start = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)

        if end < today {
            return .past
        }

        if start > today {
            return .upcoming
        }

        return .current
    }

    var color: Color {
        switch self {
        case .past:
            return .secondary
        case .current:
            return .lastDay
        case .upcoming:
            return .available
        }
    }

    var symbol: String {
        switch self {
        case .past:
            return "clock.arrow.circlepath"
        case .current:
            return "location.fill"
        case .upcoming:
            return "calendar.badge.plus"
        }
    }
}

private struct TripGroup: View {
    var title: String
    var trips: [Trip]
    var today: Date
    var calendar: Calendar
    var onTap: (Trip) -> Void

    var body: some View {
        if !trips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(spacing: 10) {
                    ForEach(trips) { trip in
                        TripRow(trip: trip, today: today, calendar: calendar) {
                            onTap(trip)
                        }
                    }
                }
            }
        }
    }
}

private struct SummaryCard: View {
    var title: String
    var value: String
    var detail: String
    var symbol: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)

            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder)
        )
    }
}

private struct UpcomingTripHero: View {
    var trip: Trip
    var today: Date
    var calendar: Calendar
    var onTap: () -> Void

    private var daysUntilDeparture: Int {
        max(0, calendar.dateComponents([.day], from: today, to: trip.startDate).day ?? 0)
    }

    private var tripDayCount: Int {
        (calendar.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0) + 1
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("EU is waiting for you")
                            .font(.title2.bold())
                        Text("Your next Schengen trip starts soon")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "airplane.departure")
                        .font(.title2.weight(.semibold))
                        .padding(12)
                        .background(.white.opacity(0.16), in: Circle())
                }

                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text("\(daysUntilDeparture)")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                    Text(daysUntilDeparture == 1 ? "day to go" : "days to go")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                HStack(spacing: 8) {
                    Label(
                        "\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "calendar"
                    )
                    Spacer(minLength: 8)
                    Text("\(tripDayCount) \(tripDayCount == 1 ? "day" : "days")")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.24, blue: 0.58), Color(red: 0.12, green: 0.52, blue: 0.39)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "sparkles")
                    .font(.system(size: 72))
                    .foregroundStyle(.white.opacity(0.08))
                    .padding(10)
                    .accessibilityHidden(true)
            }
            .shadow(color: Color.available.opacity(0.22), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("EU is waiting for you. \(daysUntilDeparture) days until your next trip")
        .accessibilityHint("Opens the trip")
    }
}

private struct TripRow: View {
    var trip: Trip
    var today: Date
    var calendar: Calendar
    var onTap: () -> Void

    private var status: TripStatus {
        TripStatus.status(for: trip, today: today, calendar: calendar)
    }

    private var dayCount: Int {
        calendar.dateComponents([.day], from: trip.startDate, to: trip.endDate).day.map { $0 + 1 } ?? 1
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(status.color)
                    .frame(width: 8, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) - \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(dayCount) Schengen \(dayCount == 1 ? "day" : "days")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(status.rawValue, systemImage: status.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.color)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(status.color.opacity(0.12), in: Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.appElevatedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.appBorder)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

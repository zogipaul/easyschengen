import SwiftUI

private struct DashboardSnapshot {
    let calculator: SchengenCalculator
    let summary: SchengenSummary
    let stayContext: CalendarStayContext
    let statistics: TravelStatistics

    init(trips: [Trip], calendar: Calendar, on date: Date = .now) {
        calculator = SchengenCalculator(trips: trips, calendar: calendar)
        summary = calculator.summary(on: date)
        stayContext = calculator.calendarStayContext(on: date)
        statistics = TravelStatistics(trips: trips, on: date, calendar: calendar)
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("appearanceMode") private var appearanceModeRawValue = AppearanceMode.system.rawValue

    @State private var trips: [Trip]
    @State private var snapshot: DashboardSnapshot
    @State private var visibleMonth = Date.now
    @State private var editorContext: TripEditorContext?

    private let calendar = Calendar.schengen

    init() {
        let trips = TripStore.load()
        _trips = State(initialValue: trips)
        _snapshot = State(initialValue: DashboardSnapshot(trips: trips, calendar: .schengen))
    }

    var body: some View {
        let calculator = snapshot.calculator
        let summary = snapshot.summary

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    allowanceHero(summary: summary)

                    if let nextTrip = nextUpcomingTrip {
                        UpcomingTripCard(trip: nextTrip, today: summary.today, calendar: calendar) {
                            editorContext = .edit(nextTrip)
                        }
                    }

                    calendarPanel(calculator: calculator, summary: summary)
                    TravelStatsCard(statistics: snapshot.statistics)
                    tripsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .appBackground()
            .navigationTitle("Easy Schengen")
            .inlineNavigationTitleWhenAvailable()
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Appearance", selection: $appearanceModeRawValue) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.symbol).tag(mode.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: appearanceMode.symbol)
                            .frame(width: 34, height: 34)
                            .background(.thinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Appearance")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorContext = .new
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.bold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white)
                            .background(Color.brandIndigo, in: Circle())
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: trips) { _, newTrips in
                TripStore.save(newTrips)
                refreshSnapshot()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshSnapshot() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                refreshSnapshot()
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .tint(.brandIndigo)
    }

    private func refreshSnapshot() {
        snapshot = DashboardSnapshot(trips: trips, calendar: .schengen)
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var nextUpcomingTrip: Trip? {
        let today = snapshot.summary.today
        return trips
            .filter { calendar.startOfDay(for: $0.startDate) > today }
            .min { $0.startDate < $1.startDate }
    }

    private func allowanceHero(summary: SchengenSummary) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
            layout {
                AvailabilityRing(available: summary.availableToday)

                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR ALLOWANCE")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(allowanceTitle(summary.availableToday))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Based on the previous 180 days")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }

            Divider().overlay(.white.opacity(0.18))

            HStack(spacing: 0) {
                HeroMetric(
                    value: "\(summary.usedToday)",
                    label: "Days used",
                    symbol: "clock.arrow.circlepath"
                )

                metricDivider

                HeroMetric(
                    value: "\(trips.count)",
                    label: trips.count == 1 ? "Trip" : "Trips",
                    symbol: "suitcase.rolling.fill"
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(trips.contains {
                    calendar.startOfDay(for: $0.startDate) <= summary.today &&
                    calendar.startOfDay(for: $0.endDate) >= summary.today
                } ? "If you continue your stay today" : "If you enter today")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                if let latestExit = summary.lastContinuousDay {
                    Label("You can stay until \(latestExit.formatted(date: .abbreviated, time: .omitted))", systemImage: "flag.checkered")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                } else {
                    Text("No stay available from today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.16, blue: 0.46), Color(red: 0.08, green: 0.43, blue: 0.48)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 190, height: 190)
                        .offset(x: 58, y: -82)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.brandIndigo.opacity(0.22), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.16))
            .frame(width: 1, height: 42)
    }

    private func allowanceTitle(_ available: Int) -> String {
        switch available {
        case 61...: return "You’re clear to travel"
        case 31...60: return "You have room to travel"
        case 1...30: return "Plan your stay carefully"
        default: return "No days currently available"
        }
    }

    private func calendarPanel(calculator: SchengenCalculator, summary: SchengenSummary) -> some View {
        let stayContext = snapshot.stayContext
        return VStack(alignment: .leading, spacing: 18) {
            SectionHeading(
                eyebrow: "PLAN AHEAD",
                title: "Travel calendar",
                symbol: "calendar"
            )

            VStack(alignment: .leading, spacing: 6) {
                if stayContext.trip != nil {
                    Text("For your trip starting \(stayContext.entryDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("If you enter today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let latestExit = stayContext.latestExitDate {
                    Label("Latest possible exit: \(latestExit.formatted(date: .abbreviated, time: .omitted))", systemImage: "flag.checkered")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lastDay)
                } else {
                    Label("No entry available for this start date", systemImage: "exclamationmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.unavailable)
                }
            }

            HStack {
                monthButton(symbol: "chevron.left", label: "Previous month") {
                    moveMonth(by: -1)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { visibleMonth = .now }
                } label: {
                    VStack(spacing: 2) {
                        Text(visibleMonth.formatted(.dateTime.month(.wide)))
                            .font(.headline)
                        Text(visibleMonth.formatted(.dateTime.year()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Returns to the current month")

                Spacer()

                monthButton(symbol: "chevron.right", label: "Next month") {
                    moveMonth(by: 1)
                }
            }

            CalendarMonthView(
                month: visibleMonth,
                today: summary.today,
                calculator: calculator,
                lastContinuousDay: stayContext.latestExitDate,
                nextPossibleEntryDate: summary.nextPossibleEntryDate
            ) { date in
                editorContext = .newTrip(startDate: date)
            }

            LegendView(nextPossibleEntryDate: summary.nextPossibleEntryDate)
        }
        .sectionSurface()
    }

    private func monthButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .frame(width: 38, height: 38)
                .background(Color.appElevatedSurface, in: Circle())
                .overlay(Circle().stroke(Color.appBorder))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                SectionHeading(eyebrow: "YOUR HISTORY", title: "Trips", symbol: "suitcase.rolling")

                Spacer()

                Button {
                    editorContext = .new
                } label: {
                    Label("Add trip", systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .foregroundStyle(.white)
                        .background(Color.brandIndigo, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            let sortedTrips = trips.sortedForDisplay()
            let today = snapshot.summary.today
            let currentTrips = sortedTrips.filter { TripStatus.status(for: $0, today: today) == .current }
            let upcomingTrips = sortedTrips.filter { TripStatus.status(for: $0, today: today) == .upcoming }
            let pastTrips = sortedTrips.filter { TripStatus.status(for: $0, today: today) == .past }.reversed()

            if sortedTrips.isEmpty {
                EmptyTripsView { editorContext = .new }
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    TripGroup(title: "In progress", trips: Array(currentTrips), today: today, calendar: calendar) { editorContext = .edit($0) }
                    TripGroup(title: "Coming up", trips: Array(upcomingTrips), today: today, calendar: calendar) { editorContext = .edit($0) }
                    TripGroup(title: "Past", trips: Array(pastTrips), today: today, calendar: calendar) { editorContext = .edit($0) }
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
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
        }
    }
}

private struct AvailabilityRing: View {
    var available: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: 9)
            Circle()
                .trim(from: 0, to: CGFloat(available) / 90)
                .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(available)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("DAYS LEFT")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.6)
                    .opacity(0.68)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 100, height: 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(available) days available")
    }
}

private struct HeroMetric: View {
    var value: String
    var label: String
    var symbol: String

    var body: some View {
        VStack(spacing: 5) {
            Label(value, systemImage: symbol)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }
}

private struct SectionHeading: View {
    var eyebrow: String
    var title: String
    var symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandIndigo)
                .frame(width: 34, height: 34)
                .background(Color.brandIndigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 1) {
                Text(eyebrow)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
            }
        }
    }
}

private enum TripStatus: String {
    case past = "Past"
    case current = "Now"
    case upcoming = "Upcoming"

    static func status(for trip: Trip, today: Date, calendar: Calendar = .schengen) -> TripStatus {
        let start = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        if end < today { return .past }
        if start > today { return .upcoming }
        return .current
    }

    var color: Color {
        switch self {
        case .past: return .secondary
        case .current: return .lastDay
        case .upcoming: return .available
        }
    }

    var symbol: String {
        switch self {
        case .past: return "checkmark"
        case .current: return "location.fill"
        case .upcoming: return "airplane.departure"
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
            LazyVStack(alignment: .leading, spacing: 9) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                LazyVStack(spacing: 8) {
                    ForEach(trips) { trip in
                        TripRow(trip: trip, today: today, calendar: calendar) { onTap(trip) }
                    }
                }
            }
        }
    }
}

private struct UpcomingTripCard: View {
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
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.brandIndigo.opacity(0.11))
                    Image(systemName: "airplane.departure")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.brandIndigo)
                }
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 5) {
                    Text("NEXT TRIP · IN \(daysUntilDeparture) \(daysUntilDeparture == 1 ? "DAY" : "DAYS")")
                        .font(.caption2.weight(.bold))
                        .tracking(0.65)
                        .foregroundStyle(Color.brandIndigo)
                    Text(trip.startDate.formatted(.dateTime.month(.wide).day()))
                        .font(.title3.weight(.bold))
                    if let country = trip.country {
                        Text(country.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("\(trip.startDate.formatted(.dateTime.day().month(.abbreviated))) – \(trip.endDate.formatted(.dateTime.day().month(.abbreviated)))  ·  \(tripDayCount) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.appBorder))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the trip")
    }
}

private struct TripRow: View {
    var trip: Trip
    var today: Date
    var calendar: Calendar
    var onTap: () -> Void

    private var status: TripStatus { TripStatus.status(for: trip, today: today, calendar: calendar) }
    private var dayCount: Int { calendar.dateComponents([.day], from: trip.startDate, to: trip.endDate).day.map { $0 + 1 } ?? 1 }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 13) {
                VStack(spacing: 1) {
                    Text(trip.startDate.formatted(.dateTime.day()))
                        .font(.title3.bold())
                    Text(trip.startDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(status.color)
                }
                .frame(width: 44, height: 48)
                .background(status.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 4) {
                    if let country = trip.country {
                        Text(country.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("\(trip.startDate.formatted(.dateTime.month(.abbreviated).day())) – \(trip.endDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                        .font(.subheadline.weight(.semibold))
                    Text("\(dayCount) Schengen \(dayCount == 1 ? "day" : "days")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Label(status.rawValue, systemImage: status.symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(status.color)
                    .labelStyle(.iconOnly)
                    .frame(width: 30, height: 30)
                    .background(status.color.opacity(0.1), in: Circle())

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.appElevatedSurface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(status.rawValue) trip, \(trip.country?.name ?? "Schengen Area"), \(trip.startDate.formatted(date: .abbreviated, time: .omitted)) to \(trip.endDate.formatted(date: .abbreviated, time: .omitted)), \(dayCount) days")
    }
}

private struct TravelStatsCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let statistics: TravelStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(eyebrow: "YOUR JOURNEY", title: "Travel stats", symbol: "chart.bar.xaxis")
            Text("All time · through today")
                .font(.caption)
                .foregroundStyle(.secondary)

            let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 3
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: columns), spacing: 10) {
                metric(statistics.tripsTaken, title: "Trips taken", symbol: "suitcase.rolling", color: .brandIndigo)
                metric(statistics.visitedCountries.count, title: "Countries", symbol: "globe.europe.africa", color: .available)
                metric(statistics.travelDays, title: "Travel days", symbol: "sun.max", color: .lastDay)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("\(statistics.visitedCountries.count) of \(SchengenCountry.allCases.count) Schengen countries visited")
                    .font(.caption.weight(.medium))
                ProgressView(value: Double(statistics.visitedCountries.count), total: Double(SchengenCountry.allCases.count))
                    .tint(Color.available)
                    .accessibilityLabel("Schengen countries visited")
                    .accessibilityValue("\(statistics.visitedCountries.count) of \(SchengenCountry.allCases.count)")
            }

            if !statistics.visitedCountries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(statistics.visitedCountries) { country in
                            Text(country.title)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.appElevatedSurface, in: Capsule())
                        }
                    }
                }
            }

            if statistics.tripsWithoutCountry > 0 {
                Text("Add destinations to \(statistics.tripsWithoutCountry) \(statistics.tripsWithoutCountry == 1 ? "trip" : "trips") in your history to complete your country count.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if statistics.tripsTaken == 0 {
                Text("Your stats grow as you travel. Upcoming trips count from their entry date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sectionSurface()
    }

    private func metric(_ value: Int, title: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(value.formatted())
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyTripsView: View {
    var action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 30))
                .foregroundStyle(Color.brandIndigo)
                .frame(width: 62, height: 62)
                .background(Color.brandIndigo.opacity(0.09), in: Circle())
            Text("Start with your first trip")
                .font(.headline)
            Text("Add past and future stays to calculate your rolling 90/180-day allowance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add a trip", action: action)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}

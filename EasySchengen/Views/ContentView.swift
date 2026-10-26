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
    @State private var tripPendingDeletion: Trip?
    @State private var loadIssue: TripStore.LoadResult?

    private let calendar = Calendar.schengen

    init() {
        let result = TripStore.loadResult()
        _trips = State(initialValue: result.trips)
        _snapshot = State(initialValue: DashboardSnapshot(trips: result.trips, calendar: .schengen))
        _loadIssue = State(initialValue: result.hasIssue ? result : nil)
    }

    var body: some View {
        let calculator = snapshot.calculator
        let summary = snapshot.summary

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    allowanceHero(summary: summary)

                    if let nextTrip = nextUpcomingTrip {
                        UpcomingTripCard(trip: nextTrip, today: today) {
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
            .toolbar { toolbarContent }
            .sheet(item: $editorContext) { context in
                TripEditorView(context: context, existingTrips: trips) { trip in
                    upsert(trip)
                } onDelete: { trip in
                    delete(trip)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert(
                "Some saved data could not be read",
                isPresented: isShowingLoadIssue,
                presenting: loadIssue
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { issue in
                if let count = issue.unreadableTrips {
                    Text("\(count) saved trips could not be read and are not shown. A copy of the original data has been kept on this device.")
                } else {
                    Text("Your saved trips could not be read. A copy of the original data has been kept on this device and nothing was deleted.")
                }
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(get: { tripPendingDeletion != nil }, set: { if !$0 { tripPendingDeletion = nil } })
    }

    private var isShowingLoadIssue: Binding<Bool> {
        Binding(get: { loadIssue != nil }, set: { if !$0 { loadIssue = nil } })
    }

    private func refreshSnapshot() {
        snapshot = DashboardSnapshot(trips: trips, calendar: .schengen)
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var today: CalendarDay {
        CalendarDay(snapshot.summary.today, calendar: calendar)
    }

    private var upcomingTrips: [Trip] {
        trips.filter { $0.status(on: today) == .upcoming }
    }

    private var nextUpcomingTrip: Trip? {
        upcomingTrips.min { $0.start < $1.start }
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

            // Both metrics describe the rolling window, not all-time history,
            // so they never contradict the travel stats further down.
            HStack(spacing: 0) {
                HeroMetric(
                    value: summary.usedToday,
                    label: "Days used",
                    symbol: "clock.arrow.circlepath"
                )

                metricDivider

                HeroMetric(
                    value: upcomingTrips.count,
                    label: "Trips planned",
                    symbol: "airplane.departure"
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(trips.contains { $0.status(on: today) == .current }
                     ? "If you continue your stay today"
                     : "If you enter today")
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
                .fill(LinearGradient.hero)
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

    private func allowanceTitle(_ available: Int) -> LocalizedStringKey {
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

    private func monthButton(symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
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
            let todayDay = today

            if sortedTrips.isEmpty {
                EmptyTripsView { editorContext = .new }
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach([TripStatus.current, .upcoming, .past], id: \.self) { status in
                        let group = sortedTrips.filter { $0.status(on: todayDay) == status }
                        TripGroup(
                            title: status.groupTitle,
                            trips: status == .past ? group.reversed() : group,
                            today: todayDay,
                            onEdit: { editorContext = .edit($0) },
                            onDelete: { tripPendingDeletion = $0 }
                        )
                    }
                }

                Text("Tip: touch and hold a trip to edit or delete it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sectionSurface()
        .confirmationDialog(
            "Delete this trip?",
            isPresented: isConfirmingDeletion,
            titleVisibility: .visible,
            presenting: tripPendingDeletion
        ) { trip in
            Button("Delete trip", role: .destructive) { delete(trip) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This removes the trip and recalculates your allowance.")
        }
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

#Preview {
    ContentView()
}

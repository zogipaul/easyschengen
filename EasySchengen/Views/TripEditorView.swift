import SwiftUI

struct TripEditorContext: Identifiable {
    var id: UUID
    var trip: Trip?
    var initialStartDate: Date?

    static var new: TripEditorContext {
        TripEditorContext(id: UUID(), trip: nil, initialStartDate: nil)
    }

    static func newTrip(startDate: Date) -> TripEditorContext {
        TripEditorContext(id: UUID(), trip: nil, initialStartDate: Calendar.schengen.startOfDay(for: startDate))
    }

    static func edit(_ trip: Trip) -> TripEditorContext {
        TripEditorContext(id: trip.id, trip: trip, initialStartDate: nil)
    }
}

struct TripEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var context: TripEditorContext
    var existingTrips: [Trip]
    var onSave: (Trip) -> Void
    var onDelete: (Trip) -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showingDeleteConfirmation = false

    private let calendar = Calendar.schengen

    init(context: TripEditorContext, existingTrips: [Trip], onSave: @escaping (Trip) -> Void, onDelete: @escaping (Trip) -> Void) {
        self.context = context
        self.existingTrips = existingTrips
        self.onSave = onSave
        self.onDelete = onDelete
        let calendar = Calendar.schengen
        let initialDate = context.trip?.startDate ?? context.initialStartDate ?? .now
        let initialStartDay = calendar.startOfDay(for: initialDate)
        let initialEndDay = calendar.startOfDay(for: context.trip?.endDate ?? initialStartDay)
        _startDate = State(initialValue: initialStartDay)
        _endDate = State(initialValue: max(initialStartDay, initialEndDay))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    tripSummary
                    datesSection
                    allowanceSection

                    if context.trip != nil {
                        deleteButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle(context.trip == nil ? "Plan a trip" : "Edit trip")
            .inlineNavigationTitleWhenAvailable()
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
            .onChange(of: startDate) { _, _ in clampExitDateIfNeeded() }
            .onChange(of: endDate) { _, _ in clampExitDateIfNeeded() }
            .onAppear { clampExitDateIfNeeded() }
            .confirmationDialog(
                "Delete this trip?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete trip", role: .destructive) {
                    if let trip = context.trip {
                        onDelete(trip)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the trip and recalculates your allowance.")
            }
        }
        .tint(.brandIndigo)
    }

    private var tripSummary: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.14))
                Image(systemName: "airplane")
                    .font(.title2.weight(.semibold))
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(dayCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(dayCount == 1 ? "Schengen day" : "Schengen days")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Image(systemName: canSave ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(canSave ? Color.available : Color.lastDay)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.20, blue: 0.56), Color(red: 0.06, green: 0.49, blue: 0.52)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: Color.brandIndigo.opacity(0.18), radius: 18, y: 8)
        .animation(.easeInOut(duration: 0.2), value: dayCount)
    }

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            editorHeading("Travel dates", symbol: "calendar")

            VStack(spacing: 0) {
                dateRow(title: "Entry", subtitle: "First day in the Schengen Area", symbol: "airplane.arrival") {
                    DatePicker("Entry date", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }

                Divider().padding(.leading, 52)

                dateRow(title: "Exit", subtitle: "Last day in the Schengen Area", symbol: "airplane.departure") {
                    if let exitDateRange {
                        DatePicker("Exit date", selection: $endDate, in: exitDateRange, displayedComponents: .date)
                            .labelsHidden()
                    } else {
                        Text("Unavailable")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.unavailable)
                    }
                }
            }
            .background(Color.appElevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .sectionSurface()
    }

    private func dateRow<Content: View>(title: String, subtitle: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandIndigo)
                .frame(width: 38, height: 38)
                .background(Color.brandIndigo.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
            content()
        }
        .padding(13)
    }

    private var allowanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            editorHeading("Allowance check", symbol: "checkmark.shield")

            HStack(spacing: 14) {
                Image(systemName: latestAvailableExit == nil ? "xmark.circle.fill" : "flag.checkered")
                    .font(.title3)
                    .foregroundStyle(latestAvailableExit == nil ? Color.unavailable : Color.lastDay)
                    .frame(width: 44, height: 44)
                    .background((latestAvailableExit == nil ? Color.unavailable : Color.lastDay).opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Latest possible exit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(latestAvailableExit?.formatted(date: .long, time: .omitted) ?? "No entry available")
                        .font(.subheadline.weight(.bold))
                }
                Spacer()
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.unavailable)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.unavailable.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
            } else {
                Label("This trip fits within your current 90/180-day allowance.", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.available)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.available.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .sectionSurface()
    }

    private func editorHeading(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete trip", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.unavailable.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.unavailable)
    }

    private var validationMessage: String? {
        if latestAvailableExit == nil {
            return "No Schengen day is available for this entry date."
        }
        if isPastLatestExit {
            return "Choose an earlier exit date to stay within the 90/180-day limit."
        }
        return nil
    }

    private var baseTrips: [Trip] {
        guard let currentTrip = context.trip else { return existingTrips }
        return existingTrips.filter { $0.id != currentTrip.id }
    }

    private var latestPossibleExit: Date? {
        SchengenCalculator(trips: baseTrips, calendar: calendar).lastContinuousStayDay(from: startDay)
    }

    private var latestAvailableExit: Date? {
        guard let latestPossibleExit, latestPossibleExit >= startDay else { return nil }
        return latestPossibleExit
    }

    private var exitDateRange: ClosedRange<Date>? {
        guard let latestAvailableExit else { return nil }
        return startDay...latestAvailableExit
    }

    private var isPastLatestExit: Bool {
        guard let latestAvailableExit else { return true }
        return endDay > latestAvailableExit
    }

    private var canSave: Bool { exitDateRange != nil && !isPastLatestExit }

    private var dayCount: Int {
        max(1, calendar.dateComponents([.day], from: startDay, to: endDay).day.map { $0 + 1 } ?? 1)
    }

    private var startDay: Date { calendar.startOfDay(for: startDate) }
    private var endDay: Date { calendar.startOfDay(for: endDate) }

    private func save() {
        let trip = Trip(
            id: context.trip?.id ?? UUID(),
            startDate: startDay,
            endDate: endDay,
            calendar: calendar
        )
        onSave(trip)
        dismiss()
    }

    private func clampExitDateIfNeeded() {
        let normalizedStart = startDay
        let normalizedEnd = endDay

        if startDate != normalizedStart { startDate = normalizedStart }

        guard let latestAvailableExit else {
            if endDate != normalizedStart { endDate = normalizedStart }
            return
        }

        if normalizedEnd < normalizedStart {
            endDate = normalizedStart
        } else if normalizedEnd > latestAvailableExit {
            endDate = latestAvailableExit
        } else if endDate != normalizedEnd {
            endDate = normalizedEnd
        }
    }
}

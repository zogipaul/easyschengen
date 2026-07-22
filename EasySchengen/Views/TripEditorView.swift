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
            Form {
                Section("Dates") {
                    DatePicker("Entry", selection: $startDate, displayedComponents: .date)

                    if let exitDateRange {
                        DatePicker("Exit", selection: $endDate, in: exitDateRange, displayedComponents: .date)
                    } else {
                        DatePicker("Exit", selection: $endDate, in: startDay...startDay, displayedComponents: .date)
                            .disabled(true)
                    }
                }

                Section("Allowance") {
                    LabeledContent("Trip length", value: "\(dayCount) \(dayCount == 1 ? "day" : "days")")

                    if let latestAvailableExit {
                        LabeledContent("Latest possible exit") {
                            Text(latestAvailableExit.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(Color.lastDay)
                        }
                    } else {
                        LabeledContent("Latest possible exit") {
                            Text("No entry available")
                                .foregroundStyle(Color.unavailable)
                        }
                    }

                    if latestAvailableExit == nil {
                        Label("No Schengen day is available for this entry date.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.unavailable)
                    } else if isPastLatestExit {
                        Label("Move the exit date earlier to stay within 90/180 days.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.unavailable)
                    }
                }

                if let trip = context.trip {
                    Section {
                        Button(role: .destructive) {
                            onDelete(trip)
                            dismiss()
                        } label: {
                            Label("Delete trip", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(context.trip == nil ? "New Trip" : "Edit Trip")
            .inlineNavigationTitleWhenAvailable()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trip = Trip(
                            id: context.trip?.id ?? UUID(),
                            startDate: startDay,
                            endDate: endDay,
                            calendar: calendar
                        )
                        onSave(trip)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onChange(of: startDate) { _, _ in
                clampExitDateIfNeeded()
            }
            .onChange(of: endDate) { _, _ in
                clampExitDateIfNeeded()
            }
            .onAppear {
                clampExitDateIfNeeded()
            }
        }
    }

    private var baseTrips: [Trip] {
        guard let currentTrip = context.trip else {
            return existingTrips
        }

        return existingTrips.filter { $0.id != currentTrip.id }
    }

    private var latestPossibleExit: Date? {
        SchengenCalculator(trips: baseTrips, calendar: calendar)
            .lastContinuousStayDay(from: startDay)
    }

    private var latestAvailableExit: Date? {
        guard let latestPossibleExit, latestPossibleExit >= startDay else {
            return nil
        }

        return latestPossibleExit
    }

    private var exitDateRange: ClosedRange<Date>? {
        guard let latestAvailableExit else {
            return nil
        }

        return startDay...latestAvailableExit
    }

    private var isPastLatestExit: Bool {
        guard let latestAvailableExit else {
            return true
        }

        return endDay > latestAvailableExit
    }

    private var canSave: Bool {
        exitDateRange != nil && !isPastLatestExit
    }

    private var dayCount: Int {
        max(1, calendar.dateComponents(
            [.day],
            from: startDay,
            to: endDay
        ).day.map { $0 + 1 } ?? 1)
    }

    private var startDay: Date {
        calendar.startOfDay(for: startDate)
    }

    private var endDay: Date {
        calendar.startOfDay(for: endDate)
    }

    private func clampExitDateIfNeeded() {
        let normalizedStart = startDay
        let normalizedEnd = endDay

        if startDate != normalizedStart {
            startDate = normalizedStart
        }

        guard let latestAvailableExit else {
            if endDate != normalizedStart {
                endDate = normalizedStart
            }
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

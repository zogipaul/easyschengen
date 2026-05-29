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
        let initialDate = context.trip?.startDate ?? context.initialStartDate ?? .now
        _startDate = State(initialValue: initialDate)
        _endDate = State(initialValue: context.trip?.endDate ?? initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dates") {
                    DatePicker("Entry", selection: $startDate, displayedComponents: .date)

                    if let latestPossibleExit {
                        DatePicker("Exit", selection: $endDate, in: startDate...latestPossibleExit, displayedComponents: .date)
                    } else {
                        DatePicker("Exit", selection: $endDate, in: startDate...startDate, displayedComponents: .date)
                            .disabled(true)
                    }
                }

                Section("Allowance") {
                    LabeledContent("Trip length", value: "\(dayCount) \(dayCount == 1 ? "day" : "days")")

                    if let latestPossibleExit {
                        LabeledContent("Latest possible exit") {
                            Text(latestPossibleExit.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(Color.lastDay)
                        }
                    } else {
                        LabeledContent("Latest possible exit") {
                            Text("No entry available")
                                .foregroundStyle(Color.unavailable)
                        }
                    }

                    if isPastLatestExit {
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
                            startDate: startDate,
                            endDate: endDate,
                            calendar: calendar
                        )
                        onSave(trip)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onChange(of: startDate) { _, newStart in
                if endDate < newStart {
                    endDate = newStart
                }
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
            .lastContinuousStayDay(from: startDate)
    }

    private var isPastLatestExit: Bool {
        guard let latestPossibleExit else {
            return true
        }

        return calendar.startOfDay(for: endDate) > latestPossibleExit
    }

    private var canSave: Bool {
        latestPossibleExit != nil && !isPastLatestExit
    }

    private var dayCount: Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: endDate)
        ).day.map { $0 + 1 } ?? 1
    }

    private func clampExitDateIfNeeded() {
        guard let latestPossibleExit else {
            endDate = startDate
            return
        }

        if endDate > latestPossibleExit {
            endDate = latestPossibleExit
        }
    }
}

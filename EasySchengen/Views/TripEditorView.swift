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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var context: TripEditorContext
    var existingTrips: [Trip]
    var onSave: (Trip) -> Void
    var onDelete: (Trip) -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var countries: [SchengenCountry]
    @State private var showingDeleteConfirmation = false
    @State private var latestPossibleExit: Date?

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
        _countries = State(initialValue: context.trip?.countries ?? [])
        _latestPossibleExit = State(initialValue: SchengenCalculator(trips: existingTrips, calendar: calendar)
            .latestPossibleExit(from: initialStartDay, excluding: context.trip?.id))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    tripSummary
                    destinationSection
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
            .onChange(of: startDate) { _, _ in
                refreshAllowance()
                clampExitDateIfNeeded()
            }
            .onChange(of: existingTrips) { _, _ in refreshAllowance() }
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
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout {
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

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }

            Image(systemName: canSave ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(canSave ? Color.available : Color.lastDay)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(LinearGradient.hero, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.brandIndigo.opacity(0.18), radius: 18, y: 8)
        .animation(.easeInOut(duration: 0.2), value: dayCount)
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            editorHeading("Destinations", symbol: "globe.europe.africa")

            NavigationLink {
                SchengenCountryPicker(selection: $countries)
            } label: {
                HStack(spacing: 12) {
                    Group {
                        if let title = countries.title {
                            Text(title)
                        } else {
                            Text("Choose countries")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.appElevatedSurface, in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel("Schengen countries")
            .accessibilityValue(countries.names ?? String(localized: "Not specified"))

            Text("Optional. Select every country you visit on this trip.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sectionSurface()
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
                    DatePicker("Exit date", selection: $endDate, in: startDay..., displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .background(Color.appElevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Label("Entry and exit days each count as a full Schengen day, even if you arrive late or leave early.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sectionSurface()
    }

    private func dateRow<Content: View>(title: LocalizedStringKey, subtitle: LocalizedStringKey, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandIndigo)
                    .frame(width: 38, height: 38)
                    .background(Color.brandIndigo.opacity(0.1), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
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
                    Group {
                        if let latestAvailableExit {
                            Text(latestAvailableExit.formatted(date: .long, time: .omitted))
                        } else {
                            Text("No entry available")
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    Text("Based on entry on \(startDay.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private func editorHeading(_ title: LocalizedStringKey, symbol: String) -> some View {
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

    private var validationMessage: LocalizedStringKey? {
        if latestAvailableExit == nil {
            return "No Schengen day is available for this entry date."
        }
        if isPastLatestExit {
            return "Choose an earlier exit date to stay within the 90/180-day limit."
        }
        return nil
    }

    private func refreshAllowance() {
        latestPossibleExit = SchengenCalculator(trips: existingTrips, calendar: calendar)
            .latestPossibleExit(from: startDay, excluding: context.trip?.id)
    }

    private var latestAvailableExit: Date? {
        guard let latestPossibleExit, latestPossibleExit >= startDay else { return nil }
        return latestPossibleExit
    }

    private var isPastLatestExit: Bool {
        guard let latestAvailableExit else { return true }
        return endDay > latestAvailableExit
    }

    private var canSave: Bool { endDay >= startDay && !isPastLatestExit }

    private var dayCount: Int {
        max(1, calendar.dateComponents([.day], from: startDay, to: endDay).day.map { $0 + 1 } ?? 1)
    }

    private var startDay: Date { calendar.startOfDay(for: startDate) }
    private var endDay: Date { calendar.startOfDay(for: endDate) }

    private func save() {
        guard canSave else { return }
        let trip = Trip(
            id: context.trip?.id ?? UUID(),
            startDate: startDay,
            endDate: endDay,
            countries: countries,
            calendar: calendar
        )
        onSave(trip)
        dismiss()
    }

    private func clampExitDateIfNeeded() {
        let normalizedStart = startDay
        let normalizedEnd = endDay

        if startDate != normalizedStart { startDate = normalizedStart }

        // Never shorten a saved trip merely by opening the editor. Invalid
        // allowance dates stay visible with validation until the user fixes them.
        if normalizedEnd < normalizedStart {
            endDate = normalizedStart
        } else if endDate != normalizedEnd {
            endDate = normalizedEnd
        }
    }
}

private struct SchengenCountryPicker: View {
    @Binding var selection: [SchengenCountry]
    @State private var searchText = ""

    private var countries: [SchengenCountry] {
        SchengenCountry.sortedByName.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if searchText.isEmpty && !selection.isEmpty {
                Section {
                    Button("Clear selection", role: .destructive) { selection = [] }
                } footer: {
                    Text("\(selection.count) countries selected")
                }
            }
            Section {
                ForEach(countries) { country in
                    countryOption(country)
                }
            }
        }
        .overlay {
            if countries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Find a country")
        .navigationTitle("Schengen countries")
        .inlineNavigationTitleWhenAvailable()
    }

    private func countryOption(_ country: SchengenCountry) -> some View {
        let isSelected = selection.contains(country)
        return Button {
            if isSelected {
                selection.removeAll { $0 == country }
            } else {
                selection.append(country)
            }
        } label: {
            HStack {
                Text(country.title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brandIndigo)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

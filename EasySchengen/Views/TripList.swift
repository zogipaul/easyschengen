import SwiftUI

extension TripStatus {
    var title: String {
        switch self {
        case .past: return String(localized: "Past")
        case .current: return String(localized: "Now")
        case .upcoming: return String(localized: "Upcoming")
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .past: return String(localized: "Past trip")
        case .current: return String(localized: "Current trip")
        case .upcoming: return String(localized: "Upcoming trip")
        }
    }

    var groupTitle: LocalizedStringKey {
        switch self {
        case .past: return "Past"
        case .current: return "In progress"
        case .upcoming: return "Coming up"
        }
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

struct TripGroup: View {
    var title: LocalizedStringKey
    var trips: [Trip]
    var today: CalendarDay
    var onEdit: (Trip) -> Void
    var onDelete: (Trip) -> Void

    var body: some View {
        if !trips.isEmpty {
            LazyVStack(alignment: .leading, spacing: 9) {
                Text(title)
                    .textCase(.uppercase)
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                LazyVStack(spacing: 8) {
                    ForEach(trips) { trip in
                        TripRow(trip: trip, today: today) { onEdit(trip) }
                            .contextMenu {
                                Button("Edit trip", systemImage: "pencil") { onEdit(trip) }
                                Button("Delete trip", systemImage: "trash", role: .destructive) { onDelete(trip) }
                            }
                            .accessibilityAction(named: "Delete trip") { onDelete(trip) }
                    }
                }
            }
        }
    }
}

struct TripRow: View {
    var trip: Trip
    var today: CalendarDay
    var onTap: () -> Void

    private var status: TripStatus { trip.status(on: today) }

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
                    if let countries = trip.countries.title {
                        Text(countries)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("\(trip.startDate.formatted(.dateTime.month(.abbreviated).day())) – \(trip.endDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                        .font(.subheadline.weight(.semibold))
                    Text("\(trip.dayCount) Schengen days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Label(status.title, systemImage: status.symbol)
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
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let destination = trip.countries.names ?? String(localized: "Schengen Area")
        let start = trip.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = trip.endDate.formatted(date: .abbreviated, time: .omitted)
        return [
            status.accessibilityTitle,
            destination,
            String(localized: "\(start) to \(end)"),
            String(localized: "\(trip.dayCount) Schengen days")
        ].joined(separator: ", ")
    }
}

struct EmptyTripsView: View {
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

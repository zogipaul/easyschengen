import SwiftUI

struct AvailabilityRing: View {
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

struct HeroMetric: View {
    var value: Int
    var label: LocalizedStringKey
    var symbol: String

    var body: some View {
        VStack(spacing: 5) {
            Label(value.formatted(), systemImage: symbol)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeading: View {
    var eyebrow: LocalizedStringKey
    var title: LocalizedStringKey
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

struct UpcomingTripCard: View {
    var trip: Trip
    var today: CalendarDay
    var onTap: () -> Void

    private var daysUntilDeparture: Int { max(0, today.days(to: trip.start)) }

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
                    Text("NEXT TRIP · IN \(daysUntilDeparture) DAYS")
                        .font(.caption2.weight(.bold))
                        .tracking(0.65)
                        .foregroundStyle(Color.brandIndigo)
                    Text(trip.startDate.formatted(.dateTime.month(.wide).day()))
                        .font(.title3.weight(.bold))
                    if let countries = trip.countries.title {
                        Text(countries)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("\(trip.startDate.formatted(.dateTime.day().month(.abbreviated))) – \(trip.endDate.formatted(.dateTime.day().month(.abbreviated))) · \(trip.dayCount) days")
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

struct TravelStatsCard: View {
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
                Text("Add destinations to \(statistics.tripsWithoutCountry) trips in your history to complete your country count.")
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

    private func metric(_ value: Int, title: LocalizedStringKey, symbol: String, color: Color) -> some View {
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

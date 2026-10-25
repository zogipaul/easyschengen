import Foundation

struct TravelStatistics {
    let tripsTaken: Int
    let travelDays: Int
    let visitedCountries: [SchengenCountry]
    let tripsWithoutCountry: Int

    init(trips: [Trip], on date: Date = .now, calendar: Calendar = .schengen) {
        let today = calendar.startOfDay(for: date)
        let startedTrips = trips.filter { calendar.startOfDay(for: $0.startDate) <= today }
        tripsTaken = startedTrips.count
        visitedCountries = Set(startedTrips.compactMap(\.country)).sorted { $0.name < $1.name }
        tripsWithoutCountry = startedTrips.filter { $0.country == nil }.count

        // Merge inclusive ranges to count shared entry/exit days only once.
        // Clip ongoing stays to today; future plans are not travel history yet.
        let ranges = startedTrips.map {
            calendar.startOfDay(for: $0.startDate)...min(today, calendar.startOfDay(for: $0.endDate))
        }.sorted { $0.lowerBound < $1.lowerBound }
        var merged: [ClosedRange<Date>] = []
        for range in ranges {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        travelDays = merged.reduce(0) {
            $0 + (calendar.dateComponents([.day], from: $1.lowerBound, to: $1.upperBound).day ?? 0) + 1
        }
    }
}

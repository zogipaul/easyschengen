import Foundation

struct TravelStatistics {
    let tripsTaken: Int
    let travelDays: Int
    let visitedCountries: [SchengenCountry]
    let tripsWithoutCountry: Int

    init(trips: [Trip], on date: Date = .now, calendar: Calendar = .schengen) {
        let today = CalendarDay(date, calendar: calendar)
        let startedTrips = trips.filter { $0.start <= today }
        tripsTaken = startedTrips.count
        visitedCountries = Set(startedTrips.flatMap(\.countries)).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        tripsWithoutCountry = startedTrips.filter(\.countries.isEmpty).count

        // Merge inclusive ranges to count shared entry/exit days only once.
        // Clip ongoing stays to today; future plans are not travel history yet.
        let ranges = startedTrips
            .map { $0.start.ordinal...min(today, $0.end).ordinal }
            .sorted { $0.lowerBound < $1.lowerBound }
        var merged: [ClosedRange<Int>] = []
        for range in ranges {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        travelDays = merged.reduce(0) { $0 + $1.count }
    }
}

import Foundation

@main
struct TravelStatisticsTests {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        func date(_ value: String) -> Date { formatter.date(from: value)! }
        func trip(_ start: String, _ end: String, _ country: SchengenCountry? = nil) -> Trip {
            Trip(startDate: date(start), endDate: date(end), country: country, calendar: calendar)
        }
        let today = date("2026-10-25")

        // Old app-group payloads have no country key. Preserve IDs and dates.
        let legacy = Data("""
        [{"id":"82BCE1A3-F8BA-478F-9325-6C6E0C9E78DF","startDate":805593600,"endDate":805680000}]
        """.utf8)
        let decoded = try JSONDecoder().decode([Trip].self, from: legacy)
        precondition(decoded.count == 1 && decoded[0].country == nil)
        precondition(decoded[0].id.uuidString == "82BCE1A3-F8BA-478F-9325-6C6E0C9E78DF")
        precondition(decoded[0].startDate.timeIntervalSinceReferenceDate == 805593600)
        precondition(decoded[0].endDate.timeIntervalSinceReferenceDate == 805680000)
        let mixed = decoded + [trip("2026-10-01", "2026-10-03", .austria)]
        precondition(tryRoundTrip(mixed) == mixed)
        var edited = decoded[0]
        edited.country = .romania
        precondition(tryRoundTrip([edited])[0].country == .romania)
        edited.country = nil
        precondition(tryRoundTrip([edited])[0].country == nil)

        let empty = TravelStatistics(trips: [], on: today, calendar: calendar)
        precondition(empty.tripsTaken == 0 && empty.travelDays == 0 && empty.visitedCountries.isEmpty)

        // Overlap, repeated country, one-day visit, missing destination, DST,
        // an ongoing trip and a future destination that must not count yet.
        let trips = [
            trip("2026-10-30", "2026-11-02", .spain),
            trip("2026-10-01", "2026-10-03", .austria),
            trip("2026-10-03", "2026-10-05", .italy),
            trip("2026-10-10", "2026-10-10", .austria),
            trip("2026-10-20", "2026-10-20"),
            trip("2026-10-24", "2026-10-29", .romania)
        ]
        let stats = TravelStatistics(trips: trips, on: today, calendar: calendar)
        precondition(stats.tripsTaken == 5)
        precondition(stats.travelDays == 9)
        precondition(stats.visitedCountries == [.austria, .italy, .romania])
        precondition(stats.tripsWithoutCountry == 1)
        let departureDay = TravelStatistics(trips: [trips[0]], on: date("2026-10-30"), calendar: calendar)
        precondition(departureDay.tripsTaken == 1 && departureDay.travelDays == 1)
        precondition(departureDay.visitedCountries == [.spain])
        let springDST = TravelStatistics(trips: [trip("2026-03-28", "2026-03-30")], on: today, calendar: calendar)
        precondition(springDST.travelDays == 3)
        let autumnDST = TravelStatistics(trips: [trip("2026-10-24", "2026-10-26")], on: date("2026-10-26"), calendar: calendar)
        precondition(autumnDST.travelDays == 3)
        let nested = TravelStatistics(trips: [trip("2026-01-01", "2026-01-10"), trip("2026-01-02", "2026-01-03")], on: today, calendar: calendar)
        precondition(nested.travelDays == 10)

        // Destination metadata must never change allowance calculations.
        let withCountries = SchengenCalculator(trips: trips, calendar: calendar).summary(on: today)
        let withoutCountries = SchengenCalculator(trips: trips.map {
            Trip(id: $0.id, startDate: $0.startDate, endDate: $0.endDate, calendar: calendar)
        }, calendar: calendar).summary(on: today)
        precondition(withCountries == withoutCountries)
        precondition(SchengenCountry.allCases.count == 29)
        precondition(SchengenCountry(rawValue: "IE") == nil && SchengenCountry(rawValue: "CY") == nil)
        print("Travel statistics, legacy storage, country round-trip and allowance checks passed.")
    }

    private static func tryRoundTrip(_ trips: [Trip]) -> [Trip] {
        try! JSONDecoder().decode([Trip].self, from: JSONEncoder().encode(trips))
    }
}

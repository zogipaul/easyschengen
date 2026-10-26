import XCTest

final class TravelStatisticsTests: XCTestCase {
    func testRegressionChecks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        func date(_ value: String) -> Date { formatter.date(from: value)! }
        func trip(_ start: String, _ end: String, _ countries: SchengenCountry...) -> Trip {
            Trip(startDate: date(start), endDate: date(end), countries: countries, calendar: calendar)
        }
        let today = date("2026-10-25")

        // Version 1.0 payloads have no country key. Preserve IDs and calendar days.
        // 805593600 is 2026-07-12 00:00 UTC, i.e. midnight of 12 July in London.
        let legacy = Data("""
        [{"id":"82BCE1A3-F8BA-478F-9325-6C6E0C9E78DF","startDate":805593600,"endDate":805680000}]
        """.utf8)
        let decoded = try JSONDecoder().decode([Trip].self, from: legacy)
        XCTAssertTrue(decoded.count == 1 && decoded[0].countries.isEmpty)
        XCTAssertTrue(decoded[0].id.uuidString == "82BCE1A3-F8BA-478F-9325-6C6E0C9E78DF")
        let legacyStart = Date(timeIntervalSinceReferenceDate: 805593600)
        XCTAssertTrue(decoded[0].start == Trip.legacyDay(legacyStart))
        XCTAssertTrue(decoded[0].end == decoded[0].start.adding(days: 1))
        // Midnight in any zone less than twelve hours from Vienna maps back to the same day.
        for zone in ["America/Los_Angeles", "America/New_York", "Europe/Vienna", "Asia/Tokyo", "Pacific/Auckland"] {
            var created = Calendar(identifier: .gregorian)
            created.timeZone = TimeZone(identifier: zone)!
            let midnight = created.date(from: DateComponents(year: 2026, month: 3, day: 29))!
            XCTAssertTrue(Trip.legacyDay(midnight, calendar: calendar) == CalendarDay(year: 2026, month: 3, day: 29), zone)
        }
        // Version 1.2 payloads carry one optional country.
        let singleCountry = try JSONDecoder().decode([Trip].self, from: Data("""
        [{"id":"82BCE1A3-F8BA-478F-9325-6C6E0C9E78DF","startDate":805593600,"endDate":805680000,"country":"IT"}]
        """.utf8))
        XCTAssertTrue(singleCountry[0].countries == [.italy])
        let mixed = decoded + [trip("2026-10-01", "2026-10-03", .austria, .italy)]
        XCTAssertTrue(tryRoundTrip(mixed) == mixed)
        var edited = decoded[0]
        edited.countries = [.romania, .bulgaria]
        XCTAssertTrue(tryRoundTrip([edited])[0].countries == [.romania, .bulgaria])
        edited.countries = []
        XCTAssertTrue(tryRoundTrip([edited])[0].countries.isEmpty)
        let stored = String(decoding: try JSONEncoder().encode([trip("2026-10-01", "2026-10-03")]), as: UTF8.self)
        XCTAssertTrue(stored.contains("\"start\":\"2026-10-01\"") && stored.contains("\"end\":\"2026-10-03\""))

        // A stored trip keeps its calendar days in every time zone.
        let vienna = trip("2026-10-05", "2026-10-07")
        for zone in ["America/Los_Angeles", "Asia/Tokyo", "Pacific/Kiritimati"] {
            var abroad = Calendar(identifier: .gregorian)
            abroad.timeZone = TimeZone(identifier: zone)!
            XCTAssertTrue(abroad.component(.day, from: vienna.start.date(in: abroad)) == 5, zone)
            let summary = SchengenCalculator(trips: [vienna], calendar: abroad)
                .summary(on: abroad.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 23))!)
            XCTAssertTrue(summary.usedToday == 3, zone)
        }
        for ordinal in stride(from: -800_000, through: 800_000, by: 997) {
            XCTAssertTrue(CalendarDay(ordinal: ordinal).ordinal == ordinal)
        }
        XCTAssertTrue(CalendarDay(year: 1970, month: 1, day: 1).ordinal == 0)
        XCTAssertTrue(CalendarDay(year: 2024, month: 2, day: 29).adding(days: 1) == CalendarDay(year: 2024, month: 3, day: 1))

        let empty = TravelStatistics(trips: [], on: today, calendar: calendar)
        XCTAssertTrue(empty.tripsTaken == 0 && empty.travelDays == 0 && empty.visitedCountries.isEmpty)

        // Overlap, repeated country, one-day visit, missing destination, DST,
        // an ongoing trip and a future destination that must not count yet.
        let trips = [
            trip("2026-10-30", "2026-11-02", .spain, .portugal),
            trip("2026-10-01", "2026-10-03", .austria),
            trip("2026-10-03", "2026-10-05", .italy),
            trip("2026-10-10", "2026-10-10", .austria),
            trip("2026-10-20", "2026-10-20"),
            trip("2026-10-24", "2026-10-29", .romania)
        ]
        let stats = TravelStatistics(trips: trips, on: today, calendar: calendar)
        XCTAssertTrue(stats.tripsTaken == 5)
        XCTAssertTrue(stats.travelDays == 9)
        XCTAssertTrue(Set(stats.visitedCountries) == [.austria, .italy, .romania])
        XCTAssertTrue(stats.tripsWithoutCountry == 1)
        let departureDay = TravelStatistics(trips: [trips[0]], on: date("2026-10-30"), calendar: calendar)
        XCTAssertTrue(departureDay.tripsTaken == 1 && departureDay.travelDays == 1)
        XCTAssertTrue(Set(departureDay.visitedCountries) == [.spain, .portugal])
        let springDST = TravelStatistics(trips: [trip("2026-03-28", "2026-03-30")], on: today, calendar: calendar)
        XCTAssertTrue(springDST.travelDays == 3)
        let autumnDST = TravelStatistics(trips: [trip("2026-10-24", "2026-10-26")], on: date("2026-10-26"), calendar: calendar)
        XCTAssertTrue(autumnDST.travelDays == 3)
        let nested = TravelStatistics(trips: [trip("2026-01-01", "2026-01-10"), trip("2026-01-02", "2026-01-03")], on: today, calendar: calendar)
        XCTAssertTrue(nested.travelDays == 10)

        // Destination metadata must never change allowance calculations.
        let withCountries = SchengenCalculator(trips: trips, calendar: calendar).summary(on: today)
        let withoutCountries = SchengenCalculator(trips: trips.map {
            Trip(id: $0.id, start: $0.start, end: $0.end)
        }, calendar: calendar).summary(on: today)
        XCTAssertTrue(withCountries == withoutCountries)
        XCTAssertTrue(SchengenCountry.allCases.count == 29)
        XCTAssertTrue(SchengenCountry(rawValue: "IE") == nil && SchengenCountry(rawValue: "CY") == nil)
    }

    private func tryRoundTrip(_ trips: [Trip]) -> [Trip] {
        try! JSONDecoder().decode([Trip].self, from: JSONEncoder().encode(trips))
    }
}

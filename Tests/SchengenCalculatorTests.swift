import Foundation

// Compare the optimized range engine with an independent, enumerated-day oracle.
@main
struct SchengenCalculatorTests {
    static func main() {
        var seed: UInt64 = 20261025
        func random(_ upper: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 32) % UInt64(upper))
        }
        var checks = 0
        for zone in ["Europe/Vienna", "America/New_York", "Asia/Kathmandu", "Pacific/Auckland"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: zone)!
            let base = calendar.date(from: DateComponents(year: 2024, month: 2, day: 1))!
            func date(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: base)! }
            func lastAllowed(_ start: Int, _ days: Set<Int>) -> Date? {
                var extra = Set<Int>()
                var last: Int?
                for day in start...(start + 90) {
                    extra.insert(day)
                    if days.union(extra).filter({ $0 >= day - 179 && $0 <= day }).count > 90 { break }
                    last = day
                }
                return last.map(date)
            }
            for _ in 0..<40 {
                let ranges = (0..<random(25)).map { _ -> ClosedRange<Int> in
                    let start = random(1100) - 700
                    return start...(start + random(120))
                }
                let trips = ranges.map { Trip(startDate: date($0.lowerBound), endDate: date($0.upperBound), calendar: calendar) }
                let days = Set(ranges.flatMap { Array($0) })
                let calculator = SchengenCalculator(trips: trips, calendar: calendar)
                for offset in [-500, -180, -179, -1, 0, 58, 59, 60, 90, 179, 180, 260, 300, 400, 500] {
                    let used = days.filter { $0 >= offset - 179 && $0 <= offset }.count
                    let last = lastAllowed(offset, days)
                    let evaluation = calculator.evaluation(for: date(offset).addingTimeInterval(3600), lastContinuousDay: last)
                    precondition(evaluation.usedDays == used, "Window mismatch in \(zone)")
                    precondition(evaluation.isTripDay == days.contains(offset))
                    precondition(evaluation.canBeSchengenDay == (used + (days.contains(offset) ? 0 : 1) <= 90))
                    precondition(evaluation.remainingDays == max(0, 90 - used))
                    let summary = calculator.summary(on: date(offset))
                    precondition(summary.usedToday == used)
                    precondition(summary.lastContinuousDay == last, "Continuous stay mismatch in \(zone)")
                    let searchStart = max(offset, (ranges.map(\.upperBound).max() ?? (offset - 1)) + 1)
                    let next = (searchStart..<(searchStart + 370)).first { candidate in
                        days.union([candidate]).filter { $0 >= candidate - 179 && $0 <= candidate }.count <= 90
                    }
                    precondition(summary.nextPossibleEntryDate == next.map(date))
                    if let first = trips.first {
                        let excludedDays = Set(ranges.dropFirst().flatMap { Array($0) })
                        precondition(calculator.latestPossibleExit(from: date(offset), excluding: first.id) == lastAllowed(offset, excludedDays))
                    }
                    checks += 1
                }
            }
            let ninety = Trip(startDate: date(0), endDate: date(89), calendar: calendar)
            let full = SchengenCalculator(trips: [ninety, ninety], calendar: calendar)
            precondition(full.evaluation(for: date(89), lastContinuousDay: nil).usedDays == 90)
            precondition(full.lastContinuousStayDay(from: date(90)) == nil)
            precondition(full.lastContinuousStayDay(from: date(180)) == date(269))
            let month = full.monthDates(containing: date(28)) // Leap February 2024.
            precondition(month.count % 7 == 0 && month.compactMap { $0 }.count == 29)
            // Long imports must use bounded memory and retain inclusive counts.
            let long = SchengenCalculator(trips: [Trip(startDate: date(-36500), endDate: date(0), calendar: calendar)], calendar: calendar)
            precondition(long.summary(on: date(0)).usedToday == 180)
            precondition(long.summary(on: date(180)).availableToday == 90)
            let expired = SchengenCalculator(trips: [Trip(startDate: date(-36500), endDate: date(-200), calendar: calendar)], calendar: calendar)
            for offset in -24...0 {
                let expected = max(0, -200 - (offset - 179) + 1)
                precondition(expired.evaluation(for: date(offset), lastContinuousDay: nil).usedDays == expected)
            }
        }
        print("Calculator oracle: \(checks) scenarios passed across 4 time zones, plus overlap, 90/180 boundaries, leap year and long imports.")
    }
}

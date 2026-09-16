import Foundation

// Standalone regression checks; see README for the swiftc command.
@main
struct CalendarStayContextTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        func date(_ value: String) -> Date { formatter.date(from: value)! }
        func trip(_ start: String, _ end: String) -> Trip {
            Trip(startDate: date(start), endDate: date(end), calendar: calendar)
        }
        let history = [
            trip("2026-01-11", "2026-01-29"),
            trip("2026-03-12", "2026-04-02"),
            trip("2026-05-03", "2026-06-12"),
            trip("2026-06-20", "2026-06-26"),
            trip("2026-08-11", "2026-08-30")
        ]
        let planned = trip("2026-09-17", "2026-10-08")
        let calculator = SchengenCalculator(trips: history + [planned], calendar: calendar)
        let context = calculator.calendarStayContext(on: date("2026-09-15"))
        precondition(context.trip?.id == planned.id)
        precondition(context.entryDate == date("2026-09-17"))
        precondition(context.latestExitDate == date("2026-10-08"))
        precondition(calculator.summary(on: date("2026-09-15")).lastContinuousDay == date("2026-10-06"))
        precondition(calculator.summary(on: date("2026-09-16")).lastContinuousDay == date("2026-10-07"))
        precondition(calculator.calendarStayContext(on: date("2026-09-16")) == context)
        precondition(calculator.latestPossibleExit(from: planned.startDate, excluding: planned.id) == context.latestExitDate)
        precondition(calculator.evaluation(for: date("2026-10-08"), lastContinuousDay: context.latestExitDate).isLastContinuousDay)
        precondition(!calculator.evaluation(for: date("2026-10-06"), lastContinuousDay: context.latestExitDate).isLastContinuousDay)

        // A current trip wins over a later trip, regardless of input order.
        let later = trip("2026-12-01", "2026-12-03")
        let multiple = SchengenCalculator(trips: [later, planned] + history.reversed(), calendar: calendar)
        for day in ["2026-09-17", "2026-09-25", "2026-10-08"] {
            let current = multiple.calendarStayContext(on: date(day))
            precondition(current.trip?.id == planned.id)
            precondition(current.latestExitDate == date("2026-10-08"))
        }
        precondition(multiple.calendarStayContext(on: date("2026-10-09")).trip?.id == later.id)

        // Once all trips have ended, the context returns to today, even if entry is blocked.
        let blocked = calculator.calendarStayContext(on: date("2026-10-09"))
        precondition(blocked.trip == nil)
        precondition(blocked.entryDate == date("2026-10-09"))
        precondition(blocked.latestExitDate == nil)
        let unavailableTrip = trip("2026-10-09", "2026-10-10")
        let unavailable = SchengenCalculator(trips: history + [planned, unavailableTrip], calendar: calendar)
            .calendarStayContext(on: date("2026-10-09"))
        precondition(unavailable.trip?.id == unavailableTrip.id)
        precondition(unavailable.latestExitDate == nil)

        // With no upcoming trip, the fallback also works across daylight saving time.
        for trips in [[], history] {
            let fallback = SchengenCalculator(trips: trips, calendar: calendar)
                .calendarStayContext(on: date("2026-09-15"))
            precondition(fallback.trip == nil)
            precondition(fallback.entryDate == date("2026-09-15"))
            precondition(fallback.latestExitDate == (trips.isEmpty ? date("2026-12-13") : date("2026-10-06")))
        }
        print("Calendar stay context regression checks passed.")
    }
}

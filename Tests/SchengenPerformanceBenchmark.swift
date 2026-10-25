import Foundation
@main struct Benchmark {
 static func main() {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
  let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25))!
  func day(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: today)! }
  let cases: [(String, [Trip])] = [
   ("100 historical trips", (0..<100).map { Trip(startDate: day(-$0 * 100 - 200), endDate: day(-$0 * 100 - 180), calendar: calendar) }),
   ("100-year imported stay", [Trip(startDate: day(-36500), endDate: day(-200), calendar: calendar)])
  ]
  for (name, trips) in cases {
   var checksum = 0
   let start = Date()
   for _ in 0..<10 {
    let calc = SchengenCalculator(trips: trips, calendar: calendar)
    let summary = calc.summary(on: today)
    checksum += summary.availableToday
    let context = calc.calendarStayContext(on: today)
    for date in calc.monthDates(containing: today).compactMap({ $0 }) {
     checksum += calc.evaluation(for: date, lastContinuousDay: context.latestExitDate).usedDays
    }
    for _ in 0..<10 { checksum += calc.latestPossibleExit(from: today) == nil ? 0 : 1 }
   }
   print("\(name): \(Date().timeIntervalSince(start) * 1000 / 10) ms/workload; checksum \(checksum)")
  }
 }
}

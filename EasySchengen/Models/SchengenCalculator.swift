import Foundation

struct DayEvaluation: Hashable {
    var date: Date
    var isTripDay: Bool
    var usedDays: Int
    var remainingDays: Int
    var canBeSchengenDay: Bool
    var isLastContinuousDay: Bool
}

struct SchengenSummary: Hashable {
    var today: Date
    var usedToday: Int
    var availableToday: Int
    var lastContinuousDay: Date?
    var latestTripEnd: Date?
    var nextPossibleEntryDate: Date?
}

struct CalendarStayContext: Hashable {
    var trip: Trip?
    var entryDate: Date
    var latestExitDate: Date?
}

struct SchengenCalculator {
    private let calendar: Calendar
    private let trips: [Trip]
    // Calendar-day offsets keep DST days inclusive without allocating every travel day.
    private let epoch: Date
    private let tripRanges: [ClosedRange<Int>]

    init(trips: [Trip], calendar: Calendar = .schengen) {
        self.calendar = calendar
        self.trips = trips
        let epoch = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        self.epoch = epoch
        let ranges = trips.compactMap { trip -> ClosedRange<Int>? in
            let start = calendar.dateComponents([.day], from: epoch, to: calendar.startOfDay(for: trip.startDate)).day ?? 0
            let end = calendar.dateComponents([.day], from: epoch, to: calendar.startOfDay(for: trip.endDate)).day ?? 0
            guard end >= start else { return nil }
            return start...end
        }.sorted { $0.lowerBound < $1.lowerBound }
        var merged: [ClosedRange<Int>] = []
        for range in ranges {
            if let last = merged.last, range.lowerBound <= last.upperBound + 1 {
                merged[merged.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        self.tripRanges = merged
    }

    func summary(on date: Date = .now) -> SchengenSummary {
        let today = calendar.startOfDay(for: date)
        let used = usedDays(endingOn: dayIndex(today))
        let remaining = max(0, 90 - used)
        let maxTripEnd = trips.map(\.endDate).max()

        return SchengenSummary(
            today: today,
            usedToday: used,
            availableToday: remaining,
            lastContinuousDay: lastContinuousStayDay(from: today),
            latestTripEnd: maxTripEnd,
            nextPossibleEntryDate: nextPossibleEntryDate(after: maxTripEnd, today: today)
        )
    }

    func calendarStayContext(on date: Date = .now) -> CalendarStayContext {
        let today = calendar.startOfDay(for: date)
        // A current trip sorts before any upcoming trip. Completed trips are ignored.
        let trip = trips
            .filter { calendar.startOfDay(for: $0.endDate) >= today }
            .min { $0.startDate < $1.startDate }
        let entryDate = trip.map { calendar.startOfDay(for: $0.startDate) } ?? today

        return CalendarStayContext(
            trip: trip,
            entryDate: entryDate,
            latestExitDate: latestPossibleExit(from: entryDate, excluding: trip?.id)
        )
    }

    // Use the same entry-date scenario in the calendar and the trip editor.
    func latestPossibleExit(from entryDate: Date, excluding tripID: UUID? = nil) -> Date? {
        guard let tripID else { return lastContinuousStayDay(from: entryDate) }
        return SchengenCalculator(
            trips: trips.filter { $0.id != tripID },
            calendar: calendar
        ).lastContinuousStayDay(from: entryDate)
    }

    func nextPossibleEntryDate(after latestTripEnd: Date?, today: Date) -> Date? {
        let searchBase: Date
        if let latestTripEnd = latestTripEnd, latestTripEnd >= today {
            searchBase = latestTripEnd
        } else {
            searchBase = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }

        var dayToCheck = calendar.date(byAdding: .day, value: 1, to: searchBase) ?? searchBase

        for _ in 0..<370 {
            let index = dayIndex(dayToCheck)
            let usedIfAdded = usedDays(endingOn: index) + (isTripDay(index) ? 0 : 1)
            if usedIfAdded <= 90 {
                return dayToCheck
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayToCheck) else {
                break
            }
            dayToCheck = nextDay
        }
        return nil
    }

    func evaluation(for date: Date, lastContinuousDay: Date?) -> DayEvaluation {
        let day = calendar.startOfDay(for: date)
        let index = dayIndex(day)
        let isTripDay = isTripDay(index)
        let used = usedDays(endingOn: index)
        let usedIfAdded = used + (isTripDay ? 0 : 1)

        return DayEvaluation(
            date: day,
            isTripDay: isTripDay,
            usedDays: used,
            remainingDays: max(0, 90 - used),
            canBeSchengenDay: usedIfAdded <= 90,
            isLastContinuousDay: lastContinuousDay == day
        )
    }

    func lastContinuousStayDay(from startDate: Date = .now) -> Date? {
        let start = dayIndex(startDate)
        var lastAllowed: Int?

        // The hypothetical stay already covers every day from entry onwards.
        // Count only history before entry, so overlaps and future plans count once.
        for day in start...(start + 90) {
            let history = countTripDays(from: day - 179, through: start - 1)
            guard history + day - start + 1 <= 90 else { break }
            lastAllowed = day
        }
        return lastAllowed.flatMap { calendar.date(byAdding: .day, value: $0, to: epoch) }
    }

    func monthDates(containing date: Date) -> [Date?] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: date),
            let numberOfDays = calendar.range(of: .day, in: .month, for: monthInterval.start)
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: monthInterval.start)
        let firstWeekday = calendar.firstWeekday
        let leadingEmptyDays = (weekday - firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        days += numberOfDays.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func dayIndex(_ date: Date) -> Int {
        calendar.dateComponents([.day], from: epoch, to: calendar.startOfDay(for: date)).day ?? 0
    }

    private func usedDays(endingOn day: Int) -> Int {
        countTripDays(from: day - 179, through: day)
    }

    private func isTripDay(_ day: Int) -> Bool {
        let index = firstRange(endingOnOrAfter: day)
        return index < tripRanges.count && tripRanges[index].lowerBound <= day
    }

    private func firstRange(endingOnOrAfter day: Int) -> Int {
        var lower = 0
        var upper = tripRanges.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if tripRanges[middle].upperBound < day {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func countTripDays(from start: Int, through end: Int) -> Int {
        guard start <= end else { return 0 }
        var index = firstRange(endingOnOrAfter: start)
        var count = 0
        while index < tripRanges.count && tripRanges[index].lowerBound <= end {
            let range = tripRanges[index]
            count += min(end, range.upperBound) - max(start, range.lowerBound) + 1
            index += 1
        }
        return count
    }
}

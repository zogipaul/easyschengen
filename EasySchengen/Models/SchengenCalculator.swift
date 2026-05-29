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

struct SchengenCalculator {
    private let calendar: Calendar
    private let trips: [Trip]
    private let tripDays: Set<Date>

    init(trips: [Trip], calendar: Calendar = .schengen) {
        self.calendar = calendar
        self.trips = trips
        self.tripDays = Self.tripDaySet(for: trips, calendar: calendar)
    }

    func summary(on date: Date = .now) -> SchengenSummary {
        let today = calendar.startOfDay(for: date)
        let used = usedDays(endingOn: today, includingExtraDay: nil)
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

    func nextPossibleEntryDate(after latestTripEnd: Date?, today: Date) -> Date? {
        let searchBase: Date
        if let latestTripEnd = latestTripEnd, latestTripEnd >= today {
            searchBase = latestTripEnd
        } else {
            searchBase = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }

        var dayToCheck = calendar.date(byAdding: .day, value: 1, to: searchBase) ?? searchBase

        for _ in 0..<370 {
            let usedIfAdded = usedDays(endingOn: dayToCheck, includingExtraDays: [dayToCheck])
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
        let isTripDay = tripDays.contains(day)
        let used = usedDays(endingOn: day, includingExtraDay: nil)
        let usedIfAdded = usedDays(endingOn: day, includingExtraDays: isTripDay ? [] : [day])

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
        var day = calendar.startOfDay(for: startDate)
        var lastAllowed: Date?
        var continuousStayDays = Set<Date>()

        for _ in 0..<370 {
            continuousStayDays.insert(day)
            let usedIfStayed = usedDays(endingOn: day, includingExtraDays: continuousStayDays)
            guard usedIfStayed <= 90 else {
                break
            }

            lastAllowed = day
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return lastAllowed
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

    private func usedDays(endingOn date: Date, includingExtraDay extraDay: Date?) -> Int {
        usedDays(endingOn: date, includingExtraDays: extraDay.map { [$0] } ?? [])
    }

    private func usedDays(endingOn date: Date, includingExtraDays extraDays: Set<Date>) -> Int {
        guard let windowStart = calendar.date(byAdding: .day, value: -179, to: date) else {
            return 0
        }

        var days = tripDays.filter { day in
            day >= windowStart && day <= date
        }

        for extraDay in extraDays where extraDay >= windowStart && extraDay <= date {
            days.insert(extraDay)
        }

        return days.count
    }

    private static func tripDaySet(for trips: [Trip], calendar: Calendar) -> Set<Date> {
        var days = Set<Date>()

        for trip in trips {
            var day = calendar.startOfDay(for: trip.startDate)
            let end = calendar.startOfDay(for: trip.endDate)

            while day <= end {
                days.insert(day)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                    break
                }
                day = nextDay
            }
        }

        return days
    }
}

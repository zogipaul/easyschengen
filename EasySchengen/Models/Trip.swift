import Foundation

/// A calendar date without a time or time zone. Trips are stored this way so
/// a stay entered in Vienna is still the same days after flying to New York.
struct CalendarDay: Hashable, Comparable, Codable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .schengen) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 1970, month: components.month ?? 1, day: components.day ?? 1)
    }

    /// Days since 1970-01-01 in the proleptic Gregorian calendar.
    init(ordinal: Int) {
        // Inverse of `ordinal`, after Howard Hinnant's civil_from_days.
        let z = ordinal + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        self.init(year: yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month: month, day: day)
    }

    var ordinal: Int {
        // Howard Hinnant's days_from_civil: exact for every Gregorian date.
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
        let yearOfEra = shiftedYear - era * 400
        let dayOfYear = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    func adding(days: Int) -> CalendarDay { CalendarDay(ordinal: ordinal + days) }

    func days(to other: CalendarDay) -> Int { other.ordinal - ordinal }

    /// Midnight of this day in `calendar`'s time zone.
    func date(in calendar: Calendar = .schengen) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
            ?? calendar.startOfDay(for: .now)
    }

    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool { lhs.ordinal < rhs.ordinal }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected yyyy-MM-dd, got \(value)")
        }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

enum TripStatus {
    case past
    case current
    case upcoming
}

struct Trip: Identifiable, Codable, Hashable {
    var id: UUID
    var start: CalendarDay
    var end: CalendarDay
    /// Countries visited on this trip, in the order the user picked them.
    var countries: [SchengenCountry]

    init(id: UUID = UUID(), start: CalendarDay, end: CalendarDay, countries: [SchengenCountry] = []) {
        self.id = id
        self.start = start
        self.end = max(start, end)
        self.countries = countries.uniqued()
    }

    init(id: UUID = UUID(), startDate: Date, endDate: Date, countries: [SchengenCountry] = [], calendar: Calendar = .schengen) {
        self.init(
            id: id,
            start: CalendarDay(startDate, calendar: calendar),
            end: CalendarDay(endDate, calendar: calendar),
            countries: countries
        )
    }

    /// Entry day at midnight in the device's current time zone.
    var startDate: Date { start.date() }
    /// Exit day at midnight in the device's current time zone.
    var endDate: Date { end.date() }

    /// Inclusive: entry and exit days both count as Schengen days.
    var dayCount: Int { start.days(to: end) + 1 }

    func contains(_ day: CalendarDay) -> Bool { start <= day && day <= end }

    func status(on today: CalendarDay) -> TripStatus {
        if end < today { return .past }
        if start > today { return .upcoming }
        return .current
    }

    func status(on date: Date, calendar: Calendar = .schengen) -> TripStatus {
        status(on: CalendarDay(date, calendar: calendar))
    }

    // MARK: Storage

    private enum CodingKeys: String, CodingKey {
        case id, start, end, countries
        // Version 1.2 and earlier stored instants and a single optional country.
        case startDate, endDate, country
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let countries = try container.decodeIfPresent([SchengenCountry].self, forKey: .countries)
            ?? (try container.decodeIfPresent(SchengenCountry.self, forKey: .country)).map { [$0] }
            ?? []

        if let start = try container.decodeIfPresent(CalendarDay.self, forKey: .start) {
            self.init(id: id, start: start, end: try container.decode(CalendarDay.self, forKey: .end), countries: countries)
        } else {
            self.init(
                id: id,
                start: Self.legacyDay(try container.decode(Date.self, forKey: .startDate)),
                end: Self.legacyDay(try container.decode(Date.self, forKey: .endDate)),
                countries: countries
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(start, forKey: .start)
        try container.encode(end, forKey: .end)
        try container.encode(countries, forKey: .countries)
    }

    /// Legacy dates are local midnight in whatever zone the trip was created in.
    /// Reading the instant at noon keeps the original day for any zone up to
    /// twelve hours from the current one, which covers re-reading at home.
    static func legacyDay(_ instant: Date, calendar: Calendar = .schengen) -> CalendarDay {
        CalendarDay(instant.addingTimeInterval(12 * 60 * 60), calendar: calendar)
    }
}

enum SchengenCountry: String, Codable, CaseIterable, Identifiable {
    // Current membership: https://www.consilium.europa.eu/en/policies/schengen-area/
    case austria = "AT", belgium = "BE", bulgaria = "BG", croatia = "HR"
    case czechia = "CZ", denmark = "DK", estonia = "EE", finland = "FI"
    case france = "FR", germany = "DE", greece = "GR", hungary = "HU"
    case iceland = "IS", italy = "IT", latvia = "LV", liechtenstein = "LI"
    case lithuania = "LT", luxembourg = "LU", malta = "MT", netherlands = "NL"
    case norway = "NO", poland = "PL", portugal = "PT", romania = "RO"
    case slovakia = "SK", slovenia = "SI", spain = "ES", sweden = "SE", switzerland = "CH"

    var id: String { rawValue }

    /// Country name in the user's language.
    var name: String {
        Locale.current.localizedString(forRegionCode: rawValue) ?? rawValue
    }

    var flag: String {
        String(String.UnicodeScalarView(rawValue.unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }))
    }

    var title: String { "\(flag) \(name)" }

    static var sortedByName: [SchengenCountry] {
        allCases.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

extension Array where Element == SchengenCountry {
    /// "🇦🇹 Austria, 🇮🇹 Italy" for one or two countries, flags only beyond that.
    var title: String? {
        guard !isEmpty else { return nil }
        if count <= 2 { return map(\.title).joined(separator: ", ") }
        return map(\.flag).joined(separator: " ")
    }

    var names: String? {
        isEmpty ? nil : map(\.name).formatted(.list(type: .and))
    }

    fileprivate func uniqued() -> [SchengenCountry] {
        var seen = Set<SchengenCountry>()
        return filter { seen.insert($0).inserted }
    }
}

extension Calendar {
    static var schengen: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        return calendar
    }
}

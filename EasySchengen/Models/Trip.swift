import Foundation

struct Trip: Identifiable, Codable, Hashable {
    var id: UUID
    var startDate: Date
    var endDate: Date

    init(id: UUID = UUID(), startDate: Date, endDate: Date, calendar: Calendar = .schengen) {
        self.id = id
        self.startDate = calendar.startOfDay(for: startDate)
        self.endDate = calendar.startOfDay(for: max(startDate, endDate))
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


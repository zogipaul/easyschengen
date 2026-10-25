import Foundation

struct Trip: Identifiable, Codable, Hashable {
    var id: UUID
    var startDate: Date
    var endDate: Date
    // Optional so trips saved before destination support still decode unchanged.
    var country: SchengenCountry?

    init(id: UUID = UUID(), startDate: Date, endDate: Date, country: SchengenCountry? = nil, calendar: Calendar = .schengen) {
        self.id = id
        self.startDate = calendar.startOfDay(for: startDate)
        self.endDate = calendar.startOfDay(for: max(startDate, endDate))
        self.country = country
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

    var name: String {
        Locale(identifier: "en").localizedString(forRegionCode: rawValue) ?? rawValue
    }

    var flag: String {
        String(String.UnicodeScalarView(rawValue.unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }))
    }

    var title: String { "\(flag) \(name)" }
}

extension Calendar {
    static var schengen: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        return calendar
    }
}


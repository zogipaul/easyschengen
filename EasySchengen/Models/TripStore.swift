import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum TripStore {
    static let appGroupIdentifier = "group.com.easyschengen.app"
    private static let storageKey = "easy-schengen.trips"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func load() -> [Trip] {
        migrateStandardDefaultsIfNeeded()

        guard let data = sharedDefaults.data(forKey: storageKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([Trip].self, from: data).sortedForDisplay()
        } catch {
            return []
        }
    }

    static func save(_ trips: [Trip]) {
        guard let data = try? JSONEncoder().encode(trips.sortedForDisplay()) else {
            return
        }

        sharedDefaults.set(data, forKey: storageKey)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "EasySchengenCountdownWidget")
        #endif
    }

    private static func migrateStandardDefaultsIfNeeded() {
        guard sharedDefaults.data(forKey: storageKey) == nil,
              let existingData = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        sharedDefaults.set(existingData, forKey: storageKey)
    }
}

extension Array where Element == Trip {
    func sortedForDisplay() -> [Trip] {
        sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.endDate < rhs.endDate
            }
            return lhs.startDate < rhs.startDate
        }
    }
}

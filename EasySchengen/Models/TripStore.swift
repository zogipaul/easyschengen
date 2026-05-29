import Foundation

enum TripStore {
    private static let storageKey = "easy-schengen.trips"

    static func load() -> [Trip] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
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

        UserDefaults.standard.set(data, forKey: storageKey)
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


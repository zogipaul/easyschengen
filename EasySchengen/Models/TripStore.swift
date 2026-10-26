import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum TripStore {
    static let appGroupIdentifier = "group.com.easyschengen.app"
    private static let storageKey = "easy-schengen.trips"
    /// Raw payloads that could not be fully read. Never overwritten or pruned
    /// automatically, so a decoding bug can always be recovered from.
    static let backupKey = "easy-schengen.trips.unreadable-backups"

    struct LoadResult {
        var trips: [Trip]
        /// Number of stored trips that could not be read. `nil` if the whole payload was unreadable.
        var unreadableTrips: Int?
        var hasIssue: Bool { unreadableTrips != 0 }
    }

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func load() -> [Trip] {
        loadResult().trips
    }

    static func loadResult(from defaults: UserDefaults? = nil) -> LoadResult {
        if defaults == nil { migrateStandardDefaultsIfNeeded() }
        let defaults = defaults ?? sharedDefaults

        guard let data = defaults.data(forKey: storageKey) else {
            return LoadResult(trips: [], unreadableTrips: 0)
        }

        if let trips = try? JSONDecoder().decode([Trip].self, from: data) {
            // Rewrite legacy payloads once, so old instants are pinned to calendar days.
            if let current = try? encode(trips), current != data {
                defaults.set(current, forKey: storageKey)
            }
            return LoadResult(trips: trips.sortedForDisplay(), unreadableTrips: 0)
        }

        // Keep the original bytes before anything can save over them, then
        // salvage every trip that still decodes.
        backUp(data, in: defaults)
        guard let items = try? JSONDecoder().decode([LossyTrip].self, from: data) else {
            return LoadResult(trips: [], unreadableTrips: nil)
        }
        let trips = items.compactMap(\.trip)
        return LoadResult(trips: trips.sortedForDisplay(), unreadableTrips: items.count - trips.count)
    }

    static func save(_ trips: [Trip], to defaults: UserDefaults? = nil) {
        guard let data = try? encode(trips) else {
            return
        }

        (defaults ?? sharedDefaults).set(data, forKey: storageKey)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "EasySchengenCountdownWidget")
        #endif
    }

    private static func encode(_ trips: [Trip]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(trips.sortedForDisplay())
    }

    private static func backUp(_ data: Data, in defaults: UserDefaults) {
        var backups = defaults.array(forKey: backupKey) as? [Data] ?? []
        guard !backups.contains(data) else { return }
        backups.append(data)
        defaults.set(backups, forKey: backupKey)
    }

    private static func migrateStandardDefaultsIfNeeded() {
        guard sharedDefaults.data(forKey: storageKey) == nil,
              let existingData = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        sharedDefaults.set(existingData, forKey: storageKey)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "EasySchengenCountdownWidget")
        #endif
    }
}

private struct LossyTrip: Decodable {
    let trip: Trip?

    init(from decoder: Decoder) throws {
        trip = try? Trip(from: decoder)
    }
}

extension Array where Element == Trip {
    func sortedForDisplay() -> [Trip] {
        sorted { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.end < rhs.end
            }
            return lhs.start < rhs.start
        }
    }
}

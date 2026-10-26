import XCTest

final class TripStoreTests: XCTestCase {
    func testRegressionChecks() throws {
        let suite = "easy-schengen.store-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "easy-schengen.trips"

        // Empty storage is not an error.
        XCTAssertTrue(TripStore.loadResult(from: defaults).trips.isEmpty)
        XCTAssertTrue(!TripStore.loadResult(from: defaults).hasIssue)

        // Legacy instants are rewritten once as calendar days.
        defaults.set(Data("""
        [{"id":"82BCE1A3-F8BA-478F-9325-6C6E0C9E78DF","startDate":805593600,"endDate":805680000}]
        """.utf8), forKey: key)
        let migrated = TripStore.loadResult(from: defaults)
        XCTAssertTrue(migrated.trips.count == 1 && !migrated.hasIssue)
        let rewritten = String(decoding: defaults.data(forKey: key)!, as: UTF8.self)
        XCTAssertTrue(rewritten.contains("\"start\"") && !rewritten.contains("startDate"))
        XCTAssertTrue(TripStore.loadResult(from: defaults).trips == migrated.trips)

        // One broken trip must not take the others down, and the original
        // bytes stay untouched until the user saves.
        let partlyBroken = Data("""
        [{"id":"82BCE1A3-F8BA-478F-9325-6C6E0C9E78DF","start":"2026-10-01","end":"2026-10-03"},
         {"id":"not-a-uuid","start":"2026-11-01","end":"2026-11-02"}]
        """.utf8)
        defaults.set(partlyBroken, forKey: key)
        let salvaged = TripStore.loadResult(from: defaults)
        XCTAssertTrue(salvaged.trips.count == 1 && salvaged.unreadableTrips == 1 && salvaged.hasIssue)
        XCTAssertTrue(defaults.data(forKey: key) == partlyBroken)
        XCTAssertTrue(defaults.array(forKey: TripStore.backupKey) as? [Data] == [partlyBroken])

        // Loading again does not duplicate the backup; saving keeps it.
        _ = TripStore.loadResult(from: defaults)
        TripStore.save(salvaged.trips, to: defaults)
        XCTAssertTrue(defaults.array(forKey: TripStore.backupKey) as? [Data] == [partlyBroken])
        XCTAssertTrue(TripStore.loadResult(from: defaults).trips == salvaged.trips)

        // A completely unreadable payload is reported and backed up, not discarded.
        let garbage = Data("{\"unexpected\":true}".utf8)
        defaults.set(garbage, forKey: key)
        let unreadable = TripStore.loadResult(from: defaults)
        XCTAssertTrue(unreadable.trips.isEmpty && unreadable.unreadableTrips == nil && unreadable.hasIssue)
        XCTAssertTrue(defaults.array(forKey: TripStore.backupKey) as? [Data] == [partlyBroken, garbage])
    }
}

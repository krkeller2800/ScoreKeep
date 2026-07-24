import XCTest
@testable import ScoreKeep

@MainActor
final class Task917ExistingKeychainStateInterpretationSuite: XCTestCase {
    private let keychain = KeychainService()
    private let entitlementKey = "seasonPassMaxExpirationISO8601"
    private var counterKeys: [String] = []

    override func setUp() {
        super.setUp()
        try? keychain.delete(entitlementKey)
        counterKeys.removeAll()
    }

    override func tearDown() {
        try? keychain.delete(entitlementKey)
        for key in counterKeys {
            try? keychain.delete(key)
        }
        super.tearDown()
    }

    func testMissingFreeGameCounterUsesExistingDefault() {
        let key = uniqueCounterKey()

        let counter = KeychainBackedCounter(key: key, defaultValue: 2)

        XCTAssertEqual(counter.value, 2)
    }

    func testValidFreeGameCounterPreservesStoredValue() throws {
        let key = uniqueCounterKey()
        try storeCounterValue(1, for: key)

        let counter = KeychainBackedCounter(key: key, defaultValue: 2)

        XCTAssertEqual(counter.value, 1)
    }

    func testMalformedFreeGameCounterDoesNotFabricateRemainingAllowance() throws {
        let key = uniqueCounterKey()
        try keychain.set(Data("not-json".utf8), for: key)

        let counter = KeychainBackedCounter(key: key, defaultValue: 2)

        XCTAssertEqual(counter.value, 0)
    }

    func testNegativeFreeGameCounterDoesNotFabricateRemainingAllowance() throws {
        let key = uniqueCounterKey()
        try storeCounterValue(-3, for: key)

        let counter = KeychainBackedCounter(key: key, defaultValue: 2)

        XCTAssertEqual(counter.value, 0)
    }

    func testMalformedMLBDownloadCounterUsesBlockingUsedCount() throws {
        let key = uniqueCounterKey()
        try keychain.set(Data("not-json".utf8), for: key)

        let counter = KeychainBackedCounter(
            key: key,
            defaultValue: 0,
            invalidStoredValue: 4
        )

        XCTAssertEqual(counter.value, 4)
    }

    func testNegativeMLBDownloadCounterUsesBlockingUsedCount() throws {
        let key = uniqueCounterKey()
        try storeCounterValue(-1, for: key)

        let counter = KeychainBackedCounter(
            key: key,
            defaultValue: 0,
            invalidStoredValue: 4
        )

        XCTAssertEqual(counter.value, 4)
    }

    func testValidMLBDownloadCounterPreservesStoredUsedCount() throws {
        let key = uniqueCounterKey()
        try storeCounterValue(3, for: key)

        let counter = KeychainBackedCounter(
            key: key,
            defaultValue: 0,
            invalidStoredValue: 4
        )

        XCTAssertEqual(counter.value, 3)
    }

    func testMalformedEntitlementExpirationDoesNotFabricateAccess() async throws {
        try keychain.set(Data("not-a-date".utf8), for: entitlementKey)
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = []
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.refreshEntitlements()

        XCTAssertFalse(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .statusUnavailable)
    }

    func testMalformedEntitlementExpirationDoesNotDiscardValidStoreKitEvidence() async throws {
        try keychain.set(Data("not-a-date".utf8), for: entitlementKey)
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [
            TransactionEvidenceInput(
                productID: "com.komakode.ScoreKeep.SeasonPass2025",
                isVerified: true,
                isRevoked: false
            )
        ]
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.refreshEntitlements()

        XCTAssertTrue(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .entitled)
    }

    func testLegacyISO8601EntitlementValueRemainsCompatible() async throws {
        let expiration = Date(timeIntervalSince1970: 1767225599) // Dec 31, 2025
        let stored = ISO8601DateFormatter().string(from: expiration)
        try keychain.set(Data(stored.utf8), for: entitlementKey)
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = []
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.refreshEntitlements()

        XCTAssertTrue(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .entitled)
    }

    func testExpiredISO8601EntitlementValueRemainsPriorSeason() async throws {
        let expiration = Date(timeIntervalSince1970: 1735603199) // Dec 31, 2024
        let stored = ISO8601DateFormatter().string(from: expiration)
        try keychain.set(Data(stored.utf8), for: entitlementKey)
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = []
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.refreshEntitlements()

        XCTAssertFalse(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .priorSeason)
    }

    private func uniqueCounterKey() -> String {
        let key = "Task917Counter-\(UUID().uuidString)"
        counterKeys.append(key)
        return key
    }

    private func storeCounterValue(_ value: Int, for key: String) throws {
        let data = try JSONEncoder().encode(value)
        try keychain.set(data, for: key)
    }
}

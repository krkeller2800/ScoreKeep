import XCTest
@testable import ScoreKeep

@MainActor
final class Task918FreeGameAllowanceSuite: XCTestCase {
    private let keychain = KeychainService()
    private var counterKeys: [String] = []

    override func setUp() {
        super.setUp()
        counterKeys.removeAll()
    }

    override func tearDown() {
        for key in counterKeys {
            try? keychain.delete(key)
        }
        super.tearDown()
    }

    func testMissingStoredValueExposesDefaultRemainingAllowance() throws {
        let state = try freeGameAllowanceState(forStoredValue: nil)

        XCTAssertEqual(state.remaining, 2)
        XCTAssertEqual(state.storageInterpretation, .missingDefault)
        XCTAssertTrue(state.canCreateWithAllowance)
        XCTAssertEqual(state.displayText, "Free games: 2")
        XCTAssertEqual(state.accessibilityLabel, "Free games remaining 2")
    }

    func testValidZeroRemainingValueIsPreservedAndBlocksAllowanceUse() throws {
        let state = try freeGameAllowanceState(forStoredValue: .integer(0))

        XCTAssertEqual(state.remaining, 0)
        XCTAssertEqual(state.storageInterpretation, .validStored)
        XCTAssertFalse(state.canCreateWithAllowance)
        XCTAssertEqual(state.displayText, "Free games: 0")
        XCTAssertEqual(state.accessibilityLabel, "Free games remaining 0")
    }

    func testValidDefaultRemainingValueIsPreserved() throws {
        let state = try freeGameAllowanceState(forStoredValue: .integer(2))

        XCTAssertEqual(state.remaining, 2)
        XCTAssertEqual(state.storageInterpretation, .validStored)
        XCTAssertTrue(state.canCreateWithAllowance)
    }

    func testMalformedStoredValueExposesConservativeZeroRemaining() throws {
        let state = try freeGameAllowanceState(forStoredValue: .malformed)

        XCTAssertEqual(state.remaining, 0)
        XCTAssertEqual(state.storageInterpretation, .invalidStored)
        XCTAssertFalse(state.canCreateWithAllowance)
        XCTAssertEqual(state.displayText, "Free games: 0")
    }

    func testNegativeStoredValueExposesConservativeZeroRemaining() throws {
        let state = try freeGameAllowanceState(forStoredValue: .integer(-1))

        XCTAssertEqual(state.remaining, 0)
        XCTAssertEqual(state.storageInterpretation, .invalidStored)
        XCTAssertFalse(state.canCreateWithAllowance)
    }

    func testDebugAndProductionResetClassificationRemainSeparated() {
        XCTAssertEqual(
            FreeGameAllowanceDebugResetPolicy.classify(buildConfiguration: .debug),
            .debugOnlyResetToDefault
        )
        XCTAssertEqual(
            FreeGameAllowanceDebugResetPolicy.classify(buildConfiguration: .release),
            .noProductionReset
        )
    }

    func testWrongSeasonPreventionRemainsUnchanged() async {
        let fetcher = SpyEntitlementFetcher()
        fetcher.inputs = [
            TransactionEvidenceInput(
                productID: "com.example.OtherProduct2025",
                isVerified: true,
                isRevoked: false
            )
        ]
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )

        await manager.completeVerifiedRecovery(productID: "com.example.OtherProduct2025")

        XCTAssertFalse(manager.isSeasonPassActive)
        XCTAssertEqual(manager.entitlementState, .notEntitled)
    }

    func testTask917InvalidCounterInterpretationStillDoesNotOverwriteDurableState() throws {
        let key = uniqueCounterKey()
        let malformedData = Data("not-json".utf8)
        try keychain.set(malformedData, for: key)

        let counter = KeychainBackedCounter(
            key: key,
            defaultValue: 2,
            invalidStoredValue: 0
        )

        XCTAssertEqual(counter.value, 0)
        XCTAssertEqual(counter.storageInterpretation, .invalidStored)
        XCTAssertEqual(try keychain.get(key), malformedData)
    }

    private func freeGameAllowanceState(
        forStoredValue storedValue: StoredCounterValue?
    ) throws -> FreeGameAllowanceState {
        let key = uniqueCounterKey()

        switch storedValue {
        case .none:
            break
        case .integer(let value):
            let data = try JSONEncoder().encode(value)
            try keychain.set(data, for: key)
        case .malformed:
            try keychain.set(Data("not-json".utf8), for: key)
        }

        let counter = KeychainBackedCounter(
            key: key,
            defaultValue: FreeGameAllowanceState.defaultRemaining,
            invalidStoredValue: FreeGameAllowanceState.invalidStoredRemaining
        )

        return FreeGameAllowanceState(
            remaining: counter.value,
            storageInterpretation: counter.storageInterpretation
        )
    }

    private func uniqueCounterKey() -> String {
        let key = "Task918FreeGameAllowance-\(UUID().uuidString)"
        counterKeys.append(key)
        return key
    }

    private enum StoredCounterValue {
        case integer(Int)
        case malformed
    }
}

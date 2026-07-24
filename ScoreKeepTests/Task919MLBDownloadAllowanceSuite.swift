import XCTest
@testable import ScoreKeep

@MainActor
final class Task919MLBDownloadAllowanceSuite: XCTestCase {
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

    func testMissingStoredValueExposesFullRemainingAllowance() throws {
        let state = try mlbDownloadAllowanceState(forStoredValue: nil)

        XCTAssertEqual(state.usedCount, 0)
        XCTAssertEqual(state.remaining, 4)
        XCTAssertEqual(state.storageInterpretation, .missingDefault)
        XCTAssertTrue(state.canDownloadWithAllowance)
        XCTAssertEqual(state.displayText, "Downloads remaining: 4 of 4")
        XCTAssertEqual(state.accessibilityLabel, "MLB downloads remaining 4 of 4")
    }

    func testValidUsedCountsExposeRemainingAllowance() throws {
        let unusedState = try mlbDownloadAllowanceState(forStoredValue: .integer(0))
        let partialState = try mlbDownloadAllowanceState(forStoredValue: .integer(2))
        let exhaustedState = try mlbDownloadAllowanceState(forStoredValue: .integer(4))

        XCTAssertEqual(unusedState.remaining, 4)
        XCTAssertEqual(unusedState.storageInterpretation, .validStored)
        XCTAssertTrue(unusedState.canDownloadWithAllowance)

        XCTAssertEqual(partialState.remaining, 2)
        XCTAssertEqual(partialState.storageInterpretation, .validStored)
        XCTAssertTrue(partialState.canDownloadWithAllowance)

        XCTAssertEqual(exhaustedState.remaining, 0)
        XCTAssertEqual(exhaustedState.storageInterpretation, .validStored)
        XCTAssertFalse(exhaustedState.canDownloadWithAllowance)
        XCTAssertEqual(exhaustedState.displayText, "Downloads remaining: 0 of 4")
    }

    func testMalformedStoredValueBlocksFreeDownloadAllowance() throws {
        let state = try mlbDownloadAllowanceState(forStoredValue: .malformed)

        XCTAssertEqual(state.usedCount, 4)
        XCTAssertEqual(state.remaining, 0)
        XCTAssertEqual(state.storageInterpretation, .invalidStored)
        XCTAssertFalse(state.canDownloadWithAllowance)
    }

    func testNegativeStoredValueBlocksFreeDownloadAllowance() throws {
        let state = try mlbDownloadAllowanceState(forStoredValue: .integer(-1))

        XCTAssertEqual(state.usedCount, 4)
        XCTAssertEqual(state.remaining, 0)
        XCTAssertEqual(state.storageInterpretation, .invalidStored)
        XCTAssertFalse(state.canDownloadWithAllowance)
    }

    func testTask917InvalidCounterInterpretationStillPreservesDurableState() throws {
        let key = uniqueCounterKey()
        let malformedData = Data("not-json".utf8)
        try keychain.set(malformedData, for: key)

        let counter = KeychainBackedCounter(
            key: key,
            defaultValue: MLBDownloadAllowanceState.defaultUsedCount,
            invalidStoredValue: MLBDownloadAllowanceState.invalidStoredUsedCount
        )

        XCTAssertEqual(counter.value, 4)
        XCTAssertEqual(counter.storageInterpretation, .invalidStored)
        XCTAssertEqual(try keychain.get(key), malformedData)
    }

    func testTask918FreeGameAllowanceRemainsUnchanged() throws {
        let key = uniqueCounterKey()
        let data = try JSONEncoder().encode(2)
        try keychain.set(data, for: key)

        let counter = KeychainBackedCounter(
            key: key,
            defaultValue: FreeGameAllowanceState.defaultRemaining,
            invalidStoredValue: FreeGameAllowanceState.invalidStoredRemaining
        )
        let state = FreeGameAllowanceState(
            remaining: counter.value,
            storageInterpretation: counter.storageInterpretation
        )

        XCTAssertEqual(state.remaining, 2)
        XCTAssertEqual(state.storageInterpretation, .validStored)
        XCTAssertTrue(state.canCreateWithAllowance)
        XCTAssertEqual(state.displayText, "Free games: 2")
    }

    private func mlbDownloadAllowanceState(
        forStoredValue storedValue: StoredCounterValue?
    ) throws -> MLBDownloadAllowanceState {
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
            defaultValue: MLBDownloadAllowanceState.defaultUsedCount,
            invalidStoredValue: MLBDownloadAllowanceState.invalidStoredUsedCount
        )

        return MLBDownloadAllowanceState(
            usedCount: counter.value,
            storageInterpretation: counter.storageInterpretation
        )
    }

    private func uniqueCounterKey() -> String {
        let key = "Task919MLBDownloadAllowance-\(UUID().uuidString)"
        counterKeys.append(key)
        return key
    }

    private enum StoredCounterValue {
        case integer(Int)
        case malformed
    }
}

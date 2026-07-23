import XCTest
@testable import ScoreKeep

struct MockEntitlementFetcher: CurrentEntitlementFetching {
    var inputs: [TransactionEvidenceInput] = []
    
    func currentEntitlements() async -> [TransactionEvidenceInput] {
        return inputs
    }
}

@MainActor
final class Task95EntitlementRecognitionSuite: XCTestCase {
    
    private let keychain = KeychainService()
    private let entitlementKey = "seasonPassMaxExpirationISO8601"
    
    override func setUp() {
        super.setUp()
        try? keychain.delete(entitlementKey)
    }
    
    override func tearDown() {
        try? keychain.delete(entitlementKey)
        super.tearDown()
    }
    
    func testNoEvidenceYieldsNotEntitled() async {
        let fetcher = MockEntitlementFetcher(inputs: [])
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            calendar: .current,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )
        
        await manager.refreshEntitlements()
        
        XCTAssertEqual(manager.entitlementState, .notEntitled)
        XCTAssertFalse(manager.isSeasonPassActive)
    }
    
    func testActiveStoreKitTransactionYieldsEntitled() async {
        let fetcher = MockEntitlementFetcher(inputs: [
            TransactionEvidenceInput(productID: "com.komakode.ScoreKeep.SeasonPass2025", isVerified: true, isRevoked: false)
        ])
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            calendar: .current,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )
        
        await manager.refreshEntitlements()
        
        XCTAssertEqual(manager.entitlementState, .entitled)
        XCTAssertTrue(manager.isSeasonPassActive)
    }
    
    func testRevokedStoreKitTransactionYieldsNotEntitled() async {
        let fetcher = MockEntitlementFetcher(inputs: [
            TransactionEvidenceInput(productID: "com.komakode.ScoreKeep.SeasonPass2025", isVerified: true, isRevoked: true)
        ])
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            calendar: .current,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )
        
        await manager.refreshEntitlements()
        
        XCTAssertEqual(manager.entitlementState, .notEntitled)
        XCTAssertFalse(manager.isSeasonPassActive)
    }
    
    func testPriorSeasonTransactionYieldsPriorSeasonState() async {
        let fetcher = MockEntitlementFetcher(inputs: [
            TransactionEvidenceInput(productID: "com.komakode.ScoreKeep.SeasonPass2024", isVerified: true, isRevoked: false)
        ])
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            calendar: .current,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )
        
        await manager.refreshEntitlements()
        
        XCTAssertEqual(manager.entitlementState, .priorSeason)
        XCTAssertFalse(manager.isSeasonPassActive)
    }
    
    func testUnexpiredKeychainEvidenceYieldsEntitledOffline() async {
        // Set a keychain date in the future (Dec 31, 2025)
        let futureDate = Date(timeIntervalSince1970: 1767139199)
        let str = ISO8601DateFormatter().string(from: futureDate)
        if let data = str.data(using: .utf8) {
            try? keychain.set(data, for: entitlementKey)
        }
        
        // No StoreKit transactions (offline simulation)
        let fetcher = MockEntitlementFetcher(inputs: [])
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            calendar: .current,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )
        
        await manager.refreshEntitlements()
        
        XCTAssertEqual(manager.entitlementState, .entitled)
        XCTAssertTrue(manager.isSeasonPassActive)
    }
    
    func testExpiredKeychainEvidenceYieldsPriorSeasonOffline() async {
        // Set a keychain date in the past (Dec 31, 2024)
        let pastDate = Date(timeIntervalSince1970: 1735603199)
        let str = ISO8601DateFormatter().string(from: pastDate)
        if let data = str.data(using: .utf8) {
            try? keychain.set(data, for: entitlementKey)
        }
        
        // No StoreKit transactions
        let fetcher = MockEntitlementFetcher(inputs: [])
        let manager = PurchaseManager(
            entitlementFetcher: fetcher,
            calendar: .current,
            currentDate: { Date(timeIntervalSince1970: 1748736000) } // Jun 1, 2025
        )
        
        await manager.refreshEntitlements()
        
        XCTAssertEqual(manager.entitlementState, .priorSeason)
        XCTAssertFalse(manager.isSeasonPassActive)
    }
}

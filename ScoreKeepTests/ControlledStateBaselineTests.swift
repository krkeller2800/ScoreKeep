import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
struct ControlledSeasonBaselineTests {
    @Test("fixed current-season date builds configured season product identifier")
    func fixedCurrentSeasonDateBuildsConfiguredSeasonProductIdentifier() {
        let seasonDate = ControlledStateBaselineSupport.fixedDate(year: 2026, month: 7, day: 14)

        #expect(
            ControlledStateBaselineSupport.productIdentifier(for: seasonDate) ==
                "com.komakode.ScoreKeep.SeasonPass2026"
        )
    }

    @Test("configured StoreKit product identifiers parse season years")
    func configuredStoreKitProductIdentifiersParseSeasonYears() {
        #expect(
            ControlledStateBaselineSupport.parsedSeasonYear(
                from: "com.komakode.ScoreKeep.SeasonPass2025"
            ) == 2025
        )
        #expect(
            ControlledStateBaselineSupport.parsedSeasonYear(
                from: "com.komakode.ScoreKeep.SeasonPass2026"
            ) == 2026
        )
        #expect(
            ControlledStateBaselineSupport.parsedSeasonYear(
                from: "com.komakode.ScoreKeep.SeasonPass20A6"
            ) == nil
        )
        #expect(ControlledStateBaselineSupport.parsedSeasonYear(from: "123") == nil)
    }

    @Test("season expiration uses explicit local end of year")
    func seasonExpirationUsesExplicitLocalEndOfYear() {
        let expiration = ControlledStateBaselineSupport.endOfSeasonYear(2026)
        let components = ControlledStateBaselineSupport.policyCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: expiration
        )
        let utcComponents = ControlledStateBaselineSupport.utcCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: expiration
        )

        #expect(components.year == 2026)
        #expect(components.month == 12)
        #expect(components.day == 31)
        #expect(components.hour == 23)
        #expect(components.minute == 59)
        #expect(components.second == 59)
        #expect(utcComponents.year == 2027)
        #expect(utcComponents.month == 1)
        #expect(utcComponents.day == 1)
        #expect(utcComponents.hour == 4)
        #expect(utcComponents.minute == 59)
        #expect(utcComponents.second == 59)
    }

    @Test("entitlement is active only before fixed expiration instant")
    func entitlementIsActiveOnlyBeforeFixedExpirationInstant() {
        let expiration = ControlledStateBaselineSupport.endOfSeasonYear(2026)
        let beforeExpiration = expiration.addingTimeInterval(-1)
        let exactlyExpiration = expiration
        let afterExpiration = expiration.addingTimeInterval(1)

        #expect(ControlledStateBaselineSupport.isEntitlementActive(expiration: expiration, at: beforeExpiration))
        #expect(!ControlledStateBaselineSupport.isEntitlementActive(expiration: expiration, at: exactlyExpiration))
        #expect(!ControlledStateBaselineSupport.isEntitlementActive(expiration: expiration, at: afterExpiration))
        #expect(!ControlledStateBaselineSupport.isEntitlementActive(expiration: nil, at: beforeExpiration))
    }

    @Test("fixed current year classifies prior current and future products")
    func fixedCurrentYearClassifiesPriorCurrentAndFutureProducts() {
        #expect(ControlledStateBaselineSupport.seasonClassification(productYear: 2025, currentYear: 2026) == .prior)
        #expect(ControlledStateBaselineSupport.seasonClassification(productYear: 2026, currentYear: 2026) == .current)
        #expect(ControlledStateBaselineSupport.seasonClassification(productYear: 2027, currentYear: 2026) == .future)
    }

    @Test("missing product remains distinct from no entitlement")
    func missingProductRemainsDistinctFromNoEntitlement() {
        let now = ControlledStateBaselineSupport.fixedDate(year: 2026, month: 7, day: 14)
        let expired = ControlledStateBaselineSupport.endOfSeasonYear(2025)
        let active = ControlledStateBaselineSupport.endOfSeasonYear(2026)

        #expect(
            ControlledStateBaselineSupport.productAvailability(
                productWasLoaded: false,
                entitlementExpiration: active,
                now: now
            ) == .missingProduct
        )
        #expect(
            ControlledStateBaselineSupport.productAvailability(
                productWasLoaded: true,
                entitlementExpiration: expired,
                now: now
            ) == .notEntitled
        )
        #expect(
            ControlledStateBaselineSupport.productAvailability(
                productWasLoaded: true,
                entitlementExpiration: active,
                now: now
            ) == .entitled
        )
    }
}

@MainActor
struct AllowanceSeedAndDebugBaselineTests {
    @Test("allowance baseline constants match repository evidence")
    func allowanceBaselineConstantsMatchRepositoryEvidence() {
        #expect(ControlledStateBaselineSupport.freeGameCreatesCounterKey == "freeGameCreatesRemainingKC")
        #expect(ControlledStateBaselineSupport.freeGameCreatesDefault == 2)
        #expect(ControlledStateBaselineSupport.mlbDownloadCounterKey == "mlbDownloadCountKC")
        #expect(ControlledStateBaselineSupport.mlbDownloadFreeLimit == 4)
    }

    @Test("allowance consumption is deterministic and never below zero")
    func allowanceConsumptionIsDeterministicAndNeverBelowZero() {
        #expect(
            ControlledStateBaselineSupport.remainingAllowance(
                after: .successfulQualifyingAction,
                startingAt: 2
            ) == 1
        )
        #expect(
            ControlledStateBaselineSupport.remainingAllowance(
                after: .failedAction,
                startingAt: 2
            ) == 2
        )
        #expect(
            ControlledStateBaselineSupport.remainingAllowance(
                after: .canceledAction,
                startingAt: 2
            ) == 2
        )
        #expect(
            ControlledStateBaselineSupport.remainingAllowance(
                after: .successfulQualifyingAction,
                startingAt: 0
            ) == 0
        )
    }

    @Test("download allowance uses a distinct used-count model")
    func downloadAllowanceUsesDistinctUsedCountModel() {
        #expect(ControlledStateBaselineSupport.freeGameCreatesCounterKey != ControlledStateBaselineSupport.mlbDownloadCounterKey)
        #expect(
            ControlledStateBaselineSupport.usedDownloadCount(
                after: .successfulQualifyingAction,
                startingAt: 0
            ) == 1
        )
        #expect(
            ControlledStateBaselineSupport.usedDownloadCount(
                after: .failedAction,
                startingAt: 0
            ) == 0
        )
        #expect(
            ControlledStateBaselineSupport.usedDownloadCount(
                after: .canceledAction,
                startingAt: 3
            ) == 3
        )
    }

    @Test("repeated isolated test environments remain seed free")
    func repeatedIsolatedTestEnvironmentsRemainSeedFree() throws {
        for _ in 0..<2 {
            let environment = try IsolatedPersistenceEnvironment()

            #expect(try environment.fetch(FetchDescriptor<Game>()).isEmpty)
            #expect(try environment.fetch(FetchDescriptor<Team>()).isEmpty)
            #expect(try environment.fetch(FetchDescriptor<Player>()).isEmpty)
            #expect(try environment.fetch(FetchDescriptor<Atbat>()).isEmpty)
            #expect(try environment.fetch(FetchDescriptor<Lineup>()).isEmpty)
            #expect(try environment.fetch(FetchDescriptor<Pitcher>()).isEmpty)
        }
    }

    @Test("controlled test preferences do not use production seed preferences")
    func controlledTestPreferencesDoNotUseProductionSeedPreferences() throws {
        let suiteName = "ScoreKeepControlledSeedBaselineTests"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(defaults.bool(forKey: ControlledStateBaselineSupport.seedPreferenceKey) == false)
        defaults.set(true, forKey: ControlledStateBaselineSupport.seedPreferenceKey)
        #expect(defaults.bool(forKey: ControlledStateBaselineSupport.seedPreferenceKey) == true)
    }

    @Test("test execution records active compilation configuration")
    func testExecutionRecordsActiveCompilationConfiguration() {
        #expect(BuildConfigurationBaseline.isDebugBuild == true)
    }
}

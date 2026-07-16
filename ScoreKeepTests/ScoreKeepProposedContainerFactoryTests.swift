import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Proposed container factory startup verification")
struct ScoreKeepProposedContainerFactoryTests {
    @Test("explicit disposable URL constructs new empty Proposed V2 store")
    func explicitDisposableURLConstructsNewEmptyProposedV2Store() throws {
        let url = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let result = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .noStoreExists))

        #expect(result.disposition == .constructedNewEmptyProposedV2Store)
        #expect(result.container != nil)
        #expect(result.verificationStillRequired)
        #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: result.container!) == 0)
    }

    @Test("empty minimal representative and edge unversioned stores transition to Proposed V2")
    func unversionedStoresTransitionToProposedV2() throws {
        for scenario in UnversionedStoreScenario.allCases {
            let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(scenario)
            let result = ScoreKeepProposedContainerFactory.construct(input(url: source.url, source: scenario == .empty ? .emptyCurrentUnversionedStore : .populatedCurrentUnversionedStore))

            #expect(result.disposition == .openedCompatibleUnversionedSourceAndTransitionedToProposedV2)
            #expect(result.container != nil)
            let migrated = try IsolatedUnversionedProductionStoreSupport.snapshot(from: result.container!, fixtureIdentity: scenario.rawValue)
            #expect(migrated.counts == source.snapshot.counts)
            #expect(migrated.gameIDs == source.snapshot.gameIDs)
            #expect(migrated.teamIDs == source.snapshot.teamIDs)
            #expect(migrated.playerIDs == source.snapshot.playerIDs)
            #expect(migrated.lineups == source.snapshot.lineups)
            #expect(migrated.atbatSequences == source.snapshot.atbatSequences)
            #expect(migrated.scorecardColumns == source.snapshot.scorecardColumns)
            #expect(migrated.storedScores == source.snapshot.storedScores)
            #expect(migrated.playerPhotoFingerprints == source.snapshot.playerPhotoFingerprints)
            #expect(migrated.teamLogoFingerprints == source.snapshot.teamLogoFingerprints)
            #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: result.container!) == 0)
        }
    }

    @Test("existing Proposed V2 store reopens repeatedly")
    func existingProposedV2StoreReopensRepeatedly() throws {
        let url = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let first = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .noStoreExists))
        #expect(first.container != nil)

        let second = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .existingProposedV2Store))
        let third = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .existingProposedV2Store))

        #expect(second.disposition == .openedExistingProposedV2Store)
        #expect(third.disposition == .openedExistingProposedV2Store)
        #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: second.container!) == 0)
        #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: third.container!) == 0)
    }

    @Test("read only configuration opens for diagnosis and prohibits write readiness")
    func readOnlyConfigurationOpensForDiagnosis() throws {
        let url = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let writable = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .noStoreExists))
        #expect(writable.container != nil)

        let result = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .existingProposedV2Store, mode: .readOnlyDiagnosis, intent: .readOnlyDiagnosis))

        #expect(result.disposition == .openedReadOnlyForDiagnosis)
        #expect(result.diagnostics.stableDiagnosticCodes.contains("startup.factory.openedReadOnlyForDiagnosis"))
    }

    @Test("invalid, disabled, future, nonempty destination, and injected failures are classified")
    func failuresAreClassified() throws {
        let production = ScoreKeepProposedContainerFactory.construct(ScoreKeepProposedContainerFactoryInput(
            storeLocation: .productionIntendedApplicationStore,
            writabilityMode: .writable,
            startupIntent: .productionTransitionPreparation,
            sourceClassification: .noStoreExists,
            routeChoice: .proposedV2EligibleForIsolatedVerification
        ))
        #expect(production.disposition == .unsafe)

        let disabledURL = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let disabled = ScoreKeepProposedContainerFactory.construct(input(url: disabledURL, source: .noStoreExists, route: .legacyUnversionedProductionStartup))
        #expect(disabled.disposition == .disabledByRoutePolicy)

        let futureURL = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let future = ScoreKeepProposedContainerFactory.construct(input(url: futureURL, source: .unsupportedFutureVersion))
        #expect(future.disposition == .unsupportedFutureSchema)

        let existing = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.empty)
        let nonEmpty = ScoreKeepProposedContainerFactory.construct(ScoreKeepProposedContainerFactoryInput(
            storeLocation: .disposableMigrationTarget(url: existing.url, requiresFreshDestination: true),
            writabilityMode: .writable,
            startupIntent: .isolatedVerification,
            sourceClassification: .noStoreExists,
            routeChoice: .proposedV2EligibleForIsolatedVerification
        ))
        #expect(nonEmpty.disposition == .unsafe)

        let injectedURL = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let injected = ScoreKeepProposedContainerFactory.construct(input(url: injectedURL, source: .noStoreExists, injection: .constructionCompletionUncertain))
        #expect(injected.disposition == .migrationCompletionUncertain)
    }

    private func input(
        url: URL,
        source: ScoreKeepSourceStoreClassification,
        mode: ScoreKeepStartupWritabilityMode = .writable,
        intent: ScoreKeepStartupIntent = .isolatedVerification,
        route: ScoreKeepSchemaRouteChoice = .proposedV2EligibleForIsolatedVerification,
        injection: ScoreKeepProposedContainerFactoryInjection? = nil
    ) -> ScoreKeepProposedContainerFactoryInput {
        ScoreKeepProposedContainerFactoryInput(
            storeLocation: .disposableTestStore(url: url),
            writabilityMode: mode,
            startupIntent: intent,
            sourceClassification: source,
            routeChoice: route,
            failureInjection: injection
        )
    }
}

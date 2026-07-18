import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Proposed container factory startup verification")
struct ScoreKeepProposedContainerFactoryTests {
    @Test("explicit disposable URL constructs new empty Proposed V3 store")
    func explicitDisposableURLConstructsNewEmptyProposedV3Store() throws {
        let url = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let result = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .noStoreExists))

        #expect(result.disposition == .constructedNewEmptyProposedV3Store)
        #expect(result.container != nil)
        #expect(result.verificationStillRequired)
        #expect(try IsolatedUnversionedProductionStoreSupport.evidenceCount(in: result.container!) == 0)
    }

    @Test("hosted current-target unversioned stores fail closed before V2 plus V3 construction")
    func unversionedStoresFailClosedBeforeV2PlusV3Construction() throws {
        for scenario in UnversionedStoreScenario.allCases {
            let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(scenario)
            let result = ScoreKeepProposedContainerFactory.construct(input(url: source.url, source: scenario == .empty ? .emptyCurrentUnversionedStore : .populatedCurrentUnversionedStore))

            #expect(result.disposition == .unsafe)
            #expect(result.container == nil)
            #expect(result.verificationStillRequired == false)
        }
    }

    @Test("existing Proposed V2 store is blocked in the hosted current target")
    func existingProposedV2StoreIsBlockedInHostedCurrentTarget() throws {
        let url = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let first = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .noStoreExists))
        #expect(first.container != nil)

        let second = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .existingProposedV2Store))
        let third = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .existingProposedV2Store))

        #expect(second.disposition == .semanticVerifierUnavailableCurrentTargetV2AndV3DuplicateEffectiveChecksums)
        #expect(third.disposition == .semanticVerifierUnavailableCurrentTargetV2AndV3DuplicateEffectiveChecksums)
        #expect(second.container == nil)
        #expect(third.container == nil)
    }

    @Test("read only configuration opens for diagnosis and prohibits write readiness")
    func readOnlyConfigurationOpensForDiagnosis() throws {
        let url = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        let writable = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .noStoreExists))
        #expect(writable.container != nil)

        let result = ScoreKeepProposedContainerFactory.construct(input(url: url, source: .existingProposedV3Store, mode: .readOnlyDiagnosis, intent: .readOnlyDiagnosis))

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
            routeChoice: .proposedV3EligibleForIsolatedVerification
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
            routeChoice: .proposedV3EligibleForIsolatedVerification
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
        route: ScoreKeepSchemaRouteChoice = .proposedV3EligibleForIsolatedVerification,
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

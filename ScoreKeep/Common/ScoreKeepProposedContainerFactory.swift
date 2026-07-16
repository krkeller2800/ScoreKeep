import Foundation
import SwiftData

enum ScoreKeepProposedContainerFactoryInjection: String, CaseIterable, Hashable, Sendable {
    case preflightFailure
    case sourceClassificationFailure
    case sourcePreservationFailure
    case containerConstructionFailure
    case migrationFailure
    case constructionCompletionUncertain
    case postOpenVerificationFailure
    case completionEvidenceFailure
    case disableStateActivated
    case recoveryRequired
    case readOnlyStore
    case unsupportedFutureSource
    case conflictingMigrationEvidence
}

enum ScoreKeepProposedContainerConstructionDisposition: String, CaseIterable, Hashable, Sendable, Codable {
    case constructedNewEmptyProposedV2Store
    case openedCompatibleUnversionedSourceAndTransitionedToProposedV2
    case openedExistingProposedV2Store
    case openedReadOnlyForDiagnosis
    case sourceUnavailable
    case sourceVersionUnknown
    case unsupportedFutureSchema
    case migrationInProgress
    case migrationInterrupted
    case migrationFailedSafely
    case migrationCompletionUncertain
    case containerCreatedVerificationPending
    case verificationFailed
    case recoveryRequired
    case writesProhibited
    case disabledByRoutePolicy
    case unsafe
    case internalConfigurationError
}

struct ScoreKeepProposedContainerFactoryInput: Hashable, Sendable {
    let storeLocation: ScoreKeepStartupStoreLocation
    let writabilityMode: ScoreKeepStartupWritabilityMode
    let schemaSelection: ScoreKeepProposedSchemaSelection
    let migrationPlanSelection: ScoreKeepProposedMigrationPlanSelection
    let startupIntent: ScoreKeepStartupIntent
    let sourceClassification: ScoreKeepSourceStoreClassification
    let routeChoice: ScoreKeepSchemaRouteChoice
    let failureInjection: ScoreKeepProposedContainerFactoryInjection?

    init(
        storeLocation: ScoreKeepStartupStoreLocation,
        writabilityMode: ScoreKeepStartupWritabilityMode,
        schemaSelection: ScoreKeepProposedSchemaSelection = .proposedV2,
        migrationPlanSelection: ScoreKeepProposedMigrationPlanSelection = .provenV1ToV2TeamCreationEvidencePlan,
        startupIntent: ScoreKeepStartupIntent,
        sourceClassification: ScoreKeepSourceStoreClassification,
        routeChoice: ScoreKeepSchemaRouteChoice,
        failureInjection: ScoreKeepProposedContainerFactoryInjection? = nil
    ) {
        self.storeLocation = storeLocation
        self.writabilityMode = writabilityMode
        self.schemaSelection = schemaSelection
        self.migrationPlanSelection = migrationPlanSelection
        self.startupIntent = startupIntent
        self.sourceClassification = sourceClassification
        self.routeChoice = routeChoice
        self.failureInjection = failureInjection
    }
}

@MainActor
struct ScoreKeepProposedContainerFactoryResult {
    let disposition: ScoreKeepProposedContainerConstructionDisposition
    let container: ModelContainer?
    let diagnostics: ScoreKeepStartupDiagnosticSummary

    var verificationStillRequired: Bool {
        switch disposition {
        case .constructedNewEmptyProposedV2Store,
             .openedCompatibleUnversionedSourceAndTransitionedToProposedV2,
             .openedExistingProposedV2Store,
             .openedReadOnlyForDiagnosis,
             .containerCreatedVerificationPending:
            return true
        case .sourceUnavailable, .sourceVersionUnknown, .unsupportedFutureSchema,
             .migrationInProgress, .migrationInterrupted, .migrationFailedSafely,
             .migrationCompletionUncertain, .verificationFailed, .recoveryRequired,
             .writesProhibited, .disabledByRoutePolicy, .unsafe, .internalConfigurationError:
            return false
        }
    }
}

@MainActor
enum ScoreKeepProposedContainerFactory {
    static func construct(_ input: ScoreKeepProposedContainerFactoryInput) -> ScoreKeepProposedContainerFactoryResult {
        if let injected = input.failureInjection {
            return injectedResult(for: injected, input: input)
        }

        guard input.schemaSelection == .proposedV2,
              input.migrationPlanSelection == .provenV1ToV2TeamCreationEvidencePlan else {
            return classified(.internalConfigurationError, input: input)
        }

        guard input.routeChoice != .proposedV2PreparedButDisabled,
              input.routeChoice != .legacyUnversionedProductionStartup else {
            return classified(.disabledByRoutePolicy, input: input)
        }

        guard input.storeLocation.kind != .productionIntendedApplicationStore else {
            return classified(.unsafe, input: input)
        }

        guard let url = input.storeLocation.url else {
            return classified(.sourceUnavailable, input: input)
        }

        if input.storeLocation.requiresFreshDestination && storeFamilyExists(at: url) {
            return classified(.unsafe, input: input)
        }

        guard input.sourceClassification.isSupportedForProposedV2Startup else {
            switch input.sourceClassification {
            case .unknownVersion:
                return classified(.sourceVersionUnknown, input: input)
            case .unsupportedFutureVersion:
                return classified(.unsupportedFutureSchema, input: input)
            case .unreadableStore:
                return classified(.sourceUnavailable, input: input)
            case .readOnlyDiagnosisRequired:
                return classified(.writesProhibited, input: input)
            default:
                return classified(.unsafe, input: input)
            }
        }

        do {
            let schema = Schema(ScoreKeepProposedVersionedSchema.V2.models)
            let configuration = ModelConfiguration(
                "ScoreKeepProposedV2StartupReadiness",
                schema: schema,
                url: url,
                allowsSave: input.writabilityMode == .writable
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ScoreKeepProposedTeamCreationEvidenceMigrationPlan.self,
                configurations: [configuration]
            )
            return ScoreKeepProposedContainerFactoryResult(
                disposition: successDisposition(for: input),
                container: container,
                diagnostics: diagnostics(successDisposition(for: input), input: input)
            )
        } catch {
            return classified(.migrationFailedSafely, input: input)
        }
    }

    private static func successDisposition(for input: ScoreKeepProposedContainerFactoryInput) -> ScoreKeepProposedContainerConstructionDisposition {
        if input.writabilityMode == .readOnlyDiagnosis {
            return .openedReadOnlyForDiagnosis
        }
        switch input.sourceClassification {
        case .noStoreExists:
            return .constructedNewEmptyProposedV2Store
        case .emptyCurrentUnversionedStore, .populatedCurrentUnversionedStore, .proposedV1RecognizableStore:
            return .openedCompatibleUnversionedSourceAndTransitionedToProposedV2
        case .existingProposedV2Store, .convertedProposedV2Store:
            return .openedExistingProposedV2Store
        case .automaticallyEvolvedComparisonStore, .unknownVersion, .unsupportedFutureVersion,
             .unreadableStore, .contradictoryMetadata, .migrationEvidenceExists,
             .migrationEvidenceMissing, .migrationEvidenceUncertain, .readOnlyDiagnosisRequired:
            return .containerCreatedVerificationPending
        }
    }

    private static func injectedResult(
        for injection: ScoreKeepProposedContainerFactoryInjection,
        input: ScoreKeepProposedContainerFactoryInput
    ) -> ScoreKeepProposedContainerFactoryResult {
        let disposition: ScoreKeepProposedContainerConstructionDisposition
        switch injection {
        case .preflightFailure, .sourceClassificationFailure, .sourcePreservationFailure, .conflictingMigrationEvidence:
            disposition = .unsafe
        case .containerConstructionFailure, .migrationFailure:
            disposition = .migrationFailedSafely
        case .constructionCompletionUncertain:
            disposition = .migrationCompletionUncertain
        case .postOpenVerificationFailure:
            disposition = .verificationFailed
        case .completionEvidenceFailure:
            disposition = .migrationCompletionUncertain
        case .disableStateActivated:
            disposition = .disabledByRoutePolicy
        case .recoveryRequired:
            disposition = .recoveryRequired
        case .readOnlyStore:
            disposition = .writesProhibited
        case .unsupportedFutureSource:
            disposition = .unsupportedFutureSchema
        }
        return classified(disposition, input: input)
    }

    private static func classified(
        _ disposition: ScoreKeepProposedContainerConstructionDisposition,
        input: ScoreKeepProposedContainerFactoryInput
    ) -> ScoreKeepProposedContainerFactoryResult {
        ScoreKeepProposedContainerFactoryResult(
            disposition: disposition,
            container: nil,
            diagnostics: diagnostics(disposition, input: input)
        )
    }

    private static func diagnostics(
        _ disposition: ScoreKeepProposedContainerConstructionDisposition,
        input: ScoreKeepProposedContainerFactoryInput
    ) -> ScoreKeepStartupDiagnosticSummary {
        ScoreKeepStartupDiagnosticSummary(
            factoryPath: "ScoreKeepProposedContainerFactory.construct",
            routeChoice: input.routeChoice,
            storeLocationKind: input.storeLocation.kind,
            sourceClassification: input.sourceClassification,
            migrationDiagnosticToken: nil,
            targetSchema: input.schemaSelection,
            constructionDisposition: disposition,
            verificationDisposition: disposition == .verificationFailed ? "failed" : "notRun",
            writeReadinessDisposition: "notEvaluatedByFactory",
            disableState: input.routeChoice,
            recoveryRequired: disposition == .recoveryRequired,
            stableDiagnosticCodes: ["startup.factory.\(disposition.rawValue)"]
        )
    }

    private static func storeFamilyExists(at storeURL: URL) -> Bool {
        let directory = storeURL.deletingLastPathComponent()
        let baseName = storeURL.lastPathComponent
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return false
        }
        return names.contains { $0 == baseName || $0.hasPrefix(baseName + "-") }
    }
}

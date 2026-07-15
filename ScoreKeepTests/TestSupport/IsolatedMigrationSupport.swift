import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

struct MigrationFixtureExpectation: Hashable, Sendable {
    let identity: String
    let categories: [String]
    let sourceClassification: CanonicalMigrationSourceClassification
    let expectedDisposition: CanonicalMigrationDisposition
    let expectedRecordCounts: CanonicalMigrationRecordCounts
    let expectedFindings: [String]
    let mayContinue: Bool
    let reviewRequired: Bool
    let rollbackOrPreservationRequired: Bool
    let allowanceProbe: CanonicalMigrationPurchaseAllowanceProbe
}

enum MigrationFixtureManifest {
    static let defaultProbe = CanonicalMigrationPurchaseAllowanceProbe(
        freeGameCreatesRemaining: 2,
        mlbDownloadUseCount: 0,
        entitlementMarker: "entitlement-unchanged",
        purchaseMarker: "purchase-unchanged"
    )

    static let expectations: [MigrationFixtureExpectation] = [
        .init(
            identity: "empty-source",
            categories: ["empty source", "truly empty new store"],
            sourceClassification: .trulyEmptyNewStore,
            expectedDisposition: .emptySourceInitialized,
            expectedRecordCounts: .empty,
            expectedFindings: [],
            mayContinue: true,
            reviewRequired: false,
            rollbackOrPreservationRequired: false,
            allowanceProbe: defaultProbe
        ),
        .init(
            identity: "minimal-valid-store",
            categories: ["minimal valid store", "multiple teams", "reusable players", "roster relationships"],
            sourceClassification: .populatedExistingStore,
            expectedDisposition: .requiresReview,
            expectedRecordCounts: .init(games: 1, teams: 2, players: 4, atbats: 1, lineups: 1, pitchers: 1),
            expectedFindings: ["populated store conversion deferred to task 3.14"],
            mayContinue: false,
            reviewRequired: true,
            rollbackOrPreservationRequired: true,
            allowanceProbe: defaultProbe
        ),
        .init(
            identity: "in-progress-game",
            categories: ["in-progress game", "stored-score evidence", "multiple scoring events"],
            sourceClassification: .populatedExistingStore,
            expectedDisposition: .requiresReview,
            expectedRecordCounts: .init(games: 1, teams: 2, players: 4, atbats: 2, lineups: 1, pitchers: 2),
            expectedFindings: ["in-progress source remains fixture evidence only in task 3.13"],
            mayContinue: false,
            reviewRequired: true,
            rollbackOrPreservationRequired: true,
            allowanceProbe: defaultProbe
        ),
        .init(
            identity: "completed-game",
            categories: ["completed game", "pitcher evidence", "substitution evidence", "ordering evidence"],
            sourceClassification: .populatedExistingStore,
            expectedDisposition: .requiresReview,
            expectedRecordCounts: .init(games: 1, teams: 2, players: 4, atbats: 2, lineups: 1, pitchers: 2),
            expectedFindings: ["completed populated conversion deferred to task 3.14"],
            mayContinue: false,
            reviewRequired: true,
            rollbackOrPreservationRequired: true,
            allowanceProbe: defaultProbe
        ),
        .init(
            identity: "optional-values-and-media",
            categories: ["optional values missing", "photos and logos", "media evidence"],
            sourceClassification: .populatedExistingStore,
            expectedDisposition: .requiresReview,
            expectedRecordCounts: .init(games: 1, teams: 3, players: 4, atbats: 2, lineups: 1, pitchers: 2),
            expectedFindings: ["media migration is evidence only before populated migration"],
            mayContinue: false,
            reviewRequired: true,
            rollbackOrPreservationRequired: true,
            allowanceProbe: defaultProbe
        ),
        .init(
            identity: "duplicate-identity",
            categories: ["duplicate identity", "requires relationship repair assessment"],
            sourceClassification: .populatedExistingStore,
            expectedDisposition: .requiresReview,
            expectedRecordCounts: .empty,
            expectedFindings: ["duplicate identity must not be merged automatically"],
            mayContinue: false,
            reviewRequired: true,
            rollbackOrPreservationRequired: true,
            allowanceProbe: defaultProbe
        ),
        .init(
            identity: "broken-relationship",
            categories: ["broken relationship", "requires relationship repair assessment"],
            sourceClassification: .populatedExistingStore,
            expectedDisposition: .requiresReview,
            expectedRecordCounts: .empty,
            expectedFindings: ["broken relationship must remain preserved for review"],
            mayContinue: false,
            reviewRequired: true,
            rollbackOrPreservationRequired: true,
            allowanceProbe: defaultProbe
        ),
        .init(
            identity: "conflicting-ordering",
            categories: ["duplicate or conflicting ordering", "requires ordering repair assessment"],
            sourceClassification: .populatedExistingStore,
            expectedDisposition: .requiresReview,
            expectedRecordCounts: .empty,
            expectedFindings: ["conflicting order must not be resequenced automatically"],
            mayContinue: false,
            reviewRequired: true,
            rollbackOrPreservationRequired: true,
            allowanceProbe: defaultProbe
        ),
        .init(
            identity: "unsupported-raw-value",
            categories: ["unsupported raw value", "malformed or incomplete evidence"],
            sourceClassification: .unsupportedSource,
            expectedDisposition: .unsupportedSource,
            expectedRecordCounts: .empty,
            expectedFindings: ["unsupported raw evidence must be preserved or rejected safely"],
            mayContinue: false,
            reviewRequired: true,
            rollbackOrPreservationRequired: true,
            allowanceProbe: defaultProbe
        ),
        .init(
            identity: "purchase-allowance-probes",
            categories: ["purchase and allowance separation probes", "preferences-only source"],
            sourceClassification: .purchaseOrAllowanceOnlyNoBaseballRecords,
            expectedDisposition: .emptySourceInitialized,
            expectedRecordCounts: .empty,
            expectedFindings: [],
            mayContinue: true,
            reviewRequired: false,
            rollbackOrPreservationRequired: false,
            allowanceProbe: .init(
                freeGameCreatesRemaining: 1,
                mlbDownloadUseCount: 3,
                entitlementMarker: "known-entitlement-marker",
                purchaseMarker: "known-purchase-marker"
            )
        )
    ]
}

enum IsolatedMigrationInjectedError: Error {
    case containerCreationFailed
}

@MainActor
enum IsolatedMigrationSupport {
    static func recordCounts(from container: ModelContainer) throws -> CanonicalMigrationRecordCounts {
        let context = ModelContext(container)
        return CanonicalMigrationRecordCounts(
            games: try context.fetch(FetchDescriptor<Game>()).count,
            teams: try context.fetch(FetchDescriptor<Team>()).count,
            players: try context.fetch(FetchDescriptor<Player>()).count,
            atbats: try context.fetch(FetchDescriptor<Atbat>()).count,
            lineups: try context.fetch(FetchDescriptor<Lineup>()).count,
            pitchers: try context.fetch(FetchDescriptor<Pitcher>()).count
        )
    }

    static func emptyStoreInput(
        fixtureIdentity: String,
        operationIdentity: String = "empty-store-migration-001",
        sourceClassification: CanonicalMigrationSourceClassification = .trulyEmptyNewStore,
        mode: CanonicalMigrationMode = .initializeEmptyStore,
        probe: CanonicalMigrationPurchaseAllowanceProbe = MigrationFixtureManifest.defaultProbe
    ) -> CanonicalMigrationInput {
        CanonicalMigrationInput(
            fixtureIdentity: fixtureIdentity,
            operationIdentity: operationIdentity,
            sourceVersion: "legacy-current-swiftdata-unversioned",
            targetVersion: "current-swiftdata-model",
            sourceClassification: sourceClassification,
            targetClassification: .currentSwiftDataEmptyBaseballState,
            mode: mode,
            purchaseAllowanceProbe: probe
        )
    }

    static func migrateEmptyStore(
        input: CanonicalMigrationInput,
        existingContainer: ModelContainer? = nil,
        injectedFailure: IsolatedMigrationInjectedError? = nil,
        interrupted: Bool = false,
        probeAfter: CanonicalMigrationPurchaseAllowanceProbe? = nil
    ) throws -> CanonicalMigrationResult {
        let probeAfter = probeAfter ?? input.purchaseAllowanceProbe
        guard injectedFailure == nil else {
            return result(
                input: input,
                targetCounts: .empty,
                disposition: .recoveryAvailable,
                transactionResult: CanonicalPersistenceTransactionClassifier.recoveryAvailable(operationIdentity: input.operationIdentity),
                probeAfter: probeAfter,
                findings: [CanonicalMigrationFinding(code: "migration.emptyStore.containerCreationFailed", summary: "The isolated empty-store container could not be created.", requiresReview: true)]
            )
        }

        if interrupted {
            return result(
                input: input,
                targetCounts: .empty,
                disposition: .interrupted,
                transactionResult: CanonicalPersistenceTransactionClassifier.interruptedOperation(operationIdentity: input.operationIdentity),
                probeAfter: probeAfter,
                findings: [CanonicalMigrationFinding(code: "migration.emptyStore.interrupted", summary: "Empty-store initialization did not prove completion.", requiresReview: true)]
            )
        }

        let environment = try existingContainer.map { ExistingContainerBox(container: $0) } ?? ExistingContainerBox(container: IsolatedPersistenceEnvironment().container)
        let targetCounts = try recordCounts(from: environment.container)
        let disposition = CanonicalMigrationClassifier.migrationDisposition(
            for: input.sourceClassification,
            mode: input.mode,
            targetRecordCounts: targetCounts,
            purchaseAllowanceUnchanged: input.purchaseAllowanceProbe == probeAfter
        )
        let transactionResult = transactionResult(for: disposition, operationIdentity: input.operationIdentity)
        return result(
            input: input,
            targetCounts: targetCounts,
            disposition: disposition,
            transactionResult: transactionResult,
            probeAfter: probeAfter,
            findings: findings(for: disposition, targetCounts: targetCounts)
        )
    }

    private static func transactionResult(
        for disposition: CanonicalMigrationDisposition,
        operationIdentity: String
    ) -> CanonicalPersistenceTransactionResult {
        switch disposition {
        case .emptySourceInitialized, .notRequired, .success, .successWithWarnings:
            return CanonicalPersistenceTransactionClassifier.success(operationIdentity: operationIdentity)
        case .noChange, .alreadyMigrated:
            return CanonicalPersistenceTransactionClassifier.noChange(operationIdentity: operationIdentity)
        case .requiresReview, .requiresRollback, .relationshipFailure:
            return CanonicalPersistenceTransactionClassifier.relationshipFailure(
                [finding("migration.emptyStore.reviewRequired", summary: "The isolated target is not an empty baseball store.")],
                operationIdentity: operationIdentity
            )
        case .orderingFailure:
            return CanonicalPersistenceTransactionClassifier.orderingFailure(
                [finding("migration.emptyStore.orderingFailure", summary: "Ordering could not be established.")],
                operationIdentity: operationIdentity
            )
        case .mediaFailure:
            return CanonicalPersistenceTransactionClassifier.mediaFailure(
                [finding("migration.emptyStore.mediaFailure", summary: "Media evidence could not be handled.")],
                operationIdentity: operationIdentity
            )
        case .purchaseSeparationFailure:
            return CanonicalPersistenceTransactionClassifier.contradictory(
                [finding("migration.emptyStore.purchaseSeparationFailure", summary: "Purchase or allowance probes changed during baseball migration.")],
                operationIdentity: operationIdentity
            )
        case .unknownSourceVersion:
            return CanonicalPersistenceTransactionClassifier.unsupported(
                [finding("migration.emptyStore.unknownSourceVersion", summary: "The source version is unknown.")],
                operationIdentity: operationIdentity
            )
        case .unsupportedSource:
            return CanonicalPersistenceTransactionClassifier.unsupported(
                [finding("migration.emptyStore.unsupportedSource", summary: "The source classification is unsupported for empty-store migration.")],
                operationIdentity: operationIdentity
            )
        case .partialOrUncertain, .interrupted:
            return CanonicalPersistenceTransactionClassifier.interruptedOperation(operationIdentity: operationIdentity)
        case .retrySafe:
            return CanonicalPersistenceTransactionClassifier.retrySafe(operationIdentity: operationIdentity)
        case .retryUnsafe, .validationRejected, .contradictory, .unresolved:
            return CanonicalPersistenceTransactionClassifier.unresolved(
                [finding("migration.emptyStore.unresolved", summary: "Empty-store migration could not prove a safe result.")],
                operationIdentity: operationIdentity
            )
        case .recoveryAvailable, .priorStorePreserved:
            return CanonicalPersistenceTransactionClassifier.recoveryAvailable(operationIdentity: operationIdentity)
        }
    }

    private static func result(
        input: CanonicalMigrationInput,
        targetCounts: CanonicalMigrationRecordCounts,
        disposition: CanonicalMigrationDisposition,
        transactionResult: CanonicalPersistenceTransactionResult,
        probeAfter: CanonicalMigrationPurchaseAllowanceProbe,
        findings: [CanonicalMigrationFinding]
    ) -> CanonicalMigrationResult {
        CanonicalMigrationResult(
            disposition: disposition,
            sourceClassification: input.sourceClassification,
            targetClassification: input.targetClassification,
            sourceRecordCounts: input.sourceRecordCounts,
            targetRecordCounts: targetCounts,
            findings: findings,
            transactionResult: transactionResult,
            purchaseAllowanceProbeBefore: input.purchaseAllowanceProbe,
            purchaseAllowanceProbeAfter: probeAfter,
            sourceRemainsUsable: transactionResult.priorAcceptedStateRemainsUsable,
            targetIsUsable: targetCounts.containsBaseballRecords == false && disposition != .unsupportedSource && disposition != .unknownSourceVersion,
            retryIsSafe: transactionResult.retryIsSafe || disposition == .emptySourceInitialized || disposition == .noChange,
            reloadRequired: transactionResult.explicitReloadRequired,
            reviewOrRepairRequired: transactionResult.repairOrReviewRequired || findings.contains { $0.requiresReview },
            producedRecords: targetCounts.containsBaseballRecords,
            noOp: disposition == .noChange || disposition == .notRequired,
            completionProven: transactionResult.saveCompletionProven
                && disposition != .interrupted
                && disposition != .recoveryAvailable
                && disposition != .requiresRollback
        )
    }

    private static func findings(
        for disposition: CanonicalMigrationDisposition,
        targetCounts: CanonicalMigrationRecordCounts
    ) -> [CanonicalMigrationFinding] {
        if targetCounts.containsBaseballRecords {
            return [CanonicalMigrationFinding(code: "migration.emptyStore.unexpectedRecords", summary: "The target already contains baseball records.", requiresReview: true)]
        }
        switch disposition {
        case .unknownSourceVersion:
            return [CanonicalMigrationFinding(code: "migration.emptyStore.unknownSourceVersion", summary: "The source version is unknown.", requiresReview: true)]
        case .unsupportedSource:
            return [CanonicalMigrationFinding(code: "migration.emptyStore.unsupportedSource", summary: "The source classification is unsupported for empty-store migration.", requiresReview: true)]
        case .purchaseSeparationFailure:
            return [CanonicalMigrationFinding(code: "migration.emptyStore.purchaseSeparationFailure", summary: "Purchase or allowance probes changed during baseball migration.", requiresReview: true)]
        default:
            return []
        }
    }

    private static func finding(_ code: String, summary: String) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(
            code,
            concept: .game,
            severity: .rejection,
            disposition: .rejected,
            summary: summary
        )
    }
}

private struct ExistingContainerBox {
    let container: ModelContainer
}

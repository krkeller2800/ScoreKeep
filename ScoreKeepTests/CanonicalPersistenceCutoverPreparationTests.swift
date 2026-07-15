import Foundation
import Testing
@testable import ScoreKeep

@Suite("Canonical persistence cutover preparation verification")
struct CanonicalPersistenceCutoverPreparationTests {
    @Test("every known route has a classification")
    func everyKnownRouteHasAClassification() {
        let routes = CanonicalPersistenceCutoverRouteManifest.routes

        #expect(routes.map(\.routeID).sorted { $0.rawValue < $1.rawValue } == CanonicalPersistenceCutoverRouteID.allCases.sorted { $0.rawValue < $1.rawValue })
        #expect(routes.allSatisfy { !$0.classifications.isEmpty })
    }

    @Test("every writer route has a current authority")
    func everyWriterRouteHasCurrentAuthority() {
        let writerRoutes = CanonicalPersistenceCutoverRouteManifest.routes.filter(\.routeID.isWriterRoute)

        #expect(writerRoutes.isEmpty == false)
        #expect(writerRoutes.allSatisfy { $0.currentAuthority != .none })
        #expect(writerRoutes.allSatisfy { route in
            route.classifications.contains(.purchaseOrAllowanceWriterOutsideBaseballPersistence)
            || route.currentAuthority == .legacySwiftData
        })
    }

    @Test("no route is classified as having two active writers")
    func noRouteIsClassifiedAsHavingTwoActiveWriters() {
        let routes = CanonicalPersistenceCutoverRouteManifest.routes

        #expect(routes.allSatisfy { $0.activeProductionWriterCount <= 1 })
        #expect(routes.allSatisfy { $0.proposedFutureAuthority != .proposedPersistenceAuthority || $0.activeProductionWriterCount == 1 })
    }

    @Test("missing schema decision blocks routing")
    func missingSchemaDecisionBlocksRouting() {
        var gates = CanonicalPersistenceCutoverGateSet.allSatisfied
        gates.schemaDecisionComplete = false

        let result = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .teamCreationAndEditing, gates: gates)

        #expect(result.disposition == .requiresSchemaDecision)
        #expect(result.blockingReasons.contains(.schemaDecisionMissing))
        #expect(result.productionRoutingChanged == false)
    }

    @Test("unknown source version blocks routing")
    func unknownSourceVersionBlocksRouting() {
        var gates = CanonicalPersistenceCutoverGateSet.allSatisfied
        gates.sourceVersionKnown = false

        let result = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .gameCreation, gates: gates)

        #expect(result.blockingReasons.contains(.sourceVersionUnknown))
        #expect(result.disposition == .blocked)
    }

    @Test("missing migration progress design blocks migration routing")
    func missingMigrationProgressDesignBlocksMigrationRouting() {
        var gates = CanonicalPersistenceCutoverGateSet.allSatisfied
        gates.migrationProgressDesignComplete = false

        let result = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .compatibilityImports, gates: gates)

        #expect(result.blockingReasons.contains(.migrationProgressDesignMissing))
        #expect(result.disposition == .requiresMigrationDesign)
    }

    @Test("missing rollback or disable path blocks routing")
    func missingRollbackOrDisablePathBlocksRouting() {
        var gates = CanonicalPersistenceCutoverGateSet.allSatisfied
        gates.disablePathDefined = false
        gates.rollbackOrRecoveryDefined = false

        let result = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .teamCreationAndEditing, gates: gates)

        #expect(result.blockingReasons.contains(.disablePathMissing))
        #expect(result.blockingReasons.contains(.rollbackOrRecoveryMissing))
        #expect(result.disposition == .requiresRollbackDesign)
    }

    @Test("missing user review policy blocks ambiguous data routing")
    func missingUserReviewPolicyBlocksAmbiguousDataRouting() {
        var gates = CanonicalPersistenceCutoverGateSet.allSatisfied
        gates.userReviewPolicyResolved = false

        let result = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .substitutions, gates: gates)

        #expect(result.blockingReasons.contains(.userReviewPolicyMissing))
        #expect(result.disposition == .requiresUserReviewDesign)
    }

    @Test("purchase separation failure blocks routing")
    func purchaseSeparationFailureBlocksRouting() {
        var gates = CanonicalPersistenceCutoverGateSet.allSatisfied
        gates.purchaseSeparationVerified = false

        let result = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .gameCreation, gates: gates)

        #expect(result.blockingReasons.contains(.purchaseSeparationFailed))
        #expect(result.disposition == .requiresPurchaseSeparationProof)
    }

    @Test("allowance boundary failure blocks routing")
    func allowanceBoundaryFailureBlocksRouting() {
        var gates = CanonicalPersistenceCutoverGateSet.allSatisfied
        gates.allowanceBoundaryVerified = false

        let result = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .gameCreation, gates: gates)

        #expect(result.blockingReasons.contains(.allowanceBoundaryFailed))
        #expect(result.disposition == .requiresPurchaseSeparationProof)
    }

    @Test("unsupported mapping blocks routing")
    func unsupportedMappingBlocksRouting() {
        var gates = CanonicalPersistenceCutoverGateSet.allSatisfied
        gates.mappingSupported = false

        let result = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .substitutions, gates: gates)

        #expect(result.blockingReasons.contains(.unsupportedMapping))
        #expect(result.disposition == .blocked)
    }

    @Test("unverified relationship or ordering blocks routing")
    func unverifiedRelationshipOrOrderingBlocksRouting() {
        var gates = CanonicalPersistenceCutoverGateSet.allSatisfied
        gates.relationshipVerificationPassed = false
        gates.orderingVerificationPassed = false

        let result = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .lineupChanges, gates: gates)

        #expect(result.blockingReasons.contains(.relationshipVerificationMissing))
        #expect(result.blockingReasons.contains(.orderingVerificationMissing))
        #expect(result.disposition == .blocked)
    }

    @Test("candidate simple route can become ready only when every required gate is satisfied")
    func candidateSimpleRouteCanBecomeReadyOnlyWhenEveryRequiredGateIsSatisfied() {
        let blocked = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(
            routeID: .teamCreationAndEditing,
            gates: .missingProductionDecisions
        )
        let ready = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(
            routeID: .teamCreationAndEditing,
            gates: .allSatisfied
        )

        #expect(blocked.disposition != .readyForBoundedRouting)
        #expect(ready.disposition == .readyForBoundedRouting)
        #expect(ready.blockingReasons.isEmpty)
        #expect(ready.exactlyOneWriterGuaranteed)
    }

    @Test("scoring correction import delete and migration routes remain blocked")
    func highRiskRoutesRemainBlocked() {
        let routes: [CanonicalPersistenceCutoverRouteID] = [
            .scoringEventCreation,
            .correctionPersistence,
            .compatibilityImports,
            .gameDeletion,
            .modelContainerStartup
        ]
        let results = routes.map { CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: $0, gates: .allSatisfied) }

        #expect(results.allSatisfy { $0.disposition != .readyForBoundedRouting })
        #expect(results[0].blockingReasons.contains(.scoringCutoverDeferred))
        #expect(results[1].blockingReasons.contains(.scoringCutoverDeferred))
        #expect(results[2].blockingReasons.contains(.importTooBroad))
        #expect(results[3].blockingReasons.contains(.deleteTooDestructive))
        #expect(results[4].blockingReasons.contains(.migrationDesignMissing))
    }

    @Test("legacy retirement remains blocked")
    func legacyRetirementRemainsBlocked() {
        let result = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(
            routeID: .teamCreationAndEditing,
            gates: .allSatisfied,
            legacyRetirementRequested: true
        )

        #expect(result.blockingReasons.contains(.legacyRetirementBlocked))
        #expect(result.disposition != .readyForBoundedRouting)
    }

    @Test("repeated readiness evaluation is deterministic")
    func repeatedReadinessEvaluationIsDeterministic() {
        let gates = CanonicalPersistenceCutoverGateSet.missingProductionDecisions
        let first = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .gameCreation, gates: gates)
        let second = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .gameCreation, gates: gates)

        #expect(first == second)
    }

    @Test("input values remain unchanged")
    func inputValuesRemainUnchanged() {
        let gates = CanonicalPersistenceCutoverGateSet.missingProductionDecisions
        let before = gates
        _ = CanonicalPersistenceCutoverReadinessEvaluator.evaluate(routeID: .gameCreation, gates: gates)

        #expect(gates == before)
    }

    @Test("no production persistence APIs are used by preparation vocabulary")
    func noProductionPersistenceAPIsAreUsedByPreparationVocabulary() {
        let source = String(describing: CanonicalPersistenceCutoverRouteManifest.routes)
        let forbiddenAPITokens = ["ModelContext", "ModelContainer", "FetchDescriptor", ".save(", ".insert(", ".delete(", "@Model"]

        #expect(forbiddenAPITokens.allSatisfy { source.contains($0) == false })
    }

    @Test("source reference manifest covers known production writers")
    func sourceReferenceManifestCoversKnownProductionWriters() {
        let coveredReferences = Set(CanonicalPersistenceCutoverRouteManifest.routes.flatMap(\.sourceReferences))
        let missing = CanonicalPersistenceCutoverRouteManifest.requiredProductionWriterReferences.subtracting(coveredReferences)

        #expect(missing.isEmpty)
    }
}

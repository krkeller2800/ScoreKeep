import Foundation
import Testing
@testable import ScoreKeep

@Suite("Canonical scoring authority cutover preparation")
struct CanonicalScoringAuthorityCutoverPreparationTests {
    @Test("every production scoring route is inventoried and remains legacy or read-only")
    func everyProductionScoringRouteIsInventoriedAndRemainsLegacyOrReadOnly() {
        let inventory = CanonicalScoringAuthorityPolicy.routeInventory

        #expect(Set(inventory.keys) == Set(CanonicalScoringProductionRouteID.allCases))
        #expect(inventory.values.allSatisfy { $0.currentAuthority != .canonicalCandidate })
        #expect(inventory.values.allSatisfy { $0.futureRoutingEligibility != .canonicalCandidateBlocked || $0.currentAuthority == .legacy })
        #expect(inventory[.statisticsAndReportReads]?.futureRoutingEligibility == .readOnly)
        #expect(inventory[.saveAtbatHistory]?.blockers.contains(.canonicalEventPersistenceAbsent) == true)
    }

    @Test("production authority defaults every scoring request to legacy before mutation")
    func productionAuthorityDefaultsEveryScoringRequestToLegacyBeforeMutation() {
        let decisions = CanonicalScoringProductionRouteID.allCases.map { routeID in
            CanonicalScoringAuthorityPolicy.select(
                CanonicalScoringAuthorityRequest(routeID: routeID, commandFamily: family(for: routeID))
            )
        }

        #expect(decisions.allSatisfy { $0.selectedAuthority == .legacy })
        #expect(decisions.allSatisfy { $0.legacyMutationPermitted })
        #expect(decisions.allSatisfy { $0.canonicalMutationPermitted == false })
        #expect(decisions.allSatisfy { $0.activeWriterCount == 1 })
        #expect(decisions.allSatisfy { $0.routeSelectionImmutable })
        #expect(decisions.allSatisfy { $0.blockingReasons.contains(.productionApprovalAbsent) })
        #expect(decisions.allSatisfy { $0.blockingReasons.contains(.canonicalProductionRouteDisabled) })
    }

    @Test("canonical approval flag alone cannot enable production canonical scoring")
    func canonicalApprovalFlagAloneCannotEnableProductionCanonicalScoring() {
        let decision = CanonicalScoringAuthorityPolicy.select(
            CanonicalScoringAuthorityRequest(
                routeID: .batterReachesBase,
                commandFamily: .batterReachesFirst,
                canonicalApprovalPresent: true
            )
        )

        #expect(CanonicalScoringAuthorityPolicy.productionCanonicalApprovalPresent == false)
        #expect(decision.selectedAuthority == .legacy)
        #expect(decision.canonicalMutationPermitted == false)
        #expect(decision.blockingReasons.contains(.canonicalProductionRouteDisabled))
    }

    @Test("unsupported ambiguity recovery and persistence states fail closed before mutation")
    func unsupportedAmbiguityRecoveryAndPersistenceStatesFailClosedBeforeMutation() {
        let unsupported = CanonicalScoringAuthorityPolicy.select(.init(routeID: .pickoff, commandFamily: .pickoff, commandSupported: false))
        let ambiguous = CanonicalScoringAuthorityPolicy.select(.init(routeID: .thirdOut, commandFamily: .thirdOutTransition, hasAmbiguousEvidence: true))
        let recovery = CanonicalScoringAuthorityPolicy.select(.init(routeID: .runnerThrownOut, commandFamily: .runnerOut, recoveryRequired: true))
        let unavailable = CanonicalScoringAuthorityPolicy.select(.init(routeID: .runnerScores, commandFamily: .runnerScores, persistenceAvailable: false))
        let rejected = CanonicalScoringAuthorityPolicy.select(.init(routeID: .batterOut, commandFamily: .batterOut, validationAccepted: false))

        #expect(unsupported.selectedAuthority == .unsupportedAction)
        #expect(ambiguous.selectedAuthority == .ambiguousEvidence)
        #expect(recovery.selectedAuthority == .recoveryRequired)
        #expect(unavailable.selectedAuthority == .persistenceUnavailable)
        #expect(rejected.selectedAuthority == .rejected)
        #expect([unsupported, ambiguous, recovery, unavailable, rejected].allSatisfy { $0.activeWriterCount == 0 })
        #expect([unsupported, ambiguous, recovery, unavailable, rejected].allSatisfy { $0.canonicalMutationPermitted == false && $0.legacyMutationPermitted == false })
    }

    @Test("simple team routing and migration completion cannot enable scoring")
    func simpleTeamRoutingAndMigrationCompletionCannotEnableScoring() {
        #expect(ScoreKeepProductionStartupRouteApproval.simpleTeamCreationProductionEnabled)

        let decision = CanonicalScoringAuthorityPolicy.select(
            .init(
                routeID: .batterOut,
                commandFamily: .batterOut,
                canonicalApprovalPresent: true,
                persistenceAvailable: true,
                recoveryRequired: false
            )
        )

        #expect(decision.selectedAuthority == .legacy)
        #expect(decision.canonicalMutationPermitted == false)
        #expect(decision.blockingReasons.contains(.canonicalProductionRouteDisabled))
    }

    @Test("one writer assessment rejects dual mutation fallback second save autosave and escaping models")
    func oneWriterAssessmentRejectsDualMutationFallbackSecondSaveAutosaveAndEscapingModels() {
        let legacyOnly = CanonicalScoringOneWriterAssessment(
            authoritySelectedBeforeMutation: true,
            routeSelectionImmutable: true,
            transactionOwnerCount: 1,
            modelContextCount: 1,
            legacyMutationStarted: true,
            canonicalMutationStarted: false,
            fallbackAfterCanonicalMutation: false,
            viewIssuedSecondSave: false,
            autosaveSecondaryCommit: false,
            managedModelsEscapeBoundary: false
        )
        let dual = CanonicalScoringOneWriterAssessment(authoritySelectedBeforeMutation: true, routeSelectionImmutable: true, transactionOwnerCount: 1, modelContextCount: 1, legacyMutationStarted: true, canonicalMutationStarted: true, fallbackAfterCanonicalMutation: false, viewIssuedSecondSave: false, autosaveSecondaryCommit: false, managedModelsEscapeBoundary: false)
        let fallback = CanonicalScoringOneWriterAssessment(authoritySelectedBeforeMutation: true, routeSelectionImmutable: true, transactionOwnerCount: 1, modelContextCount: 1, legacyMutationStarted: false, canonicalMutationStarted: true, fallbackAfterCanonicalMutation: true, viewIssuedSecondSave: false, autosaveSecondaryCommit: false, managedModelsEscapeBoundary: false)
        let secondSave = CanonicalScoringOneWriterAssessment(authoritySelectedBeforeMutation: true, routeSelectionImmutable: true, transactionOwnerCount: 1, modelContextCount: 1, legacyMutationStarted: true, canonicalMutationStarted: false, fallbackAfterCanonicalMutation: false, viewIssuedSecondSave: true, autosaveSecondaryCommit: false, managedModelsEscapeBoundary: false)
        let autosave = CanonicalScoringOneWriterAssessment(authoritySelectedBeforeMutation: true, routeSelectionImmutable: true, transactionOwnerCount: 1, modelContextCount: 1, legacyMutationStarted: true, canonicalMutationStarted: false, fallbackAfterCanonicalMutation: false, viewIssuedSecondSave: false, autosaveSecondaryCommit: true, managedModelsEscapeBoundary: false)
        let escaping = CanonicalScoringOneWriterAssessment(authoritySelectedBeforeMutation: true, routeSelectionImmutable: true, transactionOwnerCount: 1, modelContextCount: 1, legacyMutationStarted: true, canonicalMutationStarted: false, fallbackAfterCanonicalMutation: false, viewIssuedSecondSave: false, autosaveSecondaryCommit: false, managedModelsEscapeBoundary: true)

        #expect(legacyOnly.exactlyOneWriter)
        #expect(legacyOnly.failClosed)
        #expect(dual.exactlyOneWriter == false)
        #expect(dual.failClosed == false)
        #expect(fallback.exactlyOneWriter == false)
        #expect(secondSave.exactlyOneWriter == false)
        #expect(autosave.exactlyOneWriter == false)
        #expect(escaping.exactlyOneWriter == false)
    }

    @Test("readiness matrix classifies every required command family and marks none production eligible")
    func readinessMatrixClassifiesEveryRequiredCommandFamilyAndMarksNoneProductionEligible() {
        let matrix = CanonicalScoringAuthorityPolicy.readinessMatrix

        #expect(Set(matrix.keys) == Set(CanonicalScoringCommandFamily.allCases))
        #expect(matrix.values.allSatisfy { $0.productionRouteEligible == false })
        #expect(matrix.values.allSatisfy { $0.blockedReasons.contains(.productionApprovalAbsent) })
        #expect(matrix.values.allSatisfy { $0.blockedReasons.contains(.canonicalProductionRouteDisabled) })
        #expect(matrix[.ball]?.semantics == .absent)
        #expect(matrix[.batterOut]?.semantics == .complete)
        #expect(matrix[.runnerOut]?.persistenceMapping == .ambiguous)
        #expect(matrix[.correction]?.blockedReasons.contains(.idempotencyPersistenceMissing) == true)
        #expect(matrix[.thirdOutTransition]?.legacyParity == .ambiguousLegacyEvidence)
    }

    @Test("persistence mappings classify exact lossy ambiguous and unsupported fields as blockers")
    func persistenceMappingsClassifyExactLossyAmbiguousAndUnsupportedFieldsAsBlockers() {
        let mappings = CanonicalScoringAuthorityPolicy.persistenceMappings

        #expect(mappings.contains { $0.modelName == "Team" && $0.status == .exact })
        #expect(mappings.contains { $0.modelName == "Atbat" && $0.status == .compatibleLossy })
        #expect(mappings.contains { $0.modelName == "substitution arrays" && $0.status == .ambiguous })
        #expect(mappings.contains { $0.modelName == "canonical scoring events" && $0.status == .unsupported })
        #expect(mappings.allSatisfy { $0.blocker.isEmpty == false })
    }

    @Test("delayed runner out third out gate preserves evidence and blocks invented facts")
    func delayedRunnerOutThirdOutGatePreservesEvidenceAndBlocksInventedFacts() {
        let gate = CanonicalScoringAuthorityPolicy.delayedRunnerOutGate
        let inventedRun = CanonicalScoringDelayedRunnerOutBoundary(
            runnerStableIdentityRetained: true,
            originatingAtbatIdentityRetained: true,
            interveningAtbatOrderRetained: true,
            laterRunnerOutEvidenceRetained: true,
            thirdOutClassificationRetained: true,
            inningBoundaryRetained: true,
            activeBatterCompletionExplicit: true,
            nextBatterEvidencePreserved: true,
            scoreEvidencePreserved: true,
            runValidityAmbiguityExplicit: false,
            inventedRunValidity: true,
            inventedPitcherResponsibility: false,
            inventedSubstitutionTiming: false,
            inventedCompletedAtbatStatus: false,
            inventedNextBatter: false
        )

        #expect(gate.permitsCanonicalProductionRoute)
        #expect(gate.inventedRunValidity == false)
        #expect(gate.inventedPitcherResponsibility == false)
        #expect(gate.inventedSubstitutionTiming == false)
        #expect(gate.inventedCompletedAtbatStatus == false)
        #expect(gate.inventedNextBatter == false)
        #expect(inventedRun.permitsCanonicalProductionRoute == false)
    }

    @Test("diagnostics are privacy safe stable classifications")
    func diagnosticsArePrivacySafeStableClassifications() {
        let decision = CanonicalScoringAuthorityPolicy.select(
            .init(routeID: .runnerThrownOut, commandFamily: .runnerOut, hasAmbiguousEvidence: true)
        )
        let diagnostics = CanonicalScoringAuthorityPolicy.diagnostics(for: decision)
        let fields = diagnostics.privacySafeFields.joined(separator: "|")

        #expect(diagnostics.selectedAuthority == .ambiguousEvidence)
        #expect(diagnostics.commandFamily == .runnerOut)
        #expect(diagnostics.persistenceMappingStatus == .ambiguous)
        #expect(diagnostics.legacyParityStatus == .ambiguousLegacyEvidence)
        #expect(fields.contains("runnerThrownOut") == false)
        #expect(fields.contains("/Volumes/") == false)
        #expect(fields.contains("UUID") == false)
        #expect(fields.contains("Keychain") == false)
        #expect(fields.contains("Receipt") == false)
    }

    @Test("correction preparation blocks duplicate and conflicting production route activation")
    func correctionPreparationBlocksDuplicateAndConflictingProductionRouteActivation() {
        let readiness = try! #require(CanonicalScoringAuthorityPolicy.readinessMatrix[.correction])
        let correctionRoute = try! #require(CanonicalScoringAuthorityPolicy.routeInventory[.correctionOrUndo])
        let decision = CanonicalScoringAuthorityPolicy.select(
            .init(routeID: .correctionOrUndo, commandFamily: .correction, canonicalApprovalPresent: true)
        )

        #expect(readiness.correction == .partial)
        #expect(readiness.idempotency == .partial)
        #expect(readiness.persistenceMapping == .unsupported)
        #expect(readiness.productionRouteEligible == false)
        #expect(correctionRoute.blockers.contains(.idempotencyPersistenceMissing))
        #expect(decision.selectedAuthority == .legacy)
        #expect(decision.canonicalMutationPermitted == false)
    }

    @Test("legacy parity remains non boolean and unresolved cases stay blockers")
    func legacyParityRemainsNonBooleanAndUnresolvedCasesStayBlockers() {
        let outcomes = Set(CanonicalScoringParityStatus.allCases)
        let matrix = CanonicalScoringAuthorityPolicy.readinessMatrix.values

        #expect(outcomes.contains(.match))
        #expect(outcomes.contains(.explainableDifference))
        #expect(outcomes.contains(.ambiguousLegacyEvidence))
        #expect(outcomes.contains(.unsupportedCanonicalMapping))
        #expect(outcomes.contains(.contradiction))
        #expect(outcomes.contains(.mismatchRequiresReview))
        #expect(matrix.contains { $0.legacyParity == .ambiguousLegacyEvidence })
        #expect(matrix.contains { $0.legacyParity == .unsupportedCanonicalMapping })
        #expect(matrix.allSatisfy { $0.productionRouteEligible == false })
    }

    private func family(for routeID: CanonicalScoringProductionRouteID) -> CanonicalScoringCommandFamily {
        switch routeID {
        case .gameStart, .resumeInProgressGame, .saveAtbatHistory:
            return .scoreRecalculation
        case .currentBatterSelection:
            return .batterReachesFirst
        case .pitcherSelectionOrChange:
            return .pitcherChange
        case .ballsAndStrikes:
            return .ball
        case .batterOut:
            return .batterOut
        case .batterReachesBase:
            return .batterReachesFirst
        case .runnerAdvance:
            return .runnerAdvance
        case .runnerScores:
            return .runnerScores
        case .runnerThrownOut:
            return .runnerOut
        case .stolenBaseOrCaughtStealing:
            return .stolenBase
        case .pickoff:
            return .pickoff
        case .hitByPitch:
            return .hitByPitch
        case .sacrifice:
            return .sacrifice
        case .rbiEvidence:
            return .rbi
        case .inningTransition:
            return .inningTransition
        case .thirdOut:
            return .thirdOutTransition
        case .substitution:
            return .playerSubstitution
        case .correctionOrUndo:
            return .correction
        case .scoreRecalculation, .statisticsAndReportReads:
            return .scoreRecalculation
        }
    }
}

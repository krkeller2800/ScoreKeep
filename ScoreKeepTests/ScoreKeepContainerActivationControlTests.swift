import Foundation
import Testing
@testable import ScoreKeep

@Suite("Container activation control")
struct ScoreKeepContainerActivationControlTests {
    @Test("legacy is selected by default and production authorization is absent by default")
    func legacyDefaultAndAbsentAuthorization() {
        #expect(ScoreKeepContainerStartupSelection.currentDefault == .legacyActive)
        #expect(ScoreKeepProductionTransitionAuthorization.absent.isSatisfied == false)
        let selection = ScoreKeepContainerStartupSelector.select(ScoreKeepContainerStartupSelectionInput(disableState: .legacyRouteRequired, migrationAttemptHasBegun: false, authorization: nil, ownershipState: .noOwner))
        #expect(selection.selection == .legacyActive)
        #expect(selection.constructLegacyContainer)
        #expect(selection.constructProposedContainer == false)
    }

    @Test("proposed test authorization requires every gate and conflicting state blocks activation")
    func authorizationRequiresEveryGate() {
        let authorized = ScoreKeepProductionTransitionAuthorization(
            buildSupportsProposedV2: true,
            productionPathLayoutResolved: true,
            capacityPreflightPassed: true,
            protectionPolicyVerifiedOrAccepted: true,
            disableStatePermitsTransition: true,
            noUnresolvedPriorMigration: true,
            sourceClassificationSupported: true,
            sourcePreservationAvailable: true,
            oneWriterOwnershipAvailable: true,
            diagnosticsAndUserOutcomesAvailable: true,
            explicitReleaseAuthorization: true,
            rollbackAndDowngradePolicyAccepted: true
        )
        #expect(authorized.isSatisfied)
        let selected = ScoreKeepContainerStartupSelector.select(ScoreKeepContainerStartupSelectionInput(disableState: .proposedTransitionExplicitlyAuthorized, migrationAttemptHasBegun: false, authorization: authorized, ownershipState: .noOwner))
        #expect(selected.selection == .proposedAuthorizedForTransition)
        #expect(selected.constructLegacyContainer == false)
        #expect(selected.constructProposedContainer)

        let conflict = ScoreKeepContainerStartupSelector.select(ScoreKeepContainerStartupSelectionInput(disableState: .proposedTransitionExplicitlyAuthorized, migrationAttemptHasBegun: false, authorization: authorized, ownershipState: .conflictingOwners))
        #expect(conflict.selection == .unsafe)
        let missingStateAfterAttempt = ScoreKeepContainerStartupSelector.select(ScoreKeepContainerStartupSelectionInput(disableState: nil, migrationAttemptHasBegun: true, authorization: nil, ownershipState: .noOwner))
        #expect(missingStateAfterAttempt.selection == .unsafe)
    }

    @Test("one writer activation control never selects legacy and proposed together")
    func oneWriterVocabularyNeverDualConstructs() {
        for selection in ScoreKeepContainerStartupSelection.allCases {
            let control = ScoreKeepOneWriterActivationControl.control(for: selection)
            #expect(!(control.constructsLegacy && control.constructsProposed))
        }
        let proposed = ScoreKeepOneWriterActivationControl.control(for: .proposedAuthorizedForTransition)
        #expect(proposed.claimsMigrationOwnership)
        #expect(proposed.preservesSourceBeforeOpeningTarget)
        #expect(proposed.keepsBaseballWritesDisabledUntilReadinessPasses)
    }
}

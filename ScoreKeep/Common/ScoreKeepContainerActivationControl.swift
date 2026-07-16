import Foundation

enum ScoreKeepContainerStartupSelection: String, CaseIterable, Hashable, Sendable {
    case legacyActive
    case proposedPreparedButDisabled
    case proposedAuthorizedForTransition
    case proposedActive
    case proposedTemporarilyDisabledAfterActivation
    case recoveryOnly
    case unsafe
    case unknown

    static let currentDefault: ScoreKeepContainerStartupSelection = .legacyActive
}

struct ScoreKeepContainerStartupSelectionInput: Hashable, Sendable {
    let disableState: ScoreKeepSchemaRouteDisableState?
    let migrationAttemptHasBegun: Bool
    let authorization: ScoreKeepProductionTransitionAuthorization?
    let ownershipState: ScoreKeepStartupOwnershipState
}

struct ScoreKeepContainerStartupSelectionResult: Hashable, Sendable {
    let selection: ScoreKeepContainerStartupSelection
    let exactlyOneAuthoritySelected: Bool
    let constructLegacyContainer: Bool
    let constructProposedContainer: Bool
    let diagnosticsCode: String
}

enum ScoreKeepContainerStartupSelector {
    static func select(_ input: ScoreKeepContainerStartupSelectionInput) -> ScoreKeepContainerStartupSelectionResult {
        guard let disableState = input.disableState else {
            let selection: ScoreKeepContainerStartupSelection = input.migrationAttemptHasBegun ? .unsafe : .legacyActive
            return result(selection)
        }
        switch disableState {
        case .legacyRouteRequired:
            return input.migrationAttemptHasBegun ? result(.unsafe) : result(.legacyActive)
        case .proposedTransitionPreparedButDisabled:
            return result(.proposedPreparedButDisabled)
        case .proposedTransitionExplicitlyAuthorized:
            guard input.authorization?.isSatisfied == true else { return result(.unsafe) }
            guard input.ownershipState != .conflictingOwners else { return result(.unsafe) }
            return result(.proposedAuthorizedForTransition)
        case .proposedSchemaActiveButNewWritersDisabled:
            return result(.proposedActive)
        case .proposedTransitionTemporarilyDisabled:
            return result(.proposedTemporarilyDisabledAfterActivation)
        case .recoveryOnly:
            return result(.recoveryOnly)
        case .unsafe, .unknownFutureValue:
            return result(.unsafe)
        }
    }

    private static func result(_ selection: ScoreKeepContainerStartupSelection) -> ScoreKeepContainerStartupSelectionResult {
        let legacy = selection == .legacyActive
        let proposed = selection == .proposedAuthorizedForTransition || selection == .proposedActive
        return ScoreKeepContainerStartupSelectionResult(
            selection: selection,
            exactlyOneAuthoritySelected: legacy != proposed || (!legacy && !proposed),
            constructLegacyContainer: legacy,
            constructProposedContainer: proposed,
            diagnosticsCode: "selection.\(selection.rawValue)"
        )
    }
}

struct ScoreKeepProductionTransitionAuthorization: Hashable, Sendable {
    let buildSupportsProposedV2: Bool
    let productionPathLayoutResolved: Bool
    let capacityPreflightPassed: Bool
    let protectionPolicyVerifiedOrAccepted: Bool
    let disableStatePermitsTransition: Bool
    let noUnresolvedPriorMigration: Bool
    let sourceClassificationSupported: Bool
    let sourcePreservationAvailable: Bool
    let oneWriterOwnershipAvailable: Bool
    let diagnosticsAndUserOutcomesAvailable: Bool
    let explicitReleaseAuthorization: Bool
    let rollbackAndDowngradePolicyAccepted: Bool

    static let absent = ScoreKeepProductionTransitionAuthorization(
        buildSupportsProposedV2: false,
        productionPathLayoutResolved: false,
        capacityPreflightPassed: false,
        protectionPolicyVerifiedOrAccepted: false,
        disableStatePermitsTransition: false,
        noUnresolvedPriorMigration: false,
        sourceClassificationSupported: false,
        sourcePreservationAvailable: false,
        oneWriterOwnershipAvailable: false,
        diagnosticsAndUserOutcomesAvailable: false,
        explicitReleaseAuthorization: false,
        rollbackAndDowngradePolicyAccepted: false
    )

    var isSatisfied: Bool {
        buildSupportsProposedV2 && productionPathLayoutResolved && capacityPreflightPassed && protectionPolicyVerifiedOrAccepted && disableStatePermitsTransition && noUnresolvedPriorMigration && sourceClassificationSupported && sourcePreservationAvailable && oneWriterOwnershipAvailable && diagnosticsAndUserOutcomesAvailable && explicitReleaseAuthorization && rollbackAndDowngradePolicyAccepted
    }
}

enum ScoreKeepOneWriterActivationPath: String, CaseIterable, Hashable, Sendable {
    case legacyPath
    case proposedPath
    case recoveryOnly
    case unsafe
}

struct ScoreKeepOneWriterActivationControl: Hashable, Sendable {
    let path: ScoreKeepOneWriterActivationPath
    let constructsLegacy: Bool
    let constructsProposed: Bool
    let claimsMigrationOwnership: Bool
    let preservesSourceBeforeOpeningTarget: Bool
    let keepsBaseballWritesDisabledUntilReadinessPasses: Bool

    static func control(for selection: ScoreKeepContainerStartupSelection) -> ScoreKeepOneWriterActivationControl {
        switch selection {
        case .legacyActive, .proposedPreparedButDisabled:
            return ScoreKeepOneWriterActivationControl(path: .legacyPath, constructsLegacy: true, constructsProposed: false, claimsMigrationOwnership: false, preservesSourceBeforeOpeningTarget: false, keepsBaseballWritesDisabledUntilReadinessPasses: false)
        case .proposedAuthorizedForTransition, .proposedActive:
            return ScoreKeepOneWriterActivationControl(path: .proposedPath, constructsLegacy: false, constructsProposed: true, claimsMigrationOwnership: true, preservesSourceBeforeOpeningTarget: true, keepsBaseballWritesDisabledUntilReadinessPasses: true)
        case .recoveryOnly, .proposedTemporarilyDisabledAfterActivation:
            return ScoreKeepOneWriterActivationControl(path: .recoveryOnly, constructsLegacy: false, constructsProposed: false, claimsMigrationOwnership: false, preservesSourceBeforeOpeningTarget: false, keepsBaseballWritesDisabledUntilReadinessPasses: true)
        case .unsafe, .unknown:
            return ScoreKeepOneWriterActivationControl(path: .unsafe, constructsLegacy: false, constructsProposed: false, claimsMigrationOwnership: false, preservesSourceBeforeOpeningTarget: false, keepsBaseballWritesDisabledUntilReadinessPasses: true)
        }
    }
}

enum ScoreKeepDowngradeAndReleaseReversionPolicy: String, CaseIterable, Hashable, Sendable {
    case olderBuildCannotBeAssumedToOpenProposedV2
    case codeRollbackAndDataRollbackAreDistinct
    case verifiedBackupRetainedThroughReleaseInterval
    case releaseDisableStopsNewWritersWithoutLegacyReopen
}

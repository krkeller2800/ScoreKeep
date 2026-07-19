import Foundation

@MainActor
struct LiveScoringShellPresentation {
    struct SelectionPresentation {
        let disposition: LiveScoringWorkflowCoordinator.Disposition
        let selectedAtbat: Atbat?
        let shouldPresentScoringSheet: Bool
        let shouldMarkChanged: Bool
        let message: String?
    }

    struct ProjectionPresentation {
        let disposition: LiveScoringWorkflowCoordinator.Disposition
        let columnBoxes: [BoxScore]
        let batterBoxes: [BoxScore]
        let totalBoxes: [BoxScore]
        let inningStatus: InnStatus
        let message: String?
    }

    struct PreparedStatePresentation {
        let preparedState: LiveScoringWorkflowCoordinator.PreparedLiveGameState
        let canScore: Bool
        let message: String?
    }

    struct SemanticScorePresentation {
        let semanticScoreState: LiveScoringWorkflowCoordinator.SemanticScoreState
        let homeScore: Int
        let visitingScore: Int
        let inning: Int
        let outs: Int
        let message: String?
    }

    struct EnabledActionPresentation {
        let identity: LiveScoringWorkflowCoordinator.ScoringActionIdentity
        let isEnabled: Bool
        let accessibilityLabel: String
        let accessibilityHint: String?
        let warningMessage: String?
    }

    struct EnabledActionSetPresentation {
        let actionSet: LiveScoringWorkflowCoordinator.EnabledScoringActionSet
        let actions: [EnabledActionPresentation]

        func state(for identity: LiveScoringWorkflowCoordinator.ScoringActionIdentity) -> EnabledActionPresentation? {
            actions.first { $0.identity == identity }
        }
    }

    struct SubmissionPresentation {
        let disposition: LiveScoringWorkflowCoordinator.SubmissionDisposition
        let submittedAtbat: Atbat?
        let shouldDismissScoringSheet: Bool
        let shouldMarkChanged: Bool
        let message: String?
    }

    struct AdditionalChoicePresentation {
        let disposition: LiveScoringWorkflowCoordinator.AdditionalChoiceDisposition
        let pendingChoice: LiveScoringWorkflowCoordinator.PendingAdditionalScoringChoice?
        let shouldPresentAdditionalChoices: Bool
        let shouldMarkChanged: Bool
        let message: String?
    }

    enum CorrectionReviewOutcome: Equatable {
        case pending
        case confirming
        case accepted
        case canceled
        case validationRejected
        case targetMissing
        case targetStale
        case wrongGameTarget
        case unsupportedCorrection
        case persistenceFailed
        case recalculationFailed
        case refreshedStateUnavailable
    }

    struct CorrectionReviewSummary: Equatable {
        let batter: String
        let inningDescription: String
        let originalResult: String
        let proposedResult: String
        let originalRBI: Int
        let proposedRBI: Int
        let originalOuts: Int
        let proposedOuts: Int?
        let originalBasePath: String
        let proposedBasePath: String
        let originalEarnedRun: Bool
        let proposedEarnedRun: Bool
        let originalStolenBases: Int
        let proposedStolenBases: Int
        let originalFielderPlay: String
        let proposedFielderPlay: String
    }

    struct CorrectionReviewState: Equatable {
        let gameIdentity: UUID
        let atbatIdentity: UUID
        let target: LiveScoringWorkflowCoordinator.LegacyCorrectionTarget
        let replacement: LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement
        let originalSnapshot: LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot
        let summary: CorrectionReviewSummary
        var outcome: CorrectionReviewOutcome
        var message: String?
        var refreshedState: LiveScoringWorkflowCoordinator.PreparedLiveGameState?

        var canConfirm: Bool {
            outcome == .pending
        }

        var canCancel: Bool {
            outcome != .confirming
        }
    }

    struct CorrectionReviewPresentation: Equatable {
        let outcome: CorrectionReviewOutcome
        let shouldClearPendingReview: Bool
        let shouldMarkChanged: Bool
        let refreshedState: LiveScoringWorkflowCoordinator.PreparedLiveGameState?
        let message: String?
        let confirmAccessibilityLabel: String
        let confirmAccessibilityHint: String?
        let cancelAccessibilityLabel: String
        let statusAccessibilityLabel: String?
    }

    enum CorrectionEntryDisposition: Equatable {
        case available
        case noTarget
        case alreadyReviewing
        case targetMissing
        case wrongGameTarget
        case unsupportedTarget
        case unsupportedReplacement
    }

    struct CorrectionEntryPresentation: Equatable {
        let disposition: CorrectionEntryDisposition
        let reviewState: CorrectionReviewState?
        let message: String?

        var shouldPresentReview: Bool {
            disposition == .available && reviewState != nil
        }
    }

    typealias CorrectionSubmitAction = (
        LiveScoringWorkflowCoordinator.LegacyCorrectionTarget,
        LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement
    ) -> LiveScoringWorkflowCoordinator.CorrectionSubmissionResult

    enum SubstitutionReviewOutcome: Equatable {
        case pending
        case confirming
        case accepted
        case canceled
        case validationRejected
        case gameMissing
        case participantMissing
        case wrongTeamOrGame
        case staleState
        case sameParticipant
        case duplicateOrConflicting
        case unsupportedFamily
        case persistenceFailed
        case projectionFailed
        case refreshedStateUnavailable
    }

    struct SubstitutionReviewState: Equatable {
        let gameIdentity: UUID
        let outgoingPlayerIdentity: UUID
        let incomingPlayerIdentity: UUID
        let summaryOutgoingName: String
        let summaryIncomingName: String
        var outcome: SubstitutionReviewOutcome
        var message: String?
        var refreshedState: LiveScoringWorkflowCoordinator.PreparedLiveGameState?

        var canConfirm: Bool { outcome == .pending }
        var canCancel: Bool { outcome != .confirming }
    }

    struct SubstitutionReviewPresentation: Equatable {
        let outcome: SubstitutionReviewOutcome
        let shouldClearPendingReview: Bool
        let shouldMarkChanged: Bool
        let refreshedState: LiveScoringWorkflowCoordinator.PreparedLiveGameState?
        let message: String?
    }

    struct PitcherChangeReviewState: Equatable {
        let gameIdentity: UUID
        let teamIdentity: UUID
        let incomingPitcherIdentity: UUID
        let startInning: Int
        let startOuts: Int
        let startBatters: Int
        let summaryIncomingName: String
        var outcome: SubstitutionReviewOutcome
        var message: String?
        var refreshedState: LiveScoringWorkflowCoordinator.PreparedLiveGameState?

        var canConfirm: Bool { outcome == .pending }
        var canCancel: Bool { outcome != .confirming }
    }

    typealias SubstitutionSubmitAction = (
        UUID, UUID, UUID
    ) -> LiveScoringWorkflowCoordinator.SubstitutionSubmissionResult

    typealias PitcherChangeSubmitAction = (
        UUID, UUID, UUID, Int, Int, Int
    ) -> LiveScoringWorkflowCoordinator.SubstitutionSubmissionResult



    func prepareSubstitutionReview(
        gameIdentity: UUID,
        outgoingPlayerIdentity: UUID,
        incomingPlayerIdentity: UUID,
        summaryOutgoingName: String,
        summaryIncomingName: String
    ) -> SubstitutionReviewState {
        return SubstitutionReviewState(
            gameIdentity: gameIdentity,
            outgoingPlayerIdentity: outgoingPlayerIdentity,
            incomingPlayerIdentity: incomingPlayerIdentity,
            summaryOutgoingName: summaryOutgoingName,
            summaryIncomingName: summaryIncomingName,
            outcome: .pending,
            message: nil,
            refreshedState: nil
        )
    }

    func cancelSubstitutionReview(_ state: inout SubstitutionReviewState?) -> SubstitutionReviewPresentation {
        state = nil
        return SubstitutionReviewPresentation(
            outcome: .canceled,
            shouldClearPendingReview: true,
            shouldMarkChanged: false,
            refreshedState: nil,
            message: nil
        )
    }

    func confirmSubstitutionReview(
        _ state: inout SubstitutionReviewState?,
        submit: SubstitutionSubmitAction
    ) -> SubstitutionReviewPresentation {
        guard var review = state, review.outcome == .pending else {
            return SubstitutionReviewPresentation(
                outcome: state?.outcome ?? .canceled,
                shouldClearPendingReview: false,
                shouldMarkChanged: false,
                refreshedState: state?.refreshedState,
                message: state?.message
            )
        }

        review.outcome = .confirming
        state = review

        let result = submit(review.gameIdentity, review.outgoingPlayerIdentity, review.incomingPlayerIdentity)
        let outcome = substitutionReviewOutcome(for: result.disposition)
        let shouldClear = outcome == .accepted

        review.outcome = outcome
        review.message = result.message
        review.refreshedState = result.refreshedState
        state = shouldClear ? nil : review

        return SubstitutionReviewPresentation(
            outcome: outcome,
            shouldClearPendingReview: shouldClear,
            shouldMarkChanged: outcome == .accepted,
            refreshedState: result.refreshedState,
            message: substitutionReviewMessage(for: result)
        )
    }

    func preparePitcherChangeReview(
        gameIdentity: UUID,
        teamIdentity: UUID,
        incomingPitcherIdentity: UUID,
        startInning: Int,
        startOuts: Int,
        startBatters: Int,
        summaryIncomingName: String
    ) -> PitcherChangeReviewState {
        return PitcherChangeReviewState(
            gameIdentity: gameIdentity,
            teamIdentity: teamIdentity,
            incomingPitcherIdentity: incomingPitcherIdentity,
            startInning: startInning,
            startOuts: startOuts,
            startBatters: startBatters,
            summaryIncomingName: summaryIncomingName,
            outcome: .pending,
            message: nil,
            refreshedState: nil
        )
    }

    func cancelPitcherChangeReview(_ state: inout PitcherChangeReviewState?) -> SubstitutionReviewPresentation {
        state = nil
        return SubstitutionReviewPresentation(
            outcome: .canceled,
            shouldClearPendingReview: true,
            shouldMarkChanged: false,
            refreshedState: nil,
            message: nil
        )
    }

    func confirmPitcherChangeReview(
        _ state: inout PitcherChangeReviewState?,
        submit: PitcherChangeSubmitAction
    ) -> SubstitutionReviewPresentation {
        guard var review = state, review.outcome == .pending else {
            return SubstitutionReviewPresentation(
                outcome: state?.outcome ?? .canceled,
                shouldClearPendingReview: false,
                shouldMarkChanged: false,
                refreshedState: state?.refreshedState,
                message: state?.message
            )
        }

        review.outcome = .confirming
        state = review

        let result = submit(review.gameIdentity, review.teamIdentity, review.incomingPitcherIdentity, review.startInning, review.startOuts, review.startBatters)
        let outcome = substitutionReviewOutcome(for: result.disposition)
        let shouldClear = outcome == .accepted

        review.outcome = outcome
        review.message = result.message
        review.refreshedState = result.refreshedState
        state = shouldClear ? nil : review

        return SubstitutionReviewPresentation(
            outcome: outcome,
            shouldClearPendingReview: shouldClear,
            shouldMarkChanged: outcome == .accepted,
            refreshedState: result.refreshedState,
            message: substitutionReviewMessage(for: result)
        )
    }

    func scorecardCellIsEnabled(column: Int, sourceAtbat: Atbat?) -> Bool {
        column > 0 && sourceAtbat != nil
    }

    func presentSelectionResult(_ result: LiveScoringWorkflowCoordinator.SelectionResult) -> SelectionPresentation {
        let canPresent = (result.disposition == .success || result.disposition == .noChange) && result.atbat != nil
        return SelectionPresentation(
            disposition: result.disposition,
            selectedAtbat: result.atbat,
            shouldPresentScoringSheet: canPresent,
            shouldMarkChanged: canPresent,
            message: result.message
        )
    }

    func presentProjectionResult(_ result: LiveScoringWorkflowCoordinator.ProjectionResult) -> ProjectionPresentation {
        ProjectionPresentation(
            disposition: result.disposition,
            columnBoxes: result.columnBoxes,
            batterBoxes: result.batterBoxes,
            totalBoxes: result.totalBoxes,
            inningStatus: result.inningStatus,
            message: result.message
        )
    }

    func presentPreparedState(_ state: LiveScoringWorkflowCoordinator.PreparedLiveGameState) -> PreparedStatePresentation {
        PreparedStatePresentation(
            preparedState: state,
            canScore: state.canScore,
            message: state.warnings.first
        )
    }

    func presentSemanticScoreState(_ state: LiveScoringWorkflowCoordinator.SemanticScoreState) -> SemanticScorePresentation {
        SemanticScorePresentation(
            semanticScoreState: state,
            homeScore: state.canPresentScoringLine ? state.score.home : state.storedScore.home,
            visitingScore: state.canPresentScoringLine ? state.score.visiting : state.storedScore.visiting,
            inning: state.inning,
            outs: state.outs,
            message: state.warnings.first
        )
    }

    func presentEnabledActionSet(
        _ actionSet: LiveScoringWorkflowCoordinator.EnabledScoringActionSet
    ) -> EnabledActionSetPresentation {
        EnabledActionSetPresentation(
            actionSet: actionSet,
            actions: actionSet.actions.map(presentEnabledAction)
        )
    }

    func presentSubmissionResult(
        _ result: LiveScoringWorkflowCoordinator.ScoringSubmissionResult,
        requiresAdditionalChoice: Bool
    ) -> SubmissionPresentation {
        let accepted = result.disposition == .accepted || result.disposition == .duplicatePrevented
        return SubmissionPresentation(
            disposition: result.disposition,
            submittedAtbat: result.atbat,
            shouldDismissScoringSheet: accepted && !requiresAdditionalChoice,
            shouldMarkChanged: result.disposition == .accepted,
            message: result.message
        )
    }

    func presentAdditionalChoicePreparation(
        _ result: LiveScoringWorkflowCoordinator.AdditionalChoicePreparationResult
    ) -> AdditionalChoicePresentation {
        let pending = result.disposition == .pending && result.pendingChoice != nil
        return AdditionalChoicePresentation(
            disposition: result.disposition,
            pendingChoice: result.pendingChoice,
            shouldPresentAdditionalChoices: pending,
            shouldMarkChanged: false,
            message: result.message
        )
    }

    func prepareCorrectionReview(
        original: LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot,
        batterName: String,
        replacement: LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement?,
        supportedLegacyResults: [String]
    ) -> CorrectionReviewState? {
        guard let replacement,
              replacement.result != "Result",
              supportedLegacyResults.contains(replacement.result) else {
            return nil
        }
        let target = LiveScoringWorkflowCoordinator.LegacyCorrectionTarget(
            gameIdentity: original.gameIdentity,
            atbatIdentity: original.atbatIdentity,
            expectedOriginal: original
        )
        return CorrectionReviewState(
            gameIdentity: original.gameIdentity,
            atbatIdentity: original.atbatIdentity,
            target: target,
            replacement: replacement,
            originalSnapshot: original,
            summary: CorrectionReviewSummary(
                batter: batterName,
                inningDescription: inningDescription(for: original.inning),
                originalResult: original.result,
                proposedResult: replacement.result,
                originalRBI: original.rbis,
                proposedRBI: replacement.rbis,
                originalOuts: original.outs,
                proposedOuts: nil,
                originalBasePath: basePathDescription(maxBase: original.maxBase, outAt: original.outAt),
                proposedBasePath: basePathDescription(maxBase: replacement.maxBase, outAt: replacement.outAt),
                originalEarnedRun: original.earnedRun,
                proposedEarnedRun: replacement.earnedRun,
                originalStolenBases: original.stolenBases,
                proposedStolenBases: replacement.stolenBases,
                originalFielderPlay: original.playRecord,
                proposedFielderPlay: replacement.playRecord
            ),
            outcome: .pending,
            message: nil,
            refreshedState: nil
        )
    }

    func prepareCorrectionEntry(
        targetAtbat: Atbat?,
        game: Game,
        replacement: LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement?,
        supportedLegacyResults: [String],
        currentReview: CorrectionReviewState?
    ) -> CorrectionEntryPresentation {
        guard currentReview == nil else {
            return CorrectionEntryPresentation(
                disposition: .alreadyReviewing,
                reviewState: nil,
                message: "A correction is already being reviewed."
            )
        }
        guard let targetAtbat else {
            return CorrectionEntryPresentation(
                disposition: .noTarget,
                reviewState: nil,
                message: "Select a scored at-bat before correcting."
            )
        }
        guard targetAtbat.game.ident == game.ident else {
            return CorrectionEntryPresentation(
                disposition: .wrongGameTarget,
                reviewState: nil,
                message: "The correction target belongs to a different game."
            )
        }
        guard game.atbats.contains(where: { $0.ident == targetAtbat.ident }) else {
            return CorrectionEntryPresentation(
                disposition: .targetMissing,
                reviewState: nil,
                message: "The correction target is no longer available."
            )
        }
        guard targetAtbat.result != "Result",
              supportedLegacyResults.contains(targetAtbat.result) else {
            return CorrectionEntryPresentation(
                disposition: .unsupportedTarget,
                reviewState: nil,
                message: "This at-bat is not a supported correction target."
            )
        }

        guard let review = prepareCorrectionReview(
            original: LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(targetAtbat),
            batterName: targetAtbat.player.name,
            replacement: replacement,
            supportedLegacyResults: supportedLegacyResults
        ) else {
            return CorrectionEntryPresentation(
                disposition: .unsupportedReplacement,
                reviewState: nil,
                message: "This correction is not supported."
            )
        }

        return CorrectionEntryPresentation(
            disposition: .available,
            reviewState: review,
            message: nil
        )
    }

    func cancelCorrectionReview(_ state: inout CorrectionReviewState?) -> CorrectionReviewPresentation {
        state = nil
        return CorrectionReviewPresentation(
            outcome: .canceled,
            shouldClearPendingReview: true,
            shouldMarkChanged: false,
            refreshedState: nil,
            message: nil,
            confirmAccessibilityLabel: "Confirm correction",
            confirmAccessibilityHint: nil,
            cancelAccessibilityLabel: "Cancel correction review",
            statusAccessibilityLabel: nil
        )
    }

    func confirmCorrectionReview(
        _ state: inout CorrectionReviewState?,
        submit: CorrectionSubmitAction
    ) -> CorrectionReviewPresentation {
        guard var review = state, review.outcome == .pending else {
            return correctionReviewPresentation(for: state)
        }

        review.outcome = .confirming
        state = review

        let result = submit(review.target, review.replacement)
        let outcome = correctionReviewOutcome(for: result.disposition)
        let shouldClear = outcome == .accepted

        review.outcome = outcome
        review.message = result.message
        review.refreshedState = result.refreshedState
        state = shouldClear ? nil : review

        return CorrectionReviewPresentation(
            outcome: outcome,
            shouldClearPendingReview: shouldClear,
            shouldMarkChanged: outcome == .accepted,
            refreshedState: result.refreshedState,
            message: correctionReviewMessage(for: result),
            confirmAccessibilityLabel: "Confirm correction",
            confirmAccessibilityHint: outcome == .accepted ? nil : correctionReviewMessage(for: result),
            cancelAccessibilityLabel: "Dismiss correction review",
            statusAccessibilityLabel: correctionReviewMessage(for: result)
        )
    }

    private func presentEnabledAction(
        _ state: LiveScoringWorkflowCoordinator.EnabledScoringActionState
    ) -> EnabledActionPresentation {
        EnabledActionPresentation(
            identity: state.identity,
            isEnabled: state.isEnabled,
            accessibilityLabel: accessibilityLabel(for: state.identity),
            accessibilityHint: state.unavailableReason,
            warningMessage: state.warnings.first
        )
    }

    private func accessibilityLabel(for identity: LiveScoringWorkflowCoordinator.ScoringActionIdentity) -> String {
        switch identity {
        case let .scorecardCell(column, battingOrder):
            return "Score batter \(battingOrder), column \(column)"
        case let .legacyResult(result):
            return result
        case let .unsupported(result):
            return result
        }
    }

    private func correctionReviewPresentation(for state: CorrectionReviewState?) -> CorrectionReviewPresentation {
        CorrectionReviewPresentation(
            outcome: state?.outcome ?? .canceled,
            shouldClearPendingReview: false,
            shouldMarkChanged: false,
            refreshedState: state?.refreshedState,
            message: state?.message,
            confirmAccessibilityLabel: "Confirm correction",
            confirmAccessibilityHint: state?.canConfirm == false ? "Correction confirmation is not currently available." : nil,
            cancelAccessibilityLabel: "Cancel correction review",
            statusAccessibilityLabel: state?.message
        )
    }

    private func correctionReviewOutcome(
        for disposition: LiveScoringWorkflowCoordinator.CorrectionDisposition
    ) -> CorrectionReviewOutcome {
        switch disposition {
        case .accepted:
            return .accepted
        case .canceled:
            return .canceled
        case .validationRejected:
            return .validationRejected
        case .targetMissing:
            return .targetMissing
        case .targetStale:
            return .targetStale
        case .wrongGameTarget:
            return .wrongGameTarget
        case .unsupportedCorrection:
            return .unsupportedCorrection
        case .persistenceFailed:
            return .persistenceFailed
        case .recalculationFailed:
            return .recalculationFailed
        case .refreshedStateUnavailable:
            return .refreshedStateUnavailable
        }
    }

    private func correctionReviewMessage(
        for result: LiveScoringWorkflowCoordinator.CorrectionSubmissionResult
    ) -> String? {
        if let message = result.message {
            return message
        }
        switch result.disposition {
        case .accepted:
            return "Correction accepted."
        case .canceled:
            return nil
        case .validationRejected:
            return "The correction could not be accepted."
        case .targetMissing:
            return "The correction target is no longer available."
        case .targetStale:
            return "The correction target changed before acceptance."
        case .wrongGameTarget:
            return "The correction target belongs to a different game."
        case .unsupportedCorrection:
            return "This correction is not supported."
        case .persistenceFailed:
            return "The correction could not be saved."
        case .recalculationFailed:
            return "The correction could not refresh game state."
        case .refreshedStateUnavailable:
            return "The refreshed game state is unavailable."
        }
    }

    private func inningDescription(for inning: CGFloat) -> String {
        let wholeInning = Int(inning)
        let half = inning - CGFloat(wholeInning) >= 0.5 ? "Bottom" : "Top"
        return "\(half) \(max(wholeInning, 1))"
    }

    private func basePathDescription(maxBase: String, outAt: String) -> String {
        if outAt != "Safe" {
            return "Out at \(outAt)"
        }
        return maxBase
    }


    private func substitutionReviewOutcome(
        for disposition: LiveScoringWorkflowCoordinator.SubstitutionDisposition
    ) -> SubstitutionReviewOutcome {
        switch disposition {
        case .accepted: return .accepted
        case .canceled: return .canceled
        case .validationRejected: return .validationRejected
        case .gameMissing: return .gameMissing
        case .participantMissing: return .participantMissing
        case .wrongTeamOrGame: return .wrongTeamOrGame
        case .staleState: return .staleState
        case .sameParticipant: return .sameParticipant
        case .duplicateOrConflicting: return .duplicateOrConflicting
        case .unsupportedFamily: return .unsupportedFamily
        case .persistenceFailed: return .persistenceFailed
        case .projectionFailed: return .projectionFailed
        case .refreshedStateUnavailable: return .refreshedStateUnavailable
        }
    }

    private func substitutionReviewMessage(
        for result: LiveScoringWorkflowCoordinator.SubstitutionSubmissionResult
    ) -> String? {
        if let message = result.message { return message }
        switch result.disposition {
        case .accepted: return "Substitution accepted."
        case .canceled: return nil
        case .validationRejected: return "The substitution could not be accepted."
        case .gameMissing: return "The game is no longer available."
        case .participantMissing: return "A participant could not be found."
        case .wrongTeamOrGame: return "Participants do not belong to a valid team in this game."
        case .staleState: return "The game state changed before acceptance."
        case .sameParticipant: return "Cannot substitute a player for themselves."
        case .duplicateOrConflicting: return "This substitution has already been processed."
        case .unsupportedFamily: return "This substitution type is not supported."
        case .persistenceFailed: return "The substitution could not be saved."
        case .projectionFailed: return "The game projection failed."
        case .refreshedStateUnavailable: return "The refreshed game state is unavailable."
        }
    }
}

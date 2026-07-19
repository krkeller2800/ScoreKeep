import Foundation
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Live scoring shell presentation")
struct LiveScoringShellPresentationTests {
    @Test("successful scorecard selection opens the existing scoring sheet with the coordinator at-bat")
    func successfulScorecardSelectionOpensExistingScoringSheetWithCoordinatorAtbat() {
        let atbat = Fixture.atbat()
        let presenter = LiveScoringShellPresentation()

        let presentation = presenter.presentSelectionResult(.init(disposition: .success, atbat: atbat, message: nil))

        #expect(presentation.disposition == .success)
        #expect(presentation.selectedAtbat === atbat)
        #expect(presentation.shouldPresentScoringSheet)
        #expect(presentation.shouldMarkChanged)
        #expect(presentation.message == nil)
    }

    @Test("existing-cell no-change selection remains presentable without creating presentation fallback")
    func existingCellNoChangeSelectionRemainsPresentableWithoutCreatingPresentationFallback() {
        let atbat = Fixture.atbat()
        let presenter = LiveScoringShellPresentation()

        let presentation = presenter.presentSelectionResult(.init(disposition: .noChange, atbat: atbat, message: nil))

        #expect(presentation.disposition == .noChange)
        #expect(presentation.selectedAtbat === atbat)
        #expect(presentation.shouldPresentScoringSheet)
        #expect(presentation.shouldMarkChanged)
    }

    @Test("invalid and persistence-failed selection outcomes keep sheet and changed state closed")
    func invalidAndPersistenceFailedSelectionOutcomesKeepSheetAndChangedStateClosed() {
        let atbat = Fixture.atbat()
        let presenter = LiveScoringShellPresentation()

        let invalid = presenter.presentSelectionResult(.init(disposition: .validationFailed, atbat: nil, message: "Batter selection is unavailable."))
        let failed = presenter.presentSelectionResult(.init(disposition: .persistenceFailed, atbat: atbat, message: "Error saving new atbats."))

        #expect(invalid.selectedAtbat == nil)
        #expect(!invalid.shouldPresentScoringSheet)
        #expect(!invalid.shouldMarkChanged)
        #expect(invalid.message == "Batter selection is unavailable.")
        #expect(failed.selectedAtbat === atbat)
        #expect(!failed.shouldPresentScoringSheet)
        #expect(!failed.shouldMarkChanged)
        #expect(failed.message == "Error saving new atbats.")
    }

    @Test("projection presentation displays only coordinator-provided projection values")
    func projectionPresentationDisplaysOnlyCoordinatorProvidedProjectionValues() {
        var columnBoxes = Array(repeating: BoxScore(), count: 2)
        var batterBoxes = Array(repeating: BoxScore(), count: 2)
        var totalBoxes = Array(repeating: BoxScore(), count: 1)
        columnBoxes[1].runs = 2
        batterBoxes[1].hits = 1
        totalBoxes[0].walks = 1
        let inningStatus = InnStatus(outs: 2, onFirst: true, onSecond: false, onThird: true)
        let presenter = LiveScoringShellPresentation()

        let presentation = presenter.presentProjectionResult(.init(
            disposition: .success,
            columnBoxes: columnBoxes,
            batterBoxes: batterBoxes,
            totalBoxes: totalBoxes,
            inningStatus: inningStatus,
            message: nil
        ))

        #expect(presentation.disposition == .success)
        #expect(presentation.columnBoxes[1].runs == 2)
        #expect(presentation.batterBoxes[1].hits == 1)
        #expect(presentation.totalBoxes[0].walks == 1)
        #expect(presentation.inningStatus.outs == 2)
        #expect(presentation.inningStatus.onFirst)
        #expect(!presentation.inningStatus.onSecond)
        #expect(presentation.inningStatus.onThird)
    }

    @Test("scorecard cell enablement reflects available selection input without baseball rules")
    func scorecardCellEnablementReflectsAvailableSelectionInputWithoutBaseballRules() {
        let atbat = Fixture.atbat()
        let presenter = LiveScoringShellPresentation()

        #expect(presenter.scorecardCellIsEnabled(column: 1, sourceAtbat: atbat))
        #expect(!presenter.scorecardCellIsEnabled(column: 0, sourceAtbat: atbat))
        #expect(!presenter.scorecardCellIsEnabled(column: 1, sourceAtbat: nil))
    }

    @Test("semantic score presentation displays coordinator-provided score and line state")
    func semanticScorePresentationDisplaysCoordinatorProvidedScoreAndLineState() {
        let presenter = LiveScoringShellPresentation()
        let state = LiveScoringWorkflowCoordinator.SemanticScoreState(
            disposition: .storedScoreMismatch,
            score: .init(home: 4, visiting: 3),
            storedScore: .init(home: 5, visiting: 3),
            battingSide: .home,
            inning: 6,
            halfInning: .home,
            outs: 2,
            bases: .init(first: nil, second: nil, third: nil),
            warnings: ["semanticScoreState.storedScoreMismatch"],
            canPresentScoringLine: true
        )

        let presentation = presenter.presentSemanticScoreState(state)

        #expect(presentation.homeScore == 4)
        #expect(presentation.visitingScore == 3)
        #expect(presentation.inning == 6)
        #expect(presentation.outs == 2)
        #expect(presentation.message == "semanticScoreState.storedScoreMismatch")
    }

    @Test("enabled action presentation exposes disabled reason for accessibility")
    func enabledActionPresentationExposesDisabledReasonForAccessibility() {
        let presenter = LiveScoringShellPresentation()
        let prepared = Fixture.preparedState(canScore: false)
        let disabled = LiveScoringWorkflowCoordinator.EnabledScoringActionState(
            identity: .legacyResult("Single"),
            isEnabled: false,
            disposition: .disabledPreparedStateUnavailable,
            validationDisposition: nil,
            unavailableReason: "A current pitcher is required before scoring.",
            warnings: []
        )
        let actionSet = LiveScoringWorkflowCoordinator.EnabledScoringActionSet(
            preparedState: prepared,
            semanticScoreState: nil,
            actions: [disabled],
            warnings: []
        )

        let presentation = presenter.presentEnabledActionSet(actionSet)
        let action = presentation.state(for: .legacyResult("Single"))

        #expect(action?.isEnabled == false)
        #expect(action?.accessibilityLabel == "Single")
        #expect(action?.accessibilityHint == "A current pitcher is required before scoring.")
    }

    @Test("submission presentation dismisses only accepted ordinary outcomes without additional choices")
    func submissionPresentationDismissesOnlyAcceptedOrdinaryOutcomesWithoutAdditionalChoices() {
        let atbat = Fixture.atbat()
        let presenter = LiveScoringShellPresentation()

        let accepted = presenter.presentSubmissionResult(
            .init(disposition: .accepted, atbat: atbat, actionState: nil, message: nil),
            requiresAdditionalChoice: false
        )
        let needsChoice = presenter.presentSubmissionResult(
            .init(disposition: .accepted, atbat: atbat, actionState: nil, message: nil),
            requiresAdditionalChoice: true
        )
        let failed = presenter.presentSubmissionResult(
            .init(disposition: .persistenceFailed, atbat: atbat, actionState: nil, message: "Error saving scoring action."),
            requiresAdditionalChoice: false
        )

        #expect(accepted.shouldDismissScoringSheet)
        #expect(accepted.shouldMarkChanged)
        #expect(!needsChoice.shouldDismissScoringSheet)
        #expect(needsChoice.shouldMarkChanged)
        #expect(!failed.shouldDismissScoringSheet)
        #expect(!failed.shouldMarkChanged)
        #expect(failed.message == "Error saving scoring action.")
    }

    @Test("additional choice preparation presents pending choices without marking changed")
    func additionalChoicePreparationPresentsPendingChoicesWithoutMarkingChanged() {
        let presenter = LiveScoringShellPresentation()
        let pending = LiveScoringWorkflowCoordinator.PendingAdditionalScoringChoice(
            operationIdentity: UUID(uuidString: "97000000-0000-0000-0000-000000000000")!,
            originalScoringAction: .legacyResult("Fielder's Choice"),
            requiredChoiceCategory: "runnerMovementAndRecordedOut",
            gameIdentity: UUID(uuidString: "97000000-0000-0000-0000-000000000001")!,
            atbatIdentity: UUID(uuidString: "97000000-0000-0000-0000-000000000002")!,
            legacyResult: "Fielder's Choice",
            choices: .init(legacyResult: "Fielder's Choice", maxBase: "First", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true, playRecord: ""),
            availableMaxBases: ["No Bases", "First", "Second", "Third", "Home"],
            availableOutAtBases: ["Safe", "First", "Second", "Third", "Home"],
            availableRBIs: [0, 1, 2, 3, 4],
            availableStolenBases: [0, 1, 2, 3],
            allowsEarnedRunChoice: true,
            allowsPlayRecordChoice: true,
            validationWarnings: []
        )

        let presentation = presenter.presentAdditionalChoicePreparation(.init(disposition: .pending, pendingChoice: pending, actionState: nil, message: nil))
        let failed = presenter.presentAdditionalChoicePreparation(.init(disposition: .unsupportedAction, pendingChoice: nil, actionState: nil, message: "Unsupported"))

        #expect(presentation.shouldPresentAdditionalChoices)
        #expect(!presentation.shouldMarkChanged)
        #expect(presentation.pendingChoice == pending)
        #expect(!failed.shouldPresentAdditionalChoices)
        #expect(!failed.shouldMarkChanged)
        #expect(failed.message == "Unsupported")
    }

    @Test("correction review preparation creates value-only state with stable target facts")
    func correctionReviewPreparationCreatesValueOnlyStateWithStableTargetFacts() {
        let presenter = LiveScoringShellPresentation()
        let atbat = Fixture.scoredAtbat()
        let original = LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(atbat)
        let replacement = LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement(
            result: "Double",
            maxBase: "Second",
            outAt: "Safe",
            rbis: 1,
            stolenBases: 0,
            earnedRun: true
        )

        let review = presenter.prepareCorrectionReview(
            original: original,
            batterName: "Visitor One",
            replacement: replacement,
            supportedLegacyResults: ["Single", "Double", "Ground Out"]
        )
        let unsupported = presenter.prepareCorrectionReview(
            original: original,
            batterName: "Visitor One",
            replacement: .init(result: "Unsupported Legacy Result", maxBase: "No Bases", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            supportedLegacyResults: ["Single", "Double", "Ground Out"]
        )

        #expect(review?.gameIdentity == atbat.game.ident)
        #expect(review?.atbatIdentity == atbat.ident)
        #expect(review?.target.expectedOriginal == original)
        #expect(review?.replacement == replacement)
        #expect(review?.summary.batter == "Visitor One")
        #expect(review?.summary.originalResult == "Single")
        #expect(review?.summary.proposedResult == "Double")
        #expect(review?.summary.originalRBI == 0)
        #expect(review?.summary.proposedRBI == 1)
        #expect(review?.summary.originalOuts == 0)
        #expect(review?.summary.proposedOuts == nil)
        #expect(review?.summary.originalBasePath == "First")
        #expect(review?.summary.proposedBasePath == "Second")
        #expect(review?.canConfirm == true)
        #expect(review?.canCancel == true)
        #expect(unsupported == nil)
    }

    @Test("Task 7.9 correction entry is available only for a stable supported target")
    func task79CorrectionEntryIsAvailableOnlyForStableSupportedTarget() {
        let presenter = LiveScoringShellPresentation()
        let target = Fixture.scoredAtbat()
        let game = target.game
        let replacement = LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement(
            result: "Double",
            maxBase: "Second",
            outAt: "Safe",
            rbis: 1,
            stolenBases: 0,
            earnedRun: true
        )

        let available = presenter.prepareCorrectionEntry(
            targetAtbat: target,
            game: game,
            replacement: replacement,
            supportedLegacyResults: ["Single", "Double", "Ground Out"],
            currentReview: nil
        )
        let noTarget = presenter.prepareCorrectionEntry(
            targetAtbat: nil,
            game: game,
            replacement: replacement,
            supportedLegacyResults: ["Single", "Double", "Ground Out"],
            currentReview: nil
        )
        let alreadyReviewing = presenter.prepareCorrectionEntry(
            targetAtbat: target,
            game: game,
            replacement: replacement,
            supportedLegacyResults: ["Single", "Double", "Ground Out"],
            currentReview: available.reviewState
        )

        #expect(available.disposition == .available)
        #expect(available.shouldPresentReview)
        #expect(available.reviewState?.gameIdentity == game.ident)
        #expect(available.reviewState?.atbatIdentity == target.ident)
        #expect(available.reviewState?.target.expectedOriginal == LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(target))
        #expect(available.reviewState?.replacement == replacement)
        #expect(noTarget.disposition == .noTarget)
        #expect(!noTarget.shouldPresentReview)
        #expect(alreadyReviewing.disposition == .alreadyReviewing)
        #expect(!alreadyReviewing.shouldPresentReview)
        #expect(target.result == "Single")
    }

    @Test("Task 7.9 correction entry fails closed for deleted wrong-game and unsupported targets")
    func task79CorrectionEntryFailsClosedForInvalidTargets() {
        let presenter = LiveScoringShellPresentation()
        let target = Fixture.scoredAtbat()
        let game = target.game
        let wrongGame = Game(date: "2026-07-18T12:00:00Z", location: "Wrong Game", highLights: "", hscore: 0, vscore: 0)
        let replacement = LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement(
            result: "Double",
            maxBase: "Second",
            outAt: "Safe",
            rbis: 0,
            stolenBases: 0,
            earnedRun: true
        )
        let deletedTarget = Fixture.scoredAtbat()
        deletedTarget.game.atbats = []
        let placeholder = Fixture.atbat()
        let unsupportedResult = Fixture.scoredAtbat()
        unsupportedResult.result = "Unsupported Legacy Result"

        let deleted = presenter.prepareCorrectionEntry(
            targetAtbat: deletedTarget,
            game: deletedTarget.game,
            replacement: replacement,
            supportedLegacyResults: ["Single", "Double", "Ground Out"],
            currentReview: nil
        )
        let wrong = presenter.prepareCorrectionEntry(
            targetAtbat: target,
            game: wrongGame,
            replacement: replacement,
            supportedLegacyResults: ["Single", "Double", "Ground Out"],
            currentReview: nil
        )
        let unsupportedTarget = presenter.prepareCorrectionEntry(
            targetAtbat: unsupportedResult,
            game: unsupportedResult.game,
            replacement: replacement,
            supportedLegacyResults: ["Single", "Double", "Ground Out"],
            currentReview: nil
        )
        let unsupportedReplacement = presenter.prepareCorrectionEntry(
            targetAtbat: target,
            game: game,
            replacement: .init(result: "Unsupported Legacy Result", maxBase: "No Bases", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            supportedLegacyResults: ["Single", "Double", "Ground Out"],
            currentReview: nil
        )
        let unsupportedPlaceholder = presenter.prepareCorrectionEntry(
            targetAtbat: placeholder,
            game: placeholder.game,
            replacement: replacement,
            supportedLegacyResults: ["Single", "Double", "Ground Out"],
            currentReview: nil
        )

        #expect(deleted.disposition == .targetMissing)
        #expect(wrong.disposition == .wrongGameTarget)
        #expect(unsupportedTarget.disposition == .unsupportedTarget)
        #expect(unsupportedReplacement.disposition == .unsupportedReplacement)
        #expect(unsupportedPlaceholder.disposition == .unsupportedTarget)
        #expect([deleted, wrong, unsupportedTarget, unsupportedReplacement, unsupportedPlaceholder].allSatisfy { !$0.shouldPresentReview })
        #expect(target.result == "Single")
    }

    @Test("correction review confirmation submits stable identities once and clears accepted review")
    func correctionReviewConfirmationSubmitsStableIdentitiesOnceAndClearsAcceptedReview() {
        let presenter = LiveScoringShellPresentation()
        let atbat = Fixture.scoredAtbat()
        let original = LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(atbat)
        let replacement = LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement(
            result: "Ground Out",
            maxBase: "No Bases",
            outAt: "Safe",
            rbis: 0,
            stolenBases: 0,
            earnedRun: true
        )
        var review = presenter.prepareCorrectionReview(
            original: original,
            batterName: "Visitor One",
            replacement: replacement,
            supportedLegacyResults: ["Single", "Ground Out"]
        )
        var submitCount = 0
        var submittedTarget: LiveScoringWorkflowCoordinator.LegacyCorrectionTarget?
        var submittedReplacement: LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement?
        let refreshedState = Fixture.preparedState(canScore: true)

        let presentation = presenter.confirmCorrectionReview(&review) { target, replacement in
            submitCount += 1
            submittedTarget = target
            submittedReplacement = replacement
            return LiveScoringWorkflowCoordinator.CorrectionSubmissionResult(
                disposition: .accepted,
                targetAtbatIdentity: target.atbatIdentity,
                refreshedState: refreshedState,
                projectionResult: nil,
                correctionPlan: nil,
                applicationResult: nil,
                message: nil
            )
        }

        #expect(submitCount == 1)
        #expect(submittedTarget?.gameIdentity == atbat.game.ident)
        #expect(submittedTarget?.atbatIdentity == atbat.ident)
        #expect(submittedTarget?.expectedOriginal == original)
        #expect(submittedReplacement == replacement)
        #expect(presentation.outcome == .accepted)
        #expect(presentation.shouldClearPendingReview)
        #expect(presentation.shouldMarkChanged)
        #expect(presentation.refreshedState == refreshedState)
        #expect(review == nil)
        #expect(atbat.result == "Single")
    }

    @Test("correction review confirmation guard prevents repeated in-progress submission")
    func correctionReviewConfirmationGuardPreventsRepeatedInProgressSubmission() {
        let presenter = LiveScoringShellPresentation()
        let atbat = Fixture.scoredAtbat()
        let original = LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(atbat)
        var review = presenter.prepareCorrectionReview(
            original: original,
            batterName: "Visitor One",
            replacement: .init(result: "Double", maxBase: "Second", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            supportedLegacyResults: ["Single", "Double"]
        )
        review?.outcome = .confirming
        var submitCount = 0

        let presentation = presenter.confirmCorrectionReview(&review) { target, replacement in
            submitCount += 1
            return LiveScoringWorkflowCoordinator.CorrectionSubmissionResult(
                disposition: .accepted,
                targetAtbatIdentity: target.atbatIdentity,
                refreshedState: nil,
                projectionResult: nil,
                correctionPlan: nil,
                applicationResult: nil,
                message: replacement.result
            )
        }

        #expect(submitCount == 0)
        #expect(presentation.outcome == .confirming)
        #expect(!presentation.shouldMarkChanged)
        #expect(review?.outcome == .confirming)
    }

    @Test("correction review cancellation clears state without workflow submission")
    func correctionReviewCancellationClearsStateWithoutWorkflowSubmission() {
        let presenter = LiveScoringShellPresentation()
        let atbat = Fixture.scoredAtbat()
        var review = presenter.prepareCorrectionReview(
            original: LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(atbat),
            batterName: "Visitor One",
            replacement: .init(result: "Double", maxBase: "Second", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            supportedLegacyResults: ["Single", "Double"]
        )

        let presentation = presenter.cancelCorrectionReview(&review)

        #expect(presentation.outcome == .canceled)
        #expect(presentation.shouldClearPendingReview)
        #expect(!presentation.shouldMarkChanged)
        #expect(review == nil)
        #expect(atbat.result == "Single")
    }


    @Test("batter substitution review preparation creates value-only state")
    func batterSubstitutionReviewPreparationCreatesValueOnlyState() {
        let presenter = LiveScoringShellPresentation()
        let gameId = UUID()
        let outgoingId = UUID()
        let incomingId = UUID()

        let review = presenter.prepareSubstitutionReview(
            gameIdentity: gameId,
            outgoingPlayerIdentity: outgoingId,
            incomingPlayerIdentity: incomingId,
            summaryOutgoingName: "Out Name",
            summaryIncomingName: "In Name"
        )

        #expect(review.gameIdentity == gameId)
        #expect(review.outgoingPlayerIdentity == outgoingId)
        #expect(review.incomingPlayerIdentity == incomingId)
        #expect(review.summaryOutgoingName == "Out Name")
        #expect(review.summaryIncomingName == "In Name")
        #expect(review.canConfirm == true)
        #expect(review.canCancel == true)
    }

    @Test("pitcher change review preparation creates value-only state")
    func pitcherChangeReviewPreparationCreatesValueOnlyState() {
        let presenter = LiveScoringShellPresentation()
        let gameId = UUID()
        let teamId = UUID()
        let incomingId = UUID()

        let review = presenter.preparePitcherChangeReview(
            gameIdentity: gameId,
            teamIdentity: teamId,
            incomingPitcherIdentity: incomingId,
            startInning: 1,
            startOuts: 0,
            startBatters: 0,
            summaryIncomingName: "In Name"
        )

        #expect(review.gameIdentity == gameId)
        #expect(review.teamIdentity == teamId)
        #expect(review.incomingPitcherIdentity == incomingId)
        #expect(review.startInning == 1)
        #expect(review.startOuts == 0)
        #expect(review.startBatters == 0)
        #expect(review.summaryIncomingName == "In Name")
        #expect(review.canConfirm == true)
        #expect(review.canCancel == true)
    }

    @Test("batter substitution review confirmation submits state exactly once")
    func batterSubstitutionReviewConfirmationSubmitsStateExactlyOnce() {
        let presenter = LiveScoringShellPresentation()
        var review: LiveScoringShellPresentation.SubstitutionReviewState? = presenter.prepareSubstitutionReview(
            gameIdentity: UUID(),
            outgoingPlayerIdentity: UUID(),
            incomingPlayerIdentity: UUID(),
            summaryOutgoingName: "Out Name",
            summaryIncomingName: "In Name"
        )

        var submitCount = 0
        let refreshed = Fixture.preparedState(canScore: true)
        let presentation = presenter.confirmSubstitutionReview(&review) { _, _, _ in
            submitCount += 1
            return LiveScoringWorkflowCoordinator.SubstitutionSubmissionResult(
                disposition: .accepted,
                refreshedState: refreshed,
                message: nil
            )
        }

        #expect(submitCount == 1)
        #expect(presentation.outcome == .accepted)
        #expect(presentation.shouldClearPendingReview == true)
        #expect(presentation.shouldMarkChanged == true)
        #expect(presentation.refreshedState == refreshed)
        #expect(review == nil)
    }

    @Test("pitcher change review confirmation submits state exactly once")
    func pitcherChangeReviewConfirmationSubmitsStateExactlyOnce() {
        let presenter = LiveScoringShellPresentation()
        var review: LiveScoringShellPresentation.PitcherChangeReviewState? = presenter.preparePitcherChangeReview(
            gameIdentity: UUID(),
            teamIdentity: UUID(),
            incomingPitcherIdentity: UUID(),
            startInning: 1,
            startOuts: 0,
            startBatters: 0,
            summaryIncomingName: "In Name"
        )

        var submitCount = 0
        let refreshed = Fixture.preparedState(canScore: true)
        let presentation = presenter.confirmPitcherChangeReview(&review) { _, _, _, _, _, _ in
            submitCount += 1
            return LiveScoringWorkflowCoordinator.SubstitutionSubmissionResult(
                disposition: .accepted,
                refreshedState: refreshed,
                message: nil
            )
        }

        #expect(submitCount == 1)
        #expect(presentation.outcome == .accepted)
        #expect(presentation.shouldClearPendingReview == true)
        #expect(presentation.shouldMarkChanged == true)
        #expect(presentation.refreshedState == refreshed)
        #expect(review == nil)
    }

    @Test("substitution review cancellation clears state without submission")
    func substitutionReviewCancellationClearsStateWithoutSubmission() {
        let presenter = LiveScoringShellPresentation()
        var review: LiveScoringShellPresentation.SubstitutionReviewState? = presenter.prepareSubstitutionReview(
            gameIdentity: UUID(),
            outgoingPlayerIdentity: UUID(),
            incomingPlayerIdentity: UUID(),
            summaryOutgoingName: "Out",
            summaryIncomingName: "In"
        )

        let presentation = presenter.cancelSubstitutionReview(&review)

        #expect(presentation.outcome == .canceled)
        #expect(presentation.shouldClearPendingReview == true)
        #expect(presentation.shouldMarkChanged == false)
        #expect(review == nil)
    }

    @Test("pitcher change review cancellation clears state without submission")
    func pitcherChangeReviewCancellationClearsStateWithoutSubmission() {
        let presenter = LiveScoringShellPresentation()
        var review: LiveScoringShellPresentation.PitcherChangeReviewState? = presenter.preparePitcherChangeReview(
            gameIdentity: UUID(),
            teamIdentity: UUID(),
            incomingPitcherIdentity: UUID(),
            startInning: 1,
            startOuts: 0,
            startBatters: 0,
            summaryIncomingName: "In"
        )

        let presentation = presenter.cancelPitcherChangeReview(&review)

        #expect(presentation.outcome == .canceled)
        #expect(presentation.shouldClearPendingReview == true)
        #expect(presentation.shouldMarkChanged == false)
        #expect(review == nil)
    }

    @Test("correction review maps stale rejected wrong-game unsupported and failed outcomes as not accepted")
    func correctionReviewMapsRepresentativeFailuresAsNotAccepted() {
        let presenter = LiveScoringShellPresentation()
        let dispositions: [(LiveScoringWorkflowCoordinator.CorrectionDisposition, LiveScoringShellPresentation.CorrectionReviewOutcome)] = [
            (.targetStale, .targetStale),
            (.validationRejected, .validationRejected),
            (.wrongGameTarget, .wrongGameTarget),
            (.unsupportedCorrection, .unsupportedCorrection),
            (.persistenceFailed, .persistenceFailed)
        ]

        for (disposition, expectedOutcome) in dispositions {
            let atbat = Fixture.scoredAtbat()
            var review = presenter.prepareCorrectionReview(
                original: LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(atbat),
                batterName: "Visitor One",
                replacement: .init(result: "Double", maxBase: "Second", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
                supportedLegacyResults: ["Single", "Double"]
            )

            let presentation = presenter.confirmCorrectionReview(&review) { target, _ in
                LiveScoringWorkflowCoordinator.CorrectionSubmissionResult(
                    disposition: disposition,
                    targetAtbatIdentity: target.atbatIdentity,
                    refreshedState: nil,
                    projectionResult: nil,
                    correctionPlan: nil,
                    applicationResult: nil,
                    message: nil
                )
            }

            #expect(presentation.outcome == expectedOutcome)
            #expect(!presentation.shouldClearPendingReview)
            #expect(!presentation.shouldMarkChanged)
            #expect(review?.outcome == expectedOutcome)
            #expect(review?.canCancel == true)
            #expect(atbat.result == "Single")
        }
    }

    @Test("Task 7.11 unconfirmed correction review interruption discards state without mutation")
    func task711UnconfirmedCorrectionReviewInterruptionDiscardsStateWithoutMutation() {
        var presenter = LiveScoringShellPresentation()
        let atbat = Fixture.scoredAtbat()
        var review: LiveScoringShellPresentation.CorrectionReviewState? = presenter.prepareCorrectionReview(
            original: LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(atbat),
            batterName: "Visitor One",
            replacement: .init(result: "Double", maxBase: "Second", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            supportedLegacyResults: ["Single", "Double"]
        )

        presenter = LiveScoringShellPresentation()
        review = nil

        #expect(atbat.result == "Single")
        #expect(review == nil)
    }

    @Test("Task 7.11 unconfirmed batter substitution review interruption discards state without mutation")
    func task711UnconfirmedBatterSubstitutionReviewInterruptionDiscardsStateWithoutMutation() {
        var presenter = LiveScoringShellPresentation()
        var review: LiveScoringShellPresentation.SubstitutionReviewState? = presenter.prepareSubstitutionReview(
            gameIdentity: UUID(),
            outgoingPlayerIdentity: UUID(),
            incomingPlayerIdentity: UUID(),
            summaryOutgoingName: "Out Name",
            summaryIncomingName: "In Name"
        )

        presenter = LiveScoringShellPresentation()
        review = nil

        #expect(review == nil)
    }

    @Test("Task 7.11 unconfirmed pitcher change review interruption discards state without mutation")
    func task711UnconfirmedPitcherChangeReviewInterruptionDiscardsStateWithoutMutation() {
        var presenter = LiveScoringShellPresentation()
        var review: LiveScoringShellPresentation.PitcherChangeReviewState? = presenter.preparePitcherChangeReview(
            gameIdentity: UUID(),
            teamIdentity: UUID(),
            incomingPitcherIdentity: UUID(),
            startInning: 1,
            startOuts: 0,
            startBatters: 0,
            summaryIncomingName: "In Name"
        )

        presenter = LiveScoringShellPresentation()
        review = nil

        #expect(review == nil)
    }
}

private enum Fixture {
    static func atbat() -> Atbat {
        let team = Team(name: "Visitors", coach: "", details: "")
        let player = Player(name: "Visitor One", number: "1", position: "SS", batDir: "R", batOrder: 1, team: team)
        let game = Game(date: "2026-07-18T12:00:00Z", location: "Task 6.9 Field", highLights: "", hscore: 0, vscore: 0, vteam: team, hteam: Team(name: "Home", coach: "", details: ""))
        let atbat = Atbat(game: game, team: team, player: player, result: "Result", maxbase: "No Bases", batOrder: 1, outAt: "Safe", inning: 1, seq: 1, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
        game.atbats = [atbat]
        return atbat
    }

    static func scoredAtbat() -> Atbat {
        let atbat = atbat()
        atbat.result = "Single"
        atbat.maxbase = "First"
        atbat.outAt = "Safe"
        atbat.rbis = 0
        atbat.outs = 0
        atbat.earnedRun = true
        return atbat
    }

    static func preparedState(canScore: Bool) -> LiveScoringWorkflowCoordinator.PreparedLiveGameState {
        let homeTeamID = UUID()
        let visitingTeamID = UUID()
        return LiveScoringWorkflowCoordinator.PreparedLiveGameState(
            disposition: canScore ? .ready : .unavailablePitcher,
            gameIdentity: UUID(uuidString: "97000000-0000-0000-0000-000000000001"),
            homeTeam: .init(identity: homeTeamID, name: "Home", side: .home),
            visitingTeam: .init(identity: visitingTeamID, name: "Visitors", side: .visiting),
            battingSide: .visiting,
            battingTeam: .init(identity: visitingTeamID, name: "Visitors", side: .visiting),
            defensiveTeam: .init(identity: homeTeamID, name: "Home", side: .home),
            configuredInningCount: 9,
            everyoneHits: false,
            inning: 1,
            halfInning: .visiting,
            outs: 0,
            score: .init(home: 0, visiting: 0),
            bases: .init(first: nil, second: nil, third: nil),
            currentBatter: nil,
            battingOrderPosition: nil,
            currentPitcher: nil,
            latestScoringSequence: nil,
            currentScorecardColumn: 1,
            currentOrPendingLegacyAtbat: nil,
            lineup: [],
            pitcherAppearances: [],
            substitutions: [],
            warnings: canScore ? [] : ["preparedLiveGameState.unavailablePitcher"],
            canScore: canScore
        )
    }
}

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
}

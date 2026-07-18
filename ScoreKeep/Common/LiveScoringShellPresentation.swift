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
}

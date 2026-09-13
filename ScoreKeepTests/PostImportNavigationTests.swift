import Testing
@testable import ScoreKeep

@Suite("Post-import navigation")
struct PostImportNavigationTests {
    @Test("only successful game imports return to the normal Games navigation")
    func onlySuccessfulGameImportsReturnToNormalGamesNavigation() {
        #expect(ImportFlowCompletionPolicy.returnsToGamesAfterSuccessfulImport(fileType: "ScoreKeep_Games"))
        #expect(ImportFlowCompletionPolicy.returnsToGamesAfterSuccessfulImport(fileType: "Team.ScoreKeep_Games"))
        #expect(!ImportFlowCompletionPolicy.returnsToGamesAfterSuccessfulImport(fileType: "ScoreKeep_Players"))
        #expect(!ImportFlowCompletionPolicy.returnsToGamesAfterSuccessfulImport(fileType: ""))
    }
}

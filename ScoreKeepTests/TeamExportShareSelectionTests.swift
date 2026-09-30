import Foundation
import Testing
@testable import ScoreKeep

@Suite("Team export share selection")
struct TeamExportShareSelectionTests {
    @Test("Deselected team cannot expose a stale export")
    func deselectedTeamCannotExposeStaleExport() {
        let previousURL = URL(fileURLWithPath: "/tmp/previous.ScoreKeep_Players")

        #expect(TeamExportShareSelection(team: nil, url: previousURL)?.url == nil)
    }

    @Test("Selected team exposes its generated export")
    func selectedTeamExposesGeneratedExport() {
        let team = Team(name: "Tigers", coach: "", details: "")
        let url = URL(fileURLWithPath: "/tmp/Tigers.ScoreKeep_Players")

        let selection = TeamExportShareSelection(team: team, url: url)

        #expect(selection?.url == url)
        #expect(selection?.teamName == "Tigers")
        #expect(TeamExportShareSelection(team: team, url: nil)?.url == nil)
    }
}

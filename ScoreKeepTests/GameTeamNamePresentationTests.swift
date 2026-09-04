import Testing
@testable import ScoreKeep

struct GameTeamNamePresentationTests {
    @Test("Games list prefers one-line team names before fallback")
    func gamesListPrefersOneLineTeamNamesBeforeFallback() {
        #expect(GameTeamNamePresentation.preferredLineCount == 1)
        #expect(GameTeamNamePresentation.maximumLineCount == 2)
        #expect(GameTeamNamePresentation.minimumScaleFactor == 0.75)
        #expect(GameTeamNamePresentation.allowsTailTruncation == false)
    }

    @Test("Pirates remains a one-line team-name candidate")
    func piratesRemainsOneLineTeamNameCandidate() {
        #expect(GameTeamNamePresentation.preferredLines(for: "Pirates") == ["Pirates"])
        #expect(GameTeamNamePresentation.fallbackLines(for: "Pirates") == ["Pirates"])
    }

    @Test("Royals remains a one-line team-name candidate")
    func royalsRemainsOneLineTeamNameCandidate() {
        #expect(GameTeamNamePresentation.preferredLines(for: "Royals") == ["Royals"])
        #expect(GameTeamNamePresentation.fallbackLines(for: "Royals") == ["Royals"])
    }

    @Test("Guardians fallback preserves the complete source name without ellipsis")
    func guardiansFallbackPreservesCompleteSourceNameWithoutEllipsis() {
        let lines = GameTeamNamePresentation.fallbackLines(for: "Guardians")

        #expect(lines.count == GameTeamNamePresentation.maximumLineCount)
        #expect(lines.joined() == "Guardians")
        #expect(lines.allSatisfy { !$0.contains("...") && !$0.contains("…") })
    }

    @Test("spaced team-name fallback preserves complete source words")
    func spacedTeamNameFallbackPreservesCompleteSourceWords() {
        let lines = GameTeamNamePresentation.fallbackLines(for: "Blue Jays")

        #expect(lines == ["Blue", "Jays"])
        #expect(lines.joined(separator: " ") == "Blue Jays")
    }

    @Test("home and away team-name columns share one presentation contract")
    func homeAndAwayTeamNameColumnsShareOnePresentationContract() {
        let awayLines = GameTeamNamePresentation.preferredLines(for: "Pirates")
        let homeLines = GameTeamNamePresentation.preferredLines(for: "Royals")

        #expect(awayLines.count == GameTeamNamePresentation.preferredLineCount)
        #expect(homeLines.count == GameTeamNamePresentation.preferredLineCount)
        #expect(GameTeamNamePresentation.fallbackLines(for: "Guardians").joined() == "Guardians")
    }
}

import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalScoringCommandTests {
    @Test func supportedCommandFamiliesComeFromRepositoryEvidence() {
        let supported = [
            "Single", "Double", "Triple", "Home Run", "Walk", "Hit By Pitch", "Dropped 3rd Strike",
            "Catcher Interference", "Fielder's Choice", "Error", "Ground Out", "Fly Out", "Line Out",
            "Foul Out", "Strikeout", "Strikeout Looking", "Sacrifice Fly", "Sacrifice Bunt"
        ]

        for raw in supported {
            if case .supported = CanonicalScoringCommandVocabulary.legacyResultDisposition(rawValue: raw) {
                #expect(true)
            } else {
                Issue.record("Expected supported command for \(raw)")
            }
        }
    }

    @Test func commandIdentityDoesNotDependOnUILabelTextAndEquivalentInputIsEqual() {
        let batter = ScoringCommandTestSupport.batter()
        let first = CanonicalScoringCommandVocabulary.command(
            rawResult: "Single",
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .visiting,
            batter: batter,
            source: .scoringView
        )
        let second = CanonicalScoringCommand(
            intent: .batterReaches(destination: .first, result: .batterReachesBase(rawValue: "Single")),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .visiting,
            batter: batter,
            rawLegacyEvidence: ["Single"],
            source: .scoringView
        )

        #expect(first == second)
        #expect(String(describing: first.intent).contains("On Base") == false)
        #expect(String(describing: first.intent).contains("Batting Out") == false)
    }

    @Test func unsupportedUnknownAmbiguousAndContradictoryLegacyValuesStayDistinct() {
        #expect(CanonicalScoringCommandVocabulary.legacyResultDisposition(rawValue: "Sacrifise Fly") == .recognizedUnsupported(rawValue: "Sacrifise Fly"))
        #expect(CanonicalScoringCommandVocabulary.legacyResultDisposition(rawValue: "??") == .unknownRaw(rawValue: "??"))
        #expect(CanonicalScoringCommandVocabulary.legacyResultDisposition(rawValue: "Moon Shot") == .unsupported(rawValue: "Moon Shot"))

        let ambiguous = CanonicalScoringCommandLegacyDisposition.ambiguous(
            rawValue: "Safe",
            candidates: [.runnerAdvances(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .second, stolenBase: false)]
        )
        let contradictory = CanonicalScoringCommandLegacyDisposition.contradictory(rawValues: ["Single", "Ground Out"])

        #expect(ambiguous.rawValue == "Safe")
        #expect(contradictory.rawValue == "Ground Out|Single")
    }

    @Test func repeatedConstructionIsDeterministic() {
        let first = CanonicalScoringCommandVocabulary.command(
            rawResult: "Walk",
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .home,
            batter: ScoringCommandTestSupport.batter(side: .home)
        )
        let second = CanonicalScoringCommandVocabulary.command(
            rawResult: "Walk",
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .home,
            batter: ScoringCommandTestSupport.batter(side: .home)
        )

        #expect(first == second)
        #expect(first.proposedEventIdentity == .missing)
    }
}

enum ScoringCommandTestSupport {
    static let eventID = StableIdentityAndOrderingTestSupport.fixedUUID("92000000-0000-0000-0000-000000000001")
    static let runnerA = CanonicalGameStatePrimitivesTestSupport.runner(id: CanonicalGameStatePrimitivesTestSupport.participantB, name: "Runner A")
    static let runnerB = CanonicalGameStatePrimitivesTestSupport.runner(id: CanonicalGameStatePrimitivesTestSupport.participantC, name: "Runner B")

    static func batter(side: TeamSideRole = .visiting, id: UUID = CanonicalGameStatePrimitivesTestSupport.participantA) -> LineupParticipantEvidence {
        .gameParticipant(participant(side: side, id: id, name: "Fixture Batter"))
    }

    static func participant(side: TeamSideRole = .visiting, id: UUID, name: String) -> GamePlayerParticipation {
        let team = ReusableCanonicalTeam(identity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID(side == .visiting ? "93000000-0000-0000-0000-000000000001" : "93000000-0000-0000-0000-000000000002")), display: TeamDisplayEvidence(name: .present(side == .visiting ? "Visitors" : "Home")))
        return GamePlayerParticipation(
            participantIdentity: .valid(id),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            playerResolution: .reusablePlayer(CanonicalGameStatePrimitivesTestSupport.player(id: id, name: name)),
            teamEvidence: .gameSide(GameSideTeamParticipation(gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), role: side, resolution: .reusableTeam(team))),
            historicalDisplay: PlayerDisplayEvidence(name: .present(name)),
            roles: [.batter],
            source: .historicalGameParticipation
        )
    }

    static func state(
        game: CanonicalGameIdentity = CanonicalGameStatePrimitivesTestSupport.game(lifecycle: .inProgress),
        side: TeamSideRole = .visiting,
        inning: CanonicalHalfInning? = CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(7)),
        outs: Int = 0,
        occupancy: CanonicalBaseOccupancy = CanonicalBaseOccupancy(),
        count: BallStrikeCountEvidence = .unsupportedRepositoryEvidence,
        score: CanonicalProjectedScore = CanonicalProjectedScore(),
        batter: LineupParticipantEvidence? = batter(),
        lineup: [LineupParticipantEvidence] = [batter()],
        pitcher: CanonicalPitcherResponsibilityEvidence? = pitcherResponsibility()
    ) -> CanonicalScoringCommandInputState {
        CanonicalScoringCommandInputState(
            game: game,
            battingSide: side,
            inning: inning,
            outs: CanonicalOutsState(outs: .known(outs)),
            baseOccupancy: occupancy,
            count: count,
            score: score,
            currentBatter: batter,
            lineupParticipants: lineup,
            pitcherResponsibility: pitcher
        )
    }

    static func pitcherResponsibility() -> CanonicalPitcherResponsibilityEvidence {
        let appearance = CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("94000000-0000-0000-0000-000000000001")),
            reusablePitcherIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("94000000-0000-0000-0000-000000000002")),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .home,
            appearanceOrder: .init(kind: .pitcherAppearance, value: 1),
            roleEvidence: [.activePitcher],
            source: .syntheticVerification
        )
        return CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .missing,
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .home,
            responsibility: .explicitPitcher(appearance),
            source: .syntheticVerification
        )
    }

    static func occupancy(_ states: [RunnerStateEvidence]) -> CanonicalBaseOccupancy {
        CanonicalBaseOccupancy(runnerStates: states, source: .syntheticVerification)
    }
}

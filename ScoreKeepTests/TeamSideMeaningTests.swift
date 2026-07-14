import Foundation
import Testing
@testable import ScoreKeep

struct TeamSideMeaningTests {
    @Test("same reusable team can be home and visiting in different games")
    func sameReusableTeamCanHaveDifferentRolesInDifferentGames() {
        let reusable = CanonicalTeamMeaningTestSupport.team()
        let home = CanonicalTeamMeaningTestSupport.side(
            gameID: CanonicalTeamMeaningTestSupport.gameA,
            role: .home,
            team: reusable
        )
        let visiting = CanonicalTeamMeaningTestSupport.side(
            gameID: CanonicalTeamMeaningTestSupport.gameB,
            role: .visiting,
            team: reusable
        )

        #expect(home.role == .home)
        #expect(visiting.role == .visiting)
        #expect(home.reusableTeamIdentity == visiting.reusableTeamIdentity)
        #expect(home != visiting)
    }

    @Test("home and visiting sides classify distinct and contradictory teams")
    func homeAndVisitingSidesClassifyDistinctAndContradictoryTeams() {
        let homeTeam = CanonicalTeamMeaningTestSupport.team(id: CanonicalTeamMeaningTestSupport.teamA)
        let visitingTeam = CanonicalTeamMeaningTestSupport.team(id: CanonicalTeamMeaningTestSupport.teamB)
        let home = CanonicalTeamMeaningTestSupport.side(role: .home, team: homeTeam)
        let visiting = CanonicalTeamMeaningTestSupport.side(role: .visiting, team: visitingTeam)
        let sameTeamVisiting = CanonicalTeamMeaningTestSupport.side(role: .visiting, team: homeTeam)

        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: home, visiting: visiting) == .completeDistinctSides)
        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: home, visiting: sameTeamVisiting) == .sameReusableTeamOnBothSides)
    }

    @Test("missing and unresolved sides remain explicit")
    func missingAndUnresolvedSidesRemainExplicit() {
        let home = CanonicalTeamMeaningTestSupport.side(role: .home)
        let visiting = CanonicalTeamMeaningTestSupport.side(role: .visiting)
        let unresolvedRole = CanonicalTeamMeaningTestSupport.side(role: .unresolved)
        let unknownHome = CanonicalTeamMeaningTestSupport.unknownSide(role: .home)
        let unknownVisiting = CanonicalTeamMeaningTestSupport.unknownSide(role: .visiting)

        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: nil, visiting: visiting) == .missingHomeSide)
        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: home, visiting: nil) == .missingVisitingSide)
        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: nil, visiting: nil) == .bothSidesUnresolved)
        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: unresolvedRole, visiting: visiting) == .unresolvedSideRole)
        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: unknownHome, visiting: unknownVisiting) == .completeDistinctSides)
        #expect(unknownHome.resolution == .unknown(CanonicalTeamMeaningTestSupport.display(name: .missing)))
    }

    @Test("contradictory side evidence is classified without normalizing it")
    func contradictorySideEvidenceIsClassifiedWithoutNormalizing() {
        let home = GameSideTeamParticipation(
            gameIdentity: .valid(CanonicalTeamMeaningTestSupport.gameA),
            role: .home,
            resolution: .conflicting(CanonicalTeamMeaningTestSupport.display(name: .present("Conflicting Home"))),
            historicalDisplay: CanonicalTeamMeaningTestSupport.display(name: .present("Conflicting Home")),
            source: .importedGame
        )
        let visiting = CanonicalTeamMeaningTestSupport.side(
            role: .visiting,
            team: CanonicalTeamMeaningTestSupport.team(id: CanonicalTeamMeaningTestSupport.teamB)
        )

        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: home, visiting: visiting) == .contradictorySideEvidence(["home"]))
    }

    @Test("historical side display is separate from current reusable display")
    func historicalSideDisplayIsSeparateFromCurrentReusableDisplay() {
        let current = CanonicalTeamMeaningTestSupport.team(
            display: CanonicalTeamMeaningTestSupport.display(
                name: .present("Current Tigers"),
                coach: .present("Current Coach"),
                logo: .present(CanonicalTeamMeaningTestSupport.logoA)
            ),
            rosterEvidence: .relationshipReference(count: 18)
        )
        let historicalDisplay = CanonicalTeamMeaningTestSupport.display(
            name: .present("Game-Time Tigers"),
            coach: .present("Old Coach"),
            logo: .present(CanonicalTeamMeaningTestSupport.logoB)
        )
        let side = CanonicalTeamMeaningTestSupport.side(
            role: .home,
            team: current,
            display: historicalDisplay
        )
        let renamedCurrent = CanonicalTeamMeaningTestSupport.team(
            display: CanonicalTeamMeaningTestSupport.display(
                name: .present("Renamed Tigers"),
                coach: .present("New Coach"),
                logo: .missing
            ),
            rosterEvidence: .relationshipReference(count: 10)
        )

        #expect(current == renamedCurrent)
        #expect(side.historicalDisplay == historicalDisplay)
        #expect(side.historicalDisplay != renamedCurrent.display)
        #expect(side.reusableTeamIdentity == .valid(CanonicalTeamMeaningTestSupport.teamA))
    }

    @Test("same teams on same date can belong to distinct game identities")
    func sameTeamsOnSameDateCanBelongToDistinctGameIdentities() {
        let homeTeam = CanonicalTeamMeaningTestSupport.team(id: CanonicalTeamMeaningTestSupport.teamA)
        let visitingTeam = CanonicalTeamMeaningTestSupport.team(id: CanonicalTeamMeaningTestSupport.teamB)
        let firstHome = CanonicalTeamMeaningTestSupport.side(
            gameID: CanonicalTeamMeaningTestSupport.gameA,
            role: .home,
            team: homeTeam
        )
        let firstVisiting = CanonicalTeamMeaningTestSupport.side(
            gameID: CanonicalTeamMeaningTestSupport.gameA,
            role: .visiting,
            team: visitingTeam
        )
        let secondHome = CanonicalTeamMeaningTestSupport.side(
            gameID: CanonicalTeamMeaningTestSupport.gameB,
            role: .home,
            team: homeTeam
        )
        let secondVisiting = CanonicalTeamMeaningTestSupport.side(
            gameID: CanonicalTeamMeaningTestSupport.gameB,
            role: .visiting,
            team: visitingTeam
        )

        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: firstHome, visiting: firstVisiting) == .completeDistinctSides)
        #expect(CanonicalTeamMeaningClassifier.classifyGameSides(home: secondHome, visiting: secondVisiting) == .completeDistinctSides)
        #expect(firstHome.gameIdentity != secondHome.gameIdentity)
        #expect(firstVisiting.reusableTeamIdentity == secondVisiting.reusableTeamIdentity)
    }
}

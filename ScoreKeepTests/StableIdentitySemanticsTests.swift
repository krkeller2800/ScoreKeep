import Foundation
import Testing
@testable import ScoreKeep

struct StableIdentitySemanticsTests {
    @Test("team identity preserves identifiers across matching and changed display values")
    func teamIdentityPreservesIdentifiersAcrossDisplayChanges() {
        let original = StableIdentityAndOrderingTestSupport.teamEvidence(
            id: StableIdentityAndOrderingTestSupport.teamA,
            name: "Fixture Tigers"
        )
        let matching = StableIdentityAndOrderingTestSupport.teamEvidence(
            id: StableIdentityAndOrderingTestSupport.teamA,
            name: "Fixture Tigers"
        )
        let renamed = StableIdentityAndOrderingTestSupport.teamEvidence(
            id: StableIdentityAndOrderingTestSupport.teamA,
            name: "Fixture Tigers 2026"
        )

        #expect(StableIdentityClassifier.compare(original, matching) == .sameIdentifierMatchingEvidence)
        #expect(StableIdentityClassifier.compare(original, renamed) == .sameIdentifierConflictingEvidence(["name"]))
    }

    @Test("team display name is not canonical identity")
    func teamDisplayNameIsNotCanonicalIdentity() {
        let first = StableIdentityAndOrderingTestSupport.teamEvidence(
            id: StableIdentityAndOrderingTestSupport.teamA,
            name: "Fixture Tigers"
        )
        let second = StableIdentityAndOrderingTestSupport.teamEvidence(
            id: StableIdentityAndOrderingTestSupport.teamB,
            name: "Fixture Tigers"
        )
        let missing = StableIdentityEvidence(
            concept: .team,
            importedIdentifier: .missing,
            displayEvidence: [.init("name", "Fixture Tigers")]
        )
        let invalid = StableIdentityEvidence(
            concept: .team,
            importedIdentifier: ImportedIdentifierEvidence(rawValue: "not-a-uuid"),
            displayEvidence: [.init("name", "Fixture Tigers")]
        )

        #expect(StableIdentityClassifier.compare(first, second) == .differentIdentifiersMatchingDisplay)
        #expect(StableIdentityClassifier.compare(first, missing) == .oneMissingIdentifier)
        #expect(StableIdentityClassifier.compare(first, invalid) == .invalidIdentifier)
    }

    @Test("player identity is distinct from names jersey numbers and team membership")
    func playerIdentityIsDistinctFromDisplayAndRosterHints() {
        let original = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerA,
            name: "Fixture Alex Same",
            number: "8",
            teamID: StableIdentityAndOrderingTestSupport.teamA
        )
        let sameIdentifierNumberChange = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerA,
            name: "Fixture Alex Same",
            number: "18",
            teamID: StableIdentityAndOrderingTestSupport.teamA
        )
        let sameFullNameDifferentIdentifier = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerB,
            name: "Fixture Alex Same",
            number: "8",
            teamID: StableIdentityAndOrderingTestSupport.teamA
        )
        let sameLastName = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerB,
            name: "Fixture Jordan Same",
            number: "12",
            teamID: StableIdentityAndOrderingTestSupport.teamA
        )
        let sameNumberDifferentPlayer = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerB,
            name: "Fixture Morgan Other",
            number: "8",
            teamID: StableIdentityAndOrderingTestSupport.teamA
        )
        let samePlayerDifferentTeam = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerA,
            name: "Fixture Alex Same",
            number: "8",
            teamID: StableIdentityAndOrderingTestSupport.teamB
        )

        #expect(StableIdentityClassifier.compare(original, sameIdentifierNumberChange) == .sameIdentifierConflictingEvidence(["number"]))
        #expect(StableIdentityClassifier.compare(original, sameFullNameDifferentIdentifier) == .differentIdentifiersMatchingDisplay)
        #expect(StableIdentityClassifier.compare(original, sameLastName) == .differentIdentifiersDifferentDisplay)
        #expect(StableIdentityClassifier.compare(original, sameNumberDifferentPlayer) == .differentIdentifiersDifferentDisplay)
        #expect(StableIdentityClassifier.compare(original, samePlayerDifferentTeam) == .sameIdentifierConflictingEvidence(["teamID"]))
    }

    @Test("player missing and invalid imported identifiers remain unresolved")
    func playerMissingAndInvalidIdentifiersRemainUnresolved() {
        let missing = StableIdentityEvidence(
            concept: .player,
            importedIdentifier: .missing,
            displayEvidence: [.init("name", "Fixture Missing Player")]
        )
        let invalid = StableIdentityEvidence(
            concept: .player,
            importedIdentifier: ImportedIdentifierEvidence(rawValue: "broken-player-id"),
            displayEvidence: [.init("name", "Fixture Invalid Player")]
        )

        #expect(StableIdentityClassifier.compare(missing, missing) == .bothMissingIdentifier)
        #expect(StableIdentityClassifier.compare(missing, invalid) == .invalidIdentifier)
    }

    @Test("game identity supports same teams same date and doubleheaders")
    func gameIdentitySupportsSameTeamsSameDateAndDoubleheaders() {
        let firstGame = StableIdentityAndOrderingTestSupport.gameEvidence(
            id: StableIdentityAndOrderingTestSupport.gameA,
            date: "2026-04-04T18:00:00Z",
            visitors: StableIdentityAndOrderingTestSupport.teamA,
            home: StableIdentityAndOrderingTestSupport.teamB,
            label: "doubleheader opener"
        )
        let secondGame = StableIdentityAndOrderingTestSupport.gameEvidence(
            id: StableIdentityAndOrderingTestSupport.gameB,
            date: "2026-04-04T18:00:00Z",
            visitors: StableIdentityAndOrderingTestSupport.teamA,
            home: StableIdentityAndOrderingTestSupport.teamB,
            label: "doubleheader nightcap"
        )
        let teamDateMatchOnly = StableIdentityAndOrderingTestSupport.gameEvidence(
            id: StableIdentityAndOrderingTestSupport.gameB,
            date: "2026-04-04T18:00:00Z",
            visitors: StableIdentityAndOrderingTestSupport.teamA,
            home: StableIdentityAndOrderingTestSupport.teamB,
            label: "doubleheader opener"
        )
        let conflictingSameID = StableIdentityAndOrderingTestSupport.gameEvidence(
            id: StableIdentityAndOrderingTestSupport.gameA,
            date: "2026-04-05T18:00:00Z",
            visitors: StableIdentityAndOrderingTestSupport.teamA,
            home: StableIdentityAndOrderingTestSupport.teamB
        )

        #expect(StableIdentityClassifier.compare(firstGame, secondGame) == .differentIdentifiersDifferentDisplay)
        #expect(StableIdentityClassifier.compare(firstGame, teamDateMatchOnly) == .differentIdentifiersMatchingDisplay)
        #expect(StableIdentityClassifier.compare(firstGame, conflictingSameID) == .sameIdentifierConflictingEvidence(["date", "label"]))
    }

    @Test("duplicate identity classification detects repeated matching and conflicting evidence")
    func duplicateIdentityClassificationDetectsConflicts() {
        let original = StableIdentityAndOrderingTestSupport.eventEvidence(
            id: StableIdentityAndOrderingTestSupport.eventA,
            result: "Single"
        )
        let exactRepeat = original
        let conflictingRepeat = StableIdentityAndOrderingTestSupport.eventEvidence(
            id: StableIdentityAndOrderingTestSupport.eventA,
            result: "Double"
        )
        let missing = StableIdentityEvidence(
            concept: .scoringEvent,
            importedIdentifier: .missing,
            displayEvidence: [.init("result", "Walk")]
        )
        let invalid = StableIdentityEvidence(
            concept: .scoringEvent,
            importedIdentifier: ImportedIdentifierEvidence(rawValue: "bad-event-id"),
            displayEvidence: [.init("result", "Walk")]
        )

        let classifications = StableIdentityClassifier.classifyDuplicates([
            original,
            exactRepeat,
            conflictingRepeat,
            missing,
            invalid
        ])

        #expect(classifications.contains(.exactRepeatedEvidence))
        #expect(classifications.contains(.duplicateIdentifierConflictingContent(["result"])))
        #expect(classifications.contains(.missingIdentifier))
        #expect(classifications.contains(.invalidIdentifier))
    }
}

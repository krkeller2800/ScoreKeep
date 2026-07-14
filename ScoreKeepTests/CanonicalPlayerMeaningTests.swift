import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalPlayerMeaningTests {
    @Test("reusable player identity is stable across display and media changes")
    func reusablePlayerIdentityIsStableAcrossDisplayAndMediaChanges() {
        let original = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(photo: .present(CanonicalPlayerMeaningTestSupport.photoA))
        )
        let matching = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(photo: .present(CanonicalPlayerMeaningTestSupport.photoA))
        )
        let renamed = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(name: .present("Casey Johnson"))
        )
        let renumbered = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(jerseyNumber: .present("27"))
        )
        let changedPosition = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(position: .present("CF"))
        )
        let changedBattingDirection = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(battingDirection: .present("L"))
        )
        let changedPhoto = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(photo: .present(CanonicalPlayerMeaningTestSupport.photoB))
        )
        let conflictingDisplay = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(
                name: .present("Jordan Lee"),
                jerseyNumber: .present("44"),
                position: .present("P"),
                battingDirection: .present("S"),
                photo: .invalid("not image data")
            )
        )

        #expect(original == matching)
        #expect(original == renamed)
        #expect(original == renumbered)
        #expect(original == changedPosition)
        #expect(original == changedBattingDirection)
        #expect(original == changedPhoto)
        #expect(CanonicalPlayerMeaningClassifier.compare(original, matching) == .sameIdentityMatchingDisplay)
        #expect(CanonicalPlayerMeaningClassifier.compare(original, renamed) == .sameIdentityConflictingDisplay(["name"]))
        #expect(CanonicalPlayerMeaningClassifier.compare(original, renumbered) == .sameIdentityConflictingDisplay(["jerseyNumber"]))
        #expect(CanonicalPlayerMeaningClassifier.compare(original, changedPosition) == .sameIdentityConflictingDisplay(["position"]))
        #expect(CanonicalPlayerMeaningClassifier.compare(original, changedBattingDirection) == .sameIdentityConflictingDisplay(["battingDirection"]))
        #expect(CanonicalPlayerMeaningClassifier.compare(original, changedPhoto) == .sameIdentityConflictingDisplay(["photoByteCount"]))
        #expect(CanonicalPlayerMeaningClassifier.compare(original, conflictingDisplay) == .sameIdentityConflictingDisplay(["battingDirection", "jerseyNumber", "name", "position"]))
        #expect(original.hashValue == renamed.hashValue)
    }

    @Test("same names last names and numbers do not merge distinct players")
    func sameNamesLastNamesAndNumbersDoNotMergeDistinctPlayers() {
        let sameFullNameA = CanonicalPlayerMeaningTestSupport.player(
            id: CanonicalPlayerMeaningTestSupport.playerA,
            display: CanonicalPlayerMeaningTestSupport.display(name: .present("Riley Morgan"), jerseyNumber: .present("8"))
        )
        let sameFullNameB = CanonicalPlayerMeaningTestSupport.player(
            id: CanonicalPlayerMeaningTestSupport.playerB,
            display: CanonicalPlayerMeaningTestSupport.display(name: .present("Riley Morgan"), jerseyNumber: .present("8"))
        )
        let sameLastName = CanonicalPlayerMeaningTestSupport.player(
            id: CanonicalPlayerMeaningTestSupport.playerC,
            display: CanonicalPlayerMeaningTestSupport.display(name: .present("Avery Morgan"), jerseyNumber: .present("8"))
        )

        #expect(sameFullNameA != sameFullNameB)
        #expect(sameFullNameA != sameLastName)
        #expect(CanonicalPlayerMeaningClassifier.compare(sameFullNameA, sameFullNameB) == .distinctIdentitiesMatchingDisplay)
        #expect(CanonicalPlayerMeaningClassifier.compare(sameFullNameA, sameLastName) == .distinctIdentitiesDifferentDisplay)
    }

    @Test("missing invalid duplicate and conflicting player identities remain classified")
    func unresolvedDuplicateAndConflictingPlayerIdentitiesRemainClassified() {
        let missing = CanonicalPlayerMeaningTestSupport.player(id: nil)
        let invalid = CanonicalPlayerMeaningTestSupport.player(rawID: "not-a-player-id")
        let duplicateMatching = CanonicalPlayerMeaningTestSupport.player()
        let duplicateConflicting = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(name: .present("Renamed Player"))
        )
        let classifications = CanonicalPlayerMeaningClassifier.classifyDuplicates([
            duplicateMatching,
            duplicateMatching,
            duplicateConflicting,
            missing,
            invalid
        ])

        #expect(CanonicalPlayerMeaningClassifier.compare(missing, duplicateMatching) == .oneMissingIdentifier)
        #expect(CanonicalPlayerMeaningClassifier.compare(invalid, duplicateMatching) == .invalidIdentifier)
        #expect(classifications.contains(.exactRepeatedEvidence))
        #expect(classifications.contains(.duplicateIdentifierConflictingDisplay(["name"])))
        #expect(classifications.contains(.missingIdentifier))
        #expect(classifications.contains(.invalidIdentifier))
    }

    @Test("player display evidence preserves blank missing unknown invalid and changed values")
    func playerDisplayEvidencePreservesBlankMissingUnknownInvalidAndChangedValues() {
        let complete = CanonicalPlayerMeaningTestSupport.display(
            name: .present("Casey Smith"),
            jerseyNumber: .present("12"),
            position: .present("SS"),
            battingDirection: .present("R"),
            photo: .present(CanonicalPlayerMeaningTestSupport.photoA)
        )
        let blankName = CanonicalPlayerMeaningTestSupport.display(name: .present(""))
        let missingName = CanonicalPlayerMeaningTestSupport.display(name: .missing)
        let blankNumber = CanonicalPlayerMeaningTestSupport.display(jerseyNumber: .present(""))
        let missingNumber = CanonicalPlayerMeaningTestSupport.display(jerseyNumber: .missing)
        let blankPosition = CanonicalPlayerMeaningTestSupport.display(position: .present(""))
        let missingPosition = CanonicalPlayerMeaningTestSupport.display(position: .missing)
        let unknownPosition = CanonicalPlayerMeaningTestSupport.display(position: .unknown("Rover"))
        let blankBattingDirection = CanonicalPlayerMeaningTestSupport.display(battingDirection: .present(""))
        let missingBattingDirection = CanonicalPlayerMeaningTestSupport.display(battingDirection: .missing)
        let unknownBattingDirection = CanonicalPlayerMeaningTestSupport.display(battingDirection: .unknown("Ambidextrous"))
        let invalidPhoto = CanonicalPlayerMeaningTestSupport.display(photo: .invalid("invalid base64 photo"))
        let player = CanonicalPlayerMeaningTestSupport.player(display: invalidPhoto)
        let changedDisplayPlayer = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(name: .present("Renamed Player"))
        )

        #expect(complete.name == .present("Casey Smith"))
        #expect(blankName.name == .present(""))
        #expect(missingName.name == .missing)
        #expect(blankNumber.jerseyNumber == .present(""))
        #expect(missingNumber.jerseyNumber == .missing)
        #expect(blankPosition.position == .present(""))
        #expect(missingPosition.position == .missing)
        #expect(unknownPosition.position == .unknown("Rover"))
        #expect(blankBattingDirection.battingDirection == .present(""))
        #expect(missingBattingDirection.battingDirection == .missing)
        #expect(unknownBattingDirection.battingDirection == .unknown("Ambidextrous"))
        #expect(invalidPhoto.photo == .invalid("invalid base64 photo"))
        #expect(player.identity == .valid(CanonicalPlayerMeaningTestSupport.playerA))
        #expect(player == changedDisplayPlayer)
    }

    @Test("current team and roster evidence are separate from reusable player identity")
    func currentTeamAndRosterEvidenceAreSeparateFromReusablePlayerIdentity() {
        let currentTeam = CanonicalPlayerMeaningTestSupport.player(
            rosterEvidence: .currentRelationship(teamIdentity: .valid(CanonicalPlayerMeaningTestSupport.teamA))
        )
        let changedTeam = CanonicalPlayerMeaningTestSupport.player(
            rosterEvidence: .currentRelationship(teamIdentity: .valid(CanonicalPlayerMeaningTestSupport.teamB))
        )
        let removed = CanonicalPlayerMeaningTestSupport.player(rosterEvidence: .removedFromCurrentRoster)
        let deletedEvidence = CanonicalPlayerMeaningTestSupport.player(rosterEvidence: .deletedReusableRecordEvidence)

        #expect(currentTeam == changedTeam)
        #expect(currentTeam == removed)
        #expect(currentTeam == deletedEvidence)
        #expect(CanonicalPlayerMeaningClassifier.compare(currentTeam, changedTeam) == .sameIdentityMatchingDisplay)
        #expect(currentTeam.rosterEvidence != changedTeam.rosterEvidence)
    }
}

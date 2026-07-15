import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalDefensivePositionSemanticsTests {
    @Test func recognizedRepositoryPositionValuesClassify() {
        let rawValues = [
            "P": CanonicalDefensivePosition.pitcher,
            "SP": .startingPitcher,
            "Relief Pitcher": .reliefPitcher,
            "C": .catcher,
            "1B": .firstBase,
            "2B": .secondBase,
            "SS": .shortstop,
            "3B": .thirdBase,
            "LF": .leftField,
            "CF": .centerField,
            "RF": .rightField,
            "DH": .designatedHitter,
            "Starting Pitcher": .startingPitcher,
            "Catcher": .catcher,
            "First Baseman": .firstBase,
            "Second Baseman": .secondBase,
            "Shortstop": .shortstop,
            "Third Baseman": .thirdBase,
            "Left Fielder": .leftField,
            "Center Fielder": .centerField,
            "Right Fielder": .rightField,
            "Designated Hitter": .designatedHitter
        ]

        for (rawValue, expected) in rawValues {
            let classifications = CanonicalDefensivePositionClassifier.classify(participation(rawValue: rawValue))
            #expect(classifications.contains(.recognizedPosition(expected)))
        }
    }

    @Test func blankMissingUnknownUnsupportedAndRawImportedPositionValuesClassify() {
        let blank = CanonicalDefensivePositionClassifier.classify(participation(rawValue: ""))
        let missing = CanonicalDefensivePositionClassifier.classify(participation(rawValue: nil))
        let unknown = CanonicalDefensivePositionClassifier.classify(participation(position: .unknownRawText("??")))
        let unsupported = CanonicalDefensivePositionClassifier.classify(participation(rawValue: "Sweeper"))
        let imported = CanonicalDefensivePositionClassifier.classify(
            participation(position: DefensivePositionEvidence(rawValue: "Rover", source: .importedRoster))
        )

        #expect(blank.contains(.blankPosition))
        #expect(blank.contains(.participantWithoutDefensivePosition))
        #expect(missing.contains(.missingPosition))
        #expect(unknown.contains(.unknownRawText("??")))
        #expect(unsupported.contains(.unsupportedRawText("Sweeper")))
        #expect(imported.contains(.rawImportedPosition("Rover")))
    }

    @Test func conflictingHistoricalAndUnresolvedPositionEvidenceClassifies() {
        let conflicting = CanonicalDefensivePositionClassifier.classify(
            participation(position: .conflicting([
                .recognized(.shortstop, rawValue: "SS", displayValue: "Shortstop"),
                .recognized(.centerField, rawValue: "CF", displayValue: "Center Fielder")
            ]))
        )
        let historical = CanonicalDefensivePositionClassifier.classify(
            participation(position: DefensivePositionEvidence(rawValue: "SS", source: .historicalGameParticipation))
        )
        let unresolved = CanonicalDefensivePositionClassifier.classify(
            participation(position: .unresolvedLineupParticipant(rawValue: "SS"))
        )

        #expect(conflicting.contains(.conflictingPositionEvidence))
        #expect(historical.contains(.historicalPositionEvidence))
        #expect(historical.contains(.recognizedPosition(.shortstop)))
        #expect(unresolved.contains(.unresolvedLineupParticipant))
    }

    @Test func samePlayerCanHaveDifferentHistoricalPositionsInDifferentGames() {
        let playerID = ImportedIdentifierEvidence.valid(CanonicalLineupMeaningTestSupport.playerA)
        let gameA = participation(gameID: CanonicalLineupMeaningTestSupport.gameA, playerID: playerID, rawValue: "SS")
        let gameB = participation(gameID: CanonicalLineupMeaningTestSupport.gameB, playerID: playerID, rawValue: "CF")

        #expect(gameA.reusablePlayerIdentity == gameB.reusablePlayerIdentity)
        #expect(gameA.gameIdentity != gameB.gameIdentity)
        #expect(gameA.positionEvidence.canonicalPosition == .shortstop)
        #expect(gameB.positionEvidence.canonicalPosition == .centerField)
    }

    @Test func currentPositionChangeDoesNotRewriteHistoricalEvidence() {
        let historical = DefensivePositionEvidence(rawValue: "SS", source: .historicalGameParticipation)
        let current = DefensivePositionEvidence(rawValue: "CF", source: .currentPlayerRecord)

        #expect(historical.canonicalPosition == .shortstop)
        #expect(current.canonicalPosition == .centerField)
        #expect(historical != current)
    }

    @Test func positionDoesNotDefineIdentityRosterMembershipOrBattingSlot() {
        let classifications = CanonicalDefensivePositionClassifier.classify(participation(rawValue: "SS"))

        #expect(classifications.contains(.identityUnaffected))
        #expect(classifications.contains(.rosterMembershipUnaffected))
        #expect(classifications.contains(.battingSlotUnaffected))
    }

    @Test func pitcherOnlyAndBatterPitcherParticipationRemainRepresentable() {
        let pitcherOnly = CanonicalDefensivePositionClassifier.classify(
            participation(rawValue: "SP", pitcherEvidence: .pitcherOnly(nil))
        )
        let batterAndPitcher = CanonicalDefensivePositionClassifier.classify(
            participation(rawValue: "P", pitcherEvidence: .batterAndPitcher)
        )
        let unknownPitcher = CanonicalDefensivePositionClassifier.classify(
            participation(rawValue: nil, pitcherEvidence: .unknownPitcherRelationship)
        )

        #expect(pitcherOnly.contains(.pitcherOnlyParticipation))
        #expect(batterAndPitcher.contains(.batterAndPitcherParticipation))
        #expect(batterAndPitcher.contains(.recognizedPosition(.pitcher)))
        #expect(unknownPitcher.contains(.unknownPitcherRelationship))
    }

    @Test func invalidOrUnknownPositionDoesNotInvalidatePlayerIdentity() {
        let playerID = ImportedIdentifierEvidence.valid(CanonicalLineupMeaningTestSupport.playerA)
        let unsupported = participation(playerID: playerID, rawValue: "Sweeper")
        let classifications = CanonicalDefensivePositionClassifier.classify(unsupported)

        #expect(unsupported.reusablePlayerIdentity == playerID)
        #expect(classifications.contains(.unsupportedRawText("Sweeper")))
        #expect(classifications.contains(.identityUnaffected))
    }

    @Test func displayValueRemainsSeparateFromCanonicalPosition() {
        let evidence = participation(
            position: .recognized(.shortstop, rawValue: "SS", displayValue: "Shortstop"),
            displayValue: "SS"
        )
        let classifications = CanonicalDefensivePositionClassifier.classify(evidence)

        #expect(evidence.positionEvidence.canonicalPosition == .shortstop)
        #expect(evidence.displayValue == "SS")
        #expect(classifications.contains(.displayValueSeparate))
    }

    @Test func lineupEntryAndFixturePositionEvidenceClassifiesWithoutMutation() throws {
        let lineupGame = try CanonicalTeamMeaningTestSupport.decodeGameFixture("LineupGame.ScoreKeep_Games")
        let pitcherGame = try CanonicalTeamMeaningTestSupport.decodeGameFixture("PitcherGame.ScoreKeep_Games")
        let roster = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("CompleteRoster.ScoreKeep_Players")
        let missingRoster = try CanonicalTeamMeaningTestSupport.decodeRosterFixture("MissingOptionalValues.ScoreKeep_Players")
        let lineup = try #require(lineupGame.lineups.first.map { CanonicalLineupMeaningTestSupport.importedLineup(from: $0, gameID: lineupGame.id) })
        let firstEntry = try #require(lineup.entries.first)
        let defensive = CanonicalDefensiveParticipationEvidence(lineupEntry: firstEntry, gameIdentity: .valid(lineupGame.id))

        #expect(CanonicalDefensivePositionClassifier.classify(defensive).contains(.recognizedPosition(.shortstop)))
        #expect(pitcherGame.pitchers.first?.player.position == "SP")
        #expect(roster.map(\.position).contains("P"))
        #expect(roster.map(\.position).contains("C"))
        #expect(roster.map(\.position).contains("SS"))
        #expect(roster.map(\.position).contains("CF"))
        #expect(missingRoster.first?.position == "")
    }

    @Test func brokenPitcherFixtureSupportsUnknownPitcherRelationship() throws {
        let brokenPitcher = try CanonicalTeamMeaningTestSupport.decodeMalformedGameFixture("BrokenPitcherRelationship.ScoreKeep_Games")
        let pitcher = try #require(brokenPitcher.pitchers.first)
        let evidence = participation(
            gameID: brokenPitcher.id,
            rawValue: pitcher.player.position,
            pitcherEvidence: .unknownPitcherRelationship
        )
        let classifications = CanonicalDefensivePositionClassifier.classify(evidence)

        #expect(pitcher.team.id != brokenPitcher.vteam.id)
        #expect(pitcher.team.id != brokenPitcher.hteam.id)
        #expect(classifications.contains(.unknownPitcherRelationship))
    }

    @Test func repeatedEvaluationIsDeterministic() {
        let evidence = participation(rawValue: "SS", pitcherEvidence: .batterAndPitcher)
        let first = CanonicalDefensivePositionClassifier.classify(evidence)
        let second = CanonicalDefensivePositionClassifier.classify(evidence)

        #expect(first == second)
    }

    private func participation(
        gameID: UUID = CanonicalLineupMeaningTestSupport.gameA,
        playerID: ImportedIdentifierEvidence = .valid(CanonicalLineupMeaningTestSupport.playerA),
        rawValue: String?,
        pitcherEvidence: CanonicalPitcherParticipationEvidence = .none
    ) -> CanonicalDefensiveParticipationEvidence {
        participation(
            gameID: gameID,
            playerID: playerID,
            position: DefensivePositionEvidence(rawValue: rawValue, source: .currentPlayerRecord),
            pitcherEvidence: pitcherEvidence
        )
    }

    private func participation(
        position: DefensivePositionEvidence,
        displayValue: String? = nil,
        pitcherEvidence: CanonicalPitcherParticipationEvidence = .none
    ) -> CanonicalDefensiveParticipationEvidence {
        participation(
            gameID: CanonicalLineupMeaningTestSupport.gameA,
            playerID: .valid(CanonicalLineupMeaningTestSupport.playerA),
            position: position,
            displayValue: displayValue,
            pitcherEvidence: pitcherEvidence
        )
    }

    private func participation(
        gameID: UUID,
        playerID: ImportedIdentifierEvidence,
        position: DefensivePositionEvidence,
        displayValue: String? = nil,
        pitcherEvidence: CanonicalPitcherParticipationEvidence = .none
    ) -> CanonicalDefensiveParticipationEvidence {
        CanonicalDefensiveParticipationEvidence(
            gameIdentity: .valid(gameID),
            participant: .gameParticipant(CanonicalLineupMeaningTestSupport.participant()),
            reusablePlayerIdentity: playerID,
            positionEvidence: position,
            pitcherEvidence: pitcherEvidence,
            displayValue: displayValue,
            source: .syntheticVerification
        )
    }
}

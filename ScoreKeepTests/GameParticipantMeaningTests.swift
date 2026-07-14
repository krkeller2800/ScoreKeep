import Foundation
import Testing
@testable import ScoreKeep

struct GameParticipantMeaningTests {
    @Test("reusable player can be represented as distinct game participants")
    func reusablePlayerCanBeRepresentedAsDistinctGameParticipants() {
        let reusable = CanonicalPlayerMeaningTestSupport.player()
        let firstGame = CanonicalPlayerMeaningTestSupport.participant(
            participantID: CanonicalPlayerMeaningTestSupport.participantA,
            gameID: CanonicalPlayerMeaningTestSupport.gameA,
            player: reusable,
            roles: [.lineupParticipant]
        )
        let secondGame = CanonicalPlayerMeaningTestSupport.participant(
            participantID: CanonicalPlayerMeaningTestSupport.participantB,
            gameID: CanonicalPlayerMeaningTestSupport.gameB,
            player: reusable,
            roles: [.lineupParticipant]
        )

        #expect(firstGame.reusablePlayerIdentity == .valid(CanonicalPlayerMeaningTestSupport.playerA))
        #expect(secondGame.reusablePlayerIdentity == .valid(CanonicalPlayerMeaningTestSupport.playerA))
        #expect(firstGame != secondGame)
        #expect(firstGame.gameIdentity != secondGame.gameIdentity)
        #expect(firstGame.participantIdentity != secondGame.participantIdentity)
    }

    @Test("game participant can carry multiple role evidence")
    func gameParticipantCanCarryMultipleRoleEvidence() {
        let lineup = PlayerLineupParticipationEvidence(
            lineupIdentity: .valid(CanonicalPlayerMeaningTestSupport.lineupA),
            slotOrder: OrderEvidence(kind: .lineupSlot, value: 4),
            battingOrder: OrderEvidence(kind: .battingOrder, value: 4)
        )
        let plateAppearance = PlayerPlateAppearanceEvidence(
            scoringEventIdentity: .valid(CanonicalPlayerMeaningTestSupport.eventA),
            battingOrder: OrderEvidence(kind: .battingOrder, value: 4)
        )
        let pitcherAppearance = PlayerPitcherAppearanceEvidence(
            pitcherIdentity: .valid(CanonicalPlayerMeaningTestSupport.pitcherA),
            appearanceOrder: OrderEvidence(kind: .pitcherAppearance, value: 1)
        )
        let substitution = PlayerSubstitutionEvidence(
            substitutionIdentity: .valid(CanonicalPlayerMeaningTestSupport.substitutionA),
            incomingIdentity: .valid(CanonicalPlayerMeaningTestSupport.playerA),
            outgoingIdentity: .valid(CanonicalPlayerMeaningTestSupport.playerB),
            order: OrderEvidence(kind: .substitution, value: 1)
        )
        let participant = CanonicalPlayerMeaningTestSupport.participant(
            roles: [.rosterMember, .lineupParticipant, .batter, .pitcher, .substitute, .replacedParticipant],
            lineupEvidence: lineup,
            plateAppearanceEvidence: [plateAppearance],
            pitcherAppearanceEvidence: [pitcherAppearance],
            substitutionEvidence: [substitution]
        )

        #expect(participant.roles.contains(.rosterMember))
        #expect(participant.roles.contains(.lineupParticipant))
        #expect(participant.roles.contains(.batter))
        #expect(participant.roles.contains(.pitcher))
        #expect(participant.roles.contains(.substitute))
        #expect(participant.roles.contains(.replacedParticipant))
        #expect(participant.lineupEvidence == lineup)
        #expect(participant.plateAppearanceEvidence == [plateAppearance])
        #expect(participant.pitcherAppearanceEvidence == [pitcherAppearance])
        #expect(participant.substitutionEvidence == [substitution])
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(participant) == .resolvedParticipant)
    }

    @Test("historical participation display remains separate from current reusable display")
    func historicalParticipationDisplayRemainsSeparateFromCurrentReusableDisplay() {
        let current = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(
                name: .present("Current Name"),
                jerseyNumber: .present("22"),
                position: .present("CF"),
                battingDirection: .present("L"),
                photo: .present(CanonicalPlayerMeaningTestSupport.photoA)
            ),
            rosterEvidence: .currentRelationship(teamIdentity: .valid(CanonicalPlayerMeaningTestSupport.teamB))
        )
        let historicalDisplay = CanonicalPlayerMeaningTestSupport.display(
            name: .present("Game-Time Name"),
            jerseyNumber: .present("7"),
            position: .present("2B"),
            battingDirection: .present("R"),
            photo: .missing
        )
        let participant = CanonicalPlayerMeaningTestSupport.participant(
            player: current,
            teamEvidence: .gameSide(CanonicalPlayerMeaningTestSupport.side(teamID: CanonicalPlayerMeaningTestSupport.teamA)),
            historicalDisplay: historicalDisplay,
            roles: [.batter]
        )
        let renamedCurrent = CanonicalPlayerMeaningTestSupport.player(
            display: CanonicalPlayerMeaningTestSupport.display(
                name: .present("Future Name"),
                jerseyNumber: .present("31"),
                position: .present("P"),
                battingDirection: .present("S"),
                photo: .present(CanonicalPlayerMeaningTestSupport.photoB)
            ),
            rosterEvidence: .removedFromCurrentRoster
        )

        #expect(current == renamedCurrent)
        #expect(participant.historicalDisplay == historicalDisplay)
        #expect(participant.historicalDisplay != renamedCurrent.display)
        #expect(participant.reusablePlayerIdentity == .valid(CanonicalPlayerMeaningTestSupport.playerA))
        #expect(participant.teamEvidence != .currentReusableTeam(CanonicalTeamMeaningTestSupport.team(id: CanonicalPlayerMeaningTestSupport.teamB)))
    }

    @Test("missing invalid duplicate conflicting unknown and detached participant evidence classifies explicitly")
    func unresolvedParticipantEvidenceClassifiesExplicitly() {
        let display = CanonicalPlayerMeaningTestSupport.display(name: .present("Imported Unknown"))
        let missing = GamePlayerParticipation(
            gameIdentity: .valid(CanonicalPlayerMeaningTestSupport.gameA),
            playerResolution: .missingIdentity(display),
            historicalDisplay: display,
            roles: [.lineupParticipant]
        )
        let invalid = GamePlayerParticipation(
            gameIdentity: .valid(CanonicalPlayerMeaningTestSupport.gameA),
            playerResolution: .invalidIdentity(.invalid("bad-player-id"), display),
            historicalDisplay: display,
            roles: [.lineupParticipant]
        )
        let duplicate = GamePlayerParticipation(
            gameIdentity: .valid(CanonicalPlayerMeaningTestSupport.gameA),
            playerResolution: .duplicateIdentity(.valid(CanonicalPlayerMeaningTestSupport.playerA), display),
            historicalDisplay: display,
            roles: [.lineupParticipant]
        )
        let conflict = GamePlayerParticipation(
            gameIdentity: .valid(CanonicalPlayerMeaningTestSupport.gameA),
            playerResolution: .conflictingEvidence(.valid(CanonicalPlayerMeaningTestSupport.playerA), display),
            historicalDisplay: display,
            roles: [.lineupParticipant]
        )
        let unknown = GamePlayerParticipation(
            gameIdentity: .valid(CanonicalPlayerMeaningTestSupport.gameA),
            playerResolution: .unknown(display),
            historicalDisplay: display,
            roles: [.lineupParticipant]
        )
        let detached = GamePlayerParticipation(
            gameIdentity: .valid(CanonicalPlayerMeaningTestSupport.gameA),
            playerResolution: .importedDetached(display),
            historicalDisplay: display,
            roles: [.lineupParticipant]
        )
        let unresolvedRole = CanonicalPlayerMeaningTestSupport.participant(roles: [.unresolved])
        let missingGame = GamePlayerParticipation(
            gameIdentity: .missing,
            playerResolution: .unknown(display),
            roles: [.lineupParticipant]
        )
        let invalidGame = GamePlayerParticipation(
            gameIdentity: .invalid("bad-game-id"),
            playerResolution: .unknown(display),
            roles: [.lineupParticipant]
        )

        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(missing) == .missingReusablePlayerIdentity)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(invalid) == .invalidReusablePlayerIdentity)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(duplicate) == .duplicateReusablePlayerIdentity)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(conflict) == .conflictingPlayerEvidence)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(unknown) == .unknownParticipant)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(detached) == .importedDetachedParticipant)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(unresolvedRole) == .unresolvedRole)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(missingGame) == .missingGameIdentity)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(invalidGame) == .invalidGameIdentity)
    }

    @Test("array placement alone does not fabricate role evidence")
    func arrayPlacementAloneDoesNotFabricateRoleEvidence() {
        let sourceOrder = OrderEvidence(kind: .sourceFile, value: 1, sourceIndex: 0)
        let participant = GamePlayerParticipation(
            gameIdentity: .valid(CanonicalPlayerMeaningTestSupport.gameA),
            playerResolution: .reusablePlayer(CanonicalPlayerMeaningTestSupport.player()),
            roles: [],
            lineupEvidence: PlayerLineupParticipationEvidence(slotOrder: sourceOrder)
        )

        #expect(participant.roles.isEmpty)
        #expect(participant.lineupEvidence?.slotOrder == sourceOrder)
        #expect(CanonicalPlayerMeaningClassifier.classifyParticipant(participant) == .unresolvedRole)
    }
}

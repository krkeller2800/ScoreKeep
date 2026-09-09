import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Lineup slot safety coordinator")
struct LineupSlotSafetyCoordinatorTests {
    @Test func defaultMaterializationFromRosterOrderCreatesLineupAndPristinePlaceholders() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 3)

        let result = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.source == .rosterBattingOrder)
        #expect(result.lineup.players.sorted { $0.batOrder < $1.batOrder }.map(\.identifier) == fixture.visitingPlayers.map(\.identifier))
        #expect(result.slots.map(\.battingOrder) == [1, 2, 3])
        #expect(result.slots.map(\.isEditable) == [true, true, true])
        #expect(result.slots.map { $0.placeholderAtbat.player.identifier } == fixture.visitingPlayers.map(\.identifier))
        #expect(result.slots.map { $0.placeholderAtbat.result } == ["Result", "Result", "Result"])
        #expect(fixture.game.players.map(\.identifier).contains(fixture.visitingPlayers[0].identifier))
    }

    @Test func existingLineupIsPreferredOverRosterFallback() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 4)
        let lineup = Lineup(everyoneHits: false, game: fixture.game, team: fixture.visitingTeam, inning: 1, players: [
            fixture.visitingPlayers[2],
            fixture.visitingPlayers[0]
        ])
        fixture.visitingPlayers[2].batOrder = 1
        fixture.visitingPlayers[0].batOrder = 2
        fixture.visitingPlayers[1].batOrder = 3
        fixture.visitingPlayers[3].batOrder = 4
        store.context.insert(lineup)
        fixture.game.lineups = [lineup]

        let result = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.source == .existingLineup)
        #expect(result.slots.map { $0.player.identifier } == [fixture.visitingPlayers[2].identifier, fixture.visitingPlayers[0].identifier])
        #expect(fixture.game.atbats.count == 2)
    }

    @Test func firstColumnAtbatFallbackIsUsedWhenLineupIsEmpty() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 3)
        let emptyLineup = Lineup(everyoneHits: false, game: fixture.game, team: fixture.visitingTeam, inning: 1)
        fixture.game.lineups = [emptyLineup]
        store.context.insert(emptyLineup)
        let first = Fixture.placeholder(game: fixture.game, team: fixture.visitingTeam, player: fixture.visitingPlayers[1], slot: 1)
        let second = Fixture.placeholder(game: fixture.game, team: fixture.visitingTeam, player: fixture.visitingPlayers[0], slot: 2)
        fixture.visitingPlayers[1].batOrder = 99
        fixture.visitingPlayers[0].batOrder = 99
        store.context.insert(first)
        store.context.insert(second)
        fixture.game.atbats = [second, first]

        let result = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.source == .firstColumnAtbats)
        #expect(result.slots.map { $0.player.identifier } == [fixture.visitingPlayers[1].identifier, fixture.visitingPlayers[0].identifier])
        #expect(result.slots.map { $0.placeholderAtbat.ident } == [first.ident, second.ident])
    }

    @Test func everyoneHitsMaterializesSlotsBeyondNine() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 12, everyoneHits: true)

        let result = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.slots.count == 12)
        #expect(result.slots.map(\.battingOrder) == Array(1...12))
        #expect(result.lineup.everyoneHits)
    }

    @Test func ambiguousDuplicateRosterSlotFailsClosedDuringMaterialization() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 2)
        fixture.visitingPlayers[1].batOrder = 1

        do {
            _ = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
                game: fixture.game,
                team: fixture.visitingTeam,
                modelContext: store.context
            )
            Issue.record("Expected duplicate roster slot to fail closed")
        } catch LineupSlotSafetyError.ambiguousLineupState(let reason) {
            #expect(reason == .duplicateLineupSlot)
        }
    }

    @Test func ambiguousDuplicateFirstColumnSlotFailsClosedDuringMaterialization() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 2)
        fixture.visitingPlayers.forEach { $0.batOrder = 99 }
        let first = Fixture.placeholder(game: fixture.game, team: fixture.visitingTeam, player: fixture.visitingPlayers[0], slot: 1)
        let duplicate = Fixture.placeholder(game: fixture.game, team: fixture.visitingTeam, player: fixture.visitingPlayers[1], slot: 1)
        store.context.insert(first)
        store.context.insert(duplicate)
        fixture.game.atbats = [first, duplicate]

        do {
            _ = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
                game: fixture.game,
                team: fixture.visitingTeam,
                modelContext: store.context
            )
            Issue.record("Expected duplicate first-column slot to fail closed")
        } catch LineupSlotSafetyError.ambiguousLineupState(let reason) {
            #expect(reason == .duplicateLineupSlot)
        }
    }

    @Test func multiplePersistedLineupsLockResolvedSlots() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 2)
        let duplicateLineup = Lineup(everyoneHits: false, game: fixture.game, team: fixture.visitingTeam, inning: 1, players: fixture.visitingPlayers)
        store.context.insert(duplicateLineup)
        fixture.game.lineups.append(duplicateLineup)

        let slots = LineupSlotSafetyCoordinator.resolvedSlots(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(slots.map(\.editability) == [
            .locked(.ambiguousLineupState),
            .locked(.ambiguousLineupState)
        ])
    }

    @Test func pristineSlotIsEditable() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 2)

        let editability = LineupSlotSafetyCoordinator.editability(
            for: 1,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(editability == .editable)
    }

    @Test func scoredOrNonPristineSlotLocks() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 2)
        let target = try #require(fixture.game.atbats.first { $0.batOrder == 1 && $0.col == 1 })
        target.result = "Single"
        target.maxbase = "First"

        let editability = LineupSlotSafetyCoordinator.editability(
            for: 1,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(editability == .locked(.placeholderNotPristine))
    }

    @Test func acceptedLegacyScoringEvidenceLocksSlot() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 2)
        let target = try #require(fixture.game.atbats.first { $0.batOrder == 1 && $0.col == 1 })
        store.context.insert(LegacyScoringOperationEvidenceRecord(
            operationIdentity: UUID(),
            requestFingerprint: "legacy-score",
            targetGameIdentity: fixture.game.ident,
            targetAtbatIdentity: target.ident,
            submissionFamily: LegacyScoringOperationEvidenceConstants.ordinarySubmissionFamily,
            acceptedResultClassification: "hit",
            acceptedOutcomeReference: "Single"
        ))

        let editability = LineupSlotSafetyCoordinator.editability(
            for: 1,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(editability == .locked(.acceptedScoringEvidence))
    }

    @Test func acceptedCanonicalScoringEvidenceLocksEverySlotBecausePlayerLinkCannotBeProven() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 2)
        store.context.insert(CanonicalScoringOperationEvidenceRecord(
            operationIdentity: UUID(),
            gameIdentity: fixture.game.ident,
            operationKind: "scoringEvent",
            requestFingerprint: "canonical-score",
            disposition: CanonicalScoringPersistenceConstants.operationAcceptedDisposition
        ))

        let editability = LineupSlotSafetyCoordinator.editability(
            for: 2,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(editability == .locked(.acceptedScoringEvidence))
    }

    @Test func substitutionReplacementParticipationLocksSlot() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 2)
        fixture.game.replaced = [fixture.visitingPlayers[0]]

        let editability = LineupSlotSafetyCoordinator.editability(
            for: 1,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(editability == .locked(.substitutionParticipation))
    }

    @Test func pitcherParticipationLocksSlot() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 2)
        let pitcher = Pitcher(player: fixture.visitingPlayers[0], team: fixture.visitingTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(pitcher)
        fixture.game.pitchers = [pitcher]

        let editability = LineupSlotSafetyCoordinator.editability(
            for: 1,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(editability == .locked(.pitcherParticipation))
    }

    @Test func duplicateIncomingPlayerIsRefused() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 2)

        do {
            _ = try LineupSlotSafetyCoordinator.reassignPlayer(
                in: 1,
                to: fixture.visitingPlayers[1],
                game: fixture.game,
                team: fixture.visitingTeam,
                modelContext: store.context
            )
            Issue.record("Expected duplicate incoming player to be refused")
        } catch LineupSlotSafetyError.incomingPlayerUnavailable(let reason) {
            #expect(reason == .incomingPlayerUnavailable)
        }
    }

    @Test func safeReassignmentChangesOnlyTargetSlotAndPreservesUnrelatedGameState() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 3)
        let bench = Fixture.player(name: "Bench Player", number: "44", slot: 99, team: fixture.visitingTeam)
        let unrelatedPitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        let unrelatedSub = Fixture.player(name: "Home Sub", number: "45", slot: 99, team: fixture.homeTeam)
        fixture.game.hscore = 4
        fixture.game.vscore = 3
        fixture.game.pitchers = [unrelatedPitcher]
        fixture.game.incomings = [unrelatedSub]
        store.context.insert(bench)
        store.context.insert(unrelatedPitcher)
        store.context.insert(unrelatedSub)
        fixture.visitingTeam.players.append(bench)
        fixture.homeTeam.players.append(unrelatedSub)
        try store.context.save()

        let firstSlotAtbat = try #require(fixture.game.atbats.first { $0.batOrder == 1 && $0.col == 1 })
        firstSlotAtbat.result = "Single"
        firstSlotAtbat.maxbase = "First"
        let thirdSlotAtbat = try #require(fixture.game.atbats.first { $0.batOrder == 3 && $0.col == 1 })
        let originalFirstAtbatIdentity = firstSlotAtbat.ident
        let originalSecondPlayerIdentity = fixture.visitingPlayers[1].identifier
        let originalThirdAtbatIdentity = thirdSlotAtbat.ident
        let result = try LineupSlotSafetyCoordinator.reassignPlayer(
            in: 3,
            to: bench,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.outgoingPlayer.identifier == fixture.visitingPlayers[2].identifier)
        #expect(result.slot.player.identifier == bench.identifier)
        #expect(result.slot.placeholderAtbat.ident == originalThirdAtbatIdentity)
        #expect(fixture.game.atbats.count == 3)
        #expect(firstSlotAtbat.ident == originalFirstAtbatIdentity)
        #expect(firstSlotAtbat.result == "Single")
        #expect(LineupSlotSafetyCoordinator.resolvedSlots(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        ).map(\.player.identifier) == [
            fixture.visitingPlayers[0].identifier,
            originalSecondPlayerIdentity,
            bench.identifier
        ])
        #expect(fixture.visitingPlayers[2].batOrder == 3)
        #expect(bench.batOrder == 99)
        #expect(fixture.game.hscore == 4)
        #expect(fixture.game.vscore == 3)
        #expect(fixture.game.pitchers.map(\.ident) == [unrelatedPitcher.ident])
        #expect(fixture.game.incomings.map(\.identifier) == [unrelatedSub.identifier])
        #expect(fixture.game.players.contains(where: { $0.identifier == bench.identifier }))
        #expect(fixture.game.players.contains(where: { $0.identifier == fixture.visitingPlayers[2].identifier }) == false)
    }

    @Test func persistedReloadEquivalentProducesSameEligibility() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 2)
        let secondSlotAtbat = try #require(fixture.game.atbats.first { $0.batOrder == 2 && $0.col == 1 })
        secondSlotAtbat.result = "Ground Out"
        try store.context.save()

        let firstPass = LineupSlotSafetyCoordinator.resolvedSlots(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        ).map(\.editability)

        let resumedContext = ModelContext(store.container)
        let resumedGame = try #require(try resumedContext.fetch(FetchDescriptor<Game>()).first)
        let resumedTeam = try #require(resumedGame.vteam)
        let secondPass = LineupSlotSafetyCoordinator.resolvedSlots(
            game: resumedGame,
            team: resumedTeam,
            modelContext: resumedContext
        ).map(\.editability)

        #expect(firstPass == secondPass)
        #expect(secondPass == [.editable, .locked(.placeholderNotPristine)])
    }

    @Test func liveScorecardEntryMaterializesDefaultLineupWithoutLineupVisit() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 3)

        let result = try EditScoreView.materializeLineupForLiveScoring(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.source == .rosterBattingOrder)
        #expect(result.slots.map(\.battingOrder) == [1, 2, 3])
        #expect(result.slots.map { $0.placeholderAtbat.player.identifier } == fixture.visitingPlayers.map(\.identifier))
        #expect(fixture.game.lineups.count == 1)
        #expect(fixture.game.atbats.count == 3)
    }

    @Test func liveScorecardEntryPreservesExistingPartialAndScoredLineup() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 4)
        let existingLineup = Lineup(
            everyoneHits: false,
            game: fixture.game,
            team: fixture.visitingTeam,
            inning: 1,
            players: [fixture.visitingPlayers[2], fixture.visitingPlayers[0]]
        )
        fixture.visitingPlayers[2].batOrder = 1
        fixture.visitingPlayers[0].batOrder = 2
        store.context.insert(existingLineup)
        fixture.game.lineups = [existingLineup]
        let first = Fixture.placeholder(game: fixture.game, team: fixture.visitingTeam, player: fixture.visitingPlayers[2], slot: 1)
        let second = Fixture.placeholder(game: fixture.game, team: fixture.visitingTeam, player: fixture.visitingPlayers[0], slot: 2)
        second.result = "Single"
        second.maxbase = "First"
        store.context.insert(first)
        store.context.insert(second)
        fixture.game.atbats = [first, second]
        let originalFirstIdentity = first.ident
        let originalSecondIdentity = second.ident

        let result = try EditScoreView.materializeLineupForLiveScoring(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.source == .existingLineup)
        #expect(result.slots.map { $0.player.identifier } == [fixture.visitingPlayers[2].identifier, fixture.visitingPlayers[0].identifier])
        #expect(result.slots.map { $0.placeholderAtbat.ident } == [originalFirstIdentity, originalSecondIdentity])
        #expect(result.slots.map(\.editability) == [.editable, .locked(.placeholderNotPristine)])
        #expect(fixture.game.atbats.count == 2)
        #expect(second.result == "Single")
        #expect(second.maxbase == "First")
    }

    @Test func liveScorecardEntryIsIdempotentAcrossReopenEquivalent() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 2)
        let first = try EditScoreView.materializeLineupForLiveScoring(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )
        let firstAtbatIdentities = fixture.game.atbats
            .sorted { $0.batOrder < $1.batOrder }
            .map(\.ident)
        let firstLineupIdentity = first.lineup.ident

        let reopenedContext = ModelContext(store.container)
        let reopenedGame = try #require(try reopenedContext.fetch(FetchDescriptor<Game>()).first)
        let reopenedTeam = try #require(reopenedGame.vteam)
        let second = try EditScoreView.materializeLineupForLiveScoring(
            game: reopenedGame,
            team: reopenedTeam,
            modelContext: reopenedContext
        )

        #expect(second.lineup.ident == firstLineupIdentity)
        #expect(reopenedGame.atbats.sorted { $0.batOrder < $1.batOrder }.map(\.ident) == firstAtbatIdentities)
        #expect(second.slots.map(\.battingOrder) == [1, 2])
    }

    @Test func liveScorecardEntryMaterializesWhenSwitchingTeams() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 2)

        let visiting = try EditScoreView.materializeLineupForLiveScoring(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )
        let home = try EditScoreView.materializeLineupForLiveScoring(
            game: fixture.game,
            team: fixture.homeTeam,
            modelContext: store.context
        )

        #expect(visiting.slots.map(\.player.identifier) == fixture.visitingPlayers.map(\.identifier))
        #expect(home.slots.map(\.player.identifier) == [fixture.homePitcher.identifier])
        #expect(fixture.game.lineups.count == 2)
        #expect(fixture.game.atbats.filter { $0.team.ident == fixture.visitingTeam.ident }.count == 2)
        #expect(fixture.game.atbats.filter { $0.team.ident == fixture.homeTeam.ident }.count == 1)
    }

    @Test func liveScorecardEntryPreservesEveryoneHitsLineup() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 12, everyoneHits: true)

        let result = try EditScoreView.materializeLineupForLiveScoring(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.slots.count == 12)
        #expect(result.slots.map(\.battingOrder) == Array(1...12))
        #expect(result.lineup.everyoneHits)
    }

    @Test func liveScorecardEntryFailsSafelyWhenNoDefaultLineupExists() throws {
        let store = try LineupSlotStore()
        let emptyTeam = Team(name: "Empty", coach: "", details: "")
        let opponent = Team(name: "Opponent", coach: "", details: "")
        let game = Game(date: "2026-09-09T12:00:00Z", location: "Field", highLights: "", hscore: 0, vscore: 0, vteam: emptyTeam, hteam: opponent)
        store.context.insert(emptyTeam)
        store.context.insert(opponent)
        store.context.insert(game)

        do {
            _ = try EditScoreView.materializeLineupForLiveScoring(
                game: game,
                team: emptyTeam,
                modelContext: store.context
            )
            Issue.record("Expected no-default lineup to fail safely")
        } catch LineupSlotSafetyError.noEligibleRosterPlayers {
            #expect(EditScoreView.liveScorecardLineupMaterializationMessage(for: LineupSlotSafetyError.noEligibleRosterPlayers) == "No batting lineup is available. Add roster Players or set batting order before scoring.")
        }
    }

    @Test func unorderedRosterAutomaticallyGetsStableDefaultOrder() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, players: [
            Fixture.player(name: "Charlie", number: "10", slot: 99, team: nil),
            Fixture.player(name: "Able", number: "2", slot: 99, team: nil),
            Fixture.player(name: "Baker", number: "7", slot: 99, team: nil)
        ])

        let result = try EditScoreView.materializeLineupForLiveScoring(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.source == LineupSlotMaterializationResult.Source.rosterDeterministicOrder)
        #expect(result.slots.map { $0.player.name } == ["Able", "Baker", "Charlie"])
        let persistedDefaultOrder = fixture.visitingTeam.players
            .sorted { $0.batOrder < $1.batOrder }
            .map { "\($0.batOrder):\($0.name)" }
        #expect(persistedDefaultOrder == [
            "1:Able",
            "2:Baker",
            "3:Charlie"
        ])
    }

    @Test func deterministicDefaultOrderUsesNameNumberThenPersistentIdentity() {
        let team = Team(name: "Default Order", coach: "", details: "")
        let zed = Fixture.player(name: "Zed", number: "1", slot: 99, team: team)
        let sameNameLaterNumber = Fixture.player(name: "Able", number: "12", slot: 99, team: team)
        let sameNameEarlierNumber = Fixture.player(name: "Able", number: "2", slot: 99, team: team)

        let ordered = LineupSlotSafetyCoordinator.deterministicRosterDefaultOrder(from: [
            zed,
            sameNameLaterNumber,
            sameNameEarlierNumber
        ])

        #expect(ordered.map(\.identifier) == [
            sameNameEarlierNumber.identifier,
            sameNameLaterNumber.identifier,
            zed.identifier
        ])
    }

    @Test func unorderedRosterDefaultPersistsForSubsequentNewGames() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, players: [
            Fixture.player(name: "Delta", number: "4", slot: 99, team: nil),
            Fixture.player(name: "Alpha", number: "1", slot: 99, team: nil),
            Fixture.player(name: "Charlie", number: "3", slot: 99, team: nil)
        ])
        _ = try EditScoreView.materializeLineupForLiveScoring(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )
        let nextGame = Game(
            date: "2026-08-02T12:00:00Z",
            location: "Second Field",
            highLights: "",
            hscore: 0,
            vscore: 0,
            vteam: fixture.visitingTeam,
            hteam: fixture.homeTeam
        )
        store.context.insert(nextGame)

        let result = try EditScoreView.materializeLineupForLiveScoring(
            game: nextGame,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.source == LineupSlotMaterializationResult.Source.rosterBattingOrder)
        #expect(result.slots.map { $0.player.name } == ["Alpha", "Charlie", "Delta"])
    }

    @Test func rearrangedTeamDefaultAffectsFutureGames() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 3)
        fixture.visitingPlayers[0].batOrder = 3
        fixture.visitingPlayers[1].batOrder = 1
        fixture.visitingPlayers[2].batOrder = 2
        let futureGame = Game(
            date: "2026-08-03T12:00:00Z",
            location: "Future Field",
            highLights: "",
            hscore: 0,
            vscore: 0,
            vteam: fixture.visitingTeam,
            hteam: fixture.homeTeam
        )
        store.context.insert(futureGame)

        let result = try EditScoreView.materializeLineupForLiveScoring(
            game: futureGame,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.source == LineupSlotMaterializationResult.Source.rosterBattingOrder)
        #expect(result.slots.map(\.player.identifier) == [
            fixture.visitingPlayers[1].identifier,
            fixture.visitingPlayers[2].identifier,
            fixture.visitingPlayers[0].identifier
        ])
    }

    @Test func gameSpecificCorrectionDoesNotAlterTeamDefaultOrder() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 3)
        let originalDefaults = Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) })
        let bench = Fixture.player(name: "Bench Player", number: "40", slot: 99, team: fixture.visitingTeam)
        store.context.insert(bench)
        fixture.visitingTeam.players.append(bench)

        _ = try LineupSlotSafetyCoordinator.reassignPlayer(
            in: 2,
            to: bench,
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) }) == originalDefaults)
        #expect(bench.batOrder == 99)
    }

    @Test func existingImportedBattingOrderIsUnchangedByLiveScorecardEntry() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, playerCount: 3)
        let originalDefaults = Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) })

        let result = try EditScoreView.materializeLineupForLiveScoring(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.source == LineupSlotMaterializationResult.Source.rosterBattingOrder)
        #expect(Dictionary(uniqueKeysWithValues: fixture.visitingPlayers.map { ($0.identifier, $0.batOrder) }) == originalDefaults)
    }

    @Test func unorderedEveryoneHitsRosterMaterializesAllPlayers() throws {
        let store = try LineupSlotStore()
        let fixture = Fixture.insertRosterOnlyGame(into: store.context, players: (1...12).reversed().map {
            Fixture.player(name: "Player \($0)", number: "\($0)", slot: 99, team: nil)
        }, everyoneHits: true)

        let result = try EditScoreView.materializeLineupForLiveScoring(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: store.context
        )

        #expect(result.source == LineupSlotMaterializationResult.Source.rosterDeterministicOrder)
        #expect(result.slots.count == 12)
        #expect(result.slots.map { $0.battingOrder } == Array(1...12))
    }

    @Test func reopeningScoredGameDoesNotRebuildFromTeamDefault() throws {
        let store = try LineupSlotStore()
        let fixture = try Fixture.materialized(into: store.context, playerCount: 3)
        let firstAtbat = try #require(fixture.game.atbats.first { $0.batOrder == 1 && $0.col == 1 })
        firstAtbat.result = "Single"
        firstAtbat.maxbase = "First"
        let originalAtbatIdentities = fixture.game.atbats
            .sorted { $0.batOrder < $1.batOrder }
            .map(\.ident)
        fixture.visitingPlayers[0].batOrder = 3
        fixture.visitingPlayers[1].batOrder = 1
        fixture.visitingPlayers[2].batOrder = 2
        try store.context.save()

        let reopenedContext = ModelContext(store.container)
        let reopenedGame = try #require(try reopenedContext.fetch(FetchDescriptor<Game>()).first)
        let reopenedTeam = try #require(reopenedGame.vteam)
        let result = try EditScoreView.materializeLineupForLiveScoring(
            game: reopenedGame,
            team: reopenedTeam,
            modelContext: reopenedContext
        )

        #expect(result.source == .existingLineup)
        #expect(reopenedGame.atbats.sorted { $0.batOrder < $1.batOrder }.map(\.ident) == originalAtbatIdentities)
        #expect(result.slots.map { $0.placeholderAtbat.result } == ["Single", "Result", "Result"])
    }
}

@MainActor
private struct LineupSlotStore {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }
}

@MainActor
private struct Fixture {
    let game: Game
    let visitingTeam: Team
    let homeTeam: Team
    let visitingPlayers: [Player]
    let homePitcher: Player

    static func materialized(into context: ModelContext, playerCount: Int) throws -> Fixture {
        let fixture = insertRosterOnlyGame(into: context, playerCount: playerCount)
        _ = try LineupSlotSafetyCoordinator.materializeLineupIfNeeded(
            game: fixture.game,
            team: fixture.visitingTeam,
            modelContext: context
        )
        return fixture
    }

    static func insertRosterOnlyGame(into context: ModelContext, playerCount: Int, everyoneHits: Bool = false) -> Fixture {
        let visitingTeam = Team(name: "Visitors", coach: "", details: "")
        let homeTeam = Team(name: "Home", coach: "", details: "")
        let visitingPlayers = (1...playerCount).map { slot in
            player(name: "Visitor \(slot)", number: "\(slot)", slot: slot, team: visitingTeam)
        }
        let homePitcher = player(name: "Home Pitcher", number: "99", slot: 1, team: homeTeam)
        let game = Game(
            date: "2026-08-01T12:00:00Z",
            location: "Lineup Slot Park",
            highLights: "",
            hscore: 0,
            vscore: 0,
            everyOneHits: everyoneHits,
            vteam: visitingTeam,
            hteam: homeTeam
        )

        context.insert(visitingTeam)
        context.insert(homeTeam)
        context.insert(homePitcher)
        context.insert(game)
        for player in visitingPlayers {
            context.insert(player)
        }
        visitingTeam.players = visitingPlayers
        homeTeam.players = [homePitcher]
        return Fixture(
            game: game,
            visitingTeam: visitingTeam,
            homeTeam: homeTeam,
            visitingPlayers: visitingPlayers,
            homePitcher: homePitcher
        )
    }

    static func insertRosterOnlyGame(into context: ModelContext, players: [Player], everyoneHits: Bool = false) -> Fixture {
        let visitingTeam = Team(name: "Visitors", coach: "", details: "")
        let homeTeam = Team(name: "Home", coach: "", details: "")
        let visitingPlayers = players
        for player in visitingPlayers {
            player.team = visitingTeam
        }
        let homePitcher = player(name: "Home Pitcher", number: "99", slot: 1, team: homeTeam)
        let game = Game(
            date: "2026-08-01T12:00:00Z",
            location: "Lineup Slot Park",
            highLights: "",
            hscore: 0,
            vscore: 0,
            everyOneHits: everyoneHits,
            vteam: visitingTeam,
            hteam: homeTeam
        )

        context.insert(visitingTeam)
        context.insert(homeTeam)
        context.insert(homePitcher)
        context.insert(game)
        for player in visitingPlayers {
            context.insert(player)
        }
        visitingTeam.players = visitingPlayers
        homeTeam.players = [homePitcher]
        return Fixture(
            game: game,
            visitingTeam: visitingTeam,
            homeTeam: homeTeam,
            visitingPlayers: visitingPlayers,
            homePitcher: homePitcher
        )
    }

    static func player(name: String, number: String, slot: Int, team: Team?) -> Player {
        Player(name: name, number: number, position: "SS", batDir: "R", batOrder: slot, team: team)
    }

    static func placeholder(game: Game, team: Team, player: Player, slot: Int) -> Atbat {
        Atbat(
            game: game,
            team: team,
            player: player,
            result: "Result",
            maxbase: "No Bases",
            batOrder: slot,
            outAt: "Safe",
            inning: 1,
            seq: slot,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
    }
}

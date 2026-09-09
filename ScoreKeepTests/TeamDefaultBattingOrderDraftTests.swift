import Foundation
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Team default batting order draft")
struct TeamDefaultBattingOrderDraftTests {
    @Test func ninePlayerOrderWithExtrasIncludesFullRoster() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let orderedPlayers = (1...9).map {
            TeamDefaultBattingOrderDraftFixture.player(name: "Starter \($0)", number: "\($0)", batOrder: $0, team: team)
        }
        let extras = [
            TeamDefaultBattingOrderDraftFixture.player(name: "Bench One", number: "21", batOrder: 99, team: team),
            TeamDefaultBattingOrderDraftFixture.player(name: "Bench Two", number: "22", batOrder: 99, team: team)
        ]

        let draft = TeamDefaultBattingOrderDraft(players: orderedPlayers + extras)

        #expect(draft.orderedEntries.map(\.playerIdentifier) == orderedPlayers.map(\.identifier))
        #expect(draft.orderedEntries.map(\.draftBattingOrder) == Array(1...9))
        #expect(draft.benchEntries.map(\.playerIdentifier) == extras.map(\.identifier))
        #expect(draft.benchEntries.map(\.draftBattingOrder) == [99, 99])
        #expect(draft.entries.count == 11)
    }

    @Test func everyoneHitsBeyondNineRemainsInOrder() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let players = (1...12).map {
            TeamDefaultBattingOrderDraftFixture.player(name: "Hitter \($0)", number: "\($0)", batOrder: $0, team: team)
        }

        let draft = TeamDefaultBattingOrderDraft(players: players)

        #expect(draft.orderedEntries.count == 12)
        #expect(draft.orderedEntries.map(\.draftBattingOrder) == Array(1...12))
        #expect(draft.orderedEntries.map(\.playerIdentifier) == players.map(\.identifier))
        #expect(draft.benchEntries.isEmpty)
    }

    @Test func reorderWithinActiveOrderCompactsDraftOnly() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let players = (1...4).map {
            TeamDefaultBattingOrderDraftFixture.player(name: "Player \($0)", number: "\($0)", batOrder: $0, team: team)
        }
        var draft = TeamDefaultBattingOrderDraft(players: players)

        draft.reorderActive(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(draft.orderedEntries.map(\.playerIdentifier) == [
            players[1].identifier,
            players[2].identifier,
            players[0].identifier,
            players[3].identifier
        ])
        #expect(draft.orderedEntries.map(\.draftBattingOrder) == [1, 2, 3, 4])
        #expect(players.map(\.batOrder) == [1, 2, 3, 4])
    }

    @Test func benchPlayerCanMoveIntoActiveOrder() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let first = TeamDefaultBattingOrderDraftFixture.player(name: "First", number: "1", batOrder: 1, team: team)
        let second = TeamDefaultBattingOrderDraftFixture.player(name: "Second", number: "2", batOrder: 2, team: team)
        let bench = TeamDefaultBattingOrderDraftFixture.player(name: "Bench", number: "20", batOrder: 99, team: team)
        var draft = TeamDefaultBattingOrderDraft(players: [first, second, bench])

        draft.movePlayerToOrder(playerIdentifier: bench.identifier, at: 1)

        #expect(draft.orderedEntries.map(\.playerIdentifier) == [first.identifier, bench.identifier, second.identifier])
        #expect(draft.orderedEntries.map(\.draftBattingOrder) == [1, 2, 3])
        #expect(draft.benchEntries.isEmpty)
        #expect(bench.batOrder == 99)
    }

    @Test func activePlayerCanMoveOutOfOrder() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let players = (1...3).map {
            TeamDefaultBattingOrderDraftFixture.player(name: "Player \($0)", number: "\($0)", batOrder: $0, team: team)
        }
        var draft = TeamDefaultBattingOrderDraft(players: players)

        draft.movePlayerOutOfOrder(playerIdentifier: players[1].identifier)

        #expect(draft.orderedEntries.map(\.playerIdentifier) == [players[0].identifier, players[2].identifier])
        #expect(draft.orderedEntries.map(\.draftBattingOrder) == [1, 2])
        #expect(draft.benchEntries.map(\.playerIdentifier) == [players[1].identifier])
        #expect(draft.benchEntries.first?.draftBattingOrder == 99)
        #expect(players[1].batOrder == 2)
    }

    @Test func duplicateGappedAndInvalidIncomingOrdersNormalizeInDraftOnly() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let alpha = TeamDefaultBattingOrderDraftFixture.player(name: "Alpha", number: "2", batOrder: 1, team: team)
        let beta = TeamDefaultBattingOrderDraftFixture.player(name: "Beta", number: "1", batOrder: 1, team: team)
        let gap = TeamDefaultBattingOrderDraftFixture.player(name: "Gap", number: "3", batOrder: 4, team: team)
        let zero = TeamDefaultBattingOrderDraftFixture.player(name: "Zero", number: "4", batOrder: 0, team: team)
        let high = TeamDefaultBattingOrderDraftFixture.player(name: "High", number: "5", batOrder: 100, team: team)

        let draft = TeamDefaultBattingOrderDraft(players: [high, gap, beta, zero, alpha])

        #expect(draft.orderedEntries.map(\.playerIdentifier) == [alpha.identifier, beta.identifier, gap.identifier])
        #expect(draft.orderedEntries.map(\.draftBattingOrder) == [1, 2, 3])
        #expect(draft.benchEntries.map(\.playerIdentifier) == [high.identifier, zero.identifier])
        #expect([alpha, beta, gap, zero, high].map(\.batOrder) == [1, 1, 4, 0, 100])
    }

    @Test func ambiguousUnorderedPlayersSortDeterministically() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let laterIdentity = TeamDefaultBattingOrderDraftFixture.player(
            identifier: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Same",
            number: "7",
            batOrder: 99,
            team: team
        )
        let earlierIdentity = TeamDefaultBattingOrderDraftFixture.player(
            identifier: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Same",
            number: "7",
            batOrder: 99,
            team: team
        )

        let draft = TeamDefaultBattingOrderDraft(players: [laterIdentity, earlierIdentity])

        #expect(draft.benchEntries.map(\.playerIdentifier) == [earlierIdentity.identifier, laterIdentity.identifier])
    }

    @Test func pitchersRemainEligibleForDefaultOrder() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let starter = TeamDefaultBattingOrderDraftFixture.player(name: "Starter", number: "35", position: "SP", batOrder: 99, team: team)
        let reliever = TeamDefaultBattingOrderDraftFixture.player(name: "Reliever", number: "48", position: "RP", batOrder: 99, team: team)
        let pitcher = TeamDefaultBattingOrderDraftFixture.player(name: "Pitcher", number: "44", position: "P", batOrder: 99, team: team)
        var draft = TeamDefaultBattingOrderDraft(players: [starter, reliever, pitcher])

        draft.movePlayerToOrder(playerIdentifier: reliever.identifier)
        draft.movePlayerToOrder(playerIdentifier: starter.identifier)
        draft.movePlayerToOrder(playerIdentifier: pitcher.identifier)

        #expect(draft.orderedEntries.map(\.playerIdentifier) == [reliever.identifier, starter.identifier, pitcher.identifier])
        #expect(draft.orderedEntries.map(\.position) == ["RP", "SP", "P"])
        #expect(draft.orderedEntries.map(\.draftBattingOrder) == [1, 2, 3])
    }

    @Test func draftEditsDoNotPersistUntilFutureSave() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let first = TeamDefaultBattingOrderDraftFixture.player(name: "First", number: "1", batOrder: 1, team: team)
        let second = TeamDefaultBattingOrderDraftFixture.player(name: "Second", number: "2", batOrder: 2, team: team)
        let bench = TeamDefaultBattingOrderDraftFixture.player(name: "Bench", number: "20", batOrder: 99, team: team)
        var draft = TeamDefaultBattingOrderDraft(players: [first, second, bench])

        draft.movePlayerToOrder(playerIdentifier: bench.identifier, at: 0)
        draft.movePlayerOutOfOrder(playerIdentifier: second.identifier)
        let proposedOrders = draft.proposedBattingOrdersByPlayerIdentifier()

        #expect(first.batOrder == 1)
        #expect(second.batOrder == 2)
        #expect(bench.batOrder == 99)
        #expect(proposedOrders[bench.identifier] == 1)
        #expect(proposedOrders[first.identifier] == 2)
        #expect(proposedOrders[second.identifier] == 99)
    }

    @Test func synchronizingRosterAddsNewPlayersAsBenchWithoutLosingDraftOrder() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let first = TeamDefaultBattingOrderDraftFixture.player(name: "First", number: "1", batOrder: 1, team: team)
        let second = TeamDefaultBattingOrderDraftFixture.player(name: "Second", number: "2", batOrder: 2, team: team)
        let newPlayer = TeamDefaultBattingOrderDraftFixture.player(name: "New Player", number: "30", batOrder: 99, team: team)
        var draft = TeamDefaultBattingOrderDraft(players: [first, second])

        draft.reorderActive(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        draft.synchronizeRosterPlayers([first, second, newPlayer])

        #expect(draft.orderedEntries.map(\.playerIdentifier) == [second.identifier, first.identifier])
        #expect(draft.orderedEntries.map(\.draftBattingOrder) == [1, 2])
        #expect(draft.benchEntries.map(\.playerIdentifier) == [newPlayer.identifier])
        #expect(newPlayer.batOrder == 99)
    }

    @Test func movingRosterRowsCanMoveBetweenActiveAndBenchRegions() {
        let team = TeamDefaultBattingOrderDraftFixture.team()
        let first = TeamDefaultBattingOrderDraftFixture.player(name: "First", number: "1", batOrder: 1, team: team)
        let second = TeamDefaultBattingOrderDraftFixture.player(name: "Second", number: "2", batOrder: 2, team: team)
        let bench = TeamDefaultBattingOrderDraftFixture.player(name: "Bench", number: "20", batOrder: 99, team: team)
        let extra = TeamDefaultBattingOrderDraftFixture.player(name: "Extra", number: "21", batOrder: 99, team: team)
        var draft = TeamDefaultBattingOrderDraft(players: [first, second, bench, extra])

        draft.moveRosterEntries(fromOffsets: IndexSet(integer: 2), toOffset: 1)

        #expect(draft.orderedEntries.map(\.playerIdentifier) == [first.identifier, bench.identifier, second.identifier])
        #expect(draft.orderedEntries.map(\.draftBattingOrder) == [1, 2, 3])
        #expect(draft.benchEntries.map(\.playerIdentifier) == [extra.identifier])

        draft.moveRosterEntries(fromOffsets: IndexSet(integer: 1), toOffset: 4)

        #expect(draft.orderedEntries.map(\.playerIdentifier) == [first.identifier, second.identifier])
        #expect(draft.orderedEntries.map(\.draftBattingOrder) == [1, 2])
        #expect(draft.benchEntries.map(\.playerIdentifier) == [bench.identifier, extra.identifier])
    }
}

private enum TeamDefaultBattingOrderDraftFixture {
    static func team() -> Team {
        Team(name: "Default Order Team", coach: "", details: "")
    }

    static func player(
        identifier: UUID = UUID(),
        name: String,
        number: String,
        position: String = "SS",
        batDir: String = "R",
        batOrder: Int,
        team: Team
    ) -> Player {
        Player(
            identifier: identifier,
            name: name,
            number: number,
            position: position,
            batDir: batDir,
            batOrder: batOrder,
            team: team
        )
    }
}

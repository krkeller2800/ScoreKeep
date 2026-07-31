import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
struct ScoreKeepMigrationBaselineOrderingTests {
    @Test("lineup fingerprint ignores relationship traversal order when batting order is unchanged")
    func lineupFingerprintIgnoresTraversalOrderWhenBattingOrderUnchanged() throws {
        let forward = try makeRecord(lineupOrder: [.first, .second], firstBatOrder: 1, secondBatOrder: 2)
        let reversed = try makeRecord(lineupOrder: [.second, .first], firstBatOrder: 1, secondBatOrder: 2)

        #expect(forward.orderingFingerprint == reversed.orderingFingerprint)
    }

    @Test("lineup fingerprint changes when batting order changes")
    func lineupFingerprintChangesWhenBattingOrderChanges() throws {
        let original = try makeRecord(lineupOrder: [.first, .second], firstBatOrder: 1, secondBatOrder: 2)
        let changed = try makeRecord(lineupOrder: [.first, .second], firstBatOrder: 2, secondBatOrder: 1)

        #expect(original.orderingFingerprint != changed.orderingFingerprint)
    }

    @Test("substitution evidence ignores relationship traversal order")
    func substitutionEvidenceIgnoresRelationshipTraversalOrder() throws {
        let forward = try makeRecord(
            lineupOrder: [.first, .second],
            firstBatOrder: 1,
            secondBatOrder: 2,
            replacedOrder: [.first, .second],
            incomingOrder: [.third, .fourth]
        )
        let reversed = try makeRecord(
            lineupOrder: [.first, .second],
            firstBatOrder: 1,
            secondBatOrder: 2,
            replacedOrder: [.second, .first],
            incomingOrder: [.fourth, .third]
        )

        #expect(forward.substitutionEvidence == reversed.substitutionEvidence)
    }

    @Test("substitution evidence changes when membership changes")
    func substitutionEvidenceChangesWhenMembershipChanges() throws {
        let original = try makeRecord(
            lineupOrder: [.first, .second],
            firstBatOrder: 1,
            secondBatOrder: 2,
            replacedOrder: [.first, .second],
            incomingOrder: [.third, .fourth]
        )
        let changed = try makeRecord(
            lineupOrder: [.first, .second],
            firstBatOrder: 1,
            secondBatOrder: 2,
            replacedOrder: [.first, .third],
            incomingOrder: [.third, .fourth]
        )

        #expect(original.substitutionEvidence != changed.substitutionEvidence)
    }

    @Test("incorrect lineup positions still fail through ordering fingerprint")
    func incorrectLineupPositionsStillFailThroughOrderingFingerprint() throws {
        let original = try makeRecord(
            lineupOrder: [.first, .second],
            firstBatOrder: 1,
            secondBatOrder: 2,
            replacedOrder: [.first, .second],
            incomingOrder: [.third, .fourth]
        )
        let changed = try makeRecord(
            lineupOrder: [.first, .second],
            firstBatOrder: 2,
            secondBatOrder: 1,
            replacedOrder: [.first, .second],
            incomingOrder: [.third, .fourth]
        )

        #expect(original.substitutionEvidence == changed.substitutionEvidence)
        #expect(original.orderingFingerprint != changed.orderingFingerprint)
    }

    private enum FixturePlayer {
        case first
        case second
        case third
        case fourth
    }

    private func makeRecord(
        lineupOrder: [FixturePlayer],
        firstBatOrder: Int,
        secondBatOrder: Int,
        replacedOrder: [FixturePlayer] = [],
        incomingOrder: [FixturePlayer] = []
    ) throws -> ScoreKeepMigrationBaselineRecord {
        let schema = Schema([Game.self, Team.self, Player.self, Atbat.self, Lineup.self, Pitcher.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let visiting = Team(
            ident: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Visitors",
            coach: "",
            details: ""
        )
        let home = Team(
            ident: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "Home",
            coach: "",
            details: ""
        )
        let first = Player(
            identifier: UUID(uuidString: "10000000-0000-0000-0000-000000000011")!,
            name: "First",
            number: "1",
            position: "SS",
            batDir: "R",
            batOrder: firstBatOrder,
            team: visiting
        )
        let second = Player(
            identifier: UUID(uuidString: "10000000-0000-0000-0000-000000000012")!,
            name: "Second",
            number: "2",
            position: "CF",
            batDir: "L",
            batOrder: secondBatOrder,
            team: visiting
        )
        let third = Player(
            identifier: UUID(uuidString: "10000000-0000-0000-0000-000000000013")!,
            name: "Third",
            number: "3",
            position: "LF",
            batDir: "R",
            batOrder: 3,
            team: visiting
        )
        let fourth = Player(
            identifier: UUID(uuidString: "10000000-0000-0000-0000-000000000014")!,
            name: "Fourth",
            number: "4",
            position: "RF",
            batDir: "L",
            batOrder: 4,
            team: visiting
        )
        let playersByFixture: [FixturePlayer: Player] = [
            .first: first,
            .second: second,
            .third: third,
            .fourth: fourth
        ]
        let game = Game(
            ident: UUID(uuidString: "10000000-0000-0000-0000-000000000021")!,
            date: "2026-07-30",
            location: "Fixture Field",
            highLights: "",
            hscore: 0,
            vscore: 0,
            vteam: visiting,
            hteam: home
        )
        let lineupPlayers = lineupOrder.compactMap { playersByFixture[$0] }
        let lineup = Lineup(
            ident: UUID(uuidString: "10000000-0000-0000-0000-000000000031")!,
            everyoneHits: false,
            game: game,
            team: visiting,
            inning: 1,
            players: lineupPlayers
        )

        visiting.players = [first, second, third, fourth]
        visiting.games = [game]
        home.games = [game]
        game.players = [first, second, third, fourth]
        game.lineups = [lineup]
        game.replaced = replacedOrder.compactMap { playersByFixture[$0] }
        game.incomings = incomingOrder.compactMap { playersByFixture[$0] }

        context.insert(visiting)
        context.insert(home)
        context.insert(first)
        context.insert(second)
        context.insert(third)
        context.insert(fourth)
        context.insert(game)
        context.insert(lineup)
        try context.save()

        return try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: context)
    }
}

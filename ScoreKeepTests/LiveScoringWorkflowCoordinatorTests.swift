import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Live scoring workflow coordination")
struct LiveScoringWorkflowCoordinatorTests {
    @Test("selecting an existing scorecard cell returns the existing legacy at-bat without duplication")
    func selectingExistingScorecardCellReturnsExistingAtbatWithoutDuplication() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let result = coordinator.selectAtbat(
            column: 1,
            rowIndex: 0,
            sourceAtbat: fixture.visitingFirst,
            displayedAtbats: fixture.displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )

        #expect(result.disposition == .noChange)
        #expect(result.atbat?.ident == fixture.visitingFirst.ident)
        #expect(fixture.game.atbats.count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("selecting an empty scorecard cell creates one legacy placeholder at-bat and no canonical records")
    func selectingEmptyScorecardCellCreatesOneLegacyPlaceholderAtbatAndNoCanonicalRecords() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let result = coordinator.selectAtbat(
            column: 2,
            rowIndex: 0,
            sourceAtbat: fixture.visitingFirst,
            displayedAtbats: fixture.displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )

        let selected = try #require(result.atbat)
        #expect(result.disposition == .success)
        #expect(selected.result == "Result")
        #expect(selected.maxbase == "No Bases")
        #expect(selected.outAt == "Safe")
        #expect(selected.inning == 99)
        #expect(selected.seq == 99)
        #expect(selected.col == 2)
        #expect(selected.batOrder == 1)
        #expect(fixture.game.atbats.count == 3)
        #expect(try store.fetchLegacyAtbats().count == 3)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("projection refresh preserves legacy scoring outcomes and pitcher marker updates")
    func projectionRefreshPreservesLegacyScoringOutcomesAndPitcherMarkerUpdates() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game)
        store.context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        fixture.visitingFirst.result = "Single"
        fixture.visitingSecond.result = "Ground Out"
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let result = coordinator.refreshProjections(
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            game: fixture.game,
            save: { try store.context.save() }
        )

        #expect(result.disposition == .success)
        #expect(fixture.visitingFirst.seq == 1)
        #expect(abs(Double(fixture.visitingFirst.inning) - 0.1) < 0.0001)
        #expect(fixture.visitingFirst.maxbase == "First")
        #expect(fixture.visitingSecond.seq == 2)
        #expect(fixture.visitingSecond.outs == 1)
        #expect(result.inningStatus.outs == 1)
        #expect(result.inningStatus.onFirst)
        #expect(result.columnBoxes[1].hits == 1)
        #expect(pitcher.startInn == 1)
        #expect(pitcher.endInn == 1)
        #expect(pitcher.eOuts == 1)
        #expect(pitcher.eBats == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("invalid scorecard selection fails closed without creating records")
    func invalidScorecardSelectionFailsClosedWithoutCreatingRecords() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let result = coordinator.selectAtbat(
            column: 0,
            rowIndex: 0,
            sourceAtbat: fixture.visitingFirst,
            displayedAtbats: fixture.displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )

        #expect(result.disposition == .validationFailed)
        #expect(result.atbat == nil)
        #expect(fixture.game.atbats.count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("persistence failure is reported as failure rather than success")
    func persistenceFailureIsReportedAsFailureRatherThanSuccess() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let result = coordinator.selectAtbat(
            column: 2,
            rowIndex: 1,
            sourceAtbat: fixture.visitingSecond,
            displayedAtbats: fixture.displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { throw InjectedSaveError() }
        )

        #expect(result.disposition == .persistenceFailed)
        #expect(result.message?.contains("Error saving new atbats") == true)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }
}

private struct Store {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    func fetchLegacyAtbats() throws -> [Atbat] {
        try context.fetch(FetchDescriptor<Atbat>())
    }

    func canonicalScoringRecordCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<CanonicalGameHistoryRecord>()) +
            context.fetchCount(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>()) +
            context.fetchCount(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>()) +
            context.fetchCount(FetchDescriptor<CanonicalScoringEventPayloadRecord>()) +
            context.fetchCount(FetchDescriptor<CanonicalScoringCorrectionRecord>())
    }
}

private struct Fixture {
    let game: Game
    let visitingTeam: Team
    let homeTeam: Team
    let visitingFirst: Atbat
    let visitingSecond: Atbat
    let homePitcher: Player

    var displayedAtbats: [Atbat] {
        [visitingFirst, visitingSecond]
    }

    static func insertGame(into context: ModelContext) -> Fixture {
        let visitingTeam = Team(name: "Visitors", coach: "", details: "")
        let homeTeam = Team(name: "Home", coach: "", details: "")
        let visitingFirstPlayer = Player(name: "Visitor One", number: "1", position: "SS", batDir: "R", batOrder: 1, team: visitingTeam)
        let visitingSecondPlayer = Player(name: "Visitor Two", number: "2", position: "2B", batDir: "R", batOrder: 2, team: visitingTeam)
        let homePitcher = Player(name: "Home Pitcher", number: "9", position: "P", batDir: "R", batOrder: 1, team: homeTeam)
        let game = Game(
            date: "2026-07-18T12:00:00Z",
            location: "Task 5.10 Field",
            highLights: "",
            hscore: 0,
            vscore: 0,
            vteam: visitingTeam,
            hteam: homeTeam
        )
        let visitingFirst = Atbat(
            game: game,
            team: visitingTeam,
            player: visitingFirstPlayer,
            result: "Result",
            maxbase: "No Bases",
            batOrder: 1,
            outAt: "Safe",
            inning: 1,
            seq: 1,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
        let visitingSecond = Atbat(
            game: game,
            team: visitingTeam,
            player: visitingSecondPlayer,
            result: "Result",
            maxbase: "No Bases",
            batOrder: 2,
            outAt: "Safe",
            inning: 1,
            seq: 2,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )

        context.insert(visitingTeam)
        context.insert(homeTeam)
        context.insert(visitingFirstPlayer)
        context.insert(visitingSecondPlayer)
        context.insert(homePitcher)
        context.insert(game)
        context.insert(visitingFirst)
        context.insert(visitingSecond)

        visitingTeam.players = [visitingFirstPlayer, visitingSecondPlayer]
        homeTeam.players = [homePitcher]
        game.players = [visitingFirstPlayer, visitingSecondPlayer, homePitcher]
        game.atbats = [visitingFirst, visitingSecond]

        return Fixture(
            game: game,
            visitingTeam: visitingTeam,
            homeTeam: homeTeam,
            visitingFirst: visitingFirst,
            visitingSecond: visitingSecond,
            homePitcher: homePitcher
        )
    }
}

private struct InjectedSaveError: Error {}

import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Live scoring workflow coordination")
struct LiveScoringWorkflowCoordinatorTests {
    @Test("blank first current cell without pitcher fails visibly without creating a placeholder")
    func blankFirstCurrentCellWithoutPitcherFailsVisiblyWithoutCreatingPlaceholder() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let presenter = LiveScoringShellPresentation()

        let result = coordinator.selectAtbat(
            column: 1,
            rowIndex: 0,
            sourceAtbat: fixture.visitingFirst,
            displayedAtbats: fixture.displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )
        let presentation = presenter.presentSelectionResult(result)

        #expect(result.disposition == .validationFailed)
        #expect(result.atbat == nil)
        #expect(result.message == "Select the starting pitcher before scoring the game.")
        #expect(!presentation.shouldPresentScoringSheet)
        #expect(!presentation.shouldMarkChanged)
        #expect(presentation.message == "Select the starting pitcher before scoring the game.")
        #expect(fixture.game.atbats.count == 2)
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("blank first current cell with starting pitcher selects existing lineup placeholder")
    func blankFirstCurrentCellWithStartingPitcherSelectsExistingLineupPlaceholder() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
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
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("later current cell without pitcher fails visibly without creating a placeholder")
    func laterCurrentCellWithoutPitcherFailsVisiblyWithoutCreatingPlaceholder() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        fixture.visitingFirst.seq = 1
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let presenter = LiveScoringShellPresentation()

        let result = coordinator.selectAtbat(
            column: 1,
            rowIndex: 1,
            sourceAtbat: fixture.visitingSecond,
            displayedAtbats: fixture.displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )
        let presentation = presenter.presentSelectionResult(result)

        #expect(result.disposition == .validationFailed)
        #expect(result.atbat == nil)
        #expect(result.message == "Select the starting pitcher before scoring the game.")
        #expect(!presentation.shouldPresentScoringSheet)
        #expect(!presentation.shouldMarkChanged)
        #expect(presentation.message == "Select the starting pitcher before scoring the game.")
        #expect(fixture.game.atbats.count == 2)
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("completed scorecard cell remains selectable for correction without active pitcher")
    func completedScorecardCellRemainsSelectableForCorrectionWithoutActivePitcher() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        fixture.visitingFirst.seq = 1
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
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("selecting an empty scorecard cell creates one legacy placeholder at-bat and no canonical records")
    func selectingEmptyScorecardCellCreatesOneLegacyPlaceholderAtbatAndNoCanonicalRecords() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        fixture.visitingFirst.result = "Ground Out"
        fixture.visitingFirst.seq = 1
        fixture.visitingFirst.outs = 1
        fixture.visitingSecond.result = "Ground Out"
        fixture.visitingSecond.seq = 2
        fixture.visitingSecond.outs = 2
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

    @Test("partially scored game rejects unused non-current cells when current placeholder is absent")
    func partiallyScoredGameRejectsUnusedNonCurrentCellsWhenCurrentPlaceholderIsAbsent() throws {
        let presenter = LiveScoringShellPresentation()

        do {
            let store = try Store()
            let fixture = Fixture.insertGame(into: store.context)
            _ = Fixture.insertPitcher(for: fixture, into: store.context)
            markFirstTwoVisitorsCompleted(fixture)
            try store.context.save()
            let coordinator = LiveScoringWorkflowCoordinator()
            let prepared = coordinator.prepareLiveGameState(
                game: fixture.game,
                battingTeam: fixture.visitingTeam,
                displayedAtbats: fixture.displayedAtbats,
                pitchers: fixture.game.pitchers
            )

            let current = coordinator.selectAtbat(
                column: 2,
                rowIndex: 0,
                sourceAtbat: fixture.visitingFirst,
                displayedAtbats: fixture.displayedAtbats,
                game: fixture.game,
                modelContext: store.context,
                save: { try store.context.save() }
            )
            let presentation = presenter.presentSelectionResult(current)

            #expect(prepared.currentBatter?.identity == fixture.visitingFirst.player.identifier)
            #expect(prepared.currentScorecardColumn == 2)
            #expect(prepared.currentOrPendingLegacyAtbat == nil)
            #expect(current.disposition == .success)
            #expect(current.atbat?.player.identifier == fixture.visitingFirst.player.identifier)
            #expect(current.atbat?.col == 2)
            #expect(presentation.shouldPresentScoringSheet)
            #expect(fixture.game.atbats.count == 3)
            #expect(try store.fetchLegacyAtbats().count == 3)
        }

        do {
            let store = try Store()
            let fixture = Fixture.insertGame(into: store.context)
            _ = Fixture.insertPitcher(for: fixture, into: store.context)
            markFirstTwoVisitorsCompleted(fixture)
            try store.context.save()
            let coordinator = LiveScoringWorkflowCoordinator()

            let wrongUnused = coordinator.selectAtbat(
                column: 2,
                rowIndex: 1,
                sourceAtbat: fixture.visitingSecond,
                displayedAtbats: fixture.displayedAtbats,
                game: fixture.game,
                modelContext: store.context,
                save: { try store.context.save() }
            )
            let presentation = presenter.presentSelectionResult(wrongUnused)

            #expect(wrongUnused.disposition == .validationFailed)
            #expect(wrongUnused.atbat == nil)
            #expect(!presentation.shouldPresentScoringSheet)
            #expect(fixture.game.atbats.count == 2)
            #expect(try store.fetchLegacyAtbats().count == 2)
        }

        do {
            let store = try Store()
            let fixture = Fixture.insertGame(into: store.context)
            _ = Fixture.insertPitcher(for: fixture, into: store.context)
            markFirstTwoVisitorsCompleted(fixture)
            let wrongPlaceholder = Atbat(
                game: fixture.game,
                team: fixture.visitingTeam,
                player: fixture.visitingSecond.player,
                result: "Result",
                maxbase: "No Bases",
                batOrder: fixture.visitingSecond.batOrder,
                outAt: "Safe",
                inning: 99,
                seq: 99,
                col: 2,
                rbis: 0,
                outs: 0,
                sacFly: 0,
                sacBunt: 0,
                stolenBases: 0
            )
            store.context.insert(wrongPlaceholder)
            fixture.game.atbats.append(wrongPlaceholder)
            try store.context.save()
            let coordinator = LiveScoringWorkflowCoordinator()
            let displayedAtbats = fixture.displayedAtbats + [wrongPlaceholder]

            let wrongExistingPlaceholder = coordinator.selectAtbat(
                column: 2,
                rowIndex: 1,
                sourceAtbat: fixture.visitingSecond,
                displayedAtbats: displayedAtbats,
                game: fixture.game,
                modelContext: store.context,
                save: { try store.context.save() }
            )
            let presentation = presenter.presentSelectionResult(wrongExistingPlaceholder)

            #expect(wrongExistingPlaceholder.disposition == .validationFailed)
            #expect(wrongExistingPlaceholder.atbat == nil)
            #expect(!presentation.shouldPresentScoringSheet)
            #expect(fixture.game.atbats.count == 3)
            #expect(try store.fetchLegacyAtbats().count == 3)
        }

        do {
            let store = try Store()
            let fixture = Fixture.insertGame(into: store.context)
            _ = Fixture.insertPitcher(for: fixture, into: store.context)
            markFirstTwoVisitorsCompleted(fixture)
            try store.context.save()
            let coordinator = LiveScoringWorkflowCoordinator()

            let completed = coordinator.selectAtbat(
                column: 1,
                rowIndex: 0,
                sourceAtbat: fixture.visitingFirst,
                displayedAtbats: fixture.displayedAtbats,
                game: fixture.game,
                modelContext: store.context,
                save: { try store.context.save() }
            )
            let presentation = presenter.presentSelectionResult(completed)

            #expect(completed.disposition == .noChange)
            #expect(completed.atbat?.ident == fixture.visitingFirst.ident)
            #expect(presentation.shouldPresentScoringSheet)
            #expect(fixture.game.atbats.count == 2)
            #expect(try store.fetchLegacyAtbats().count == 2)
        }
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

    @Test("invalid open-cell guidance targets the concrete pending at-bat when logical slot is ambiguous")
    func invalidOpenCellGuidanceTargetsConcretePendingAtbatWhenLogicalSlotIsAmbiguous() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        let duplicateSlotPlayer = Player(
            name: "Duplicate Slot Visitor",
            number: "22",
            position: "RF",
            batDir: "L",
            batOrder: 2,
            team: fixture.visitingTeam
        )
        let duplicateSlotAtbat = Atbat(
            game: fixture.game,
            team: fixture.visitingTeam,
            player: duplicateSlotPlayer,
            result: "Result",
            maxbase: "No Bases",
            batOrder: 2,
            outAt: "Safe",
            inning: 1,
            seq: 3,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
        store.context.insert(duplicateSlotPlayer)
        store.context.insert(duplicateSlotAtbat)
        fixture.visitingTeam.players.append(duplicateSlotPlayer)
        fixture.game.players.append(duplicateSlotPlayer)
        fixture.game.atbats.append(duplicateSlotAtbat)
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        fixture.visitingFirst.inning = 0.1
        fixture.visitingFirst.seq = 1
        fixture.visitingFirst.outs = 0
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let displayedAtbats = [fixture.visitingFirst, fixture.visitingSecond, duplicateSlotAtbat]

        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: [pitcher]
        )
        let invalid = coordinator.selectAtbat(
            column: 1,
            rowIndex: 2,
            sourceAtbat: duplicateSlotAtbat,
            displayedAtbats: displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )
        let current = coordinator.selectAtbat(
            column: 1,
            rowIndex: 99,
            sourceAtbat: fixture.visitingSecond,
            displayedAtbats: displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )
        let completed = coordinator.selectAtbat(
            column: 1,
            rowIndex: 0,
            sourceAtbat: fixture.visitingFirst,
            displayedAtbats: displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )

        #expect(prepared.currentOrPendingLegacyAtbat?.identity == fixture.visitingSecond.ident)
        #expect(invalid.disposition == .validationFailed)
        #expect(invalid.targetAction == .scorecardCell(column: 1, battingOrder: 2))
        #expect(invalid.targetCell?.atbatIdentity == fixture.visitingSecond.ident)
        #expect(invalid.targetCell?.playerIdentity == fixture.visitingSecond.player.identifier)
        #expect(invalid.targetCell?.column == 1)
        #expect(invalid.targetCell?.battingOrder == 2)
        #expect(invalid.targetCell?.sequence == 2)
        #expect(invalid.renderedTarget?.renderedRowIdentity == fixture.visitingSecond.ident)
        #expect(invalid.renderedTarget?.column == 1)
        #expect(invalid.renderedTarget?.uiIdentifier == LiveScoringWorkflowCoordinator.RenderedScorecardCellTarget.uiIdentifier(renderedRowIdentity: fixture.visitingSecond.ident, column: 1))
        #expect(invalid.renderedTarget?.uiIdentifier != LiveScoringWorkflowCoordinator.RenderedScorecardCellTarget.uiIdentifier(renderedRowIdentity: duplicateSlotAtbat.ident, column: 1))
        #expect(duplicateSlotAtbat.batOrder == fixture.visitingSecond.batOrder)
        #expect(current.disposition == .noChange)
        #expect(current.atbat?.ident == fixture.visitingSecond.ident)
        #expect(completed.disposition == .noChange)
        #expect(completed.atbat?.ident == fixture.visitingFirst.ident)
        #expect(fixture.game.atbats.count == 3)
        #expect(try store.fetchLegacyAtbats().count == 3)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("later-column invalid guidance maps concrete pending at-bat to rendered row target")
    func laterColumnInvalidGuidanceMapsConcretePendingAtbatToRenderedRowTarget() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        _ = Fixture.insertPitcher(for: fixture, into: store.context)
        let pendingFirstInSecondColumn = Atbat(
            game: fixture.game,
            team: fixture.visitingTeam,
            player: fixture.visitingFirst.player,
            result: "Result",
            maxbase: "No Bases",
            batOrder: fixture.visitingFirst.batOrder,
            outAt: "Safe",
            inning: 99,
            seq: 99,
            col: 2,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
        store.context.insert(pendingFirstInSecondColumn)
        fixture.game.atbats.append(pendingFirstInSecondColumn)
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        fixture.visitingFirst.inning = 0.1
        fixture.visitingFirst.seq = 1
        fixture.visitingSecond.result = "Ground Out"
        fixture.visitingSecond.inning = 0.2
        fixture.visitingSecond.seq = 2
        fixture.visitingSecond.outs = 1
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let displayedAtbats = [fixture.visitingFirst, fixture.visitingSecond, pendingFirstInSecondColumn]

        let invalid = coordinator.selectAtbat(
            column: 2,
            rowIndex: 1,
            sourceAtbat: fixture.visitingSecond,
            displayedAtbats: displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )
        let current = coordinator.selectAtbat(
            column: 2,
            rowIndex: 0,
            sourceAtbat: fixture.visitingFirst,
            displayedAtbats: displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )
        let completed = coordinator.selectAtbat(
            column: 1,
            rowIndex: 0,
            sourceAtbat: fixture.visitingFirst,
            displayedAtbats: displayedAtbats,
            game: fixture.game,
            modelContext: store.context,
            save: { try store.context.save() }
        )
        let expectedRenderedID = LiveScoringWorkflowCoordinator.RenderedScorecardCellTarget.uiIdentifier(
            renderedRowIdentity: fixture.visitingFirst.ident,
            column: 2
        )

        #expect(invalid.disposition == .validationFailed)
        #expect(invalid.targetCell?.atbatIdentity == pendingFirstInSecondColumn.ident)
        #expect(invalid.targetCell?.column == 2)
        #expect(invalid.renderedTarget?.renderedRowIdentity == fixture.visitingFirst.ident)
        #expect(invalid.renderedTarget?.column == 2)
        #expect(invalid.renderedTarget?.uiIdentifier == expectedRenderedID)
        #expect(current.disposition == .noChange)
        #expect(current.atbat?.ident == pendingFirstInSecondColumn.ident)
        #expect(completed.disposition == .noChange)
        #expect(completed.atbat?.ident == fixture.visitingFirst.ident)
        #expect(fixture.game.atbats.count == 3)
        #expect(try store.fetchLegacyAtbats().count == 3)
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

    @Test("prepared live game state preserves visitor half legacy facts without writing canonical records")
    func preparedLiveGameStatePreservesVisitorHalfLegacyFactsWithoutWritingCanonicalRecords() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        fixture.game.hscore = 3
        fixture.game.vscore = 2
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        fixture.visitingFirst.inning = 0.1
        fixture.visitingFirst.seq = 1
        fixture.visitingFirst.outs = 0
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let state = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher]
        )

        #expect(state.disposition == .ready)
        #expect(state.canScore)
        #expect(state.gameIdentity == fixture.game.ident)
        #expect(state.battingSide == .visiting)
        #expect(state.halfInning == .visiting)
        #expect(state.inning == 1)
        #expect(state.outs == 0)
        #expect(state.score == .init(home: 3, visiting: 2))
        #expect(state.bases.first?.player.identity == fixture.visitingFirst.player.identifier)
        #expect(state.currentBatter?.identity == fixture.visitingSecond.player.identifier)
        #expect(state.battingOrderPosition == 2)
        #expect(state.currentPitcher?.player.identity == fixture.homePitcher.identifier)
        #expect(state.latestScoringSequence == 1)
        #expect(state.currentScorecardColumn == 1)
        #expect(state.lineup.map(\.slot) == [1, 2])
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("prepared live game state preserves home half identity and defensive pitcher")
    func preparedLiveGameStatePreservesHomeHalfIdentityAndDefensivePitcher() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let visitorPitcher = Player(name: "Visitor Pitcher", number: "7", position: "P", batDir: "R", batOrder: 3, team: fixture.visitingTeam)
        let homeBatter = Player(name: "Home One", number: "4", position: "CF", batDir: "L", batOrder: 1, team: fixture.homeTeam)
        let homeAtbat = Atbat(game: fixture.game, team: fixture.homeTeam, player: homeBatter, result: "Result", maxbase: "No Bases", batOrder: 1, outAt: "Safe", inning: 1, seq: 1, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
        let pitcher = Pitcher(player: visitorPitcher, team: fixture.visitingTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(visitorPitcher)
        store.context.insert(homeBatter)
        store.context.insert(homeAtbat)
        store.context.insert(pitcher)
        fixture.homeTeam.players.append(homeBatter)
        fixture.visitingTeam.players.append(visitorPitcher)
        fixture.game.players.append(contentsOf: [visitorPitcher, homeBatter])
        fixture.game.atbats.append(homeAtbat)
        fixture.game.pitchers.append(pitcher)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let state = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.homeTeam,
            displayedAtbats: [homeAtbat],
            pitchers: [pitcher]
        )

        #expect(state.disposition == .ready)
        #expect(state.battingSide == .home)
        #expect(state.halfInning == .home)
        #expect(state.battingTeam?.identity == fixture.homeTeam.ident)
        #expect(state.defensiveTeam?.identity == fixture.visitingTeam.ident)
        #expect(state.currentBatter?.identity == homeBatter.identifier)
        #expect(state.currentPitcher?.player.identity == visitorPitcher.identifier)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("prepared live game state is deterministic and read-only")
    func preparedLiveGameStateIsDeterministicAndReadOnly() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let before = Snapshot.capture(fixture.game)

        let first = coordinator.prepareLiveGameState(game: fixture.game, battingTeam: fixture.visitingTeam, displayedAtbats: fixture.displayedAtbats.reversed(), pitchers: [pitcher])
        let second = coordinator.prepareLiveGameState(game: fixture.game, battingTeam: fixture.visitingTeam, displayedAtbats: fixture.displayedAtbats, pitchers: [pitcher])
        let after = Snapshot.capture(fixture.game)

        #expect(first == second)
        #expect(before == after)
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("prepared live game state carries exact legacy game configuration evidence")
    func preparedLiveGameStateCarriesExactLegacyGameConfigurationEvidence() throws {
        let store = try Store()
        let sevenInningFixture = Fixture.insertGame(into: store.context, location: "Seven Inning Field", everyOneHits: true, numInnings: 7)
        let nineInningFixture = Fixture.insertGame(into: store.context, location: "Nine Inning Field", everyOneHits: false, numInnings: 9)
        let sevenPitcher = Pitcher(player: sevenInningFixture.homePitcher, team: sevenInningFixture.homeTeam, game: sevenInningFixture.game, startInn: 1, endInn: 1)
        let ninePitcher = Pitcher(player: nineInningFixture.homePitcher, team: nineInningFixture.homeTeam, game: nineInningFixture.game, startInn: 1, endInn: 1)
        store.context.insert(sevenPitcher)
        store.context.insert(ninePitcher)
        sevenInningFixture.game.pitchers.append(sevenPitcher)
        nineInningFixture.game.pitchers.append(ninePitcher)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let beforeSeven = Snapshot.capture(sevenInningFixture.game)

        let seven = coordinator.prepareLiveGameState(game: sevenInningFixture.game, battingTeam: sevenInningFixture.visitingTeam, displayedAtbats: sevenInningFixture.displayedAtbats, pitchers: [sevenPitcher])
        let sevenRepeat = coordinator.prepareLiveGameState(game: sevenInningFixture.game, battingTeam: sevenInningFixture.visitingTeam, displayedAtbats: sevenInningFixture.displayedAtbats, pitchers: [sevenPitcher])
        let nine = coordinator.prepareLiveGameState(game: nineInningFixture.game, battingTeam: nineInningFixture.visitingTeam, displayedAtbats: nineInningFixture.displayedAtbats, pitchers: [ninePitcher])
        let afterSeven = Snapshot.capture(sevenInningFixture.game)

        #expect(seven.configuredInningCount == 7)
        #expect(seven.everyoneHits == true)
        #expect(nine.configuredInningCount == 9)
        #expect(nine.everyoneHits == false)
        #expect(seven == sevenRepeat)
        #expect(beforeSeven == afterSeven)
        #expect(seven.score == .init(home: 0, visiting: 0))
        #expect(seven.lineup.map(\.slot) == [1, 2])
        #expect(try store.fetchLegacyAtbats().count == 4)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("prepared live game state reflects legacy substitution arrays and pitch hitter lineup entry")
    func preparedLiveGameStateReflectsLegacySubstitutionArraysAndPitchHitterLineupEntry() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let incoming = Player(name: "Incoming Visitor", number: "12", position: "RF", batDir: "R", batOrder: 3, team: fixture.visitingTeam)
        let pitchHitter = Atbat(game: fixture.game, team: fixture.visitingTeam, player: incoming, result: "Pitch Hitter", maxbase: "No Bases", batOrder: 3, outAt: "Safe", inning: 1, seq: 3, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(incoming)
        store.context.insert(pitchHitter)
        store.context.insert(pitcher)
        fixture.visitingTeam.players.append(incoming)
        fixture.game.players.append(incoming)
        fixture.game.atbats.append(pitchHitter)
        fixture.game.pitchers.append(pitcher)
        fixture.game.replaced.append(fixture.visitingSecond.player)
        fixture.game.incomings.append(incoming)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let state = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: [fixture.visitingFirst, fixture.visitingSecond, pitchHitter],
            pitchers: [pitcher]
        )

        #expect(state.disposition == .ready)
        #expect(state.lineup.map(\.slot) == [1, 2, 3])
        #expect(state.lineup.last?.isIncoming == true)
        #expect(state.lineup[1].isReplaced)
        #expect(state.substitutions.count == 1)
        #expect(state.substitutions.first?.outgoing.identity == fixture.visitingSecond.player.identifier)
        #expect(state.substitutions.first?.incoming.identity == incoming.identifier)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("prepared live game state fails closed for missing pitcher and inconsistent legacy input")
    func preparedLiveGameStateFailsClosedForMissingPitcherAndInconsistentLegacyInput() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let otherFixture = Fixture.insertGame(into: store.context, location: "Other Field")
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let missingPitcher = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: []
        )
        let unrelatedAtbat = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats + [otherFixture.visitingFirst],
            pitchers: []
        )
        fixture.visitingFirst.outs = 4
        fixture.visitingFirst.result = "Ground Out"
        let invalidOuts = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: []
        )

        #expect(missingPitcher.disposition == .unavailablePitcher)
        #expect(!missingPitcher.canScore)
        #expect(missingPitcher.warnings == ["preparedLiveGameState.unavailablePitcher"])
        #expect(unrelatedAtbat.disposition == .inconsistentLegacyState)
        #expect(unrelatedAtbat.warnings == ["preparedLiveGameState.unrelatedAtbatExcluded"])
        #expect(invalidOuts.disposition == .inconsistentLegacyState)
        #expect(invalidOuts.warnings == ["preparedLiveGameState.invalidOutCount"])
        #expect(try store.fetchLegacyAtbats().count == 4)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("semantic score state presents projected score and current line from prepared state")
    func semanticScoreStatePresentsProjectedScoreAndCurrentLineFromPreparedState() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        fixture.game.hscore = 0
        fixture.game.vscore = 1
        fixture.visitingFirst.result = "Home Run"
        fixture.visitingFirst.maxbase = "Home"
        fixture.visitingFirst.inning = 0.1
        fixture.visitingFirst.seq = 1
        fixture.visitingFirst.outs = 0
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher]
        )
        let semantic = coordinator.semanticScoreState(preparedState: prepared, displayedAtbats: fixture.displayedAtbats)

        #expect(semantic.disposition == .ready)
        #expect(semantic.score == .init(home: 0, visiting: 1))
        #expect(semantic.storedScore == .init(home: 0, visiting: 1))
        #expect(semantic.battingSide == .visiting)
        #expect(semantic.inning == 1)
        #expect(semantic.outs == 0)
        #expect(semantic.canPresentScoringLine)
        #expect(semantic.warnings.isEmpty)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("semantic score state classifies stored score mismatch without mutating legacy state")
    func semanticScoreStateClassifiesStoredScoreMismatchWithoutMutatingLegacyState() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        fixture.game.hscore = 0
        fixture.game.vscore = 2
        fixture.visitingFirst.result = "Home Run"
        fixture.visitingFirst.maxbase = "Home"
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let before = Snapshot.capture(fixture.game)

        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher]
        )
        let semantic = coordinator.semanticScoreState(preparedState: prepared, displayedAtbats: fixture.displayedAtbats)
        let after = Snapshot.capture(fixture.game)

        #expect(semantic.disposition == .storedScoreMismatch)
        #expect(semantic.score == .init(home: 0, visiting: 1))
        #expect(semantic.storedScore == .init(home: 0, visiting: 2))
        #expect(semantic.warnings.contains("semanticScoreState.storedScoreMismatch"))
        #expect(before == after)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("semantic score state fails closed when prepared state is unavailable")
    func semanticScoreStateFailsClosedWhenPreparedStateIsUnavailable() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: []
        )
        let semantic = coordinator.semanticScoreState(preparedState: prepared, displayedAtbats: fixture.displayedAtbats)

        #expect(prepared.disposition == .unavailablePitcher)
        #expect(semantic.disposition == .preparedStateUnavailable)
        #expect(!semantic.canPresentScoringLine)
        #expect(semantic.score == prepared.score)
        #expect(semantic.warnings.contains("semanticScoreState.preparedStateUnavailable"))
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("enabled action state enables supported choices from valid prepared state")
    func enabledActionStateEnablesSupportedChoicesFromValidPreparedState() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let prepared = coordinator.prepareLiveGameState(game: fixture.game, battingTeam: fixture.visitingTeam, displayedAtbats: fixture.displayedAtbats, pitchers: [pitcher])
        let semantic = coordinator.semanticScoreState(preparedState: prepared, displayedAtbats: fixture.displayedAtbats)
        let actions = coordinator.enabledScoringActions(preparedState: prepared, semanticScoreState: semantic, displayedAtbats: fixture.displayedAtbats, supportedLegacyResults: ["Single", "Ground Out"])

        #expect(actions.state(for: .legacyResult("Single"))?.isEnabled == true)
        #expect(actions.state(for: .legacyResult("Single"))?.validationDisposition == .valid)
        #expect(actions.state(for: .legacyResult("Ground Out"))?.isEnabled == true)
        #expect(actions.state(for: .scorecardCell(column: 1, battingOrder: 1))?.isEnabled == true)
        #expect(actions.actions.filter { !$0.isEnabled }.allSatisfy { $0.unavailableReason?.isEmpty == false })
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("enabled action state disables validation rejection with accessible deterministic reason")
    func enabledActionStateDisablesValidationRejectionWithAccessibleDeterministicReason() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        fixture.visitingFirst.result = "Ground Out"
        fixture.visitingFirst.outs = 3
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let prepared = coordinator.prepareLiveGameState(game: fixture.game, battingTeam: fixture.visitingTeam, displayedAtbats: fixture.displayedAtbats, pitchers: [pitcher])
        let semantic = coordinator.semanticScoreState(preparedState: prepared, displayedAtbats: fixture.displayedAtbats)
        let first = coordinator.enabledScoringActions(preparedState: prepared, semanticScoreState: semantic, displayedAtbats: fixture.displayedAtbats, supportedLegacyResults: ["Single"])
        let second = coordinator.enabledScoringActions(preparedState: prepared, semanticScoreState: semantic, displayedAtbats: fixture.displayedAtbats, supportedLegacyResults: ["Single"])

        let single = try #require(first.state(for: .legacyResult("Single")))
        #expect(!single.isEnabled)
        #expect(single.disposition == .disabledValidationRejected)
        #expect(single.validationDisposition == .rejected)
        #expect(single.unavailableReason == "A new scoring command cannot apply after an existing third-out context in this foundation.")
        #expect(first == second)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("enabled action state disables unsupported and unavailable prepared actions with reasons")
    func enabledActionStateDisablesUnsupportedAndUnavailablePreparedActionsWithReasons() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let prepared = coordinator.prepareLiveGameState(game: fixture.game, battingTeam: fixture.visitingTeam, displayedAtbats: fixture.displayedAtbats, pitchers: [])
        let semantic = coordinator.semanticScoreState(preparedState: prepared, displayedAtbats: fixture.displayedAtbats)
        let unavailable = coordinator.enabledScoringActions(preparedState: prepared, semanticScoreState: semantic, displayedAtbats: fixture.displayedAtbats, supportedLegacyResults: ["Single"])

        #expect(unavailable.state(for: .legacyResult("Single"))?.isEnabled == false)
        #expect(unavailable.state(for: .legacyResult("Single"))?.unavailableReason == "A current pitcher is required before scoring.")

        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        try store.context.save()
        let ready = coordinator.prepareLiveGameState(game: fixture.game, battingTeam: fixture.visitingTeam, displayedAtbats: fixture.displayedAtbats, pitchers: [pitcher])
        let readySemantic = coordinator.semanticScoreState(preparedState: ready, displayedAtbats: fixture.displayedAtbats)
        let unsupported = coordinator.enabledScoringActions(preparedState: ready, semanticScoreState: readySemantic, displayedAtbats: fixture.displayedAtbats, supportedLegacyResults: ["Moon Shot"])
        let unsupportedAction = try #require(unsupported.state(for: .legacyResult("Moon Shot")))

        #expect(!unsupportedAction.isEnabled)
        #expect(unsupportedAction.disposition == .disabledUnsupported)
        #expect(unsupportedAction.unavailableReason == "Legacy scoring result is preserved but unsupported by accepted command vocabulary.")
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("enabled action state preserves prepared and semantic score state")
    func enabledActionStatePreservesPreparedAndSemanticScoreState() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        store.context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let before = Snapshot.capture(fixture.game)

        let prepared = coordinator.prepareLiveGameState(game: fixture.game, battingTeam: fixture.visitingTeam, displayedAtbats: fixture.displayedAtbats, pitchers: [pitcher])
        let semantic = coordinator.semanticScoreState(preparedState: prepared, displayedAtbats: fixture.displayedAtbats)
        let actions = coordinator.enabledScoringActions(preparedState: prepared, semanticScoreState: semantic, displayedAtbats: fixture.displayedAtbats, supportedLegacyResults: ["Single", "Ground Out"])
        let after = Snapshot.capture(fixture.game)

        #expect(actions.preparedState == prepared)
        #expect(actions.semanticScoreState == semantic)
        #expect(before == after)
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("scoring action submission accepts one ordinary legacy result and writes no canonical records")
    func scoringActionSubmissionAcceptsOneOrdinaryLegacyResultAndWritesNoCanonicalRecords() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        let result = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: { try store.context.save() }
        )

        #expect(result.disposition == .accepted)
        #expect(result.atbat?.ident == fixture.visitingFirst.ident)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(fixture.visitingFirst.maxbase == "No Bases")
        #expect(fixture.game.atbats.filter { $0.result == "Single" }.count == 1)
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("second inning scoring advances prepared column after inning-ending third out before lineup wraps")
    func secondInningScoringAdvancesPreparedColumnAfterInningEndingThirdOutBeforeLineupWraps() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecondInningPreparedStateRegression-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        let configuration = ModelConfiguration("LiveScoringWorkflowCoordinatorTests-SecondInningPreparedState", url: url)
        var container: ModelContainer? = try ModelContainer(for: schema, configurations: [configuration])
        var context: ModelContext? = ModelContext(container!)

        let fixture = Fixture.insertGame(into: context!)
        var lineupAtbats = fixture.displayedAtbats
        for order in 3...9 {
            let player = Player(name: "Visitor \(order)", number: "\(order)", position: "CF", batDir: "R", batOrder: order, team: fixture.visitingTeam)
            let atbat = Atbat(game: fixture.game, team: fixture.visitingTeam, player: player, result: "Result", maxbase: "No Bases", batOrder: order, outAt: "Safe", inning: 1, seq: order, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
            context!.insert(player)
            context!.insert(atbat)
            fixture.visitingTeam.players.append(player)
            fixture.game.players.append(player)
            fixture.game.atbats.append(atbat)
            lineupAtbats.append(atbat)
        }
        let pitcher = Fixture.insertPitcher(for: fixture, into: context!)
        try context!.save()

        let coordinator = LiveScoringWorkflowCoordinator()
        let presenter = LiveScoringShellPresentation()
        let visitingAtbats = { fixture.game.atbats.filter { $0.team.ident == fixture.visitingTeam.ident } }
        let thirdAtbat = try #require(lineupAtbats.first { $0.batOrder == 3 })
        let fourthAtbat = try #require(lineupAtbats.first { $0.batOrder == 4 })

        let firstOut = coordinator.submitScoringAction(
            legacyResult: "Ground Out",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: visitingAtbats(),
            pitchers: [pitcher],
            supportedLegacyResults: ["Ground Out", "Strikeout"],
            save: { try context!.save() }
        )
        #expect(firstOut.disposition == .accepted)
        #expect(fixture.visitingFirst.result == "Ground Out")
        #expect(coordinator.refreshProjections(displayedAtbats: visitingAtbats(), pitchers: [pitcher], game: fixture.game, save: { try context!.save() }).disposition == .success)

        let secondOut = coordinator.submitScoringAction(
            legacyResult: "Ground Out",
            targetAtbat: fixture.visitingSecond,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: visitingAtbats(),
            pitchers: [pitcher],
            supportedLegacyResults: ["Ground Out", "Strikeout"],
            save: { try context!.save() }
        )
        #expect(secondOut.disposition == .accepted)
        #expect(fixture.visitingSecond.result == "Ground Out")
        #expect(coordinator.refreshProjections(displayedAtbats: visitingAtbats(), pitchers: [pitcher], game: fixture.game, save: { try context!.save() }).disposition == .success)

        let thirdOut = coordinator.submitScoringAction(
            legacyResult: "Strikeout",
            targetAtbat: thirdAtbat,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: visitingAtbats(),
            pitchers: [pitcher],
            supportedLegacyResults: ["Ground Out", "Strikeout"],
            save: { try context!.save() }
        )
        #expect(thirdOut.disposition == .accepted)
        #expect(thirdAtbat.result == "Strikeout")
        let firstInningRefresh = coordinator.refreshProjections(displayedAtbats: visitingAtbats(), pitchers: [pitcher], game: fixture.game, save: { try context!.save() })
        #expect(firstInningRefresh.disposition == .success)
        #expect(thirdAtbat.outs == 3)
        #expect(thirdAtbat.endOfInning)
        #expect(thirdAtbat.batOrder < lineupAtbats.count)

        let selection = coordinator.selectAtbat(
            column: 2,
            rowIndex: 3,
            sourceAtbat: fourthAtbat,
            displayedAtbats: visitingAtbats(),
            game: fixture.game,
            modelContext: context!,
            save: { try context!.save() }
        )
        let secondInningAtbat = try #require(selection.atbat)
        #expect(selection.disposition == .success)
        #expect(presenter.presentSelectionResult(selection).shouldPresentScoringSheet)

        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: visitingAtbats(),
            pitchers: [pitcher]
        )
        #expect(prepared.disposition == .ready)
        #expect(prepared.inning == 2)
        #expect(prepared.outs == 0)
        #expect(prepared.currentScorecardColumn == 2)
        #expect(prepared.currentOrPendingLegacyAtbat?.identity == secondInningAtbat.ident)
        #expect(prepared.battingOrderPosition == 4)

        let secondInningSubmit = coordinator.submitScoringAction(
            legacyResult: "Strikeout",
            targetAtbat: secondInningAtbat,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: visitingAtbats(),
            pitchers: [pitcher],
            supportedLegacyResults: ["Ground Out", "Strikeout"],
            save: { try context!.save() }
        )
        #expect(secondInningSubmit.disposition == .accepted)
        #expect(secondInningAtbat.result == "Strikeout")
        #expect(presenter.presentSubmissionResult(secondInningSubmit, requiresAdditionalChoice: false).shouldDismissScoringSheet)

        let secondInningRefresh = coordinator.refreshProjections(displayedAtbats: visitingAtbats(), pitchers: [pitcher], game: fixture.game, save: { try context!.save() })
        #expect(secondInningRefresh.disposition == .success)
        #expect(secondInningAtbat.col == 2)
        #expect(secondInningAtbat.outs == 1)

        let gameIdentity = fixture.game.ident
        let secondInningAtbatIdentity = secondInningAtbat.ident
        context = nil
        container = nil

        let reloadedContainer = try ModelContainer(for: schema, configurations: [configuration])
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(try reloadedContext.fetch(FetchDescriptor<Game>()).first { $0.ident == gameIdentity })
        let reloadedPitcher = try #require(try reloadedContext.fetch(FetchDescriptor<Pitcher>()).first)
        let reloadedSecondInningAtbat = try #require(reloadedGame.atbats.first { $0.ident == secondInningAtbatIdentity })
        #expect(reloadedSecondInningAtbat.result == "Strikeout")
        #expect(reloadedSecondInningAtbat.col == 2)
        #expect(reloadedSecondInningAtbat.outs == 1)

        let reloadedPrepared = LiveScoringWorkflowCoordinator().prepareLiveGameState(
            game: reloadedGame,
            battingTeam: reloadedGame.vteam!,
            displayedAtbats: reloadedGame.atbats.filter { $0.team.ident == reloadedGame.vteam!.ident },
            pitchers: [reloadedPitcher]
        )
        #expect(reloadedPrepared.disposition == .ready)
        #expect(reloadedPrepared.inning == 2)
        #expect(reloadedPrepared.outs == 1)

        try FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test("prepared current column still advances when batting around without ending the inning")
    func preparedCurrentColumnStillAdvancesWhenBattingAroundWithoutEndingTheInning() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        var lineupAtbats = fixture.displayedAtbats
        for order in 3...9 {
            let player = Player(name: "Visitor \(order)", number: "\(order)", position: "CF", batDir: "R", batOrder: order, team: fixture.visitingTeam)
            let atbat = Atbat(game: fixture.game, team: fixture.visitingTeam, player: player, result: "Result", maxbase: "No Bases", batOrder: order, outAt: "Safe", inning: 1, seq: order, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
            store.context.insert(player)
            store.context.insert(atbat)
            fixture.visitingTeam.players.append(player)
            fixture.game.players.append(player)
            fixture.game.atbats.append(atbat)
            lineupAtbats.append(atbat)
        }
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        for atbat in lineupAtbats.sorted(by: { $0.batOrder < $1.batOrder }) {
            let result = coordinator.submitScoringAction(
                legacyResult: "Single",
                targetAtbat: atbat,
                game: fixture.game,
                battingTeam: fixture.visitingTeam,
                displayedAtbats: fixture.game.atbats.filter { $0.team.ident == fixture.visitingTeam.ident },
                pitchers: [pitcher],
                supportedLegacyResults: ["Single"],
                save: { try store.context.save() }
            )
            #expect(result.disposition == .accepted)
            #expect(coordinator.refreshProjections(displayedAtbats: fixture.game.atbats.filter { $0.team.ident == fixture.visitingTeam.ident }, pitchers: [pitcher], game: fixture.game, save: { try store.context.save() }).disposition == .success)
        }

        let lastCompleted = try #require(lineupAtbats.first { $0.batOrder == 9 })
        #expect(lastCompleted.endOfInning == false)
        #expect(lastCompleted.batOrder == lineupAtbats.count)

        let prepared = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.game.atbats.filter { $0.team.ident == fixture.visitingTeam.ident },
            pitchers: [pitcher]
        )

        #expect(prepared.disposition == .ready)
        #expect(prepared.inning == 1)
        #expect(prepared.outs == 0)
        #expect(prepared.currentScorecardColumn == 2)
        #expect(prepared.battingOrderPosition == 1)
    }

    @Test("Task 7.7 ordinary exact retry returns persisted outcome without a second mutation")
    func task77OrdinaryExactRetryReturnsPersistedOutcomeWithoutSecondMutation() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let operation = UUID(uuidString: "70000000-0000-0000-0000-000000000701")!
        var saveCount = 0
        let adapter = LegacyScoringOperationEvidenceAdapter(
            container: store.container,
            dependencies: LegacyScoringOperationEvidenceDependencies(save: { context in
                saveCount += 1
                try context.save()
            })
        )

        let first = LiveScoringWorkflowCoordinator().submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Double"],
            save: { throw InjectedSaveError() },
            operationIdentity: operation,
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        let retryAfterCoordinatorReconstruction = LiveScoringWorkflowCoordinator().submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Double"],
            save: { throw InjectedSaveError() },
            operationIdentity: operation,
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )

        #expect(first.disposition == .accepted)
        #expect(first.operationEvidenceResult?.idempotencyResult == .firstInvocation)
        #expect(retryAfterCoordinatorReconstruction.disposition == .duplicatePrevented)
        #expect(retryAfterCoordinatorReconstruction.operationEvidenceResult?.idempotencyResult == .exactRetryAlreadyAccepted)
        #expect(saveCount == 1)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.7 ordinary conflicting identity reuse fails closed")
    func task77OrdinaryConflictingIdentityReuseFailsClosed() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let operation = UUID(uuidString: "70000000-0000-0000-0000-000000000702")!
        let adapter = LegacyScoringOperationEvidenceAdapter(container: store.container)

        let first = coordinatorSubmitOrdinary(
            coordinator: LiveScoringWorkflowCoordinator(),
            store: store,
            fixture: fixture,
            pitcher: pitcher,
            result: "Single",
            operation: operation,
            adapter: adapter
        )
        let conflict = coordinatorSubmitOrdinary(
            coordinator: LiveScoringWorkflowCoordinator(),
            store: store,
            fixture: fixture,
            pitcher: pitcher,
            result: "Double",
            operation: operation,
            adapter: adapter
        )

        #expect(first.disposition == .accepted)
        #expect(conflict.disposition == .conflict)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.7 confirmed failure with no evidence can retry using the same ordinary identity")
    func task77ConfirmedFailureWithNoEvidenceCanRetryUsingSameOrdinaryIdentity() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let operation = UUID(uuidString: "70000000-0000-0000-0000-000000000703")!
        let failingAdapter = LegacyScoringOperationEvidenceAdapter(
            container: store.container,
            dependencies: LegacyScoringOperationEvidenceDependencies(injectedFailures: [.save])
        )
        let retryAdapter = LegacyScoringOperationEvidenceAdapter(container: store.container)

        let failed = coordinatorSubmitOrdinary(
            coordinator: LiveScoringWorkflowCoordinator(),
            store: store,
            fixture: fixture,
            pitcher: pitcher,
            result: "Single",
            operation: operation,
            adapter: failingAdapter
        )
        let retry = coordinatorSubmitOrdinary(
            coordinator: LiveScoringWorkflowCoordinator(),
            store: store,
            fixture: fixture,
            pitcher: pitcher,
            result: "Single",
            operation: operation,
            adapter: retryAdapter
        )

        #expect(failed.disposition == .persistenceFailed)
        #expect(failed.operationEvidenceResult?.transaction.retrySafety == .safe)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(retry.disposition == .accepted)
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.7 committed but unacknowledged ordinary save reconciles through fresh lookup")
    func task77CommittedButUnacknowledgedOrdinarySaveReconcilesThroughFreshLookup() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let operation = UUID(uuidString: "70000000-0000-0000-0000-000000000704")!
        let adapter = LegacyScoringOperationEvidenceAdapter(
            container: store.container,
            dependencies: LegacyScoringOperationEvidenceDependencies(save: { context in
                try context.save()
                throw InjectedSaveError()
            })
        )

        let result = coordinatorSubmitOrdinary(
            coordinator: LiveScoringWorkflowCoordinator(),
            store: store,
            fixture: fixture,
            pitcher: pitcher,
            result: "Single",
            operation: operation,
            adapter: adapter
        )

        #expect(result.disposition == .duplicatePrevented)
        #expect(result.operationEvidenceResult?.saveResult == .completionUncertain)
        #expect(result.operationEvidenceResult?.lookupResult.classification == .acceptedExactRetry)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("submission revalidates current state and fails closed after stale enabled state")
    func submissionRevalidatesCurrentStateAndFailsClosedAfterStaleEnabledState() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let prepared = coordinator.prepareLiveGameState(game: fixture.game, battingTeam: fixture.visitingTeam, displayedAtbats: fixture.displayedAtbats, pitchers: [pitcher])
        let semantic = coordinator.semanticScoreState(preparedState: prepared, displayedAtbats: fixture.displayedAtbats)
        let enabled = coordinator.enabledScoringActions(preparedState: prepared, semanticScoreState: semantic, displayedAtbats: fixture.displayedAtbats, supportedLegacyResults: ["Single"])

        let result = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() }
        )

        #expect(enabled.state(for: .legacyResult("Single"))?.isEnabled == true)
        #expect(result.disposition == .unavailablePreparedState)
        #expect(result.message == "A current pitcher is required before scoring.")
        #expect(fixture.visitingFirst.result == "Result")
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("disabled unsupported cancellation duplicate conflict and persistence failure submissions do not create extra outcomes")
    func disabledUnsupportedCancellationDuplicateConflictAndPersistenceFailureSubmissionsDoNotCreateExtraOutcomes() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let validationFixture = Fixture.insertGame(into: store.context, location: "Validation Field")
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        let validationPitcher = Fixture.insertPitcher(for: validationFixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()

        validationFixture.visitingFirst.result = "Ground Out"
        validationFixture.visitingFirst.outs = 3
        let validationRejected = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: validationFixture.visitingSecond,
            game: validationFixture.game,
            battingTeam: validationFixture.visitingTeam,
            displayedAtbats: validationFixture.displayedAtbats,
            pitchers: [validationPitcher],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() }
        )
        let cancellation = coordinator.submitScoringAction(
            legacyResult: "Result",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() }
        )
        let unsupported = coordinator.submitScoringAction(
            legacyResult: "Moon Shot",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() }
        )
        let conflict = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingSecond,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() }
        )
        let persistenceFailure = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: { throw InjectedSaveError() }
        )
        let accepted = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() }
        )
        let duplicate = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() }
        )

        #expect(validationRejected.disposition == .validationRejected)
        #expect(validationFixture.visitingSecond.result == "Result")
        #expect(cancellation.disposition == .cancellation)
        #expect(unsupported.disposition == .unsupportedAction)
        #expect(conflict.disposition == .conflict)
        #expect(persistenceFailure.disposition == .persistenceFailed)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(accepted.disposition == .accepted)
        #expect(duplicate.disposition == .duplicatePrevented)
        #expect(fixture.game.atbats.filter { $0.result == "Single" }.count == 1)
        #expect(fixture.visitingSecond.result == "Result")
        #expect(try store.fetchLegacyAtbats().count == 4)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("rapid repeated ordinary scoring input persists one accepted legacy outcome")
    func rapidRepeatedOrdinaryScoringInputPersistsOneAcceptedLegacyOutcome() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let unrelated = Fixture.insertGame(into: store.context, location: "Task 7.6 Other Field")
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        _ = Fixture.insertPitcher(for: unrelated, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let saves = SaveRecorder { try store.context.save() }
        let unrelatedBefore = Snapshot.capture(unrelated.game)

        let first = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: saves.save
        )
        let immediateRepeat = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: saves.save
        )
        let delayedCallbackRepeat = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: saves.save
        )
        let retryAfterDuplicatePrevented = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: saves.save
        )

        #expect(first.disposition == .accepted)
        #expect(immediateRepeat.disposition == .duplicatePrevented)
        #expect(delayedCallbackRepeat.disposition == .duplicatePrevented)
        #expect(retryAfterDuplicatePrevented.disposition == .duplicatePrevented)
        #expect(saves.attempts == 1)
        #expect(fixture.game.atbats.filter { $0.result == "Single" }.count == 1)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(fixture.visitingFirst.maxbase == "No Bases")
        #expect(fixture.visitingSecond.result == "Result")
        #expect(Snapshot.capture(unrelated.game) == unrelatedBefore)
        #expect(try store.fetchLegacyAtbats().count == 4)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("repeated ordinary cancellation and unsupported input remain deterministic no-ops")
    func repeatedOrdinaryCancellationAndUnsupportedInputRemainDeterministicNoOps() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let saves = SaveRecorder { try store.context.save() }
        let before = Snapshot.capture(fixture.game)

        let firstCancellation = coordinator.submitScoringAction(
            legacyResult: "Result",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: saves.save
        )
        let repeatedCancellation = coordinator.submitScoringAction(
            legacyResult: "Result",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: saves.save
        )
        let unsupported = coordinator.submitScoringAction(
            legacyResult: "Moon Shot",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: saves.save
        )
        let unsupportedRetry = coordinator.submitScoringAction(
            legacyResult: "Moon Shot",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: saves.save
        )

        #expect(firstCancellation.disposition == .cancellation)
        #expect(repeatedCancellation.disposition == .cancellation)
        #expect(unsupported.disposition == .unsupportedAction)
        #expect(unsupportedRetry.disposition == .unsupportedAction)
        #expect(saves.attempts == 0)
        #expect(Snapshot.capture(fixture.game) == before)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("ordinary retry after persistence failure restores fields then accepts once")
    func ordinaryRetryAfterPersistenceFailureRestoresFieldsThenAcceptsOnce() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let saves = SaveRecorder { try store.context.save() }
        saves.failNextSave()
        let before = Snapshot.capture(fixture.game)

        let failed = coordinator.submitScoringAction(
            legacyResult: "Ground Out",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: saves.save
        )
        let afterFailure = Snapshot.capture(fixture.game)
        let acceptedRetry = coordinator.submitScoringAction(
            legacyResult: "Ground Out",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: saves.save
        )
        let successRetry = coordinator.submitScoringAction(
            legacyResult: "Ground Out",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: saves.save
        )

        #expect(failed.disposition == .persistenceFailed)
        #expect(afterFailure == before)
        #expect(acceptedRetry.disposition == .accepted)
        #expect(successRetry.disposition == .duplicatePrevented)
        #expect(saves.attempts == 2)
        #expect(fixture.game.atbats.filter { $0.result == "Ground Out" }.count == 1)
        #expect(fixture.visitingFirst.outs == 0)
        #expect(fixture.visitingSecond.result == "Result")
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("scoring action submission leaves unrelated games unaffected")
    func scoringActionSubmissionLeavesUnrelatedGamesUnaffected() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let unrelated = Fixture.insertGame(into: store.context, location: "Other Field")
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        _ = Fixture.insertPitcher(for: unrelated, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let unrelatedBefore = Snapshot.capture(unrelated.game)

        let result = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() }
        )
        let unrelatedAfter = Snapshot.capture(unrelated.game)

        #expect(result.disposition == .accepted)
        #expect(unrelatedBefore == unrelatedAfter)
        #expect(try store.fetchLegacyAtbats().count == 4)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("additional-choice scoring preparation holds choices without accepted mutation")
    func additionalChoiceScoringPreparationHoldsChoicesWithoutAcceptedMutation() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let before = Snapshot.capture(fixture.game)

        let preparation = coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Fielder's Choice",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        )
        let after = Snapshot.capture(fixture.game)

        #expect(preparation.disposition == .pending)
        #expect(preparation.pendingChoice?.legacyResult == "Fielder's Choice")
        #expect(preparation.pendingChoice?.gameIdentity == fixture.game.ident)
        #expect(preparation.pendingChoice?.atbatIdentity == fixture.visitingFirst.ident)
        #expect(preparation.pendingChoice?.availableMaxBases == ["No Bases", "First", "Second", "Third", "Home"])
        #expect(preparation.pendingChoice?.availableOutAtBases == ["Safe", "First", "Second", "Third", "Home"])
        #expect(preparation.pendingChoice?.availableRBIs == [0, 1, 2, 3, 4])
        #expect(preparation.pendingChoice?.availableStolenBases == [0, 1, 2, 3])
        #expect(preparation.pendingChoice?.allowsEarnedRunChoice == true)
        #expect(preparation.pendingChoice?.allowsPlayRecordChoice == true)
        #expect(before == after)
        #expect(fixture.visitingFirst.result == "Result")
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("additional-choice final submission writes exactly one legacy outcome and no canonical records")
    func additionalChoiceFinalSubmissionWritesOneLegacyOutcomeAndNoCanonicalRecords() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let unrelated = Fixture.insertGame(into: store.context, location: "Other Field")
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        _ = Fixture.insertPitcher(for: unrelated, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let unrelatedBefore = Snapshot.capture(unrelated.game)
        let preparation = coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Fielder's Choice",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        )
        let pending = try #require(preparation.pendingChoice)
        let choices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Fielder's Choice",
            maxBase: "First",
            outAt: "Second",
            rbis: 1,
            stolenBases: 1,
            earnedRun: false,
            playRecord: "6-4"
        )

        let accepted = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { try store.context.save() }
        )
        let repeated = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { try store.context.save() }
        )

        #expect(accepted.disposition == .accepted)
        #expect(repeated.disposition == .conflict || repeated.disposition == .duplicatePrevented)
        #expect(fixture.visitingFirst.result == "Fielder's Choice")
        #expect(fixture.visitingFirst.maxbase == "First")
        #expect(fixture.visitingFirst.outAt == "Second")
        #expect(fixture.visitingFirst.rbis == 1)
        #expect(fixture.visitingFirst.stolenBases == 1)
        #expect(fixture.visitingFirst.earnedRun == false)
        #expect(fixture.visitingFirst.playRec == "6-4")
        #expect(fixture.game.atbats.filter { $0.result == "Fielder's Choice" }.count == 1)
        #expect(Snapshot.capture(unrelated.game) == unrelatedBefore)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.7 additional-choice exact retry returns persisted outcome without a second mutation")
    func task77AdditionalChoiceExactRetryReturnsPersistedOutcomeWithoutSecondMutation() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        var saveCount = 0
        let adapter = LegacyScoringOperationEvidenceAdapter(
            container: store.container,
            dependencies: LegacyScoringOperationEvidenceDependencies(save: { context in
                saveCount += 1
                try context.save()
            })
        )
        let coordinator = LiveScoringWorkflowCoordinator()
        let pending = try #require(coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Fielder's Choice",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        ).pendingChoice)
        let choices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Fielder's Choice",
            maxBase: "First",
            outAt: "Second",
            rbis: 1,
            stolenBases: 1,
            earnedRun: false,
            playRecord: "6-4"
        )

        let first = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        let retryAfterPresentationReconstruction = LiveScoringWorkflowCoordinator().submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )

        #expect(first.disposition == .accepted)
        #expect(retryAfterPresentationReconstruction.disposition == .duplicatePrevented)
        #expect(retryAfterPresentationReconstruction.operationEvidenceResult?.idempotencyResult == .exactRetryAlreadyAccepted)
        #expect(saveCount == 1)
        #expect(fixture.visitingFirst.result == "Fielder's Choice")
        #expect(fixture.visitingFirst.playRec == "6-4")
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.7 additional-choice changed facts under one identity fail closed")
    func task77AdditionalChoiceChangedFactsUnderOneIdentityFailClosed() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let adapter = LegacyScoringOperationEvidenceAdapter(container: store.container)
        let coordinator = LiveScoringWorkflowCoordinator()
        let pending = try #require(coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        ).pendingChoice)
        let acceptedChoices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Single",
            maxBase: "First",
            outAt: "Safe",
            rbis: 0,
            stolenBases: 0,
            earnedRun: true,
            playRecord: ""
        )
        let changedChoices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Single",
            maxBase: "Home",
            outAt: "Safe",
            rbis: 1,
            stolenBases: 0,
            earnedRun: false,
            playRecord: ""
        )

        let accepted = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: acceptedChoices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        let conflict = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: changedChoices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )

        #expect(accepted.disposition == .accepted)
        #expect(conflict.disposition == .conflict)
        #expect(fixture.visitingFirst.maxbase == "First")
        #expect(fixture.visitingFirst.rbis == 0)
        #expect(fixture.visitingFirst.earnedRun == true)
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.7 additional-choice cancellation creates no accepted evidence")
    func task77AdditionalChoiceCancellationCreatesNoAcceptedEvidence() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let pending = try #require(coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        ).pendingChoice)
        let cancellation = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: nil,
            choices: pending.choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter(container: store.container),
            modelContext: store.context
        )

        #expect(cancellation.disposition == .cancellation)
        #expect(fixture.visitingFirst.result == "Result")
        #expect(try store.legacyScoringOperationEvidenceCount() == 0)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("rapid repeated additional-choice final input persists one accepted legacy outcome")
    func rapidRepeatedAdditionalChoiceFinalInputPersistsOneAcceptedLegacyOutcome() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let unrelated = Fixture.insertGame(into: store.context, location: "Task 7.6 Additional Other Field")
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        _ = Fixture.insertPitcher(for: unrelated, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let saves = SaveRecorder { try store.context.save() }
        let unrelatedBefore = Snapshot.capture(unrelated.game)
        let preparation = coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Fielder's Choice",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        )
        let repeatedPreparation = coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Fielder's Choice",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        )
        let pending = try #require(preparation.pendingChoice)
        let choices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Fielder's Choice",
            maxBase: "First",
            outAt: "Second",
            rbis: 1,
            stolenBases: 1,
            earnedRun: false,
            playRecord: "6-4"
        )

        let accepted = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )
        let immediateRepeat = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )
        let delayedFinalCallback = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )
        let sheetDismissalCallback = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: nil,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )
        let repeatedSheetDismissalCallback = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: nil,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )

        #expect(preparation.disposition == .pending)
        #expect(repeatedPreparation.disposition == .pending)
        #expect(accepted.disposition == .accepted)
        #expect(immediateRepeat.disposition == .duplicatePrevented)
        #expect(delayedFinalCallback.disposition == .duplicatePrevented)
        #expect(sheetDismissalCallback.disposition == .cancellation)
        #expect(repeatedSheetDismissalCallback.disposition == .cancellation)
        #expect(saves.attempts == 1)
        #expect(fixture.game.atbats.filter { $0.result == "Fielder's Choice" }.count == 1)
        #expect(fixture.visitingFirst.maxbase == "First")
        #expect(fixture.visitingFirst.outAt == "Second")
        #expect(fixture.visitingFirst.rbis == 1)
        #expect(fixture.visitingFirst.stolenBases == 1)
        #expect(fixture.visitingFirst.earnedRun == false)
        #expect(fixture.visitingFirst.playRec == "6-4")
        #expect(fixture.visitingSecond.result == "Result")
        #expect(Snapshot.capture(unrelated.game) == unrelatedBefore)
        #expect(try store.fetchLegacyAtbats().count == 4)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("additional-choice retry after persistence failure restores fields then accepts once")
    func additionalChoiceRetryAfterPersistenceFailureRestoresFieldsThenAcceptsOnce() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let saves = SaveRecorder { try store.context.save() }
        saves.failNextSave()
        let before = Snapshot.capture(fixture.game)
        let preparation = coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        )
        let pending = try #require(preparation.pendingChoice)
        let choices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Single",
            maxBase: "Home",
            outAt: "Safe",
            rbis: 1,
            stolenBases: 0,
            earnedRun: true,
            playRecord: ""
        )

        let failed = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )
        let afterFailure = Snapshot.capture(fixture.game)
        let acceptedRetry = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )
        let duplicateRetry = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )

        #expect(failed.disposition == .persistenceFailed)
        #expect(afterFailure == before)
        #expect(acceptedRetry.disposition == .accepted)
        #expect(duplicateRetry.disposition == .duplicatePrevented)
        #expect(saves.attempts == 2)
        #expect(fixture.game.atbats.filter { $0.result == "Single" }.count == 1)
        #expect(fixture.visitingFirst.maxbase == "Home")
        #expect(fixture.visitingFirst.rbis == 1)
        #expect(fixture.visitingSecond.result == "Result")
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("additional-choice stale and conflicting repeated callbacks fail closed")
    func additionalChoiceStaleAndConflictingRepeatedCallbacksFailClosed() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let staleFixture = Fixture.insertGame(into: store.context, location: "Task 7.6 Stale Field")
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        let stalePitcher = Fixture.insertPitcher(for: staleFixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let saves = SaveRecorder { try store.context.save() }
        let preparation = coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        )
        let pending = try #require(preparation.pendingChoice)
        let acceptedChoices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Single",
            maxBase: "First",
            outAt: "Safe",
            rbis: 0,
            stolenBases: 0,
            earnedRun: true,
            playRecord: ""
        )
        let conflictingChoices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Single",
            maxBase: "Home",
            outAt: "Safe",
            rbis: 1,
            stolenBases: 0,
            earnedRun: false,
            playRecord: ""
        )
        let stalePreparation = coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Single",
            targetAtbat: staleFixture.visitingFirst,
            game: staleFixture.game,
            battingTeam: staleFixture.visitingTeam,
            displayedAtbats: staleFixture.displayedAtbats,
            pitchers: [stalePitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        )
        let stalePending = try #require(stalePreparation.pendingChoice)

        let accepted = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: acceptedChoices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )
        let conflictingRepeat = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: conflictingChoices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )
        staleFixture.visitingSecond.result = "Single"
        let stale = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: stalePending,
            choices: acceptedChoices,
            targetAtbat: staleFixture.visitingFirst,
            game: staleFixture.game,
            battingTeam: staleFixture.visitingTeam,
            displayedAtbats: staleFixture.displayedAtbats,
            pitchers: [stalePitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: saves.save
        )

        #expect(accepted.disposition == .accepted)
        #expect(conflictingRepeat.disposition == .conflict)
        #expect(stale.disposition == .conflict)
        #expect(saves.attempts == 1)
        #expect(fixture.visitingFirst.maxbase == "First")
        #expect(fixture.visitingFirst.rbis == 0)
        #expect(fixture.visitingFirst.earnedRun == true)
        #expect(staleFixture.visitingFirst.result == "Result")
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("additional-choice cancellation stale unsupported and failed saves do not create accepted facts")
    func additionalChoiceCancellationStaleUnsupportedAndFailedSavesDoNotCreateAcceptedFacts() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let staleFixture = Fixture.insertGame(into: store.context, location: "Stale Field")
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        let stalePitcher = Fixture.insertPitcher(for: staleFixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let before = Snapshot.capture(fixture.game)
        let preparation = coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        )
        let pending = try #require(preparation.pendingChoice)
        let validChoices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Single",
            maxBase: "Home",
            outAt: "Safe",
            rbis: 1,
            stolenBases: 0,
            earnedRun: true,
            playRecord: ""
        )
        let unsupportedChoices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Single",
            maxBase: "Dugout",
            outAt: "Safe",
            rbis: 1,
            stolenBases: 0,
            earnedRun: true,
            playRecord: ""
        )

        let afterPrepareOnly = Snapshot.capture(fixture.game)
        let unsupported = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: unsupportedChoices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { try store.context.save() }
        )
        let failedSave = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: validChoices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() }
        )
        let stalePreparation = coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Single",
            targetAtbat: staleFixture.visitingFirst,
            game: staleFixture.game,
            battingTeam: staleFixture.visitingTeam,
            displayedAtbats: staleFixture.displayedAtbats,
            pitchers: [stalePitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        )
        let stalePending = try #require(stalePreparation.pendingChoice)
        let stale = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: stalePending,
            choices: validChoices,
            targetAtbat: staleFixture.visitingFirst,
            game: staleFixture.game,
            battingTeam: staleFixture.visitingTeam,
            displayedAtbats: staleFixture.displayedAtbats,
            pitchers: [],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { try store.context.save() }
        )

        #expect(afterPrepareOnly == before)
        #expect(unsupported.disposition == .unsupportedAction)
        #expect(failedSave.disposition == .persistenceFailed)
        #expect(stale.disposition == .unavailablePreparedState)
        #expect(fixture.visitingFirst.result == "Result")
        #expect(fixture.visitingFirst.maxbase == "No Bases")
        #expect(fixture.visitingFirst.rbis == 0)
        #expect(fixture.visitingFirst.earnedRun == true)
        #expect(staleFixture.visitingFirst.result == "Result")
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.8 accepted ordinary scoring agrees after fresh V4 reload")
    func task78AcceptedOrdinaryScoringAgreesAfterFreshV4Reload() throws {
        let store = try Store(fileBackedName: "Task78OrdinaryAgreement")
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let adapter = LegacyScoringOperationEvidenceAdapter(container: store.container)
        let operation = UUID(uuidString: "10000000-0000-0000-0000-000000078001")!

        let accepted = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationIdentity: operation,
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        let expected = try LegacyPersistenceAgreementExpected.make(
            result: accepted,
            submissionFamily: LegacyScoringOperationEvidenceConstants.ordinarySubmissionFamily,
            game: fixture.game,
            targetAtbat: fixture.visitingFirst,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher]
        )

        let agreement = LegacyPersistenceAgreementVerifier(container: store.container).verify(expected)
        let retry = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationIdentity: operation,
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )

        #expect(accepted.disposition == .accepted)
        #expect(agreement.classification == .agreementConfirmed)
        #expect(agreement.lookupPerformedWrites == false)
        #expect(agreement.comparedFacts.contains(.result))
        #expect(agreement.comparedFacts.contains(.runnerOrBaseState))
        #expect(agreement.comparedFacts.contains(.currentBatter))
        #expect(retry.disposition == .duplicatePrevented)
        #expect(retry.operationEvidenceResult?.idempotencyResult == .exactRetryAlreadyAccepted)
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.8 accepted out-producing ordinary scoring agrees after fresh V4 reload")
    func task78AcceptedOutProducingOrdinaryScoringAgreesAfterFreshV4Reload() throws {
        let store = try Store(fileBackedName: "Task78OutAgreement")
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let adapter = LegacyScoringOperationEvidenceAdapter(container: store.container)

        let accepted = coordinator.submitScoringAction(
            legacyResult: "Ground Out",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationIdentity: UUID(uuidString: "10000000-0000-0000-0000-000000078002")!,
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        let expected = try LegacyPersistenceAgreementExpected.make(
            result: accepted,
            submissionFamily: LegacyScoringOperationEvidenceConstants.ordinarySubmissionFamily,
            game: fixture.game,
            targetAtbat: fixture.visitingFirst,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher]
        )
        let agreement = LegacyPersistenceAgreementVerifier(container: store.container).verify(expected)

        #expect(accepted.disposition == .accepted)
        #expect(agreement.classification == .agreementConfirmed)
        #expect(agreement.comparedFacts.contains(.outs))
        #expect(agreement.comparedFacts.contains(.inningAndHalfInning))
        #expect(agreement.comparedFacts.contains(.completionOrProgressionState))
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.8 accepted additional-choice scoring agrees after fresh V4 reload")
    func task78AcceptedAdditionalChoiceScoringAgreesAfterFreshV4Reload() throws {
        let store = try Store(fileBackedName: "Task78AdditionalChoiceAgreement")
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let adapter = LegacyScoringOperationEvidenceAdapter(container: store.container)
        let pending = try #require(coordinator.prepareAdditionalChoiceScoringAction(
            legacyResult: "Fielder's Choice",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults
        ).pendingChoice)
        let choices = LiveScoringWorkflowCoordinator.AdditionalScoringChoices(
            legacyResult: "Fielder's Choice",
            maxBase: "First",
            outAt: "Second",
            rbis: 1,
            stolenBases: 1,
            earnedRun: false,
            playRecord: "6-4"
        )

        let accepted = coordinator.submitAdditionalChoiceScoringAction(
            pendingChoice: pending,
            choices: choices,
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        let expected = try LegacyPersistenceAgreementExpected.make(
            result: accepted,
            submissionFamily: LegacyScoringOperationEvidenceConstants.additionalChoiceSubmissionFamily,
            game: fixture.game,
            targetAtbat: fixture.visitingFirst,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher]
        )
        let agreement = LegacyPersistenceAgreementVerifier(container: store.container).verify(expected)

        #expect(accepted.disposition == .accepted)
        #expect(agreement.classification == .agreementConfirmed)
        #expect(agreement.comparedFacts.contains(.rbi))
        #expect(agreement.comparedFacts.contains(.earnedRunClassification))
        #expect(agreement.comparedFacts.contains(.stolenBaseOrSacrificeFacts))
        #expect(agreement.comparedFacts.contains(.fielderPlayFacts))
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.8 agreement fails closed for missing evidence target and fingerprint conflicts")
    func task78AgreementFailsClosedForMissingEvidenceTargetAndFingerprintConflicts() throws {
        let store = try Store(fileBackedName: "Task78FailureClassifications")
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        let unrelated = Fixture.insertGame(into: store.context, location: "Task 7.8 Unrelated Field")
        _ = Fixture.insertPitcher(for: unrelated, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let adapter = LegacyScoringOperationEvidenceAdapter(container: store.container)
        let accepted = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationIdentity: UUID(uuidString: "10000000-0000-0000-0000-000000078003")!,
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        let expected = try LegacyPersistenceAgreementExpected.make(
            result: accepted,
            submissionFamily: LegacyScoringOperationEvidenceConstants.ordinarySubmissionFamily,
            game: fixture.game,
            targetAtbat: fixture.visitingFirst,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher]
        )
        let verifier = LegacyPersistenceAgreementVerifier(container: store.container)
        let missingEvidenceExpected = expected.replacing(operationIdentity: UUID(uuidString: "10000000-0000-0000-0000-0000000780ff")!)
        let unrelatedTargetExpected = expected.replacing(gameIdentity: unrelated.game.ident, atbatIdentity: unrelated.visitingFirst.ident)
        let conflictingFingerprintExpected = expected.replacing(requestFingerprint: "conflicting-fingerprint")
        let missingAtbatIdentity = UUID(uuidString: "10000000-0000-0000-0000-0000000780aa")!
        let missingGameIdentity = UUID(uuidString: "10000000-0000-0000-0000-0000000780bb")!

        #expect(verifier.verify(missingEvidenceExpected).classification == .acceptedOperationEvidenceMissing)
        #expect(verifier.verify(unrelatedTargetExpected).classification == .operationIdentityOrFingerprintConflict)
        #expect(verifier.verify(conflictingFingerprintExpected).classification == .operationIdentityOrFingerprintConflict)

        let freshContext = ModelContext(store.container)
        let loadedEvidence = try fetchEvidence(expected.operationIdentity, in: freshContext)
        let evidence = try #require(loadedEvidence)
        evidence.targetAtbatIdentity = missingAtbatIdentity
        try freshContext.save()
        #expect(verifier.verify(expected.replacing(atbatIdentity: missingAtbatIdentity)).classification == .targetAtbatMissing)

        evidence.targetGameIdentity = missingGameIdentity
        try freshContext.save()
        #expect(verifier.verify(expected.replacing(gameIdentity: missingGameIdentity, atbatIdentity: missingAtbatIdentity)).classification == .targetGameMissing)
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.8 agreement fails closed for missing target fact disagreement and reload failure")
    func task78AgreementFailsClosedForMissingTargetFactDisagreementAndReloadFailure() throws {
        let store = try Store(fileBackedName: "Task78MismatchAndReloadFailure")
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let adapter = LegacyScoringOperationEvidenceAdapter(container: store.container)
        let accepted = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: Common().onresults + Common().outresults,
            save: { throw InjectedSaveError() },
            operationIdentity: UUID(uuidString: "10000000-0000-0000-0000-000000078004")!,
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        let expected = try LegacyPersistenceAgreementExpected.make(
            result: accepted,
            submissionFamily: LegacyScoringOperationEvidenceConstants.ordinarySubmissionFamily,
            game: fixture.game,
            targetAtbat: fixture.visitingFirst,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher]
        )

        let freshMutation = ModelContext(store.container)
        let persistedAtbat = try fetchRequiredAtbat(fixture.visitingFirst.ident, in: freshMutation)
        persistedAtbat.rbis = 2
        try freshMutation.save()
        let mismatch = LegacyPersistenceAgreementVerifier(container: store.container).verify(expected)
        let reloadFailure = LegacyPersistenceAgreementVerifier(
            container: store.container,
            makeFreshContext: { _ in throw LegacyPersistenceAgreementInjectedError.reloadFailed }
        ).verify(expected)

        #expect(mismatch.classification == .persistedFactsDisagree)
        #expect(reloadFailure.classification == .reloadFailure)
        #expect(reloadFailure.lookupPerformedWrites == false)
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 5.11 accepted correction is coordinated below presentation and refreshes Legacy state")
    func task511AcceptedCorrectionIsCoordinatedBelowPresentationAndRefreshesLegacyState() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        fixture.visitingFirst.seq = 1
        fixture.visitingSecond.result = "Single"
        fixture.visitingSecond.maxbase = "First"
        fixture.visitingSecond.seq = 2
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let target = LiveScoringWorkflowCoordinator.LegacyCorrectionTarget(
            gameIdentity: fixture.game.ident,
            atbatIdentity: fixture.visitingFirst.ident,
            expectedOriginal: .init(fixture.visitingFirst)
        )
        var saveCount = 0

        let result = coordinator.submitCorrection(
            target: target,
            replacement: .init(result: "Ground Out", maxBase: "No Bases", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            modelContext: store.context,
            save: {
                saveCount += 1
                try store.context.save()
            }
        )

        #expect(result.disposition == .accepted)
        #expect(result.correctionPlan?.disposition.mayApply == true)
        #expect(result.applicationResult?.applied == true)
        #expect(result.projectionResult?.disposition == .success)
        #expect(result.refreshedState?.gameIdentity == fixture.game.ident)
        #expect(result.targetAtbatIdentity == fixture.visitingFirst.ident)
        #expect(fixture.visitingFirst.result == "Ground Out")
        #expect(fixture.visitingFirst.outs == 1)
        #expect(fixture.visitingSecond.seq == 2)
        #expect(saveCount == 1)
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.legacyScoringOperationEvidenceCount() == 0)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 5.11 cancellation performs no mutation or save")
    func task511CancellationPerformsNoMutationOrSave() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let before = Snapshot.capture(fixture.game)
        var saveCount = 0

        let result = coordinator.submitCorrection(
            target: .init(gameIdentity: fixture.game.ident, atbatIdentity: fixture.visitingFirst.ident, expectedOriginal: .init(fixture.visitingFirst)),
            replacement: nil,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [],
            modelContext: store.context,
            save: {
                saveCount += 1
                try store.context.save()
            }
        )

        #expect(result.disposition == .canceled)
        #expect(Snapshot.capture(fixture.game) == before)
        #expect(saveCount == 0)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 5.11 target mismatch and unsupported correction fail closed")
    func task511TargetMismatchAndUnsupportedCorrectionFailClosed() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let otherFixture = Fixture.insertGame(into: store.context, location: "Other Task 5.11 Field")
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let before = Snapshot.capture(fixture.game)

        let missing = coordinator.submitCorrection(
            target: .init(gameIdentity: fixture.game.ident, atbatIdentity: UUID()),
            replacement: .init(result: "Ground Out", maxBase: "No Bases", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [],
            modelContext: store.context,
            save: { try store.context.save() }
        )
        let wrongGame = coordinator.submitCorrection(
            target: .init(gameIdentity: otherFixture.game.ident, atbatIdentity: fixture.visitingFirst.ident),
            replacement: .init(result: "Ground Out", maxBase: "No Bases", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [],
            modelContext: store.context,
            save: { try store.context.save() }
        )
        let unsupported = coordinator.submitCorrection(
            target: .init(gameIdentity: fixture.game.ident, atbatIdentity: fixture.visitingFirst.ident),
            replacement: .init(result: "Unsupported Legacy Result", maxBase: "No Bases", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [],
            modelContext: store.context,
            save: { try store.context.save() }
        )

        #expect(missing.disposition == .targetMissing)
        #expect(wrongGame.disposition == .wrongGameTarget)
        #expect(unsupported.disposition == .unsupportedCorrection)
        #expect(Snapshot.capture(fixture.game) == before)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 5.11 stale target and persistence failure preserve prior accepted state")
    func task511StaleTargetAndPersistenceFailurePreservePriorAcceptedState() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let expected = LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(fixture.visitingFirst)
        fixture.visitingFirst.rbis = 1

        let stale = coordinator.submitCorrection(
            target: .init(gameIdentity: fixture.game.ident, atbatIdentity: fixture.visitingFirst.ident, expectedOriginal: expected),
            replacement: .init(result: "Ground Out", maxBase: "No Bases", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [],
            modelContext: store.context,
            save: { try store.context.save() }
        )
        let beforeFailure = Snapshot.capture(fixture.game)
        let failed = coordinator.submitCorrection(
            target: .init(gameIdentity: fixture.game.ident, atbatIdentity: fixture.visitingFirst.ident, expectedOriginal: .init(fixture.visitingFirst)),
            replacement: .init(result: "Ground Out", maxBase: "No Bases", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [],
            modelContext: store.context,
            save: { throw InjectedSaveError() }
        )

        #expect(stale.disposition == .targetStale)
        #expect(failed.disposition == .persistenceFailed)
        #expect(Snapshot.capture(fixture.game) == beforeFailure)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(fixture.visitingFirst.rbis == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.9 entry review confirmation routes through correction workflow and refreshes accepted state")
    func task79EntryReviewConfirmationRoutesThroughCorrectionWorkflowAndRefreshesAcceptedState() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "First"
        fixture.visitingFirst.seq = 1
        fixture.visitingSecond.result = "Single"
        fixture.visitingSecond.maxbase = "First"
        fixture.visitingSecond.seq = 2
        try store.context.save()
        let presenter = LiveScoringShellPresentation()
        let coordinator = LiveScoringWorkflowCoordinator()
        let replacement = LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement(
            result: "Ground Out",
            maxBase: "No Bases",
            outAt: "Safe",
            rbis: 0,
            stolenBases: 0,
            earnedRun: true
        )
        let beforeUnrelated = AtbatSnapshot(fixture.visitingSecond)
        var review = presenter.prepareCorrectionEntry(
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            replacement: replacement,
            supportedLegacyResults: ["Single", "Ground Out"],
            currentReview: nil
        ).reviewState
        var submitCount = 0
        var saveCount = 0

        let presentation = presenter.confirmCorrectionReview(&review) { target, replacement in
            submitCount += 1
            return coordinator.submitCorrection(
                target: target,
                replacement: replacement,
                displayedAtbats: fixture.displayedAtbats,
                pitchers: [pitcher],
                modelContext: store.context,
                save: {
                    saveCount += 1
                    try store.context.save()
                }
            )
        }

        #expect(submitCount == 1)
        #expect(saveCount == 1)
        #expect(presentation.outcome == .accepted)
        #expect(presentation.refreshedState?.gameIdentity == fixture.game.ident)
        #expect(presentation.refreshedState?.currentBatter?.identity == fixture.visitingFirst.player.identifier)
        #expect(presentation.refreshedState?.battingOrderPosition == 1)
        #expect(presentation.refreshedState?.latestScoringSequence == 2)
        #expect(presentation.refreshedState?.currentScorecardColumn == 2)
        #expect(presentation.refreshedState?.outs == 1)
        #expect(presentation.refreshedState?.currentOrPendingLegacyAtbat == nil)
        #expect(review == nil)
        #expect(fixture.visitingFirst.result == "Ground Out")
        #expect(fixture.visitingFirst.outs == 1)
        #expect(AtbatSnapshot(fixture.visitingSecond).identity == beforeUnrelated.identity)
        #expect(AtbatSnapshot(fixture.visitingSecond).result == beforeUnrelated.result)
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.legacyScoringOperationEvidenceCount() == 0)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.11 accepted save followed by coordinator recreation does not lose or duplicate event")
    func task711AcceptedSaveFollowedByCoordinatorRecreation() throws {
        let store = try Store(fileBackedName: "Task711CoordinatorRecreation")
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()

        let operationIdentity = UUID(uuidString: "71100000-0000-0000-0000-000000000711")!
        let adapter = LegacyScoringOperationEvidenceAdapter(container: store.container)

        let coordinator = LiveScoringWorkflowCoordinator()
        let result = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: { try store.context.save() },
            operationIdentity: operationIdentity,
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        #expect(result.disposition == .accepted)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)

        let newCoordinator = LiveScoringWorkflowCoordinator()
        let prepared = newCoordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.game.atbats,
            pitchers: [pitcher]
        )

        #expect(prepared.disposition == .ready)
        #expect(fixture.game.atbats.count == 2)
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.11 reopening the same game repeatedly does not resubmit or duplicate event")
    func task711ReopeningSameGameRepeatedlyDoesNotResubmit() throws {
        let store = try Store(fileBackedName: "Task711Reopening")
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()

        let operationIdentity = UUID(uuidString: "71100000-0000-0000-0000-000000000712")!
        let adapter = LegacyScoringOperationEvidenceAdapter(container: store.container)

        let coordinator = LiveScoringWorkflowCoordinator()
        let result = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: { try store.context.save() },
            operationIdentity: operationIdentity,
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        #expect(result.disposition == .accepted)

        let prepareAgain = coordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.game.atbats,
            pitchers: [pitcher]
        )

        #expect(prepareAgain.disposition == .ready)
        #expect(fixture.game.atbats.count == 2)
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.11 repeated identical submission after recreation uses Task 7.7 safety")
    func task711RepeatedIdenticalSubmissionAfterRecreation() throws {
        let store = try Store(fileBackedName: "Task711RepeatedSubmission")
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let operationIdentity = UUID(uuidString: "71100000-0000-0000-0000-000000000713")!
        let adapter = LegacyScoringOperationEvidenceAdapter(container: store.container)

        let coordinator = LiveScoringWorkflowCoordinator()
        let first = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: { try store.context.save() },
            operationIdentity: operationIdentity,
            operationEvidenceAdapter: adapter,
            modelContext: store.context
        )
        #expect(first.disposition == .accepted)

        let newCoordinator = LiveScoringWorkflowCoordinator()
        let newAdapter = LegacyScoringOperationEvidenceAdapter(container: store.container)
        let second = newCoordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: { try store.context.save() },
            operationIdentity: operationIdentity,
            operationEvidenceAdapter: newAdapter,
            modelContext: store.context
        )

        #expect(second.disposition == .duplicatePrevented)
        #expect(fixture.game.atbats.count == 2)
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.11 save failure followed by reconstruction leaves no partial state")
    func task711SaveFailureFollowedByReconstruction() throws {
        let store = try Store(fileBackedName: "Task711SaveFailure")
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let operationIdentity = UUID(uuidString: "71100000-0000-0000-0000-000000000714")!

        var coordinator: LiveScoringWorkflowCoordinator? = LiveScoringWorkflowCoordinator()
        let failingAdapter = LegacyScoringOperationEvidenceAdapter(
            container: store.container,
            dependencies: LegacyScoringOperationEvidenceDependencies(injectedFailures: [.save])
        )

        let failed = coordinator!.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: { try store.context.save() },
            operationIdentity: operationIdentity,
            operationEvidenceAdapter: failingAdapter,
            modelContext: store.context
        )
        #expect(failed.disposition == .persistenceFailed)

        coordinator = nil
        let newCoordinator = LiveScoringWorkflowCoordinator()
        let prepared = newCoordinator.prepareLiveGameState(
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.game.atbats,
            pitchers: [pitcher]
        )

        #expect(prepared.disposition == .ready)
        #expect(fixture.visitingFirst.result == "Result")
        #expect(fixture.game.atbats.count == 2)
        #expect(try store.legacyScoringOperationEvidenceCount() == 0)
        #expect(try store.canonicalScoringRecordCount() == 0)
    }

    @Test("Task 7.11 accepted save followed by container recreation does not lose or duplicate event")
    func task711AcceptedSaveFollowedByContainerRecreation() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Task711ContainerRecreation-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        let configuration = ModelConfiguration("LiveScoringWorkflowCoordinatorTests-Task711Recreation", url: url)
        var container: ModelContainer? = try ModelContainer(for: schema, configurations: [configuration])
        var context: ModelContext? = ModelContext(container!)

        let fixture = Fixture.insertGame(into: context!)
        let pitcher = Fixture.insertPitcher(for: fixture, into: context!)
        let gameIdentity = fixture.game.ident
        let targetIdentity = fixture.visitingFirst.ident
        try context!.save()

        let operationIdentity = UUID(uuidString: "71100000-0000-0000-0000-000000000715")!
        let adapter = LegacyScoringOperationEvidenceAdapter(container: container!)

        let coordinator = LiveScoringWorkflowCoordinator()
        let result = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single", "Ground Out"],
            save: { try context!.save() },
            operationIdentity: operationIdentity,
            operationEvidenceAdapter: adapter,
            modelContext: context!
        )
        #expect(result.disposition == .accepted)

        context = nil
        container = nil

        let newContainer = try ModelContainer(for: schema, configurations: [configuration])
        let newContext = ModelContext(newContainer)

        var evidenceDescriptor = FetchDescriptor<LegacyScoringOperationEvidenceRecord>()
        let evidence = try newContext.fetch(evidenceDescriptor)
        #expect(evidence.count == 1)
        #expect(evidence.first?.operationIdentity == operationIdentity)

        var gameDescriptor = FetchDescriptor<Game>()
        let games = try newContext.fetch(gameDescriptor)
        let reloadedGame = try #require(games.first { $0.ident == gameIdentity })

        let reloadedTarget = try #require(reloadedGame.atbats.first { $0.ident == targetIdentity })
        #expect(reloadedTarget.result == "Single")
        #expect(reloadedGame.atbats.count == 2)

        let canonicalRecords = try newContext.fetchCount(FetchDescriptor<CanonicalGameHistoryRecord>())
        #expect(canonicalRecords == 0)

        let reloadedPitcher = try #require(try newContext.fetch(FetchDescriptor<Pitcher>()).first)
        let newCoordinator = LiveScoringWorkflowCoordinator()
        let prepared = newCoordinator.prepareLiveGameState(
            game: reloadedGame,
            battingTeam: reloadedGame.vteam!,
            displayedAtbats: reloadedGame.atbats,
            pitchers: [reloadedPitcher]
        )
        #expect(prepared.disposition == .ready)
        #expect(reloadedGame.atbats.count == 2)

        try FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // The task718 test has been moved out to a top level struct
}

struct Task718Suite {
    @Test("Task 7.18 Legacy comparison matrix verifies routed behavior matches legacy evidence")
    @MainActor
    func task718LegacyComparisonMatrixVerifiesRoutedBehaviorMatchesLegacyEvidence() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let coordinator = LiveScoringWorkflowCoordinator()
        let presenter = LiveScoringShellPresentation()

        // 1. Prepared State & Presentation Enablement (Action Availability & Disabled conditions)
        let prepared = coordinator.prepareLiveGameState(game: fixture.game, battingTeam: fixture.visitingTeam, displayedAtbats: fixture.displayedAtbats, pitchers: [pitcher])
        let semantic = coordinator.semanticScoreState(preparedState: prepared, displayedAtbats: fixture.displayedAtbats)
        let actions = coordinator.enabledScoringActions(preparedState: prepared, semanticScoreState: semantic, displayedAtbats: fixture.displayedAtbats, supportedLegacyResults: ["Single", "Ground Out"])
        let presentation = presenter.presentEnabledActionSet(actions)

        let singleAction = try #require(presentation.state(for: .legacyResult("Single")))
        #expect(singleAction.isEnabled == true)
        #expect(singleAction.accessibilityLabel == "Score Single")
        #expect(singleAction.accessibilityValue == "Available")

        let unsupportedActions = coordinator.enabledScoringActions(preparedState: prepared, semanticScoreState: semantic, displayedAtbats: fixture.displayedAtbats, supportedLegacyResults: ["Unsupported"])
        let unsupportedAction = try #require(unsupportedActions.state(for: .legacyResult("Unsupported")))
        #expect(unsupportedAction.isEnabled == false)
        #expect(unsupportedAction.disposition == .disabledUnsupported)

        // 2. Cancelation behavior
        var review = presenter.prepareCorrectionReview(
            original: LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(fixture.visitingFirst),
            batterName: "Batter",
            replacement: .init(result: "Double", maxBase: "Second", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true),
            supportedLegacyResults: ["Single", "Double"]
        )
        let cancelResult = presenter.cancelCorrectionReview(&review)
        #expect(cancelResult.outcome == .canceled)
        #expect(cancelResult.shouldClearPendingReview == true)
        #expect(review == nil)

        // 3. Accepted scoring outcome, effects, navigation dismissal
        let operation = UUID()
        let submitResult = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() },
            operationIdentity: operation,
            operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter(container: store.container),
            modelContext: store.context
        )

        #expect(submitResult.disposition == .accepted)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(fixture.visitingFirst.maxbase == "No Bases")

        let presentationSubmit = presenter.presentSubmissionResult(submitResult, requiresAdditionalChoice: false)
        #expect(presentationSubmit.shouldDismissScoringSheet == true)

        // 4. Duplicate prevention & idempotency
        let duplicateSubmit = coordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() },
            operationIdentity: operation,
            operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter(container: store.container),
            modelContext: store.context
        )
        #expect(duplicateSubmit.disposition == .duplicatePrevented)
        #expect(fixture.visitingFirst.result == "Single")

        // 5. Persistence boundary, routing, absence of canonical writes
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.fetchLegacyAtbats().count == 2)
        #expect(try store.canonicalScoringRecordCount() == 0)

        if let url = store.container.configurations.first?.url {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }
}

@MainActor
private func coordinatorSubmitOrdinary(
    coordinator: LiveScoringWorkflowCoordinator,
    store: Store,
    fixture: Fixture,
    pitcher: Pitcher,
    result: String,
    operation: UUID,
    adapter: LegacyScoringOperationEvidenceAdapter
) -> LiveScoringWorkflowCoordinator.ScoringSubmissionResult {
    coordinator.submitScoringAction(
        legacyResult: result,
        targetAtbat: fixture.visitingFirst,
        game: fixture.game,
        battingTeam: fixture.visitingTeam,
        displayedAtbats: fixture.displayedAtbats,
        pitchers: [pitcher],
        supportedLegacyResults: ["Single", "Double", "Ground Out"],
        save: { throw InjectedSaveError() },
        operationIdentity: operation,
        operationEvidenceAdapter: adapter,
        modelContext: store.context
    )
}

    @Test("Task 7.12 sustained routed live-scoring session remains coherent and durable")
    @MainActor
    func task712SustainedRoutedLiveScoringSessionRemainsCoherentAndDurable() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Task712LongSession-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        let configuration = ModelConfiguration("LiveScoringWorkflowCoordinatorTests-Task712", url: url)
        var container: ModelContainer? = try ModelContainer(for: schema, configurations: [configuration])
        var context: ModelContext? = ModelContext(container!)

        let fixture = Fixture.insertGame(into: context!)
        let homePitcher = Fixture.insertPitcher(for: fixture, into: context!)
        let homeBatter = Player(name: "Home Batter", number: "10", position: "1B", batDir: "R", batOrder: 2, team: fixture.homeTeam)
        context!.insert(homeBatter)
        fixture.homeTeam.players.append(homeBatter)
        fixture.game.players.append(homeBatter)

        let incoming = Player(name: "Incoming Visitor", number: "12", position: "RF", batDir: "R", batOrder: 3, team: fixture.visitingTeam)
        context!.insert(incoming)
        fixture.visitingTeam.players.append(incoming)
        fixture.game.players.append(incoming)
        fixture.game.replaced.append(fixture.visitingSecond.player)
        fixture.game.incomings.append(incoming)

        let incomingAtbat = Atbat(game: fixture.game, team: fixture.visitingTeam, player: incoming, result: "Result", maxbase: "No Bases", batOrder: 3, outAt: "Safe", inning: 1, seq: 3, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
        context!.insert(incomingAtbat)
        fixture.game.atbats.append(incomingAtbat)

        try context!.save()

        var coordinator: LiveScoringWorkflowCoordinator? = LiveScoringWorkflowCoordinator()
        var adapter: LegacyScoringOperationEvidenceAdapter? = LegacyScoringOperationEvidenceAdapter(container: container!)

        var operationCount = 0
        func nextIdentity() -> UUID {
            operationCount += 1
            return UUID(uuidString: String(format: "71200000-0000-0000-0000-%012d", operationCount))!
        }

        // 1. Scoring operations
        let op1 = nextIdentity()
        let act1 = coordinator!.submitScoringAction(
            legacyResult: "Single", targetAtbat: fixture.visitingFirst, game: fixture.game, battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.game.atbats, pitchers: [homePitcher], supportedLegacyResults: ["Single"],
            save: { try context!.save() }, operationIdentity: op1, operationEvidenceAdapter: adapter!, modelContext: context!
        )
        #expect(act1.disposition == .accepted)
        fixture.visitingFirst.result = "Single"
        fixture.visitingFirst.maxbase = "No Bases"

        let op2 = nextIdentity()
        let act2 = coordinator!.submitScoringAction(
            legacyResult: "Ground Out", targetAtbat: fixture.visitingSecond, game: fixture.game, battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.game.atbats, pitchers: [homePitcher], supportedLegacyResults: ["Ground Out"],
            save: { try context!.save() }, operationIdentity: op2, operationEvidenceAdapter: adapter!, modelContext: context!
        )
        #expect(act2.disposition == .accepted)
        fixture.visitingSecond.result = "Ground Out"
        fixture.visitingSecond.outs = 1

        // Coordinator recreation
        coordinator = nil
        coordinator = LiveScoringWorkflowCoordinator()

        // Substitution usage
        let op3 = nextIdentity()
        let act3 = coordinator!.submitScoringAction(
            legacyResult: "Strikeout", targetAtbat: incomingAtbat, game: fixture.game, battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.game.atbats, pitchers: [homePitcher], supportedLegacyResults: ["Strikeout"],
            save: { try context!.save() }, operationIdentity: op3, operationEvidenceAdapter: adapter!, modelContext: context!
        )
        #expect(act3.disposition == .accepted)
        incomingAtbat.result = "Strikeout"
        incomingAtbat.outs = 1

        // Background / Resume boundary (Container recreation)
        context = nil
        adapter = nil
        container = nil
        coordinator = nil

        let resumedContainer = try ModelContainer(for: schema, configurations: [configuration])
        let resumedContext = ModelContext(resumedContainer)
        let resumedCoordinator = LiveScoringWorkflowCoordinator()
        let resumedAdapter = LegacyScoringOperationEvidenceAdapter(container: resumedContainer)

        let games = try resumedContext.fetch(FetchDescriptor<Game>())
        let resumedGame = try #require(games.first)
        let resumedHomePitcher = try #require(resumedGame.pitchers.first)

        // Pitcher change
        let visitingPitcher = Player(name: "Visiting Pitcher", number: "99", position: "P", batDir: "R", batOrder: 9, team: resumedGame.vteam!)
        let newPitcher = Pitcher(player: visitingPitcher, team: resumedGame.vteam!, game: resumedGame, startInn: 1, endInn: 1)
        resumedContext.insert(visitingPitcher)
        resumedContext.insert(newPitcher)
        resumedGame.vteam!.players.append(visitingPitcher)
        resumedGame.players.append(visitingPitcher)
        resumedGame.pitchers.append(newPitcher)

        let homeAtbat = Atbat(game: resumedGame, team: resumedGame.hteam!, player: resumedGame.hteam!.players.first { $0.name == "Home Batter" }!, result: "Result", maxbase: "No Bases", batOrder: 1, outAt: "Safe", inning: 1, seq: 4, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
        resumedContext.insert(homeAtbat)
        resumedGame.atbats.append(homeAtbat)
        try resumedContext.save()

        let resumedHomeAtbats = resumedGame.atbats.filter { $0.team.ident == resumedGame.hteam!.ident }

        let op4 = nextIdentity()
        let act4 = resumedCoordinator.submitScoringAction(
            legacyResult: "Single", targetAtbat: homeAtbat, game: resumedGame, battingTeam: resumedGame.hteam!,
            displayedAtbats: resumedHomeAtbats, pitchers: [resumedHomePitcher, newPitcher], supportedLegacyResults: ["Single", "Double"],
            save: { try resumedContext.save() }, operationIdentity: op4, operationEvidenceAdapter: resumedAdapter, modelContext: resumedContext
        )
        #expect(act4.disposition == .accepted)

        // Duplicate
        let act6 = resumedCoordinator.submitScoringAction(
            legacyResult: "Single", targetAtbat: homeAtbat, game: resumedGame, battingTeam: resumedGame.hteam!,
            displayedAtbats: resumedHomeAtbats, pitchers: [resumedHomePitcher, newPitcher], supportedLegacyResults: ["Single", "Double"],
            save: { try resumedContext.save() }, operationIdentity: op4, operationEvidenceAdapter: resumedAdapter, modelContext: resumedContext
        )
        #expect(act6.disposition == .duplicatePrevented)

        // Failure
        let op7 = nextIdentity()
        let act7 = resumedCoordinator.submitScoringAction(
            legacyResult: "Single", targetAtbat: homeAtbat, game: resumedGame, battingTeam: resumedGame.hteam!,
            displayedAtbats: resumedHomeAtbats, pitchers: [resumedHomePitcher, newPitcher], supportedLegacyResults: ["Single", "Double"],
            save: { throw InjectedSaveError() }, operationIdentity: op7, operationEvidenceAdapter: resumedAdapter, modelContext: resumedContext
        )
        #expect(act7.disposition == .persistenceFailed)

        // Correction
        let snapshot = LiveScoringWorkflowCoordinator.LegacyCorrectionSnapshot(homeAtbat)
        let correctionPlan = LiveScoringWorkflowCoordinator.LegacyCorrectionReplacement(result: "Double", maxBase: "Second", outAt: "Safe", rbis: 0, stolenBases: 0, earnedRun: true)
        let correctionTarget = LiveScoringWorkflowCoordinator.LegacyCorrectionTarget(gameIdentity: resumedGame.ident, atbatIdentity: homeAtbat.ident, expectedOriginal: snapshot)
        _ = nextIdentity()
        let act5 = resumedCoordinator.submitCorrection(
            target: correctionTarget,
            replacement: correctionPlan,
            displayedAtbats: resumedHomeAtbats,
            pitchers: [resumedHomePitcher, newPitcher],
            modelContext: resumedContext,
            save: { try resumedContext.save() }
        )
        #expect(act5.disposition == .accepted)

        // Final durable-state verification
        let evidence = try resumedContext.fetch(FetchDescriptor<LegacyScoringOperationEvidenceRecord>())
        #expect(evidence.map(\.operationIdentity).sorted { $0.uuidString < $1.uuidString } == [op1, op2, op3, op4])
        #expect(evidence.filter { $0.disposition == "accepted" }.count == 4)
        #expect(resumedGame.atbats.filter { $0.result != "Result" }.count == 4)

        #expect(try resumedContext.fetchCount(FetchDescriptor<CanonicalGameHistoryRecord>()) == 0)
        #expect(try resumedContext.fetchCount(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>()) == 0)
        #expect(try resumedContext.fetchCount(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>()) == 0)
        #expect(try resumedContext.fetchCount(FetchDescriptor<CanonicalScoringEventPayloadRecord>()) == 0)
        #expect(try resumedContext.fetchCount(FetchDescriptor<CanonicalScoringCorrectionRecord>()) == 0)
    }



private struct Store {
    let container: ModelContainer
    let context: ModelContext

    init(fileBackedName: String? = nil) throws {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
        let configuration: ModelConfiguration
        if let fileBackedName {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ScoreKeepTask78PersistenceAgreement", isDirectory: true)
                .appendingPathComponent("\(fileBackedName)-\(UUID().uuidString)", isDirectory: true)
                .appendingPathComponent("Store.sqlite")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            configuration = ModelConfiguration("LiveScoringWorkflowCoordinatorTests-\(fileBackedName)", url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
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

    func legacyScoringOperationEvidenceCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<LegacyScoringOperationEvidenceRecord>())
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

    static func insertGame(
        into context: ModelContext,
        location: String = "Task 5.10 Field",
        everyOneHits: Bool = false,
        numInnings: Int = 9
    ) -> Fixture {
        let visitingTeam = Team(name: "Visitors", coach: "", details: "")
        let homeTeam = Team(name: "Home", coach: "", details: "")
        let visitingFirstPlayer = Player(name: "Visitor One", number: "1", position: "SS", batDir: "R", batOrder: 1, team: visitingTeam)
        let visitingSecondPlayer = Player(name: "Visitor Two", number: "2", position: "2B", batDir: "R", batOrder: 2, team: visitingTeam)
        let homePitcher = Player(name: "Home Pitcher", number: "9", position: "P", batDir: "R", batOrder: 1, team: homeTeam)
        let game = Game(
            date: "2026-07-18T12:00:00Z",
            location: location,
            highLights: "",
            hscore: 0,
            vscore: 0,
            everyOneHits: everyOneHits,
            numInnings: numInnings,
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

    static func insertPitcher(for fixture: Fixture, into context: ModelContext) -> Pitcher {
        let pitcher = Pitcher(player: fixture.homePitcher, team: fixture.homeTeam, game: fixture.game, startInn: 1, endInn: 1)
        context.insert(pitcher)
        fixture.game.pitchers.append(pitcher)
        return pitcher
    }
}

private func markFirstTwoVisitorsCompleted(_ fixture: Fixture) {
    fixture.visitingFirst.result = "Single"
    fixture.visitingFirst.maxbase = "First"
    fixture.visitingFirst.inning = 0.1
    fixture.visitingFirst.seq = 1
    fixture.visitingFirst.outs = 0
    fixture.visitingSecond.result = "Ground Out"
    fixture.visitingSecond.inning = 0.2
    fixture.visitingSecond.seq = 2
    fixture.visitingSecond.outs = 1
}

private struct InjectedSaveError: Error {}

@MainActor
private final class SaveRecorder {
    private let action: () throws -> Void
    private var shouldFailNextSave = false
    private(set) var attempts = 0

    init(action: @escaping () throws -> Void) {
        self.action = action
    }

    func failNextSave() {
        shouldFailNextSave = true
    }

    func save() throws {
        attempts += 1
        if shouldFailNextSave {
            shouldFailNextSave = false
            throw InjectedSaveError()
        }
        try action()
    }
}

private struct Snapshot: Equatable {
    let gameHomeScore: Int
    let gameVisitingScore: Int
    let atbats: [AtbatSnapshot]
    let pitchers: [PitcherSnapshot]

    static func capture(_ game: Game) -> Snapshot {
        Snapshot(
            gameHomeScore: game.hscore,
            gameVisitingScore: game.vscore,
            atbats: game.atbats
                .sorted {
                    ($0.col, $0.seq, $0.batOrder, $0.ident.uuidString) <
                    ($1.col, $1.seq, $1.batOrder, $1.ident.uuidString)
                }
                .map(AtbatSnapshot.init),
            pitchers: game.pitchers
                .sorted { $0.ident.uuidString < $1.ident.uuidString }
                .map(PitcherSnapshot.init)
        )
    }
}

private struct AtbatSnapshot: Equatable {
    let identity: UUID
    let result: String
    let maxbase: String
    let outAt: String
    let inning: CGFloat
    let seq: Int
    let col: Int
    let batOrder: Int
    let outs: Int
    let rbis: Int
    let sacFly: Int
    let sacBunt: Int
    let stolenBases: Int
    let earnedRun: Bool
    let playRecord: String
    let endOfInning: Bool

    init(_ atbat: Atbat) {
        identity = atbat.ident
        result = atbat.result
        maxbase = atbat.maxbase
        outAt = atbat.outAt
        inning = atbat.inning
        seq = atbat.seq
        col = atbat.col
        batOrder = atbat.batOrder
        outs = atbat.outs
        rbis = atbat.rbis
        sacFly = atbat.sacFly
        sacBunt = atbat.sacBunt
        stolenBases = atbat.stolenBases
        earnedRun = atbat.earnedRun
        playRecord = atbat.playRec
        endOfInning = atbat.endOfInning
    }
}

private struct PitcherSnapshot: Equatable {
    let identity: UUID
    let startInn: Int
    let sOuts: Int
    let sBats: Int
    let endInn: Int
    let eOuts: Int
    let eBats: Int

    init(_ pitcher: Pitcher) {
        identity = pitcher.ident
        startInn = pitcher.startInn
        sOuts = pitcher.sOuts
        sBats = pitcher.sBats
        endInn = pitcher.endInn
        eOuts = pitcher.eOuts
        eBats = pitcher.eBats
    }
}

private enum LegacyPersistenceAgreementClassification: String, Hashable {
    case agreementConfirmed
    case acceptedOperationEvidenceMissing
    case targetGameMissing
    case targetAtbatMissing
    case persistedFactsDisagree
    case operationIdentityOrFingerprintConflict
    case unsupportedComparison
    case reloadFailure
}

private enum LegacyPersistenceAgreementFact: Hashable {
    case gameIdentity
    case targetAtbatIdentity
    case scoringResult
    case inningAndHalfInning
    case outs
    case runsAndScore
    case runnerOrBaseState
    case battingOrderAndCurrentBatter
    case currentBatter
    case pitcherAttribution
    case rbi
    case earnedRunClassification
    case stolenBaseOrSacrificeFacts
    case fielderPlayFacts
    case completionOrProgressionState
    case operationEvidenceIdentityAndOutcome
    case result
}

private struct LegacyPersistenceAgreementResult {
    let classification: LegacyPersistenceAgreementClassification
    let comparedFacts: Set<LegacyPersistenceAgreementFact>
    let lookupPerformedWrites: Bool
}

private struct LegacyPersistenceAgreementExpected {
    let operationIdentity: UUID
    let requestFingerprint: String
    let submissionFamily: String
    let acceptedResultClassification: String
    let acceptedOutcomeReference: String
    let gameSnapshot: AgreementGameSnapshot
    let atbatSnapshot: AgreementAtbatSnapshot
    let preparedSnapshot: AgreementPreparedSnapshot

    var gameIdentity: UUID { gameSnapshot.identity }
    var atbatIdentity: UUID { atbatSnapshot.identity }

    @MainActor
    static func make(
        result: LiveScoringWorkflowCoordinator.ScoringSubmissionResult,
        submissionFamily: String,
        game: Game,
        targetAtbat: Atbat,
        battingTeam: Team,
        displayedAtbats: [Atbat],
        pitchers: [Pitcher]
    ) throws -> LegacyPersistenceAgreementExpected {
        let evidence = try #require(result.operationEvidenceResult)
        let prepared = LiveScoringWorkflowCoordinator().prepareLiveGameState(
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: pitchers
        )
        return LegacyPersistenceAgreementExpected(
            operationIdentity: evidence.operationIdentity,
            requestFingerprint: evidence.requestFingerprint,
            submissionFamily: submissionFamily,
            acceptedResultClassification: targetAtbat.result,
            acceptedOutcomeReference: "legacyAtbat:\(targetAtbat.ident.uuidString.lowercased())",
            gameSnapshot: AgreementGameSnapshot(game),
            atbatSnapshot: AgreementAtbatSnapshot(targetAtbat),
            preparedSnapshot: AgreementPreparedSnapshot(prepared)
        )
    }

    func replacing(
        operationIdentity: UUID? = nil,
        requestFingerprint: String? = nil,
        gameIdentity: UUID? = nil,
        atbatIdentity: UUID? = nil
    ) -> LegacyPersistenceAgreementExpected {
        LegacyPersistenceAgreementExpected(
            operationIdentity: operationIdentity ?? self.operationIdentity,
            requestFingerprint: requestFingerprint ?? self.requestFingerprint,
            submissionFamily: submissionFamily,
            acceptedResultClassification: acceptedResultClassification,
            acceptedOutcomeReference: acceptedOutcomeReference,
            gameSnapshot: gameSnapshot.replacing(identity: gameIdentity),
            atbatSnapshot: atbatSnapshot.replacing(identity: atbatIdentity),
            preparedSnapshot: preparedSnapshot
        )
    }
}

@MainActor
private struct LegacyPersistenceAgreementVerifier {
    private let container: ModelContainer
    private let makeFreshContext: (ModelContainer) throws -> ModelContext

    init(
        container: ModelContainer,
        makeFreshContext: @escaping (ModelContainer) throws -> ModelContext = { ModelContext($0) }
    ) {
        self.container = container
        self.makeFreshContext = makeFreshContext
    }

    func verify(_ expected: LegacyPersistenceAgreementExpected) -> LegacyPersistenceAgreementResult {
        do {
            let context = try makeFreshContext(container)
            context.autosaveEnabled = false
            guard let evidence = try fetchEvidence(expected.operationIdentity, in: context) else {
                return result(.acceptedOperationEvidenceMissing)
            }
            guard evidence.requestFingerprint == expected.requestFingerprint,
                  evidence.targetGameIdentity == expected.gameIdentity,
                  evidence.targetAtbatIdentity == expected.atbatIdentity,
                  evidence.submissionFamily == expected.submissionFamily,
                  evidence.disposition == LegacyScoringOperationEvidenceConstants.acceptedDisposition,
                  evidence.completionState == LegacyScoringOperationEvidenceConstants.completedState,
                  evidence.acceptedResultClassification == expected.acceptedResultClassification,
                  evidence.acceptedOutcomeReference == expected.acceptedOutcomeReference else {
                return result(.operationIdentityOrFingerprintConflict)
            }
            guard let game = try fetchGame(expected.gameIdentity, in: context) else {
                return result(.targetGameMissing)
            }
            guard let atbat = try fetchAtbat(expected.atbatIdentity, in: context) else {
                return result(.targetAtbatMissing)
            }
            guard atbat.game.ident == game.ident,
                  atbat.game.ident == evidence.targetGameIdentity,
                  atbat.ident == evidence.targetAtbatIdentity else {
                return result(.operationIdentityOrFingerprintConflict)
            }
            guard AgreementGameSnapshot(game) == expected.gameSnapshot,
                  AgreementAtbatSnapshot(atbat) == expected.atbatSnapshot else {
                return result(.persistedFactsDisagree)
            }
            guard let battingTeam = [game.vteam, game.hteam].compactMap({ $0 }).first(where: { $0.ident == atbat.team.ident }) else {
                return result(.unsupportedComparison)
            }
            let prepared = LiveScoringWorkflowCoordinator().prepareLiveGameState(
                game: game,
                battingTeam: battingTeam,
                displayedAtbats: game.atbats.filter { $0.team.ident == battingTeam.ident },
                pitchers: game.pitchers
            )
            guard AgreementPreparedSnapshot(prepared) == expected.preparedSnapshot else {
                return result(.persistedFactsDisagree)
            }
            return result(.agreementConfirmed)
        } catch {
            return result(.reloadFailure)
        }
    }

    private func result(_ classification: LegacyPersistenceAgreementClassification) -> LegacyPersistenceAgreementResult {
        LegacyPersistenceAgreementResult(
            classification: classification,
            comparedFacts: [
                .gameIdentity,
                .targetAtbatIdentity,
                .scoringResult,
                .inningAndHalfInning,
                .outs,
                .runsAndScore,
                .runnerOrBaseState,
                .battingOrderAndCurrentBatter,
                .currentBatter,
                .pitcherAttribution,
                .rbi,
                .earnedRunClassification,
                .stolenBaseOrSacrificeFacts,
                .fielderPlayFacts,
                .completionOrProgressionState,
                .operationEvidenceIdentityAndOutcome,
                .result
            ],
            lookupPerformedWrites: false
        )
    }
}

private struct AgreementGameSnapshot: Equatable {
    let identity: UUID
    let homeScore: Int
    let visitingScore: Int
    let everyOneHits: Bool
    let numInnings: Int
    let visitingTeamIdentity: UUID?
    let homeTeamIdentity: UUID?
    let atbatIdentities: [UUID]
    let lineupIdentities: [UUID]
    let pitcherIdentities: [UUID]

    init(_ game: Game) {
        identity = game.ident
        homeScore = game.hscore
        visitingScore = game.vscore
        everyOneHits = game.everyOneHits
        numInnings = game.numInnings
        visitingTeamIdentity = game.vteam?.ident
        homeTeamIdentity = game.hteam?.ident
        atbatIdentities = game.atbats.map(\.ident).sorted { $0.uuidString < $1.uuidString }
        lineupIdentities = game.lineups.map(\.ident).sorted { $0.uuidString < $1.uuidString }
        pitcherIdentities = game.pitchers.map(\.ident).sorted { $0.uuidString < $1.uuidString }
    }

    func replacing(identity: UUID?) -> AgreementGameSnapshot {
        AgreementGameSnapshot(
            identity: identity ?? self.identity,
            homeScore: homeScore,
            visitingScore: visitingScore,
            everyOneHits: everyOneHits,
            numInnings: numInnings,
            visitingTeamIdentity: visitingTeamIdentity,
            homeTeamIdentity: homeTeamIdentity,
            atbatIdentities: atbatIdentities,
            lineupIdentities: lineupIdentities,
            pitcherIdentities: pitcherIdentities
        )
    }

    private init(
        identity: UUID,
        homeScore: Int,
        visitingScore: Int,
        everyOneHits: Bool,
        numInnings: Int,
        visitingTeamIdentity: UUID?,
        homeTeamIdentity: UUID?,
        atbatIdentities: [UUID],
        lineupIdentities: [UUID],
        pitcherIdentities: [UUID]
    ) {
        self.identity = identity
        self.homeScore = homeScore
        self.visitingScore = visitingScore
        self.everyOneHits = everyOneHits
        self.numInnings = numInnings
        self.visitingTeamIdentity = visitingTeamIdentity
        self.homeTeamIdentity = homeTeamIdentity
        self.atbatIdentities = atbatIdentities
        self.lineupIdentities = lineupIdentities
        self.pitcherIdentities = pitcherIdentities
    }
}

private struct AgreementAtbatSnapshot: Equatable {
    let identity: UUID
    let gameIdentity: UUID
    let teamIdentity: UUID
    let playerIdentity: UUID
    let result: String
    let maxbase: String
    let outAt: String
    let inning: CGFloat
    let sequence: Int
    let column: Int
    let battingOrder: Int
    let outs: Int
    let rbis: Int
    let sacFly: Int
    let sacBunt: Int
    let stolenBases: Int
    let earnedRun: Bool
    let playRecord: String
    let endOfInning: Bool

    init(_ atbat: Atbat) {
        identity = atbat.ident
        gameIdentity = atbat.game.ident
        teamIdentity = atbat.team.ident
        playerIdentity = atbat.player.identifier
        result = atbat.result
        maxbase = atbat.maxbase
        outAt = atbat.outAt
        inning = atbat.inning
        sequence = atbat.seq
        column = atbat.col
        battingOrder = atbat.batOrder
        outs = atbat.outs
        rbis = atbat.rbis
        sacFly = atbat.sacFly
        sacBunt = atbat.sacBunt
        stolenBases = atbat.stolenBases
        earnedRun = atbat.earnedRun
        playRecord = atbat.playRec
        endOfInning = atbat.endOfInning
    }

    func replacing(identity: UUID?) -> AgreementAtbatSnapshot {
        AgreementAtbatSnapshot(
            identity: identity ?? self.identity,
            gameIdentity: gameIdentity,
            teamIdentity: teamIdentity,
            playerIdentity: playerIdentity,
            result: result,
            maxbase: maxbase,
            outAt: outAt,
            inning: inning,
            sequence: sequence,
            column: column,
            battingOrder: battingOrder,
            outs: outs,
            rbis: rbis,
            sacFly: sacFly,
            sacBunt: sacBunt,
            stolenBases: stolenBases,
            earnedRun: earnedRun,
            playRecord: playRecord,
            endOfInning: endOfInning
        )
    }

    private init(
        identity: UUID,
        gameIdentity: UUID,
        teamIdentity: UUID,
        playerIdentity: UUID,
        result: String,
        maxbase: String,
        outAt: String,
        inning: CGFloat,
        sequence: Int,
        column: Int,
        battingOrder: Int,
        outs: Int,
        rbis: Int,
        sacFly: Int,
        sacBunt: Int,
        stolenBases: Int,
        earnedRun: Bool,
        playRecord: String,
        endOfInning: Bool
    ) {
        self.identity = identity
        self.gameIdentity = gameIdentity
        self.teamIdentity = teamIdentity
        self.playerIdentity = playerIdentity
        self.result = result
        self.maxbase = maxbase
        self.outAt = outAt
        self.inning = inning
        self.sequence = sequence
        self.column = column
        self.battingOrder = battingOrder
        self.outs = outs
        self.rbis = rbis
        self.sacFly = sacFly
        self.sacBunt = sacBunt
        self.stolenBases = stolenBases
        self.earnedRun = earnedRun
        self.playRecord = playRecord
        self.endOfInning = endOfInning
    }
}

private struct AgreementPreparedSnapshot: Equatable {
    let disposition: LiveScoringWorkflowCoordinator.PreparedStateDisposition
    let gameIdentity: UUID?
    let battingSide: TeamSideRole
    let halfInning: TeamSideRole
    let inning: Int
    let outs: Int
    let score: LiveScoringWorkflowCoordinator.PreparedScore
    let firstRunner: UUID?
    let secondRunner: UUID?
    let thirdRunner: UUID?
    let currentBatter: UUID?
    let battingOrderPosition: Int?
    let currentPitcher: UUID?
    let latestScoringSequence: Int?
    let currentScorecardColumn: Int?
    let lineupSlots: [Int]

    init(_ state: LiveScoringWorkflowCoordinator.PreparedLiveGameState) {
        disposition = state.disposition
        gameIdentity = state.gameIdentity
        battingSide = state.battingSide
        halfInning = state.halfInning
        inning = state.inning
        outs = state.outs
        score = state.score
        firstRunner = state.bases.first?.player.identity
        secondRunner = state.bases.second?.player.identity
        thirdRunner = state.bases.third?.player.identity
        currentBatter = state.currentBatter?.identity
        battingOrderPosition = state.battingOrderPosition
        currentPitcher = state.currentPitcher?.player.identity
        latestScoringSequence = state.latestScoringSequence
        currentScorecardColumn = state.currentScorecardColumn
        lineupSlots = state.lineup.map(\.slot)
    }
}

private enum LegacyPersistenceAgreementInjectedError: Error {
    case reloadFailed
}

@MainActor
private func fetchEvidence(_ operationIdentity: UUID, in context: ModelContext) throws -> LegacyScoringOperationEvidenceRecord? {
    var descriptor = FetchDescriptor<LegacyScoringOperationEvidenceRecord>(
        predicate: #Predicate { $0.operationIdentity == operationIdentity }
    )
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count <= 1 else { throw LegacyPersistenceAgreementInjectedError.reloadFailed }
    return records.first
}

@MainActor
private func fetchGame(_ identity: UUID, in context: ModelContext) throws -> Game? {
    var descriptor = FetchDescriptor<Game>(
        predicate: #Predicate { $0.ident == identity }
    )
    descriptor.fetchLimit = 2
    let games = try context.fetch(descriptor)
    guard games.count <= 1 else { throw LegacyPersistenceAgreementInjectedError.reloadFailed }
    return games.first
}

@MainActor
private func fetchAtbat(_ identity: UUID, in context: ModelContext) throws -> Atbat? {
    var descriptor = FetchDescriptor<Atbat>(
        predicate: #Predicate { $0.ident == identity }
    )
    descriptor.fetchLimit = 2
    let atbats = try context.fetch(descriptor)
    guard atbats.count <= 1 else { throw LegacyPersistenceAgreementInjectedError.reloadFailed }
    return atbats.first
}

@MainActor
private func fetchRequiredAtbat(_ identity: UUID, in context: ModelContext) throws -> Atbat {
    guard let atbat = try fetchAtbat(identity, in: context) else {
        throw LegacyPersistenceAgreementInjectedError.reloadFailed
    }
    return atbat
}

struct Task719Suite {
    @Test("Task 7.19 Internal Routing is disableable and cannot dual write")
    @MainActor
    func task719InternalRoutingIsDisableableAndCannotDualWrite() throws {
        let store = try Store()
        let fixture = Fixture.insertGame(into: store.context)
        let pitcher = Fixture.insertPitcher(for: fixture, into: store.context)
        try store.context.save()
        let presenter = LiveScoringShellPresentation()

        let operation = UUID()

        // 1. Internal route disabled: ordinary operation uses Legacy production path
        var disabledCoordinator = LiveScoringWorkflowCoordinator()
        disabledCoordinator.launchMode = .production

        let prepared = disabledCoordinator.prepareLiveGameState(game: fixture.game, battingTeam: fixture.visitingTeam, displayedAtbats: fixture.displayedAtbats, pitchers: [pitcher])
        let semantic = disabledCoordinator.semanticScoreState(preparedState: prepared, displayedAtbats: fixture.displayedAtbats)
        let actions = disabledCoordinator.enabledScoringActions(preparedState: prepared, semanticScoreState: semantic, displayedAtbats: fixture.displayedAtbats, supportedLegacyResults: ["Single"])

        let submitResultLegacy = disabledCoordinator.submitScoringAction(
            legacyResult: "Single",
            targetAtbat: fixture.visitingFirst,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Single"],
            save: { try store.context.save() },
            operationIdentity: operation,
            operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter(container: store.container),
            modelContext: store.context
        )

        #expect(submitResultLegacy.disposition == .accepted)
        #expect(fixture.visitingFirst.result == "Single")
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)
        #expect(try store.canonicalScoringRecordCount() == 0)

        // 2. Internal route enabled through the authorized debug/internal gate only
        // 3. No dual writer produces two accepted outcomes (one operation identity cannot be accepted by both routes)
        var enabledCoordinator = LiveScoringWorkflowCoordinator()
        enabledCoordinator.launchMode = .internalRouting

        let internalOperation = UUID()
        let submitResultInternal = enabledCoordinator.submitScoringAction(
            legacyResult: "Double",
            targetAtbat: fixture.visitingSecond,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Double"],
            save: { try store.context.save() },
            operationIdentity: internalOperation,
            operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter(container: store.container),
            modelContext: store.context
        )

        // Internal routing mode does not return .accepted
        #expect(submitResultInternal.disposition == .unsupportedAction)

        // Internal routing preserves pending review or returns the caller signal that prevents success dismissal
        let presentationInternal = presenter.presentSubmissionResult(submitResultInternal, requiresAdditionalChoice: false)
        #expect(presentationInternal.shouldDismissScoringSheet == false)

        // Internal routing mode does not mutate Legacy scoring state
        #expect(fixture.visitingSecond.result != "Double")

        // Internal routing mode does not write Legacy operation evidence (still 1 from the first operation)
        #expect(try store.legacyScoringOperationEvidenceCount() == 1)

        // Internal routing mode writes zero canonical records
        #expect(try store.canonicalScoringRecordCount() == 0)

        // Disabling internal routing restores normal Legacy acceptance
        var restoredCoordinator = LiveScoringWorkflowCoordinator()
        restoredCoordinator.launchMode = .production

        // The same operation identity can be accepted once through Legacy after the non-accepted internal observation
        let submitResultRestored = restoredCoordinator.submitScoringAction(
            legacyResult: "Double",
            targetAtbat: fixture.visitingSecond,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Double"],
            save: { try store.context.save() },
            operationIdentity: internalOperation,
            operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter(container: store.container),
            modelContext: store.context
        )

        #expect(submitResultRestored.disposition == .accepted)
        #expect(fixture.visitingSecond.result == "Double")
        #expect(try store.legacyScoringOperationEvidenceCount() == 2)

        // A subsequent repeat through Legacy is duplicate-prevented
        let duplicateSubmitRestored = restoredCoordinator.submitScoringAction(
            legacyResult: "Double",
            targetAtbat: fixture.visitingSecond,
            game: fixture.game,
            battingTeam: fixture.visitingTeam,
            displayedAtbats: fixture.displayedAtbats,
            pitchers: [pitcher],
            supportedLegacyResults: ["Double"],
            save: { try store.context.save() },
            operationIdentity: internalOperation,
            operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter(container: store.container),
            modelContext: store.context
        )

        #expect(duplicateSubmitRestored.disposition == .duplicatePrevented)
        #expect(try store.legacyScoringOperationEvidenceCount() == 2) // exactly one new record per operation

        // 4. Normal startup does not activate the internal route
        #expect(ScoreKeepLaunchIsolation.mode(arguments: [], commandLineArguments: [], environment: [:]) == .production)

        if let url = store.container.configurations.first?.url {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }
}

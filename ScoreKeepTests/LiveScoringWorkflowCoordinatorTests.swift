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

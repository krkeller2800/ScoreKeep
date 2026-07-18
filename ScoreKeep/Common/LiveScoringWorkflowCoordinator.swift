import Foundation
import SwiftData

@MainActor
struct LiveScoringWorkflowCoordinator {
    enum Disposition: Equatable {
        case success
        case noChange
        case validationFailed
        case persistenceFailed
    }

    struct SelectionResult {
        let disposition: Disposition
        let atbat: Atbat?
        let message: String?
    }

    struct ProjectionResult {
        let disposition: Disposition
        let columnBoxes: [BoxScore]
        let batterBoxes: [BoxScore]
        let totalBoxes: [BoxScore]
        let inningStatus: InnStatus
        let message: String?
    }

    enum SemanticScoreDisposition: Equatable {
        case ready
        case preparedStateUnavailable
        case storedScoreMismatch
    }

    struct SemanticScoreState: Equatable {
        let disposition: SemanticScoreDisposition
        let score: PreparedScore
        let storedScore: PreparedScore
        let battingSide: TeamSideRole
        let inning: Int
        let halfInning: TeamSideRole
        let outs: Int
        let bases: PreparedBaseOccupancy
        let warnings: [String]
        let canPresentScoringLine: Bool
    }

    enum ScoringActionIdentity: Hashable {
        case scorecardCell(column: Int, battingOrder: Int)
        case legacyResult(String)
        case unsupported(String)
    }

    enum EnabledActionDisposition: Equatable {
        case enabled
        case enabledWithWarnings
        case disabledPreparedStateUnavailable
        case disabledPresentationUnavailable
        case disabledValidationRejected
        case disabledUnsupported
    }

    struct EnabledScoringActionState: Equatable {
        let identity: ScoringActionIdentity
        let isEnabled: Bool
        let disposition: EnabledActionDisposition
        let validationDisposition: CanonicalValidationDisposition?
        let unavailableReason: String?
        let warnings: [String]
    }

    struct EnabledScoringActionSet: Equatable {
        let preparedState: PreparedLiveGameState
        let semanticScoreState: SemanticScoreState?
        let actions: [EnabledScoringActionState]
        let warnings: [String]

        func state(for identity: ScoringActionIdentity) -> EnabledScoringActionState? {
            actions.first { $0.identity == identity }
        }
    }

    enum SubmissionDisposition: Equatable {
        case accepted
        case validationRejected
        case unavailablePreparedState
        case disabledAction
        case cancellation
        case persistenceFailed
        case unsupportedAction
        case duplicatePrevented
        case conflict
    }

    struct ScoringSubmissionResult {
        let disposition: SubmissionDisposition
        let atbat: Atbat?
        let actionState: EnabledScoringActionState?
        let message: String?
    }

    enum PreparedStateDisposition: Equatable {
        case ready
        case missingGame
        case missingRequiredTeam
        case missingLineup
        case unavailableBatter
        case unavailablePitcher
        case inconsistentLegacyState
        case unsupportedState
    }

    struct PreparedScore: Equatable {
        let home: Int
        let visiting: Int
    }

    struct PreparedTeamSnapshot: Equatable {
        let identity: UUID
        let name: String
        let side: TeamSideRole
    }

    struct PreparedPlayerSnapshot: Equatable {
        let identity: UUID
        let name: String
        let number: String
        let battingOrder: Int
    }

    struct PreparedLineupEntry: Equatable {
        let slot: Int
        let player: PreparedPlayerSnapshot
        let sourceAtbatIdentity: UUID
        let isReplaced: Bool
        let isIncoming: Bool
    }

    struct PreparedRunner: Equatable {
        let player: PreparedPlayerSnapshot
        let sourceAtbatIdentity: UUID
    }

    struct PreparedBaseOccupancy: Equatable {
        let first: PreparedRunner?
        let second: PreparedRunner?
        let third: PreparedRunner?
    }

    struct PreparedPitcherSnapshot: Equatable {
        let player: PreparedPlayerSnapshot
        let team: PreparedTeamSnapshot
        let appearanceIndex: Int
        let startInning: Int
        let startOuts: Int
        let startBatterSequence: Int
        let endInning: Int
        let endOuts: Int
        let endBatterSequence: Int
    }

    struct PreparedAtbatSnapshot: Equatable {
        let identity: UUID
        let player: PreparedPlayerSnapshot
        let result: String
        let maxBase: String
        let outAt: String
        let inning: CGFloat
        let sequence: Int
        let column: Int
        let battingOrder: Int
        let outs: Int
    }

    struct PreparedSubstitutionSnapshot: Equatable {
        let order: Int
        let outgoing: PreparedPlayerSnapshot
        let incoming: PreparedPlayerSnapshot
    }

    struct PreparedLiveGameState: Equatable {
        let disposition: PreparedStateDisposition
        let gameIdentity: UUID?
        let homeTeam: PreparedTeamSnapshot?
        let visitingTeam: PreparedTeamSnapshot?
        let battingSide: TeamSideRole
        let battingTeam: PreparedTeamSnapshot?
        let defensiveTeam: PreparedTeamSnapshot?
        let configuredInningCount: Int?
        let everyoneHits: Bool?
        let inning: Int
        let halfInning: TeamSideRole
        let outs: Int
        let score: PreparedScore
        let bases: PreparedBaseOccupancy
        let currentBatter: PreparedPlayerSnapshot?
        let battingOrderPosition: Int?
        let currentPitcher: PreparedPitcherSnapshot?
        let latestScoringSequence: Int?
        let currentScorecardColumn: Int
        let currentOrPendingLegacyAtbat: PreparedAtbatSnapshot?
        let lineup: [PreparedLineupEntry]
        let pitcherAppearances: [PreparedPitcherSnapshot]
        let substitutions: [PreparedSubstitutionSnapshot]
        let warnings: [String]
        let canScore: Bool
    }

    typealias SaveAction = () throws -> Void

    private let common = Common()

    private struct LegacyAtbatSubmissionSnapshot {
        let result: String
        let maxbase: String
        let outAt: String
        let rbis: Int
        let outs: Int
        let sacFly: Int
        let sacBunt: Int
        let stolenBases: Int
        let earnedRun: Bool
        let playRec: String
        let endOfInning: Bool
        let gameEndOfInningFlags: [(UUID, Bool)]

        init(_ atbat: Atbat) {
            result = atbat.result
            maxbase = atbat.maxbase
            outAt = atbat.outAt
            rbis = atbat.rbis
            outs = atbat.outs
            sacFly = atbat.sacFly
            sacBunt = atbat.sacBunt
            stolenBases = atbat.stolenBases
            earnedRun = atbat.earnedRun
            playRec = atbat.playRec
            endOfInning = atbat.endOfInning
            gameEndOfInningFlags = atbat.game.atbats.map { ($0.ident, $0.endOfInning) }
        }

        func restore(to atbat: Atbat) {
            atbat.result = result
            atbat.maxbase = maxbase
            atbat.outAt = outAt
            atbat.rbis = rbis
            atbat.outs = outs
            atbat.sacFly = sacFly
            atbat.sacBunt = sacBunt
            atbat.stolenBases = stolenBases
            atbat.earnedRun = earnedRun
            atbat.playRec = playRec
            atbat.endOfInning = endOfInning
            for (identity, endOfInning) in gameEndOfInningFlags {
                atbat.game.atbats.first { $0.ident == identity }?.endOfInning = endOfInning
            }
        }
    }

    func selectAtbat(
        column: Int,
        rowIndex: Int,
        sourceAtbat: Atbat?,
        displayedAtbats: [Atbat],
        game: Game,
        modelContext: ModelContext,
        save: SaveAction
    ) -> SelectionResult {
        guard column > 0 else {
            return SelectionResult(disposition: .validationFailed, atbat: nil, message: "Scorecard column is unavailable.")
        }

        let battingOrder = rowIndex + 1
        guard battingOrder > 0, let sourceAtbat else {
            return SelectionResult(disposition: .validationFailed, atbat: nil, message: "Batter selection is unavailable.")
        }

        if let existingIndex = displayedAtbats.firstIndex(where: {
            $0.game == sourceAtbat.game &&
            $0.team == sourceAtbat.team &&
            $0.batOrder == battingOrder &&
            $0.col == column
        }) {
            return SelectionResult(disposition: .noChange, atbat: displayedAtbats[existingIndex], message: nil)
        }

        let newAtbat = Atbat(
            game: sourceAtbat.game,
            team: sourceAtbat.team,
            player: sourceAtbat.player,
            result: "Result",
            maxbase: "No Bases",
            batOrder: battingOrder,
            outAt: "Safe",
            inning: 99,
            seq: 99,
            col: column,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )

        modelContext.insert(newAtbat)
        game.atbats.append(newAtbat)

        do {
            try save()
            return SelectionResult(disposition: .success, atbat: newAtbat, message: nil)
        } catch {
            return SelectionResult(disposition: .persistenceFailed, atbat: newAtbat, message: "Error saving new atbats: \(error)")
        }
    }

    func refreshProjections(
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        game: Game,
        save: SaveAction
    ) -> ProjectionResult {
        var columnBoxes = Array(repeating: BoxScore(), count: 20)
        var batterBoxes = Array(repeating: BoxScore(), count: 20)
        var totalBoxes = Array(repeating: BoxScore(), count: 5)

        let sequenceDisposition = sequenceGame(
            displayedAtbats: displayedAtbats,
            columnBoxes: &columnBoxes,
            batterBoxes: &batterBoxes,
            totalBoxes: &totalBoxes,
            save: save
        )

        guard sequenceDisposition.disposition != .persistenceFailed else {
            return ProjectionResult(
                disposition: .persistenceFailed,
                columnBoxes: columnBoxes,
                batterBoxes: batterBoxes,
                totalBoxes: totalBoxes,
                inningStatus: InnStatus(),
                message: sequenceDisposition.message
            )
        }

        let inningStatus = updateMaxBases(displayedAtbats: displayedAtbats)
        let pitcherDisposition = updatePitcherMarkers(displayedAtbats: displayedAtbats, pitchers: pitchers, game: game, save: save)

        guard pitcherDisposition.disposition != .persistenceFailed else {
            return ProjectionResult(
                disposition: .persistenceFailed,
                columnBoxes: columnBoxes,
                batterBoxes: batterBoxes,
                totalBoxes: totalBoxes,
                inningStatus: inningStatus,
                message: pitcherDisposition.message
            )
        }

        return ProjectionResult(
            disposition: .success,
            columnBoxes: columnBoxes,
            batterBoxes: batterBoxes,
            totalBoxes: totalBoxes,
            inningStatus: inningStatus,
            message: nil
        )
    }

    func prepareLiveGameState(
        game: Game?,
        battingTeam: Team?,
        displayedAtbats: [Atbat],
        pitchers: [Pitcher]
    ) -> PreparedLiveGameState {
        guard let game else {
            return unavailablePreparedState(.missingGame, warnings: ["preparedLiveGameState.missingGame"])
        }

        guard let homeTeam = game.hteam, let visitingTeam = game.vteam else {
            return unavailablePreparedState(
                .missingRequiredTeam,
                game: game,
                warnings: ["preparedLiveGameState.missingRequiredTeam"]
            )
        }

        guard let battingTeam else {
            return unavailablePreparedState(
                .missingRequiredTeam,
                game: game,
                homeTeam: homeTeam,
                visitingTeam: visitingTeam,
                warnings: ["preparedLiveGameState.missingBattingTeam"]
            )
        }

        let battingSide: TeamSideRole
        let defensiveTeam: Team
        if sameModel(battingTeam, homeTeam) {
            battingSide = .home
            defensiveTeam = visitingTeam
        } else if sameModel(battingTeam, visitingTeam) {
            battingSide = .visiting
            defensiveTeam = homeTeam
        } else {
            return unavailablePreparedState(
                .missingRequiredTeam,
                game: game,
                homeTeam: homeTeam,
                visitingTeam: visitingTeam,
                warnings: ["preparedLiveGameState.battingTeamNotInGame"]
            )
        }

        let score = PreparedScore(home: game.hscore, visiting: game.vscore)
        guard score.home >= 0, score.visiting >= 0 else {
            return unavailablePreparedState(
                .inconsistentLegacyState,
                game: game,
                homeTeam: homeTeam,
                visitingTeam: visitingTeam,
                battingTeam: battingTeam,
                battingSide: battingSide,
                defensiveTeam: defensiveTeam,
                warnings: ["preparedLiveGameState.negativeStoredScore"]
            )
        }

        let gameAtbats = displayedAtbats
            .filter { sameModel($0.game, game) && sameModel($0.team, battingTeam) }
            .sorted(by: atbatPrecedes)
        guard gameAtbats.count == displayedAtbats.count else {
            return unavailablePreparedState(
                .inconsistentLegacyState,
                game: game,
                homeTeam: homeTeam,
                visitingTeam: visitingTeam,
                battingTeam: battingTeam,
                battingSide: battingSide,
                defensiveTeam: defensiveTeam,
                warnings: ["preparedLiveGameState.unrelatedAtbatExcluded"]
            )
        }

        let lineup = preparedLineup(from: gameAtbats, game: game)
        guard lineup.isEmpty == false else {
            return unavailablePreparedState(
                .missingLineup,
                game: game,
                homeTeam: homeTeam,
                visitingTeam: visitingTeam,
                battingTeam: battingTeam,
                battingSide: battingSide,
                defensiveTeam: defensiveTeam,
                warnings: ["preparedLiveGameState.missingLineup"]
            )
        }

        let completedAtbats = gameAtbats
            .filter { $0.result != "Result" }
            .sorted(by: atbatPrecedes)
        guard completedAtbats.allSatisfy({ (0...3).contains($0.outs) }) else {
            return unavailablePreparedState(
                .inconsistentLegacyState,
                game: game,
                homeTeam: homeTeam,
                visitingTeam: visitingTeam,
                battingTeam: battingTeam,
                battingSide: battingSide,
                defensiveTeam: defensiveTeam,
                warnings: ["preparedLiveGameState.invalidOutCount"]
            )
        }

        let baseState = preparedBaseOccupancy(from: completedAtbats)
        let lastCompleted = completedAtbats.last
        let inning = max(1, Int((lastCompleted?.inning ?? 1).rounded(.up)))
        let outs = lastCompleted?.outs ?? 0
        let currentColumn = preparedCurrentColumn(after: lastCompleted, lineupCount: lineup.count)
        let currentBatterEntry = preparedCurrentBatter(after: lastCompleted, lineup: lineup)
        let preparedPitchers = preparedPitcherAppearances(from: pitchers, game: game, defensiveTeam: defensiveTeam)
        let currentPitcher = preparedPitchers.last
        let pendingAtbat = preparedPendingAtbat(
            in: gameAtbats,
            currentBatter: currentBatterEntry?.player,
            currentColumn: currentColumn
        )
        var warnings: [String] = []

        if currentBatterEntry == nil {
            warnings.append("preparedLiveGameState.unavailableBatter")
        }
        if currentPitcher == nil {
            warnings.append("preparedLiveGameState.unavailablePitcher")
        }
        if pitchers.contains(where: { !sameModel($0.game, game) }) {
            warnings.append("preparedLiveGameState.unrelatedPitcherExcluded")
        }
        if hasAmbiguousPitcherOrdering(preparedPitchers) {
            warnings.append("preparedLiveGameState.ambiguousPitcherOrdering")
        }

        let disposition: PreparedStateDisposition
        if currentBatterEntry == nil {
            disposition = .unavailableBatter
        } else if currentPitcher == nil {
            disposition = .unavailablePitcher
        } else {
            disposition = .ready
        }

        return PreparedLiveGameState(
            disposition: disposition,
            gameIdentity: game.ident,
            homeTeam: preparedTeam(homeTeam, side: .home),
            visitingTeam: preparedTeam(visitingTeam, side: .visiting),
            battingSide: battingSide,
            battingTeam: preparedTeam(battingTeam, side: battingSide),
            defensiveTeam: preparedTeam(defensiveTeam, side: battingSide == .home ? .visiting : .home),
            configuredInningCount: game.numInnings,
            everyoneHits: game.everyOneHits,
            inning: inning,
            halfInning: battingSide,
            outs: outs,
            score: score,
            bases: baseState,
            currentBatter: currentBatterEntry?.player,
            battingOrderPosition: currentBatterEntry?.slot,
            currentPitcher: currentPitcher,
            latestScoringSequence: lastCompleted?.seq,
            currentScorecardColumn: currentColumn,
            currentOrPendingLegacyAtbat: pendingAtbat,
            lineup: lineup,
            pitcherAppearances: preparedPitchers,
            substitutions: preparedSubstitutions(in: game),
            warnings: warnings.sorted(),
            canScore: disposition == .ready
        )
    }

    func semanticScoreState(
        preparedState: PreparedLiveGameState,
        displayedAtbats: [Atbat]
    ) -> SemanticScoreState {
        guard preparedState.disposition == .ready else {
            return SemanticScoreState(
                disposition: .preparedStateUnavailable,
                score: preparedState.score,
                storedScore: preparedState.score,
                battingSide: preparedState.battingSide,
                inning: preparedState.inning,
                halfInning: preparedState.halfInning,
                outs: preparedState.outs,
                bases: preparedState.bases,
                warnings: (preparedState.warnings + ["semanticScoreState.preparedStateUnavailable"]).sorted(),
                canPresentScoringLine: false
            )
        }

        let scoredRunners = displayedAtbats
            .filter { $0.result != "Result" && $0.maxbase == "Home" }
            .map(runnerIdentity)
        let storedScore = CanonicalProjectedScore(
            home: preparedState.score.home,
            visiting: preparedState.score.visiting
        )
        let inputScore: CanonicalProjectedScore

        switch preparedState.battingSide {
        case .home:
            inputScore = CanonicalProjectedScore(home: 0, visiting: preparedState.score.visiting)
        case .visiting:
            inputScore = CanonicalProjectedScore(home: preparedState.score.home, visiting: 0)
        case .unresolved:
            inputScore = storedScore
        }

        let calculated = CanonicalScoreCalculation.calculate(.init(
            inputScore: inputScore,
            battingSide: preparedState.battingSide,
            scoredRunners: scoredRunners,
            storedScoreEvidence: storedScore
        ))
        let score = PreparedScore(home: calculated.resultingScore.home, visiting: calculated.resultingScore.visiting)
        let scoreMatchesStored = calculated.storedScoreMatchesProjection ?? false

        return SemanticScoreState(
            disposition: scoreMatchesStored ? .ready : .storedScoreMismatch,
            score: score,
            storedScore: preparedState.score,
            battingSide: preparedState.battingSide,
            inning: preparedState.inning,
            halfInning: preparedState.halfInning,
            outs: preparedState.outs,
            bases: preparedState.bases,
            warnings: semanticScoreWarnings(
                preparedState: preparedState,
                calculated: calculated,
                scoreMatchesStored: scoreMatchesStored
            ),
            canPresentScoringLine: true
        )
    }

    func enabledScoringActions(
        preparedState: PreparedLiveGameState,
        semanticScoreState: SemanticScoreState?,
        displayedAtbats: [Atbat],
        supportedLegacyResults: [String]
    ) -> EnabledScoringActionSet {
        let resultActions = supportedLegacyResults
            .filter { $0.isEmpty == false }
            .map {
                enabledState(
                    for: .legacyResult($0),
                    command: command(forLegacyResult: $0, preparedState: preparedState),
                    preparedState: preparedState,
                    semanticScoreState: semanticScoreState
                )
            }

        let cellActions = preparedState.lineup.map {
            enabledScorecardCell(
                column: preparedState.currentScorecardColumn,
                lineupEntry: $0,
                preparedState: preparedState,
                semanticScoreState: semanticScoreState
            )
        }

        return EnabledScoringActionSet(
            preparedState: preparedState,
            semanticScoreState: semanticScoreState,
            actions: (cellActions + resultActions).sorted(by: enabledActionPrecedes),
            warnings: ((semanticScoreState?.warnings ?? []) + preparedState.warnings).sorted()
        )
    }

    func submitScoringAction(
        legacyResult: String,
        targetAtbat: Atbat?,
        game: Game,
        battingTeam: Team?,
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        supportedLegacyResults: [String],
        save: SaveAction
    ) -> ScoringSubmissionResult {
        guard legacyResult != "Result" else {
            return ScoringSubmissionResult(
                disposition: .cancellation,
                atbat: targetAtbat,
                actionState: nil,
                message: "No scoring action was submitted."
            )
        }

        guard supportedLegacyResults.contains(legacyResult) else {
            return ScoringSubmissionResult(
                disposition: .unsupportedAction,
                atbat: targetAtbat,
                actionState: nil,
                message: "This scoring choice is not supported for the current game state."
            )
        }

        guard let targetAtbat else {
            return ScoringSubmissionResult(
                disposition: .unavailablePreparedState,
                atbat: nil,
                actionState: nil,
                message: "An at-bat is required before scoring."
            )
        }

        let preparedState = prepareLiveGameState(
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: pitchers
        )
        guard preparedState.canScore else {
            return ScoringSubmissionResult(
                disposition: .unavailablePreparedState,
                atbat: targetAtbat,
                actionState: nil,
                message: unavailableReason(forPreparedState: preparedState)
            )
        }

        let semanticState = semanticScoreState(preparedState: preparedState, displayedAtbats: displayedAtbats)
        let actionSet = enabledScoringActions(
            preparedState: preparedState,
            semanticScoreState: semanticState,
            displayedAtbats: displayedAtbats,
            supportedLegacyResults: supportedLegacyResults
        )
        guard let actionState = actionSet.state(for: .legacyResult(legacyResult)) else {
            return ScoringSubmissionResult(
                disposition: .unsupportedAction,
                atbat: targetAtbat,
                actionState: nil,
                message: "This scoring choice is not supported for the current game state."
            )
        }
        guard actionState.isEnabled else {
            let disposition: SubmissionDisposition
            switch actionState.disposition {
            case .disabledUnsupported:
                disposition = .unsupportedAction
            case .disabledValidationRejected:
                disposition = .validationRejected
            default:
                disposition = .disabledAction
            }
            return ScoringSubmissionResult(
                disposition: disposition,
                atbat: targetAtbat,
                actionState: actionState,
                message: actionState.unavailableReason
            )
        }

        guard targetAtbat.result != legacyResult else {
            return ScoringSubmissionResult(
                disposition: .duplicatePrevented,
                atbat: targetAtbat,
                actionState: actionState,
                message: nil
            )
        }

        guard preparedState.currentOrPendingLegacyAtbat?.identity == targetAtbat.ident else {
            return ScoringSubmissionResult(
                disposition: .conflict,
                atbat: targetAtbat,
                actionState: actionState,
                message: "The scoring state changed before this action could be submitted."
            )
        }

        let previous = LegacyAtbatSubmissionSnapshot(targetAtbat)
        targetAtbat.result = legacyResult
        applyOrdinaryResultDefaults(to: targetAtbat)
        markEndOfInning(for: targetAtbat)

        do {
            try save()
            return ScoringSubmissionResult(
                disposition: .accepted,
                atbat: targetAtbat,
                actionState: actionState,
                message: nil
            )
        } catch {
            previous.restore(to: targetAtbat)
            return ScoringSubmissionResult(
                disposition: .persistenceFailed,
                atbat: targetAtbat,
                actionState: actionState,
                message: "Error saving scoring action: \(error)"
            )
        }
    }

    private func sequenceGame(
        displayedAtbats: [Atbat],
        columnBoxes: inout [BoxScore],
        batterBoxes: inout [BoxScore],
        totalBoxes: inout [BoxScore],
        save: SaveAction
    ) -> (disposition: Disposition, message: String?) {
        var allOuts = 0
        var outs = 0
        var sequence = 1
        var inning = 1
        var column = 1
        var endOfInning = false

        let atbatsSoFar = displayedAtbats.sorted { ($0.col, $0.seq) < ($1.col, $1.seq) }

        for atbat in atbatsSoFar {
            if atbat.result != "Result" {
                if outs == 3 && endOfInning {
                    outs = 0
                    inning += 1
                    column += 1
                    sequence = 1
                }

                let numOfHitters = atbatsSoFar.filter { $0.col == 1 }.count
                if sequence == numOfHitters + 1 || sequence == 2 * numOfHitters + 1 {
                    column += 1
                }

                atbat.col = atbat.col == 1 && atbat.result == "Pitch Hitter" ? 1 : column
                if common.outresults.contains(atbat.result) || atbat.outAt != "Safe" {
                    outs += 1
                    allOuts += 1
                }
                atbat.inning = CGFloat(allOuts) / 3.0
                if (CGFloat(inning) > atbat.inning && (atbat.col != 1 && atbat.result != "Pitch Hitter")) ||
                    (atbat.col == 1 && atbat.inning == 0 && common.onresults.contains(atbat.result)) {
                    atbat.inning += 0.1
                }
                atbat.outs = outs
                atbat.seq = atbat.col == 1 && atbat.result == "Pitch Hitter" ? atbat.batOrder : sequence
                sequence += 1
                endOfInning = atbat.endOfInning

                if atbat.maxbase == "Home" {
                    columnBoxes[column].runs += 1
                    batterBoxes[atbat.batOrder].runs += 1
                    totalBoxes[0].runs += 1
                }
                if atbat.result == "Home Run" {
                    columnBoxes[column].HR += 1
                    batterBoxes[atbat.batOrder].HR += 1
                    totalBoxes[0].HR += 1
                }
                if common.hitresults.contains(atbat.result) {
                    columnBoxes[column].hits += 1
                    batterBoxes[atbat.batOrder].hits += 1
                    totalBoxes[0].hits += 1
                }
                if atbat.result == "Walk" {
                    columnBoxes[column].walks += 1
                    batterBoxes[atbat.batOrder].walks += 1
                    totalBoxes[0].walks += 1
                }
                if atbat.result == "Strikeout" || atbat.result == "Strikeout Looking" || atbat.result == "Dropped 3rd Strike" {
                    columnBoxes[column].strikeouts += 1
                    batterBoxes[atbat.batOrder].strikeouts += 1
                    totalBoxes[0].strikeouts += 1
                }
                if common.onresults.contains(atbat.result) && atbat.stolenBases > 0 {
                    columnBoxes[column].stoleBase += atbat.stolenBases
                    batterBoxes[atbat.batOrder].stoleBase += atbat.stolenBases
                    totalBoxes[0].stoleBase += atbat.stolenBases
                }
                columnBoxes[column].inning = inning
            }

            do {
                try save()
            } catch {
                return (.persistenceFailed, "Error saving seq atbats: \(error)")
            }
        }

        return (.success, nil)
    }

    private func updateMaxBases(displayedAtbats: [Atbat]) -> InnStatus {
        let usedAtbats = displayedAtbats.filter { $0.result != "Result" }
        let inning = usedAtbats.last?.inning.rounded(.up) ?? 0
        let atbatsToUpdate = usedAtbats.filter {
            ($0.inning.rounded(.up) == inning || ($0.inning.rounded(.up) == 0 && inning == 1)) &&
            common.onresults.contains($0.result)
        }
        var currentMaxBase = 0
        let maxbases = ["First", "Second", "Third", "Home"]
        let maxHits = ["Single", "Double", "Triple", "Home Run"]
        let sortedAtbats = atbatsToUpdate.sorted { ($0.col, $0.seq) < ($1.col, $1.seq) }
        var inningStatus = InnStatus(outs: usedAtbats.last?.outs ?? 0)

        for (index, atbat) in sortedAtbats.reversed().enumerated() {
            let maxBaseIndex = maxbases.firstIndex(of: atbat.maxbase) ?? -1
            var maxHitIndex = maxHits.firstIndex(of: atbat.result) ?? -1
            maxHitIndex = (atbat.result == "Walk") ? 0 :
                (atbat.result == "Dropped 3rd Strike") ? 0 :
                (atbat.result == "Hit By Pitch") ? 0 :
                (atbat.result == "Catcher Interference") ? 0 : maxHitIndex

            if atbat.maxbase == "No Bases" || maxHitIndex > maxBaseIndex {
                atbat.maxbase = (atbat.result == "Dropped 3rd Strike") ? "First" :
                    (atbat.result == "Walk") ? "First" :
                    (atbat.result == "Error") ? "First" :
                    (atbat.result == "Fielder's Choice") ? "First" :
                    (atbat.result == "Catcher Interference") ? "First" :
                    (atbat.result == "Hit By Pitch") ? "First" :
                    (atbat.result == "Single") ? "First" :
                    (atbat.result == "Double") ? "Second" :
                    (atbat.result == "Triple") ? "Third" :
                    (atbat.result == "Home Run") ? "Home" : atbat.result
            }

            if index == 0 {
                currentMaxBase = maxbases.firstIndex(of: atbat.maxbase) ?? -1
            }

            if currentMaxBase >= maxbases.firstIndex(of: atbat.maxbase) ?? -1 && index != 0 && currentMaxBase != 3 && atbat.outAt == "Safe" {
                atbat.maxbase = maxbases[currentMaxBase + 1]
                currentMaxBase += 1
            } else if currentMaxBase >= 3 && atbat.outAt == "Safe" {
                atbat.maxbase = maxbases[3]
            } else if index != 0 && atbat.outAt == "Safe" {
                currentMaxBase = maxbases.firstIndex(of: atbat.maxbase) ?? -1
            }

            if atbat.outAt == "Safe" {
                if atbat.maxbase == "Third" {
                    inningStatus.onThird = true
                } else if atbat.maxbase == "Second" {
                    inningStatus.onSecond = true
                } else if atbat.maxbase == "First" {
                    inningStatus.onFirst = true
                }
            }
        }

        return inningStatus
    }

    private func updatePitcherMarkers(
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        game: Game,
        save: SaveAction
    ) -> (disposition: Disposition, message: String?) {
        let firstTeam = displayedAtbats.first?.team
        let otherTeamHitting = displayedAtbats.sorted { ($0.col, $0.seq) < ($1.col, $1.seq) }
        let currentBatter = otherTeamHitting.last(where: { $0.result != "Result" })
        let opposingPitchers = pitchers.filter { $0.team != firstTeam }

        guard !opposingPitchers.isEmpty else { return (.noChange, nil) }

        let currentPitcher = opposingPitchers[opposingPitchers.count - 1]

        if opposingPitchers.count == 1 {
            if currentPitcher.startInn == 0 && currentPitcher.sOuts == 0 && currentPitcher.sBats == 0 {
                currentPitcher.startInn = 1
                currentPitcher.sOuts = 0
                currentPitcher.sBats = 0
                currentPitcher.endInn = 1
                currentPitcher.eOuts = 0
                currentPitcher.eBats = 0

                do {
                    try save()
                } catch {
                    return (.persistenceFailed, "Error saving pitcher markers: \(error)")
                }
            }
        } else {
            let previousPitcher = opposingPitchers[opposingPitchers.count - 2]

            if currentPitcher.startInn == 0 && currentPitcher.sOuts == 0 && currentPitcher.sBats == 0 {
                var startInn = previousPitcher.endInn
                var startOuts = previousPitcher.eOuts
                var startBats = previousPitcher.eBats

                if startInn == 0 {
                    if let currentBatter {
                        if currentBatter.outs == 3 {
                            startInn = Int(currentBatter.inning.rounded(.up)) + 1
                            startOuts = 0
                            startBats = 0
                        } else {
                            startInn = Int(currentBatter.inning.rounded(.up))
                            startOuts = currentBatter.outs
                            startBats = currentBatter.seq
                        }
                    } else {
                        startInn = 1
                        startOuts = 0
                        startBats = 0
                    }
                }

                if previousPitcher.endInn == 0 {
                    previousPitcher.endInn = startInn
                    previousPitcher.eOuts = startOuts
                    previousPitcher.eBats = startBats
                }

                currentPitcher.startInn = previousPitcher.endInn
                currentPitcher.sOuts = previousPitcher.eOuts
                currentPitcher.sBats = previousPitcher.eBats
                currentPitcher.endInn = currentPitcher.startInn
                currentPitcher.eOuts = currentPitcher.sOuts
                currentPitcher.eBats = currentPitcher.sBats

                do {
                    try save()
                    return (.success, nil)
                } catch {
                    return (.persistenceFailed, "Error saving pitcher markers: \(error)")
                }
            }
        }

        if let currentBatter {
            if currentBatter.outs == 3 {
                currentPitcher.endInn = Int(currentBatter.inning.rounded(.up)) + 1
                currentPitcher.eOuts = 0
                currentPitcher.eBats = 0
            } else {
                currentPitcher.endInn = Int(currentBatter.inning.rounded(.up))
                currentPitcher.eOuts = currentBatter.outs
                currentPitcher.eBats = currentBatter.seq
            }
        }

        if opposingPitchers.count >= 2 {
            let previousPitcher = opposingPitchers[opposingPitchers.count - 2]
            if previousPitcher.endInn == 0 {
                previousPitcher.endInn = currentPitcher.startInn
                previousPitcher.eOuts = currentPitcher.sOuts
                previousPitcher.eBats = currentPitcher.sBats
            }
        }

        do {
            try save()
            return (.success, nil)
        } catch {
            return (.persistenceFailed, "Error saving pitcher markers: \(error)")
        }
    }

    private func semanticScoreWarnings(
        preparedState: PreparedLiveGameState,
        calculated: CanonicalScoreCalculationResult,
        scoreMatchesStored: Bool
    ) -> [String] {
        var warnings = preparedState.warnings
        if scoreMatchesStored == false {
            warnings.append("semanticScoreState.storedScoreMismatch")
        }
        warnings.append(contentsOf: calculated.validation.findings.map(\.code))
        return warnings.sorted()
    }

    private func enabledScorecardCell(
        column: Int,
        lineupEntry: PreparedLineupEntry,
        preparedState: PreparedLiveGameState,
        semanticScoreState: SemanticScoreState?
    ) -> EnabledScoringActionState {
        let identity = ScoringActionIdentity.scorecardCell(column: column, battingOrder: lineupEntry.slot)
        guard column > 0 else {
            return disabledAction(identity, disposition: .disabledPresentationUnavailable, reason: "Scorecard column is unavailable.")
        }
        guard preparedState.canScore else {
            return disabledAction(identity, disposition: .disabledPreparedStateUnavailable, reason: unavailableReason(forPreparedState: preparedState))
        }
        guard semanticScoreState?.canPresentScoringLine ?? false else {
            return disabledAction(identity, disposition: .disabledPresentationUnavailable, reason: "Scoring state is not ready for this at-bat.")
        }

        return EnabledScoringActionState(
            identity: identity,
            isEnabled: true,
            disposition: .enabled,
            validationDisposition: nil,
            unavailableReason: nil,
            warnings: []
        )
    }

    private func enabledState(
        for identity: ScoringActionIdentity,
        command: CanonicalScoringCommand?,
        preparedState: PreparedLiveGameState,
        semanticScoreState: SemanticScoreState?
    ) -> EnabledScoringActionState {
        guard preparedState.canScore else {
            return disabledAction(identity, disposition: .disabledPreparedStateUnavailable, reason: unavailableReason(forPreparedState: preparedState))
        }
        guard semanticScoreState?.canPresentScoringLine ?? false else {
            return disabledAction(identity, disposition: .disabledPresentationUnavailable, reason: "Scoring state is not ready for this action.")
        }
        guard let command else {
            return disabledAction(identity, disposition: .disabledUnsupported, reason: "This scoring choice is not supported for the current game state.")
        }

        let input = scoringCommandInputState(from: preparedState)
        let validation = CanonicalScoringCommandValidator.validate(command, against: input, sourceLocation: "Task 7.3 enabled action state")
        guard validation.mayApplyInMemory else {
            return EnabledScoringActionState(
                identity: identity,
                isEnabled: false,
                disposition: validation.result.disposition == .unsupported ? .disabledUnsupported : .disabledValidationRejected,
                validationDisposition: validation.result.disposition,
                unavailableReason: unavailableReason(for: validation),
                warnings: validation.result.findings.map(\.code).sorted()
            )
        }

        return EnabledScoringActionState(
            identity: identity,
            isEnabled: true,
            disposition: validation.result.disposition == .validWithWarnings ? .enabledWithWarnings : .enabled,
            validationDisposition: validation.result.disposition,
            unavailableReason: nil,
            warnings: validation.result.findings.map(\.code).sorted()
        )
    }

    private func scoringCommandInputState(from preparedState: PreparedLiveGameState) -> CanonicalScoringCommandInputState {
        CanonicalScoringCommandInputState(
            game: canonicalGame(from: preparedState),
            battingSide: preparedState.battingSide,
            inning: CanonicalHalfInning(
                number: .known(preparedState.inning),
                half: .known(preparedState.halfInning == .home ? .bottom : .top),
                expectedInnings: expectedInnings(from: preparedState.configuredInningCount),
                source: .currentGameRecord
            ),
            outs: CanonicalOutsState(outs: .known(preparedState.outs), source: .currentGameRecord),
            baseOccupancy: canonicalBaseOccupancy(from: preparedState.bases),
            count: .unsupportedRepositoryEvidence,
            score: CanonicalProjectedScore(home: preparedState.score.home, visiting: preparedState.score.visiting),
            currentBatter: preparedState.currentBatter.map { lineupParticipant(from: $0, gameIdentity: preparedState.gameIdentity, side: preparedState.battingSide) },
            lineupParticipants: preparedState.lineup.map { lineupParticipant(from: $0.player, gameIdentity: preparedState.gameIdentity, side: preparedState.battingSide) },
            pitcherResponsibility: preparedState.currentPitcher.map { pitcherResponsibility(from: $0, gameIdentity: preparedState.gameIdentity) }
        )
    }

    private func command(forLegacyResult rawResult: String, preparedState: PreparedLiveGameState) -> CanonicalScoringCommand? {
        guard let gameIdentity = preparedState.gameIdentity else { return nil }
        return CanonicalScoringCommandVocabulary.command(
            rawResult: rawResult,
            gameIdentity: .valid(gameIdentity),
            teamSide: preparedState.battingSide,
            batter: preparedState.currentBatter.map { lineupParticipant(from: $0, gameIdentity: preparedState.gameIdentity, side: preparedState.battingSide) },
            proposedEventIdentity: preparedState.currentOrPendingLegacyAtbat.map { .valid($0.identity) } ?? .missing,
            source: .scoringView
        )
    }

    private func canonicalGame(from preparedState: PreparedLiveGameState) -> CanonicalGameIdentity {
        CanonicalGameIdentity(
            identity: preparedState.gameIdentity.map { .valid($0) } ?? .missing,
            displayEvidence: GameDisplayEvidence(
                homeTeamName: preparedState.homeTeam?.name,
                visitingTeamName: preparedState.visitingTeam?.name,
                storedHomeScore: preparedState.score.home,
                storedVisitingScore: preparedState.score.visiting
            ),
            configuration: gameConfiguration(from: preparedState),
            origin: .unknown,
            lifecycle: preparedState.canScore ? .inProgress : .incomplete,
            source: .currentGameRecord
        )
    }

    private func gameConfiguration(from preparedState: PreparedLiveGameState) -> GameConfigurationEvidence {
        guard let configuredInningCount = preparedState.configuredInningCount,
              let everyoneHits = preparedState.everyoneHits else {
            return .missing
        }
        return .configured(
            expectedInnings: expectedInnings(from: configuredInningCount),
            lineupMode: everyoneHits ? .everyoneHits : .traditional
        )
    }

    private func expectedInnings(from configuredInningCount: Int?) -> ExpectedInningCountEvidence {
        guard let configuredInningCount else { return .missing }
        return configuredInningCount <= 0 ? .invalid(configuredInningCount) : .known(configuredInningCount)
    }

    private func canonicalBaseOccupancy(from bases: PreparedBaseOccupancy) -> CanonicalBaseOccupancy {
        var runnerStates: [RunnerStateEvidence] = []
        if let first = bases.first { runnerStates.append(.activeOccupant(base: .first, runner: runnerIdentity(from: first))) }
        if let second = bases.second { runnerStates.append(.activeOccupant(base: .second, runner: runnerIdentity(from: second))) }
        if let third = bases.third { runnerStates.append(.activeOccupant(base: .third, runner: runnerIdentity(from: third))) }
        return CanonicalBaseOccupancy(runnerStates: runnerStates, source: .currentGameRecord)
    }

    private func lineupParticipant(from player: PreparedPlayerSnapshot, gameIdentity: UUID?, side: TeamSideRole) -> LineupParticipantEvidence {
        let reusablePlayer = ReusableCanonicalPlayer(
            identity: .valid(player.identity),
            display: playerDisplay(from: player),
            source: .historicalGameParticipation
        )
        return .gameParticipant(GamePlayerParticipation(
            participantIdentity: .valid(player.identity),
            gameIdentity: gameIdentity.map { .valid($0) } ?? .missing,
            playerResolution: .reusablePlayer(reusablePlayer),
            teamEvidence: .gameSide(GameSideTeamParticipation(
                gameIdentity: gameIdentity.map { .valid($0) } ?? .missing,
                role: side,
                resolution: .unknown(TeamDisplayEvidence())
            )),
            historicalDisplay: playerDisplay(from: player),
            roles: [.batter],
            source: .historicalGameParticipation
        ))
    }

    private func runnerIdentity(from runner: PreparedRunner) -> RunnerIdentityEvidence {
        .knownHistoricalParticipant(.valid(runner.player.identity), playerDisplay(from: runner.player))
    }

    private func pitcherResponsibility(from pitcher: PreparedPitcherSnapshot, gameIdentity: UUID?) -> CanonicalPitcherResponsibilityEvidence {
        let appearance = CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: .valid(pitcher.player.identity),
            reusablePitcherIdentity: .valid(pitcher.player.identity),
            gameIdentity: gameIdentity.map { .valid($0) } ?? .missing,
            teamSide: pitcher.team.side,
            appearanceOrder: .init(kind: .pitcherAppearance, value: pitcher.appearanceIndex),
            roleEvidence: [.activePitcher],
            historicalDisplayEvidence: playerDisplay(from: pitcher.player),
            source: .currentPitcherRecord
        )
        return CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .missing,
            gameIdentity: gameIdentity.map { .valid($0) } ?? .missing,
            teamSide: pitcher.team.side,
            responsibility: .explicitPitcher(appearance),
            source: .currentPitcherRecord
        )
    }

    private func playerDisplay(from player: PreparedPlayerSnapshot) -> PlayerDisplayEvidence {
        PlayerDisplayEvidence(
            name: .present(player.name),
            jerseyNumber: .present(player.number)
        )
    }

    private func disabledAction(
        _ identity: ScoringActionIdentity,
        disposition: EnabledActionDisposition,
        reason: String
    ) -> EnabledScoringActionState {
        EnabledScoringActionState(
            identity: identity,
            isEnabled: false,
            disposition: disposition,
            validationDisposition: nil,
            unavailableReason: reason,
            warnings: []
        )
    }

    private func applyOrdinaryResultDefaults(to atbat: Atbat) {
        if atbat.result == "Dropped 3rd Strike" || atbat.result == "Error" {
            atbat.earnedRun = false
        }
        if !common.recOuts.contains(atbat.result) || atbat.outAt != "Safe" {
            atbat.playRec = ""
        }
    }

    private func markEndOfInning(for selectedAtbat: Atbat) {
        var inning = 0
        var outs = 0
        let completedAtbats = selectedAtbat.game.atbats
            .filter { $0.team == selectedAtbat.team && $0.result != "Result" }
            .sorted { ($0.col, $0.seq) < ($1.col, $1.seq) }

        for atbat in completedAtbats {
            atbat.endOfInning = false
            inning += outs % 3 == 0 ? 1 : 0
            if common.outresults.contains(atbat.result) || atbat.outAt != "Safe" {
                outs += 1
            }
        }

        let innings = outs / 3
        let out = outs % 3
        guard innings > 0 else { return }

        for inning in 1...innings {
            if inning <= innings || out == 0 {
                let inningAtbats = selectedAtbat.game.atbats
                    .filter {
                        $0.team == selectedAtbat.team &&
                        $0.result != "Result" &&
                        $0.result != "Pitch Hitter" &&
                        ($0.inning >= CGFloat(inning - 1) && $0.inning <= CGFloat(inning))
                    }
                    .sorted { ($0.col, $0.seq) < ($1.col, $1.seq) }
                inningAtbats.last?.endOfInning = true
            }
        }
        selectedAtbat.sacFly = selectedAtbat.sacFly != 0 ? 0 : -1
    }

    private func unavailableReason(forPreparedState preparedState: PreparedLiveGameState) -> String {
        switch preparedState.disposition {
        case .ready:
            return "This scoring action is unavailable."
        case .missingGame:
            return "A game is required before scoring."
        case .missingRequiredTeam:
            return "Both teams are required before scoring."
        case .missingLineup:
            return "A batting lineup is required before scoring."
        case .unavailableBatter:
            return "A current batter is required before scoring."
        case .unavailablePitcher:
            return "A current pitcher is required before scoring."
        case .inconsistentLegacyState:
            return "The current game state must be reviewed before scoring."
        case .unsupportedState:
            return "This game state is not supported for scoring."
        }
    }

    private func unavailableReason(for validation: CanonicalScoringCommandValidation) -> String {
        let sortedFindings = validation.result.findings.sorted(by: { $0.code < $1.code })
        if let finding = sortedFindings.first(where: { $0.disposition != .validWithWarnings }) ?? sortedFindings.first {
            return finding.summary
        }
        return "This scoring choice is not available for the current game state."
    }

    private func enabledActionPrecedes(_ lhs: EnabledScoringActionState, _ rhs: EnabledScoringActionState) -> Bool {
        enabledActionSortKey(lhs.identity) < enabledActionSortKey(rhs.identity)
    }

    private func enabledActionSortKey(_ identity: ScoringActionIdentity) -> String {
        switch identity {
        case let .scorecardCell(column, battingOrder):
            return "0-\(column)-\(battingOrder)"
        case let .legacyResult(result):
            return "1-\(result)"
        case let .unsupported(result):
            return "2-\(result)"
        }
    }

    private func runnerIdentity(from atbat: Atbat) -> RunnerIdentityEvidence {
        .knownHistoricalParticipant(
            .valid(atbat.player.identifier),
            PlayerDisplayEvidence(
                name: .present(atbat.player.name),
                jerseyNumber: .present(atbat.player.number),
                position: .present(atbat.player.position),
                battingDirection: .present(atbat.player.batDir)
            )
        )
    }

    private func unavailablePreparedState(
        _ disposition: PreparedStateDisposition,
        game: Game? = nil,
        homeTeam: Team? = nil,
        visitingTeam: Team? = nil,
        battingTeam: Team? = nil,
        battingSide: TeamSideRole = .unresolved,
        defensiveTeam: Team? = nil,
        warnings: [String]
    ) -> PreparedLiveGameState {
        PreparedLiveGameState(
            disposition: disposition,
            gameIdentity: game?.ident,
            homeTeam: homeTeam.map { preparedTeam($0, side: .home) },
            visitingTeam: visitingTeam.map { preparedTeam($0, side: .visiting) },
            battingSide: battingSide,
            battingTeam: battingTeam.map { preparedTeam($0, side: battingSide) },
            defensiveTeam: defensiveTeam.map { preparedTeam($0, side: battingSide == .home ? .visiting : .home) },
            configuredInningCount: game?.numInnings,
            everyoneHits: game?.everyOneHits,
            inning: 1,
            halfInning: battingSide,
            outs: 0,
            score: PreparedScore(home: max(0, game?.hscore ?? 0), visiting: max(0, game?.vscore ?? 0)),
            bases: PreparedBaseOccupancy(first: nil, second: nil, third: nil),
            currentBatter: nil,
            battingOrderPosition: nil,
            currentPitcher: nil,
            latestScoringSequence: nil,
            currentScorecardColumn: 1,
            currentOrPendingLegacyAtbat: nil,
            lineup: [],
            pitcherAppearances: [],
            substitutions: game.map(preparedSubstitutions(in:)) ?? [],
            warnings: warnings.sorted(),
            canScore: false
        )
    }

    private func preparedLineup(from atbats: [Atbat], game: Game) -> [PreparedLineupEntry] {
        atbats
            .filter { $0.col == 1 && $0.batOrder != 99 }
            .sorted {
                ($0.batOrder, $0.seq, $0.player.identifier.uuidString, $0.ident.uuidString) <
                ($1.batOrder, $1.seq, $1.player.identifier.uuidString, $1.ident.uuidString)
            }
            .map {
                PreparedLineupEntry(
                    slot: $0.batOrder,
                    player: preparedPlayer($0.player),
                    sourceAtbatIdentity: $0.ident,
                    isReplaced: containsModel($0.player, in: game.replaced),
                    isIncoming: containsModel($0.player, in: game.incomings)
                )
            }
    }

    private func preparedCurrentBatter(
        after lastCompleted: Atbat?,
        lineup: [PreparedLineupEntry]
    ) -> PreparedLineupEntry? {
        guard lineup.isEmpty == false else { return nil }
        guard let lastCompleted else { return lineup.first }

        if let next = lineup.first(where: { $0.slot > lastCompleted.batOrder }) {
            return next
        }
        return lineup.first
    }

    private func preparedCurrentColumn(after lastCompleted: Atbat?, lineupCount: Int) -> Int {
        guard let lastCompleted else { return 1 }
        guard lineupCount > 0 else { return max(1, lastCompleted.col) }
        return lastCompleted.batOrder >= lineupCount ? lastCompleted.col + 1 : max(1, lastCompleted.col)
    }

    private func preparedPendingAtbat(
        in atbats: [Atbat],
        currentBatter: PreparedPlayerSnapshot?,
        currentColumn: Int
    ) -> PreparedAtbatSnapshot? {
        guard let currentBatter else { return nil }
        return atbats
            .filter {
                $0.result == "Result" &&
                $0.col == currentColumn &&
                $0.player.identifier == currentBatter.identity
            }
            .sorted(by: atbatPrecedes)
            .first
            .map(preparedAtbat)
    }

    private func preparedBaseOccupancy(from completedAtbats: [Atbat]) -> PreparedBaseOccupancy {
        let usedAtbats = completedAtbats.filter { $0.result != "Result" }
        let inning = usedAtbats.last?.inning.rounded(.up) ?? 0
        let inningAtbats = usedAtbats
            .filter {
                ($0.inning.rounded(.up) == inning || ($0.inning.rounded(.up) == 0 && inning == 1)) &&
                common.onresults.contains($0.result)
            }
            .sorted(by: atbatPrecedes)

        var currentMaxBase = 0
        var first: PreparedRunner?
        var second: PreparedRunner?
        var third: PreparedRunner?
        let maxbases = ["First", "Second", "Third", "Home"]
        let maxHits = ["Single", "Double", "Triple", "Home Run"]

        for (index, atbat) in inningAtbats.reversed().enumerated() {
            let maxBase = projectedMaxBase(
                for: atbat,
                index: index,
                currentMaxBase: &currentMaxBase,
                maxbases: maxbases,
                maxHits: maxHits
            )

            guard atbat.outAt == "Safe" else { continue }
            let runner = PreparedRunner(player: preparedPlayer(atbat.player), sourceAtbatIdentity: atbat.ident)
            if maxBase == "Third" {
                third = runner
            } else if maxBase == "Second" {
                second = runner
            } else if maxBase == "First" {
                first = runner
            }
        }

        return PreparedBaseOccupancy(first: first, second: second, third: third)
    }

    private func projectedMaxBase(
        for atbat: Atbat,
        index: Int,
        currentMaxBase: inout Int,
        maxbases: [String],
        maxHits: [String]
    ) -> String {
        let maxBaseIndex = maxbases.firstIndex(of: atbat.maxbase) ?? -1
        let maxHitIndex = projectedHitIndex(for: atbat.result, maxHits: maxHits)
        var projected = atbat.maxbase

        if atbat.maxbase == "No Bases" || maxHitIndex > maxBaseIndex {
            projected = projectedBase(for: atbat.result)
        }

        if index == 0 {
            currentMaxBase = maxbases.firstIndex(of: projected) ?? -1
        }

        if currentMaxBase >= (maxbases.firstIndex(of: projected) ?? -1) && index != 0 && currentMaxBase != 3 && atbat.outAt == "Safe" {
            projected = maxbases[currentMaxBase + 1]
            currentMaxBase += 1
        } else if currentMaxBase >= 3 && atbat.outAt == "Safe" {
            projected = maxbases[3]
        } else if index != 0 && atbat.outAt == "Safe" {
            currentMaxBase = maxbases.firstIndex(of: projected) ?? -1
        }

        return projected
    }

    private func projectedHitIndex(for result: String, maxHits: [String]) -> Int {
        switch result {
        case "Walk", "Dropped 3rd Strike", "Hit By Pitch", "Catcher Interference":
            return 0
        default:
            return maxHits.firstIndex(of: result) ?? -1
        }
    }

    private func projectedBase(for result: String) -> String {
        switch result {
        case "Dropped 3rd Strike", "Walk", "Error", "Fielder's Choice", "Catcher Interference", "Hit By Pitch", "Single":
            return "First"
        case "Double":
            return "Second"
        case "Triple":
            return "Third"
        case "Home Run":
            return "Home"
        default:
            return result
        }
    }

    private func preparedPitcherAppearances(
        from pitchers: [Pitcher],
        game: Game,
        defensiveTeam: Team
    ) -> [PreparedPitcherSnapshot] {
        pitchers
            .filter { sameModel($0.game, game) && sameModel($0.team, defensiveTeam) }
            .sorted(by: pitcherPrecedes)
            .enumerated()
            .map { index, pitcher in
                PreparedPitcherSnapshot(
                    player: preparedPlayer(pitcher.player),
                    team: preparedTeam(pitcher.team, side: sameModel(pitcher.team, game.hteam) ? .home : .visiting),
                    appearanceIndex: index + 1,
                    startInning: pitcher.startInn,
                    startOuts: pitcher.sOuts,
                    startBatterSequence: pitcher.sBats,
                    endInning: pitcher.endInn,
                    endOuts: pitcher.eOuts,
                    endBatterSequence: pitcher.eBats
                )
            }
    }

    private func hasAmbiguousPitcherOrdering(_ pitchers: [PreparedPitcherSnapshot]) -> Bool {
        guard pitchers.count > 1 else { return false }
        var seen: Set<String> = []
        for pitcher in pitchers {
            let marker = "\(pitcher.startInning)-\(pitcher.startOuts)-\(pitcher.startBatterSequence)-\(pitcher.endInning)-\(pitcher.endOuts)-\(pitcher.endBatterSequence)"
            if seen.contains(marker) {
                return true
            }
            seen.insert(marker)
        }
        return false
    }

    private func preparedSubstitutions(in game: Game) -> [PreparedSubstitutionSnapshot] {
        zip(game.replaced, game.incomings)
            .enumerated()
            .map { index, pair in
                PreparedSubstitutionSnapshot(
                    order: index + 1,
                    outgoing: preparedPlayer(pair.0),
                    incoming: preparedPlayer(pair.1)
                )
            }
    }

    private func preparedAtbat(_ atbat: Atbat) -> PreparedAtbatSnapshot {
        PreparedAtbatSnapshot(
            identity: atbat.ident,
            player: preparedPlayer(atbat.player),
            result: atbat.result,
            maxBase: atbat.maxbase,
            outAt: atbat.outAt,
            inning: atbat.inning,
            sequence: atbat.seq,
            column: atbat.col,
            battingOrder: atbat.batOrder,
            outs: atbat.outs
        )
    }

    private func preparedTeam(_ team: Team, side: TeamSideRole) -> PreparedTeamSnapshot {
        PreparedTeamSnapshot(identity: team.ident, name: team.name, side: side)
    }

    private func preparedPlayer(_ player: Player) -> PreparedPlayerSnapshot {
        PreparedPlayerSnapshot(
            identity: player.identifier,
            name: player.name,
            number: player.number,
            battingOrder: player.batOrder
        )
    }

    private func sameModel(_ lhs: Game, _ rhs: Game) -> Bool {
        lhs.ident == rhs.ident
    }

    private func sameModel(_ lhs: Team, _ rhs: Team?) -> Bool {
        lhs.ident == rhs?.ident
    }

    private func sameModel(_ lhs: Team, _ rhs: Team) -> Bool {
        lhs.ident == rhs.ident
    }

    private func containsModel(_ player: Player, in players: [Player]) -> Bool {
        players.contains { $0.identifier == player.identifier }
    }

    private func atbatPrecedes(_ lhs: Atbat, _ rhs: Atbat) -> Bool {
        (
            lhs.col,
            lhs.seq,
            lhs.batOrder,
            lhs.player.identifier.uuidString,
            lhs.ident.uuidString
        ) <
        (
            rhs.col,
            rhs.seq,
            rhs.batOrder,
            rhs.player.identifier.uuidString,
            rhs.ident.uuidString
        )
    }

    private func pitcherPrecedes(_ lhs: Pitcher, _ rhs: Pitcher) -> Bool {
        let leftValues = [
            lhs.startInn,
            lhs.sOuts,
            lhs.sBats,
            lhs.endInn,
            lhs.eOuts,
            lhs.eBats
        ]
        let rightValues = [
            rhs.startInn,
            rhs.sOuts,
            rhs.sBats,
            rhs.endInn,
            rhs.eOuts,
            rhs.eBats
        ]

        if leftValues != rightValues {
            return leftValues.lexicographicallyPrecedes(rightValues)
        }

        if lhs.player.identifier != rhs.player.identifier {
            return lhs.player.identifier.uuidString < rhs.player.identifier.uuidString
        }

        return lhs.ident.uuidString < rhs.ident.uuidString
    }
}

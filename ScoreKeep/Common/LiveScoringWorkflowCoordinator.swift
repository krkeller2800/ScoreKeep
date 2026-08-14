import Foundation
import SwiftData

@MainActor
struct LiveScoringWorkflowCoordinator {
    var launchMode: ScoreKeepLaunchMode = ScoreKeepLaunchIsolation.mode()

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
        let targetAction: ScoringActionIdentity?
        let targetCell: ScorecardCellTarget?
        let renderedTarget: RenderedScorecardCellTarget?

        init(
            disposition: Disposition,
            atbat: Atbat?,
            message: String?,
            targetAction: ScoringActionIdentity?,
            targetCell: ScorecardCellTarget? = nil,
            renderedTarget: RenderedScorecardCellTarget? = nil
        ) {
            self.disposition = disposition
            self.atbat = atbat
            self.message = message
            self.targetAction = targetAction
            self.targetCell = targetCell
            self.renderedTarget = renderedTarget
        }
    }

    struct ScorecardCellTarget: Hashable {
        let atbatIdentity: UUID
        let playerIdentity: UUID
        let column: Int
        let battingOrder: Int
        let sequence: Int

        var uiIdentifier: String {
            Self.uiIdentifier(atbatIdentity: atbatIdentity, column: column)
        }

        static func uiIdentifier(atbatIdentity: UUID, column: Int) -> String {
            "scorecard_cell_\(atbatIdentity.uuidString)_\(column)"
        }
    }

    struct RenderedScorecardCellTarget: Hashable {
        let renderedRowIdentity: UUID
        let column: Int

        var uiIdentifier: String {
            Self.uiIdentifier(renderedRowIdentity: renderedRowIdentity, column: column)
        }

        static func uiIdentifier(renderedRowIdentity: UUID, column: Int) -> String {
            "scorecard_rendered_cell_\(renderedRowIdentity.uuidString)_\(column)"
        }
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
        let operationIdentity: UUID?
        let operationEvidenceResult: LegacyScoringOperationEvidenceTransactionResult?

        init(
            disposition: SubmissionDisposition,
            atbat: Atbat?,
            actionState: EnabledScoringActionState?,
            message: String?,
            operationIdentity: UUID? = nil,
            operationEvidenceResult: LegacyScoringOperationEvidenceTransactionResult? = nil
        ) {
            self.disposition = disposition
            self.atbat = atbat
            self.actionState = actionState
            self.message = message
            self.operationIdentity = operationIdentity
            self.operationEvidenceResult = operationEvidenceResult
        }
    }

    enum CorrectionDisposition: Equatable {
        case accepted
        case canceled
        case validationRejected
        case targetMissing
        case targetStale
        case wrongGameTarget
        case unsupportedCorrection
        case persistenceFailed
        case recalculationFailed
        case refreshedStateUnavailable
    }

    struct LegacyCorrectionTarget: Equatable {
        let gameIdentity: UUID
        let atbatIdentity: UUID
        let expectedOriginal: LegacyCorrectionSnapshot?

        init(gameIdentity: UUID, atbatIdentity: UUID, expectedOriginal: LegacyCorrectionSnapshot? = nil) {
            self.gameIdentity = gameIdentity
            self.atbatIdentity = atbatIdentity
            self.expectedOriginal = expectedOriginal
        }
    }

    struct LegacyCorrectionSnapshot: Equatable {
        let gameIdentity: UUID
        let atbatIdentity: UUID
        let teamIdentity: UUID
        let playerIdentity: UUID
        let result: String
        let maxBase: String
        let outAt: String
        let inning: CGFloat
        let sequence: Int
        let column: Int
        let battingOrder: Int
        let rbis: Int
        let outs: Int
        let sacrificeFly: Int
        let sacrificeBunt: Int
        let stolenBases: Int
        let earnedRun: Bool
        let playRecord: String
        let endOfInning: Bool

        init(_ atbat: Atbat) {
            gameIdentity = atbat.game.ident
            atbatIdentity = atbat.ident
            teamIdentity = atbat.team.ident
            playerIdentity = atbat.player.identifier
            result = atbat.result
            maxBase = atbat.maxbase
            outAt = atbat.outAt
            inning = atbat.inning
            sequence = atbat.seq
            column = atbat.col
            battingOrder = atbat.batOrder
            rbis = atbat.rbis
            outs = atbat.outs
            sacrificeFly = atbat.sacFly
            sacrificeBunt = atbat.sacBunt
            stolenBases = atbat.stolenBases
            earnedRun = atbat.earnedRun
            playRecord = atbat.playRec
            endOfInning = atbat.endOfInning
        }
    }

    struct LegacyCorrectionReplacement: Equatable {
        let result: String
        let maxBase: String
        let outAt: String
        let rbis: Int
        let stolenBases: Int
        let earnedRun: Bool
        let playRecord: String

        init(
            result: String,
            maxBase: String,
            outAt: String,
            rbis: Int,
            stolenBases: Int,
            earnedRun: Bool,
            playRecord: String = ""
        ) {
            self.result = result
            self.maxBase = maxBase
            self.outAt = outAt
            self.rbis = rbis
            self.stolenBases = stolenBases
            self.earnedRun = earnedRun
            self.playRecord = playRecord
        }
    }

    struct CorrectionSubmissionResult {
        let disposition: CorrectionDisposition
        let targetAtbatIdentity: UUID?
        let refreshedState: PreparedLiveGameState?
        let projectionResult: ProjectionResult?
        let correctionPlan: CanonicalCorrectionPlan?
        let applicationResult: CanonicalCorrectionApplicationResult?
        let message: String?
    }

    enum SubstitutionFamily: Equatable {
        case batterReplacement
        case pitcherChange
    }

    enum SubstitutionDisposition: Equatable {
        case accepted
        case canceled
        case validationRejected
        case gameMissing
        case participantMissing
        case wrongTeamOrGame
        case staleState
        case sameParticipant
        case duplicateOrConflicting
        case unsupportedFamily
        case persistenceFailed
        case projectionFailed
        case refreshedStateUnavailable
    }

    struct SubstitutionSubmissionResult {
        let disposition: SubstitutionDisposition
        let refreshedState: PreparedLiveGameState?
        let message: String?
    }

    enum AdditionalChoiceDisposition: Equatable {
        case pending
        case noAdditionalChoiceRequired
        case validationRejected
        case unavailablePreparedState
        case disabledAction
        case unsupportedAction
        case conflict
    }

    struct AdditionalScoringChoices: Equatable {
        let legacyResult: String
        let maxBase: String
        let outAt: String
        let rbis: Int
        let stolenBases: Int
        let earnedRun: Bool
        let playRecord: String
    }

    struct PendingAdditionalScoringChoice: Equatable {
        let operationIdentity: UUID
        let originalScoringAction: ScoringActionIdentity
        let requiredChoiceCategory: String
        let gameIdentity: UUID
        let atbatIdentity: UUID
        let legacyResult: String
        let choices: AdditionalScoringChoices
        let availableMaxBases: [String]
        let availableOutAtBases: [String]
        let availableRBIs: [Int]
        let availableStolenBases: [Int]
        let allowsEarnedRunChoice: Bool
        let allowsPlayRecordChoice: Bool
        let validationWarnings: [String]
    }

    struct AdditionalChoicePreparationResult {
        let disposition: AdditionalChoiceDisposition
        let pendingChoice: PendingAdditionalScoringChoice?
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
    private let availableBaseChoices = ["No Bases", "First", "Second", "Third", "Home"]
    private let availableOutAtChoices = ["Safe", "First", "Second", "Third", "Home"]
    private let availableRBIChoices = [0, 1, 2, 3, 4]
    private let availableStolenBaseChoices = [0, 1, 2, 3]

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

    private struct LegacyCorrectionAtbatState {
        let identity: UUID
        let result: String
        let maxbase: String
        let outAt: String
        let inning: CGFloat
        let sequence: Int
        let column: Int
        let rbis: Int
        let outs: Int
        let sacFly: Int
        let sacBunt: Int
        let stolenBases: Int
        let earnedRun: Bool
        let playRec: String
        let endOfInning: Bool

        init(_ atbat: Atbat) {
            identity = atbat.ident
            result = atbat.result
            maxbase = atbat.maxbase
            outAt = atbat.outAt
            inning = atbat.inning
            sequence = atbat.seq
            column = atbat.col
            rbis = atbat.rbis
            outs = atbat.outs
            sacFly = atbat.sacFly
            sacBunt = atbat.sacBunt
            stolenBases = atbat.stolenBases
            earnedRun = atbat.earnedRun
            playRec = atbat.playRec
            endOfInning = atbat.endOfInning
        }

        func restore(in game: Game) {
            guard let atbat = game.atbats.first(where: { $0.ident == identity }) else { return }
            atbat.result = result
            atbat.maxbase = maxbase
            atbat.outAt = outAt
            atbat.inning = inning
            atbat.seq = sequence
            atbat.col = column
            atbat.rbis = rbis
            atbat.outs = outs
            atbat.sacFly = sacFly
            atbat.sacBunt = sacBunt
            atbat.stolenBases = stolenBases
            atbat.earnedRun = earnedRun
            atbat.playRec = playRec
            atbat.endOfInning = endOfInning
        }
    }

    private struct LegacyCorrectionPitcherState {
        let identity: UUID
        let startInn: Int
        let startOuts: Int
        let startBats: Int
        let endInn: Int
        let endOuts: Int
        let endBats: Int

        init(_ pitcher: Pitcher) {
            identity = pitcher.ident
            startInn = pitcher.startInn
            startOuts = pitcher.sOuts
            startBats = pitcher.sBats
            endInn = pitcher.endInn
            endOuts = pitcher.eOuts
            endBats = pitcher.eBats
        }

        func restore(in game: Game) {
            guard let pitcher = game.pitchers.first(where: { $0.ident == identity }) else { return }
            pitcher.startInn = startInn
            pitcher.sOuts = startOuts
            pitcher.sBats = startBats
            pitcher.endInn = endInn
            pitcher.eOuts = endOuts
            pitcher.eBats = endBats
        }
    }

    private struct LegacyCorrectionRollbackSnapshot {
        let game: Game
        let homeScore: Int
        let visitingScore: Int
        let atbats: [LegacyCorrectionAtbatState]
        let pitchers: [LegacyCorrectionPitcherState]

        init(game: Game) {
            self.game = game
            homeScore = game.hscore
            visitingScore = game.vscore
            atbats = game.atbats.map(LegacyCorrectionAtbatState.init)
            pitchers = game.pitchers.map(LegacyCorrectionPitcherState.init)
        }

        func restore() {
            game.hscore = homeScore
            game.vscore = visitingScore
            atbats.forEach { $0.restore(in: game) }
            pitchers.forEach { $0.restore(in: game) }
        }
    }

    private struct LegacySubstitutionRollbackSnapshot {
        let game: Game
        let replaced: [Player]
        let incomings: [Player]
        let atbats: [LegacyCorrectionAtbatState]
        let pitchers: [LegacyCorrectionPitcherState]
        let playerBatOrders: [(UUID, Int)]
        let atbatBatOrders: [(UUID, Int)]
        let atbatSequences: [(UUID, Int)]
        let playerCounts: Int
        let atbatCounts: Int
        let pitcherCounts: Int

        init(game: Game) {
            self.game = game
            self.replaced = game.replaced
            self.incomings = game.incomings
            self.atbats = game.atbats.map(LegacyCorrectionAtbatState.init)
            self.pitchers = game.pitchers.map(LegacyCorrectionPitcherState.init)
            self.playerBatOrders = game.players.map { ($0.identifier, $0.batOrder) }
            self.atbatBatOrders = game.atbats.map { ($0.ident, $0.batOrder) }
            self.atbatSequences = game.atbats.map { ($0.ident, $0.seq) }
            self.playerCounts = game.players.count
            self.atbatCounts = game.atbats.count
            self.pitcherCounts = game.pitchers.count
        }

        func restore(modelContext: ModelContext) {
            game.replaced = replaced
            game.incomings = incomings

            if game.players.count > playerCounts {
                let addedPlayers = Array(game.players.dropFirst(playerCounts))
                for p in addedPlayers {
                    game.players.removeAll { $0.identifier == p.identifier }
                }
            }

            if game.atbats.count > atbatCounts {
                let addedAtbats = Array(game.atbats.dropFirst(atbatCounts))
                for a in addedAtbats {
                    game.atbats.removeAll { $0.ident == a.ident }
                    modelContext.delete(a)
                }
            }

            if game.pitchers.count > pitcherCounts {
                let addedPitchers = Array(game.pitchers.dropFirst(pitcherCounts))
                for p in addedPitchers {
                    game.pitchers.removeAll { $0.ident == p.ident }
                    modelContext.delete(p)
                }
            }

            for (id, order) in playerBatOrders {
                if let p = game.players.first(where: { $0.identifier == id }) {
                    p.batOrder = order
                }
            }

            for (id, order) in atbatBatOrders {
                if let a = game.atbats.first(where: { $0.ident == id }) {
                    a.batOrder = order
                }
            }

            for (id, seq) in atbatSequences {
                if let a = game.atbats.first(where: { $0.ident == id }) {
                    a.seq = seq
                }
            }

            atbats.forEach { $0.restore(in: game) }
            pitchers.forEach { $0.restore(in: game) }
        }
    }

    private enum LiveScoringOperationEvidenceMutationError: Error {
        case targetAlreadyScored
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
            return SelectionResult(disposition: .validationFailed, atbat: nil, message: "Scorecard column is unavailable.", targetAction: nil, targetCell: nil)
        }

        let battingOrder = sourceAtbat?.batOrder ?? rowIndex + 1
        guard battingOrder > 0, let sourceAtbat else {
            return SelectionResult(disposition: .validationFailed, atbat: nil, message: "Batter selection is unavailable.", targetAction: nil, targetCell: nil)
        }

        if let existingIndex = displayedAtbats.firstIndex(where: {
            $0.game == sourceAtbat.game &&
            $0.team == sourceAtbat.team &&
            $0.player.identifier == sourceAtbat.player.identifier &&
            $0.col == column
        }) {
            let existing = displayedAtbats[existingIndex]
            if existing.result != "Result" && existing.result != "Pitch Hitter" {
                // Completed at-bat. Editable.
                return SelectionResult(disposition: .noChange, atbat: existing, message: nil, targetAction: nil, targetCell: nil)
            }
        }

        let preparedState = prepareLiveGameState(
            game: game,
            battingTeam: sourceAtbat.team,
            displayedAtbats: displayedAtbats,
            pitchers: game.pitchers
        )

        if preparedState.disposition == .unavailablePitcher {
            return SelectionResult(
                disposition: .validationFailed,
                atbat: nil,
                message: "Select the starting pitcher before scoring the game.",
                targetAction: nil,
                targetCell: nil
            )
        }

        if let existingIndex = displayedAtbats.firstIndex(where: {
            $0.game == sourceAtbat.game &&
            $0.team == sourceAtbat.team &&
            $0.player.identifier == sourceAtbat.player.identifier &&
            $0.col == column
        }) {
            let existing = displayedAtbats[existingIndex]
            if let pending = preparedState.currentOrPendingLegacyAtbat {
                if pending.identity != existing.ident || pending.column != column {
                    return invalidNonCurrentSelectionResult(
                        preparedState: preparedState,
                        displayedAtbats: displayedAtbats
                    )
                }
            } else if !isComputedCurrentSelection(
                sourceAtbat: sourceAtbat,
                column: column,
                preparedState: preparedState
            ) {
                return invalidNonCurrentSelectionResult(
                    preparedState: preparedState,
                    displayedAtbats: displayedAtbats
                )
            }
            guard existing.result != "Pitch Hitter" else {
                return invalidNonCurrentSelectionResult(
                    preparedState: preparedState,
                    displayedAtbats: displayedAtbats
                )
            }
            return SelectionResult(disposition: .noChange, atbat: existing, message: nil, targetAction: nil, targetCell: nil)
        }

        if let pending = preparedState.currentOrPendingLegacyAtbat {
            if pending.player.identity != sourceAtbat.player.identifier || pending.column != column {
                return invalidNonCurrentSelectionResult(
                    preparedState: preparedState,
                    displayedAtbats: displayedAtbats
                )
            }
        } else if !isComputedCurrentSelection(
            sourceAtbat: sourceAtbat,
            column: column,
            preparedState: preparedState
        ) {
            return invalidNonCurrentSelectionResult(
                preparedState: preparedState,
                displayedAtbats: displayedAtbats
            )
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
            return SelectionResult(disposition: .success, atbat: newAtbat, message: nil, targetAction: nil, targetCell: nil)
        } catch {
            return SelectionResult(disposition: .persistenceFailed, atbat: newAtbat, message: "Error saving new atbats: \(error)", targetAction: nil, targetCell: nil)
        }
    }

    func refreshProjections(
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        game: Game,
        maintainPitcherMarkers: Bool = true,
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
        let pitcherDisposition: (disposition: Disposition, message: String?)
        if maintainPitcherMarkers {
            pitcherDisposition = updatePitcherMarkers(displayedAtbats: displayedAtbats, pitchers: pitchers, game: game, save: save)
        } else {
            pitcherDisposition = (.noChange, nil)
        }

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

    func shouldMaintainPitcherMarkers(
        preparedState: PreparedLiveGameState,
        afterScoringSubmission: Bool = false
    ) -> Bool {
        afterScoringSubmission ||
        (preparedState.canScore && preparedState.currentOrPendingLegacyAtbat != nil)
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
        let completedScoringAtbats = completedAtbats
            .filter { $0.result != "Pitch Hitter" }
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

        let baseState = preparedBaseOccupancy(from: completedScoringAtbats)
        let lastCompleted = completedScoringAtbats.last
        let completedInning = max(1, Int((lastCompleted?.inning ?? 1).rounded(.up)))
        let completedHalfInningEnded = lastCompleted?.outs == 3 && lastCompleted?.endOfInning == true
        let inning = completedHalfInningEnded ? completedInning + 1 : completedInning
        let outs = completedHalfInningEnded ? 0 : (lastCompleted?.outs ?? 0)
        let currentBatterEntry = preparedCurrentBatter(after: lastCompleted, lineup: lineup)
        let currentColumn = preparedCurrentColumn(
            after: lastCompleted,
            nextBatterSlot: currentBatterEntry?.slot,
            completedAtbats: completedAtbats,
            completedHalfInningEnded: completedHalfInningEnded
        )
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
        save: SaveAction,
        operationIdentity: UUID? = nil,
        operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter? = nil,
        modelContext: ModelContext? = nil
    ) -> ScoringSubmissionResult {
        let validation = validateSubmission(
            legacyResult: legacyResult,
            targetAtbat: targetAtbat,
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: pitchers,
            supportedLegacyResults: supportedLegacyResults
        )
        guard validation.result.disposition == .accepted else {
            return validation.result
        }
        guard let targetAtbat = validation.targetAtbat else {
            return validation.result
        }
        let actionState = validation.result.actionState

        guard launchMode != .internalRouting else {
            return ScoringSubmissionResult(
                disposition: .unsupportedAction,
                atbat: targetAtbat,
                actionState: actionState,
                message: "Internal routing is observation-only and does not mutate Legacy state.",
                operationIdentity: operationIdentity,
                operationEvidenceResult: nil
            )
        }

        if let operationIdentity, let operationEvidenceAdapter, let modelContext {
            let previous = LegacyAtbatSubmissionSnapshot(targetAtbat)
            let request = ordinaryOperationRequest(
                operationIdentity: operationIdentity,
                legacyResult: legacyResult,
                targetAtbat: targetAtbat,
                game: game,
                battingTeam: battingTeam,
                preparedState: validation.preparedState
            )
            let evidenceResult = operationEvidenceAdapter.apply(request, in: modelContext) { _ in
                guard targetAtbat.result == "Result" else {
                    throw LiveScoringOperationEvidenceMutationError.targetAlreadyScored
                }
                targetAtbat.result = legacyResult
                applyOrdinaryResultDefaults(to: targetAtbat)
                markEndOfInning(for: targetAtbat)
            }
            if evidenceResult.transaction.disposition == .saveFailed,
               evidenceResult.lookupResult.classification == .noEvidence {
                previous.restore(to: targetAtbat)
            }
            return scoringSubmissionResult(
                from: evidenceResult,
                atbat: targetAtbat,
                actionState: actionState,
                failureMessage: "Error saving scoring action."
            )
        }

        if operationIdentity != nil || operationEvidenceAdapter != nil || modelContext != nil {
            return ScoringSubmissionResult(
                disposition: .unsupportedAction,
                atbat: targetAtbat,
                actionState: actionState,
                message: "Durable duplicate prevention is unavailable for this scoring action.",
                operationIdentity: operationIdentity
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

    func prepareAdditionalChoiceScoringAction(
        legacyResult: String,
        targetAtbat: Atbat?,
        game: Game,
        battingTeam: Team?,
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        supportedLegacyResults: [String]
    ) -> AdditionalChoicePreparationResult {
        guard requiresAdditionalChoice(for: legacyResult) else {
            return AdditionalChoicePreparationResult(
                disposition: .noAdditionalChoiceRequired,
                pendingChoice: nil,
                actionState: nil,
                message: "This scoring choice does not require additional choices."
            )
        }

        let validation = validateSubmission(
            legacyResult: legacyResult,
            targetAtbat: targetAtbat,
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: pitchers,
            supportedLegacyResults: supportedLegacyResults
        )
        guard validation.result.disposition == .accepted else {
            return AdditionalChoicePreparationResult(
                disposition: additionalChoiceDisposition(for: validation.result.disposition),
                pendingChoice: nil,
                actionState: validation.result.actionState,
                message: validation.result.message
            )
        }
        guard let targetAtbat = validation.targetAtbat,
              validation.preparedState?.gameIdentity == game.ident else {
            return AdditionalChoicePreparationResult(
                disposition: .conflict,
                pendingChoice: nil,
                actionState: validation.result.actionState,
                message: "The scoring state changed before this action could be prepared."
            )
        }

        let choices = defaultAdditionalChoices(for: legacyResult, atbat: targetAtbat)
        return AdditionalChoicePreparationResult(
            disposition: .pending,
            pendingChoice: PendingAdditionalScoringChoice(
                operationIdentity: UUID(),
                originalScoringAction: .legacyResult(legacyResult),
                requiredChoiceCategory: additionalChoiceCategory(for: legacyResult),
                gameIdentity: game.ident,
                atbatIdentity: targetAtbat.ident,
                legacyResult: legacyResult,
                choices: choices,
                availableMaxBases: availableBaseChoices,
                availableOutAtBases: availableOutAtChoices,
                availableRBIs: availableRBIChoices,
                availableStolenBases: availableStolenBaseChoices,
                allowsEarnedRunChoice: common.onresults.contains(legacyResult),
                allowsPlayRecordChoice: common.recOuts.contains(legacyResult),
                validationWarnings: validation.result.actionState?.warnings ?? []
            ),
            actionState: validation.result.actionState,
            message: nil
        )
    }

    func submitAdditionalChoiceScoringAction(
        pendingChoice: PendingAdditionalScoringChoice?,
        choices: AdditionalScoringChoices,
        targetAtbat: Atbat?,
        game: Game,
        battingTeam: Team?,
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        supportedLegacyResults: [String],
        save: SaveAction,
        operationEvidenceAdapter: LegacyScoringOperationEvidenceAdapter? = nil,
        modelContext: ModelContext? = nil
    ) -> ScoringSubmissionResult {
        guard let pendingChoice else {
            return ScoringSubmissionResult(disposition: .cancellation, atbat: targetAtbat, actionState: nil, message: "No additional scoring choice was submitted.")
        }
        guard choices.legacyResult == pendingChoice.legacyResult else {
            return ScoringSubmissionResult(disposition: .conflict, atbat: targetAtbat, actionState: nil, message: "The scoring choice changed before final submission.")
        }
        guard game.ident == pendingChoice.gameIdentity,
              targetAtbat?.ident == pendingChoice.atbatIdentity else {
            return ScoringSubmissionResult(disposition: .conflict, atbat: targetAtbat, actionState: nil, message: "The scoring state changed before final submission.")
        }
        guard additionalChoicesAreSupported(choices) else {
            return ScoringSubmissionResult(disposition: .unsupportedAction, atbat: targetAtbat, actionState: nil, message: "This additional scoring choice is not supported.")
        }

        let validation = validateSubmission(
            legacyResult: pendingChoice.legacyResult,
            targetAtbat: targetAtbat,
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: pitchers,
            supportedLegacyResults: supportedLegacyResults,
            additionalChoices: choices
        )
        guard validation.result.disposition == .accepted else {
            return validation.result
        }
        guard let targetAtbat = validation.targetAtbat else {
            return validation.result
        }
        let actionState = validation.result.actionState

        if let operationEvidenceAdapter, let modelContext {
            let previous = LegacyAtbatSubmissionSnapshot(targetAtbat)
            let request = additionalChoiceOperationRequest(
                operationIdentity: pendingChoice.operationIdentity,
                choices: choices,
                targetAtbat: targetAtbat,
                game: game,
                battingTeam: battingTeam,
                preparedState: validation.preparedState
            )
            let evidenceResult = operationEvidenceAdapter.apply(request, in: modelContext) { _ in
                guard targetAtbat.result == "Result" else {
                    throw LiveScoringOperationEvidenceMutationError.targetAlreadyScored
                }
                targetAtbat.result = choices.legacyResult
                applyOrdinaryResultDefaults(to: targetAtbat)
                targetAtbat.maxbase = choices.maxBase
                targetAtbat.outAt = choices.outAt
                targetAtbat.rbis = choices.rbis
                targetAtbat.stolenBases = choices.stolenBases
                targetAtbat.earnedRun = choices.earnedRun
                targetAtbat.playRec = choices.playRecord
                if !common.recOuts.contains(targetAtbat.result) && targetAtbat.outAt == "Safe" {
                    targetAtbat.playRec = ""
                }
                markEndOfInning(for: targetAtbat)
            }
            if evidenceResult.transaction.disposition == .saveFailed,
               evidenceResult.lookupResult.classification == .noEvidence {
                previous.restore(to: targetAtbat)
            }
            return scoringSubmissionResult(
                from: evidenceResult,
                atbat: targetAtbat,
                actionState: actionState,
                failureMessage: "Error saving scoring action."
            )
        }

        if operationEvidenceAdapter != nil || modelContext != nil {
            return ScoringSubmissionResult(
                disposition: .unsupportedAction,
                atbat: targetAtbat,
                actionState: actionState,
                message: "Durable duplicate prevention is unavailable for this scoring action.",
                operationIdentity: pendingChoice.operationIdentity
            )
        }

        if targetAtbat.result == choices.legacyResult && currentAdditionalChoices(for: targetAtbat, legacyResult: choices.legacyResult) == choices {
            return ScoringSubmissionResult(disposition: .duplicatePrevented, atbat: targetAtbat, actionState: actionState, message: nil)
        }
        guard targetAtbat.result == "Result" else {
            return ScoringSubmissionResult(disposition: .conflict, atbat: targetAtbat, actionState: actionState, message: "The scoring state changed before final submission.")
        }

        let previous = LegacyAtbatSubmissionSnapshot(targetAtbat)
        targetAtbat.result = choices.legacyResult
        applyOrdinaryResultDefaults(to: targetAtbat)
        targetAtbat.maxbase = choices.maxBase
        targetAtbat.outAt = choices.outAt
        targetAtbat.rbis = choices.rbis
        targetAtbat.stolenBases = choices.stolenBases
        targetAtbat.earnedRun = choices.earnedRun
        targetAtbat.playRec = choices.playRecord
        if !common.recOuts.contains(targetAtbat.result) && targetAtbat.outAt == "Safe" {
            targetAtbat.playRec = ""
        }
        markEndOfInning(for: targetAtbat)

        do {
            try save()
            return ScoringSubmissionResult(disposition: .accepted, atbat: targetAtbat, actionState: actionState, message: nil)
        } catch {
            previous.restore(to: targetAtbat)
            return ScoringSubmissionResult(disposition: .persistenceFailed, atbat: targetAtbat, actionState: actionState, message: "Error saving scoring action: \(error)")
        }
    }

    func submitCorrection(
        target: LegacyCorrectionTarget,
        replacement: LegacyCorrectionReplacement?,
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        modelContext: ModelContext,
        save: SaveAction
    ) -> CorrectionSubmissionResult {
        guard let replacement else {
            return CorrectionSubmissionResult(
                disposition: .canceled,
                targetAtbatIdentity: target.atbatIdentity,
                refreshedState: nil,
                projectionResult: nil,
                correctionPlan: nil,
                applicationResult: nil,
                message: nil
            )
        }
        guard isSupportedCorrectionReplacement(replacement) else {
            return CorrectionSubmissionResult(
                disposition: .unsupportedCorrection,
                targetAtbatIdentity: target.atbatIdentity,
                refreshedState: nil,
                projectionResult: nil,
                correctionPlan: nil,
                applicationResult: nil,
                message: "This correction is not supported by the current Legacy workflow."
            )
        }
        guard let authoritativeGame = fetchGame(identity: target.gameIdentity, in: modelContext),
              let authoritativeAtbat = fetchAtbat(identity: target.atbatIdentity, in: modelContext) else {
            return CorrectionSubmissionResult(
                disposition: .targetMissing,
                targetAtbatIdentity: target.atbatIdentity,
                refreshedState: nil,
                projectionResult: nil,
                correctionPlan: nil,
                applicationResult: nil,
                message: "The correction target is no longer available."
            )
        }
        guard authoritativeAtbat.game.ident == authoritativeGame.ident,
              authoritativeAtbat.game.ident == target.gameIdentity else {
            return CorrectionSubmissionResult(
                disposition: .wrongGameTarget,
                targetAtbatIdentity: authoritativeAtbat.ident,
                refreshedState: nil,
                projectionResult: nil,
                correctionPlan: nil,
                applicationResult: nil,
                message: "The correction target belongs to a different game."
            )
        }
        guard authoritativeGame.atbats.contains(where: { $0.ident == authoritativeAtbat.ident }) else {
            return CorrectionSubmissionResult(
                disposition: .targetMissing,
                targetAtbatIdentity: authoritativeAtbat.ident,
                refreshedState: nil,
                projectionResult: nil,
                correctionPlan: nil,
                applicationResult: nil,
                message: "The correction target is no longer active in this game."
            )
        }
        if let expectedOriginal = target.expectedOriginal,
           expectedOriginal != LegacyCorrectionSnapshot(authoritativeAtbat) {
            return CorrectionSubmissionResult(
                disposition: .targetStale,
                targetAtbatIdentity: authoritativeAtbat.ident,
                refreshedState: nil,
                projectionResult: nil,
                correctionPlan: nil,
                applicationResult: nil,
                message: "The correction target changed before acceptance."
            )
        }
        guard authoritativeAtbat.result != "Result" else {
            return CorrectionSubmissionResult(
                disposition: .unsupportedCorrection,
                targetAtbatIdentity: authoritativeAtbat.ident,
                refreshedState: nil,
                projectionResult: nil,
                correctionPlan: nil,
                applicationResult: nil,
                message: "Placeholder at-bats are not supported correction targets."
            )
        }

        let battingTeam = authoritativeAtbat.team
        let factAtbats = authoritativeGame.atbats
            .filter { $0.result != "Result" }
            .sorted(by: atbatPrecedes)
        let factSet = CanonicalCorrectionFactSet(
            gameIdentity: .valid(authoritativeGame.ident),
            activeEvents: factAtbats.map(canonicalEvent)
        )
        let replacementEvent = canonicalReplacementEvent(from: authoritativeAtbat, replacement: replacement)
        let intent = CanonicalCorrectionIntent(
            targetGameIdentity: .valid(target.gameIdentity),
            targetEventIdentity: .valid(target.atbatIdentity),
            operation: .replaceEvent(replacementEvent),
            expectedOriginalEvent: target.expectedOriginal.map { canonicalEvent(from: $0, teamSide: side(for: authoritativeAtbat.team, in: authoritativeGame)) },
            source: .scoringView
        )
        let plan = CanonicalCorrectionPlanner.plan(intent, in: factSet)
        guard plan.disposition.mayApply else {
            return CorrectionSubmissionResult(
                disposition: correctionDisposition(for: plan),
                targetAtbatIdentity: authoritativeAtbat.ident,
                refreshedState: nil,
                projectionResult: nil,
                correctionPlan: plan,
                applicationResult: nil,
                message: plan.findings.first?.summary
            )
        }
        let application = CanonicalCorrectionApplicator.apply(plan, to: factSet)
        guard application.applied else {
            return CorrectionSubmissionResult(
                disposition: .validationRejected,
                targetAtbatIdentity: authoritativeAtbat.ident,
                refreshedState: nil,
                projectionResult: nil,
                correctionPlan: plan,
                applicationResult: application,
                message: application.findings.first?.summary
            )
        }

        let rollback = LegacyCorrectionRollbackSnapshot(game: authoritativeGame)
        applyCorrection(replacement, to: authoritativeAtbat)
        let projection = recalculateLegacyAfterCorrection(
            displayedAtbats: authoritativeGame.atbats.filter { $0.team.ident == battingTeam.ident },
            pitchers: pitchers.filter { $0.game.ident == authoritativeGame.ident },
            game: authoritativeGame
        )
        guard projection.disposition != .persistenceFailed else {
            rollback.restore()
            return CorrectionSubmissionResult(
                disposition: .recalculationFailed,
                targetAtbatIdentity: authoritativeAtbat.ident,
                refreshedState: nil,
                projectionResult: projection,
                correctionPlan: plan,
                applicationResult: application,
                message: projection.message
            )
        }

        do {
            try save()
        } catch {
            rollback.restore()
            return CorrectionSubmissionResult(
                disposition: .persistenceFailed,
                targetAtbatIdentity: authoritativeAtbat.ident,
                refreshedState: nil,
                projectionResult: projection,
                correctionPlan: plan,
                applicationResult: application,
                message: "Error saving correction: \(error)"
            )
        }

        let refreshed = prepareLiveGameState(
            game: authoritativeGame,
            battingTeam: battingTeam,
            displayedAtbats: authoritativeGame.atbats.filter { $0.team.ident == battingTeam.ident },
            pitchers: pitchers.filter { $0.game.ident == authoritativeGame.ident }
        )
        guard refreshed.disposition == .ready else {
            return CorrectionSubmissionResult(
                disposition: .refreshedStateUnavailable,
                targetAtbatIdentity: authoritativeAtbat.ident,
                refreshedState: refreshed,
                projectionResult: projection,
                correctionPlan: plan,
                applicationResult: application,
                message: refreshed.warnings.first
            )
        }

        return CorrectionSubmissionResult(
            disposition: .accepted,
            targetAtbatIdentity: authoritativeAtbat.ident,
            refreshedState: refreshed,
            projectionResult: projection,
            correctionPlan: plan,
            applicationResult: application,
            message: nil
        )
    }

    func submitSubstitution(
        gameIdentity: UUID,
        outgoingParticipant: UUID,
        incomingParticipant: UUID,
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        modelContext: ModelContext,
        save: SaveAction
    ) -> SubstitutionSubmissionResult {
        guard let authoritativeGame = fetchGame(identity: gameIdentity, in: modelContext) else {
            return SubstitutionSubmissionResult(
                disposition: .gameMissing,
                refreshedState: nil,
                message: "The game is no longer available."
            )
        }

        guard let outgoingPlayer = fetchPlayer(identity: outgoingParticipant, in: modelContext),
              let incomingPlayer = fetchPlayer(identity: incomingParticipant, in: modelContext) else {
            return SubstitutionSubmissionResult(
                disposition: .participantMissing,
                refreshedState: nil,
                message: "Participant could not be found."
            )
        }

        guard outgoingPlayer.team?.ident == incomingPlayer.team?.ident,
              outgoingPlayer.team?.ident == authoritativeGame.hteam?.ident || outgoingPlayer.team?.ident == authoritativeGame.vteam?.ident else {
            return SubstitutionSubmissionResult(
                disposition: .wrongTeamOrGame,
                refreshedState: nil,
                message: "Participants do not belong to a valid team in this game."
            )
        }

        guard outgoingPlayer.identifier != incomingPlayer.identifier else {
            return SubstitutionSubmissionResult(
                disposition: .sameParticipant,
                refreshedState: nil,
                message: "Cannot substitute a player for themselves."
            )
        }

        let team = outgoingPlayer.team!
        let gameAtbats = authoritativeGame.atbats.filter { $0.team.ident == team.ident }

        if authoritativeGame.replaced.contains(where: { $0.identifier == outgoingPlayer.identifier }) &&
           authoritativeGame.incomings.contains(where: { $0.identifier == incomingPlayer.identifier }) {
             return SubstitutionSubmissionResult(
                 disposition: .duplicateOrConflicting,
                 refreshedState: nil,
                 message: "This substitution has already been processed."
             )
        }

        let rollback = LegacySubstitutionRollbackSnapshot(game: authoritativeGame)

        incomingPlayer.batOrder = outgoingPlayer.batOrder + 1
        authoritativeGame.replaced.append(outgoingPlayer)
        authoritativeGame.incomings.append(incomingPlayer)

        let allTeamPlayers = (try? modelContext.fetch(FetchDescriptor<Player>()))?.filter { $0.team?.ident == team.ident } ?? []
        for player in allTeamPlayers {
            if player.batOrder >= incomingPlayer.batOrder && player.identifier != incomingPlayer.identifier && player.identifier != outgoingPlayer.identifier && player.batOrder < 99 {
                player.batOrder += 1
            }
        }

        var newseq = Array(repeating: 999, count: 20)
        for atbat in gameAtbats {
            atbat.batOrder = atbat.player.batOrder
            if atbat.player.identifier == outgoingPlayer.identifier {
                newseq[atbat.col] = atbat.seq + 1
            }
        }

        for atbat in gameAtbats {
            if atbat.seq >= newseq[atbat.col] {
                atbat.seq += 1
            }
            if atbat.player.identifier == outgoingPlayer.identifier {
                let newatbat = Atbat(
                    game: authoritativeGame,
                    team: team,
                    player: incomingPlayer,
                    result: "Pitch Hitter",
                    maxbase: "No Bases",
                    batOrder: incomingPlayer.batOrder,
                    outAt: "Safe",
                    inning: atbat.inning,
                    seq: newseq[atbat.col],
                    col: atbat.col,
                    rbis: 0,
                    outs: 0,
                    sacFly: 0,
                    sacBunt: 0,
                    stolenBases: 0
                )
                modelContext.insert(newatbat)
                authoritativeGame.atbats.append(newatbat)
                if atbat.col == 1 {
                    authoritativeGame.players.append(incomingPlayer)
                }
            }
        }

        do {
            try save()
        } catch {
            rollback.restore(modelContext: modelContext)
            return SubstitutionSubmissionResult(
                disposition: .persistenceFailed,
                refreshedState: nil,
                message: "Error saving substitution: \(error)"
            )
        }

        let refreshed = prepareLiveGameState(
            game: authoritativeGame,
            battingTeam: team,
            displayedAtbats: authoritativeGame.atbats.filter { $0.team.ident == team.ident },
            pitchers: pitchers.filter { $0.game.ident == authoritativeGame.ident }
        )
        guard refreshed.disposition == .ready else {
            return SubstitutionSubmissionResult(
                disposition: .refreshedStateUnavailable,
                refreshedState: refreshed,
                message: refreshed.warnings.first
            )
        }

        return SubstitutionSubmissionResult(
            disposition: .accepted,
            refreshedState: refreshed,
            message: nil
        )
    }

    func submitPitcherChange(
        gameIdentity: UUID,
        teamIdentity: UUID,
        incomingPitcherIdentity: UUID,
        startInning: Int,
        startOuts: Int,
        startBatters: Int,
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        modelContext: ModelContext,
        save: SaveAction
    ) -> SubstitutionSubmissionResult {
        guard let authoritativeGame = fetchGame(identity: gameIdentity, in: modelContext) else {
            return SubstitutionSubmissionResult(
                disposition: .gameMissing,
                refreshedState: nil,
                message: "The game is no longer available."
            )
        }
        guard let incomingPlayer = fetchPlayer(identity: incomingPitcherIdentity, in: modelContext) else {
            return SubstitutionSubmissionResult(
                disposition: .participantMissing,
                refreshedState: nil,
                message: "Participant could not be found."
            )
        }
        let team: Team
        if let h = authoritativeGame.hteam, h.ident == teamIdentity { team = h }
        else if let v = authoritativeGame.vteam, v.ident == teamIdentity { team = v }
        else {
            return SubstitutionSubmissionResult(
                disposition: .wrongTeamOrGame,
                refreshedState: nil,
                message: "Team is not part of this game."
            )
        }

        let rollback = LegacySubstitutionRollbackSnapshot(game: authoritativeGame)
        let battingTeamAtbats = authoritativeGame.atbats.filter { $0.team.ident != teamIdentity }
        let existingGamePitchers = authoritativeGame.pitchers.filter { $0.game.ident == authoritativeGame.ident }
        updatePitcherMarkersInMemory(
            displayedAtbats: battingTeamAtbats,
            pitchers: existingGamePitchers,
            game: authoritativeGame
        )

        if let existing = authoritativeGame.pitchers.first(where: { $0.player.identifier == incomingPlayer.identifier }) {
             existing.startInn = startInning
             existing.sOuts = startOuts
             existing.sBats = startBatters
        } else {
             let pitcher = Pitcher(
                 player: incomingPlayer,
                 team: team,
                 game: authoritativeGame,
                 startInn: startInning,
                 sOuts: startOuts,
                 sBats: startBatters,
                 endInn: 0,
                 eOuts: 0,
                 eBats: 0,
                 strikeOuts: 0,
                 walks: 0,
                 hits: 0,
                 runs: 0,
                 won: false
             )
             modelContext.insert(pitcher)
             authoritativeGame.pitchers.append(pitcher)
        }

        let gamePitchers = authoritativeGame.pitchers.filter { $0.game.ident == authoritativeGame.ident }
        updatePitcherMarkersInMemory(
            displayedAtbats: battingTeamAtbats,
            pitchers: gamePitchers,
            game: authoritativeGame
        )

        do {
            try save()
        } catch {
            rollback.restore(modelContext: modelContext)
            return SubstitutionSubmissionResult(
                disposition: .persistenceFailed,
                refreshedState: nil,
                message: "Error saving pitcher change: \(error)"
            )
        }

        let refreshed = prepareLiveGameState(
            game: authoritativeGame,
            battingTeam: authoritativeGame.hteam?.ident == teamIdentity ? authoritativeGame.vteam : authoritativeGame.hteam,
            displayedAtbats: battingTeamAtbats,
            pitchers: gamePitchers
        )

        return SubstitutionSubmissionResult(
            disposition: .accepted,
            refreshedState: refreshed.disposition == .ready ? refreshed : nil,
            message: nil
        )
    }

    private func fetchGame(identity: UUID, in modelContext: ModelContext) -> Game? {
        (try? modelContext.fetch(FetchDescriptor<Game>()))?.first { $0.ident == identity }
    }

    private func fetchAtbat(identity: UUID, in modelContext: ModelContext) -> Atbat? {
        (try? modelContext.fetch(FetchDescriptor<Atbat>()))?.first { $0.ident == identity }
    }

    private func fetchPlayer(identity: UUID, in modelContext: ModelContext) -> Player? {
        (try? modelContext.fetch(FetchDescriptor<Player>()))?.first { $0.identifier == identity }
    }

    private func isSupportedCorrectionReplacement(_ replacement: LegacyCorrectionReplacement) -> Bool {
        replacement.result != "Result" &&
        (common.onresults.contains(replacement.result) || common.outresults.contains(replacement.result)) &&
        availableBaseChoices.contains(replacement.maxBase) &&
        availableOutAtChoices.contains(replacement.outAt) &&
        availableRBIChoices.contains(replacement.rbis) &&
        availableStolenBaseChoices.contains(replacement.stolenBases)
    }

    private func correctionDisposition(for plan: CanonicalCorrectionPlan) -> CorrectionDisposition {
        switch plan.resolution {
        case .missingTarget, .unsupportedTarget, .alreadySupersededTarget:
            return .targetMissing
        case .wrongGameTarget:
            return .wrongGameTarget
        case .staleExpectedOriginal:
            return .targetStale
        case .duplicateTargetIdentity, .conflictingTargetEvidence, .ambiguousOrdering:
            return .validationRejected
        case .uniquelyResolved:
            break
        }
        switch plan.disposition {
        case .unsupported:
            return .unsupportedCorrection
        case .rejected, .contradictory, .unresolved, .repairRequired:
            return .validationRejected
        case .accepted, .planned, .warningOnly:
            return .validationRejected
        }
    }

    private func applyCorrection(_ replacement: LegacyCorrectionReplacement, to atbat: Atbat) {
        atbat.result = replacement.result
        atbat.maxbase = replacement.maxBase
        atbat.outAt = replacement.outAt
        atbat.rbis = replacement.rbis
        atbat.stolenBases = replacement.stolenBases
        atbat.earnedRun = replacement.earnedRun
        atbat.playRec = replacement.playRecord
        atbat.sacFly = replacement.result == "Sacrifice Fly" ? 1 : 0
        atbat.sacBunt = replacement.result == "Sacrifice Bunt" ? 1 : 0
        if !common.recOuts.contains(atbat.result) && atbat.outAt == "Safe" {
            atbat.playRec = ""
        }
        markEndOfInning(for: atbat)
    }

    private func recalculateLegacyAfterCorrection(
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        game: Game
    ) -> ProjectionResult {
        var columnBoxes = Array(repeating: BoxScore(), count: 20)
        var batterBoxes = Array(repeating: BoxScore(), count: 20)
        var totalBoxes = Array(repeating: BoxScore(), count: 5)
        sequenceGameInMemory(
            displayedAtbats: displayedAtbats,
            columnBoxes: &columnBoxes,
            batterBoxes: &batterBoxes,
            totalBoxes: &totalBoxes
        )
        let inningStatus = updateMaxBases(displayedAtbats: displayedAtbats)
        updatePitcherMarkersInMemory(displayedAtbats: displayedAtbats, pitchers: pitchers, game: game)
        return ProjectionResult(
            disposition: .success,
            columnBoxes: columnBoxes,
            batterBoxes: batterBoxes,
            totalBoxes: totalBoxes,
            inningStatus: inningStatus,
            message: nil
        )
    }

    private func sequenceGameInMemory(
        displayedAtbats: [Atbat],
        columnBoxes: inout [BoxScore],
        batterBoxes: inout [BoxScore],
        totalBoxes: inout [BoxScore]
    ) {
        var allOuts = 0
        var outs = 0
        var sequence = 1
        var inning = 1
        var column = 1
        var endOfInning = false

        for atbat in displayedAtbats.sorted(by: atbatPrecedes) where atbat.result != "Result" {
            if outs == 3 && endOfInning {
                outs = 0
                inning += 1
                column += 1
                sequence = 1
            }

            let numOfHitters = displayedAtbats.filter { $0.col == 1 }.count
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
    }

    private func updatePitcherMarkersInMemory(
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        game: Game
    ) {
        let firstTeam = displayedAtbats.first?.team
        let currentBatter = displayedAtbats.sorted(by: atbatPrecedes).last(where: { $0.result != "Result" })
        let currentBoundary = pitcherBoundary(after: currentBatter)
        let opposingPitchers = pitchers.filter { $0.team != firstTeam && $0.game.ident == game.ident }
        guard let currentPitcher = opposingPitchers.last else { return }

        if opposingPitchers.count == 1,
           currentPitcher.startInn == 0 && currentPitcher.sOuts == 0 && currentPitcher.sBats == 0 {
            currentPitcher.startInn = currentBoundary.inning
            currentPitcher.sOuts = currentBoundary.outs
            currentPitcher.sBats = currentBoundary.batters
            currentPitcher.endInn = currentBoundary.inning
            currentPitcher.eOuts = currentBoundary.outs
            currentPitcher.eBats = currentBoundary.batters
        } else if opposingPitchers.count > 1 {
            let previousPitcher = opposingPitchers[opposingPitchers.count - 2]
            if currentPitcher.startInn == 0 && currentPitcher.sOuts == 0 && currentPitcher.sBats == 0 {
                previousPitcher.endInn = currentBoundary.inning
                previousPitcher.eOuts = currentBoundary.outs
                previousPitcher.eBats = currentBoundary.batters

                currentPitcher.startInn = currentBoundary.inning
                currentPitcher.sOuts = currentBoundary.outs
                currentPitcher.sBats = currentBoundary.batters
                currentPitcher.endInn = currentPitcher.startInn
                currentPitcher.eOuts = currentPitcher.sOuts
                currentPitcher.eBats = currentPitcher.sBats
            }
        }

        if let currentBatter {
            let endBoundary = pitcherBoundary(after: currentBatter)
            currentPitcher.endInn = endBoundary.inning
            currentPitcher.eOuts = endBoundary.outs
            currentPitcher.eBats = endBoundary.batters
        }

        if opposingPitchers.count >= 2 {
            let previousPitcher = opposingPitchers[opposingPitchers.count - 2]
            if previousPitcher.endInn == 0 {
                previousPitcher.endInn = currentPitcher.startInn
                previousPitcher.eOuts = currentPitcher.sOuts
                previousPitcher.eBats = currentPitcher.sBats
            }
        }
    }

    private func pitcherBoundary(after currentBatter: Atbat?) -> (inning: Int, outs: Int, batters: Int) {
        guard let currentBatter else {
            return (inning: 1, outs: 0, batters: 0)
        }

        if currentBatter.outs == 3 || currentBatter.endOfInning {
            return (inning: Int(currentBatter.inning.rounded(.up)) + 1, outs: 0, batters: 0)
        }

        return (
            inning: Int(currentBatter.inning.rounded(.up)),
            outs: currentBatter.outs,
            batters: currentBatter.seq
        )
    }

    private func canonicalReplacementEvent(
        from atbat: Atbat,
        replacement: LegacyCorrectionReplacement
    ) -> CanonicalScoringEventEvidence {
        let snapshot = LegacyCorrectionSnapshot(atbat)
        return canonicalEvent(
            from: snapshot,
            teamSide: side(for: atbat.team, in: atbat.game),
            overrideResult: replacement.result,
            overrideMaxBase: replacement.maxBase,
            overrideOutAt: replacement.outAt,
            overrideRBIs: replacement.rbis,
            overrideStolenBases: replacement.stolenBases,
            overrideEarnedRun: replacement.earnedRun,
            overridePlayRecord: replacement.playRecord
        )
    }

    private func canonicalEvent(_ atbat: Atbat) -> CanonicalScoringEventEvidence {
        canonicalEvent(
            from: LegacyCorrectionSnapshot(atbat),
            teamSide: side(for: atbat.team, in: atbat.game)
        )
    }

    private func canonicalEvent(
        from snapshot: LegacyCorrectionSnapshot,
        teamSide: TeamSideRole?,
        overrideResult: String? = nil,
        overrideMaxBase: String? = nil,
        overrideOutAt: String? = nil,
        overrideRBIs: Int? = nil,
        overrideStolenBases: Int? = nil,
        overrideEarnedRun: Bool? = nil,
        overridePlayRecord: String? = nil
    ) -> CanonicalScoringEventEvidence {
        let result = overrideResult ?? snapshot.result
        let maxBase = overrideMaxBase ?? snapshot.maxBase
        let outAt = overrideOutAt ?? snapshot.outAt
        let rbis = overrideRBIs ?? snapshot.rbis
        let stolenBases = overrideStolenBases ?? snapshot.stolenBases
        let earnedRun = overrideEarnedRun ?? snapshot.earnedRun
        let playRecord = overridePlayRecord ?? snapshot.playRecord
        let batter = LineupParticipantEvidence.gameParticipant(GamePlayerParticipation(
            participantIdentity: .valid(snapshot.playerIdentity),
            gameIdentity: .valid(snapshot.gameIdentity),
            playerResolution: .unknown(PlayerDisplayEvidence()),
            teamEvidence: .gameSide(GameSideTeamParticipation(
                gameIdentity: .valid(snapshot.gameIdentity),
                role: teamSide ?? .unresolved,
                resolution: .unknown(TeamDisplayEvidence())
            )),
            historicalDisplay: PlayerDisplayEvidence(),
            roles: [.batter],
            source: .historicalGameParticipation
        ))

        return CanonicalScoringEventEvidence(
            eventIdentity: .valid(snapshot.atbatIdentity),
            gameIdentity: .valid(snapshot.gameIdentity),
            orderingEvidence: [
                .knownSequence(OrderEvidence(kind: .eventSequence, value: snapshot.sequence, sourceIndex: snapshot.column)),
                .stableTieEvidence(OrderEvidence(kind: .displaySort, value: snapshot.column, sourceIndex: snapshot.battingOrder))
            ],
            inningContext: CanonicalHalfInning(
                number: .known(max(1, Int(snapshot.inning.rounded(.up)))),
                half: teamSide == .home ? .known(.bottom) : .known(.top),
                expectedInnings: .missing,
                source: .currentGameRecord
            ),
            teamSide: teamSide,
            participants: ScoringEventParticipantEvidence(batter: batter),
            resultEvidence: ScoringEventResultEvidence(rawValue: result),
            outsEvidence: CanonicalOutsState(outs: .known(snapshot.outs), source: .currentGameRecord),
            batterAdvancement: runnerState(for: maxBase, playerIdentity: snapshot.playerIdentity),
            runnerAdvancement: outAt == "Safe" ? [] : [.out(runner: .knownHistoricalParticipant(.valid(snapshot.playerIdentity), PlayerDisplayEvidence()), sourceBase: base(for: outAt))],
            runsScored: maxBase == "Home" ? .count(1) : .notRepresented,
            rbiEvidence: .count(rbis),
            earnedRunEvidence: .flag(earnedRun),
            sacrificeEvidence: sacrificeEvidence(for: result),
            stolenBaseEvidence: .count(stolenBases),
            endOfHalfEvidence: snapshot.endOfInning,
            historicalDisplayEvidence: [
                "legacyResult=\(result)",
                "maxBase=\(maxBase)",
                "outAt=\(outAt)",
                "playRecord=\(playRecord)"
            ],
            unsupportedRawLegacyEvidence: [],
            source: .currentAtbatRecord
        )
    }

    private func side(for team: Team, in game: Game) -> TeamSideRole? {
        if game.hteam?.ident == team.ident { return .home }
        if game.vteam?.ident == team.ident { return .visiting }
        return nil
    }

    private func runnerState(for maxBase: String, playerIdentity: UUID) -> RunnerStateEvidence? {
        let runner = RunnerIdentityEvidence.knownHistoricalParticipant(.valid(playerIdentity), PlayerDisplayEvidence())
        switch maxBase {
        case "First":
            return .activeOccupant(base: .first, runner: runner)
        case "Second":
            return .activeOccupant(base: .second, runner: runner)
        case "Third":
            return .activeOccupant(base: .third, runner: runner)
        case "Home":
            return .scored(runner: runner, sourceBase: nil)
        default:
            return nil
        }
    }

    private func base(for legacyBase: String) -> Base {
        switch legacyBase {
        case "First":
            return .first
        case "Second":
            return .second
        case "Third":
            return .third
        default:
            return .home
        }
    }

    private func sacrificeEvidence(for result: String) -> ScoringEventMarkerEvidence {
        if result == "Sacrifice Fly" || result == "Sacrifice Bunt" {
            return .flag(true)
        }
        return .notRepresented
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
        let currentBoundary = pitcherBoundary(after: currentBatter)
        let opposingPitchers = pitchers.filter { $0.team != firstTeam }

        guard !opposingPitchers.isEmpty else { return (.noChange, nil) }

        let currentPitcher = opposingPitchers[opposingPitchers.count - 1]

        if opposingPitchers.count == 1 {
            if currentPitcher.startInn == 0 && currentPitcher.sOuts == 0 && currentPitcher.sBats == 0 {
                currentPitcher.startInn = currentBoundary.inning
                currentPitcher.sOuts = currentBoundary.outs
                currentPitcher.sBats = currentBoundary.batters
                currentPitcher.endInn = currentBoundary.inning
                currentPitcher.eOuts = currentBoundary.outs
                currentPitcher.eBats = currentBoundary.batters

                do {
                    try save()
                } catch {
                    return (.persistenceFailed, "Error saving pitcher markers: \(error)")
                }
            }
        } else {
            let previousPitcher = opposingPitchers[opposingPitchers.count - 2]

            if currentPitcher.startInn == 0 && currentPitcher.sOuts == 0 && currentPitcher.sBats == 0 {
                previousPitcher.endInn = currentBoundary.inning
                previousPitcher.eOuts = currentBoundary.outs
                previousPitcher.eBats = currentBoundary.batters

                currentPitcher.startInn = currentBoundary.inning
                currentPitcher.sOuts = currentBoundary.outs
                currentPitcher.sBats = currentBoundary.batters
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
            let endBoundary = pitcherBoundary(after: currentBatter)
            currentPitcher.endInn = endBoundary.inning
            currentPitcher.eOuts = endBoundary.outs
            currentPitcher.eBats = endBoundary.batters
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
        if preparedState.disposition == .unavailablePitcher {
            return EnabledScoringActionState(
                identity: identity,
                isEnabled: true,
                disposition: .enabledWithWarnings,
                validationDisposition: nil,
                unavailableReason: unavailableReason(forPreparedState: preparedState),
                warnings: preparedState.warnings
            )
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

    private func ordinaryOperationRequest(
        operationIdentity: UUID,
        legacyResult: String,
        targetAtbat: Atbat,
        game: Game,
        battingTeam: Team?,
        preparedState: PreparedLiveGameState?
    ) -> LegacyScoringOperationRequestFacts {
        var facts = sharedOperationFacts(
            targetAtbat: targetAtbat,
            game: game,
            battingTeam: battingTeam,
            preparedState: preparedState
        )
        facts.append("selectedResult=\(legacyResult)")
        facts.append("ordinaryDefaults=earnedRunAndPlayRecord")
        return LegacyScoringOperationRequestFacts(
            operationIdentity: operationIdentity,
            targetGameIdentity: game.ident,
            targetAtbatIdentity: targetAtbat.ident,
            submissionFamily: LegacyScoringOperationEvidenceConstants.ordinarySubmissionFamily,
            acceptedResultClassification: legacyResult,
            acceptedOutcomeReference: acceptedOutcomeReference(for: targetAtbat),
            deterministicRequestFacts: facts
        )
    }

    private func additionalChoiceOperationRequest(
        operationIdentity: UUID,
        choices: AdditionalScoringChoices,
        targetAtbat: Atbat,
        game: Game,
        battingTeam: Team?,
        preparedState: PreparedLiveGameState?
    ) -> LegacyScoringOperationRequestFacts {
        var facts = sharedOperationFacts(
            targetAtbat: targetAtbat,
            game: game,
            battingTeam: battingTeam,
            preparedState: preparedState
        )
        facts.append(contentsOf: [
            "selectedResult=\(choices.legacyResult)",
            "maxBase=\(choices.maxBase)",
            "outAt=\(choices.outAt)",
            "rbis=\(choices.rbis)",
            "stolenBases=\(choices.stolenBases)",
            "earnedRun=\(choices.earnedRun)",
            "playRecord=\(choices.playRecord)",
            "sacrificeFly=\(choices.legacyResult == "Sacrifice Fly")",
            "sacrificeBunt=\(choices.legacyResult == "Sacrifice Bunt")",
            "choiceFamily=\(additionalChoiceCategory(for: choices.legacyResult))"
        ])
        return LegacyScoringOperationRequestFacts(
            operationIdentity: operationIdentity,
            targetGameIdentity: game.ident,
            targetAtbatIdentity: targetAtbat.ident,
            submissionFamily: LegacyScoringOperationEvidenceConstants.additionalChoiceSubmissionFamily,
            acceptedResultClassification: choices.legacyResult,
            acceptedOutcomeReference: acceptedOutcomeReference(for: targetAtbat),
            deterministicRequestFacts: facts
        )
    }

    private func sharedOperationFacts(
        targetAtbat: Atbat,
        game: Game,
        battingTeam: Team?,
        preparedState: PreparedLiveGameState?
    ) -> [String] {
        [
            "game=\(game.ident.uuidString.lowercased())",
            "atbat=\(targetAtbat.ident.uuidString.lowercased())",
            "battingTeam=\(battingTeam?.ident.uuidString.lowercased() ?? "missing")",
            "targetPlayer=\(targetAtbat.player.identifier.uuidString.lowercased())",
            "targetBatOrder=\(targetAtbat.batOrder)",
            "targetColumn=\(targetAtbat.col)",
            "targetSequence=\(targetAtbat.seq)",
            "preparedBattingSide=\(preparedState?.battingSide.rawValue ?? "missing")"
        ]
    }

    private func acceptedOutcomeReference(for atbat: Atbat) -> String {
        "legacyAtbat:\(atbat.ident.uuidString.lowercased())"
    }

    private func scoringSubmissionResult(
        from evidenceResult: LegacyScoringOperationEvidenceTransactionResult,
        atbat: Atbat,
        actionState: EnabledScoringActionState?,
        failureMessage: String
    ) -> ScoringSubmissionResult {
        switch evidenceResult.transaction.disposition {
        case .success:
            return ScoringSubmissionResult(
                disposition: .accepted,
                atbat: atbat,
                actionState: actionState,
                message: nil,
                operationIdentity: evidenceResult.operationIdentity,
                operationEvidenceResult: evidenceResult
            )
        case .duplicateAlreadyApplied:
            return ScoringSubmissionResult(
                disposition: .duplicatePrevented,
                atbat: atbat,
                actionState: actionState,
                message: nil,
                operationIdentity: evidenceResult.operationIdentity,
                operationEvidenceResult: evidenceResult
            )
        case .contradictory:
            return ScoringSubmissionResult(
                disposition: .conflict,
                atbat: atbat,
                actionState: actionState,
                message: "The scoring operation identity was reused for different facts.",
                operationIdentity: evidenceResult.operationIdentity,
                operationEvidenceResult: evidenceResult
            )
        default:
            return ScoringSubmissionResult(
                disposition: .persistenceFailed,
                atbat: atbat,
                actionState: actionState,
                message: failureMessage,
                operationIdentity: evidenceResult.operationIdentity,
                operationEvidenceResult: evidenceResult
            )
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
        let activeLineup = lineup.filter { $0.isReplaced == false }
        guard activeLineup.isEmpty == false else { return nil }
        guard let lastCompleted else { return activeLineup.first }

        if let next = activeLineup.first(where: { $0.slot > lastCompleted.batOrder }) {
            return next
        }
        return activeLineup.first
    }

    private func preparedCurrentColumn(
        after lastCompleted: Atbat?,
        nextBatterSlot: Int?,
        completedAtbats: [Atbat],
        completedHalfInningEnded: Bool
    ) -> Int {
        guard let lastCompleted else { return 1 }
        if completedHalfInningEnded { return lastCompleted.col + 1 }
        let currentColumn = max(1, lastCompleted.col)

        guard let nextBatterSlot else { return currentColumn }

        let isSlotOccupiedInCurrentColumn = completedAtbats.contains {
            $0.col == currentColumn && $0.batOrder == nextBatterSlot
        }

        return isSlotOccupiedInCurrentColumn ? currentColumn + 1 : currentColumn
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

    private func validateSubmission(
        legacyResult: String,
        targetAtbat: Atbat?,
        game: Game,
        battingTeam: Team?,
        displayedAtbats: [Atbat],
        pitchers: [Pitcher],
        supportedLegacyResults: [String],
        additionalChoices: AdditionalScoringChoices? = nil
    ) -> (result: ScoringSubmissionResult, targetAtbat: Atbat?, preparedState: PreparedLiveGameState?) {
        guard legacyResult != "Result" else {
            return (
                ScoringSubmissionResult(disposition: .cancellation, atbat: targetAtbat, actionState: nil, message: "No scoring action was submitted."),
                targetAtbat,
                nil
            )
        }

        guard supportedLegacyResults.contains(legacyResult) else {
            return (
                ScoringSubmissionResult(disposition: .unsupportedAction, atbat: targetAtbat, actionState: nil, message: "This scoring choice is not supported for the current game state."),
                targetAtbat,
                nil
            )
        }

        guard let targetAtbat else {
            return (
                ScoringSubmissionResult(disposition: .unavailablePreparedState, atbat: nil, actionState: nil, message: "An at-bat is required before scoring."),
                nil,
                nil
            )
        }

        let preparedState = prepareLiveGameState(
            game: game,
            battingTeam: battingTeam,
            displayedAtbats: displayedAtbats,
            pitchers: pitchers
        )
        guard preparedState.canScore else {
            return (
                ScoringSubmissionResult(disposition: .unavailablePreparedState, atbat: targetAtbat, actionState: nil, message: unavailableReason(forPreparedState: preparedState)),
                targetAtbat,
                preparedState
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
            return (
                ScoringSubmissionResult(disposition: .unsupportedAction, atbat: targetAtbat, actionState: nil, message: "This scoring choice is not supported for the current game state."),
                targetAtbat,
                preparedState
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
            return (
                ScoringSubmissionResult(disposition: disposition, atbat: targetAtbat, actionState: actionState, message: actionState.unavailableReason),
                targetAtbat,
                preparedState
            )
        }

        if let additionalChoices {
            if targetAtbat.result == legacyResult && currentAdditionalChoices(for: targetAtbat, legacyResult: legacyResult) == additionalChoices {
                return (
                    ScoringSubmissionResult(disposition: .accepted, atbat: targetAtbat, actionState: actionState, message: nil),
                    targetAtbat,
                    preparedState
                )
            }
        } else if targetAtbat.result == legacyResult {
            return (
                ScoringSubmissionResult(disposition: .accepted, atbat: targetAtbat, actionState: actionState, message: nil),
                targetAtbat,
                preparedState
            )
        }

        guard preparedState.currentOrPendingLegacyAtbat?.identity == targetAtbat.ident else {
            return (
                ScoringSubmissionResult(disposition: .conflict, atbat: targetAtbat, actionState: actionState, message: "The scoring state changed before this action could be submitted."),
                targetAtbat,
                preparedState
            )
        }

        if let additionalChoices {
            let command = command(forLegacyResult: legacyResult, preparedState: preparedState, additionalChoices: additionalChoices)
            let validation = CanonicalScoringCommandValidator.validate(
                command,
                against: scoringCommandInputState(from: preparedState),
                sourceLocation: "Task 7.5 additional-choice scoring action submission"
            )
            guard validation.mayApplyInMemory else {
                return (
                    ScoringSubmissionResult(disposition: .validationRejected, atbat: targetAtbat, actionState: actionState, message: unavailableReason(for: validation)),
                    targetAtbat,
                    preparedState
                )
            }
        }

        return (
            ScoringSubmissionResult(disposition: .accepted, atbat: targetAtbat, actionState: actionState, message: nil),
            targetAtbat,
            preparedState
        )
    }

    private func command(
        forLegacyResult rawResult: String,
        preparedState: PreparedLiveGameState,
        additionalChoices: AdditionalScoringChoices
    ) -> CanonicalScoringCommand {
        let base = command(forLegacyResult: rawResult, preparedState: preparedState)
        let extraOuts = additionalChoices.outAt == "Safe" ? 0 : 1
        let earnedEvidence: ScoringEventMarkerEvidence = common.onresults.contains(rawResult) ? .flag(additionalChoices.earnedRun) : .notRepresented
        let rbiEvidence: ScoringEventMarkerEvidence = additionalChoices.rbis == 0 ? .count(0) : .count(additionalChoices.rbis)
        let stolenEvidence: ScoringEventMarkerEvidence = additionalChoices.stolenBases == 0 ? .count(0) : .count(additionalChoices.stolenBases)
        let sacrificeEvidence: ScoringEventMarkerEvidence
        if rawResult == "Sacrifice Fly" || rawResult == "Sacrifice Bunt" {
            sacrificeEvidence = .count(1)
        } else {
            sacrificeEvidence = .notRepresented
        }

        return CanonicalScoringCommand(
            intent: base?.intent ?? .unsupportedLegacy(.unknownRaw(rawValue: rawResult)),
            gameIdentity: base?.gameIdentity ?? .missing,
            teamSide: base?.teamSide ?? preparedState.battingSide,
            batter: base?.batter,
            runnerDestinations: base?.runnerDestinations ?? [],
            outsRequested: extraOuts,
            rbiEvidence: rbiEvidence,
            sacrificeEvidence: sacrificeEvidence,
            stolenBaseEvidence: stolenEvidence,
            earnedRunEvidence: earnedEvidence,
            pitcherResponsibility: base?.pitcherResponsibility,
            proposedEventIdentity: base?.proposedEventIdentity ?? .missing,
            orderingEvidence: base?.orderingEvidence ?? [],
            rawLegacyEvidence: base?.rawLegacyEvidence ?? [rawResult],
            source: .scoringView
        )
    }

    private func requiresAdditionalChoice(for legacyResult: String) -> Bool {
        let immediateDismiss = [
            "Walk",
            "Intentional Walk",
            "Hit By Pitch",
            "Strikeout",
            "Strikeout Looking",
            "Catcher Interference"
        ]
        if immediateDismiss.contains(legacyResult) {
            return false
        }
        return common.onresults.contains(legacyResult) || common.recOuts.contains(legacyResult)
    }

    private func additionalChoiceCategory(for legacyResult: String) -> String {
        if common.onresults.contains(legacyResult) && common.recOuts.contains(legacyResult) {
            return "runnerMovementAndRecordedOut"
        }
        if common.onresults.contains(legacyResult) {
            return "runnerMovementRBIStolenBaseAndEarnedRun"
        }
        return "recordedOut"
    }

    private func defaultAdditionalChoices(for legacyResult: String, atbat: Atbat) -> AdditionalScoringChoices {
        let earned = (legacyResult == "Dropped 3rd Strike" || legacyResult == "Error") ? false : atbat.earnedRun
        return AdditionalScoringChoices(
            legacyResult: legacyResult,
            maxBase: atbat.maxbase,
            outAt: atbat.outAt,
            rbis: atbat.rbis,
            stolenBases: atbat.stolenBases,
            earnedRun: earned,
            playRecord: atbat.playRec
        )
    }

    private func currentAdditionalChoices(for atbat: Atbat, legacyResult: String) -> AdditionalScoringChoices {
        AdditionalScoringChoices(
            legacyResult: legacyResult,
            maxBase: atbat.maxbase,
            outAt: atbat.outAt,
            rbis: atbat.rbis,
            stolenBases: atbat.stolenBases,
            earnedRun: atbat.earnedRun,
            playRecord: atbat.playRec
        )
    }

    private func additionalChoicesAreSupported(_ choices: AdditionalScoringChoices) -> Bool {
        availableBaseChoices.contains(choices.maxBase) &&
            availableOutAtChoices.contains(choices.outAt) &&
            availableRBIChoices.contains(choices.rbis) &&
            availableStolenBaseChoices.contains(choices.stolenBases) &&
            playRecordIsSupported(choices.playRecord)
    }

    private func playRecordIsSupported(_ playRecord: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "PFL123456789-")
        return playRecord.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func additionalChoiceDisposition(for submissionDisposition: SubmissionDisposition) -> AdditionalChoiceDisposition {
        switch submissionDisposition {
        case .accepted:
            return .pending
        case .validationRejected:
            return .validationRejected
        case .unavailablePreparedState:
            return .unavailablePreparedState
        case .disabledAction:
            return .disabledAction
        case .unsupportedAction:
            return .unsupportedAction
        case .conflict:
            return .conflict
        case .cancellation, .duplicatePrevented, .persistenceFailed:
            return .validationRejected
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

    private func scorecardCellTarget(for atbat: PreparedAtbatSnapshot) -> ScorecardCellTarget {
        ScorecardCellTarget(
            atbatIdentity: atbat.identity,
            playerIdentity: atbat.player.identity,
            column: atbat.column,
            battingOrder: atbat.battingOrder,
            sequence: atbat.sequence
        )
    }

    private func isComputedCurrentSelection(
        sourceAtbat: Atbat,
        column: Int,
        preparedState: PreparedLiveGameState
    ) -> Bool {
        guard let currentBatter = preparedState.currentBatter else { return false }
        return sourceAtbat.player.identifier == currentBatter.identity &&
            column == preparedState.currentScorecardColumn
    }

    private func invalidNonCurrentSelectionResult(
        preparedState: PreparedLiveGameState,
        displayedAtbats: [Atbat]
    ) -> SelectionResult {
        let message = "That is not the current at-bat. You may edit completed at-bats or score the next open at-bat."
        if let pending = preparedState.currentOrPendingLegacyAtbat {
            return SelectionResult(
                disposition: .validationFailed,
                atbat: nil,
                message: message,
                targetAction: .scorecardCell(column: pending.column, battingOrder: pending.battingOrder),
                targetCell: scorecardCellTarget(for: pending),
                renderedTarget: renderedScorecardCellTarget(for: pending, displayedAtbats: displayedAtbats)
            )
        }

        return SelectionResult(
            disposition: .validationFailed,
            atbat: nil,
            message: message,
            targetAction: computedCurrentTargetAction(for: preparedState),
            targetCell: nil,
            renderedTarget: renderedScorecardCellTarget(forComputedCurrent: preparedState, displayedAtbats: displayedAtbats)
        )
    }

    private func renderedScorecardCellTarget(
        for atbat: PreparedAtbatSnapshot,
        displayedAtbats: [Atbat]
    ) -> RenderedScorecardCellTarget? {
        let renderedRow = displayedAtbats
            .filter {
                $0.player.identifier == atbat.player.identity &&
                $0.col == 1 &&
                $0.inning <= 1 &&
                $0.batOrder != 99
            }
            .sorted(by: atbatPrecedes)
            .first
        guard let renderedRow else { return nil }

        return RenderedScorecardCellTarget(
            renderedRowIdentity: renderedRow.ident,
            column: atbat.column
        )
    }

    private func computedCurrentTargetAction(for preparedState: PreparedLiveGameState) -> ScoringActionIdentity? {
        guard let battingOrder = preparedState.battingOrderPosition else { return nil }
        return .scorecardCell(column: preparedState.currentScorecardColumn, battingOrder: battingOrder)
    }

    private func renderedScorecardCellTarget(
        forComputedCurrent preparedState: PreparedLiveGameState,
        displayedAtbats: [Atbat]
    ) -> RenderedScorecardCellTarget? {
        guard let currentBatter = preparedState.currentBatter else { return nil }
        let renderedRow = displayedAtbats
            .filter {
                $0.player.identifier == currentBatter.identity &&
                $0.col == 1 &&
                $0.inning <= 1 &&
                $0.batOrder != 99
            }
            .sorted(by: atbatPrecedes)
            .first
        guard let renderedRow else { return nil }

        return RenderedScorecardCellTarget(
            renderedRowIdentity: renderedRow.ident,
            column: preparedState.currentScorecardColumn
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

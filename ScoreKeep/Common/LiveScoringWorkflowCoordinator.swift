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

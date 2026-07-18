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
}

import Foundation
import SwiftData

struct LineupSlot: Identifiable, Equatable {
    var id: Int { battingOrder }
    let battingOrder: Int
    let player: Player
    let placeholderAtbat: Atbat
    let editability: LineupSlotEditability

    var isEditable: Bool {
        editability == .editable
    }
}

enum LineupSlotEditability: Equatable {
    case editable
    case locked(LineupSlotLockReason)
}

enum LineupSlotLockReason: String, Equatable {
    case missingPlaceholder = "A lineup placeholder is missing for this slot."
    case ambiguousLineupState = "Lineup records for this game are ambiguous."
    case duplicateLineupSlot = "More than one player is assigned to this batting-order slot."
    case duplicatePlayerAssignment = "This player is assigned to more than one lineup slot."
    case placeholderNotPristine = "This lineup slot already has scoring details."
    case playerHasOtherAtbat = "This player already has other at-bat participation in this game."
    case acceptedScoringEvidence = "Accepted scoring evidence exists for this slot."
    case substitutionParticipation = "This player is already part of a substitution in this game."
    case pitcherParticipation = "This player has pitched in this game."
    case incomingPlayerUnavailable = "The selected player is already used in this game lineup."
    case persistenceEvidenceUnavailable = "Scoring evidence could not be verified."
}

struct LineupSlotMaterializationResult: Equatable {
    enum Source: Equatable {
        case existingLineup
        case firstColumnAtbats
        case rosterBattingOrder
    }

    let source: Source
    let lineup: Lineup
    let slots: [LineupSlot]
}

struct LineupSlotReassignmentResult: Equatable {
    let slot: LineupSlot
    let outgoingPlayer: Player
    let incomingPlayer: Player
}

enum LineupSlotSafetyError: Error, Equatable, LocalizedError {
    case missingTeam
    case noEligibleRosterPlayers
    case ambiguousLineupState(LineupSlotLockReason)
    case slotNotFound(Int)
    case slotLocked(LineupSlotLockReason)
    case incomingPlayerUnavailable(LineupSlotLockReason)

    var errorDescription: String? {
        switch self {
        case .missingTeam:
            return "A team is required to resolve lineup slots."
        case .noEligibleRosterPlayers:
            return "No eligible roster players are available for this lineup."
        case .ambiguousLineupState(let reason):
            return reason.rawValue
        case .slotNotFound(let slot):
            return "Batting-order slot \(slot) could not be resolved."
        case .slotLocked(let reason):
            return reason.rawValue
        case .incomingPlayerUnavailable(let reason):
            return reason.rawValue
        }
    }
}

@MainActor
enum LineupSlotSafetyCoordinator {
    static func materializeLineupIfNeeded(
        game: Game,
        team: Team,
        modelContext: ModelContext
    ) throws -> LineupSlotMaterializationResult {
        let sourcePlayers = try resolvedSourcePlayers(game: game, team: team)
        let lineup = try resolvedOrCreatedLineup(game: game, team: team, players: sourcePlayers.players, source: sourcePlayers.source, modelContext: modelContext)
        lineup.everyoneHits = game.everyOneHits
        lineup.players = sourcePlayers.players

        for (index, player) in sourcePlayers.players.enumerated() {
            let slot = index + 1
            player.batOrder = slot
            if game.players.contains(where: { samePlayer($0, player) }) == false {
                game.players.append(player)
            }
            if firstColumnPlaceholder(for: player, slot: slot, game: game, team: team) == nil {
                let placeholder = Atbat(
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
                modelContext.insert(placeholder)
                game.atbats.append(placeholder)
            }
        }

        try modelContext.save()
        let slots = resolvedSlots(game: game, team: team, modelContext: modelContext)
        return LineupSlotMaterializationResult(source: sourcePlayers.source, lineup: lineup, slots: slots)
    }

    static func resolvedSlots(
        game: Game,
        team: Team,
        modelContext: ModelContext
    ) -> [LineupSlot] {
        let ambiguousLineups = game.lineups.filter { $0.game.ident == game.ident && $0.team.ident == team.ident }.count > 1
        let orderedPlaceholders = firstColumnPlaceholders(game: game, team: team)
        let slotCounts = Dictionary(grouping: orderedPlaceholders, by: { $0.batOrder }).mapValues(\.count)
        let playerCounts = Dictionary(grouping: orderedPlaceholders, by: { $0.player.identifier }).mapValues(\.count)

        return orderedPlaceholders.map { atbat in
            let reason: LineupSlotLockReason?
            if ambiguousLineups {
                reason = .ambiguousLineupState
            } else if slotCounts[atbat.batOrder, default: 0] > 1 {
                reason = .duplicateLineupSlot
            } else if playerCounts[atbat.player.identifier, default: 0] > 1 {
                reason = .duplicatePlayerAssignment
            } else {
                reason = lockReason(for: atbat, game: game, team: team, modelContext: modelContext)
            }

            return LineupSlot(
                battingOrder: atbat.batOrder,
                player: atbat.player,
                placeholderAtbat: atbat,
                editability: reason.map { .locked($0) } ?? .editable
            )
        }
    }

    static func editability(
        for slot: Int,
        game: Game,
        team: Team,
        modelContext: ModelContext
    ) -> LineupSlotEditability {
        guard let slot = resolvedSlots(game: game, team: team, modelContext: modelContext).first(where: { $0.battingOrder == slot }) else {
            return .locked(.missingPlaceholder)
        }
        return slot.editability
    }

    static func reassignPlayer(
        in slot: Int,
        to incomingPlayer: Player,
        game: Game,
        team: Team,
        modelContext: ModelContext
    ) throws -> LineupSlotReassignmentResult {
        let slots = resolvedSlots(game: game, team: team, modelContext: modelContext)
        guard let targetSlot = slots.first(where: { $0.battingOrder == slot }) else {
            throw LineupSlotSafetyError.slotNotFound(slot)
        }
        guard case .editable = targetSlot.editability else {
            if case .locked(let reason) = targetSlot.editability {
                throw LineupSlotSafetyError.slotLocked(reason)
            }
            throw LineupSlotSafetyError.slotLocked(.ambiguousLineupState)
        }
        guard incomingPlayer.team?.ident == team.ident else {
            throw LineupSlotSafetyError.incomingPlayerUnavailable(.incomingPlayerUnavailable)
        }
        guard samePlayer(incomingPlayer, targetSlot.player) == false else {
            return LineupSlotReassignmentResult(slot: targetSlot, outgoingPlayer: targetSlot.player, incomingPlayer: incomingPlayer)
        }
        guard incomingPlayerIsAvailable(incomingPlayer, targetSlot: targetSlot, allSlots: slots, game: game, team: team, modelContext: modelContext) else {
            throw LineupSlotSafetyError.incomingPlayerUnavailable(.incomingPlayerUnavailable)
        }

        let outgoingPlayer = targetSlot.player
        targetSlot.placeholderAtbat.player = incomingPlayer
        incomingPlayer.batOrder = slot
        outgoingPlayer.batOrder = 99

        if let lineup = game.lineups.first(where: { $0.game.ident == game.ident && $0.team.ident == team.ident }) {
            lineup.players = slots.map { lineupSlot in
                lineupSlot.battingOrder == slot ? incomingPlayer : lineupSlot.player
            }
        }

        if game.players.contains(where: { samePlayer($0, incomingPlayer) }) == false {
            game.players.append(incomingPlayer)
        }
        if playerIsStillReferencedInGame(outgoingPlayer, excluding: targetSlot.placeholderAtbat, game: game) == false {
            game.players.removeAll { samePlayer($0, outgoingPlayer) }
        }

        try modelContext.save()
        let refreshed = resolvedSlots(game: game, team: team, modelContext: modelContext).first(where: { $0.battingOrder == slot }) ?? targetSlot
        return LineupSlotReassignmentResult(slot: refreshed, outgoingPlayer: outgoingPlayer, incomingPlayer: incomingPlayer)
    }

    private static func resolvedSourcePlayers(game: Game, team: Team) throws -> (source: LineupSlotMaterializationResult.Source, players: [Player]) {
        let matchingLineups = game.lineups.filter { $0.game.ident == game.ident && $0.team.ident == team.ident }
        guard matchingLineups.count <= 1 else {
            throw LineupSlotSafetyError.ambiguousLineupState(.ambiguousLineupState)
        }
        if let lineup = matchingLineups.first, lineup.players.isEmpty == false {
            let players = try orderedUniquePlayers(lineup.players, everyoneHits: game.everyOneHits)
            return (.existingLineup, players)
        }

        let firstColumnAtbats = firstColumnPlaceholders(game: game, team: team)
        if firstColumnAtbats.isEmpty == false {
            let players = try orderedUniquePlayers(from: firstColumnAtbats, everyoneHits: game.everyOneHits)
            return (.firstColumnAtbats, players)
        }

        let rosterPlayers = try orderedUniquePlayers(team.players, everyoneHits: game.everyOneHits)
        guard rosterPlayers.isEmpty == false else {
            throw LineupSlotSafetyError.noEligibleRosterPlayers
        }
        return (.rosterBattingOrder, rosterPlayers)
    }

    private static func resolvedOrCreatedLineup(
        game: Game,
        team: Team,
        players: [Player],
        source: LineupSlotMaterializationResult.Source,
        modelContext: ModelContext
    ) throws -> Lineup {
        let matchingLineups = game.lineups.filter { $0.game.ident == game.ident && $0.team.ident == team.ident }
        guard matchingLineups.count <= 1 else {
            throw LineupSlotSafetyError.ambiguousLineupState(.ambiguousLineupState)
        }
        if let lineup = matchingLineups.first {
            return lineup
        }
        let lineup = Lineup(everyoneHits: game.everyOneHits, game: game, team: team, inning: 1, players: players)
        modelContext.insert(lineup)
        game.lineups.append(lineup)
        return lineup
    }

    private static func orderedUniquePlayers(_ players: [Player], everyoneHits: Bool) throws -> [Player] {
        let eligible = players
            .filter { player in
                if everyoneHits {
                    return player.batOrder > 0 && player.batOrder != 99
                }
                return (1...9).contains(player.batOrder)
            }
            .sorted {
                if $0.batOrder == $1.batOrder {
                    return $0.identifier.uuidString < $1.identifier.uuidString
                }
                return $0.batOrder < $1.batOrder
            }

        let slotCounts = Dictionary(grouping: eligible, by: { $0.batOrder }).mapValues(\.count)
        guard slotCounts.values.allSatisfy({ $0 == 1 }) else {
            throw LineupSlotSafetyError.ambiguousLineupState(.duplicateLineupSlot)
        }
        let playerCounts = Dictionary(grouping: eligible, by: { $0.identifier }).mapValues(\.count)
        guard playerCounts.values.allSatisfy({ $0 == 1 }) else {
            throw LineupSlotSafetyError.ambiguousLineupState(.duplicatePlayerAssignment)
        }
        return eligible
    }

    private static func orderedUniquePlayers(from atbats: [Atbat], everyoneHits: Bool) throws -> [Player] {
        let eligible = atbats
            .filter { atbat in
                if everyoneHits {
                    return atbat.batOrder > 0 && atbat.batOrder != 99
                }
                return (1...9).contains(atbat.batOrder)
            }
            .sorted {
                if $0.batOrder == $1.batOrder {
                    return $0.seq < $1.seq
                }
                return $0.batOrder < $1.batOrder
            }

        let slotCounts = Dictionary(grouping: eligible, by: { $0.batOrder }).mapValues(\.count)
        guard slotCounts.values.allSatisfy({ $0 == 1 }) else {
            throw LineupSlotSafetyError.ambiguousLineupState(.duplicateLineupSlot)
        }
        let playerCounts = Dictionary(grouping: eligible, by: { $0.player.identifier }).mapValues(\.count)
        guard playerCounts.values.allSatisfy({ $0 == 1 }) else {
            throw LineupSlotSafetyError.ambiguousLineupState(.duplicatePlayerAssignment)
        }
        return eligible.map(\.player)
    }

    private static func firstColumnPlaceholders(game: Game, team: Team) -> [Atbat] {
        game.atbats
            .filter { $0.game.ident == game.ident && $0.team.ident == team.ident && $0.inning <= 1 && $0.col == 1 && $0.batOrder != 99 }
            .sorted {
                if $0.batOrder == $1.batOrder {
                    return $0.seq < $1.seq
                }
                return $0.batOrder < $1.batOrder
            }
    }

    private static func firstColumnPlaceholder(for player: Player, slot: Int, game: Game, team: Team) -> Atbat? {
        firstColumnPlaceholders(game: game, team: team).first {
            $0.batOrder == slot && samePlayer($0.player, player)
        }
    }

    private static func lockReason(for placeholder: Atbat, game: Game, team: Team, modelContext: ModelContext) -> LineupSlotLockReason? {
        if pristinePlaceholder(placeholder, expectedSlot: placeholder.batOrder) == false {
            return .placeholderNotPristine
        }
        if playerHasOtherAtbat(placeholder.player, excluding: placeholder, game: game) {
            return .playerHasOtherAtbat
        }
        if acceptedLegacyEvidenceExists(for: placeholder, modelContext: modelContext) {
            return .acceptedScoringEvidence
        }
        let canonicalEvidenceState = acceptedCanonicalEvidenceExists(for: game, modelContext: modelContext)
        if canonicalEvidenceState == .locked {
            return .acceptedScoringEvidence
        } else if canonicalEvidenceState == .unverified {
            return .persistenceEvidenceUnavailable
        }
        if game.replaced.contains(where: { samePlayer($0, placeholder.player) }) || game.incomings.contains(where: { samePlayer($0, placeholder.player) }) {
            return .substitutionParticipation
        }
        if game.pitchers.contains(where: { $0.game.ident == game.ident && samePlayer($0.player, placeholder.player) }) {
            return .pitcherParticipation
        }
        return nil
    }

    private static func pristinePlaceholder(_ atbat: Atbat, expectedSlot: Int) -> Bool {
        atbat.result == "Result" &&
            atbat.maxbase == "No Bases" &&
            atbat.batOrder == expectedSlot &&
            atbat.outAt == "Safe" &&
            atbat.inning == 1 &&
            atbat.seq == expectedSlot &&
            atbat.col == 1 &&
            atbat.rbis == 0 &&
            atbat.outs == 0 &&
            atbat.sacFly == 0 &&
            atbat.sacBunt == 0 &&
            atbat.stolenBases == 0 &&
            atbat.earnedRun == true &&
            atbat.playRec.isEmpty &&
            atbat.endOfInning == false
    }

    private static func playerHasOtherAtbat(_ player: Player, excluding excludedAtbat: Atbat, game: Game) -> Bool {
        game.atbats.contains { atbat in
            atbat.ident != excludedAtbat.ident &&
                atbat.game.ident == game.ident &&
                samePlayer(atbat.player, player)
        }
    }

    private static func acceptedLegacyEvidenceExists(for atbat: Atbat, modelContext: ModelContext) -> Bool {
        do {
            let atbatIdentity = atbat.ident
            let gameIdentity = atbat.game.ident
            let acceptedDisposition = LegacyScoringOperationEvidenceConstants.acceptedDisposition
            let completedState = LegacyScoringOperationEvidenceConstants.completedState
            return try modelContext.fetch(FetchDescriptor<LegacyScoringOperationEvidenceRecord>(
                predicate: #Predicate {
                    $0.targetGameIdentity == gameIdentity &&
                    $0.targetAtbatIdentity == atbatIdentity &&
                    $0.disposition == acceptedDisposition &&
                    $0.completionState == completedState
                }
            )).isEmpty == false
        } catch {
            return true
        }
    }

    private enum CanonicalEvidenceState {
        case clear
        case locked
        case unverified
    }

    private static func acceptedCanonicalEvidenceExists(for game: Game, modelContext: ModelContext) -> CanonicalEvidenceState {
        do {
            let gameIdentity = game.ident
            let acceptedDisposition = CanonicalScoringPersistenceConstants.operationAcceptedDisposition
            let accepted = try modelContext.fetch(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>(
                predicate: #Predicate {
                    $0.gameIdentity == gameIdentity &&
                    $0.disposition == acceptedDisposition
                }
            ))
            return accepted.isEmpty ? .clear : .locked
        } catch {
            return .unverified
        }
    }

    private static func incomingPlayerIsAvailable(
        _ incomingPlayer: Player,
        targetSlot: LineupSlot,
        allSlots: [LineupSlot],
        game: Game,
        team: Team,
        modelContext: ModelContext
    ) -> Bool {
        guard incomingPlayer.team?.ident == team.ident else { return false }
        if allSlots.contains(where: { $0.battingOrder != targetSlot.battingOrder && samePlayer($0.player, incomingPlayer) }) {
            return false
        }
        if game.replaced.contains(where: { samePlayer($0, incomingPlayer) }) || game.incomings.contains(where: { samePlayer($0, incomingPlayer) }) {
            return false
        }
        if game.pitchers.contains(where: { $0.game.ident == game.ident && samePlayer($0.player, incomingPlayer) }) {
            return false
        }
        if game.atbats.contains(where: { $0.ident != targetSlot.placeholderAtbat.ident && $0.game.ident == game.ident && samePlayer($0.player, incomingPlayer) }) {
            return false
        }
        return acceptedCanonicalEvidenceExists(for: game, modelContext: modelContext) == .clear
    }

    private static func playerIsStillReferencedInGame(_ player: Player, excluding excludedAtbat: Atbat, game: Game) -> Bool {
        game.atbats.contains { $0.ident != excludedAtbat.ident && $0.game.ident == game.ident && samePlayer($0.player, player) } ||
            game.lineups.contains { lineup in
                lineup.game.ident == game.ident && lineup.players.contains(where: { samePlayer($0, player) })
            } ||
            game.pitchers.contains { $0.game.ident == game.ident && samePlayer($0.player, player) } ||
            game.replaced.contains(where: { samePlayer($0, player) }) ||
            game.incomings.contains(where: { samePlayer($0, player) })
    }

    private static func samePlayer(_ lhs: Player, _ rhs: Player) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

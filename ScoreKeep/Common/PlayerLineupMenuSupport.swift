import Foundation

enum PlayerLineupMenuItem: Identifiable {
    case addPlayer
    case player(Player, isSelected: Bool)

    var id: String {
        switch self {
        case .addPlayer:
            return "add-player"
        case .player(let player, _):
            return player.identifier.uuidString
        }
    }
}

enum PlayerLineupMenuContext {
    case startingLineupEditor
    case scorecardSwapCorrection
    case scorecardCorrection
}

enum PlayerLineupMenuSupport {
    static func playerMenuItems(
        from players: [Player],
        slots: [LineupSlot],
        targetSlot: LineupSlot,
        team: Team,
        context: PlayerLineupMenuContext = .startingLineupEditor
    ) -> [PlayerLineupMenuItem] {
        [.addPlayer] + selectableRosterPlayers(
            from: players,
            slots: slots,
            targetSlot: targetSlot,
            team: team,
            context: context
        ).map { player in
            .player(player, isSelected: player.identifier == targetSlot.player.identifier)
        }
    }

    static func selectableRosterPlayers(
        from players: [Player],
        slots: [LineupSlot],
        targetSlot: LineupSlot,
        team: Team,
        context: PlayerLineupMenuContext = .startingLineupEditor
    ) -> [Player] {
        let assignedPlayerIdentities = Set(slots
            .filter { $0.battingOrder != targetSlot.battingOrder }
            .map { $0.player.identifier })
        return players
            .filter { player in
                guard player.team?.ident == team.ident else { return false }
                switch context {
                case .startingLineupEditor:
                    return true
                case .scorecardSwapCorrection:
                    return true
                case .scorecardCorrection:
                    return player.identifier == targetSlot.player.identifier || assignedPlayerIdentities.contains(player.identifier) == false
                }
            }
            .sorted {
                if $0.batOrder == $1.batOrder {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.batOrder < $1.batOrder
            }
    }
}

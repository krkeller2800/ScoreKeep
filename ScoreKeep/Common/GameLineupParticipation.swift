import Foundation

struct GameLineupParticipation {
    struct Snapshot {
        let activePlayers: [Player]
        let replacedPlayers: [Player]
        let usedIncomingPlayers: [Player]
        let availableReplacementPlayers: [Player]
    }

    static func snapshot(game: Game, team: Team, rosterPlayers: [Player]) -> Snapshot {
        let roster = rosterPlayers.filter { $0.team?.ident == team.ident }
        let active = activeLineupPlayers(game: game, team: team)
        let activeIDs = Set(active.map(\.identifier))
        let replaced = players(in: game.replaced, for: team)
        let incoming = players(in: game.incomings, for: team)
        let replacedIDs = Set(replaced.map(\.identifier))
        let incomingIDs = Set(incoming.map(\.identifier))
        let pitcherIDs = Set(game.pitchers
            .filter { $0.game.ident == game.ident && $0.team.ident == team.ident }
            .map { $0.player.identifier })

        let unavailableIDs = activeIDs
            .union(replacedIDs)
            .union(incomingIDs)
            .union(pitcherIDs)
        let available = roster.filter { unavailableIDs.contains($0.identifier) == false }

        return Snapshot(
            activePlayers: active,
            replacedPlayers: replaced,
            usedIncomingPlayers: incoming,
            availableReplacementPlayers: available
        )
    }

    static func activeLineupPlayers(game: Game, team: Team) -> [Player] {
        let replacedIDs = Set(players(in: game.replaced, for: team).map(\.identifier))
        return firstColumnLineupRows(game: game, team: team)
            .filter { replacedIDs.contains($0.player.identifier) == false }
            .map(\.player)
    }

    static func substitutionEligibleActivePlayers(game: Game, team: Team) -> [Player] {
        let completedSlots = completedFirstPlateAppearanceSlots(game: game, team: team)
        let replacedIDs = Set(players(in: game.replaced, for: team).map(\.identifier))
        return firstColumnLineupRows(game: game, team: team)
            .filter {
                replacedIDs.contains($0.player.identifier) == false &&
                    completedSlots.contains($0.batOrder)
            }
            .map(\.player)
    }

    static func hasCompletedFirstPlateAppearance(slot: Int, game: Game, team: Team) -> Bool {
        completedFirstPlateAppearanceSlots(game: game, team: team).contains(slot)
    }

    static func completedFirstPlateAppearanceSlots(game: Game, team: Team) -> Set<Int> {
        Set(game.atbats.compactMap { atbat in
            guard atbat.game.ident == game.ident,
                  atbat.team.ident == team.ident,
                  atbat.batOrder != PlayerRosterBattingOrder.notHitting,
                  atbat.result != "Result",
                  atbat.result != "Pitch Hitter" else {
                return nil
            }
            return atbat.batOrder
        })
    }

    static func firstColumnLineupRows(game: Game, team: Team) -> [Atbat] {
        game.atbats
            .filter {
                $0.game.ident == game.ident &&
                    $0.team.ident == team.ident &&
                    $0.inning <= 1 &&
                    $0.col == 1 &&
                    $0.batOrder != PlayerRosterBattingOrder.notHitting
            }
            .sorted {
                if $0.batOrder != $1.batOrder {
                    return $0.batOrder < $1.batOrder
                }
                if $0.seq != $1.seq {
                    return $0.seq < $1.seq
                }
                if $0.player.identifier.uuidString != $1.player.identifier.uuidString {
                    return $0.player.identifier.uuidString < $1.player.identifier.uuidString
                }
                return $0.ident.uuidString < $1.ident.uuidString
            }
    }

    static func isActive(_ player: Player, game: Game, team: Team) -> Bool {
        activeLineupPlayers(game: game, team: team).contains { $0.identifier == player.identifier }
    }

    static func isAvailableReplacement(_ player: Player, game: Game, team: Team, rosterPlayers: [Player]) -> Bool {
        snapshot(game: game, team: team, rosterPlayers: rosterPlayers)
            .availableReplacementPlayers
            .contains { $0.identifier == player.identifier }
    }

    private static func players(in players: [Player], for team: Team) -> [Player] {
        players.filter { $0.team?.ident == team.ident }
    }
}

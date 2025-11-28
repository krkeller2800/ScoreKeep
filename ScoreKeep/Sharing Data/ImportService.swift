import Foundation
import SwiftData
import SwiftUI

@MainActor
struct ImportService {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Overwrite strategy

    enum OverwriteStrategy {
        case imported   // mirror ImportPlayersView.sharedPlayersBoss (overwrite with incoming non-blank)
        case current    // mirror ImportPlayersView.currentPlayersBoss (only fill blanks on existing)
    }

    // MARK: - Decode (bundle-seeded)

    func decodeSeededGame(from url: URL) throws -> [ShareGame] {
        // No security-scope needed for bundle URLs
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let loaded = try decoder.decode(ShareGame.self, from: data)
        return [loaded]
    }

    // MARK: - Decode (security-scoped external URLs)

    func decodePlayers(from url: URL) throws -> [SharePlayer] {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let loaded = try decoder.decode([SharePlayer].self, from: data)
        return loaded.sorted { $0.batOrder < $1.batOrder }
    }

    func decodeGame(from url: URL) throws -> [ShareGame] {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let loaded = try decoder.decode(ShareGame.self, from: data)
        return [loaded]
    }

    // MARK: - Import entry (players only)

    func importPlayers(_ sharePlayers: [SharePlayer], teamName: String, strategy: OverwriteStrategy) throws {
        let teams = try fetchTeams()
        try upsertSharedPlayers(sharedPlayers: sharePlayers, teamName: teamName, strategy: strategy, teamsCache: teams)
        try modelContext.save()
    }

    // MARK: - Import entry (games)

    func importShareGames(_ shareGames: [ShareGame]) throws {
        // Preload existing Teams and Games
        var teamsCache = try fetchTeams()
        var gamesCache = try fetchGames()

        for shareGame in shareGames {
            // Resolve both teams ONCE per game using normalized names
            let vNorm = normalizeName(shareGame.vteam.name)
            let hNorm = normalizeName(shareGame.hteam.name)

            let visiting = upsertTeam(from: shareGame.vteam, teamsCache: &teamsCache)
            let home = upsertTeam(from: shareGame.hteam, teamsCache: &teamsCache)

            // Build the per-game resolution map; only two teams are allowed
            var resolvedTeamsByName: [String: Team] = [:]
            resolvedTeamsByName[vNorm] = visiting
            resolvedTeamsByName[hNorm] = home

            // Ensure players for both teams are present/updated using "Imported" behavior
            try upsertSharedPlayers(sharedPlayers: shareGame.vteam.players, teamName: visiting.name, strategy: .imported, teamsCache: teamsCache)
            try upsertSharedPlayers(sharedPlayers: shareGame.hteam.players, teamName: home.name, strategy: .imported, teamsCache: teamsCache)

            // Normalized date duplicate check (keep your current behavior; add normalization fallback)
            let formatter = ISO8601DateFormatter()
            let incomingDate = formatter.date(from: shareGame.date)
            let existingDup = gamesCache.first { g in
                let sameTeams =
                    (g.vteam?.name.caseInsensitiveCompare(visiting.name) == .orderedSame) &&
                    (g.hteam?.name.caseInsensitiveCompare(home.name) == .orderedSame)
                guard sameTeams else { return false }
                if let gDate = formatter.date(from: g.date), let iDate = incomingDate {
                    return gDate == iDate
                } else {
                    return g.date == shareGame.date
                }
            }
            if existingDup != nil {
                // Skip this game if it already exists
                continue
            }

            // Create the game
            let currentGame = Game(
                date: shareGame.date,
                location: shareGame.location,
                highLights: shareGame.highLights,
                hscore: shareGame.hscore,
                vscore: shareGame.vscore,
                everyOneHits: shareGame.everyOneHits,
                numInnings: shareGame.numInnings,
                vteam: visiting,
                hteam: home
            )
            modelContext.insert(currentGame)

            // Import children using ONLY the resolvedTeamsByName map.
            try importAtbats(shareAtbats: shareGame.atbats, currentGame: currentGame, resolvedTeamsByName: resolvedTeamsByName)
            try importLineups(shareLineups: shareGame.lineups, currentGame: currentGame, resolvedTeamsByName: resolvedTeamsByName)
            try importPitchers(sharePitchers: shareGame.pitchers, currentGame: currentGame, resolvedTeamsByName: resolvedTeamsByName)
            try importReplaced(shareReplaced: shareGame.replaced, currentGame: currentGame, resolvedTeamsByName: resolvedTeamsByName)
            try importIncomings(shareIncomings: shareGame.incomings, currentGame: currentGame, resolvedTeamsByName: resolvedTeamsByName)

            // Cache the game to prevent duplicates in the same batch
            gamesCache.append(currentGame)
        }

        try modelContext.save()
    }

    // MARK: - Helpers

    private func fetchTeams() throws -> [Team] {
        try modelContext.fetch(FetchDescriptor<Team>())
    }

    private func fetchGames() throws -> [Game] {
        try modelContext.fetch(FetchDescriptor<Game>())
    }

    // Normalize names for consistent keying (trim + lowercase)
    private func normalizeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Centralized Team upsert by normalized name.
    // - One Team per name, case-insensitive.
    // - If an existing team has empty logo and incoming has non-empty, set it.
    // - Never overwrite an existing non-empty logo with empty data.
    // - Coach/details filled in only if empty and incoming has values.
    @discardableResult
    private func upsertTeam(from share: ShareTeam, teamsCache: inout [Team]) -> Team {
        let normalizedName = share.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = teamsCache.firstIndex(where: { $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame }) {
            let existing = teamsCache[idx]
            if (existing.logo?.isEmpty ?? true), !share.logo.isEmpty {
                existing.logo = share.logo
            }
            if existing.coach.isEmpty, !share.coach.isEmpty {
                existing.coach = share.coach
            }
            if existing.details.isEmpty, !share.details.isEmpty {
                existing.details = share.details
            }
            return existing
        } else {
            let newTeam = Team(name: normalizedName, coach: share.coach, details: share.details, logo: share.logo)
            modelContext.insert(newTeam)
            teamsCache.append(newTeam)
            return newTeam
        }
    }

    private func upsertSharedPlayers(sharedPlayers: [SharePlayer], teamName: String, strategy: OverwriteStrategy, teamsCache: [Team]) throws {
        // Resolve team from cache (this keeps behavior identical to your previous flow)
        let team: Team
        if let t = teamsCache.first(where: { $0.name == teamName }) {
            team = t
        } else {
            // If not found in the preloaded cache, create a new one using incoming metadata
            let coach = sharedPlayers.first?.team?.coach ?? ""
            let details = sharedPlayers.first?.team?.details ?? ""
            let logo = sharedPlayers.first?.team?.logo ?? Data()
            team = Team(name: teamName, coach: coach, details: details, logo: logo)
            modelContext.insert(team)
            try modelContext.save()
        }

        // Fetch existing players for team
        var fd = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.batOrder)])
        fd.predicate = #Predicate { $0.team?.name == teamName }
        let existing = try modelContext.fetch(fd)

        for sp in sharedPlayers {
            if let curr = existing.first(where: { $0.name == sp.name || $0.name.split(separator: " ").last == sp.name.split(separator: " ").last }) {
                switch strategy {
                case .imported:
                    if !sp.number.isEmpty { curr.number = sp.number }
                    if sp.batOrder < 50 { curr.batOrder = sp.batOrder }
                    if !sp.batDir.isEmpty { curr.batDir = sp.batDir }
                    if !sp.position.isEmpty { curr.position = sp.position }
                    if !sp.photo.isEmpty { curr.photo = sp.photo }
                    if curr.team == nil { curr.team = team }

                case .current:
                    if curr.number.isEmpty { curr.number = sp.number }
                    if curr.batOrder > 50 { curr.batOrder = sp.batOrder }
                    if curr.batDir.isEmpty { curr.batDir = sp.batDir }
                    if curr.position.isEmpty { curr.position = sp.position }
                    if (curr.photo?.isEmpty ?? true), !sp.photo.isEmpty {
                        curr.photo = sp.photo
                    }
                    if curr.team == nil { curr.team = team }
                }
            } else {
                let np = Player(name: sp.name, number: sp.number, position: sp.position, batDir: sp.batDir, batOrder: sp.batOrder, team: team)
                if !sp.photo.isEmpty { np.photo = sp.photo }
                modelContext.insert(np)
            }
        }
        try modelContext.save()
    }

    // MARK: - Child imports using ONLY resolvedTeamsByName

    private func importAtbats(shareAtbats: [ShareAtbat], currentGame: Game, resolvedTeamsByName: [String: Team]) throws {
        for sa in shareAtbats {
            let key = normalizeName(sa.team.name)
            guard let t = resolvedTeamsByName[key] else {
                throw ImportError.moreThanTwoTeamsInGame("Unexpected team '\(sa.team.name)' found in atbats for a game; only two teams per game are allowed.")
            }
            // Find or create player on that resolved team
            let player: Player
            if let p = t.players.first(where: { $0.name == sa.player.name }) {
                player = p
            } else {
                let np = Player(name: sa.player.name, number: sa.player.number, position: sa.player.position, batDir: sa.player.batDir, batOrder: sa.player.batOrder, team: t)
                if !sa.player.photo.isEmpty { np.photo = sa.player.photo }
                modelContext.insert(np)
                player = np
            }
            let newAtbat = Atbat(
                game: currentGame,
                team: t,
                player: player,
                result: sa.result,
                maxbase: sa.maxbase,
                batOrder: sa.batOrder,
                outAt: sa.outAt,
                inning: sa.inning,
                seq: sa.seq,
                col: sa.col,
                rbis: sa.rbis,
                outs: sa.outs,
                sacFly: sa.sacFly,
                sacBunt: sa.sacBunt,
                stolenBases: sa.stolenBases,
                earnedRun: sa.earnedRun,
                playRec: sa.playRec,
                endOfInning: sa.endOfInning
            )
            if !(sa.col > 1 && sa.result == "Result") {
                modelContext.insert(newAtbat)
                currentGame.atbats.append(newAtbat)
            }
        }
        try modelContext.save()
    }

    private func importLineups(shareLineups: [ShareLineup], currentGame: Game, resolvedTeamsByName: [String: Team]) throws {
        for sl in shareLineups {
            let key = normalizeName(sl.team.name)
            guard let team = resolvedTeamsByName[key] else {
                throw ImportError.moreThanTwoTeamsInGame("Unexpected team '\(sl.team.name)' found in lineups for a game; only two teams per game are allowed.")
            }
            var lineupPlayers: [Player] = []
            for sp in sl.players {
                if let p = team.players.first(where: { $0.name == sp.name }) {
                    lineupPlayers.append(p)
                } else {
                    let np = Player(name: sp.name, number: sp.number, position: sp.position, batDir: sp.batDir, batOrder: sp.batOrder, team: team)
                    if !sp.photo.isEmpty { np.photo = sp.photo }
                    modelContext.insert(np)
                    lineupPlayers.append(np)
                }
            }
            let lineup = Lineup(everyoneHits: sl.everyoneHits, game: currentGame, team: team, inning: sl.inning, players: lineupPlayers)
            modelContext.insert(lineup)
            currentGame.lineups.append(lineup)
        }
        try modelContext.save()
    }

    private func importPitchers(sharePitchers: [SharePitcher], currentGame: Game, resolvedTeamsByName: [String: Team]) throws {
        for sp in sharePitchers {
            let key = normalizeName(sp.team.name)
            guard let pitcherTeam = resolvedTeamsByName[key] else {
                throw ImportError.moreThanTwoTeamsInGame("Unexpected team '\(sp.team.name)' found in pitchers for a game; only two teams per game are allowed.")
            }

            // Resolve or create player on the resolved team
            let player: Player = pitcherTeam.players.first(where: { $0.name == sp.player.name }) ?? {
                let p = Player(name: sp.player.name, number: sp.player.number, position: sp.player.position, batDir: sp.player.batDir, batOrder: sp.player.batOrder, team: pitcherTeam)
                if !sp.player.photo.isEmpty { p.photo = sp.player.photo }
                modelContext.insert(p)
                return p
            }()

            let pitcher = Pitcher(
                player: player,
                team: pitcherTeam,
                game: currentGame,
                startInn: sp.startInn,
                sOuts: sp.sOuts,
                sBats: sp.sBats,
                endInn: sp.endInn,
                eOuts: sp.eOuts,
                eBats: sp.eBats,
                strikeOuts: sp.strikeOuts,
                walks: sp.walks,
                hits: sp.hits,
                runs: sp.runs,
                won: sp.won
            )
            modelContext.insert(pitcher)
            currentGame.pitchers.append(pitcher)
        }
        try modelContext.save()
    }

    private func importReplaced(shareReplaced: [SharePlayer], currentGame: Game, resolvedTeamsByName: [String: Team]) throws {
        for sp in shareReplaced {
            guard let tname = sp.team?.name else { continue }
            let key = normalizeName(tname)
            guard let team = resolvedTeamsByName[key] else {
                throw ImportError.moreThanTwoTeamsInGame("Unexpected team '\(tname)' found in replaced list for a game; only two teams per game are allowed.")
            }
            if let rplayer = team.players.first(where: { $0.name == sp.name }) {
                currentGame.replaced.append(rplayer)
            }
        }
    }

    private func importIncomings(shareIncomings: [SharePlayer], currentGame: Game, resolvedTeamsByName: [String: Team]) throws {
        for sp in shareIncomings {
            guard let tname = sp.team?.name else { continue }
            let key = normalizeName(tname)
            guard let team = resolvedTeamsByName[key] else {
                throw ImportError.moreThanTwoTeamsInGame("Unexpected team '\(tname)' found in incomings list for a game; only two teams per game are allowed.")
            }
            if let rplayer = team.players.first(where: { $0.name == sp.name }) {
                currentGame.incomings.append(rplayer)
            }
        }
    }

    // MARK: - Errors

    enum ImportError: Error, LocalizedError {
        case moreThanTwoTeamsInGame(String)

        var errorDescription: String? {
            switch self {
            case .moreThanTwoTeamsInGame(let msg):
                return msg
            }
        }
    }
}

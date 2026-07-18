import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

struct UnversionedCompatibilityIDs {
    static let visitingTeam = fixedUUID("00000000-0000-0000-0000-000000006101")
    static let homeTeam = fixedUUID("00000000-0000-0000-0000-000000006102")
    static let extraTeam = fixedUUID("00000000-0000-0000-0000-000000006103")
    static let visitingPlayerOne = fixedUUID("00000000-0000-0000-0000-000000006201")
    static let visitingPlayerTwo = fixedUUID("00000000-0000-0000-0000-000000006202")
    static let homePlayerOne = fixedUUID("00000000-0000-0000-0000-000000006203")
    static let homePlayerTwo = fixedUUID("00000000-0000-0000-0000-000000006204")
    static let extraPlayer = fixedUUID("00000000-0000-0000-0000-000000006205")
    static let gameOne = fixedUUID("00000000-0000-0000-0000-000000006301")
    static let gameTwo = fixedUUID("00000000-0000-0000-0000-000000006302")
    static let atbatOne = fixedUUID("00000000-0000-0000-0000-000000006401")
    static let atbatTwo = fixedUUID("00000000-0000-0000-0000-000000006402")
    static let atbatThree = fixedUUID("00000000-0000-0000-0000-000000006403")
    static let lineupOne = fixedUUID("00000000-0000-0000-0000-000000006501")
    static let lineupTwo = fixedUUID("00000000-0000-0000-0000-000000006502")
    static let pitcherOne = fixedUUID("00000000-0000-0000-0000-000000006601")
    static let pitcherTwo = fixedUUID("00000000-0000-0000-0000-000000006602")

    static func fixedUUID(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}

struct UnversionedStoreSnapshot: Equatable, Sendable {
    let fixtureIdentity: String
    let counts: CanonicalMigrationRecordCounts
    let gameIDs: [UUID]
    let teamIDs: [UUID]
    let playerIDs: [UUID]
    let atbatIDs: [UUID]
    let lineupIDs: [UUID]
    let pitcherIDs: [UUID]
    let gameSides: [UUID: [String: UUID]]
    let rosterMembership: [UUID: UUID]
    let gameParticipants: [UUID: [UUID]]
    let lineups: [UUID: [UUID]]
    let atbatOrder: [UUID]
    let atbatSequences: [Int]
    let scorecardColumns: [Int]
    let battingOrders: [Int]
    let atbatResults: [UUID: String]
    let atbatMaxbases: [UUID: String]
    let pitcherGameIDs: [UUID: UUID]
    let replacedPlayerIDsByGame: [UUID: [UUID]]
    let incomingPlayerIDsByGame: [UUID: [UUID]]
    let substitutionPairs: [[UUID]]
    let storedScores: [UUID: [Int]]
    let playerPhotoFingerprints: [UUID: String]
    let teamLogoFingerprints: [UUID: String]
    let unsupportedEvidence: [String]
    let ambiguousEvidence: [String]
    let allowanceProbe: CanonicalMigrationPurchaseAllowanceProbe
}

enum UnversionedStoreScenario: String, CaseIterable, Sendable {
    case empty
    case minimal
    case representative
    case edgeEvidence
}

enum IsolatedUnversionedProductionStoreSupportError: Error, Equatable {
    case missingStoreFamily(URL)
    case nonEmptyDestination(URL)
    case duplicateStableIdentity(model: String, identity: UUID, count: Int)
    case missingRecord(UUID)
}

@MainActor
enum IsolatedUnversionedProductionStoreSupport {
    static let tinyPhoto = Data([0x89, 0x50, 0x4E, 0x47, 0x06, 0x21])
    static let tinyLogo = Data([0x89, 0x50, 0x4E, 0x47, 0x06, 0x22])
    static let alternateTinyMedia = Data([0x89, 0x50, 0x4E, 0x47, 0x06, 0x23])

    static let allowanceProbe = CanonicalMigrationPurchaseAllowanceProbe(
        freeGameCreatesRemaining: 2,
        mlbDownloadUseCount: 0,
        entitlementMarker: "entitlement-probe-unchanged",
        purchaseMarker: "purchase-probe-unchanged"
    )

    static func temporaryStoreURL(_ name: String = UUID().uuidString) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepUnversionedCompatibility", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let existingContents = try fileManager.contentsOfDirectory(atPath: directory.path)
        guard existingContents.isEmpty else {
            throw IsolatedUnversionedProductionStoreSupportError.nonEmptyDestination(directory)
        }
        return directory.appendingPathComponent("ScoreKeep.store")
    }

    static func exactCurrentUnversionedProductionStyleContainer(url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: url)
        return try ModelContainer(for: Game.self, configurations: configuration)
    }

    static func proposedV1Container(url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V1.self)
        let configuration = ModelConfiguration("ProposedV1Recognition", schema: schema, url: url, allowsSave: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func proposedV2Container(url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V2.self)
        let configuration = ModelConfiguration("ProposedV2Migration", url: url, allowsSave: true)
        return try ModelContainer(for: schema, migrationPlan: ScoreKeepProposedTeamCreationEvidenceMigrationPlan.self, configurations: [configuration])
    }

    static func automaticCurrentModelsPlusEvidenceContainer(url: URL) throws -> ModelContainer {
        let schema = Schema([
            Game.self,
            Team.self,
            Player.self,
            Atbat.self,
            Lineup.self,
            Pitcher.self,
            TeamCreationOperationEvidenceRecord.self
        ])
        let configuration = ModelConfiguration("CurrentPlusEvidence", schema: schema, url: url, allowsSave: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func createSourceStore(_ scenario: UnversionedStoreScenario, name: String = UUID().uuidString) throws -> (url: URL, snapshot: UnversionedStoreSnapshot) {
        let url = try temporaryStoreURL(name)
        do {
            let container = try exactCurrentUnversionedProductionStyleContainer(url: url)
            let context = ModelContext(container)
            try populate(scenario, in: context)
            try context.save()
        }
        let reopened = try exactCurrentUnversionedProductionStyleContainer(url: url)
        return (url, try snapshot(from: reopened, fixtureIdentity: scenario.rawValue))
    }

    static func copyStoreFamily(from sourceURL: URL, name: String = UUID().uuidString) throws -> URL {
        let destinationURL = try temporaryStoreURL(name)
        let fileManager = FileManager.default
        let family = try storeFamilyURLs(for: sourceURL)
        guard family.isEmpty == false else { throw IsolatedUnversionedProductionStoreSupportError.missingStoreFamily(sourceURL) }
        for source in family {
            let destination = destinationURL.deletingLastPathComponent().appendingPathComponent(source.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }
        return destinationURL
    }

    static func storeFamilyURLs(for storeURL: URL) throws -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let baseName = storeURL.lastPathComponent
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        return names
            .filter { $0 == baseName || $0.hasPrefix(baseName + "-") }
            .map { directory.appendingPathComponent($0) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func storeFamilyFingerprint(for storeURL: URL) throws -> [String] {
        try storeFamilyURLs(for: storeURL).map { url in
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? NSNumber
            return "\(url.lastPathComponent):\(size?.intValue ?? -1)"
        }
    }

    static func snapshot(from container: ModelContainer, fixtureIdentity: String) throws -> UnversionedStoreSnapshot {
        let context = ModelContext(container)
        let games = try context.fetch(FetchDescriptor<Game>()).sorted { $0.ident.uuidString < $1.ident.uuidString }
        let teams = try context.fetch(FetchDescriptor<Team>()).sorted { $0.ident.uuidString < $1.ident.uuidString }
        let players = try context.fetch(FetchDescriptor<Player>()).sorted { $0.identifier.uuidString < $1.identifier.uuidString }
        let atbats = try context.fetch(FetchDescriptor<Atbat>()).sorted { lhs, rhs in
            if lhs.seq == rhs.seq { return lhs.ident.uuidString < rhs.ident.uuidString }
            return lhs.seq < rhs.seq
        }
        let lineups = try context.fetch(FetchDescriptor<Lineup>()).sorted { $0.ident.uuidString < $1.ident.uuidString }
        let pitchers = try context.fetch(FetchDescriptor<Pitcher>()).sorted { $0.ident.uuidString < $1.ident.uuidString }

        try validateUniqueStableIdentities(model: "Game", identities: games.map(\.ident))
        try validateUniqueStableIdentities(model: "Team", identities: teams.map(\.ident))
        try validateUniqueStableIdentities(model: "Player", identities: players.map(\.identifier))
        try validateUniqueStableIdentities(model: "Atbat", identities: atbats.map(\.ident))
        try validateUniqueStableIdentities(model: "Lineup", identities: lineups.map(\.ident))
        try validateUniqueStableIdentities(model: "Pitcher", identities: pitchers.map(\.ident))

        return UnversionedStoreSnapshot(
            fixtureIdentity: fixtureIdentity,
            counts: CanonicalMigrationRecordCounts(
                games: games.count,
                teams: teams.count,
                players: players.count,
                atbats: atbats.count,
                lineups: lineups.count,
                pitchers: pitchers.count
            ),
            gameIDs: games.map(\.ident),
            teamIDs: teams.map(\.ident),
            playerIDs: players.map(\.identifier),
            atbatIDs: atbats.map(\.ident),
            lineupIDs: lineups.map(\.ident),
            pitcherIDs: pitchers.map(\.ident),
            gameSides: Dictionary(uniqueKeysWithValues: games.map { game in
                var sides: [String: UUID] = [:]
                sides["home"] = game.hteam?.ident
                sides["visiting"] = game.vteam?.ident
                return (game.ident, sides)
            }),
            rosterMembership: Dictionary(uniqueKeysWithValues: players.compactMap { player in
                player.team.map { (player.identifier, $0.ident) }
            }),
            gameParticipants: Dictionary(uniqueKeysWithValues: games.map { game in
                (game.ident, game.players.map(\.identifier).sorted { $0.uuidString < $1.uuidString })
            }),
            lineups: Dictionary(uniqueKeysWithValues: lineups.map { lineup in
                (lineup.ident, lineup.players.map(\.identifier).sorted { $0.uuidString < $1.uuidString })
            }),
            atbatOrder: atbats.map(\.ident),
            atbatSequences: atbats.map(\.seq),
            scorecardColumns: atbats.map(\.col),
            battingOrders: atbats.map(\.batOrder),
            atbatResults: Dictionary(uniqueKeysWithValues: atbats.map { ($0.ident, $0.result) }),
            atbatMaxbases: Dictionary(uniqueKeysWithValues: atbats.map { ($0.ident, $0.maxbase) }),
            pitcherGameIDs: Dictionary(uniqueKeysWithValues: pitchers.map { ($0.ident, $0.game.ident) }),
            replacedPlayerIDsByGame: Dictionary(uniqueKeysWithValues: games.map { game in
                (game.ident, game.replaced.map(\.identifier))
            }),
            incomingPlayerIDsByGame: Dictionary(uniqueKeysWithValues: games.map { game in
                (game.ident, game.incomings.map(\.identifier))
            }),
            substitutionPairs: games.flatMap { game in
                zip(game.replaced, game.incomings).map { [$0.identifier, $1.identifier] }
            },
            storedScores: Dictionary(uniqueKeysWithValues: games.map { ($0.ident, [$0.hscore, $0.vscore]) }),
            playerPhotoFingerprints: Dictionary(uniqueKeysWithValues: players.map { ($0.identifier, fingerprint($0.photo)) }),
            teamLogoFingerprints: Dictionary(uniqueKeysWithValues: teams.map { ($0.ident, fingerprint($0.logo)) }),
            unsupportedEvidence: unsupportedEvidence(in: atbats),
            ambiguousEvidence: ambiguousEvidence(in: games, atbats: atbats),
            allowanceProbe: allowanceProbe
        )
    }

    static func evidenceCount(in container: ModelContainer) throws -> Int {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<TeamCreationOperationEvidenceRecord>()).count
    }

    static func occurrenceCounts(for identity: UUID, in container: ModelContainer) throws -> [String: Int] {
        let context = ModelContext(container)
        let games = try context.fetch(FetchDescriptor<Game>()).filter { $0.ident == identity }.count
        let teams = try context.fetch(FetchDescriptor<Team>()).filter { $0.ident == identity }.count
        let players = try context.fetch(FetchDescriptor<Player>()).filter { $0.identifier == identity }.count
        let atbats = try context.fetch(FetchDescriptor<Atbat>()).filter { $0.ident == identity }.count
        let lineups = try context.fetch(FetchDescriptor<Lineup>()).filter { $0.ident == identity }.count
        let pitchers = try context.fetch(FetchDescriptor<Pitcher>()).filter { $0.ident == identity }.count
        let evidence = try context.fetch(FetchDescriptor<TeamCreationOperationEvidenceRecord>()).filter { $0.targetTeamIdentity == identity }.count
        return [
            "Game": games,
            "Team": teams,
            "Player": players,
            "Atbat": atbats,
            "Lineup": lineups,
            "Pitcher": pitchers,
            "TeamCreationOperationEvidenceRecord.targetTeamIdentity": evidence
        ]
    }

    static func reconstruct(_ snapshot: UnversionedStoreSnapshot, into container: ModelContainer) throws {
        let context = ModelContext(container)
        let teamMap = makeTeams(snapshot: snapshot)
        let playerMap = makePlayers(snapshot: snapshot, teams: teamMap)
        let gameMap = makeGames(snapshot: snapshot, teams: teamMap, players: playerMap)
        for team in teamMap.values { context.insert(team) }
        for player in playerMap.values { context.insert(player) }
        for game in gameMap.values { context.insert(game) }
        for lineup in makeLineups(snapshot: snapshot, teams: teamMap, players: playerMap, games: gameMap) { context.insert(lineup) }
        for atbat in makeAtbats(snapshot: snapshot, teams: teamMap, players: playerMap, games: gameMap) { context.insert(atbat) }
        for pitcher in makePitchers(snapshot: snapshot, teams: teamMap, players: playerMap, games: gameMap) { context.insert(pitcher) }
        try context.save()
    }

    private static func populate(_ scenario: UnversionedStoreScenario, in context: ModelContext) throws {
        switch scenario {
        case .empty:
            return
        case .minimal:
            insertMinimalGraph(in: context)
        case .representative:
            insertRepresentativeGraph(in: context)
        case .edgeEvidence:
            insertEdgeEvidenceGraph(in: context)
        }
    }

    private static func insertMinimalGraph(in context: ModelContext) {
        let graph = makeMinimalGraph()
        insert(graph, in: context)
    }

    private static func insertRepresentativeGraph(in context: ModelContext) {
        let graph = makeRepresentativeGraph(includeEdgeEvidence: false)
        insert(graph, in: context)
    }

    private static func insertEdgeEvidenceGraph(in context: ModelContext) {
        let graph = makeRepresentativeGraph(includeEdgeEvidence: true)
        insert(graph, in: context)
    }

    private static func insert(_ graph: ([Team], [Player], [Game], [Lineup], [Atbat], [Pitcher]), in context: ModelContext) {
        for team in graph.0 { context.insert(team) }
        for player in graph.1 { context.insert(player) }
        for game in graph.2 { context.insert(game) }
        for lineup in graph.3 { context.insert(lineup) }
        for atbat in graph.4 { context.insert(atbat) }
        for pitcher in graph.5 { context.insert(pitcher) }
    }

    private static func makeMinimalGraph() -> ([Team], [Player], [Game], [Lineup], [Atbat], [Pitcher]) {
        let visitors = Team(ident: UnversionedCompatibilityIDs.visitingTeam, name: "Synthetic Visitors", coach: "Coach V", details: "Minimal source", logo: tinyLogo)
        let home = Team(ident: UnversionedCompatibilityIDs.homeTeam, name: "Synthetic Home", coach: "Coach H", details: "Minimal source")
        let batter = Player(identifier: UnversionedCompatibilityIDs.visitingPlayerOne, name: "Visitor One", number: "1", position: "SS", batDir: "R", batOrder: 1, team: visitors, photo: tinyPhoto)
        let runner = Player(identifier: UnversionedCompatibilityIDs.visitingPlayerTwo, name: "Visitor Two", number: "2", position: "CF", batDir: "L", batOrder: 2, team: visitors)
        let pitcherPlayer = Player(identifier: UnversionedCompatibilityIDs.homePlayerOne, name: "Home One", number: "11", position: "P", batDir: "R", batOrder: 1, team: home)
        let catcher = Player(identifier: UnversionedCompatibilityIDs.homePlayerTwo, name: "Home Two", number: "12", position: "C", batDir: "R", batOrder: 2, team: home)
        visitors.players = [batter, runner]
        home.players = [pitcherPlayer, catcher]
        let game = Game(ident: UnversionedCompatibilityIDs.gameOne, date: "2026-07-16", location: "Synthetic Field", highLights: "Minimal deterministic game", hscore: 0, vscore: 1, everyOneHits: false, numInnings: 6, vteam: visitors, hteam: home, players: [batter, runner, pitcherPlayer, catcher])
        visitors.games = [game]
        home.games = [game]
        let lineup = Lineup(ident: UnversionedCompatibilityIDs.lineupOne, everyoneHits: false, game: game, team: visitors, inning: 1, players: [batter, runner])
        let atbat = Atbat(ident: UnversionedCompatibilityIDs.atbatOne, game: game, team: visitors, player: batter, result: "Single", maxbase: "1", batOrder: 1, outAt: "", inning: 1.0, seq: 1, col: 1, rbis: 1, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0, earnedRun: true, playRec: "synthetic single", endOfInning: false)
        let pitcher = Pitcher(ident: UnversionedCompatibilityIDs.pitcherOne, player: pitcherPlayer, team: home, game: game, startInn: 1, sOuts: 0, sBats: 1, endInn: 1, eOuts: 0, eBats: 1, strikeOuts: 0, walks: 0, hits: 1, runs: 1, won: false)
        game.lineups = [lineup]
        game.atbats = [atbat]
        game.pitchers = [pitcher]
        batter.atbat = [atbat]
        return ([visitors, home], [batter, runner, pitcherPlayer, catcher], [game], [lineup], [atbat], [pitcher])
    }

    private static func makeRepresentativeGraph(includeEdgeEvidence: Bool) -> ([Team], [Player], [Game], [Lineup], [Atbat], [Pitcher]) {
        var minimal = makeMinimalGraph()
        let extra = Team(ident: UnversionedCompatibilityIDs.extraTeam, name: "Synthetic Utility", coach: "Coach U", details: includeEdgeEvidence ? "" : "Reusable players", logo: includeEdgeEvidence ? nil : alternateTinyMedia)
        let extraPlayer = Player(identifier: UnversionedCompatibilityIDs.extraPlayer, name: "Utility Player", number: "99", position: includeEdgeEvidence ? "??" : "RF", batDir: "S", batOrder: includeEdgeEvidence ? 1 : 9, team: extra, photo: includeEdgeEvidence ? nil : alternateTinyMedia)
        extra.players = [extraPlayer]
        let visitors = minimal.0[0]
        let home = minimal.0[1]
        let batter = minimal.1[0]
        let runner = minimal.1[1]
        let pitcherPlayer = minimal.1[2]
        let gameTwo = Game(ident: UnversionedCompatibilityIDs.gameTwo, date: "2026-07-17", location: "Synthetic Field Two", highLights: includeEdgeEvidence ? "Stored score mismatch" : "Representative deterministic game", hscore: includeEdgeEvidence ? 7 : 2, vscore: 3, everyOneHits: true, numInnings: 7, vteam: home, hteam: visitors, players: [batter, runner, pitcherPlayer, extraPlayer], replaced: [runner], incomings: includeEdgeEvidence ? [] : [extraPlayer])
        visitors.games.append(gameTwo)
        home.games.append(gameTwo)
        extra.games = [gameTwo]
        let lineupTwo = Lineup(ident: UnversionedCompatibilityIDs.lineupTwo, everyoneHits: true, game: gameTwo, team: visitors, inning: 2, players: [runner, batter, extraPlayer])
        let atbatTwo = Atbat(ident: UnversionedCompatibilityIDs.atbatTwo, game: gameTwo, team: visitors, player: runner, result: includeEdgeEvidence ? "UnsupportedResult" : "Double", maxbase: includeEdgeEvidence ? "FutureBase" : "2", batOrder: includeEdgeEvidence ? 1 : 2, outAt: "", inning: 2.0, seq: includeEdgeEvidence ? 1 : 2, col: 2, rbis: 2, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 1, earnedRun: true, playRec: "representative play", endOfInning: false)
        let atbatThree = Atbat(ident: UnversionedCompatibilityIDs.atbatThree, game: gameTwo, team: visitors, player: extraPlayer, result: "Out", maxbase: "0", batOrder: includeEdgeEvidence ? 1 : 9, outAt: "1", inning: 2.1, seq: includeEdgeEvidence ? 1 : 3, col: includeEdgeEvidence ? 2 : 3, rbis: 0, outs: 1, sacFly: 0, sacBunt: 0, stolenBases: 0, earnedRun: false, playRec: "ordering evidence", endOfInning: includeEdgeEvidence)
        let pitcherTwo = Pitcher(ident: UnversionedCompatibilityIDs.pitcherTwo, player: pitcherPlayer, team: home, game: gameTwo, startInn: 2, sOuts: 0, sBats: 2, endInn: 3, eOuts: 2, eBats: 5, strikeOuts: 2, walks: 1, hits: 2, runs: includeEdgeEvidence ? 7 : 2, won: true)
        gameTwo.lineups = [lineupTwo]
        gameTwo.atbats = [atbatTwo, atbatThree]
        gameTwo.pitchers = [pitcherTwo]
        runner.atbat.append(atbatTwo)
        extraPlayer.atbat = [atbatThree]
        minimal.0.append(extra)
        minimal.1.append(extraPlayer)
        minimal.2.append(gameTwo)
        minimal.3.append(lineupTwo)
        minimal.4.append(contentsOf: [atbatTwo, atbatThree])
        minimal.5.append(pitcherTwo)
        return minimal
    }

    private static func makeTeams(snapshot: UnversionedStoreSnapshot) -> [UUID: Team] {
        Dictionary(uniqueKeysWithValues: snapshot.teamIDs.map { id in
            let logoFingerprint = snapshot.teamLogoFingerprints[id]
            let logo: Data?
            if logoFingerprint == fingerprint(tinyLogo) {
                logo = tinyLogo
            } else if logoFingerprint == fingerprint(alternateTinyMedia) {
                logo = alternateTinyMedia
            } else {
                logo = nil
            }
            return (id, Team(ident: id, name: "Reconstructed \(id.uuidString.suffix(4))", coach: "Synthetic", details: "Converted", logo: logo))
        })
    }

    private static func makePlayers(snapshot: UnversionedStoreSnapshot, teams: [UUID: Team]) -> [UUID: Player] {
        Dictionary(uniqueKeysWithValues: snapshot.playerIDs.enumerated().map { offset, id in
            let team = snapshot.rosterMembership[id].flatMap { teams[$0] }
            let photoFingerprint = snapshot.playerPhotoFingerprints[id]
            let photo: Data?
            if photoFingerprint == fingerprint(tinyPhoto) {
                photo = tinyPhoto
            } else if photoFingerprint == fingerprint(alternateTinyMedia) {
                photo = alternateTinyMedia
            } else {
                photo = nil
            }
            let player = Player(identifier: id, name: "Reconstructed Player \(offset + 1)", number: "\(offset + 1)", position: "P", batDir: "R", batOrder: offset + 1, team: team, photo: photo)
            team?.players.append(player)
            return (id, player)
        })
    }

    private static func makeGames(snapshot: UnversionedStoreSnapshot, teams: [UUID: Team], players: [UUID: Player]) -> [UUID: Game] {
        Dictionary(uniqueKeysWithValues: snapshot.gameIDs.map { id in
            let sides = snapshot.gameSides[id] ?? [:]
            let scores = snapshot.storedScores[id] ?? [0, 0]
            let gamePlayers = (snapshot.gameParticipants[id] ?? []).compactMap { players[$0] }
            let replaced = (snapshot.replacedPlayerIDsByGame[id] ?? []).compactMap { players[$0] }
            let incoming = (snapshot.incomingPlayerIDsByGame[id] ?? []).compactMap { players[$0] }
            let game = Game(ident: id, date: "2026-07-16", location: "Reconstructed", highLights: "Converted", hscore: scores.first ?? 0, vscore: scores.dropFirst().first ?? 0, everyOneHits: true, numInnings: 7, vteam: sides["visiting"].flatMap { teams[$0] }, hteam: sides["home"].flatMap { teams[$0] }, players: gamePlayers, replaced: replaced, incomings: incoming)
            game.vteam?.games.append(game)
            game.hteam?.games.append(game)
            return (id, game)
        })
    }

    private static func makeLineups(snapshot: UnversionedStoreSnapshot, teams: [UUID: Team], players: [UUID: Player], games: [UUID: Game]) -> [Lineup] {
        snapshot.lineupIDs.enumerated().compactMap { offset, id in
            guard let game = games[snapshot.gameIDs[min(offset, max(snapshot.gameIDs.count - 1, 0))]], let team = game.vteam ?? game.hteam else { return nil }
            let lineupPlayers = (snapshot.lineups[id] ?? []).compactMap { players[$0] }
            let lineup = Lineup(ident: id, everyoneHits: true, game: game, team: team, inning: offset + 1, players: lineupPlayers)
            game.lineups.append(lineup)
            return lineup
        }
    }

    private static func makeAtbats(snapshot: UnversionedStoreSnapshot, teams: [UUID: Team], players: [UUID: Player], games: [UUID: Game]) -> [Atbat] {
        snapshot.atbatIDs.enumerated().compactMap { offset, id in
            guard let game = games[snapshot.gameIDs[min(offset, max(snapshot.gameIDs.count - 1, 0))]], let team = game.vteam ?? game.hteam, let player = players[snapshot.playerIDs[min(offset, max(snapshot.playerIDs.count - 1, 0))]] else { return nil }
            let result = snapshot.atbatResults[id] ?? "Single"
            let maxbase = snapshot.atbatMaxbases[id] ?? "1"
            let atbat = Atbat(ident: id, game: game, team: team, player: player, result: result, maxbase: maxbase, batOrder: snapshot.battingOrders[min(offset, max(snapshot.battingOrders.count - 1, 0))], outAt: "", inning: CGFloat(offset + 1), seq: snapshot.atbatSequences[min(offset, max(snapshot.atbatSequences.count - 1, 0))], col: snapshot.scorecardColumns[min(offset, max(snapshot.scorecardColumns.count - 1, 0))], rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
            game.atbats.append(atbat)
            player.atbat.append(atbat)
            return atbat
        }
    }

    private static func makePitchers(snapshot: UnversionedStoreSnapshot, teams: [UUID: Team], players: [UUID: Player], games: [UUID: Game]) -> [Pitcher] {
        snapshot.pitcherIDs.compactMap { id in
            guard let gameID = snapshot.pitcherGameIDs[id], let game = games[gameID], let team = game.hteam ?? game.vteam, let player = players.values.sorted(by: { $0.identifier.uuidString < $1.identifier.uuidString }).first else { return nil }
            let pitcher = Pitcher(ident: id, player: player, team: team, game: game, startInn: 1, sOuts: 0, sBats: 1, endInn: 1, eOuts: 1, eBats: 2, strikeOuts: 1, walks: 0, hits: 1, runs: 0, won: false)
            game.pitchers.append(pitcher)
            return pitcher
        }
    }

    private static func validateUniqueStableIdentities(model: String, identities: [UUID]) throws {
        let grouped = Dictionary(grouping: identities, by: { $0 })
        if let duplicate = grouped.first(where: { $0.value.count > 1 }) {
            throw IsolatedUnversionedProductionStoreSupportError.duplicateStableIdentity(
                model: model,
                identity: duplicate.key,
                count: duplicate.value.count
            )
        }
    }

    private static func unsupportedEvidence(in atbats: [Atbat]) -> [String] {
        atbats.flatMap { atbat in
            var evidence: [String] = []
            if atbat.result == "UnsupportedResult" { evidence.append("unsupported-result") }
            if atbat.maxbase == "FutureBase" { evidence.append("unsupported-maxbase") }
            return evidence
        }.sorted()
    }

    private static func ambiguousEvidence(in games: [Game], atbats: [Atbat]) -> [String] {
        var evidence: [String] = []
        if games.contains(where: { $0.replaced.count != $0.incomings.count }) {
            evidence.append("ambiguous-substitution-arrays")
        }
        let sequences = atbats.map(\.seq)
        if Set(sequences).count != sequences.count {
            evidence.append("duplicate-event-sequence")
        }
        return evidence.sorted()
    }

    private static func fingerprint(_ data: Data?) -> String {
        guard let data else { return "nil" }
        return "bytes-\(data.count)-sum-\(data.reduce(0) { $0 + Int($1) })"
    }
}

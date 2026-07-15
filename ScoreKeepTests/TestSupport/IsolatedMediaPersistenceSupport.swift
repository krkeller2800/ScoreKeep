import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

struct MediaPersistenceVerificationIDs: Hashable, Sendable {
    static let unrelatedTeam = fixedUUID("00000000-0000-0000-0000-000000003103")
    static let duplicatePlayer = fixedUUID("00000000-0000-0000-0000-000000003205")

    static func fixedUUID(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}

struct IsolatedMediaSnapshot: Hashable, Sendable {
    let playerPhotos: [UUID: Data?]
    let teamLogos: [UUID: Data?]
    let teamNames: [UUID: String]
    let playerNames: [UUID: String]
    let gameIDs: [UUID]
    let allowanceProbe: IsolatedPersistenceProbeState
}

struct IsolatedRecordInventorySnapshot: Hashable, Sendable {
    let gameIDs: [UUID]
    let teamIDs: [UUID]
    let playerIDs: [UUID]
    let atbatIDs: [UUID]
    let lineupIDs: [UUID]
    let pitcherIDs: [UUID]
    let playerPhotoByteCounts: [UUID: Int?]
    let teamLogoByteCounts: [UUID: Int?]
    let allowanceProbe: IsolatedPersistenceProbeState
}

struct IsolatedDeleteSnapshot: Hashable, Sendable {
    let gameIDs: [UUID]
    let teamIDs: [UUID]
    let playerIDs: [UUID]
    let atbatIDs: [UUID]
    let lineupIDs: [UUID]
    let pitcherIDs: [UUID]
    let gameHomeTeamIDs: [UUID: UUID?]
    let gameVisitingTeamIDs: [UUID: UUID?]
    let teamPlayerIDs: [UUID: [UUID]]
    let gamePlayerIDs: [UUID: [UUID]]
    let gameAtbatIDs: [UUID: [UUID]]
    let gameLineupIDs: [UUID: [UUID]]
    let gamePitcherIDs: [UUID: [UUID]]
    let gameReplacementPairs: [UUID: [IsolatedPersistenceReplacementPair]]
    let playerPhotoByteCounts: [UUID: Int?]
    let teamLogoByteCounts: [UUID: Int?]
}

enum IsolatedMediaPersistenceSupport {
    static let smallValidPNG = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
        0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
        0x44, 0xAE, 0x42, 0x60, 0x82
    ])
    static let alternateValidPNG = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x60, 0xF8, 0xCF, 0x00,
        0x00, 0x02, 0x02, 0x01, 0x00, 0x7D, 0xF9, 0x0B,
        0x4D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
        0x44, 0xAE, 0x42, 0x60, 0x82
    ])
    static let malformedBytes = Data([0x00, 0x01, 0x02, 0x03])

    @MainActor
    static func insertMediaGraph(into context: ModelContext, includeMedia: Bool = true) {
        _ = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(into: context)
        let players = (try? context.fetch(FetchDescriptor<Player>())) ?? []
        let teams = (try? context.fetch(FetchDescriptor<Team>())) ?? []
        players.first { $0.identifier == PersistenceVerificationIDs.visitingPlayerOne }?.photo = includeMedia ? smallValidPNG : nil
        players.first { $0.identifier == PersistenceVerificationIDs.visitingPlayerTwo }?.photo = includeMedia ? alternateValidPNG : nil
        teams.first { $0.ident == PersistenceVerificationIDs.visitingTeam }?.logo = includeMedia ? alternateValidPNG : nil
        teams.first { $0.ident == PersistenceVerificationIDs.homeTeam }?.logo = includeMedia ? smallValidPNG : nil
        context.insert(Team(ident: MediaPersistenceVerificationIDs.unrelatedTeam, name: "Unrelated Media Team", coach: "", details: "", logo: smallValidPNG))
    }

    @MainActor
    static func mediaSnapshot(from container: ModelContainer, allowanceProbe: IsolatedPersistenceProbeState = .init(freeGameCreatesRemaining: 2, mlbDownloadUseCount: 0, entitlementMarker: "unchanged")) throws -> IsolatedMediaSnapshot {
        let context = ModelContext(container)
        let players = try context.fetch(FetchDescriptor<Player>())
        let teams = try context.fetch(FetchDescriptor<Team>())
        let games = try context.fetch(FetchDescriptor<Game>())
        return IsolatedMediaSnapshot(
            playerPhotos: Dictionary(uniqueKeysWithValues: players.map { ($0.identifier, $0.photo) }),
            teamLogos: Dictionary(uniqueKeysWithValues: teams.map { ($0.ident, $0.logo) }),
            teamNames: Dictionary(uniqueKeysWithValues: teams.map { ($0.ident, $0.name) }),
            playerNames: Dictionary(uniqueKeysWithValues: players.map { ($0.identifier, $0.name) }),
            gameIDs: games.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            allowanceProbe: allowanceProbe
        )
    }

    @MainActor
    static func recordInventorySnapshot(
        from container: ModelContainer,
        allowanceProbe: IsolatedPersistenceProbeState = .init(freeGameCreatesRemaining: 2, mlbDownloadUseCount: 0, entitlementMarker: "unchanged")
    ) throws -> IsolatedRecordInventorySnapshot {
        let context = ModelContext(container)
        let games = try context.fetch(FetchDescriptor<Game>())
        let teams = try context.fetch(FetchDescriptor<Team>())
        let players = try context.fetch(FetchDescriptor<Player>())
        let atbats = try context.fetch(FetchDescriptor<Atbat>())
        let lineups = try context.fetch(FetchDescriptor<Lineup>())
        let pitchers = try context.fetch(FetchDescriptor<Pitcher>())

        return IsolatedRecordInventorySnapshot(
            gameIDs: games.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            teamIDs: teams.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            playerIDs: players.map(\.identifier).sorted { $0.uuidString < $1.uuidString },
            atbatIDs: atbats.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            lineupIDs: lineups.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            pitcherIDs: pitchers.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            playerPhotoByteCounts: Dictionary(uniqueKeysWithValues: players.map { ($0.identifier, $0.photo?.count) }),
            teamLogoByteCounts: Dictionary(uniqueKeysWithValues: teams.map { ($0.ident, $0.logo?.count) }),
            allowanceProbe: allowanceProbe
        )
    }

    @MainActor
    static func deleteSnapshot(from container: ModelContainer) throws -> IsolatedDeleteSnapshot {
        let context = ModelContext(container)
        let games = try context.fetch(FetchDescriptor<Game>())
        let teams = try context.fetch(FetchDescriptor<Team>())
        let players = try context.fetch(FetchDescriptor<Player>())
        let atbats = try context.fetch(FetchDescriptor<Atbat>())
        let lineups = try context.fetch(FetchDescriptor<Lineup>())
        let pitchers = try context.fetch(FetchDescriptor<Pitcher>())

        return IsolatedDeleteSnapshot(
            gameIDs: games.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            teamIDs: teams.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            playerIDs: players.map(\.identifier).sorted { $0.uuidString < $1.uuidString },
            atbatIDs: atbats.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            lineupIDs: lineups.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            pitcherIDs: pitchers.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            gameHomeTeamIDs: Dictionary(uniqueKeysWithValues: games.map { ($0.ident, $0.hteam?.ident) }),
            gameVisitingTeamIDs: Dictionary(uniqueKeysWithValues: games.map { ($0.ident, $0.vteam?.ident) }),
            teamPlayerIDs: Dictionary(uniqueKeysWithValues: teams.map { team in (team.ident, team.players.map(\.identifier).sorted { $0.uuidString < $1.uuidString }) }),
            gamePlayerIDs: Dictionary(uniqueKeysWithValues: games.map { game in (game.ident, game.players.map(\.identifier).sorted { $0.uuidString < $1.uuidString }) }),
            gameAtbatIDs: Dictionary(uniqueKeysWithValues: games.map { game in (game.ident, game.atbats.map(\.ident).sorted { $0.uuidString < $1.uuidString }) }),
            gameLineupIDs: Dictionary(uniqueKeysWithValues: games.map { game in (game.ident, game.lineups.map(\.ident).sorted { $0.uuidString < $1.uuidString }) }),
            gamePitcherIDs: Dictionary(uniqueKeysWithValues: games.map { game in (game.ident, game.pitchers.map(\.ident).sorted { $0.uuidString < $1.uuidString }) }),
            gameReplacementPairs: Dictionary(uniqueKeysWithValues: games.map { game in
                (game.ident, zip(game.replaced, game.incomings).map { IsolatedPersistenceReplacementPair(outgoing: $0.identifier, incoming: $1.identifier) })
            }),
            playerPhotoByteCounts: Dictionary(uniqueKeysWithValues: players.map { ($0.identifier, $0.photo?.count) }),
            teamLogoByteCounts: Dictionary(uniqueKeysWithValues: teams.map { ($0.ident, $0.logo?.count) })
        )
    }

    static func classifyMediaEvidence(ownerIdentity: UUID?, data: Data?) -> CanonicalPersistenceTransactionResult {
        if ownerIdentity == nil {
            return CanonicalPersistenceTransactionClassifier.relationshipFailure([
                CanonicalDomainValidator.finding(
                    "media.owner.missing",
                    concept: .player,
                    severity: .unresolved,
                    disposition: .unresolved,
                    summary: "Media evidence has no resolved owner."
                )
            ], operationIdentity: "media-owner")
        }
        guard let data else {
            return CanonicalPersistenceTransactionClassifier.noChange(operationIdentity: "media-missing")
        }
        if data.isEmpty {
            return CanonicalPersistenceTransactionClassifier.mediaFailure([
                CanonicalDomainValidator.finding(
                    "media.empty",
                    concept: .player,
                    severity: .warning,
                    disposition: .validWithWarnings,
                    summary: "Media evidence is empty and remains optional."
                )
            ], operationIdentity: "media-empty")
        }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return CanonicalPersistenceTransactionClassifier.success(operationIdentity: "media-valid")
        }
        return CanonicalPersistenceTransactionClassifier.mediaFailure([
            CanonicalDomainValidator.finding(
                "media.unsupportedOrMalformed",
                concept: .player,
                severity: .warning,
                disposition: .validWithWarnings,
                summary: "Media bytes are unsupported or malformed but baseball facts remain usable.",
                unsupported: true
            )
        ], operationIdentity: "media-malformed")
    }
}

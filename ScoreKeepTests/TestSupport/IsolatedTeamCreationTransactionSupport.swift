import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

struct TeamCreationTransactionVerificationIDs: Hashable, Sendable {
    static let createdTeam = fixedUUID("00000000-0000-0000-0000-000000004101")
    static let unrelatedTeam = fixedUUID("00000000-0000-0000-0000-000000004102")
    static let conflictingTeam = fixedUUID("00000000-0000-0000-0000-000000004103")
    static let unrelatedPlayer = fixedUUID("00000000-0000-0000-0000-000000004201")
    static let unrelatedGame = fixedUUID("00000000-0000-0000-0000-000000004301")
    static let unrelatedAtbat = fixedUUID("00000000-0000-0000-0000-000000004401")
    static let unrelatedLineup = fixedUUID("00000000-0000-0000-0000-000000004501")
    static let unrelatedPitcher = fixedUUID("00000000-0000-0000-0000-000000004601")

    static func fixedUUID(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}

struct IsolatedTeamCreationStoreSnapshot: Hashable, Sendable {
    let teams: [UUID: IsolatedTeamCreationTeamSnapshot]
    let playerIDs: [UUID]
    let gameIDs: [UUID]
    let atbatIDs: [UUID]
    let lineupIDs: [UUID]
    let pitcherIDs: [UUID]
    let gameHomeTeamIDs: [UUID: UUID?]
    let gameVisitingTeamIDs: [UUID: UUID?]
    let teamPlayerIDs: [UUID: [UUID]]
    let teamGameIDs: [UUID: [UUID]]
    let gamePlayerIDs: [UUID: [UUID]]
    let allowanceProbe: CanonicalTeamCreationPurchaseAllowanceProbe
}

struct IsolatedTeamCreationTeamSnapshot: Hashable, Sendable {
    let identity: UUID
    let name: String
    let coach: String
    let details: String
    let logoByteCount: Int?
}

@MainActor
enum IsolatedTeamCreationTransactionSupport {
    nonisolated static let baselineProbe = CanonicalTeamCreationPurchaseAllowanceProbe(
        purchaseMarker: "purchase-unchanged",
        entitlementMarker: "entitlement-unchanged",
        freeGameCreatesRemaining: 2,
        mlbDownloadUseCount: 0
    )

    static func request(
        operationIdentity: String = "team-create-op-001",
        teamIdentity: UUID = TeamCreationTransactionVerificationIDs.createdTeam,
        teamName: String = "Isolated Falcons",
        coach: String = "Coach One",
        details: String = "Simple isolated team",
        expectedDuplicatePolicy: CanonicalTeamCreationDuplicatePolicy = .rejectConflicts,
        knownInvocationFingerprints: [String: CanonicalTeamCreationRequestFingerprint] = [:],
        unsupportedEvidenceFields: [String] = [],
        beforeProbe: CanonicalTeamCreationPurchaseAllowanceProbe = baselineProbe,
        afterProbe: CanonicalTeamCreationPurchaseAllowanceProbe = baselineProbe,
        gateState: CanonicalTeamCreationGateState = .readyForIsolatedAdapter
    ) -> CanonicalTeamCreationRequest {
        CanonicalTeamCreationRequest(
            operationIdentity: operationIdentity,
            teamIdentity: teamIdentity,
            teamName: teamName,
            coach: coach,
            details: details,
            expectedDuplicatePolicy: expectedDuplicatePolicy,
            knownInvocationFingerprints: knownInvocationFingerprints,
            unsupportedEvidenceFields: unsupportedEvidenceFields,
            beforeProbe: beforeProbe,
            afterProbe: afterProbe,
            gateState: gateState
        )
    }

    static func adapter(
        for environment: IsolatedPersistenceEnvironment,
        injectedFailures: Set<CanonicalTeamCreationInjectedFailure> = []
    ) -> CanonicalTeamCreationTransactionAdapter {
        CanonicalTeamCreationTransactionAdapter(
            container: environment.container,
            dependencies: CanonicalTeamCreationTransactionDependencies(injectedFailures: injectedFailures)
        )
    }

    static func insertUnrelatedGraph(into context: ModelContext) {
        let team = Team(
            ident: TeamCreationTransactionVerificationIDs.unrelatedTeam,
            name: "Unrelated Team",
            coach: "Unrelated Coach",
            details: "Unrelated Details",
            logo: IsolatedMediaPersistenceSupport.smallValidPNG
        )
        let player = Player(
            identifier: TeamCreationTransactionVerificationIDs.unrelatedPlayer,
            name: "Unrelated Player",
            number: "9",
            position: "SS",
            batDir: "R",
            batOrder: 1,
            team: team,
            photo: IsolatedMediaPersistenceSupport.alternateValidPNG
        )
        let game = Game(
            ident: TeamCreationTransactionVerificationIDs.unrelatedGame,
            date: "2026-07-15T12:00:00Z",
            location: "Unrelated Field",
            highLights: "Preserve me",
            hscore: 0,
            vscore: 0,
            everyOneHits: false,
            numInnings: 7,
            vteam: team,
            hteam: nil,
            players: [player]
        )
        let atbat = Atbat(
            ident: TeamCreationTransactionVerificationIDs.unrelatedAtbat,
            game: game,
            team: team,
            player: player,
            result: "Single",
            maxbase: "First",
            batOrder: 1,
            outAt: "",
            inning: 1,
            seq: 1,
            col: 3,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
        let lineup = Lineup(
            ident: TeamCreationTransactionVerificationIDs.unrelatedLineup,
            everyoneHits: false,
            game: game,
            team: team,
            inning: 1,
            players: [player]
        )
        let pitcher = Pitcher(
            ident: TeamCreationTransactionVerificationIDs.unrelatedPitcher,
            player: player,
            team: team,
            game: game,
            startInn: 1,
            sOuts: 0,
            sBats: 0
        )
        team.players = [player]
        team.games = [game]
        game.atbats = [atbat]
        game.lineups = [lineup]
        game.pitchers = [pitcher]
        context.insert(team)
    }

    static func insertExistingMatchingTeam(_ request: CanonicalTeamCreationRequest, into context: ModelContext) {
        context.insert(Team(
            ident: request.teamIdentity,
            name: request.teamName.trimmingCharacters(in: .whitespacesAndNewlines),
            coach: request.coach,
            details: request.details
        ))
    }

    static func insertExistingConflictingTeam(_ request: CanonicalTeamCreationRequest, into context: ModelContext) {
        context.insert(Team(
            ident: request.teamIdentity,
            name: "Conflicting Team",
            coach: request.coach,
            details: request.details
        ))
    }

    static func snapshot(
        from container: ModelContainer,
        allowanceProbe: CanonicalTeamCreationPurchaseAllowanceProbe = baselineProbe
    ) throws -> IsolatedTeamCreationStoreSnapshot {
        let context = ModelContext(container)
        let teams = try context.fetch(FetchDescriptor<Team>())
        let players = try context.fetch(FetchDescriptor<Player>())
        let games = try context.fetch(FetchDescriptor<Game>())
        let atbats = try context.fetch(FetchDescriptor<Atbat>())
        let lineups = try context.fetch(FetchDescriptor<Lineup>())
        let pitchers = try context.fetch(FetchDescriptor<Pitcher>())

        return IsolatedTeamCreationStoreSnapshot(
            teams: Dictionary(uniqueKeysWithValues: teams.map { team in
                (team.ident, IsolatedTeamCreationTeamSnapshot(
                    identity: team.ident,
                    name: team.name,
                    coach: team.coach,
                    details: team.details,
                    logoByteCount: team.logo?.count
                ))
            }),
            playerIDs: players.map(\.identifier).sorted { $0.uuidString < $1.uuidString },
            gameIDs: games.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            atbatIDs: atbats.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            lineupIDs: lineups.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            pitcherIDs: pitchers.map(\.ident).sorted { $0.uuidString < $1.uuidString },
            gameHomeTeamIDs: Dictionary(uniqueKeysWithValues: games.map { ($0.ident, $0.hteam?.ident) }),
            gameVisitingTeamIDs: Dictionary(uniqueKeysWithValues: games.map { ($0.ident, $0.vteam?.ident) }),
            teamPlayerIDs: Dictionary(uniqueKeysWithValues: teams.map { team in (team.ident, team.players.map(\.identifier).sorted { $0.uuidString < $1.uuidString }) }),
            teamGameIDs: Dictionary(uniqueKeysWithValues: teams.map { team in (team.ident, team.games.map(\.ident).sorted { $0.uuidString < $1.uuidString }) }),
            gamePlayerIDs: Dictionary(uniqueKeysWithValues: games.map { game in (game.ident, game.players.map(\.identifier).sorted { $0.uuidString < $1.uuidString }) }),
            allowanceProbe: allowanceProbe
        )
    }

    static func assertOnlyCreatedTeamChanged(
        before: IsolatedTeamCreationStoreSnapshot,
        after: IsolatedTeamCreationStoreSnapshot,
        request: CanonicalTeamCreationRequest
    ) {
        var expectedTeams = before.teams
        expectedTeams[request.teamIdentity] = IsolatedTeamCreationTeamSnapshot(
            identity: request.teamIdentity,
            name: request.teamName.trimmingCharacters(in: .whitespacesAndNewlines),
            coach: request.coach,
            details: request.details,
            logoByteCount: nil
        )

        #expect(after.teams == expectedTeams)
        #expect(after.playerIDs == before.playerIDs)
        #expect(after.gameIDs == before.gameIDs)
        #expect(after.atbatIDs == before.atbatIDs)
        #expect(after.lineupIDs == before.lineupIDs)
        #expect(after.pitcherIDs == before.pitcherIDs)
        #expect(after.gameHomeTeamIDs == before.gameHomeTeamIDs)
        #expect(after.gameVisitingTeamIDs == before.gameVisitingTeamIDs)
        #expect(after.teamPlayerIDs[request.teamIdentity] == [])
        #expect(after.teamGameIDs[request.teamIdentity] == [])
        #expect(after.gamePlayerIDs == before.gamePlayerIDs)
        #expect(after.allowanceProbe == before.allowanceProbe)
    }
}

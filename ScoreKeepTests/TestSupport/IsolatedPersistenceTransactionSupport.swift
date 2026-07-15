import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
struct IsolatedPersistenceSaveBoundary {
    typealias SaveAction = (ModelContext) throws -> Void

    let saveAction: SaveAction

    init(saveAction: @escaping SaveAction = { context in try context.save() }) {
        self.saveAction = saveAction
    }

    func apply(
        operationIdentity: String,
        context: ModelContext,
        validationFindings: [CanonicalValidationFinding] = [],
        warnings: [CanonicalValidationFinding] = [],
        affectedRecordIdentities: [String] = [],
        mutate: () throws -> Void
    ) -> CanonicalPersistenceTransactionResult {
        guard validationFindings.isEmpty else {
            return CanonicalPersistenceTransactionClassifier.validationRejected(validationFindings, operationIdentity: operationIdentity)
        }

        do {
            try mutate()
            try saveAction(context)
            if warnings.isEmpty {
                return CanonicalPersistenceTransactionClassifier.success(
                    operationIdentity: operationIdentity,
                    affectedRecordIdentities: affectedRecordIdentities
                )
            }
            return CanonicalPersistenceTransactionClassifier.successWithWarnings(warnings, operationIdentity: operationIdentity)
        } catch {
            return CanonicalPersistenceTransactionClassifier.saveFailed(
                [CanonicalDomainValidator.finding(
                    "persistence.save.injectedFailure",
                    concept: .game,
                    severity: .rejection,
                    disposition: .rejected,
                    summary: "The isolated save boundary reported a deterministic save failure."
                )],
                operationIdentity: operationIdentity
            )
        }
    }
}

struct IsolatedPersistenceProbeState: Hashable, Sendable {
    var freeGameCreatesRemaining: Int
    var mlbDownloadUseCount: Int
    var entitlementMarker: String
}

enum IsolatedPersistenceInjectedSaveError: Error {
    case deterministicFailure
}

struct PersistenceVerificationIDs: Hashable, Sendable {
    static let visitingTeam = fixedUUID("00000000-0000-0000-0000-000000003101")
    static let homeTeam = fixedUUID("00000000-0000-0000-0000-000000003102")
    static let visitingPlayerOne = fixedUUID("00000000-0000-0000-0000-000000003201")
    static let visitingPlayerTwo = fixedUUID("00000000-0000-0000-0000-000000003202")
    static let homePlayerOne = fixedUUID("00000000-0000-0000-0000-000000003203")
    static let homePlayerTwo = fixedUUID("00000000-0000-0000-0000-000000003204")
    static let game = fixedUUID("00000000-0000-0000-0000-000000003301")
    static let eventOne = fixedUUID("00000000-0000-0000-0000-000000003401")
    static let eventTwo = fixedUUID("00000000-0000-0000-0000-000000003402")
    static let eventThree = fixedUUID("00000000-0000-0000-0000-000000003403")
    static let lineup = fixedUUID("00000000-0000-0000-0000-000000003501")
    static let pitcherOne = fixedUUID("00000000-0000-0000-0000-000000003601")
    static let pitcherTwo = fixedUUID("00000000-0000-0000-0000-000000003602")

    static func fixedUUID(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}

struct IsolatedPersistenceGraphIDs: Hashable, Sendable {
    let gameID: UUID
    let visitingTeamID: UUID
    let homeTeamID: UUID
    let playerIDs: [UUID]
    let eventIDs: [UUID]
    let lineupID: UUID
    let pitcherIDs: [UUID]
}

struct IsolatedPersistenceReplacementPair: Hashable, Sendable {
    let outgoing: UUID
    let incoming: UUID
}

struct IsolatedPersistenceReloadSnapshot: Hashable, Sendable {
    let gameID: UUID
    let date: String
    let location: String
    let homeTeamID: UUID?
    let visitingTeamID: UUID?
    let playerIDs: [UUID]
    let atbatIDsBySequence: [UUID]
    let eventSequences: [Int]
    let scorecardColumnsBySequence: [Int]
    let battingOrdersBySequence: [Int]
    let lineupPlayerIDsByExplicitBattingOrder: [UUID]
    let pitcherIDsByAppearanceOrder: [UUID]
    let replacementPairIDs: [IsolatedPersistenceReplacementPair]
    let storedScore: CanonicalProjectedScore
    let interpretationDispositions: [CanonicalPersistedInterpretationDisposition]
}

@MainActor
enum IsolatedPersistenceRoundTripSupport {
    static func insertRepresentativeGame(
        into context: ModelContext,
        includeSecondEvent: Bool = true,
        includeSubstitution: Bool = true,
        reversedLineupArray: Bool = false
    ) -> IsolatedPersistenceGraphIDs {
        let visitingTeam = Team(ident: PersistenceVerificationIDs.visitingTeam, name: "Isolated Visitors", coach: "Visitor Coach", details: "Synthetic")
        let homeTeam = Team(ident: PersistenceVerificationIDs.homeTeam, name: "Isolated Home", coach: "Home Coach", details: "Synthetic")
        let visitorOne = Player(identifier: PersistenceVerificationIDs.visitingPlayerOne, name: "Visitor One", number: "1", position: "SS", batDir: "R", batOrder: 1, team: visitingTeam)
        let visitorTwo = Player(identifier: PersistenceVerificationIDs.visitingPlayerTwo, name: "Visitor Two", number: "2", position: "CF", batDir: "L", batOrder: 2, team: visitingTeam)
        let homeOne = Player(identifier: PersistenceVerificationIDs.homePlayerOne, name: "Home One", number: "11", position: "P", batDir: "R", batOrder: 1, team: homeTeam)
        let homeTwo = Player(identifier: PersistenceVerificationIDs.homePlayerTwo, name: "Home Two", number: "12", position: "RP", batDir: "R", batOrder: 2, team: homeTeam)
        let game = Game(
            ident: PersistenceVerificationIDs.game,
            date: "2026-07-15T12:00:00Z",
            location: "Isolated Verification Field",
            highLights: "Phase 3 representative persistence graph",
            hscore: 1,
            vscore: includeSecondEvent ? 1 : 0,
            everyOneHits: false,
            numInnings: 7,
            vteam: visitingTeam,
            hteam: homeTeam,
            players: [visitorOne, visitorTwo, homeOne, homeTwo]
        )
        let eventOne = Atbat(
            ident: PersistenceVerificationIDs.eventOne,
            game: game,
            team: visitingTeam,
            player: visitorOne,
            result: "Single",
            maxbase: "First",
            batOrder: 1,
            outAt: "",
            inning: 1.0,
            seq: 1,
            col: 3,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
        let eventTwo = Atbat(
            ident: PersistenceVerificationIDs.eventTwo,
            game: game,
            team: visitingTeam,
            player: visitorTwo,
            result: "Home Run",
            maxbase: "Home",
            batOrder: 2,
            outAt: "",
            inning: 1.0,
            seq: 2,
            col: 7,
            rbis: 1,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
        let lineupPlayers = reversedLineupArray ? [visitorTwo, visitorOne] : [visitorOne, visitorTwo]
        let lineup = Lineup(
            ident: PersistenceVerificationIDs.lineup,
            everyoneHits: false,
            game: game,
            team: visitingTeam,
            inning: 1,
            players: lineupPlayers
        )
        let pitcherOne = Pitcher(
            ident: PersistenceVerificationIDs.pitcherOne,
            player: homeOne,
            team: homeTeam,
            game: game,
            startInn: 1,
            sOuts: 0,
            sBats: 0,
            endInn: includeSecondEvent ? 1 : 0,
            eOuts: includeSecondEvent ? 0 : 0,
            eBats: includeSecondEvent ? 2 : 0
        )
        let pitcherTwo = Pitcher(
            ident: PersistenceVerificationIDs.pitcherTwo,
            player: homeTwo,
            team: homeTeam,
            game: game,
            startInn: 2,
            sOuts: 0,
            sBats: 0
        )

        visitingTeam.players = [visitorOne, visitorTwo]
        homeTeam.players = [homeOne, homeTwo]
        visitingTeam.games = [game]
        homeTeam.games = [game]
        game.atbats = includeSecondEvent ? [eventTwo, eventOne] : [eventOne]
        game.lineups = [lineup]
        game.pitchers = includeSecondEvent ? [pitcherTwo, pitcherOne] : [pitcherOne]
        if includeSubstitution {
            game.replaced = [visitorOne]
            game.incomings = [visitorTwo]
        }

        context.insert(visitingTeam)
        context.insert(homeTeam)
        context.insert(visitorOne)
        context.insert(visitorTwo)
        context.insert(homeOne)
        context.insert(homeTwo)
        context.insert(game)
        context.insert(eventOne)
        context.insert(lineup)
        context.insert(pitcherOne)
        if includeSecondEvent {
            context.insert(eventTwo)
            context.insert(pitcherTwo)
        }

        return IsolatedPersistenceGraphIDs(
            gameID: game.ident,
            visitingTeamID: visitingTeam.ident,
            homeTeamID: homeTeam.ident,
            playerIDs: [visitorOne.identifier, visitorTwo.identifier, homeOne.identifier, homeTwo.identifier],
            eventIDs: includeSecondEvent ? [eventOne.ident, eventTwo.ident] : [eventOne.ident],
            lineupID: lineup.ident,
            pitcherIDs: includeSecondEvent ? [pitcherOne.ident, pitcherTwo.ident] : [pitcherOne.ident]
        )
    }

    static func reloadSnapshot(from container: ModelContainer) throws -> IsolatedPersistenceReloadSnapshot {
        let context = ModelContext(container)
        let games = try context.fetch(FetchDescriptor<Game>())
        let game = try #require(games.first)
        let atbats = try context.fetch(FetchDescriptor<Atbat>()).sorted { lhs, rhs in
            if lhs.seq != rhs.seq { return lhs.seq < rhs.seq }
            return lhs.ident.uuidString < rhs.ident.uuidString
        }
        let lineups = try context.fetch(FetchDescriptor<Lineup>())
        let pitchers = try context.fetch(FetchDescriptor<Pitcher>()).sorted { lhs, rhs in
            if lhs.startInn != rhs.startInn { return lhs.startInn < rhs.startInn }
            if lhs.sOuts != rhs.sOuts { return lhs.sOuts < rhs.sOuts }
            return lhs.ident.uuidString < rhs.ident.uuidString
        }
        let playerIDs = try context.fetch(FetchDescriptor<Player>()).map(\.identifier).sorted { $0.uuidString < $1.uuidString }
        let lineupPlayerIDs = lineups.first?.players.sorted { lhs, rhs in
            if lhs.batOrder != rhs.batOrder { return lhs.batOrder < rhs.batOrder }
            return lhs.identifier.uuidString < rhs.identifier.uuidString
        }.map(\.identifier) ?? []
        let substitutions = zip(game.replaced, game.incomings).map { outgoing, incoming in
            IsolatedPersistenceReplacementPair(outgoing: outgoing.identifier, incoming: incoming.identifier)
        }
        let homeSide = game.hteam.map {
            GameSideTeamParticipation(
                gameIdentity: .valid(game.ident),
                role: .home,
                resolution: .reusableTeam(ReusableCanonicalTeam(identity: .valid($0.ident)))
            )
        }
        let visitingSide = game.vteam.map {
            GameSideTeamParticipation(
                gameIdentity: .valid(game.ident),
                role: .visiting,
                resolution: .reusableTeam(ReusableCanonicalTeam(identity: .valid($0.ident)))
            )
        }
        var dispositions = [CanonicalPersistedEvidenceInterpreter.interpretGame(LegacyGameEvidenceSnapshot(game: game)).disposition]
        dispositions += lineups.map {
            CanonicalPersistedEvidenceInterpreter.interpretLineup(
                LegacyLineupEvidenceSnapshot(lineup: $0),
                homeSide: homeSide,
                visitingSide: visitingSide
            ).disposition
        }
        dispositions += atbats.map {
            CanonicalPersistedEvidenceInterpreter.interpretScoringEvent(LegacyAtbatEvidenceSnapshot(atbat: $0)).disposition
        }
        dispositions += pitchers.map {
            CanonicalPersistedEvidenceInterpreter.interpretPitcherAppearance(
                LegacyPitcherEvidenceSnapshot(pitcher: $0),
                homeSide: homeSide,
                visitingSide: visitingSide
            ).disposition
        }
        let substitutionInterpretations = CanonicalPersistedEvidenceInterpreter.interpretSubstitutions(
            incoming: game.incomings.map { LegacyPlayerEvidenceSnapshot(player: $0) },
            outgoing: game.replaced.map { LegacyPlayerEvidenceSnapshot(player: $0) },
            gameIdentity: .valid(game.ident)
        )
        dispositions += substitutionInterpretations.map(\.disposition)

        return IsolatedPersistenceReloadSnapshot(
            gameID: game.ident,
            date: game.date,
            location: game.location,
            homeTeamID: game.hteam?.ident,
            visitingTeamID: game.vteam?.ident,
            playerIDs: playerIDs,
            atbatIDsBySequence: atbats.map(\.ident),
            eventSequences: atbats.map(\.seq),
            scorecardColumnsBySequence: atbats.map(\.col),
            battingOrdersBySequence: atbats.map(\.batOrder),
            lineupPlayerIDsByExplicitBattingOrder: lineupPlayerIDs,
            pitcherIDsByAppearanceOrder: pitchers.map(\.ident),
            replacementPairIDs: substitutions,
            storedScore: CanonicalProjectedScore(home: game.hscore, visiting: game.vscore),
            interpretationDispositions: dispositions
        )
    }
}

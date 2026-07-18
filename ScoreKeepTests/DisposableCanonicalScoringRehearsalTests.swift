import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Disposable canonical scoring rehearsal")
struct DisposableCanonicalScoringRehearsalTests {
    @Test("file-backed canonical scoring transaction and replay rehearsal succeeds")
    func fileBackedCanonicalScoringTransactionAndReplayRehearsalSucceeds() throws {
        let storeRoot = try RehearsalEnvironment.temporaryStoreRoot()
        let storeURL = storeRoot.appendingPathComponent("Task325.store")
        defer { try? FileManager.default.removeItem(at: storeRoot) }

        let expectedReplay: CanonicalPersistedScoringReplayResult
        let legacyBeforeReplay: RehearsalLegacySnapshot
        let countsAfterWrite: RehearsalCounts
        let firstResult: CanonicalScoringTransactionResult
        let secondResult: CanonicalScoringTransactionResult
        let retryResult: CanonicalScoringTransactionResult
        let correctionResult: CanonicalScoringTransactionResult

        do {
            let writing = try RehearsalEnvironment(url: storeURL)
            let adapter = CanonicalScoringTransactionAdapter(container: writing.container)
            let firstRequest = RehearsalRequestFactory.scoringRequest(
                operationIdentity: RehearsalRequestFactory.operationOne,
                eventIdentity: RehearsalRequestFactory.eventOne,
                rawResult: "Single"
            )
            let secondRequest = RehearsalRequestFactory.scoringRequest(
                operationIdentity: RehearsalRequestFactory.operationTwo,
                eventIdentity: RehearsalRequestFactory.eventTwo,
                rawResult: "Walk"
            )

            firstResult = adapter.applyUsingDedicatedOperationContext(firstRequest)
            secondResult = adapter.applyUsingDedicatedOperationContext(secondRequest)
            let countsBeforeRetry = try RehearsalCounts(container: writing.container)
            retryResult = adapter.applyUsingDedicatedOperationContext(firstRequest)
            let countsAfterRetry = try RehearsalCounts(container: writing.container)
            let correctionRequest = RehearsalRequestFactory.correctionRequest(expectedFingerprint: firstResult.payloadFingerprint)
            correctionResult = adapter.applyUsingDedicatedOperationContext(correctionRequest)
            _ = adapter.applyUsingDedicatedOperationContext(RehearsalRequestFactory.otherGameScoringRequest())

            #expect(firstResult.transaction.disposition == .success)
            #expect(secondResult.transaction.disposition == .success)
            #expect(retryResult.transaction.disposition == .duplicateAlreadyApplied)
            #expect(retryResult.idempotencyResult == .exactRepeatAlreadyApplied)
            #expect(correctionResult.transaction.disposition == .success)
            #expect(firstResult.commitSequence == 1)
            #expect(secondResult.commitSequence == 2)
            #expect(correctionResult.commitSequence == 3)
            #expect(countsBeforeRetry == countsAfterRetry)

            legacyBeforeReplay = try RehearsalLegacySnapshot(container: writing.container)
            countsAfterWrite = try RehearsalCounts(container: writing.container)
            expectedReplay = CanonicalPersistedScoringReplayVerifier(container: writing.container)
                .replay(gameIdentity: RehearsalRequestFactory.gameA)
            #expect(expectedReplay.classification == .completeCanonicalHistory)
        }

        do {
            let reopened = try RehearsalEnvironment(url: storeURL, insertSyntheticGraph: false)
            let firstReplayAfterReopen = CanonicalPersistedScoringReplayVerifier(container: reopened.container)
                .replay(gameIdentity: RehearsalRequestFactory.gameA)
            let secondReplayAfterReopen = CanonicalPersistedScoringReplayVerifier(container: reopened.container)
                .replay(gameIdentity: RehearsalRequestFactory.gameA)
            let otherGameReplay = CanonicalPersistedScoringReplayVerifier(container: reopened.container)
                .replay(gameIdentity: RehearsalRequestFactory.gameB)
            let legacyAfterReplay = try RehearsalLegacySnapshot(container: reopened.container)
            let countsAfterReplay = try RehearsalCounts(container: reopened.container)

            #expect(firstReplayAfterReopen == expectedReplay)
            #expect(secondReplayAfterReopen == firstReplayAfterReopen)
            #expect(firstReplayAfterReopen.replayPerformedWrites == false)
            #expect(firstReplayAfterReopen.auditEntries.map(\.eventIdentity) == [
                RehearsalRequestFactory.eventOne,
                RehearsalRequestFactory.eventTwo,
                RehearsalRequestFactory.eventThree
            ])
            #expect(firstReplayAfterReopen.auditEntries.map(\.commitSequence) == [1, 2, 3])
            #expect(firstReplayAfterReopen.auditEntries.map(\.status) == [
                .originalSuperseded,
                .originalActive,
                .correctionReplacementAuditOnly
            ])
            #expect(firstReplayAfterReopen.effectiveEntries.map(\.eventIdentity) == [
                RehearsalRequestFactory.eventThree,
                RehearsalRequestFactory.eventTwo
            ])
            #expect(firstReplayAfterReopen.effectiveEntries.map(\.replaySequence) == [1, 2])
            #expect(firstReplayAfterReopen.correctionLinks.map(\.originalEventIdentity) == [RehearsalRequestFactory.eventOne])
            #expect(firstReplayAfterReopen.correctionLinks.map(\.replacementEventIdentity) == [RehearsalRequestFactory.eventThree])
            #expect(firstReplayAfterReopen.auditEntries.contains { $0.eventIdentity == RehearsalRequestFactory.otherGameEvent } == false)
            #expect(otherGameReplay.auditEntries.map(\.eventIdentity) == [RehearsalRequestFactory.otherGameEvent])
            #expect(countsAfterReplay == countsAfterWrite)
            #expect(legacyAfterReplay == legacyBeforeReplay)
            #expect(firstReplayAfterReopen.routingRemainsDisabled)
            #expect(firstReplayAfterReopen.managedObjectsEscaped == false)
            #expect(firstResult.routingRemainsDisabled)
            #expect(secondResult.routingRemainsDisabled)
            #expect(retryResult.routingRemainsDisabled)
            #expect(correctionResult.routingRemainsDisabled)
        }

        try FileManager.default.removeItem(at: storeRoot)
        #expect(FileManager.default.fileExists(atPath: storeRoot.path) == false)
    }

    @Test("rehearsal failures remain isolated and fail closed")
    func rehearsalFailuresRemainIsolatedAndFailClosed() throws {
        let storeRoot = try RehearsalEnvironment.temporaryStoreRoot()
        let storeURL = storeRoot.appendingPathComponent("Task325Failure.store")
        defer { try? FileManager.default.removeItem(at: storeRoot) }

        do {
            let environment = try RehearsalEnvironment(url: storeURL)
            let adapter = CanonicalScoringTransactionAdapter(container: environment.container)
            let first = adapter.applyUsingDedicatedOperationContext(RehearsalRequestFactory.scoringRequest(
                operationIdentity: RehearsalRequestFactory.operationOne,
                eventIdentity: RehearsalRequestFactory.eventOne,
                rawResult: "Single"
            ))
            let beforeFailure = try RehearsalCounts(container: environment.container)
            let legacyBeforeFailure = try RehearsalLegacySnapshot(container: environment.container)

            let conflict = adapter.applyUsingDedicatedOperationContext(RehearsalRequestFactory.scoringRequest(
                operationIdentity: RehearsalRequestFactory.operationOne,
                eventIdentity: RehearsalRequestFactory.eventTwo,
                rawResult: "Double"
            ))
            let missingTarget = adapter.applyUsingDedicatedOperationContext(RehearsalRequestFactory.correctionRequest(
                operationIdentity: RehearsalRequestFactory.operationThree,
                correctionIdentity: RehearsalRequestFactory.correctionOne,
                eventIdentity: RehearsalRequestFactory.eventThree,
                targetEventIdentity: RehearsalRequestFactory.missingEvent,
                expectedFingerprint: first.payloadFingerprint
            ))
            let replay = CanonicalPersistedScoringReplayVerifier(container: environment.container)
                .replay(gameIdentity: RehearsalRequestFactory.gameA)

            #expect(first.transaction.disposition == .success)
            #expect(conflict.transaction.disposition == .contradictory)
            #expect(conflict.idempotencyResult == .conflictingOperationIdentity)
            #expect(missingTarget.transaction.disposition == .validationRejected)
            #expect(missingTarget.validationFindings.contains { $0.code == "scoringTransaction.correctionTarget.notFound" })
            #expect(replay.classification == .completeCanonicalHistory)
            #expect(replay.auditEntries.map(\.eventIdentity) == [RehearsalRequestFactory.eventOne])
            #expect(try RehearsalCounts(container: environment.container) == beforeFailure)
            #expect(try RehearsalLegacySnapshot(container: environment.container) == legacyBeforeFailure)
        }

        try FileManager.default.removeItem(at: storeRoot)
        #expect(FileManager.default.fileExists(atPath: storeRoot.path) == false)
    }

    @Test("rehearsal source remains test-only and production routing stays Legacy")
    func rehearsalSourceRemainsTestOnlyAndProductionRoutingStaysLegacy() throws {
        let root = try StableIdentityAndOrderingTestSupport.repositoryRoot()
        let rehearsalSource = try String(
            contentsOf: root.appendingPathComponent("ScoreKeepTests/DisposableCanonicalScoringRehearsalTests.swift"),
            encoding: .utf8
        )
        let playersToScore = try String(contentsOf: root.appendingPathComponent("ScoreKeep/Disply graphics/PlayersToScoreView.swift"), encoding: .utf8)
        let scoreGame = try String(contentsOf: root.appendingPathComponent("ScoreKeep/Disply graphics/ScoreGameView.swift"), encoding: .utf8)
        let appSource = try String(contentsOf: root.appendingPathComponent("ScoreKeep/ScoreKeepApp.swift"), encoding: .utf8)
        let startup = try String(contentsOf: root.appendingPathComponent("ScoreKeep/Common/ScoreKeepProductionStartupHost.swift"), encoding: .utf8)
        let reportFiles = [
            "ScoreKeep/Content Views/ScoreContentView.swift",
            "ScoreKeep/Content Views/TeamContentView.swift",
            "ScoreKeep/Content Views/PlayerContentView.swift",
            "ScoreKeep/Content Views/PitcherContentView.swift"
        ]
        let reportAndSetupSources = try reportFiles.map {
            try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8)
        }

        #expect(rehearsalSource.contains("ScoreKeepProposedVersionedSchema." + "V2") == false)
        #expect(rehearsalSource.contains("ScoreKeepProposedCanonicalScoringStorage" + "MigrationPlan") == false)
        #expect(playersToScore.contains("CanonicalScoringTransactionAdapter") == false)
        #expect(scoreGame.contains("CanonicalScoringTransactionAdapter") == false)
        #expect(appSource.contains("ScoreKeepUnitTestHostIsolationView"))
        #expect(ScoreKeepLaunchIsolation.mode(
            arguments: [],
            commandLineArguments: [],
            environment: ["XCTestConfigurationFilePath": "/tmp/task325.xctestconfiguration"]
        ) == .unitTestHostIsolation)
        #expect(ScoreKeepLaunchIsolation.mode(
            arguments: [ScoreKeepLaunchIsolation.schemaDiagnosticArgument],
            commandLineArguments: [],
            environment: [:]
        ) == .schemaDiagnostic)
        #expect(ScoreKeepLaunchIsolation.mode(arguments: [], commandLineArguments: [], environment: [:]) == .production)
        #expect(startup.contains("CanonicalPersistedScoringReplayVerifier") == false)
        #expect(reportAndSetupSources.allSatisfy { $0.contains("CanonicalPersistedScoringReplayVerifier") == false })
        #expect(ScoreKeepProposedVersionedSchema.v1ModelNames.count == 6)
        #expect(ScoreKeepProposedVersionedSchema.v2AddedModelNames.count == 1)
        #expect(ScoreKeepProposedVersionedSchema.V3.models.count == 12)
        #expect(CanonicalScoringPersistenceModelBoundary.implementationModelNames.count == 5)
    }
}

private enum RehearsalRequestFactory {
    static let gameA = CanonicalGameStatePrimitivesTestSupport.gameA
    static let gameB = CanonicalGameStatePrimitivesTestSupport.gameB
    static let operationOne = fixedUUID("00000000-0000-0000-0000-000000032501")
    static let operationTwo = fixedUUID("00000000-0000-0000-0000-000000032502")
    static let operationThree = fixedUUID("00000000-0000-0000-0000-000000032503")
    static let operationFour = fixedUUID("00000000-0000-0000-0000-000000032504")
    static let eventOne = fixedUUID("00000000-0000-0000-0000-000000032511")
    static let eventTwo = fixedUUID("00000000-0000-0000-0000-000000032512")
    static let eventThree = fixedUUID("00000000-0000-0000-0000-000000032513")
    static let otherGameEvent = fixedUUID("00000000-0000-0000-0000-000000032514")
    static let missingEvent = fixedUUID("00000000-0000-0000-0000-000000032515")
    static let correctionOne = fixedUUID("00000000-0000-0000-0000-000000032521")

    static func scoringRequest(
        operationIdentity: UUID,
        eventIdentity: UUID,
        rawResult: String,
        gameIdentity: UUID = gameA
    ) -> CanonicalScoringTransactionRequest {
        CanonicalScoringTransactionRequest(
            operationIdentity: operationIdentity,
            command: command(rawResult: rawResult, eventIdentity: eventIdentity, gameIdentity: gameIdentity),
            inputState: state(gameIdentity: gameIdentity)
        )
    }

    static func correctionRequest(
        operationIdentity: UUID = operationThree,
        correctionIdentity: UUID = correctionOne,
        eventIdentity: UUID = eventThree,
        targetEventIdentity: UUID = eventOne,
        expectedFingerprint: String?
    ) -> CanonicalScoringTransactionRequest {
        CanonicalScoringTransactionRequest(
            operationIdentity: operationIdentity,
            operationMode: .correctionReplacement,
            command: command(rawResult: "Double", eventIdentity: eventIdentity, gameIdentity: gameA),
            inputState: state(gameIdentity: gameA),
            correctionIdentity: correctionIdentity,
            targetEventIdentity: targetEventIdentity,
            expectedTargetPayloadFingerprint: expectedFingerprint
        )
    }

    static func otherGameScoringRequest() -> CanonicalScoringTransactionRequest {
        scoringRequest(
            operationIdentity: operationFour,
            eventIdentity: otherGameEvent,
            rawResult: "Ground Out",
            gameIdentity: gameB
        )
    }

    private static func command(rawResult: String, eventIdentity: UUID, gameIdentity: UUID) -> CanonicalScoringCommand {
        CanonicalScoringCommandVocabulary.command(
            rawResult: rawResult,
            gameIdentity: .valid(gameIdentity),
            teamSide: .visiting,
            batter: ScoringCommandTestSupport.batter(),
            proposedEventIdentity: .valid(eventIdentity),
            source: .syntheticVerification
        )
    }

    private static func state(gameIdentity: UUID) -> CanonicalScoringCommandInputState {
        ScoringCommandTestSupport.state(
            game: CanonicalGameStatePrimitivesTestSupport.game(id: gameIdentity, lifecycle: .inProgress)
        )
    }

    private static func fixedUUID(_ rawValue: String) -> UUID {
        UUID(uuidString: rawValue)!
    }
}

@MainActor
private final class RehearsalEnvironment {
    let container: ModelContainer
    let context: ModelContext

    init(url: URL, insertSyntheticGraph: Bool = true) throws {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
        let configuration = ModelConfiguration("Task325DisposableRehearsal", schema: schema, url: url, allowsSave: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
        if insertSyntheticGraph {
            insertSyntheticLegacyGraph(into: context)
            try context.save()
        }
    }

    static func temporaryStoreRoot(_ name: String = UUID().uuidString) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepTask325CanonicalScoringRehearsal", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func insertSyntheticLegacyGraph(into context: ModelContext) {
        insertGameGraph(gameIdentity: RehearsalRequestFactory.gameA, location: "Task 3.25 Field", context: context)
        insertGameGraph(gameIdentity: RehearsalRequestFactory.gameB, location: "Task 3.25 Other Field", context: context)
    }

    private func insertGameGraph(gameIdentity: UUID, location: String, context: ModelContext) {
        let visitingTeam = Team(ident: fixedUUID(gameIdentity, suffix: "01"), name: "Task 3.25 Visitors", coach: "Synthetic Coach", details: "Disposable")
        let homeTeam = Team(ident: fixedUUID(gameIdentity, suffix: "02"), name: "Task 3.25 Home", coach: "Synthetic Coach", details: "Disposable")
        let visitorOne = Player(identifier: fixedUUID(gameIdentity, suffix: "11"), name: "Rehearsal Batter", number: "1", position: "SS", batDir: "R", batOrder: 1, team: visitingTeam)
        let visitorTwo = Player(identifier: fixedUUID(gameIdentity, suffix: "12"), name: "Rehearsal Runner", number: "2", position: "CF", batDir: "L", batOrder: 2, team: visitingTeam)
        let homePitcher = Player(identifier: fixedUUID(gameIdentity, suffix: "13"), name: "Rehearsal Pitcher", number: "9", position: "P", batDir: "R", batOrder: 1, team: homeTeam)
        let game = Game(
            ident: gameIdentity,
            date: "2026-07-18",
            location: location,
            highLights: "Task 3.25 disposable synthetic game",
            hscore: 0,
            vscore: 0,
            everyOneHits: false,
            numInnings: 7,
            vteam: visitingTeam,
            hteam: homeTeam,
            players: [visitorOne, visitorTwo, homePitcher]
        )
        let legacyAtbat = Atbat(
            ident: fixedUUID(gameIdentity, suffix: "21"),
            game: game,
            team: visitingTeam,
            player: visitorOne,
            result: "Result",
            maxbase: "No Bases",
            batOrder: 1,
            outAt: "Safe",
            inning: 1,
            seq: 1,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
        let lineup = Lineup(
            ident: fixedUUID(gameIdentity, suffix: "31"),
            everyoneHits: false,
            game: game,
            team: visitingTeam,
            inning: 1,
            players: [visitorOne, visitorTwo]
        )
        let pitcher = Pitcher(
            ident: fixedUUID(gameIdentity, suffix: "41"),
            player: homePitcher,
            team: homeTeam,
            game: game,
            startInn: 1,
            sOuts: 0,
            sBats: 0
        )

        visitingTeam.players = [visitorOne, visitorTwo]
        homeTeam.players = [homePitcher]
        visitingTeam.games = [game]
        homeTeam.games = [game]
        game.atbats = [legacyAtbat]
        game.lineups = [lineup]
        game.pitchers = [pitcher]

        [visitingTeam, homeTeam].forEach(context.insert)
        [visitorOne, visitorTwo, homePitcher].forEach(context.insert)
        context.insert(game)
        context.insert(legacyAtbat)
        context.insert(lineup)
        context.insert(pitcher)
    }

    private func fixedUUID(_ gameIdentity: UUID, suffix: String) -> UUID {
        let prefix = gameIdentity == RehearsalRequestFactory.gameA ? "00000000-0000-0000-0000-0000000326" : "00000000-0000-0000-0000-0000000327"
        return UUID(uuidString: prefix + suffix)!
    }
}

@MainActor
private struct RehearsalCounts: Equatable {
    let games: Int
    let teams: Int
    let players: Int
    let atbats: Int
    let lineups: Int
    let pitchers: Int
    let histories: Int
    let events: Int
    let payloads: Int
    let operations: Int
    let corrections: Int

    init(container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        games = try context.fetch(FetchDescriptor<Game>()).count
        teams = try context.fetch(FetchDescriptor<Team>()).count
        players = try context.fetch(FetchDescriptor<Player>()).count
        atbats = try context.fetch(FetchDescriptor<Atbat>()).count
        lineups = try context.fetch(FetchDescriptor<Lineup>()).count
        pitchers = try context.fetch(FetchDescriptor<Pitcher>()).count
        histories = try context.fetch(FetchDescriptor<CanonicalGameHistoryRecord>()).count
        events = try context.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>()).count
        payloads = try context.fetch(FetchDescriptor<CanonicalScoringEventPayloadRecord>()).count
        operations = try context.fetch(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>()).count
        corrections = try context.fetch(FetchDescriptor<CanonicalScoringCorrectionRecord>()).count
    }
}

@MainActor
private struct RehearsalLegacySnapshot: Equatable {
    let games: [GameSummary]
    let teamIDs: [UUID]
    let playerIDs: [UUID]
    let atbatIDs: [UUID]
    let lineupIDs: [UUID]
    let pitcherIDs: [UUID]

    init(container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        games = try context.fetch(FetchDescriptor<Game>()).map(GameSummary.init).sorted { $0.identity.uuidString < $1.identity.uuidString }
        teamIDs = try context.fetch(FetchDescriptor<Team>()).map(\.ident).sortedUUIDs()
        playerIDs = try context.fetch(FetchDescriptor<Player>()).map(\.identifier).sortedUUIDs()
        atbatIDs = try context.fetch(FetchDescriptor<Atbat>()).map(\.ident).sortedUUIDs()
        lineupIDs = try context.fetch(FetchDescriptor<Lineup>()).map(\.ident).sortedUUIDs()
        pitcherIDs = try context.fetch(FetchDescriptor<Pitcher>()).map(\.ident).sortedUUIDs()
    }

    struct GameSummary: Equatable {
        let identity: UUID
        let date: String
        let location: String
        let homeScore: Int
        let visitingScore: Int
        let atbatCount: Int
        let lineupCount: Int
        let pitcherCount: Int

        init(_ game: Game) {
            identity = game.ident
            date = game.date
            location = game.location
            homeScore = game.hscore
            visitingScore = game.vscore
            atbatCount = game.atbats.count
            lineupCount = game.lineups.count
            pitcherCount = game.pitchers.count
        }
    }
}

private extension Array where Element == UUID {
    func sortedUUIDs() -> [UUID] {
        sorted { $0.uuidString < $1.uuidString }
    }
}

import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical persisted scoring replay verifier")
struct CanonicalPersistedScoringReplayVerifierTests {
    @Test("persisted first operation replays from a fresh context and repeats identically")
    func persistedFirstOperationReplaysFromFreshContextAndRepeatsIdentically() throws {
        let environment = try ReplayEnvironment()
        let request = ReplayRequestFactory.scoringRequest()

        let transaction = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(request)
        let first = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.gameA)
        let second = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.gameA)

        #expect(transaction.transaction.disposition == .success)
        #expect(first.classification == .completeCanonicalHistory)
        #expect(first == second)
        #expect(first.auditEntries.map(\.eventIdentity) == [ReplayRequestFactory.eventOne])
        #expect(first.effectiveEntries.map(\.eventIdentity) == [ReplayRequestFactory.eventOne])
        #expect(first.routingRemainsDisabled)
        #expect(first.managedObjectsEscaped == false)
    }

    @Test("file backed store reopen returns the same replay result")
    func fileBackedStoreReopenReturnsTheSameReplayResult() throws {
        let url = try ReplayEnvironment.temporaryStoreURL()
        do {
            let environment = try ReplayEnvironment(url: url)
            _ = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(ReplayRequestFactory.scoringRequest())
            let beforeClose = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.gameA)
            #expect(beforeClose.classification == .completeCanonicalHistory)
        }

        let reopened = try ReplayEnvironment(url: url, insertGame: false)
        let firstReadAfterReopen = CanonicalPersistedScoringReplayVerifier(container: reopened.container).replay(gameIdentity: ReplayRequestFactory.gameA)
        let secondReadAfterReopen = CanonicalPersistedScoringReplayVerifier(container: reopened.container).replay(gameIdentity: ReplayRequestFactory.gameA)

        #expect(firstReadAfterReopen.classification == .completeCanonicalHistory)
        #expect(firstReadAfterReopen == secondReadAfterReopen)
        #expect(firstReadAfterReopen.auditEntries.count == 1)
    }

    @Test("exact retry appears only once in replay")
    func exactRetryAppearsOnlyOnceInReplay() throws {
        let environment = try ReplayEnvironment()
        let adapter = CanonicalScoringTransactionAdapter(container: environment.container)
        let request = ReplayRequestFactory.scoringRequest()

        _ = adapter.applyUsingDedicatedOperationContext(request)
        let retry = adapter.applyUsingDedicatedOperationContext(request)
        let replay = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.gameA)

        #expect(retry.idempotencyResult == .exactRepeatAlreadyApplied)
        #expect(replay.classification == .completeCanonicalHistory)
        #expect(replay.auditEntries.count == 1)
        #expect(replay.effectiveEntries.count == 1)
    }

    @Test("multiple games and operations replay in deterministic scoped order")
    func multipleGamesAndOperationsReplayInDeterministicScopedOrder() throws {
        let environment = try ReplayEnvironment(insertOtherGame: true)
        let adapter = CanonicalScoringTransactionAdapter(container: environment.container)

        _ = adapter.applyUsingDedicatedOperationContext(ReplayRequestFactory.scoringRequest(operationIdentity: ReplayRequestFactory.operationTwo, eventIdentity: ReplayRequestFactory.eventTwo, rawResult: "Double"))
        _ = adapter.applyUsingDedicatedOperationContext(ReplayRequestFactory.scoringRequest(operationIdentity: ReplayRequestFactory.operationOne, eventIdentity: ReplayRequestFactory.eventOne, rawResult: "Single"))
        _ = adapter.applyUsingDedicatedOperationContext(ReplayRequestFactory.otherGameScoringRequest())

        let replay = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.gameA)

        #expect(replay.classification == .completeCanonicalHistory)
        #expect(replay.auditEntries.map(\.commitSequence) == [1, 2])
        #expect(replay.auditEntries.map(\.eventIdentity) == [ReplayRequestFactory.eventTwo, ReplayRequestFactory.eventOne])
        #expect(replay.auditEntries.allSatisfy { $0.payloadFacts.teamSide == "visiting" })
        #expect(replay.auditEntries.contains { $0.eventIdentity == ReplayRequestFactory.otherGameEvent } == false)
    }

    @Test("game with no canonical history returns empty result without synthesizing records")
    func gameWithNoCanonicalHistoryReturnsEmptyResultWithoutSynthesizingRecords() throws {
        let environment = try ReplayEnvironment()
        let before = try ReplayCounts(container: environment.container)

        let replay = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.gameA)
        let after = try ReplayCounts(container: environment.container)

        #expect(replay.classification == .noCanonicalHistory)
        #expect(replay.auditEntries.isEmpty)
        #expect(replay.effectiveEntries.isEmpty)
        #expect(before == after)
    }

    @Test("envelope payload and operation evidence associate correctly")
    func envelopePayloadAndOperationEvidenceAssociateCorrectly() throws {
        let environment = try ReplayEnvironment()
        let transaction = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(ReplayRequestFactory.scoringRequest())

        let replay = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.gameA)
        let entry = try #require(replay.auditEntries.first)

        #expect(replay.classification == .completeCanonicalHistory)
        #expect(entry.eventIdentity == transaction.acceptedEventIdentity)
        #expect(entry.operationIdentity == transaction.operationIdentity)
        #expect(entry.payloadFingerprint == transaction.payloadFingerprint)
        #expect(entry.payloadFacts.eventFamily == "batterReaches")
        #expect(entry.payloadFacts.result == "Single")
    }

    @Test("malformed persisted evidence fails closed")
    func malformedPersistedEvidenceFailsClosed() throws {
        try expectMalformed(.missingPayload) { environment in
            try environment.insertManualEvent(payload: .missing)
        }
        try expectMalformed(.missingOperationEvidence) { environment in
            try environment.insertManualEvent(operation: .missing)
        }
        try expectMalformed(.fingerprintMismatch) { environment in
            try environment.insertManualEvent(payload: .fingerprintMismatch)
        }
        try expectMalformed(.unsupportedFutureVersion) { environment in
            try environment.insertManualEvent(payload: .futureVersion)
        }
        try expectMalformed(.sequenceGap) { environment in
            try environment.insertManualEvent(commitSequence: 2)
        }
        try expectMalformed(.missingEnvelope) { environment in
            try environment.insertCorrection(original: ReplayRequestFactory.eventOne, replacement: ReplayRequestFactory.eventTwo, includeOriginal: true, includeReplacement: false)
        }
    }

    @Test("correction creates append only audit history and replacement effective history")
    func correctionCreatesAppendOnlyAuditHistoryAndReplacementEffectiveHistory() throws {
        let environment = try ReplayEnvironment()
        let adapter = CanonicalScoringTransactionAdapter(container: environment.container)
        let original = adapter.applyUsingDedicatedOperationContext(ReplayRequestFactory.scoringRequest())
        let correction = ReplayRequestFactory.correctionRequest(expectedFingerprint: original.payloadFingerprint)

        let firstCorrection = adapter.applyUsingDedicatedOperationContext(correction)
        let retry = adapter.applyUsingDedicatedOperationContext(correction)
        let replay = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.gameA)

        #expect(firstCorrection.transaction.disposition == .success)
        #expect(retry.idempotencyResult == .exactRepeatAlreadyApplied)
        #expect(replay.classification == .completeCanonicalHistory)
        #expect(replay.auditEntries.map(\.eventIdentity) == [ReplayRequestFactory.eventOne, ReplayRequestFactory.eventTwo])
        #expect(replay.auditEntries.map(\.status) == [.originalSuperseded, .correctionReplacementAuditOnly])
        #expect(replay.effectiveEntries.map(\.eventIdentity) == [ReplayRequestFactory.eventTwo])
        #expect(replay.effectiveEntries.first?.replaySequence == 1)
        #expect(replay.correctionLinks.count == 1)
    }

    @Test("invalid supersession chains fail closed")
    func invalidSupersessionChainsFailClosed() throws {
        try expectMalformed(.missingCorrectionTarget) { environment in
            try environment.insertCorrection(original: ReplayRequestFactory.eventOne, replacement: ReplayRequestFactory.eventTwo, includeOriginal: false, includeReplacement: true)
        }
        try expectMalformed(.selfSupersession) { environment in
            try environment.insertCorrection(original: ReplayRequestFactory.eventOne, replacement: ReplayRequestFactory.eventOne, includeOriginal: true, includeReplacement: true)
        }
        try expectMalformed(.crossGameSupersession, insertOtherGame: true) { environment in
            try environment.insertManualEvent(gameIdentity: ReplayRequestFactory.gameB, historyIdentity: ReplayRequestFactory.historyB, eventIdentity: ReplayRequestFactory.eventThree, operationIdentity: ReplayRequestFactory.operationThree)
            try environment.insertCorrection(original: ReplayRequestFactory.eventThree, replacement: ReplayRequestFactory.eventTwo, includeOriginal: false, includeReplacement: true)
        }
        try expectMalformed(.branchingSupersessionConflict) { environment in
            try environment.insertCorrection(original: ReplayRequestFactory.eventOne, replacement: ReplayRequestFactory.eventTwo, includeOriginal: true, includeReplacement: true)
            try environment.insertCorrection(correctionIdentity: ReplayRequestFactory.correctionTwo, correctionOperationIdentity: ReplayRequestFactory.operationFour, original: ReplayRequestFactory.eventOne, replacement: ReplayRequestFactory.eventThree, includeOriginal: false, includeReplacement: true)
        }
        try expectMalformed(.circularSupersession) { environment in
            try environment.insertCorrection(original: ReplayRequestFactory.eventOne, replacement: ReplayRequestFactory.eventTwo, includeOriginal: true, includeReplacement: true)
            try environment.insertCorrection(correctionIdentity: ReplayRequestFactory.correctionTwo, correctionOperationIdentity: ReplayRequestFactory.operationFour, original: ReplayRequestFactory.eventTwo, replacement: ReplayRequestFactory.eventOne, includeOriginal: false, includeReplacement: false)
        }
    }

    @Test("replay performs no canonical or Legacy mutations")
    func replayPerformsNoCanonicalOrLegacyMutations() throws {
        let environment = try ReplayEnvironment()
        _ = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(ReplayRequestFactory.scoringRequest())
        let before = try ReplayCounts(container: environment.container)
        let legacyBefore = try #require(try environment.fetchGame(ReplayRequestFactory.gameA))

        let replay = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.gameA)
        let after = try ReplayCounts(container: environment.container)
        let legacyAfter = try #require(try environment.fetchGame(ReplayRequestFactory.gameA))

        #expect(replay.classification == .completeCanonicalHistory)
        #expect(replay.replayPerformedWrites == false)
        #expect(before == after)
        #expect(legacyBefore.hscore == legacyAfter.hscore)
        #expect(legacyBefore.vscore == legacyAfter.vscore)
        #expect(legacyBefore.atbats.count == legacyAfter.atbats.count)
    }

    @Test("Legacy scoring paths remain unconnected and no historical backfill occurs")
    func legacyScoringPathsRemainUnconnectedAndNoHistoricalBackfillOccurs() throws {
        let root = try StableIdentityAndOrderingTestSupport.repositoryRoot()
        let playersToScore = try String(contentsOf: root.appendingPathComponent("ScoreKeep/Disply graphics/PlayersToScoreView.swift"), encoding: .utf8)
        let scoreGame = try String(contentsOf: root.appendingPathComponent("ScoreKeep/Disply graphics/ScoreGameView.swift"), encoding: .utf8)
        let startup = try String(contentsOf: root.appendingPathComponent("ScoreKeep/Common/ScoreKeepProductionStartupHost.swift"), encoding: .utf8)
        let testSource = try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
        let environment = try ReplayEnvironment(insertGame: false)
        environment.context.insert(Game(ident: ReplayRequestFactory.legacyGame, date: "2026-07-18", location: "Legacy Field", highLights: "", hscore: 7, vscore: 6))
        try environment.context.save()

        let replay = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.legacyGame)
        let counts = try ReplayCounts(container: environment.container)

        #expect(playersToScore.contains("CanonicalPersistedScoringReplayVerifier") == false)
        #expect(scoreGame.contains("CanonicalPersistedScoringReplayVerifier") == false)
        #expect(startup.contains("CanonicalPersistedScoringReplayVerifier") == false)
        #expect(replay.classification == .noCanonicalHistory)
        #expect(counts.histories == 0)
        #expect(testSource.contains("ScoreKeepProposedVersionedSchema." + "V2") == false)
        #expect(testSource.contains("ScoreKeepProposedCanonicalScoringStorage" + "MigrationPlan") == false)
    }

    private func expectMalformed(
        _ classification: CanonicalPersistedScoringReplayClassification,
        insertOtherGame: Bool = false,
        configure: (ReplayEnvironment) throws -> Void
    ) throws {
        let environment = try ReplayEnvironment(insertOtherGame: insertOtherGame)
        try configure(environment)

        let replay = CanonicalPersistedScoringReplayVerifier(container: environment.container).replay(gameIdentity: ReplayRequestFactory.gameA)

        #expect(replay.classification == classification)
        #expect(replay.classification.succeeded == false)
        #expect(replay.routingRemainsDisabled)
        #expect(replay.managedObjectsEscaped == false)
    }
}

private enum ReplayRequestFactory {
    static let gameA = CanonicalGameStatePrimitivesTestSupport.gameA
    static let gameB = CanonicalGameStatePrimitivesTestSupport.gameB
    static let legacyGame = fixedUUID("00000000-0000-0000-0000-000000032499")
    static let historyA = fixedUUID("00000000-0000-0000-0000-000000032400")
    static let historyB = fixedUUID("00000000-0000-0000-0000-000000032401")
    static let operationOne = fixedUUID("00000000-0000-0000-0000-000000032401")
    static let operationTwo = fixedUUID("00000000-0000-0000-0000-000000032402")
    static let operationThree = fixedUUID("00000000-0000-0000-0000-000000032403")
    static let operationFour = fixedUUID("00000000-0000-0000-0000-000000032404")
    static let eventOne = fixedUUID("00000000-0000-0000-0000-000000032411")
    static let eventTwo = fixedUUID("00000000-0000-0000-0000-000000032412")
    static let eventThree = fixedUUID("00000000-0000-0000-0000-000000032413")
    static let otherGameEvent = fixedUUID("00000000-0000-0000-0000-000000032414")
    static let correctionOne = fixedUUID("00000000-0000-0000-0000-000000032421")
    static let correctionTwo = fixedUUID("00000000-0000-0000-0000-000000032422")

    static func scoringRequest(
        operationIdentity: UUID = operationOne,
        eventIdentity: UUID = eventOne,
        rawResult: String = "Single",
        gameIdentity: UUID = gameA
    ) -> CanonicalScoringTransactionRequest {
        let command = CanonicalScoringCommandVocabulary.command(
            rawResult: rawResult,
            gameIdentity: .valid(gameIdentity),
            teamSide: .visiting,
            batter: ScoringCommandTestSupport.batter(),
            proposedEventIdentity: .valid(eventIdentity),
            source: .syntheticVerification
        )
        return CanonicalScoringTransactionRequest(
            operationIdentity: operationIdentity,
            command: command,
            inputState: ScoringCommandTestSupport.state(game: CanonicalGameStatePrimitivesTestSupport.game(id: gameIdentity, lifecycle: .inProgress))
        )
    }

    static func otherGameScoringRequest() -> CanonicalScoringTransactionRequest {
        scoringRequest(operationIdentity: operationThree, eventIdentity: otherGameEvent, rawResult: "Walk", gameIdentity: gameB)
    }

    static func correctionRequest(expectedFingerprint: String?) -> CanonicalScoringTransactionRequest {
        let command = CanonicalScoringCommandVocabulary.command(
            rawResult: "Double",
            gameIdentity: .valid(gameA),
            teamSide: .visiting,
            batter: ScoringCommandTestSupport.batter(),
            proposedEventIdentity: .valid(eventTwo),
            source: .syntheticVerification
        )
        return CanonicalScoringTransactionRequest(
            operationIdentity: operationTwo,
            operationMode: .correctionReplacement,
            command: command,
            inputState: ScoringCommandTestSupport.state(),
            correctionIdentity: correctionOne,
            targetEventIdentity: eventOne,
            expectedTargetPayloadFingerprint: expectedFingerprint
        )
    }

    private static func fixedUUID(_ rawValue: String) -> UUID {
        UUID(uuidString: rawValue)!
    }
}

@MainActor
private final class ReplayEnvironment {
    let container: ModelContainer
    let context: ModelContext

    init(url: URL? = nil, insertGame: Bool = true, insertOtherGame: Bool = false) throws {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration("Task324PersistedReplay", schema: schema, url: url, allowsSave: true)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
        if insertGame {
            context.insert(Game(ident: ReplayRequestFactory.gameA, date: "2026-07-18", location: "Task 3.24 Field", highLights: "", hscore: 0, vscore: 0))
        }
        if insertOtherGame {
            context.insert(Game(ident: ReplayRequestFactory.gameB, date: "2026-07-18", location: "Other Field", highLights: "", hscore: 0, vscore: 0))
        }
        if insertGame || insertOtherGame {
            try context.save()
        }
    }

    static func temporaryStoreURL(_ name: String = UUID().uuidString) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepTask324PersistedReplay", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ScoreKeep.store")
    }

    func fetchGame(_ identity: UUID) throws -> Game? {
        try context.fetch(FetchDescriptor<Game>(predicate: #Predicate { $0.ident == identity })).first
    }

    func insertManualEvent(
        gameIdentity: UUID = ReplayRequestFactory.gameA,
        historyIdentity: UUID = ReplayRequestFactory.historyA,
        eventIdentity: UUID = ReplayRequestFactory.eventOne,
        operationIdentity: UUID = ReplayRequestFactory.operationOne,
        commitSequence: Int = 1,
        rawResult: String = "Single",
        operation: ManualPresence = .present,
        payload: ManualPayload = .valid
    ) throws {
        let game = try #require(try fetchGame(gameIdentity))
        let history = try fetchOrCreateHistory(gameIdentity: gameIdentity, historyIdentity: historyIdentity, game: game)
        history.lastCommittedSequence = max(history.lastCommittedSequence, commitSequence)
        let eventFamily = rawResult == "Ground Out" ? "batterOut" : "batterReaches"
        let event = CanonicalScoringEventEnvelopeRecord(
            eventIdentity: eventIdentity,
            historyIdentity: history.historyIdentity,
            gameIdentity: gameIdentity,
            commitSequence: commitSequence,
            eventFamily: eventFamily,
            sourceClassification: ScoringEventEvidenceSource.syntheticVerification.rawValue,
            originatingOperationIdentity: operationIdentity,
            history: history
        )
        context.insert(event)
        history.events.append(event)

        if operation == .present {
            let operationRecord = CanonicalScoringOperationEvidenceRecord(
                operationIdentity: operationIdentity,
                gameIdentity: gameIdentity,
                operationKind: CanonicalScoringPersistenceConstants.operationScoringKind,
                requestFingerprint: "request-\(operationIdentity.uuidString)",
                disposition: CanonicalScoringPersistenceConstants.operationAcceptedDisposition,
                proposedEventIdentity: eventIdentity,
                acceptedEventIdentity: eventIdentity,
                commitSequence: commitSequence,
                history: history,
                acceptedEvent: event
            )
            event.operation = operationRecord
            history.operations.append(operationRecord)
            context.insert(operationRecord)
        }

        if payload != .missing {
            let payloadVersion = payload == .futureVersion ? 99 : 1
            let payloadValue = CanonicalScoringPayloadValue(
                formatVersion: payloadVersion,
                eventFamily: eventFamily,
                gameIdentity: gameIdentity,
                eventIdentity: eventIdentity,
                teamSide: "visiting",
                result: rawResult,
                batterIdentity: CanonicalGameStatePrimitivesTestSupport.participantA
            )
            let payloadData = try CanonicalScoringPayloadCoding.encode(payloadValue)
            let payloadRecord = CanonicalScoringEventPayloadRecord(
                eventIdentity: eventIdentity,
                eventFamily: eventFamily,
                payloadVersion: payloadVersion,
                scoringSemanticsVersion: payloadVersion,
                encodedPayload: payloadData,
                payloadFingerprint: payload == .fingerprintMismatch ? "not-the-fingerprint" : nil,
                event: event
            )
            event.payload = payloadRecord
            context.insert(payloadRecord)
        }
        try context.save()
    }

    func insertCorrection(
        correctionIdentity: UUID = ReplayRequestFactory.correctionOne,
        correctionOperationIdentity: UUID = ReplayRequestFactory.operationTwo,
        original: UUID,
        replacement: UUID,
        includeOriginal: Bool,
        includeReplacement: Bool
    ) throws {
        if includeOriginal, (try event(original)) == nil {
            try insertManualEvent(eventIdentity: original, operationIdentity: ReplayRequestFactory.operationOne, commitSequence: 1, rawResult: "Single")
        }
        if includeReplacement, (try event(replacement)) == nil {
            let sequence = try nextSequence()
            try insertManualEvent(eventIdentity: replacement, operationIdentity: correctionOperationIdentity, commitSequence: sequence, rawResult: "Double")
        }
        let gameIdentity = ReplayRequestFactory.gameA
        let history = try #require(try context.fetch(FetchDescriptor<CanonicalGameHistoryRecord>(predicate: #Predicate { $0.gameIdentity == gameIdentity })).first)
        let correction = CanonicalScoringCorrectionRecord(
            correctionIdentity: correctionIdentity,
            gameIdentity: ReplayRequestFactory.gameA,
            correctionOperationIdentity: correctionOperationIdentity,
            originalEventIdentity: original,
            correctionOperationShape: CanonicalScoringPersistenceConstants.correctionReplaceShape,
            disposition: CanonicalScoringPersistenceConstants.correctionAcceptedDisposition,
            earliestReplaySequence: (try event(original))?.commitSequence ?? 1,
            replacementEventIdentity: replacement,
            history: history,
            originalEvent: try event(original),
            replacementEvent: try event(replacement),
            operation: try operation(correctionOperationIdentity)
        )
        let correctionOperation: CanonicalScoringOperationEvidenceRecord?
        if let existingOperation = try operation(correctionOperationIdentity) {
            correctionOperation = existingOperation
        } else {
            let operationRecord = CanonicalScoringOperationEvidenceRecord(
                operationIdentity: correctionOperationIdentity,
                gameIdentity: ReplayRequestFactory.gameA,
                operationKind: CanonicalScoringPersistenceConstants.operationCorrectionKind,
                requestFingerprint: "request-\(correctionOperationIdentity.uuidString)",
                disposition: CanonicalScoringPersistenceConstants.operationAcceptedDisposition,
                proposedEventIdentity: replacement,
                acceptedEventIdentity: nil,
                correctionIdentity: correctionIdentity,
                targetEventIdentity: original,
                replacementEventIdentity: replacement,
                history: history,
                correction: correction
            )
            history.operations.append(operationRecord)
            context.insert(operationRecord)
            correctionOperation = operationRecord
        }
        correctionOperation?.operationKind = CanonicalScoringPersistenceConstants.operationCorrectionKind
        correctionOperation?.correctionIdentity = correctionIdentity
        correctionOperation?.targetEventIdentity = original
        correctionOperation?.replacementEventIdentity = replacement
        correctionOperation?.correction = correction
        history.corrections.append(correction)
        context.insert(correction)
        try context.save()
    }

    private func fetchOrCreateHistory(gameIdentity: UUID, historyIdentity: UUID, game: Game) throws -> CanonicalGameHistoryRecord {
        if let existing = try context.fetch(FetchDescriptor<CanonicalGameHistoryRecord>(predicate: #Predicate { $0.gameIdentity == gameIdentity })).first {
            return existing
        }
        let history = CanonicalGameHistoryRecord(historyIdentity: historyIdentity, gameIdentity: gameIdentity, game: game)
        context.insert(history)
        return history
    }

    private func event(_ identity: UUID) throws -> CanonicalScoringEventEnvelopeRecord? {
        try context.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>(predicate: #Predicate { $0.eventIdentity == identity })).first
    }

    private func operation(_ identity: UUID) throws -> CanonicalScoringOperationEvidenceRecord? {
        try context.fetch(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>(predicate: #Predicate { $0.operationIdentity == identity })).first
    }

    private func nextSequence() throws -> Int {
        let gameIdentity = ReplayRequestFactory.gameA
        let events = try context.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>(predicate: #Predicate { $0.gameIdentity == gameIdentity }))
        return (events.map(\.commitSequence).max() ?? 0) + 1
    }
}

private enum ManualPresence {
    case present
    case missing
}

private enum ManualPayload {
    case valid
    case missing
    case fingerprintMismatch
    case futureVersion
}

@MainActor
private struct ReplayCounts: Equatable {
    let games: Int
    let atbats: Int
    let histories: Int
    let events: Int
    let payloads: Int
    let operations: Int
    let corrections: Int

    init(container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        games = try context.fetch(FetchDescriptor<Game>()).count
        atbats = try context.fetch(FetchDescriptor<Atbat>()).count
        histories = try context.fetch(FetchDescriptor<CanonicalGameHistoryRecord>()).count
        events = try context.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>()).count
        payloads = try context.fetch(FetchDescriptor<CanonicalScoringEventPayloadRecord>()).count
        operations = try context.fetch(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>()).count
        corrections = try context.fetch(FetchDescriptor<CanonicalScoringCorrectionRecord>()).count
    }
}

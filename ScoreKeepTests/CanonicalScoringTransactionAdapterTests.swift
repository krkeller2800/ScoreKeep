import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical scoring transaction adapter")
struct CanonicalScoringTransactionAdapterTests {
    @Test("first scoring operation persists one complete canonical transaction")
    func firstScoringOperationPersistsOneCompleteCanonicalTransaction() throws {
        let environment = try Environment()
        let request = RequestFactory.scoringRequest()

        let result = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(request)
        let snapshot = try Snapshot(container: environment.container)

        #expect(result.transaction.disposition == .success)
        #expect(result.saveResult == .succeeded)
        #expect(result.reloadResult == .succeeded)
        #expect(result.idempotencyResult == .firstInvocation)
        #expect(result.routingRemainsDisabled)
        #expect(result.managedObjectsEscaped == false)
        #expect(result.commitSequence == 1)
        #expect(snapshot.histories.count == 1)
        #expect(snapshot.events.count == 1)
        #expect(snapshot.payloads.count == 1)
        #expect(snapshot.operations.count == 1)
        #expect(snapshot.corrections.isEmpty)
    }

    @Test("envelope payload and operation evidence are linked correctly")
    func envelopePayloadAndOperationEvidenceAreLinkedCorrectly() throws {
        let environment = try Environment()
        let request = RequestFactory.scoringRequest()

        let result = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(request)
        let snapshot = try Snapshot(container: environment.container)
        let event = try #require(snapshot.events[RequestFactory.eventOne])
        let payload = try #require(snapshot.payloads[RequestFactory.eventOne])
        let operation = try #require(snapshot.operations[RequestFactory.operationOne])

        #expect(event.eventIdentity == RequestFactory.eventOne)
        #expect(event.originatingOperationIdentity == RequestFactory.operationOne)
        #expect(event.payloadEventIdentity == payload.eventIdentity)
        #expect(operation.acceptedEventIdentity == RequestFactory.eventOne)
        #expect(operation.requestFingerprint == result.requestFingerprint)
        #expect(payload.payloadFingerprint == result.payloadFingerprint)
    }

    @Test("exact retry creates no duplicate and returns deterministic already applied evidence")
    func exactRetryCreatesNoDuplicateAndReturnsDeterministicAlreadyAppliedEvidence() throws {
        let environment = try Environment()
        let adapter = CanonicalScoringTransactionAdapter(container: environment.container)
        let request = RequestFactory.scoringRequest()

        let first = adapter.applyUsingDedicatedOperationContext(request)
        let retry = adapter.applyUsingDedicatedOperationContext(request)
        let snapshot = try Snapshot(container: environment.container)

        #expect(first.transaction.disposition == .success)
        #expect(retry.transaction.disposition == .duplicateAlreadyApplied)
        #expect(retry.idempotencyResult == .exactRepeatAlreadyApplied)
        #expect(retry.commitSequence == first.commitSequence)
        #expect(retry.requestFingerprint == first.requestFingerprint)
        #expect(snapshot.events.count == 1)
        #expect(snapshot.payloads.count == 1)
        #expect(snapshot.operations.count == 1)
    }

    @Test("same operation identity with different payload fails as conflict")
    func sameOperationIdentityWithDifferentPayloadFailsAsConflict() throws {
        let environment = try Environment()
        let adapter = CanonicalScoringTransactionAdapter(container: environment.container)
        let first = RequestFactory.scoringRequest()
        let conflicting = RequestFactory.scoringRequest(eventIdentity: RequestFactory.eventTwo, rawResult: "Double")

        _ = adapter.applyUsingDedicatedOperationContext(first)
        let result = adapter.applyUsingDedicatedOperationContext(conflicting)
        let snapshot = try Snapshot(container: environment.container)

        #expect(result.transaction.disposition == .contradictory)
        #expect(result.idempotencyResult == .conflictingOperationIdentity)
        #expect(result.validationFindings.contains { $0.code == "scoringTransaction.operationIdentity.conflict" })
        #expect(snapshot.events.count == 1)
        #expect(snapshot.operations.count == 1)
    }

    @Test("failed validation creates no canonical records")
    func failedValidationCreatesNoCanonicalRecords() throws {
        let environment = try Environment(insertGame: false)
        let request = RequestFactory.scoringRequest()

        let result = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(request)
        let snapshot = try Snapshot(container: environment.container)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.validationFindings.contains { $0.code == "scoringTransaction.game.missing" })
        #expect(snapshot.isCanonicalEmpty)
    }

    @Test("persistence failure leaves no partial transaction and retry succeeds once")
    func persistenceFailureLeavesNoPartialTransactionAndRetrySucceedsOnce() throws {
        let environment = try Environment()
        let request = RequestFactory.scoringRequest()
        let failing = CanonicalScoringTransactionAdapter(
            container: environment.container,
            dependencies: CanonicalScoringTransactionDependencies(injectedFailures: [.save])
        )

        let failed = failing.applyUsingDedicatedOperationContext(request)
        let afterFailure = try Snapshot(container: environment.container)
        let retry = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(request)
        let afterRetry = try Snapshot(container: environment.container)

        #expect(failed.transaction.disposition == .saveFailed)
        #expect(failed.rollbackResult == .completed)
        #expect(failed.transaction.retrySafety == .safe)
        #expect(afterFailure.isCanonicalEmpty)
        #expect(retry.transaction.disposition == .success)
        #expect(afterRetry.events.count == 1)
    }

    @Test("near concurrent duplicate attempts result in one accepted operation")
    func nearConcurrentDuplicateAttemptsResultInOneAcceptedOperation() throws {
        let environment = try Environment()
        let request = RequestFactory.scoringRequest()
        var duplicateCommitted = false
        let dependencies = CanonicalScoringTransactionDependencies(
            save: { context in
                if duplicateCommitted == false {
                    duplicateCommitted = true
                    _ = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(request)
                }
                try context.save()
            }
        )

        let result = CanonicalScoringTransactionAdapter(container: environment.container, dependencies: dependencies).applyUsingDedicatedOperationContext(request)
        let snapshot = try Snapshot(container: environment.container)

        #expect(result.transaction.disposition == .duplicateAlreadyApplied)
        #expect(result.idempotencyResult == .exactRepeatAlreadyApplied)
        #expect(snapshot.events.count == 1)
        #expect(snapshot.operations.count == 1)
    }

    @Test("correction creates append only replacement event and supersession evidence")
    func correctionCreatesAppendOnlyReplacementEventAndSupersessionEvidence() throws {
        let environment = try Environment()
        let adapter = CanonicalScoringTransactionAdapter(container: environment.container)
        let original = adapter.applyUsingDedicatedOperationContext(RequestFactory.scoringRequest())
        let before = try Snapshot(container: environment.container)
        let correction = RequestFactory.correctionRequest(expectedFingerprint: original.payloadFingerprint)

        let result = adapter.applyUsingDedicatedOperationContext(correction)
        let after = try Snapshot(container: environment.container)
        let correctionRecord = try #require(after.corrections[RequestFactory.correctionOne])
        let originalEvent = try #require(after.events[RequestFactory.eventOne])
        let replacementEvent = try #require(after.events[RequestFactory.eventTwo])

        #expect(result.transaction.disposition == .success)
        #expect(result.commitSequence == 2)
        #expect(after.events.count == 2)
        #expect(before.payloads[RequestFactory.eventOne]?.payloadFingerprint == after.payloads[RequestFactory.eventOne]?.payloadFingerprint)
        #expect(originalEvent.eventStatus == CanonicalScoringPersistenceConstants.eventActiveStatus)
        #expect(replacementEvent.replaySlotOriginalEventIdentity == RequestFactory.eventOne)
        #expect(correctionRecord.originalEventIdentity == RequestFactory.eventOne)
        #expect(correctionRecord.replacementEventIdentity == RequestFactory.eventTwo)
        #expect(correctionRecord.earliestReplaySequence == 1)
    }

    @Test("missing correction target fails closed")
    func missingCorrectionTargetFailsClosed() throws {
        let environment = try Environment()
        let request = RequestFactory.correctionRequest(expectedFingerprint: nil)

        let result = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(request)
        let snapshot = try Snapshot(container: environment.container)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.validationFindings.contains { $0.code == "scoringTransaction.correctionTarget.notFound" })
        #expect(snapshot.isCanonicalEmpty)
    }

    @Test("self supersession fails closed")
    func selfSupersessionFailsClosed() throws {
        let environment = try Environment()
        let request = RequestFactory.correctionRequest(eventIdentity: RequestFactory.eventOne, targetEventIdentity: RequestFactory.eventOne)

        let result = CanonicalScoringTransactionAdapter(container: environment.container).applyUsingDedicatedOperationContext(request)
        let snapshot = try Snapshot(container: environment.container)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.validationFindings.contains { $0.code == "scoringTransaction.supersession.selfReference" })
        #expect(snapshot.isCanonicalEmpty)
    }

    @Test("duplicate correction retry is idempotent")
    func duplicateCorrectionRetryIsIdempotent() throws {
        let environment = try Environment()
        let adapter = CanonicalScoringTransactionAdapter(container: environment.container)
        let original = adapter.applyUsingDedicatedOperationContext(RequestFactory.scoringRequest())
        let request = RequestFactory.correctionRequest(expectedFingerprint: original.payloadFingerprint)

        let first = adapter.applyUsingDedicatedOperationContext(request)
        let retry = adapter.applyUsingDedicatedOperationContext(request)
        let snapshot = try Snapshot(container: environment.container)

        #expect(first.transaction.disposition == .success)
        #expect(retry.transaction.disposition == .duplicateAlreadyApplied)
        #expect(snapshot.events.count == 2)
        #expect(snapshot.corrections.count == 1)
    }

    @Test("second correction against already superseded target is rejected")
    func secondCorrectionAgainstAlreadySupersededTargetIsRejected() throws {
        let environment = try Environment()
        let adapter = CanonicalScoringTransactionAdapter(container: environment.container)
        let original = adapter.applyUsingDedicatedOperationContext(RequestFactory.scoringRequest())
        _ = adapter.applyUsingDedicatedOperationContext(RequestFactory.correctionRequest(expectedFingerprint: original.payloadFingerprint))

        let second = RequestFactory.correctionRequest(
            operationIdentity: RequestFactory.operationThree,
            correctionIdentity: RequestFactory.correctionTwo,
            eventIdentity: RequestFactory.eventThree,
            expectedFingerprint: original.payloadFingerprint
        )
        let result = adapter.applyUsingDedicatedOperationContext(second)
        let snapshot = try Snapshot(container: environment.container)

        #expect(result.transaction.disposition == .validationRejected)
        #expect(result.validationFindings.contains { $0.code == "scoringTransaction.correctionTarget.alreadySuperseded" })
        #expect(snapshot.events.count == 2)
        #expect(snapshot.corrections.count == 1)
    }

    @Test("ordering remains deterministic and correction follows target")
    func orderingRemainsDeterministicAndCorrectionFollowsTarget() throws {
        let environment = try Environment()
        let adapter = CanonicalScoringTransactionAdapter(container: environment.container)
        let original = adapter.applyUsingDedicatedOperationContext(RequestFactory.scoringRequest())
        _ = adapter.applyUsingDedicatedOperationContext(RequestFactory.scoringRequest(operationIdentity: RequestFactory.operationThree, eventIdentity: RequestFactory.eventThree, rawResult: "Walk"))
        let correction = adapter.applyUsingDedicatedOperationContext(RequestFactory.correctionRequest(expectedFingerprint: original.payloadFingerprint))
        let snapshot = try Snapshot(container: environment.container)

        #expect(snapshot.commitSequences == [1, 2, 3])
        #expect(correction.commitSequence == 3)
        #expect(try #require(snapshot.corrections[RequestFactory.correctionOne]).earliestReplaySequence == 1)
    }

    @Test("dedicated operation context disables autosave and does not use caller context")
    func dedicatedOperationContextDisablesAutosaveAndDoesNotUseCallerContext() throws {
        let environment = try Environment()
        environment.context.insert(Team(ident: RequestFactory.unrelatedTeam, name: "Pending", coach: "", details: ""))
        var saveSawAutosaveDisabled = false
        var saveUsedCallerContext = false
        let dependencies = CanonicalScoringTransactionDependencies(
            save: { context in
                saveSawAutosaveDisabled = context.autosaveEnabled == false
                saveUsedCallerContext = context === environment.context
                try context.save()
            }
        )

        let result = CanonicalScoringTransactionAdapter(container: environment.container, dependencies: dependencies).applyUsingDedicatedOperationContext(RequestFactory.scoringRequest())

        #expect(result.transaction.disposition == .success)
        #expect(saveSawAutosaveDisabled)
        #expect(saveUsedCallerContext == false)
        #expect(environment.context.hasChanges)
    }

    @Test("legacy production scoring remains unconnected to canonical adapter")
    func legacyProductionScoringRemainsUnconnectedToCanonicalAdapter() throws {
        let root = try StableIdentityAndOrderingTestSupport.repositoryRoot()
        let playersToScore = try String(contentsOf: root.appendingPathComponent("ScoreKeep/Disply graphics/PlayersToScoreView.swift"), encoding: .utf8)
        let scoreGame = try String(contentsOf: root.appendingPathComponent("ScoreKeep/Disply graphics/ScoreGameView.swift"), encoding: .utf8)
        let adapterSource = try String(contentsOf: root.appendingPathComponent("ScoreKeep/Common/CanonicalScoringTransactionAdapter.swift"), encoding: .utf8)

        #expect(playersToScore.contains("CanonicalScoringTransactionAdapter") == false)
        #expect(scoreGame.contains("CanonicalScoringTransactionAdapter") == false)
        #expect(adapterSource.contains("CanonicalScoringTransactionAdapter"))
    }

    @Test("V3 startup and canonical zero boundaries remain unaffected")
    func v3StartupAndCanonicalZeroBoundariesRemainUnaffected() throws {
        let empty = try Environment(insertGame: false)
        let snapshot = try Snapshot(container: empty.container)

        #expect(ScoreKeepProposedVersionedSchema.v3AddedModelNames == CanonicalScoringPersistenceModelBoundary.implementationModelNames)
        #expect(snapshot.isCanonicalEmpty)
        #expect(CanonicalScoringPersistenceModelBoundary.implementationModelNames.count == 5)
    }

    @Test("historical Legacy game receives no synthesized canonical history")
    func historicalLegacyGameReceivesNoSynthesizedCanonicalHistory() throws {
        let environment = try Environment(insertGame: false)
        environment.context.insert(Game(ident: RequestFactory.legacyHistoricalGame, date: "2026-07-18", location: "Legacy Park", highLights: "", hscore: 5, vscore: 4))
        try environment.context.save()
        let snapshot = try Snapshot(container: environment.container)

        #expect(snapshot.games.contains(RequestFactory.legacyHistoricalGame))
        #expect(snapshot.isCanonicalEmpty)
    }

    @Test("selected task tests do not construct runtime effective V2 and V3 together")
    func selectedTaskTestsDoNotConstructRuntimeEffectiveV2AndV3Together() throws {
        let root = try StableIdentityAndOrderingTestSupport.repositoryRoot()
        let source = try String(contentsOf: root.appendingPathComponent("ScoreKeepTests/CanonicalScoringTransactionAdapterTests.swift"), encoding: .utf8)
        let v2SchemaToken = "ScoreKeepProposedVersionedSchema." + "V2"
        let migrationPlanToken = "ScoreKeepProposedCanonicalScoringStorage" + "MigrationPlan"

        #expect(source.contains(v2SchemaToken) == false)
        #expect(source.contains(migrationPlanToken) == false)
    }
}

private enum RequestFactory {
    static let operationOne = fixedUUID("00000000-0000-0000-0000-000000032301")
    static let operationTwo = fixedUUID("00000000-0000-0000-0000-000000032302")
    static let operationThree = fixedUUID("00000000-0000-0000-0000-000000032303")
    static let eventOne = fixedUUID("00000000-0000-0000-0000-000000032311")
    static let eventTwo = fixedUUID("00000000-0000-0000-0000-000000032312")
    static let eventThree = fixedUUID("00000000-0000-0000-0000-000000032313")
    static let correctionOne = fixedUUID("00000000-0000-0000-0000-000000032321")
    static let correctionTwo = fixedUUID("00000000-0000-0000-0000-000000032322")
    static let unrelatedTeam = fixedUUID("00000000-0000-0000-0000-000000032331")
    static let legacyHistoricalGame = fixedUUID("00000000-0000-0000-0000-000000032341")

    static func scoringRequest(
        operationIdentity: UUID = operationOne,
        eventIdentity: UUID = eventOne,
        rawResult: String = "Single"
    ) -> CanonicalScoringTransactionRequest {
        let command = CanonicalScoringCommandVocabulary.command(
            rawResult: rawResult,
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .visiting,
            batter: ScoringCommandTestSupport.batter(),
            proposedEventIdentity: .valid(eventIdentity),
            source: .syntheticVerification
        )
        return CanonicalScoringTransactionRequest(
            operationIdentity: operationIdentity,
            command: command,
            inputState: ScoringCommandTestSupport.state()
        )
    }

    static func correctionRequest(
        operationIdentity: UUID = operationTwo,
        correctionIdentity: UUID = correctionOne,
        eventIdentity: UUID = eventTwo,
        targetEventIdentity: UUID = eventOne,
        expectedFingerprint: String? = nil
    ) -> CanonicalScoringTransactionRequest {
        let command = CanonicalScoringCommandVocabulary.command(
            rawResult: "Double",
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .visiting,
            batter: ScoringCommandTestSupport.batter(),
            proposedEventIdentity: .valid(eventIdentity),
            source: .syntheticVerification
        )
        return CanonicalScoringTransactionRequest(
            operationIdentity: operationIdentity,
            operationMode: .correctionReplacement,
            command: command,
            inputState: ScoringCommandTestSupport.state(),
            correctionIdentity: correctionIdentity,
            targetEventIdentity: targetEventIdentity,
            expectedTargetPayloadFingerprint: expectedFingerprint
        )
    }

    private static func fixedUUID(_ rawValue: String) -> UUID {
        UUID(uuidString: rawValue)!
    }
}

@MainActor
private struct Environment {
    let container: ModelContainer
    let context: ModelContext

    init(insertGame: Bool = true) throws {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
        if insertGame {
            context.insert(Game(ident: CanonicalGameStatePrimitivesTestSupport.gameA, date: "2026-07-18", location: "Task 3.23 Field", highLights: "", hscore: 0, vscore: 0))
            try context.save()
        }
    }
}

@MainActor
private struct Snapshot {
    let games: Set<UUID>
    let histories: [UUID: CanonicalGameHistoryRecord]
    let events: [UUID: Event]
    let payloads: [UUID: Payload]
    let operations: [UUID: Operation]
    let corrections: [UUID: Correction]

    var isCanonicalEmpty: Bool {
        histories.isEmpty && events.isEmpty && payloads.isEmpty && operations.isEmpty && corrections.isEmpty
    }

    var commitSequences: [Int] {
        events.values.map(\.commitSequence).sorted()
    }

    init(container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        games = Set(try context.fetch(FetchDescriptor<Game>()).map(\.ident))
        histories = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CanonicalGameHistoryRecord>()).map { ($0.historyIdentity, $0) })
        events = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>()).map { record in
            (record.eventIdentity, Event(record))
        })
        payloads = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CanonicalScoringEventPayloadRecord>()).map { record in
            (record.eventIdentity, Payload(record))
        })
        operations = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>()).map { record in
            (record.operationIdentity, Operation(record))
        })
        corrections = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CanonicalScoringCorrectionRecord>()).map { record in
            (record.correctionIdentity, Correction(record))
        })
    }

    struct Event: Hashable {
        let eventIdentity: UUID
        let commitSequence: Int
        let eventStatus: String
        let originatingOperationIdentity: UUID?
        let replaySlotOriginalEventIdentity: UUID?
        let payloadEventIdentity: UUID?

        init(_ record: CanonicalScoringEventEnvelopeRecord) {
            eventIdentity = record.eventIdentity
            commitSequence = record.commitSequence
            eventStatus = record.eventStatus
            originatingOperationIdentity = record.originatingOperationIdentity
            replaySlotOriginalEventIdentity = record.replaySlotOriginalEventIdentity
            payloadEventIdentity = record.payload?.eventIdentity
        }
    }

    struct Payload: Hashable {
        let eventIdentity: UUID
        let payloadFingerprint: String

        init(_ record: CanonicalScoringEventPayloadRecord) {
            eventIdentity = record.eventIdentity
            payloadFingerprint = record.payloadFingerprint
        }
    }

    struct Operation: Hashable {
        let acceptedEventIdentity: UUID?
        let requestFingerprint: String

        init(_ record: CanonicalScoringOperationEvidenceRecord) {
            acceptedEventIdentity = record.acceptedEventIdentity
            requestFingerprint = record.requestFingerprint
        }
    }

    struct Correction: Hashable {
        let originalEventIdentity: UUID
        let replacementEventIdentity: UUID?
        let earliestReplaySequence: Int

        init(_ record: CanonicalScoringCorrectionRecord) {
            originalEventIdentity = record.originalEventIdentity
            replacementEventIdentity = record.replacementEventIdentity
            earliestReplaySequence = record.earliestReplaySequence
        }
    }
}

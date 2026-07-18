import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Versioned canonical scoring persistence")
struct VersionedCanonicalScoringPersistenceTests {
    @Test("Proposed V3 adds exactly five canonical scoring storage models")
    func proposedV3AddsExactlyFiveCanonicalScoringStorageModels() {
        #expect(ScoreKeepProposedVersionedSchema.V3.versionIdentifier == Schema.Version(3, 0, 0))
        #expect(ScoreKeepProposedVersionedSchema.v3AddedModelNames == CanonicalScoringPersistenceModelBoundary.implementationModelNames)
        #expect(ScoreKeepProposedSchemaAssessment.current.proposedV3AddsOnlyCanonicalScoringStorage)
        #expect(ScoreKeepProposedSchemaAssessment.current.productionContainerTargetsProposedV3)
        #expect(CanonicalScoringPersistenceModelBoundary.payloadStorageType == "Data")
        #expect(CanonicalScoringPersistenceModelBoundary.rejectedCorrectionsStorage == "operationEvidenceOnly")
        #expect(CanonicalScoringPersistenceModelBoundary.uniquenessSupport.contains("iOS 17.6"))
    }

    @Test("history event payload operation and correction records persist scalar authority fields")
    func canonicalRecordsPersistScalarAuthorityFields() throws {
        let environment = try environment()
        let ids = CanonicalStorageFixtureIDs()
        let game = Game(ident: ids.game, date: "2026-07-17", location: "Fixture Park", highLights: "", hscore: 0, vscore: 0)
        let history = CanonicalGameHistoryRecord(historyIdentity: ids.history, gameIdentity: ids.game, game: game)
        let operation = CanonicalScoringOperationEvidenceRecord(
            operationIdentity: ids.operation,
            gameIdentity: ids.game,
            operationKind: CanonicalScoringPersistenceConstants.operationScoringKind,
            requestFingerprint: "request-fingerprint",
            disposition: CanonicalScoringPersistenceConstants.operationAcceptedDisposition,
            proposedEventIdentity: ids.event,
            acceptedEventIdentity: ids.event,
            commitSequence: 1,
            history: history
        )
        let payloadValue = CanonicalScoringPayloadValue(
            eventFamily: "batterReaches",
            gameIdentity: ids.game,
            eventIdentity: ids.event,
            teamSide: "visiting",
            result: "Single",
            batterIdentity: ids.batter,
            runsScored: 0,
            rbi: 0
        )
        let payloadData = try CanonicalScoringPayloadCoding.encode(payloadValue)
        let event = CanonicalScoringEventEnvelopeRecord(
            eventIdentity: ids.event,
            historyIdentity: ids.history,
            gameIdentity: ids.game,
            commitSequence: 1,
            eventFamily: "batterReaches",
            sourceClassification: ScoringEventEvidenceSource.syntheticVerification.rawValue,
            originatingOperationIdentity: ids.operation,
            history: history,
            operation: operation
        )
        let payload = CanonicalScoringEventPayloadRecord(
            payloadIdentity: ids.payload,
            eventIdentity: ids.event,
            eventFamily: "batterReaches",
            encodedPayload: payloadData,
            event: event
        )
        let correction = CanonicalScoringCorrectionRecord(
            correctionIdentity: ids.correction,
            gameIdentity: ids.game,
            correctionOperationIdentity: ids.correctionOperation,
            originalEventIdentity: ids.event,
            correctionOperationShape: CanonicalScoringPersistenceConstants.correctionRemoveShape,
            disposition: CanonicalScoringPersistenceConstants.correctionAcceptedDisposition,
            earliestReplaySequence: 1,
            history: history,
            originalEvent: event,
            operation: operation
        )
        event.payload = payload
        operation.correctionIdentity = ids.correction
        operation.correction = correction
        history.events = [event]
        history.operations = [operation]
        history.corrections = [correction]

        environment.context.insert(game)
        environment.context.insert(history)
        environment.context.insert(operation)
        environment.context.insert(event)
        environment.context.insert(payload)
        environment.context.insert(correction)
        try environment.context.save()

        let reload = ModelContext(environment.container)
        #expect(try reload.fetch(FetchDescriptor<CanonicalGameHistoryRecord>()).single().gameIdentity == ids.game)
        #expect(try reload.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>()).single().commitSequence == 1)
        #expect(try reload.fetch(FetchDescriptor<CanonicalScoringEventPayloadRecord>()).single().payloadFingerprint == CanonicalScoringPayloadCoding.fingerprint(payloadData))
        #expect(try reload.fetch(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>()).single().operationIdentity == ids.operation)
        #expect(try reload.fetch(FetchDescriptor<CanonicalScoringCorrectionRecord>()).single().originalEventIdentity == ids.event)
        #expect(try CanonicalScoringPayloadCoding.decode(payloadData) == payloadValue)
    }

    @Test("payload encoding is deterministic versioned and fail closed")
    func payloadEncodingIsDeterministicVersionedAndFailClosed() throws {
        let ids = CanonicalStorageFixtureIDs()
        let value = CanonicalScoringPayloadValue(
            eventFamily: "runnerOut",
            gameIdentity: ids.game,
            eventIdentity: ids.event,
            teamSide: "home",
            result: "Third",
            runnerIdentities: [ids.runnerTwo, ids.runnerOne],
            outsRecorded: 1,
            ambiguityCodes: ["runValidityUnknown", "forceTimingUnknown"],
            unsupportedRawEvidence: ["legacy.outAt=Third"]
        )

        let first = try CanonicalScoringPayloadCoding.encode(value)
        let second = try CanonicalScoringPayloadCoding.encode(value)
        let decoded = try CanonicalScoringPayloadCoding.decode(first)
        let future = try CanonicalScoringPayloadCoding.encode(CanonicalScoringPayloadValue(
            formatVersion: 99,
            eventFamily: "runnerOut",
            gameIdentity: ids.game,
            eventIdentity: ids.event,
            teamSide: "home",
            result: "Third"
        ))

        #expect(first == second)
        #expect(decoded == value)
        #expect(String(data: first, encoding: .utf8)?.contains("Fixture") == false)
        #expect(throws: CanonicalScoringPayloadCodingError.unsupportedPayloadVersion(99)) {
            _ = try CanonicalScoringPayloadCoding.decode(future)
        }
        #expect(throws: (any Error).self) {
            _ = try CanonicalScoringPayloadCoding.decode(Data([0, 1, 2]))
        }
    }

    @Test("supported scalar uniqueness declarations remain present")
    func supportedScalarUniquenessDeclarationsRemainPresent() throws {
        let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = projectRoot.appendingPathComponent("ScoreKeep/Common/CanonicalScoringPersistenceModels.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        #expect(source.contains("@Attribute(.unique) var historyIdentity: UUID"))
        #expect(source.contains("@Attribute(.unique) var gameIdentity: UUID"))
        #expect(source.contains("@Attribute(.unique) var operationIdentity: UUID"))
        #expect(source.contains("@Attribute(.unique) var eventIdentity: UUID"))
        #expect(source.contains("@Attribute(.unique) var payloadIdentity: UUID"))
        #expect(source.contains("@Attribute(.unique) var correctionIdentity: UUID"))
    }

    @Test("history cascade removes child canonical rows without deleting the Legacy Game")
    func historyCascadeRemovesChildRowsWithoutDeletingLegacyGame() throws {
        let environment = try environment()
        let ids = CanonicalStorageFixtureIDs()
        let game = Game(ident: ids.game, date: "2026-07-17", location: "Fixture Park", highLights: "", hscore: 0, vscore: 0)
        let history = CanonicalGameHistoryRecord(historyIdentity: ids.history, gameIdentity: ids.game, game: game)
        let event = CanonicalScoringEventEnvelopeRecord(
            eventIdentity: ids.event,
            historyIdentity: ids.history,
            gameIdentity: ids.game,
            commitSequence: 1,
            eventFamily: "batterOut",
            sourceClassification: ScoringEventEvidenceSource.syntheticVerification.rawValue,
            history: history
        )
        let payloadData = try CanonicalScoringPayloadCoding.encode(CanonicalScoringPayloadValue(
            eventFamily: "batterOut",
            gameIdentity: ids.game,
            eventIdentity: ids.event,
            teamSide: "visiting",
            result: "Ground Out"
        ))
        let payload = CanonicalScoringEventPayloadRecord(eventIdentity: ids.event, eventFamily: "batterOut", encodedPayload: payloadData, event: event)
        event.payload = payload
        history.events = [event]
        environment.context.insert(game)
        environment.context.insert(history)
        environment.context.insert(event)
        environment.context.insert(payload)
        try environment.context.save()

        environment.context.delete(history)
        try environment.context.save()

        let reload = ModelContext(environment.container)
        #expect(try reload.fetch(FetchDescriptor<Game>()).count == 1)
        #expect(try reload.fetch(FetchDescriptor<CanonicalGameHistoryRecord>()).isEmpty)
        #expect(try reload.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>()).isEmpty)
        #expect(try reload.fetch(FetchDescriptor<CanonicalScoringEventPayloadRecord>()).isEmpty)
    }

    @Test("V2 to V3 runtime migration proof requires isolated V2 boundary")
    func v2ToV3RuntimeMigrationProofRequiresIsolatedV2Boundary() throws {
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
        let currentTest = try #require(source.range(of: "func v2ToV3RuntimeMigrationProofRequiresIsolatedV2Boundary"))
        let tail = source[currentTest.lowerBound...]
        let nextHelper = try #require(tail.range(of: "private func environment()"))
        let testSource = tail[..<nextHelper.lowerBound]

        #expect(ScoreKeepProposedVersionedSchema.v3AddedModelNames == CanonicalScoringPersistenceModelBoundary.implementationModelNames)
        #expect(ScoreKeepProposedSchemaAssessment.current.proposedV3AddsOnlyCanonicalScoringStorage)
        #expect(testSource.contains("ScoreKeepProposedCanonicalScoringStorageMigrationPlan") == false)
        #expect(testSource.contains("Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V2.self)") == false)
        #expect(testSource.contains("ModelContainer(for: v2Schema") == false)
    }

    private func environment() throws -> (container: ModelContainer, context: ModelContext) {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V3.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (container, ModelContext(container))
    }

    private func canonicalCounts(in container: ModelContainer) throws -> CanonicalStorageCounts {
        let context = ModelContext(container)
        return try CanonicalStorageCounts(
            histories: context.fetch(FetchDescriptor<CanonicalGameHistoryRecord>()).count,
            events: context.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>()).count,
            payloads: context.fetch(FetchDescriptor<CanonicalScoringEventPayloadRecord>()).count,
            operations: context.fetch(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>()).count,
            corrections: context.fetch(FetchDescriptor<CanonicalScoringCorrectionRecord>()).count
        )
    }
}

private struct CanonicalStorageFixtureIDs {
    let game = UUID(uuidString: "10000000-0000-0000-0000-000000003220")!
    let history = UUID(uuidString: "10000000-0000-0000-0000-000000003221")!
    let otherHistory = UUID(uuidString: "10000000-0000-0000-0000-000000003229")!
    let operation = UUID(uuidString: "10000000-0000-0000-0000-000000003222")!
    let correctionOperation = UUID(uuidString: "10000000-0000-0000-0000-000000003223")!
    let event = UUID(uuidString: "10000000-0000-0000-0000-000000003224")!
    let payload = UUID(uuidString: "10000000-0000-0000-0000-000000003225")!
    let correction = UUID(uuidString: "10000000-0000-0000-0000-000000003226")!
    let batter = UUID(uuidString: "10000000-0000-0000-0000-000000003227")!
    let runnerOne = UUID(uuidString: "10000000-0000-0000-0000-000000003228")!
    let runnerTwo = UUID(uuidString: "10000000-0000-0000-0000-000000003230")!
}

private struct CanonicalStorageCounts: Equatable {
    let histories: Int
    let events: Int
    let payloads: Int
    let operations: Int
    let corrections: Int

    static let zero = CanonicalStorageCounts(histories: 0, events: 0, payloads: 0, operations: 0, corrections: 0)
}

private extension Array {
    func single() throws -> Element {
        try #require(count == 1)
        return self[0]
    }
}

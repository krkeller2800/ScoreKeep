import CryptoKit
import Foundation
import SwiftData

@Model
final class CanonicalGameHistoryRecord {
    @Attribute(.unique) var historyIdentity: UUID
    @Attribute(.unique) var gameIdentity: UUID
    var historyFormatVersion: Int
    var initializedStatus: String
    var authorityStatus: String
    var lastCommittedSequence: Int
    var verificationStatus: String
    var legacyCoexistenceClassification: String
    var creationOperationIdentity: UUID?
    var evidenceSchemaVersion: Int
    var diagnosticCodesStorage: String
    var game: Game?
    @Relationship(deleteRule: .cascade, inverse: \CanonicalScoringEventEnvelopeRecord.history) var events: [CanonicalScoringEventEnvelopeRecord]
    @Relationship(deleteRule: .cascade, inverse: \CanonicalScoringOperationEvidenceRecord.history) var operations: [CanonicalScoringOperationEvidenceRecord]
    @Relationship(deleteRule: .cascade, inverse: \CanonicalScoringCorrectionRecord.history) var corrections: [CanonicalScoringCorrectionRecord]

    init(
        historyIdentity: UUID = UUID(),
        gameIdentity: UUID,
        historyFormatVersion: Int = 1,
        initializedStatus: String = CanonicalScoringPersistenceConstants.historyInitializedStatus,
        authorityStatus: String = CanonicalScoringPersistenceConstants.historyIncompleteStatus,
        lastCommittedSequence: Int = 0,
        verificationStatus: String = CanonicalScoringPersistenceConstants.verificationPendingStatus,
        legacyCoexistenceClassification: String = CanonicalScoringPersistenceConstants.legacyCoexistenceCanonicalInitialized,
        creationOperationIdentity: UUID? = nil,
        evidenceSchemaVersion: Int = 1,
        diagnosticCodesStorage: String = "",
        game: Game? = nil,
        events: [CanonicalScoringEventEnvelopeRecord] = [],
        operations: [CanonicalScoringOperationEvidenceRecord] = [],
        corrections: [CanonicalScoringCorrectionRecord] = []
    ) {
        self.historyIdentity = historyIdentity
        self.gameIdentity = gameIdentity
        self.historyFormatVersion = historyFormatVersion
        self.initializedStatus = initializedStatus
        self.authorityStatus = authorityStatus
        self.lastCommittedSequence = lastCommittedSequence
        self.verificationStatus = verificationStatus
        self.legacyCoexistenceClassification = legacyCoexistenceClassification
        self.creationOperationIdentity = creationOperationIdentity
        self.evidenceSchemaVersion = evidenceSchemaVersion
        self.diagnosticCodesStorage = diagnosticCodesStorage
        self.game = game
        self.events = events
        self.operations = operations
        self.corrections = corrections
    }
}

@Model
final class CanonicalScoringOperationEvidenceRecord {
    @Attribute(.unique) var operationIdentity: UUID
    var gameIdentity: UUID
    var operationKind: String
    var requestFingerprint: String
    var disposition: String
    var evidenceSchemaVersion: Int
    var verificationStatus: String
    var diagnosticCodesStorage: String
    var proposedEventIdentity: UUID?
    var acceptedEventIdentity: UUID?
    var correctionIdentity: UUID?
    var targetEventIdentity: UUID?
    var replacementEventIdentity: UUID?
    var commitSequence: Int?
    var rejectionReason: String?
    var diagnosticIdentity: String
    var history: CanonicalGameHistoryRecord?
    @Relationship(deleteRule: .noAction) var acceptedEvent: CanonicalScoringEventEnvelopeRecord?
    @Relationship(deleteRule: .noAction) var correction: CanonicalScoringCorrectionRecord?

    init(
        operationIdentity: UUID = UUID(),
        gameIdentity: UUID,
        operationKind: String,
        requestFingerprint: String,
        disposition: String,
        evidenceSchemaVersion: Int = 1,
        verificationStatus: String = CanonicalScoringPersistenceConstants.verificationPendingStatus,
        diagnosticCodesStorage: String = "",
        proposedEventIdentity: UUID? = nil,
        acceptedEventIdentity: UUID? = nil,
        correctionIdentity: UUID? = nil,
        targetEventIdentity: UUID? = nil,
        replacementEventIdentity: UUID? = nil,
        commitSequence: Int? = nil,
        rejectionReason: String? = nil,
        diagnosticIdentity: String? = nil,
        history: CanonicalGameHistoryRecord? = nil,
        acceptedEvent: CanonicalScoringEventEnvelopeRecord? = nil,
        correction: CanonicalScoringCorrectionRecord? = nil
    ) {
        self.operationIdentity = operationIdentity
        self.gameIdentity = gameIdentity
        self.operationKind = operationKind
        self.requestFingerprint = requestFingerprint
        self.disposition = disposition
        self.evidenceSchemaVersion = evidenceSchemaVersion
        self.verificationStatus = verificationStatus
        self.diagnosticCodesStorage = diagnosticCodesStorage
        self.proposedEventIdentity = proposedEventIdentity
        self.acceptedEventIdentity = acceptedEventIdentity
        self.correctionIdentity = correctionIdentity
        self.targetEventIdentity = targetEventIdentity
        self.replacementEventIdentity = replacementEventIdentity
        self.commitSequence = commitSequence
        self.rejectionReason = rejectionReason
        self.diagnosticIdentity = diagnosticIdentity ?? CanonicalScoringPersistenceDiagnostics.shortIdentity(operationIdentity)
        self.history = history
        self.acceptedEvent = acceptedEvent
        self.correction = correction
    }
}

@Model
final class CanonicalScoringEventEnvelopeRecord {
    @Attribute(.unique) var eventIdentity: UUID
    var historyIdentity: UUID
    var gameIdentity: UUID
    var commitSequence: Int
    var eventFamily: String
    var envelopeVersion: Int
    var eventStatus: String
    var sourceClassification: String
    var evidenceSchemaVersion: Int
    var diagnosticIdentity: String
    var originatingOperationIdentity: UUID?
    var supersededByCorrectionIdentity: UUID?
    var replaySlotOriginalEventIdentity: UUID?
    var history: CanonicalGameHistoryRecord?
    @Relationship(deleteRule: .cascade, inverse: \CanonicalScoringEventPayloadRecord.event) var payload: CanonicalScoringEventPayloadRecord?
    @Relationship(deleteRule: .noAction) var operation: CanonicalScoringOperationEvidenceRecord?

    init(
        eventIdentity: UUID = UUID(),
        historyIdentity: UUID,
        gameIdentity: UUID,
        commitSequence: Int,
        eventFamily: String,
        envelopeVersion: Int = 1,
        eventStatus: String = CanonicalScoringPersistenceConstants.eventActiveStatus,
        sourceClassification: String,
        evidenceSchemaVersion: Int = 1,
        diagnosticIdentity: String? = nil,
        originatingOperationIdentity: UUID? = nil,
        supersededByCorrectionIdentity: UUID? = nil,
        replaySlotOriginalEventIdentity: UUID? = nil,
        history: CanonicalGameHistoryRecord? = nil,
        payload: CanonicalScoringEventPayloadRecord? = nil,
        operation: CanonicalScoringOperationEvidenceRecord? = nil
    ) {
        self.eventIdentity = eventIdentity
        self.historyIdentity = historyIdentity
        self.gameIdentity = gameIdentity
        self.commitSequence = commitSequence
        self.eventFamily = eventFamily
        self.envelopeVersion = envelopeVersion
        self.eventStatus = eventStatus
        self.sourceClassification = sourceClassification
        self.evidenceSchemaVersion = evidenceSchemaVersion
        self.diagnosticIdentity = diagnosticIdentity ?? CanonicalScoringPersistenceDiagnostics.shortIdentity(eventIdentity)
        self.originatingOperationIdentity = originatingOperationIdentity
        self.supersededByCorrectionIdentity = supersededByCorrectionIdentity
        self.replaySlotOriginalEventIdentity = replaySlotOriginalEventIdentity
        self.history = history
        self.payload = payload
        self.operation = operation
    }
}

@Model
final class CanonicalScoringEventPayloadRecord {
    @Attribute(.unique) var payloadIdentity: UUID
    @Attribute(.unique) var eventIdentity: UUID
    var eventFamily: String
    var payloadVersion: Int
    var scoringSemanticsVersion: Int
    var encodedPayload: Data
    var payloadFingerprint: String
    var unsupportedClassification: String?
    var ambiguityClassification: String?
    var decoderDiagnosticState: String?
    var event: CanonicalScoringEventEnvelopeRecord?

    init(
        payloadIdentity: UUID = UUID(),
        eventIdentity: UUID,
        eventFamily: String,
        payloadVersion: Int = 1,
        scoringSemanticsVersion: Int = 1,
        encodedPayload: Data,
        payloadFingerprint: String? = nil,
        unsupportedClassification: String? = nil,
        ambiguityClassification: String? = nil,
        decoderDiagnosticState: String? = nil,
        event: CanonicalScoringEventEnvelopeRecord? = nil
    ) {
        self.payloadIdentity = payloadIdentity
        self.eventIdentity = eventIdentity
        self.eventFamily = eventFamily
        self.payloadVersion = payloadVersion
        self.scoringSemanticsVersion = scoringSemanticsVersion
        self.encodedPayload = encodedPayload
        self.payloadFingerprint = payloadFingerprint ?? CanonicalScoringPayloadCoding.fingerprint(encodedPayload)
        self.unsupportedClassification = unsupportedClassification
        self.ambiguityClassification = ambiguityClassification
        self.decoderDiagnosticState = decoderDiagnosticState
        self.event = event
    }
}

@Model
final class CanonicalScoringCorrectionRecord {
    @Attribute(.unique) var correctionIdentity: UUID
    var gameIdentity: UUID
    var correctionOperationIdentity: UUID
    var originalEventIdentity: UUID
    var correctionOperationShape: String
    var disposition: String
    var earliestReplaySequence: Int
    var evidenceSchemaVersion: Int
    var replacementEventIdentity: UUID?
    var expectedOriginalEventFingerprint: String?
    var rejectionDiagnostic: String?
    var history: CanonicalGameHistoryRecord?
    @Relationship(deleteRule: .noAction) var originalEvent: CanonicalScoringEventEnvelopeRecord?
    @Relationship(deleteRule: .noAction) var replacementEvent: CanonicalScoringEventEnvelopeRecord?
    @Relationship(deleteRule: .noAction) var operation: CanonicalScoringOperationEvidenceRecord?

    init(
        correctionIdentity: UUID = UUID(),
        gameIdentity: UUID,
        correctionOperationIdentity: UUID,
        originalEventIdentity: UUID,
        correctionOperationShape: String,
        disposition: String,
        earliestReplaySequence: Int,
        evidenceSchemaVersion: Int = 1,
        replacementEventIdentity: UUID? = nil,
        expectedOriginalEventFingerprint: String? = nil,
        rejectionDiagnostic: String? = nil,
        history: CanonicalGameHistoryRecord? = nil,
        originalEvent: CanonicalScoringEventEnvelopeRecord? = nil,
        replacementEvent: CanonicalScoringEventEnvelopeRecord? = nil,
        operation: CanonicalScoringOperationEvidenceRecord? = nil
    ) {
        self.correctionIdentity = correctionIdentity
        self.gameIdentity = gameIdentity
        self.correctionOperationIdentity = correctionOperationIdentity
        self.originalEventIdentity = originalEventIdentity
        self.correctionOperationShape = correctionOperationShape
        self.disposition = disposition
        self.earliestReplaySequence = earliestReplaySequence
        self.evidenceSchemaVersion = evidenceSchemaVersion
        self.replacementEventIdentity = replacementEventIdentity
        self.expectedOriginalEventFingerprint = expectedOriginalEventFingerprint
        self.rejectionDiagnostic = rejectionDiagnostic
        self.history = history
        self.originalEvent = originalEvent
        self.replacementEvent = replacementEvent
        self.operation = operation
    }
}

enum CanonicalScoringPersistenceConstants {
    static let historyInitializedStatus = "initialized"
    static let historyIncompleteStatus = "canonicalHistoryIncomplete"
    static let legacyCoexistenceCanonicalInitialized = "canonicalInitializedLegacyCoexistence"
    static let verificationPendingStatus = "verificationPending"
    static let eventActiveStatus = "active"
    static let eventSupersededStatus = "superseded"
    static let eventRemovedStatus = "removed"
    static let operationScoringKind = "scoringEvent"
    static let operationCorrectionKind = "correction"
    static let operationRejectedKind = "unsupportedOrRejectedAttempt"
    static let operationAcceptedDisposition = "accepted"
    static let operationRejectedDisposition = "rejected"
    static let correctionReplaceShape = "replaceEvent"
    static let correctionRemoveShape = "removeEvent"
    static let correctionAcceptedDisposition = "accepted"
}

struct CanonicalScoringPayloadValue: Codable, Equatable, Sendable {
    let formatVersion: Int
    let eventFamily: String
    let gameIdentity: UUID
    let eventIdentity: UUID
    let teamSide: String
    let result: String
    let batterIdentity: UUID?
    let runnerIdentities: [UUID]
    let outsRecorded: Int?
    let runsScored: Int?
    let rbi: Int?
    let ambiguityCodes: [String]
    let unsupportedRawEvidence: [String]

    init(
        formatVersion: Int = 1,
        eventFamily: String,
        gameIdentity: UUID,
        eventIdentity: UUID,
        teamSide: String,
        result: String,
        batterIdentity: UUID? = nil,
        runnerIdentities: [UUID] = [],
        outsRecorded: Int? = nil,
        runsScored: Int? = nil,
        rbi: Int? = nil,
        ambiguityCodes: [String] = [],
        unsupportedRawEvidence: [String] = []
    ) {
        self.formatVersion = formatVersion
        self.eventFamily = eventFamily
        self.gameIdentity = gameIdentity
        self.eventIdentity = eventIdentity
        self.teamSide = teamSide
        self.result = result
        self.batterIdentity = batterIdentity
        self.runnerIdentities = runnerIdentities.sorted { $0.uuidString < $1.uuidString }
        self.outsRecorded = outsRecorded
        self.runsScored = runsScored
        self.rbi = rbi
        self.ambiguityCodes = ambiguityCodes.sorted()
        self.unsupportedRawEvidence = unsupportedRawEvidence.sorted()
    }
}

enum CanonicalScoringPayloadCoding {
    static let supportedPayloadVersion = 1

    static func encode(_ value: CanonicalScoringPayloadValue) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func decode(_ data: Data, expectedVersion: Int = supportedPayloadVersion) throws -> CanonicalScoringPayloadValue {
        let value = try JSONDecoder().decode(CanonicalScoringPayloadValue.self, from: data)
        guard value.formatVersion == expectedVersion else {
            throw CanonicalScoringPayloadCodingError.unsupportedPayloadVersion(value.formatVersion)
        }
        return value
    }

    static func fingerprint(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum CanonicalScoringPayloadCodingError: Error, Equatable {
    case unsupportedPayloadVersion(Int)
}

enum CanonicalScoringPersistenceDiagnostics {
    static func shortIdentity(_ identity: UUID) -> String {
        let digest = SHA256.hash(data: Data(identity.uuidString.lowercased().utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

struct CanonicalScoringPersistenceModelBoundary: Hashable, Sendable {
    static let implementationModelNames = [
        "CanonicalGameHistoryRecord",
        "CanonicalScoringOperationEvidenceRecord",
        "CanonicalScoringEventEnvelopeRecord",
        "CanonicalScoringEventPayloadRecord",
        "CanonicalScoringCorrectionRecord"
    ]

    static let payloadStorageType = "Data"
    static let rejectedCorrectionsStorage = "operationEvidenceOnly"
    static let uniquenessSupport = "iOS 17.6 target supports @Attribute(.unique) single scalar constraints; #Unique compound constraints and #Index are unavailable until iOS 18."
    static let relationshipLimitationsDeferredToTask323 = [
        "Game-to-history cascade cannot be enforced without adding a Legacy Game field; approved game deletion must perform route-level cleanup.",
        "One payload per event is represented by scalar event identity plus relationship and must be validated transactionally.",
        "Same-game correction target ownership must be validated transactionally."
    ]
}

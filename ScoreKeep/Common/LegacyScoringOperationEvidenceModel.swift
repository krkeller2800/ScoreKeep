import CryptoKit
import Foundation
import SwiftData

@Model
final class LegacyScoringOperationEvidenceRecord {
    @Attribute(.unique) var operationIdentity: UUID
    var requestFingerprint: String
    var targetGameIdentity: UUID
    var targetAtbatIdentity: UUID
    var submissionFamily: String
    var acceptedResultClassification: String
    var acceptedOutcomeReference: String
    var disposition: String
    var conflictEvidence: String
    var completionState: String
    var evidenceSchemaVersion: Int

    init(
        operationIdentity: UUID,
        requestFingerprint: String,
        targetGameIdentity: UUID,
        targetAtbatIdentity: UUID,
        submissionFamily: String,
        acceptedResultClassification: String,
        acceptedOutcomeReference: String,
        disposition: String = LegacyScoringOperationEvidenceConstants.acceptedDisposition,
        conflictEvidence: String = "",
        completionState: String = LegacyScoringOperationEvidenceConstants.completedState,
        evidenceSchemaVersion: Int = 1
    ) {
        self.operationIdentity = operationIdentity
        self.requestFingerprint = requestFingerprint
        self.targetGameIdentity = targetGameIdentity
        self.targetAtbatIdentity = targetAtbatIdentity
        self.submissionFamily = submissionFamily
        self.acceptedResultClassification = acceptedResultClassification
        self.acceptedOutcomeReference = acceptedOutcomeReference
        self.disposition = disposition
        self.conflictEvidence = conflictEvidence
        self.completionState = completionState
        self.evidenceSchemaVersion = evidenceSchemaVersion
    }
}

enum LegacyScoringOperationEvidenceConstants {
    static let ordinarySubmissionFamily = "ordinary"
    static let additionalChoiceSubmissionFamily = "additionalChoice"
    static let acceptedDisposition = "accepted"
    static let conflictDisposition = "conflict"
    static let completedState = "completed"
}

struct LegacyScoringOperationEvidenceModelBoundary: Hashable, Sendable {
    static let implementationModelNames = ["LegacyScoringOperationEvidenceRecord"]

    static let storedFields = [
        "operationIdentity",
        "requestFingerprint",
        "targetGameIdentity",
        "targetAtbatIdentity",
        "submissionFamily",
        "acceptedResultClassification",
        "acceptedOutcomeReference",
        "disposition",
        "conflictEvidence",
        "completionState",
        "evidenceSchemaVersion"
    ]

    static let excludedResponsibilities = [
        "uiState",
        "navigationState",
        "displayLabels",
        "analytics",
        "canonicalEventHistory",
        "mutableBaseballProjection",
        "historicalBackfill"
    ]

    static let isBaseballFactAuthority = false
    static let ownedByLegacyScoringWriter = true
}

struct LegacyScoringOperationRequestFacts: Hashable, Sendable {
    let operationIdentity: UUID
    let targetGameIdentity: UUID
    let targetAtbatIdentity: UUID
    let submissionFamily: String
    let acceptedResultClassification: String
    let acceptedOutcomeReference: String
    let deterministicRequestFacts: [String]

    init(
        operationIdentity: UUID,
        targetGameIdentity: UUID,
        targetAtbatIdentity: UUID,
        submissionFamily: String,
        acceptedResultClassification: String,
        acceptedOutcomeReference: String,
        deterministicRequestFacts: [String]
    ) {
        self.operationIdentity = operationIdentity
        self.targetGameIdentity = targetGameIdentity
        self.targetAtbatIdentity = targetAtbatIdentity
        self.submissionFamily = submissionFamily
        self.acceptedResultClassification = acceptedResultClassification
        self.acceptedOutcomeReference = acceptedOutcomeReference
        self.deterministicRequestFacts = deterministicRequestFacts.sorted()
    }
}

struct LegacyScoringOperationRequestFingerprint: Hashable, Sendable {
    let rawValue: String

    init(_ request: LegacyScoringOperationRequestFacts) {
        let fields = [
            "operation=\(request.operationIdentity.uuidString.lowercased())",
            "game=\(request.targetGameIdentity.uuidString.lowercased())",
            "atbat=\(request.targetAtbatIdentity.uuidString.lowercased())",
            "family=\(request.submissionFamily)",
            "classification=\(request.acceptedResultClassification)",
            "outcome=\(request.acceptedOutcomeReference)",
            "facts=\(request.deterministicRequestFacts.joined(separator: "|"))"
        ].joined(separator: "|")
        rawValue = SHA256.hash(data: Data(fields.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

import Foundation
import SwiftData

@Model
final class TeamCreationOperationEvidenceRecord {
    @Attribute(.unique) var operationIdentity: String
    var targetTeamIdentity: UUID
    var requestFingerprint: String
    var phase: String
    var completionProof: String
    var finalDisposition: String
    var retryClassification: String
    var reviewRequired: Bool
    var diagnosticCodesStorage: String
    var source: String
    var evidenceSchemaVersion: Int

    init(
        operationIdentity: String,
        targetTeamIdentity: UUID,
        requestFingerprint: String,
        phase: String,
        completionProof: String,
        finalDisposition: String,
        retryClassification: String,
        reviewRequired: Bool,
        diagnosticCodesStorage: String,
        source: String,
        evidenceSchemaVersion: Int = 1
    ) {
        self.operationIdentity = operationIdentity
        self.targetTeamIdentity = targetTeamIdentity
        self.requestFingerprint = requestFingerprint
        self.phase = phase
        self.completionProof = completionProof
        self.finalDisposition = finalDisposition
        self.retryClassification = retryClassification
        self.reviewRequired = reviewRequired
        self.diagnosticCodesStorage = diagnosticCodesStorage
        self.source = source
        self.evidenceSchemaVersion = evidenceSchemaVersion
    }
}

struct TeamCreationOperationEvidenceModelBoundary: Hashable, Sendable {
    static let storedFields = [
        "operationIdentity",
        "targetTeamIdentity",
        "requestFingerprint",
        "phase",
        "completionProof",
        "finalDisposition",
        "retryClassification",
        "reviewRequired",
        "diagnosticCodesStorage",
        "source",
        "evidenceSchemaVersion"
    ]

    static let excludedFields = [
        "teamName",
        "coach",
        "details",
        "logo",
        "players",
        "games",
        "lineups",
        "receipts",
        "entitlements",
        "allowances",
        "keychainData",
        "rawErrors",
        "uiMessages",
        "fullRequests",
        "fullResults",
        "retryHistory"
    ]

    static let hasTeamRelationship = false
    static let hasPurchaseOrAllowanceFields = false
    static let hasMediaFields = false
}

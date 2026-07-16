import Foundation
import Testing
@testable import ScoreKeep

final class IsolatedStartupMigrationEvidenceSupport: ScoreKeepMigrationOperationEvidenceAuthority {
    private final class Box {
        var recordsByOperation: [ScoreKeepMigrationOperationIdentity: ScoreKeepMigrationEvidenceRecord] = [:]
        var operationByStore: [String: ScoreKeepMigrationOperationIdentity] = [:]
    }

    private let box: Box

    init() {
        self.box = Box()
    }

    private init(box: Box) {
        self.box = box
    }

    func freshAuthorityInstance() -> IsolatedStartupMigrationEvidenceSupport {
        IsolatedStartupMigrationEvidenceSupport(box: box)
    }

    func evidence(for operationIdentity: ScoreKeepMigrationOperationIdentity) throws -> ScoreKeepMigrationEvidenceRecord? {
        box.recordsByOperation[operationIdentity]
    }

    func currentEvidence(forStoreIdentity storeIdentity: String) throws -> ScoreKeepMigrationEvidenceRecord? {
        guard let operation = box.operationByStore[storeIdentity] else { return nil }
        return box.recordsByOperation[operation]
    }

    func beginPreflight(operationIdentity: ScoreKeepMigrationOperationIdentity, storeIdentity: String) throws {
        if let existingOperation = box.operationByStore[storeIdentity], existingOperation != operationIdentity {
            throw ScoreKeepMigrationEvidenceError.conflictingOperationReuse
        }
        if let existing = box.recordsByOperation[operationIdentity], existing.storeIdentity != storeIdentity {
            throw ScoreKeepMigrationEvidenceError.conflictingStoreIdentity
        }
        let record = try advanced(
            ScoreKeepMigrationEvidenceRecord.initial(operationIdentity: operationIdentity, storeIdentity: storeIdentity),
            to: .preflightBegan,
            diagnostics: ["evidence.preflightBegan"]
        )
        box.recordsByOperation[operationIdentity] = record
        box.operationByStore[storeIdentity] = operationIdentity
    }

    func recordSourceClassification(_ classification: ScoreKeepSourceStoreClassification, operationIdentity: ScoreKeepMigrationOperationIdentity) throws {
        let record = try required(operationIdentity)
        try store(update(record, status: .sourceClassified, sourceClassification: classification, diagnostic: "evidence.sourceClassified"))
    }

    func recordSourcePreservationStatus(_ preserved: Bool, operationIdentity: ScoreKeepMigrationOperationIdentity) throws {
        let record = try required(operationIdentity)
        try store(update(record, status: .sourcePreserved, sourcePreserved: preserved, diagnostic: "evidence.sourcePreserved"))
    }

    func recordMigrationAttempt(operationIdentity: ScoreKeepMigrationOperationIdentity) throws {
        let record = try required(operationIdentity)
        try store(update(record, status: .migrationAttempted, diagnostic: "evidence.migrationAttempted"))
    }

    func recordContainerConstructionResult(_ disposition: ScoreKeepProposedContainerConstructionDisposition, operationIdentity: ScoreKeepMigrationOperationIdentity) throws {
        let record = try required(operationIdentity)
        try store(update(record, status: .containerConstructionRecorded, constructionDisposition: disposition, diagnostic: "evidence.containerConstructed"))
    }

    func recordPostOpenVerificationResult(_ passed: Bool, operationIdentity: ScoreKeepMigrationOperationIdentity) throws {
        let record = try required(operationIdentity)
        try store(update(record, status: .postOpenVerificationRecorded, verificationPassed: passed, diagnostic: "evidence.verificationRecorded"))
    }

    func recordCompletion(operationIdentity: ScoreKeepMigrationOperationIdentity) throws {
        let record = try required(operationIdentity)
        try store(update(record, status: .completed, diagnostic: "evidence.completed"))
    }

    func recordSafeFailure(operationIdentity: ScoreKeepMigrationOperationIdentity) throws {
        let record = try required(operationIdentity)
        try store(update(record, status: .failedSafely, diagnostic: "evidence.failedSafely"))
    }

    func recordUncertainCompletion(operationIdentity: ScoreKeepMigrationOperationIdentity) throws {
        let record = try required(operationIdentity)
        try store(update(record, status: .completionUncertain, diagnostic: "evidence.completionUncertain"))
    }

    func recordRecoveryRequirement(operationIdentity: ScoreKeepMigrationOperationIdentity) throws {
        let record = try required(operationIdentity)
        try store(update(record, status: .recoveryRequired, diagnostic: "evidence.recoveryRequired"))
    }

    func recordDisableState(operationIdentity: ScoreKeepMigrationOperationIdentity) throws {
        let record = try required(operationIdentity)
        try store(update(record, status: .disabled, diagnostic: "evidence.disabled"))
    }

    private func required(_ operationIdentity: ScoreKeepMigrationOperationIdentity) throws -> ScoreKeepMigrationEvidenceRecord {
        guard let record = box.recordsByOperation[operationIdentity] else {
            throw ScoreKeepMigrationEvidenceError.evidenceMissing
        }
        return record
    }

    private func store(_ record: ScoreKeepMigrationEvidenceRecord) throws {
        if let existing = box.operationByStore[record.storeIdentity], existing != record.operationIdentity {
            throw ScoreKeepMigrationEvidenceError.conflictingOperationReuse
        }
        box.recordsByOperation[record.operationIdentity] = record
        box.operationByStore[record.storeIdentity] = record.operationIdentity
    }

    private func update(
        _ record: ScoreKeepMigrationEvidenceRecord,
        status: ScoreKeepMigrationEvidenceStatus,
        sourceClassification: ScoreKeepSourceStoreClassification? = nil,
        sourcePreserved: Bool? = nil,
        constructionDisposition: ScoreKeepProposedContainerConstructionDisposition? = nil,
        verificationPassed: Bool? = nil,
        diagnostic: String
    ) throws -> ScoreKeepMigrationEvidenceRecord {
        try advanced(
            ScoreKeepMigrationEvidenceRecord(
                operationIdentity: record.operationIdentity,
                storeIdentity: record.storeIdentity,
                sourceClassification: sourceClassification ?? record.sourceClassification,
                sourcePreserved: sourcePreserved ?? record.sourcePreserved,
                constructionDisposition: constructionDisposition ?? record.constructionDisposition,
                verificationPassed: verificationPassed ?? record.verificationPassed,
                status: status,
                diagnosticCodes: record.diagnosticCodes + [diagnostic]
            ),
            from: record.status
        )
    }

    private func advanced(
        _ record: ScoreKeepMigrationEvidenceRecord,
        to status: ScoreKeepMigrationEvidenceStatus,
        diagnostics: [String]
    ) throws -> ScoreKeepMigrationEvidenceRecord {
        try advanced(
            ScoreKeepMigrationEvidenceRecord(
                operationIdentity: record.operationIdentity,
                storeIdentity: record.storeIdentity,
                sourceClassification: record.sourceClassification,
                sourcePreserved: record.sourcePreserved,
                constructionDisposition: record.constructionDisposition,
                verificationPassed: record.verificationPassed,
                status: status,
                diagnosticCodes: record.diagnosticCodes + diagnostics
            ),
            from: record.status
        )
    }

    private func advanced(
        _ record: ScoreKeepMigrationEvidenceRecord,
        from priorStatus: ScoreKeepMigrationEvidenceStatus
    ) throws -> ScoreKeepMigrationEvidenceRecord {
        guard statusRank(record.status) >= statusRank(priorStatus) else {
            throw ScoreKeepMigrationEvidenceError.phaseRegression(from: priorStatus, to: record.status)
        }
        return record
    }

    private func statusRank(_ status: ScoreKeepMigrationEvidenceStatus) -> Int {
        ScoreKeepMigrationEvidenceStatus.allCases.firstIndex(of: status) ?? 0
    }
}

func startupMigrationIdentity(
    storeIdentity: String = "disposable-store",
    source: ScoreKeepSourceStoreClassification = .populatedCurrentUnversionedStore,
    uuid: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000007001")!
) -> ScoreKeepMigrationOperationIdentity {
    ScoreKeepMigrationOperationIdentity(
        sourceStoreIdentity: storeIdentity,
        sourceSchema: source,
        targetSchema: .proposedV2,
        applicationMigrationGeneration: 1,
        operationUUID: uuid
    )
}

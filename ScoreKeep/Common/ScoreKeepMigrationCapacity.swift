import Foundation

struct ScoreKeepMigrationCapacityInput: Hashable, Sendable {
    let storeFamilyAllocatedBytes: UInt64
    let backupMultiplier: UInt64
    let targetMultiplier: UInt64
    let verificationCopyMultiplier: UInt64
    let journalAndDiagnosticOverheadBytes: UInt64
    let copyReplacementOverheadBytes: UInt64
    let growthAllowancePercent: UInt64
    let safetyMarginPercent: UInt64
    let fixedMinimumSafetyReserveBytes: UInt64
    let existingRetainedArtifactBytes: UInt64

    static func policy(
        storeFamilyAllocatedBytes: UInt64,
        existingRetainedArtifactBytes: UInt64 = 0,
        growthAllowancePercent: UInt64 = 25,
        safetyMarginPercent: UInt64 = 20,
        fixedMinimumSafetyReserveBytes: UInt64 = 64 * 1024 * 1024
    ) -> ScoreKeepMigrationCapacityInput {
        ScoreKeepMigrationCapacityInput(
            storeFamilyAllocatedBytes: storeFamilyAllocatedBytes,
            backupMultiplier: 1,
            targetMultiplier: 1,
            verificationCopyMultiplier: 1,
            journalAndDiagnosticOverheadBytes: 4 * 1024 * 1024,
            copyReplacementOverheadBytes: 16 * 1024 * 1024,
            growthAllowancePercent: growthAllowancePercent,
            safetyMarginPercent: safetyMarginPercent,
            fixedMinimumSafetyReserveBytes: fixedMinimumSafetyReserveBytes,
            existingRetainedArtifactBytes: existingRetainedArtifactBytes
        )
    }
}

enum ScoreKeepMigrationCapacityDisposition: String, CaseIterable, Hashable, Sendable {
    case sufficient
    case insufficient
    case unavailable
    case queryFailed
    case volumeUnsupported
    case readOnlyVolume
    case capacityChangedDuringPreflight
    case uncertain
    case safetyMarginNotMet
    case overflow
    case invalidInput
}

struct ScoreKeepMigrationCapacityResult: Hashable, Sendable {
    let disposition: ScoreKeepMigrationCapacityDisposition
    let requiredBytes: UInt64?
    let availableBytes: UInt64?
    let reserveBytes: UInt64?
    let surplusBytes: UInt64?
    let deficitBytes: UInt64?
    let confidence: String
    let mayProceed: Bool
    let diagnosticCode: String
}

struct ScoreKeepMigrationVolumeCapacity: Hashable, Sendable {
    let availableBytesForImportantUsage: UInt64?
    let availableBytes: UInt64?
    let isReadOnly: Bool
    let isSupported: Bool
    let queryFailed: Bool
}

enum ScoreKeepMigrationCapacityCalculator {
    static func requiredBytes(for input: ScoreKeepMigrationCapacityInput) -> UInt64? {
        guard input.backupMultiplier > 0,
              input.targetMultiplier > 0,
              input.verificationCopyMultiplier > 0 else { return nil }
        var total: UInt64 = 0
        guard add(&total, input.storeFamilyAllocatedBytes, multipliedBy: input.backupMultiplier) else { return nil }
        guard add(&total, input.storeFamilyAllocatedBytes, multipliedBy: input.targetMultiplier) else { return nil }
        guard add(&total, input.storeFamilyAllocatedBytes, multipliedBy: input.verificationCopyMultiplier) else { return nil }
        guard add(&total, input.storeFamilyAllocatedBytes, multipliedBy: input.growthAllowancePercent, dividedBy: 100) else { return nil }
        guard add(&total, input.journalAndDiagnosticOverheadBytes, multipliedBy: 1) else { return nil }
        guard add(&total, input.copyReplacementOverheadBytes, multipliedBy: 1) else { return nil }
        guard add(&total, input.existingRetainedArtifactBytes, multipliedBy: 1) else { return nil }
        guard let percentageReserve = multiplied(total, by: input.safetyMarginPercent, dividedBy: 100) else { return nil }
        let reserve = max(percentageReserve, input.fixedMinimumSafetyReserveBytes)
        let final = total.addingReportingOverflow(reserve)
        guard final.overflow == false else { return nil }
        return final.partialValue
    }

    static func evaluate(input: ScoreKeepMigrationCapacityInput, volume: ScoreKeepMigrationVolumeCapacity) -> ScoreKeepMigrationCapacityResult {
        guard volume.isSupported else { return failure(.volumeUnsupported) }
        guard volume.queryFailed == false else { return failure(.queryFailed) }
        guard volume.isReadOnly == false else { return failure(.readOnlyVolume) }
        guard let available = volume.availableBytesForImportantUsage ?? volume.availableBytes else { return failure(.unavailable) }
        guard let required = requiredBytes(for: input) else { return failure(.overflow) }
        guard let reserve = multiplied(required, by: input.safetyMarginPercent, dividedBy: 100) else { return failure(.overflow) }
        let effectiveReserve = max(reserve, input.fixedMinimumSafetyReserveBytes)
        if available >= required {
            return ScoreKeepMigrationCapacityResult(
                disposition: .sufficient,
                requiredBytes: required,
                availableBytes: available,
                reserveBytes: effectiveReserve,
                surplusBytes: available - required,
                deficitBytes: nil,
                confidence: "availableForImportantUsageOrInjectedEquivalent",
                mayProceed: true,
                diagnosticCode: "capacity.sufficient"
            )
        }
        let deficit = required - available
        return ScoreKeepMigrationCapacityResult(
            disposition: deficit <= effectiveReserve ? .safetyMarginNotMet : .insufficient,
            requiredBytes: required,
            availableBytes: available,
            reserveBytes: effectiveReserve,
            surplusBytes: nil,
            deficitBytes: deficit,
            confidence: "failClosed",
            mayProceed: false,
            diagnosticCode: deficit <= effectiveReserve ? "capacity.safetyMarginNotMet" : "capacity.insufficient"
        )
    }

    static func queryVolume(at url: URL, fileManager: FileManager = .default) -> ScoreKeepMigrationVolumeCapacity {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey, .volumeIsReadOnlyKey])
            return ScoreKeepMigrationVolumeCapacity(
                availableBytesForImportantUsage: values.volumeAvailableCapacityForImportantUsage.map(UInt64.init),
                availableBytes: values.volumeAvailableCapacity.map(UInt64.init),
                isReadOnly: values.volumeIsReadOnly ?? false,
                isSupported: true,
                queryFailed: false
            )
        } catch {
            return ScoreKeepMigrationVolumeCapacity(availableBytesForImportantUsage: nil, availableBytes: nil, isReadOnly: false, isSupported: true, queryFailed: true)
        }
    }

    private static func add(_ total: inout UInt64, _ value: UInt64, multipliedBy multiplier: UInt64, dividedBy divisor: UInt64 = 1) -> Bool {
        guard let product = multiplied(value, by: multiplier, dividedBy: divisor) else { return false }
        let result = total.addingReportingOverflow(product)
        guard result.overflow == false else { return false }
        total = result.partialValue
        return true
    }

    private static func multiplied(_ value: UInt64, by multiplier: UInt64, dividedBy divisor: UInt64 = 1) -> UInt64? {
        guard divisor > 0 else { return nil }
        let result = value.multipliedReportingOverflow(by: multiplier)
        guard result.overflow == false else { return nil }
        return result.partialValue / divisor
    }

    private static func failure(_ disposition: ScoreKeepMigrationCapacityDisposition) -> ScoreKeepMigrationCapacityResult {
        ScoreKeepMigrationCapacityResult(
            disposition: disposition,
            requiredBytes: nil,
            availableBytes: nil,
            reserveBytes: nil,
            surplusBytes: nil,
            deficitBytes: nil,
            confidence: "failClosed",
            mayProceed: false,
            diagnosticCode: "capacity.\(disposition.rawValue)"
        )
    }
}

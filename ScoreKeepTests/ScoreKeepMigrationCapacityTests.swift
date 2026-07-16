import Foundation
import Testing
@testable import ScoreKeep

@Suite("Migration capacity preflight")
struct ScoreKeepMigrationCapacityTests {
    @Test("required bytes are conservative and account for sidecars media retained artifacts and margin")
    func requiredBytesAreConservative() throws {
        let input = ScoreKeepMigrationCapacityInput.policy(storeFamilyAllocatedBytes: 10_000, existingRetainedArtifactBytes: 5_000, growthAllowancePercent: 50, safetyMarginPercent: 20, fixedMinimumSafetyReserveBytes: 1_000)
        let required = try #require(ScoreKeepMigrationCapacityCalculator.requiredBytes(for: input))
        #expect(required == 30_000 + 5_000 + 4_194_304 + 16_777_216 + 5_000 + 4_202_304)
    }

    @Test("exact sufficiency proceeds and one byte below fails closed")
    func exactSufficiencyAndOneByteBelow() throws {
        let input = ScoreKeepMigrationCapacityInput.policy(storeFamilyAllocatedBytes: 1_024, fixedMinimumSafetyReserveBytes: 1_024)
        let required = try #require(ScoreKeepMigrationCapacityCalculator.requiredBytes(for: input))
        let exact = ScoreKeepMigrationCapacityCalculator.evaluate(input: input, volume: ScoreKeepMigrationVolumeCapacity(availableBytesForImportantUsage: required, availableBytes: nil, isReadOnly: false, isSupported: true, queryFailed: false))
        #expect(exact.disposition == .sufficient)
        #expect(exact.mayProceed)
        let short = ScoreKeepMigrationCapacityCalculator.evaluate(input: input, volume: ScoreKeepMigrationVolumeCapacity(availableBytesForImportantUsage: required - 1, availableBytes: nil, isReadOnly: false, isSupported: true, queryFailed: false))
        #expect(short.mayProceed == false)
        #expect(short.deficitBytes == 1)
    }

    @Test("unavailable query failure read only unsupported and overflow fail closed")
    func unavailableAndInvalidValuesFailClosed() {
        let input = ScoreKeepMigrationCapacityInput.policy(storeFamilyAllocatedBytes: UInt64.max / 2)
        #expect(ScoreKeepMigrationCapacityCalculator.requiredBytes(for: input) == nil)
        let normal = ScoreKeepMigrationCapacityInput.policy(storeFamilyAllocatedBytes: 1)
        #expect(ScoreKeepMigrationCapacityCalculator.evaluate(input: normal, volume: ScoreKeepMigrationVolumeCapacity(availableBytesForImportantUsage: nil, availableBytes: nil, isReadOnly: false, isSupported: true, queryFailed: false)).disposition == .unavailable)
        #expect(ScoreKeepMigrationCapacityCalculator.evaluate(input: normal, volume: ScoreKeepMigrationVolumeCapacity(availableBytesForImportantUsage: 100, availableBytes: nil, isReadOnly: false, isSupported: true, queryFailed: true)).disposition == .queryFailed)
        #expect(ScoreKeepMigrationCapacityCalculator.evaluate(input: normal, volume: ScoreKeepMigrationVolumeCapacity(availableBytesForImportantUsage: 100, availableBytes: nil, isReadOnly: true, isSupported: true, queryFailed: false)).disposition == .readOnlyVolume)
        #expect(ScoreKeepMigrationCapacityCalculator.evaluate(input: normal, volume: ScoreKeepMigrationVolumeCapacity(availableBytesForImportantUsage: 100, availableBytes: nil, isReadOnly: false, isSupported: false, queryFailed: false)).disposition == .volumeUnsupported)
    }

    @Test("minimal populated media and sidecar synthetic totals do not allocate giant files")
    func syntheticTotalsCoverStoreShapes() throws {
        let empty = try #require(ScoreKeepMigrationCapacityCalculator.requiredBytes(for: .policy(storeFamilyAllocatedBytes: 0)))
        let minimal = try #require(ScoreKeepMigrationCapacityCalculator.requiredBytes(for: .policy(storeFamilyAllocatedBytes: 32 * 1024)))
        let populated = try #require(ScoreKeepMigrationCapacityCalculator.requiredBytes(for: .policy(storeFamilyAllocatedBytes: 2 * 1024 * 1024)))
        let media = try #require(ScoreKeepMigrationCapacityCalculator.requiredBytes(for: .policy(storeFamilyAllocatedBytes: 75 * 1024 * 1024)))
        #expect(empty < minimal)
        #expect(minimal < populated)
        #expect(populated < media)
    }
}

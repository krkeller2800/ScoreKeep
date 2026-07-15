import Testing
@testable import ScoreKeep

@Suite("Canonical migration fixture manifest verification")
struct CanonicalMigrationFixtureTests {
    @Test("representative migration fixture manifest covers required categories")
    func representativeMigrationFixtureManifestCoversRequiredCategories() {
        let categories = Set(MigrationFixtureManifest.expectations.flatMap(\.categories))

        #expect(categories.contains("empty source"))
        #expect(categories.contains("minimal valid store"))
        #expect(categories.contains("in-progress game"))
        #expect(categories.contains("completed game"))
        #expect(categories.contains("multiple teams"))
        #expect(categories.contains("reusable players"))
        #expect(categories.contains("roster relationships"))
        #expect(categories.contains("multiple scoring events"))
        #expect(categories.contains("pitcher evidence"))
        #expect(categories.contains("substitution evidence"))
        #expect(categories.contains("ordering evidence"))
        #expect(categories.contains("optional values missing"))
        #expect(categories.contains("photos and logos"))
        #expect(categories.contains("media evidence"))
        #expect(categories.contains("duplicate identity"))
        #expect(categories.contains("broken relationship"))
        #expect(categories.contains("duplicate or conflicting ordering"))
        #expect(categories.contains("unsupported raw value"))
        #expect(categories.contains("malformed or incomplete evidence"))
        #expect(categories.contains("purchase and allowance separation probes"))
    }

    @Test("migration fixture expectations are deterministic and privacy safe")
    func migrationFixtureExpectationsAreDeterministicAndPrivacySafe() {
        let expectations = MigrationFixtureManifest.expectations

        #expect(Set(expectations.map(\.identity)).count == expectations.count)
        #expect(expectations.allSatisfy { $0.identity.isEmpty == false })
        #expect(expectations.allSatisfy { $0.expectedRecordCounts.games >= 0 })
        #expect(expectations.allSatisfy { $0.expectedRecordCounts.teams >= 0 })
        #expect(expectations.allSatisfy { $0.expectedRecordCounts.players >= 0 })
        #expect(expectations.allSatisfy { $0.expectedRecordCounts.atbats >= 0 })
        #expect(expectations.allSatisfy { $0.expectedRecordCounts.lineups >= 0 })
        #expect(expectations.allSatisfy { $0.expectedRecordCounts.pitchers >= 0 })
        #expect(expectations.allSatisfy { expectation in
            expectation.allowanceProbe.entitlementMarker.contains("receipt") == false
            && expectation.allowanceProbe.purchaseMarker.contains("transaction") == false
            && expectation.allowanceProbe.purchaseMarker.contains("receipt") == false
        })
    }

    @Test("populated migration fixtures are evidence only before task 3.14")
    func populatedMigrationFixturesAreEvidenceOnlyBeforeTask314() {
        let populated = MigrationFixtureManifest.expectations.filter { $0.sourceClassification == .populatedExistingStore }

        #expect(populated.isEmpty == false)
        #expect(populated.allSatisfy { $0.expectedDisposition == .requiresReview })
        #expect(populated.allSatisfy { $0.mayContinue == false })
        #expect(populated.allSatisfy { $0.reviewRequired })
        #expect(populated.allSatisfy { $0.rollbackOrPreservationRequired })
    }

    @Test("purchase and allowance fixture probes remain separate from baseball record counts")
    func purchaseAndAllowanceFixtureProbesRemainSeparateFromBaseballRecordCounts() throws {
        let probeFixture = try #require(MigrationFixtureManifest.expectations.first { $0.identity == "purchase-allowance-probes" })

        #expect(probeFixture.expectedRecordCounts == .empty)
        #expect(probeFixture.sourceClassification == .purchaseOrAllowanceOnlyNoBaseballRecords)
        #expect(probeFixture.allowanceProbe.freeGameCreatesRemaining == 1)
        #expect(probeFixture.allowanceProbe.mlbDownloadUseCount == 3)
        #expect(probeFixture.allowanceProbe.entitlementMarker == "known-entitlement-marker")
        #expect(probeFixture.allowanceProbe.purchaseMarker == "known-purchase-marker")
    }
}

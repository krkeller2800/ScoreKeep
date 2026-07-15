import Testing
@testable import ScoreKeep

@Suite("Canonical migration source inventory verification")
struct CanonicalMigrationSourceInventoryTests {
    @Test("migration source classifications cover baseball compatibility and non-baseball boundaries")
    func migrationSourceClassificationsCoverRequiredBoundaries() {
        let classifications = Set(CanonicalMigrationSourceClassification.allCases)

        #expect(classifications.contains(.trulyEmptyNewStore))
        #expect(classifications.contains(.emptyExistingStore))
        #expect(classifications.contains(.metadataOnlyNoBaseballRecords))
        #expect(classifications.contains(.preferencesOnlyNoBaseballRecords))
        #expect(classifications.contains(.purchaseOrAllowanceOnlyNoBaseballRecords))
        #expect(classifications.contains(.previouslyInitializedEmptyStore))
        #expect(classifications.contains(.populatedExistingStore))
        #expect(classifications.contains(.unknownSourceVersion))
        #expect(classifications.contains(.unsupportedSource))
        #expect(classifications.contains(.unableToOpenSource))
    }

    @Test("empty source classifier distinguishes zero-record source conditions")
    func emptySourceClassifierDistinguishesZeroRecordConditions() {
        #expect(
            CanonicalMigrationClassifier.classifyEmptySource(
                recordCounts: .empty,
                hasMetadata: false,
                hasPreferences: false,
                hasPurchaseOrAllowanceEvidence: false,
                wasPreviouslyInitialized: false,
                sourceVersionKnown: true
            ) == .trulyEmptyNewStore
        )
        #expect(
            CanonicalMigrationClassifier.classifyEmptySource(
                recordCounts: .empty,
                hasMetadata: true,
                hasPreferences: false,
                hasPurchaseOrAllowanceEvidence: false,
                wasPreviouslyInitialized: false,
                sourceVersionKnown: true
            ) == .metadataOnlyNoBaseballRecords
        )
        #expect(
            CanonicalMigrationClassifier.classifyEmptySource(
                recordCounts: .empty,
                hasMetadata: false,
                hasPreferences: true,
                hasPurchaseOrAllowanceEvidence: false,
                wasPreviouslyInitialized: false,
                sourceVersionKnown: true
            ) == .preferencesOnlyNoBaseballRecords
        )
        #expect(
            CanonicalMigrationClassifier.classifyEmptySource(
                recordCounts: .empty,
                hasMetadata: false,
                hasPreferences: false,
                hasPurchaseOrAllowanceEvidence: true,
                wasPreviouslyInitialized: false,
                sourceVersionKnown: true
            ) == .purchaseOrAllowanceOnlyNoBaseballRecords
        )
        #expect(
            CanonicalMigrationClassifier.classifyEmptySource(
                recordCounts: .empty,
                hasMetadata: false,
                hasPreferences: false,
                hasPurchaseOrAllowanceEvidence: false,
                wasPreviouslyInitialized: true,
                sourceVersionKnown: true
            ) == .previouslyInitializedEmptyStore
        )
        #expect(
            CanonicalMigrationClassifier.classifyEmptySource(
                recordCounts: .empty,
                hasMetadata: false,
                hasPreferences: false,
                hasPurchaseOrAllowanceEvidence: false,
                wasPreviouslyInitialized: false,
                sourceVersionKnown: false
            ) == .unknownSourceVersion
        )
    }

    @Test("populated baseball evidence is not treated as empty-store migration")
    func populatedBaseballEvidenceIsNotTreatedAsEmptyStoreMigration() {
        let counts = CanonicalMigrationRecordCounts(games: 1, teams: 2, players: 4, atbats: 2, lineups: 1, pitchers: 1)

        #expect(counts.containsBaseballRecords)
        #expect(
            CanonicalMigrationClassifier.classifyEmptySource(
                recordCounts: counts,
                hasMetadata: false,
                hasPreferences: false,
                hasPurchaseOrAllowanceEvidence: false,
                wasPreviouslyInitialized: false,
                sourceVersionKnown: true
            ) == .populatedExistingStore
        )
    }

    @Test("migration dispositions include required failure retry and separation vocabulary")
    func migrationDispositionsIncludeRequiredVocabulary() {
        let dispositions = Set(CanonicalMigrationDisposition.allCases)

        #expect(dispositions.contains(.notRequired))
        #expect(dispositions.contains(.emptySourceInitialized))
        #expect(dispositions.contains(.success))
        #expect(dispositions.contains(.successWithWarnings))
        #expect(dispositions.contains(.noChange))
        #expect(dispositions.contains(.alreadyMigrated))
        #expect(dispositions.contains(.partialOrUncertain))
        #expect(dispositions.contains(.interrupted))
        #expect(dispositions.contains(.retrySafe))
        #expect(dispositions.contains(.retryUnsafe))
        #expect(dispositions.contains(.recoveryAvailable))
        #expect(dispositions.contains(.validationRejected))
        #expect(dispositions.contains(.unsupportedSource))
        #expect(dispositions.contains(.unknownSourceVersion))
        #expect(dispositions.contains(.relationshipFailure))
        #expect(dispositions.contains(.orderingFailure))
        #expect(dispositions.contains(.mediaFailure))
        #expect(dispositions.contains(.purchaseSeparationFailure))
        #expect(dispositions.contains(.contradictory))
        #expect(dispositions.contains(.unresolved))
        #expect(dispositions.contains(.requiresReview))
        #expect(dispositions.contains(.requiresRollback))
        #expect(dispositions.contains(.priorStorePreserved))
    }
}

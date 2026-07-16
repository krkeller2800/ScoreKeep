import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Unversioned store duplicate identity diagnostics")
struct UnversionedStoreDuplicateIdentityDiagnosticsTests {
    @Test("minimal source has exactly one game 6301 and no cross model collision")
    func minimalSourceHasExactlyOneGame6301AndNoCrossModelCollision() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let reopened = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: source.url)
        let counts = try IsolatedUnversionedProductionStoreSupport.occurrenceCounts(for: UnversionedCompatibilityIDs.gameOne, in: reopened)

        #expect(counts["Game"] == 1)
        #expect(counts["Team"] == 0)
        #expect(counts["Player"] == 0)
        #expect(counts["Atbat"] == 0)
        #expect(counts["Lineup"] == 0)
        #expect(counts["Pitcher"] == 0)
        #expect(counts["TeamCreationOperationEvidenceRecord.targetTeamIdentity"] == 0)
    }

    @Test("migrated minimal copy has exactly one game 6301 after first proposed V2 open")
    func migratedMinimalCopyHasExactlyOneGame6301AfterFirstProposedV2Open() throws {
        let source = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal)
        let copy = try IsolatedUnversionedProductionStoreSupport.copyStoreFamily(from: source.url)
        let v2 = try IsolatedUnversionedProductionStoreSupport.proposedV2Container(url: copy)
        let counts = try IsolatedUnversionedProductionStoreSupport.occurrenceCounts(for: UnversionedCompatibilityIDs.gameOne, in: v2)

        #expect(counts["Game"] == 1)
        #expect(counts["Team"] == 0)
        #expect(counts["Player"] == 0)
        #expect(counts["Atbat"] == 0)
        #expect(counts["Lineup"] == 0)
        #expect(counts["Pitcher"] == 0)
        #expect(counts["TeamCreationOperationEvidenceRecord.targetTeamIdentity"] == 0)
    }

    @Test("snapshot reports duplicate game identity without fatal dictionary construction")
    func snapshotReportsDuplicateGameIdentityWithoutFatalDictionaryConstruction() throws {
        let url = try IsolatedUnversionedProductionStoreSupport.temporaryStoreURL()
        do {
            let container = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: url)
            let context = ModelContext(container)
            let first = Game(ident: UnversionedCompatibilityIDs.gameOne, date: "2026-07-16", location: "A", highLights: "first", hscore: 0, vscore: 0)
            let second = Game(ident: UnversionedCompatibilityIDs.gameOne, date: "2026-07-17", location: "B", highLights: "second", hscore: 1, vscore: 1)
            context.insert(first)
            context.insert(second)
            try context.save()
        }

        let reopened = try IsolatedUnversionedProductionStoreSupport.exactCurrentUnversionedProductionStyleContainer(url: url)
        do {
            _ = try IsolatedUnversionedProductionStoreSupport.snapshot(from: reopened, fixtureIdentity: "duplicate-diagnostic")
            Issue.record("Duplicate stable game identity should be diagnosed before snapshot dictionaries are created")
        } catch IsolatedUnversionedProductionStoreSupportError.duplicateStableIdentity(let model, let identity, let count) {
            #expect(model == "Game")
            #expect(identity == UnversionedCompatibilityIDs.gameOne)
            #expect(count == 2)
        }
    }

    @Test("non empty destination names are rejected to prevent fixture accumulation")
    func nonEmptyDestinationNamesAreRejectedToPreventFixtureAccumulation() throws {
        let name = "destination-reuse-diagnostic-\(UUID().uuidString)"
        _ = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal, name: name)

        do {
            _ = try IsolatedUnversionedProductionStoreSupport.createSourceStore(.minimal, name: name)
            Issue.record("Reusing a non-empty disposable store directory should be rejected")
        } catch IsolatedUnversionedProductionStoreSupportError.nonEmptyDestination {
            #expect(Bool(true))
        }
    }
}

import Foundation
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Production migration path preparation")
struct ScoreKeepProductionMigrationPathTests {
    @Test("injected application support layout is deterministic non overlapping and dry")
    func injectedLayoutIsDeterministicNonOverlappingAndDry() throws {
        let environment = try IsolatedProductionTransitionEnvironment.make()
        let assessment = ScoreKeepProductionPathDryAssessment.assess(applicationSupportRoot: environment.applicationSupportRoot)
        #expect(assessment.validation.isValid)
        #expect(assessment.createsDirectories == false)
        #expect(assessment.opensProductionStore == false)
        #expect(assessment.enumeratesProductionFiles == false)
        #expect(assessment.storeDiscovery == .frameworkDefaultPathInferredFromDisposableEquivalence)
        let roles = Set(assessment.descriptors.map(\.role))
        #expect(roles.contains(.activeStore))
        #expect(roles.contains(.migrationJournal))
        #expect(roles.contains(.verifiedBackup))
        #expect(environment.layout.activeStore != environment.layout.backupsRoot)
        #expect(environment.layout.journal.path.contains(ScoreKeepProductionMigrationLayout.migrationDirectoryName))
    }

    @Test("path validation rejects traversal source equality nested backup and target equality")
    func pathValidationRejectsUnsafeRelationships() throws {
        let environment = try IsolatedProductionTransitionEnvironment.make()
        var layout = environment.layout
        layout = ScoreKeepProductionMigrationLayout(
            applicationSupportRoot: environment.applicationSupportRoot,
            activeStore: environment.layout.activeStore,
            migrationControlRoot: environment.layout.migrationControlRoot,
            journal: environment.layout.journal,
            backupsRoot: environment.layout.activeStore.deletingLastPathComponent(),
            temporaryTargetsRoot: environment.layout.temporaryTargetsRoot,
            incompleteTargetsRoot: environment.layout.incompleteTargetsRoot,
            recoveryCopiesRoot: environment.layout.recoveryCopiesRoot,
            diagnosticsState: environment.layout.diagnosticsState,
            manualReviewRoot: environment.layout.manualReviewRoot,
            cleanupStagingRoot: environment.layout.cleanupStagingRoot
        )
        #expect(ScoreKeepProductionPathValidator.validate(layout: layout).disposition == .sourceEqualsDestination)

        let escaped = ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: environment.root.appendingPathComponent("ApplicationSupport/../Other", isDirectory: true))
        #expect(ScoreKeepProductionPathValidator.validate(layout: escaped).isValid)

        let outside = ScoreKeepProductionMigrationLayout(
            applicationSupportRoot: environment.applicationSupportRoot,
            activeStore: environment.root.deletingLastPathComponent().appendingPathComponent("outside.store"),
            migrationControlRoot: environment.layout.migrationControlRoot,
            journal: environment.layout.journal,
            backupsRoot: environment.layout.backupsRoot,
            temporaryTargetsRoot: environment.layout.temporaryTargetsRoot,
            incompleteTargetsRoot: environment.layout.incompleteTargetsRoot,
            recoveryCopiesRoot: environment.layout.recoveryCopiesRoot,
            diagnosticsState: environment.layout.diagnosticsState,
            manualReviewRoot: environment.layout.manualReviewRoot,
            cleanupStagingRoot: environment.layout.cleanupStagingRoot
        )
        #expect(ScoreKeepProductionPathValidator.validate(layout: outside).disposition == .pathTraversalOutsideRoot)
    }

    @Test("directory creation policy is explicit and read only assessment creates nothing")
    func directoryCreationPolicyIsExplicit() throws {
        let environment = try IsolatedProductionTransitionEnvironment.make()
        let control = environment.layout.migrationControlRoot
        #expect(ScoreKeepDirectoryCreationPolicy.assess(url: control, intent: .readOnlyAssessment) == .noCreationForReadOnlyAssessment)
        #expect(ScoreKeepDirectoryCreationPolicy.assess(url: control, intent: .authorizedPreflightControlRoot) == .mayCreateEmptyDirectory)
        try FileManager.default.createDirectory(at: control, withIntermediateDirectories: true)
        #expect(ScoreKeepDirectoryCreationPolicy.assess(url: control, intent: .authorizedPreflightControlRoot) == .existingEmptyDirectoryAccepted)
        try environment.createSmallFile(control.appendingPathComponent("unexpected"))
        #expect(ScoreKeepDirectoryCreationPolicy.assess(url: control, intent: .authorizedPreflightControlRoot) == .existingNonEmptyDirectoryRequiresReconciliation)
    }

    @Test("cleanup path validation requires test owned migration root")
    func cleanupValidationRequiresTestOwnedRoot() throws {
        let environment = try IsolatedProductionTransitionEnvironment.make()
        let candidate = environment.layout.temporaryTargetsRoot.appendingPathComponent("candidate", isDirectory: true)
        #expect(ScoreKeepProductionPathValidator.validateCleanupCandidate(candidate, layout: environment.layout, testOwnedRoot: nil).disposition == .productionPathRejectedForTestCleanup)
        #expect(ScoreKeepProductionPathValidator.validateCleanupCandidate(candidate, layout: environment.layout, testOwnedRoot: environment.root).isValid)
    }
}

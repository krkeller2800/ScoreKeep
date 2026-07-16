import Foundation
import SwiftData
@testable import ScoreKeep

@MainActor
struct IsolatedProductionTransitionEnvironment {
    let root: URL
    let applicationSupportRoot: URL
    let layout: ScoreKeepProductionMigrationLayout
    let operationIdentity: ScoreKeepMigrationOperationIdentity

    static func make(name: String = UUID().uuidString) throws -> IsolatedProductionTransitionEnvironment {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreKeepProductionTransitionEnvironment", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let contents = try FileManager.default.contentsOfDirectory(atPath: root.path)
        guard contents.isEmpty else { throw IsolatedProductionTransitionEnvironmentError.nonEmptyRoot }
        let applicationSupportRoot = root.appendingPathComponent("ApplicationSupport", isDirectory: true)
        try FileManager.default.createDirectory(at: applicationSupportRoot, withIntermediateDirectories: true)
        let layout = ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: applicationSupportRoot)
        return IsolatedProductionTransitionEnvironment(
            root: root,
            applicationSupportRoot: applicationSupportRoot,
            layout: layout,
            operationIdentity: ScoreKeepMigrationOperationIdentity(
                sourceStoreIdentity: "test-owned-source",
                sourceSchema: .populatedCurrentUnversionedStore,
                targetSchema: .proposedV2,
                applicationMigrationGeneration: 1,
                operationUUID: UUID(uuidString: "00000000-0000-0000-0000-000000009101")!
            )
        )
    }

    func createControlDirectories() throws {
        try FileManager.default.createDirectory(at: layout.migrationControlRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: layout.journal.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: layout.backupsRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: layout.temporaryTargetsRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: layout.incompleteTargetsRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: layout.recoveryCopiesRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: layout.diagnosticsState.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    func createSmallFile(_ url: URL, bytes: [UInt8] = [1, 2, 3]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data(bytes))
    }

    func createUnversionedSource(_ scenario: UnversionedStoreScenario) throws -> (url: URL, snapshot: UnversionedStoreSnapshot) {
        try IsolatedUnversionedProductionStoreSupport.createSourceStore(scenario)
    }

    func journalStore() throws -> ScoreKeepMigrationJournalStore {
        try FileManager.default.createDirectory(at: layout.journal.deletingLastPathComponent(), withIntermediateDirectories: true)
        return ScoreKeepMigrationJournalStore(directory: layout.journal.deletingLastPathComponent())
    }
}

enum IsolatedProductionTransitionEnvironmentError: Error {
    case nonEmptyRoot
}

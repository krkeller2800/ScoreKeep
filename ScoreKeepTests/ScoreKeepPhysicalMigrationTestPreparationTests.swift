import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@Suite("Physical migration test preparation")
struct ScoreKeepPhysicalMigrationTestPreparationTests {
    @Test("production bundle and migration-test bundle are distinct")
    func bundleIdentitiesAreDistinct() {
        #expect(ScoreKeepPhysicalMigrationTestIdentity.productionBundleIdentifier == "Komakode.ScoreKeep")
        #expect(ScoreKeepPhysicalMigrationTestIdentity.disposableBundleIdentifier == "com.komakode.ScoreKeepMigrationTest")
        #expect(ScoreKeepPhysicalMigrationTestIdentity.productionBundleIdentifier != ScoreKeepPhysicalMigrationTestIdentity.disposableBundleIdentifier)
    }

    @Test("default compiled mode is production outside migration test configurations")
    func defaultCompiledModeIsProduction() {
        switch ScoreKeepPhysicalMigrationTestMode.compiledMode {
        case .production:
            #expect(ScoreKeepPhysicalMigrationTestSafety.evaluate().authorization == .notMigrationTestBuild)
        case .legacyStore:
            #expect(ScoreKeepPhysicalMigrationTestSafety.evaluate().authorization == .authorizedLegacyOnly)
        case .proposedV2Migration:
            #expect(ScoreKeepPhysicalMigrationTestSafety.evaluate().authorization == .proposedMigrationDisabledPendingManualBaseline)
        }
    }

    @Test("legacy and proposed modes require the disposable bundle identity")
    func migrationModesRequireDisposableIdentity() {
        let legacyMismatch = ScoreKeepPhysicalMigrationTestSafety.evaluate(
            bundleIdentifier: ScoreKeepPhysicalMigrationTestIdentity.productionBundleIdentifier,
            mode: .legacyStore
        )
        let proposedMismatch = ScoreKeepPhysicalMigrationTestSafety.evaluate(
            bundleIdentifier: ScoreKeepPhysicalMigrationTestIdentity.productionBundleIdentifier,
            mode: .proposedV2Migration
        )
        #expect(legacyMismatch.authorization == .invalidBundleModePairing)
        #expect(proposedMismatch.authorization == .invalidBundleModePairing)
    }

    @Test("legacy mode is authorized only for unversioned baseline capture")
    func legacyModeIsLegacyOnly() {
        let safety = ScoreKeepPhysicalMigrationTestSafety.evaluate(
            bundleIdentifier: ScoreKeepPhysicalMigrationTestIdentity.disposableBundleIdentifier,
            mode: .legacyStore
        )
        #expect(safety.authorization == .authorizedLegacyOnly)
        #expect(safety.authorization.permitsProposedMigration == false)
        #expect(safety.stableDiagnosticCodes.contains("migrationTest.proposedNotRun"))
    }

    @Test("proposed mode is prepared but disabled pending manual baseline")
    func proposedModeIsDisabled() {
        let safety = ScoreKeepPhysicalMigrationTestSafety.evaluate(
            bundleIdentifier: ScoreKeepPhysicalMigrationTestIdentity.disposableBundleIdentifier,
            mode: .proposedV2Migration
        )
        #expect(safety.authorization == .proposedMigrationDisabledPendingManualBaseline)
        #expect(safety.authorization.permitsProposedMigration == false)
        #expect(safety.stableDiagnosticCodes.contains("migrationTest.requiresManualBaseline"))
    }

    @Test("diagnostic summary redacts paths operation ids and raw private data")
    func diagnosticsSummaryIsRedacted() throws {
        let root = try temporaryDirectory()
        let diagnostics = ScoreKeepPhysicalDeviceDiagnostics.current(
            protectedDataState: .available,
            baselineStatus: "baselinePending",
            fileManager: .default
        )
        let summary = diagnostics.copyableSummary
        #expect(summary.contains("Mode:"))
        #expect(summary.contains("Store:"))
        #expect(summary.contains("default.store"))
        #expect(summary.contains(root.path) == false)
        #expect(summary.localizedCaseInsensitiveContains("UUID") == false)
        #expect(summary.localizedCaseInsensitiveContains("keychain") == false)
        #expect(summary.localizedCaseInsensitiveContains("receipt") == false)
    }

    @Test("baseline capture requires legacy disposable identity")
    @MainActor
    func baselineCaptureRequiresLegacyDisposableIdentity() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let badSafety = ScoreKeepPhysicalMigrationTestSafety.evaluate(
            bundleIdentifier: ScoreKeepPhysicalMigrationTestIdentity.productionBundleIdentifier,
            mode: .legacyStore
        )
        #expect(throws: ScoreKeepMigrationBaselineCaptureError.invalidBundleIdentity) {
            try ScoreKeepMigrationBaselineCapture.capture(modelContext: context, safety: badSafety)
        }
    }

    @Test("baseline capture writes application support sidecar and reloads without mutating records")
    @MainActor
    func baselineCaptureWritesApplicationSupportSidecarAndReloadsWithoutMutatingRecords() throws {
        let root = try temporaryDirectory()
        let container = try makeContainer(url: root.appendingPathComponent("baseline.store"))
        let context = container.mainContext
        let graph = try insertRepresentativeGraph(context: context)
        let safety = ScoreKeepPhysicalMigrationTestSafety.evaluate(
            bundleIdentifier: ScoreKeepPhysicalMigrationTestIdentity.disposableBundleIdentifier,
            mode: .legacyStore
        )

        let beforeGames = try context.fetch(FetchDescriptor<Game>()).count
        let first = try ScoreKeepMigrationBaselineCapture.capture(modelContext: context, safety: safety, fileManager: .default, applicationSupportRoot: root)
        let sidecarURL = ScoreKeepPhysicalDeviceDiagnostics.baselineSidecarURL(fileManager: .default, applicationSupportRoot: root)
        let loadedFromFreshPath = ScoreKeepMigrationBaselineCapture.load(fileManager: .default, applicationSupportRoot: root)
        let launchReloadResult = ScoreKeepMigrationBaselineCapture.loadResult(fileManager: .default, applicationSupportRoot: root)
        let second = try ScoreKeepMigrationBaselineCapture.capture(modelContext: context, safety: safety, fileManager: .default, applicationSupportRoot: root)
        let afterGames = try context.fetch(FetchDescriptor<Game>()).count

        #expect(beforeGames == afterGames)
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))
        #expect(sidecarURL.path.hasPrefix(root.path))
        #expect(loadedFromFreshPath?.stableIdentityFingerprint == first.stableIdentityFingerprint)
        #expect(launchReloadResult.statusMessage == first.status)
        #expect(first.gameCount == 1)
        #expect(first.teamCount == 2)
        #expect(first.playerCount == 2)
        #expect(first.atbatCount == 2)
        #expect(first.lineupCount == 1)
        #expect(first.pitcherCount == 1)
        #expect(first.stableIdentityFingerprint == second.stableIdentityFingerprint)
        #expect(first.relationshipFingerprint == second.relationshipFingerprint)
        #expect(first.orderingFingerprint == second.orderingFingerprint)
        #expect(first.summary.contains(graph.home.name) == false)
        #expect(first.summary.contains(graph.player.name) == false)
    }

    @Test("missing and corrupt baseline sidecars fail explicitly")
    @MainActor
    func baselineLoadFailuresAreExplicit() throws {
        let root = try temporaryDirectory()
        let missing = ScoreKeepMigrationBaselineCapture.loadResult(fileManager: .default, applicationSupportRoot: root)
        #expect(missing == .missing)
        #expect(missing.statusMessage == "Baseline missing")

        let sidecarURL = ScoreKeepPhysicalDeviceDiagnostics.baselineSidecarURL(fileManager: .default, applicationSupportRoot: root)
        try FileManager.default.createDirectory(at: sidecarURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: sidecarURL)

        let corrupt = ScoreKeepMigrationBaselineCapture.loadResult(fileManager: .default, applicationSupportRoot: root)
        #expect(corrupt == .corrupt)
        #expect(corrupt.statusMessage == "Baseline corrupt or unsupported")
    }

    @Test("ScoreKeepApp production startup remains guarded and legacy")
    func productionStartupSourceRemainsLegacy() throws {
        let productionSafety = ScoreKeepPhysicalMigrationTestSafety.evaluate(
            bundleIdentifier: ScoreKeepPhysicalMigrationTestIdentity.productionBundleIdentifier,
            mode: .production
        )
        #expect(productionSafety.identity.isProductionIdentity)
        #expect(productionSafety.authorization == .notMigrationTestBuild)
        #expect(productionSafety.stableDiagnosticCodes == ["migrationTest.productionMode"])
    }

    @Test("physical migration execution requires explicit proposed disposable readiness")
    @MainActor
    func physicalMigrationExecutionRequiresExplicitProposedDisposableReadiness() throws {
        let root = try temporaryDirectory()
        let baseline = try baselineRecord()
        let safety = ScoreKeepPhysicalMigrationTestSafety.evaluate(
            bundleIdentifier: ScoreKeepPhysicalMigrationTestIdentity.disposableBundleIdentifier,
            mode: .proposedV2Migration
        )
        let operation = ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: "test-source",
            sourceSchema: .populatedCurrentUnversionedStore,
            targetSchema: .proposedV2,
            applicationMigrationGeneration: 1,
            operationUUID: UUID(uuidString: "00000000-0000-0000-0000-000000008888")!
        )
        let ready = ScoreKeepPhysicalMigrationExecutionPreflight(
            protectedDataState: .available,
            safety: safety,
            baselineLoadResult: .loaded(baseline),
            layout: ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: root),
            storeFamilyStatus: "default.store,default.store-wal,default.store-shm",
            storeFamilyIdentity: "store-family",
            operationIdentity: operation,
            journalStatus: "absent",
            backupStatus: "absent",
            capacityStatus: "capacity.sufficient",
            postMigrationBaselineStatus: "notRun",
            readinessCodes: []
        )
        #expect(ready.isReadyForFinalAuthorization)
        #expect(ready.readinessStatus == "readyForFinalManualAuthorization")

        let blocked = ScoreKeepPhysicalMigrationExecutionPreflight(
            protectedDataState: .unavailable,
            safety: safety,
            baselineLoadResult: .loaded(baseline),
            layout: ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: root),
            storeFamilyStatus: "default.store",
            storeFamilyIdentity: "store-family",
            operationIdentity: operation,
            journalStatus: "absent",
            backupStatus: "absent",
            capacityStatus: "capacity.sufficient",
            postMigrationBaselineStatus: "notRun",
            readinessCodes: ["migration.start.blocked.protectedDataUnavailable"]
        )
        #expect(blocked.isReadyForFinalAuthorization == false)
    }

    @Test("completed physical migration checkpoint blocks reauthorization")
    @MainActor
    func completedPhysicalMigrationCheckpointBlocksReauthorization() throws {
        let root = try temporaryDirectory()
        let baseline = try baselineRecord()
        let operation = ScoreKeepMigrationOperationIdentity(
            sourceStoreIdentity: "test-source",
            sourceSchema: .populatedCurrentUnversionedStore,
            targetSchema: .proposedV2,
            applicationMigrationGeneration: 1,
            operationUUID: UUID(uuidString: "00000000-0000-0000-0000-000000009999")!
        )
        let completed = ScoreKeepPhysicalMigrationExecutionPreflight(
            protectedDataState: .available,
            safety: ScoreKeepPhysicalMigrationTestSafety.evaluate(
                bundleIdentifier: ScoreKeepPhysicalMigrationTestIdentity.disposableBundleIdentifier,
                mode: .proposedV2Migration
            ),
            baselineLoadResult: .loaded(baseline),
            layout: ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: root),
            storeFamilyStatus: "default.store,default.store-wal,default.store-shm",
            storeFamilyIdentity: "store-family",
            operationIdentity: operation,
            journalStatus: ScoreKeepMigrationJournalPhase.completionRecorded.rawValue,
            backupStatus: "present",
            capacityStatus: "capacity.sufficient",
            postMigrationBaselineStatus: "matchesStoredLegacyBaseline",
            readinessCodes: ["migration.completed.reauthorizationBlocked"]
        )
        #expect(completed.isReadyForFinalAuthorization == false)
        #expect(completed.readinessStatus == "completedMigrationRecorded")
        #expect(completed.copyableSummary(result: nil).contains("Post-Migration Baseline: matchesStoredLegacyBaseline"))
    }

    @Test("blocked physical migration execution does not permit writes")
    @MainActor
    func blockedPhysicalMigrationExecutionDoesNotPermitWrites() throws {
        let root = try temporaryDirectory()
        let blocked = ScoreKeepPhysicalMigrationExecutionPreflight(
            protectedDataState: .available,
            safety: ScoreKeepPhysicalMigrationTestSafety.evaluate(
                bundleIdentifier: ScoreKeepPhysicalMigrationTestIdentity.productionBundleIdentifier,
                mode: .proposedV2Migration
            ),
            baselineLoadResult: .missing,
            layout: ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: root),
            storeFamilyStatus: "missing",
            storeFamilyIdentity: nil,
            operationIdentity: nil,
            journalStatus: "absent",
            backupStatus: "absent",
            capacityStatus: "capacity.sufficient",
            postMigrationBaselineStatus: "notRun",
            readinessCodes: ["migration.start.blocked.invalidBundle"]
        )
        let result = try ScoreKeepPhysicalMigrationExecutor.run(preflight: blocked)
        #expect(result.disposition == "blockedBeforeAuthorization")
        #expect(result.writeReadiness == "prohibited")
        #expect(result.diagnosticCodes.contains("migration.start.blocked.invalidBundle"))
    }

    private struct FixtureGraph {
        let home: Team
        let player: Player
    }

    @MainActor
    private func insertRepresentativeGraph(context: ModelContext) throws -> FixtureGraph {
        let visiting = Team(ident: UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!, name: "Visitors", coach: "", details: "")
        let home = Team(ident: UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!, name: "Home", coach: "", details: "", logo: Data([1, 2, 3]))
        let player = Player(identifier: UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!, name: "Player One", number: "1", position: "C", batDir: "R", batOrder: 1, team: home, photo: Data([4, 5]))
        let runner = Player(identifier: UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!, name: "Runner", number: "2", position: "SS", batDir: "L", batOrder: 2, team: home)
        let game = Game(ident: UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!, date: "Apr 4, 2026", location: "Test", highLights: "", hscore: 4, vscore: 3, vteam: visiting, hteam: home)
        let firstAtbat = Atbat(ident: UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!, game: game, team: home, player: runner, result: "Single", maxbase: "First", batOrder: 2, outAt: "", inning: 1, seq: 1, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
        let thirdOut = Atbat(ident: UUID(uuidString: "00000000-0000-0000-0000-00000000D002")!, game: game, team: home, player: player, result: "Fielder's Choice", maxbase: "First", batOrder: 1, outAt: "Home", inning: 1, seq: 2, col: 2, rbis: 0, outs: 3, sacFly: 0, sacBunt: 0, stolenBases: 0, playRec: "runner out", endOfInning: true)
        let lineup = Lineup(ident: UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!, everyoneHits: false, game: game, team: home, inning: 1, players: [player, runner])
        let pitcher = Pitcher(ident: UUID(uuidString: "00000000-0000-0000-0000-00000000F001")!, player: player, team: home, game: game, startInn: 1, sOuts: 0, sBats: 1, endInn: 1, eOuts: 3, eBats: 2)
        game.players = [player, runner]
        game.atbats = [firstAtbat, thirdOut]
        game.lineups = [lineup]
        game.pitchers = [pitcher]
        game.replaced = [runner]
        game.incomings = [player]
        home.players = [player, runner]
        home.games = [game]
        visiting.games = [game]
        context.insert(visiting)
        context.insert(home)
        context.insert(player)
        context.insert(runner)
        context.insert(game)
        context.insert(firstAtbat)
        context.insert(thirdOut)
        context.insert(lineup)
        context.insert(pitcher)
        try context.save()
        return FixtureGraph(home: home, player: player)
    }

    @MainActor
    private func makeContainer(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([Game.self, Team.self, Player.self, Atbat.self, Lineup.self, Pitcher.self])
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @MainActor
    private func baselineRecord() throws -> ScoreKeepMigrationBaselineRecord {
        let container = try makeContainer()
        let context = container.mainContext
        _ = try insertRepresentativeGraph(context: context)
        return try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: context)
    }

}

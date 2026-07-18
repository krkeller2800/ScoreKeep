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
        case .proposedV3Migration:
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
            mode: .proposedV3Migration
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
            mode: .proposedV3Migration
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
            mode: .proposedV3Migration
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
                mode: .proposedV3Migration
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
                mode: .proposedV3Migration
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

    @Test("post migration comparison accepts exact baseline before routed writes")
    @MainActor
    func postMigrationComparisonAcceptsExactBaselineBeforeRoutedWrites() throws {
        let pair = try comparisonPair()

        let result = try ScoreKeepPostMigrationAuthorizedAdditiveComparison.compare(
            proposedContainer: pair.proposed,
            originalContainer: pair.original,
            storedBaseline: pair.baseline
        )

        if result.status != .matchesStoredLegacyBaseline {
            Issue.record(Comment(rawValue: try comparisonFailureReport(failedCase: "exactBaseline", pair: pair, routedTeamIdentity: nil)))
        }
        #expect(result.status == .matchesStoredLegacyBaseline)
    }

    @Test("post migration comparison accepts one authorized additive team and evidence")
    @MainActor
    func postMigrationComparisonAcceptsAuthorizedAdditiveTeamAndEvidence() throws {
        let pair = try comparisonPair()
        try insertAuthorizedRoutedTeam(into: pair.proposed.mainContext)

        let result = try ScoreKeepPostMigrationAuthorizedAdditiveComparison.compare(
            proposedContainer: pair.proposed,
            originalContainer: pair.original,
            storedBaseline: pair.baseline
        )

        if result.status != .authorizedAdditiveChangeMatches {
            Issue.record(Comment(rawValue: try comparisonFailureReport(
                failedCase: "authorizedAdditive",
                pair: pair,
                routedTeamIdentity: UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!
            )))
        }
        #expect(result.status == .authorizedAdditiveChangeMatches)
        #expect(result.diagnosticCodes.contains("oneAuthorizedTeamAdded"))
        #expect(result.diagnosticCodes.contains("oneDurableOperationEvidenceRecord"))
    }

    @Test("post migration comparison rejects duplicate routed team")
    @MainActor
    func postMigrationComparisonRejectsDuplicateRoutedTeam() throws {
        let pair = try comparisonPair()
        try insertAuthorizedRoutedTeam(into: pair.proposed.mainContext)
        pair.proposed.mainContext.insert(Team(ident: UUID(uuidString: "00000000-0000-0000-0000-00000000A004")!, name: "Duplicate Temp", coach: "", details: ""))
        try pair.proposed.mainContext.save()

        let result = try ScoreKeepPostMigrationAuthorizedAdditiveComparison.compare(
            proposedContainer: pair.proposed,
            originalContainer: pair.original,
            storedBaseline: pair.baseline
        )

        #expect(result.status == .mismatchRequiresReview)
    }

    @Test("post migration comparison rejects changed original team")
    @MainActor
    func postMigrationComparisonRejectsChangedOriginalTeam() throws {
        let pair = try comparisonPair()
        try insertAuthorizedRoutedTeam(into: pair.proposed.mainContext)
        let teams = try pair.proposed.mainContext.fetch(FetchDescriptor<Team>())
        teams.first { $0.ident == UUID(uuidString: "00000000-0000-0000-0000-00000000A002")! }?.name = "Changed Home"
        try pair.proposed.mainContext.save()

        let result = try ScoreKeepPostMigrationAuthorizedAdditiveComparison.compare(
            proposedContainer: pair.proposed,
            originalContainer: pair.original,
            storedBaseline: pair.baseline
        )

        #expect(result.status == .mismatchRequiresReview)
    }

    @Test("post migration comparison rejects changed original game lineup atbat and pitcher data")
    @MainActor
    func postMigrationComparisonRejectsChangedOriginalGameLineupAtbatAndPitcherData() throws {
        try assertAuthorizedComparisonRejectsMutation { context in
            let games = try context.fetch(FetchDescriptor<Game>())
            games.first?.location = "Changed"
        }
        try assertAuthorizedComparisonRejectsMutation { context in
            let lineups = try context.fetch(FetchDescriptor<Lineup>())
            lineups.first?.inning = 2
        }
        try assertAuthorizedComparisonRejectsMutation { context in
            let atbats = try context.fetch(FetchDescriptor<Atbat>())
            atbats.first?.result = "Double"
        }
        try assertAuthorizedComparisonRejectsMutation { context in
            let pitchers = try context.fetch(FetchDescriptor<Pitcher>())
            pitchers.first?.strikeOuts = 1
        }
    }

    @Test("post migration comparison rejects unexpected relationship score substitution media and evidence changes")
    @MainActor
    func postMigrationComparisonRejectsUnexpectedRelationshipScoreSubstitutionMediaAndEvidenceChanges() throws {
        try assertAuthorizedComparisonRejectsMutation { context in
            let teams = try context.fetch(FetchDescriptor<Team>())
            let players = try context.fetch(FetchDescriptor<Player>())
            teams.first { $0.ident == UUID(uuidString: "00000000-0000-0000-0000-00000000A003")! }?.players = Array(players.prefix(1))
        }
        try assertAuthorizedComparisonRejectsMutation { context in
            let games = try context.fetch(FetchDescriptor<Game>())
            games.first?.hscore += 1
        }
        try assertAuthorizedComparisonRejectsMutation { context in
            let games = try context.fetch(FetchDescriptor<Game>())
            games.first?.incomings = []
        }
        try assertAuthorizedComparisonRejectsMutation { context in
            let teams = try context.fetch(FetchDescriptor<Team>())
            teams.first { $0.ident == UUID(uuidString: "00000000-0000-0000-0000-00000000A002")! }?.logo = Data([9, 9])
        }
        try assertAuthorizedComparisonRejectsMutation { context in
            context.insert(TeamCreationOperationEvidenceRecord(
                operationIdentity: "unexpected-second-evidence",
                targetTeamIdentity: UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!,
                requestFingerprint: "unexpected",
                phase: CanonicalTeamCreationOperationPhase.completed.rawValue,
                completionProof: CanonicalTeamCreationCompletionProof.completionMarkerRecorded.rawValue,
                finalDisposition: CanonicalTeamCreationFinalDisposition.createdAndVerified.rawValue,
                retryClassification: CanonicalTeamCreationRetryClassification.retryUnnecessaryCompletionProven.rawValue,
                reviewRequired: false,
                diagnosticCodesStorage: "",
                source: "test"
            ))
        }
    }

    private struct FixtureGraph {
        let home: Team
        let player: Player
    }

    private struct ComparisonPair {
        let original: ModelContainer
        let proposed: ModelContainer
        let baseline: ScoreKeepMigrationBaselineRecord
    }

    private struct DiagnosticCategory: Hashable {
        let name: String
        let expected: [String]
        let actual: [String]

        var differs: Bool { expected != actual }

        var summaryLine: String {
            [
                "category=\(name)",
                "status=\(differs ? "different" : "equal")",
                "expectedCount=\(expected.count)",
                "actualCount=\(actual.count)",
                "expectedFingerprint=\(privacyFingerprint(expected))",
                "actualFingerprint=\(privacyFingerprint(actual))"
            ].joined(separator: " ")
        }
    }

    @MainActor
    private func comparisonFailureReport(
        failedCase: String,
        pair: ComparisonPair,
        routedTeamIdentity: UUID?
    ) throws -> String {
        let categories = try diagnosticCategories(pair: pair, routedTeamIdentity: routedTeamIdentity)
        let exactCategories = try diagnosticCategories(pair: pair, routedTeamIdentity: nil)
        let additiveCategories: [DiagnosticCategory]
        if routedTeamIdentity != nil {
            additiveCategories = categories
        } else {
            let additivePair = try comparisonPair()
            try insertAuthorizedRoutedTeam(into: additivePair.proposed.mainContext)
            additiveCategories = try diagnosticCategories(pair: additivePair, routedTeamIdentity: UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!)
        }
        let exactDifferent = Set(exactCategories.filter(\.differs).map(\.name))
        let additiveDifferent = Set(additiveCategories.filter(\.differs).map(\.name))
        let sameDifferentCategories = exactDifferent.intersection(additiveDifferent).sorted()
        return ([
            "privacy-safe post-migration comparison diagnostic",
            "failedCase=\(failedCase)",
            "sameDifferentCategories=\(sameDifferentCategories.isEmpty ? "none" : sameDifferentCategories.joined(separator: ","))"
        ] + categories.map(\.summaryLine)).joined(separator: "\n")
    }

    @MainActor
    private func diagnosticCategories(pair: ComparisonPair, routedTeamIdentity: UUID?) throws -> [DiagnosticCategory] {
        let originalContext = ModelContext(pair.original)
        originalContext.autosaveEnabled = false
        let proposedContext = ModelContext(pair.proposed)
        proposedContext.autosaveEnabled = false
        let original = try DiagnosticSnapshot.capture(modelContext: originalContext)
        let proposed = try DiagnosticSnapshot.capture(modelContext: proposedContext, excludingTeamIdentity: routedTeamIdentity)
        let evidence = try proposedContext.fetch(FetchDescriptor<TeamCreationOperationEvidenceRecord>())
        let expectedEvidence = routedTeamIdentity.map { identity in
            [Self.operationEvidenceValue(
                operationIdentity: "ui-simple-team-op-authorized-additive",
                targetTeamIdentity: identity,
                requestFingerprint: "authorized-additive-fingerprint",
                phase: CanonicalTeamCreationOperationPhase.completed.rawValue,
                completionProof: CanonicalTeamCreationCompletionProof.completionMarkerRecorded.rawValue,
                finalDisposition: CanonicalTeamCreationFinalDisposition.createdAndVerified.rawValue,
                retryClassification: CanonicalTeamCreationRetryClassification.retryUnnecessaryCompletionProven.rawValue,
                reviewRequired: false,
                diagnosticCodesStorage: CanonicalTeamCreationDiagnosticCode.executorCompletionProven.rawValue,
                source: "test"
            )]
        } ?? []
        return [
            DiagnosticCategory(name: "games", expected: original.games, actual: proposed.games),
            DiagnosticCategory(name: "teams", expected: original.teams, actual: proposed.teams),
            DiagnosticCategory(name: "players", expected: original.players, actual: proposed.players),
            DiagnosticCategory(name: "lineups", expected: original.lineups, actual: proposed.lineups),
            DiagnosticCategory(name: "at-bats", expected: original.atbats, actual: proposed.atbats),
            DiagnosticCategory(name: "pitchers", expected: original.pitchers, actual: proposed.pitchers),
            DiagnosticCategory(name: "canonical relationships", expected: original.relationships, actual: proposed.relationships),
            DiagnosticCategory(name: "score", expected: original.scores, actual: proposed.scores),
            DiagnosticCategory(name: "substitutions", expected: original.substitutions, actual: proposed.substitutions),
            DiagnosticCategory(name: "media", expected: original.media, actual: proposed.media),
            DiagnosticCategory(name: "operation evidence", expected: expectedEvidence, actual: evidence.map(Self.operationEvidenceValue).sorted())
        ]
    }

    private struct DiagnosticSnapshot {
        let games: [String]
        let teams: [String]
        let players: [String]
        let lineups: [String]
        let atbats: [String]
        let pitchers: [String]
        let relationships: [String]
        let scores: [String]
        let substitutions: [String]
        let media: [String]

        @MainActor
        static func capture(modelContext: ModelContext, excludingTeamIdentity: UUID? = nil) throws -> DiagnosticSnapshot {
            let games = try modelContext.fetch(FetchDescriptor<Game>())
            let teams = try modelContext.fetch(FetchDescriptor<Team>()).filter { $0.ident != excludingTeamIdentity }
            let players = try modelContext.fetch(FetchDescriptor<Player>())
            let lineups = try modelContext.fetch(FetchDescriptor<Lineup>())
            let atbats = try modelContext.fetch(FetchDescriptor<Atbat>())
            let pitchers = try modelContext.fetch(FetchDescriptor<Pitcher>())
            return DiagnosticSnapshot(
                games: games.map(gameValue).sorted(),
                teams: teams.map { teamValue($0, games: games) }.sorted(),
                players: players.map(playerValue).sorted(),
                lineups: lineups.map(lineupValue).sorted(),
                atbats: atbats.map(atbatValue).sorted(),
                pitchers: pitchers.map(pitcherValue).sorted(),
                relationships: relationshipValues(games: games, teams: teams, players: players, lineups: lineups, atbats: atbats, pitchers: pitchers),
                scores: games.map { scoreValue($0) }.sorted(),
                substitutions: games.map { substitutionValue($0) }.sorted(),
                media: mediaValues(teams: teams, players: players)
            )
        }
    }

    private static func gameValue(_ game: Game) -> String {
        [
            "game", game.ident.uuidString, game.date, game.location, game.highLights,
            String(game.hscore), String(game.vscore), String(game.everyOneHits), String(game.numInnings),
            game.vteam?.ident.uuidString ?? "nil", game.hteam?.ident.uuidString ?? "nil",
            game.players.map { $0.identifier.uuidString }.sorted().joined(separator: ","),
            game.atbats.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            game.lineups.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            game.pitchers.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            game.replaced.map { $0.identifier.uuidString }.joined(separator: ","),
            game.incomings.map { $0.identifier.uuidString }.joined(separator: ",")
        ].joined(separator: "|")
    }

    private static func teamValue(_ team: Team, games: [Game]) -> String {
        let gameIdentities = games.filter { $0.hteam?.ident == team.ident || $0.vteam?.ident == team.ident }
            .map { $0.ident.uuidString }
            .sorted()
            .joined(separator: ",")
        return [
            "team", team.ident.uuidString, team.name, team.coach, team.details,
            team.players.map { $0.identifier.uuidString }.sorted().joined(separator: ","),
            gameIdentities,
            dataFingerprint(team.logo)
        ].joined(separator: "|")
    }

    private static func playerValue(_ player: Player) -> String {
        [
            "player", player.identifier.uuidString, player.name, player.number, player.position, player.batDir,
            String(player.batOrder), player.team?.ident.uuidString ?? "nil",
            player.atbat.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            dataFingerprint(player.photo)
        ].joined(separator: "|")
    }

    private static func lineupValue(_ lineup: Lineup) -> String {
        [
            "lineup", lineup.ident.uuidString, String(lineup.everyoneHits), lineup.game.ident.uuidString,
            lineup.team.ident.uuidString, String(lineup.inning),
            lineup.players.sorted { lhs, rhs in
                lhs.batOrder == rhs.batOrder ? lhs.identifier.uuidString < rhs.identifier.uuidString : lhs.batOrder < rhs.batOrder
            }
            .map { $0.identifier.uuidString }
            .joined(separator: ",")
        ].joined(separator: "|")
    }

    private static func atbatValue(_ atbat: Atbat) -> String {
        [
            "atbat", atbat.ident.uuidString, atbat.game.ident.uuidString, atbat.team.ident.uuidString,
            atbat.player.identifier.uuidString, atbat.result, atbat.maxbase, String(atbat.batOrder),
            atbat.outAt, String(Double(atbat.inning)), String(atbat.seq), String(atbat.col),
            String(atbat.rbis), String(atbat.outs), String(atbat.sacFly), String(atbat.sacBunt),
            String(atbat.stolenBases), String(atbat.earnedRun), atbat.playRec, String(atbat.endOfInning)
        ].joined(separator: "|")
    }

    private static func pitcherValue(_ pitcher: Pitcher) -> String {
        [
            "pitcher", pitcher.ident.uuidString, pitcher.player.identifier.uuidString, pitcher.team.ident.uuidString,
            pitcher.game.ident.uuidString, String(pitcher.startInn), String(pitcher.sOuts), String(pitcher.sBats),
            String(pitcher.endInn), String(pitcher.eOuts), String(pitcher.eBats), String(pitcher.strikeOuts),
            String(pitcher.walks), String(pitcher.hits), String(pitcher.runs), String(pitcher.won)
        ].joined(separator: "|")
    }

    private static func relationshipValues(
        games: [Game],
        teams: [Team],
        players: [Player],
        lineups: [Lineup],
        atbats: [Atbat],
        pitchers: [Pitcher]
    ) -> [String] {
        var values: [String] = []
        values += games.map { game in
            [
                "game", game.ident.uuidString,
                game.hteam?.ident.uuidString ?? "nil",
                game.vteam?.ident.uuidString ?? "nil",
                game.players.map { $0.identifier.uuidString }.sorted().joined(separator: ","),
                game.atbats.map { $0.ident.uuidString }.sorted().joined(separator: ","),
                game.lineups.map { $0.ident.uuidString }.sorted().joined(separator: ","),
                game.pitchers.map { $0.ident.uuidString }.sorted().joined(separator: ",")
            ].joined(separator: "|")
        }
        values += teams.map { team in
            [
                "team", team.ident.uuidString,
                team.players.map { $0.identifier.uuidString }.sorted().joined(separator: ","),
                games.filter { $0.hteam?.ident == team.ident || $0.vteam?.ident == team.ident }.map { $0.ident.uuidString }.sorted().joined(separator: ",")
            ].joined(separator: "|")
        }
        values += players.map { player in
            ["player", player.identifier.uuidString, player.team?.ident.uuidString ?? "nil", player.atbat.map { $0.ident.uuidString }.sorted().joined(separator: ",")].joined(separator: "|")
        }
        values += lineups.map { lineup in
            [
                "lineup", lineup.ident.uuidString, lineup.game.ident.uuidString, lineup.team.ident.uuidString,
                lineup.players.sorted { lhs, rhs in
                    lhs.batOrder == rhs.batOrder ? lhs.identifier.uuidString < rhs.identifier.uuidString : lhs.batOrder < rhs.batOrder
                }
                .map { $0.identifier.uuidString }
                .joined(separator: ",")
            ].joined(separator: "|")
        }
        values += atbats.map { ["atbat", $0.ident.uuidString, $0.game.ident.uuidString, $0.team.ident.uuidString, $0.player.identifier.uuidString].joined(separator: "|") }
        values += pitchers.map { ["pitcher", $0.ident.uuidString, $0.game.ident.uuidString, $0.team.ident.uuidString, $0.player.identifier.uuidString].joined(separator: "|") }
        return values.sorted()
    }

    private static func scoreValue(_ game: Game) -> String {
        [game.ident.uuidString, "h=\(game.hscore)", "v=\(game.vscore)", "innings=\(game.numInnings)"].joined(separator: "|")
    }

    private static func substitutionValue(_ game: Game) -> String {
        [
            game.ident.uuidString,
            "replaced=\(game.replaced.map { $0.identifier.uuidString }.joined(separator: ","))",
            "incoming=\(game.incomings.map { $0.identifier.uuidString }.joined(separator: ","))"
        ].joined(separator: "|")
    }

    private static func mediaValues(teams: [Team], players: [Player]) -> [String] {
        (teams.map { ["team", $0.ident.uuidString, dataFingerprint($0.logo)].joined(separator: "|") }
            + players.map { ["player", $0.identifier.uuidString, dataFingerprint($0.photo)].joined(separator: "|") })
            .sorted()
    }

    private static func operationEvidenceValue(_ record: TeamCreationOperationEvidenceRecord) -> String {
        operationEvidenceValue(
            operationIdentity: record.operationIdentity,
            targetTeamIdentity: record.targetTeamIdentity,
            requestFingerprint: record.requestFingerprint,
            phase: record.phase,
            completionProof: record.completionProof,
            finalDisposition: record.finalDisposition,
            retryClassification: record.retryClassification,
            reviewRequired: record.reviewRequired,
            diagnosticCodesStorage: record.diagnosticCodesStorage,
            source: record.source
        )
    }

    private static func operationEvidenceValue(
        operationIdentity: String,
        targetTeamIdentity: UUID,
        requestFingerprint: String,
        phase: String,
        completionProof: String,
        finalDisposition: String,
        retryClassification: String,
        reviewRequired: Bool,
        diagnosticCodesStorage: String,
        source: String
    ) -> String {
        [
            operationIdentity,
            targetTeamIdentity.uuidString,
            requestFingerprint,
            phase,
            completionProof,
            finalDisposition,
            retryClassification,
            String(reviewRequired),
            diagnosticCodesStorage,
            source
        ].joined(separator: "|")
    }

    private static func privacyFingerprint(_ values: [String]) -> String {
        shortStableFingerprint(values.joined(separator: "\n"))
    }

    private static func dataFingerprint(_ data: Data?) -> String {
        guard let data, data.isEmpty == false else { return "absent" }
        return shortStableFingerprint(data.map { String(format: "%02x", $0) }.joined())
    }

    private static func shortStableFingerprint(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    @MainActor
    private func comparisonPair() throws -> ComparisonPair {
        let original = try makeContainer()
        _ = try insertRepresentativeGraph(context: original.mainContext)
        let proposed = try makeProposedContainer()
        _ = try insertRepresentativeGraph(context: proposed.mainContext)
        return ComparisonPair(
            original: original,
            proposed: proposed,
            baseline: try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: original.mainContext)
        )
    }

    @MainActor
    private func assertAuthorizedComparisonRejectsMutation(_ mutate: (ModelContext) throws -> Void) throws {
        let pair = try comparisonPair()
        try insertAuthorizedRoutedTeam(into: pair.proposed.mainContext)
        try mutate(pair.proposed.mainContext)
        try pair.proposed.mainContext.save()
        let result = try ScoreKeepPostMigrationAuthorizedAdditiveComparison.compare(
            proposedContainer: pair.proposed,
            originalContainer: pair.original,
            storedBaseline: pair.baseline
        )
        #expect(result.status == .mismatchRequiresReview)
    }

    @MainActor
    private func insertAuthorizedRoutedTeam(into context: ModelContext) throws {
        let routedTeamIdentity = UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!
        context.insert(Team(ident: routedTeamIdentity, name: "Temporary Route Team", coach: "", details: ""))
        context.insert(TeamCreationOperationEvidenceRecord(
            operationIdentity: "ui-simple-team-op-authorized-additive",
            targetTeamIdentity: routedTeamIdentity,
            requestFingerprint: "authorized-additive-fingerprint",
            phase: CanonicalTeamCreationOperationPhase.completed.rawValue,
            completionProof: CanonicalTeamCreationCompletionProof.completionMarkerRecorded.rawValue,
            finalDisposition: CanonicalTeamCreationFinalDisposition.createdAndVerified.rawValue,
            retryClassification: CanonicalTeamCreationRetryClassification.retryUnnecessaryCompletionProven.rawValue,
            reviewRequired: false,
            diagnosticCodesStorage: CanonicalTeamCreationDiagnosticCode.executorCompletionProven.rawValue,
            source: "test"
        ))
        try context.save()
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
        player.atbat = [thirdOut]
        runner.atbat = [firstAtbat]
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

    @MainActor
    private func makeProposedContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V2.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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

import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Legacy scoring operation evidence")
struct LegacyScoringOperationEvidenceTests {
    @Test("V1 V2 V3 remain frozen and V4 adds one Legacy scoring operation evidence model")
    func schemaInventoryPreservesFrozenVersionsAndAddsOneV4Model() {
        let v1 = names(ScoreKeepProposedVersionedSchema.V1.self)
        let v2 = names(ScoreKeepProposedVersionedSchema.V2.self)
        let v3 = names(ScoreKeepProposedVersionedSchema.V3.self)
        let v4 = names(ScoreKeepProposedVersionedSchema.V4.self)

        #expect(ScoreKeepProposedVersionedSchema.V1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(ScoreKeepProposedVersionedSchema.V2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(ScoreKeepProposedVersionedSchema.V3.versionIdentifier == Schema.Version(3, 0, 0))
        #expect(ScoreKeepProposedVersionedSchema.V4.versionIdentifier == Schema.Version(4, 0, 0))
        #expect(v1.count == 6)
        #expect(v2.count == 7)
        #expect(v3.count == 12)
        #expect(v4.count == 13)
        #expect(Set(v3).isSubset(of: Set(v4)))
        #expect(Set(v4).subtracting(v3) == Set(LegacyScoringOperationEvidenceModelBoundary.implementationModelNames))
        #expect(Set(v4).count == v4.count)
        #expect(ScoreKeepProposedSchemaAssessment.current.proposedV4AddsOnlyLegacyScoringOperationEvidence)
        #expect(ScoreKeepProposedSchemaAssessment.current.productionContainerTargetsProposedV3)
        #expect(ScoreKeepProposedLegacyScoringOperationEvidenceMigrationPlan.schemas.map { String(describing: $0).components(separatedBy: ".").last ?? "" } == ["V3", "V4"])
    }

    @Test("V3 store migrates to V4 with zero historical Legacy scoring operation evidence")
    func v3StoreMigratesToV4WithZeroHistoricalOperationEvidence() throws {
        let url = temporaryStoreURL("LegacyEvidenceV3ToV4")
        let ids = FixtureIDs()
        do {
            let environment = try fileBackedEnvironment(schema: ScoreKeepProposedVersionedSchema.V3.self, url: url)
            try insertLegacyFixture(ids: ids, context: environment.context)
            try environment.context.save()
            #expect(try environment.context.fetch(FetchDescriptor<CanonicalGameHistoryRecord>()).count == 1)
        }

        let migrated = try fileBackedEnvironment(
            schema: ScoreKeepProposedVersionedSchema.V4.self,
            url: url,
            migrationPlan: ScoreKeepProposedLegacyScoringOperationEvidenceMigrationPlan.self
        )
        let baseline = try ScoreKeepMigrationBaselineCapture.makeRecord(modelContext: migrated.context)

        #expect(baseline.gameCount == 1)
        #expect(baseline.teamCount == 1)
        #expect(baseline.playerCount == 1)
        #expect(baseline.atbatCount == 1)
        #expect(baseline.teamCreationOperationEvidenceCount == 1)
        #expect(baseline.canonicalHistoryCount == 1)
        #expect(baseline.canonicalOperationCount == 1)
        #expect(baseline.legacyScoringOperationEvidenceCount == 0)
    }

    @Test("operation evidence and deterministic request fingerprint round trip")
    func operationEvidenceAndFingerprintRoundTrip() throws {
        let environment = try inMemoryV4Environment()
        let request = request()
        let fingerprint = LegacyScoringOperationRequestFingerprint(request)
        environment.context.insert(LegacyScoringOperationEvidenceRecord(
            operationIdentity: request.operationIdentity,
            requestFingerprint: fingerprint.rawValue,
            targetGameIdentity: request.targetGameIdentity,
            targetAtbatIdentity: request.targetAtbatIdentity,
            submissionFamily: request.submissionFamily,
            acceptedResultClassification: request.acceptedResultClassification,
            acceptedOutcomeReference: request.acceptedOutcomeReference
        ))
        try environment.context.save()

        let reload = ModelContext(environment.container)
        let stored = try reload.fetch(FetchDescriptor<LegacyScoringOperationEvidenceRecord>()).single()
        #expect(stored.operationIdentity == request.operationIdentity)
        #expect(stored.requestFingerprint == fingerprint.rawValue)
        #expect(stored.targetGameIdentity == request.targetGameIdentity)
        #expect(stored.targetAtbatIdentity == request.targetAtbatIdentity)
        #expect(stored.submissionFamily == LegacyScoringOperationEvidenceConstants.ordinarySubmissionFamily)
    }

    @Test("atomic Legacy mutation plus evidence succeeds together")
    func atomicLegacyMutationPlusEvidenceSucceedsTogether() throws {
        let environment = try inMemoryV4Environment()
        let ids = try insertLegacyFixture(context: environment.context)
        let request = request(ids: ids, result: "Single")

        let result = LegacyScoringOperationEvidenceAdapter(container: environment.container).applyUsingDedicatedContext(request) { context in
            let atbat = try fetchAtbat(ids.atbat, context: context)
            atbat.result = "Single"
            atbat.maxbase = "First"
        }
        let snapshot = try Snapshot(container: environment.container)

        #expect(result.transaction.disposition == .success)
        #expect(result.saveResult == .succeeded)
        #expect(snapshot.atbatResult == "Single")
        #expect(snapshot.evidenceCount == 1)
        #expect(snapshot.canonicalCount == 1)
    }

    @Test("injected save failure persists neither Legacy mutation nor operation evidence")
    func injectedSaveFailurePersistsNeitherLegacyMutationNorEvidence() throws {
        let environment = try inMemoryV4Environment()
        let ids = try insertLegacyFixture(context: environment.context)
        let request = request(ids: ids, result: "Double")
        let adapter = LegacyScoringOperationEvidenceAdapter(
            container: environment.container,
            dependencies: LegacyScoringOperationEvidenceDependencies(injectedFailures: [.save])
        )

        let result = adapter.applyUsingDedicatedContext(request) { context in
            let atbat = try fetchAtbat(ids.atbat, context: context)
            atbat.result = "Double"
            atbat.maxbase = "Second"
        }
        let snapshot = try Snapshot(container: environment.container)

        #expect(result.transaction.disposition == .saveFailed)
        #expect(result.transaction.retrySafety == .safe)
        #expect(snapshot.atbatResult == "Result")
        #expect(snapshot.evidenceCount == 0)
    }

    @Test("exact retry returns existing evidence without second mutation")
    func exactRetryReturnsExistingEvidenceWithoutSecondMutation() throws {
        let environment = try inMemoryV4Environment()
        let ids = try insertLegacyFixture(context: environment.context)
        let request = request(ids: ids, result: "Single")
        let adapter = LegacyScoringOperationEvidenceAdapter(container: environment.container)
        var mutationCount = 0

        let first = adapter.applyUsingDedicatedContext(request) { context in
            mutationCount += 1
            try fetchAtbat(ids.atbat, context: context).result = "Single"
        }
        let retry = adapter.applyUsingDedicatedContext(request) { context in
            mutationCount += 1
            try fetchAtbat(ids.atbat, context: context).result = "Triple"
        }
        let snapshot = try Snapshot(container: environment.container)

        #expect(first.transaction.disposition == .success)
        #expect(retry.transaction.disposition == .duplicateAlreadyApplied)
        #expect(retry.idempotencyResult == .exactRetryAlreadyAccepted)
        #expect(mutationCount == 1)
        #expect(snapshot.atbatResult == "Single")
        #expect(snapshot.evidenceCount == 1)
    }

    @Test("conflicting fingerprint fails closed without Legacy mutation")
    func conflictingFingerprintFailsClosedWithoutMutation() throws {
        let environment = try inMemoryV4Environment()
        let ids = try insertLegacyFixture(context: environment.context)
        let adapter = LegacyScoringOperationEvidenceAdapter(container: environment.container)
        let first = request(ids: ids, result: "Single")
        let conflict = request(ids: ids, result: "Double")

        _ = adapter.applyUsingDedicatedContext(first) { context in
            try fetchAtbat(ids.atbat, context: context).result = "Single"
        }
        let result = adapter.applyUsingDedicatedContext(conflict) { context in
            try fetchAtbat(ids.atbat, context: context).result = "Double"
        }
        let snapshot = try Snapshot(container: environment.container)

        #expect(result.transaction.disposition == .contradictory)
        #expect(result.idempotencyResult == .conflictingOperationIdentity)
        #expect(snapshot.atbatResult == "Single")
        #expect(snapshot.evidenceCount == 1)
    }

    @Test("fresh context lookup resolves accepted conflict no evidence and performs no writes")
    func freshContextLookupClassifiesEvidenceWithoutWrites() throws {
        let environment = try inMemoryV4Environment()
        let ids = try insertLegacyFixture(context: environment.context)
        let accepted = request(ids: ids, result: "Single")
        let unrelated = request(ids: ids, operation: FixtureIDs.unrelatedOperation, result: "Single")
        _ = LegacyScoringOperationEvidenceAdapter(container: environment.container).applyUsingDedicatedContext(accepted) { context in
            try fetchAtbat(ids.atbat, context: context).result = "Single"
        }

        let lookup = LegacyScoringOperationEvidenceFreshLookup(container: environment.container)
        let exact = lookup.lookup(accepted)
        let conflict = lookup.lookup(request(ids: ids, result: "Double"))
        let missing = lookup.lookup(unrelated)
        let snapshot = try Snapshot(container: environment.container)

        #expect(exact.classification == .acceptedExactRetry)
        #expect(conflict.classification == .conflictingReuse)
        #expect(missing.classification == .noEvidence)
        #expect(exact.lookupPerformedWrites == false)
        #expect(conflict.lookupPerformedWrites == false)
        #expect(missing.lookupPerformedWrites == false)
        #expect(snapshot.evidenceCount == 1)
    }

    @Test("ordinary live scoring coordinator remains unrouted from operation evidence")
    func ordinaryLiveScoringCoordinatorRemainsUnroutedFromOperationEvidence() throws {
        let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = projectRoot.appendingPathComponent("ScoreKeep/Common/LiveScoringWorkflowCoordinator.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("LegacyScoringOperationEvidenceAdapter") == false)
        #expect(source.contains("LegacyScoringOperationEvidenceRecord") == false)
        #expect(source.contains("CanonicalScoringTransactionAdapter") == false)
    }
}

private struct FixtureIDs: Hashable {
    static let operation = UUID(uuidString: "10000000-0000-0000-0000-0000000077b0")!
    static let unrelatedOperation = UUID(uuidString: "10000000-0000-0000-0000-0000000077b9")!
    let game = UUID(uuidString: "10000000-0000-0000-0000-0000000077b1")!
    let team = UUID(uuidString: "10000000-0000-0000-0000-0000000077b2")!
    let player = UUID(uuidString: "10000000-0000-0000-0000-0000000077b3")!
    let atbat = UUID(uuidString: "10000000-0000-0000-0000-0000000077b4")!
    let teamOperation = UUID(uuidString: "10000000-0000-0000-0000-0000000077b5")!
    let canonicalHistory = UUID(uuidString: "10000000-0000-0000-0000-0000000077b6")!
    let canonicalOperation = UUID(uuidString: "10000000-0000-0000-0000-0000000077b7")!
}

private struct Snapshot {
    let atbatResult: String
    let evidenceCount: Int
    let canonicalCount: Int

    @MainActor
    init(container: ModelContainer) throws {
        let context = ModelContext(container)
        atbatResult = try context.fetch(FetchDescriptor<Atbat>()).single().result
        evidenceCount = try context.fetch(FetchDescriptor<LegacyScoringOperationEvidenceRecord>()).count
        canonicalCount = try context.fetch(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>()).count
    }
}

@MainActor
private func names(_ schema: any VersionedSchema.Type) -> [String] {
    schema.models.map { String(describing: $0) }.sorted()
}

@MainActor
private func inMemoryV4Environment() throws -> (container: ModelContainer, context: ModelContext) {
    let schema = Schema(versionedSchema: ScoreKeepProposedVersionedSchema.V4.self)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return (container, ModelContext(container))
}

@MainActor
private func fileBackedEnvironment(
    schema schemaType: any VersionedSchema.Type,
    url: URL,
    migrationPlan: (any SchemaMigrationPlan.Type)? = nil
) throws -> (container: ModelContainer, context: ModelContext) {
    let schema = Schema(versionedSchema: schemaType)
    let configuration = ModelConfiguration("LegacyScoringOperationEvidenceTests", url: url)
    let container = try ModelContainer(for: schema, migrationPlan: migrationPlan, configurations: [configuration])
    return (container, ModelContext(container))
}

private func temporaryStoreURL(_ prefix: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("Store.sqlite")
}

@MainActor
@discardableResult
private func insertLegacyFixture(ids: FixtureIDs = FixtureIDs(), context: ModelContext) throws -> FixtureIDs {
    let team = Team(ident: ids.team, name: "Fixture Team", coach: "", details: "")
    let player = Player(identifier: ids.player, name: "Fixture Player", number: "1", position: "Catcher", batDir: "Right", batOrder: 1, team: team)
    let game = Game(ident: ids.game, date: "2026-07-18", location: "Fixture Park", highLights: "", hscore: 0, vscore: 0, vteam: team)
    let atbat = Atbat(
        ident: ids.atbat,
        game: game,
        team: team,
        player: player,
        result: "Result",
        maxbase: "No Bases",
        batOrder: 1,
        outAt: "Safe",
        inning: 1,
        seq: 1,
        col: 1,
        rbis: 0,
        outs: 0,
        sacFly: 0,
        sacBunt: 0,
        stolenBases: 0
    )
    let teamEvidence = TeamCreationOperationEvidenceRecord(
        operationIdentity: ids.teamOperation.uuidString,
        targetTeamIdentity: ids.team,
        requestFingerprint: "team-fingerprint",
        phase: "completed",
        completionProof: "saved",
        finalDisposition: "accepted",
        retryClassification: "firstInvocation",
        reviewRequired: false,
        diagnosticCodesStorage: "",
        source: "synthetic"
    )
    let history = CanonicalGameHistoryRecord(historyIdentity: ids.canonicalHistory, gameIdentity: ids.game, game: game)
    let canonicalOperation = CanonicalScoringOperationEvidenceRecord(
        operationIdentity: ids.canonicalOperation,
        gameIdentity: ids.game,
        operationKind: CanonicalScoringPersistenceConstants.operationScoringKind,
        requestFingerprint: "canonical-fingerprint",
        disposition: CanonicalScoringPersistenceConstants.operationAcceptedDisposition,
        acceptedEventIdentity: nil,
        commitSequence: 1,
        history: history
    )
    history.operations = [canonicalOperation]
    game.players = [player]
    game.atbats = [atbat]
    team.players = [player]
    team.games = [game]
    player.atbat = [atbat]

    context.insert(team)
    context.insert(player)
    context.insert(game)
    context.insert(atbat)
    context.insert(teamEvidence)
    context.insert(history)
    context.insert(canonicalOperation)
    try context.save()
    return ids
}

@MainActor
private func request(
    ids: FixtureIDs = FixtureIDs(),
    operation: UUID = FixtureIDs.operation,
    result: String = "Single"
) -> LegacyScoringOperationRequestFacts {
    LegacyScoringOperationRequestFacts(
        operationIdentity: operation,
        targetGameIdentity: ids.game,
        targetAtbatIdentity: ids.atbat,
        submissionFamily: LegacyScoringOperationEvidenceConstants.ordinarySubmissionFamily,
        acceptedResultClassification: result,
        acceptedOutcomeReference: "atbat:\(ids.atbat.uuidString.lowercased())",
        deterministicRequestFacts: [
            "result=\(result)",
            "maxbase=\(result == "Double" ? "Second" : "First")",
            "rbis=0",
            "outs=0"
        ]
    )
}

@MainActor
private func fetchAtbat(_ identity: UUID, context: ModelContext) throws -> Atbat {
    let descriptor = FetchDescriptor<Atbat>(predicate: #Predicate { $0.ident == identity })
    return try #require(try context.fetch(descriptor).first)
}

private extension Array {
    func single() throws -> Element {
        try #require(count == 1)
        return self[0]
    }
}

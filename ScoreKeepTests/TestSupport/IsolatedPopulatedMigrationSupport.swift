import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

struct PopulatedMigrationVerificationIDs: Hashable, Sendable {
    static let sourceTarget = "isolated-current-swiftdata-target"
    static let operation = "populated-migration-operation-001"
    static let secondOperation = "populated-migration-operation-002"
    static let conflictingOperation = "conflicting-populated-migration-operation"

    static let visitingTeam = fixedUUID("00000000-0000-0000-0000-000000004101")
    static let homeTeam = fixedUUID("00000000-0000-0000-0000-000000004102")
    static let neutralTeam = fixedUUID("00000000-0000-0000-0000-000000004103")
    static let visitingPlayerOne = fixedUUID("00000000-0000-0000-0000-000000004201")
    static let visitingPlayerTwo = fixedUUID("00000000-0000-0000-0000-000000004202")
    static let homePlayerOne = fixedUUID("00000000-0000-0000-0000-000000004203")
    static let homePlayerTwo = fixedUUID("00000000-0000-0000-0000-000000004204")
    static let gameOne = fixedUUID("00000000-0000-0000-0000-000000004301")
    static let gameTwo = fixedUUID("00000000-0000-0000-0000-000000004302")
    static let eventOne = fixedUUID("00000000-0000-0000-0000-000000004401")
    static let eventTwo = fixedUUID("00000000-0000-0000-0000-000000004402")
    static let eventThree = fixedUUID("00000000-0000-0000-0000-000000004403")
    static let lineupOne = fixedUUID("00000000-0000-0000-0000-000000004501")
    static let lineupTwo = fixedUUID("00000000-0000-0000-0000-000000004502")
    static let pitcherOne = fixedUUID("00000000-0000-0000-0000-000000004601")
    static let pitcherTwo = fixedUUID("00000000-0000-0000-0000-000000004602")

    static func fixedUUID(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}

struct IsolatedPopulatedMigrationTeam: Hashable, Sendable {
    let id: UUID?
    let name: String
    let coach: String
    let details: String
    let logo: Data?
}

struct IsolatedPopulatedMigrationPlayer: Hashable, Sendable {
    let id: UUID?
    let name: String
    let number: String
    let position: String
    let batDirection: String
    let batOrder: Int
    let teamID: UUID?
    let photo: Data?
}

struct IsolatedPopulatedMigrationGame: Hashable, Sendable {
    let id: UUID?
    let date: String
    let location: String
    let highlights: String
    let storedHomeScore: Int?
    let storedVisitingScore: Int?
    let replayHomeScore: Int?
    let replayVisitingScore: Int?
    let everyoneHits: Bool
    let innings: Int
    let visitingTeamID: UUID?
    let homeTeamID: UUID?
    let participantIDs: [UUID]
    let replacedPlayerIDs: [UUID]
    let incomingPlayerIDs: [UUID]
}

struct IsolatedPopulatedMigrationAtbat: Hashable, Sendable {
    let id: UUID?
    let gameID: UUID?
    let teamID: UUID?
    let playerID: UUID?
    let result: String
    let maxbase: String
    let batOrder: Int
    let outAt: String
    let inning: Double
    let sequence: Int
    let scorecardColumn: Int
    let rbis: Int
    let outs: Int
    let sacFly: Int
    let sacBunt: Int
    let stolenBases: Int
    let earnedRun: Bool
    let playRecord: String
    let endOfInning: Bool
}

struct IsolatedPopulatedMigrationLineup: Hashable, Sendable {
    let id: UUID?
    let gameID: UUID?
    let teamID: UUID?
    let inning: Int
    let everyoneHits: Bool
    let playerIDs: [UUID]
}

struct IsolatedPopulatedMigrationPitcher: Hashable, Sendable {
    let id: UUID?
    let playerID: UUID?
    let teamID: UUID?
    let gameID: UUID?
    let startInn: Int
    let sOuts: Int
    let sBats: Int
    let endInn: Int
    let eOuts: Int
    let eBats: Int
    let strikeOuts: Int
    let walks: Int
    let hits: Int
    let runs: Int
    let won: Bool
}

struct IsolatedPopulatedMigrationSource: Hashable, Sendable {
    let identity: String
    let sourceVersion: String
    var teams: [IsolatedPopulatedMigrationTeam]
    var players: [IsolatedPopulatedMigrationPlayer]
    var games: [IsolatedPopulatedMigrationGame]
    var atbats: [IsolatedPopulatedMigrationAtbat]
    var lineups: [IsolatedPopulatedMigrationLineup]
    var pitchers: [IsolatedPopulatedMigrationPitcher]
    var unsupportedRawEvidence: [String]
    let malformed: Bool

    var recordCounts: CanonicalMigrationRecordCounts {
        CanonicalMigrationRecordCounts(
            games: games.count,
            teams: teams.count,
            players: players.count,
            atbats: atbats.count,
            lineups: lineups.count,
            pitchers: pitchers.count
        )
    }
}

struct IsolatedPopulatedMigrationSemanticSnapshot: Hashable, Sendable {
    let gameIDs: [UUID]
    let gameSides: [UUID: [String: UUID]]
    let teamIDs: [UUID]
    let playerIDs: [UUID]
    let rosterMembership: [UUID: UUID]
    let lineupIDs: [UUID]
    let eventIDsBySequence: [UUID]
    let eventSequences: [Int]
    let scorecardColumns: [Int]
    let pitcherIDs: [UUID]
    let substitutionPairs: [IsolatedPersistenceReplacementPair]
    let playerPhotoByteCounts: [UUID: Int?]
    let teamLogoByteCounts: [UUID: Int?]
    let storedScores: [UUID: CanonicalProjectedScore]
}

struct IsolatedPopulatedMigrationResult: Hashable, Sendable {
    let migration: CanonicalMigrationResult
    let summary: CanonicalPopulatedMigrationSummary
    let semanticSnapshot: IsolatedPopulatedMigrationSemanticSnapshot?
    let recoveryStrategy: String
    let physicalSchemaAssessment: String
    let productionStoreOpened: Bool
    let productionRouteChanged: Bool
    let receiptOrSignedTransactionDataPresent: Bool
}

enum IsolatedPopulatedMigrationFailure: String, CaseIterable, Hashable, Sendable {
    case sourceReadFailure
    case sourceValidationFailure
    case targetCreationFailure
    case recordWriteFailure
    case relationshipWriteFailure
    case orderingWriteFailure
    case mediaWriteFailure
    case saveFailure
    case reloadFailure
    case verificationFailure
    case completionMarkerFailure
    case purchaseSeparationFailure

    var phase: CanonicalPopulatedMigrationPhase {
        switch self {
        case .sourceReadFailure: return .inspectSource
        case .sourceValidationFailure: return .validateSource
        case .targetCreationFailure: return .createIsolatedTarget
        case .recordWriteFailure: return .writeSupportedTargetRecords
        case .relationshipWriteFailure: return .writeSupportedTargetRecords
        case .orderingWriteFailure: return .compareSourceAndTargetMeaning
        case .mediaWriteFailure: return .preserveUnsupportedEvidence
        case .saveFailure: return .saveTarget
        case .reloadFailure: return .reloadTarget
        case .verificationFailure: return .interpretTargetCanonically
        case .completionMarkerFailure: return .markCompletion
        case .purchaseSeparationFailure: return .compareSourceAndTargetMeaning
        }
    }
}

@MainActor
enum IsolatedPopulatedMigrationSupport {
    nonisolated static let nonDefaultProbe = CanonicalMigrationPurchaseAllowanceProbe(
        freeGameCreatesRemaining: 1,
        mlbDownloadUseCount: 3,
        entitlementMarker: "season-pass-probe-active-2026",
        purchaseMarker: "purchase-probe-known"
    )

    static func source(_ kind: PopulatedMigrationSourceKind) -> IsolatedPopulatedMigrationSource {
        kind.source
    }

    static func migrate(
        source: IsolatedPopulatedMigrationSource,
        operationIdentity: String = PopulatedMigrationVerificationIDs.operation,
        targetIdentity: String = PopulatedMigrationVerificationIDs.sourceTarget,
        existingContainer: ModelContainer? = nil,
        interruption: CanonicalPopulatedMigrationPhase? = nil,
        injectedFailure: IsolatedPopulatedMigrationFailure? = nil,
        probe: CanonicalMigrationPurchaseAllowanceProbe = nonDefaultProbe,
        probeAfter: CanonicalMigrationPurchaseAllowanceProbe? = nil
    ) throws -> IsolatedPopulatedMigrationResult {
        let probeAfter = probeAfter ?? probe
        var completedPhases: [CanonicalPopulatedMigrationPhase] = []
        var targetCounts = CanonicalMigrationRecordCounts.empty
        var semanticSnapshot: IsolatedPopulatedMigrationSemanticSnapshot?
        var preservedEvidenceCount = source.unsupportedRawEvidence.count
        var skippedRecordCount = 0
        let unsupportedEvidenceCount = source.unsupportedRawEvidence.count
        let duplicateIdentityCount = duplicateIdentityCount(in: source)
        var relationshipFindingCount = 0
        let orderingFindingCount = duplicateOrderingCount(in: source)
        let mediaFindingCount = malformedMediaCount(in: source)
        var migratedCounts = CanonicalMigrationRecordCounts.empty
        let storedScoreReconciliation = storedScoreReconciliation(for: source)
        var reconciliation: Set<CanonicalMigrationEvidenceReconciliation> = [.preservedDirectly]
        var container: ModelContainer?
        var alreadyMigrated = false
        var operationConflict = false

        func stop(
            disposition: CanonicalMigrationDisposition,
            transaction: CanonicalPersistenceTransactionResult,
            phase: CanonicalPopulatedMigrationPhase?,
            failureCode: String? = nil,
            interruptionCode: String? = nil,
            findings: [CanonicalMigrationFinding] = [],
            targetUsable: Bool = false,
            completionProven: Bool = false,
            recoveryStrategy: String = "Preserve source and retry only after review."
        ) -> IsolatedPopulatedMigrationResult {
            let progress = CanonicalPopulatedMigrationProgressEvidence(
                operationIdentity: operationIdentity,
                sourceIdentity: source.identity,
                targetIdentity: targetIdentity,
                currentPhase: phase,
                completedPhases: completedPhases,
                recordCounts: targetCounts,
                completionMarker: completionProven,
                failureMarker: failureCode,
                interruptionMarker: interruptionCode
            )
            let summary = CanonicalPopulatedMigrationSummary(
                sourceIdentity: source.identity,
                targetIdentity: targetIdentity,
                lastCompletedPhase: completedPhases.last,
                sourceRecordCounts: source.recordCounts,
                targetRecordCounts: targetCounts,
                migratedCounts: migratedCounts,
                preservedEvidenceCount: preservedEvidenceCount,
                skippedRecordCount: skippedRecordCount,
                unsupportedEvidenceCount: unsupportedEvidenceCount,
                duplicateIdentityCount: duplicateIdentityCount,
                relationshipFindingCount: relationshipFindingCount,
                orderingFindingCount: orderingFindingCount,
                mediaFindingCount: mediaFindingCount,
                storedScoreReconciliation: storedScoreReconciliation,
                reconciliation: Array(reconciliation).sorted { $0.rawValue < $1.rawValue },
                progress: progress
            )
            let input = CanonicalMigrationInput(
                fixtureIdentity: source.identity,
                operationIdentity: operationIdentity,
                sourceVersion: source.sourceVersion,
                targetVersion: "current-swiftdata-model-isolated-test-target",
                sourceClassification: source.malformed ? .unsupportedSource : .populatedExistingStore,
                targetClassification: targetCounts.containsBaseballRecords ? .currentSwiftDataPopulatedState : .notEstablished,
                mode: .rejectPopulatedStore,
                sourceRecordCounts: source.recordCounts,
                purchaseAllowanceProbe: probe
            )
            let migration = CanonicalMigrationResult(
                disposition: probe == probeAfter ? disposition : .purchaseSeparationFailure,
                sourceClassification: input.sourceClassification,
                targetClassification: input.targetClassification,
                sourceRecordCounts: input.sourceRecordCounts,
                targetRecordCounts: targetCounts,
                findings: probe == probeAfter ? findings : findings + [finding("migration.populated.purchaseSeparationFailure", "Purchase or allowance probe changed during populated migration.", true)],
                transactionResult: probe == probeAfter ? transaction : CanonicalPersistenceTransactionClassifier.contradictory(
                    [validationFinding("migration.populated.purchaseSeparationFailure", "Purchase or allowance probe changed during populated migration.")],
                    operationIdentity: operationIdentity
                ),
                purchaseAllowanceProbeBefore: probe,
                purchaseAllowanceProbeAfter: probeAfter,
                sourceRemainsUsable: true,
                targetIsUsable: targetUsable && probe == probeAfter,
                retryIsSafe: transaction.retryIsSafe || disposition == .alreadyMigrated || disposition == .successWithWarnings,
                reloadRequired: transaction.explicitReloadRequired,
                reviewOrRepairRequired: transaction.repairOrReviewRequired || findings.contains { $0.requiresReview } || probe != probeAfter,
                producedRecords: targetCounts.containsBaseballRecords,
                noOp: disposition == .alreadyMigrated || disposition == .noChange,
                completionProven: completionProven && probe == probeAfter
            )
            return IsolatedPopulatedMigrationResult(
                migration: migration,
                summary: summary,
                semanticSnapshot: semanticSnapshot,
                recoveryStrategy: recoveryStrategy,
                physicalSchemaAssessment: "Test-only compatibility conversion and persisted-evidence reconstruction are currently supportable; no physical VersionedSchema migration is proven or routed.",
                productionStoreOpened: false,
                productionRouteChanged: false,
                receiptOrSignedTransactionDataPresent: false
            )
        }

        for phase in CanonicalPopulatedMigrationPhase.allCases {
            if interruption == phase {
                return stop(
                    disposition: .interrupted,
                    transaction: CanonicalPersistenceTransactionClassifier.interruptedOperation(operationIdentity: operationIdentity),
                    phase: phase,
                    interruptionCode: "migration.populated.interrupted.\(phase.rawValue)",
                    findings: [finding("migration.populated.interrupted.\(phase.rawValue)", "Populated migration interrupted before \(phase.rawValue).", true)],
                    targetUsable: false,
                    recoveryStrategy: "Discard the isolated incomplete target or restart from the immutable source snapshot."
                )
            }
            if injectedFailure?.phase == phase {
                let failure = injectedFailure!
                return stop(
                    disposition: disposition(for: failure),
                    transaction: transaction(for: failure, operationIdentity: operationIdentity),
                    phase: phase,
                    failureCode: "migration.populated.failure.\(failure.rawValue)",
                    findings: [finding("migration.populated.failure.\(failure.rawValue)", "Injected populated migration failure at \(phase.rawValue).", true)],
                    targetUsable: false,
                    recoveryStrategy: recoveryStrategy(for: failure)
                )
            }

            switch phase {
            case .inspectSource:
                guard source.malformed == false else {
                    return stop(
                        disposition: .unsupportedSource,
                        transaction: CanonicalPersistenceTransactionClassifier.unsupported(
                            [validationFinding("migration.populated.malformedSource", "Malformed populated source cannot be safely converted.")],
                            operationIdentity: operationIdentity
                        ),
                        phase: phase,
                        findings: [finding("migration.populated.malformedSource", "Malformed populated source remains preserved for review.", true)],
                        recoveryStrategy: "Return read-only source access and require review."
                    )
                }
            case .classifySource:
                break
            case .validateSource:
                if source.games.contains(where: { $0.id == nil }) || source.teams.contains(where: { $0.id == nil }) || source.players.contains(where: { $0.id == nil }) {
                    reconciliation.insert(.requiresUserReview)
                    skippedRecordCount += source.games.filter { $0.id == nil }.count
                    + source.teams.filter { $0.id == nil }.count
                    + source.players.filter { $0.id == nil }.count
                }
            case .snapshotSourceEvidence:
                preservedEvidenceCount += source.recordCounts.baseballRecordCount
            case .buildMigrationPlan:
                if duplicateIdentityCount > 0 { reconciliation.insert(.requiresRepairAssessment) }
                if orderingFindingCount > 0 { reconciliation.insert(.ambiguous) }
                if source.unsupportedRawEvidence.isEmpty == false { reconciliation.insert(.unsupported) }
            case .createIsolatedTarget:
                container = try existingContainer ?? IsolatedPersistenceEnvironment().container
                let existingCounts = try IsolatedMigrationSupport.recordCounts(from: container!)
                if existingCounts.containsBaseballRecords {
                    let existingSnapshot = try Self.semanticSnapshot(from: container!)
                    let incomingGameIDs = Set(source.games.compactMap(\.id))
                    let existingGameIDs = Set(existingSnapshot.gameIDs)
                    if source.recordCounts.containsBaseballRecords && incomingGameIDs.isSubset(of: existingGameIDs) {
                        alreadyMigrated = true
                        operationConflict = operationIdentity == PopulatedMigrationVerificationIDs.conflictingOperation
                    }
                }
            case .writeSupportedTargetRecords:
                if alreadyMigrated { break }
                guard let container else {
                    return stop(
                        disposition: .recoveryAvailable,
                        transaction: CanonicalPersistenceTransactionClassifier.recoveryAvailable(operationIdentity: operationIdentity),
                        phase: phase,
                        findings: [finding("migration.populated.targetMissing", "Isolated target was not available.", true)]
                    )
                }
                let writeResult = try writeSupportedRecords(from: source, into: container)
                migratedCounts = writeResult.migratedCounts
                skippedRecordCount += writeResult.skippedCount
                relationshipFindingCount += writeResult.relationshipFindingCount
            case .preserveUnsupportedEvidence:
                if mediaFindingCount > 0 { reconciliation.insert(.preservedWithWarning) }
                if unsupportedEvidenceCount > 0 { reconciliation.insert(.preservedAsCompatibilityEvidence) }
            case .saveTarget:
                if let container {
                    try ModelContext(container).save()
                }
            case .reloadTarget:
                if let container {
                    targetCounts = try IsolatedMigrationSupport.recordCounts(from: container)
                    semanticSnapshot = try Self.semanticSnapshot(from: container)
                }
            case .interpretTargetCanonically:
                if targetCounts.containsBaseballRecords == false && source.recordCounts.containsBaseballRecords {
                    return stop(
                        disposition: .partialOrUncertain,
                        transaction: CanonicalPersistenceTransactionClassifier.partialOrUncertainOutcome(
                            [validationFinding("migration.populated.noTargetRecords", "No migrated target records were found after reload.")],
                            operationIdentity: operationIdentity
                        ),
                        phase: phase,
                        findings: [finding("migration.populated.noTargetRecords", "Target reload did not prove migrated records.", true)]
                    )
                }
            case .compareSourceAndTargetMeaning:
                if operationConflict {
                    return stop(
                        disposition: .requiresReview,
                        transaction: CanonicalPersistenceTransactionClassifier.unresolved(
                            [validationFinding("migration.populated.conflictingOperation", "A different operation identity targeted an already migrated source.")],
                            operationIdentity: operationIdentity
                        ),
                        phase: phase,
                        findings: [finding("migration.populated.conflictingOperation", "Conflicting repeated migration intent requires review.", true)],
                        targetUsable: true,
                        completionProven: false,
                        recoveryStrategy: "Preserve the accepted target and reject the conflicting operation until reviewed."
                    )
                }
            case .markCompletion:
                break
            }
            completedPhases.append(phase)
        }

        if alreadyMigrated {
            return stop(
                disposition: .alreadyMigrated,
                transaction: CanonicalPersistenceTransactionClassifier.duplicateAlreadyApplied(operationIdentity: operationIdentity),
                phase: .markCompletion,
                targetUsable: true,
                completionProven: true,
                recoveryStrategy: "Existing isolated target already contains the same stable source identities; no duplicate records were written."
            )
        }

        let warningCount = duplicateIdentityCount + relationshipFindingCount + orderingFindingCount + mediaFindingCount + unsupportedEvidenceCount + skippedRecordCount
        let disposition: CanonicalMigrationDisposition = warningCount == 0 ? .success : .successWithWarnings
        let transaction: CanonicalPersistenceTransactionResult = warningCount == 0
            ? CanonicalPersistenceTransactionClassifier.success(operationIdentity: operationIdentity, affectedRecordIdentities: migratedRecordIdentities(from: semanticSnapshot))
            : CanonicalPersistenceTransactionClassifier.successWithWarnings(
                [validationFinding("migration.populated.warningEvidencePreserved", "Populated migration completed with preserved warning evidence.")],
                operationIdentity: operationIdentity
            )
        return stop(
            disposition: disposition,
            transaction: transaction,
            phase: .markCompletion,
            findings: findingsForCompletedMigration(
                duplicateIdentityCount: duplicateIdentityCount,
                relationshipFindingCount: relationshipFindingCount,
                orderingFindingCount: orderingFindingCount,
                mediaFindingCount: mediaFindingCount,
                unsupportedEvidenceCount: unsupportedEvidenceCount,
                storedScoreReconciliation: storedScoreReconciliation
            ),
            targetUsable: true,
            completionProven: true,
            recoveryStrategy: "Completed isolated target can be retained as accepted test evidence; source remains usable."
        )
    }

    private static func writeSupportedRecords(
        from source: IsolatedPopulatedMigrationSource,
        into container: ModelContainer
    ) throws -> (migratedCounts: CanonicalMigrationRecordCounts, skippedCount: Int, relationshipFindingCount: Int) {
        let context = ModelContext(container)
        var teamByID = Dictionary(uniqueKeysWithValues: (try context.fetch(FetchDescriptor<Team>())).map { ($0.ident, $0) })
        var playerByID = Dictionary(uniqueKeysWithValues: (try context.fetch(FetchDescriptor<Player>())).map { ($0.identifier, $0) })
        var gameByID = Dictionary(uniqueKeysWithValues: (try context.fetch(FetchDescriptor<Game>())).map { ($0.ident, $0) })
        var eventIDs = Set((try context.fetch(FetchDescriptor<Atbat>())).map(\.ident))
        var lineupIDs = Set((try context.fetch(FetchDescriptor<Lineup>())).map(\.ident))
        var pitcherIDs = Set((try context.fetch(FetchDescriptor<Pitcher>())).map(\.ident))
        var skipped = 0
        var relationshipFindings = 0
        var migrated = CanonicalMigrationRecordCounts.empty

        for teamSource in source.teams {
            guard let id = teamSource.id else { skipped += 1; continue }
            guard teamByID[id] == nil else { skipped += 1; continue }
            let team = Team(ident: id, name: teamSource.name, coach: teamSource.coach, details: teamSource.details, logo: teamSource.logo)
            context.insert(team)
            teamByID[id] = team
            migrated = addTeam(to: migrated)
        }

        for playerSource in source.players {
            guard let id = playerSource.id else { skipped += 1; continue }
            guard playerByID[id] == nil else { skipped += 1; continue }
            let team = playerSource.teamID.flatMap { teamByID[$0] }
            if playerSource.teamID != nil && team == nil { relationshipFindings += 1 }
            let player = Player(
                identifier: id,
                name: playerSource.name,
                number: playerSource.number,
                position: playerSource.position,
                batDir: playerSource.batDirection,
                batOrder: playerSource.batOrder,
                team: team,
                photo: playerSource.photo
            )
            context.insert(player)
            playerByID[id] = player
            if let team { team.players.append(player) }
            migrated = addPlayer(to: migrated)
        }

        for gameSource in source.games {
            guard let id = gameSource.id else { skipped += 1; continue }
            guard gameByID[id] == nil else { skipped += 1; continue }
            let home = gameSource.homeTeamID.flatMap { teamByID[$0] }
            let visiting = gameSource.visitingTeamID.flatMap { teamByID[$0] }
            if gameSource.homeTeamID != nil && home == nil { relationshipFindings += 1 }
            if gameSource.visitingTeamID != nil && visiting == nil { relationshipFindings += 1 }
            let participants = gameSource.participantIDs.compactMap { playerByID[$0] }
            if participants.count != gameSource.participantIDs.count { relationshipFindings += 1 }
            let game = Game(
                ident: id,
                date: gameSource.date,
                location: gameSource.location,
                highLights: gameSource.highlights,
                hscore: gameSource.storedHomeScore ?? 0,
                vscore: gameSource.storedVisitingScore ?? 0,
                everyOneHits: gameSource.everyoneHits,
                numInnings: gameSource.innings,
                vteam: visiting,
                hteam: home,
                players: participants
            )
            game.replaced = gameSource.replacedPlayerIDs.compactMap { playerByID[$0] }
            game.incomings = gameSource.incomingPlayerIDs.compactMap { playerByID[$0] }
            if game.replaced.count != gameSource.replacedPlayerIDs.count || game.incomings.count != gameSource.incomingPlayerIDs.count {
                relationshipFindings += 1
            }
            context.insert(game)
            gameByID[id] = game
            home?.games.append(game)
            visiting?.games.append(game)
            migrated = addGame(to: migrated)
        }

        for eventSource in source.atbats {
            guard let id = eventSource.id else { skipped += 1; continue }
            guard eventIDs.contains(id) == false else { skipped += 1; continue }
            guard let gameID = eventSource.gameID, let game = gameByID[gameID],
                  let teamID = eventSource.teamID, let team = teamByID[teamID],
                  let playerID = eventSource.playerID, let player = playerByID[playerID] else {
                skipped += 1
                relationshipFindings += 1
                continue
            }
            let event = Atbat(
                ident: id,
                game: game,
                team: team,
                player: player,
                result: eventSource.result,
                maxbase: eventSource.maxbase,
                batOrder: eventSource.batOrder,
                outAt: eventSource.outAt,
                inning: CGFloat(eventSource.inning),
                seq: eventSource.sequence,
                col: eventSource.scorecardColumn,
                rbis: eventSource.rbis,
                outs: eventSource.outs,
                sacFly: eventSource.sacFly,
                sacBunt: eventSource.sacBunt,
                stolenBases: eventSource.stolenBases,
                earnedRun: eventSource.earnedRun,
                playRec: eventSource.playRecord,
                endOfInning: eventSource.endOfInning
            )
            context.insert(event)
            game.atbats.append(event)
            player.atbat.append(event)
            eventIDs.insert(id)
            migrated = addAtbat(to: migrated)
        }

        for lineupSource in source.lineups {
            guard let id = lineupSource.id else { skipped += 1; continue }
            guard lineupIDs.contains(id) == false else { skipped += 1; continue }
            guard let gameID = lineupSource.gameID, let game = gameByID[gameID],
                  let teamID = lineupSource.teamID, let team = teamByID[teamID] else {
                skipped += 1
                relationshipFindings += 1
                continue
            }
            let players = lineupSource.playerIDs.compactMap { playerByID[$0] }
            if players.count != lineupSource.playerIDs.count { relationshipFindings += 1 }
            let lineup = Lineup(
                ident: id,
                everyoneHits: lineupSource.everyoneHits,
                game: game,
                team: team,
                inning: lineupSource.inning,
                players: players
            )
            context.insert(lineup)
            game.lineups.append(lineup)
            lineupIDs.insert(id)
            migrated = addLineup(to: migrated)
        }

        for pitcherSource in source.pitchers {
            guard let id = pitcherSource.id else { skipped += 1; continue }
            guard pitcherIDs.contains(id) == false else { skipped += 1; continue }
            guard let playerID = pitcherSource.playerID, let player = playerByID[playerID],
                  let teamID = pitcherSource.teamID, let team = teamByID[teamID],
                  let gameID = pitcherSource.gameID, let game = gameByID[gameID] else {
                skipped += 1
                relationshipFindings += 1
                continue
            }
            let pitcher = Pitcher(
                ident: id,
                player: player,
                team: team,
                game: game,
                startInn: pitcherSource.startInn,
                sOuts: pitcherSource.sOuts,
                sBats: pitcherSource.sBats,
                endInn: pitcherSource.endInn,
                eOuts: pitcherSource.eOuts,
                eBats: pitcherSource.eBats,
                strikeOuts: pitcherSource.strikeOuts,
                walks: pitcherSource.walks,
                hits: pitcherSource.hits,
                runs: pitcherSource.runs,
                won: pitcherSource.won
            )
            context.insert(pitcher)
            game.pitchers.append(pitcher)
            pitcherIDs.insert(id)
            migrated = addPitcher(to: migrated)
        }

        try context.save()
        return (migrated, skipped, relationshipFindings)
    }

    static func semanticSnapshot(from container: ModelContainer) throws -> IsolatedPopulatedMigrationSemanticSnapshot {
        let context = ModelContext(container)
        let games = try context.fetch(FetchDescriptor<Game>()).sorted { $0.ident.uuidString < $1.ident.uuidString }
        let teams = try context.fetch(FetchDescriptor<Team>()).sorted { $0.ident.uuidString < $1.ident.uuidString }
        let players = try context.fetch(FetchDescriptor<Player>()).sorted { $0.identifier.uuidString < $1.identifier.uuidString }
        let atbats = try context.fetch(FetchDescriptor<Atbat>()).sorted {
            if $0.seq != $1.seq { return $0.seq < $1.seq }
            return $0.ident.uuidString < $1.ident.uuidString
        }
        let lineups = try context.fetch(FetchDescriptor<Lineup>()).sorted { $0.ident.uuidString < $1.ident.uuidString }
        let pitchers = try context.fetch(FetchDescriptor<Pitcher>()).sorted {
            if $0.startInn != $1.startInn { return $0.startInn < $1.startInn }
            if $0.sOuts != $1.sOuts { return $0.sOuts < $1.sOuts }
            return $0.ident.uuidString < $1.ident.uuidString
        }
        var gameSides: [UUID: [String: UUID]] = [:]
        var storedScores: [UUID: CanonicalProjectedScore] = [:]
        var substitutions: [IsolatedPersistenceReplacementPair] = []
        for game in games {
            gameSides[game.ident] = [
                "home": game.hteam?.ident,
                "visiting": game.vteam?.ident
            ].compactMapValues { $0 }
            storedScores[game.ident] = CanonicalProjectedScore(home: game.hscore, visiting: game.vscore)
            substitutions += zip(game.replaced, game.incomings).map { IsolatedPersistenceReplacementPair(outgoing: $0.identifier, incoming: $1.identifier) }
        }
        return IsolatedPopulatedMigrationSemanticSnapshot(
            gameIDs: games.map(\.ident),
            gameSides: gameSides,
            teamIDs: teams.map(\.ident),
            playerIDs: players.map(\.identifier),
            rosterMembership: Dictionary(uniqueKeysWithValues: players.compactMap { player in player.team.map { (player.identifier, $0.ident) } }),
            lineupIDs: lineups.map(\.ident),
            eventIDsBySequence: atbats.map(\.ident),
            eventSequences: atbats.map(\.seq),
            scorecardColumns: atbats.map(\.col),
            pitcherIDs: pitchers.map(\.ident),
            substitutionPairs: substitutions,
            playerPhotoByteCounts: Dictionary(uniqueKeysWithValues: players.map { ($0.identifier, $0.photo?.count) }),
            teamLogoByteCounts: Dictionary(uniqueKeysWithValues: teams.map { ($0.ident, $0.logo?.count) }),
            storedScores: storedScores
        )
    }

    private static func duplicateIdentityCount(in source: IsolatedPopulatedMigrationSource) -> Int {
        duplicateCount(source.teams.compactMap(\.id))
        + duplicateCount(source.players.compactMap(\.id))
        + duplicateCount(source.games.compactMap(\.id))
        + duplicateCount(source.atbats.compactMap(\.id))
        + duplicateCount(source.lineups.compactMap(\.id))
        + duplicateCount(source.pitchers.compactMap(\.id))
    }

    private static func duplicateCount(_ values: [UUID]) -> Int {
        values.count - Set(values).count
    }

    private static func duplicateOrderingCount(in source: IsolatedPopulatedMigrationSource) -> Int {
        let sequencesByGame = Dictionary(grouping: source.atbats.compactMap { atbat -> (UUID, Int)? in
            guard let gameID = atbat.gameID else { return nil }
            return (gameID, atbat.sequence)
        }, by: \.0)
        return sequencesByGame.values.reduce(0) { total, pairs in
            total + duplicateCount(pairs.map(\.1))
        }
    }

    private static func duplicateCount(_ values: [Int]) -> Int {
        values.count - Set(values).count
    }

    private static func malformedMediaCount(in source: IsolatedPopulatedMigrationSource) -> Int {
        source.players.compactMap(\.photo).filter { $0.isEmpty || !$0.starts(with: [0x89, 0x50, 0x4E, 0x47]) }.count
        + source.teams.compactMap(\.logo).filter { $0.isEmpty || !$0.starts(with: [0x89, 0x50, 0x4E, 0x47]) }.count
    }

    private static func storedScoreReconciliation(for source: IsolatedPopulatedMigrationSource) -> CanonicalStoredScoreReconciliation {
        let reconciliations = source.games.map { game -> CanonicalStoredScoreReconciliation in
            guard let storedHome = game.storedHomeScore, let storedVisiting = game.storedVisitingScore else { return .storedScoreAbsent }
            guard storedHome >= 0 && storedVisiting >= 0 else { return .storedScoreUnsupported }
            guard let replayHome = game.replayHomeScore, let replayVisiting = game.replayVisitingScore else { return .replayCannotEstablishScore }
            return storedHome == replayHome && storedVisiting == replayVisiting ? .matchesReplayDerivedScore : .differsFromReplayDerivedScore
        }
        if reconciliations.contains(.storedScoreUnsupported) { return .storedScoreUnsupported }
        if reconciliations.contains(.differsFromReplayDerivedScore) { return .differsFromReplayDerivedScore }
        if reconciliations.contains(.replayCannotEstablishScore) { return .replayCannotEstablishScore }
        if reconciliations.contains(.storedScoreAbsent) { return .storedScoreAbsent }
        return .matchesReplayDerivedScore
    }

    private static func disposition(for failure: IsolatedPopulatedMigrationFailure) -> CanonicalMigrationDisposition {
        switch failure {
        case .sourceReadFailure, .sourceValidationFailure: return .validationRejected
        case .targetCreationFailure, .saveFailure, .reloadFailure, .completionMarkerFailure: return .recoveryAvailable
        case .recordWriteFailure: return .partialOrUncertain
        case .relationshipWriteFailure: return .relationshipFailure
        case .orderingWriteFailure: return .orderingFailure
        case .mediaWriteFailure: return .mediaFailure
        case .verificationFailure: return .requiresReview
        case .purchaseSeparationFailure: return .purchaseSeparationFailure
        }
    }

    private static func transaction(for failure: IsolatedPopulatedMigrationFailure, operationIdentity: String) -> CanonicalPersistenceTransactionResult {
        let finding = validationFinding("migration.populated.failure.\(failure.rawValue)", "Injected populated migration failure.")
        switch failure {
        case .sourceReadFailure, .sourceValidationFailure:
            return CanonicalPersistenceTransactionClassifier.validationRejected([finding], operationIdentity: operationIdentity)
        case .targetCreationFailure, .completionMarkerFailure:
            return CanonicalPersistenceTransactionClassifier.recoveryAvailable(operationIdentity: operationIdentity)
        case .recordWriteFailure, .reloadFailure, .verificationFailure:
            return CanonicalPersistenceTransactionClassifier.partialOrUncertainOutcome([finding], operationIdentity: operationIdentity)
        case .relationshipWriteFailure:
            return CanonicalPersistenceTransactionClassifier.relationshipFailure([finding], operationIdentity: operationIdentity)
        case .orderingWriteFailure:
            return CanonicalPersistenceTransactionClassifier.orderingFailure([finding], operationIdentity: operationIdentity)
        case .mediaWriteFailure:
            return CanonicalPersistenceTransactionClassifier.mediaFailure([finding], operationIdentity: operationIdentity)
        case .saveFailure:
            return CanonicalPersistenceTransactionClassifier.saveFailed([finding], operationIdentity: operationIdentity)
        case .purchaseSeparationFailure:
            return CanonicalPersistenceTransactionClassifier.contradictory([finding], operationIdentity: operationIdentity)
        }
    }

    private static func recoveryStrategy(for failure: IsolatedPopulatedMigrationFailure) -> String {
        switch failure {
        case .sourceReadFailure, .sourceValidationFailure:
            return "Return read-only source access; retry requires source review."
        case .targetCreationFailure:
            return "No target is accepted; retry can recreate an isolated target."
        case .recordWriteFailure, .relationshipWriteFailure, .orderingWriteFailure, .mediaWriteFailure:
            return "Discard the isolated partial target or restart from the source snapshot."
        case .saveFailure, .reloadFailure, .verificationFailure, .completionMarkerFailure:
            return "Reload before trusting the target; completion remains uncertain until verified."
        case .purchaseSeparationFailure:
            return "Do not repair entitlement state inside baseball migration; preserve source and require review."
        }
    }

    private static func findingsForCompletedMigration(
        duplicateIdentityCount: Int,
        relationshipFindingCount: Int,
        orderingFindingCount: Int,
        mediaFindingCount: Int,
        unsupportedEvidenceCount: Int,
        storedScoreReconciliation: CanonicalStoredScoreReconciliation
    ) -> [CanonicalMigrationFinding] {
        var findings: [CanonicalMigrationFinding] = []
        if duplicateIdentityCount > 0 { findings.append(finding("migration.populated.duplicateIdentity", "Duplicate identity evidence was preserved without merging.", true)) }
        if relationshipFindingCount > 0 { findings.append(finding("migration.populated.relationshipWarning", "Broken or missing relationship evidence was preserved without fabrication.", true)) }
        if orderingFindingCount > 0 { findings.append(finding("migration.populated.orderingWarning", "Duplicate or conflicting ordering evidence was preserved without resequencing.", true)) }
        if mediaFindingCount > 0 { findings.append(finding("migration.populated.mediaWarning", "Malformed or unsupported media bytes were classified without changing baseball facts.", true)) }
        if unsupportedEvidenceCount > 0 { findings.append(finding("migration.populated.unsupportedEvidence", "Unsupported raw evidence remains visible as compatibility evidence.", true)) }
        if storedScoreReconciliation != .matchesReplayDerivedScore { findings.append(finding("migration.populated.storedScoreReview", "Stored score remains comparison evidence requiring review.", true)) }
        return findings
    }

    private static func migratedRecordIdentities(from snapshot: IsolatedPopulatedMigrationSemanticSnapshot?) -> [String] {
        guard let snapshot else { return [] }
        return (snapshot.gameIDs + snapshot.teamIDs + snapshot.playerIDs + snapshot.eventIDsBySequence + snapshot.lineupIDs + snapshot.pitcherIDs)
            .map(\.uuidString)
    }

    private static func finding(_ code: String, _ summary: String, _ requiresReview: Bool = false) -> CanonicalMigrationFinding {
        CanonicalMigrationFinding(code: code, summary: summary, requiresReview: requiresReview)
    }

    private static func validationFinding(_ code: String, _ summary: String) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(
            code,
            concept: .game,
            severity: .rejection,
            disposition: .rejected,
            summary: summary
        )
    }

    private static func addGame(to counts: CanonicalMigrationRecordCounts) -> CanonicalMigrationRecordCounts {
        CanonicalMigrationRecordCounts(games: counts.games + 1, teams: counts.teams, players: counts.players, atbats: counts.atbats, lineups: counts.lineups, pitchers: counts.pitchers)
    }

    private static func addTeam(to counts: CanonicalMigrationRecordCounts) -> CanonicalMigrationRecordCounts {
        CanonicalMigrationRecordCounts(games: counts.games, teams: counts.teams + 1, players: counts.players, atbats: counts.atbats, lineups: counts.lineups, pitchers: counts.pitchers)
    }

    private static func addPlayer(to counts: CanonicalMigrationRecordCounts) -> CanonicalMigrationRecordCounts {
        CanonicalMigrationRecordCounts(games: counts.games, teams: counts.teams, players: counts.players + 1, atbats: counts.atbats, lineups: counts.lineups, pitchers: counts.pitchers)
    }

    private static func addAtbat(to counts: CanonicalMigrationRecordCounts) -> CanonicalMigrationRecordCounts {
        CanonicalMigrationRecordCounts(games: counts.games, teams: counts.teams, players: counts.players, atbats: counts.atbats + 1, lineups: counts.lineups, pitchers: counts.pitchers)
    }

    private static func addLineup(to counts: CanonicalMigrationRecordCounts) -> CanonicalMigrationRecordCounts {
        CanonicalMigrationRecordCounts(games: counts.games, teams: counts.teams, players: counts.players, atbats: counts.atbats, lineups: counts.lineups + 1, pitchers: counts.pitchers)
    }

    private static func addPitcher(to counts: CanonicalMigrationRecordCounts) -> CanonicalMigrationRecordCounts {
        CanonicalMigrationRecordCounts(games: counts.games, teams: counts.teams, players: counts.players, atbats: counts.atbats, lineups: counts.lineups, pitchers: counts.pitchers + 1)
    }
}

enum PopulatedMigrationSourceKind: Hashable, Sendable {
    case minimal
    case inProgress
    case completed
    case multipleGames
    case warnings
    case malformed
    case empty

    var source: IsolatedPopulatedMigrationSource {
        switch self {
        case .minimal:
            return Self.base(identity: "minimal-populated-source", includeSecondEvent: false, includeSecondGame: false, includeMedia: false, storedScoreMismatch: false)
        case .inProgress:
            return Self.base(identity: "in-progress-populated-source", includeSecondEvent: true, includeSecondGame: false, includeMedia: false, storedScoreMismatch: true)
        case .completed:
            return Self.base(identity: "completed-populated-source", includeSecondEvent: true, includeSecondGame: false, includeMedia: true, storedScoreMismatch: false)
        case .multipleGames:
            return Self.base(identity: "multiple-games-populated-source", includeSecondEvent: true, includeSecondGame: true, includeMedia: true, storedScoreMismatch: false)
        case .warnings:
            var source = Self.base(identity: "warning-populated-source", includeSecondEvent: true, includeSecondGame: false, includeMedia: true, storedScoreMismatch: true)
            source.teams.append(IsolatedPopulatedMigrationTeam(id: PopulatedMigrationVerificationIDs.visitingTeam, name: "Duplicate Visitors", coach: "Duplicate", details: "Duplicate identity", logo: nil))
            source.players.append(IsolatedPopulatedMigrationPlayer(id: nil, name: "Missing Identity", number: "99", position: "OF", batDirection: "R", batOrder: 9, teamID: PopulatedMigrationVerificationIDs.neutralTeam, photo: nil))
            source.atbats.append(IsolatedPopulatedMigrationAtbat(
                id: PopulatedMigrationVerificationIDs.eventThree,
                gameID: PopulatedMigrationVerificationIDs.gameOne,
                teamID: PopulatedMigrationVerificationIDs.neutralTeam,
                playerID: PopulatedMigrationVerificationIDs.visitingPlayerOne,
                result: "Unsupported Future Result",
                maxbase: "UnknownBase",
                batOrder: 1,
                outAt: "",
                inning: 2.0,
                sequence: 2,
                scorecardColumn: 7,
                rbis: 0,
                outs: 0,
                sacFly: 0,
                sacBunt: 0,
                stolenBases: 0,
                earnedRun: true,
                playRecord: "unsupported raw value",
                endOfInning: false
            ))
            source.lineups.append(IsolatedPopulatedMigrationLineup(id: PopulatedMigrationVerificationIDs.lineupTwo, gameID: PopulatedMigrationVerificationIDs.gameOne, teamID: nil, inning: 2, everyoneHits: false, playerIDs: [PopulatedMigrationVerificationIDs.visitingPlayerOne]))
            source.pitchers.append(IsolatedPopulatedMigrationPitcher(id: PopulatedMigrationVerificationIDs.pitcherTwo, playerID: PopulatedMigrationVerificationIDs.homePlayerTwo, teamID: nil, gameID: PopulatedMigrationVerificationIDs.gameOne, startInn: 3, sOuts: 0, sBats: 0, endInn: 0, eOuts: 0, eBats: 0, strikeOuts: 0, walks: 0, hits: 0, runs: 0, won: false))
            source.unsupportedRawEvidence += ["unsupported-result", "broken-team-relationship", "broken-lineup-relationship", "broken-pitcher-relationship", "ambiguous-substitution-arrays"]
            return source
        case .malformed:
            return IsolatedPopulatedMigrationSource(
                identity: "malformed-populated-source",
                sourceVersion: "legacy-current-swiftdata-unversioned",
                teams: [],
                players: [],
                games: [],
                atbats: [],
                lineups: [],
                pitchers: [],
                unsupportedRawEvidence: ["malformed-source"],
                malformed: true
            )
        case .empty:
            return IsolatedPopulatedMigrationSource(
                identity: "empty-source-for-populated-repeat",
                sourceVersion: "legacy-current-swiftdata-unversioned",
                teams: [],
                players: [],
                games: [],
                atbats: [],
                lineups: [],
                pitchers: [],
                unsupportedRawEvidence: [],
                malformed: false
            )
        }
    }

    private static func base(
        identity: String,
        includeSecondEvent: Bool,
        includeSecondGame: Bool,
        includeMedia: Bool,
        storedScoreMismatch: Bool
    ) -> IsolatedPopulatedMigrationSource {
        let teams = [
            IsolatedPopulatedMigrationTeam(id: PopulatedMigrationVerificationIDs.visitingTeam, name: "Migration Visitors", coach: "Visitor Coach", details: "Synthetic source", logo: includeMedia ? IsolatedMediaPersistenceSupport.smallValidPNG : nil),
            IsolatedPopulatedMigrationTeam(id: PopulatedMigrationVerificationIDs.homeTeam, name: "Migration Home", coach: "Home Coach", details: "Synthetic source", logo: includeMedia ? IsolatedMediaPersistenceSupport.alternateValidPNG : nil),
            IsolatedPopulatedMigrationTeam(id: PopulatedMigrationVerificationIDs.neutralTeam, name: "Detached Review Team", coach: "", details: "Optional review evidence", logo: includeMedia ? IsolatedMediaPersistenceSupport.malformedBytes : nil)
        ]
        let players = [
            IsolatedPopulatedMigrationPlayer(id: PopulatedMigrationVerificationIDs.visitingPlayerOne, name: "Visitor One", number: "1", position: "SS", batDirection: "R", batOrder: 1, teamID: PopulatedMigrationVerificationIDs.visitingTeam, photo: includeMedia ? IsolatedMediaPersistenceSupport.smallValidPNG : nil),
            IsolatedPopulatedMigrationPlayer(id: PopulatedMigrationVerificationIDs.visitingPlayerTwo, name: "Visitor Two", number: "2", position: "CF", batDirection: "L", batOrder: 2, teamID: PopulatedMigrationVerificationIDs.visitingTeam, photo: includeMedia ? nil : nil),
            IsolatedPopulatedMigrationPlayer(id: PopulatedMigrationVerificationIDs.homePlayerOne, name: "Home One", number: "11", position: "P", batDirection: "R", batOrder: 1, teamID: PopulatedMigrationVerificationIDs.homeTeam, photo: includeMedia ? IsolatedMediaPersistenceSupport.alternateValidPNG : nil),
            IsolatedPopulatedMigrationPlayer(id: PopulatedMigrationVerificationIDs.homePlayerTwo, name: "Home Two", number: "12", position: "RP", batDirection: "R", batOrder: 2, teamID: PopulatedMigrationVerificationIDs.homeTeam, photo: includeMedia ? IsolatedMediaPersistenceSupport.malformedBytes : nil)
        ]
        var games = [
            IsolatedPopulatedMigrationGame(
                id: PopulatedMigrationVerificationIDs.gameOne,
                date: "2026-07-15T12:00:00Z",
                location: "Migration Verification Field",
                highlights: includeSecondEvent ? "In-progress or completed representative source" : "Minimal populated source",
                storedHomeScore: storedScoreMismatch ? 5 : 1,
                storedVisitingScore: includeSecondEvent ? 1 : 0,
                replayHomeScore: 1,
                replayVisitingScore: includeSecondEvent ? 1 : 0,
                everyoneHits: false,
                innings: 7,
                visitingTeamID: PopulatedMigrationVerificationIDs.visitingTeam,
                homeTeamID: PopulatedMigrationVerificationIDs.homeTeam,
                participantIDs: [PopulatedMigrationVerificationIDs.visitingPlayerOne, PopulatedMigrationVerificationIDs.visitingPlayerTwo, PopulatedMigrationVerificationIDs.homePlayerOne, PopulatedMigrationVerificationIDs.homePlayerTwo],
                replacedPlayerIDs: includeSecondEvent ? [PopulatedMigrationVerificationIDs.visitingPlayerOne] : [],
                incomingPlayerIDs: includeSecondEvent ? [PopulatedMigrationVerificationIDs.visitingPlayerTwo] : []
            )
        ]
        if includeSecondGame {
            games.append(IsolatedPopulatedMigrationGame(
                id: PopulatedMigrationVerificationIDs.gameTwo,
                date: "2026-07-16T12:00:00Z",
                location: "Migration Verification Field Two",
                highlights: "Second game with reusable players",
                storedHomeScore: 0,
                storedVisitingScore: 0,
                replayHomeScore: nil,
                replayVisitingScore: nil,
                everyoneHits: true,
                innings: 6,
                visitingTeamID: PopulatedMigrationVerificationIDs.homeTeam,
                homeTeamID: PopulatedMigrationVerificationIDs.visitingTeam,
                participantIDs: [PopulatedMigrationVerificationIDs.visitingPlayerOne, PopulatedMigrationVerificationIDs.homePlayerOne],
                replacedPlayerIDs: [],
                incomingPlayerIDs: []
            ))
        }
        var atbats = [
            IsolatedPopulatedMigrationAtbat(id: PopulatedMigrationVerificationIDs.eventOne, gameID: PopulatedMigrationVerificationIDs.gameOne, teamID: PopulatedMigrationVerificationIDs.visitingTeam, playerID: PopulatedMigrationVerificationIDs.visitingPlayerOne, result: "Single", maxbase: "First", batOrder: 1, outAt: "", inning: 1.0, sequence: 1, scorecardColumn: 3, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0, earnedRun: true, playRecord: "runner on first", endOfInning: false)
        ]
        if includeSecondEvent {
            atbats.append(IsolatedPopulatedMigrationAtbat(id: PopulatedMigrationVerificationIDs.eventTwo, gameID: PopulatedMigrationVerificationIDs.gameOne, teamID: PopulatedMigrationVerificationIDs.visitingTeam, playerID: PopulatedMigrationVerificationIDs.visitingPlayerTwo, result: "Home Run", maxbase: "Home", batOrder: 2, outAt: "", inning: 1.0, sequence: 2, scorecardColumn: 7, rbis: 1, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0, earnedRun: true, playRecord: "stored score comparison", endOfInning: false))
        }
        let lineups = [
            IsolatedPopulatedMigrationLineup(id: PopulatedMigrationVerificationIDs.lineupOne, gameID: PopulatedMigrationVerificationIDs.gameOne, teamID: PopulatedMigrationVerificationIDs.visitingTeam, inning: 1, everyoneHits: false, playerIDs: [PopulatedMigrationVerificationIDs.visitingPlayerOne, PopulatedMigrationVerificationIDs.visitingPlayerTwo])
        ]
        let pitchers = [
            IsolatedPopulatedMigrationPitcher(id: PopulatedMigrationVerificationIDs.pitcherOne, playerID: PopulatedMigrationVerificationIDs.homePlayerOne, teamID: PopulatedMigrationVerificationIDs.homeTeam, gameID: PopulatedMigrationVerificationIDs.gameOne, startInn: 1, sOuts: 0, sBats: 0, endInn: includeSecondEvent ? 1 : 0, eOuts: 0, eBats: includeSecondEvent ? 2 : 0, strikeOuts: 1, walks: 0, hits: includeSecondEvent ? 2 : 1, runs: 1, won: false)
        ]
        return IsolatedPopulatedMigrationSource(
            identity: identity,
            sourceVersion: "legacy-current-swiftdata-unversioned",
            teams: teams,
            players: players,
            games: games,
            atbats: atbats,
            lineups: lineups,
            pitchers: pitchers,
            unsupportedRawEvidence: includeMedia ? ["malformed-media-preserved"] : [],
            malformed: false
        )
    }
}

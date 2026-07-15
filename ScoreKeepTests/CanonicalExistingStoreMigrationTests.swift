import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical existing-store migration verification")
struct CanonicalExistingStoreMigrationTests {
    @Test("minimal populated source converts into isolated target with stable semantic identity")
    func minimalPopulatedSourceConvertsIntoIsolatedTargetWithStableSemanticIdentity() throws {
        let source = IsolatedPopulatedMigrationSupport.source(.minimal)

        let result = try IsolatedPopulatedMigrationSupport.migrate(source: source)
        let snapshot = try #require(result.semanticSnapshot)

        #expect(result.migration.disposition == .success)
        #expect(result.migration.completionProven)
        #expect(result.migration.sourceRemainsUsable)
        #expect(result.migration.targetIsUsable)
        #expect(result.migration.purchaseAndAllowanceUnchanged)
        #expect(result.summary.lastCompletedPhase == .markCompletion)
        #expect(result.summary.completedAllVerificationPhases)
        #expect(snapshot.gameIDs == [PopulatedMigrationVerificationIDs.gameOne])
        #expect(snapshot.gameSides[PopulatedMigrationVerificationIDs.gameOne]?["home"] == PopulatedMigrationVerificationIDs.homeTeam)
        #expect(snapshot.gameSides[PopulatedMigrationVerificationIDs.gameOne]?["visiting"] == PopulatedMigrationVerificationIDs.visitingTeam)
        #expect(snapshot.eventSequences == [1])
        #expect(snapshot.scorecardColumns == [3])
        #expect(snapshot.storedScores[PopulatedMigrationVerificationIDs.gameOne] == CanonicalProjectedScore(home: 1, visiting: 0))
        #expect(result.productionStoreOpened == false)
        #expect(result.productionRouteChanged == false)
    }

    @Test("representative populated sources preserve games relationships ordering pitchers substitutions media and scores")
    func representativePopulatedSourcesPreserveGamesRelationshipsOrderingPitchersSubstitutionsMediaAndScores() throws {
        let completed = try IsolatedPopulatedMigrationSupport.migrate(source: IsolatedPopulatedMigrationSupport.source(.completed))
        let multiple = try IsolatedPopulatedMigrationSupport.migrate(source: IsolatedPopulatedMigrationSupport.source(.multipleGames))
        let completedSnapshot = try #require(completed.semanticSnapshot)
        let multipleSnapshot = try #require(multiple.semanticSnapshot)

        #expect(completed.migration.disposition == .successWithWarnings)
        #expect(completed.summary.mediaFindingCount == 2)
        #expect(completed.summary.storedScoreReconciliation == .matchesReplayDerivedScore)
        #expect(completedSnapshot.playerPhotoByteCounts[PopulatedMigrationVerificationIDs.visitingPlayerOne] == IsolatedMediaPersistenceSupport.smallValidPNG.count)
        #expect(completedSnapshot.teamLogoByteCounts[PopulatedMigrationVerificationIDs.homeTeam] == IsolatedMediaPersistenceSupport.alternateValidPNG.count)
        #expect(completedSnapshot.pitcherIDs == [PopulatedMigrationVerificationIDs.pitcherOne])
        #expect(completedSnapshot.substitutionPairs == [IsolatedPersistenceReplacementPair(outgoing: PopulatedMigrationVerificationIDs.visitingPlayerOne, incoming: PopulatedMigrationVerificationIDs.visitingPlayerTwo)])
        #expect(multiple.migration.targetRecordCounts.games == 2)
        #expect(multipleSnapshot.gameIDs == [PopulatedMigrationVerificationIDs.gameOne, PopulatedMigrationVerificationIDs.gameTwo])
        #expect(multipleSnapshot.playerIDs.count == 4)
        #expect(multiple.summary.storedScoreReconciliation == .replayCannotEstablishScore)
    }

    @Test("broken unsupported and contradictory source evidence remains visible without fabrication")
    func brokenUnsupportedAndContradictorySourceEvidenceRemainsVisibleWithoutFabrication() throws {
        let result = try IsolatedPopulatedMigrationSupport.migrate(source: IsolatedPopulatedMigrationSupport.source(.warnings))
        let snapshot = try #require(result.semanticSnapshot)

        #expect(result.migration.disposition == .successWithWarnings)
        #expect(result.summary.duplicateIdentityCount > 0)
        #expect(result.summary.relationshipFindingCount > 0)
        #expect(result.summary.orderingFindingCount > 0)
        #expect(result.summary.unsupportedEvidenceCount > 0)
        #expect(result.summary.storedScoreReconciliation == .differsFromReplayDerivedScore)
        #expect(result.migration.reviewOrRepairRequired)
        #expect(snapshot.teamIDs.filter { $0 == PopulatedMigrationVerificationIDs.visitingTeam }.count == 1)
        #expect(snapshot.playerIDs.contains(PopulatedMigrationVerificationIDs.visitingPlayerOne))
        #expect(snapshot.eventSequences == [1, 2, 2])
        #expect(result.summary.reconciliation.contains(.requiresRepairAssessment))
        #expect(result.summary.reconciliation.contains(.unsupported))
    }

    @Test("malformed populated source is rejected without target records or purchase changes")
    func malformedPopulatedSourceIsRejectedWithoutTargetRecordsOrPurchaseChanges() throws {
        let result = try IsolatedPopulatedMigrationSupport.migrate(source: IsolatedPopulatedMigrationSupport.source(.malformed))

        #expect(result.migration.disposition == .unsupportedSource)
        #expect(result.migration.completionProven == false)
        #expect(result.migration.targetRecordCounts == .empty)
        #expect(result.migration.sourceRemainsUsable)
        #expect(result.migration.purchaseAndAllowanceUnchanged)
        #expect(result.semanticSnapshot == nil)
    }
}

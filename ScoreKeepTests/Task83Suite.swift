import Testing
@testable import ScoreKeep

@Suite("Task83Suite")
struct Task83Suite {
    @Test func task83SemanticScorecardProjectionPreservesReplayOrderAndDiagnostics() throws {
        let batter1 = ReplayTestSupport.batter(1)
        let eventID1 = ReplayTestSupport.eventID(1)
        let eventID2 = ReplayTestSupport.eventID(2)
        
        let appliedSummary = CanonicalReplayEventSummary(
            eventIdentity: ImportedIdentifierEvidence.valid(eventID1),
            sourceSequence: 1,
            sourceIndex: 0,
            orderingDisposition: CanonicalReplayEventOrderingDisposition.explicitValidOrder,
            outcomeDisposition: CanonicalReplayDisposition.complete,
            applied: true,
            changedFacts: [],
            diagnosticCodes: [],
            resultingInning: CanonicalHalfInning(number: InningNumberEvidence.known(1), half: HalfInningEvidence.known(InningHalf.top), expectedInnings: ExpectedInningCountEvidence.known(7)),
            resultingOuts: 1,
            resultingOccupiedBases: [],
            resultingScore: CanonicalProjectedScore(home: 0, visiting: 1),
            batterIdentity: batter1.playerIdentity,
            pitcherIdentity: nil,
            unsupportedRawClassification: []
        )
        
        let unappliedSummary = CanonicalReplayEventSummary(
            eventIdentity: ImportedIdentifierEvidence.valid(eventID2),
            sourceSequence: 2,
            sourceIndex: 1,
            orderingDisposition: CanonicalReplayEventOrderingDisposition.explicitValidOrder,
            outcomeDisposition: CanonicalReplayDisposition.rejected,
            applied: false,
            changedFacts: [],
            diagnosticCodes: ["test.diagnostic.1"],
            resultingInning: nil,
            resultingOuts: nil,
            resultingOccupiedBases: [],
            resultingScore: CanonicalProjectedScore(home: 0, visiting: 1),
            batterIdentity: nil,
            pitcherIdentity: nil,
            unsupportedRawClassification: ["Unsupported Hit"]
        )
        
        let duplicateSummary = CanonicalReplayEventSummary(
            eventIdentity: ImportedIdentifierEvidence.valid(eventID1), // Duplicate
            sourceSequence: 3,
            sourceIndex: 2,
            orderingDisposition: CanonicalReplayEventOrderingDisposition.explicitValidOrder,
            outcomeDisposition: CanonicalReplayDisposition.complete,
            applied: true,
            changedFacts: [],
            diagnosticCodes: [],
            resultingInning: nil,
            resultingOuts: nil,
            resultingOccupiedBases: [],
            resultingScore: CanonicalProjectedScore(home: 0, visiting: 1),
            batterIdentity: nil,
            pitcherIdentity: nil,
            unsupportedRawClassification: []
        )
        
        let state = CanonicalReplayProjectedState(
            gameIdentity: ImportedIdentifierEvidence.valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            battingSide: TeamSideRole.visiting,
            inning: nil,
            outs: CanonicalOutsState(outs: OutsEvidence.known(0)),
            baseOccupancy: CanonicalBaseOccupancy(runnerStates: []),
            score: CanonicalProjectedScore(home: 0, visiting: 0),
            appliedEventCount: 0,
            nextEventSequence: nil,
            projectedBatters: [],
            projectedPitchers: []
        )
        
        let replayResult = CanonicalReplayResult(
            finalState: state,
            eventSummaries: [appliedSummary, unappliedSummary, duplicateSummary],
            appliedEventCount: 1,
            unappliedEventCount: 2,
            firstProblematicEventIdentity: ImportedIdentifierEvidence.valid(eventID2),
            firstProblematicEventIndex: 1,
            disposition: CanonicalReplayDisposition.partial,
            validationFindings: [],
            storedScoreComparison: CanonicalStoredScoreComparison.notSupplied,
            readOnlyComparisonMayContinue: true,
            futureRoutingOrPersistenceMustStop: true
        )
        
        let result = CanonicalScorecardProjector.project(replayResult: replayResult)
        
        // 1. Applied summaries appear in exact replay order.
        #expect(result.events.count == 3)
        #expect(result.events[0].eventIdentity == ImportedIdentifierEvidence.valid(eventID1))
        #expect(result.events[1].eventIdentity == ImportedIdentifierEvidence.valid(eventID2))
        #expect(result.events[2].eventIdentity == ImportedIdentifierEvidence.valid(eventID1))
        
        // 2. Event identities are preserved.
        #expect(result.events[0].sourceSequence == 1)
        
        // 3. Replay-provided resulting state is copied without recalculation.
        #expect(result.events[0].resultingScore == CanonicalProjectedScore(home: 0, visiting: 1))
        
        // 4. An unapplied or rejected summary remains explicitly non-applied.
        #expect(result.events[1].applied == false)
        #expect(result.events[1].outcomeDisposition == CanonicalReplayDisposition.rejected)
        
        // 5. A warning or unsupported classification remains visible.
        #expect(result.events[1].diagnosticCodes.contains("test.diagnostic.1"))
        #expect(result.events[1].unsupportedRawClassification.contains("Unsupported Hit"))
        
        // 6. Partial or unsupported replay does not become a resolved projection.
        // 7. Duplicate event identities produce an unsupported result and diagnostic.
        #expect(result.disposition == CanonicalProjectionDisposition.unsupported)
        #expect(result.diagnostics.contains { $0.code == "scorecardProjection.duplicateEventIdentity" })
        #expect(result.events[2].applied == false)
        #expect(result.events[2].outcomeDisposition == CanonicalReplayDisposition.rejected)
        #expect(result.events[2].diagnosticCodes.contains("scorecardProjection.duplicateEventIdentity"))
        
        // 8. Repeated projection produces equal output.
        let repeatedResult = CanonicalScorecardProjector.project(replayResult: replayResult)
        #expect(result == repeatedResult)
    }
}

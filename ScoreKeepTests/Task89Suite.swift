import Testing
import Foundation
@testable import ScoreKeep

@Suite("Task89Suite")
struct Task89Suite {
    
    @Test("task89HittingAndPitchingSemanticRowsRemainDeterministic")
    func task89HittingAndPitchingSemanticRowsRemainDeterministic() throws {
        let batter1 = ReplayTestSupport.batter(1)
        let pitcherID = UUID()
        let pitcherIdentity = ImportedIdentifierEvidence.valid(pitcherID)
        
        let event1 = ReplayTestSupport.event(
            sequence: 1, 
            raw: "Single", 
            eventID: ReplayTestSupport.eventID(1),
            batter: batter1
        )
        
        let events = [event1]
        let replayInput = ReplayTestSupport.input(events: events)
        let replayResult = CanonicalGameReplay.replay(replayInput)
        
        // Hitting Projection
        let hittingInput = CanonicalHittingProjectionInput(
            replayResult: replayResult,
            recordedEvents: events
        )
        let hittingProj1 = CanonicalHittingProjector.project(hittingInput)
        let hittingProj2 = CanonicalHittingProjector.project(hittingInput)
        
        #expect(hittingProj1 == hittingProj2) // Deterministic
        
        let b1Stats = try #require(hittingProj1.playerStatistics[batter1.playerIdentity])
        #expect(b1Stats.playerIdentity == batter1.playerIdentity) // Structured player identity
        #expect(b1Stats.hits == 1) // Numeric values remain typed, not just color
        #expect(b1Stats.singles == 1)
        
        // Pitching Projection
        let app = CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: .valid(UUID()),
            reusablePitcherIdentity: pitcherIdentity,
            gameIdentity: .valid(UUID()),
            teamSide: .visiting,
            appearanceOrder: OrderEvidence(kind: .pitcherAppearance, value: 1, sourceIndex: 0),
            roleEvidence: [.startingPitcher],
            startBoundary: .missing,
            endBoundary: .missing,
            historicalDisplayEvidence: PlayerDisplayEvidence(),
            source: .syntheticVerification
        )
        let projectedPitcher = CanonicalProjectedPitcher(
            appearance: app,
            appearanceOrder: 1,
            isStartingPitcher: true,
            isReliefPitcher: false
        )
        let pitcherProj = CanonicalPitcherProjectionResult(
            disposition: .resolved,
            activePitcher: projectedPitcher,
            startingPitcher: projectedPitcher,
            reliefAppearances: [],
            appearanceOrder: [projectedPitcher],
            responsibilityWarnings: [],
            diagnostics: [],
            validationFindings: [],
            sourceEvidenceUsed: [],
            sourceEvidenceIgnored: []
        )
        let responsibility = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(ReplayTestSupport.eventID(1)),
            gameIdentity: .valid(UUID()),
            teamSide: .visiting,
            responsibility: .explicitPitcher(app),
            source: .syntheticVerification
        )
        let pitchingInput = CanonicalPitchingStatisticsProjectionInput(
            replayResult: replayResult,
            recordedEvents: events,
            pitcherProjection: pitcherProj,
            eventResponsibilities: [responsibility]
        )
        let pitchingProj1 = CanonicalPitchingStatisticsProjector.project(pitchingInput)
        let pitchingProj2 = CanonicalPitchingStatisticsProjector.project(pitchingInput)
        
        #expect(pitchingProj1 == pitchingProj2) // Deterministic
        
        // Outs will be 0 because event1 doesn't record outs, but pitcherIdentity exists
        let p1Stats = try #require(pitchingProj1.pitcherStatistics[pitcherIdentity])
        #expect(p1Stats.pitcherIdentity == pitcherIdentity) // Structured pitcher identity
        #expect(p1Stats.appearances == 1) // Typed
    }
    
    @Test("task89ScorecardReadingOrderAndStatusRemainSemantic")
    func task89ScorecardReadingOrderAndStatusRemainSemantic() throws {
        let batter1 = ReplayTestSupport.batter(1)
        
        // ── One-occurrence replay ──
        // Replay stops after the first unsupported event, so only 2 summaries are produced.
        let oneOccEvent1 = ReplayTestSupport.event(sequence: 1, raw: "Single", eventID: ReplayTestSupport.eventID(1), batter: batter1)
        let oneOccEvent2 = ReplayTestSupport.event(sequence: 2, raw: "UnsupportedPlay", eventID: ReplayTestSupport.eventID(2), batter: batter1)
        
        let oneOccEvents = [oneOccEvent1, oneOccEvent2]
        let oneOccReplayInput = ReplayTestSupport.input(events: oneOccEvents)
        let oneOccReplayResult = CanonicalGameReplay.replay(oneOccReplayInput)
        
        let oneOccProj1 = CanonicalScorecardProjector.project(replayResult: oneOccReplayResult)
        let oneOccProj2 = CanonicalScorecardProjector.project(replayResult: oneOccReplayResult)
        
        // Repeated independent projection runs produce exact equal results
        #expect(oneOccProj1 == oneOccProj2)
        #expect(oneOccProj1.events == oneOccProj2.events)
        #expect(oneOccProj1.diagnostics == oneOccProj2.diagnostics)
        
        // Exact projected event count
        #expect(oneOccProj1.events.count == 2)
        guard oneOccProj1.events.count == 2 else {
            Issue.record("Expected 2 projected events in one-occurrence replay, got \(oneOccProj1.events.count)")
            return
        }
        
        // Replay order preserved
        #expect(oneOccProj1.events.map(\.sourceSequence) == [1, 2])
        
        // Event identity remains available
        #expect(oneOccProj1.events[0].eventIdentity == .valid(ReplayTestSupport.eventID(1)))
        #expect(oneOccProj1.events[1].eventIdentity == .valid(ReplayTestSupport.eventID(2)))
        
        // Applied status structurally distinguishable
        #expect(oneOccProj1.events[0].applied == true)
        #expect(oneOccProj1.events[1].applied == false)
        
        // One-occurrence unsupported evidence is exactly one entry
        #expect(oneOccProj1.events[1].unsupportedRawClassification == ["UnsupportedPlay"])
        #expect(oneOccProj2.events[1].unsupportedRawClassification == ["UnsupportedPlay"])
        
        // ── Two-occurrence replay ──
        // A separate replay where the first unsupported event carries two source occurrences.
        let twoOccEvent1 = ReplayTestSupport.event(sequence: 1, raw: "Single", eventID: ReplayTestSupport.eventID(1), batter: batter1)
        let baseTwoOcc = ReplayTestSupport.event(sequence: 2, raw: "UnsupportedPlay", eventID: ReplayTestSupport.eventID(2), batter: batter1)
        let twoOccEvent2 = CanonicalScoringEventEvidence(
            eventIdentity: baseTwoOcc.eventIdentity,
            gameIdentity: baseTwoOcc.gameIdentity,
            orderingEvidence: baseTwoOcc.orderingEvidence,
            inningContext: baseTwoOcc.inningContext,
            teamSide: baseTwoOcc.teamSide,
            participants: baseTwoOcc.participants,
            resultEvidence: baseTwoOcc.resultEvidence,
            outsEvidence: baseTwoOcc.outsEvidence,
            batterAdvancement: baseTwoOcc.batterAdvancement,
            runnerAdvancement: baseTwoOcc.runnerAdvancement,
            rbiEvidence: baseTwoOcc.rbiEvidence,
            earnedRunEvidence: baseTwoOcc.earnedRunEvidence,
            sacrificeEvidence: baseTwoOcc.sacrificeEvidence,
            stolenBaseEvidence: baseTwoOcc.stolenBaseEvidence,
            endOfHalfEvidence: baseTwoOcc.endOfHalfEvidence,
            historicalDisplayEvidence: baseTwoOcc.historicalDisplayEvidence,
            unsupportedRawLegacyEvidence: ["UnsupportedPlay", "UnsupportedPlay"],
            source: baseTwoOcc.source
        )
        
        let twoOccEvents = [twoOccEvent1, twoOccEvent2]
        let twoOccReplayInput = ReplayTestSupport.input(events: twoOccEvents)
        let twoOccReplayResult = CanonicalGameReplay.replay(twoOccReplayInput)
        
        let twoOccProj1 = CanonicalScorecardProjector.project(replayResult: twoOccReplayResult)
        let twoOccProj2 = CanonicalScorecardProjector.project(replayResult: twoOccReplayResult)
        
        // Repeated independent projection runs produce exact equal results
        #expect(twoOccProj1 == twoOccProj2)
        #expect(twoOccProj1.events == twoOccProj2.events)
        #expect(twoOccProj1.diagnostics == twoOccProj2.diagnostics)
        
        // Exact projected event count
        #expect(twoOccProj1.events.count == 2)
        guard twoOccProj1.events.count == 2 else {
            Issue.record("Expected 2 projected events in two-occurrence replay, got \(twoOccProj1.events.count)")
            return
        }
        
        // Two-occurrence unsupported evidence preserves multiplicity exactly
        #expect(twoOccProj1.events[1].unsupportedRawClassification == ["UnsupportedPlay", "UnsupportedPlay"])
        #expect(twoOccProj2.events[1].unsupportedRawClassification == ["UnsupportedPlay", "UnsupportedPlay"])
    }
    
    @Test("task89CanonicalDocumentProvidesStructuredOutputAlternatives")
    func task89CanonicalDocumentProvidesStructuredOutputAlternatives() throws {
        let teamID = UUID()
        let gameID = UUID()
        let scope = PreparedReportScope.singleGame(teamID: teamID, gameID: gameID)
        
        let diag = CanonicalProjectionDiagnostic(
            "test.diag",
            disposition: .unsupported,
            concept: .scoringEvent,
            severity: .unsupported,
            validationDisposition: .unsupported,
            summary: "Test Summary"
        )
        
        let scorecardResult = CanonicalScorecardProjectionResult(
            disposition: .resolvedWithWarnings,
            events: [
                CanonicalScorecardProjectedEvent(
                    eventIdentity: .valid(UUID()),
                    sourceSequence: 1,
                    sourceIndex: 0,
                    applied: true,
                    resultingInning: nil,
                    resultingOuts: nil,
                    resultingOccupiedBases: [],
                    resultingScore: CanonicalProjectedScore(home: 0, visiting: 0),
                    batterIdentity: .valid(UUID()),
                    pitcherIdentity: .valid(UUID()),
                    outcomeDisposition: .complete,
                    orderingDisposition: .explicitValidOrder,
                    diagnosticCodes: [],
                    unsupportedRawClassification: []
                )
            ],
            diagnostics: [diag],
            replayMayContinue: true
        )
        
        let docResult = CanonicalPDFDocumentPreparer.prepare(
            family: .singleGameScorecard,
            scope: scope,
            source: .scorecard(scorecardResult)
        )
        
        let doc = try #require(try? docResult.get())
        
        // Scope and report family available
        #expect(doc.family == .singleGameScorecard)
        #expect(doc.scope == scope)
        
        // Projection disposition available
        #expect(doc.disposition == .resolvedWithWarnings)
        
        // Document sections retain intentional order and kinds remain structurally distinguishable
        #expect(doc.sections.count == 2)
        guard case .scorecardEvents(let events) = doc.sections[0] else {
            Issue.record("First section is not scorecardEvents")
            return
        }
        #expect(events.count == 1)
        
        // Deferred or unsupported content uses CanonicalPDFDocumentUnsupportedReason
        guard case .unsupported(let reason) = doc.sections[1] else {
            Issue.record("Second section is not unsupported")
            return
        }
        #expect(reason == .deferredScorecardLayout)
        
        // Diagnostics remain structured
        #expect(doc.diagnostics.count == 1)
        #expect(doc.diagnostics[0].projectionDiagnostic.code == "test.diag")
    }
}

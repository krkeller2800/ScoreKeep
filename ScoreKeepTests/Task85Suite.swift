import Testing
import Foundation
@testable import ScoreKeep

@Suite("Task 8.5 PDF Generation Boundary Suite")
struct Task85Suite {
    
    @Test("Prepares supported projection-backed documents")
    func task85PreparesSupportedProjectionBackedDocuments() throws {
        let teamID = UUID()
        let gameID = UUID()
        let playerID = UUID()
        let scope = PreparedReportScope.teamAggregate(teamID: teamID)
        
        let validStats = CanonicalProjectedHittingStatistics(
            playerIdentity: .valid(playerID),
            plateAppearances: 4,
            officialAtBats: 3,
            hits: 2,
            singles: 1,
            doubles: 1,
            triples: 0,
            homeRuns: 0,
            walks: 1,
            strikeouts: 0,
            runs: 1,
            runsBattedIn: 2,
            sacrifices: 0,
            hitByPitch: 0
        )
        
        let missingStats = CanonicalProjectedHittingStatistics(
            playerIdentity: .missing,
            plateAppearances: 1,
            officialAtBats: 1,
            hits: 0,
            singles: 0, doubles: 0, triples: 0, homeRuns: 0, walks: 0, strikeouts: 1, runs: 0, runsBattedIn: 0, sacrifices: 0, hitByPitch: 0
        )
        
        let invalidStatsA = CanonicalProjectedHittingStatistics(
            playerIdentity: .invalid("Z"),
            plateAppearances: 1,
            officialAtBats: 1,
            hits: 0,
            singles: 0, doubles: 0, triples: 0, homeRuns: 0, walks: 0, strikeouts: 0, runs: 0, runsBattedIn: 0, sacrifices: 0, hitByPitch: 0
        )
        
        let invalidStatsB = CanonicalProjectedHittingStatistics(
            playerIdentity: .invalid("A"),
            plateAppearances: 1,
            officialAtBats: 1,
            hits: 1,
            singles: 1, doubles: 0, triples: 0, homeRuns: 0, walks: 0, strikeouts: 0, runs: 0, runsBattedIn: 0, sacrifices: 0, hitByPitch: 0
        )
        
        let hittingResult = CanonicalHittingProjectionResult(
            disposition: .resolved,
            playerStatistics: [
                .valid(playerID): validStats,
                .missing: missingStats,
                .invalid("Z"): invalidStatsA,
                .invalid("A"): invalidStatsB
            ],
            diagnostics: [],
            validationFindings: []
        )
        
        let hittingDocResult1 = CanonicalPDFDocumentPreparer.prepare(
            family: .hittingStatistics,
            scope: scope,
            source: .hitting(hittingResult)
        )
        
        let hittingDocResult2 = CanonicalPDFDocumentPreparer.prepare(
            family: .hittingStatistics,
            scope: scope,
            source: .hitting(hittingResult)
        )
        
        #expect(hittingDocResult1 == hittingDocResult2) // Repeated preparation yields equal document
        
        let doc = try #require(try? hittingDocResult1.get())
        #expect(doc.family == .hittingStatistics)
        #expect(doc.disposition == .resolved)
        
        var foundStats = false
        var foundUnsupported = false
        for section in doc.sections {
            switch section {
            case .hittingStatistics(let stats):
                foundStats = true
                #expect(stats.count == 4)
                
                // Assert exact deterministic output ordering
                // Order rank: .valid, .missing, .invalid
                // Within invalid: "A" < "Z"
                #expect(stats[0].playerIdentity == .valid(playerID))
                #expect(stats[1].playerIdentity == .missing)
                #expect(stats[2].playerIdentity == .invalid("A"))
                #expect(stats[3].playerIdentity == .invalid("Z"))
                
                #expect(stats[0].hits == 2)
            case .unsupported(let reason):
                if reason == .deferredHittingMetrics {
                    foundUnsupported = true
                }
            default:
                break
            }
        }
        #expect(foundStats)
        #expect(foundUnsupported)
        
        // Pitching Document
        let pitchingResult = CanonicalPitchingStatisticsProjectionResult(
            disposition: .resolved,
            pitcherStatistics: [
                .valid(playerID): CanonicalProjectedPitchingStatistics(
                    pitcherIdentity: .valid(playerID),
                    appearances: 1,
                    outsRecorded: 3
                )
            ],
            diagnostics: [],
            validationFindings: []
        )
        
        let pitchingDocResult = CanonicalPDFDocumentPreparer.prepare(
            family: .pitchingStatistics,
            scope: scope,
            source: .pitching(pitchingResult)
        )
        let pDoc = try #require(try? pitchingDocResult.get())
        #expect(pDoc.family == .pitchingStatistics)
        
        var pFoundUnsupported = false
        for section in pDoc.sections {
            if case .unsupported(let reason) = section, reason == .deferredPitchingMetrics {
                pFoundUnsupported = true
            }
        }
        #expect(pFoundUnsupported)
        
        // Scorecard Document
        let scorecardScope = PreparedReportScope.singleGame(teamID: teamID, gameID: gameID)
        let scorecardResult = CanonicalScorecardProjectionResult(
            disposition: .resolved,
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
                    batterIdentity: .valid(playerID),
                    pitcherIdentity: .valid(UUID()),
                    outcomeDisposition: .complete,
                    orderingDisposition: .explicitValidOrder,
                    diagnosticCodes: [],
                    unsupportedRawClassification: []
                )
            ],
            diagnostics: [],
            replayMayContinue: true
        )
        
        let scDocResult = CanonicalPDFDocumentPreparer.prepare(
            family: .singleGameScorecard,
            scope: scorecardScope,
            source: .scorecard(scorecardResult)
        )
        let scDoc = try #require(try? scDocResult.get())
        #expect(scDoc.family == .singleGameScorecard)
        #expect(scDoc.disposition == .resolved)
        
        var scFoundUnsupported = false
        for section in scDoc.sections {
            if case .unsupported(let reason) = section, reason == .deferredScorecardLayout {
                scFoundUnsupported = true
            }
        }
        #expect(scFoundUnsupported)
    }
    
    @Test("Preserves unsupported and incomplete projection evidence")
    func task85PreservesUnsupportedAndIncompleteProjectionEvidence() throws {
        let teamID = UUID()
        let scope = PreparedReportScope.teamAggregate(teamID: teamID)
        
        let diag = CanonicalProjectionDiagnostic(
            "test.code",
            disposition: .unsupported,
            concept: .scoringEvent,
            severity: .unsupported,
            validationDisposition: .unsupported,
            summary: "Test summary"
        )
        
        let hittingResult = CanonicalHittingProjectionResult(
            disposition: .unsupported,
            playerStatistics: [:],
            diagnostics: [diag],
            validationFindings: []
        )
        
        let docResult = CanonicalPDFDocumentPreparer.prepare(
            family: .hittingStatistics,
            scope: scope,
            source: .hitting(hittingResult)
        )
        
        let doc = try #require(try? docResult.get())
        #expect(doc.disposition == .unsupported)
        #expect(doc.diagnostics.count == 1)
        #expect(doc.diagnostics[0].projectionDiagnostic.code == "test.code")
    }
    
    @Test("Rejects mismatched scope and remains deterministic")
    func task85RejectsMismatchedScopeAndRemainsDeterministic() throws {
        let teamID = UUID()
        let gameID = UUID()
        let singleGameScope = PreparedReportScope.singleGame(teamID: teamID, gameID: gameID)
        
        let hittingResult = CanonicalHittingProjectionResult(
            disposition: .resolved,
            playerStatistics: [:],
            diagnostics: [],
            validationFindings: []
        )
        
        let result1 = CanonicalPDFDocumentPreparer.prepare(
            family: .hittingStatistics,
            scope: singleGameScope,
            source: .hitting(hittingResult)
        )
        
        let result2 = CanonicalPDFDocumentPreparer.prepare(
            family: .hittingStatistics,
            scope: singleGameScope,
            source: .hitting(hittingResult)
        )
        
        if case .failure(let err) = result1 {
            #expect(err == .mismatchedScopeAndFamily)
        } else {
            Issue.record("Expected failure")
        }
        
        #expect(result1 == result2)
        
        let mismatchSourceResult = CanonicalPDFDocumentPreparer.prepare(
            family: .pitchingStatistics,
            scope: .teamAggregate(teamID: teamID),
            source: .hitting(hittingResult)
        )
        if case .failure(let err) = mismatchSourceResult {
            #expect(err == .mismatchedScopeAndFamily)
        } else {
            Issue.record("Expected failure for wrong source")
        }
    }
}

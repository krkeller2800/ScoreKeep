import Foundation

struct CanonicalScorecardProjectedEvent: Hashable, Sendable {
    let eventIdentity: ImportedIdentifierEvidence
    let sourceSequence: Int?
    let sourceIndex: Int?
    let applied: Bool
    let resultingInning: CanonicalHalfInning?
    let resultingOuts: Int?
    let resultingOccupiedBases: Set<Base>
    let resultingScore: CanonicalProjectedScore
    let batterIdentity: ImportedIdentifierEvidence?
    let pitcherIdentity: ImportedIdentifierEvidence?
    let outcomeDisposition: CanonicalReplayDisposition
    let orderingDisposition: CanonicalReplayEventOrderingDisposition
    let diagnosticCodes: [String]
    let unsupportedRawClassification: [String]
}

struct CanonicalScorecardProjectionResult: Hashable, Sendable {
    let disposition: CanonicalProjectionDisposition
    let events: [CanonicalScorecardProjectedEvent]
    let diagnostics: [CanonicalProjectionDiagnostic]
    let replayMayContinue: Bool
}

enum CanonicalScorecardProjector {
    static func project(replayResult: CanonicalReplayResult) -> CanonicalScorecardProjectionResult {
        var events: [CanonicalScorecardProjectedEvent] = []
        var seenIdentities: Set<ImportedIdentifierEvidence> = []
        var duplicateDetected = false
        var diagnostics: [CanonicalProjectionDiagnostic] = []
        
        for summary in replayResult.eventSummaries {
            let isDuplicate = seenIdentities.contains(summary.eventIdentity)
            if isDuplicate {
                duplicateDetected = true
                diagnostics.append(CanonicalProjectionDiagnostic(
                    "scorecardProjection.duplicateEventIdentity",
                    disposition: .unsupported,
                    concept: .scoringEvent,
                    severity: .unsupported,
                    validationDisposition: .unsupported,
                    summary: "Duplicate event identity encountered in projection."
                ))
            } else {
                seenIdentities.insert(summary.eventIdentity)
            }
            
            events.append(CanonicalScorecardProjectedEvent(
                eventIdentity: summary.eventIdentity,
                sourceSequence: summary.sourceSequence,
                sourceIndex: summary.sourceIndex,
                applied: isDuplicate ? false : summary.applied,
                resultingInning: summary.resultingInning,
                resultingOuts: summary.resultingOuts,
                resultingOccupiedBases: summary.resultingOccupiedBases,
                resultingScore: summary.resultingScore,
                batterIdentity: summary.batterIdentity,
                pitcherIdentity: summary.pitcherIdentity,
                outcomeDisposition: isDuplicate ? .rejected : summary.outcomeDisposition,
                orderingDisposition: summary.orderingDisposition,
                diagnosticCodes: summary.diagnosticCodes + (isDuplicate ? ["scorecardProjection.duplicateEventIdentity"] : []),
                unsupportedRawClassification: summary.unsupportedRawClassification
            ))
        }
        
        let disposition: CanonicalProjectionDisposition
        if duplicateDetected {
            disposition = .unsupported
        } else {
            switch replayResult.disposition {
            case .complete: disposition = .resolved
            case .completeWithWarnings: disposition = .resolvedWithWarnings
            case .partial: disposition = .incomplete
            case .incomplete: disposition = .incomplete
            case .unsupported: disposition = .unsupported
            case .rejected: disposition = .rejected
            case .contradictory: disposition = .contradictory
            case .unresolved: disposition = .unresolved
            }
        }
        
        return CanonicalScorecardProjectionResult(
            disposition: disposition,
            events: events,
            diagnostics: diagnostics,
            replayMayContinue: disposition.replayMayContinue
        )
    }
}

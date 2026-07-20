import Foundation

struct CanonicalProjectedPitchingStatistics: Hashable, Sendable {
    let pitcherIdentity: ImportedIdentifierEvidence
    let appearances: Int
    let outsRecorded: Int
    
    init(pitcherIdentity: ImportedIdentifierEvidence, appearances: Int, outsRecorded: Int) {
        self.pitcherIdentity = pitcherIdentity
        self.appearances = appearances
        self.outsRecorded = outsRecorded
    }
}

struct CanonicalPitchingStatisticsProjectionInput: Hashable, Sendable {
    let replayResult: CanonicalReplayResult
    let recordedEvents: [CanonicalScoringEventEvidence]
    let pitcherProjection: CanonicalPitcherProjectionResult
    let eventResponsibilities: [CanonicalPitcherResponsibilityEvidence]
    let validationFindings: [CanonicalValidationFinding]
    let sourceLocation: String?
    
    init(
        replayResult: CanonicalReplayResult,
        recordedEvents: [CanonicalScoringEventEvidence],
        pitcherProjection: CanonicalPitcherProjectionResult,
        eventResponsibilities: [CanonicalPitcherResponsibilityEvidence],
        validationFindings: [CanonicalValidationFinding] = [],
        sourceLocation: String? = nil
    ) {
        self.replayResult = replayResult
        self.recordedEvents = recordedEvents
        self.pitcherProjection = pitcherProjection
        self.eventResponsibilities = eventResponsibilities
        self.validationFindings = validationFindings
        self.sourceLocation = sourceLocation
    }
}

struct CanonicalPitchingStatisticsProjectionResult: Hashable, Sendable {
    let disposition: CanonicalProjectionDisposition
    let pitcherStatistics: [ImportedIdentifierEvidence: CanonicalProjectedPitchingStatistics]
    let diagnostics: [CanonicalProjectionDiagnostic]
    let validationFindings: [CanonicalValidationFinding]
}

enum CanonicalPitchingStatisticsProjector {
    static func project(_ input: CanonicalPitchingStatisticsProjectionInput) -> CanonicalPitchingStatisticsProjectionResult {
        var diagnostics: [CanonicalProjectionDiagnostic] = []
        var finalDisposition: CanonicalProjectionDisposition = .resolved
        
        var appearancesByPitcher: [ImportedIdentifierEvidence: Int] = [:]
        for projected in input.pitcherProjection.appearanceOrder {
            let id = projected.appearance.reusablePitcherIdentity
            if id.validIdentifier != nil {
                appearancesByPitcher[id, default: 0] += 1
            } else {
                diagnostics.append(CanonicalProjectionDiagnostic(
                    "pitchingProjection.invalidAppearanceIdentity",
                    disposition: .resolvedWithWarnings,
                    concept: .scoringEvent,
                    severity: .warning,
                    validationDisposition: .validWithWarnings,
                    summary: "An appearance contained an invalid pitcher identity.",
                    sourceLocation: input.sourceLocation
                ))
                if finalDisposition == .resolved { finalDisposition = .resolvedWithWarnings }
            }
        }
        
        var duplicateEventIdentities: Set<ImportedIdentifierEvidence> = []
        var responsibilitiesByEvent: [ImportedIdentifierEvidence: CanonicalPitcherResponsibilityEvidence] = [:]
        
        for resp in input.eventResponsibilities {
            if responsibilitiesByEvent[resp.eventIdentity] != nil {
                duplicateEventIdentities.insert(resp.eventIdentity)
            } else {
                responsibilitiesByEvent[resp.eventIdentity] = resp
            }
        }
        
        var seenEventIdentities: Set<ImportedIdentifierEvidence> = []
        for event in input.recordedEvents {
            if seenEventIdentities.contains(event.eventIdentity) {
                duplicateEventIdentities.insert(event.eventIdentity)
            } else {
                seenEventIdentities.insert(event.eventIdentity)
            }
        }
        
        if !duplicateEventIdentities.isEmpty {
            diagnostics.append(CanonicalProjectionDiagnostic(
                "pitchingProjection.duplicateEventIdentity",
                disposition: .unsupported,
                concept: .scoringEvent,
                severity: .unsupported,
                validationDisposition: .unsupported,
                summary: "Duplicate source event identities detected.",
                sourceLocation: input.sourceLocation
            ))
            return CanonicalPitchingStatisticsProjectionResult(
                disposition: .unsupported,
                pitcherStatistics: [:],
                diagnostics: diagnostics,
                validationFindings: input.validationFindings
            )
        }
        
        var outsByPitcher: [ImportedIdentifierEvidence: Int] = [:]
        let eventsByIdentity = Dictionary(uniqueKeysWithValues: input.recordedEvents.map { ($0.eventIdentity, $0) })
        
        for summary in input.replayResult.eventSummaries where summary.applied {
            guard let event = eventsByIdentity[summary.eventIdentity] else { continue }
            guard let outsDelta = event.outsEvidence?.outsRecordedByEvent, outsDelta > 0 else { continue }
            
            guard let responsibility = responsibilitiesByEvent[summary.eventIdentity] else {
                diagnostics.append(CanonicalProjectionDiagnostic(
                    "pitchingProjection.missingResponsibilityForOuts",
                    disposition: .resolvedWithWarnings,
                    concept: .scoringEvent,
                    severity: .warning,
                    validationDisposition: .validWithWarnings,
                    summary: "Missing pitcher responsibility for event recording outs.",
                    sourceLocation: input.sourceLocation
                ))
                if finalDisposition == .resolved { finalDisposition = .resolvedWithWarnings }
                continue
            }
            
            switch responsibility.responsibility {
            case let .explicitPitcher(appearance):
                if appearance.reusablePitcherIdentity.validIdentifier != nil {
                    outsByPitcher[appearance.reusablePitcherIdentity, default: 0] += outsDelta
                } else {
                    diagnostics.append(CanonicalProjectionDiagnostic(
                        "pitchingProjection.invalidResponsibilityIdentity",
                        disposition: .resolvedWithWarnings,
                        concept: .scoringEvent,
                        severity: .warning,
                        validationDisposition: .validWithWarnings,
                        summary: "Invalid pitcher identity in responsibility.",
                        sourceLocation: input.sourceLocation
                    ))
                    if finalDisposition == .resolved { finalDisposition = .resolvedWithWarnings }
                }
            default:
                diagnostics.append(CanonicalProjectionDiagnostic(
                    "pitchingProjection.ambiguousResponsibilityForOuts",
                    disposition: .resolvedWithWarnings,
                    concept: .scoringEvent,
                    severity: .warning,
                    validationDisposition: .validWithWarnings,
                    summary: "Ambiguous or multiple pitcher responsibility for event recording outs.",
                    sourceLocation: input.sourceLocation
                ))
                if finalDisposition == .resolved { finalDisposition = .resolvedWithWarnings }
            }
        }
        
        var finalStats: [ImportedIdentifierEvidence: CanonicalProjectedPitchingStatistics] = [:]
        let allIdentities = Set(appearancesByPitcher.keys).union(outsByPitcher.keys)
        
        for id in allIdentities {
            finalStats[id] = CanonicalProjectedPitchingStatistics(
                pitcherIdentity: id,
                appearances: appearancesByPitcher[id] ?? 0,
                outsRecorded: outsByPitcher[id] ?? 0
            )
        }
        
        switch input.replayResult.disposition {
        case .complete:
            break // Keep finalDisposition as is
        case .completeWithWarnings, .partial:
            if finalDisposition == .resolved {
                finalDisposition = .resolvedWithWarnings
            }
        case .incomplete:
            finalDisposition = .incomplete
        case .unsupported:
            finalDisposition = .unsupported
        case .rejected:
            finalDisposition = .rejected
        case .contradictory:
            finalDisposition = .contradictory
        case .unresolved:
            finalDisposition = .unresolved
        }
        
        return CanonicalPitchingStatisticsProjectionResult(
            disposition: finalDisposition,
            pitcherStatistics: finalStats,
            diagnostics: diagnostics,
            validationFindings: input.validationFindings
        )
    }
}

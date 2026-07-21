import Foundation

enum CanonicalPDFDocumentUnsupportedReason: Equatable {
    case deferredHittingMetrics
    case deferredPitchingMetrics
    case deferredScorecardLayout
}

enum CanonicalPDFDocumentSection: Equatable {
    case hittingStatistics([CanonicalProjectedHittingStatistics])
    case pitchingStatistics([CanonicalProjectedPitchingStatistics])
    case scorecardEvents([CanonicalScorecardProjectedEvent])
    case unsupported(reason: CanonicalPDFDocumentUnsupportedReason)
}

struct CanonicalPDFDocumentDiagnostic: Hashable {
    let projectionDiagnostic: CanonicalProjectionDiagnostic
}

enum CanonicalPDFDocumentError: Error, Equatable {
    case mismatchedScopeAndFamily
}

struct CanonicalPDFDocument: Equatable {
    let family: ReportFamily
    let scope: PreparedReportScope
    let disposition: CanonicalProjectionDisposition
    let sections: [CanonicalPDFDocumentSection]
    let diagnostics: [CanonicalPDFDocumentDiagnostic]
}

enum CanonicalPDFDocumentProjectionSource {
    case hitting(CanonicalHittingProjectionResult)
    case pitching(CanonicalPitchingStatisticsProjectionResult)
    case scorecard(CanonicalScorecardProjectionResult)
}

enum CanonicalPDFDocumentPreparer {
    private static func compareIdentities(lhs: ImportedIdentifierEvidence, rhs: ImportedIdentifierEvidence) -> Bool {
        func rank(_ id: ImportedIdentifierEvidence) -> Int {
            switch id {
            case .valid: return 0
            case .missing: return 1
            case .invalid: return 2
            }
        }
        
        let lRank = rank(lhs)
        let rRank = rank(rhs)
        if lRank != rRank {
            return lRank < rRank
        }
        
        switch (lhs, rhs) {
        case (.valid(let lID), .valid(let rID)):
            return lID.uuidString < rID.uuidString
        case (.invalid(let lStr), .invalid(let rStr)):
            return lStr < rStr
        case (.missing, .missing):
            return false // Equal, so neither is strictly less than the other
        default:
            return false
        }
    }

    static func prepare(
        family: ReportFamily,
        scope: PreparedReportScope,
        source: CanonicalPDFDocumentProjectionSource
    ) -> Result<CanonicalPDFDocument, CanonicalPDFDocumentError> {
        
        var sections: [CanonicalPDFDocumentSection] = []
        let diagnostics: [CanonicalPDFDocumentDiagnostic]
        let combinedDisposition: CanonicalProjectionDisposition
        
        switch (family, scope, source) {
        case (.hittingStatistics, .teamAggregate, .hitting(let result)):
            combinedDisposition = result.disposition
            let stats = Array<CanonicalProjectedHittingStatistics>(result.playerStatistics.values).sorted {
                compareIdentities(lhs: $0.playerIdentity, rhs: $1.playerIdentity)
            }
            sections.append(.hittingStatistics(stats))
            sections.append(.unsupported(reason: .deferredHittingMetrics))
            diagnostics = result.diagnostics.map { CanonicalPDFDocumentDiagnostic(projectionDiagnostic: $0) }
            
        case (.pitchingStatistics, .teamAggregate, .pitching(let result)):
            combinedDisposition = result.disposition
            let stats = Array<CanonicalProjectedPitchingStatistics>(result.pitcherStatistics.values).sorted {
                compareIdentities(lhs: $0.pitcherIdentity, rhs: $1.pitcherIdentity)
            }
            sections.append(.pitchingStatistics(stats))
            sections.append(.unsupported(reason: .deferredPitchingMetrics))
            diagnostics = result.diagnostics.map { CanonicalPDFDocumentDiagnostic(projectionDiagnostic: $0) }
            
        case (.singleGameScorecard, .singleGame, .scorecard(let result)):
            combinedDisposition = result.disposition
            sections.append(.scorecardEvents(result.events))
            sections.append(.unsupported(reason: .deferredScorecardLayout))
            diagnostics = result.diagnostics.map { CanonicalPDFDocumentDiagnostic(projectionDiagnostic: $0) }
            
        default:
            return .failure(.mismatchedScopeAndFamily)
        }
        
        let doc = CanonicalPDFDocument(
            family: family,
            scope: scope,
            disposition: combinedDisposition,
            sections: sections,
            diagnostics: diagnostics
        )
        return .success(doc)
    }
}

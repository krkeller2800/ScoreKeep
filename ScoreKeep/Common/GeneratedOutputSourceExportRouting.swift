import Foundation

enum ShareableOutputAuthority: Hashable {
    case compatibleSourceDataExport
    case generatedOutput
}

enum CompatibleSourceDataExportKind: Hashable {
    case players
    case game

    var fileExtension: String {
        switch self {
        case .players:
            "ScoreKeep_Players"
        case .game:
            "ScoreKeep_Games"
        }
    }
}

struct CompatibleSourceDataExportRoute: Hashable {
    let kind: CompatibleSourceDataExportKind
    let fileBaseName: String

    var authority: ShareableOutputAuthority {
        .compatibleSourceDataExport
    }

    var fileName: String {
        "\(fileBaseName).\(kind.fileExtension)"
    }

    var purchaseGatedAction: PurchaseGatedAction {
        .compatibleSourceDataExport
    }

    var requiresGeneratedOutputPurchaseGate: Bool {
        purchaseGatedAction.requiresCurrentSeasonEntitlement
    }
}

enum GeneratedOutputKind: Hashable {
    case scorecardPDF
    case hittingStatistics
    case pitchingStatistics
}

struct GeneratedOutputRoute: Equatable {
    let kind: GeneratedOutputKind
    let scope: PreparedReportScope

    init?(document: CanonicalPDFDocument) {
        switch document.family {
        case .singleGameScorecard:
            self.kind = .scorecardPDF
        case .hittingStatistics:
            self.kind = .hittingStatistics
        case .pitchingStatistics:
            self.kind = .pitchingStatistics
        }
        self.scope = document.scope
    }

    var authority: ShareableOutputAuthority {
        .generatedOutput
    }

    var purchaseGatedAction: PurchaseGatedAction {
        switch kind {
        case .scorecardPDF:
            .scorecardPDF
        case .hittingStatistics:
            .hittingStatistics
        case .pitchingStatistics:
            .pitchingStatistics
        }
    }

    var requiresGeneratedOutputPurchaseGate: Bool {
        purchaseGatedAction.requiresCurrentSeasonEntitlement
    }
}

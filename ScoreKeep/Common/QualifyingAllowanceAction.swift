import Foundation

enum QualifyingAllowanceAction: CaseIterable, Equatable, Sendable {
    case successfulGameCreation
    case successfulMLBRosterDownloadImport

    enum AllowanceKind: Equatable, Sendable {
        case freeGameCreation
        case mlbRosterDownload
    }

    var allowanceKind: AllowanceKind {
        switch self {
        case .successfulGameCreation:
            return .freeGameCreation
        case .successfulMLBRosterDownloadImport:
            return .mlbRosterDownload
        }
    }

    var counterKey: String {
        switch allowanceKind {
        case .freeGameCreation:
            return FreeGameAllowanceState.counterKey
        case .mlbRosterDownload:
            return MLBDownloadAllowanceState.counterKey
        }
    }
}

enum NonQualifyingAllowanceAction: CaseIterable, Equatable, Sendable {
    case premiumAccess
    case seededGameCreation
    case blockedByAllowance
    case canceled
    case failed
    case pending
    case downloadOnlyWithoutImportBoundary
    case importPreviewOnly
}

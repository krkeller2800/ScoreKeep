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

enum PaywallInterruptedWorkflow: Equatable, Sendable {
    case gameCreation
    case rosterDownloadImport(rosterID: String)

    var qualifyingAction: QualifyingAllowanceAction {
        switch self {
        case .gameCreation:
            return .successfulGameCreation
        case .rosterDownloadImport:
            return .successfulMLBRosterDownloadImport
        }
    }
}

enum PaywallResumeResolution: Equatable, Sendable {
    case entitlement
    case allowance
}

enum PaywallResumeDecision: Equatable, Sendable {
    case resume(PaywallInterruptedWorkflow, PaywallResumeResolution)
    case blocked(PaywallInterruptedWorkflow)
    case canceled(PaywallInterruptedWorkflow?)
}

struct PaywallResumePolicy: Equatable, Sendable {
    func decision(
        for workflow: PaywallInterruptedWorkflow?,
        isEntitled: Bool,
        hasAllowance: Bool
    ) -> PaywallResumeDecision {
        guard let workflow else {
            return .canceled(nil)
        }

        if isEntitled {
            return .resume(workflow, .entitlement)
        }

        if hasAllowance {
            return .resume(workflow, .allowance)
        }

        return .blocked(workflow)
    }

    func cancellation(for workflow: PaywallInterruptedWorkflow?) -> PaywallResumeDecision {
        .canceled(workflow)
    }
}

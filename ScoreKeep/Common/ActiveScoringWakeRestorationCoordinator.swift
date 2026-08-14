import SwiftUI

enum ActiveScoringWakeRestorationResolution: Equatable {
    case noRestoreNeeded
    case clearStalePersistentRestore
    case preserveExistingPath
    case clearFailedRestore
    case rebuildPath
}

enum ActiveScoringWakeRestorationPolicy {
    static func shouldShowRestoreProgress(
        hasPersistentRestoreIntent: Bool,
        isCurrentProcessWakeRestore: Bool,
        pathIsEmpty: Bool,
        hasValidGameID: Bool
    ) -> Bool {
        hasPersistentRestoreIntent
            && isCurrentProcessWakeRestore
            && pathIsEmpty
            && hasValidGameID
    }

    static func resolution(
        hasPersistentRestoreIntent: Bool,
        isCurrentProcessWakeRestore: Bool,
        pathIsEmpty: Bool,
        hasValidGameID: Bool
    ) -> ActiveScoringWakeRestorationResolution {
        guard hasPersistentRestoreIntent else {
            return .noRestoreNeeded
        }

        guard isCurrentProcessWakeRestore else {
            return .clearStalePersistentRestore
        }

        guard pathIsEmpty else {
            return .preserveExistingPath
        }

        guard hasValidGameID else {
            return .clearFailedRestore
        }

        return .rebuildPath
    }
}

enum ActiveScoringSidebarVisibilityRestoration {
    private static let allToken = "all"
    private static let automaticToken = "automatic"
    private static let detailOnlyToken = "detailOnly"
    private static let doubleColumnToken = "doubleColumn"

    static func token(for visibility: NavigationSplitViewVisibility) -> String? {
        if visibility == .all {
            return allToken
        } else if visibility == .automatic {
            return automaticToken
        } else if visibility == .detailOnly {
            return detailOnlyToken
        } else if visibility == .doubleColumn {
            return doubleColumnToken
        } else {
            return nil
        }
    }

    static func visibility(for token: String?) -> NavigationSplitViewVisibility? {
        switch token {
        case allToken:
            return .all
        case automaticToken:
            return .automatic
        case detailOnlyToken:
            return .detailOnly
        case doubleColumnToken:
            return .doubleColumn
        default:
            return nil
        }
    }
}

@MainActor
final class ActiveScoringWakeRestorationCoordinator: ObservableObject {
    @Published private(set) var isRestoringFromCurrentProcessWake = false

    func markCurrentProcessWakeRestoreNeeded() {
        isRestoringFromCurrentProcessWake = true
    }

    func clearCurrentProcessWakeRestore() {
        isRestoringFromCurrentProcessWake = false
    }
}

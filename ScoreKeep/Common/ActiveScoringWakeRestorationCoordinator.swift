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

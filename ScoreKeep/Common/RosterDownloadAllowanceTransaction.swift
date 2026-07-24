import Foundation

enum RosterDownloadAllowanceTransactionResult: Equatable, Sendable {
    case consume(AllowanceConsumptionIdentity)
    case duplicate(AllowanceConsumptionIdentity)
    case notQualifying(NonQualifyingAllowanceAction)
    case noAllowanceRemaining(AllowanceConsumptionIdentity)
}

struct RosterDownloadAllowanceTransaction: Equatable, Sendable {
    private var idempotencyRegister: AllowanceIdempotencyRegister

    init(idempotencyRegister: AllowanceIdempotencyRegister = AllowanceIdempotencyRegister()) {
        self.idempotencyRegister = idempotencyRegister
    }

    mutating func successfulDownloadImportBoundary(
        rosterID: String,
        allowance: MLBDownloadAllowanceState
    ) -> RosterDownloadAllowanceTransactionResult {
        let identity = AllowanceConsumptionIdentity(
            action: .successfulMLBRosterDownloadImport,
            idempotencyKey: Self.idempotencyKey(for: rosterID)
        )

        guard allowance.canDownloadWithAllowance else {
            return .noAllowanceRemaining(identity)
        }

        switch idempotencyRegister.recognize(identity) {
        case .consume(let identity):
            return .consume(identity)
        case .duplicate(let identity):
            return .duplicate(identity)
        case .notQualifying(let action):
            return .notQualifying(action)
        }
    }

    func nonQualifying(_ action: NonQualifyingAllowanceAction) -> RosterDownloadAllowanceTransactionResult {
        .notQualifying(action)
    }

    static func idempotencyKey(for rosterID: String) -> String {
        "mlb-roster-download-import:\(rosterID)"
    }
}

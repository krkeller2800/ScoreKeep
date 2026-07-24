import Foundation

enum GameCreationAllowanceTransactionResult: Equatable, Sendable {
    case consume(AllowanceConsumptionIdentity)
    case duplicate(AllowanceConsumptionIdentity)
    case notQualifying(NonQualifyingAllowanceAction)
    case noAllowanceRemaining(AllowanceConsumptionIdentity)
}

struct GameCreationAllowanceTransaction: Equatable, Sendable {
    private var idempotencyRegister: AllowanceIdempotencyRegister

    init(idempotencyRegister: AllowanceIdempotencyRegister = AllowanceIdempotencyRegister()) {
        self.idempotencyRegister = idempotencyRegister
    }

    mutating func successfulPersistedCreation(
        gameID: UUID,
        allowance: FreeGameAllowanceState
    ) -> GameCreationAllowanceTransactionResult {
        let identity = AllowanceConsumptionIdentity(
            action: .successfulGameCreation,
            idempotencyKey: Self.idempotencyKey(for: gameID)
        )

        guard allowance.canCreateWithAllowance else {
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

    func nonQualifying(_ action: NonQualifyingAllowanceAction) -> GameCreationAllowanceTransactionResult {
        .notQualifying(action)
    }

    static func idempotencyKey(for gameID: UUID) -> String {
        "game-create:\(gameID.uuidString)"
    }
}

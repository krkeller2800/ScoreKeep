import Foundation

struct AllowanceConsumptionIdentity: Hashable, Sendable {
    let action: QualifyingAllowanceAction
    let idempotencyKey: String

    init(action: QualifyingAllowanceAction, idempotencyKey: String) {
        self.action = action
        self.idempotencyKey = idempotencyKey
    }

    var allowanceKind: QualifyingAllowanceAction.AllowanceKind {
        action.allowanceKind
    }

    var counterKey: String {
        action.counterKey
    }
}

enum AllowanceIdempotencyDecision: Equatable, Sendable {
    case consume(AllowanceConsumptionIdentity)
    case duplicate(AllowanceConsumptionIdentity)
    case notQualifying(NonQualifyingAllowanceAction)
}

struct AllowanceIdempotencyRegister: Equatable, Sendable {
    private var consumedIdentities: Set<AllowanceConsumptionIdentity> = []

    init(consumedIdentities: Set<AllowanceConsumptionIdentity> = []) {
        self.consumedIdentities = consumedIdentities
    }

    mutating func recognize(_ identity: AllowanceConsumptionIdentity) -> AllowanceIdempotencyDecision {
        let inserted = consumedIdentities.insert(identity).inserted
        return inserted ? .consume(identity) : .duplicate(identity)
    }

    func recognize(_ action: NonQualifyingAllowanceAction) -> AllowanceIdempotencyDecision {
        .notQualifying(action)
    }
}

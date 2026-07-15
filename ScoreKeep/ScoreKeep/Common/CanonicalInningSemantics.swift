import Foundation

/// Non-routed Phase 1 foundation for inning number, half-inning, and expected-inning evidence.
/// These values do not advance innings or change existing `Atbat.inning` values.
enum InningHalf: String, Hashable, Sendable {
    case top
    case bottom
}

enum InningNumberEvidence: Hashable, Sendable {
    case known(Int)
    case missing
    case invalid(Int)
    case unsupported(String)
    case conflicting(Set<Int>)

    var inningNumber: Int? {
        if case let .known(value) = self { return value }
        return nil
    }
}

enum HalfInningEvidence: Hashable, Sendable {
    case known(InningHalf)
    case missing
    case unresolved
    case contradictory(Set<InningHalf>)
}

enum ExpectedInningCountEvidence: Hashable, Sendable {
    case known(Int)
    case missing
    case invalid(Int)
    case unsupported(String)
    case conflicting(Set<Int>)

    var count: Int? {
        if case let .known(value) = self { return value }
        return nil
    }
}

struct CanonicalHalfInning: Hashable, Sendable {
    let number: InningNumberEvidence
    let half: HalfInningEvidence
    let expectedInnings: ExpectedInningCountEvidence
    let endOfHalfEvidence: Bool
    let interruptedEvidence: Bool
    let shortenedGameEvidence: Bool
    let source: GameEvidenceSource

    init(
        number: InningNumberEvidence,
        half: HalfInningEvidence,
        expectedInnings: ExpectedInningCountEvidence = .missing,
        endOfHalfEvidence: Bool = false,
        interruptedEvidence: Bool = false,
        shortenedGameEvidence: Bool = false,
        source: GameEvidenceSource = .unknown
    ) {
        self.number = number
        self.half = half
        self.expectedInnings = expectedInnings
        self.endOfHalfEvidence = endOfHalfEvidence
        self.interruptedEvidence = interruptedEvidence
        self.shortenedGameEvidence = shortenedGameEvidence
        self.source = source
    }
}

enum InningClassification: Hashable, Sendable {
    case validHalfInning
    case firstInning
    case regulationInning
    case extraInning
    case shortenedGameEvidence
    case interruptedInningEvidence
    case endOfHalfEvidence
    case missingInning
    case invalidInning
    case missingHalf
    case unresolvedHalf
    case contradictoryHalf
    case missingExpectedInnings
    case invalidExpectedInnings
    case contradictoryInningEvidence
}

enum CanonicalInningSemanticsClassifier {
    static func classify(_ inning: CanonicalHalfInning) -> Set<InningClassification> {
        var classifications: Set<InningClassification> = []

        switch inning.number {
        case let .known(value):
            classifications.insert(.validHalfInning)
            if value == 1 { classifications.insert(.firstInning) }
            if let expected = inning.expectedInnings.count {
                classifications.insert(value > expected ? .extraInning : .regulationInning)
            }
        case .missing:
            classifications.insert(.missingInning)
        case .invalid, .unsupported:
            classifications.insert(.invalidInning)
        case .conflicting:
            classifications.insert(.contradictoryInningEvidence)
        }

        switch inning.half {
        case .known:
            break
        case .missing:
            classifications.insert(.missingHalf)
        case .unresolved:
            classifications.insert(.unresolvedHalf)
        case .contradictory:
            classifications.insert(.contradictoryHalf)
            classifications.insert(.contradictoryInningEvidence)
        }

        switch inning.expectedInnings {
        case let .known(value) where value <= 0:
            classifications.insert(.invalidExpectedInnings)
        case .known:
            break
        case .missing:
            classifications.insert(.missingExpectedInnings)
        case .invalid, .unsupported:
            classifications.insert(.invalidExpectedInnings)
        case .conflicting:
            classifications.insert(.contradictoryInningEvidence)
        }

        if inning.endOfHalfEvidence { classifications.insert(.endOfHalfEvidence) }
        if inning.interruptedEvidence { classifications.insert(.interruptedInningEvidence) }
        if inning.shortenedGameEvidence { classifications.insert(.shortenedGameEvidence) }

        return classifications
    }

    static func sameInningDifferentHalf(_ lhs: CanonicalHalfInning, _ rhs: CanonicalHalfInning) -> Bool {
        lhs.number.inningNumber == rhs.number.inningNumber &&
            lhs.half != rhs.half &&
            lhs.number.inningNumber != nil
    }
}

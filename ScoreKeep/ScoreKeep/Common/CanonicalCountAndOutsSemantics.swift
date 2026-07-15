import Foundation

/// Non-routed Phase 1 foundation for optional count evidence and outs meaning.
/// The current repository has no persisted ball/strike count fields, so count remains an optional boundary.
enum BallStrikeCountEvidence: Hashable, Sendable {
    case unsupportedRepositoryEvidence
    case known(balls: Int, strikes: Int)
    case missing
    case invalid(balls: Int?, strikes: Int?)
    case unsupported(String)
    case resetBoundary
    case contradictory(Set<BallStrikeCountEvidence>)
}

enum CountClassification: Hashable, Sendable {
    case unsupportedRepositoryEvidence
    case knownCount
    case missingCount
    case invalidCount
    case unsupportedCount
    case fullCount
    case countResetBoundary
    case contradictoryCountEvidence
}

enum OutsEvidence: Hashable, Sendable {
    case known(Int)
    case missing
    case invalid(Int)
    case conflicting(Set<Int>)

    var outValue: Int? {
        if case let .known(value) = self { return value }
        return nil
    }
}

enum RunnerOutEvidence: Hashable, Sendable {
    case notRepresented
    case runnerOut(RunnerIdentityEvidence, base: Base)
    case batterRunnerOut(base: Base)
    case unknownRunnerOut(base: Base?)
    case conflicting
}

struct CanonicalOutsState: Hashable, Sendable {
    let outs: OutsEvidence
    let outsRecordedByEvent: Int?
    let runnerOutEvidence: [RunnerOutEvidence]
    let endOfHalfEvidence: Bool
    let thirdOutContext: Bool
    let source: GameEvidenceSource

    init(
        outs: OutsEvidence,
        outsRecordedByEvent: Int? = nil,
        runnerOutEvidence: [RunnerOutEvidence] = [],
        endOfHalfEvidence: Bool = false,
        thirdOutContext: Bool = false,
        source: GameEvidenceSource = .unknown
    ) {
        self.outs = outs
        self.outsRecordedByEvent = outsRecordedByEvent
        self.runnerOutEvidence = runnerOutEvidence
        self.endOfHalfEvidence = endOfHalfEvidence
        self.thirdOutContext = thirdOutContext
        self.source = source
    }
}

enum OutsClassification: Hashable, Sendable {
    case zeroOuts
    case oneOut
    case twoOuts
    case thirdOutContext
    case missingOuts
    case invalidNegativeOuts
    case impossibleFourthOrGreaterOutState
    case conflictingOutsEvidence
    case outsRecordedByEvent(Int)
    case runnerOutContext
    case endOfHalfEvidence
}

enum CanonicalCountAndOutsSemanticsClassifier {
    static func classifyCount(_ count: BallStrikeCountEvidence) -> Set<CountClassification> {
        switch count {
        case .unsupportedRepositoryEvidence:
            return [.unsupportedRepositoryEvidence]
        case let .known(balls, strikes):
            var classifications: Set<CountClassification> = [.knownCount]
            if balls < 0 || strikes < 0 || balls > 3 || strikes > 2 {
                classifications.insert(.invalidCount)
            }
            if balls == 3 && strikes == 2 {
                classifications.insert(.fullCount)
            }
            return classifications
        case .missing:
            return [.missingCount]
        case .invalid:
            return [.invalidCount]
        case .unsupported:
            return [.unsupportedCount]
        case .resetBoundary:
            return [.countResetBoundary]
        case .contradictory:
            return [.contradictoryCountEvidence]
        }
    }

    static func classifyOuts(_ state: CanonicalOutsState) -> Set<OutsClassification> {
        var classifications: Set<OutsClassification> = []
        switch state.outs {
        case let .known(value):
            switch value {
            case 0:
                classifications.insert(.zeroOuts)
            case 1:
                classifications.insert(.oneOut)
            case 2:
                classifications.insert(.twoOuts)
            case 3:
                classifications.insert(.thirdOutContext)
            case 4...:
                classifications.insert(.impossibleFourthOrGreaterOutState)
            default:
                classifications.insert(.invalidNegativeOuts)
            }
        case .missing:
            classifications.insert(.missingOuts)
        case let .invalid(value):
            classifications.insert(value < 0 ? .invalidNegativeOuts : .impossibleFourthOrGreaterOutState)
        case .conflicting:
            classifications.insert(.conflictingOutsEvidence)
        }

        if state.thirdOutContext { classifications.insert(.thirdOutContext) }
        if state.endOfHalfEvidence { classifications.insert(.endOfHalfEvidence) }
        if state.runnerOutEvidence.isEmpty == false { classifications.insert(.runnerOutContext) }
        if let outsRecordedByEvent = state.outsRecordedByEvent {
            classifications.insert(.outsRecordedByEvent(outsRecordedByEvent))
        }
        return classifications
    }
}

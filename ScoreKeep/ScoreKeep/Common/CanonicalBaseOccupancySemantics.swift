import Foundation

/// Non-routed Phase 1 foundation for base occupancy and runner-state evidence.
/// These values represent evidence only and do not advance runners, score runs, or replay events.
enum Base: Int, CaseIterable, Hashable, Sendable {
    case first = 1
    case second = 2
    case third = 3
    case home = 4
}

enum RunnerIdentityEvidence: Hashable, Sendable {
    case gameParticipant(GamePlayerParticipation)
    case reusablePlayer(ReusableCanonicalPlayer)
    case knownHistoricalParticipant(ImportedIdentifierEvidence, PlayerDisplayEvidence)
    case unknown(PlayerDisplayEvidence)
    case missingRelationship(PlayerDisplayEvidence)
    case invalidIdentity(ImportedIdentifierEvidence, PlayerDisplayEvidence)
    case importedUnresolved(PlayerDisplayEvidence)

    var identity: ImportedIdentifierEvidence {
        switch self {
        case let .gameParticipant(participant):
            return participant.reusablePlayerIdentity ?? participant.participantIdentity
        case let .reusablePlayer(player):
            return player.identity
        case let .knownHistoricalParticipant(identity, _):
            return identity
        case .unknown, .missingRelationship, .importedUnresolved:
            return .missing
        case let .invalidIdentity(identity, _):
            return identity
        }
    }
}

enum RunnerStateEvidence: Hashable, Sendable {
    case activeOccupant(base: Base, runner: RunnerIdentityEvidence)
    case scored(runner: RunnerIdentityEvidence, sourceBase: Base?)
    case out(runner: RunnerIdentityEvidence, sourceBase: Base?)
    case batterRunner(RunnerIdentityEvidence)
    case historicalRunner(RunnerIdentityEvidence, lastKnownBase: Base?)
    case ambiguousLegacyMaxBase(String)
    case ambiguousLegacyOutAt(String)
    case unsupportedLegacyValue(field: String, value: String)
    case contradictory(String)
}

struct CanonicalBaseOccupancy: Hashable, Sendable {
    let runnerStates: [RunnerStateEvidence]
    let source: GameEvidenceSource

    init(runnerStates: [RunnerStateEvidence] = [], source: GameEvidenceSource = .unknown) {
        self.runnerStates = runnerStates
        self.source = source
    }
}

enum BaseOccupancyClassification: Hashable, Sendable {
    case basesEmpty
    case occupiedBases(Set<Base>)
    case runnerOnFirst
    case runnerOnSecond
    case runnerOnThird
    case allBasesOccupied
    case knownRunnerIdentity
    case unknownRunner
    case missingRunnerRelationship
    case invalidRunnerIdentity
    case sameRunnerAssignedToMultipleBases
    case multipleRunnersAssignedToOneBase(Base)
    case runnerScored
    case runnerOut
    case batterRunnerEvidence
    case historicalRunnerEvidence
    case ambiguousLegacyAdvancementEvidence
    case unsupportedLegacyEvidence
    case impossibleOrContradictoryOccupancy
    case unresolvedRunnerEvidence
}

enum CanonicalBaseOccupancySemanticsClassifier {
    static func classify(_ occupancy: CanonicalBaseOccupancy) -> Set<BaseOccupancyClassification> {
        var classifications: Set<BaseOccupancyClassification> = []
        let activeOccupants = occupancy.runnerStates.compactMap(activeOccupant)
        let activeBases = Set(activeOccupants.map { $0.base })

        if activeBases.isEmpty {
            classifications.insert(.basesEmpty)
        } else {
            classifications.insert(.occupiedBases(activeBases))
            if activeBases.contains(.first) { classifications.insert(.runnerOnFirst) }
            if activeBases.contains(.second) { classifications.insert(.runnerOnSecond) }
            if activeBases.contains(.third) { classifications.insert(.runnerOnThird) }
            if activeBases == Set([.first, .second, .third]) { classifications.insert(.allBasesOccupied) }
        }

        for base in Base.allCases where base != .home {
            if activeOccupants.filter({ $0.base == base }).count > 1 {
                classifications.insert(.multipleRunnersAssignedToOneBase(base))
                classifications.insert(.impossibleOrContradictoryOccupancy)
            }
        }

        let identitiesByBase = activeOccupants.compactMap { occupant -> (ImportedIdentifierEvidence, Base)? in
            guard occupant.runner.identity.validIdentifier != nil else { return nil }
            return (occupant.runner.identity, occupant.base)
        }
        let groupedByIdentity = Dictionary(grouping: identitiesByBase, by: \.0)
        if groupedByIdentity.values.contains(where: { Set($0.map { $0.1 }).count > 1 }) {
            classifications.insert(.sameRunnerAssignedToMultipleBases)
            classifications.insert(.impossibleOrContradictoryOccupancy)
        }

        for state in occupancy.runnerStates {
            switch state {
            case let .activeOccupant(_, runner),
                 let .batterRunner(runner),
                 let .historicalRunner(runner, _),
                 let .scored(runner, _),
                 let .out(runner, _):
                classifications.formUnion(classifyRunner(runner))
            case .ambiguousLegacyMaxBase, .ambiguousLegacyOutAt:
                classifications.insert(.ambiguousLegacyAdvancementEvidence)
                classifications.insert(.unresolvedRunnerEvidence)
            case .unsupportedLegacyValue:
                classifications.insert(.unsupportedLegacyEvidence)
            case .contradictory:
                classifications.insert(.impossibleOrContradictoryOccupancy)
            }

            switch state {
            case .scored:
                classifications.insert(.runnerScored)
            case .out:
                classifications.insert(.runnerOut)
            case .batterRunner:
                classifications.insert(.batterRunnerEvidence)
            case .historicalRunner:
                classifications.insert(.historicalRunnerEvidence)
            default:
                break
            }
        }

        for occupant in activeOccupants {
            if occupancy.runnerStates.contains(where: { terminalState($0, matches: occupant.runner) }) {
                classifications.insert(.impossibleOrContradictoryOccupancy)
            }
        }

        return classifications
    }

    static func activeOccupiedBases(_ occupancy: CanonicalBaseOccupancy) -> Set<Base> {
        Set(occupancy.runnerStates.compactMap(activeOccupant).map { $0.base })
    }

    private static func activeOccupant(_ state: RunnerStateEvidence) -> (base: Base, runner: RunnerIdentityEvidence)? {
        if case let .activeOccupant(base, runner) = state {
            return (base, runner)
        }
        return nil
    }

    private static func terminalState(_ state: RunnerStateEvidence, matches runner: RunnerIdentityEvidence) -> Bool {
        switch state {
        case let .scored(scoredRunner, _), let .out(scoredRunner, _):
            return scoredRunner.identity == runner.identity
        default:
            return false
        }
    }

    private static func classifyRunner(_ runner: RunnerIdentityEvidence) -> Set<BaseOccupancyClassification> {
        switch runner {
        case .gameParticipant, .reusablePlayer, .knownHistoricalParticipant:
            return [.knownRunnerIdentity]
        case .unknown:
            return [.unknownRunner, .unresolvedRunnerEvidence]
        case .missingRelationship:
            return [.missingRunnerRelationship, .unresolvedRunnerEvidence]
        case .invalidIdentity:
            return [.invalidRunnerIdentity, .unresolvedRunnerEvidence]
        case .importedUnresolved:
            return [.unresolvedRunnerEvidence]
        }
    }
}

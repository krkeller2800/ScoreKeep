import Foundation

struct CanonicalScoringEventApplicationResult: Hashable, Sendable {
    let validation: CanonicalScoringCommandValidation
    let inputState: CanonicalScoringCommandInputState
    let event: CanonicalScoringEventEvidence?
    let resultingState: CanonicalScoringCommandInputState
    let changedFacts: Set<CanonicalScoringEventApplicationFact>
    let preservedUnsupportedEvidence: [String]

    var applied: Bool { event != nil }
    var inputStateRemainsUnchanged: Bool { inputState == validation.inputState }
}

enum CanonicalScoringEventApplicationFact: String, Hashable, Sendable {
    case eventEvidence
    case batterDestination
    case runnerDestinations
    case runnerOutState
    case outs
    case baseOccupancy
    case runEvidence
    case rbiEvidence
    case endOfHalfEvidence
    case unsupportedEvidencePreserved
}

enum CanonicalScoringEventApplicator {
    static func apply(
        _ command: CanonicalScoringCommand,
        to input: CanonicalScoringCommandInputState,
        sourceLocation: String? = nil
    ) -> CanonicalScoringEventApplicationResult {
        let validation = CanonicalScoringCommandValidator.validate(command, against: input, sourceLocation: sourceLocation)
        guard validation.mayApplyInMemory else {
            return CanonicalScoringEventApplicationResult(
                validation: validation,
                inputState: input,
                event: nil,
                resultingState: input,
                changedFacts: [],
                preservedUnsupportedEvidence: command.rawLegacyEvidence
            )
        }

        var active = activeOccupants(input.baseOccupancy)
        var runnerEvidence: [RunnerStateEvidence] = []
        var changedFacts: Set<CanonicalScoringEventApplicationFact> = [.eventEvidence]
        var outsAdded = 0
        var runsScored = 0
        var batterAdvancement: RunnerStateEvidence?
        var endOfHalf = false
        var appliedRunnerDestinations: Set<CanonicalRunnerDestinationIntent> = []

        switch command.intent {
        case let .batterReaches(destination, _):
            if let runner = batterRunner(command.batter ?? input.currentBatter) {
                active.removeAll { $0.runner.identity == runner.identity }
                active.append((destination, runner))
                batterAdvancement = .activeOccupant(base: destination, runner: runner)
                changedFacts.formUnion([.batterDestination, .baseOccupancy])
            }
        case .homeRun:
            if let runner = batterRunner(command.batter ?? input.currentBatter) {
                batterAdvancement = .scored(runner: runner, sourceBase: nil)
                runnerEvidence.append(.scored(runner: runner, sourceBase: nil))
                runsScored += 1
                changedFacts.formUnion([.batterDestination, .runEvidence])
            }
        case .batterOut:
            outsAdded += 1
            changedFacts.formUnion([.batterDestination, .outs])
        case let .runnerAdvances(runner, from, to, stolenBase):
            let destination = CanonicalRunnerDestinationIntent.advance(runner: runner, from: from, to: to, stolenBase: stolenBase)
            apply(destination, active: &active, runnerEvidence: &runnerEvidence, outsAdded: &outsAdded, runsScored: &runsScored, changedFacts: &changedFacts)
            appliedRunnerDestinations.insert(destination)
        case let .runnerScores(runner, from, rbi):
            let destination = CanonicalRunnerDestinationIntent.score(runner: runner, from: from, rbi: rbi)
            apply(destination, active: &active, runnerEvidence: &runnerEvidence, outsAdded: &outsAdded, runsScored: &runsScored, changedFacts: &changedFacts)
            appliedRunnerDestinations.insert(destination)
        case let .runnerOut(runner, from, outAt):
            let destination = CanonicalRunnerDestinationIntent.out(runner: runner, from: from, outAt: outAt)
            apply(destination, active: &active, runnerEvidence: &runnerEvidence, outsAdded: &outsAdded, runsScored: &runsScored, changedFacts: &changedFacts)
            appliedRunnerDestinations.insert(destination)
        case let .multipleOuts(count):
            outsAdded += count
            changedFacts.insert(.outs)
        case .endHalfInning:
            endOfHalf = true
            active.removeAll()
            changedFacts.formUnion([.endOfHalfEvidence, .baseOccupancy, .outs])
        case .unsupportedLegacy:
            return CanonicalScoringEventApplicationResult(
                validation: validation,
                inputState: input,
                event: nil,
                resultingState: input,
                changedFacts: command.rawLegacyEvidence.isEmpty ? [] : [.unsupportedEvidencePreserved],
                preservedUnsupportedEvidence: command.rawLegacyEvidence
            )
        }

        for destination in command.runnerDestinations where appliedRunnerDestinations.contains(destination) == false {
            apply(destination, active: &active, runnerEvidence: &runnerEvidence, outsAdded: &outsAdded, runsScored: &runsScored, changedFacts: &changedFacts)
        }

        if command.outsRequested > 0 {
            outsAdded += command.outsRequested
            changedFacts.insert(.outs)
        }

        let currentOuts = input.outs.outs.outValue ?? 0
        let projectedOuts = endOfHalf ? 3 : min(3, currentOuts + outsAdded)
        if projectedOuts == 3 { endOfHalf = endOfHalf || command.intent == .endHalfInning }

        let resultingOccupancy = CanonicalBaseOccupancy(
            runnerStates: active.sorted { $0.base.rawValue < $1.base.rawValue }.map { .activeOccupant(base: $0.base, runner: $0.runner) },
            source: input.baseOccupancy.source
        )
        let resultingOuts = CanonicalOutsState(
            outs: .known(projectedOuts),
            outsRecordedByEvent: outsAdded == 0 ? nil : outsAdded,
            endOfHalfEvidence: endOfHalf,
            thirdOutContext: projectedOuts == 3,
            source: input.outs.source
        )
        let resultingState = CanonicalScoringCommandInputState(
            game: input.game,
            battingSide: input.battingSide,
            inning: input.inning,
            outs: resultingOuts,
            baseOccupancy: resultingOccupancy,
            currentBatter: input.currentBatter,
            lineupParticipants: input.lineupParticipants,
            pitcherResponsibility: input.pitcherResponsibility
        )

        let event = CanonicalScoringEventEvidence(
            eventIdentity: command.proposedEventIdentity,
            gameIdentity: command.gameIdentity,
            orderingEvidence: command.orderingEvidence,
            inningContext: input.inning,
            teamSide: command.teamSide,
            participants: ScoringEventParticipantEvidence(batter: command.batter ?? input.currentBatter, runners: runnerEvidence),
            resultEvidence: resultEvidence(for: command.intent),
            outsEvidence: resultingOuts,
            batterAdvancement: batterAdvancement,
            runnerAdvancement: runnerEvidence,
            runsScored: runsScored == 0 ? .notRepresented : .count(runsScored),
            rbiEvidence: command.rbiEvidence,
            earnedRunEvidence: command.earnedRunEvidence,
            sacrificeEvidence: command.sacrificeEvidence,
            stolenBaseEvidence: command.stolenBaseEvidence,
            endOfHalfEvidence: endOfHalf,
            historicalDisplayEvidence: [],
            unsupportedRawLegacyEvidence: command.rawLegacyEvidence,
            source: .syntheticVerification
        )

        if markerHasEvidence(command.rbiEvidence) { changedFacts.insert(.rbiEvidence) }
        if command.rawLegacyEvidence.isEmpty == false { changedFacts.insert(.unsupportedEvidencePreserved) }

        return CanonicalScoringEventApplicationResult(
            validation: validation,
            inputState: input,
            event: event,
            resultingState: resultingState,
            changedFacts: changedFacts,
            preservedUnsupportedEvidence: command.rawLegacyEvidence
        )
    }

    private static func apply(
        _ destination: CanonicalRunnerDestinationIntent,
        active: inout [(base: Base, runner: RunnerIdentityEvidence)],
        runnerEvidence: inout [RunnerStateEvidence],
        outsAdded: inout Int,
        runsScored: inout Int,
        changedFacts: inout Set<CanonicalScoringEventApplicationFact>
    ) {
        switch destination {
        case let .advance(runner, from, to, _):
            active.removeAll { $0.base == from && $0.runner == runner }
            active.append((to, runner))
            runnerEvidence.append(.activeOccupant(base: to, runner: runner))
            changedFacts.formUnion([.runnerDestinations, .baseOccupancy])
        case let .score(runner, from, rbi):
            active.removeAll { $0.base == from && $0.runner == runner }
            runnerEvidence.append(.scored(runner: runner, sourceBase: from))
            runsScored += 1
            changedFacts.formUnion([.runnerDestinations, .baseOccupancy, .runEvidence])
            if rbi { changedFacts.insert(.rbiEvidence) }
        case let .out(runner, from, _):
            active.removeAll { $0.base == from && $0.runner == runner }
            runnerEvidence.append(.out(runner: runner, sourceBase: from))
            outsAdded += 1
            changedFacts.formUnion([.runnerOutState, .baseOccupancy, .outs])
        }
    }

    private static func resultEvidence(for intent: CanonicalScoringCommandIntent) -> ScoringEventResultEvidence {
        switch intent {
        case let .batterReaches(_, result), let .batterOut(result):
            return result
        case .homeRun:
            return .batterReachesBase(rawValue: "Home Run")
        case .runnerAdvances:
            return .runnerAdvances(rawValue: "Safe")
        case .runnerScores:
            return .runnerScores(rawValue: "Home")
        case .runnerOut:
            return .runnerOut(rawValue: "Out")
        case .multipleOuts, .endHalfInning:
            return .batterOut(rawValue: "Out")
        case let .unsupportedLegacy(disposition):
            return .unsupportedRawResult(disposition.rawValue ?? "unsupported")
        }
    }

    private static func activeOccupants(_ occupancy: CanonicalBaseOccupancy) -> [(base: Base, runner: RunnerIdentityEvidence)] {
        occupancy.runnerStates.compactMap { state in
            if case let .activeOccupant(base, runner) = state { return (base, runner) }
            return nil
        }
    }

    private static func batterRunner(_ batter: LineupParticipantEvidence?) -> RunnerIdentityEvidence? {
        guard let batter else { return nil }
        switch batter {
        case let .gameParticipant(participant), let .wrongGameSide(participant), let .unresolvedGameSide(participant):
            return .gameParticipant(participant)
        case let .reusablePlayer(player), let .historicalPlayer(player, _), let .absentFromCurrentRoster(player):
            return .reusablePlayer(player)
        case let .currentRosterMembership(membership):
            switch membership.playerEvidence {
            case let .reusablePlayer(player):
                return .reusablePlayer(player)
            case let .invalidIdentity(identity, display), let .conflicting(identity, display):
                return .invalidIdentity(identity, display)
            case let .unknown(display), let .detachedImported(display):
                return .unknown(display)
            case .missing:
                return .missingRelationship(PlayerDisplayEvidence())
            }
        case let .missingPlayerIdentity(display):
            return .missingRelationship(display)
        case let .invalidPlayerIdentity(identity, display):
            return .invalidIdentity(identity, display)
        case let .unknown(display), let .importedDetached(display):
            return .unknown(display)
        }
    }

    private static func markerHasEvidence(_ marker: ScoringEventMarkerEvidence) -> Bool {
        switch marker {
        case .notRepresented:
            return false
        case let .count(value):
            return value != 0
        case .flag, .conflicting:
            return true
        }
    }
}

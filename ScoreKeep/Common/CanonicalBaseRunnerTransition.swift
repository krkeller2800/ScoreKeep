import Foundation

enum CanonicalBatterRunnerTransition: Hashable, Sendable {
    case unresolved
    case reaches(Base, RunnerIdentityEvidence)
    case scores(RunnerIdentityEvidence)
    case out(RunnerIdentityEvidence, outAt: Base)
}

struct CanonicalBaseRunnerTransitionRequest: Hashable, Sendable {
    let inputOccupancy: CanonicalBaseOccupancy
    let batterOutcome: CanonicalBatterRunnerTransition
    let runnerDestinations: [CanonicalRunnerDestinationIntent]
    let expectedResultingOccupancy: CanonicalBaseOccupancy?

    init(inputOccupancy: CanonicalBaseOccupancy, batterOutcome: CanonicalBatterRunnerTransition = .unresolved, runnerDestinations: [CanonicalRunnerDestinationIntent] = [], expectedResultingOccupancy: CanonicalBaseOccupancy? = nil) {
        self.inputOccupancy = inputOccupancy
        self.batterOutcome = batterOutcome
        self.runnerDestinations = runnerDestinations
        self.expectedResultingOccupancy = expectedResultingOccupancy
    }
}

struct CanonicalBaseRunnerTransitionResult: Hashable, Sendable {
    let inputOccupancy: CanonicalBaseOccupancy
    let resultingOccupancy: CanonicalBaseOccupancy
    let batterOutcome: RunnerStateEvidence?
    let runnerOutcomes: [RunnerStateEvidence]
    let scoredRunners: [RunnerIdentityEvidence]
    let outRunners: [RunnerIdentityEvidence]
    let validation: CanonicalValidationResult
    let changedFacts: Set<CanonicalScoringEventApplicationFact>
    let preservedUnsupportedEvidence: [String]
    let rejected: Bool
    let inputRemainsUnchanged: Bool
}

enum CanonicalBaseRunnerTransition {
    static func apply(_ request: CanonicalBaseRunnerTransitionRequest) -> CanonicalBaseRunnerTransitionResult {
        var findings: [CanonicalValidationFinding] = []
        let inputActive = activeOccupants(request.inputOccupancy)
        var active = inputActive
        var outcomes: [RunnerStateEvidence] = []
        var scored: [RunnerIdentityEvidence] = []
        var out: [RunnerIdentityEvidence] = []
        var changed: Set<CanonicalScoringEventApplicationFact> = []

        findings += validateRunnerIdentities(inputActive.map(\.runner), codePrefix: "baseRunnerTransition.input")
        findings += validateDestinations(request.runnerDestinations, inputActive: inputActive)

        if let expected = request.expectedResultingOccupancy {
            findings += validateNoDisappearingRunners(input: inputActive, expected: activeOccupants(expected), terminalDestinations: request.runnerDestinations)
        }

        let validationBeforeApply = CanonicalValidationResult(findings: findings)
        guard validationBeforeApply.futureWriteMustStop == false else {
            return result(request, resulting: request.inputOccupancy, batterOutcome: nil, outcomes: [], scored: [], out: [], validation: validationBeforeApply, changed: [], rejected: true)
        }

        for destination in request.runnerDestinations {
            apply(destination, active: &active, outcomes: &outcomes, scored: &scored, out: &out, changed: &changed)
        }

        let batterEvidence: RunnerStateEvidence?
        switch request.batterOutcome {
        case .unresolved:
            batterEvidence = nil
        case let .reaches(base, runner):
            active.removeAll { $0.runner.identity == runner.identity }
            active.append((base, runner))
            batterEvidence = .activeOccupant(base: base, runner: runner)
            changed.formUnion([.batterDestination, .baseOccupancy])
        case let .scores(runner):
            batterEvidence = .scored(runner: runner, sourceBase: nil)
            scored.append(runner)
            outcomes.append(.scored(runner: runner, sourceBase: nil))
            changed.formUnion([.batterDestination, .runEvidence])
        case let .out(runner, _):
            batterEvidence = .out(runner: runner, sourceBase: nil)
            out.append(runner)
            outcomes.append(.out(runner: runner, sourceBase: nil))
            changed.formUnion([.batterDestination, .runnerOutState])
        }

        findings += validateFinalOccupancy(active)
        let validation = CanonicalValidationResult(findings: findings)
        let rejected = validation.futureWriteMustStop
        let occupancy = rejected ? request.inputOccupancy : CanonicalBaseOccupancy(
            runnerStates: active.sorted { $0.base.rawValue < $1.base.rawValue }.map { .activeOccupant(base: $0.base, runner: $0.runner) },
            source: request.inputOccupancy.source
        )

        return result(request, resulting: occupancy, batterOutcome: rejected ? nil : batterEvidence, outcomes: rejected ? [] : outcomes, scored: rejected ? [] : scored, out: rejected ? [] : out, validation: validation, changed: rejected ? [] : changed, rejected: rejected)
    }

    private static func result(_ request: CanonicalBaseRunnerTransitionRequest, resulting: CanonicalBaseOccupancy, batterOutcome: RunnerStateEvidence?, outcomes: [RunnerStateEvidence], scored: [RunnerIdentityEvidence], out: [RunnerIdentityEvidence], validation: CanonicalValidationResult, changed: Set<CanonicalScoringEventApplicationFact>, rejected: Bool) -> CanonicalBaseRunnerTransitionResult {
        CanonicalBaseRunnerTransitionResult(
            inputOccupancy: request.inputOccupancy,
            resultingOccupancy: resulting,
            batterOutcome: batterOutcome,
            runnerOutcomes: outcomes,
            scoredRunners: scored,
            outRunners: out,
            validation: validation,
            changedFacts: changed,
            preservedUnsupportedEvidence: [],
            rejected: rejected,
            inputRemainsUnchanged: true
        )
    }

    private static func apply(_ destination: CanonicalRunnerDestinationIntent, active: inout [(base: Base, runner: RunnerIdentityEvidence)], outcomes: inout [RunnerStateEvidence], scored: inout [RunnerIdentityEvidence], out: inout [RunnerIdentityEvidence], changed: inout Set<CanonicalScoringEventApplicationFact>) {
        switch destination {
        case let .advance(runner, from, to, _):
            active.removeAll { $0.base == from && $0.runner == runner }
            active.append((to, runner))
            outcomes.append(.activeOccupant(base: to, runner: runner))
            changed.formUnion([.runnerDestinations, .baseOccupancy])
        case let .score(runner, from, _):
            active.removeAll { $0.base == from && $0.runner == runner }
            outcomes.append(.scored(runner: runner, sourceBase: from))
            scored.append(runner)
            changed.formUnion([.runnerDestinations, .baseOccupancy, .runEvidence])
        case let .out(runner, from, _):
            active.removeAll { $0.base == from && $0.runner == runner }
            outcomes.append(.out(runner: runner, sourceBase: from))
            out.append(runner)
            changed.formUnion([.runnerDestinations, .baseOccupancy, .runnerOutState])
        }
    }

    private static func validateDestinations(_ destinations: [CanonicalRunnerDestinationIntent], inputActive: [(base: Base, runner: RunnerIdentityEvidence)]) -> [CanonicalValidationFinding] {
        var findings: [CanonicalValidationFinding] = []
        let activeByBase = Dictionary(uniqueKeysWithValues: inputActive.map { ($0.base, $0.runner) })
        let vacatedBases = Set(destinations.map(\.sourceBase))
        var seenRunners: Set<ImportedIdentifierEvidence> = []
        var destinationClaims: [Base: Int] = [:]

        for destination in destinations {
            let runner = destination.runner
            guard activeByBase[destination.sourceBase] == runner else {
                findings.append(finding("baseRunnerTransition.runnerMissingFromSource", .rejection, .rejected, "Runner is not active on the requested source base."))
                continue
            }
            if runner.identity.validIdentifier == nil {
                findings += validateRunnerIdentities([runner], codePrefix: "baseRunnerTransition.destination")
            } else if seenRunners.contains(runner.identity) {
                findings.append(finding("baseRunnerTransition.sameRunnerAssignedTwice", .contradiction, .contradictory, "The same runner has multiple outcomes in one transition."))
            }
            seenRunners.insert(runner.identity)

            if let destinationBase = destination.destinationBase {
                if destinationBase.rawValue <= destination.sourceBase.rawValue {
                    findings.append(finding("baseRunnerTransition.runnerMovesBackward", .contradiction, .contradictory, "Runner destination does not advance from the source base."))
                }
                destinationClaims[destinationBase, default: 0] += 1
                if let occupying = activeByBase[destinationBase], occupying != runner, vacatedBases.contains(destinationBase) == false {
                    findings.append(finding("baseRunnerTransition.occupiedDestination", .rejection, .rejected, "Destination base is occupied without supported coordinated movement."))
                }
            }
        }

        for (_, count) in destinationClaims where count > 1 {
            findings.append(finding("baseRunnerTransition.multipleRunnersSameDestination", .contradiction, .contradictory, "Multiple runners are assigned to one destination base."))
        }
        return findings
    }

    private static func validateFinalOccupancy(_ active: [(base: Base, runner: RunnerIdentityEvidence)]) -> [CanonicalValidationFinding] {
        let occupancy = CanonicalBaseOccupancy(runnerStates: active.map { .activeOccupant(base: $0.base, runner: $0.runner) })
        return CanonicalBaseOccupancySemanticsClassifier.classify(occupancy).contains(.impossibleOrContradictoryOccupancy)
            ? [finding("baseRunnerTransition.contradictoryResultingOccupancy", .contradiction, .contradictory, "Resulting base occupancy is contradictory.")]
            : []
    }

    private static func validateNoDisappearingRunners(input: [(base: Base, runner: RunnerIdentityEvidence)], expected: [(base: Base, runner: RunnerIdentityEvidence)], terminalDestinations: [CanonicalRunnerDestinationIntent]) -> [CanonicalValidationFinding] {
        let expectedIdentities = Set(expected.map { $0.runner.identity })
        let terminalIdentities = Set(terminalDestinations.compactMap { destination -> ImportedIdentifierEvidence? in
            switch destination {
            case let .score(runner, _, _), let .out(runner, _, _):
                return runner.identity
            case .advance:
                return nil
            }
        })
        return input.contains { expectedIdentities.contains($0.runner.identity) == false && terminalIdentities.contains($0.runner.identity) == false }
            ? [finding("baseRunnerTransition.runnerDisappeared", .contradiction, .contradictory, "A runner disappeared without scored or out evidence.")]
            : []
    }

    private static func validateRunnerIdentities(_ runners: [RunnerIdentityEvidence], codePrefix: String) -> [CanonicalValidationFinding] {
        runners.flatMap { runner -> [CanonicalValidationFinding] in
            switch runner.identity {
            case .valid:
                return []
            case .missing:
                return [finding("\(codePrefix).missingRunnerIdentity", .unresolved, .unresolved, "Runner identity is missing.")]
            case .invalid:
                return [finding("\(codePrefix).invalidRunnerIdentity", .rejection, .rejected, "Runner identity is invalid.")]
            }
        }
    }

    private static func activeOccupants(_ occupancy: CanonicalBaseOccupancy) -> [(base: Base, runner: RunnerIdentityEvidence)] {
        occupancy.runnerStates.compactMap {
            if case let .activeOccupant(base, runner) = $0 { return (base, runner) }
            return nil
        }
    }

    private static func finding(_ code: String, _ severity: CanonicalValidationSeverity, _ disposition: CanonicalValidationDisposition, _ summary: String) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(code, concept: .baseOccupancy, severity: severity, disposition: disposition, summary: summary)
    }
}

import Foundation

enum CanonicalParticipantOutEvidence: Hashable, Sendable {
    case batter(LineupParticipantEvidence?)
    case runner(RunnerIdentityEvidence, sourceBase: Base, outAt: Base)
    case unknown(sourceBase: Base?)
}

struct CanonicalOutTransitionRequest: Hashable, Sendable {
    let inputOuts: CanonicalOutsState
    let outsToAdd: Int
    let participantOuts: [CanonicalParticipantOutEvidence]
    let explicitEndOfHalfEvidence: Bool

    init(inputOuts: CanonicalOutsState, outsToAdd: Int, participantOuts: [CanonicalParticipantOutEvidence] = [], explicitEndOfHalfEvidence: Bool = false) {
        self.inputOuts = inputOuts
        self.outsToAdd = outsToAdd
        self.participantOuts = participantOuts
        self.explicitEndOfHalfEvidence = explicitEndOfHalfEvidence
    }
}

struct CanonicalOutTransitionResult: Hashable, Sendable {
    let inputOuts: CanonicalOutsState
    let resultingOuts: CanonicalOutsState
    let validation: CanonicalValidationResult
    let thirdOutContext: Bool
    let requiresEndOfHalfTransition: Bool
    let runValidityReviewRequired: Bool
    let rejected: Bool
    let inputRemainsUnchanged: Bool
}

enum CanonicalOutTransition {
    static func apply(_ request: CanonicalOutTransitionRequest) -> CanonicalOutTransitionResult {
        var findings: [CanonicalValidationFinding] = []
        let currentOuts = request.inputOuts.outs.outValue

        if request.outsToAdd < 0 {
            findings.append(finding("outTransition.negativeOutChange", .rejection, .rejected, "Out transition cannot add a negative number of outs."))
        }
        if currentOuts == nil {
            findings.append(finding("outTransition.missingCurrentOuts", .incomplete, .incomplete, "Current outs are missing and cannot be transitioned."))
        }
        if let currentOuts, currentOuts < 0 {
            findings.append(finding("outTransition.invalidCurrentOuts", .rejection, .rejected, "Current outs are negative."))
        }
        if let currentOuts, currentOuts > 3 {
            findings.append(finding("outTransition.currentOutsBeyondThird", .rejection, .rejected, "Current outs already exceed the third out."))
        }
        if request.outsToAdd > 3 {
            findings.append(finding("outTransition.tooManyRequestedOuts", .rejection, .rejected, "One event cannot request more than three outs in this foundation."))
        }
        if request.participantOuts.count > request.outsToAdd {
            findings.append(finding("outTransition.participantOutsExceedAggregate", .contradiction, .contradictory, "Participant-out evidence exceeds the aggregate out change."))
        }
        findings += participantFindings(request.participantOuts)
        if let currentOuts, currentOuts + request.outsToAdd > 3 {
            findings.append(finding("outTransition.fourthOutResult", .rejection, .rejected, "Out transition would produce a fourth-or-greater out state."))
        }

        let validation = CanonicalValidationResult(findings: findings)
        let rejected = validation.futureWriteMustStop
        let projected = (currentOuts ?? 0) + request.outsToAdd
        let thirdOut = projected == 3
        let runnerOutEvidence = request.participantOuts.map { evidence -> RunnerOutEvidence in
            switch evidence {
            case let .runner(runner, _, outAt):
                return .runnerOut(runner, base: outAt)
            case .batter:
                return .batterRunnerOut(base: .first)
            case let .unknown(sourceBase):
                return .unknownRunnerOut(base: sourceBase)
            }
        }
        let resulting = rejected ? request.inputOuts : CanonicalOutsState(
            outs: .known(projected),
            outsRecordedByEvent: request.outsToAdd == 0 ? nil : request.outsToAdd,
            runnerOutEvidence: runnerOutEvidence,
            endOfHalfEvidence: request.explicitEndOfHalfEvidence,
            thirdOutContext: thirdOut,
            source: request.inputOuts.source
        )

        return CanonicalOutTransitionResult(
            inputOuts: request.inputOuts,
            resultingOuts: resulting,
            validation: validation,
            thirdOutContext: thirdOut && rejected == false,
            requiresEndOfHalfTransition: thirdOut && request.explicitEndOfHalfEvidence == false && rejected == false,
            runValidityReviewRequired: thirdOut && runnerOutEvidence.isEmpty == false && rejected == false,
            rejected: rejected,
            inputRemainsUnchanged: true
        )
    }

    private static func participantFindings(_ participantOuts: [CanonicalParticipantOutEvidence]) -> [CanonicalValidationFinding] {
        var findings: [CanonicalValidationFinding] = []
        var seen: Set<ImportedIdentifierEvidence> = []

        for out in participantOuts {
            switch out {
            case let .runner(runner, _, _):
                switch runner.identity {
                case .valid:
                    if seen.contains(runner.identity) {
                        findings.append(finding("outTransition.duplicateParticipantOut", .contradiction, .contradictory, "The same participant is recorded out more than once."))
                    }
                    seen.insert(runner.identity)
                case .missing:
                    findings.append(finding("outTransition.missingParticipantIdentity", .unresolved, .unresolved, "Runner-out evidence is missing participant identity."))
                case .invalid:
                    findings.append(finding("outTransition.invalidParticipantIdentity", .rejection, .rejected, "Runner-out evidence has invalid participant identity."))
                }
            case .batter:
                break
            case .unknown:
                findings.append(finding("outTransition.unknownParticipantOut", .unresolved, .unresolved, "Participant-out evidence is unknown."))
            }
        }
        return findings
    }

    private static func finding(_ code: String, _ severity: CanonicalValidationSeverity, _ disposition: CanonicalValidationDisposition, _ summary: String) -> CanonicalValidationFinding {
        CanonicalDomainValidator.finding(code, concept: .outs, severity: severity, disposition: disposition, summary: summary)
    }
}

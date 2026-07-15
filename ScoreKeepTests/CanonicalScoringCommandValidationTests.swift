import Testing
@testable import ScoreKeep

struct CanonicalScoringCommandValidationTests {
    @Test func validCommandAndWarningOnlyMissingPitcherAreDistinct() {
        let command = singleCommand()
        let accepted = CanonicalScoringCommandValidator.validate(command, against: ScoringCommandTestSupport.state())
        let warning = CanonicalScoringCommandValidator.validate(command, against: ScoringCommandTestSupport.state(pitcher: nil))

        #expect(accepted.result.disposition == .valid)
        #expect(accepted.mayApplyInMemory)
        #expect(warning.result.disposition == .validWithWarnings)
        #expect(warning.mayApplyInMemory)
        #expect(warning.result.findings.contains { $0.code == "scoringCommand.pitcherMissing" })
    }

    @Test func missingGameBatterInningInvalidOutsAndThirdOutContextsRejectOrHoldIncomplete() {
        let command = singleCommand()
        let missingGameCommand = CanonicalScoringCommand(intent: command.intent, gameIdentity: .missing, teamSide: command.teamSide, batter: command.batter)
        #expect(CanonicalScoringCommandValidator.validate(missingGameCommand, against: ScoringCommandTestSupport.state(game: CanonicalGameStatePrimitivesTestSupport.game(id: nil, lifecycle: .inProgress))).result.disposition == .incomplete)
        #expect(CanonicalScoringCommandValidator.validate(CanonicalScoringCommand(intent: command.intent, gameIdentity: command.gameIdentity, teamSide: command.teamSide), against: ScoringCommandTestSupport.state(batter: nil, lineup: [])).result.disposition == .incomplete)
        #expect(CanonicalScoringCommandValidator.validate(command, against: ScoringCommandTestSupport.state(inning: CanonicalHalfInning(number: .invalid(-1), half: .known(.top), expectedInnings: .known(7)))).result.disposition == .rejected)
        #expect(CanonicalScoringCommandValidator.validate(command, against: ScoringCommandTestSupport.state(outs: -1)).result.disposition == .rejected)
        #expect(CanonicalScoringCommandValidator.validate(command, against: ScoringCommandTestSupport.state(outs: 3)).result.disposition == .rejected)
    }

    @Test func gameLifecycleSideAndBatterConflictsAreRejectedOrContradictory() {
        let command = singleCommand()
        let completed = ScoringCommandTestSupport.state(game: CanonicalGameStatePrimitivesTestSupport.game(lifecycle: .completed))
        let sideConflict = ScoringCommandTestSupport.state(side: .home, batter: ScoringCommandTestSupport.batter(side: .home), lineup: [ScoringCommandTestSupport.batter(side: .home)])
        let wrongSideBatter = CanonicalScoringCommand(intent: command.intent, gameIdentity: command.gameIdentity, teamSide: .visiting, batter: ScoringCommandTestSupport.batter(side: .home))
        let outOfLineup = CanonicalScoringCommand(intent: command.intent, gameIdentity: command.gameIdentity, teamSide: .visiting, batter: ScoringCommandTestSupport.batter(id: StableIdentityAndOrderingTestSupport.fixedUUID("95000000-0000-0000-0000-000000000001")))

        #expect(CanonicalScoringCommandValidator.validate(command, against: completed).result.disposition == .rejected)
        #expect(CanonicalScoringCommandValidator.validate(command, against: sideConflict).result.disposition == .contradictory)
        #expect(CanonicalScoringCommandValidator.validate(wrongSideBatter, against: ScoringCommandTestSupport.state()).result.disposition == .contradictory)
        #expect(CanonicalScoringCommandValidator.validate(outOfLineup, against: ScoringCommandTestSupport.state()).result.disposition == .rejected)
    }

    @Test func fourthOutUnsupportedAndContradictoryCommandsStopApplication() {
        let fourthOut = CanonicalScoringCommand(intent: .batterOut(result: .batterOut(rawValue: "Ground Out")), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, batter: ScoringCommandTestSupport.batter(), outsRequested: 1)
        let unsupported = CanonicalScoringCommandVocabulary.command(rawResult: "Moon Shot", gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, batter: ScoringCommandTestSupport.batter())
        let contradictory = CanonicalScoringCommand(intent: .batterReaches(destination: .home, result: .batterReachesBase(rawValue: "Single")), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, batter: ScoringCommandTestSupport.batter())

        #expect(CanonicalScoringCommandValidator.validate(fourthOut, against: ScoringCommandTestSupport.state(outs: 2)).result.disposition == .rejected)
        #expect(CanonicalScoringCommandValidator.validate(unsupported, against: ScoringCommandTestSupport.state()).result.disposition == .unsupported)
        #expect(CanonicalScoringCommandValidator.validate(contradictory, against: ScoringCommandTestSupport.state()).result.disposition == .contradictory)
    }

    @Test func runnerMissingDuplicateOccupiedAndImpossibleDestinationsAreClassified() {
        let occupancy = ScoringCommandTestSupport.occupancy([
            .activeOccupant(base: .first, runner: ScoringCommandTestSupport.runnerA),
            .activeOccupant(base: .second, runner: ScoringCommandTestSupport.runnerB)
        ])
        let duplicate = CanonicalScoringCommand(intent: .runnerAdvances(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .second, stolenBase: false), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, runnerDestinations: [
            .advance(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .second),
            .score(runner: ScoringCommandTestSupport.runnerA, from: .first)
        ])
        let missing = CanonicalScoringCommand(intent: .runnerAdvances(runner: ScoringCommandTestSupport.runnerA, from: .third, to: .home, stolenBase: false), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, runnerDestinations: [.score(runner: ScoringCommandTestSupport.runnerA, from: .third)])
        let impossible = CanonicalScoringCommand(intent: .runnerAdvances(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .first, stolenBase: false), gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, runnerDestinations: [.advance(runner: ScoringCommandTestSupport.runnerA, from: .first, to: .first)])

        #expect(CanonicalScoringCommandValidator.validate(duplicate, against: ScoringCommandTestSupport.state(occupancy: occupancy)).result.disposition == .contradictory)
        #expect(CanonicalScoringCommandValidator.validate(missing, against: ScoringCommandTestSupport.state(occupancy: occupancy)).result.disposition == .rejected)
        #expect(CanonicalScoringCommandValidator.validate(impossible, against: ScoringCommandTestSupport.state(occupancy: occupancy)).result.disposition == .contradictory)
    }

    @Test func rejectedValidationLeavesInputUnchangedAndIsDeterministic() {
        let input = ScoringCommandTestSupport.state(outs: 3)
        let command = singleCommand()
        let first = CanonicalScoringCommandValidator.validate(command, against: input)
        let second = CanonicalScoringCommandValidator.validate(command, against: input)

        #expect(first == second)
        #expect(first.inputState == input)
        #expect(first.inputStateRemainsUnchanged)
    }

    @Test func fixtureEvidenceConfirmsRepresentativeAndMalformedInputs() throws {
        let completed = try CanonicalGameStatePrimitivesTestSupport.fixture("CompletedGame.ScoreKeep_Games")
        let multiple = try CanonicalGameStatePrimitivesTestSupport.fixture("MultipleAtbats.ScoreKeep_Games")
        let broken = try CanonicalGameStatePrimitivesTestSupport.fixture("BrokenAtbatRelationship.ScoreKeep_Games", directory: "MalformedAndUnsupported")
        let duplicate = try CanonicalGameStatePrimitivesTestSupport.fixture("DuplicateAtbatID.ScoreKeep_Games", directory: "MalformedAndUnsupported")
        let inProgress = try CanonicalGameStatePrimitivesTestSupport.fixture("InProgressGame.ScoreKeep_Games")

        #expect(completed.atbats.isEmpty == false)
        #expect(multiple.atbats.contains { $0.maxbase == "Home" || $0.outAt != "Safe" })
        #expect(broken.atbats.contains { $0.team.name == "Fixture Third Team" })
        #expect(duplicate.atbats.map(\.id).count != Set(duplicate.atbats.map(\.id)).count)
        #expect(inProgress.atbats.isEmpty == false)
    }

    private func singleCommand() -> CanonicalScoringCommand {
        CanonicalScoringCommandVocabulary.command(rawResult: "Single", gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA), teamSide: .visiting, batter: ScoringCommandTestSupport.batter())
    }
}

import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalDomainValidationTests {
    @Test func validationVocabularyCoversAllRequiredDispositionsDeterministically() {
        let validTeam = CanonicalTeamMeaningTestSupport.team()
        let warningTeam = ReusableCanonicalTeam(identity: .valid(StableIdentityAndOrderingTestSupport.teamA), display: TeamDisplayEvidence(logo: .invalid("not-image")))
        let incompleteIdentity = StableIdentityEvidence(concept: .player, importedIdentifier: .missing)
        let repairRequiredOrder = [
            OrderEvidence(kind: .eventSequence, value: 1),
            OrderEvidence(kind: .eventSequence, value: 1)
        ]
        let unsupportedCount = BallStrikeCountEvidence.unsupportedRepositoryEvidence
        let rejectedIdentity = StableIdentityEvidence(concept: .team, importedIdentifier: .invalid("not-a-uuid"))
        let sameSide = CanonicalTeamMeaningTestSupport.side(role: .home, team: validTeam)
        let unresolvedBases = CanonicalBaseOccupancy(runnerStates: [.ambiguousLegacyMaxBase("??")])
        let repairRecommendedSubstitution = CanonicalSubstitutionEvidence(
            gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA),
            incoming: .participant(.reusablePlayer(CanonicalPlayerMeaningTestSupport.player())),
            outgoing: .missing,
            legacyArrayEvidence: .unequalCounts(incoming: 1, outgoing: 0)
        )

        let results = [
            CanonicalDomainValidator.validateTeam(validTeam),
            CanonicalDomainValidator.validateTeam(warningTeam),
            CanonicalDomainValidator.validateIdentity(incompleteIdentity),
            CanonicalDomainValidator.validateOrdering(repairRequiredOrder, expectedKind: .eventSequence),
            CanonicalDomainValidator.validateCount(unsupportedCount),
            CanonicalDomainValidator.validateIdentity(rejectedIdentity),
            CanonicalDomainValidator.validateGameSides(home: sameSide, visiting: GameSideTeamParticipation(gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), role: .visiting, resolution: .reusableTeam(validTeam))),
            CanonicalDomainValidator.validateBaseOccupancy(unresolvedBases),
            CanonicalDomainValidator.validateSubstitution(repairRecommendedSubstitution)
        ]
        let dispositions = Set(results.map(\.disposition))

        #expect(dispositions.contains(.valid))
        #expect(dispositions.contains(.validWithWarnings))
        #expect(dispositions.contains(.incomplete))
        #expect(dispositions.contains(.repairRequired))
        #expect(dispositions.contains(.unsupported))
        #expect(dispositions.contains(.rejected))
        #expect(dispositions.contains(.contradictory))
        #expect(dispositions.contains(.unresolved))
        #expect(dispositions.contains(.repairRecommended))
        #expect(results == [
            CanonicalDomainValidator.validateTeam(validTeam),
            CanonicalDomainValidator.validateTeam(warningTeam),
            CanonicalDomainValidator.validateIdentity(incompleteIdentity),
            CanonicalDomainValidator.validateOrdering(repairRequiredOrder, expectedKind: .eventSequence),
            CanonicalDomainValidator.validateCount(unsupportedCount),
            CanonicalDomainValidator.validateIdentity(rejectedIdentity),
            CanonicalDomainValidator.validateGameSides(home: sameSide, visiting: GameSideTeamParticipation(gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), role: .visiting, resolution: .reusableTeam(validTeam))),
            CanonicalDomainValidator.validateBaseOccupancy(unresolvedBases),
            CanonicalDomainValidator.validateSubstitution(repairRecommendedSubstitution)
        ])
    }

    @Test func identityAndRelationshipValidationDistinguishesMissingInvalidDuplicateAndHistoricalDisplayEvidence() {
        let teamA = CanonicalTeamMeaningTestSupport.team(id: StableIdentityAndOrderingTestSupport.teamA, display: CanonicalTeamMeaningTestSupport.display(name: .present("Same")))
        let teamB = CanonicalTeamMeaningTestSupport.team(id: StableIdentityAndOrderingTestSupport.teamB, display: CanonicalTeamMeaningTestSupport.display(name: .present("Same")))
        let conflictA = StableIdentityEvidence(concept: .team, importedIdentifier: .valid(StableIdentityAndOrderingTestSupport.teamA), displayEvidence: [.init("name", "Old")])
        let conflictB = StableIdentityEvidence(concept: .team, importedIdentifier: .valid(StableIdentityAndOrderingTestSupport.teamA), displayEvidence: [.init("name", "New")])
        let matchingDuplicate = CanonicalDomainValidator.validateDuplicateIdentities([teamA.stableIdentityEvidence, teamA.stableIdentityEvidence])
        let conflictingDuplicate = CanonicalDomainValidator.validateDuplicateIdentities([conflictA, conflictB])
        let distinctSameName = CanonicalDomainValidator.validateDuplicateIdentities([teamA.stableIdentityEvidence, teamB.stableIdentityEvidence])
        let missing = CanonicalDomainValidator.validateIdentity(StableIdentityEvidence(concept: .player, importedIdentifier: .missing))
        let invalid = CanonicalDomainValidator.validateIdentity(StableIdentityEvidence(concept: .player, importedIdentifier: .invalid("bad")))
        let historicalPlayer = ReusableCanonicalPlayer(identity: .valid(StableIdentityAndOrderingTestSupport.playerA), rosterEvidence: .removedFromCurrentRoster)

        #expect(missing.disposition == .incomplete)
        #expect(invalid.disposition == .rejected)
        #expect(matchingDuplicate.disposition == .validWithWarnings)
        #expect(conflictingDuplicate.disposition == .contradictory)
        #expect(distinctSameName.disposition == .valid)
        #expect(CanonicalDomainValidator.validatePlayer(historicalPlayer).disposition == .validWithWarnings)
    }

    @Test func rosterAndLineupValidationClassifiesConflictsWithoutMergingOrRepairing() {
        let teamA = CanonicalTeamMeaningTestSupport.team(id: StableIdentityAndOrderingTestSupport.teamA)
        let teamB = CanonicalTeamMeaningTestSupport.team(id: StableIdentityAndOrderingTestSupport.teamB)
        let player = CanonicalPlayerMeaningTestSupport.player(id: StableIdentityAndOrderingTestSupport.playerA)
        let membershipA = CurrentRosterMembership(teamEvidence: .reusableTeam(teamA), playerEvidence: .reusablePlayer(player))
        let membershipB = CurrentRosterMembership(teamEvidence: .reusableTeam(teamB), playerEvidence: .reusablePlayer(player))
        let rosterResult = CanonicalDomainValidator.validateRoster([membershipA, membershipB])
        let emptyRoster = CanonicalDomainValidator.validateRoster([])
        let validLineup = CanonicalLineupMeaningTestSupport.lineup(entries: [CanonicalLineupMeaningTestSupport.entry(player: player, slot: .known(1))])
        let emptyLineup = CanonicalLineupMeaningTestSupport.lineup(entries: [])
        let duplicateSlotLineup = CanonicalLineupMeaningTestSupport.lineup(entries: [
            CanonicalLineupMeaningTestSupport.entry(player: player, slot: .known(1)),
            CanonicalLineupMeaningTestSupport.entry(player: CanonicalPlayerMeaningTestSupport.player(id: StableIdentityAndOrderingTestSupport.playerB), slot: .known(1))
        ])
        let unknownModeLineup = CanonicalGameLineup(gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), sideEvidence: .home, mode: .unknown, entries: [CanonicalLineupMeaningTestSupport.entry(player: player, slot: .known(1))])
        let historicalLineup = CanonicalLineupMeaningTestSupport.lineup(entries: [LineupEntryEvidence(participant: .absentFromCurrentRoster(player), battingSlot: .known(1))])

        #expect(CanonicalDomainValidator.validateRosterMembership(membershipA).disposition == .valid)
        #expect(rosterResult.disposition == .contradictory)
        #expect(emptyRoster.disposition == .validWithWarnings)
        #expect(CanonicalDomainValidator.validateLineup(validLineup).disposition == .valid)
        #expect(CanonicalDomainValidator.validateLineup(emptyLineup).disposition == .incomplete)
        #expect(CanonicalDomainValidator.validateLineup(duplicateSlotLineup).disposition == .contradictory)
        #expect(CanonicalDomainValidator.validateLineup(unknownModeLineup).disposition == .incomplete)
        #expect(CanonicalDomainValidator.validateLineup(historicalLineup).processingMayContinueReadOnly)
    }

    @Test func gameStateAndRecordedPlayValidationClassifiesBoundaries() {
        let game = CanonicalGameIdentity(identity: .valid(StableIdentityAndOrderingTestSupport.gameA), configuration: .configured(expectedInnings: .known(7), lineupMode: .traditional))
        let doubleheaderA = CanonicalGameIdentity(identity: .valid(StableIdentityAndOrderingTestSupport.gameA), displayEvidence: GameDisplayEvidence(date: "2026-07-15", homeTeamName: "A", visitingTeamName: "B", doubleheaderDesignator: "1"))
        let doubleheaderB = CanonicalGameIdentity(identity: .valid(StableIdentityAndOrderingTestSupport.gameB), displayEvidence: GameDisplayEvidence(date: "2026-07-15", homeTeamName: "A", visitingTeamName: "B", doubleheaderDesignator: "2"))
        let invalidInning = CanonicalHalfInning(number: .invalid(0), half: .known(.top))
        let bottom = CanonicalHalfInning(number: .known(1), half: .known(.bottom), expectedInnings: .known(7))
        let invalidOuts = CanonicalOutsState(outs: .known(4))
        let thirdOut = CanonicalOutsState(outs: .known(3), thirdOutContext: true)
        let runner = RunnerIdentityEvidence.reusablePlayer(CanonicalPlayerMeaningTestSupport.player())
        let validBases = CanonicalBaseOccupancy(runnerStates: [.activeOccupant(base: .first, runner: runner)])
        let sameRunnerTwoBases = CanonicalBaseOccupancy(runnerStates: [.activeOccupant(base: .first, runner: runner), .activeOccupant(base: .second, runner: runner)])
        let unsupportedBases = CanonicalBaseOccupancy(runnerStates: [.unsupportedLegacyValue(field: "maxbase", value: "Moon")])
        let validEvent = event(batter: .reusablePlayer(CanonicalPlayerMeaningTestSupport.player()))
        let missingBatter = event(batter: nil)
        let unsupportedEvent = event(batter: .reusablePlayer(CanonicalPlayerMeaningTestSupport.player()), result: .unsupportedRawResult("Balkish"))

        #expect(CanonicalDomainValidator.validateGame(game).disposition == .valid)
        #expect(CanonicalGameMeaningClassifier.classifyGameSet([doubleheaderA, doubleheaderB]).contains(.doubleheaderDistinctGames))
        #expect(CanonicalDomainValidator.validateInning(invalidInning).disposition == .rejected)
        #expect(CanonicalDomainValidator.validateInning(bottom).disposition == .valid)
        #expect(CanonicalDomainValidator.validateOuts(invalidOuts).disposition == .rejected)
        #expect(CanonicalDomainValidator.validateOuts(thirdOut).disposition == .validWithWarnings)
        #expect(CanonicalDomainValidator.validateCount(.unsupportedRepositoryEvidence).containsUnsupportedEvidence)
        #expect(CanonicalDomainValidator.validateBaseOccupancy(validBases).disposition == .valid)
        #expect(CanonicalDomainValidator.validateBaseOccupancy(sameRunnerTwoBases).disposition == .contradictory)
        #expect(CanonicalDomainValidator.validateBaseOccupancy(unsupportedBases).disposition == .unsupported)
        #expect(CanonicalDomainValidator.validateScoringEvent(validEvent).disposition == .valid)
        #expect(CanonicalDomainValidator.validateScoringEvent(missingBatter).disposition == .incomplete)
        #expect(CanonicalDomainValidator.validateScoringEvent(unsupportedEvent).disposition == .unsupported)
    }

    private func event(
        batter: LineupParticipantEvidence?,
        result: ScoringEventResultEvidence = .batterReachesBase(rawValue: "Single")
    ) -> CanonicalScoringEventEvidence {
        CanonicalScoringEventEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.eventA),
            gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA),
            orderingEvidence: [.knownSequence(OrderEvidence(kind: .eventSequence, value: 1))],
            participants: ScoringEventParticipantEvidence(batter: batter),
            resultEvidence: result,
            source: .syntheticVerification
        )
    }

    @Test func pitcherAndSubstitutionValidationPreservesAmbiguityForRepairBoundaries() {
        let pitcher = CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("50000000-0000-0000-0000-000000000001")),
            reusablePitcherIdentity: .valid(StableIdentityAndOrderingTestSupport.playerA),
            gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA),
            teamSide: .home,
            appearanceOrder: OrderEvidence(kind: .pitcherAppearance, value: 0),
            roleEvidence: [.startingPitcher]
        )
        let missingPitcher = CanonicalPitcherResponsibilityEvidence(eventIdentity: .valid(StableIdentityAndOrderingTestSupport.eventA), gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), responsibility: .missingPitcherRelationship, runResponsibilityEvidence: .count(1))
        let conflictingPitcher = CanonicalPitcherResponsibilityEvidence(eventIdentity: .valid(StableIdentityAndOrderingTestSupport.eventA), gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), teamSide: .visiting, responsibility: .explicitPitcher(pitcher))
        let player = CanonicalPlayerMeaningTestSupport.player()
        let participant = SubstitutionParticipantEvidence.participant(.reusablePlayer(player))
        let validSubstitution = CanonicalSubstitutionEvidence(gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), incoming: participant, outgoing: .participant(.reusablePlayer(CanonicalPlayerMeaningTestSupport.player(id: StableIdentityAndOrderingTestSupport.playerB))), effectiveOrder: OrderEvidence(kind: .substitution, value: 1), roleEvidence: [.batterReplacement])
        let unequalArrays = CanonicalSubstitutionEvidence(gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), incoming: participant, outgoing: .missing, legacyArrayEvidence: .unequalCounts(incoming: 1, outgoing: 0))
        let sameIncomingOutgoing = CanonicalSubstitutionEvidence(gameIdentity: .valid(StableIdentityAndOrderingTestSupport.gameA), incoming: participant, outgoing: participant)

        #expect(CanonicalDomainValidator.validatePitcherAppearance(pitcher).disposition == .valid)
        #expect(CanonicalDomainValidator.validatePitcherResponsibility(missingPitcher).disposition == .incomplete)
        #expect(CanonicalDomainValidator.validatePitcherResponsibility(conflictingPitcher).disposition == .contradictory)
        #expect(CanonicalDomainValidator.validateSubstitution(validSubstitution).disposition == .valid)
        #expect(CanonicalDomainValidator.validateSubstitution(unequalArrays).disposition == .repairRecommended)
        #expect(CanonicalDomainValidator.validateSubstitution(sameIncomingOutgoing).disposition == .contradictory)
    }
}

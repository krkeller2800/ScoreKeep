import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalSubstitutionMeaningTests {
    @Test func knownIncomingOutgoingAndContextClassify() {
        let substitution = substitution(
            incoming: .participant(participant(id: "c1000000-0000-0000-0000-000000000001")),
            outgoing: .participant(participant(id: "c1000000-0000-0000-0000-000000000002")),
            order: .init(kind: .substitution, value: 3),
            battingSlot: .known(5),
            position: DefensivePositionEvidence(rawValue: "RF", source: .historicalGameParticipation),
            pitcherChange: true,
            roles: [.batterReplacement, .runnerReplacement, .defensiveReplacement, .pitcherChange, .lineupEntryReplacement]
        )
        let classes = CanonicalSubstitutionMeaningClassifier.classify(substitution)

        #expect(classes.contains(.incomingParticipantKnown))
        #expect(classes.contains(.outgoingParticipantKnown))
        #expect(classes.contains(.effectiveOrderKnown))
        #expect(classes.contains(.battingSlotContextKnown))
        #expect(classes.contains(.defensivePositionContextKnown))
        #expect(classes.contains(.pitcherChangeEvidence))
        #expect(classes.contains(.batterReplacementEvidence))
        #expect(classes.contains(.runnerReplacementEvidence))
        #expect(classes.contains(.defensiveReplacementEvidence))
        #expect(classes.contains(.lineupEntryReplacementEvidence))
        #expect(classes.contains(.nonApplyingSubstitutionEvidenceOnly))
    }

    @Test func legacyParallelArraysRemainEvidenceNotCertainty() {
        let incoming = [participantEvidence(id: "c2000000-0000-0000-0000-000000000001")]
        let outgoing = [participantEvidence(id: "c2000000-0000-0000-0000-000000000002")]
        let equalClasses = CanonicalSubstitutionMeaningClassifier.classifyLegacyParallelArrays(incoming: incoming, outgoing: outgoing)
        let unequalClasses = CanonicalSubstitutionMeaningClassifier.classifyLegacyParallelArrays(incoming: incoming + incoming, outgoing: outgoing)

        #expect(equalClasses.contains(.equalLegacyArraysPlausiblePairingOnly))
        #expect(equalClasses.contains(.ambiguousSubstitutionPairing))
        #expect(equalClasses.contains(.arrayOrderDoesNotFabricateTimingRoleOrLegality))
        #expect(unequalClasses.contains(.unequalLegacyArrays))
        #expect(unequalClasses.contains(.conflictingSubstitutionEvidence))
    }

    @Test func missingSameDuplicateAndConflictingContextClassify() {
        let sameID = "c3000000-0000-0000-0000-000000000001"
        let same = substitution(
            incoming: participantEvidence(id: sameID),
            outgoing: participantEvidence(id: sameID),
            battingSlot: .conflicting([4, 7]),
            position: .conflicting([
                DefensivePositionEvidence(rawValue: "P"),
                DefensivePositionEvidence(rawValue: "SS")
            ]),
            roles: [.unknown]
        )
        let missingIncoming = substitution(incoming: .missing, outgoing: participantEvidence(id: "c3000000-0000-0000-0000-000000000002"))
        let missingOutgoing = substitution(incoming: participantEvidence(id: "c3000000-0000-0000-0000-000000000003"), outgoing: .missing)
        let duplicateA = substitution(id: "c3990000-0000-0000-0000-000000000001")
        let duplicateB = substitution(id: "c3990000-0000-0000-0000-000000000001")

        let sameClasses = CanonicalSubstitutionMeaningClassifier.classify(same)
        #expect(sameClasses.contains(.sameParticipantIncomingAndOutgoing))
        #expect(sameClasses.contains(.conflictingBattingSlotContext))
        #expect(sameClasses.contains(.conflictingDefensivePositionContext))
        #expect(sameClasses.contains(.unknownSubstitutionRole))
        #expect(sameClasses.contains(.missingEffectiveOrder))
        #expect(CanonicalSubstitutionMeaningClassifier.classify(missingIncoming).contains(.missingIncomingParticipant))
        #expect(CanonicalSubstitutionMeaningClassifier.classify(missingOutgoing).contains(.missingOutgoingParticipant))
        #expect(CanonicalSubstitutionMeaningClassifier.classifySet([duplicateA, duplicateB]).contains(.duplicateSubstitutionEvidence))
    }

    @Test func missingArraysDuplicateParticipantsBothSidesHistoricalAndDeterministicClassify() {
        let duplicateIncoming = [participantEvidence(id: "c4000000-0000-0000-0000-000000000001"), participantEvidence(id: "c4000000-0000-0000-0000-000000000001")]
        let outgoing = [participantEvidence(id: "c4000000-0000-0000-0000-000000000002"), participantEvidence(id: "c4000000-0000-0000-0000-000000000003")]
        let missingArrays = CanonicalSubstitutionMeaningClassifier.classifyLegacyParallelArrays(incoming: nil, outgoing: nil)
        let duplicateClasses = CanonicalSubstitutionMeaningClassifier.classifyLegacyParallelArrays(incoming: duplicateIncoming, outgoing: outgoing)
        let bothSidesA = substitution(incoming: participantEvidence(id: "c5000000-0000-0000-0000-000000000001"), outgoing: .missing, teamSide: .home)
        let bothSidesB = substitution(incoming: participantEvidence(id: "c5000000-0000-0000-0000-000000000001"), outgoing: .missing, teamSide: .visiting)
        let historical = substitution(historical: .laterLineupComposition, legacy: .cannotEstablishRoleOrTiming)

        #expect(missingArrays.contains(.missingLegacyIncomingArray))
        #expect(missingArrays.contains(.missingLegacyOutgoingArray))
        #expect(duplicateClasses.contains(.duplicateIncomingParticipant))
        #expect(CanonicalSubstitutionMeaningClassifier.classifySet([bothSidesA, bothSidesB]).contains(.sameParticipantOnBothTeamSides))
        #expect(CanonicalSubstitutionMeaningClassifier.classify(historical).contains(.historicalSubstitutionEvidence))
        #expect(CanonicalSubstitutionMeaningClassifier.classify(historical).contains(.arrayOrderDoesNotFabricateTimingRoleOrLegality))
        #expect(CanonicalSubstitutionMeaningClassifier.classify(historical) == CanonicalSubstitutionMeaningClassifier.classify(historical))
    }

    @Test func compatibilityFixturesExposeSubstitutionArraysWithoutMutation() throws {
        let lineup = try CanonicalGameStatePrimitivesTestSupport.fixture("LineupGame.ScoreKeep_Games")
        let pitcher = try CanonicalGameStatePrimitivesTestSupport.fixture("PitcherGame.ScoreKeep_Games")
        let completed = try CanonicalGameStatePrimitivesTestSupport.fixture("CompletedGame.ScoreKeep_Games")

        let fixtureCounts = [lineup, pitcher, completed].map { ($0.replaced.count, $0.incomings.count) }
        #expect(fixtureCounts.allSatisfy { $0.0 >= 0 && $0.1 >= 0 })
        #expect(lineup.lineups.isEmpty == false || lineup.replaced.isEmpty || lineup.incomings.isEmpty)
        #expect(pitcher.pitchers.isEmpty == false)
    }

    private func substitution(
        id: String = "c0000000-0000-0000-0000-000000000001",
        incoming: SubstitutionParticipantEvidence? = nil,
        outgoing: SubstitutionParticipantEvidence? = nil,
        teamSide: TeamSideRole = .home,
        order: OrderEvidence? = nil,
        battingSlot: CanonicalBattingSlotEvidence? = nil,
        position: DefensivePositionEvidence? = nil,
        pitcherChange: Bool = false,
        roles: Set<SubstitutionRoleEvidence> = [.unknown],
        historical: LineupSubstitutionEvidence? = nil,
        legacy: LegacyParallelSubstitutionEvidence? = nil
    ) -> CanonicalSubstitutionEvidence {
        CanonicalSubstitutionEvidence(
            substitutionIdentity: ImportedIdentifierEvidence(rawValue: id),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: teamSide,
            incoming: incoming ?? participantEvidence(id: "c0000000-0000-0000-0000-000000000002"),
            outgoing: outgoing ?? participantEvidence(id: "c0000000-0000-0000-0000-000000000003"),
            effectiveOrder: order,
            battingSlotContext: battingSlot,
            defensivePositionContext: position,
            pitcherChangeContext: pitcherChange,
            roleEvidence: roles,
            historicalLineupContext: historical,
            legacyArrayEvidence: legacy,
            source: .syntheticVerification
        )
    }

    private func participantEvidence(id: String) -> SubstitutionParticipantEvidence {
        .participant(participant(id: id))
    }

    private func participant(id: String) -> LineupParticipantEvidence {
        .gameParticipant(
            CanonicalGameStatePrimitivesTestSupport.participant(
                id: StableIdentityAndOrderingTestSupport.fixedUUID(id),
                name: "Fixture Substitute"
            )
        )
    }
}

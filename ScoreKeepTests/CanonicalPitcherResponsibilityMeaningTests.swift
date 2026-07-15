import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalPitcherResponsibilityMeaningTests {
    @Test func startingReliefPitcherOnlyAndBatterPitcherEvidenceClassify() {
        let starting = appearance(order: 1, roles: [.startingPitcher, .pitcherOnlyParticipant])
        let relief = appearance(id: "b0000000-0000-0000-0000-000000000002", order: 2, roles: [.reliefPitcher, .batterAndPitcher])
        let classes = CanonicalPitcherResponsibilityMeaningClassifier.classifyAppearanceSet([starting, relief])

        #expect(classes.contains(.startingPitcherEvidence))
        #expect(classes.contains(.reliefPitcherEvidence))
        #expect(classes.contains(.pitcherOnlyParticipant))
        #expect(classes.contains(.batterAndPitcherParticipant))
        #expect(classes.contains(.appearanceOrderKnown))
        #expect(classes.contains(.nonCalculatingResponsibilityEvidenceOnly))
    }

    @Test func missingDuplicateOrderAndDuplicateIdentityClassify() {
        let duplicateA = appearance(id: "b0000000-0000-0000-0000-000000000003", order: 4)
        let duplicateB = appearance(id: "b0000000-0000-0000-0000-000000000003", order: 4)
        let missingOrder = appearance(id: "b0000000-0000-0000-0000-000000000004", order: nil)
        let classes = CanonicalPitcherResponsibilityMeaningClassifier.classifyAppearanceSet([duplicateA, duplicateB, missingOrder])

        #expect(classes.contains(.duplicatePitcherIdentity))
        #expect(classes.contains(.appearanceOrderDuplicated(4)))
        #expect(classes.contains(.appearanceOrderMissing))
    }

    @Test func responsibilityKnownMissingInvalidConflictingAndMarkersClassify() {
        let knownAppearance = appearance(teamSide: .home)
        let known = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("b1000000-0000-0000-0000-000000000001")),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .home,
            responsibility: .explicitPitcher(knownAppearance)
        )
        let missing = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("b1000000-0000-0000-0000-000000000002")),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            responsibility: .missingPitcherRelationship,
            runResponsibilityEvidence: .count(1),
            earnedRunResponsibilityEvidence: .flag(true)
        )
        let invalid = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("b1000000-0000-0000-0000-000000000003")),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            responsibility: .invalidPitcherIdentity(.invalid("bad-pitcher-id"))
        )
        let conflicting = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("b1000000-0000-0000-0000-000000000004")),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            responsibility: .multiplePitchers([.valid(StableIdentityAndOrderingTestSupport.fixedUUID("b2000000-0000-0000-0000-000000000001")), .valid(StableIdentityAndOrderingTestSupport.fixedUUID("b2000000-0000-0000-0000-000000000002"))])
        )

        #expect(CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(known).contains(.eventReferencesKnownPitcher))
        #expect(CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(missing).contains(.missingPitcherRelationship))
        #expect(CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(missing).contains(.runMarkerWithoutResolvablePitcher))
        #expect(CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(missing).contains(.earnedRunMarkerWithoutResolvablePitcher))
        #expect(CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(invalid).contains(.invalidPitcherIdentity))
        #expect(CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(conflicting).contains(.conflictingPitcherResponsibility))
    }

    @Test func teamSideConflictAndCurrentStateDoNotRewriteHistoricalEvidence() {
        let historical = appearance(teamSide: .home)
        let teamConflict = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("b3000000-0000-0000-0000-000000000001")),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .visiting,
            responsibility: .explicitPitcher(historical)
        )
        let currentDiffers = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("b3000000-0000-0000-0000-000000000002")),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            responsibility: .currentActivePitcherDiffers(historical: historical.reusablePitcherIdentity, current: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("b3000000-0000-0000-0000-000000000003")))
        )
        let conflictClasses = CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(teamConflict)
        let currentClasses = CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(currentDiffers)

        #expect(conflictClasses.contains(.teamSideConflict))
        #expect(currentClasses.contains(.currentPitcherStateDoesNotRewriteHistoricalResponsibility))
        #expect(currentClasses.contains(.historicalPitcherEvidence))
        #expect(currentClasses == CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(currentDiffers))
    }

    @Test func compatibilityFixturesExposePitcherEvidenceWithoutMutation() throws {
        let pitcherGame = try CanonicalGameStatePrimitivesTestSupport.fixture("PitcherGame.ScoreKeep_Games")
        let brokenPitcher = try CanonicalGameStatePrimitivesTestSupport.fixture("BrokenPitcherRelationship.ScoreKeep_Games", directory: "MalformedAndUnsupported")
        let missingOptional = try CanonicalGameStatePrimitivesTestSupport.fixture("MissingOptionalValues.ScoreKeep_Games")

        #expect(pitcherGame.pitchers.isEmpty == false)
        #expect(pitcherGame.pitchers.contains { $0.startInn >= 0 && $0.sOuts >= 0 && $0.sBats >= 0 })
        #expect(brokenPitcher.pitchers.contains { $0.player.name == "Missing Pitcher Relationship" || $0.team.name.isEmpty == false })
        #expect(missingOptional.pitchers.isEmpty || missingOptional.pitchers.allSatisfy { $0.runs >= 0 || $0.startInn <= 0 })
    }

    private func appearance(
        id: String = "b0000000-0000-0000-0000-000000000001",
        pitcherID: String = "b9000000-0000-0000-0000-000000000001",
        teamSide: TeamSideRole = .home,
        order: Int? = 1,
        roles: Set<PitcherAppearanceRoleEvidence> = [.startingPitcher]
    ) -> CanonicalPitcherAppearanceEvidence {
        CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: ImportedIdentifierEvidence(rawValue: id),
            reusablePitcherIdentity: ImportedIdentifierEvidence(rawValue: pitcherID),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: teamSide,
            appearanceOrder: order.map { OrderEvidence(kind: .pitcherAppearance, value: $0) },
            roleEvidence: roles,
            startBoundary: .known(inning: 1, outs: 0, batters: 0),
            endBoundary: .incomplete(inning: nil, outs: nil, batters: nil),
            historicalDisplayEvidence: PlayerDisplayEvidence(name: .present("Fixture Pitcher")),
            source: .syntheticVerification
        )
    }
}

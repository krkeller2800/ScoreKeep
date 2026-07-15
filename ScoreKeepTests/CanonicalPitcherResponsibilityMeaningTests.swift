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

struct CanonicalPitcherProjectionTests {
    @Test func startingPitcherResolvesAndRemainsActiveBeforeChange() {
        let starter = appearance(order: 0, role: [.startingPitcher], playerID: "61000000-0000-0000-0000-000000000001")
        let projection = CanonicalPitcherProjector.project(input(appearances: [starter]))

        #expect(projection.disposition == .resolved)
        #expect(projection.startingPitcher?.appearance.reusablePitcherIdentity == starter.reusablePitcherIdentity)
        #expect(projection.activePitcher?.appearance.reusablePitcherIdentity == starter.reusablePitcherIdentity)
        #expect(projection.reliefAppearances.isEmpty)
    }

    @Test func missingAndMultipleStartingPitcherClaimsClassify() {
        let reliefOnly = CanonicalPitcherProjector.project(input(appearances: [
            appearance(order: 1, role: [.reliefPitcher], playerID: "61000000-0000-0000-0000-000000000002")
        ]))
        let multipleStarters = CanonicalPitcherProjector.project(input(appearances: [
            appearance(order: 0, role: [.startingPitcher], playerID: "61000000-0000-0000-0000-000000000001"),
            appearance(order: 1, role: [.startingPitcher], playerID: "61000000-0000-0000-0000-000000000002")
        ]))

        #expect(reliefOnly.disposition == .resolvedWithWarnings)
        #expect(reliefOnly.startingPitcher == nil)
        #expect(multipleStarters.disposition == .ambiguous)
        #expect(multipleStarters.diagnostics.contains { $0.code == "pitcherProjection.multipleStartingPitchers" })
    }

    @Test func reliefAppearancesOrderAndActivePitcherResolve() {
        let starter = appearance(order: 0, role: [.startingPitcher], playerID: "61000000-0000-0000-0000-000000000001")
        let firstRelief = appearance(order: 1, role: [.reliefPitcher], playerID: "61000000-0000-0000-0000-000000000002")
        let activeRelief = appearance(order: 2, role: [.reliefPitcher, .activePitcher], playerID: "61000000-0000-0000-0000-000000000003")

        let projection = CanonicalPitcherProjector.project(input(appearances: [activeRelief, starter, firstRelief]))

        #expect(projection.disposition == .resolved)
        #expect(projection.appearanceOrder.map(\.appearance.reusablePitcherIdentity) == [starter, firstRelief, activeRelief].map(\.reusablePitcherIdentity))
        #expect(projection.activePitcher?.appearance.reusablePitcherIdentity == activeRelief.reusablePitcherIdentity)
        #expect(projection.reliefAppearances.count == 2)
    }

    @Test func missingDuplicateAndInvalidAppearanceOrderClassifyWithoutFabrication() {
        let starter = appearance(order: 0, role: [.startingPitcher], playerID: "61000000-0000-0000-0000-000000000001")
        let missingOrder = CanonicalPitcherProjector.project(input(appearances: [
            starter,
            appearance(order: nil, role: [.reliefPitcher], playerID: "61000000-0000-0000-0000-000000000002")
        ]))
        let duplicateOrder = CanonicalPitcherProjector.project(input(appearances: [
            starter,
            appearance(order: 1, role: [.reliefPitcher], playerID: "61000000-0000-0000-0000-000000000002"),
            appearance(order: 1, role: [.reliefPitcher], playerID: "61000000-0000-0000-0000-000000000003")
        ]))
        let invalidIdentity = CanonicalPitcherProjector.project(input(appearances: [
            appearance(order: 0, role: [.startingPitcher], pitcherIdentity: .invalid("bad-pitcher"))
        ]))

        #expect(missingOrder.disposition == .ambiguous)
        #expect(missingOrder.activePitcher == nil)
        #expect(duplicateOrder.disposition == .ambiguous)
        #expect(duplicateOrder.activePitcher == nil)
        #expect(invalidIdentity.disposition == .rejected)
    }

    @Test func explicitPitcherChangeAndUnsafeChangeEvidenceClassify() {
        let starterParticipant = participant(id: "61000000-0000-0000-0000-000000000001", name: "Starter")
        let reliefParticipant = participant(id: "61000000-0000-0000-0000-000000000002", name: "Relief")
        let starter = appearance(order: 0, role: [.startingPitcher], pitcherIdentity: starterParticipant.playerIdentity)
        let change = pitcherChange(incoming: reliefParticipant, outgoing: starterParticipant, order: 1)
        let missingIncoming = CanonicalPitcherChangeEvidence(
            CanonicalSubstitutionEvidence(
                gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
                teamSide: .home,
                incoming: .missing,
                outgoing: .participant(starterParticipant),
                effectiveOrder: OrderEvidence(kind: .substitution, value: 2),
                pitcherChangeContext: true,
                roleEvidence: [.pitcherChange],
                source: .syntheticVerification
            )
        )
        let missingOutgoing = CanonicalPitcherChangeEvidence(
            CanonicalSubstitutionEvidence(
                gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
                teamSide: .home,
                incoming: .participant(reliefParticipant),
                outgoing: .missing,
                effectiveOrder: OrderEvidence(kind: .substitution, value: 2),
                pitcherChangeContext: true,
                roleEvidence: [.pitcherChange],
                source: .syntheticVerification
            )
        )
        let sameParticipant = pitcherChange(incoming: reliefParticipant, outgoing: reliefParticipant, order: 2)

        let applied = CanonicalPitcherProjector.project(input(appearances: [starter], changes: [change]))
        let missingIncomingProjection = CanonicalPitcherProjector.project(input(appearances: [starter], changes: [missingIncoming]))
        let missingOutgoingProjection = CanonicalPitcherProjector.project(input(appearances: [starter], changes: [missingOutgoing]))
        let sameParticipantProjection = CanonicalPitcherProjector.project(input(appearances: [starter], changes: [sameParticipant]))

        #expect(applied.activePitcher?.appearance.reusablePitcherIdentity == reliefParticipant.playerIdentity)
        #expect(applied.disposition == .resolvedWithWarnings)
        #expect(missingIncomingProjection.disposition == .unresolved)
        #expect(missingOutgoingProjection.disposition == .unresolved)
        #expect(sameParticipantProjection.disposition == .contradictory)
    }

    @Test func teamSideConflictPitcherOnlyAndDualRoleRemainRepresentable() {
        let sideConflict = CanonicalPitcherProjector.project(input(appearances: [
            appearance(order: 0, role: [.startingPitcher], side: .visiting, playerID: "61000000-0000-0000-0000-000000000001")
        ]))
        let pitcherOnly = appearance(order: 0, role: [.startingPitcher, .pitcherOnlyParticipant], playerID: "61000000-0000-0000-0000-000000000002")
        let batterPitcherParticipant = participant(id: "61000000-0000-0000-0000-000000000003", name: "Two Way", roles: [.lineupParticipant, .batter, .pitcher])
        let dualRole = appearance(order: 0, role: [.startingPitcher, .batterAndPitcher], pitcherIdentity: batterPitcherParticipant.playerIdentity)

        let pitcherOnlyProjection = CanonicalPitcherProjector.project(input(appearances: [pitcherOnly]))
        let dualRoleProjection = CanonicalPitcherProjector.project(input(appearances: [dualRole]))

        #expect(sideConflict.disposition == .incomplete)
        #expect(sideConflict.diagnostics.contains { $0.code == "pitcherProjection.teamSideConflict" })
        #expect(pitcherOnlyProjection.activePitcher?.appearance.roleEvidence.contains(.pitcherOnlyParticipant) == true)
        #expect(dualRoleProjection.activePitcher?.appearance.reusablePitcherIdentity == batterPitcherParticipant.playerIdentity)
        #expect(dualRoleProjection.activePitcher?.appearance.roleEvidence.contains(.batterAndPitcher) == true)
    }

    @Test func eventResponsibilityWarningsStayHistorical() {
        let starter = appearance(order: 0, role: [.startingPitcher], playerID: "61000000-0000-0000-0000-000000000001")
        let relief = appearance(order: 1, role: [.reliefPitcher, .activePitcher], playerID: "61000000-0000-0000-0000-000000000002")
        let activeEvent = responsibility(sequence: 1, pitcher: relief)
        let priorEvent = responsibility(sequence: 2, pitcher: starter)
        let missingEvent = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("73000000-0000-0000-0000-000000000003")),
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            teamSide: .home,
            responsibility: .missingPitcherRelationship,
            source: .syntheticVerification
        )
        let invalidEvent = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("73000000-0000-0000-0000-000000000004")),
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            teamSide: .home,
            responsibility: .invalidPitcherIdentity(.invalid("bad")),
            source: .syntheticVerification
        )
        let unresolvedRun = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("73000000-0000-0000-0000-000000000005")),
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            teamSide: .home,
            responsibility: .unresolved,
            runResponsibilityEvidence: .count(1),
            earnedRunResponsibilityEvidence: .flag(true),
            source: .syntheticVerification
        )

        let projection = CanonicalPitcherProjector.project(input(appearances: [starter, relief], responsibilities: [activeEvent, priorEvent, missingEvent, invalidEvent, unresolvedRun]))

        #expect(projection.disposition == .resolvedWithWarnings)
        #expect(projection.activePitcher?.appearance.reusablePitcherIdentity == relief.reusablePitcherIdentity)
        #expect(projection.responsibilityWarnings.count == 4)
        #expect(projection.responsibilityWarnings.contains { $0.eventIdentity == priorEvent.eventIdentity })
        #expect(projection.responsibilityWarnings.contains { $0.classifications.contains(.runMarkerWithoutResolvablePitcher) })
        #expect(projection.responsibilityWarnings.contains { $0.classifications.contains(.earnedRunMarkerWithoutResolvablePitcher) })
    }

    @Test func projectionIsDeterministicImmutableAndFixtureBacked() throws {
        let fixture = try CanonicalTeamMeaningTestSupport.decodeGameFixture("PitcherGame.ScoreKeep_Games")
        let fixturePitcher = try #require(fixture.pitchers.first)
        let starter = appearance(
            order: 0,
            role: [.startingPitcher],
            pitcherIdentity: .valid(fixturePitcher.player.id)
        )
        let original = input(appearances: [starter])

        let first = CanonicalPitcherProjector.project(original)
        let second = CanonicalPitcherProjector.project(original)

        #expect(first == second)
        #expect(original.appearances == [starter])
        #expect(first.sourceEvidenceIgnored.contains("swiftDataFetchOrder"))
        #expect(first.sourceEvidenceIgnored.contains("currentDate"))
        #expect(first.futureProductionMustStop == false)
    }

    private func input(
        appearances: [CanonicalPitcherAppearanceEvidence],
        changes: [CanonicalPitcherChangeEvidence] = [],
        responsibilities: [CanonicalPitcherResponsibilityEvidence] = []
    ) -> CanonicalPitcherProjectionInput {
        CanonicalPitcherProjectionInput(
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            defensiveSide: .home,
            appearances: appearances,
            pitcherChanges: changes,
            eventResponsibilities: responsibilities,
            sourceLocation: "CanonicalPitcherProjectionTests"
        )
    }

    private func appearance(
        order: Int?,
        role: Set<PitcherAppearanceRoleEvidence>,
        side: TeamSideRole? = .home,
        playerID: String
    ) -> CanonicalPitcherAppearanceEvidence {
        appearance(order: order, role: role, side: side, pitcherIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID(playerID)))
    }

    private func appearance(
        order: Int?,
        role: Set<PitcherAppearanceRoleEvidence>,
        side: TeamSideRole? = .home,
        pitcherIdentity: ImportedIdentifierEvidence
    ) -> CanonicalPitcherAppearanceEvidence {
        CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("62000000-0000-0000-0000-0000000000\(String(format: "%02d", order ?? 99))")),
            reusablePitcherIdentity: pitcherIdentity,
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            teamSide: side,
            appearanceOrder: order.map { OrderEvidence(kind: .pitcherAppearance, value: $0) },
            roleEvidence: role,
            startBoundary: order == 0 ? .known(inning: 1, outs: 0, batters: 0) : .known(inning: 3, outs: 1, batters: 12),
            endBoundary: .notRepresented,
            source: .syntheticVerification
        )
    }

    private func participant(
        id: String,
        name: String,
        roles: Set<PlayerParticipantRole> = [.pitcher]
    ) -> LineupParticipantEvidence {
        .gameParticipant(
            CanonicalLineupMeaningTestSupport.participant(
                player: CanonicalLineupMeaningTestSupport.player(
                    id: StableIdentityAndOrderingTestSupport.fixedUUID(id),
                    name: name
                ),
                roles: roles
            )
        )
    }

    private func pitcherChange(
        incoming: LineupParticipantEvidence,
        outgoing: LineupParticipantEvidence,
        order: Int
    ) -> CanonicalPitcherChangeEvidence {
        CanonicalPitcherChangeEvidence(
            CanonicalSubstitutionEvidence(
                substitutionIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("72000000-0000-0000-0000-0000000000\(String(format: "%02d", order))")),
                gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
                teamSide: .home,
                incoming: .participant(incoming),
                outgoing: .participant(outgoing),
                effectiveOrder: OrderEvidence(kind: .substitution, value: order),
                pitcherChangeContext: true,
                roleEvidence: [.pitcherChange],
                source: .syntheticVerification
            )
        )
    }

    private func responsibility(
        sequence: Int,
        pitcher: CanonicalPitcherAppearanceEvidence
    ) -> CanonicalPitcherResponsibilityEvidence {
        CanonicalPitcherResponsibilityEvidence(
            eventIdentity: .valid(StableIdentityAndOrderingTestSupport.fixedUUID("73000000-0000-0000-0000-0000000000\(String(format: "%02d", sequence))")),
            gameIdentity: .valid(CanonicalLineupMeaningTestSupport.gameA),
            teamSide: .home,
            responsibility: .explicitPitcher(pitcher),
            source: .syntheticVerification
        )
    }
}

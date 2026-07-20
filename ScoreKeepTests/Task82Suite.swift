import Testing
@testable import ScoreKeep
import Foundation

@Suite("Task82Suite")
struct Task82Suite {
    @Test func task82PitchingStatisticsProjectionMatchesApprovedReplayFixtures() throws {
        let batter1 = ReplayTestSupport.batter(1)
        let pitcherIdentity = ImportedIdentifierEvidence.valid(UUID())
        let appearanceIdentity = ImportedIdentifierEvidence.valid(UUID())
        
        let appearance = CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: appearanceIdentity,
            reusablePitcherIdentity: pitcherIdentity,
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .home,
            appearanceOrder: OrderEvidence(kind: .pitcherAppearance, value: 1, sourceIndex: 0),
            roleEvidence: [.startingPitcher]
        )
        
        let projectedPitcher = CanonicalProjectedPitcher(
            appearance: appearance,
            appearanceOrder: 1,
            isStartingPitcher: true,
            isReliefPitcher: false
        )
        
        // Event with explicit outsRecordedByEvent = 1
        let outsEvidence = CanonicalOutsState(outs: .known(1), outsRecordedByEvent: 1, runnerOutEvidence: [], endOfHalfEvidence: false, thirdOutContext: false, source: .syntheticVerification)
        let event1 = CanonicalScoringEventEvidence(
            eventIdentity: .valid(ReplayTestSupport.eventID(1)),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            orderingEvidence: [.knownSequence(OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 0))],
            inningContext: CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(7)),
            teamSide: .visiting,
            participants: ScoringEventParticipantEvidence(batter: batter1),
            resultEvidence: .batterOut(rawValue: "Strikeout"),
            outsEvidence: outsEvidence,
            batterAdvancement: .out(runner: ReplayTestSupport.runner(1), sourceBase: nil),
            runnerAdvancement: [],
            rbiEvidence: .notRepresented,
            source: .syntheticVerification
        )
        
        let responsibility1 = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: event1.eventIdentity,
            gameIdentity: event1.gameIdentity,
            responsibility: .explicitPitcher(appearance),
            runResponsibilityEvidence: .notRepresented,
            earnedRunResponsibilityEvidence: .notRepresented
        )
        
        let events = [event1]
        let replayInput = ReplayTestSupport.input(events: events)
        let replayResult = CanonicalGameReplay.replay(replayInput)
        
        #expect(replayResult.disposition == CanonicalReplayDisposition.complete)
        
        let pitcherProjection = CanonicalPitcherProjectionResult(
            disposition: .resolved,
            activePitcher: projectedPitcher,
            startingPitcher: projectedPitcher,
            reliefAppearances: [],
            appearanceOrder: [projectedPitcher],
            responsibilityWarnings: [],
            diagnostics: [],
            validationFindings: [],
            sourceEvidenceUsed: [],
            sourceEvidenceIgnored: []
        )
        
        let projectionInput = CanonicalPitchingStatisticsProjectionInput(
            replayResult: replayResult,
            recordedEvents: events,
            pitcherProjection: pitcherProjection,
            eventResponsibilities: [responsibility1]
        )
        
        // 1 & 2. One approved appearance -> appearances == 1, exactly one explicit pitcher with 1 out delta -> outs == 1
        let projection = CanonicalPitchingStatisticsProjector.project(projectionInput)
        #expect(projection.disposition == CanonicalProjectionDisposition.resolved)
        
        let pStats = try #require(projection.pitcherStatistics[pitcherIdentity])
        #expect(pStats.appearances == 1)
        #expect(pStats.outsRecorded == 1)
        
        // 3. Repeating projection with identical input produces equal result
        let secondProjection = CanonicalPitchingStatisticsProjector.project(projectionInput)
        #expect(secondProjection == projection)
        
        // 4. Duplicate event identities produce an unsupported result and diagnostic
        let duplicateEvent = CanonicalScoringEventEvidence(
            eventIdentity: .valid(ReplayTestSupport.eventID(1)), // Duplicate!
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            orderingEvidence: [.knownSequence(OrderEvidence(kind: .eventSequence, value: 2, sourceIndex: 1))],
            inningContext: CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(7)),
            teamSide: .visiting,
            participants: ScoringEventParticipantEvidence(batter: batter1),
            resultEvidence: .batterOut(rawValue: "Strikeout"),
            outsEvidence: outsEvidence,
            batterAdvancement: .out(runner: ReplayTestSupport.runner(2), sourceBase: nil),
            runnerAdvancement: [],
            rbiEvidence: .notRepresented,
            source: .syntheticVerification
        )
        let dupEvents = [event1, duplicateEvent]
        let dupReplayInput = ReplayTestSupport.input(events: dupEvents)
        let dupReplayResult = CanonicalGameReplay.replay(dupReplayInput)
        
        let dupProjectionInput = CanonicalPitchingStatisticsProjectionInput(
            replayResult: dupReplayResult,
            recordedEvents: dupEvents,
            pitcherProjection: pitcherProjection,
            eventResponsibilities: [responsibility1]
        )
        let dupProjection = CanonicalPitchingStatisticsProjector.project(dupProjectionInput)
        #expect(dupProjection.disposition == CanonicalProjectionDisposition.unsupported)
        #expect(dupProjection.diagnostics.contains { $0.code == "pitchingProjection.duplicateEventIdentity" })
        
        // 5. Missing pitcher responsibility for an out-producing event produces warning
        let missingRespInput = CanonicalPitchingStatisticsProjectionInput(
            replayResult: replayResult,
            recordedEvents: events,
            pitcherProjection: pitcherProjection,
            eventResponsibilities: [] // Missing!
        )
        let missingProjection = CanonicalPitchingStatisticsProjector.project(missingRespInput)
        #expect(missingProjection.disposition == CanonicalProjectionDisposition.resolvedWithWarnings)
        #expect(missingProjection.diagnostics.contains { $0.code == "pitchingProjection.missingResponsibilityForOuts" })
        if let stats = missingProjection.pitcherStatistics[pitcherIdentity] {
            #expect(stats.outsRecorded == 0) // Outs are not assigned
        }
        
        // 6. Multiple pitcher responsibilities surfaced and outs not assigned
        let multipleResponsibility = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: event1.eventIdentity,
            gameIdentity: event1.gameIdentity,
            responsibility: .multiplePitchers([pitcherIdentity]),
            runResponsibilityEvidence: .notRepresented,
            earnedRunResponsibilityEvidence: .notRepresented
        )
        let multiRespInput = CanonicalPitchingStatisticsProjectionInput(
            replayResult: replayResult,
            recordedEvents: events,
            pitcherProjection: pitcherProjection,
            eventResponsibilities: [multipleResponsibility]
        )
        let multiProjection = CanonicalPitchingStatisticsProjector.project(multiRespInput)
        #expect(multiProjection.disposition == CanonicalProjectionDisposition.resolvedWithWarnings)
        #expect(multiProjection.diagnostics.contains { $0.code == "pitchingProjection.ambiguousResponsibilityForOuts" })
        if let stats = multiProjection.pitcherStatistics[pitcherIdentity] {
            #expect(stats.outsRecorded == 0) // Outs are not assigned
        }
        
        // 7. Invalid pitcher identity evidence surfaced
        let invalidPitcherIdentity = ImportedIdentifierEvidence.invalid(UUID().uuidString)
        let invalidAppearance = CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: appearanceIdentity,
            reusablePitcherIdentity: invalidPitcherIdentity,
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            teamSide: .home,
            appearanceOrder: OrderEvidence(kind: .pitcherAppearance, value: 1, sourceIndex: 0),
            roleEvidence: [.startingPitcher]
        )
        let invalidProjectedPitcher = CanonicalProjectedPitcher(
            appearance: invalidAppearance,
            appearanceOrder: 1,
            isStartingPitcher: true,
            isReliefPitcher: false
        )
        let invalidPitcherProjection = CanonicalPitcherProjectionResult(
            disposition: .resolved,
            activePitcher: invalidProjectedPitcher,
            startingPitcher: invalidProjectedPitcher,
            reliefAppearances: [],
            appearanceOrder: [invalidProjectedPitcher],
            responsibilityWarnings: [],
            diagnostics: [],
            validationFindings: [],
            sourceEvidenceUsed: [],
            sourceEvidenceIgnored: []
        )
        let invalidResponsibility = CanonicalPitcherResponsibilityEvidence(
            eventIdentity: event1.eventIdentity,
            gameIdentity: event1.gameIdentity,
            responsibility: .explicitPitcher(invalidAppearance),
            runResponsibilityEvidence: .notRepresented,
            earnedRunResponsibilityEvidence: .notRepresented
        )
        let invalidInput = CanonicalPitchingStatisticsProjectionInput(
            replayResult: replayResult,
            recordedEvents: events,
            pitcherProjection: invalidPitcherProjection,
            eventResponsibilities: [invalidResponsibility]
        )
        let invalidProjection = CanonicalPitchingStatisticsProjector.project(invalidInput)
        #expect(invalidProjection.disposition == CanonicalProjectionDisposition.resolvedWithWarnings)
        #expect(invalidProjection.diagnostics.contains { $0.code == "pitchingProjection.invalidAppearanceIdentity" })
        #expect(invalidProjection.diagnostics.contains { $0.code == "pitchingProjection.invalidResponsibilityIdentity" })
    }
}

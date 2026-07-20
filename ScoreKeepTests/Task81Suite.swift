import Testing
@testable import ScoreKeep

@Suite("Task81Suite")
struct Task81Suite {
    @Test func task81HittingStatisticsProjectionMatchesApprovedReplayFixtures() throws {
        let batter1 = ReplayTestSupport.batter(1)
        let batter2 = ReplayTestSupport.batter(2)
        
        // Batter 1: Home Run with explicit RBI and Run
        let event1 = CanonicalScoringEventEvidence(
            eventIdentity: .valid(ReplayTestSupport.eventID(1)),
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            orderingEvidence: [.knownSequence(OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 0))],
            inningContext: CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: .known(7)),
            teamSide: .visiting,
            participants: ScoringEventParticipantEvidence(batter: batter1),
            resultEvidence: .batterReachesBase(rawValue: "Home Run"),
            batterAdvancement: .scored(runner: ReplayTestSupport.runner(1), sourceBase: nil),
            runnerAdvancement: [],
            rbiEvidence: .flag(true),
            source: .syntheticVerification
        )
        
        // Batter 1: Strikeout
        let event2 = ReplayTestSupport.event(
            sequence: 2, 
            raw: "Strikeout", 
            eventID: ReplayTestSupport.eventID(2),
            batter: batter1
        )
        
        // Batter 2: Walk
        let event3 = ReplayTestSupport.event(
            sequence: 3, 
            raw: "Walk", 
            eventID: ReplayTestSupport.eventID(3),
            batter: batter2
        )
        
        let events = [event1, event2, event3]
        let replayInput = ReplayTestSupport.input(events: events)
        let replayResult = CanonicalGameReplay.replay(replayInput)
        
        #expect(replayResult.disposition == CanonicalReplayDisposition.complete)
        
        let projectionInput = CanonicalHittingProjectionInput(
            replayResult: replayResult,
            recordedEvents: events
        )
        
        let projection = CanonicalHittingProjector.project(projectionInput)
        
        #expect(projection.disposition == CanonicalProjectionDisposition.resolved)
        
        let b1Stats = try #require(projection.playerStatistics[batter1.playerIdentity])
        #expect(b1Stats.plateAppearances == 2)
        #expect(b1Stats.officialAtBats == 2)
        #expect(b1Stats.hits == 1)
        #expect(b1Stats.singles == 0)
        #expect(b1Stats.homeRuns == 1)
        #expect(b1Stats.runs == 1)
        #expect(b1Stats.runsBattedIn == 1)
        #expect(b1Stats.strikeouts == 1)
        #expect(b1Stats.battingAverage == 0.5)
        
        let b2Stats = try #require(projection.playerStatistics[batter2.playerIdentity])
        #expect(b2Stats.plateAppearances == 1)
        #expect(b2Stats.officialAtBats == 0) // Walk does not count as AB
        #expect(b2Stats.walks == 1)
        #expect(b2Stats.hits == 0)
        #expect(b2Stats.battingAverage == nil)
        
        // Determinism Check
        let secondProjection = CanonicalHittingProjector.project(projectionInput)
        #expect(secondProjection == projection)
        
        // Duplicate Event Identity test
        let duplicateEvent = ReplayTestSupport.event(
            sequence: 4,
            raw: "Walk",
            eventID: ReplayTestSupport.eventID(3), // duplicate ID!
            batter: batter2
        )
        
        let dupEvents = [event1, event2, event3, duplicateEvent]
        let dupReplayInput = ReplayTestSupport.input(events: dupEvents)
        let dupReplayResult = CanonicalGameReplay.replay(dupReplayInput)
        
        let dupProjectionInput = CanonicalHittingProjectionInput(
            replayResult: dupReplayResult,
            recordedEvents: dupEvents
        )
        let dupProjection = CanonicalHittingProjector.project(dupProjectionInput)
        
        #expect(dupProjection.disposition == CanonicalProjectionDisposition.unsupported)
        #expect(dupProjection.diagnostics.contains { $0.code == "hittingProjection.duplicateEventIdentity" })
    }
}

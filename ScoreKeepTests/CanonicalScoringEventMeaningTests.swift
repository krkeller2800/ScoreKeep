import Foundation
import Testing
@testable import ScoreKeep

struct CanonicalScoringEventMeaningTests {
    @Test func eventIdentityMatchingConflictingAndVisualDuplicateEvidenceClassifies() {
        let eventID = StableIdentityAndOrderingTestSupport.fixedUUID("a0000000-0000-0000-0000-000000000001")
        let otherID = StableIdentityAndOrderingTestSupport.fixedUUID("a0000000-0000-0000-0000-000000000002")
        let first = event(id: eventID, result: .batterReachesBase(rawValue: "Single"), display: ["Smith Single"])
        let matching = event(id: eventID, result: .batterReachesBase(rawValue: "Single"), display: ["Smith Single"])
        let conflicting = event(id: eventID, result: .batterOut(rawValue: "Ground Out"), display: ["Smith Single"])
        let visualDuplicate = event(id: otherID, result: .batterReachesBase(rawValue: "Single"), display: ["Smith Single"])

        #expect(CanonicalScoringEventMeaningClassifier.compareIdentity(first, matching) == .sameIdentityMatchingEvidence)
        #expect(CanonicalScoringEventMeaningClassifier.compareIdentity(first, conflicting) == .sameIdentityConflictingEvidence(["resultEvidence"]))
        #expect(CanonicalScoringEventMeaningClassifier.compareIdentity(first, visualDuplicate) == .distinctIdentitiesMatchingPlayEvidence)
    }

    @Test func missingInvalidDuplicateAndOrderingEvidenceClassifies() {
        let invalid = event(rawID: "not-a-uuid", ordering: [.missingSequence])
        let duplicateID = StableIdentityAndOrderingTestSupport.fixedUUID("a0000000-0000-0000-0000-000000000003")
        let duplicateA = event(id: duplicateID, ordering: [.knownSequence(.init(kind: .eventSequence, value: 1))])
        let duplicateB = event(id: duplicateID, ordering: [.duplicateSequence(1)])
        let conflicting = event(ordering: [.conflictingSequenceAndScorecardColumn(sequence: 2, column: 4), .sourceFileOrder(.init(kind: .sourceFile, value: 0)), .stableTieEvidence(.init(kind: .eventSequence, value: 2, sourceIndex: 0))])

        #expect(CanonicalScoringEventMeaningClassifier.classify(event(id: nil)).contains(.missingEventIdentity))
        #expect(CanonicalScoringEventMeaningClassifier.classify(invalid).contains(.invalidEventIdentity))
        #expect(CanonicalScoringEventMeaningClassifier.classifyEventSet([duplicateA, duplicateB]).contains(.duplicateImportedEventIdentity))
        #expect(CanonicalScoringEventMeaningClassifier.classify(duplicateB).contains(.duplicateEventSequence(1)))
        #expect(CanonicalScoringEventMeaningClassifier.classify(conflicting).contains(.conflictingSequenceAndScorecardColumn))
        #expect(CanonicalScoringEventMeaningClassifier.classify(conflicting).contains(.sourceFileOrderEvidence))
        #expect(CanonicalScoringEventMeaningClassifier.classify(conflicting).contains(.stableTieEvidence))
    }

    @Test func participantsAdvancementMarkersAndUnsupportedResultsClassifyWithoutMutation() {
        let batter = participant(id: StableIdentityAndOrderingTestSupport.fixedUUID("a1000000-0000-0000-0000-000000000001"))
        let runner = CanonicalGameStatePrimitivesTestSupport.runner(id: StableIdentityAndOrderingTestSupport.fixedUUID("a1000000-0000-0000-0000-000000000002"))
        let scoring = event(
            result: .conflicting([.batterReachesBase(rawValue: "Single"), .batterOut(rawValue: "Ground Out")]),
            batter: batter,
            runners: [.scored(runner: runner, sourceBase: .third), .out(runner: runner, sourceBase: .home)],
            outs: CanonicalOutsState(outs: .known(2), outsRecordedByEvent: 2),
            batterAdvancement: .batterRunner(runner),
            rbis: .count(1),
            earned: .flag(true),
            sacrifice: .count(1),
            steals: .count(1),
            endOfHalf: true,
            unsupportedRaw: ["legacyField=unsupported"]
        )
        let classes = CanonicalScoringEventMeaningClassifier.classify(scoring)

        #expect(classes.contains(.batterParticipantPresent))
        #expect(classes.contains(.runnerAdvancementEvidence))
        #expect(classes.contains(.runnerScores))
        #expect(classes.contains(.runnerOut))
        #expect(classes.contains(.multipleOutsRecorded))
        #expect(classes.contains(.rbiMarker))
        #expect(classes.contains(.earnedRunMarker))
        #expect(classes.contains(.sacrificeMarker))
        #expect(classes.contains(.stolenBaseMarker))
        #expect(classes.contains(.endOfInningMarker))
        #expect(classes.contains(.contradictoryResultEvidence))
        #expect(classes.contains(.unsupportedRawLegacyEvidence))
        #expect(classes.contains(.nonMutatingEvidenceOnly))
    }

    @Test func missingInvalidBatterUnknownUnsupportedAndDeterministicEvaluationClassify() {
        let invalidBatter = LineupParticipantEvidence.invalidPlayerIdentity(.invalid("bad-player-id"), PlayerDisplayEvidence(name: .present("Unknown Batter")))
        let missing = event(result: .unknownRawResult("??"), batter: nil, unresolved: ["player"])
        let invalid = event(result: .unsupportedRawResult("Sacrifise Fly"), batter: invalidBatter)

        #expect(CanonicalScoringEventMeaningClassifier.classify(missing).contains(.batterParticipantMissing))
        #expect(CanonicalScoringEventMeaningClassifier.classify(missing).contains(.unknownResultEvidence))
        #expect(CanonicalScoringEventMeaningClassifier.classify(missing).contains(.missingOrUnresolvedParticipantRelationship))
        #expect(CanonicalScoringEventMeaningClassifier.classify(invalid).contains(.batterParticipantInvalid))
        #expect(CanonicalScoringEventMeaningClassifier.classify(invalid).contains(.unsupportedResultEvidence))
        #expect(CanonicalScoringEventMeaningClassifier.classify(invalid) == CanonicalScoringEventMeaningClassifier.classify(invalid))
    }

    @Test func compatibilityFixturesExposeRecordedPlayEvidenceWithoutMutation() throws {
        let completed = try CanonicalGameStatePrimitivesTestSupport.fixture("CompletedGame.ScoreKeep_Games")
        let multiple = try CanonicalGameStatePrimitivesTestSupport.fixture("MultipleAtbats.ScoreKeep_Games")
        let broken = try CanonicalGameStatePrimitivesTestSupport.fixture("BrokenAtbatRelationship.ScoreKeep_Games", directory: "MalformedAndUnsupported")
        let duplicate = try CanonicalGameStatePrimitivesTestSupport.fixture("DuplicateAtbatID.ScoreKeep_Games", directory: "MalformedAndUnsupported")

        #expect(completed.atbats.contains { $0.rbis >= 0 && $0.result.isEmpty == false })
        #expect(multiple.atbats.contains { $0.maxbase == "Home" || $0.outAt != "Safe" || $0.stolenBases > 0 })
        #expect(broken.atbats.contains { $0.team.name == "Fixture Third Team" })
        #expect(duplicate.atbats.map(\.id).count != Set(duplicate.atbats.map(\.id)).count)
    }

    private func event(
        id: UUID? = StableIdentityAndOrderingTestSupport.fixedUUID("a0000000-0000-0000-0000-000000000010"),
        rawID: String? = nil,
        result: ScoringEventResultEvidence = .batterReachesBase(rawValue: "Single"),
        ordering: [ScoringEventOrderingEvidence] = [.knownSequence(.init(kind: .eventSequence, value: 1))],
        display: [String] = ["Fixture play"],
        batter: LineupParticipantEvidence? = nil,
        runners: [RunnerStateEvidence] = [],
        outs: CanonicalOutsState? = nil,
        batterAdvancement: RunnerStateEvidence? = nil,
        rbis: ScoringEventMarkerEvidence = .notRepresented,
        earned: ScoringEventMarkerEvidence = .notRepresented,
        sacrifice: ScoringEventMarkerEvidence = .notRepresented,
        steals: ScoringEventMarkerEvidence = .notRepresented,
        endOfHalf: Bool = false,
        unresolved: [String] = [],
        unsupportedRaw: [String] = []
    ) -> CanonicalScoringEventEvidence {
        let identity: ImportedIdentifierEvidence
        if let rawID {
            identity = ImportedIdentifierEvidence(rawValue: rawID)
        } else if let id {
            identity = .valid(id)
        } else {
            identity = .missing
        }

        return CanonicalScoringEventEvidence(
            eventIdentity: identity,
            gameIdentity: .valid(CanonicalGameStatePrimitivesTestSupport.gameA),
            orderingEvidence: ordering,
            teamSide: .visiting,
            participants: ScoringEventParticipantEvidence(batter: batter, runners: runners, unresolvedRelationships: unresolved),
            resultEvidence: result,
            outsEvidence: outs,
            batterAdvancement: batterAdvancement,
            rbiEvidence: rbis,
            earnedRunEvidence: earned,
            sacrificeEvidence: sacrifice,
            stolenBaseEvidence: steals,
            endOfHalfEvidence: endOfHalf,
            historicalDisplayEvidence: display,
            unsupportedRawLegacyEvidence: unsupportedRaw,
            source: .syntheticVerification
        )
    }

    private func participant(id: UUID = CanonicalGameStatePrimitivesTestSupport.participantA) -> LineupParticipantEvidence {
        .gameParticipant(CanonicalGameStatePrimitivesTestSupport.participant(id: id, name: "Fixture Batter"))
    }
}

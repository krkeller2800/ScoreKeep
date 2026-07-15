import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical persistence ordering verification")
struct CanonicalPersistenceOrderingTests {
    @Test("explicit event sequence and scorecard column evidence survive reload")
    func explicitEventSequenceAndScorecardColumnEvidenceSurviveReload() throws {
        let environment = try IsolatedPersistenceEnvironment()
        _ = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(into: environment.context)
        try environment.save()

        let firstReload = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)
        let secondReload = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)

        #expect(firstReload.eventSequences == [1, 2])
        #expect(firstReload.scorecardColumnsBySequence == [3, 7])
        #expect(firstReload.atbatIDsBySequence == [PersistenceVerificationIDs.eventOne, PersistenceVerificationIDs.eventTwo])
        #expect(firstReload == secondReload)
    }

    @Test("duplicate event sequence and sequence column conflicts remain diagnosable")
    func duplicateEventSequenceAndSequenceColumnConflictsRemainDiagnosable() {
        let duplicateSequence = CanonicalDomainValidator.validateOrdering(
            [
                OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 0),
                OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 1)
            ],
            expectedKind: .eventSequence
        )
        let conflictingSequence = CanonicalDomainValidator.validateOrdering(
            [
                OrderEvidence(kind: .eventSequence, value: 2, sourceIndex: 0),
                OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 1)
            ],
            expectedKind: .eventSequence
        )
        let scorecardColumnOrder = StableOrderingClassifier.classify(
            [
                OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 0),
                OrderEvidence(kind: .eventSequence, value: 2, sourceIndex: 1),
                OrderEvidence(kind: .displaySort, value: 7, sourceIndex: 0),
                OrderEvidence(kind: .displaySort, value: 3, sourceIndex: 1)
            ],
            expectedKind: .eventSequence
        )

        #expect(duplicateSequence.disposition == .repairRequired)
        #expect(duplicateSequence.findings.map(\.code).contains("ordering.duplicate"))
        #expect(conflictingSequence.disposition == .contradictory)
        #expect(scorecardColumnOrder == .ordered)
    }

    @Test("batting order survives reload and duplicate batting slots remain detectable")
    func battingOrderSurvivesReloadAndDuplicateBattingSlotsRemainDetectable() throws {
        let environment = try IsolatedPersistenceEnvironment()
        _ = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(into: environment.context)
        try environment.save()

        let snapshot = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)
        let duplicateBatting = CanonicalDomainValidator.validateOrdering(
            [
                OrderEvidence(kind: .battingOrder, value: 1, sourceIndex: 0),
                OrderEvidence(kind: .battingOrder, value: 1, sourceIndex: 1)
            ],
            expectedKind: .battingOrder
        )

        #expect(snapshot.battingOrdersBySequence == [1, 2])
        #expect(snapshot.lineupPlayerIDsByExplicitBattingOrder == [PersistenceVerificationIDs.visitingPlayerOne, PersistenceVerificationIDs.visitingPlayerTwo])
        #expect(duplicateBatting.disposition == .repairRequired)
    }

    @Test("lineup array order is not treated as authority when explicit batting order differs")
    func lineupArrayOrderIsNotTreatedAsAuthorityWhenExplicitBattingOrderDiffers() throws {
        let environment = try IsolatedPersistenceEnvironment()
        _ = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(
            into: environment.context,
            reversedLineupArray: true
        )
        try environment.save()

        let snapshot = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)
        let presentationOnlyOrder = StableOrderingClassifier.classify(
            [OrderEvidence(kind: .displaySort, value: nil, sourceIndex: 0)],
            expectedKind: .battingOrder
        )

        #expect(snapshot.lineupPlayerIDsByExplicitBattingOrder == [PersistenceVerificationIDs.visitingPlayerOne, PersistenceVerificationIDs.visitingPlayerTwo])
        #expect(presentationOnlyOrder == .missingOrder)
    }

    @Test("pitcher and substitution ordering remain stable where evidence supports it")
    func pitcherAndSubstitutionOrderingRemainStableWhereEvidenceSupportsIt() throws {
        let environment = try IsolatedPersistenceEnvironment()
        _ = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(into: environment.context)
        try environment.save()

        let snapshot = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)
        let pitcherOrder = StableOrderingClassifier.classify(
            [
                OrderEvidence(kind: .pitcherAppearance, value: 0, sourceIndex: 0),
                OrderEvidence(kind: .pitcherAppearance, value: 1, sourceIndex: 1)
            ],
            expectedKind: .pitcherAppearance
        )
        let substitutionOrder = StableOrderingClassifier.classify(
            [OrderEvidence(kind: .substitution, value: 0, sourceIndex: 0)],
            expectedKind: .substitution
        )

        #expect(snapshot.pitcherIDsByAppearanceOrder == [PersistenceVerificationIDs.pitcherOne, PersistenceVerificationIDs.pitcherTwo])
        #expect(snapshot.replacementPairIDs == [IsolatedPersistenceReplacementPair(outgoing: PersistenceVerificationIDs.visitingPlayerOne, incoming: PersistenceVerificationIDs.visitingPlayerTwo)])
        #expect(pitcherOrder == .ordered)
        #expect(substitutionOrder == .ordered)
    }

    @Test("parallel substitution arrays stay aligned or classify as ambiguous")
    func parallelSubstitutionArraysStayAlignedOrClassifyAsAmbiguous() {
        let incoming = LegacyPlayerEvidenceSnapshot(identity: .valid(PersistenceVerificationIDs.visitingPlayerTwo), name: "Incoming", battingOrder: 2)
        let outgoing = LegacyPlayerEvidenceSnapshot(identity: .valid(PersistenceVerificationIDs.visitingPlayerOne), name: "Outgoing", battingOrder: 1)
        let aligned = CanonicalPersistedEvidenceInterpreter.interpretSubstitutions(
            incoming: [incoming],
            outgoing: [outgoing],
            gameIdentity: .valid(PersistenceVerificationIDs.game)
        )
        let ambiguous = CanonicalPersistedEvidenceInterpreter.interpretSubstitutions(
            incoming: [incoming, incoming],
            outgoing: [outgoing],
            gameIdentity: .valid(PersistenceVerificationIDs.game)
        )

        let alignedOrder = aligned[0].canonicalValue?.effectiveOrder?.value
        let ambiguousEvidence = ambiguous.compactMap { $0.canonicalValue?.legacyArrayEvidence }

        #expect(aligned.count == 1)
        #expect(alignedOrder == 0)
        #expect(ambiguous.count == 2)
        #expect(ambiguousEvidence.contains(.unequalCounts(incoming: 2, outgoing: 1)))
    }

    @Test("imported explicit source ordering is preserved when available")
    func importedExplicitSourceOrderingIsPreservedWhenAvailable() {
        let importedOrdering = StableOrderingClassifier.classify(
            [
                OrderEvidence(kind: .sourceFile, value: 0, sourceIndex: 0),
                OrderEvidence(kind: .sourceFile, value: 1, sourceIndex: 1),
                OrderEvidence(kind: .sourceFile, value: 2, sourceIndex: 2)
            ],
            expectedKind: .sourceFile
        )
        let unsafeFetchOnlyOrdering = StableOrderingClassifier.classify(
            [
                OrderEvidence(kind: .persistenceFetch, value: nil, sourceIndex: nil),
                OrderEvidence(kind: .persistenceFetch, value: nil, sourceIndex: nil)
            ],
            expectedKind: .eventSequence
        )

        #expect(importedOrdering == .ordered)
        #expect(unsafeFetchOnlyOrdering == .missingOrder)
    }
}

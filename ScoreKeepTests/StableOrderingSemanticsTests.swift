import Testing
@testable import ScoreKeep

struct StableOrderingSemanticsTests {
    @Test("event ordering classifies increasing duplicate missing and conflicting sequence values")
    func eventOrderingClassifiesSequenceEvidence() {
        let increasing = [
            OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 0),
            OrderEvidence(kind: .eventSequence, value: 2, sourceIndex: 1),
            OrderEvidence(kind: .eventSequence, value: 3, sourceIndex: 2)
        ]
        let duplicate = [
            OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 0),
            OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 1)
        ]
        let missing = [
            OrderEvidence(kind: .eventSequence, value: nil, sourceIndex: 0)
        ]
        let conflicting = [
            OrderEvidence(kind: .eventSequence, value: 2, sourceIndex: 0),
            OrderEvidence(kind: .eventSequence, value: 1, sourceIndex: 1)
        ]

        #expect(StableOrderingClassifier.classify(increasing, expectedKind: .eventSequence) == .ordered)
        #expect(StableOrderingClassifier.classify(duplicate, expectedKind: .eventSequence) == .duplicateOrderValue(1))
        #expect(StableOrderingClassifier.classify(missing, expectedKind: .eventSequence) == .missingOrder)
        #expect(StableOrderingClassifier.classify(conflicting, expectedKind: .eventSequence) == .conflictingOrderEvidence)
    }

    @Test("source order is retained as evidence but does not make duplicate sequence safe")
    func sourceOrderIsTieEvidenceOnly() {
        let first = OrderEvidence(kind: .eventSequence, value: 7, sourceIndex: 0)
        let second = OrderEvidence(kind: .eventSequence, value: 7, sourceIndex: 1)
        let sourceFirst = OrderEvidence(kind: .sourceFile, value: 0, sourceIndex: 0)
        let sourceSecond = OrderEvidence(kind: .sourceFile, value: 1, sourceIndex: 1)

        #expect(StableOrderingClassifier.compare(first, second) == .ambiguous)
        #expect(StableOrderingClassifier.compare(sourceFirst, sourceSecond) == .orderedBefore)
        #expect(
            StableOrderingClassifier.classify([first, second], expectedKind: .eventSequence) ==
                .duplicateOrderValue(7)
        )
    }

    @Test("ordering comparison is stable across repeated evaluation")
    func orderingComparisonIsStableAcrossRepeatedEvaluation() {
        let lhs = OrderEvidence(kind: .eventSequence, value: 3, sourceIndex: 10)
        let rhs = OrderEvidence(kind: .eventSequence, value: 9, sourceIndex: 11)
        let firstPass = StableOrderingClassifier.compare(lhs, rhs)
        let secondPass = StableOrderingClassifier.compare(lhs, rhs)

        #expect(firstPass == .orderedBefore)
        #expect(secondPass == firstPass)
    }

    @Test("lineup slot is separate from player identity and display sorting")
    func lineupSlotIsSeparateFromIdentityAndDisplaySorting() {
        let player = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerA,
            name: "Fixture Sorted Last",
            number: "1"
        )
        let samePlayerLaterSlot = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerA,
            name: "Fixture Sorted Last",
            number: "1"
        )
        let lineupSlotOne = OrderEvidence(kind: .lineupSlot, value: 1, sourceIndex: 3)
        let lineupSlotNine = OrderEvidence(kind: .lineupSlot, value: 9, sourceIndex: 4)
        let displaySort = OrderEvidence(kind: .displaySort, value: 1, sourceIndex: 0)

        #expect(StableIdentityClassifier.compare(player, samePlayerLaterSlot) == .sameIdentifierMatchingEvidence)
        #expect(StableOrderingClassifier.compare(lineupSlotOne, lineupSlotNine) == .orderedBefore)
        #expect(StableOrderingClassifier.compare(lineupSlotOne, displaySort) == .incomparableOrderKinds)
    }

    @Test("pitcher appearance order remains separate from pitcher identity")
    func pitcherAppearanceOrderRemainsSeparateFromPitcherIdentity() {
        let pitcherIdentity = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerA,
            name: "Fixture Pitcher",
            number: "22"
        )
        let samePitcherIdentity = StableIdentityAndOrderingTestSupport.playerEvidence(
            id: StableIdentityAndOrderingTestSupport.playerA,
            name: "Fixture Pitcher",
            number: "22"
        )
        let firstAppearance = OrderEvidence(kind: .pitcherAppearance, value: 1, sourceIndex: 4)
        let secondAppearance = OrderEvidence(kind: .pitcherAppearance, value: 2, sourceIndex: 9)
        let battingOrder = OrderEvidence(kind: .battingOrder, value: 2, sourceIndex: 1)

        #expect(StableIdentityClassifier.compare(pitcherIdentity, samePitcherIdentity) == .sameIdentifierMatchingEvidence)
        #expect(StableOrderingClassifier.compare(firstAppearance, secondAppearance) == .orderedBefore)
        #expect(StableOrderingClassifier.compare(firstAppearance, battingOrder) == .incomparableOrderKinds)
    }

    @Test("substitution evidence preserves known pairs and ambiguous legacy arrays")
    func substitutionEvidencePreservesAmbiguity() {
        let knownPair = OrderedSubstitutionEvidence(
            incomingIdentifier: .valid(StableIdentityAndOrderingTestSupport.playerB),
            outgoingIdentifier: .valid(StableIdentityAndOrderingTestSupport.playerA),
            order: OrderEvidence(kind: .substitution, value: 1, sourceIndex: 12),
            battingSlot: 4,
            role: "pinch hitter",
            timingDescription: "before event 7"
        )
        let incompletePair = OrderedSubstitutionEvidence(
            incomingIdentifier: .valid(StableIdentityAndOrderingTestSupport.playerB),
            outgoingIdentifier: nil,
            order: OrderEvidence(kind: .substitution, value: 1, sourceIndex: 12),
            battingSlot: nil,
            role: nil,
            timingDescription: nil
        )

        #expect(SubstitutionEvidenceClassifier.classifyKnownPair(knownPair) == .completeOrderedEvidence)
        #expect(SubstitutionEvidenceClassifier.classifyKnownPair(incompletePair) == .incompleteEvidence)
        #expect(
            SubstitutionEvidenceClassifier.classifyParallelArrays(
                incomingCount: 2,
                outgoingCount: 2,
                hasTimingOrRoleEvidence: false
            ) == .ambiguousParallelArrays
        )
        #expect(
            SubstitutionEvidenceClassifier.classifyParallelArrays(
                incomingCount: 2,
                outgoingCount: 1,
                hasTimingOrRoleEvidence: false
            ) == .contradictoryEvidence
        )
    }
}

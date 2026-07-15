import Testing
@testable import ScoreKeep

struct CanonicalBaseOccupancySemanticsTests {
    @Test func emptySinglesTwoBaseCombinationsAndLoadedBasesClassify() {
        #expect(CanonicalBaseOccupancySemanticsClassifier.classify(CanonicalBaseOccupancy()).contains(.basesEmpty))

        let first = occupancy([.first])
        let second = occupancy([.second])
        let third = occupancy([.third])
        let firstSecond = occupancy([.first, .second])
        let firstThird = occupancy([.first, .third])
        let secondThird = occupancy([.second, .third])
        let loaded = occupancy([.first, .second, .third])

        #expect(CanonicalBaseOccupancySemanticsClassifier.classify(first).contains(.runnerOnFirst))
        #expect(CanonicalBaseOccupancySemanticsClassifier.classify(second).contains(.runnerOnSecond))
        #expect(CanonicalBaseOccupancySemanticsClassifier.classify(third).contains(.runnerOnThird))
        #expect(CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(firstSecond) == Set([.first, .second]))
        #expect(CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(firstThird) == Set([.first, .third]))
        #expect(CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(secondThird) == Set([.second, .third]))
        #expect(CanonicalBaseOccupancySemanticsClassifier.classify(loaded).contains(.allBasesOccupied))
    }

    @Test func runnerIdentityUnknownMissingInvalidDuplicateAndConflictClassify() {
        let known = CanonicalGameStatePrimitivesTestSupport.runner(id: CanonicalGameStatePrimitivesTestSupport.participantA)
        let unknown = RunnerIdentityEvidence.unknown(PlayerDisplayEvidence(name: .unknown("unknown runner")))
        let missing = RunnerIdentityEvidence.missingRelationship(PlayerDisplayEvidence(name: .present("missing relation")))
        let invalid = RunnerIdentityEvidence.invalidIdentity(.invalid("bad-runner-id"), PlayerDisplayEvidence())

        var classifications = CanonicalBaseOccupancySemanticsClassifier.classify(CanonicalBaseOccupancy(runnerStates: [
            .activeOccupant(base: .first, runner: known),
            .activeOccupant(base: .second, runner: known),
            .activeOccupant(base: .third, runner: unknown)
        ]))
        #expect(classifications.contains(.sameRunnerAssignedToMultipleBases))
        #expect(classifications.contains(.unknownRunner))

        classifications = CanonicalBaseOccupancySemanticsClassifier.classify(CanonicalBaseOccupancy(runnerStates: [
            .activeOccupant(base: .first, runner: missing),
            .activeOccupant(base: .first, runner: invalid)
        ]))
        #expect(classifications.contains(.multipleRunnersAssignedToOneBase(.first)))
        #expect(classifications.contains(.missingRunnerRelationship))
        #expect(classifications.contains(.invalidRunnerIdentity))
    }

    @Test func scoredOutBatterHistoricalAndAmbiguousLegacyEvidenceClassify() {
        let runner = CanonicalGameStatePrimitivesTestSupport.runner()
        let occupancy = CanonicalBaseOccupancy(runnerStates: [
            .scored(runner: runner, sourceBase: .third),
            .out(runner: runner, sourceBase: .home),
            .batterRunner(runner),
            .historicalRunner(runner, lastKnownBase: .second),
            .ambiguousLegacyMaxBase("Home"),
            .ambiguousLegacyOutAt("First"),
            .unsupportedLegacyValue(field: "maxbase", value: "Moon")
        ])
        let classifications = CanonicalBaseOccupancySemanticsClassifier.classify(occupancy)

        #expect(classifications.contains(.runnerScored))
        #expect(classifications.contains(.runnerOut))
        #expect(classifications.contains(.batterRunnerEvidence))
        #expect(classifications.contains(.historicalRunnerEvidence))
        #expect(classifications.contains(.ambiguousLegacyAdvancementEvidence))
        #expect(classifications.contains(.unsupportedLegacyEvidence))
        #expect(CanonicalBaseOccupancySemanticsClassifier.activeOccupiedBases(occupancy).isEmpty)
    }

    @Test func scoredOrOutRunnerCannotRemainActiveAndOccupancyDoesNotCalculateScore() {
        let runner = CanonicalGameStatePrimitivesTestSupport.runner()
        let occupancy = CanonicalBaseOccupancy(runnerStates: [
            .activeOccupant(base: .third, runner: runner),
            .scored(runner: runner, sourceBase: .third)
        ])
        let classifications = CanonicalBaseOccupancySemanticsClassifier.classify(occupancy)

        #expect(classifications.contains(.runnerScored))
        #expect(classifications.contains(.impossibleOrContradictoryOccupancy))
        #expect(classifications.contains(.occupiedBases([.third])))
    }

    @Test func historicalAndCompatibilityBoundariesRemainUnfabricatedAndDeterministic() {
        let renamed = CanonicalGameStatePrimitivesTestSupport.runner(name: "Renamed Runner")
        let unresolved = RunnerIdentityEvidence.importedUnresolved(PlayerDisplayEvidence(name: .unknown("fixture import")))
        let occupancy = CanonicalBaseOccupancy(runnerStates: [
            .historicalRunner(renamed, lastKnownBase: .first),
            .activeOccupant(base: .second, runner: unresolved)
        ])

        #expect(CanonicalBaseOccupancySemanticsClassifier.classify(occupancy).contains(.historicalRunnerEvidence))
        #expect(CanonicalBaseOccupancySemanticsClassifier.classify(occupancy).contains(.unresolvedRunnerEvidence))
        #expect(CanonicalBaseOccupancySemanticsClassifier.classify(occupancy) == CanonicalBaseOccupancySemanticsClassifier.classify(occupancy))
    }

    private func occupancy(_ bases: [Base]) -> CanonicalBaseOccupancy {
        let states = bases.enumerated().map { index, base in
            RunnerStateEvidence.activeOccupant(
                base: base,
                runner: CanonicalGameStatePrimitivesTestSupport.runner(
                    id: [CanonicalGameStatePrimitivesTestSupport.participantA, CanonicalGameStatePrimitivesTestSupport.participantB, CanonicalGameStatePrimitivesTestSupport.participantC][index],
                    name: "Fixture Runner \(index)"
                )
            )
        }
        return CanonicalBaseOccupancy(runnerStates: states)
    }
}

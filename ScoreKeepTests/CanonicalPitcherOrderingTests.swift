import XCTest
@testable import ScoreKeep

final class CanonicalPitcherOrderingTests: XCTestCase {

    private func makeDummyPitcher(
        ident: UUID = UUID(),
        startInn: Int, sOuts: Int, sBats: Int,
        endInn: Int, eOuts: Int, eBats: Int
    ) -> Pitcher {
        let dummyPlayer = Player(name: "P", number: "1", position: "P", batDir: "R", batOrder: 1)
        let dummyTeam = Team(name: "T", coach: "C", details: "D")
        let dummyGame = Game(date: "", location: "", highLights: "", hscore: 0, vscore: 0)
        return Pitcher(
            ident: ident,
            player: dummyPlayer,
            team: dummyTeam,
            game: dummyGame,
            startInn: startInn, sOuts: sOuts, sBats: sBats,
            endInn: endInn, eOuts: eOuts, eBats: eBats
        )
    }

    func testNormalInningChangesSortCorrectly() throws {
        let pitcherA = makeDummyPitcher(startInn: 1, sOuts: 0, sBats: 0, endInn: 2, eOuts: 0, eBats: 0)
        let pitcherB = makeDummyPitcher(startInn: 2, sOuts: 0, sBats: 0, endInn: 3, eOuts: 0, eBats: 0)

        let unsorted = [pitcherB, pitcherA]
        let sorted = unsorted.sorted(by: CanonicalPitcherOrdering.canonicalOrder)

        XCTAssertEqual(sorted.first?.ident, pitcherA.ident)
        XCTAssertEqual(sorted.last?.ident, pitcherB.ident)
    }

    func testMultipleRelieversInOneInningSortCorrectly() throws {
        let pitcherA = makeDummyPitcher(startInn: 2, sOuts: 0, sBats: 0, endInn: 2, eOuts: 1, eBats: 1)
        let pitcherB = makeDummyPitcher(startInn: 2, sOuts: 1, sBats: 1, endInn: 2, eOuts: 2, eBats: 2)
        let pitcherC = makeDummyPitcher(startInn: 2, sOuts: 2, sBats: 2, endInn: 3, eOuts: 0, eBats: 3)

        let unsorted = [pitcherB, pitcherC, pitcherA]
        let sorted = unsorted.sorted(by: CanonicalPitcherOrdering.canonicalOrder)

        XCTAssertEqual(sorted.map { $0.ident }, [pitcherA.ident, pitcherB.ident, pitcherC.ident])
    }

    func testMidBatterInjuryReplacementSortsCorrectlyUsingEndBoundaries() throws {
        let pitcherA = makeDummyPitcher(startInn: 1, sOuts: 0, sBats: 0, endInn: 1, eOuts: 0, eBats: 1)
        let pitcherB = makeDummyPitcher(startInn: 1, sOuts: 0, sBats: 1, endInn: 1, eOuts: 0, eBats: 1)
        let pitcherC = makeDummyPitcher(startInn: 1, sOuts: 0, sBats: 1, endInn: 1, eOuts: 1, eBats: 1)

        let unsorted = [pitcherC, pitcherB, pitcherA]
        let sorted = unsorted.sorted(by: CanonicalPitcherOrdering.canonicalOrder)

        XCTAssertEqual(sorted.map { $0.ident }, [pitcherA.ident, pitcherB.ident, pitcherC.ident])
    }

    func testRelationshipArrayPermutationDoesNotChangeDisplayedOrder() throws {
        let pitcherA = makeDummyPitcher(startInn: 1, sOuts: 0, sBats: 0, endInn: 2, eOuts: 0, eBats: 0)
        let pitcherB = makeDummyPitcher(startInn: 2, sOuts: 0, sBats: 0, endInn: 3, eOuts: 0, eBats: 0)
        let pitcherC = makeDummyPitcher(startInn: 3, sOuts: 0, sBats: 0, endInn: 4, eOuts: 0, eBats: 0)

        let p1 = [pitcherA, pitcherB, pitcherC]
        let p2 = [pitcherC, pitcherA, pitcherB]
        let p3 = [pitcherB, pitcherC, pitcherA]

        XCTAssertEqual(p1.sorted(by: CanonicalPitcherOrdering.canonicalOrder).map { $0.ident }, [pitcherA.ident, pitcherB.ident, pitcherC.ident])
        XCTAssertEqual(p2.sorted(by: CanonicalPitcherOrdering.canonicalOrder).map { $0.ident }, [pitcherA.ident, pitcherB.ident, pitcherC.ident])
        XCTAssertEqual(p3.sorted(by: CanonicalPitcherOrdering.canonicalOrder).map { $0.ident }, [pitcherA.ident, pitcherB.ident, pitcherC.ident])
    }

    func testMalformedExactTiesRemainDeterministicThroughUUIDFallback() throws {
        let id1 = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let id2 = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let id3 = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        let pitcherA = makeDummyPitcher(ident: id2, startInn: 1, sOuts: 0, sBats: 0, endInn: 1, eOuts: 0, eBats: 0)
        let pitcherB = makeDummyPitcher(ident: id1, startInn: 1, sOuts: 0, sBats: 0, endInn: 1, eOuts: 0, eBats: 0)
        let pitcherC = makeDummyPitcher(ident: id3, startInn: 1, sOuts: 0, sBats: 0, endInn: 1, eOuts: 0, eBats: 0)

        let unsorted = [pitcherA, pitcherB, pitcherC]
        let sorted = unsorted.sorted(by: CanonicalPitcherOrdering.canonicalOrder)

        XCTAssertEqual(sorted.map { $0.ident }, [id1, id2, id3])
    }
}

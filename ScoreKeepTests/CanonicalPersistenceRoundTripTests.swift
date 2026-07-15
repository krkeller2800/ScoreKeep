import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

@MainActor
@Suite("Canonical persistence round-trip verification")
struct CanonicalPersistenceRoundTripTests {
    @Test("empty isolated store reloads without production seed or user records")
    func emptyIsolatedStoreReloadsWithoutProductionSeedOrUserRecords() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let snapshotContext = ModelContext(environment.container)

        let games = try snapshotContext.fetch(FetchDescriptor<Game>())
        let teams = try snapshotContext.fetch(FetchDescriptor<Team>())
        let players = try snapshotContext.fetch(FetchDescriptor<Player>())
        let atbats = try snapshotContext.fetch(FetchDescriptor<Atbat>())
        let lineups = try snapshotContext.fetch(FetchDescriptor<Lineup>())
        let pitchers = try snapshotContext.fetch(FetchDescriptor<Pitcher>())

        #expect(games.isEmpty)
        #expect(teams.isEmpty)
        #expect(players.isEmpty)
        #expect(atbats.isEmpty)
        #expect(lineups.isEmpty)
        #expect(pitchers.isEmpty)
    }

    @Test("minimal game round trips through isolated store and fresh context")
    func minimalGameRoundTripsThroughIsolatedStoreAndFreshContext() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let ids = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(
            into: environment.context,
            includeSecondEvent: false,
            includeSubstitution: false
        )
        try environment.save()

        let snapshot = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)

        #expect(snapshot.gameID == ids.gameID)
        #expect(snapshot.homeTeamID == ids.homeTeamID)
        #expect(snapshot.visitingTeamID == ids.visitingTeamID)
        #expect(snapshot.playerIDs == ids.playerIDs.sorted { $0.uuidString < $1.uuidString })
        #expect(snapshot.atbatIDsBySequence == ids.eventIDs)
        #expect(snapshot.eventSequences == [1])
        #expect(snapshot.scorecardColumnsBySequence == [3])
        #expect(snapshot.battingOrdersBySequence == [1])
        #expect(snapshot.lineupPlayerIDsByExplicitBattingOrder == [PersistenceVerificationIDs.visitingPlayerOne, PersistenceVerificationIDs.visitingPlayerTwo])
        #expect(snapshot.pitcherIDsByAppearanceOrder == ids.pitcherIDs)
        #expect(snapshot.storedScore == CanonicalProjectedScore(home: 1, visiting: 0))
        let unsafeDispositions: Set<CanonicalPersistedInterpretationDisposition> = [.unsupported, .contradictory, .unresolved, .rejectedForFutureWrite]
        #expect(snapshot.interpretationDispositions.allSatisfy { unsafeDispositions.contains($0) == false })
    }

    @Test("in-progress game round trip preserves optional unsupported and stored score evidence")
    func inProgressGameRoundTripPreservesOptionalUnsupportedAndStoredScoreEvidence() throws {
        let environment = try IsolatedPersistenceEnvironment()
        _ = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(into: environment.context)
        try environment.save()

        let snapshot = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)
        let unsupported = CanonicalPersistedEvidenceInterpreter.interpretScoringEvent(
            LegacyAtbatEvidenceSnapshot(
                identity: .valid(PersistenceVerificationIDs.eventThree),
                gameIdentity: .valid(PersistenceVerificationIDs.game),
                teamIdentity: .valid(PersistenceVerificationIDs.visitingTeam),
                player: LegacyPlayerEvidenceSnapshot(
                    identity: .valid(PersistenceVerificationIDs.visitingPlayerOne),
                    name: "Visitor One",
                    number: "1",
                    position: "SS",
                    battingDirection: "R",
                    battingOrder: 1,
                    teamIdentity: .valid(PersistenceVerificationIDs.visitingTeam)
                ),
                result: "Future Result",
                maxbase: "Fourth",
                battingOrder: 1,
                outAt: "",
                inning: 2,
                sequence: 3,
                scorecardColumn: 9,
                rbis: 0,
                outs: 0,
                sacrificeFly: 0,
                sacrificeBunt: 0,
                stolenBases: 0,
                earnedRun: true,
                playRecord: "unsupported preserved as raw evidence",
                endOfInning: false
            )
        )
        let storedScore = CanonicalPersistedEvidenceInterpreter.interpretStoredScore(
            CanonicalPersistedStoredScoreSnapshot(
                gameIdentity: .valid(snapshot.gameID),
                home: snapshot.storedScore.home,
                visiting: snapshot.storedScore.visiting
            )
        )

        #expect(snapshot.eventSequences == [1, 2])
        #expect(snapshot.scorecardColumnsBySequence == [3, 7])
        #expect(snapshot.replacementPairIDs == [IsolatedPersistenceReplacementPair(outgoing: PersistenceVerificationIDs.visitingPlayerOne, incoming: PersistenceVerificationIDs.visitingPlayerTwo)])
        #expect(unsupported.disposition == .unsupported)
        #expect(unsupported.unsupportedRawEvidence.contains("result=Future Result"))
        #expect(storedScore.canonicalValue == CanonicalProjectedScore(home: 1, visiting: 1))
    }

    @Test("completed representative game round trip is deterministic across repeated reloads")
    func completedRepresentativeGameRoundTripIsDeterministicAcrossRepeatedReloads() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let ids = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(into: environment.context)
        try environment.save()

        let firstReload = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)
        let secondReload = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)

        #expect(firstReload == secondReload)
        #expect(firstReload.gameID == ids.gameID)
        #expect(firstReload.atbatIDsBySequence == ids.eventIDs)
        #expect(firstReload.pitcherIDsByAppearanceOrder == ids.pitcherIDs)
    }

    @Test("input snapshot remains unchanged by save and reload interpretation")
    func inputSnapshotRemainsUnchangedBySaveAndReloadInterpretation() throws {
        let environment = try IsolatedPersistenceEnvironment()
        let ids = IsolatedPersistenceRoundTripSupport.insertRepresentativeGame(into: environment.context)
        let inputIDs = ids
        try environment.save()

        _ = try IsolatedPersistenceRoundTripSupport.reloadSnapshot(from: environment.container)

        #expect(ids == inputIDs)
    }
}

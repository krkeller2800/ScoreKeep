import Foundation
@testable import ScoreKeep

enum CanonicalGameStatePrimitivesTestSupport {
    static let gameA = StableIdentityAndOrderingTestSupport.fixedUUID("90000000-0000-0000-0000-000000000001")
    static let gameB = StableIdentityAndOrderingTestSupport.fixedUUID("90000000-0000-0000-0000-000000000002")
    static let participantA = StableIdentityAndOrderingTestSupport.fixedUUID("91000000-0000-0000-0000-000000000001")
    static let participantB = StableIdentityAndOrderingTestSupport.fixedUUID("91000000-0000-0000-0000-000000000002")
    static let participantC = StableIdentityAndOrderingTestSupport.fixedUUID("91000000-0000-0000-0000-000000000003")

    static func game(
        id: UUID? = gameA,
        rawID: String? = nil,
        date: String = "2026-04-10T18:00:00Z",
        location: String = "Fixture Field",
        home: String = "Fixture Home",
        visiting: String = "Fixture Visitors",
        homeScore: Int? = 0,
        visitingScore: Int? = 0,
        doubleheaderDesignator: String? = nil,
        expectedInnings: ExpectedInningCountEvidence = .known(7),
        lineupMode: LineupModeEvidence = .traditional,
        origin: GameOriginEvidence = .userCreated,
        lifecycle: GameLifecycleEvidence = .ready,
        source: GameEvidenceSource = .syntheticVerification
    ) -> CanonicalGameIdentity {
        let identity: ImportedIdentifierEvidence
        if let rawID {
            identity = ImportedIdentifierEvidence(rawValue: rawID)
        } else if let id {
            identity = .valid(id)
        } else {
            identity = .missing
        }

        return CanonicalGameIdentity(
            identity: identity,
            displayEvidence: GameDisplayEvidence(
                date: date,
                location: location,
                homeTeamName: home,
                visitingTeamName: visiting,
                storedHomeScore: homeScore,
                storedVisitingScore: visitingScore,
                doubleheaderDesignator: doubleheaderDesignator
            ),
            configuration: .configured(expectedInnings: expectedInnings, lineupMode: lineupMode),
            origin: origin,
            lifecycle: lifecycle,
            source: source
        )
    }

    static func importedGame(_ shareGame: ShareGame, source: GameEvidenceSource = .importedGame) -> CanonicalGameIdentity {
        CanonicalGameIdentity(
            identity: .valid(shareGame.id),
            displayEvidence: GameDisplayEvidence(
                date: shareGame.date,
                location: shareGame.location,
                homeTeamName: shareGame.hteam.name,
                visitingTeamName: shareGame.vteam.name,
                storedHomeScore: shareGame.hscore,
                storedVisitingScore: shareGame.vscore
            ),
            configuration: .configured(
                expectedInnings: shareGame.numInnings > 0 ? .known(shareGame.numInnings) : .missing,
                lineupMode: shareGame.everyOneHits ? .everyoneHits : .traditional
            ),
            origin: source == .seededGame ? .seeded : .imported,
            lifecycle: shareGame.atbats.isEmpty ? .ready : .imported,
            source: source
        )
    }

    static func player(id: UUID = participantA, name: String = "Fixture Runner") -> ReusableCanonicalPlayer {
        ReusableCanonicalPlayer(
            identity: .valid(id),
            display: PlayerDisplayEvidence(name: .present(name)),
            rosterEvidence: .notRepresented,
            source: .historicalGameParticipation
        )
    }

    static func participant(id: UUID = participantA, name: String = "Fixture Runner") -> GamePlayerParticipation {
        CanonicalPlayerMeaningTestSupport.participant(
            gameID: gameA,
            player: player(id: id, name: name),
            historicalDisplay: PlayerDisplayEvidence(name: .present(name)),
            roles: [.batter],
            source: .historicalGameParticipation
        )
    }

    static func runner(id: UUID = participantA, name: String = "Fixture Runner") -> RunnerIdentityEvidence {
        .gameParticipant(participant(id: id, name: name))
    }

    static func fixture(_ filename: String, directory: String = "ScoreKeep_Games") throws -> ShareGame {
        let url = StableIdentityAndOrderingTestSupport.sourceFixtureURL(directory: directory, filename: filename)
        return try JSONDecoder().decode(ShareGame.self, from: Data(contentsOf: url))
    }
}

import Foundation
@testable import ScoreKeep

enum CanonicalTeamMeaningTestSupport {
    static let teamA = StableIdentityAndOrderingTestSupport.teamA
    static let teamB = StableIdentityAndOrderingTestSupport.teamB
    static let teamC = StableIdentityAndOrderingTestSupport.fixedUUID("10000000-0000-0000-0000-000000000003")
    static let gameA = StableIdentityAndOrderingTestSupport.gameA
    static let gameB = StableIdentityAndOrderingTestSupport.gameB

    static let logoA = Data([0x01, 0x02, 0x03])
    static let logoB = Data([0x04, 0x05, 0x06, 0x07])

    static func display(
        name: TeamTextEvidence = .present("Fixture Tigers"),
        coach: TeamTextEvidence = .present("Coach One"),
        details: TeamTextEvidence = .present("Season roster"),
        logo: TeamLogoEvidence = .missing
    ) -> TeamDisplayEvidence {
        TeamDisplayEvidence(name: name, coach: coach, details: details, logo: logo)
    }

    static func team(
        id: UUID? = teamA,
        rawID: String? = nil,
        display: TeamDisplayEvidence = display(),
        rosterEvidence: TeamRosterEvidence = .notRepresented,
        source: TeamEvidenceSource = .currentReusableRecord
    ) -> ReusableCanonicalTeam {
        let identity: ImportedIdentifierEvidence
        if let rawID {
            identity = ImportedIdentifierEvidence(rawValue: rawID)
        } else if let id {
            identity = .valid(id)
        } else {
            identity = .missing
        }

        return ReusableCanonicalTeam(
            identity: identity,
            display: display,
            rosterEvidence: rosterEvidence,
            source: source
        )
    }

    static func side(
        gameID: UUID = gameA,
        role: TeamSideRole,
        team: ReusableCanonicalTeam? = team(),
        display: TeamDisplayEvidence = display(),
        source: TeamEvidenceSource = .historicalGameSide
    ) -> GameSideTeamParticipation {
        let resolution: TeamSideResolution = team.map { .reusableTeam($0) } ?? .missing
        return GameSideTeamParticipation(
            gameIdentity: .valid(gameID),
            role: role,
            resolution: resolution,
            historicalDisplay: display,
            source: source
        )
    }

    static func unknownSide(
        gameID: UUID = gameA,
        role: TeamSideRole,
        display: TeamDisplayEvidence = display(name: .missing)
    ) -> GameSideTeamParticipation {
        GameSideTeamParticipation(
            gameIdentity: .valid(gameID),
            role: role,
            resolution: .unknown(display),
            historicalDisplay: display,
            source: .historicalGameSide
        )
    }

    static func fixtureData(directory: String, filename: String, callerFilePath: String = #filePath) throws -> Data {
        let fileManager = FileManager.default
        var searchDirectory = URL(fileURLWithPath: callerFilePath).deletingLastPathComponent()

        for _ in 0..<8 {
            let candidate = searchDirectory.appendingPathComponent("ScoreKeep/Docs/Verification/Fixtures")
            if fileManager.fileExists(atPath: candidate.path) {
                let fixtureURL = candidate.appendingPathComponent(directory).appendingPathComponent(filename)
                return try Data(contentsOf: fixtureURL)
            }
            searchDirectory.deleteLastPathComponent()
        }

        let fallback = StableIdentityAndOrderingTestSupport.sourceFixtureURL(directory: directory, filename: filename)
        return try Data(contentsOf: fallback)
    }

    static func decodeRosterFixture(_ filename: String) throws -> [SharePlayer] {
        try JSONDecoder().decode(
            [SharePlayer].self,
            from: fixtureData(directory: "ScoreKeep_Players", filename: filename)
        )
    }

    static func decodeGameFixture(_ filename: String) throws -> ShareGame {
        try JSONDecoder().decode(
            ShareGame.self,
            from: fixtureData(directory: "ScoreKeep_Games", filename: filename)
        )
    }

    static func decodeMalformedGameFixture(_ filename: String) throws -> ShareGame {
        try JSONDecoder().decode(
            ShareGame.self,
            from: fixtureData(directory: "MalformedAndUnsupported", filename: filename)
        )
    }
}

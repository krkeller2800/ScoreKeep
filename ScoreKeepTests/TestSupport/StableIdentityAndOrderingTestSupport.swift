import Foundation
@testable import ScoreKeep

enum StableIdentityAndOrderingTestSupport {
    static let teamA = fixedUUID("10000000-0000-0000-0000-000000000001")
    static let teamB = fixedUUID("10000000-0000-0000-0000-000000000002")
    static let playerA = fixedUUID("20000000-0000-0000-0000-000000000001")
    static let playerB = fixedUUID("20000000-0000-0000-0000-000000000002")
    static let gameA = fixedUUID("30000000-0000-0000-0000-000000000001")
    static let gameB = fixedUUID("30000000-0000-0000-0000-000000000002")
    static let eventA = fixedUUID("40000000-0000-0000-0000-000000000001")
    static let eventB = fixedUUID("40000000-0000-0000-0000-000000000002")

    static func fixedUUID(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }

    static func teamEvidence(id: UUID?, name: String) -> StableIdentityEvidence {
        StableIdentityEvidence(
            concept: .team,
            importedIdentifier: id.map { .valid($0) } ?? .missing,
            displayEvidence: [.init("name", name)]
        )
    }

    static func playerEvidence(id: UUID?, name: String, number: String, teamID: UUID? = nil) -> StableIdentityEvidence {
        var displayEvidence: [IdentityDisplayEvidence] = [
            .init("name", name),
            .init("number", number)
        ]

        if let teamID {
            displayEvidence.append(.init("teamID", teamID.uuidString))
        }

        return StableIdentityEvidence(
            concept: .player,
            importedIdentifier: id.map { .valid($0) } ?? .missing,
            displayEvidence: displayEvidence
        )
    }

    static func gameEvidence(id: UUID?, date: String, visitors: UUID, home: UUID, label: String = "game") -> StableIdentityEvidence {
        StableIdentityEvidence(
            concept: .game,
            importedIdentifier: id.map { .valid($0) } ?? .missing,
            displayEvidence: [
                .init("date", date),
                .init("visitingTeam", visitors.uuidString),
                .init("homeTeam", home.uuidString),
                .init("label", label)
            ]
        )
    }

    static func eventEvidence(id: UUID?, result: String = "Single") -> StableIdentityEvidence {
        StableIdentityEvidence(
            concept: .scoringEvent,
            importedIdentifier: id.map { .valid($0) } ?? .missing,
            displayEvidence: [.init("result", result)]
        )
    }

    static func sourceFixtureURL(
        directory: String,
        filename: String,
        callerFilePath: String = #filePath
    ) -> URL {
        var url = URL(fileURLWithPath: callerFilePath)
        for _ in 0..<2 {
            url.deleteLastPathComponent()
        }
        url.appendPathComponent("ScoreKeep/Docs/Verification/Fixtures")
        url.appendPathComponent(directory)
        url.appendPathComponent(filename)
        return url
    }
}

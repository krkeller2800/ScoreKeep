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
        if let url = try? repositoryURL("ScoreKeep/Docs/Verification/Fixtures/\(directory)/\(filename)", callerFilePath: callerFilePath) {
            return url
        }
        return URL(fileURLWithPath: callerFilePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ScoreKeep/Docs/Verification/Fixtures")
            .appendingPathComponent(directory)
            .appendingPathComponent(filename)
    }

    static func repositoryURL(_ relativePath: String, callerFilePath: String = #filePath) throws -> URL {
        let root = try repositoryRoot(callerFilePath: callerFilePath)
        return relativePath.split(separator: "/").reduce(root) { url, component in
            url.appendingPathComponent(String(component))
        }
    }

    static func repositorySource(_ relativePath: String, callerFilePath: String = #filePath) throws -> String {
        try String(contentsOf: repositoryURL(relativePath, callerFilePath: callerFilePath), encoding: .utf8)
    }

    static func repositoryRoot(callerFilePath: String = #filePath) throws -> URL {
        var candidates: [URL] = []
        for key in ["SRCROOT", "SOURCE_ROOT", "PROJECT_DIR", "PROJECT_FILE_PATH", "PWD"] {
            if let value = ProcessInfo.processInfo.environment[key], value.isEmpty == false {
                candidates.append(URL(fileURLWithPath: value))
            }
        }
        candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        candidates.append(URL(fileURLWithPath: callerFilePath))
        if callerFilePath.hasPrefix("/") == false {
            candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(callerFilePath))
        }

        for candidate in candidates {
            if let root = repositoryRoot(containing: candidate) {
                return root
            }
        }
        throw StableIdentityAndOrderingTestSupportError.repositoryRootNotFound
    }

    private static func repositoryRoot(containing candidate: URL) -> URL? {
        let fileManager = FileManager.default
        var url = candidate.standardizedFileURL
        if url.pathExtension == "xcodeproj" {
            url.deleteLastPathComponent()
        }
        if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            url.deleteLastPathComponent()
        }
        for _ in 0..<12 {
            let project = url.appendingPathComponent("ScoreKeep.xcodeproj")
            let app = url.appendingPathComponent("ScoreKeep/ScoreKeepApp.swift")
            if fileManager.fileExists(atPath: project.path), fileManager.fileExists(atPath: app.path) {
                return url
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return nil
    }
}

enum StableIdentityAndOrderingTestSupportError: Error {
    case repositoryRootNotFound
}

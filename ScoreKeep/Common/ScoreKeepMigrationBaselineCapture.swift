import Foundation
import SwiftData
import CryptoKit

struct ScoreKeepMigrationBaselineRecord: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let schemaClassification: String
    let gameCount: Int
    let teamCount: Int
    let playerCount: Int
    let lineupCount: Int
    let atbatCount: Int
    let pitcherCount: Int
    let teamCreationOperationEvidenceCount: Int
    let canonicalHistoryCount: Int
    let canonicalEventCount: Int
    let canonicalPayloadCount: Int
    let canonicalOperationCount: Int
    let canonicalCorrectionCount: Int
    let legacyScoringOperationEvidenceCount: Int
    let stableIdentityFingerprint: String
    let relationshipFingerprint: String
    let orderingFingerprint: String
    let scoreEvidence: String
    let substitutionEvidence: String
    let mediaOwnershipFingerprint: String
    let importSourceClassification: String
    let difficultRunnerSequence: ScoreKeepDifficultRunnerSequenceEvidence
    let capturedAt: Date
    let status: String
    let diagnosticCodes: [String]

    var summary: String {
        [
            "Baseline: \(status)",
            "Schema: \(schemaClassification)",
            "Counts: games=\(gameCount), teams=\(teamCount), players=\(playerCount), lineups=\(lineupCount), atbats=\(atbatCount), pitchers=\(pitcherCount), teamOps=\(teamCreationOperationEvidenceCount), canonicalHistories=\(canonicalHistoryCount), canonicalEvents=\(canonicalEventCount), canonicalPayloads=\(canonicalPayloadCount), canonicalOps=\(canonicalOperationCount), canonicalCorrections=\(canonicalCorrectionCount), legacyScoringOps=\(legacyScoringOperationEvidenceCount)",
            "Score: \(scoreEvidence)",
            "Substitutions: \(substitutionEvidence)",
            "Runner Sequence: \(difficultRunnerSequence.status)",
            "Codes: \(diagnosticCodes.joined(separator: ","))"
        ].joined(separator: "\n")
    }
}

struct ScoreKeepDifficultRunnerSequenceEvidence: Codable, Hashable, Sendable {
    let status: String
    let runnerIdentityFingerprint: String?
    let originatingAtbatFingerprint: String?
    let interveningAtbatOrderFingerprint: String?
    let runnerOutEvidence: String
    let thirdOutClassification: String
    let inningBoundary: String
    let nextBatterEvidence: String
    let scoreBeforeBoundary: String
    let scoreAfterBoundary: String
    let unsupportedFacts: [String]
}

enum ScoreKeepMigrationBaselineCaptureError: Error, LocalizedError {
    case unavailableOutsideLegacyMigrationTest
    case invalidBundleIdentity
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .unavailableOutsideLegacyMigrationTest:
            return "Baseline capture is available only in Legacy migration-test mode."
        case .invalidBundleIdentity:
            return "Baseline capture requires the disposable migration-test bundle identity."
        case .writeFailed:
            return "Baseline capture could not write its test-only sidecar."
        }
    }
}

enum ScoreKeepMigrationBaselineLoadResult: Hashable, Sendable {
    case loaded(ScoreKeepMigrationBaselineRecord)
    case missing
    case corrupt

    var record: ScoreKeepMigrationBaselineRecord? {
        if case .loaded(let record) = self { return record }
        return nil
    }

    var statusMessage: String {
        switch self {
        case .loaded(let record):
            return record.status
        case .missing:
            return "Baseline missing"
        case .corrupt:
            return "Baseline corrupt or unsupported"
        }
    }
}

@MainActor
enum ScoreKeepMigrationBaselineCapture {
    static func capture(
        modelContext: ModelContext,
        safety: ScoreKeepPhysicalMigrationTestSafety = ScoreKeepPhysicalMigrationTestSafety.evaluate(),
        fileManager: FileManager = .default,
        applicationSupportRoot: URL? = nil
    ) throws -> ScoreKeepMigrationBaselineRecord {
        guard safety.mode == .legacyStore else { throw ScoreKeepMigrationBaselineCaptureError.unavailableOutsideLegacyMigrationTest }
        guard safety.identity.isDisposableMigrationTestIdentity else { throw ScoreKeepMigrationBaselineCaptureError.invalidBundleIdentity }

        let record = try makeRecord(modelContext: modelContext)
        try persist(record, fileManager: fileManager, applicationSupportRoot: applicationSupportRoot)
        return record
    }

    static func makeRecord(modelContext: ModelContext) throws -> ScoreKeepMigrationBaselineRecord {
        let games = try modelContext.fetch(FetchDescriptor<Game>())
        let teams = try modelContext.fetch(FetchDescriptor<Team>())
        let players = try modelContext.fetch(FetchDescriptor<Player>())
        let lineups = try modelContext.fetch(FetchDescriptor<Lineup>())
        let atbats = try modelContext.fetch(FetchDescriptor<Atbat>())
        let pitchers = try modelContext.fetch(FetchDescriptor<Pitcher>())
        let teamCreationOperationEvidenceCount = try optionalRecordCount(TeamCreationOperationEvidenceRecord.self, in: modelContext)
        let canonicalHistoryCount = try optionalRecordCount(CanonicalGameHistoryRecord.self, in: modelContext)
        let canonicalEventCount = try optionalRecordCount(CanonicalScoringEventEnvelopeRecord.self, in: modelContext)
        let canonicalPayloadCount = try optionalRecordCount(CanonicalScoringEventPayloadRecord.self, in: modelContext)
        let canonicalOperationCount = try optionalRecordCount(CanonicalScoringOperationEvidenceRecord.self, in: modelContext)
        let canonicalCorrectionCount = try optionalRecordCount(CanonicalScoringCorrectionRecord.self, in: modelContext)
        let legacyScoringOperationEvidenceCount = try optionalRecordCount(LegacyScoringOperationEvidenceRecord.self, in: modelContext)

        return ScoreKeepMigrationBaselineRecord(
            schemaVersion: 1,
            schemaClassification: "currentUnversionedLegacySwiftData",
            gameCount: games.count,
            teamCount: teams.count,
            playerCount: players.count,
            lineupCount: lineups.count,
            atbatCount: atbats.count,
            pitcherCount: pitchers.count,
            teamCreationOperationEvidenceCount: teamCreationOperationEvidenceCount,
            canonicalHistoryCount: canonicalHistoryCount,
            canonicalEventCount: canonicalEventCount,
            canonicalPayloadCount: canonicalPayloadCount,
            canonicalOperationCount: canonicalOperationCount,
            canonicalCorrectionCount: canonicalCorrectionCount,
            legacyScoringOperationEvidenceCount: legacyScoringOperationEvidenceCount,
            stableIdentityFingerprint: stableIdentityFingerprint(games: games, teams: teams, players: players, lineups: lineups, atbats: atbats, pitchers: pitchers),
            relationshipFingerprint: relationshipFingerprint(games: games, teams: teams, players: players, lineups: lineups, atbats: atbats, pitchers: pitchers),
            orderingFingerprint: orderingFingerprint(games: games, lineups: lineups, atbats: atbats, pitchers: pitchers),
            scoreEvidence: scoreEvidence(games: games),
            substitutionEvidence: substitutionEvidence(games: games),
            mediaOwnershipFingerprint: mediaOwnershipFingerprint(teams: teams, players: players),
            importSourceClassification: importSourceClassification(games: games, teams: teams),
            difficultRunnerSequence: difficultRunnerSequenceEvidence(games: games),
            capturedAt: Date(),
            status: baselineStatus(games: games, teams: teams, players: players, atbats: atbats),
            diagnosticCodes: diagnosticCodes(games: games, teams: teams, players: players, atbats: atbats)
        )
    }

    static func load(fileManager: FileManager = .default, applicationSupportRoot: URL? = nil) -> ScoreKeepMigrationBaselineRecord? {
        loadResult(fileManager: fileManager, applicationSupportRoot: applicationSupportRoot).record
    }

    static func loadResult(fileManager: FileManager = .default, applicationSupportRoot: URL? = nil) -> ScoreKeepMigrationBaselineLoadResult {
        let url = ScoreKeepPhysicalDeviceDiagnostics.baselineSidecarURL(fileManager: fileManager, applicationSupportRoot: applicationSupportRoot)
        guard fileManager.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url) else { return .corrupt }
        do {
            return .loaded(try decoder().decode(ScoreKeepMigrationBaselineRecord.self, from: data))
        } catch {
            return .corrupt
        }
    }

    static func optionalRecordCount(entityName: String, schema: Schema, fetchCount: () throws -> Int) rethrows -> Int {
        guard schema.entitiesByName[entityName] != nil else { return 0 }
        return try fetchCount()
    }

    private static func optionalRecordCount<T: PersistentModel>(_ modelType: T.Type, in modelContext: ModelContext) throws -> Int {
        try optionalRecordCount(entityName: String(describing: modelType), schema: modelContext.container.schema) {
            try modelContext.fetch(FetchDescriptor<T>()).count
        }
    }

    private static func persist(_ record: ScoreKeepMigrationBaselineRecord, fileManager: FileManager, applicationSupportRoot: URL?) throws {
        let url = ScoreKeepPhysicalDeviceDiagnostics.baselineSidecarURL(fileManager: fileManager, applicationSupportRoot: applicationSupportRoot)
        let directory = url.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder().encode(record)
            try data.write(to: url, options: [.atomic])
            _ = try decoder().decode(ScoreKeepMigrationBaselineRecord.self, from: Data(contentsOf: url))
        } catch {
            throw ScoreKeepMigrationBaselineCaptureError.writeFailed
        }
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func stableIdentityFingerprint(games: [Game], teams: [Team], players: [Player], lineups: [Lineup], atbats: [Atbat], pitchers: [Pitcher]) -> String {
        fingerprint([
            "games:" + games.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            "teams:" + teams.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            "players:" + players.map { $0.identifier.uuidString }.sorted().joined(separator: ","),
            "lineups:" + lineups.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            "atbats:" + atbats.map { $0.ident.uuidString }.sorted().joined(separator: ","),
            "pitchers:" + pitchers.map { $0.ident.uuidString }.sorted().joined(separator: ",")
        ])
    }

    private static func relationshipFingerprint(games: [Game], teams: [Team], players: [Player], lineups: [Lineup], atbats: [Atbat], pitchers: [Pitcher]) -> String {
        var evidence: [String] = []
        evidence += games.map { game in
            "game:\(game.ident.uuidString):h=\(game.hteam?.ident.uuidString ?? "nil"):v=\(game.vteam?.ident.uuidString ?? "nil"):players=\(game.players.count):atbats=\(game.atbats.count):lineups=\(game.lineups.count):pitchers=\(game.pitchers.count)"
        }
        evidence += teams.map { "team:\($0.ident.uuidString):players=\($0.players.count):games=\($0.games.count)" }
        evidence += players.map { "player:\($0.identifier.uuidString):team=\($0.team?.ident.uuidString ?? "nil"):atbats=\($0.atbat.count)" }
        evidence += lineups.map { "lineup:\($0.ident.uuidString):game=\($0.game.ident.uuidString):team=\($0.team.ident.uuidString):players=\($0.players.count)" }
        evidence += atbats.map { "atbat:\($0.ident.uuidString):game=\($0.game.ident.uuidString):team=\($0.team.ident.uuidString):player=\($0.player.identifier.uuidString)" }
        evidence += pitchers.map { "pitcher:\($0.ident.uuidString):game=\($0.game.ident.uuidString):team=\($0.team.ident.uuidString):player=\($0.player.identifier.uuidString)" }
        return fingerprint(evidence.sorted())
    }

    private static func orderingFingerprint(games: [Game], lineups: [Lineup], atbats: [Atbat], pitchers: [Pitcher]) -> String {
        var evidence: [String] = []
        evidence += games.map { game in
            let orderedAtbats = game.atbats.map { "\($0.inning):\($0.seq):\($0.col):\($0.ident.uuidString)" }.sorted().joined(separator: "|")
            return "game:\(game.ident.uuidString):\(orderedAtbats)"
        }
        evidence += lineups.map { lineup in
            "lineup:\(lineup.ident.uuidString):inning=\(lineup.inning):players=\(orderedLineupPlayerEvidence(lineup.players))"
        }
        evidence += pitchers.map { "pitcher:\($0.ident.uuidString):start=\($0.startInn).\($0.sOuts).\($0.sBats):end=\($0.endInn).\($0.eOuts).\($0.eBats)" }
        evidence += atbats.map { "atbat:\($0.ident.uuidString):inning=\($0.inning):seq=\($0.seq):col=\($0.col):batOrder=\($0.batOrder)" }
        return fingerprint(evidence.sorted())
    }

    private static func orderedLineupPlayerEvidence(_ players: [Player]) -> String {
        players
            .sorted {
                if $0.batOrder == $1.batOrder {
                    return $0.identifier.uuidString < $1.identifier.uuidString
                }
                return $0.batOrder < $1.batOrder
            }
            .map { "\($0.batOrder):\($0.identifier.uuidString)" }
            .joined(separator: ",")
    }

    private static func scoreEvidence(games: [Game]) -> String {
        fingerprint(games.map { "\($0.ident.uuidString):h=\($0.hscore):v=\($0.vscore):innings=\($0.numInnings)" }.sorted())
    }

    private static func substitutionEvidence(games: [Game]) -> String {
        let values = games.map { game in
            "\(game.ident.uuidString):replaced=\(unorderedPlayerIdentityEvidence(game.replaced)):incoming=\(unorderedPlayerIdentityEvidence(game.incomings))"
        }
        return fingerprint(values.sorted())
    }

    private static func unorderedPlayerIdentityEvidence(_ players: [Player]) -> String {
        players
            .map { $0.identifier.uuidString }
            .sorted()
            .joined(separator: ",")
    }

    private static func mediaOwnershipFingerprint(teams: [Team], players: [Player]) -> String {
        var evidence: [String] = []
        evidence += teams.map { "team:\($0.ident.uuidString):logo=\(dataFingerprint($0.logo))" }
        evidence += players.map { "player:\($0.identifier.uuidString):photo=\(dataFingerprint($0.photo))" }
        return fingerprint(evidence.sorted())
    }

    private static func importSourceClassification(games: [Game], teams: [Team]) -> String {
        if games.isEmpty && teams.isEmpty { return "emptyOrNotYetImported" }
        if games.isEmpty { return "rosterOnlyOrTeamsOnly" }
        if teams.isEmpty { return "gameRecordsWithoutTeamFetchEvidence" }
        return "legacyCompatibilityImportsPresent"
    }

    private static func difficultRunnerSequenceEvidence(games: [Game]) -> ScoreKeepDifficultRunnerSequenceEvidence {
        for game in games {
            let sortedAtbats = game.atbats.sorted { lhs, rhs in
                if lhs.inning == rhs.inning { return lhs.seq == rhs.seq ? lhs.col < rhs.col : lhs.seq < rhs.seq }
                return lhs.inning < rhs.inning
            }
            guard let boundary = sortedAtbats.first(where: { $0.endOfInning && $0.outs >= 3 }) else { continue }
            let sameInningBefore = sortedAtbats.filter { $0.inning == boundary.inning && ($0.seq < boundary.seq || ($0.seq == boundary.seq && $0.col <= boundary.col)) }
            let intervening = sameInningBefore.dropLast().map { $0.ident.uuidString }
            let next = sortedAtbats.first { $0.inning > boundary.inning }
            let runnerOutSupported = boundary.outAt.isEmpty == false || boundary.playRec.localizedCaseInsensitiveContains("out")
            return ScoreKeepDifficultRunnerSequenceEvidence(
                status: runnerOutSupported && intervening.count > 0 ? "candidateThirdOutSequenceCaptured" : "thirdOutBoundaryCapturedWithAmbiguity",
                runnerIdentityFingerprint: runnerOutSupported ? dataFingerprint(Data(boundary.player.identifier.uuidString.utf8)) : nil,
                originatingAtbatFingerprint: sameInningBefore.first.map { dataFingerprint(Data($0.ident.uuidString.utf8)) },
                interveningAtbatOrderFingerprint: intervening.isEmpty ? nil : fingerprint(intervening),
                runnerOutEvidence: boundary.outAt.isEmpty ? "playRecordOrUnsupported" : "outAtPresent",
                thirdOutClassification: boundary.outs >= 3 ? "thirdOut" : "unsupported",
                inningBoundary: "inning=\(boundary.inning):endOfInning=\(boundary.endOfInning)",
                nextBatterEvidence: next.map { "inning=\($0.inning):batOrder=\($0.batOrder)" } ?? "unsupportedOrGameComplete",
                scoreBeforeBoundary: "h=\(game.hscore):v=\(game.vscore)",
                scoreAfterBoundary: "storedFinal:h=\(game.hscore):v=\(game.vscore)",
                unsupportedFacts: runnerOutSupported ? [] : ["exactRunnerContinuityAcrossInterveningBattersUnsupportedByCompactLegacyModel"]
            )
        }
        return ScoreKeepDifficultRunnerSequenceEvidence(
            status: "notFoundOrNotYetImported",
            runnerIdentityFingerprint: nil,
            originatingAtbatFingerprint: nil,
            interveningAtbatOrderFingerprint: nil,
            runnerOutEvidence: "notFound",
            thirdOutClassification: "notFound",
            inningBoundary: "notFound",
            nextBatterEvidence: "notFound",
            scoreBeforeBoundary: "notFound",
            scoreAfterBoundary: "notFound",
            unsupportedFacts: ["fixtureNotImportedOrLegacyEvidenceInsufficient"]
        )
    }

    private static func baselineStatus(games: [Game], teams: [Team], players: [Player], atbats: [Atbat]) -> String {
        if games.count >= 1 && teams.count >= 3 && players.count > 0 && atbats.count > 0 {
            return "completeOrReviewAmbiguity"
        }
        return "incompleteImports"
    }

    private static func diagnosticCodes(games: [Game], teams: [Team], players: [Player], atbats: [Atbat]) -> [String] {
        var codes = ["baseline.capture.completed"]
        if games.isEmpty { codes.append("baseline.noGames") }
        if teams.count < 3 { codes.append("baseline.expectedIndependentRosterPending") }
        if players.isEmpty { codes.append("baseline.noPlayers") }
        if atbats.isEmpty { codes.append("baseline.noAtbats") }
        return codes
    }

    static func baselineMismatchDiagnosticLines(expected: ScoreKeepMigrationBaselineRecord, actual: ScoreKeepMigrationBaselineRecord) -> [String] {
        var lines: [String] = []
        appendMismatch("gameCount", expected.gameCount, actual.gameCount, to: &lines)
        appendMismatch("teamCount", expected.teamCount, actual.teamCount, to: &lines)
        appendMismatch("playerCount", expected.playerCount, actual.playerCount, to: &lines)
        appendMismatch("lineupCount", expected.lineupCount, actual.lineupCount, to: &lines)
        appendMismatch("atbatCount", expected.atbatCount, actual.atbatCount, to: &lines)
        appendMismatch("pitcherCount", expected.pitcherCount, actual.pitcherCount, to: &lines)
        appendMismatch("teamCreationOperationEvidenceCount", expected.teamCreationOperationEvidenceCount, actual.teamCreationOperationEvidenceCount, to: &lines)
        appendMismatch("canonicalHistoryCount", expected.canonicalHistoryCount, actual.canonicalHistoryCount, to: &lines)
        appendMismatch("canonicalEventCount", expected.canonicalEventCount, actual.canonicalEventCount, to: &lines)
        appendMismatch("canonicalPayloadCount", expected.canonicalPayloadCount, actual.canonicalPayloadCount, to: &lines)
        appendMismatch("canonicalOperationCount", expected.canonicalOperationCount, actual.canonicalOperationCount, to: &lines)
        appendMismatch("canonicalCorrectionCount", expected.canonicalCorrectionCount, actual.canonicalCorrectionCount, to: &lines)
        appendMismatch("legacyScoringOperationEvidenceCount", expected.legacyScoringOperationEvidenceCount, actual.legacyScoringOperationEvidenceCount, to: &lines)
        appendMismatch("stableIdentityFingerprint", expected.stableIdentityFingerprint, actual.stableIdentityFingerprint, to: &lines)
        appendMismatch("relationshipFingerprint", expected.relationshipFingerprint, actual.relationshipFingerprint, to: &lines)
        appendMismatch("orderingFingerprint", expected.orderingFingerprint, actual.orderingFingerprint, to: &lines)
        appendMismatch("scoreEvidence", expected.scoreEvidence, actual.scoreEvidence, to: &lines)
        appendMismatch("substitutionEvidence", expected.substitutionEvidence, actual.substitutionEvidence, to: &lines)
        appendMismatch("mediaOwnershipFingerprint", expected.mediaOwnershipFingerprint, actual.mediaOwnershipFingerprint, to: &lines)
        appendMismatch("importSourceClassification", expected.importSourceClassification, actual.importSourceClassification, to: &lines)
        appendMismatch("difficultRunnerSequence.status", expected.difficultRunnerSequence.status, actual.difficultRunnerSequence.status, to: &lines)
        appendMismatch("difficultRunnerSequence.runnerIdentityFingerprint", expected.difficultRunnerSequence.runnerIdentityFingerprint, actual.difficultRunnerSequence.runnerIdentityFingerprint, to: &lines)
        appendMismatch("difficultRunnerSequence.originatingAtbatFingerprint", expected.difficultRunnerSequence.originatingAtbatFingerprint, actual.difficultRunnerSequence.originatingAtbatFingerprint, to: &lines)
        appendMismatch("difficultRunnerSequence.interveningAtbatOrderFingerprint", expected.difficultRunnerSequence.interveningAtbatOrderFingerprint, actual.difficultRunnerSequence.interveningAtbatOrderFingerprint, to: &lines)
        appendMismatch("difficultRunnerSequence.runnerOutEvidence", expected.difficultRunnerSequence.runnerOutEvidence, actual.difficultRunnerSequence.runnerOutEvidence, to: &lines)
        appendMismatch("difficultRunnerSequence.thirdOutClassification", expected.difficultRunnerSequence.thirdOutClassification, actual.difficultRunnerSequence.thirdOutClassification, to: &lines)
        appendMismatch("difficultRunnerSequence.inningBoundary", expected.difficultRunnerSequence.inningBoundary, actual.difficultRunnerSequence.inningBoundary, to: &lines)
        appendMismatch("difficultRunnerSequence.nextBatterEvidence", expected.difficultRunnerSequence.nextBatterEvidence, actual.difficultRunnerSequence.nextBatterEvidence, to: &lines)
        appendMismatch("difficultRunnerSequence.scoreBeforeBoundary", expected.difficultRunnerSequence.scoreBeforeBoundary, actual.difficultRunnerSequence.scoreBeforeBoundary, to: &lines)
        appendMismatch("difficultRunnerSequence.scoreAfterBoundary", expected.difficultRunnerSequence.scoreAfterBoundary, actual.difficultRunnerSequence.scoreAfterBoundary, to: &lines)
        appendMismatch("difficultRunnerSequence.unsupportedFacts", expected.difficultRunnerSequence.unsupportedFacts.joined(separator: ","), actual.difficultRunnerSequence.unsupportedFacts.joined(separator: ","), to: &lines)
        return lines.isEmpty ? ["baselineMismatch.fields=none"] : Array(lines.prefix(48))
    }

    private static func appendMismatch<T: CustomStringConvertible>(_ field: String, _ expected: T, _ actual: T, to lines: inout [String]) where T: Equatable {
        guard expected != actual else { return }
        lines.append("baselineMismatch.field=\(field);expected=\(expected.description);actual=\(actual.description)")
    }

    private static func appendMismatch(_ field: String, _ expected: String, _ actual: String, to lines: inout [String]) {
        guard expected != actual else { return }
        lines.append("baselineMismatch.field=\(field);expected=\(redactedDiagnosticValue(expected));actual=\(redactedDiagnosticValue(actual))")
    }

    private static func appendMismatch(_ field: String, _ expected: String?, _ actual: String?, to lines: inout [String]) {
        guard expected != actual else { return }
        lines.append("baselineMismatch.field=\(field);expected=\(redactedDiagnosticValue(expected));actual=\(redactedDiagnosticValue(actual))")
    }

    private static func redactedDiagnosticValue(_ value: String?) -> String {
        guard let value else { return "nil" }
        return "len=\(value.count),fingerprint=\(dataFingerprint(Data(value.utf8)))"
    }

    private static func dataFingerprint(_ data: Data?) -> String {
        guard let data, data.isEmpty == false else { return "absent" }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    private static func fingerprint(_ values: [String]) -> String {
        dataFingerprint(Data(values.joined(separator: "\n").utf8))
    }
}

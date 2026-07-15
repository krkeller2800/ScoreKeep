import Foundation
@testable import ScoreKeep

enum LegacyCanonicalComparisonOutcome: String, Hashable, Sendable {
    case agreement
    case agreementWithWarnings
    case explainableDifference
    case legacyOnlyEvidence
    case rewrittenOnlyEvidence
    case unsupportedComparison
    case incompleteComparison
    case ambiguousComparison
    case contradictoryComparison
    case unsafeComparison
    case requiresReview
}

enum LegacyCanonicalEvidenceClassification: String, Hashable, Sendable {
    case canonicalReplayInput
    case legacyStoredFact
    case legacyDerivedValue
    case reportDerivedLegacyEvidence
    case compatibilityTransportEvidence
    case supportedComparison
    case explainableMismatch
    case unsupportedEvidence
    case incompleteEvidence
    case ambiguousEvidence
    case contradictoryEvidence
    case unsafeComparison
    case legacyImplementationDetail
}

struct LegacyCanonicalComparisonDifference: Hashable, Sendable {
    let code: String
    let outcome: LegacyCanonicalComparisonOutcome
    let classification: LegacyCanonicalEvidenceClassification
    let explanation: String
}

struct LegacyCanonicalComparedDimension: Hashable, Sendable {
    let name: String
    let outcome: LegacyCanonicalComparisonOutcome
    let classification: LegacyCanonicalEvidenceClassification
    let diagnosticCodes: [String]
}

struct LegacyCanonicalScoringComparisonResult: Hashable, Sendable {
    let scenarioIdentity: String
    let overallOutcome: LegacyCanonicalComparisonOutcome
    let evidenceClassifications: Set<LegacyCanonicalEvidenceClassification>
    let dimensions: [LegacyCanonicalComparedDimension]
    let differences: [LegacyCanonicalComparisonDifference]
    let readOnlyComparisonCompleted: Bool
    let suitableForCutoverEvaluation: Bool
    let requiresRepairOrUnsupportedHandling: Bool
}

struct LegacyReportDerivedEvidence: Hashable, Sendable {
    let homeRuns: Int
    let visitingRuns: Int
    let hits: Int
    let runsBattedIn: Int
    let strikeouts: Int
    let walks: Int
}

enum LegacyCanonicalScoringComparisonSupport {
    static let validFixtureNames = [
        "MinimalValid.ScoreKeep_Games",
        "InProgressGame.ScoreKeep_Games",
        "CompletedGame.ScoreKeep_Games",
        "MultipleAtbats.ScoreKeep_Games",
        "LineupGame.ScoreKeep_Games",
        "PitcherGame.ScoreKeep_Games",
        "MissingOptionalValues.ScoreKeep_Games"
    ]

    static let malformedFixtureNames = [
        "BrokenAtbatRelationship.ScoreKeep_Games",
        "BrokenLineupRelationship.ScoreKeep_Games",
        "BrokenPitcherRelationship.ScoreKeep_Games",
        "DuplicateAtbatID.ScoreKeep_Games",
        "UnsupportedScoreValue.ScoreKeep_Games"
    ]

    static func compareValidFixture(_ filename: String) throws -> LegacyCanonicalScoringComparisonResult {
        let before = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "ScoreKeep_Games", filename: filename)
        let game = try JSONDecoder().decode(ShareGame.self, from: before)
        let result = compare(game: game, scenarioIdentity: filename)
        let after = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "ScoreKeep_Games", filename: filename)
        precondition(before == after)
        return result
    }

    static func compareMalformedFixture(_ filename: String) throws -> LegacyCanonicalScoringComparisonResult {
        let before = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: filename)
        let game = try JSONDecoder().decode(ShareGame.self, from: before)
        let result = compare(game: game, scenarioIdentity: filename)
        let after = try CanonicalTeamMeaningTestSupport.fixtureData(directory: "MalformedAndUnsupported", filename: filename)
        precondition(before == after)
        return result
    }

    static func compareUnsupportedResultScenario() -> LegacyCanonicalScoringComparisonResult {
        let game = syntheticGame(
            id: StableIdentityAndOrderingTestSupport.fixedUUID("67000000-0000-0000-0000-000000000001"),
            filename: "SyntheticUnsupportedResult",
            hscore: 0,
            vscore: 0,
            atbats: [syntheticAtbat(sequence: 1, result: "Moon Shot", maxbase: "Moon", teamSide: .visiting)]
        )
        return compare(game: game, scenarioIdentity: "SyntheticUnsupportedResult")
    }

    static func compareDuplicateEventIdentityScenario() -> LegacyCanonicalScoringComparisonResult {
        let sharedID = StableIdentityAndOrderingTestSupport.fixedUUID("67000000-0000-0000-0000-000000000099")
        let first = syntheticAtbat(id: sharedID, sequence: 1, result: "Single", maxbase: "First", teamSide: .visiting)
        let second = syntheticAtbat(id: sharedID, sequence: 2, result: "Ground Out", maxbase: "", teamSide: .visiting)
        let game = syntheticGame(
            id: StableIdentityAndOrderingTestSupport.fixedUUID("67000000-0000-0000-0000-000000000002"),
            filename: "SyntheticDuplicateEventIdentity",
            hscore: 0,
            vscore: 0,
            atbats: [first, second]
        )
        return compare(game: game, scenarioIdentity: "SyntheticDuplicateEventIdentity")
    }

    static func compare(game: ShareGame, scenarioIdentity: String) -> LegacyCanonicalScoringComparisonResult {
        let mapping = LegacyCanonicalVerificationMapper.mapGame(game, sourceLocation: scenarioIdentity)
        let events = scoringEvents(from: game)
        let replayInput = replayInput(from: game, mapping: mapping, events: events)
        let replay = CanonicalGameReplay.replay(replayInput)
        let reportEvidence = reportDerivedEvidence(from: game)
        let duplicateEventIdentity = hasDuplicateValidIdentity(events.map(\.eventIdentity))
        let duplicateSequence = hasDuplicateSequence(events)
        let unsupportedRaw = mapping.scoringEvents.flatMap(\.unsupportedRawEvidence) + replay.eventSummaries.flatMap(\.unsupportedRawClassification)
        let relationshipIssues = mapping.validation.findings.filter { finding in
            finding.code.contains("relationship") || finding.code.contains("side") || finding.code.contains("team") || finding.code.contains("player") || finding.code.contains("pitcher") || finding.code.contains("lineup")
        }
        let brokenPitcherRelationships = game.pitchers.filter { pitcher in
            teamSide(for: pitcher.team.id, in: game) == nil || game.players.contains(where: { $0.id == pitcher.player.id }) == false
        }

        var dimensions: [LegacyCanonicalComparedDimension] = []
        var differences: [LegacyCanonicalComparisonDifference] = []
        var classifications: Set<LegacyCanonicalEvidenceClassification> = [.compatibilityTransportEvidence, .canonicalReplayInput, .legacyStoredFact]

        dimensions.append(LegacyCanonicalComparedDimension(
            name: "gameIdentity",
            outcome: mapping.game.sourceIdentity == .valid(game.id) ? .agreement : .contradictoryComparison,
            classification: .supportedComparison,
            diagnosticCodes: []
        ))

        dimensions.append(LegacyCanonicalComparedDimension(
            name: "eventCount",
            outcome: mapping.scoringEvents.count == game.atbats.count && events.count == game.atbats.count ? .agreement : .incompleteComparison,
            classification: .supportedComparison,
            diagnosticCodes: []
        ))

        let orderingOutcome: LegacyCanonicalComparisonOutcome
        if duplicateSequence {
            orderingOutcome = .contradictoryComparison
            classifications.insert(.contradictoryEvidence)
            differences.append(difference("comparison.duplicateSequence", .contradictoryComparison, .contradictoryEvidence, "Legacy event sequence evidence contains duplicate values."))
        } else if duplicateEventIdentity {
            orderingOutcome = .contradictoryComparison
            classifications.insert(.contradictoryEvidence)
            differences.append(difference("comparison.duplicateEventIdentity", .contradictoryComparison, .contradictoryEvidence, "Legacy event identity evidence contains duplicates."))
        } else if events.count == game.atbats.count {
            orderingOutcome = .agreement
        } else {
            orderingOutcome = .incompleteComparison
            classifications.insert(.incompleteEvidence)
        }
        dimensions.append(LegacyCanonicalComparedDimension(name: "eventOrdering", outcome: orderingOutcome, classification: orderingOutcome == .agreement ? .supportedComparison : .contradictoryEvidence, diagnosticCodes: []))

        let storedScore = CanonicalProjectedScore(home: game.hscore, visiting: game.vscore)
        let scoreOutcome: LegacyCanonicalComparisonOutcome
        switch replay.storedScoreComparison {
        case .matchesStoredScore:
            scoreOutcome = replay.disposition == .complete ? .agreement : .agreementWithWarnings
            classifications.insert(.supportedComparison)
        case .differsFromStoredScore:
            scoreOutcome = .explainableDifference
            classifications.insert(.explainableMismatch)
            differences.append(difference("comparison.storedScoreMismatch", .explainableDifference, .explainableMismatch, "Stored score differs from replay-derived score."))
        case .storedScoreUnsupported:
            scoreOutcome = .unsupportedComparison
            classifications.insert(.unsupportedEvidence)
            differences.append(difference("comparison.unsupportedStoredScore", .unsupportedComparison, .unsupportedEvidence, "Stored score evidence is unsupported."))
        case .replayCannotEstablishScoreSafely:
            scoreOutcome = .unsafeComparison
            classifications.insert(.unsafeComparison)
            differences.append(difference("comparison.replayCannotEstablishScore", .unsafeComparison, .unsafeComparison, "Replay could not establish score safely for stored-score comparison."))
        case .reviewRequired:
            scoreOutcome = .requiresReview
            differences.append(difference("comparison.storedScoreReviewRequired", .requiresReview, .ambiguousEvidence, "Stored score comparison requires review."))
        case .notSupplied:
            scoreOutcome = storedScore == .init() ? .agreement : .legacyOnlyEvidence
        }
        dimensions.append(LegacyCanonicalComparedDimension(name: "storedScore", outcome: scoreOutcome, classification: scoreOutcome == .agreement ? .supportedComparison : .explainableMismatch, diagnosticCodes: []))

        let replayCodes = replay.validationFindings.map(\.code).sorted()
        let replayOutcome: LegacyCanonicalComparisonOutcome
        switch replay.disposition {
        case .complete:
            replayOutcome = .agreement
        case .completeWithWarnings:
            replayOutcome = .agreementWithWarnings
        case .partial, .incomplete:
            replayOutcome = .incompleteComparison
            classifications.insert(.incompleteEvidence)
        case .unsupported:
            replayOutcome = .unsupportedComparison
            classifications.insert(.unsupportedEvidence)
        case .rejected, .contradictory:
            replayOutcome = .unsafeComparison
            classifications.insert(.unsafeComparison)
        case .unresolved:
            replayOutcome = .ambiguousComparison
            classifications.insert(.ambiguousEvidence)
        }
        dimensions.append(LegacyCanonicalComparedDimension(name: "replayDisposition", outcome: replayOutcome, classification: replayOutcome == .agreement ? .supportedComparison : .incompleteEvidence, diagnosticCodes: replayCodes))

        if unsupportedRaw.isEmpty == false {
            dimensions.append(LegacyCanonicalComparedDimension(name: "unsupportedRawValues", outcome: .unsupportedComparison, classification: .unsupportedEvidence, diagnosticCodes: unsupportedRaw.sorted()))
            differences.append(difference("comparison.unsupportedRawEvidence", .unsupportedComparison, .unsupportedEvidence, "Unsupported raw legacy values were preserved for diagnostics."))
            classifications.insert(.unsupportedEvidence)
        }

        if relationshipIssues.isEmpty == false || mapping.validation.futureWriteMustStop || brokenPitcherRelationships.isEmpty == false {
            let outcome: LegacyCanonicalComparisonOutcome = mapping.validation.futureWriteMustStop ? .unsafeComparison : .requiresReview
            let classification: LegacyCanonicalEvidenceClassification = mapping.validation.futureWriteMustStop ? .unsafeComparison : .ambiguousEvidence
            let relationshipCodes = relationshipIssues.map(\.code).sorted() + brokenPitcherRelationships.map { _ in "comparison.brokenPitcherRelationship" }
            dimensions.append(LegacyCanonicalComparedDimension(name: "relationships", outcome: outcome, classification: classification, diagnosticCodes: relationshipCodes))
            differences.append(difference("comparison.relationshipEvidenceRequiresReview", outcome, classification, "Legacy relationship evidence is incomplete, contradictory, or unsafe for write routing."))
            classifications.insert(classification)
        }

        let reportOutcome: LegacyCanonicalComparisonOutcome
        if replay.disposition == .complete || replay.disposition == .completeWithWarnings {
            let replayRuns = replay.finalState.score.home + replay.finalState.score.visiting
            let reportRuns = reportEvidence.homeRuns + reportEvidence.visitingRuns
            if replayRuns == reportRuns {
                reportOutcome = .agreement
            } else {
                reportOutcome = .explainableDifference
                differences.append(difference("comparison.reportRunMismatch", .explainableDifference, .explainableMismatch, "Pure report-derived run count differs from replay-derived runs."))
                classifications.insert(.explainableMismatch)
            }
        } else {
            reportOutcome = .incompleteComparison
            classifications.insert(.incompleteEvidence)
        }
        dimensions.append(LegacyCanonicalComparedDimension(name: "reportDerivedRunsAndTotals", outcome: reportOutcome, classification: .reportDerivedLegacyEvidence, diagnosticCodes: ["hits=\(reportEvidence.hits)", "rbis=\(reportEvidence.runsBattedIn)", "strikeouts=\(reportEvidence.strikeouts)", "walks=\(reportEvidence.walks)"]))

        let requiresRepair = differences.contains { $0.outcome == .unsupportedComparison || $0.outcome == .unsafeComparison || $0.outcome == .contradictoryComparison || $0.outcome == .requiresReview }
        let overall = overallOutcome(dimensions: dimensions, differences: differences)
        return LegacyCanonicalScoringComparisonResult(
            scenarioIdentity: scenarioIdentity,
            overallOutcome: overall,
            evidenceClassifications: classifications,
            dimensions: dimensions,
            differences: differences,
            readOnlyComparisonCompleted: true,
            suitableForCutoverEvaluation: overall == .agreement || overall == .agreementWithWarnings || overall == .explainableDifference || overall == .incompleteComparison || overall == .unsupportedComparison || overall == .unsafeComparison,
            requiresRepairOrUnsupportedHandling: requiresRepair
        )
    }

    private static func replayInput(from game: ShareGame, mapping: LegacyCanonicalGameMapping, events: [CanonicalScoringEventEvidence]) -> CanonicalReplayInput {
        CanonicalReplayInput(
            game: mapping.game.canonicalValue ?? CanonicalGameStatePrimitivesTestSupport.importedGame(game),
            homeTeamIdentity: .valid(game.hteam.id),
            visitingTeamIdentity: .valid(game.vteam.id),
            initialBattingSide: .visiting,
            initialInning: CanonicalHalfInning(number: .known(1), half: .known(.top), expectedInnings: game.numInnings > 0 ? .known(game.numInnings) : .missing),
            initialOuts: CanonicalOutsState(outs: .known(0)),
            pitchers: pitcherInputs(from: mapping.pitcherAppearances.compactMap(\.canonicalValue)),
            recordedEvents: events,
            validationFindings: mapping.validation.findings.filter { $0.futureWriteMustStop == false },
            storedScore: CanonicalProjectedScore(home: game.hscore, visiting: game.vscore)
        )
    }

    private static func scoringEvents(from game: ShareGame) -> [CanonicalScoringEventEvidence] {
        game.atbats.enumerated().map { index, atbat in
            let snapshot = LegacyAtbatEvidenceSnapshot(atbat: atbat, fallbackGameIdentity: .valid(game.id), sourceIndex: index, sourceLocation: "legacyComparison.atbat")
            let mapped = LegacyCanonicalVerificationMapper.mapScoringEvent(snapshot, source: .compatibilityTransport)
            let base = mapped.canonicalValue
            return CanonicalScoringEventEvidence(
                eventIdentity: base?.eventIdentity ?? .valid(atbat.id),
                gameIdentity: .valid(game.id),
                orderingEvidence: base?.orderingEvidence ?? [.knownSequence(OrderEvidence(kind: .eventSequence, value: atbat.seq, sourceIndex: index))],
                inningContext: base?.inningContext,
                teamSide: teamSide(for: atbat.team.id, in: game),
                participants: base?.participants ?? ScoringEventParticipantEvidence(batter: nil, unresolvedRelationships: ["batter"]),
                resultEvidence: base?.resultEvidence ?? ScoringEventResultEvidence(rawValue: atbat.result),
                outsEvidence: base?.outsEvidence,
                batterAdvancement: base?.batterAdvancement,
                runnerAdvancement: base?.runnerAdvancement ?? [],
                rbiEvidence: base?.rbiEvidence ?? .count(atbat.rbis),
                earnedRunEvidence: base?.earnedRunEvidence ?? .flag(atbat.earnedRun),
                sacrificeEvidence: base?.sacrificeEvidence ?? .count(atbat.sacFly + atbat.sacBunt),
                stolenBaseEvidence: base?.stolenBaseEvidence ?? .count(atbat.stolenBases),
                endOfHalfEvidence: base?.endOfHalfEvidence ?? atbat.endOfInning,
                historicalDisplayEvidence: base?.historicalDisplayEvidence ?? [atbat.result],
                unsupportedRawLegacyEvidence: mapped.unsupportedRawEvidence,
                source: .compatibilityTransport
            )
        }
    }

    private static func pitcherInputs(from appearances: [CanonicalPitcherAppearanceEvidence]) -> [CanonicalReplayPitcherInput] {
        Dictionary(grouping: appearances, by: { $0.teamSide ?? .unresolved })
            .filter { $0.key != .unresolved }
            .map { CanonicalReplayPitcherInput(defensiveSide: $0.key, appearances: $0.value) }
            .sorted { $0.defensiveSide.rawValue < $1.defensiveSide.rawValue }
    }

    private static func reportDerivedEvidence(from game: ShareGame) -> LegacyReportDerivedEvidence {
        let common = Common()
        var homeRuns = 0
        var visitingRuns = 0
        var hits = 0
        var rbis = 0
        var strikeouts = 0
        var walks = 0
        for atbat in game.atbats {
            if atbat.maxbase == "Home" {
                if atbat.team.id == game.hteam.id { homeRuns += 1 } else if atbat.team.id == game.vteam.id { visitingRuns += 1 }
            }
            if common.hitresults.contains(atbat.result) { hits += 1 }
            if atbat.result == "Strikeout" || atbat.result == "Strikeout Looking" { strikeouts += 1 }
            if atbat.result == "Walk" { walks += 1 }
            rbis += atbat.rbis
        }
        return LegacyReportDerivedEvidence(homeRuns: homeRuns, visitingRuns: visitingRuns, hits: hits, runsBattedIn: rbis, strikeouts: strikeouts, walks: walks)
    }

    private static func teamSide(for teamID: UUID, in game: ShareGame) -> TeamSideRole? {
        if teamID == game.vteam.id { return .visiting }
        if teamID == game.hteam.id { return .home }
        return nil
    }

    private static func hasDuplicateValidIdentity(_ identities: [ImportedIdentifierEvidence]) -> Bool {
        let ids = identities.compactMap(\.validIdentifier)
        return Set(ids).count != ids.count
    }

    private static func hasDuplicateSequence(_ events: [CanonicalScoringEventEvidence]) -> Bool {
        let sequences = events.compactMap { event in
            event.orderingEvidence.compactMap { evidence -> Int? in
                if case let .knownSequence(order) = evidence { return order.value }
                return nil
            }.first
        }
        return Set(sequences).count != sequences.count
    }

    private static func difference(_ code: String, _ outcome: LegacyCanonicalComparisonOutcome, _ classification: LegacyCanonicalEvidenceClassification, _ explanation: String) -> LegacyCanonicalComparisonDifference {
        LegacyCanonicalComparisonDifference(code: code, outcome: outcome, classification: classification, explanation: explanation)
    }

    private static func overallOutcome(dimensions: [LegacyCanonicalComparedDimension], differences: [LegacyCanonicalComparisonDifference]) -> LegacyCanonicalComparisonOutcome {
        let outcomes = Set(dimensions.map(\.outcome) + differences.map(\.outcome))
        if outcomes.contains(.unsafeComparison) { return .unsafeComparison }
        if outcomes.contains(.contradictoryComparison) { return .contradictoryComparison }
        if outcomes.contains(.unsupportedComparison) { return .unsupportedComparison }
        if outcomes.contains(.requiresReview) { return .requiresReview }
        if outcomes.contains(.ambiguousComparison) { return .ambiguousComparison }
        if outcomes.contains(.incompleteComparison) { return .incompleteComparison }
        if outcomes.contains(.explainableDifference) { return .explainableDifference }
        if outcomes.contains(.agreementWithWarnings) { return .agreementWithWarnings }
        return .agreement
    }

    private static func syntheticGame(id: UUID, filename: String, hscore: Int, vscore: Int, atbats: [ShareAtbat]) -> ShareGame {
        ShareGame(
            id: id,
            date: "2026-04-20T18:00:00Z",
            location: filename,
            highLights: "Synthetic comparison evidence",
            hscore: hscore,
            vscore: vscore,
            everyOneHits: false,
            numInnings: 7,
            vteam: syntheticTeam(.visiting),
            hteam: syntheticTeam(.home),
            players: [syntheticPlayer(side: .visiting), syntheticPlayer(side: .home)],
            atbats: atbats,
            lineups: [],
            pitchers: [],
            replaced: [],
            incomings: []
        )
    }

    private static func syntheticAtbat(id: UUID = StableIdentityAndOrderingTestSupport.fixedUUID("67000000-0000-0000-0000-000000000010"), sequence: Int, result: String, maxbase: String, teamSide: TeamSideRole) -> ShareAtbat {
        ShareAtbat(
            id: id,
            game: nil,
            team: syntheticTeam(teamSide),
            player: syntheticPlayer(side: teamSide),
            result: result,
            maxbase: maxbase,
            batOrder: 1,
            outAt: "",
            inning: teamSide == .visiting ? 1 : 1.5,
            seq: sequence,
            col: sequence,
            rbis: maxbase == "Home" ? 1 : 0,
            outs: result.contains("Out") || result.contains("Strikeout") ? 1 : 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0,
            earnedRun: true,
            playRec: "",
            endOfInning: false
        )
    }

    private static func syntheticTeam(_ side: TeamSideRole) -> ShareTeam {
        ShareTeam(
            id: StableIdentityAndOrderingTestSupport.fixedUUID(side == .visiting ? "67000000-0000-0000-0000-000000000101" : "67000000-0000-0000-0000-000000000102"),
            name: side == .visiting ? "Synthetic Visitors" : "Synthetic Home",
            coach: "",
            details: "",
            players: [],
            games: [],
            logo: Data()
        )
    }

    private static func syntheticPlayer(side: TeamSideRole) -> SharePlayer {
        SharePlayer(
            id: StableIdentityAndOrderingTestSupport.fixedUUID(side == .visiting ? "67000000-0000-0000-0000-000000000201" : "67000000-0000-0000-0000-000000000202"),
            name: side == .visiting ? "Synthetic Visitor Batter" : "Synthetic Home Batter",
            number: "1",
            position: "",
            batDir: "",
            batOrder: 1,
            team: syntheticTeam(side),
            atbats: [],
            photo: Data()
        )
    }
}

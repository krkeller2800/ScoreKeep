import Foundation

/// Non-routed Phase 1 validation boundary for canonical baseball evidence.
/// Validation reports diagnostics only; it does not mutate, repair, route, persist, or generate identifiers.
enum CanonicalValidationDisposition: String, Hashable, Sendable, CaseIterable {
    case valid
    case validWithWarnings
    case incomplete
    case repairRecommended
    case repairRequired
    case unsupported
    case rejected
    case contradictory
    case unresolved

    var processingMayContinueReadOnly: Bool {
        switch self {
        case .valid, .validWithWarnings, .incomplete, .repairRecommended, .unsupported, .unresolved:
            return true
        case .repairRequired, .rejected, .contradictory:
            return false
        }
    }

    var futureWriteMustStop: Bool {
        switch self {
        case .repairRequired, .unsupported, .rejected, .contradictory, .unresolved:
            return true
        case .valid, .validWithWarnings, .incomplete, .repairRecommended:
            return false
        }
    }

    var explicitRepairRequired: Bool {
        self == .repairRequired || self == .contradictory
    }

    fileprivate var rank: Int {
        switch self {
        case .valid: return 0
        case .validWithWarnings: return 1
        case .incomplete: return 2
        case .repairRecommended: return 3
        case .unsupported: return 4
        case .unresolved: return 5
        case .repairRequired: return 6
        case .rejected: return 7
        case .contradictory: return 8
        }
    }
}

enum CanonicalValidationSeverity: String, Hashable, Sendable {
    case information
    case warning
    case incomplete
    case repair
    case unsupported
    case rejection
    case contradiction
    case unresolved
}

enum CanonicalValidationConcept: String, Hashable, Sendable, CaseIterable {
    case stableIdentity
    case ordering
    case team
    case gameSide
    case player
    case gameParticipant
    case rosterMembership
    case lineup
    case battingOrder
    case defensivePosition
    case game
    case inning
    case count
    case outs
    case baseOccupancy
    case scoringEvent
    case pitcherResponsibility
    case substitution
    case legacyMapping
    case compatibilityTransport
}

struct CanonicalValidationFinding: Hashable, Sendable {
    let code: String
    let concept: CanonicalValidationConcept
    let severity: CanonicalValidationSeverity
    let disposition: CanonicalValidationDisposition
    let summary: String
    let sourceLocation: String?
    let processingMayContinueReadOnly: Bool
    let futureWriteMustStop: Bool
    let explicitRepairRequired: Bool
    let unsupportedRatherThanMalformed: Bool

    init(
        code: String,
        concept: CanonicalValidationConcept,
        severity: CanonicalValidationSeverity,
        disposition: CanonicalValidationDisposition,
        summary: String,
        sourceLocation: String? = nil,
        unsupportedRatherThanMalformed: Bool = false
    ) {
        self.code = code
        self.concept = concept
        self.severity = severity
        self.disposition = disposition
        self.summary = summary
        self.sourceLocation = sourceLocation
        self.processingMayContinueReadOnly = disposition.processingMayContinueReadOnly
        self.futureWriteMustStop = disposition.futureWriteMustStop
        self.explicitRepairRequired = disposition.explicitRepairRequired
        self.unsupportedRatherThanMalformed = unsupportedRatherThanMalformed
    }
}

struct CanonicalValidationResult: Hashable, Sendable {
    let disposition: CanonicalValidationDisposition
    let findings: [CanonicalValidationFinding]

    init(findings: [CanonicalValidationFinding]) {
        let orderedFindings = findings.sorted { lhs, rhs in
            if lhs.disposition.rank != rhs.disposition.rank { return lhs.disposition.rank > rhs.disposition.rank }
            if lhs.concept.rawValue != rhs.concept.rawValue { return lhs.concept.rawValue < rhs.concept.rawValue }
            if lhs.code != rhs.code { return lhs.code < rhs.code }
            return lhs.summary < rhs.summary
        }
        self.findings = orderedFindings
        self.disposition = orderedFindings.map(\.disposition).max { $0.rank < $1.rank } ?? .valid
    }

    var processingMayContinueReadOnly: Bool {
        disposition.processingMayContinueReadOnly && findings.allSatisfy(\.processingMayContinueReadOnly)
    }

    var futureWriteMustStop: Bool {
        disposition.futureWriteMustStop || findings.contains(where: \.futureWriteMustStop)
    }

    var explicitRepairRequired: Bool {
        disposition.explicitRepairRequired || findings.contains(where: \.explicitRepairRequired)
    }

    var containsUnsupportedEvidence: Bool {
        findings.contains(where: \.unsupportedRatherThanMalformed)
    }

    static var valid: CanonicalValidationResult { CanonicalValidationResult(findings: []) }

    static func combined(_ results: [CanonicalValidationResult]) -> CanonicalValidationResult {
        CanonicalValidationResult(findings: results.flatMap(\.findings))
    }
}

enum CanonicalDomainValidator {
    static func finding(
        _ code: String,
        concept: CanonicalValidationConcept,
        severity: CanonicalValidationSeverity,
        disposition: CanonicalValidationDisposition,
        summary: String,
        sourceLocation: String? = nil,
        unsupported: Bool = false
    ) -> CanonicalValidationFinding {
        CanonicalValidationFinding(
            code: code,
            concept: concept,
            severity: severity,
            disposition: disposition,
            summary: summary,
            sourceLocation: sourceLocation,
            unsupportedRatherThanMalformed: unsupported
        )
    }

    static func validateIdentity(_ evidence: StableIdentityEvidence, sourceLocation: String? = nil) -> CanonicalValidationResult {
        switch evidence.importedIdentifier {
        case .valid:
            return .valid
        case .missing:
            return CanonicalValidationResult(findings: [finding("identity.missing", concept: .stableIdentity, severity: .incomplete, disposition: .incomplete, summary: "Identity evidence is missing for \(evidence.concept.rawValue).", sourceLocation: sourceLocation)])
        case let .invalid(value):
            return CanonicalValidationResult(findings: [finding("identity.invalid", concept: .stableIdentity, severity: .rejection, disposition: .rejected, summary: "Identity evidence is not a valid UUID: \(value).", sourceLocation: sourceLocation)])
        }
    }

    static func validateDuplicateIdentities(_ evidence: [StableIdentityEvidence], sourceLocation: String? = nil) -> CanonicalValidationResult {
        let findings = StableIdentityClassifier.classifyDuplicates(evidence).flatMap { classification -> [CanonicalValidationFinding] in
            switch classification {
            case .exactRepeatedEvidence, .duplicateIdentifierMatchingContent:
                return [finding("identity.duplicate.matching", concept: .stableIdentity, severity: .warning, disposition: .validWithWarnings, summary: "Duplicate identity carries matching evidence.", sourceLocation: sourceLocation)]
            case let .duplicateIdentifierConflictingContent(fields):
                return [finding("identity.duplicate.conflicting", concept: .stableIdentity, severity: .contradiction, disposition: .contradictory, summary: "Duplicate identity carries conflicting evidence: \(fields.joined(separator: ", ")).", sourceLocation: sourceLocation)]
            case .differentIdentifiersMatchingDisplay:
                return [finding("identity.display.matchingDistinct", concept: .stableIdentity, severity: .information, disposition: .valid, summary: "Matching display evidence does not merge distinct identities.", sourceLocation: sourceLocation)]
            case .missingIdentifier:
                return [finding("identity.missing", concept: .stableIdentity, severity: .incomplete, disposition: .incomplete, summary: "One or more identities are missing.", sourceLocation: sourceLocation)]
            case .invalidIdentifier:
                return [finding("identity.invalid", concept: .stableIdentity, severity: .rejection, disposition: .rejected, summary: "One or more identities are invalid.", sourceLocation: sourceLocation)]
            case .unresolvedEquivalence:
                return [finding("identity.unresolved", concept: .stableIdentity, severity: .unresolved, disposition: .unresolved, summary: "Identity equivalence cannot be resolved from available evidence.", sourceLocation: sourceLocation)]
            }
        }
        return CanonicalValidationResult(findings: findings)
    }

    static func validateOrdering(_ evidence: [OrderEvidence], expectedKind: BaseballOrderKind, sourceLocation: String? = nil) -> CanonicalValidationResult {
        switch StableOrderingClassifier.classify(evidence, expectedKind: expectedKind) {
        case .ordered:
            return .valid
        case .missingOrder:
            return CanonicalValidationResult(findings: [finding("ordering.missing", concept: .ordering, severity: .incomplete, disposition: .incomplete, summary: "Expected \(expectedKind.rawValue) ordering evidence is missing.", sourceLocation: sourceLocation)])
        case let .duplicateOrderValue(value):
            return CanonicalValidationResult(findings: [finding("ordering.duplicate", concept: .ordering, severity: .repair, disposition: .repairRequired, summary: "Duplicate order value \(value) requires explicit review before writing.", sourceLocation: sourceLocation)])
        case .conflictingOrderEvidence:
            return CanonicalValidationResult(findings: [finding("ordering.conflicting", concept: .ordering, severity: .contradiction, disposition: .contradictory, summary: "Ordering evidence conflicts with source order.", sourceLocation: sourceLocation)])
        case .ambiguousOrder:
            return CanonicalValidationResult(findings: [finding("ordering.ambiguous", concept: .ordering, severity: .repair, disposition: .repairRecommended, summary: "Ordering evidence is ambiguous and should be reviewed.", sourceLocation: sourceLocation)])
        }
    }

    static func validateTeam(_ team: ReusableCanonicalTeam, sourceLocation: String? = nil) -> CanonicalValidationResult {
        var findings = validateIdentity(team.stableIdentityEvidence, sourceLocation: sourceLocation).findings
        if case let .invalid(reason) = team.display.logo {
            findings.append(finding("team.logo.invalid", concept: .team, severity: .warning, disposition: .validWithWarnings, summary: "Team logo evidence is invalid: \(reason).", sourceLocation: sourceLocation))
        }
        return CanonicalValidationResult(findings: findings)
    }

    static func validateGameSides(home: GameSideTeamParticipation?, visiting: GameSideTeamParticipation?, sourceLocation: String? = nil) -> CanonicalValidationResult {
        switch CanonicalTeamMeaningClassifier.classifyGameSides(home: home, visiting: visiting) {
        case .completeDistinctSides:
            return .valid
        case .sameReusableTeamOnBothSides:
            return CanonicalValidationResult(findings: [finding("gameSide.sameTeamBothSides", concept: .gameSide, severity: .contradiction, disposition: .contradictory, summary: "The same reusable team is present as both home and visiting side.", sourceLocation: sourceLocation)])
        case .missingHomeSide:
            return CanonicalValidationResult(findings: [finding("gameSide.homeMissing", concept: .gameSide, severity: .incomplete, disposition: .incomplete, summary: "Home-side team evidence is missing.", sourceLocation: sourceLocation)])
        case .missingVisitingSide:
            return CanonicalValidationResult(findings: [finding("gameSide.visitingMissing", concept: .gameSide, severity: .incomplete, disposition: .incomplete, summary: "Visiting-side team evidence is missing.", sourceLocation: sourceLocation)])
        case .bothSidesUnresolved:
            return CanonicalValidationResult(findings: [finding("gameSide.unresolved", concept: .gameSide, severity: .unresolved, disposition: .unresolved, summary: "Both game sides are unresolved.", sourceLocation: sourceLocation)])
        case .unresolvedSideRole:
            return CanonicalValidationResult(findings: [finding("gameSide.roleUnresolved", concept: .gameSide, severity: .unresolved, disposition: .unresolved, summary: "A game side role is unresolved.", sourceLocation: sourceLocation)])
        case let .contradictorySideEvidence(fields):
            return CanonicalValidationResult(findings: [finding("gameSide.contradictory", concept: .gameSide, severity: .contradiction, disposition: .contradictory, summary: "Game-side evidence is contradictory: \(fields.joined(separator: ", ")).", sourceLocation: sourceLocation)])
        }
    }

    static func validatePlayer(_ player: ReusableCanonicalPlayer, sourceLocation: String? = nil) -> CanonicalValidationResult {
        var findings = validateIdentity(player.stableIdentityEvidence, sourceLocation: sourceLocation).findings
        if case let .invalid(reason) = player.display.photo {
            findings.append(finding("player.photo.invalid", concept: .player, severity: .warning, disposition: .validWithWarnings, summary: "Player photo evidence is invalid: \(reason).", sourceLocation: sourceLocation))
        }
        if case .removedFromCurrentRoster = player.rosterEvidence {
            findings.append(finding("player.removedHistorical", concept: .player, severity: .warning, disposition: .validWithWarnings, summary: "Historical player evidence differs from current reusable roster state.", sourceLocation: sourceLocation))
        }
        return CanonicalValidationResult(findings: findings)
    }

    static func validateRosterMembership(_ membership: CurrentRosterMembership, sourceLocation: String? = nil) -> CanonicalValidationResult {
        switch CanonicalRosterMembershipClassifier.classify(membership) {
        case .current, .importedMembershipEvidence:
            return .valid
        case .missingTeamIdentity:
            return CanonicalValidationResult(findings: [finding("roster.teamMissing", concept: .rosterMembership, severity: .incomplete, disposition: .incomplete, summary: "Roster membership is missing team identity.", sourceLocation: sourceLocation)])
        case .invalidTeamIdentity:
            return CanonicalValidationResult(findings: [finding("roster.teamInvalid", concept: .rosterMembership, severity: .rejection, disposition: .rejected, summary: "Roster membership has invalid team identity.", sourceLocation: sourceLocation)])
        case .missingPlayerIdentity:
            return CanonicalValidationResult(findings: [finding("roster.playerMissing", concept: .rosterMembership, severity: .incomplete, disposition: .incomplete, summary: "Roster membership is missing player identity.", sourceLocation: sourceLocation)])
        case .invalidPlayerIdentity:
            return CanonicalValidationResult(findings: [finding("roster.playerInvalid", concept: .rosterMembership, severity: .rejection, disposition: .rejected, summary: "Roster membership has invalid player identity.", sourceLocation: sourceLocation)])
        case .incompleteMembership:
            return CanonicalValidationResult(findings: [finding("roster.incomplete", concept: .rosterMembership, severity: .incomplete, disposition: .incomplete, summary: "Roster membership is incomplete.", sourceLocation: sourceLocation)])
        case .unresolvedMembership:
            return CanonicalValidationResult(findings: [finding("roster.unresolved", concept: .rosterMembership, severity: .unresolved, disposition: .unresolved, summary: "Roster membership relationship is unresolved.", sourceLocation: sourceLocation)])
        case .conflictingMembershipEvidence:
            return CanonicalValidationResult(findings: [finding("roster.conflicting", concept: .rosterMembership, severity: .contradiction, disposition: .contradictory, summary: "Roster membership evidence conflicts.", sourceLocation: sourceLocation)])
        }
    }

    static func validateRoster(_ memberships: [CurrentRosterMembership], expectedTeamIdentity: ImportedIdentifierEvidence? = nil, sourceLocation: String? = nil) -> CanonicalValidationResult {
        let classifications = CanonicalRosterMembershipClassifier.classifyRoster(memberships, expectedTeamIdentity: expectedTeamIdentity)
        let findings = sortedDescriptions(classifications).map { $0.lowercased() }.compactMap { description -> CanonicalValidationFinding? in
            if description.contains("emptyroster") {
                return finding("roster.empty", concept: .rosterMembership, severity: .warning, disposition: .validWithWarnings, summary: "Roster evidence is empty.", sourceLocation: sourceLocation)
            }
            if description.contains("containsinvalidrelationship") {
                return finding("roster.invalidRelationship", concept: .rosterMembership, severity: .rejection, disposition: .rejected, summary: "Roster contains an invalid relationship.", sourceLocation: sourceLocation)
            }
            if description.contains("containsduplicatemembership") || description.contains("containsconflictingmembership") || description.contains("playeronmultiplecurrentteams") || description.contains("mixedteamevidence") {
                return finding("roster.relationshipConflict", concept: .rosterMembership, severity: .contradiction, disposition: .contradictory, summary: "Roster relationship evidence conflicts: \(description).", sourceLocation: sourceLocation)
            }
            if description.contains("containsincompletemembership") || description.contains("containsunresolvedmembership") || description.contains("playerwithoutcurrentteam") {
                return finding("roster.relationshipIncomplete", concept: .rosterMembership, severity: .incomplete, disposition: .incomplete, summary: "Roster relationship evidence is incomplete: \(description).", sourceLocation: sourceLocation)
            }
            if description.contains("duplicatejerseynumber") || description.contains("duplicaterosterorder") {
                return finding("roster.displayDuplicate", concept: .rosterMembership, severity: .warning, disposition: .validWithWarnings, summary: "Roster display or order evidence is duplicated: \(description).", sourceLocation: sourceLocation)
            }
            return nil
        }
        return CanonicalValidationResult(findings: findings)
    }

    static func validateLineup(_ lineup: CanonicalGameLineup, currentRoster: [CurrentRosterMembership] = [], sourceLocation: String? = nil) -> CanonicalValidationResult {
        let classifications = CanonicalLineupMeaningClassifier.classifyLineup(lineup, currentRosterMemberships: currentRoster)
        let findings = sortedDescriptions(classifications).map { $0.lowercased() }.compactMap { description -> CanonicalValidationFinding? in
            if description.contains("emptylineup") {
                return finding("lineup.empty", concept: .lineup, severity: .incomplete, disposition: .incomplete, summary: "Lineup evidence is empty.", sourceLocation: sourceLocation)
            }
            if description.contains("invalidgame") || description.contains("invalidparticipant") || description.contains("invalidslot") {
                return finding("lineup.invalid", concept: .lineup, severity: .rejection, disposition: .rejected, summary: "Lineup contains invalid evidence: \(description).", sourceLocation: sourceLocation)
            }
            if description.contains("conflicting") || description.contains("teamsideconflict") || description.contains("participantsideconflict") || description.contains("duplicateslot") || description.contains("duplicateparticipant") || description.contains("duplicatelineup") {
                return finding("lineup.conflict", concept: .lineup, severity: .contradiction, disposition: .contradictory, summary: "Lineup evidence conflicts: \(description).", sourceLocation: sourceLocation)
            }
            if description.contains("missing") || description.contains("incomplete") || description.contains("unresolved") || description.contains("unknownmode") {
                return finding("lineup.incomplete", concept: .lineup, severity: .incomplete, disposition: .incomplete, summary: "Lineup evidence is incomplete or unresolved: \(description).", sourceLocation: sourceLocation)
            }
            if description.contains("unsupported") {
                return finding("lineup.unsupported", concept: .lineup, severity: .unsupported, disposition: .unsupported, summary: "Lineup contains unsupported evidence: \(description).", sourceLocation: sourceLocation, unsupported: true)
            }
            if description.contains("ambiguous") || description.contains("absentfromcurrentroster") || description.contains("historical") {
                return finding("lineup.review", concept: .lineup, severity: .warning, disposition: .validWithWarnings, summary: "Lineup carries review-only evidence: \(description).", sourceLocation: sourceLocation)
            }
            return nil
        }
        return CanonicalValidationResult(findings: findings)
    }

    static func validateBattingOrder(_ evidence: CanonicalBattingOrderEvidence, sourceLocation: String? = nil) -> CanonicalValidationResult {
        let classifications = CanonicalBattingOrderClassifier.classify(evidence)
        let findings = sortedDescriptions(classifications).map { $0.lowercased() }.compactMap { description -> CanonicalValidationFinding? in
            if description.contains("invalidrawslot") {
                return finding("batting.invalidSlot", concept: .battingOrder, severity: .rejection, disposition: .rejected, summary: "Batting-order slot evidence is invalid.", sourceLocation: sourceLocation)
            }
            if description.contains("unsupportedrawslot") {
                return finding("batting.unsupportedSlot", concept: .battingOrder, severity: .unsupported, disposition: .unsupported, summary: "Batting-order slot evidence is unsupported: \(description).", sourceLocation: sourceLocation, unsupported: true)
            }
            if description.contains("duplicateslot") || description.contains("conflictingslotevidence") || description.contains("progressionambiguous") {
                return finding("batting.conflict", concept: .battingOrder, severity: .repair, disposition: .repairRequired, summary: "Batting-order evidence needs explicit repair: \(description).", sourceLocation: sourceLocation)
            }
            if description.contains("missingslot") || description.contains("unresolvedparticipant") || description.contains("progressionunknown") || description.contains("unknownlineupmode") {
                return finding("batting.incomplete", concept: .battingOrder, severity: .incomplete, disposition: .incomplete, summary: "Batting-order evidence is incomplete: \(description).", sourceLocation: sourceLocation)
            }
            return nil
        }
        return CanonicalValidationResult(findings: findings)
    }

    static func validateDefensivePosition(_ evidence: CanonicalDefensiveParticipationEvidence, sourceLocation: String? = nil) -> CanonicalValidationResult {
        let classifications = CanonicalDefensivePositionClassifier.classify(evidence)
        let findings = sortedDescriptions(classifications).map { $0.lowercased() }.compactMap { description -> CanonicalValidationFinding? in
            if description.contains("unsupportedrawposition") || description.contains("rawimportedposition") {
                return finding("defense.unsupportedPosition", concept: .defensivePosition, severity: .unsupported, disposition: .unsupported, summary: "Defensive-position evidence is unsupported but preserved: \(description).", sourceLocation: sourceLocation, unsupported: true)
            }
            if description.contains("conflictingposition") {
                return finding("defense.conflictingPosition", concept: .defensivePosition, severity: .contradiction, disposition: .contradictory, summary: "Defensive-position evidence conflicts.", sourceLocation: sourceLocation)
            }
            if description.contains("missingposition") || description.contains("unresolvedlineupparticipant") || description.contains("unknownpitcherrelationship") {
                return finding("defense.incomplete", concept: .defensivePosition, severity: .incomplete, disposition: .incomplete, summary: "Defensive-position evidence is incomplete: \(description).", sourceLocation: sourceLocation)
            }
            if description.contains("blankposition") || description.contains("unknownrawposition") || description.contains("historicalposition") {
                return finding("defense.warning", concept: .defensivePosition, severity: .warning, disposition: .validWithWarnings, summary: "Defensive-position evidence is interpretable with warning: \(description).", sourceLocation: sourceLocation)
            }
            return nil
        }
        return CanonicalValidationResult(findings: findings)
    }

    static func validateGame(_ game: CanonicalGameIdentity, sourceLocation: String? = nil) -> CanonicalValidationResult {
        var findings = validateIdentity(game.stableIdentityEvidence, sourceLocation: sourceLocation).findings
        for classification in sortedDescriptions(CanonicalGameMeaningClassifier.classifyGame(game)).map({ $0.lowercased() }) {
            if classification.contains("contradictory") {
                findings.append(finding("game.contradictory", concept: .game, severity: .contradiction, disposition: .contradictory, summary: "Game evidence is contradictory.", sourceLocation: sourceLocation))
            }
        }
        switch game.configuration {
        case .missing:
            findings.append(finding("game.configurationMissing", concept: .game, severity: .incomplete, disposition: .incomplete, summary: "Game configuration evidence is missing.", sourceLocation: sourceLocation))
        case let .invalid(reason):
            findings.append(finding("game.configurationInvalid", concept: .game, severity: .rejection, disposition: .rejected, summary: "Game configuration is invalid: \(reason).", sourceLocation: sourceLocation))
        case .conflicting:
            findings.append(finding("game.configurationConflicting", concept: .game, severity: .contradiction, disposition: .contradictory, summary: "Game configuration evidence conflicts.", sourceLocation: sourceLocation))
        case .configured:
            break
        }
        return CanonicalValidationResult(findings: findings)
    }

    static func validateInning(_ inning: CanonicalHalfInning, sourceLocation: String? = nil) -> CanonicalValidationResult {
        findings(from: sortedDescriptions(CanonicalInningSemanticsClassifier.classify(inning)), concept: .inning, sourceLocation: sourceLocation) { description in
            if description.contains("contradictory") { return (.contradiction, .contradictory, "inning.contradictory", false) }
            if description.contains("invalid") { return (.rejection, .rejected, "inning.invalid", false) }
            if description.contains("missing") || description.contains("unresolved") { return (.incomplete, .incomplete, "inning.incomplete", false) }
            return nil
        }
    }

    static func validateCount(_ count: BallStrikeCountEvidence, sourceLocation: String? = nil) -> CanonicalValidationResult {
        findings(from: sortedDescriptions(CanonicalCountAndOutsSemanticsClassifier.classifyCount(count)), concept: .count, sourceLocation: sourceLocation) { description in
            if description.contains("unsupported") { return (.unsupported, .unsupported, "count.unsupported", true) }
            if description.contains("invalid") { return (.rejection, .rejected, "count.invalid", false) }
            if description.contains("contradictory") { return (.contradiction, .contradictory, "count.contradictory", false) }
            if description.contains("missing") { return (.incomplete, .incomplete, "count.missing", false) }
            return nil
        }
    }

    static func validateOuts(_ outs: CanonicalOutsState, sourceLocation: String? = nil) -> CanonicalValidationResult {
        findings(from: sortedDescriptions(CanonicalCountAndOutsSemanticsClassifier.classifyOuts(outs)), concept: .outs, sourceLocation: sourceLocation) { description in
            if description.contains("conflicting") { return (.contradiction, .contradictory, "outs.conflicting", false) }
            if description.contains("invalid") || description.contains("impossible") { return (.rejection, .rejected, "outs.invalid", false) }
            if description.contains("missing") { return (.incomplete, .incomplete, "outs.missing", false) }
            if description.contains("thirdoutcontext") { return (.warning, .validWithWarnings, "outs.thirdOutContext", false) }
            return nil
        }
    }

    static func validateBaseOccupancy(_ occupancy: CanonicalBaseOccupancy, sourceLocation: String? = nil) -> CanonicalValidationResult {
        findings(from: sortedDescriptions(CanonicalBaseOccupancySemanticsClassifier.classify(occupancy)), concept: .baseOccupancy, sourceLocation: sourceLocation) { description in
            if description.contains("impossible") || description.contains("samerunnerassigned") || description.contains("multiplerunnersassigned") { return (.contradiction, .contradictory, "bases.contradictory", false) }
            if description.contains("unsupported") { return (.unsupported, .unsupported, "bases.unsupported", true) }
            if description.contains("missing") || description.contains("unresolved") || description.contains("ambiguous") { return (.unresolved, .unresolved, "bases.unresolved", false) }
            if description.contains("historical") { return (.warning, .validWithWarnings, "bases.historical", false) }
            return nil
        }
    }

    static func validateScoringEvent(_ event: CanonicalScoringEventEvidence, sourceLocation: String? = nil) -> CanonicalValidationResult {
        let classifications = CanonicalScoringEventMeaningClassifier.classify(event)
        return findings(from: sortedDescriptions(classifications), concept: .scoringEvent, sourceLocation: sourceLocation) { description in
            if description.contains("contradictory") || description.contains("conflicting") || description.contains("duplicate") { return (.contradiction, .contradictory, "event.conflicting", false) }
            if description.contains("invalid") { return (.rejection, .rejected, "event.invalid", false) }
            if description.contains("unsupported") { return (.unsupported, .unsupported, "event.unsupported", true) }
            if description.contains("missing") || description.contains("unresolved") || description.contains("unknownresult") { return (.incomplete, .incomplete, "event.incomplete", false) }
            if description.contains("historical") || description.contains("multipleoutsrecorded") { return (.warning, .validWithWarnings, "event.warning", false) }
            return nil
        }
    }

    static func validatePitcherAppearance(_ appearance: CanonicalPitcherAppearanceEvidence, sourceLocation: String? = nil) -> CanonicalValidationResult {
        findings(from: sortedDescriptions(CanonicalPitcherResponsibilityMeaningClassifier.classifyAppearance(appearance)), concept: .pitcherResponsibility, sourceLocation: sourceLocation) { pitcherDisposition($0) }
    }

    static func validatePitcherResponsibility(_ responsibility: CanonicalPitcherResponsibilityEvidence, sourceLocation: String? = nil) -> CanonicalValidationResult {
        findings(from: sortedDescriptions(CanonicalPitcherResponsibilityMeaningClassifier.classifyResponsibility(responsibility)), concept: .pitcherResponsibility, sourceLocation: sourceLocation) { pitcherDisposition($0) }
    }

    static func validateSubstitution(_ substitution: CanonicalSubstitutionEvidence, sourceLocation: String? = nil) -> CanonicalValidationResult {
        if case .unequalCounts = substitution.legacyArrayEvidence {
            return CanonicalValidationResult(findings: [
                finding("substitution.repairRecommended", concept: .substitution, severity: .repair, disposition: .repairRecommended, summary: "Legacy substitution arrays are unequal and require explicit review before pairing.", sourceLocation: sourceLocation)
            ])
        }
        return findings(from: sortedDescriptions(CanonicalSubstitutionMeaningClassifier.classify(substitution)), concept: .substitution, sourceLocation: sourceLocation) { description in
            if description.contains("conflicting") || description.contains("sameparticipantincomingandoutgoing") || description.contains("sameparticipantonbothteamsides") { return (.contradiction, .contradictory, "substitution.conflicting", false) }
            if description.contains("unsupported") { return (.unsupported, .unsupported, "substitution.unsupported", true) }
            if description.contains("unequallegacyarrays") || description.contains("ambiguous") { return (.repair, .repairRecommended, "substitution.repairRecommended", false) }
            if description.contains("missing") || description.contains("unresolved") || description.contains("unknown") { return (.incomplete, .incomplete, "substitution.incomplete", false) }
            return nil
        }
    }

    private static func pitcherDisposition(_ description: String) -> (CanonicalValidationSeverity, CanonicalValidationDisposition, String, Bool)? {
        if description.contains("conflicting") || description.contains("teamsideconflict") { return (.contradiction, .contradictory, "pitcher.conflicting", false) }
        if description.contains("invalid") { return (.rejection, .rejected, "pitcher.invalid", false) }
        if description.contains("missing") || description.contains("incomplete") || description.contains("unresolved") { return (.incomplete, .incomplete, "pitcher.incomplete", false) }
        if description.contains("ambiguous") { return (.repair, .repairRecommended, "pitcher.ambiguous", false) }
        if description.contains("historical") || description.contains("currentpitcherstatedoesnotrewrite") { return (.warning, .validWithWarnings, "pitcher.historical", false) }
        return nil
    }

    private static func findings(
        from descriptions: [String],
        concept: CanonicalValidationConcept,
        sourceLocation: String?,
        classify: (String) -> (CanonicalValidationSeverity, CanonicalValidationDisposition, String, Bool)?
    ) -> CanonicalValidationResult {
        let findings = descriptions.compactMap { description -> CanonicalValidationFinding? in
            guard let (severity, disposition, code, unsupported) = classify(description.lowercased()) else { return nil }
            return finding(code, concept: concept, severity: severity, disposition: disposition, summary: "\(concept.rawValue) evidence classified as \(description).", sourceLocation: sourceLocation, unsupported: unsupported)
        }
        return CanonicalValidationResult(findings: findings)
    }

    private static func sortedDescriptions<T: Hashable>(_ values: Set<T>) -> [String] {
        values.map { String(describing: $0) }.sorted()
    }

    private static func sortedDescriptions<T>(_ values: [T]) -> [String] {
        values.map { String(describing: $0) }.sorted()
    }
}

import Foundation

/// Non-routed Phase 3 classification of how canonical baseball meaning is evidenced by the current persisted shape.
enum CanonicalPersistenceConcept: String, CaseIterable, Hashable, Sendable {
    case team
    case reusablePlayer
    case rosterMembership
    case gameParticipant
    case gameIdentityAndConfiguration
    case gameSide
    case lineup
    case battingOrder
    case defensivePosition
    case scoringEvent
    case inningAndHalf
    case outs
    case baseAndRunnerEvidence
    case score
    case pitcherAppearanceAndResponsibility
    case substitution
    case correctionAndSupersession
    case media
    case ordering
    case missingRepresentation
    case unsupportedCanonicalValue
}

enum CanonicalPersistedRepresentationKind: String, CaseIterable, Hashable, Sendable {
    case directStoredFact
    case relationship
    case media
    case derivedStoredValue
    case compatibilityOnlyValue
    case missingRepresentation
    case ambiguousRepresentation
    case unsupportedRepresentation
    case futureSchemaOrAdapterDecision
}

struct CanonicalPersistenceEvidenceMapping: Hashable, Sendable {
    let concept: CanonicalPersistenceConcept
    let representations: [CanonicalPersistedRepresentationKind]
    let persistedEvidence: [String]
    let risks: [String]

    var requiresFutureDecision: Bool {
        representations.contains(.missingRepresentation)
        || representations.contains(.ambiguousRepresentation)
        || representations.contains(.unsupportedRepresentation)
        || representations.contains(.futureSchemaOrAdapterDecision)
    }

    init(
        concept: CanonicalPersistenceConcept,
        representations: [CanonicalPersistedRepresentationKind],
        persistedEvidence: [String],
        risks: [String] = []
    ) {
        self.concept = concept
        self.representations = representations.sorted { $0.rawValue < $1.rawValue }
        self.persistedEvidence = persistedEvidence.sorted()
        self.risks = risks.sorted()
    }
}

enum CanonicalPersistenceConceptMapper {
    static func map(_ concept: CanonicalPersistenceConcept) -> CanonicalPersistenceEvidenceMapping {
        switch concept {
        case .team:
            return mapping(concept, [.directStoredFact, .relationship, .media], ["Team identity, display fields, logo, games, players"])
        case .reusablePlayer:
            return mapping(concept, [.directStoredFact, .relationship, .media], ["Player identity, display fields, team, photo"])
        case .rosterMembership:
            return mapping(concept, [.relationship, .directStoredFact], ["Player.team and Team.players"], ["Membership is mutable from multiple views"])
        case .gameParticipant:
            return mapping(concept, [.relationship, .ambiguousRepresentation], ["Game.players and lineup or at-bat references"], ["Participant source can be roster, lineup, scoring, or substitution"])
        case .gameIdentityAndConfiguration:
            return mapping(concept, [.directStoredFact], ["Game identity, date, location, innings, everyone-hits flag, highlights"])
        case .gameSide:
            return mapping(concept, [.relationship], ["Game.hteam and Game.vteam"])
        case .lineup:
            return mapping(concept, [.relationship, .directStoredFact], ["Lineup game, team, inning, everyone-hits, players"])
        case .battingOrder:
            return mapping(concept, [.directStoredFact, .relationship, .ambiguousRepresentation], ["Player.batOrder, Atbat.batOrder, Lineup.players order"], ["Ordering may be duplicated across records"])
        case .defensivePosition:
            return mapping(concept, [.directStoredFact, .compatibilityOnlyValue], ["Player.position"])
        case .scoringEvent:
            return mapping(concept, [.directStoredFact, .relationship, .compatibilityOnlyValue], ["Atbat result, bases, RBI, outs, inning, sequence, column, related game/team/player"])
        case .inningAndHalf:
            return mapping(concept, [.directStoredFact, .compatibilityOnlyValue], ["Atbat.inning and Lineup.inning"], ["Half inning is encoded conventionally rather than structurally"])
        case .outs:
            return mapping(concept, [.directStoredFact, .derivedStoredValue], ["Atbat.outs and Atbat.outAt"], ["Some outs are recalculated during scoring projection"])
        case .baseAndRunnerEvidence:
            return mapping(concept, [.directStoredFact, .compatibilityOnlyValue, .ambiguousRepresentation], ["Atbat.maxbase, result, stolen bases, outAt"], ["Runner identity and base state are partly inferred"])
        case .score:
            return mapping(concept, [.derivedStoredValue, .compatibilityOnlyValue], ["Game.hscore and Game.vscore"], ["Stored score must not silently become authoritative"])
        case .pitcherAppearanceAndResponsibility:
            return mapping(concept, [.directStoredFact, .relationship, .derivedStoredValue], ["Pitcher player, team, game, start/end markers, aggregate stats"], ["Markers can be updated by scoring projection"])
        case .substitution:
            return mapping(concept, [.relationship, .ambiguousRepresentation, .compatibilityOnlyValue], ["Game.replaced and Game.incomings parallel arrays"], ["Pairing depends on array order"])
        case .correctionAndSupersession:
            return mapping(concept, [.missingRepresentation, .futureSchemaOrAdapterDecision], [], ["No persisted canonical supersession record exists"])
        case .media:
            return mapping(concept, [.media, .relationship, .futureSchemaOrAdapterDecision], ["Team.logo and Player.photo external storage"], ["Replacement is direct field mutation without media transaction evidence"])
        case .ordering:
            return mapping(concept, [.directStoredFact, .relationship, .ambiguousRepresentation], ["Player.batOrder, Atbat.seq, Atbat.col, Lineup.players order, substitution array order"], ["Ordering cannot rely only on fetch or presentation order"])
        case .missingRepresentation:
            return mapping(concept, [.missingRepresentation], [], ["Future schema or adapter must decide whether to persist the concept"])
        case .unsupportedCanonicalValue:
            return mapping(concept, [.unsupportedRepresentation], [], ["Unsupported evidence must be preserved for diagnostics"])
        }
    }

    static func mapAll() -> [CanonicalPersistenceEvidenceMapping] {
        CanonicalPersistenceConcept.allCases.map(map)
    }

    private static func mapping(
        _ concept: CanonicalPersistenceConcept,
        _ representations: [CanonicalPersistedRepresentationKind],
        _ evidence: [String],
        _ risks: [String] = []
    ) -> CanonicalPersistenceEvidenceMapping {
        CanonicalPersistenceEvidenceMapping(
            concept: concept,
            representations: representations,
            persistedEvidence: evidence,
            risks: risks
        )
    }
}

enum CanonicalPersistedInterpretationDisposition: String, CaseIterable, Hashable, Sendable {
    case fullyInterpreted
    case interpretedWithWarnings
    case partial
    case unsupported
    case contradictory
    case unresolved
    case rejectedForFutureWrite
}

struct CanonicalPersistedInterpretation<Value: Hashable & Sendable>: Hashable, Sendable {
    let canonicalValue: Value?
    let disposition: CanonicalPersistedInterpretationDisposition
    let validation: CanonicalValidationResult
    let preservedRawEvidence: [String: String]
    let unsupportedRawEvidence: [String]
    let sourceIdentity: ImportedIdentifierEvidence
    let relationshipResolution: LegacyRelationshipResolutionStatus

    var futureWriteMustStop: Bool { validation.futureWriteMustStop || disposition == .rejectedForFutureWrite }
    var interpretedReadOnlyMayContinue: Bool { validation.processingMayContinueReadOnly }
}

struct CanonicalPersistedStoredScoreSnapshot: Hashable, Sendable {
    let gameIdentity: ImportedIdentifierEvidence
    let home: Int
    let visiting: Int
    let sourceLocation: String?

    init(gameIdentity: ImportedIdentifierEvidence, home: Int, visiting: Int, sourceLocation: String? = nil) {
        self.gameIdentity = gameIdentity
        self.home = home
        self.visiting = visiting
        self.sourceLocation = sourceLocation
    }
}

enum CanonicalPersistedEvidenceInterpreter {
    static func interpretTeam(_ snapshot: LegacyTeamEvidenceSnapshot) -> CanonicalPersistedInterpretation<ReusableCanonicalTeam> {
        wrap(LegacyCanonicalVerificationMapper.mapTeam(snapshot))
    }

    static func interpretPlayer(_ snapshot: LegacyPlayerEvidenceSnapshot) -> CanonicalPersistedInterpretation<ReusableCanonicalPlayer> {
        wrap(LegacyCanonicalVerificationMapper.mapPlayer(snapshot))
    }

    static func interpretRosterMembership(_ snapshot: LegacyPlayerEvidenceSnapshot) -> CanonicalPersistedInterpretation<CurrentRosterMembership> {
        wrap(LegacyCanonicalVerificationMapper.mapRosterMembership(snapshot))
    }

    static func interpretGame(_ snapshot: LegacyGameEvidenceSnapshot) -> CanonicalPersistedInterpretation<CanonicalGameIdentity> {
        wrap(LegacyCanonicalVerificationMapper.mapGameIdentity(snapshot))
    }

    static func interpretLineup(
        _ snapshot: LegacyLineupEvidenceSnapshot,
        homeSide: GameSideTeamParticipation?,
        visitingSide: GameSideTeamParticipation?
    ) -> CanonicalPersistedInterpretation<CanonicalGameLineup> {
        wrap(LegacyCanonicalVerificationMapper.mapLineup(snapshot, homeSide: homeSide, visitingSide: visitingSide))
    }

    static func interpretScoringEvent(_ snapshot: LegacyAtbatEvidenceSnapshot) -> CanonicalPersistedInterpretation<CanonicalScoringEventEvidence> {
        wrap(LegacyCanonicalVerificationMapper.mapScoringEvent(snapshot))
    }

    static func interpretPitcherAppearance(
        _ snapshot: LegacyPitcherEvidenceSnapshot,
        homeSide: GameSideTeamParticipation?,
        visitingSide: GameSideTeamParticipation?
    ) -> CanonicalPersistedInterpretation<CanonicalPitcherAppearanceEvidence> {
        wrap(LegacyCanonicalVerificationMapper.mapPitcherAppearance(snapshot, homeSide: homeSide, visitingSide: visitingSide))
    }

    static func interpretSubstitutions(
        incoming: [LegacyPlayerEvidenceSnapshot],
        outgoing: [LegacyPlayerEvidenceSnapshot],
        gameIdentity: ImportedIdentifierEvidence,
        sourceLocation: String? = nil
    ) -> [CanonicalPersistedInterpretation<CanonicalSubstitutionEvidence>] {
        LegacyCanonicalVerificationMapper.mapSubstitutions(
            incoming: incoming,
            outgoing: outgoing,
            gameIdentity: gameIdentity,
            sourceLocation: sourceLocation
        ).map(wrap)
    }

    static func interpretStoredScore(_ snapshot: CanonicalPersistedStoredScoreSnapshot) -> CanonicalPersistedInterpretation<CanonicalProjectedScore> {
        let findings: [CanonicalValidationFinding]
        if snapshot.home < 0 || snapshot.visiting < 0 {
            findings = [CanonicalDomainValidator.finding(
                "persistenceMapping.negativeStoredScore",
                concept: .game,
                severity: .rejection,
                disposition: .rejected,
                summary: "Stored score evidence cannot be negative.",
                sourceLocation: snapshot.sourceLocation
            )]
        } else {
            findings = []
        }
        let validation = CanonicalValidationResult(findings: findings)
        return CanonicalPersistedInterpretation(
            canonicalValue: validation.futureWriteMustStop ? nil : CanonicalProjectedScore(home: snapshot.home, visiting: snapshot.visiting),
            disposition: disposition(validation: validation, completeness: LegacyCanonicalMappingCompleteness(validation: validation), relationship: .resolved),
            validation: validation,
            preservedRawEvidence: ["home": String(snapshot.home), "visiting": String(snapshot.visiting)],
            unsupportedRawEvidence: [],
            sourceIdentity: snapshot.gameIdentity,
            relationshipResolution: .resolved
        )
    }

    private static func wrap<Value>(_ result: LegacyCanonicalMappingResult<Value>) -> CanonicalPersistedInterpretation<Value> {
        CanonicalPersistedInterpretation(
            canonicalValue: result.canonicalValue,
            disposition: disposition(validation: result.validation, completeness: result.completeness, relationship: result.relationshipResolution),
            validation: result.validation,
            preservedRawEvidence: result.preservedRawEvidence,
            unsupportedRawEvidence: result.unsupportedRawEvidence,
            sourceIdentity: result.sourceIdentity,
            relationshipResolution: result.relationshipResolution
        )
    }

    private static func disposition(
        validation: CanonicalValidationResult,
        completeness: LegacyCanonicalMappingCompleteness,
        relationship: LegacyRelationshipResolutionStatus
    ) -> CanonicalPersistedInterpretationDisposition {
        if validation.disposition == .contradictory || relationship == .conflicting { return .contradictory }
        if validation.disposition == .rejected || validation.disposition == .repairRequired { return .rejectedForFutureWrite }
        if validation.disposition == .unresolved || relationship == .unresolved || relationship == .missing { return .unresolved }
        if validation.containsUnsupportedEvidence || validation.disposition == .unsupported || completeness == .unsupportedEvidencePreserved { return .unsupported }
        if validation.disposition == .validWithWarnings || validation.disposition == .repairRecommended { return .interpretedWithWarnings }
        if validation.disposition == .incomplete || completeness == .partiallyInterpreted { return .partial }
        return .fullyInterpreted
    }
}

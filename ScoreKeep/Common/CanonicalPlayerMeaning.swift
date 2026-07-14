import Foundation

/// Non-routed Phase 1 foundation for reusable player and game-specific participant meaning.
/// These values do not read, write, migrate, or route existing SwiftData records.
enum PlayerEvidenceSource: String, Hashable, Sendable {
    case currentReusableRecord
    case currentRosterRelationship
    case historicalGameParticipation
    case importedRoster
    case importedGame
    case compatibilityTransport
    case unknown
}

enum PlayerTextEvidence: Hashable, Sendable {
    case missing
    case present(String)
    case unknown(String)

    var value: String? {
        switch self {
        case let .present(value), let .unknown(value):
            return value
        case .missing:
            return nil
        }
    }
}

enum PlayerMediaEvidence: Hashable, Sendable {
    case missing
    case present(Data)
    case invalid(String)
}

struct PlayerDisplayEvidence: Hashable, Sendable {
    let name: PlayerTextEvidence
    let jerseyNumber: PlayerTextEvidence
    let position: PlayerTextEvidence
    let battingDirection: PlayerTextEvidence
    let photo: PlayerMediaEvidence

    init(
        name: PlayerTextEvidence = .missing,
        jerseyNumber: PlayerTextEvidence = .missing,
        position: PlayerTextEvidence = .missing,
        battingDirection: PlayerTextEvidence = .missing,
        photo: PlayerMediaEvidence = .missing
    ) {
        self.name = name
        self.jerseyNumber = jerseyNumber
        self.position = position
        self.battingDirection = battingDirection
        self.photo = photo
    }

    var stableIdentityDisplayEvidence: [IdentityDisplayEvidence] {
        var evidence: [IdentityDisplayEvidence] = []
        appendTextEvidence(name, field: "name", to: &evidence)
        appendTextEvidence(jerseyNumber, field: "jerseyNumber", to: &evidence)
        appendTextEvidence(position, field: "position", to: &evidence)
        appendTextEvidence(battingDirection, field: "battingDirection", to: &evidence)

        switch photo {
        case .missing:
            break
        case let .present(data):
            evidence.append(.init("photoByteCount", String(data.count)))
        case let .invalid(reason):
            evidence.append(.init("photoInvalid", reason))
        }

        return evidence
    }

    private func appendTextEvidence(_ text: PlayerTextEvidence, field: String, to evidence: inout [IdentityDisplayEvidence]) {
        switch text {
        case .missing:
            break
        case let .present(value):
            evidence.append(.init(field, value))
        case let .unknown(value):
            evidence.append(.init("\(field)Unknown", value))
        }
    }
}

enum PlayerRosterEvidence: Hashable, Sendable {
    case notRepresented
    case currentRelationship(teamIdentity: ImportedIdentifierEvidence?)
    case importedRosterReference(teamIdentity: ImportedIdentifierEvidence?, sourceCount: Int?)
    case removedFromCurrentRoster
    case deletedReusableRecordEvidence
}

struct ReusableCanonicalPlayer: Hashable, Sendable {
    let identity: ImportedIdentifierEvidence
    let display: PlayerDisplayEvidence
    let rosterEvidence: PlayerRosterEvidence
    let source: PlayerEvidenceSource

    init(
        identity: ImportedIdentifierEvidence,
        display: PlayerDisplayEvidence = PlayerDisplayEvidence(),
        rosterEvidence: PlayerRosterEvidence = .notRepresented,
        source: PlayerEvidenceSource = .unknown
    ) {
        self.identity = identity
        self.display = display
        self.rosterEvidence = rosterEvidence
        self.source = source
    }

    static func == (lhs: ReusableCanonicalPlayer, rhs: ReusableCanonicalPlayer) -> Bool {
        switch (lhs.identity, rhs.identity) {
        case let (.valid(lhsID), .valid(rhsID)):
            return lhsID == rhsID
        default:
            return lhs.identity == rhs.identity &&
                lhs.display == rhs.display &&
                lhs.rosterEvidence == rhs.rosterEvidence &&
                lhs.source == rhs.source
        }
    }

    func hash(into hasher: inout Hasher) {
        switch identity {
        case let .valid(identifier):
            hasher.combine("ReusableCanonicalPlayer.validIdentity")
            hasher.combine(identifier)
        default:
            hasher.combine("ReusableCanonicalPlayer.unresolvedIdentity")
            hasher.combine(identity)
            hasher.combine(display)
            hasher.combine(rosterEvidence)
            hasher.combine(source)
        }
    }

    var stableIdentityEvidence: StableIdentityEvidence {
        StableIdentityEvidence(
            concept: .player,
            importedIdentifier: identity,
            displayEvidence: display.stableIdentityDisplayEvidence
        )
    }
}

enum PlayerMeaningComparison: Hashable, Sendable {
    case sameIdentityMatchingDisplay
    case sameIdentityConflictingDisplay([String])
    case distinctIdentitiesMatchingDisplay
    case distinctIdentitiesDifferentDisplay
    case bothMissingIdentifier
    case oneMissingIdentifier
    case invalidIdentifier
    case unresolvedEquivalence
}

enum PlayerDuplicateClassification: Hashable, Sendable {
    case exactRepeatedEvidence
    case duplicateIdentifierMatchingDisplay
    case duplicateIdentifierConflictingDisplay([String])
    case differentIdentifiersMatchingDisplay
    case missingIdentifier
    case invalidIdentifier
    case unresolvedEquivalence
}

enum PlayerTeamEvidence: Hashable, Sendable {
    case currentReusableTeam(ReusableCanonicalTeam)
    case gameSide(GameSideTeamParticipation)
    case missing
    case unknown(TeamDisplayEvidence)
    case conflicting(TeamDisplayEvidence)
}

enum PlayerResolution: Hashable, Sendable {
    case reusablePlayer(ReusableCanonicalPlayer)
    case missingIdentity(PlayerDisplayEvidence)
    case invalidIdentity(ImportedIdentifierEvidence, PlayerDisplayEvidence)
    case duplicateIdentity(ImportedIdentifierEvidence, PlayerDisplayEvidence)
    case conflictingEvidence(ImportedIdentifierEvidence, PlayerDisplayEvidence)
    case unknown(PlayerDisplayEvidence)
    case importedDetached(PlayerDisplayEvidence)
}

enum PlayerParticipantRole: String, Hashable, Sendable {
    case rosterMember
    case lineupParticipant
    case batter
    case pitcher
    case substitute
    case replacedParticipant
    case unresolved
}

struct PlayerLineupParticipationEvidence: Hashable, Sendable {
    let lineupIdentity: ImportedIdentifierEvidence?
    let slotOrder: OrderEvidence?
    let battingOrder: OrderEvidence?

    init(
        lineupIdentity: ImportedIdentifierEvidence? = nil,
        slotOrder: OrderEvidence? = nil,
        battingOrder: OrderEvidence? = nil
    ) {
        self.lineupIdentity = lineupIdentity
        self.slotOrder = slotOrder
        self.battingOrder = battingOrder
    }
}

struct PlayerPlateAppearanceEvidence: Hashable, Sendable {
    let scoringEventIdentity: ImportedIdentifierEvidence
    let battingOrder: OrderEvidence?

    init(scoringEventIdentity: ImportedIdentifierEvidence, battingOrder: OrderEvidence? = nil) {
        self.scoringEventIdentity = scoringEventIdentity
        self.battingOrder = battingOrder
    }
}

struct PlayerPitcherAppearanceEvidence: Hashable, Sendable {
    let pitcherIdentity: ImportedIdentifierEvidence
    let appearanceOrder: OrderEvidence?

    init(pitcherIdentity: ImportedIdentifierEvidence, appearanceOrder: OrderEvidence? = nil) {
        self.pitcherIdentity = pitcherIdentity
        self.appearanceOrder = appearanceOrder
    }
}

struct PlayerSubstitutionEvidence: Hashable, Sendable {
    let substitutionIdentity: ImportedIdentifierEvidence?
    let incomingIdentity: ImportedIdentifierEvidence?
    let outgoingIdentity: ImportedIdentifierEvidence?
    let order: OrderEvidence?

    init(
        substitutionIdentity: ImportedIdentifierEvidence? = nil,
        incomingIdentity: ImportedIdentifierEvidence? = nil,
        outgoingIdentity: ImportedIdentifierEvidence? = nil,
        order: OrderEvidence? = nil
    ) {
        self.substitutionIdentity = substitutionIdentity
        self.incomingIdentity = incomingIdentity
        self.outgoingIdentity = outgoingIdentity
        self.order = order
    }
}

struct GamePlayerParticipation: Hashable, Sendable {
    let participantIdentity: ImportedIdentifierEvidence
    let gameIdentity: ImportedIdentifierEvidence
    let playerResolution: PlayerResolution
    let teamEvidence: PlayerTeamEvidence
    let historicalDisplay: PlayerDisplayEvidence
    let roles: Set<PlayerParticipantRole>
    let lineupEvidence: PlayerLineupParticipationEvidence?
    let plateAppearanceEvidence: [PlayerPlateAppearanceEvidence]
    let pitcherAppearanceEvidence: [PlayerPitcherAppearanceEvidence]
    let substitutionEvidence: [PlayerSubstitutionEvidence]
    let source: PlayerEvidenceSource

    init(
        participantIdentity: ImportedIdentifierEvidence = .missing,
        gameIdentity: ImportedIdentifierEvidence,
        playerResolution: PlayerResolution,
        teamEvidence: PlayerTeamEvidence = .missing,
        historicalDisplay: PlayerDisplayEvidence = PlayerDisplayEvidence(),
        roles: Set<PlayerParticipantRole> = [],
        lineupEvidence: PlayerLineupParticipationEvidence? = nil,
        plateAppearanceEvidence: [PlayerPlateAppearanceEvidence] = [],
        pitcherAppearanceEvidence: [PlayerPitcherAppearanceEvidence] = [],
        substitutionEvidence: [PlayerSubstitutionEvidence] = [],
        source: PlayerEvidenceSource = .unknown
    ) {
        self.participantIdentity = participantIdentity
        self.gameIdentity = gameIdentity
        self.playerResolution = playerResolution
        self.teamEvidence = teamEvidence
        self.historicalDisplay = historicalDisplay
        self.roles = roles
        self.lineupEvidence = lineupEvidence
        self.plateAppearanceEvidence = plateAppearanceEvidence
        self.pitcherAppearanceEvidence = pitcherAppearanceEvidence
        self.substitutionEvidence = substitutionEvidence
        self.source = source
    }

    var reusablePlayerIdentity: ImportedIdentifierEvidence? {
        if case let .reusablePlayer(player) = playerResolution { return player.identity }
        return nil
    }
}

enum GamePlayerParticipationClassification: Hashable, Sendable {
    case resolvedParticipant
    case missingReusablePlayerIdentity
    case invalidReusablePlayerIdentity
    case duplicateReusablePlayerIdentity
    case conflictingPlayerEvidence
    case unknownParticipant
    case importedDetachedParticipant
    case unresolvedRole
    case missingGameIdentity
    case invalidGameIdentity
}

enum CanonicalPlayerMeaningClassifier {
    static func compare(_ lhs: ReusableCanonicalPlayer, _ rhs: ReusableCanonicalPlayer) -> PlayerMeaningComparison {
        switch StableIdentityClassifier.compare(lhs.stableIdentityEvidence, rhs.stableIdentityEvidence) {
        case .sameIdentifierMatchingEvidence:
            return .sameIdentityMatchingDisplay
        case let .sameIdentifierConflictingEvidence(fields):
            return .sameIdentityConflictingDisplay(fields)
        case .differentIdentifiersMatchingDisplay:
            return .distinctIdentitiesMatchingDisplay
        case .differentIdentifiersDifferentDisplay:
            return .distinctIdentitiesDifferentDisplay
        case .bothMissingIdentifier:
            return .bothMissingIdentifier
        case .oneMissingIdentifier:
            return .oneMissingIdentifier
        case .invalidIdentifier:
            return .invalidIdentifier
        case .unresolvedEquivalence:
            return .unresolvedEquivalence
        }
    }

    static func classifyDuplicates(_ players: [ReusableCanonicalPlayer]) -> [PlayerDuplicateClassification] {
        let stableClassifications = StableIdentityClassifier.classifyDuplicates(players.map(\.stableIdentityEvidence))
        return stableClassifications.map { classification in
            switch classification {
            case .exactRepeatedEvidence:
                return .exactRepeatedEvidence
            case .duplicateIdentifierMatchingContent:
                return .duplicateIdentifierMatchingDisplay
            case let .duplicateIdentifierConflictingContent(fields):
                return .duplicateIdentifierConflictingDisplay(fields)
            case .differentIdentifiersMatchingDisplay:
                return .differentIdentifiersMatchingDisplay
            case .missingIdentifier:
                return .missingIdentifier
            case .invalidIdentifier:
                return .invalidIdentifier
            case .unresolvedEquivalence:
                return .unresolvedEquivalence
            }
        }
    }

    static func classifyParticipant(_ participant: GamePlayerParticipation) -> GamePlayerParticipationClassification {
        switch participant.gameIdentity {
        case .missing:
            return .missingGameIdentity
        case .invalid:
            return .invalidGameIdentity
        case .valid:
            break
        }

        if participant.roles.isEmpty || participant.roles == [.unresolved] {
            return .unresolvedRole
        }

        switch participant.playerResolution {
        case .reusablePlayer:
            return .resolvedParticipant
        case .missingIdentity:
            return .missingReusablePlayerIdentity
        case .invalidIdentity:
            return .invalidReusablePlayerIdentity
        case .duplicateIdentity:
            return .duplicateReusablePlayerIdentity
        case .conflictingEvidence:
            return .conflictingPlayerEvidence
        case .unknown:
            return .unknownParticipant
        case .importedDetached:
            return .importedDetachedParticipant
        }
    }
}

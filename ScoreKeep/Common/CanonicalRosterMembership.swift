import Foundation

/// Non-routed Phase 1 foundation for current roster-membership meaning.
/// These values do not read, write, migrate, or route existing SwiftData records.
enum RosterMembershipEvidenceSource: String, Hashable, Sendable {
    case currentReusableRelationship
    case importedRoster
    case importedGame
    case compatibilityTransport
    case historicalGameParticipation
    case syntheticVerification
    case unknown
}

enum RosterMembershipTeamEvidence: Hashable, Sendable {
    case reusableTeam(ReusableCanonicalTeam)
    case missing
    case invalidIdentity(ImportedIdentifierEvidence, TeamDisplayEvidence)
    case unknown(TeamDisplayEvidence)
    case conflicting(ImportedIdentifierEvidence, TeamDisplayEvidence)

    var identity: ImportedIdentifierEvidence {
        switch self {
        case let .reusableTeam(team):
            return team.identity
        case .missing, .unknown:
            return .missing
        case let .invalidIdentity(identity, _), let .conflicting(identity, _):
            return identity
        }
    }
}

enum RosterMembershipPlayerEvidence: Hashable, Sendable {
    case reusablePlayer(ReusableCanonicalPlayer)
    case missing
    case invalidIdentity(ImportedIdentifierEvidence, PlayerDisplayEvidence)
    case unknown(PlayerDisplayEvidence)
    case conflicting(ImportedIdentifierEvidence, PlayerDisplayEvidence)
    case detachedImported(PlayerDisplayEvidence)

    var identity: ImportedIdentifierEvidence {
        switch self {
        case let .reusablePlayer(player):
            return player.identity
        case .missing, .unknown, .detachedImported:
            return .missing
        case let .invalidIdentity(identity, _), let .conflicting(identity, _):
            return identity
        }
    }
}

struct RosterMembershipDisplayEvidence: Hashable, Sendable {
    let jerseyNumber: PlayerTextEvidence
    let position: PlayerTextEvidence
    let rosterOrder: OrderEvidence?
    let battingOrder: OrderEvidence?
    let media: PlayerMediaEvidence

    init(
        jerseyNumber: PlayerTextEvidence = .missing,
        position: PlayerTextEvidence = .missing,
        rosterOrder: OrderEvidence? = nil,
        battingOrder: OrderEvidence? = nil,
        media: PlayerMediaEvidence = .missing
    ) {
        self.jerseyNumber = jerseyNumber
        self.position = position
        self.rosterOrder = rosterOrder
        self.battingOrder = battingOrder
        self.media = media
    }
}

struct CurrentRosterMembership: Hashable, Sendable {
    let teamEvidence: RosterMembershipTeamEvidence
    let playerEvidence: RosterMembershipPlayerEvidence
    let displayEvidence: RosterMembershipDisplayEvidence
    let source: RosterMembershipEvidenceSource

    init(
        teamEvidence: RosterMembershipTeamEvidence,
        playerEvidence: RosterMembershipPlayerEvidence,
        displayEvidence: RosterMembershipDisplayEvidence = RosterMembershipDisplayEvidence(),
        source: RosterMembershipEvidenceSource = .unknown
    ) {
        self.teamEvidence = teamEvidence
        self.playerEvidence = playerEvidence
        self.displayEvidence = displayEvidence
        self.source = source
    }

    static func == (lhs: CurrentRosterMembership, rhs: CurrentRosterMembership) -> Bool {
        switch (lhs.teamEvidence.identity, lhs.playerEvidence.identity, rhs.teamEvidence.identity, rhs.playerEvidence.identity) {
        case let (.valid(lhsTeamID), .valid(lhsPlayerID), .valid(rhsTeamID), .valid(rhsPlayerID)):
            return lhsTeamID == rhsTeamID && lhsPlayerID == rhsPlayerID
        default:
            return lhs.hasExactEvidence(as: rhs)
        }
    }

    func hash(into hasher: inout Hasher) {
        switch (teamEvidence.identity, playerEvidence.identity) {
        case let (.valid(teamID), .valid(playerID)):
            hasher.combine("CurrentRosterMembership.validRelationship")
            hasher.combine(teamID)
            hasher.combine(playerID)
        default:
            hasher.combine("CurrentRosterMembership.unresolvedRelationship")
            hasher.combine(teamEvidence)
            hasher.combine(playerEvidence)
            hasher.combine(displayEvidence)
            hasher.combine(source)
        }
    }

    func hasExactEvidence(as other: CurrentRosterMembership) -> Bool {
        teamEvidence == other.teamEvidence &&
            playerEvidence == other.playerEvidence &&
            displayEvidence == other.displayEvidence &&
            source == other.source
    }
}

struct PlayerWithoutCurrentRosterMembership: Hashable, Sendable {
    let player: ReusableCanonicalPlayer
    let historicalParticipation: [GamePlayerParticipation]

    init(player: ReusableCanonicalPlayer, historicalParticipation: [GamePlayerParticipation] = []) {
        self.player = player
        self.historicalParticipation = historicalParticipation
    }
}

struct TeamRosterMembershipSet: Hashable, Sendable {
    let team: ReusableCanonicalTeam
    let memberships: [CurrentRosterMembership]

    init(team: ReusableCanonicalTeam, memberships: [CurrentRosterMembership] = []) {
        self.team = team
        self.memberships = memberships
    }
}

enum RosterMembershipClassification: Hashable, Sendable {
    case current
    case missingTeamIdentity
    case invalidTeamIdentity
    case missingPlayerIdentity
    case invalidPlayerIdentity
    case incompleteMembership
    case unresolvedMembership
    case conflictingMembershipEvidence
    case importedMembershipEvidence
}

enum RosterMembershipConflictField: String, Hashable, Sendable, Comparable {
    case jerseyNumber
    case position
    case rosterOrder
    case battingOrder
    case media
    case source
    case teamIdentity
    case playerIdentity

    static func < (lhs: RosterMembershipConflictField, rhs: RosterMembershipConflictField) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum RosterMembershipComparison: Hashable, Sendable {
    case sameTeamAndPlayerMatchingEvidence
    case sameTeamAndPlayerConflictingEvidence([RosterMembershipConflictField])
    case samePlayerDifferentCurrentTeams
    case distinctMemberships
    case exactRepeatedEvidence
    case missingTeamIdentity
    case invalidTeamIdentity
    case missingPlayerIdentity
    case invalidPlayerIdentity
    case unresolvedEquivalence
}

enum RosterMembershipSetClassification: Hashable, Sendable {
    case emptyRoster
    case oneCurrentMembership
    case multipleCurrentMemberships
    case containsIncompleteMembership
    case containsUnresolvedMembership
    case containsInvalidRelationship
    case containsDuplicateMembership
    case containsConflictingMembership
    case duplicatePlayerIdentity(UUID)
    case playerOnMultipleCurrentTeams(UUID)
    case duplicateJerseyNumber(String)
    case duplicateRosterOrder(Int)
    case mixedTeamEvidence
    case teamWithEmptyRoster(UUID?)
    case playerWithoutCurrentTeam(UUID?)
    case historicalParticipationOnly
}

enum CanonicalRosterMembershipClassifier {
    static func classify(_ membership: CurrentRosterMembership) -> RosterMembershipClassification {
        switch membership.teamEvidence.identity {
        case .missing:
            return .missingTeamIdentity
        case .invalid:
            return .invalidTeamIdentity
        case .valid:
            break
        }

        switch membership.playerEvidence.identity {
        case .missing:
            return .missingPlayerIdentity
        case .invalid:
            return .invalidPlayerIdentity
        case .valid:
            break
        }

        if case .conflicting = membership.teamEvidence { return .conflictingMembershipEvidence }
        if case .conflicting = membership.playerEvidence { return .conflictingMembershipEvidence }
        if case .unknown = membership.teamEvidence { return .unresolvedMembership }
        if case .unknown = membership.playerEvidence { return .unresolvedMembership }
        if case .detachedImported = membership.playerEvidence { return .importedMembershipEvidence }

        switch membership.source {
        case .importedRoster, .compatibilityTransport:
            return .importedMembershipEvidence
        default:
            return .current
        }
    }

    static func compare(_ lhs: CurrentRosterMembership, _ rhs: CurrentRosterMembership) -> RosterMembershipComparison {
        if lhs.hasExactEvidence(as: rhs) { return .exactRepeatedEvidence }

        switch (lhs.teamEvidence.identity, rhs.teamEvidence.identity) {
        case (.invalid, _), (_, .invalid):
            return .invalidTeamIdentity
        case (.missing, _), (_, .missing):
            return .missingTeamIdentity
        case (.valid, .valid):
            break
        }

        switch (lhs.playerEvidence.identity, rhs.playerEvidence.identity) {
        case (.invalid, _), (_, .invalid):
            return .invalidPlayerIdentity
        case (.missing, _), (_, .missing):
            return .missingPlayerIdentity
        case (.valid, .valid):
            break
        }

        guard case let .valid(lhsTeamID) = lhs.teamEvidence.identity,
              case let .valid(rhsTeamID) = rhs.teamEvidence.identity,
              case let .valid(lhsPlayerID) = lhs.playerEvidence.identity,
              case let .valid(rhsPlayerID) = rhs.playerEvidence.identity else {
            return .unresolvedEquivalence
        }

        if lhsPlayerID == rhsPlayerID && lhsTeamID != rhsTeamID {
            return .samePlayerDifferentCurrentTeams
        }

        guard lhsTeamID == rhsTeamID && lhsPlayerID == rhsPlayerID else {
            return .distinctMemberships
        }

        let conflicts = conflictFields(lhs.displayEvidence, rhs.displayEvidence, sourceA: lhs.source, sourceB: rhs.source)
        return conflicts.isEmpty ? .sameTeamAndPlayerMatchingEvidence : .sameTeamAndPlayerConflictingEvidence(conflicts)
    }

    static func classifyRoster(
        _ memberships: [CurrentRosterMembership],
        expectedTeamIdentity: ImportedIdentifierEvidence? = nil
    ) -> Set<RosterMembershipSetClassification> {
        guard memberships.isEmpty == false else { return [.emptyRoster] }

        var classifications: Set<RosterMembershipSetClassification> = memberships.count == 1
            ? [.oneCurrentMembership]
            : [.multipleCurrentMemberships]

        var seenMemberships: [CurrentRosterMembership] = []
        var playerTeams: [UUID: Set<UUID>] = [:]
        var playerCounts: [UUID: Int] = [:]
        var jerseyNumbers: [String: Int] = [:]
        var rosterOrders: [Int: Int] = [:]
        var teamIDs: Set<UUID> = []
        var reusableTeamsByID: [UUID: ReusableCanonicalTeam] = [:]

        for membership in memberships {
            switch classify(membership) {
            case .current, .importedMembershipEvidence:
                break
            case .missingTeamIdentity, .missingPlayerIdentity, .incompleteMembership:
                classifications.insert(.containsIncompleteMembership)
            case .invalidTeamIdentity, .invalidPlayerIdentity:
                classifications.insert(.containsInvalidRelationship)
            case .unresolvedMembership:
                classifications.insert(.containsUnresolvedMembership)
            case .conflictingMembershipEvidence:
                classifications.insert(.containsConflictingMembership)
            }

            if seenMemberships.contains(where: { compare($0, membership) == .exactRepeatedEvidence }) {
                classifications.insert(.containsDuplicateMembership)
            }

            for existing in seenMemberships {
                switch compare(existing, membership) {
                case .sameTeamAndPlayerMatchingEvidence, .exactRepeatedEvidence:
                    classifications.insert(.containsDuplicateMembership)
                case .sameTeamAndPlayerConflictingEvidence:
                    classifications.insert(.containsDuplicateMembership)
                    classifications.insert(.containsConflictingMembership)
                case .samePlayerDifferentCurrentTeams:
                    if case let .valid(playerID) = membership.playerEvidence.identity {
                        classifications.insert(.playerOnMultipleCurrentTeams(playerID))
                    }
                default:
                    break
                }
            }
            seenMemberships.append(membership)

            if case let .valid(teamID) = membership.teamEvidence.identity {
                teamIDs.insert(teamID)
                if case let .reusableTeam(team) = membership.teamEvidence {
                    if let existingTeam = reusableTeamsByID[teamID] {
                        if case .sameIdentityConflictingDisplay = CanonicalTeamMeaningClassifier.compare(existingTeam, team) {
                            classifications.insert(.containsConflictingMembership)
                        }
                    } else {
                        reusableTeamsByID[teamID] = team
                    }
                }
                if case let .valid(playerID) = membership.playerEvidence.identity {
                    playerTeams[playerID, default: []].insert(teamID)
                    playerCounts[playerID, default: 0] += 1
                }
            }

            if let number = membership.displayEvidence.jerseyNumber.value, number.isEmpty == false {
                jerseyNumbers[number, default: 0] += 1
            }

            if let order = membership.displayEvidence.rosterOrder?.value {
                rosterOrders[order, default: 0] += 1
            }
        }

        for (playerID, count) in playerCounts where count > 1 {
            classifications.insert(.duplicatePlayerIdentity(playerID))
        }

        for (playerID, teams) in playerTeams where teams.count > 1 {
            classifications.insert(.playerOnMultipleCurrentTeams(playerID))
        }

        for (number, count) in jerseyNumbers where count > 1 {
            classifications.insert(.duplicateJerseyNumber(number))
        }

        for (order, count) in rosterOrders where count > 1 {
            classifications.insert(.duplicateRosterOrder(order))
        }

        if let expectedTeamIdentity, case let .valid(expectedTeamID) = expectedTeamIdentity {
            if teamIDs.contains(where: { $0 != expectedTeamID }) {
                classifications.insert(.mixedTeamEvidence)
            }
        } else if teamIDs.count > 1 {
            classifications.insert(.mixedTeamEvidence)
        }

        return classifications
    }

    static func classifyTeamRoster(_ roster: TeamRosterMembershipSet) -> Set<RosterMembershipSetClassification> {
        var classifications = classifyRoster(roster.memberships, expectedTeamIdentity: roster.team.identity)
        if roster.memberships.isEmpty {
            classifications.insert(.teamWithEmptyRoster(roster.team.identity.validIdentifier))
        }
        return classifications
    }

    static func classifyPlayerWithoutCurrentTeam(_ evidence: PlayerWithoutCurrentRosterMembership) -> Set<RosterMembershipSetClassification> {
        var classifications: Set<RosterMembershipSetClassification> = [
            .playerWithoutCurrentTeam(evidence.player.identity.validIdentifier)
        ]
        if evidence.historicalParticipation.isEmpty == false {
            classifications.insert(.historicalParticipationOnly)
        }
        return classifications
    }

    private static func conflictFields(
        _ lhs: RosterMembershipDisplayEvidence,
        _ rhs: RosterMembershipDisplayEvidence,
        sourceA: RosterMembershipEvidenceSource,
        sourceB: RosterMembershipEvidenceSource
    ) -> [RosterMembershipConflictField] {
        var fields: Set<RosterMembershipConflictField> = []

        if lhs.jerseyNumber != rhs.jerseyNumber { fields.insert(.jerseyNumber) }
        if lhs.position != rhs.position { fields.insert(.position) }
        if lhs.rosterOrder != rhs.rosterOrder { fields.insert(.rosterOrder) }
        if lhs.battingOrder != rhs.battingOrder { fields.insert(.battingOrder) }
        if lhs.media != rhs.media { fields.insert(.media) }
        if sourceA != sourceB { fields.insert(.source) }

        return fields.sorted()
    }
}

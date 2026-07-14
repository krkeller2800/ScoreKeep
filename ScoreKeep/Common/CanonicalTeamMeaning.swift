import Foundation

/// Non-routed Phase 1 foundation for reusable team and game-side team meaning.
/// These values do not read, write, migrate, or route existing SwiftData records.
enum TeamEvidenceSource: String, Hashable, Sendable {
    case currentReusableRecord
    case historicalGameSide
    case importedRoster
    case importedGame
    case compatibilityTransport
    case unknown
}

enum TeamTextEvidence: Hashable, Sendable {
    case missing
    case present(String)

    var value: String? {
        if case let .present(value) = self { return value }
        return nil
    }
}

enum TeamLogoEvidence: Hashable, Sendable {
    case missing
    case present(Data)
    case invalid(String)
}

struct TeamDisplayEvidence: Hashable, Sendable {
    let name: TeamTextEvidence
    let coach: TeamTextEvidence
    let details: TeamTextEvidence
    let logo: TeamLogoEvidence

    init(
        name: TeamTextEvidence = .missing,
        coach: TeamTextEvidence = .missing,
        details: TeamTextEvidence = .missing,
        logo: TeamLogoEvidence = .missing
    ) {
        self.name = name
        self.coach = coach
        self.details = details
        self.logo = logo
    }

    var stableIdentityDisplayEvidence: [IdentityDisplayEvidence] {
        var evidence: [IdentityDisplayEvidence] = []
        if let name = name.value { evidence.append(.init("name", name)) }
        if let coach = coach.value { evidence.append(.init("coach", coach)) }
        if let details = details.value { evidence.append(.init("details", details)) }
        switch logo {
        case .missing:
            break
        case let .present(data):
            evidence.append(.init("logoByteCount", String(data.count)))
        case let .invalid(reason):
            evidence.append(.init("logoInvalid", reason))
        }
        return evidence
    }
}

enum TeamRosterEvidence: Hashable, Sendable {
    case notRepresented
    case relationshipReference(count: Int?)
    case importedRosterReference(count: Int?)
}

struct ReusableCanonicalTeam: Hashable, Sendable {
    let identity: ImportedIdentifierEvidence
    let display: TeamDisplayEvidence
    let rosterEvidence: TeamRosterEvidence
    let source: TeamEvidenceSource

    init(
        identity: ImportedIdentifierEvidence,
        display: TeamDisplayEvidence = TeamDisplayEvidence(),
        rosterEvidence: TeamRosterEvidence = .notRepresented,
        source: TeamEvidenceSource = .unknown
    ) {
        self.identity = identity
        self.display = display
        self.rosterEvidence = rosterEvidence
        self.source = source
    }

    static func == (lhs: ReusableCanonicalTeam, rhs: ReusableCanonicalTeam) -> Bool {
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
            hasher.combine("ReusableCanonicalTeam.validIdentity")
            hasher.combine(identifier)
        default:
            hasher.combine("ReusableCanonicalTeam.unresolvedIdentity")
            hasher.combine(identity)
            hasher.combine(display)
            hasher.combine(rosterEvidence)
            hasher.combine(source)
        }
    }

    var stableIdentityEvidence: StableIdentityEvidence {
        StableIdentityEvidence(
            concept: .team,
            importedIdentifier: identity,
            displayEvidence: display.stableIdentityDisplayEvidence
        )
    }
}

enum TeamMeaningComparison: Hashable, Sendable {
    case sameIdentityMatchingDisplay
    case sameIdentityConflictingDisplay([String])
    case distinctIdentitiesMatchingDisplay
    case distinctIdentitiesDifferentDisplay
    case bothMissingIdentifier
    case oneMissingIdentifier
    case invalidIdentifier
    case unresolvedEquivalence
}

enum TeamDuplicateClassification: Hashable, Sendable {
    case exactRepeatedEvidence
    case duplicateIdentifierMatchingDisplay
    case duplicateIdentifierConflictingDisplay([String])
    case differentIdentifiersMatchingDisplay
    case missingIdentifier
    case invalidIdentifier
    case unresolvedEquivalence
}

enum TeamSideRole: String, Hashable, Sendable {
    case home
    case visiting
    case unresolved
}

enum TeamSideResolution: Hashable, Sendable {
    case reusableTeam(ReusableCanonicalTeam)
    case unknown(TeamDisplayEvidence)
    case missing
    case conflicting(TeamDisplayEvidence)
}

struct GameSideTeamParticipation: Hashable, Sendable {
    let gameIdentity: ImportedIdentifierEvidence
    let role: TeamSideRole
    let resolution: TeamSideResolution
    let historicalDisplay: TeamDisplayEvidence
    let source: TeamEvidenceSource

    init(
        gameIdentity: ImportedIdentifierEvidence,
        role: TeamSideRole,
        resolution: TeamSideResolution,
        historicalDisplay: TeamDisplayEvidence = TeamDisplayEvidence(),
        source: TeamEvidenceSource = .unknown
    ) {
        self.gameIdentity = gameIdentity
        self.role = role
        self.resolution = resolution
        self.historicalDisplay = historicalDisplay
        self.source = source
    }

    var reusableTeamIdentity: ImportedIdentifierEvidence? {
        if case let .reusableTeam(team) = resolution { return team.identity }
        return nil
    }
}

enum TeamSideSetClassification: Hashable, Sendable {
    case completeDistinctSides
    case sameReusableTeamOnBothSides
    case missingHomeSide
    case missingVisitingSide
    case bothSidesUnresolved
    case unresolvedSideRole
    case contradictorySideEvidence([String])
}

enum CanonicalTeamMeaningClassifier {
    static func compare(_ lhs: ReusableCanonicalTeam, _ rhs: ReusableCanonicalTeam) -> TeamMeaningComparison {
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

    static func classifyDuplicates(_ teams: [ReusableCanonicalTeam]) -> [TeamDuplicateClassification] {
        let stableClassifications = StableIdentityClassifier.classifyDuplicates(teams.map(\.stableIdentityEvidence))
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

    static func classifyGameSides(
        home: GameSideTeamParticipation?,
        visiting: GameSideTeamParticipation?
    ) -> TeamSideSetClassification {
        guard let home, let visiting else {
            if home == nil && visiting == nil { return .bothSidesUnresolved }
            return home == nil ? .missingHomeSide : .missingVisitingSide
        }

        guard home.role == .home, visiting.role == .visiting else {
            return .unresolvedSideRole
        }

        if case .conflicting = home.resolution { return .contradictorySideEvidence(["home"]) }
        if case .conflicting = visiting.resolution { return .contradictorySideEvidence(["visiting"]) }

        if sameReusableIdentity(home.reusableTeamIdentity, visiting.reusableTeamIdentity) {
            return .sameReusableTeamOnBothSides
        }

        return .completeDistinctSides
    }

    private static func sameReusableIdentity(
        _ lhs: ImportedIdentifierEvidence?,
        _ rhs: ImportedIdentifierEvidence?
    ) -> Bool {
        guard case let .valid(lhsID)? = lhs, case let .valid(rhsID)? = rhs else { return false }
        return lhsID == rhsID
    }
}

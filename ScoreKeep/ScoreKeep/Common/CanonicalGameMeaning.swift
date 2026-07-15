import Foundation

/// Non-routed Phase 1 foundation for game identity, configuration, origin, and lifecycle meaning.
/// These values do not read, write, migrate, or route existing SwiftData records.
enum GameEvidenceSource: String, Hashable, Sendable {
    case currentGameRecord
    case userCreatedGame
    case importedGame
    case seededGame
    case sampleGame
    case compatibilityTransport
    case syntheticVerification
    case unknown
}

enum GameOriginEvidence: Hashable, Sendable {
    case userCreated
    case imported
    case seeded
    case sample
    case unknown
    case conflicting(Set<GameOriginEvidence>)
}

enum GameLifecycleEvidence: Hashable, Sendable {
    case draft
    case ready
    case inProgress
    case completed
    case interrupted
    case incomplete
    case imported
    case unknown
    case unresolved
    case conflicting(Set<GameLifecycleEvidence>)
}

enum GameConfigurationEvidence: Hashable, Sendable {
    case configured(expectedInnings: ExpectedInningCountEvidence, lineupMode: LineupModeEvidence)
    case missing
    case invalid(String)
    case conflicting([String])
}

struct GameDisplayEvidence: Hashable, Sendable {
    let date: String?
    let location: String?
    let homeTeamName: String?
    let visitingTeamName: String?
    let storedHomeScore: Int?
    let storedVisitingScore: Int?
    let doubleheaderDesignator: String?

    init(
        date: String? = nil,
        location: String? = nil,
        homeTeamName: String? = nil,
        visitingTeamName: String? = nil,
        storedHomeScore: Int? = nil,
        storedVisitingScore: Int? = nil,
        doubleheaderDesignator: String? = nil
    ) {
        self.date = date
        self.location = location
        self.homeTeamName = homeTeamName
        self.visitingTeamName = visitingTeamName
        self.storedHomeScore = storedHomeScore
        self.storedVisitingScore = storedVisitingScore
        self.doubleheaderDesignator = doubleheaderDesignator
    }

    var stableIdentityDisplayEvidence: [IdentityDisplayEvidence] {
        var evidence: [IdentityDisplayEvidence] = []
        if let date { evidence.append(.init("date", date)) }
        if let location { evidence.append(.init("location", location)) }
        if let homeTeamName { evidence.append(.init("homeTeamName", homeTeamName)) }
        if let visitingTeamName { evidence.append(.init("visitingTeamName", visitingTeamName)) }
        if let doubleheaderDesignator { evidence.append(.init("doubleheaderDesignator", doubleheaderDesignator)) }
        return evidence
    }
}

struct CanonicalGameIdentity: Hashable, Sendable {
    let identity: ImportedIdentifierEvidence
    let displayEvidence: GameDisplayEvidence
    let configuration: GameConfigurationEvidence
    let origin: GameOriginEvidence
    let lifecycle: GameLifecycleEvidence
    let source: GameEvidenceSource

    init(
        identity: ImportedIdentifierEvidence,
        displayEvidence: GameDisplayEvidence = GameDisplayEvidence(),
        configuration: GameConfigurationEvidence = .missing,
        origin: GameOriginEvidence = .unknown,
        lifecycle: GameLifecycleEvidence = .unknown,
        source: GameEvidenceSource = .unknown
    ) {
        self.identity = identity
        self.displayEvidence = displayEvidence
        self.configuration = configuration
        self.origin = origin
        self.lifecycle = lifecycle
        self.source = source
    }

    static func == (lhs: CanonicalGameIdentity, rhs: CanonicalGameIdentity) -> Bool {
        switch (lhs.identity, rhs.identity) {
        case let (.valid(lhsID), .valid(rhsID)):
            return lhsID == rhsID
        default:
            return lhs.hasExactEvidence(as: rhs)
        }
    }

    func hash(into hasher: inout Hasher) {
        switch identity {
        case let .valid(identifier):
            hasher.combine("CanonicalGameIdentity.validIdentity")
            hasher.combine(identifier)
        default:
            hasher.combine("CanonicalGameIdentity.unresolvedIdentity")
            hasher.combine(identity)
            hasher.combine(displayEvidence)
            hasher.combine(configuration)
            hasher.combine(origin)
            hasher.combine(lifecycle)
            hasher.combine(source)
        }
    }

    var stableIdentityEvidence: StableIdentityEvidence {
        StableIdentityEvidence(
            concept: .game,
            importedIdentifier: identity,
            displayEvidence: displayEvidence.stableIdentityDisplayEvidence
        )
    }

    func hasExactEvidence(as other: CanonicalGameIdentity) -> Bool {
        identity == other.identity &&
            displayEvidence == other.displayEvidence &&
            configuration == other.configuration &&
            origin == other.origin &&
            lifecycle == other.lifecycle &&
            source == other.source
    }
}

enum GameIdentityComparison: Hashable, Sendable {
    case sameIdentityMatchingEvidence
    case sameIdentityConflictingEvidence([String])
    case distinctIdentitiesMatchingDisplay
    case distinctIdentitiesDifferentDisplay
    case missingIdentity
    case invalidIdentity
    case unresolvedIdentity
}

enum GameIdentitySetClassification: Hashable, Sendable {
    case oneGame
    case multipleGames
    case duplicateGame
    case duplicateConflictingGame([String])
    case missingGameIdentity
    case invalidGameIdentity
    case doubleheaderDistinctGames
    case sameTeamsAndDateDistinctGames
    case contradictoryEvidence
    case unresolvedEvidence
}

enum GameLifecycleClassification: Hashable, Sendable {
    case draft
    case ready
    case inProgress
    case completed
    case interrupted
    case incomplete
    case imported
    case unknown
    case unresolved
    case conflictingLifecycle
}

enum GameOriginClassification: Hashable, Sendable {
    case userCreated
    case imported
    case seeded
    case sample
    case unknown
    case conflictingOrigin
}

enum CanonicalGameMeaningClassifier {
    static func compareIdentity(_ lhs: CanonicalGameIdentity, _ rhs: CanonicalGameIdentity) -> GameIdentityComparison {
        switch StableIdentityClassifier.compare(lhs.stableIdentityEvidence, rhs.stableIdentityEvidence) {
        case .sameIdentifierMatchingEvidence:
            let conflicts = nonIdentityConflicts(lhs, rhs)
            return conflicts.isEmpty ? .sameIdentityMatchingEvidence : .sameIdentityConflictingEvidence(conflicts)
        case let .sameIdentifierConflictingEvidence(fields):
            return .sameIdentityConflictingEvidence(fields + nonIdentityConflicts(lhs, rhs))
        case .differentIdentifiersMatchingDisplay:
            return .distinctIdentitiesMatchingDisplay
        case .differentIdentifiersDifferentDisplay:
            return .distinctIdentitiesDifferentDisplay
        case .bothMissingIdentifier, .oneMissingIdentifier:
            return .missingIdentity
        case .invalidIdentifier:
            return .invalidIdentity
        case .unresolvedEquivalence:
            return .unresolvedIdentity
        }
    }

    static func classifyGame(_ game: CanonicalGameIdentity) -> Set<GameIdentitySetClassification> {
        var classifications: Set<GameIdentitySetClassification> = []
        switch game.identity {
        case .valid:
            break
        case .missing:
            classifications.insert(.missingGameIdentity)
        case .invalid:
            classifications.insert(.invalidGameIdentity)
        }

        if case .conflicting = game.configuration {
            classifications.insert(.contradictoryEvidence)
        }
        if case .conflicting = game.lifecycle {
            classifications.insert(.contradictoryEvidence)
        }
        if case .conflicting = game.origin {
            classifications.insert(.contradictoryEvidence)
        }
        return classifications
    }

    static func classifyGameSet(_ games: [CanonicalGameIdentity]) -> Set<GameIdentitySetClassification> {
        var classifications: Set<GameIdentitySetClassification> = games.count == 1 ? [.oneGame] : [.multipleGames]
        games.forEach { classifications.formUnion(classifyGame($0)) }

        for lhsIndex in games.indices {
            for rhsIndex in games.index(after: lhsIndex)..<games.endIndex {
                let lhs = games[lhsIndex]
                let rhs = games[rhsIndex]
                switch compareIdentity(lhs, rhs) {
                case .sameIdentityMatchingEvidence:
                    classifications.insert(.duplicateGame)
                case let .sameIdentityConflictingEvidence(fields):
                    classifications.insert(.duplicateConflictingGame(fields))
                    classifications.insert(.contradictoryEvidence)
                case .distinctIdentitiesMatchingDisplay:
                    classifications.insert(.sameTeamsAndDateDistinctGames)
                    if lhs.displayEvidence.doubleheaderDesignator != nil || rhs.displayEvidence.doubleheaderDesignator != nil {
                        classifications.insert(.doubleheaderDistinctGames)
                    }
                case .distinctIdentitiesDifferentDisplay:
                    if sameTeamsAndDate(lhs.displayEvidence, rhs.displayEvidence) {
                        classifications.insert(.sameTeamsAndDateDistinctGames)
                        if lhs.displayEvidence.doubleheaderDesignator != nil || rhs.displayEvidence.doubleheaderDesignator != nil {
                            classifications.insert(.doubleheaderDistinctGames)
                        }
                    }
                case .missingIdentity, .invalidIdentity, .unresolvedIdentity:
                    classifications.insert(.unresolvedEvidence)
                }
            }
        }

        return classifications
    }

    static func classifyLifecycle(_ lifecycle: GameLifecycleEvidence) -> GameLifecycleClassification {
        switch lifecycle {
        case .draft:
            return .draft
        case .ready:
            return .ready
        case .inProgress:
            return .inProgress
        case .completed:
            return .completed
        case .interrupted:
            return .interrupted
        case .incomplete:
            return .incomplete
        case .imported:
            return .imported
        case .unknown:
            return .unknown
        case .unresolved:
            return .unresolved
        case .conflicting:
            return .conflictingLifecycle
        }
    }

    static func classifyOrigin(_ origin: GameOriginEvidence) -> GameOriginClassification {
        switch origin {
        case .userCreated:
            return .userCreated
        case .imported:
            return .imported
        case .seeded:
            return .seeded
        case .sample:
            return .sample
        case .unknown:
            return .unknown
        case .conflicting:
            return .conflictingOrigin
        }
    }

    private static func nonIdentityConflicts(_ lhs: CanonicalGameIdentity, _ rhs: CanonicalGameIdentity) -> [String] {
        var conflicts: [String] = []
        if lhs.configuration != rhs.configuration { conflicts.append("configuration") }
        if lhs.origin != rhs.origin { conflicts.append("origin") }
        if lhs.lifecycle != rhs.lifecycle { conflicts.append("lifecycle") }
        if lhs.source != rhs.source { conflicts.append("source") }
        return conflicts.sorted()
    }

    private static func sameTeamsAndDate(_ lhs: GameDisplayEvidence, _ rhs: GameDisplayEvidence) -> Bool {
        lhs.date != nil &&
            lhs.date == rhs.date &&
            lhs.homeTeamName != nil &&
            lhs.homeTeamName == rhs.homeTeamName &&
            lhs.visitingTeamName != nil &&
            lhs.visitingTeamName == rhs.visitingTeamName
    }
}

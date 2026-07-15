import Foundation

/// Non-routed Phase 1 foundation for game-specific lineup meaning.
/// These values do not read, write, migrate, or route existing SwiftData records.
enum LineupEvidenceSource: String, Hashable, Sendable {
    case currentLineupRecord
    case startingLineupView
    case editLineupView
    case importedGame
    case compatibilityTransport
    case seededGame
    case historicalGameParticipation
    case syntheticVerification
    case unknown
}

enum LineupModeEvidence: Hashable, Sendable {
    case traditional
    case everyoneHits
    case unknown
    case missing
    case unsupported(String)
    case ambiguous(String)
}

enum LineupSideEvidence: Hashable, Sendable {
    case gameSide(GameSideTeamParticipation)
    case home
    case visiting
    case unresolved
    case missing
    case conflicting(expected: TeamSideRole?, actual: TeamSideRole?)
    case inferredFromArrayPosition(TeamSideRole)

    var role: TeamSideRole? {
        switch self {
        case let .gameSide(side):
            return side.role
        case .home:
            return .home
        case .visiting:
            return .visiting
        case let .inferredFromArrayPosition(role):
            return role
        case let .conflicting(expected, _):
            return expected
        case .unresolved, .missing:
            return nil
        }
    }

    var teamIdentity: ImportedIdentifierEvidence? {
        if case let .gameSide(side) = self { return side.reusableTeamIdentity }
        return nil
    }
}

enum LineupTeamEvidence: Hashable, Sendable {
    case gameSide(GameSideTeamParticipation)
    case reusableTeam(ReusableCanonicalTeam)
    case missing
    case unknown(TeamDisplayEvidence)
    case invalidIdentity(ImportedIdentifierEvidence, TeamDisplayEvidence)
    case conflicting(ImportedIdentifierEvidence, TeamDisplayEvidence)

    var identity: ImportedIdentifierEvidence {
        switch self {
        case let .gameSide(side):
            return side.reusableTeamIdentity ?? .missing
        case let .reusableTeam(team):
            return team.identity
        case .missing, .unknown:
            return .missing
        case let .invalidIdentity(identity, _), let .conflicting(identity, _):
            return identity
        }
    }
}

enum LineupParticipantEvidence: Hashable, Sendable {
    case gameParticipant(GamePlayerParticipation)
    case reusablePlayer(ReusableCanonicalPlayer)
    case currentRosterMembership(CurrentRosterMembership)
    case missingPlayerIdentity(PlayerDisplayEvidence)
    case invalidPlayerIdentity(ImportedIdentifierEvidence, PlayerDisplayEvidence)
    case unknown(PlayerDisplayEvidence)
    case historicalPlayer(ReusableCanonicalPlayer, PlayerDisplayEvidence)
    case absentFromCurrentRoster(ReusableCanonicalPlayer)
    case wrongGameSide(GamePlayerParticipation)
    case unresolvedGameSide(GamePlayerParticipation)
    case importedDetached(PlayerDisplayEvidence)

    var playerIdentity: ImportedIdentifierEvidence {
        switch self {
        case let .gameParticipant(participant), let .wrongGameSide(participant), let .unresolvedGameSide(participant):
            return participant.reusablePlayerIdentity ?? participant.participantIdentity
        case let .reusablePlayer(player), let .historicalPlayer(player, _), let .absentFromCurrentRoster(player):
            return player.identity
        case let .currentRosterMembership(membership):
            return membership.playerEvidence.identity
        case .missingPlayerIdentity, .unknown, .importedDetached:
            return .missing
        case let .invalidPlayerIdentity(identity, _):
            return identity
        }
    }

    var gameIdentity: ImportedIdentifierEvidence? {
        switch self {
        case let .gameParticipant(participant), let .wrongGameSide(participant), let .unresolvedGameSide(participant):
            return participant.gameIdentity
        default:
            return nil
        }
    }

    var sideRole: TeamSideRole? {
        switch self {
        case let .gameParticipant(participant), let .wrongGameSide(participant), let .unresolvedGameSide(participant):
            if case let .gameSide(side) = participant.teamEvidence { return side.role }
            return nil
        case .currentRosterMembership:
            return nil
        default:
            return nil
        }
    }
}

enum RawBattingSlotEvidence: Hashable, Sendable {
    case known(Int)
    case missing
    case invalid(String)
    case unsupportedRawValue(Int)
    case nonHittingSentinel(Int)
    case conflicting([Int])

    var slotValue: Int? {
        if case let .known(value) = self { return value }
        return nil
    }
}

enum RawLineupPositionEvidence: Hashable, Sendable {
    case present(String)
    case blank
    case missing
    case unknown(String)
    case conflicting([String])
}

enum LineupPitcherRoleEvidence: Hashable, Sendable {
    case notRepresented
    case pitcherCandidate
    case pitcherOnly
    case unknown
    case conflicting
}

enum LineupSubstitutionEvidence: Hashable, Sendable {
    case initialLineup
    case laterLineupComposition
    case ambiguousLegacyArrays
    case notRepresented
}

struct LineupEntryEvidence: Hashable, Sendable {
    let entryIdentity: ImportedIdentifierEvidence
    let participant: LineupParticipantEvidence
    let battingSlot: RawBattingSlotEvidence
    let sourceOrder: OrderEvidence?
    let rawPosition: RawLineupPositionEvidence
    let historicalDisplay: PlayerDisplayEvidence
    let pitcherRole: LineupPitcherRoleEvidence
    let substitutionEvidence: LineupSubstitutionEvidence
    let source: LineupEvidenceSource

    init(
        entryIdentity: ImportedIdentifierEvidence = .missing,
        participant: LineupParticipantEvidence,
        battingSlot: RawBattingSlotEvidence = .missing,
        sourceOrder: OrderEvidence? = nil,
        rawPosition: RawLineupPositionEvidence = .missing,
        historicalDisplay: PlayerDisplayEvidence = PlayerDisplayEvidence(),
        pitcherRole: LineupPitcherRoleEvidence = .notRepresented,
        substitutionEvidence: LineupSubstitutionEvidence = .initialLineup,
        source: LineupEvidenceSource = .unknown
    ) {
        self.entryIdentity = entryIdentity
        self.participant = participant
        self.battingSlot = battingSlot
        self.sourceOrder = sourceOrder
        self.rawPosition = rawPosition
        self.historicalDisplay = historicalDisplay
        self.pitcherRole = pitcherRole
        self.substitutionEvidence = substitutionEvidence
        self.source = source
    }
}

struct CanonicalGameLineup: Hashable, Sendable {
    let lineupIdentity: ImportedIdentifierEvidence
    let gameIdentity: ImportedIdentifierEvidence
    let sideEvidence: LineupSideEvidence
    let teamEvidence: LineupTeamEvidence
    let mode: LineupModeEvidence
    let entries: [LineupEntryEvidence]
    let source: LineupEvidenceSource
    let rawInningEvidence: Int?

    init(
        lineupIdentity: ImportedIdentifierEvidence = .missing,
        gameIdentity: ImportedIdentifierEvidence,
        sideEvidence: LineupSideEvidence,
        teamEvidence: LineupTeamEvidence = .missing,
        mode: LineupModeEvidence = .unknown,
        entries: [LineupEntryEvidence] = [],
        source: LineupEvidenceSource = .unknown,
        rawInningEvidence: Int? = nil
    ) {
        self.lineupIdentity = lineupIdentity
        self.gameIdentity = gameIdentity
        self.sideEvidence = sideEvidence
        self.teamEvidence = teamEvidence
        self.mode = mode
        self.entries = entries
        self.source = source
        self.rawInningEvidence = rawInningEvidence
    }

    static func == (lhs: CanonicalGameLineup, rhs: CanonicalGameLineup) -> Bool {
        switch (lhs.lineupIdentity, rhs.lineupIdentity) {
        case let (.valid(lhsID), .valid(rhsID)):
            return lhsID == rhsID
        default:
            return lhs.hasExactEvidence(as: rhs)
        }
    }

    func hash(into hasher: inout Hasher) {
        switch lineupIdentity {
        case let .valid(identifier):
            hasher.combine("CanonicalGameLineup.validIdentity")
            hasher.combine(identifier)
        default:
            hasher.combine("CanonicalGameLineup.unresolvedIdentity")
            hasher.combine(lineupIdentity)
            hasher.combine(gameIdentity)
            hasher.combine(sideEvidence)
            hasher.combine(teamEvidence)
            hasher.combine(mode)
            hasher.combine(entries)
            hasher.combine(source)
            hasher.combine(rawInningEvidence)
        }
    }

    func hasExactEvidence(as other: CanonicalGameLineup) -> Bool {
        lineupIdentity == other.lineupIdentity &&
            gameIdentity == other.gameIdentity &&
            sideEvidence == other.sideEvidence &&
            teamEvidence == other.teamEvidence &&
            mode == other.mode &&
            entries == other.entries &&
            source == other.source &&
            rawInningEvidence == other.rawInningEvidence
    }

    var stableIdentityEvidence: StableIdentityEvidence {
        var displayEvidence: [IdentityDisplayEvidence] = []
        if let rawInningEvidence { displayEvidence.append(.init("inning", String(rawInningEvidence))) }
        if let role = sideEvidence.role { displayEvidence.append(.init("side", role.rawValue)) }
        return StableIdentityEvidence(concept: .lineup, importedIdentifier: lineupIdentity, displayEvidence: displayEvidence)
    }
}

enum LineupIdentityComparison: Hashable, Sendable {
    case sameIdentityMatchingEvidence
    case sameIdentityConflictingEvidence([String])
    case distinctIdentitiesMatchingEvidence
    case distinctIdentitiesDifferentEvidence
    case missingIdentity
    case invalidIdentity
    case unresolvedEquivalence
}

enum LineupEntryClassification: Hashable, Sendable {
    case validMember
    case missingParticipant
    case invalidParticipant
    case unresolvedParticipant
    case importedDetachedParticipant
    case playerAbsentFromCurrentRoster
    case historicalPlayerEvidence
    case wrongGameSide
    case unresolvedGameSide
    case missingSlot
    case invalidSlot
    case unsupportedSlot
    case nonHittingSentinel
    case conflictingSlot
    case conflictingPosition
    case sourceOrderEvidence
    case pitcherRoleEvidence
    case substitutionEvidence
}

enum LineupSetClassification: Hashable, Sendable {
    case oneLineup
    case multipleLineups
    case emptyLineup
    case completeLineup
    case incompleteLineup
    case missingGame
    case invalidGame
    case missingSide
    case unresolvedSide
    case conflictingSide
    case teamSideConflict
    case participantSideConflict
    case missingParticipant
    case invalidParticipant
    case duplicateLineup
    case duplicateParticipant(UUID)
    case duplicateParticipantUnresolved
    case repeatedParticipantExact
    case participantConflictingSlot(UUID)
    case participantConflictingSide(UUID)
    case participantConflictingPosition(UUID)
    case duplicateSlot(Int)
    case missingSlot
    case invalidSlot
    case unsupportedRawEvidence
    case ambiguousEvidence
    case contradictoryEvidence
    case unresolvedEvidence
    case importedEvidence
    case traditionalEvidence
    case everyoneHitsEvidence
    case unknownModeEvidence
    case rosterMemberOmitted(UUID)
    case participantAbsentFromCurrentRoster(UUID?)
    case historicalEvidence
}

enum CanonicalLineupMeaningClassifier {
    static func compareIdentity(_ lhs: CanonicalGameLineup, _ rhs: CanonicalGameLineup) -> LineupIdentityComparison {
        switch StableIdentityClassifier.compare(lhs.stableIdentityEvidence, rhs.stableIdentityEvidence) {
        case .sameIdentifierMatchingEvidence:
            if lhs.gameIdentity != rhs.gameIdentity { return .sameIdentityConflictingEvidence(["gameIdentity"]) }
            if lhs.sideEvidence.role != rhs.sideEvidence.role { return .sameIdentityConflictingEvidence(["side"]) }
            return .sameIdentityMatchingEvidence
        case let .sameIdentifierConflictingEvidence(fields):
            return .sameIdentityConflictingEvidence(fields)
        case .differentIdentifiersMatchingDisplay:
            return .distinctIdentitiesMatchingEvidence
        case .differentIdentifiersDifferentDisplay:
            return .distinctIdentitiesDifferentEvidence
        case .bothMissingIdentifier, .oneMissingIdentifier:
            return .missingIdentity
        case .invalidIdentifier:
            return .invalidIdentity
        case .unresolvedEquivalence:
            return .unresolvedEquivalence
        }
    }

    static func classifyEntry(_ entry: LineupEntryEvidence, lineupSide: TeamSideRole? = nil) -> Set<LineupEntryClassification> {
        var classifications: Set<LineupEntryClassification> = []

        switch entry.participant {
        case .gameParticipant, .reusablePlayer, .currentRosterMembership:
            classifications.insert(.validMember)
        case .missingPlayerIdentity:
            classifications.insert(.missingParticipant)
        case .invalidPlayerIdentity:
            classifications.insert(.invalidParticipant)
        case .unknown:
            classifications.insert(.unresolvedParticipant)
        case .historicalPlayer:
            classifications.insert(.historicalPlayerEvidence)
        case .absentFromCurrentRoster:
            classifications.insert(.playerAbsentFromCurrentRoster)
        case .wrongGameSide:
            classifications.insert(.wrongGameSide)
        case .unresolvedGameSide:
            classifications.insert(.unresolvedGameSide)
        case .importedDetached:
            classifications.insert(.importedDetachedParticipant)
        }

        switch entry.battingSlot {
        case .known:
            break
        case .missing:
            classifications.insert(.missingSlot)
        case .invalid:
            classifications.insert(.invalidSlot)
        case .unsupportedRawValue:
            classifications.insert(.unsupportedSlot)
        case .nonHittingSentinel:
            classifications.insert(.nonHittingSentinel)
        case .conflicting:
            classifications.insert(.conflictingSlot)
        }

        if case .conflicting = entry.rawPosition { classifications.insert(.conflictingPosition) }
        if entry.sourceOrder != nil { classifications.insert(.sourceOrderEvidence) }
        if entry.pitcherRole != .notRepresented { classifications.insert(.pitcherRoleEvidence) }
        if entry.substitutionEvidence != .initialLineup { classifications.insert(.substitutionEvidence) }

        if let lineupSide, let participantSide = entry.participant.sideRole, participantSide != lineupSide {
            classifications.insert(.wrongGameSide)
        }

        return classifications
    }

    static func classifyLineup(
        _ lineup: CanonicalGameLineup,
        currentRosterMemberships: [CurrentRosterMembership] = []
    ) -> Set<LineupSetClassification> {
        var classifications: Set<LineupSetClassification> = [.oneLineup]

        switch lineup.gameIdentity {
        case .missing:
            classifications.insert(.missingGame)
        case .invalid:
            classifications.insert(.invalidGame)
        case .valid:
            break
        }

        classifySide(lineup, into: &classifications)
        classifyMode(lineup.mode, source: lineup.source, into: &classifications)

        if lineup.entries.isEmpty {
            classifications.insert(.emptyLineup)
            classifications.insert(.incompleteLineup)
        }

        var participantSlots: [UUID: Set<Int>] = [:]
        var participantSides: [UUID: Set<TeamSideRole>] = [:]
        var participantPositions: [UUID: Set<RawLineupPositionEvidence>] = [:]
        var participantCounts: [UUID: Int] = [:]
        var seenEntries: Set<LineupEntryEvidence> = []
        var slotCounts: [Int: Int] = [:]
        var hasIncompleteEvidence = false

        for entry in lineup.entries {
            let entryClassifications = classifyEntry(entry, lineupSide: lineup.sideEvidence.role)
            if entryClassifications.contains(.missingParticipant) {
                classifications.insert(.missingParticipant)
                hasIncompleteEvidence = true
            }
            if entryClassifications.contains(.invalidParticipant) {
                classifications.insert(.invalidParticipant)
                hasIncompleteEvidence = true
            }
            if entryClassifications.contains(.unresolvedParticipant) || entryClassifications.contains(.unresolvedGameSide) {
                classifications.insert(.unresolvedEvidence)
                hasIncompleteEvidence = true
            }
            if entryClassifications.contains(.wrongGameSide) {
                classifications.insert(.participantSideConflict)
                classifications.insert(.contradictoryEvidence)
            }
            if entryClassifications.contains(.missingSlot) {
                classifications.insert(.missingSlot)
                hasIncompleteEvidence = true
            }
            if entryClassifications.contains(.invalidSlot) {
                classifications.insert(.invalidSlot)
                classifications.insert(.contradictoryEvidence)
            }
            if entryClassifications.contains(.unsupportedSlot) || entryClassifications.contains(.nonHittingSentinel) {
                classifications.insert(.unsupportedRawEvidence)
            }
            if entryClassifications.contains(.conflictingSlot) || entryClassifications.contains(.conflictingPosition) {
                classifications.insert(.contradictoryEvidence)
            }
            if entryClassifications.contains(.playerAbsentFromCurrentRoster) {
                classifications.insert(.participantAbsentFromCurrentRoster(entry.participant.playerIdentity.validIdentifier))
            }
            if entryClassifications.contains(.historicalPlayerEvidence) {
                classifications.insert(.historicalEvidence)
            }

            if seenEntries.contains(entry) { classifications.insert(.repeatedParticipantExact) }
            seenEntries.insert(entry)

            if let slot = entry.battingSlot.slotValue { slotCounts[slot, default: 0] += 1 }
            if case let .valid(playerID) = entry.participant.playerIdentity {
                participantCounts[playerID, default: 0] += 1
                if let slot = entry.battingSlot.slotValue { participantSlots[playerID, default: []].insert(slot) }
                if let side = entry.participant.sideRole { participantSides[playerID, default: []].insert(side) }
                participantPositions[playerID, default: []].insert(entry.rawPosition)
            }
        }

        for (slot, count) in slotCounts where count > 1 {
            classifications.insert(.duplicateSlot(slot))
        }

        for (playerID, count) in participantCounts where count > 1 {
            classifications.insert(.duplicateParticipant(playerID))
            if participantSlots[playerID, default: []].count > 1 {
                classifications.insert(.participantConflictingSlot(playerID))
                classifications.insert(.contradictoryEvidence)
            }
            if participantSides[playerID, default: []].count > 1 {
                classifications.insert(.participantConflictingSide(playerID))
                classifications.insert(.contradictoryEvidence)
            }
            if participantPositions[playerID, default: []].count > 1 {
                classifications.insert(.participantConflictingPosition(playerID))
            }
        }

        if lineup.entries.contains(where: { $0.participant.playerIdentity.validIdentifier == nil }) {
            classifications.insert(.duplicateParticipantUnresolved)
        }

        classifyRosterBoundary(lineup, currentRosterMemberships: currentRosterMemberships, into: &classifications)

        if classifications.contains(.duplicateSlot(0)) || classifications.contains(.invalidGame) {
            classifications.insert(.contradictoryEvidence)
        }

        if hasIncompleteEvidence {
            classifications.insert(.incompleteLineup)
        }

        if isComplete(lineup, classifications: classifications) {
            classifications.insert(.completeLineup)
        } else if classifications.contains(.emptyLineup) == false {
            classifications.insert(.incompleteLineup)
        }

        return classifications
    }

    static func classifyLineupSet(_ lineups: [CanonicalGameLineup]) -> Set<LineupSetClassification> {
        guard lineups.isEmpty == false else { return [.emptyLineup, .incompleteLineup] }

        var classifications: Set<LineupSetClassification> = lineups.count == 1 ? [.oneLineup] : [.multipleLineups]
        var seenLineups: [CanonicalGameLineup] = []

        for lineup in lineups {
            classifications.formUnion(classifyLineup(lineup))
            for existing in seenLineups {
                if existing == lineup || compareIdentity(existing, lineup) == .sameIdentityMatchingEvidence {
                    classifications.insert(.duplicateLineup)
                }
                if existing.lineupIdentity.validIdentifier == lineup.lineupIdentity.validIdentifier,
                   existing.sideEvidence.role != lineup.sideEvidence.role {
                    classifications.insert(.conflictingSide)
                    classifications.insert(.contradictoryEvidence)
                }
            }
            seenLineups.append(lineup)
        }

        return classifications
    }

    private static func classifySide(_ lineup: CanonicalGameLineup, into classifications: inout Set<LineupSetClassification>) {
        switch lineup.sideEvidence {
        case .home, .visiting, .gameSide:
            break
        case .missing:
            classifications.insert(.missingSide)
            classifications.insert(.incompleteLineup)
        case .unresolved, .inferredFromArrayPosition:
            classifications.insert(.unresolvedSide)
        case .conflicting:
            classifications.insert(.conflictingSide)
            classifications.insert(.contradictoryEvidence)
        }

        if case .conflicting = lineup.teamEvidence {
            classifications.insert(.teamSideConflict)
            classifications.insert(.contradictoryEvidence)
        }

        if let sideTeamIdentity = lineup.sideEvidence.teamIdentity,
           case let .valid(sideTeamID) = sideTeamIdentity,
           case let .valid(lineupTeamID) = lineup.teamEvidence.identity,
           sideTeamID != lineupTeamID {
            classifications.insert(.teamSideConflict)
            classifications.insert(.contradictoryEvidence)
        }
    }

    private static func classifyMode(
        _ mode: LineupModeEvidence,
        source: LineupEvidenceSource,
        into classifications: inout Set<LineupSetClassification>
    ) {
        switch mode {
        case .traditional:
            classifications.insert(.traditionalEvidence)
        case .everyoneHits:
            classifications.insert(.everyoneHitsEvidence)
        case .unknown, .missing:
            classifications.insert(.unknownModeEvidence)
        case .unsupported:
            classifications.insert(.unsupportedRawEvidence)
        case .ambiguous:
            classifications.insert(.ambiguousEvidence)
        }

        switch source {
        case .importedGame, .compatibilityTransport, .seededGame:
            classifications.insert(.importedEvidence)
        default:
            break
        }
    }

    private static func classifyRosterBoundary(
        _ lineup: CanonicalGameLineup,
        currentRosterMemberships: [CurrentRosterMembership],
        into classifications: inout Set<LineupSetClassification>
    ) {
        guard currentRosterMemberships.isEmpty == false else { return }

        let lineupPlayerIDs = Set(lineup.entries.compactMap { $0.participant.playerIdentity.validIdentifier })
        let rosterPlayerIDs = Set(currentRosterMemberships.compactMap { $0.playerEvidence.identity.validIdentifier })

        for playerID in rosterPlayerIDs where lineupPlayerIDs.contains(playerID) == false {
            classifications.insert(.rosterMemberOmitted(playerID))
        }

        for playerID in lineupPlayerIDs where rosterPlayerIDs.contains(playerID) == false {
            classifications.insert(.participantAbsentFromCurrentRoster(playerID))
        }
    }

    private static func isComplete(_ lineup: CanonicalGameLineup, classifications: Set<LineupSetClassification>) -> Bool {
        guard lineup.entries.isEmpty == false else { return false }
        let blocking: Set<LineupSetClassification> = [
            .missingGame,
            .invalidGame,
            .missingSide,
            .conflictingSide,
            .teamSideConflict,
            .participantSideConflict,
            .missingParticipant,
            .invalidParticipant,
            .missingSlot,
            .invalidSlot,
            .contradictoryEvidence,
            .ambiguousEvidence
        ]
        return classifications.isDisjoint(with: blocking)
    }
}

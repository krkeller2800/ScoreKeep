import Foundation

/// Completeness of read-only legacy interpretation. This is verification evidence only.
enum LegacyCanonicalMappingCompleteness: String, Hashable, Sendable {
    case fullyInterpreted
    case interpretedWithWarnings
    case partiallyInterpreted
    case unsupportedEvidencePreserved
    case repairRequired
    case rejected
    case contradictory
    case relationshipUnresolved

    init(validation: CanonicalValidationResult) {
        if validation.disposition == .valid {
            self = .fullyInterpreted
        } else if validation.disposition == .validWithWarnings {
            self = .interpretedWithWarnings
        } else if validation.disposition == .unsupported || validation.containsUnsupportedEvidence {
            self = .unsupportedEvidencePreserved
        } else if validation.disposition == .repairRequired || validation.disposition == .repairRecommended {
            self = .repairRequired
        } else if validation.disposition == .rejected {
            self = .rejected
        } else if validation.disposition == .contradictory {
            self = .contradictory
        } else if validation.disposition == .unresolved {
            self = .relationshipUnresolved
        } else {
            self = .partiallyInterpreted
        }
    }
}

enum LegacyRelationshipResolutionStatus: String, Hashable, Sendable {
    case resolved
    case missing
    case unresolved
    case conflicting
    case unsupported
}

struct LegacyCanonicalMappingResult<Value: Hashable & Sendable>: Hashable, Sendable {
    let canonicalValue: Value?
    let validation: CanonicalValidationResult
    let preservedRawEvidence: [String: String]
    let unsupportedRawEvidence: [String]
    let sourceIdentity: ImportedIdentifierEvidence
    let sourceLocation: String?
    let completeness: LegacyCanonicalMappingCompleteness
    let relationshipResolution: LegacyRelationshipResolutionStatus

    init(
        canonicalValue: Value?,
        validation: CanonicalValidationResult,
        preservedRawEvidence: [String: String] = [:],
        unsupportedRawEvidence: [String] = [],
        sourceIdentity: ImportedIdentifierEvidence = .missing,
        sourceLocation: String? = nil,
        relationshipResolution: LegacyRelationshipResolutionStatus = .resolved
    ) {
        self.canonicalValue = canonicalValue
        self.validation = validation
        self.preservedRawEvidence = preservedRawEvidence
        self.unsupportedRawEvidence = unsupportedRawEvidence.sorted()
        self.sourceIdentity = sourceIdentity
        self.sourceLocation = sourceLocation
        self.completeness = LegacyCanonicalMappingCompleteness(validation: validation)
        self.relationshipResolution = relationshipResolution
    }

    var comparisonMayContinue: Bool { validation.processingMayContinueReadOnly }
    var futureWriteOrImportMustStop: Bool { validation.futureWriteMustStop }
    var explicitRepairRequired: Bool { validation.explicitRepairRequired }
}

struct LegacyTeamEvidenceSnapshot: Hashable, Sendable {
    let identity: ImportedIdentifierEvidence
    let name: String
    let coach: String
    let details: String
    let logoByteCount: Int?
    let playerCount: Int?
    let sourceLocation: String?

    init(
        identity: ImportedIdentifierEvidence,
        name: String = "",
        coach: String = "",
        details: String = "",
        logoByteCount: Int? = nil,
        playerCount: Int? = nil,
        sourceLocation: String? = nil
    ) {
        self.identity = identity
        self.name = name
        self.coach = coach
        self.details = details
        self.logoByteCount = logoByteCount
        self.playerCount = playerCount
        self.sourceLocation = sourceLocation
    }

    init(team: Team, sourceLocation: String? = nil) {
        self.init(
            identity: .valid(team.ident),
            name: team.name,
            coach: team.coach,
            details: team.details,
            logoByteCount: team.logo?.count,
            playerCount: team.players.count,
            sourceLocation: sourceLocation
        )
    }

    init(team: ShareTeam, sourceLocation: String? = nil) {
        self.init(
            identity: .valid(team.id),
            name: team.name,
            coach: team.coach,
            details: team.details,
            logoByteCount: team.logo.isEmpty ? nil : team.logo.count,
            playerCount: team.players.count,
            sourceLocation: sourceLocation
        )
    }
}

struct LegacyPlayerEvidenceSnapshot: Hashable, Sendable {
    let identity: ImportedIdentifierEvidence
    let name: String
    let number: String
    let position: String
    let battingDirection: String
    let battingOrder: Int
    let teamIdentity: ImportedIdentifierEvidence?
    let photoByteCount: Int?
    let sourceIndex: Int?
    let sourceLocation: String?

    init(
        identity: ImportedIdentifierEvidence,
        name: String = "",
        number: String = "",
        position: String = "",
        battingDirection: String = "",
        battingOrder: Int = 0,
        teamIdentity: ImportedIdentifierEvidence? = nil,
        photoByteCount: Int? = nil,
        sourceIndex: Int? = nil,
        sourceLocation: String? = nil
    ) {
        self.identity = identity
        self.name = name
        self.number = number
        self.position = position
        self.battingDirection = battingDirection
        self.battingOrder = battingOrder
        self.teamIdentity = teamIdentity
        self.photoByteCount = photoByteCount
        self.sourceIndex = sourceIndex
        self.sourceLocation = sourceLocation
    }

    init(player: Player, sourceIndex: Int? = nil, sourceLocation: String? = nil) {
        self.init(
            identity: .valid(player.identifier),
            name: player.name,
            number: player.number,
            position: player.position,
            battingDirection: player.batDir,
            battingOrder: player.batOrder,
            teamIdentity: player.team.map { .valid($0.ident) },
            photoByteCount: player.photo?.count,
            sourceIndex: sourceIndex,
            sourceLocation: sourceLocation
        )
    }

    init(player: SharePlayer, sourceIndex: Int? = nil, sourceLocation: String? = nil) {
        self.init(
            identity: .valid(player.id),
            name: player.name,
            number: player.number,
            position: player.position,
            battingDirection: player.batDir,
            battingOrder: player.batOrder,
            teamIdentity: player.team.map { .valid($0.id) },
            photoByteCount: player.photo.isEmpty ? nil : player.photo.count,
            sourceIndex: sourceIndex,
            sourceLocation: sourceLocation
        )
    }
}

struct LegacyGameEvidenceSnapshot: Hashable, Sendable {
    let identity: ImportedIdentifierEvidence
    let date: String
    let location: String
    let highlights: String
    let homeScore: Int
    let visitingScore: Int
    let everyoneHits: Bool
    let expectedInnings: Int
    let homeTeam: LegacyTeamEvidenceSnapshot?
    let visitingTeam: LegacyTeamEvidenceSnapshot?
    let sourceLocation: String?

    init(
        identity: ImportedIdentifierEvidence,
        date: String = "",
        location: String = "",
        highlights: String = "",
        homeScore: Int = 0,
        visitingScore: Int = 0,
        everyoneHits: Bool = false,
        expectedInnings: Int = 0,
        homeTeam: LegacyTeamEvidenceSnapshot? = nil,
        visitingTeam: LegacyTeamEvidenceSnapshot? = nil,
        sourceLocation: String? = nil
    ) {
        self.identity = identity
        self.date = date
        self.location = location
        self.highlights = highlights
        self.homeScore = homeScore
        self.visitingScore = visitingScore
        self.everyoneHits = everyoneHits
        self.expectedInnings = expectedInnings
        self.homeTeam = homeTeam
        self.visitingTeam = visitingTeam
        self.sourceLocation = sourceLocation
    }

    init(game: Game, sourceLocation: String? = nil) {
        self.init(
            identity: .valid(game.ident),
            date: game.date,
            location: game.location,
            highlights: game.highLights,
            homeScore: game.hscore,
            visitingScore: game.vscore,
            everyoneHits: game.everyOneHits,
            expectedInnings: game.numInnings,
            homeTeam: game.hteam.map { LegacyTeamEvidenceSnapshot(team: $0, sourceLocation: sourceLocation.map { "\($0).hteam" }) },
            visitingTeam: game.vteam.map { LegacyTeamEvidenceSnapshot(team: $0, sourceLocation: sourceLocation.map { "\($0).vteam" }) },
            sourceLocation: sourceLocation
        )
    }

    init(game: ShareGame, sourceLocation: String? = nil) {
        self.init(
            identity: .valid(game.id),
            date: game.date,
            location: game.location,
            highlights: game.highLights,
            homeScore: game.hscore,
            visitingScore: game.vscore,
            everyoneHits: game.everyOneHits,
            expectedInnings: game.numInnings,
            homeTeam: LegacyTeamEvidenceSnapshot(team: game.hteam, sourceLocation: sourceLocation.map { "\($0).hteam" }),
            visitingTeam: LegacyTeamEvidenceSnapshot(team: game.vteam, sourceLocation: sourceLocation.map { "\($0).vteam" }),
            sourceLocation: sourceLocation
        )
    }
}

struct LegacyLineupEvidenceSnapshot: Hashable, Sendable {
    let identity: ImportedIdentifierEvidence
    let gameIdentity: ImportedIdentifierEvidence
    let teamIdentity: ImportedIdentifierEvidence
    let everyoneHits: Bool
    let inning: Int
    let players: [LegacyPlayerEvidenceSnapshot]
    let sourceIndex: Int?
    let sourceLocation: String?

    init(
        identity: ImportedIdentifierEvidence,
        gameIdentity: ImportedIdentifierEvidence,
        teamIdentity: ImportedIdentifierEvidence,
        everyoneHits: Bool,
        inning: Int,
        players: [LegacyPlayerEvidenceSnapshot],
        sourceIndex: Int? = nil,
        sourceLocation: String? = nil
    ) {
        self.identity = identity
        self.gameIdentity = gameIdentity
        self.teamIdentity = teamIdentity
        self.everyoneHits = everyoneHits
        self.inning = inning
        self.players = players
        self.sourceIndex = sourceIndex
        self.sourceLocation = sourceLocation
    }

    init(lineup: Lineup, sourceIndex: Int? = nil, sourceLocation: String? = nil) {
        self.init(
            identity: .valid(lineup.ident),
            gameIdentity: .valid(lineup.game.ident),
            teamIdentity: .valid(lineup.team.ident),
            everyoneHits: lineup.everyoneHits,
            inning: lineup.inning,
            players: lineup.players.enumerated().map { LegacyPlayerEvidenceSnapshot(player: $0.element, sourceIndex: $0.offset, sourceLocation: sourceLocation) },
            sourceIndex: sourceIndex,
            sourceLocation: sourceLocation
        )
    }

    init(lineup: ShareLineup, fallbackGameIdentity: ImportedIdentifierEvidence, sourceIndex: Int? = nil, sourceLocation: String? = nil) {
        self.init(
            identity: .valid(lineup.id),
            gameIdentity: lineup.game.map { .valid($0.id) } ?? fallbackGameIdentity,
            teamIdentity: .valid(lineup.team.id),
            everyoneHits: lineup.everyoneHits,
            inning: lineup.inning,
            players: lineup.players.enumerated().map { LegacyPlayerEvidenceSnapshot(player: $0.element, sourceIndex: $0.offset, sourceLocation: sourceLocation) },
            sourceIndex: sourceIndex,
            sourceLocation: sourceLocation
        )
    }
}

struct LegacyAtbatEvidenceSnapshot: Hashable, Sendable {
    let identity: ImportedIdentifierEvidence
    let gameIdentity: ImportedIdentifierEvidence
    let teamIdentity: ImportedIdentifierEvidence
    let player: LegacyPlayerEvidenceSnapshot?
    let result: String
    let maxbase: String
    let battingOrder: Int
    let outAt: String
    let inning: Double
    let sequence: Int
    let scorecardColumn: Int
    let rbis: Int
    let outs: Int
    let sacrificeFly: Int
    let sacrificeBunt: Int
    let stolenBases: Int
    let earnedRun: Bool
    let playRecord: String
    let endOfInning: Bool
    let sourceIndex: Int?
    let sourceLocation: String?

    init(
        identity: ImportedIdentifierEvidence,
        gameIdentity: ImportedIdentifierEvidence,
        teamIdentity: ImportedIdentifierEvidence,
        player: LegacyPlayerEvidenceSnapshot?,
        result: String,
        maxbase: String,
        battingOrder: Int,
        outAt: String,
        inning: Double,
        sequence: Int,
        scorecardColumn: Int,
        rbis: Int,
        outs: Int,
        sacrificeFly: Int,
        sacrificeBunt: Int,
        stolenBases: Int,
        earnedRun: Bool,
        playRecord: String,
        endOfInning: Bool,
        sourceIndex: Int? = nil,
        sourceLocation: String? = nil
    ) {
        self.identity = identity
        self.gameIdentity = gameIdentity
        self.teamIdentity = teamIdentity
        self.player = player
        self.result = result
        self.maxbase = maxbase
        self.battingOrder = battingOrder
        self.outAt = outAt
        self.inning = inning
        self.sequence = sequence
        self.scorecardColumn = scorecardColumn
        self.rbis = rbis
        self.outs = outs
        self.sacrificeFly = sacrificeFly
        self.sacrificeBunt = sacrificeBunt
        self.stolenBases = stolenBases
        self.earnedRun = earnedRun
        self.playRecord = playRecord
        self.endOfInning = endOfInning
        self.sourceIndex = sourceIndex
        self.sourceLocation = sourceLocation
    }

    init(atbat: Atbat, sourceIndex: Int? = nil, sourceLocation: String? = nil) {
        self.init(
            identity: .valid(atbat.ident),
            gameIdentity: .valid(atbat.game.ident),
            teamIdentity: .valid(atbat.team.ident),
            player: LegacyPlayerEvidenceSnapshot(player: atbat.player, sourceIndex: sourceIndex, sourceLocation: sourceLocation),
            result: atbat.result,
            maxbase: atbat.maxbase,
            battingOrder: atbat.batOrder,
            outAt: atbat.outAt,
            inning: Double(atbat.inning),
            sequence: atbat.seq,
            scorecardColumn: atbat.col,
            rbis: atbat.rbis,
            outs: atbat.outs,
            sacrificeFly: atbat.sacFly,
            sacrificeBunt: atbat.sacBunt,
            stolenBases: atbat.stolenBases,
            earnedRun: atbat.earnedRun,
            playRecord: atbat.playRec,
            endOfInning: atbat.endOfInning,
            sourceIndex: sourceIndex,
            sourceLocation: sourceLocation
        )
    }

    init(atbat: ShareAtbat, fallbackGameIdentity: ImportedIdentifierEvidence, sourceIndex: Int? = nil, sourceLocation: String? = nil) {
        self.init(
            identity: .valid(atbat.id),
            gameIdentity: atbat.game.map { .valid($0.id) } ?? fallbackGameIdentity,
            teamIdentity: .valid(atbat.team.id),
            player: LegacyPlayerEvidenceSnapshot(player: atbat.player, sourceIndex: sourceIndex, sourceLocation: sourceLocation),
            result: atbat.result,
            maxbase: atbat.maxbase,
            battingOrder: atbat.batOrder,
            outAt: atbat.outAt,
            inning: Double(atbat.inning),
            sequence: atbat.seq,
            scorecardColumn: atbat.col,
            rbis: atbat.rbis,
            outs: atbat.outs,
            sacrificeFly: atbat.sacFly,
            sacrificeBunt: atbat.sacBunt,
            stolenBases: atbat.stolenBases,
            earnedRun: atbat.earnedRun,
            playRecord: atbat.playRec,
            endOfInning: atbat.endOfInning,
            sourceIndex: sourceIndex,
            sourceLocation: sourceLocation
        )
    }
}

struct LegacyPitcherEvidenceSnapshot: Hashable, Sendable {
    let identity: ImportedIdentifierEvidence
    let player: LegacyPlayerEvidenceSnapshot
    let teamIdentity: ImportedIdentifierEvidence
    let gameIdentity: ImportedIdentifierEvidence
    let startInning: Int
    let startOuts: Int
    let startBatters: Int
    let endInning: Int
    let endOuts: Int
    let endBatters: Int
    let sourceIndex: Int?
    let sourceLocation: String?

    init(pitcher: Pitcher, sourceIndex: Int? = nil, sourceLocation: String? = nil) {
        self.identity = .valid(pitcher.ident)
        self.player = LegacyPlayerEvidenceSnapshot(player: pitcher.player, sourceIndex: sourceIndex, sourceLocation: sourceLocation)
        self.teamIdentity = .valid(pitcher.team.ident)
        self.gameIdentity = .valid(pitcher.game.ident)
        self.startInning = pitcher.startInn
        self.startOuts = pitcher.sOuts
        self.startBatters = pitcher.sBats
        self.endInning = pitcher.endInn
        self.endOuts = pitcher.eOuts
        self.endBatters = pitcher.eBats
        self.sourceIndex = sourceIndex
        self.sourceLocation = sourceLocation
    }

    init(pitcher: SharePitcher, fallbackGameIdentity: ImportedIdentifierEvidence, sourceIndex: Int? = nil, sourceLocation: String? = nil) {
        self.identity = .valid(pitcher.id)
        self.player = LegacyPlayerEvidenceSnapshot(player: pitcher.player, sourceIndex: sourceIndex, sourceLocation: sourceLocation)
        self.teamIdentity = .valid(pitcher.team.id)
        self.gameIdentity = pitcher.game.map { .valid($0.id) } ?? fallbackGameIdentity
        self.startInning = pitcher.startInn
        self.startOuts = pitcher.sOuts
        self.startBatters = pitcher.sBats
        self.endInning = pitcher.endInn
        self.endOuts = pitcher.eOuts
        self.endBatters = pitcher.eBats
        self.sourceIndex = sourceIndex
        self.sourceLocation = sourceLocation
    }
}

struct LegacyCanonicalRosterMapping: Hashable, Sendable {
    let players: [LegacyCanonicalMappingResult<ReusableCanonicalPlayer>]
    let memberships: [LegacyCanonicalMappingResult<CurrentRosterMembership>]
    let validation: CanonicalValidationResult

    var comparisonMayContinue: Bool { validation.processingMayContinueReadOnly }
}

struct LegacyCanonicalGameMapping: Hashable, Sendable {
    let game: LegacyCanonicalMappingResult<CanonicalGameIdentity>
    let homeSide: GameSideTeamParticipation?
    let visitingSide: GameSideTeamParticipation?
    let players: [LegacyCanonicalMappingResult<ReusableCanonicalPlayer>]
    let memberships: [LegacyCanonicalMappingResult<CurrentRosterMembership>]
    let lineups: [LegacyCanonicalMappingResult<CanonicalGameLineup>]
    let scoringEvents: [LegacyCanonicalMappingResult<CanonicalScoringEventEvidence>]
    let pitcherAppearances: [LegacyCanonicalMappingResult<CanonicalPitcherAppearanceEvidence>]
    let substitutions: [LegacyCanonicalMappingResult<CanonicalSubstitutionEvidence>]
    let validation: CanonicalValidationResult

    var comparisonMayContinue: Bool { validation.processingMayContinueReadOnly }
}

enum LegacyCanonicalVerificationMapper {
    static func mapTeam(_ snapshot: LegacyTeamEvidenceSnapshot, source: TeamEvidenceSource = .compatibilityTransport) -> LegacyCanonicalMappingResult<ReusableCanonicalTeam> {
        let team = ReusableCanonicalTeam(
            identity: snapshot.identity,
            display: TeamDisplayEvidence(
                name: .present(snapshot.name),
                coach: .present(snapshot.coach),
                details: .present(snapshot.details),
                logo: snapshot.logoByteCount == nil ? .missing : .present(Data(repeating: 0, count: snapshot.logoByteCount ?? 0))
            ),
            rosterEvidence: snapshot.playerCount.map { .importedRosterReference(count: $0) } ?? .notRepresented,
            source: source
        )
        return LegacyCanonicalMappingResult(
            canonicalValue: team,
            validation: CanonicalDomainValidator.validateTeam(team, sourceLocation: snapshot.sourceLocation),
            preservedRawEvidence: ["name": snapshot.name, "coach": snapshot.coach, "details": snapshot.details],
            sourceIdentity: snapshot.identity,
            sourceLocation: snapshot.sourceLocation
        )
    }

    static func mapPlayer(_ snapshot: LegacyPlayerEvidenceSnapshot, source: PlayerEvidenceSource = .compatibilityTransport) -> LegacyCanonicalMappingResult<ReusableCanonicalPlayer> {
        let player = reusablePlayer(from: snapshot, source: source)
        let validation = CanonicalDomainValidator.validatePlayer(player, sourceLocation: snapshot.sourceLocation)
        return LegacyCanonicalMappingResult(
            canonicalValue: player,
            validation: validation,
            preservedRawEvidence: playerRawEvidence(snapshot),
            sourceIdentity: snapshot.identity,
            sourceLocation: snapshot.sourceLocation,
            relationshipResolution: snapshot.teamIdentity == nil ? .missing : .resolved
        )
    }

    static func mapRosterMembership(_ snapshot: LegacyPlayerEvidenceSnapshot, source: RosterMembershipEvidenceSource = .compatibilityTransport) -> LegacyCanonicalMappingResult<CurrentRosterMembership> {
        let player = reusablePlayer(from: snapshot, source: .compatibilityTransport)
        let teamEvidence: RosterMembershipTeamEvidence
        let relationship: LegacyRelationshipResolutionStatus
        switch snapshot.teamIdentity {
        case let .some(.valid(teamID)):
            let team = ReusableCanonicalTeam(identity: .valid(teamID), source: .compatibilityTransport)
            teamEvidence = .reusableTeam(team)
            relationship = .resolved
        case let .some(.invalid(raw)):
            teamEvidence = .invalidIdentity(.invalid(raw), TeamDisplayEvidence())
            relationship = .conflicting
        case .some(.missing):
            teamEvidence = .missing
            relationship = .missing
        case .none:
            teamEvidence = .missing
            relationship = .missing
        }

        let membership = CurrentRosterMembership(
            teamEvidence: teamEvidence,
            playerEvidence: .reusablePlayer(player),
            displayEvidence: RosterMembershipDisplayEvidence(
                jerseyNumber: .present(snapshot.number),
                position: .present(snapshot.position),
                rosterOrder: snapshot.sourceIndex.map { OrderEvidence(kind: .sourceFile, value: $0, sourceIndex: $0) },
                battingOrder: OrderEvidence(kind: .battingOrder, value: snapshot.battingOrder, sourceIndex: snapshot.sourceIndex),
                media: snapshot.photoByteCount == nil ? .missing : .present(Data(repeating: 0, count: snapshot.photoByteCount ?? 0))
            ),
            source: source
        )
        return LegacyCanonicalMappingResult(
            canonicalValue: membership,
            validation: CanonicalDomainValidator.validateRosterMembership(membership, sourceLocation: snapshot.sourceLocation),
            preservedRawEvidence: playerRawEvidence(snapshot),
            sourceIdentity: snapshot.identity,
            sourceLocation: snapshot.sourceLocation,
            relationshipResolution: relationship
        )
    }

    static func mapRoster(_ players: [SharePlayer], sourceLocation: String? = nil) -> LegacyCanonicalRosterMapping {
        let snapshots = players.enumerated().map { LegacyPlayerEvidenceSnapshot(player: $0.element, sourceIndex: $0.offset, sourceLocation: sourceLocation) }
        let playerResults = snapshots.map { mapPlayer($0, source: .importedRoster) }
        let membershipResults = snapshots.map { mapRosterMembership($0, source: .importedRoster) }
        let memberships = membershipResults.compactMap(\.canonicalValue)
        let validation = CanonicalValidationResult.combined(
            playerResults.map(\.validation) +
                membershipResults.map(\.validation) +
                [CanonicalDomainValidator.validateRoster(memberships, sourceLocation: sourceLocation)]
        )
        return LegacyCanonicalRosterMapping(players: playerResults, memberships: membershipResults, validation: validation)
    }

    static func mapGame(_ game: ShareGame, sourceLocation: String? = nil) -> LegacyCanonicalGameMapping {
        let gameSnapshot = LegacyGameEvidenceSnapshot(game: game, sourceLocation: sourceLocation)
        let gameResult = mapGameIdentity(gameSnapshot, source: .importedGame)
        let homeSide = gameSnapshot.homeTeam.map { side(from: $0, gameIdentity: gameSnapshot.identity, role: .home) }
        let visitingSide = gameSnapshot.visitingTeam.map { side(from: $0, gameIdentity: gameSnapshot.identity, role: .visiting) }
        let playerSnapshots = game.players.enumerated().map { LegacyPlayerEvidenceSnapshot(player: $0.element, sourceIndex: $0.offset, sourceLocation: sourceLocation) }
        let playerResults = playerSnapshots.map { mapPlayer($0, source: .importedGame) }
        let membershipResults = playerSnapshots.map { mapRosterMembership($0, source: .importedGame) }
        let rosterMemberships = membershipResults.compactMap(\.canonicalValue)
        let lineupResults = game.lineups.enumerated().map { index, lineup in
            mapLineup(LegacyLineupEvidenceSnapshot(lineup: lineup, fallbackGameIdentity: gameSnapshot.identity, sourceIndex: index, sourceLocation: sourceLocation), homeSide: homeSide, visitingSide: visitingSide, source: .importedGame)
        }
        let eventResults = game.atbats.enumerated().map { index, atbat in
            mapScoringEvent(LegacyAtbatEvidenceSnapshot(atbat: atbat, fallbackGameIdentity: gameSnapshot.identity, sourceIndex: index, sourceLocation: sourceLocation), source: .importedGame)
        }
        let orderedPitchers: [SharePitcher] = game.pitchers.sorted(by: CanonicalPitcherOrdering.canonicalOrder)
        let pitcherResults = orderedPitchers.enumerated().map { index, pitcher in
            mapPitcherAppearance(LegacyPitcherEvidenceSnapshot(pitcher: pitcher, fallbackGameIdentity: gameSnapshot.identity, sourceIndex: index, sourceLocation: sourceLocation), homeSide: homeSide, visitingSide: visitingSide, source: .importedGame)
        }
        let substitutionResults = mapSubstitutions(
            incoming: game.incomings.enumerated().map { LegacyPlayerEvidenceSnapshot(player: $0.element, sourceIndex: $0.offset, sourceLocation: sourceLocation) },
            outgoing: game.replaced.enumerated().map { LegacyPlayerEvidenceSnapshot(player: $0.element, sourceIndex: $0.offset, sourceLocation: sourceLocation) },
            gameIdentity: gameSnapshot.identity,
            sourceLocation: sourceLocation
        )
        let validation = CanonicalValidationResult.combined(
            [gameResult.validation, CanonicalDomainValidator.validateGameSides(home: homeSide, visiting: visitingSide, sourceLocation: sourceLocation)] +
                playerResults.map(\.validation) +
                membershipResults.map(\.validation) +
                [CanonicalDomainValidator.validateRoster(rosterMemberships, sourceLocation: sourceLocation)] +
                lineupResults.map(\.validation) +
                eventResults.map(\.validation) +
                pitcherResults.map(\.validation) +
                substitutionResults.map(\.validation)
        )
        return LegacyCanonicalGameMapping(
            game: gameResult,
            homeSide: homeSide,
            visitingSide: visitingSide,
            players: playerResults,
            memberships: membershipResults,
            lineups: lineupResults,
            scoringEvents: eventResults,
            pitcherAppearances: pitcherResults,
            substitutions: substitutionResults,
            validation: validation
        )
    }

    static func mapGameIdentity(_ snapshot: LegacyGameEvidenceSnapshot, source: GameEvidenceSource = .compatibilityTransport) -> LegacyCanonicalMappingResult<CanonicalGameIdentity> {
        let mode: LineupModeEvidence = snapshot.everyoneHits ? .everyoneHits : .traditional
        let expected: ExpectedInningCountEvidence = snapshot.expectedInnings <= 0 ? .invalid(snapshot.expectedInnings) : .known(snapshot.expectedInnings)
        let configuration: GameConfigurationEvidence = .configured(expectedInnings: expected, lineupMode: mode)
        let lifecycle: GameLifecycleEvidence = snapshot.homeScore > 0 || snapshot.visitingScore > 0 ? .inProgress : .unknown
        let game = CanonicalGameIdentity(
            identity: snapshot.identity,
            displayEvidence: GameDisplayEvidence(
                date: snapshot.date,
                location: snapshot.location,
                homeTeamName: snapshot.homeTeam?.name,
                visitingTeamName: snapshot.visitingTeam?.name,
                storedHomeScore: snapshot.homeScore,
                storedVisitingScore: snapshot.visitingScore
            ),
            configuration: configuration,
            origin: source == .seededGame ? .seeded : .imported,
            lifecycle: lifecycle,
            source: source
        )
        return LegacyCanonicalMappingResult(
            canonicalValue: game,
            validation: CanonicalDomainValidator.validateGame(game, sourceLocation: snapshot.sourceLocation),
            preservedRawEvidence: ["date": snapshot.date, "location": snapshot.location, "highlights": snapshot.highlights, "storedHomeScore": String(snapshot.homeScore), "storedVisitingScore": String(snapshot.visitingScore)],
            sourceIdentity: snapshot.identity,
            sourceLocation: snapshot.sourceLocation
        )
    }

    static func mapLineup(
        _ snapshot: LegacyLineupEvidenceSnapshot,
        homeSide: GameSideTeamParticipation?,
        visitingSide: GameSideTeamParticipation?,
        source: LineupEvidenceSource = .compatibilityTransport
    ) -> LegacyCanonicalMappingResult<CanonicalGameLineup> {
        let sideEvidence = lineupSide(teamIdentity: snapshot.teamIdentity, homeSide: homeSide, visitingSide: visitingSide)
        let lineup = CanonicalGameLineup(
            lineupIdentity: snapshot.identity,
            gameIdentity: snapshot.gameIdentity,
            sideEvidence: sideEvidence,
            teamEvidence: lineupTeam(teamIdentity: snapshot.teamIdentity, homeSide: homeSide, visitingSide: visitingSide),
            mode: snapshot.everyoneHits ? .everyoneHits : .traditional,
            entries: snapshot.players.enumerated().map { index, player in
                LineupEntryEvidence(
                    participant: .reusablePlayer(reusablePlayer(from: player, source: .compatibilityTransport)),
                    battingSlot: player.battingOrder > 0 ? .known(player.battingOrder) : .missing,
                    sourceOrder: OrderEvidence(kind: .sourceFile, value: index, sourceIndex: index),
                    rawPosition: player.position.isEmpty ? .blank : .present(player.position),
                    historicalDisplay: playerDisplay(from: player),
                    source: source
                )
            },
            source: source,
            rawInningEvidence: snapshot.inning
        )
        return LegacyCanonicalMappingResult(
            canonicalValue: lineup,
            validation: CanonicalDomainValidator.validateLineup(lineup, sourceLocation: snapshot.sourceLocation),
            preservedRawEvidence: ["inning": String(snapshot.inning), "everyoneHits": String(snapshot.everyoneHits)],
            sourceIdentity: snapshot.identity,
            sourceLocation: snapshot.sourceLocation,
            relationshipResolution: relationshipStatus(for: sideEvidence)
        )
    }

    static func mapScoringEvent(_ snapshot: LegacyAtbatEvidenceSnapshot, source: ScoringEventEvidenceSource = .compatibilityTransport) -> LegacyCanonicalMappingResult<CanonicalScoringEventEvidence> {
        let batter = snapshot.player.map { LineupParticipantEvidence.reusablePlayer(reusablePlayer(from: $0, source: .compatibilityTransport)) }
        let unsupported = unsupportedAtbatValues(snapshot)
        let event = CanonicalScoringEventEvidence(
            eventIdentity: snapshot.identity,
            gameIdentity: snapshot.gameIdentity,
            orderingEvidence: [.knownSequence(OrderEvidence(kind: .eventSequence, value: snapshot.sequence, sourceIndex: snapshot.sourceIndex)), .sourceFileOrder(OrderEvidence(kind: .sourceFile, value: snapshot.sourceIndex, sourceIndex: snapshot.sourceIndex))],
            inningContext: halfInning(from: snapshot),
            participants: ScoringEventParticipantEvidence(batter: batter, unresolvedRelationships: batter == nil ? ["batter"] : []),
            resultEvidence: ScoringEventResultEvidence(rawValue: snapshot.result),
            outsEvidence: CanonicalOutsState(outs: snapshot.outs < 0 ? .invalid(snapshot.outs) : .known(snapshot.outs), outsRecordedByEvent: snapshot.outs, endOfHalfEvidence: snapshot.endOfInning, thirdOutContext: snapshot.outs == 3),
            batterAdvancement: runnerState(maxbase: snapshot.maxbase, player: snapshot.player),
            runnerAdvancement: runnerOutState(outAt: snapshot.outAt, player: snapshot.player).map { [$0] } ?? [],
            rbiEvidence: .count(snapshot.rbis),
            earnedRunEvidence: .flag(snapshot.earnedRun),
            sacrificeEvidence: .count(snapshot.sacrificeFly + snapshot.sacrificeBunt),
            stolenBaseEvidence: .count(snapshot.stolenBases),
            endOfHalfEvidence: snapshot.endOfInning,
            historicalDisplayEvidence: [snapshot.result, snapshot.playRecord].filter { $0.isEmpty == false },
            unsupportedRawLegacyEvidence: unsupported,
            source: source
        )
        return LegacyCanonicalMappingResult(
            canonicalValue: event,
            validation: CanonicalDomainValidator.validateScoringEvent(event, sourceLocation: snapshot.sourceLocation),
            preservedRawEvidence: atbatRawEvidence(snapshot),
            unsupportedRawEvidence: unsupported,
            sourceIdentity: snapshot.identity,
            sourceLocation: snapshot.sourceLocation,
            relationshipResolution: batter == nil ? .unresolved : .resolved
        )
    }

    static func mapPitcherAppearance(
        _ snapshot: LegacyPitcherEvidenceSnapshot,
        homeSide: GameSideTeamParticipation?,
        visitingSide: GameSideTeamParticipation?,
        source: PitcherResponsibilityEvidenceSource = .compatibilityTransport
    ) -> LegacyCanonicalMappingResult<CanonicalPitcherAppearanceEvidence> {
        let side = sideRole(teamIdentity: snapshot.teamIdentity, homeSide: homeSide, visitingSide: visitingSide)
        let appearance = CanonicalPitcherAppearanceEvidence(
            appearanceIdentity: snapshot.identity,
            reusablePitcherIdentity: snapshot.player.identity,
            gameIdentity: snapshot.gameIdentity,
            teamSide: side,
            appearanceOrder: snapshot.sourceIndex.map { OrderEvidence(kind: .pitcherAppearance, value: $0, sourceIndex: $0) },
            roleEvidence: [.activePitcher],
            startBoundary: boundary(inning: snapshot.startInning, outs: snapshot.startOuts, batters: snapshot.startBatters),
            endBoundary: boundary(inning: snapshot.endInning, outs: snapshot.endOuts, batters: snapshot.endBatters),
            historicalDisplayEvidence: playerDisplay(from: snapshot.player),
            source: source
        )
        return LegacyCanonicalMappingResult(
            canonicalValue: appearance,
            validation: CanonicalDomainValidator.validatePitcherAppearance(appearance, sourceLocation: snapshot.sourceLocation),
            preservedRawEvidence: ["startInning": String(snapshot.startInning), "endInning": String(snapshot.endInning)],
            sourceIdentity: snapshot.identity,
            sourceLocation: snapshot.sourceLocation,
            relationshipResolution: side == nil ? .unresolved : .resolved
        )
    }

    static func mapSubstitutions(
        incoming: [LegacyPlayerEvidenceSnapshot],
        outgoing: [LegacyPlayerEvidenceSnapshot],
        gameIdentity: ImportedIdentifierEvidence,
        sourceLocation: String? = nil
    ) -> [LegacyCanonicalMappingResult<CanonicalSubstitutionEvidence>] {
        let maxCount = max(incoming.count, outgoing.count)
        guard maxCount > 0 else { return [] }
        let legacyArrayEvidence = CanonicalSubstitutionMeaningClassifier.classifyLegacyParallelArrays(
            incoming: incoming.map { .participant(.reusablePlayer(reusablePlayer(from: $0, source: .compatibilityTransport))) },
            outgoing: outgoing.map { .participant(.reusablePlayer(reusablePlayer(from: $0, source: .compatibilityTransport))) }
        )
        return (0..<maxCount).map { index in
            let incomingParticipant = incoming.indices.contains(index) ? SubstitutionParticipantEvidence.participant(.reusablePlayer(reusablePlayer(from: incoming[index], source: .compatibilityTransport))) : .missing
            let outgoingParticipant = outgoing.indices.contains(index) ? SubstitutionParticipantEvidence.participant(.reusablePlayer(reusablePlayer(from: outgoing[index], source: .compatibilityTransport))) : .missing
            let arrayEvidence: LegacyParallelSubstitutionEvidence = incoming.count == outgoing.count ? .equalCountsPlausibleIndexPairing(count: incoming.count) : .unequalCounts(incoming: incoming.count, outgoing: outgoing.count)
            let substitution = CanonicalSubstitutionEvidence(
                gameIdentity: gameIdentity,
                incoming: incomingParticipant,
                outgoing: outgoingParticipant,
                effectiveOrder: OrderEvidence(kind: .substitution, value: index, sourceIndex: index),
                roleEvidence: [.unknown],
                legacyArrayEvidence: legacyArrayEvidence.contains(.ambiguousSubstitutionPairing) ? .ambiguousOrdering : arrayEvidence,
                source: .compatibilityTransport
            )
            return LegacyCanonicalMappingResult(
                canonicalValue: substitution,
                validation: CanonicalDomainValidator.validateSubstitution(substitution, sourceLocation: sourceLocation),
                preservedRawEvidence: ["incomingCount": String(incoming.count), "outgoingCount": String(outgoing.count), "sourceIndex": String(index)],
                sourceIdentity: .missing,
                sourceLocation: sourceLocation,
                relationshipResolution: substitution.incoming.identity.validIdentifier == nil || substitution.outgoing.identity.validIdentifier == nil ? .unresolved : .resolved
            )
        }
    }

    private static func reusablePlayer(from snapshot: LegacyPlayerEvidenceSnapshot, source: PlayerEvidenceSource) -> ReusableCanonicalPlayer {
        ReusableCanonicalPlayer(
            identity: snapshot.identity,
            display: playerDisplay(from: snapshot),
            rosterEvidence: .importedRosterReference(teamIdentity: snapshot.teamIdentity, sourceCount: snapshot.sourceIndex),
            source: source
        )
    }

    private static func playerDisplay(from snapshot: LegacyPlayerEvidenceSnapshot) -> PlayerDisplayEvidence {
        PlayerDisplayEvidence(
            name: .present(snapshot.name),
            jerseyNumber: .present(snapshot.number),
            position: .present(snapshot.position),
            battingDirection: .present(snapshot.battingDirection),
            photo: snapshot.photoByteCount == nil ? .missing : .present(Data(repeating: 0, count: snapshot.photoByteCount ?? 0))
        )
    }

    private static func side(from snapshot: LegacyTeamEvidenceSnapshot, gameIdentity: ImportedIdentifierEvidence, role: TeamSideRole) -> GameSideTeamParticipation {
        GameSideTeamParticipation(
            gameIdentity: gameIdentity,
            role: role,
            resolution: .reusableTeam(mapTeam(snapshot).canonicalValue ?? ReusableCanonicalTeam(identity: snapshot.identity)),
            historicalDisplay: TeamDisplayEvidence(name: .present(snapshot.name), coach: .present(snapshot.coach), details: .present(snapshot.details)),
            source: .compatibilityTransport
        )
    }

    private static func lineupSide(teamIdentity: ImportedIdentifierEvidence, homeSide: GameSideTeamParticipation?, visitingSide: GameSideTeamParticipation?) -> LineupSideEvidence {
        if sameIdentity(teamIdentity, homeSide?.reusableTeamIdentity) { return homeSide.map { .gameSide($0) } ?? .home }
        if sameIdentity(teamIdentity, visitingSide?.reusableTeamIdentity) { return visitingSide.map { .gameSide($0) } ?? .visiting }
        if teamIdentity.validIdentifier == nil { return .unresolved }
        return .conflicting(expected: nil, actual: nil)
    }

    private static func lineupTeam(teamIdentity: ImportedIdentifierEvidence, homeSide: GameSideTeamParticipation?, visitingSide: GameSideTeamParticipation?) -> LineupTeamEvidence {
        if sameIdentity(teamIdentity, homeSide?.reusableTeamIdentity), let homeSide { return .gameSide(homeSide) }
        if sameIdentity(teamIdentity, visitingSide?.reusableTeamIdentity), let visitingSide { return .gameSide(visitingSide) }
        return .conflicting(teamIdentity, TeamDisplayEvidence())
    }

    private static func sideRole(teamIdentity: ImportedIdentifierEvidence, homeSide: GameSideTeamParticipation?, visitingSide: GameSideTeamParticipation?) -> TeamSideRole? {
        if sameIdentity(teamIdentity, homeSide?.reusableTeamIdentity) { return .home }
        if sameIdentity(teamIdentity, visitingSide?.reusableTeamIdentity) { return .visiting }
        return nil
    }

    private static func sameIdentity(_ lhs: ImportedIdentifierEvidence?, _ rhs: ImportedIdentifierEvidence?) -> Bool {
        guard let lhsID = lhs?.validIdentifier, let rhsID = rhs?.validIdentifier else { return false }
        return lhsID == rhsID
    }

    private static func relationshipStatus(for sideEvidence: LineupSideEvidence) -> LegacyRelationshipResolutionStatus {
        switch sideEvidence {
        case .gameSide, .home, .visiting, .inferredFromArrayPosition:
            return .resolved
        case .missing:
            return .missing
        case .conflicting:
            return .conflicting
        case .unresolved:
            return .unresolved
        }
    }

    private static func halfInning(from snapshot: LegacyAtbatEvidenceSnapshot) -> CanonicalHalfInning {
        let rounded = Int(snapshot.inning.rounded(.down))
        let half: HalfInningEvidence
        if snapshot.inning.truncatingRemainder(dividingBy: 1) == 0.5 {
            half = .known(.bottom)
        } else if snapshot.inning.truncatingRemainder(dividingBy: 1) == 0 {
            half = .known(.top)
        } else {
            half = .unresolved
        }
        return CanonicalHalfInning(
            number: rounded > 0 ? .known(rounded) : .invalid(rounded),
            half: half,
            endOfHalfEvidence: snapshot.endOfInning,
            source: .compatibilityTransport
        )
    }

    private static func runnerState(maxbase: String, player: LegacyPlayerEvidenceSnapshot?) -> RunnerStateEvidence? {
        guard maxbase.isEmpty == false else { return nil }
        guard let player else { return .ambiguousLegacyMaxBase(maxbase) }
        let runner = RunnerIdentityEvidence.reusablePlayer(reusablePlayer(from: player, source: .compatibilityTransport))
        switch maxbase {
        case "First", "1", "1B": return .activeOccupant(base: .first, runner: runner)
        case "Second", "2", "2B": return .activeOccupant(base: .second, runner: runner)
        case "Third", "3", "3B": return .activeOccupant(base: .third, runner: runner)
        case "Home", "4", "HR": return .scored(runner: runner, sourceBase: nil)
        default: return .unsupportedLegacyValue(field: "maxbase", value: maxbase)
        }
    }

    private static func runnerOutState(outAt: String, player: LegacyPlayerEvidenceSnapshot?) -> RunnerStateEvidence? {
        guard outAt.isEmpty == false else { return nil }
        guard let player else { return .ambiguousLegacyOutAt(outAt) }
        let runner = RunnerIdentityEvidence.reusablePlayer(reusablePlayer(from: player, source: .compatibilityTransport))
        switch outAt {
        case "First": return .out(runner: runner, sourceBase: .first)
        case "Second": return .out(runner: runner, sourceBase: .second)
        case "Third": return .out(runner: runner, sourceBase: .third)
        case "Home": return .out(runner: runner, sourceBase: .home)
        default: return .unsupportedLegacyValue(field: "outAt", value: outAt)
        }
    }

    private static func boundary(inning: Int, outs: Int, batters: Int) -> PitcherAppearanceBoundaryEvidence {
        if inning == 0 && outs == 0 && batters == 0 { return .missing }
        if inning <= 0 || outs < 0 || batters < 0 { return .incomplete(inning: inning, outs: outs, batters: batters) }
        return .known(inning: inning, outs: outs, batters: batters)
    }

    private static func playerRawEvidence(_ snapshot: LegacyPlayerEvidenceSnapshot) -> [String: String] {
        [
            "name": snapshot.name,
            "number": snapshot.number,
            "position": snapshot.position,
            "battingDirection": snapshot.battingDirection,
            "battingOrder": String(snapshot.battingOrder)
        ]
    }

    private static func atbatRawEvidence(_ snapshot: LegacyAtbatEvidenceSnapshot) -> [String: String] {
        [
            "result": snapshot.result,
            "maxbase": snapshot.maxbase,
            "outAt": snapshot.outAt,
            "inning": String(snapshot.inning),
            "sequence": String(snapshot.sequence),
            "scorecardColumn": String(snapshot.scorecardColumn),
            "rbis": String(snapshot.rbis),
            "outs": String(snapshot.outs),
            "playRecord": snapshot.playRecord
        ]
    }

    private static func unsupportedAtbatValues(_ snapshot: LegacyAtbatEvidenceSnapshot) -> [String] {
        var values: [String] = []
        if case .unsupportedRawResult = ScoringEventResultEvidence(rawValue: snapshot.result) {
            values.append("result=\(snapshot.result)")
        }
        if case .unsupportedLegacyValue = runnerState(maxbase: snapshot.maxbase, player: snapshot.player) {
            values.append("maxbase=\(snapshot.maxbase)")
        }
        if case .unsupportedLegacyValue = runnerOutState(outAt: snapshot.outAt, player: snapshot.player) {
            values.append("outAt=\(snapshot.outAt)")
        }
        return values.sorted()
    }
}

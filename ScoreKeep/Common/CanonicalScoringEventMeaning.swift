import Foundation

/// Non-routed Phase 1 foundation for recorded scoring-event evidence.
/// These values classify evidence only and do not apply events, score runs, or mutate game state.
enum ScoringEventEvidenceSource: String, Hashable, Sendable {
    case currentAtbatRecord
    case importedGame
    case compatibilityTransport
    case scorecardPresentation
    case syntheticVerification
    case unknown
}

enum CanonicalScoringEventIdentityComparison: Hashable, Sendable {
    case sameIdentityMatchingEvidence
    case sameIdentityConflictingEvidence([String])
    case distinctIdentitiesMatchingPlayEvidence
    case distinctIdentitiesDifferentPlayEvidence
    case missingIdentity
    case invalidIdentity
    case duplicateImportedIdentity
    case unresolvedEquivalence
}

enum ScoringEventOrderingEvidence: Hashable, Sendable {
    case knownSequence(OrderEvidence)
    case missingSequence
    case duplicateSequence(Int)
    case conflictingSequenceAndScorecardColumn(sequence: Int, column: Int)
    case sourceFileOrder(OrderEvidence)
    case stableTieEvidence(OrderEvidence)
    case unresolved
}

enum ScoringEventResultEvidence: Hashable, Sendable {
    case batterReachesBase(rawValue: String)
    case batterOut(rawValue: String)
    case runnerAdvances(rawValue: String)
    case runnerScores(rawValue: String)
    case runnerOut(rawValue: String)
    case placeholder(rawValue: String)
    case unknownRawResult(String)
    case unsupportedRawResult(String)
    case conflicting(Set<ScoringEventResultEvidence>)

    init(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case "Single", "Double", "Triple", "Home Run", "Walk", "Hit By Pitch", "Dropped 3rd Strike", "Catcher Interference", "Fielder's Choice", "Error":
            self = .batterReachesBase(rawValue: trimmed)
        case "Ground Out", "Fly Out", "Line Out", "Foul Out", "Strikeout", "Strikeout Looking", "Sacrifice Fly", "Sacrifice Bunt":
            self = .batterOut(rawValue: trimmed)
        case "Safe":
            self = .runnerAdvances(rawValue: trimmed)
        case "Home":
            self = .runnerScores(rawValue: trimmed)
        case "First", "Second", "Third":
            self = .runnerOut(rawValue: trimmed)
        case "", "Result":
            self = .placeholder(rawValue: trimmed)
        case "??":
            self = .unknownRawResult(trimmed)
        default:
            self = .unsupportedRawResult(trimmed)
        }
    }
}

enum ScoringEventMarkerEvidence: Hashable, Sendable {
    case notRepresented
    case count(Int)
    case flag(Bool)
    case conflicting(String)
}

struct ScoringEventParticipantEvidence: Hashable, Sendable {
    let batter: LineupParticipantEvidence?
    let runners: [RunnerStateEvidence]
    let unresolvedRelationships: [String]

    init(
        batter: LineupParticipantEvidence?,
        runners: [RunnerStateEvidence] = [],
        unresolvedRelationships: [String] = []
    ) {
        self.batter = batter
        self.runners = runners
        self.unresolvedRelationships = unresolvedRelationships
    }
}

struct CanonicalScoringEventEvidence: Hashable, Sendable {
    let eventIdentity: ImportedIdentifierEvidence
    let gameIdentity: ImportedIdentifierEvidence
    let orderingEvidence: [ScoringEventOrderingEvidence]
    let inningContext: CanonicalHalfInning?
    let teamSide: TeamSideRole?
    let participants: ScoringEventParticipantEvidence
    let resultEvidence: ScoringEventResultEvidence
    let outsEvidence: CanonicalOutsState?
    let batterAdvancement: RunnerStateEvidence?
    let runnerAdvancement: [RunnerStateEvidence]
    let runsScored: ScoringEventMarkerEvidence
    let rbiEvidence: ScoringEventMarkerEvidence
    let earnedRunEvidence: ScoringEventMarkerEvidence
    let sacrificeEvidence: ScoringEventMarkerEvidence
    let stolenBaseEvidence: ScoringEventMarkerEvidence
    let endOfHalfEvidence: Bool
    let historicalDisplayEvidence: [String]
    let unsupportedRawLegacyEvidence: [String]
    let source: ScoringEventEvidenceSource

    init(
        eventIdentity: ImportedIdentifierEvidence,
        gameIdentity: ImportedIdentifierEvidence,
        orderingEvidence: [ScoringEventOrderingEvidence] = [],
        inningContext: CanonicalHalfInning? = nil,
        teamSide: TeamSideRole? = nil,
        participants: ScoringEventParticipantEvidence,
        resultEvidence: ScoringEventResultEvidence,
        outsEvidence: CanonicalOutsState? = nil,
        batterAdvancement: RunnerStateEvidence? = nil,
        runnerAdvancement: [RunnerStateEvidence] = [],
        runsScored: ScoringEventMarkerEvidence = .notRepresented,
        rbiEvidence: ScoringEventMarkerEvidence = .notRepresented,
        earnedRunEvidence: ScoringEventMarkerEvidence = .notRepresented,
        sacrificeEvidence: ScoringEventMarkerEvidence = .notRepresented,
        stolenBaseEvidence: ScoringEventMarkerEvidence = .notRepresented,
        endOfHalfEvidence: Bool = false,
        historicalDisplayEvidence: [String] = [],
        unsupportedRawLegacyEvidence: [String] = [],
        source: ScoringEventEvidenceSource = .unknown
    ) {
        self.eventIdentity = eventIdentity
        self.gameIdentity = gameIdentity
        self.orderingEvidence = orderingEvidence
        self.inningContext = inningContext
        self.teamSide = teamSide
        self.participants = participants
        self.resultEvidence = resultEvidence
        self.outsEvidence = outsEvidence
        self.batterAdvancement = batterAdvancement
        self.runnerAdvancement = runnerAdvancement
        self.runsScored = runsScored
        self.rbiEvidence = rbiEvidence
        self.earnedRunEvidence = earnedRunEvidence
        self.sacrificeEvidence = sacrificeEvidence
        self.stolenBaseEvidence = stolenBaseEvidence
        self.endOfHalfEvidence = endOfHalfEvidence
        self.historicalDisplayEvidence = historicalDisplayEvidence
        self.unsupportedRawLegacyEvidence = unsupportedRawLegacyEvidence
        self.source = source
    }

    var stableIdentityEvidence: StableIdentityEvidence {
        StableIdentityEvidence(
            concept: .scoringEvent,
            importedIdentifier: eventIdentity,
            displayEvidence: historicalDisplayEvidence.map { IdentityDisplayEvidence("play", $0) }
        )
    }
}

enum ScoringEventClassification: Hashable, Sendable {
    case validEventIdentity
    case missingEventIdentity
    case invalidEventIdentity
    case duplicateImportedEventIdentity
    case unresolvedEventIdentity
    case knownEventSequence
    case missingEventSequence
    case duplicateEventSequence(Int)
    case conflictingSequenceAndScorecardColumn
    case sourceFileOrderEvidence
    case stableTieEvidence
    case unresolvedEventOrder
    case batterParticipantPresent
    case batterParticipantMissing
    case batterParticipantInvalid
    case runnerAdvancementEvidence
    case runnerScores
    case runnerOut
    case multipleOutsRecorded
    case rbiMarker
    case earnedRunMarker
    case sacrificeMarker
    case stolenBaseMarker
    case endOfInningMarker
    case batterReachesBase
    case batterOut
    case unknownResultEvidence
    case unsupportedResultEvidence
    case contradictoryResultEvidence
    case missingOrUnresolvedParticipantRelationship
    case unsupportedRawLegacyEvidence
    case historicalDisplayEvidence
    case nonMutatingEvidenceOnly
}

enum CanonicalScoringEventMeaningClassifier {
    static func compareIdentity(
        _ lhs: CanonicalScoringEventEvidence,
        _ rhs: CanonicalScoringEventEvidence
    ) -> CanonicalScoringEventIdentityComparison {
        switch StableIdentityClassifier.compare(lhs.stableIdentityEvidence, rhs.stableIdentityEvidence) {
        case .sameIdentifierMatchingEvidence:
            let conflicts = eventConflicts(lhs, rhs)
            return conflicts.isEmpty ? .sameIdentityMatchingEvidence : .sameIdentityConflictingEvidence(conflicts)
        case let .sameIdentifierConflictingEvidence(fields):
            return .sameIdentityConflictingEvidence(fields + eventConflicts(lhs, rhs))
        case .differentIdentifiersMatchingDisplay:
            return .distinctIdentitiesMatchingPlayEvidence
        case .differentIdentifiersDifferentDisplay:
            return .distinctIdentitiesDifferentPlayEvidence
        case .bothMissingIdentifier, .oneMissingIdentifier:
            return .missingIdentity
        case .invalidIdentifier:
            return .invalidIdentity
        case .unresolvedEquivalence:
            return .unresolvedEquivalence
        }
    }

    static func classify(_ event: CanonicalScoringEventEvidence) -> Set<ScoringEventClassification> {
        var classifications: Set<ScoringEventClassification> = [.nonMutatingEvidenceOnly]

        switch event.eventIdentity {
        case .valid:
            classifications.insert(.validEventIdentity)
        case .missing:
            classifications.insert(.missingEventIdentity)
            classifications.insert(.unresolvedEventIdentity)
        case .invalid:
            classifications.insert(.invalidEventIdentity)
            classifications.insert(.unresolvedEventIdentity)
        }

        for order in event.orderingEvidence {
            switch order {
            case .knownSequence:
                classifications.insert(.knownEventSequence)
            case .missingSequence:
                classifications.insert(.missingEventSequence)
            case let .duplicateSequence(value):
                classifications.insert(.duplicateEventSequence(value))
            case .conflictingSequenceAndScorecardColumn:
                classifications.insert(.conflictingSequenceAndScorecardColumn)
            case .sourceFileOrder:
                classifications.insert(.sourceFileOrderEvidence)
            case .stableTieEvidence:
                classifications.insert(.stableTieEvidence)
            case .unresolved:
                classifications.insert(.unresolvedEventOrder)
            }
        }
        if event.orderingEvidence.isEmpty { classifications.insert(.missingEventSequence) }

        if let batter = event.participants.batter {
            classifications.insert(.batterParticipantPresent)
            if case .invalidPlayerIdentity = batter { classifications.insert(.batterParticipantInvalid) }
        } else {
            classifications.insert(.batterParticipantMissing)
        }
        if event.participants.unresolvedRelationships.isEmpty == false {
            classifications.insert(.missingOrUnresolvedParticipantRelationship)
        }

        classifications.formUnion(classifyResult(event.resultEvidence))
        classifications.formUnion(classifyMarkers(event))
        classifications.formUnion(classifyRunnerEvidence(event.participants.runners + event.runnerAdvancement + [event.batterAdvancement].compactMap { $0 }))

        if let outsEvidence = event.outsEvidence,
           let outsRecorded = outsEvidence.outsRecordedByEvent,
           outsRecorded > 1 {
            classifications.insert(.multipleOutsRecorded)
        }
        if event.endOfHalfEvidence { classifications.insert(.endOfInningMarker) }
        if event.historicalDisplayEvidence.isEmpty == false { classifications.insert(.historicalDisplayEvidence) }
        if event.unsupportedRawLegacyEvidence.isEmpty == false { classifications.insert(.unsupportedRawLegacyEvidence) }

        return classifications
    }

    static func classifyEventSet(_ events: [CanonicalScoringEventEvidence]) -> Set<ScoringEventClassification> {
        var classifications = events.reduce(into: Set<ScoringEventClassification>()) { result, event in
            result.formUnion(classify(event))
        }
        let ids = events.compactMap { $0.eventIdentity.validIdentifier }
        if ids.contains(where: { id in ids.filter { $0 == id }.count > 1 }) {
            classifications.insert(.duplicateImportedEventIdentity)
        }
        return classifications
    }

    private static func classifyResult(_ result: ScoringEventResultEvidence) -> Set<ScoringEventClassification> {
        switch result {
        case .batterReachesBase:
            return [.batterReachesBase]
        case .batterOut:
            return [.batterOut]
        case .runnerAdvances:
            return [.runnerAdvancementEvidence]
        case .runnerScores:
            return [.runnerAdvancementEvidence, .runnerScores]
        case .runnerOut:
            return [.runnerAdvancementEvidence, .runnerOut]
        case .placeholder, .unknownRawResult:
            return [.unknownResultEvidence]
        case .unsupportedRawResult:
            return [.unsupportedResultEvidence]
        case .conflicting:
            return [.contradictoryResultEvidence]
        }
    }

    private static func classifyMarkers(_ event: CanonicalScoringEventEvidence) -> Set<ScoringEventClassification> {
        var classifications: Set<ScoringEventClassification> = []
        if markerHasEvidence(event.rbiEvidence) { classifications.insert(.rbiMarker) }
        if markerHasEvidence(event.earnedRunEvidence) { classifications.insert(.earnedRunMarker) }
        if markerHasEvidence(event.sacrificeEvidence) { classifications.insert(.sacrificeMarker) }
        if markerHasEvidence(event.stolenBaseEvidence) { classifications.insert(.stolenBaseMarker) }
        if markerHasEvidence(event.runsScored) { classifications.insert(.runnerScores) }
        return classifications
    }

    private static func markerHasEvidence(_ marker: ScoringEventMarkerEvidence) -> Bool {
        switch marker {
        case .notRepresented:
            return false
        case let .count(value):
            return value != 0
        case .flag, .conflicting:
            return true
        }
    }

    private static func classifyRunnerEvidence(_ states: [RunnerStateEvidence]) -> Set<ScoringEventClassification> {
        var classifications: Set<ScoringEventClassification> = []
        for state in states {
            switch state {
            case .activeOccupant, .batterRunner, .historicalRunner, .ambiguousLegacyMaxBase, .ambiguousLegacyOutAt:
                classifications.insert(.runnerAdvancementEvidence)
            case .scored:
                classifications.insert(.runnerAdvancementEvidence)
                classifications.insert(.runnerScores)
            case .out:
                classifications.insert(.runnerAdvancementEvidence)
                classifications.insert(.runnerOut)
            case .unsupportedLegacyValue:
                classifications.insert(.unsupportedRawLegacyEvidence)
            case .contradictory:
                classifications.insert(.contradictoryResultEvidence)
            }
        }
        return classifications
    }

    private static func eventConflicts(_ lhs: CanonicalScoringEventEvidence, _ rhs: CanonicalScoringEventEvidence) -> [String] {
        var conflicts: [String] = []
        if lhs.gameIdentity != rhs.gameIdentity { conflicts.append("gameIdentity") }
        if lhs.teamSide != rhs.teamSide { conflicts.append("teamSide") }
        if lhs.resultEvidence != rhs.resultEvidence { conflicts.append("resultEvidence") }
        if lhs.participants.batter?.playerIdentity != rhs.participants.batter?.playerIdentity { conflicts.append("batter") }
        return conflicts.sorted()
    }
}

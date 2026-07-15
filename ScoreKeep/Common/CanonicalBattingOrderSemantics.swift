import Foundation

/// Non-routed Phase 1 foundation for game-specific batting-order meaning.
/// These values classify evidence only and do not project current or next batters.
enum CanonicalBattingLineupContext: Hashable, Sendable {
    case traditional
    case everyoneHits
    case unknown
    case unsupported(String)
    case ambiguous(String)

    init(_ mode: LineupModeEvidence) {
        switch mode {
        case .traditional:
            self = .traditional
        case .everyoneHits:
            self = .everyoneHits
        case .unknown, .missing:
            self = .unknown
        case let .unsupported(value):
            self = .unsupported(value)
        case let .ambiguous(reason):
            self = .ambiguous(reason)
        }
    }
}

enum CanonicalBattingSlotEvidence: Hashable, Sendable {
    case known(Int)
    case missing
    case invalidRaw(String)
    case unsupportedRaw(Int)
    case nonHittingSentinel(Int)
    case duplicate(Int)
    case conflicting([Int])
    case playerWithoutSlot
    case unresolvedParticipant(slot: Int?)
    case historicalSlot(Int)
    case sourceOrder(OrderEvidence)
    case progressionHint(OrderEvidence)

    init(rawSlot: RawBattingSlotEvidence, participant: LineupParticipantEvidence? = nil, historical: Bool = false) {
        switch rawSlot {
        case let .known(value):
            if participant?.playerIdentity.validIdentifier == nil, participant != nil {
                self = .unresolvedParticipant(slot: value)
            } else if historical {
                self = .historicalSlot(value)
            } else {
                self = .known(value)
            }
        case .missing:
            if participant?.playerIdentity.validIdentifier == nil, participant != nil {
                self = .unresolvedParticipant(slot: nil)
            } else {
                self = .missing
            }
        case let .invalid(value):
            self = .invalidRaw(value)
        case let .unsupportedRawValue(value):
            self = .unsupportedRaw(value)
        case let .nonHittingSentinel(value):
            self = .nonHittingSentinel(value)
        case let .conflicting(values):
            self = .conflicting(values)
        }
    }

    var knownSlotValue: Int? {
        switch self {
        case let .known(value), let .historicalSlot(value):
            return value
        default:
            return nil
        }
    }
}

struct CanonicalBattingOrderEntry: Hashable, Sendable {
    let gameIdentity: ImportedIdentifierEvidence
    let lineupIdentity: ImportedIdentifierEvidence
    let participant: LineupParticipantEvidence
    let slotEvidence: CanonicalBattingSlotEvidence
    let sourceOrderEvidence: OrderEvidence?
    let rosterOrderEvidence: OrderEvidence?
    let displaySortEvidence: OrderEvidence?
    let jerseyNumberEvidence: PlayerTextEvidence
    let source: LineupEvidenceSource

    init(
        gameIdentity: ImportedIdentifierEvidence,
        lineupIdentity: ImportedIdentifierEvidence,
        participant: LineupParticipantEvidence,
        slotEvidence: CanonicalBattingSlotEvidence,
        sourceOrderEvidence: OrderEvidence? = nil,
        rosterOrderEvidence: OrderEvidence? = nil,
        displaySortEvidence: OrderEvidence? = nil,
        jerseyNumberEvidence: PlayerTextEvidence = .missing,
        source: LineupEvidenceSource = .unknown
    ) {
        self.gameIdentity = gameIdentity
        self.lineupIdentity = lineupIdentity
        self.participant = participant
        self.slotEvidence = slotEvidence
        self.sourceOrderEvidence = sourceOrderEvidence
        self.rosterOrderEvidence = rosterOrderEvidence
        self.displaySortEvidence = displaySortEvidence
        self.jerseyNumberEvidence = jerseyNumberEvidence
        self.source = source
    }
}

struct CanonicalBattingOrderEvidence: Hashable, Sendable {
    let gameIdentity: ImportedIdentifierEvidence
    let lineupIdentity: ImportedIdentifierEvidence
    let context: CanonicalBattingLineupContext
    let entries: [CanonicalBattingOrderEntry]
    let historicalChangeEvidence: Bool

    init(
        gameIdentity: ImportedIdentifierEvidence,
        lineupIdentity: ImportedIdentifierEvidence,
        context: CanonicalBattingLineupContext,
        entries: [CanonicalBattingOrderEntry],
        historicalChangeEvidence: Bool = false
    ) {
        self.gameIdentity = gameIdentity
        self.lineupIdentity = lineupIdentity
        self.context = context
        self.entries = entries
        self.historicalChangeEvidence = historicalChangeEvidence
    }

    init(lineup: CanonicalGameLineup, historicalChangeEvidence: Bool = false) {
        self.init(
            gameIdentity: lineup.gameIdentity,
            lineupIdentity: lineup.lineupIdentity,
            context: CanonicalBattingLineupContext(lineup.mode),
            entries: lineup.entries.map { entry in
                CanonicalBattingOrderEntry(
                    gameIdentity: lineup.gameIdentity,
                    lineupIdentity: lineup.lineupIdentity,
                    participant: entry.participant,
                    slotEvidence: CanonicalBattingSlotEvidence(
                        rawSlot: entry.battingSlot,
                        participant: entry.participant,
                        historical: entry.source == .historicalGameParticipation
                    ),
                    sourceOrderEvidence: entry.sourceOrder,
                    jerseyNumberEvidence: entry.historicalDisplay.jerseyNumber,
                    source: entry.source
                )
            },
            historicalChangeEvidence: historicalChangeEvidence
        )
    }
}

enum BattingProgressionDirection: Hashable, Sendable {
    case forward
    case unknown
}

enum BattingProgressionHint: Hashable, Sendable {
    case orderedKnownSlots([Int], direction: BattingProgressionDirection, expectsWraparound: Bool)
    case unknownIncompleteEvidence
    case ambiguousDuplicateSlots([Int])
    case ambiguousConflictingEvidence
    case historicalContext([Int])
}

enum CanonicalBattingOrderClassification: Hashable, Sendable {
    case knownDistinctSlots
    case missingSlot
    case invalidRawSlot
    case unsupportedRawSlot(Int)
    case nonHittingSentinel(Int)
    case duplicateSlot(Int)
    case conflictingSlotEvidence
    case playerWithoutSlot
    case unresolvedParticipantWithSlot(Int?)
    case historicalSlotEvidence
    case sourceOrderEvidence
    case progressionHintAvailable
    case progressionUnknown
    case progressionAmbiguous
    case traditionalContext
    case everyoneHitsContext
    case unknownLineupMode
    case rosterOrderIgnored
    case displaySortIgnored
    case jerseyNumberIgnored
}

enum CanonicalBattingOrderClassifier {
    static func classify(_ evidence: CanonicalBattingOrderEvidence) -> Set<CanonicalBattingOrderClassification> {
        var classifications: Set<CanonicalBattingOrderClassification> = []

        switch evidence.context {
        case .traditional:
            classifications.insert(.traditionalContext)
        case .everyoneHits:
            classifications.insert(.everyoneHitsContext)
        case .unknown, .unsupported, .ambiguous:
            classifications.insert(.unknownLineupMode)
        }

        var slotCounts: [Int: Int] = [:]
        var participantSlots: [UUID: Set<Int>] = [:]
        var hasMissing = false
        var hasConflict = false

        for entry in evidence.entries {
            if entry.sourceOrderEvidence != nil { classifications.insert(.sourceOrderEvidence) }
            if entry.rosterOrderEvidence != nil { classifications.insert(.rosterOrderIgnored) }
            if entry.displaySortEvidence != nil { classifications.insert(.displaySortIgnored) }
            if entry.jerseyNumberEvidence.value != nil { classifications.insert(.jerseyNumberIgnored) }

            switch entry.slotEvidence {
            case let .known(value):
                slotCounts[value, default: 0] += 1
                if let playerID = entry.participant.playerIdentity.validIdentifier {
                    participantSlots[playerID, default: []].insert(value)
                }
            case .missing:
                hasMissing = true
                classifications.insert(.missingSlot)
            case .invalidRaw:
                classifications.insert(.invalidRawSlot)
            case let .unsupportedRaw(value):
                classifications.insert(.unsupportedRawSlot(value))
            case let .nonHittingSentinel(value):
                classifications.insert(.nonHittingSentinel(value))
            case let .duplicate(value):
                classifications.insert(.duplicateSlot(value))
            case .conflicting:
                hasConflict = true
                classifications.insert(.conflictingSlotEvidence)
            case .playerWithoutSlot:
                hasMissing = true
                classifications.insert(.playerWithoutSlot)
            case let .unresolvedParticipant(slot):
                if let slot { slotCounts[slot, default: 0] += 1 }
                classifications.insert(.unresolvedParticipantWithSlot(slot))
            case let .historicalSlot(value):
                slotCounts[value, default: 0] += 1
                classifications.insert(.historicalSlotEvidence)
            case .sourceOrder:
                classifications.insert(.sourceOrderEvidence)
            case .progressionHint:
                classifications.insert(.progressionHintAvailable)
            }
        }

        for (slot, count) in slotCounts where count > 1 {
            classifications.insert(.duplicateSlot(slot))
        }

        if participantSlots.values.contains(where: { $0.count > 1 }) {
            classifications.insert(.conflictingSlotEvidence)
            hasConflict = true
        }

        if slotCounts.isEmpty == false && hasMissing == false && hasConflict == false && classifications.contains(where: whereDuplicateSlot) == false {
            classifications.insert(.knownDistinctSlots)
        }

        switch progressionHint(for: evidence) {
        case .orderedKnownSlots:
            classifications.insert(.progressionHintAvailable)
        case .unknownIncompleteEvidence:
            classifications.insert(.progressionUnknown)
        case .ambiguousDuplicateSlots, .ambiguousConflictingEvidence:
            classifications.insert(.progressionAmbiguous)
        case .historicalContext:
            classifications.insert(.historicalSlotEvidence)
            classifications.insert(.progressionHintAvailable)
        }

        if evidence.historicalChangeEvidence { classifications.insert(.historicalSlotEvidence) }

        return classifications
    }

    static func progressionHint(for evidence: CanonicalBattingOrderEvidence) -> BattingProgressionHint {
        let knownSlots = evidence.entries.compactMap(\.slotEvidence.knownSlotValue)
        guard knownSlots.count == evidence.entries.count, knownSlots.isEmpty == false else {
            return .unknownIncompleteEvidence
        }

        let duplicateSlots = knownSlots.filter { slot in knownSlots.filter { $0 == slot }.count > 1 }
        if duplicateSlots.isEmpty == false {
            return .ambiguousDuplicateSlots(Array(Set(duplicateSlots)).sorted())
        }

        if evidence.entries.contains(where: { if case .conflicting = $0.slotEvidence { return true }; return false }) {
            return .ambiguousConflictingEvidence
        }

        let orderedSlots = knownSlots.sorted()
        if evidence.historicalChangeEvidence || evidence.entries.contains(where: { if case .historicalSlot = $0.slotEvidence { return true }; return false }) {
            return .historicalContext(orderedSlots)
        }

        return .orderedKnownSlots(orderedSlots, direction: .forward, expectsWraparound: true)
    }

    private static func whereDuplicateSlot(_ classification: CanonicalBattingOrderClassification) -> Bool {
        if case .duplicateSlot = classification { return true }
        return false
    }
}

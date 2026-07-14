import Foundation

/// Non-routed Phase 1 foundation for stable baseball identity and ordering evidence.
/// These values do not read, write, or route existing SwiftData records.
enum BaseballIdentityConcept: String, Hashable, Sendable {
    case team
    case player
    case game
    case gameParticipant
    case scoringEvent
    case lineup
    case pitcher
    case substitution
}

enum ImportedIdentifierEvidence: Hashable, Sendable {
    case valid(UUID)
    case missing
    case invalid(String)

    init(rawValue: String?) {
        guard let rawValue else {
            self = .missing
            return
        }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else {
            self = .missing
            return
        }

        if let identifier = UUID(uuidString: trimmedValue) {
            self = .valid(identifier)
        } else {
            self = .invalid(trimmedValue)
        }
    }

    var validIdentifier: UUID? {
        if case let .valid(identifier) = self { return identifier }
        return nil
    }
}

struct IdentityDisplayEvidence: Hashable, Sendable {
    let field: String
    let value: String

    init(_ field: String, _ value: String) {
        self.field = field
        self.value = value
    }
}

struct StableIdentityEvidence: Hashable, Sendable {
    let concept: BaseballIdentityConcept
    let importedIdentifier: ImportedIdentifierEvidence
    let displayEvidence: [IdentityDisplayEvidence]

    init(
        concept: BaseballIdentityConcept,
        importedIdentifier: ImportedIdentifierEvidence,
        displayEvidence: [IdentityDisplayEvidence] = []
    ) {
        self.concept = concept
        self.importedIdentifier = importedIdentifier
        self.displayEvidence = displayEvidence
    }
}

enum IdentityEvidenceMatch: Hashable, Sendable {
    case sameIdentifierMatchingEvidence
    case sameIdentifierConflictingEvidence([String])
    case differentIdentifiersMatchingDisplay
    case differentIdentifiersDifferentDisplay
    case bothMissingIdentifier
    case oneMissingIdentifier
    case invalidIdentifier
    case unresolvedEquivalence
}

enum DuplicateIdentityClassification: Hashable, Sendable {
    case exactRepeatedEvidence
    case duplicateIdentifierMatchingContent
    case duplicateIdentifierConflictingContent([String])
    case differentIdentifiersMatchingDisplay
    case missingIdentifier
    case invalidIdentifier
    case unresolvedEquivalence
}

enum StableIdentityClassifier {
    static func compare(_ lhs: StableIdentityEvidence, _ rhs: StableIdentityEvidence) -> IdentityEvidenceMatch {
        guard lhs.concept == rhs.concept else { return .unresolvedEquivalence }

        switch (lhs.importedIdentifier, rhs.importedIdentifier) {
        case (.invalid, _), (_, .invalid):
            return .invalidIdentifier
        case let (.valid(lhsID), .valid(rhsID)) where lhsID == rhsID:
            let conflicts = displayConflicts(lhs.displayEvidence, rhs.displayEvidence)
            return conflicts.isEmpty ? .sameIdentifierMatchingEvidence : .sameIdentifierConflictingEvidence(conflicts)
        case (.valid, .valid):
            return displayEvidenceMatches(lhs.displayEvidence, rhs.displayEvidence)
                ? .differentIdentifiersMatchingDisplay
                : .differentIdentifiersDifferentDisplay
        case (.missing, .missing):
            return displayEvidenceMatches(lhs.displayEvidence, rhs.displayEvidence)
                ? .bothMissingIdentifier
                : .unresolvedEquivalence
        case (.valid, .missing), (.missing, .valid):
            return .oneMissingIdentifier
        }
    }

    static func classifyDuplicates(_ evidence: [StableIdentityEvidence]) -> [DuplicateIdentityClassification] {
        var classifications: [DuplicateIdentityClassification] = []
        var validIdentifierEvidence: [UUID: StableIdentityEvidence] = [:]
        var missingIdentifierFound = false
        var invalidIdentifierFound = false

        for item in evidence {
            switch item.importedIdentifier {
            case let .valid(identifier):
                if let existing = validIdentifierEvidence[identifier] {
                    if existing == item {
                        classifications.append(.exactRepeatedEvidence)
                    } else {
                        let conflicts = displayConflicts(existing.displayEvidence, item.displayEvidence)
                        classifications.append(
                            conflicts.isEmpty
                                ? .duplicateIdentifierMatchingContent
                                : .duplicateIdentifierConflictingContent(conflicts)
                        )
                    }
                } else {
                    validIdentifierEvidence[identifier] = item
                }
            case .missing:
                missingIdentifierFound = true
            case .invalid:
                invalidIdentifierFound = true
            }
        }

        if missingIdentifierFound {
            classifications.append(.missingIdentifier)
        }

        if invalidIdentifierFound {
            classifications.append(.invalidIdentifier)
        }

        if classifications.isEmpty {
            let matchingDisplayPairs = allPairs(evidence).contains { lhs, rhs in
                lhs.concept == rhs.concept &&
                    lhs.importedIdentifier.validIdentifier != rhs.importedIdentifier.validIdentifier &&
                    displayEvidenceMatches(lhs.displayEvidence, rhs.displayEvidence)
            }

            classifications.append(matchingDisplayPairs ? .differentIdentifiersMatchingDisplay : .unresolvedEquivalence)
        }

        return classifications
    }

    private static func displayConflicts(_ lhs: [IdentityDisplayEvidence], _ rhs: [IdentityDisplayEvidence]) -> [String] {
        var conflicts: [String] = []
        let rhsByField = Dictionary(uniqueKeysWithValues: rhs.map { ($0.field, $0.value) })

        for value in lhs {
            if let rhsValue = rhsByField[value.field], rhsValue != value.value {
                conflicts.append(value.field)
            }
        }

        return conflicts.sorted()
    }

    private static func displayEvidenceMatches(_ lhs: [IdentityDisplayEvidence], _ rhs: [IdentityDisplayEvidence]) -> Bool {
        guard lhs.isEmpty == false, rhs.isEmpty == false else { return false }
        return Set(lhs) == Set(rhs)
    }

    private static func allPairs(_ evidence: [StableIdentityEvidence]) -> [(StableIdentityEvidence, StableIdentityEvidence)] {
        guard evidence.count > 1 else { return [] }

        var pairs: [(StableIdentityEvidence, StableIdentityEvidence)] = []
        for lhsIndex in evidence.indices {
            for rhsIndex in evidence.index(after: lhsIndex)..<evidence.endIndex {
                pairs.append((evidence[lhsIndex], evidence[rhsIndex]))
            }
        }
        return pairs
    }
}

enum BaseballOrderKind: String, Hashable, Sendable {
    case eventSequence
    case lineupSlot
    case battingOrder
    case pitcherAppearance
    case substitution
    case sourceFile
    case persistenceFetch
    case displaySort
}

struct OrderEvidence: Hashable, Sendable {
    let kind: BaseballOrderKind
    let value: Int?
    let sourceIndex: Int?

    init(kind: BaseballOrderKind, value: Int?, sourceIndex: Int? = nil) {
        self.kind = kind
        self.value = value
        self.sourceIndex = sourceIndex
    }
}

enum OrderingClassification: Hashable, Sendable {
    case ordered
    case missingOrder
    case duplicateOrderValue(Int)
    case conflictingOrderEvidence
    case ambiguousOrder
}

enum EvidenceOrderingComparison: Hashable, Sendable {
    case orderedBefore
    case orderedAfter
    case samePosition
    case missingEvidence
    case ambiguous
    case incomparableOrderKinds
}

enum StableOrderingClassifier {
    static func classify(_ evidence: [OrderEvidence], expectedKind: BaseballOrderKind) -> OrderingClassification {
        let matchingEvidence = evidence.filter { $0.kind == expectedKind }
        guard matchingEvidence.isEmpty == false else { return .missingOrder }
        guard matchingEvidence.allSatisfy({ $0.value != nil }) else { return .missingOrder }

        let values = matchingEvidence.compactMap(\.value)
        let duplicateValue = values.first { value in values.filter { $0 == value }.count > 1 }
        if let duplicateValue {
            return .duplicateOrderValue(duplicateValue)
        }

        let sortedValues = values.sorted()
        return values == sortedValues ? .ordered : .conflictingOrderEvidence
    }

    static func compare(_ lhs: OrderEvidence, _ rhs: OrderEvidence) -> EvidenceOrderingComparison {
        guard lhs.kind == rhs.kind else { return .incomparableOrderKinds }
        guard let lhsValue = lhs.value, let rhsValue = rhs.value else { return .missingEvidence }

        if lhsValue < rhsValue { return .orderedBefore }
        if lhsValue > rhsValue { return .orderedAfter }

        if lhs.sourceIndex == rhs.sourceIndex {
            return .samePosition
        }

        return .ambiguous
    }
}

struct OrderedSubstitutionEvidence: Hashable, Sendable {
    let incomingIdentifier: ImportedIdentifierEvidence?
    let outgoingIdentifier: ImportedIdentifierEvidence?
    let order: OrderEvidence?
    let battingSlot: Int?
    let role: String?
    let timingDescription: String?
}

enum SubstitutionEvidenceClassification: Hashable, Sendable {
    case completeOrderedEvidence
    case ambiguousParallelArrays
    case incompleteEvidence
    case contradictoryEvidence
}

enum SubstitutionEvidenceClassifier {
    static func classifyKnownPair(_ evidence: OrderedSubstitutionEvidence) -> SubstitutionEvidenceClassification {
        guard evidence.incomingIdentifier != nil, evidence.outgoingIdentifier != nil else {
            return .incompleteEvidence
        }

        guard evidence.order != nil, evidence.timingDescription != nil || evidence.battingSlot != nil || evidence.role != nil else {
            return .incompleteEvidence
        }

        return .completeOrderedEvidence
    }

    static func classifyParallelArrays(incomingCount: Int, outgoingCount: Int, hasTimingOrRoleEvidence: Bool) -> SubstitutionEvidenceClassification {
        guard incomingCount == outgoingCount else { return .contradictoryEvidence }
        guard incomingCount > 0 else { return .incompleteEvidence }
        return hasTimingOrRoleEvidence ? .completeOrderedEvidence : .ambiguousParallelArrays
    }
}

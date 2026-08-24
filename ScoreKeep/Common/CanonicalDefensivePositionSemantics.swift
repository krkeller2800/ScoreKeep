import Foundation

/// Non-routed Phase 1 foundation for defensive-position and pitcher-participation evidence.
/// These values classify evidence only and do not validate defensive legality.
enum CanonicalDefensivePosition: String, CaseIterable, Hashable, Sendable {
    case pitcher
    case startingPitcher
    case reliefPitcher
    case catcher
    case firstBase
    case secondBase
    case shortstop
    case thirdBase
    case leftField
    case centerField
    case rightField
    case designatedHitter

    var displayValue: String {
        switch self {
        case .pitcher:
            return "P"
        case .startingPitcher:
            return "Starting Pitcher"
        case .reliefPitcher:
            return "Relief Pitcher"
        case .catcher:
            return "Catcher"
        case .firstBase:
            return "First Baseman"
        case .secondBase:
            return "Second Baseman"
        case .shortstop:
            return "Shortstop"
        case .thirdBase:
            return "Third Baseman"
        case .leftField:
            return "Left Fielder"
        case .centerField:
            return "Center Fielder"
        case .rightField:
            return "Right Fielder"
        case .designatedHitter:
            return "Designated Hitter"
        }
    }

    var abbreviations: Set<String> {
        switch self {
        case .pitcher:
            return ["P"]
        case .startingPitcher:
            return ["SP"]
        case .reliefPitcher:
            return ["RP"]
        case .catcher:
            return ["C"]
        case .firstBase:
            return ["1B"]
        case .secondBase:
            return ["2B"]
        case .shortstop:
            return ["SS"]
        case .thirdBase:
            return ["3B"]
        case .leftField:
            return ["LF"]
        case .centerField:
            return ["CF"]
        case .rightField:
            return ["RF"]
        case .designatedHitter:
            return ["DH"]
        }
    }

    var isPitcherRole: Bool {
        switch self {
        case .pitcher, .startingPitcher, .reliefPitcher:
            return true
        default:
            return false
        }
    }

    static func recognized(rawValue: String) -> CanonicalDefensivePosition? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercased = trimmed.uppercased()
        return allCases.first { position in
            position.displayValue.caseInsensitiveCompare(trimmed) == .orderedSame || position.abbreviations.contains(uppercased)
        }
    }

    static func normalizedDisplayValue(for rawValue: String) -> String {
        recognized(rawValue: rawValue)?.displayValue ?? rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isPitcherRole(_ rawValue: String) -> Bool {
        recognized(rawValue: rawValue)?.isPitcherRole == true
    }
}

enum DefensivePositionEvidenceSource: String, Hashable, Sendable {
    case currentPlayerRecord
    case currentRosterMembership
    case lineupEntry
    case pitcherRecord
    case importedRoster
    case importedGame
    case compatibilityTransport
    case historicalGameParticipation
    case syntheticVerification
    case unknown
}

enum DefensivePositionEvidence: Hashable, Sendable {
    case recognized(CanonicalDefensivePosition, rawValue: String?, displayValue: String?)
    case blank(rawValue: String)
    case missing
    case unknownRawText(String)
    case unsupportedRawText(String)
    case rawImported(String)
    case conflicting([DefensivePositionEvidence])
    case historical(CanonicalDefensivePosition, rawValue: String?)
    case participantWithoutPosition
    case unresolvedLineupParticipant(rawValue: String?)

    init(rawValue: String?, source: DefensivePositionEvidenceSource = .unknown, participantResolved: Bool = true) {
        guard let rawValue else {
            self = participantResolved ? .missing : .unresolvedLineupParticipant(rawValue: nil)
            return
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            self = .blank(rawValue: rawValue)
            return
        }

        if trimmed == "??" {
            self = .unknownRawText(trimmed)
            return
        }

        if let position = CanonicalDefensivePosition.recognized(rawValue: trimmed) {
            switch source {
            case .historicalGameParticipation:
                self = .historical(position, rawValue: rawValue)
            case .importedRoster, .importedGame, .compatibilityTransport:
                self = .recognized(position, rawValue: rawValue, displayValue: position.displayValue)
            default:
                self = .recognized(position, rawValue: rawValue, displayValue: position.displayValue)
            }
            return
        }

        self = source == .compatibilityTransport || source == .importedRoster || source == .importedGame
            ? .rawImported(trimmed)
            : .unsupportedRawText(trimmed)
    }

    var canonicalPosition: CanonicalDefensivePosition? {
        switch self {
        case let .recognized(position, _, _), let .historical(position, _):
            return position
        default:
            return nil
        }
    }

    var displayValue: String? {
        switch self {
        case let .recognized(_, _, displayValue):
            return displayValue
        case let .historical(position, _):
            return position.displayValue
        default:
            return nil
        }
    }
}

enum CanonicalPitcherParticipationEvidence: Hashable, Sendable {
    case none
    case recognizedPitcherPosition(CanonicalDefensivePosition)
    case pitcherOnly(PlayerPitcherAppearanceEvidence?)
    case batterAndPitcher
    case unknownPitcherRelationship
    case pitcherRecord(PlayerPitcherAppearanceEvidence)
}

struct CanonicalDefensiveParticipationEvidence: Hashable, Sendable {
    let gameIdentity: ImportedIdentifierEvidence?
    let participant: LineupParticipantEvidence?
    let reusablePlayerIdentity: ImportedIdentifierEvidence
    let positionEvidence: DefensivePositionEvidence
    let pitcherEvidence: CanonicalPitcherParticipationEvidence
    let displayValue: String?
    let source: DefensivePositionEvidenceSource

    init(
        gameIdentity: ImportedIdentifierEvidence? = nil,
        participant: LineupParticipantEvidence? = nil,
        reusablePlayerIdentity: ImportedIdentifierEvidence = .missing,
        positionEvidence: DefensivePositionEvidence,
        pitcherEvidence: CanonicalPitcherParticipationEvidence = .none,
        displayValue: String? = nil,
        source: DefensivePositionEvidenceSource = .unknown
    ) {
        self.gameIdentity = gameIdentity
        self.participant = participant
        self.reusablePlayerIdentity = reusablePlayerIdentity
        self.positionEvidence = positionEvidence
        self.pitcherEvidence = pitcherEvidence
        self.displayValue = displayValue
        self.source = source
    }

    init(lineupEntry: LineupEntryEvidence, gameIdentity: ImportedIdentifierEvidence) {
        let rawPosition: String?
        switch lineupEntry.rawPosition {
        case let .present(value), let .unknown(value):
            rawPosition = value
        case let .conflicting(values):
            let conflicts = values.map { DefensivePositionEvidence(rawValue: $0, source: .lineupEntry) }
            self.init(
                gameIdentity: gameIdentity,
                participant: lineupEntry.participant,
                reusablePlayerIdentity: lineupEntry.participant.playerIdentity,
                positionEvidence: .conflicting(conflicts),
                pitcherEvidence: CanonicalDefensiveParticipationEvidence.pitcherEvidence(from: lineupEntry),
                displayValue: nil,
                source: .lineupEntry
            )
            return
        case .blank:
            rawPosition = ""
        case .missing:
            rawPosition = nil
        }

        self.init(
            gameIdentity: gameIdentity,
            participant: lineupEntry.participant,
            reusablePlayerIdentity: lineupEntry.participant.playerIdentity,
            positionEvidence: DefensivePositionEvidence(
                rawValue: rawPosition,
                source: lineupEntry.source == .historicalGameParticipation ? .historicalGameParticipation : .lineupEntry,
                participantResolved: lineupEntry.participant.playerIdentity.validIdentifier != nil
            ),
            pitcherEvidence: CanonicalDefensiveParticipationEvidence.pitcherEvidence(from: lineupEntry),
            displayValue: rawPosition,
            source: .lineupEntry
        )
    }

    private static func pitcherEvidence(from entry: LineupEntryEvidence) -> CanonicalPitcherParticipationEvidence {
        switch entry.pitcherRole {
        case .notRepresented:
            if entry.participant.playerIdentity.validIdentifier == nil { return .unknownPitcherRelationship }
            return .none
        case .pitcherCandidate:
            return .recognizedPitcherPosition(.pitcher)
        case .pitcherOnly:
            return .pitcherOnly(nil)
        case .unknown:
            return .unknownPitcherRelationship
        case .conflicting:
            return .unknownPitcherRelationship
        }
    }
}

enum CanonicalDefensivePositionClassification: Hashable, Sendable {
    case recognizedPosition(CanonicalDefensivePosition)
    case blankPosition
    case missingPosition
    case unknownRawText(String)
    case unsupportedRawText(String)
    case rawImportedPosition(String)
    case conflictingPositionEvidence
    case historicalPositionEvidence
    case pitcherOnlyParticipation
    case recognizedPitcherPosition
    case batterAndPitcherParticipation
    case unknownPitcherRelationship
    case participantWithoutDefensivePosition
    case unresolvedLineupParticipant
    case displayValueSeparate
    case identityUnaffected
    case rosterMembershipUnaffected
    case battingSlotUnaffected
}

enum CanonicalDefensivePositionClassifier {
    static func classify(_ evidence: CanonicalDefensiveParticipationEvidence) -> Set<CanonicalDefensivePositionClassification> {
        var classifications: Set<CanonicalDefensivePositionClassification> = [
            .identityUnaffected,
            .rosterMembershipUnaffected,
            .battingSlotUnaffected
        ]

        switch evidence.positionEvidence {
        case let .recognized(position, _, displayValue):
            classifications.insert(.recognizedPosition(position))
            if displayValue != nil { classifications.insert(.displayValueSeparate) }
        case .blank:
            classifications.insert(.blankPosition)
            classifications.insert(.participantWithoutDefensivePosition)
        case .missing:
            classifications.insert(.missingPosition)
            classifications.insert(.participantWithoutDefensivePosition)
        case let .unknownRawText(value):
            classifications.insert(.unknownRawText(value))
        case let .unsupportedRawText(value):
            classifications.insert(.unsupportedRawText(value))
        case let .rawImported(value):
            classifications.insert(.rawImportedPosition(value))
        case .conflicting:
            classifications.insert(.conflictingPositionEvidence)
        case let .historical(position, _):
            classifications.insert(.recognizedPosition(position))
            classifications.insert(.historicalPositionEvidence)
            classifications.insert(.displayValueSeparate)
        case .participantWithoutPosition:
            classifications.insert(.participantWithoutDefensivePosition)
        case .unresolvedLineupParticipant:
            classifications.insert(.unresolvedLineupParticipant)
        }

        switch evidence.pitcherEvidence {
        case .none:
            break
        case let .recognizedPitcherPosition(position):
            classifications.insert(.recognizedPosition(position))
            classifications.insert(.recognizedPitcherPosition)
        case .pitcherOnly:
            classifications.insert(.pitcherOnlyParticipation)
        case .batterAndPitcher:
            classifications.insert(.batterAndPitcherParticipation)
        case .unknownPitcherRelationship:
            classifications.insert(.unknownPitcherRelationship)
        case .pitcherRecord:
            classifications.insert(.recognizedPitcherPosition)
        }

        if evidence.displayValue != evidence.positionEvidence.displayValue && evidence.displayValue != nil {
            classifications.insert(.displayValueSeparate)
        }

        return classifications
    }
}

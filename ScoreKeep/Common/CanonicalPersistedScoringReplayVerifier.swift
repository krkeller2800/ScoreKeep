import Foundation
import SwiftData

enum CanonicalPersistedScoringReplayClassification: String, Hashable, Sendable {
    case completeCanonicalHistory
    case noCanonicalHistory
    case incompleteCanonicalHistory
    case unsupportedFutureVersion
    case missingEnvelope
    case missingPayload
    case missingOperationEvidence
    case duplicateEventIdentity
    case duplicateOperationIdentity
    case sequenceGap
    case sequenceCollision
    case wrongGameOwnership
    case missingCorrectionTarget
    case crossGameSupersession
    case selfSupersession
    case circularSupersession
    case branchingSupersessionConflict
    case fingerprintMismatch
    case invalidPayload
    case unsupportedCanonicalSchemaState
    case persistenceReadFailure

    var succeeded: Bool { self == .completeCanonicalHistory || self == .noCanonicalHistory }
}

enum CanonicalPersistedScoringReplayEntryStatus: String, Hashable, Sendable {
    case originalActive
    case originalSuperseded
    case correctionReplacementActive
    case correctionReplacementAuditOnly
}

struct CanonicalPersistedScoringPayloadFacts: Hashable, Sendable {
    let eventFamily: String
    let payloadVersion: Int
    let scoringSemanticsVersion: Int
    let result: String
    let teamSide: String
    let batterIdentity: UUID?
    let runnerIdentities: [UUID]
    let outsRecorded: Int?
    let runsScored: Int?
    let rbi: Int?
    let ambiguityCodes: [String]
    let unsupportedRawEvidence: [String]
}

struct CanonicalPersistedScoringReplayEntry: Hashable, Sendable {
    let eventIdentity: UUID
    let operationIdentity: UUID
    let commitSequence: Int
    let replaySequence: Int
    let payloadIdentity: UUID
    let payloadFingerprint: String
    let eventFamily: String
    let payloadFacts: CanonicalPersistedScoringPayloadFacts
    let status: CanonicalPersistedScoringReplayEntryStatus
    let correctionIdentity: UUID?
    let supersedesEventIdentity: UUID?
    let supersededByEventIdentity: UUID?
}

struct CanonicalPersistedScoringCorrectionLink: Hashable, Sendable {
    let correctionIdentity: UUID
    let correctionOperationIdentity: UUID
    let originalEventIdentity: UUID
    let replacementEventIdentity: UUID
    let originalCommitSequence: Int
    let replacementCommitSequence: Int
}

struct CanonicalPersistedScoringReplayResult: Hashable, Sendable {
    let gameIdentity: UUID
    let historyIdentity: UUID?
    let classification: CanonicalPersistedScoringReplayClassification
    let diagnosticCodes: [String]
    let auditEntries: [CanonicalPersistedScoringReplayEntry]
    let effectiveEntries: [CanonicalPersistedScoringReplayEntry]
    let correctionLinks: [CanonicalPersistedScoringCorrectionLink]
    let routingRemainsDisabled: Bool
    let managedObjectsEscaped: Bool
    let replayPerformedWrites: Bool
}

@MainActor
struct CanonicalPersistedScoringReplayVerifier {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func replay(gameIdentity: UUID) -> CanonicalPersistedScoringReplayResult {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return Self.replay(gameIdentity: gameIdentity, in: context)
    }

    static func replay(gameIdentity: UUID, in context: ModelContext) -> CanonicalPersistedScoringReplayResult {
        context.autosaveEnabled = false
        do {
            return try load(gameIdentity: gameIdentity, in: context)
        } catch let failure as ReplayFailure {
            return failed(gameIdentity: gameIdentity, historyIdentity: failure.historyIdentity, classification: failure.classification, code: failure.code)
        } catch {
            return failed(gameIdentity: gameIdentity, historyIdentity: nil, classification: .persistenceReadFailure, code: "persistedReplay.read.failed")
        }
    }

    private static func load(gameIdentity: UUID, in context: ModelContext) throws -> CanonicalPersistedScoringReplayResult {
        let games = try context.fetch(FetchDescriptor<Game>(predicate: #Predicate { $0.ident == gameIdentity }))
        guard games.count <= 1 else {
            throw ReplayFailure(nil, .wrongGameOwnership, "persistedReplay.game.duplicateIdentity")
        }
        let histories = try context.fetch(FetchDescriptor<CanonicalGameHistoryRecord>(predicate: #Predicate { $0.gameIdentity == gameIdentity }))
        guard histories.count <= 1 else {
            throw ReplayFailure(nil, .wrongGameOwnership, "persistedReplay.history.duplicateGameIdentity")
        }
        guard let history = histories.first else {
            return CanonicalPersistedScoringReplayResult(
                gameIdentity: gameIdentity,
                historyIdentity: nil,
                classification: .noCanonicalHistory,
                diagnosticCodes: ["persistedReplay.history.absent"],
                auditEntries: [],
                effectiveEntries: [],
                correctionLinks: [],
                routingRemainsDisabled: true,
                managedObjectsEscaped: false,
                replayPerformedWrites: false
            )
        }
        guard history.historyFormatVersion == 1, history.evidenceSchemaVersion == 1 else {
            throw ReplayFailure(history.historyIdentity, .unsupportedFutureVersion, "persistedReplay.history.unsupportedVersion")
        }
        guard let game = history.game, game.ident == gameIdentity else {
            throw ReplayFailure(history.historyIdentity, .wrongGameOwnership, "persistedReplay.history.gameRelationshipMismatch")
        }

        let historyIdentity = history.historyIdentity
        let events = try context.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>(
            predicate: #Predicate { $0.historyIdentity == historyIdentity && $0.gameIdentity == gameIdentity },
            sortBy: [SortDescriptor(\.commitSequence), SortDescriptor(\.eventIdentity)]
        ))
        let scopedOperations = try context.fetch(FetchDescriptor<CanonicalScoringOperationEvidenceRecord>(
            predicate: #Predicate { $0.gameIdentity == gameIdentity }
        )).filter { $0.history?.historyIdentity == historyIdentity }
        let scopedCorrections = try context.fetch(FetchDescriptor<CanonicalScoringCorrectionRecord>(
            predicate: #Predicate { $0.gameIdentity == gameIdentity }
        )).filter { $0.history?.historyIdentity == historyIdentity }
        let payloads = try context.fetch(FetchDescriptor<CanonicalScoringEventPayloadRecord>()).filter { payload in
            events.contains { $0.eventIdentity == payload.eventIdentity }
        }
        let allEvents = try context.fetch(FetchDescriptor<CanonicalScoringEventEnvelopeRecord>())

        guard events.count == Set(events.map(\.eventIdentity)).count else {
            throw ReplayFailure(history.historyIdentity, .duplicateEventIdentity, "persistedReplay.event.duplicateIdentity")
        }
        guard scopedOperations.count == Set(scopedOperations.map(\.operationIdentity)).count else {
            throw ReplayFailure(history.historyIdentity, .duplicateOperationIdentity, "persistedReplay.operation.duplicateIdentity")
        }
        try validateSequence(events, history: history)

        let operationsByEvent = Dictionary(grouping: scopedOperations.filter { $0.disposition == CanonicalScoringPersistenceConstants.operationAcceptedDisposition }, by: { $0.acceptedEventIdentity })
        let payloadsByEvent = Dictionary(grouping: payloads, by: \.eventIdentity)
        let eventsByIdentity = Dictionary(uniqueKeysWithValues: events.map { ($0.eventIdentity, $0) })
        let operationsByIdentity = Dictionary(uniqueKeysWithValues: scopedOperations.map { ($0.operationIdentity, $0) })
        let allEventsByIdentity = Dictionary(grouping: allEvents, by: \.eventIdentity)

        var decoded: [UUID: (CanonicalScoringEventPayloadRecord, CanonicalScoringPayloadValue)] = [:]
        for event in events {
            guard event.envelopeVersion == 1, event.evidenceSchemaVersion == 1 else {
                throw ReplayFailure(history.historyIdentity, .unsupportedFutureVersion, "persistedReplay.event.unsupportedVersion")
            }
            guard let matches = operationsByEvent[Optional(event.eventIdentity)], matches.count == 1, let operation = matches.first else {
                throw ReplayFailure(history.historyIdentity, .missingOperationEvidence, "persistedReplay.operation.missingForEvent")
            }
            guard operation.operationIdentity == event.originatingOperationIdentity,
                  operation.gameIdentity == gameIdentity,
                  operation.commitSequence == event.commitSequence else {
                throw ReplayFailure(history.historyIdentity, .wrongGameOwnership, "persistedReplay.operation.eventMismatch")
            }
            guard let matchingPayloads = payloadsByEvent[event.eventIdentity], matchingPayloads.count == 1, let payload = matchingPayloads.first else {
                throw ReplayFailure(history.historyIdentity, .missingPayload, "persistedReplay.payload.missingForEvent")
            }
            guard payload.payloadVersion == CanonicalScoringPayloadCoding.supportedPayloadVersion,
                  payload.scoringSemanticsVersion == CanonicalScoringPayloadCoding.supportedPayloadVersion else {
                throw ReplayFailure(history.historyIdentity, .unsupportedFutureVersion, "persistedReplay.payload.unsupportedVersion")
            }
            guard payload.eventFamily == event.eventFamily else {
                throw ReplayFailure(history.historyIdentity, .invalidPayload, "persistedReplay.payload.familyMismatch")
            }
            guard CanonicalScoringPayloadCoding.fingerprint(payload.encodedPayload) == payload.payloadFingerprint else {
                throw ReplayFailure(history.historyIdentity, .fingerprintMismatch, "persistedReplay.payload.fingerprintMismatch")
            }
            let value: CanonicalScoringPayloadValue
            do {
                value = try CanonicalScoringPayloadCoding.decode(payload.encodedPayload)
            } catch CanonicalScoringPayloadCodingError.unsupportedPayloadVersion {
                throw ReplayFailure(history.historyIdentity, .unsupportedFutureVersion, "persistedReplay.payload.futureVersion")
            } catch {
                throw ReplayFailure(history.historyIdentity, .invalidPayload, "persistedReplay.payload.decodeFailed")
            }
            guard value.eventIdentity == event.eventIdentity,
                  value.gameIdentity == gameIdentity,
                  value.eventFamily == event.eventFamily else {
                throw ReplayFailure(history.historyIdentity, .invalidPayload, "persistedReplay.payload.identityMismatch")
            }
            decoded[event.eventIdentity] = (payload, value)
        }

        let correctionLinks = try validateCorrections(
            scopedCorrections,
            eventsByIdentity: eventsByIdentity,
            allEventsByIdentity: allEventsByIdentity,
            operationsByIdentity: operationsByIdentity,
            historyIdentity: history.historyIdentity,
            gameIdentity: gameIdentity
        )
        let replacementToOriginal = Dictionary(uniqueKeysWithValues: correctionLinks.map { ($0.replacementEventIdentity, $0.originalEventIdentity) })
        let originalToReplacement = Dictionary(uniqueKeysWithValues: correctionLinks.map { ($0.originalEventIdentity, $0.replacementEventIdentity) })
        let correctionByOriginal = Dictionary(uniqueKeysWithValues: correctionLinks.map { ($0.originalEventIdentity, $0.correctionIdentity) })

        let auditEntries = try events.map { event -> CanonicalPersistedScoringReplayEntry in
            let operation = try requireOperation(for: event, operationsByEvent: operationsByEvent, historyIdentity: history.historyIdentity)
            let (payload, value) = try requireDecoded(event.eventIdentity, decoded: decoded, historyIdentity: history.historyIdentity)
            let status: CanonicalPersistedScoringReplayEntryStatus
            if replacementToOriginal[event.eventIdentity] != nil {
                status = .correctionReplacementAuditOnly
            } else if originalToReplacement[event.eventIdentity] != nil {
                status = .originalSuperseded
            } else {
                status = .originalActive
            }
            return entry(event: event, operation: operation, payload: payload, value: value, status: status, replaySequence: event.commitSequence, correctionIdentity: correctionByOriginal[event.eventIdentity], supersedes: replacementToOriginal[event.eventIdentity], supersededBy: originalToReplacement[event.eventIdentity])
        }

        let effectiveEntries = try events.compactMap { event -> CanonicalPersistedScoringReplayEntry? in
            if replacementToOriginal[event.eventIdentity] != nil { return nil }
            let effectiveEvent = originalToReplacement[event.eventIdentity].flatMap { eventsByIdentity[$0] } ?? event
            let operation = try requireOperation(for: effectiveEvent, operationsByEvent: operationsByEvent, historyIdentity: history.historyIdentity)
            let (payload, value) = try requireDecoded(effectiveEvent.eventIdentity, decoded: decoded, historyIdentity: history.historyIdentity)
            let status: CanonicalPersistedScoringReplayEntryStatus = effectiveEvent.eventIdentity == event.eventIdentity ? .originalActive : .correctionReplacementActive
            return entry(event: effectiveEvent, operation: operation, payload: payload, value: value, status: status, replaySequence: event.commitSequence, correctionIdentity: correctionByOriginal[event.eventIdentity], supersedes: replacementToOriginal[effectiveEvent.eventIdentity], supersededBy: originalToReplacement[event.eventIdentity])
        }.sorted { lhs, rhs in
            lhs.replaySequence == rhs.replaySequence ? lhs.eventIdentity.uuidString < rhs.eventIdentity.uuidString : lhs.replaySequence < rhs.replaySequence
        }

        return CanonicalPersistedScoringReplayResult(
            gameIdentity: gameIdentity,
            historyIdentity: history.historyIdentity,
            classification: .completeCanonicalHistory,
            diagnosticCodes: [],
            auditEntries: auditEntries,
            effectiveEntries: effectiveEntries,
            correctionLinks: correctionLinks.sorted { $0.originalCommitSequence < $1.originalCommitSequence },
            routingRemainsDisabled: true,
            managedObjectsEscaped: false,
            replayPerformedWrites: context.hasChanges
        )
    }

    private static func validateSequence(_ events: [CanonicalScoringEventEnvelopeRecord], history: CanonicalGameHistoryRecord) throws {
        let sequences = events.map(\.commitSequence)
        guard sequences.count == Set(sequences).count else {
            throw ReplayFailure(history.historyIdentity, .sequenceCollision, "persistedReplay.sequence.collision")
        }
        guard sequences == Array(1...events.count) else {
            throw ReplayFailure(history.historyIdentity, .sequenceGap, "persistedReplay.sequence.gap")
        }
        guard history.lastCommittedSequence == events.count else {
            throw ReplayFailure(history.historyIdentity, .sequenceGap, "persistedReplay.history.lastSequenceMismatch")
        }
    }

    private static func validateCorrections(
        _ corrections: [CanonicalScoringCorrectionRecord],
        eventsByIdentity: [UUID: CanonicalScoringEventEnvelopeRecord],
        allEventsByIdentity: [UUID: [CanonicalScoringEventEnvelopeRecord]],
        operationsByIdentity: [UUID: CanonicalScoringOperationEvidenceRecord],
        historyIdentity: UUID,
        gameIdentity: UUID
    ) throws -> [CanonicalPersistedScoringCorrectionLink] {
        var originalTargets: Set<UUID> = []
        var links: [CanonicalPersistedScoringCorrectionLink] = []
        for correction in corrections where correction.disposition == CanonicalScoringPersistenceConstants.correctionAcceptedDisposition {
            guard correction.evidenceSchemaVersion == 1 else {
                throw ReplayFailure(historyIdentity, .unsupportedFutureVersion, "persistedReplay.correction.unsupportedVersion")
            }
            guard correction.correctionOperationShape == CanonicalScoringPersistenceConstants.correctionReplaceShape else {
                throw ReplayFailure(historyIdentity, .unsupportedCanonicalSchemaState, "persistedReplay.correction.unsupportedShape")
            }
            guard originalTargets.insert(correction.originalEventIdentity).inserted else {
                throw ReplayFailure(historyIdentity, .branchingSupersessionConflict, "persistedReplay.correction.branchingSupersession")
            }
            guard let replacementEventIdentity = correction.replacementEventIdentity else {
                throw ReplayFailure(historyIdentity, .missingEnvelope, "persistedReplay.correction.missingReplacement")
            }
            guard correction.originalEventIdentity != replacementEventIdentity else {
                throw ReplayFailure(historyIdentity, .selfSupersession, "persistedReplay.correction.selfSupersession")
            }
            guard let original = eventsByIdentity[correction.originalEventIdentity] else {
                if allEventsByIdentity[correction.originalEventIdentity]?.contains(where: { $0.gameIdentity != gameIdentity }) == true {
                    throw ReplayFailure(historyIdentity, .crossGameSupersession, "persistedReplay.correction.crossGameOriginal")
                }
                throw ReplayFailure(historyIdentity, .missingCorrectionTarget, "persistedReplay.correction.missingOriginal")
            }
            guard let replacement = eventsByIdentity[replacementEventIdentity] else {
                if allEventsByIdentity[replacementEventIdentity]?.contains(where: { $0.gameIdentity != gameIdentity }) == true {
                    throw ReplayFailure(historyIdentity, .crossGameSupersession, "persistedReplay.correction.crossGameReplacement")
                }
                throw ReplayFailure(historyIdentity, .missingEnvelope, "persistedReplay.correction.missingReplacement")
            }
            guard let operation = operationsByIdentity[correction.correctionOperationIdentity],
                  operation.operationKind == CanonicalScoringPersistenceConstants.operationCorrectionKind,
                  operation.disposition == CanonicalScoringPersistenceConstants.operationAcceptedDisposition,
                  operation.correctionIdentity == correction.correctionIdentity,
                  operation.targetEventIdentity == correction.originalEventIdentity,
                  operation.replacementEventIdentity == replacementEventIdentity else {
                throw ReplayFailure(historyIdentity, .missingOperationEvidence, "persistedReplay.correction.operationMismatch")
            }
            links.append(CanonicalPersistedScoringCorrectionLink(
                correctionIdentity: correction.correctionIdentity,
                correctionOperationIdentity: correction.correctionOperationIdentity,
                originalEventIdentity: correction.originalEventIdentity,
                replacementEventIdentity: replacementEventIdentity,
                originalCommitSequence: original.commitSequence,
                replacementCommitSequence: replacement.commitSequence
            ))
        }
        try validateAcyclic(links, historyIdentity: historyIdentity)
        guard links.allSatisfy({ $0.replacementCommitSequence > $0.originalCommitSequence && $0.originalCommitSequence == scopedEarliestReplaySequence(for: $0, in: corrections) }) else {
            throw ReplayFailure(historyIdentity, .sequenceGap, "persistedReplay.correction.orderingInvalid")
        }
        return links
    }

    private static func scopedEarliestReplaySequence(
        for link: CanonicalPersistedScoringCorrectionLink,
        in corrections: [CanonicalScoringCorrectionRecord]
    ) -> Int {
        corrections.first { $0.correctionIdentity == link.correctionIdentity }?.earliestReplaySequence ?? -1
    }

    private static func validateAcyclic(_ links: [CanonicalPersistedScoringCorrectionLink], historyIdentity: UUID) throws {
        let graph = Dictionary(uniqueKeysWithValues: links.map { ($0.originalEventIdentity, $0.replacementEventIdentity) })
        for start in graph.keys {
            var seen: Set<UUID> = []
            var current: UUID? = start
            while let event = current, let next = graph[event] {
                guard seen.insert(event).inserted else {
                    throw ReplayFailure(historyIdentity, .circularSupersession, "persistedReplay.correction.circularSupersession")
                }
                current = next
            }
        }
    }

    private static func requireOperation(
        for event: CanonicalScoringEventEnvelopeRecord,
        operationsByEvent: [UUID?: [CanonicalScoringOperationEvidenceRecord]],
        historyIdentity: UUID
    ) throws -> CanonicalScoringOperationEvidenceRecord {
        guard let operation = operationsByEvent[Optional(event.eventIdentity)]?.first else {
            throw ReplayFailure(historyIdentity, .missingOperationEvidence, "persistedReplay.operation.missingForEntry")
        }
        return operation
    }

    private static func requireDecoded(
        _ eventIdentity: UUID,
        decoded: [UUID: (CanonicalScoringEventPayloadRecord, CanonicalScoringPayloadValue)],
        historyIdentity: UUID
    ) throws -> (CanonicalScoringEventPayloadRecord, CanonicalScoringPayloadValue) {
        guard let value = decoded[eventIdentity] else {
            throw ReplayFailure(historyIdentity, .missingPayload, "persistedReplay.payload.missingForEntry")
        }
        return value
    }

    private static func entry(
        event: CanonicalScoringEventEnvelopeRecord,
        operation: CanonicalScoringOperationEvidenceRecord,
        payload: CanonicalScoringEventPayloadRecord,
        value: CanonicalScoringPayloadValue,
        status: CanonicalPersistedScoringReplayEntryStatus,
        replaySequence: Int,
        correctionIdentity: UUID?,
        supersedes: UUID?,
        supersededBy: UUID?
    ) -> CanonicalPersistedScoringReplayEntry {
        CanonicalPersistedScoringReplayEntry(
            eventIdentity: event.eventIdentity,
            operationIdentity: operation.operationIdentity,
            commitSequence: event.commitSequence,
            replaySequence: replaySequence,
            payloadIdentity: payload.payloadIdentity,
            payloadFingerprint: payload.payloadFingerprint,
            eventFamily: event.eventFamily,
            payloadFacts: CanonicalPersistedScoringPayloadFacts(
                eventFamily: value.eventFamily,
                payloadVersion: value.formatVersion,
                scoringSemanticsVersion: payload.scoringSemanticsVersion,
                result: value.result,
                teamSide: value.teamSide,
                batterIdentity: value.batterIdentity,
                runnerIdentities: value.runnerIdentities,
                outsRecorded: value.outsRecorded,
                runsScored: value.runsScored,
                rbi: value.rbi,
                ambiguityCodes: value.ambiguityCodes,
                unsupportedRawEvidence: value.unsupportedRawEvidence
            ),
            status: status,
            correctionIdentity: correctionIdentity,
            supersedesEventIdentity: supersedes,
            supersededByEventIdentity: supersededBy
        )
    }

    private static func failed(
        gameIdentity: UUID,
        historyIdentity: UUID?,
        classification: CanonicalPersistedScoringReplayClassification,
        code: String
    ) -> CanonicalPersistedScoringReplayResult {
        CanonicalPersistedScoringReplayResult(
            gameIdentity: gameIdentity,
            historyIdentity: historyIdentity,
            classification: classification,
            diagnosticCodes: [code],
            auditEntries: [],
            effectiveEntries: [],
            correctionLinks: [],
            routingRemainsDisabled: true,
            managedObjectsEscaped: false,
            replayPerformedWrites: false
        )
    }

    private struct ReplayFailure: Error {
        let historyIdentity: UUID?
        let classification: CanonicalPersistedScoringReplayClassification
        let code: String

        init(_ historyIdentity: UUID?, _ classification: CanonicalPersistedScoringReplayClassification, _ code: String) {
            self.historyIdentity = historyIdentity
            self.classification = classification
            self.code = code
        }
    }
}

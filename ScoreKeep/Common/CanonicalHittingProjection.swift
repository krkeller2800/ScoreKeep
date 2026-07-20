import Foundation

struct CanonicalProjectedHittingStatistics: Hashable, Sendable {
    let playerIdentity: ImportedIdentifierEvidence
    let plateAppearances: Int
    let officialAtBats: Int
    let hits: Int
    let singles: Int
    let doubles: Int
    let triples: Int
    let homeRuns: Int
    let walks: Int
    let strikeouts: Int
    let runs: Int
    let runsBattedIn: Int
    let sacrifices: Int
    let hitByPitch: Int

    var battingAverage: Double? {
        guard officialAtBats > 0 else { return nil }
        return Double(hits) / Double(officialAtBats)
    }
}

struct CanonicalHittingProjectionInput: Hashable, Sendable {
    let replayResult: CanonicalReplayResult
    let recordedEvents: [CanonicalScoringEventEvidence]
    let validationFindings: [CanonicalValidationFinding]
    let sourceLocation: String?

    init(
        replayResult: CanonicalReplayResult,
        recordedEvents: [CanonicalScoringEventEvidence],
        validationFindings: [CanonicalValidationFinding] = [],
        sourceLocation: String? = nil
    ) {
        self.replayResult = replayResult
        self.recordedEvents = recordedEvents
        self.validationFindings = validationFindings
        self.sourceLocation = sourceLocation
    }
}

struct CanonicalHittingProjectionResult: Hashable, Sendable {
    let disposition: CanonicalProjectionDisposition
    let playerStatistics: [ImportedIdentifierEvidence: CanonicalProjectedHittingStatistics]
    let diagnostics: [CanonicalProjectionDiagnostic]
    let validation: CanonicalValidationResult
    let replayMayContinue: Bool
    let futureProductionMustStop: Bool

    init(
        disposition: CanonicalProjectionDisposition,
        playerStatistics: [ImportedIdentifierEvidence: CanonicalProjectedHittingStatistics],
        diagnostics: [CanonicalProjectionDiagnostic],
        validationFindings: [CanonicalValidationFinding]
    ) {
        self.disposition = disposition
        self.playerStatistics = playerStatistics
        self.diagnostics = diagnostics
        self.validation = CanonicalValidationResult(findings: validationFindings + diagnostics.map(\.finding))
        self.replayMayContinue = disposition.replayMayContinue && validation.processingMayContinueReadOnly
        self.futureProductionMustStop = disposition.futureProductionMustStop || validation.futureWriteMustStop
    }
}

enum CanonicalHittingProjector {
    static func project(_ input: CanonicalHittingProjectionInput) -> CanonicalHittingProjectionResult {
        var diagnostics: [CanonicalProjectionDiagnostic] = []
        var statsByPlayer: [ImportedIdentifierEvidence: CanonicalProjectedHittingStatistics] = [:]
        
        var duplicateEventIdentities: Set<ImportedIdentifierEvidence> = []
        var seenIdentities: Set<ImportedIdentifierEvidence> = []
        for event in input.recordedEvents {
            if seenIdentities.contains(event.eventIdentity) {
                duplicateEventIdentities.insert(event.eventIdentity)
            }
            seenIdentities.insert(event.eventIdentity)
        }
        
        if !duplicateEventIdentities.isEmpty {
            diagnostics.append(CanonicalProjectionDiagnostic(
                "hittingProjection.duplicateEventIdentity",
                disposition: .unsupported,
                concept: .scoringEvent,
                severity: .unsupported,
                validationDisposition: .unsupported,
                summary: "Duplicate source event identities detected.",
                sourceLocation: input.sourceLocation
            ))
            return CanonicalHittingProjectionResult(
                disposition: .unsupported,
                playerStatistics: [:],
                diagnostics: diagnostics,
                validationFindings: input.validationFindings
            )
        }
        
        let eventsByIdentity = Dictionary(uniqueKeysWithValues: input.recordedEvents.map { ($0.eventIdentity, $0) })
        
        var rawStats: [ImportedIdentifierEvidence: RawStats] = [:]

        for summary in input.replayResult.eventSummaries where summary.applied {
            guard let event = eventsByIdentity[summary.eventIdentity] else {
                continue
            }
            
            if !summary.unsupportedRawClassification.isEmpty {
                diagnostics.append(CanonicalProjectionDiagnostic(
                    "hittingProjection.unsupportedEvidence",
                    disposition: .resolvedWithWarnings,
                    concept: .scoringEvent,
                    severity: .warning,
                    validationDisposition: .validWithWarnings,
                    summary: "Event contains unsupported legacy evidence.",
                    sourceLocation: input.sourceLocation
                ))
            }

            // Batting stats
            if let batterId = summary.batterIdentity, batterId.validIdentifier != nil {
                var stats = rawStats[batterId] ?? RawStats()
                let isPA = isPlateAppearance(event.resultEvidence)
                if isPA {
                    stats.pa += 1
                    if isOfficialAtBat(event.resultEvidence) {
                        stats.ab += 1
                    }
                    
                    switch event.resultEvidence {
                    case let .batterReachesBase(rawValue):
                        if rawValue == "Single" {
                            stats.hits += 1; stats.singles += 1
                        } else if rawValue == "Double" {
                            stats.hits += 1; stats.doubles += 1
                        } else if rawValue == "Triple" {
                            stats.hits += 1; stats.triples += 1
                        } else if rawValue == "Home Run" {
                            stats.hits += 1; stats.homeRuns += 1
                        } else if rawValue == "Walk" {
                            stats.walks += 1
                        } else if rawValue == "Hit By Pitch" {
                            stats.hbp += 1
                        }
                    case let .batterOut(rawValue):
                        if rawValue == "Strikeout" || rawValue == "Strikeout Looking" {
                            stats.strikeouts += 1
                        } else if rawValue == "Sacrifice Fly" || rawValue == "Sacrifice Bunt" {
                            stats.sacrifices += 1
                        }
                    default: break
                    }
                }
                rawStats[batterId] = stats
            }
            
            if let batterId = summary.batterIdentity, batterId.validIdentifier != nil {
                if case let .flag(isRBI) = event.rbiEvidence, isRBI {
                    rawStats[batterId, default: RawStats()].rbis += 1
                }
            }
            
            // Runs scored by runners
            let allAdvancements = event.runnerAdvancement + [event.batterAdvancement].compactMap { $0 } + event.participants.runners
            for advancement in allAdvancements {
                if case let .scored(runner, _) = advancement {
                    let runnerId = runner.identity
                    if runnerId.validIdentifier != nil {
                        rawStats[runnerId, default: RawStats()].runs += 1
                    }
                }
            }
        }
        
        for (id, raw) in rawStats {
            statsByPlayer[id] = CanonicalProjectedHittingStatistics(
                playerIdentity: id,
                plateAppearances: raw.pa,
                officialAtBats: raw.ab,
                hits: raw.hits,
                singles: raw.singles,
                doubles: raw.doubles,
                triples: raw.triples,
                homeRuns: raw.homeRuns,
                walks: raw.walks,
                strikeouts: raw.strikeouts,
                runs: raw.runs,
                runsBattedIn: raw.rbis,
                sacrifices: raw.sacrifices,
                hitByPitch: raw.hbp
            )
        }
        
        let finalDisposition: CanonicalProjectionDisposition = diagnostics.isEmpty ? .resolved : .resolvedWithWarnings
        return CanonicalHittingProjectionResult(
            disposition: finalDisposition,
            playerStatistics: statsByPlayer,
            diagnostics: diagnostics,
            validationFindings: input.validationFindings
        )
    }
    
    private struct RawStats {
        var pa = 0
        var ab = 0
        var hits = 0
        var singles = 0
        var doubles = 0
        var triples = 0
        var homeRuns = 0
        var walks = 0
        var strikeouts = 0
        var runs = 0
        var rbis = 0
        var sacrifices = 0
        var hbp = 0
    }
    
    private static func isPlateAppearance(_ result: ScoringEventResultEvidence) -> Bool {
        switch result {
        case .batterReachesBase, .batterOut:
            return true
        default:
            return false
        }
    }
    
    private static func isOfficialAtBat(_ result: ScoringEventResultEvidence) -> Bool {
        switch result {
        case let .batterReachesBase(rawValue):
            return rawValue != "Walk" && rawValue != "Hit By Pitch" && rawValue != "Catcher Interference"
        case let .batterOut(rawValue):
            return rawValue != "Sacrifice Fly" && rawValue != "Sacrifice Bunt"
        default:
            return false
        }
    }
}

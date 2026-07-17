import Foundation

/// Task 2.19 scoring-authority preparation vocabulary.
///
/// This file is intentionally side-effect free. It must not call canonical replay or command
/// application from production UI, open stores, save records, mutate SwiftData models, or route
/// production scoring away from Legacy.
enum CanonicalScoringProductionAuthority: String, CaseIterable, Hashable, Sendable {
    case legacy
    case canonicalPreparedDisabled
    case canonicalCandidate
    case unsupportedAction
    case ambiguousEvidence
    case recoveryRequired
    case persistenceUnavailable
    case rejected
    case unavailable
}

enum CanonicalScoringCommandFamily: String, CaseIterable, Hashable, Sendable {
    case ball
    case strike
    case foul
    case batterOut
    case batterReachesFirst
    case batterReachesLaterBase
    case runnerAdvance
    case runnerScores
    case runnerOut
    case stolenBase
    case caughtStealing
    case pickoff
    case hitByPitch
    case sacrifice
    case rbi
    case inningTransition
    case thirdOutTransition
    case pitcherChange
    case playerSubstitution
    case correction
    case scoreRecalculation
}

enum CanonicalScoringProductionRouteID: String, CaseIterable, Hashable, Sendable {
    case gameStart
    case currentBatterSelection
    case pitcherSelectionOrChange
    case ballsAndStrikes
    case batterOut
    case batterReachesBase
    case runnerAdvance
    case runnerScores
    case runnerThrownOut
    case stolenBaseOrCaughtStealing
    case pickoff
    case hitByPitch
    case sacrifice
    case rbiEvidence
    case inningTransition
    case thirdOut
    case substitution
    case correctionOrUndo
    case scoreRecalculation
    case resumeInProgressGame
    case saveAtbatHistory
    case statisticsAndReportReads
}

enum CanonicalScoringRouteMutationOwner: String, CaseIterable, Hashable, Sendable {
    case legacySwiftUIViewContext
    case legacyProjectionWriter
    case legacyPitcherWriter
    case legacySubstitutionWriter
    case legacyReadOnlyReport
    case none
}

enum CanonicalScoringSupportStatus: String, CaseIterable, Hashable, Sendable {
    case complete
    case partial
    case absent
    case ambiguous
    case unsupported
    case blocked
}

enum CanonicalScoringPersistenceMappingStatus: String, CaseIterable, Hashable, Sendable {
    case exact
    case compatibleLossy
    case ambiguous
    case unsupported
    case conflicting
}

enum CanonicalScoringParityStatus: String, CaseIterable, Hashable, Sendable {
    case match
    case explainableDifference
    case ambiguousLegacyEvidence
    case unsupportedCanonicalMapping
    case contradiction
    case mismatchRequiresReview
    case notProven
}

enum CanonicalScoringRouteEligibility: String, CaseIterable, Hashable, Sendable {
    case productionLegacyOnly
    case canonicalCandidateBlocked
    case unsupported
    case readOnly
}

enum CanonicalScoringAuthorityBlockingReason: String, CaseIterable, Hashable, Sendable {
    case productionApprovalAbsent
    case canonicalProductionRouteDisabled
    case unsupportedCommandFamily
    case ambiguousLegacyEvidence
    case persistenceUnavailable
    case recoveryRequired
    case validationIncomplete
    case replayIncomplete
    case correctionIncomplete
    case idempotencyPersistenceMissing
    case persistenceMappingIncomplete
    case legacyParityIncomplete
    case uiBoundaryIncomplete
    case oneWriterProofIncomplete
    case runnerOutThirdOutAmbiguous
    case pitcherResponsibilityAmbiguous
    case substitutionTimingAmbiguous
    case scoreRunValidityAmbiguous
    case canonicalEventPersistenceAbsent
}

struct CanonicalScoringAuthorityRequest: Hashable, Sendable {
    let routeID: CanonicalScoringProductionRouteID
    let commandFamily: CanonicalScoringCommandFamily
    let canonicalApprovalPresent: Bool
    let persistenceAvailable: Bool
    let recoveryRequired: Bool
    let hasAmbiguousEvidence: Bool
    let commandSupported: Bool
    let validationAccepted: Bool

    init(
        routeID: CanonicalScoringProductionRouteID,
        commandFamily: CanonicalScoringCommandFamily,
        canonicalApprovalPresent: Bool = false,
        persistenceAvailable: Bool = true,
        recoveryRequired: Bool = false,
        hasAmbiguousEvidence: Bool = false,
        commandSupported: Bool = true,
        validationAccepted: Bool = true
    ) {
        self.routeID = routeID
        self.commandFamily = commandFamily
        self.canonicalApprovalPresent = canonicalApprovalPresent
        self.persistenceAvailable = persistenceAvailable
        self.recoveryRequired = recoveryRequired
        self.hasAmbiguousEvidence = hasAmbiguousEvidence
        self.commandSupported = commandSupported
        self.validationAccepted = validationAccepted
    }
}

struct CanonicalScoringAuthorityDecision: Hashable, Sendable {
    let request: CanonicalScoringAuthorityRequest
    let selectedAuthority: CanonicalScoringProductionAuthority
    let productionMutationOwner: CanonicalScoringRouteMutationOwner
    let canonicalMutationPermitted: Bool
    let legacyMutationPermitted: Bool
    let routeSelectionImmutable: Bool
    let blockingReasons: Set<CanonicalScoringAuthorityBlockingReason>
    let stableDiagnosticCode: String

    var activeWriterCount: Int {
        (legacyMutationPermitted ? 1 : 0) + (canonicalMutationPermitted ? 1 : 0)
    }
}

struct CanonicalScoringRouteInventoryEntry: Hashable, Sendable {
    let routeID: CanonicalScoringProductionRouteID
    let initiatingSurface: String
    let currentAuthority: CanonicalScoringProductionAuthority
    let mutationOwner: CanonicalScoringRouteMutationOwner
    let contextSource: String
    let saveBehavior: String
    let autosaveParticipation: String
    let persistedModelsAndFields: [String]
    let orderingAssumptions: [String]
    let scoreAssumptions: [String]
    let runnerIdentityHandling: String
    let pitcherResponsibilityHandling: String
    let correctionBehavior: String
    let failureHandling: String
    let canonicalSupport: CanonicalScoringSupportStatus
    let futureRoutingEligibility: CanonicalScoringRouteEligibility
    let blockers: Set<CanonicalScoringAuthorityBlockingReason>
}

struct CanonicalScoringReadinessMatrixEntry: Hashable, Sendable {
    let family: CanonicalScoringCommandFamily
    let semantics: CanonicalScoringSupportStatus
    let validation: CanonicalScoringSupportStatus
    let replay: CanonicalScoringSupportStatus
    let correction: CanonicalScoringSupportStatus
    let idempotency: CanonicalScoringSupportStatus
    let persistenceMapping: CanonicalScoringPersistenceMappingStatus
    let legacyParity: CanonicalScoringParityStatus
    let uiBoundary: CanonicalScoringSupportStatus
    let productionRouteEligible: Bool
    let blockedReasons: Set<CanonicalScoringAuthorityBlockingReason>
}

struct CanonicalScoringOneWriterAssessment: Hashable, Sendable {
    let authoritySelectedBeforeMutation: Bool
    let routeSelectionImmutable: Bool
    let transactionOwnerCount: Int
    let modelContextCount: Int
    let legacyMutationStarted: Bool
    let canonicalMutationStarted: Bool
    let fallbackAfterCanonicalMutation: Bool
    let viewIssuedSecondSave: Bool
    let autosaveSecondaryCommit: Bool
    let managedModelsEscapeBoundary: Bool

    var exactlyOneWriter: Bool {
        let writerCount = (legacyMutationStarted ? 1 : 0) + (canonicalMutationStarted ? 1 : 0)
        return authoritySelectedBeforeMutation
            && routeSelectionImmutable
            && transactionOwnerCount == 1
            && modelContextCount <= 1
            && writerCount == 1
            && fallbackAfterCanonicalMutation == false
            && viewIssuedSecondSave == false
            && autosaveSecondaryCommit == false
            && managedModelsEscapeBoundary == false
    }

    var failClosed: Bool {
        fallbackAfterCanonicalMutation == false
            && viewIssuedSecondSave == false
            && autosaveSecondaryCommit == false
            && managedModelsEscapeBoundary == false
            && (legacyMutationStarted && canonicalMutationStarted) == false
    }
}

struct CanonicalScoringDelayedRunnerOutBoundary: Hashable, Sendable {
    let runnerStableIdentityRetained: Bool
    let originatingAtbatIdentityRetained: Bool
    let interveningAtbatOrderRetained: Bool
    let laterRunnerOutEvidenceRetained: Bool
    let thirdOutClassificationRetained: Bool
    let inningBoundaryRetained: Bool
    let activeBatterCompletionExplicit: Bool
    let nextBatterEvidencePreserved: Bool
    let scoreEvidencePreserved: Bool
    let runValidityAmbiguityExplicit: Bool
    let inventedRunValidity: Bool
    let inventedPitcherResponsibility: Bool
    let inventedSubstitutionTiming: Bool
    let inventedCompletedAtbatStatus: Bool
    let inventedNextBatter: Bool

    var permitsCanonicalProductionRoute: Bool {
        runnerStableIdentityRetained
            && originatingAtbatIdentityRetained
            && interveningAtbatOrderRetained
            && laterRunnerOutEvidenceRetained
            && thirdOutClassificationRetained
            && inningBoundaryRetained
            && activeBatterCompletionExplicit
            && nextBatterEvidencePreserved
            && scoreEvidencePreserved
            && runValidityAmbiguityExplicit
            && inventedRunValidity == false
            && inventedPitcherResponsibility == false
            && inventedSubstitutionTiming == false
            && inventedCompletedAtbatStatus == false
            && inventedNextBatter == false
    }
}

struct CanonicalScoringPersistenceMappingEntry: Hashable, Sendable {
    let modelName: String
    let mappedFields: [String]
    let status: CanonicalScoringPersistenceMappingStatus
    let blocker: String
}

struct CanonicalScoringAuthorityDiagnostics: Hashable, Sendable {
    let selectedAuthority: CanonicalScoringProductionAuthority
    let commandFamily: CanonicalScoringCommandFamily
    let readinessStatus: CanonicalScoringSupportStatus
    let validationStatus: CanonicalScoringSupportStatus
    let replayStatus: CanonicalScoringSupportStatus
    let correctionStatus: CanonicalScoringSupportStatus
    let persistenceMappingStatus: CanonicalScoringPersistenceMappingStatus
    let legacyParityStatus: CanonicalScoringParityStatus
    let stableDiagnosticCode: String

    var privacySafeFields: [String] {
        [
            selectedAuthority.rawValue,
            commandFamily.rawValue,
            readinessStatus.rawValue,
            validationStatus.rawValue,
            replayStatus.rawValue,
            correctionStatus.rawValue,
            persistenceMappingStatus.rawValue,
            legacyParityStatus.rawValue,
            stableDiagnosticCode
        ]
    }
}

enum CanonicalScoringAuthorityPolicy {
    static let productionCanonicalApprovalPresent = false

    static func select(_ request: CanonicalScoringAuthorityRequest) -> CanonicalScoringAuthorityDecision {
        var reasons: Set<CanonicalScoringAuthorityBlockingReason> = []
        if request.recoveryRequired { reasons.insert(.recoveryRequired) }
        if request.persistenceAvailable == false { reasons.insert(.persistenceUnavailable) }
        if request.commandSupported == false { reasons.insert(.unsupportedCommandFamily) }
        if request.hasAmbiguousEvidence { reasons.insert(.ambiguousLegacyEvidence) }
        if request.validationAccepted == false { reasons.insert(.validationIncomplete) }
        if request.canonicalApprovalPresent == false { reasons.insert(.productionApprovalAbsent) }
        reasons.insert(.canonicalProductionRouteDisabled)

        let selected: CanonicalScoringProductionAuthority
        if request.recoveryRequired {
            selected = .recoveryRequired
        } else if request.persistenceAvailable == false {
            selected = .persistenceUnavailable
        } else if request.commandSupported == false {
            selected = .unsupportedAction
        } else if request.hasAmbiguousEvidence {
            selected = .ambiguousEvidence
        } else if request.validationAccepted == false {
            selected = .rejected
        } else {
            selected = .legacy
        }

        let legacyAllowed = selected == .legacy
        return CanonicalScoringAuthorityDecision(
            request: request,
            selectedAuthority: selected,
            productionMutationOwner: legacyAllowed ? routeInventory[request.routeID]?.mutationOwner ?? .legacySwiftUIViewContext : .none,
            canonicalMutationPermitted: false,
            legacyMutationPermitted: legacyAllowed,
            routeSelectionImmutable: true,
            blockingReasons: reasons,
            stableDiagnosticCode: "scoring.authority.\(selected.rawValue).\(request.commandFamily.rawValue)"
        )
    }

    static func diagnostics(for decision: CanonicalScoringAuthorityDecision) -> CanonicalScoringAuthorityDiagnostics {
        let readiness = readinessMatrix[decision.request.commandFamily]
        return CanonicalScoringAuthorityDiagnostics(
            selectedAuthority: decision.selectedAuthority,
            commandFamily: decision.request.commandFamily,
            readinessStatus: readiness?.semantics ?? .absent,
            validationStatus: readiness?.validation ?? .absent,
            replayStatus: readiness?.replay ?? .absent,
            correctionStatus: readiness?.correction ?? .absent,
            persistenceMappingStatus: readiness?.persistenceMapping ?? .unsupported,
            legacyParityStatus: readiness?.legacyParity ?? .notProven,
            stableDiagnosticCode: decision.stableDiagnosticCode
        )
    }

    static let routeInventory: [CanonicalScoringProductionRouteID: CanonicalScoringRouteInventoryEntry] = Dictionary(
        uniqueKeysWithValues: routeEntries.map { ($0.routeID, $0) }
    )

    static let readinessMatrix: [CanonicalScoringCommandFamily: CanonicalScoringReadinessMatrixEntry] = Dictionary(
        uniqueKeysWithValues: readinessEntries.map { ($0.family, $0) }
    )

    static let persistenceMappings: [CanonicalScoringPersistenceMappingEntry] = [
        CanonicalScoringPersistenceMappingEntry(modelName: "Game", mappedFields: ["hscore", "vscore", "atbats", "lineups", "pitchers", "replaced", "incomings"], status: .compatibleLossy, blocker: "Stored scores and relationship arrays cannot prove every canonical scoring fact."),
        CanonicalScoringPersistenceMappingEntry(modelName: "Atbat", mappedFields: ["result", "maxbase", "outAt", "inning", "seq", "col", "rbis", "outs", "sacFly", "sacBunt", "stolenBases", "earnedRun", "playRec", "endOfInning"], status: .compatibleLossy, blocker: "Atbat can hold many Legacy facts but not canonical event supersession, operation identity, or complete runner responsibility."),
        CanonicalScoringPersistenceMappingEntry(modelName: "Lineup", mappedFields: ["players", "team", "game"], status: .ambiguous, blocker: "Lineup timing and batting-order changes are not fully represented for replay cutover."),
        CanonicalScoringPersistenceMappingEntry(modelName: "Pitcher", mappedFields: ["player", "team", "game", "start/end markers", "aggregate stats"], status: .ambiguous, blocker: "Pitcher responsibility and inherited-run evidence are not fully proven."),
        CanonicalScoringPersistenceMappingEntry(modelName: "Player", mappedFields: ["ident", "name", "number", "batOrder", "team"], status: .exact, blocker: "Display identity maps, but historical role timing still depends on Atbat and substitution evidence."),
        CanonicalScoringPersistenceMappingEntry(modelName: "Team", mappedFields: ["ident", "name", "players", "games"], status: .exact, blocker: "Team identity maps; no scoring activation blocker by itself."),
        CanonicalScoringPersistenceMappingEntry(modelName: "substitution arrays", mappedFields: ["Game.replaced", "Game.incomings"], status: .ambiguous, blocker: "Parallel arrays can lose pairing and timing meaning."),
        CanonicalScoringPersistenceMappingEntry(modelName: "stored score fields", mappedFields: ["Game.hscore", "Game.vscore", "Atbat.maxbase"], status: .compatibleLossy, blocker: "Run validity on ambiguous third-out plays cannot be invented."),
        CanonicalScoringPersistenceMappingEntry(modelName: "ordering and sequence fields", mappedFields: ["Atbat.seq", "Atbat.col", "Atbat.inning", "Atbat.batOrder"], status: .compatibleLossy, blocker: "Legacy ordering is usable for comparison but not complete canonical event identity."),
        CanonicalScoringPersistenceMappingEntry(modelName: "canonical scoring events", mappedFields: [], status: .unsupported, blocker: "No production schema field persists canonical events in this task.")
    ]

    static let delayedRunnerOutGate = CanonicalScoringDelayedRunnerOutBoundary(
        runnerStableIdentityRetained: true,
        originatingAtbatIdentityRetained: true,
        interveningAtbatOrderRetained: true,
        laterRunnerOutEvidenceRetained: true,
        thirdOutClassificationRetained: true,
        inningBoundaryRetained: true,
        activeBatterCompletionExplicit: true,
        nextBatterEvidencePreserved: true,
        scoreEvidencePreserved: true,
        runValidityAmbiguityExplicit: true,
        inventedRunValidity: false,
        inventedPitcherResponsibility: false,
        inventedSubstitutionTiming: false,
        inventedCompletedAtbatStatus: false,
        inventedNextBatter: false
    )

    private static let routeEntries: [CanonicalScoringRouteInventoryEntry] = [
        route(.gameStart, "ScoreContentView -> GameView -> EditScoreView", .legacySwiftUIViewContext, "Game creation and navigation use environment ModelContext.", "Game insert saves explicitly; scoring setup remains Legacy.", ["Game date/location/teams/scores"], [.productionApprovalAbsent]),
        route(.currentBatterSelection, "PlayersToScoreView scorecard cell button", .legacySwiftUIViewContext, "@Query Atbat list plus Game binding.", "Existing Atbat is selected or new placeholder Atbat is inserted and saved.", ["Atbat player/team/game/batOrder/col/seq/result"], [.uiBoundaryIncomplete]),
        route(.pitcherSelectionOrChange, "PitcherContentView and PitchersStaffView", .legacyPitcherWriter, "Environment ModelContext and Game/Team values.", "Pitcher insert/update/delete and marker saves are explicit or bound.", ["Pitcher player/team/game/start/end/stat fields"], [.pitcherResponsibilityAmbiguous]),
        route(.ballsAndStrikes, "No durable production count writer", .none, "UI state only where present.", "No canonical or persistent count route is active.", [], [.unsupportedCommandFamily]),
        route(.batterOut, "ScoreGameView batting-out picker", .legacySwiftUIViewContext, "Bound Atbat model.", "Picker mutates Atbat.result; disappear and projection paths save/delete.", ["Atbat.result", "Atbat.outs", "Atbat.endOfInning"], [.legacyParityIncomplete]),
        route(.batterReachesBase, "ScoreGameView on-base picker and max-base picker", .legacySwiftUIViewContext, "Bound Atbat model.", "Picker mutates result/maxbase and projection saves.", ["Atbat.result", "Atbat.maxbase", "Atbat.earnedRun"], [.legacyParityIncomplete]),
        route(.runnerAdvance, "ScoreGameView max-base picker and PlayersToScoreView max-base projection", .legacyProjectionWriter, "Bound Atbat plus queried inning at-bats.", "Max-base projection mutates prior Atbat rows and saves.", ["Atbat.maxbase"], [.runnerOutThirdOutAmbiguous]),
        route(.runnerScores, "ScoreGameView max-base Home and RBI picker", .legacySwiftUIViewContext, "Bound Atbat model.", "Home maxbase and RBI mutate Atbat; score is derived by projection/report paths.", ["Atbat.maxbase", "Atbat.rbis", "Game.hscore", "Game.vscore"], [.scoreRunValidityAmbiguous]),
        route(.runnerThrownOut, "ScoreGameView base-path out picker", .legacySwiftUIViewContext, "Bound Atbat model.", "outAt mutates Atbat and triggers inning/projection logic.", ["Atbat.outAt", "Atbat.playRec", "Atbat.outs"], [.runnerOutThirdOutAmbiguous]),
        route(.stolenBaseOrCaughtStealing, "ScoreGameView stolen-base picker and outAt evidence", .legacySwiftUIViewContext, "Bound Atbat model.", "Stolen-base count persists on Atbat; caught stealing is not distinct from generic runner out.", ["Atbat.stolenBases", "Atbat.outAt"], [.persistenceMappingIncomplete]),
        route(.pickoff, "ScoreGameView base-path out and play record", .legacySwiftUIViewContext, "Bound Atbat model.", "Pickoff has no dedicated canonical-ready production field.", ["Atbat.outAt", "Atbat.playRec"], [.unsupportedCommandFamily]),
        route(.hitByPitch, "ScoreGameView on-base picker", .legacySwiftUIViewContext, "Bound Atbat model.", "Result string stores Hit By Pitch.", ["Atbat.result", "Atbat.maxbase"], [.legacyParityIncomplete]),
        route(.sacrifice, "ScoreGameView batting-out picker and sac markers", .legacySwiftUIViewContext, "Bound Atbat model.", "Result and sac fields mutate directly.", ["Atbat.result", "Atbat.sacFly", "Atbat.sacBunt"], [.persistenceMappingIncomplete]),
        route(.rbiEvidence, "ScoreGameView RBI picker", .legacySwiftUIViewContext, "Bound Atbat model.", "Picker mutates Atbat.rbis.", ["Atbat.rbis"], [.scoreRunValidityAmbiguous]),
        route(.inningTransition, "PlayersToScoreView.seqGame and ScoreGameView.setEndOfInning", .legacyProjectionWriter, "Queried and related Atbat arrays.", "Projection mutates inning, outs, seq, col, and end markers and saves in loop.", ["Atbat.inning", "Atbat.outs", "Atbat.seq", "Atbat.col", "Atbat.endOfInning"], [.oneWriterProofIncomplete]),
        route(.thirdOut, "ScoreGameView.setEndOfInning and PlayersToScoreView.seqGame", .legacyProjectionWriter, "Atbat relationship order and result/out fields.", "Third-out marker is derived from stored events and saved.", ["Atbat.outs", "Atbat.endOfInning", "Atbat.inning"], [.runnerOutThirdOutAmbiguous]),
        route(.substitution, "ReplacementView.doSubs", .legacySubstitutionWriter, "Game, Player, Atbat relationship arrays.", "Substitution mutates players, at-bats, and parallel arrays.", ["Game.replaced", "Game.incomings", "Atbat result Pitch Hitter", "Player.batOrder"], [.substitutionTimingAmbiguous]),
        route(.correctionOrUndo, "ScoreGameView delete/reset controls", .legacySwiftUIViewContext, "Bound Atbat model and Game.atbats.", "Existing Atbat fields are reset or Atbat is deleted.", ["Atbat fields", "Game.atbats"], [.idempotencyPersistenceMissing]),
        route(.scoreRecalculation, "PlayersToScoreView.seqGame and reports", .legacyProjectionWriter, "Queried Atbat order.", "Derived totals and persisted projection fields recalculate from Legacy rows.", ["Atbat.seq", "Atbat.col", "Atbat.inning", "Atbat.outs", "Game score display"], [.legacyParityIncomplete]),
        route(.resumeInProgressGame, "ScoreContentView destinationView -> EditScoreView", .legacySwiftUIViewContext, "Persisted Game graph from active container.", "Opening a game does not canonical-replay or repair before scoring.", ["Game", "Atbat", "Lineup", "Pitcher"], [.uiBoundaryIncomplete]),
        route(.saveAtbatHistory, "PlayersToScoreView and ScoreGameView save/delete paths", .legacySwiftUIViewContext, "Environment ModelContext.", "Explicit saves, implicit bound persistence, and deletes persist Legacy Atbat history.", ["Atbat", "Game.atbats"], [.canonicalEventPersistenceAbsent]),
        route(.statisticsAndReportReads, "Report, PDF, score display, export reads", .legacyReadOnlyReport, "Persisted Legacy models.", "Read-only derived output; no canonical production writer.", ["Game", "Atbat", "Pitcher", "Player", "Team"], [.legacyParityIncomplete], canonicalSupport: .partial, eligibility: .readOnly)
    ]

    private static let readinessEntries: [CanonicalScoringReadinessMatrixEntry] = [
        readiness(.ball, .absent, .absent, .absent, .absent, .absent, .unsupported, .notProven, [.unsupportedCommandFamily]),
        readiness(.strike, .absent, .absent, .absent, .absent, .absent, .unsupported, .notProven, [.unsupportedCommandFamily]),
        readiness(.foul, .absent, .absent, .absent, .absent, .absent, .unsupported, .notProven, [.unsupportedCommandFamily]),
        readiness(.batterOut, .complete, .complete, .complete, .partial, .partial, .compatibleLossy, .notProven, [.persistenceMappingIncomplete, .legacyParityIncomplete, .uiBoundaryIncomplete]),
        readiness(.batterReachesFirst, .complete, .complete, .complete, .partial, .partial, .compatibleLossy, .notProven, [.persistenceMappingIncomplete, .legacyParityIncomplete, .uiBoundaryIncomplete]),
        readiness(.batterReachesLaterBase, .complete, .complete, .complete, .partial, .partial, .compatibleLossy, .notProven, [.persistenceMappingIncomplete, .legacyParityIncomplete, .uiBoundaryIncomplete]),
        readiness(.runnerAdvance, .partial, .partial, .partial, .partial, .partial, .compatibleLossy, .ambiguousLegacyEvidence, [.runnerOutThirdOutAmbiguous, .persistenceMappingIncomplete]),
        readiness(.runnerScores, .partial, .partial, .partial, .partial, .partial, .compatibleLossy, .ambiguousLegacyEvidence, [.scoreRunValidityAmbiguous, .persistenceMappingIncomplete]),
        readiness(.runnerOut, .partial, .partial, .partial, .partial, .partial, .ambiguous, .ambiguousLegacyEvidence, [.runnerOutThirdOutAmbiguous]),
        readiness(.stolenBase, .partial, .partial, .partial, .partial, .partial, .compatibleLossy, .notProven, [.legacyParityIncomplete, .persistenceMappingIncomplete]),
        readiness(.caughtStealing, .partial, .partial, .partial, .partial, .partial, .ambiguous, .ambiguousLegacyEvidence, [.persistenceMappingIncomplete]),
        readiness(.pickoff, .absent, .absent, .absent, .absent, .absent, .unsupported, .unsupportedCanonicalMapping, [.unsupportedCommandFamily]),
        readiness(.hitByPitch, .complete, .complete, .complete, .partial, .partial, .compatibleLossy, .notProven, [.legacyParityIncomplete, .uiBoundaryIncomplete]),
        readiness(.sacrifice, .partial, .partial, .partial, .partial, .partial, .compatibleLossy, .notProven, [.persistenceMappingIncomplete, .legacyParityIncomplete]),
        readiness(.rbi, .partial, .partial, .partial, .partial, .partial, .compatibleLossy, .ambiguousLegacyEvidence, [.scoreRunValidityAmbiguous]),
        readiness(.inningTransition, .complete, .complete, .complete, .partial, .partial, .compatibleLossy, .notProven, [.uiBoundaryIncomplete, .oneWriterProofIncomplete]),
        readiness(.thirdOutTransition, .partial, .partial, .partial, .partial, .partial, .ambiguous, .ambiguousLegacyEvidence, [.runnerOutThirdOutAmbiguous, .scoreRunValidityAmbiguous]),
        readiness(.pitcherChange, .partial, .partial, .partial, .partial, .partial, .ambiguous, .notProven, [.pitcherResponsibilityAmbiguous]),
        readiness(.playerSubstitution, .partial, .partial, .partial, .partial, .partial, .ambiguous, .ambiguousLegacyEvidence, [.substitutionTimingAmbiguous]),
        readiness(.correction, .partial, .partial, .partial, .partial, .partial, .unsupported, .notProven, [.idempotencyPersistenceMissing, .canonicalEventPersistenceAbsent]),
        readiness(.scoreRecalculation, .partial, .partial, .partial, .partial, .partial, .compatibleLossy, .notProven, [.legacyParityIncomplete, .persistenceMappingIncomplete])
    ]

    private static func route(
        _ routeID: CanonicalScoringProductionRouteID,
        _ surface: String,
        _ owner: CanonicalScoringRouteMutationOwner,
        _ context: String,
        _ save: String,
        _ fields: [String],
        _ blockers: Set<CanonicalScoringAuthorityBlockingReason>,
        canonicalSupport: CanonicalScoringSupportStatus = .partial,
        eligibility: CanonicalScoringRouteEligibility = .productionLegacyOnly
    ) -> CanonicalScoringRouteInventoryEntry {
        CanonicalScoringRouteInventoryEntry(
            routeID: routeID,
            initiatingSurface: surface,
            currentAuthority: owner == .none ? .unsupportedAction : .legacy,
            mutationOwner: owner,
            contextSource: context,
            saveBehavior: save,
            autosaveParticipation: owner == .legacyReadOnlyReport || owner == .none ? "none" : "legacy environment context may autosave bound mutations",
            persistedModelsAndFields: fields,
            orderingAssumptions: ["Atbat order uses col, seq, inning, batOrder, and relationship order depending on route."],
            scoreAssumptions: ["Scores are derived from Legacy Atbat result/maxbase/RBI/out evidence and stored Game score fields where present."],
            runnerIdentityHandling: "Legacy runner identity is inferred from Atbat.player and scorecard order; delayed runner identity is not a persisted canonical runner object.",
            pitcherResponsibilityHandling: "Pitcher responsibility remains marker and aggregate evidence through Pitcher records and Atbat earned-run flags.",
            correctionBehavior: "Corrections are direct Atbat edit/delete/reset behavior without canonical supersession persistence.",
            failureHandling: "Save failures are logged, ignored, or handled locally by Legacy views; no canonical transaction result is active.",
            canonicalSupport: canonicalSupport,
            futureRoutingEligibility: eligibility,
            blockers: blockers.union([.productionApprovalAbsent, .canonicalProductionRouteDisabled])
        )
    }

    private static func readiness(
        _ family: CanonicalScoringCommandFamily,
        _ semantics: CanonicalScoringSupportStatus,
        _ validation: CanonicalScoringSupportStatus,
        _ replay: CanonicalScoringSupportStatus,
        _ correction: CanonicalScoringSupportStatus,
        _ idempotency: CanonicalScoringSupportStatus,
        _ mapping: CanonicalScoringPersistenceMappingStatus,
        _ parity: CanonicalScoringParityStatus,
        _ blockers: Set<CanonicalScoringAuthorityBlockingReason>
    ) -> CanonicalScoringReadinessMatrixEntry {
        CanonicalScoringReadinessMatrixEntry(
            family: family,
            semantics: semantics,
            validation: validation,
            replay: replay,
            correction: correction,
            idempotency: idempotency,
            persistenceMapping: mapping,
            legacyParity: parity,
            uiBoundary: .absent,
            productionRouteEligible: false,
            blockedReasons: blockers.union([.productionApprovalAbsent, .canonicalProductionRouteDisabled])
        )
    }
}

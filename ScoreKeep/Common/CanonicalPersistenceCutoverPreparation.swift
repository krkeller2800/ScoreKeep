import Foundation

/// Non-routed task 3.19 preparation vocabulary for future persistence-authority cutover.
///
/// This file classifies routes and gates only. It must not open stores, save records,
/// delete records, switch writers, access purchases, access Keychain state, or run migration.
enum CanonicalPersistenceCutoverRouteID: String, CaseIterable, Hashable, Sendable {
    case modelContainerStartup
    case emptyStoreInitialization
    case gameCreation
    case gameEditing
    case teamCreationAndEditing
    case playerCreationAndEditing
    case rosterChanges
    case lineupChanges
    case scoringEventCreation
    case scoreAndGameStateProjectionWrites
    case correctionPersistence
    case pitcherChanges
    case substitutions
    case compatibilityImports
    case seededGameInsertion
    case mediaReplacementAndRemoval
    case gameDeletion
    case teamDeletion
    case playerDeletion
    case eventDeletion
    case reportAndExportReads
    case startupCleanupOrNormalization
    case purchaseEntitlementAndAllowance

    var isWriterRoute: Bool {
        CanonicalPersistenceCutoverRouteManifest.route(for: self).classifications.contains { classification in
            switch classification {
            case .legacyWriter, .legacyDestructiveWriter, .derivedProjectionWriter,
                 .compatibilityImportWriter, .seedWriter, .mediaWriter,
                 .deleteOrCleanupWriter, .purchaseOrAllowanceWriterOutsideBaseballPersistence:
                return true
            case .readOnly, .candidateForFirstBoundedRouting, .mustRemainLegacyUntilLater,
                 .blockedByMigration, .blockedBySchemaDecision, .blockedByUnsupportedCanonicalMeaning,
                 .blockedByMissingRollback, .blockedByMissingUserReview, .notPartOfPersistenceCutover:
                return false
            }
        }
    }
}

enum CanonicalPersistenceCutoverRouteClassification: String, CaseIterable, Hashable, Sendable {
    case readOnly
    case legacyWriter
    case legacyDestructiveWriter
    case derivedProjectionWriter
    case compatibilityImportWriter
    case seedWriter
    case mediaWriter
    case deleteOrCleanupWriter
    case purchaseOrAllowanceWriterOutsideBaseballPersistence
    case candidateForFirstBoundedRouting
    case mustRemainLegacyUntilLater
    case blockedByMigration
    case blockedBySchemaDecision
    case blockedByUnsupportedCanonicalMeaning
    case blockedByMissingRollback
    case blockedByMissingUserReview
    case notPartOfPersistenceCutover
}

enum CanonicalPersistenceWriterAuthority: String, CaseIterable, Hashable, Sendable {
    case none
    case legacySwiftData
    case proposedPersistenceAuthority
    case storeKitAndKeychain
    case generatedOutputOnly
}

enum CanonicalPersistenceCutoverGateStatus: String, CaseIterable, Hashable, Sendable {
    case notAssessed
    case satisfied
    case missing
    case failed
    case blocked
}

enum CanonicalPersistenceCutoverBlockingReason: String, CaseIterable, Hashable, Sendable {
    case schemaDecisionMissing
    case sourceVersionUnknown
    case migrationProgressDesignMissing
    case startupPolicyMissing
    case disablePathMissing
    case rollbackOrRecoveryMissing
    case userReviewPolicyMissing
    case purchaseSeparationFailed
    case allowanceBoundaryFailed
    case unsupportedMapping
    case relationshipVerificationMissing
    case orderingVerificationMissing
    case mediaBehaviorUnclassified
    case oneWriterNotProven
    case scoringCutoverDeferred
    case importTooBroad
    case deleteTooDestructive
    case migrationDesignMissing
    case legacyRetirementBlocked
    case explicitApprovalMissing
}

enum CanonicalPersistenceDisableClassification: String, CaseIterable, Hashable, Sendable {
    case notNeededForReadOnly
    case disableBeforeRoutingRequired
    case schemaIndependentDisablePossible
    case blockedUntilDesigned
}

enum CanonicalPersistenceRollbackClassification: String, CaseIterable, Hashable, Sendable {
    case notNeededForReadOnly
    case priorLegacyStorePreservationRequired
    case recoveryOnlyUntilBackupDesigned
    case blockedByPhysicalSchemaChange
    case blockedUntilDesigned
}

enum CanonicalPersistenceCutoverDisposition: String, CaseIterable, Hashable, Sendable {
    case notAssessed
    case evidenceIncomplete
    case blocked
    case preparationOnly
    case readyForIsolatedImplementation
    case readyForBoundedRouting
    case requiresSchemaDecision
    case requiresMigrationDesign
    case requiresRollbackDesign
    case requiresUserReviewDesign
    case requiresPurchaseSeparationProof
    case unsafe
    case rejected
}

struct CanonicalPersistenceCutoverRouteAssessment: Hashable, Sendable {
    let routeID: CanonicalPersistenceCutoverRouteID
    let workflow: String
    let sourceReferences: [String]
    let recordsRead: [String]
    let recordsInserted: [String]
    let recordsUpdated: [String]
    let recordsDeleted: [String]
    let relationshipsChanged: [String]
    let orderingChanged: [String]
    let mediaChanged: [String]
    let explicitSaveBehavior: String
    let implicitSaveBehavior: String
    let failureHandling: String
    let userVisibleResult: String
    let purchaseOrAllowanceInteraction: String
    let currentAuthority: CanonicalPersistenceWriterAuthority
    let proposedFutureAuthority: CanonicalPersistenceWriterAuthority
    let requiresMigrationReadiness: Bool
    let requiresCanonicalMapping: Bool
    let requiresOneWriterEnforcement: Bool
    let canBeRoutedIndependently: Bool
    let disableClassification: CanonicalPersistenceDisableClassification
    let rollbackClassification: CanonicalPersistenceRollbackClassification
    let verificationRequired: [String]
    let retirementPrerequisites: [String]
    let classifications: Set<CanonicalPersistenceCutoverRouteClassification>

    var activeProductionWriterCount: Int {
        switch currentAuthority {
        case .legacySwiftData, .storeKitAndKeychain:
            return isReadOnly ? 0 : 1
        case .none, .proposedPersistenceAuthority, .generatedOutputOnly:
            return 0
        }
    }

    var isReadOnly: Bool {
        classifications.contains(.readOnly) || classifications.contains(.notPartOfPersistenceCutover)
    }
}

struct CanonicalPersistenceCutoverGateSet: Hashable, Sendable {
    var schemaDecisionComplete: Bool = false
    var sourceVersionKnown: Bool = false
    var migrationProgressDesignComplete: Bool = false
    var startupPolicyComplete: Bool = false
    var disablePathDefined: Bool = false
    var rollbackOrRecoveryDefined: Bool = false
    var userReviewPolicyResolved: Bool = false
    var purchaseSeparationVerified: Bool = true
    var allowanceBoundaryVerified: Bool = true
    var mappingSupported: Bool = false
    var relationshipVerificationPassed: Bool = false
    var orderingVerificationPassed: Bool = false
    var mediaBehaviorClassified: Bool = true
    var oneWriterGuaranteed: Bool = false
    var explicitApprovalReceived: Bool = false

    static let missingProductionDecisions = CanonicalPersistenceCutoverGateSet()

    static let allSatisfied = CanonicalPersistenceCutoverGateSet(
        schemaDecisionComplete: true,
        sourceVersionKnown: true,
        migrationProgressDesignComplete: true,
        startupPolicyComplete: true,
        disablePathDefined: true,
        rollbackOrRecoveryDefined: true,
        userReviewPolicyResolved: true,
        purchaseSeparationVerified: true,
        allowanceBoundaryVerified: true,
        mappingSupported: true,
        relationshipVerificationPassed: true,
        orderingVerificationPassed: true,
        mediaBehaviorClassified: true,
        oneWriterGuaranteed: true,
        explicitApprovalReceived: true
    )
}

struct CanonicalPersistenceCutoverAcceptanceResult: Hashable, Sendable {
    let routeID: CanonicalPersistenceCutoverRouteID
    let disposition: CanonicalPersistenceCutoverDisposition
    let blockingReasons: Set<CanonicalPersistenceCutoverBlockingReason>
    let exactlyOneWriterGuaranteed: Bool
    let productionRoutingChanged: Bool
}

enum CanonicalPersistenceCutoverReadinessEvaluator {
    static func evaluate(
        routeID: CanonicalPersistenceCutoverRouteID,
        gates: CanonicalPersistenceCutoverGateSet,
        legacyRetirementRequested: Bool = false
    ) -> CanonicalPersistenceCutoverAcceptanceResult {
        let route = CanonicalPersistenceCutoverRouteManifest.route(for: routeID)
        var reasons = Set<CanonicalPersistenceCutoverBlockingReason>()

        if legacyRetirementRequested {
            reasons.insert(.legacyRetirementBlocked)
        }
        if route.requiresOneWriterEnforcement && !gates.oneWriterGuaranteed {
            reasons.insert(.oneWriterNotProven)
        }
        if !gates.schemaDecisionComplete {
            reasons.insert(.schemaDecisionMissing)
        }
        if route.requiresMigrationReadiness && !gates.sourceVersionKnown {
            reasons.insert(.sourceVersionUnknown)
        }
        if route.requiresMigrationReadiness && !gates.migrationProgressDesignComplete {
            reasons.insert(.migrationProgressDesignMissing)
        }
        if route.requiresMigrationReadiness && !gates.startupPolicyComplete {
            reasons.insert(.startupPolicyMissing)
        }
        if route.disableClassification != .notNeededForReadOnly && !gates.disablePathDefined {
            reasons.insert(.disablePathMissing)
        }
        if route.rollbackClassification != .notNeededForReadOnly && !gates.rollbackOrRecoveryDefined {
            reasons.insert(.rollbackOrRecoveryMissing)
        }
        if route.classifications.contains(.blockedByMissingUserReview) && !gates.userReviewPolicyResolved {
            reasons.insert(.userReviewPolicyMissing)
        }
        if !gates.purchaseSeparationVerified {
            reasons.insert(.purchaseSeparationFailed)
        }
        if !gates.allowanceBoundaryVerified {
            reasons.insert(.allowanceBoundaryFailed)
        }
        if route.requiresCanonicalMapping && !gates.mappingSupported {
            reasons.insert(.unsupportedMapping)
        }
        if route.requiresCanonicalMapping && !gates.relationshipVerificationPassed {
            reasons.insert(.relationshipVerificationMissing)
        }
        if route.requiresCanonicalMapping && !gates.orderingVerificationPassed {
            reasons.insert(.orderingVerificationMissing)
        }
        if route.classifications.contains(.mediaWriter) && !gates.mediaBehaviorClassified {
            reasons.insert(.mediaBehaviorUnclassified)
        }
        if route.classifications.contains(.blockedByUnsupportedCanonicalMeaning) {
            reasons.insert(.unsupportedMapping)
        }
        if routeID == .scoringEventCreation || routeID == .correctionPersistence || routeID == .scoreAndGameStateProjectionWrites {
            reasons.insert(.scoringCutoverDeferred)
        }
        if routeID == .compatibilityImports || routeID == .seededGameInsertion {
            reasons.insert(.importTooBroad)
        }
        if route.classifications.contains(.legacyDestructiveWriter) || route.classifications.contains(.deleteOrCleanupWriter) {
            reasons.insert(.deleteTooDestructive)
        }
        if route.classifications.contains(.blockedByMigration) {
            reasons.insert(.migrationDesignMissing)
        }
        if !gates.explicitApprovalReceived {
            reasons.insert(.explicitApprovalMissing)
        }

        let disposition: CanonicalPersistenceCutoverDisposition
        if route.isReadOnly && reasons.isEmpty {
            disposition = .preparationOnly
        } else if reasons.isEmpty && route.classifications.contains(.candidateForFirstBoundedRouting) {
            disposition = .readyForBoundedRouting
        } else if reasons.contains(.schemaDecisionMissing) {
            disposition = .requiresSchemaDecision
        } else if reasons.contains(.migrationDesignMissing) || reasons.contains(.migrationProgressDesignMissing) {
            disposition = .requiresMigrationDesign
        } else if reasons.contains(.rollbackOrRecoveryMissing) || reasons.contains(.disablePathMissing) {
            disposition = .requiresRollbackDesign
        } else if reasons.contains(.userReviewPolicyMissing) {
            disposition = .requiresUserReviewDesign
        } else if reasons.contains(.purchaseSeparationFailed) || reasons.contains(.allowanceBoundaryFailed) {
            disposition = .requiresPurchaseSeparationProof
        } else {
            disposition = .blocked
        }

        return CanonicalPersistenceCutoverAcceptanceResult(
            routeID: routeID,
            disposition: disposition,
            blockingReasons: reasons,
            exactlyOneWriterGuaranteed: gates.oneWriterGuaranteed && route.activeProductionWriterCount <= 1,
            productionRoutingChanged: false
        )
    }
}

enum CanonicalPersistenceCutoverRouteManifest {
    static let requiredProductionWriterReferences: Set<String> = [
        "ScoreKeepApp.modelContainer",
        "ScoreKeepApp.SeederView",
        "ContentView.createGame",
        "ScoreContentView.handleCreateGame",
        "EditGameView.gameBinding",
        "GameView.deleteGame",
        "TeamView.teamInsertDelete",
        "EditTeamView.teamFieldsAndLogo",
        "PlayerView.playerInsertDeleteOrder",
        "PlayersOnTeamView.rosterInsertDeleteOrder",
        "EditPlayerView.playerFieldsAndPhoto",
        "StartingLineupView.doLineup",
        "PlayersToScoreView.doAtbat",
        "PlayersToScoreView.seqGame",
        "PlayersToScoreView.updatePitcherMarkers",
        "ScoreGameView.scoringEditor",
        "ScoreGameView.eventDeletion",
        "PitchersStaffView.pitcherInsertUpdateDelete",
        "ReplacementView.doSubs",
        "PasteView.importPlayers",
        "PasteView.deleteAllPlayersOnSelectedTeam",
        "ImportService.importPlayers",
        "ImportService.importShareGames",
        "ReportAndExport.reads",
        "PurchaseManager.StoreKitKeychain",
        "KeychainBackedCounter.allowances"
    ]

    static let routes: [CanonicalPersistenceCutoverRouteAssessment] = [
        route(.modelContainerStartup, "App launch creates the SwiftData container and makes the legacy context available.", ["ScoreKeepApp.modelContainer"], read: ["SwiftData store metadata"], inserted: [], updated: [], deleted: [], relationships: [], ordering: [], media: [], explicit: "None in the container modifier.", implicit: "SwiftData opens or initializes the current unversioned store.", failure: "No cutover classifier; container failure is not converted into migration policy.", user: "App either starts with the legacy store or fails through platform behavior.", purchase: "Purchase refresh runs separately from baseball persistence.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: false, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["startup policy", "schema decision", "source-version policy"], retire: ["production migration and routing approved"], classes: [.legacyWriter, .blockedByMigration, .blockedBySchemaDecision]),
        route(.emptyStoreInitialization, "New or initialized-empty store handling before any baseball records exist.", ["MigrationSourcesFixturesAndEmptyStoreBaseline"], read: ["store classification evidence"], inserted: [], updated: [], deleted: [], relationships: [], ordering: [], media: [], explicit: "No production route exists beyond SwiftData startup.", implicit: "Current container may initialize an empty current-model store.", failure: "Empty-store test harness classifies failures, production startup does not.", user: "No user-facing migration behavior exists.", purchase: "Preferences, purchases, and allowances are separate evidence.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: false, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["source classification", "startup decision", "progress marker policy"], retire: ["version/source policy approved"], classes: [.legacyWriter, .blockedByMigration, .blockedBySchemaDecision]),
        route(.gameCreation, "User creates a game from game list or score flow.", ["ContentView.createGame", "ScoreContentView.handleCreateGame"], read: ["Team", "allowance counter"], inserted: ["Game"], updated: ["free-game allowance after current save attempt"], deleted: [], relationships: ["Game.hteam", "Game.vteam"], ordering: [], media: [], explicit: "Optional try save after insert.", implicit: "Bound SwiftData state may persist around navigation.", failure: "Save errors are swallowed and allowance decrement is not proven after durable save.", user: "Game appears in list or paywall is shown before creation.", purchase: "Non-premium flow decrements free-game counter after calling the legacy create path.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: true, disable: .schemaIndependentDisablePossible, rollback: .recoveryOnlyUntilBackupDesigned, verify: ["stable transaction identity", "allowance-after-save proof", "duplicate prevention"], retire: ["legacy create route replacement verified"], classes: [.legacyWriter, .candidateForFirstBoundedRouting]),
        route(.gameEditing, "User edits date, location, highlights, teams, or everyone-hits.", ["EditGameView.gameBinding"], read: ["Game", "Team"], inserted: ["Team from add-team helper"], updated: ["Game"], deleted: ["invalid game on dismiss"], relationships: ["Game.hteam", "Game.vteam"], ordering: [], media: [], explicit: "Add-team helper saves; invalid-game deletion does not classify save result.", implicit: "Bindable game edits rely on SwiftData persistence.", failure: "No transaction result or rollback.", user: "Edited game fields remain visible or invalid game is deleted.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["relationship verification", "delete-on-dismiss policy"], retire: ["edit adapter and invalid-edit policy verified"], classes: [.legacyWriter, .deleteOrCleanupWriter, .blockedByMissingRollback]),
        route(.teamCreationAndEditing, "User creates or edits reusable team records.", ["TeamView.teamInsertDelete", "EditTeamView.teamFieldsAndLogo", "ContentView.createTeam", "TeamContentView.addTeam"], read: ["Team", "Player", "Game"], inserted: ["Team"], updated: ["Team"], deleted: ["Team", "players during team deletion"], relationships: ["Team.players", "Team.games"], ordering: [], media: ["Team.logo"], explicit: "Creation and some deletes save explicitly.", implicit: "Field and logo edits rely on bound model persistence.", failure: "Errors are ignored, alerted, or logged depending on route.", user: "Team appears, changes, is deleted, or duplicate/associated-team warning is shown.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: true, disable: .schemaIndependentDisablePossible, rollback: .recoveryOnlyUntilBackupDesigned, verify: ["team identity", "media behavior", "referenced team delete guard"], retire: ["team create/edit/delete replacement verified"], classes: [.legacyWriter, .mediaWriter, .candidateForFirstBoundedRouting]),
        route(.playerCreationAndEditing, "User creates or edits reusable player records.", ["PlayerView.playerInsertDeleteOrder", "PlayersOnTeamView.rosterInsertDeleteOrder", "EditPlayerView.playerFieldsAndPhoto", "PitcherContentView.addPlayer"], read: ["Player", "Team", "Atbat", "Pitcher"], inserted: ["Player"], updated: ["Player"], deleted: ["Player"], relationships: ["Player.team", "Team.players"], ordering: ["Player.batOrder renumbering"], media: ["Player.photo"], explicit: "Creation and some deletes save explicitly.", implicit: "Field, order, team, and photo edits often rely on bound model persistence.", failure: "Some errors alert; many are ignored or logged.", user: "Player appears, changes, is deleted, or reference warning is shown.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: true, disable: .schemaIndependentDisablePossible, rollback: .recoveryOnlyUntilBackupDesigned, verify: ["player identity", "roster relationship", "batting-order verification", "media behavior"], retire: ["player create/edit/delete replacement verified"], classes: [.legacyWriter, .mediaWriter, .blockedByMissingRollback]),
        route(.rosterChanges, "User edits team roster membership and batting order.", ["PlayersOnTeamView.rosterInsertDeleteOrder", "PlayerView.playerInsertDeleteOrder", "PasteView.importPlayers"], read: ["Team", "Player", "Atbat", "Pitcher"], inserted: ["Player"], updated: ["Player.team", "Player.batOrder", "Player display fields"], deleted: ["Player"], relationships: ["Team.players", "Player.team"], ordering: ["Player.batOrder"], media: ["Player.photo through import or edit"], explicit: "Several insert/delete paths save explicitly.", implicit: "Order and relationship edits can be implicit.", failure: "No coherent transaction across roster and order updates.", user: "Roster list updates or deletion warning appears.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["roster relationship", "ordering", "duplicate prevention"], retire: ["all roster mutation paths replaced"], classes: [.legacyWriter, .blockedByMissingRollback]),
        route(.lineupChanges, "User creates, updates, reorders, or replaces a starting lineup.", ["StartingLineupView.doLineup"], read: ["Game", "Team", "Player", "Lineup", "Atbat"], inserted: ["Lineup", "Atbat placeholders", "Player from lineup editor"], updated: ["Lineup.players", "Player.batOrder", "Atbat.batOrder", "Atbat.seq"], deleted: ["Atbat when replacing lineup", "Player from lineup list"], relationships: ["Game.lineups", "Lineup.players", "Game.atbats", "Game.players", "Game.replaced", "Game.incomings"], ordering: ["lineup order", "batting order", "event sequence"], media: [], explicit: "Lineup and placeholder saves occur during the operation.", implicit: "Drag order mutations happen before final save classification.", failure: "Replacement can delete scoring evidence before complete proof.", user: "Lineup is saved or update warning is shown.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["lineup relationship", "event preservation", "rollback design"], retire: ["lineup replacement adapter verified"], classes: [.legacyWriter, .legacyDestructiveWriter, .blockedByMissingRollback, .blockedByMissingUserReview]),
        route(.scoringEventCreation, "User records or edits an at-bat scoring event.", ["PlayersToScoreView.doAtbat", "ScoreGameView.scoringEditor"], read: ["Game", "Team", "Player", "Atbat", "Pitcher"], inserted: ["Atbat"], updated: ["Atbat result/base/out/RBI/sacrifice/stolen/earned-run/play/end markers"], deleted: ["unaccepted Atbat"], relationships: ["Game.atbats", "Game.players"], ordering: ["Atbat.col", "Atbat.seq", "Atbat.inning"], media: [], explicit: "Event insertion and some deletion paths save explicitly or on disappear.", implicit: "Bound editor field changes can persist implicitly.", failure: "No canonical command identity or save disposition is active.", user: "Scorecard cell updates.", purchase: "None directly; scoring depends on game existence.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["canonical scoring storage", "idempotency", "projection verification"], retire: ["task 2.19 and route adapter complete"], classes: [.legacyWriter, .blockedByUnsupportedCanonicalMeaning, .mustRemainLegacyUntilLater]),
        route(.scoreAndGameStateProjectionWrites, "Scoring views recalculate event sequence, inning, outs, max base, score display, and pitcher markers.", ["PlayersToScoreView.seqGame", "PlayersToScoreView.updatePitcherMarkers"], read: ["Atbat", "Pitcher", "Game"], inserted: [], updated: ["Atbat.col", "Atbat.seq", "Atbat.inning", "Atbat.outs", "Atbat.maxbase", "Pitcher boundary markers"], deleted: [], relationships: [], ordering: ["event sequence", "scorecard columns", "pitcher appearance order"], media: [], explicit: "Projection loops call save repeatedly.", implicit: "Some recalculations happen from view change handlers.", failure: "Failures are logged or ignored as non-fatal.", user: "Scorecard and pitcher state update.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["derived-vs-source boundary", "fresh reload", "ordering verification"], retire: ["projection authority defined"], classes: [.derivedProjectionWriter, .mustRemainLegacyUntilLater, .blockedByUnsupportedCanonicalMeaning]),
        route(.correctionPersistence, "Current correction is direct edit or delete of persisted scoring evidence.", ["ScoreGameView.scoringEditor", "ScoreGameView.eventDeletion"], read: ["Atbat", "Game", "Team", "Player"], inserted: [], updated: ["Atbat fields"], deleted: ["Atbat"], relationships: ["Game.atbats"], ordering: ["Atbat sequence after recalculation"], media: [], explicit: "Mixed explicit delete and implicit field mutation.", implicit: "No correction transaction record exists.", failure: "No supersession or idempotency record is persisted.", user: "Existing scoring cell changes or disappears.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["correction storage decision", "idempotency", "prior-game preservation"], retire: ["scoring cutover preparation complete"], classes: [.legacyWriter, .legacyDestructiveWriter, .mustRemainLegacyUntilLater, .blockedByUnsupportedCanonicalMeaning, .blockedByMissingUserReview]),
        route(.pitcherChanges, "User or scoring projection creates, edits, deletes, and updates pitcher appearances.", ["PitchersStaffView.pitcherInsertUpdateDelete", "EditPitcherView.deletePitcher", "PlayersToScoreView.updatePitcherMarkers"], read: ["Pitcher", "Player", "Team", "Game", "Atbat"], inserted: ["Pitcher"], updated: ["Pitcher boundary markers and aggregates"], deleted: ["Pitcher"], relationships: ["Game.pitchers", "Pitcher.player", "Pitcher.team", "Pitcher.game"], ordering: ["pitcher appearance order from boundary fields"], media: [], explicit: "Creation, deletion, cleanup, and marker updates save explicitly.", implicit: "Some edit fields are bound directly.", failure: "Errors are logged or ignored.", user: "Pitcher staff state updates.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["pitcher responsibility policy", "relationship verification"], retire: ["pitcher adapter verified"], classes: [.legacyWriter, .deleteOrCleanupWriter, .blockedByUnsupportedCanonicalMeaning]),
        route(.substitutions, "User applies replacement and incoming-player substitution.", ["ReplacementView.doSubs"], read: ["Game", "Team", "Player", "Atbat"], inserted: ["Pitch Hitter Atbat"], updated: ["Player.batOrder", "Atbat.batOrder", "Atbat.seq"], deleted: [], relationships: ["Game.replaced", "Game.incomings", "Game.atbats", "Game.players"], ordering: ["parallel substitution arrays", "event sequence"], media: [], explicit: "Marker creation and final substitution save explicitly.", implicit: "Some order mutations occur before save.", failure: "Parallel arrays can become ambiguous; no transaction result.", user: "Substitution marker appears in scorecard.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["substitution timing", "pairing policy", "ordering verification"], retire: ["substitution adapter and review policy verified"], classes: [.legacyWriter, .blockedByUnsupportedCanonicalMeaning, .blockedByMissingUserReview]),
        route(.compatibilityImports, "User imports shared player or game compatibility files.", ["ImportService.importPlayers", "ImportService.importShareGames", "ImportPlayersView.importRoutes"], read: ["compatibility files", "Team", "Player", "Game"], inserted: ["Team", "Player", "Game", "Atbat", "Lineup", "Pitcher"], updated: ["Team", "Player", "replacement arrays", "incoming arrays"], deleted: [], relationships: ["complete imported graph"], ordering: ["source event order", "lineup order", "pitcher order"], media: ["Team.logo", "Player.photo"], explicit: "ImportService saves at several helper boundaries and at final application.", implicit: "Imported relationships are built before each save boundary.", failure: "Partial graph can persist before whole import proof.", user: "Imported records appear or decode/application error is shown.", purchase: "MLB/download allowance is separate and must not change during baseball import failure unless separately proven.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["whole-graph transaction", "malformed input", "partial-import recovery"], retire: ["compatibility import adapter verified"], classes: [.compatibilityImportWriter, .blockedByMigration, .blockedByMissingUserReview]),
        route(.seededGameInsertion, "First-launch bundled seed import.", ["ScoreKeepApp.SeederView", "ImportService.importShareGames"], read: ["seeded compatibility game", "hasSeededInitialGame preference"], inserted: ["Team", "Player", "Game", "Atbat", "Lineup", "Pitcher"], updated: ["seed preference", "replacement arrays", "incoming arrays"], deleted: [], relationships: ["seeded imported graph"], ordering: ["seed source order"], media: ["transport media if present"], explicit: "ImportService saves; seed flag is set after import returns.", implicit: "No production completion marker beyond AppStorage seed flag.", failure: "Error is logged; seed may retry on later launch if flag remains false.", user: "Seeded game appears or launch proceeds without it.", purchase: "Seed does not consume game allowance.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["seed idempotency", "preference separation", "whole-graph proof"], retire: ["startup seed policy replaced"], classes: [.seedWriter, .compatibilityImportWriter, .blockedByMigration]),
        route(.mediaReplacementAndRemoval, "User replaces or removes player photos and team logos.", ["EditTeamView.teamFieldsAndLogo", "EditPlayerView.playerFieldsAndPhoto"], read: ["PhotosPickerItem", "pasteboard image", "Team", "Player"], inserted: [], updated: ["Team.logo", "Player.photo"], deleted: ["media bytes by setting nil or replacing bytes"], relationships: [], ordering: [], media: ["Team.logo", "Player.photo"], explicit: "No separate media transaction; ordinary save behavior applies.", implicit: "Bound field mutation persists media bytes.", failure: "No media-specific save result in production.", user: "Image appears, changes, or disappears.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .recoveryOnlyUntilBackupDesigned, verify: ["media classification", "owner identity", "failure injection"], retire: ["media transaction adapter verified"], classes: [.mediaWriter, .blockedByMissingRollback]),
        route(.gameDeletion, "User deletes a game from the game list.", ["GameView.deleteGame"], read: ["Game", "Atbat", "Pitcher", "Lineup"], inserted: [], updated: [], deleted: ["Atbat", "Pitcher", "Lineup", "Game"], relationships: ["Game child arrays"], ordering: [], media: [], explicit: "Manual child deletes then game delete; save behavior is route dependent.", implicit: "SwiftData relationship effects are implicit.", failure: "No rollback for partial delete.", user: "Game disappears.", purchase: "No allowance refund or decrement.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["delete effects", "orphan review", "rollback"], retire: ["delete adapter verified"], classes: [.legacyDestructiveWriter, .deleteOrCleanupWriter, .blockedByMissingRollback, .blockedByMissingUserReview]),
        route(.teamDeletion, "User deletes a team when not associated with games.", ["TeamView.teamInsertDelete", "EditTeamView.teamFieldsAndLogo"], read: ["Team", "Player", "Game"], inserted: [], updated: [], deleted: ["Team", "players on team"], relationships: ["Team.players", "Player.team"], ordering: [], media: ["Team.logo", "Player.photo through player delete"], explicit: "Deletes and related player cleanup save explicitly in some paths.", implicit: "Delete-rule behavior remains implicit.", failure: "Errors may be logged; no rollback.", user: "Team disappears or associated-game warning appears.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["relationship delete effects", "orphan review"], retire: ["team delete adapter verified"], classes: [.legacyDestructiveWriter, .deleteOrCleanupWriter, .blockedByMissingRollback, .blockedByMissingUserReview]),
        route(.playerDeletion, "User deletes a player from roster/list/paste workflows.", ["PlayerView.playerInsertDeleteOrder", "PlayersOnTeamView.rosterInsertDeleteOrder", "PasteView.deleteAllPlayersOnSelectedTeam", "StartingLineupView.deletePlayer"], read: ["Player", "Atbat", "Pitcher", "Team"], inserted: [], updated: ["remaining player batting order"], deleted: ["Player"], relationships: ["Team.players", "Player.team"], ordering: ["remaining batting order"], media: ["Player.photo removed with owner"], explicit: "Some deletes save explicitly; some do not until later.", implicit: "Relationship delete effects are implicit.", failure: "Reference checks are name-based in places and not transaction-classified.", user: "Player disappears or reference warning appears.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["reference checks", "ordering", "orphan review"], retire: ["player delete adapter verified"], classes: [.legacyDestructiveWriter, .deleteOrCleanupWriter, .blockedByMissingRollback, .blockedByMissingUserReview]),
        route(.eventDeletion, "User deletes or clears an at-bat event.", ["ScoreGameView.eventDeletion", "StartingLineupView.doLineup"], read: ["Atbat", "Game"], inserted: [], updated: ["Atbat reset fields", "Game.atbats"], deleted: ["Atbat"], relationships: ["Game.atbats"], ordering: ["event sequence after deletion"], media: [], explicit: "Delete may occur on disappear or during lineup replacement.", implicit: "Field reset is bound mutation.", failure: "No supersession, rollback, or proof of downstream projection repair.", user: "Scoring event clears or disappears.", purchase: "None.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["correction policy", "projection recompute", "rollback"], retire: ["event delete adapter verified"], classes: [.legacyDestructiveWriter, .deleteOrCleanupWriter, .mustRemainLegacyUntilLater, .blockedByMissingUserReview]),
        route(.reportAndExportReads, "Reports, exports, PDFs, screenshots, and share views read baseball records.", ["ReportAndExport.reads", "ShareContentView.exportReads", "ShowReportView.fetch", "ShowPitchRptView.fetch"], read: ["Team", "Player", "Game", "Atbat", "Lineup", "Pitcher"], inserted: [], updated: [], deleted: [], relationships: [], ordering: ["read-only sort and presentation order"], media: ["read logo/photo bytes"], explicit: "No baseball source save intended.", implicit: "Generated files are outside baseball source records.", failure: "Report/export errors do not classify source records.", user: "Report, PDF, screenshot, or export file is generated.", purchase: "Report gates and MLB download allowance are outside baseball persistence.", current: .generatedOutputOnly, future: .generatedOutputOnly, migration: false, mapping: false, oneWriter: false, independent: true, disable: .notNeededForReadOnly, rollback: .notNeededForReadOnly, verify: ["read-only no-repair proof"], retire: ["not a writer route"], classes: [.readOnly]),
        route(.startupCleanupOrNormalization, "Startup seed handling and any current cleanup-like normalization.", ["ScoreKeepApp.SeederView", "PitchersStaffView.cleanupPitchers"], read: ["seed preference", "Pitcher"], inserted: ["seed graph through import"], updated: ["seed preference"], deleted: ["blank Pitcher cleanup when pitcher view runs"], relationships: ["Game.pitchers"], ordering: [], media: [], explicit: "Seed import and pitcher cleanup save explicitly.", implicit: "No general startup cleanup coordinator exists.", failure: "Seed logs errors; cleanup ignores save errors.", user: "Seeded content or cleaned pitcher list may appear.", purchase: "Seed does not consume allowances; purchase refresh is separate.", current: .legacySwiftData, future: .proposedPersistenceAuthority, migration: true, mapping: true, oneWriter: true, independent: false, disable: .blockedUntilDesigned, rollback: .blockedUntilDesigned, verify: ["startup write policy", "cleanup authorization", "idempotency"], retire: ["startup policy and cleanup adapter verified"], classes: [.seedWriter, .deleteOrCleanupWriter, .blockedByMigration]),
        route(.purchaseEntitlementAndAllowance, "StoreKit entitlement and Keychain allowance counters.", ["PurchaseManager.StoreKitKeychain", "KeychainBackedCounter.allowances", "ScoreContentView.handleCreateGame"], read: ["StoreKit products/transactions", "Keychain entitlement", "Keychain counters"], inserted: [], updated: ["season pass expiration", "free game counter", "MLB download counter"], deleted: [], relationships: [], ordering: [], media: [], explicit: "StoreKit and Keychain APIs own their own persistence.", implicit: "Not baseball SwiftData persistence.", failure: "Purchase failures show purchase errors; allowance errors are outside baseball route classification.", user: "Premium access, paywall, or remaining allowance changes.", purchase: "Authoritative purchase and allowance route outside baseball persistence.", current: .storeKitAndKeychain, future: .storeKitAndKeychain, migration: false, mapping: false, oneWriter: false, independent: false, disable: .notNeededForReadOnly, rollback: .notNeededForReadOnly, verify: ["separation proof", "allowance-after-save boundary for baseball transactions"], retire: ["not part of persistence retirement"], classes: [.purchaseOrAllowanceWriterOutsideBaseballPersistence, .notPartOfPersistenceCutover])
    ]

    static func route(for routeID: CanonicalPersistenceCutoverRouteID) -> CanonicalPersistenceCutoverRouteAssessment {
        routes.first { $0.routeID == routeID }!
    }

    private static func route(
        _ id: CanonicalPersistenceCutoverRouteID,
        _ workflow: String,
        _ refs: [String],
        read: [String],
        inserted: [String],
        updated: [String],
        deleted: [String],
        relationships: [String],
        ordering: [String],
        media: [String],
        explicit: String,
        implicit: String,
        failure: String,
        user: String,
        purchase: String,
        current: CanonicalPersistenceWriterAuthority,
        future: CanonicalPersistenceWriterAuthority,
        migration: Bool,
        mapping: Bool,
        oneWriter: Bool,
        independent: Bool,
        disable: CanonicalPersistenceDisableClassification,
        rollback: CanonicalPersistenceRollbackClassification,
        verify: [String],
        retire: [String],
        classes: Set<CanonicalPersistenceCutoverRouteClassification>
    ) -> CanonicalPersistenceCutoverRouteAssessment {
        CanonicalPersistenceCutoverRouteAssessment(
            routeID: id,
            workflow: workflow,
            sourceReferences: refs.sorted(),
            recordsRead: read.sorted(),
            recordsInserted: inserted.sorted(),
            recordsUpdated: updated.sorted(),
            recordsDeleted: deleted.sorted(),
            relationshipsChanged: relationships.sorted(),
            orderingChanged: ordering.sorted(),
            mediaChanged: media.sorted(),
            explicitSaveBehavior: explicit,
            implicitSaveBehavior: implicit,
            failureHandling: failure,
            userVisibleResult: user,
            purchaseOrAllowanceInteraction: purchase,
            currentAuthority: current,
            proposedFutureAuthority: future,
            requiresMigrationReadiness: migration,
            requiresCanonicalMapping: mapping,
            requiresOneWriterEnforcement: oneWriter,
            canBeRoutedIndependently: independent,
            disableClassification: disable,
            rollbackClassification: rollback,
            verificationRequired: verify.sorted(),
            retirementPrerequisites: retire.sorted(),
            classifications: classes
        )
    }
}

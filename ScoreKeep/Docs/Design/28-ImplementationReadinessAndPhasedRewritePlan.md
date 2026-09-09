# ScoreKeep Technical Design — 28 Implementation Readiness and Phased Rewrite Plan

<!-- MARK: - 1. Purpose -->
## 1. Purpose

This document converts the approved ScoreKeep rewrite design series into an implementation-readiness and phased-rewrite plan. It defines how implementation can begin incrementally while preserving current behavior, user-owned data, compatibility files, purchase honesty, accessibility, generated output expectations, and release trust.

Documents 1 through 27 are the primary architectural source of truth. Legacy source code, project configuration, StoreKit configuration, fixtures, tests, generated output, and current application behavior are evidence for compatibility, migration, regression, and risk. They do not redefine the approved architecture and should not be reproduced merely because they exist.

The rewrite is incremental. It is not a single replacement event. Each implementation phase must introduce one clearly defined authority, prove that authority with evidence, prevent duplicate side effects, preserve data, document coexistence, and define when the next phase may safely begin. A phase is not complete merely because code compiles, and it is not complete merely because a new screen appears functional.

This is a planning document. It does not implement production code, tests, fixtures, migrations, build changes, StoreKit changes, source reorganization, routing flags, debug tools, or new APIs.

<!-- MARK: - 2. Repository Evidence and Baseline State -->
## 2. Repository Evidence and Baseline State

The tracked repository root inspected for this document is `/Volumes/XcodeSSD/Users/karldev/Documents/ScoreKeep`. The active branch was confirmed as `scorekeep-next`, and the working tree was clean before the document was created. The tracked design-document directory is `ScoreKeep/Docs/Design`, not the Xcode group-style path shown in some project listings. Existing sibling documents use filenames such as `26-AccessibilityAndInclusiveInteractionDesign.md` and `27-VerificationFixtureAndReleaseAcceptanceDesign.md`; therefore this document belongs beside them as `28-ImplementationReadinessAndPhasedRewritePlan.md`.

The Xcode project contains the app target, unit test target, UI test target, shared scheme `ScoreKeep.xcodeproj/xcshareddata/xcschemes/ScoreKeep.xcscheme`, StoreKit configuration `ScoreKeep.storekit`, app sources under `ScoreKeep`, tests under `ScoreKeepTests` and `ScoreKeepUITests`, and a checked-in seeded game at `ScoreKeep/Seed/seededGame.ScoreKeep_Games`. Current project evidence shows the app target using bundle identifier `Komakode.ScoreKeep`, marketing version `6.1`, Swift version `5.0`, and iOS deployment target `17.6`; test target deployment settings differ in the project file and should be confirmed before implementation tasks depend on a device matrix.

The baseline Xcode build was inspected before writing this document and succeeded. The build log returned no warning entries through the inspected build-log query. Therefore no preexisting compile failure was confirmed for this task. Future implementation should still begin each phase from a known build baseline because a later compile failure must be separated from the documentation-only commit that created this plan.

<!-- MARK: - 3. Confirmed Current Implementation Surface -->
## 3. Confirmed Current Implementation Surface

Confirmed startup evidence includes `ScoreKeepApp`, SwiftUI `WindowGroup`, device-specific routing to `StartView` or `StartPhoneView`, a SwiftData model container for `Game`, app-scoped `PurchaseManager`, `AppRouter`, and `AnnouncementCenter`, scene-phase purchase and announcement refresh, custom `scorekeep://share?tab=download` deep-link parsing, announcement sheet presentation, and a background seeding runner that imports `seededGame.ScoreKeep_Games` through `ImportService` once when `hasSeededInitialGame` is false.

Confirmed persistence evidence includes SwiftData `@Model` classes such as `Game` and `Atbat`. `Game` currently stores UUID identity, string date and location values, stored home and visiting scores, Everyone Hits and inning settings, optional home and visiting teams, players, at-bats, lineups, pitchers, and parallel replacement/incoming player arrays. `Atbat` currently stores result strings, max-base and out-at strings, inning, sequence, column, RBI and out counts, sacrifice flags, stolen-base count, earned-run flag, play notation, and end-of-inning flag.

Confirmed compatibility evidence includes `.ScoreKeep_Players` and `.ScoreKeep_Games` paths in import and export code, document-type and UTType declarations, `ShareTeam`, `SharePlayer`, `ShareGame`, `ShareAtbat`, `ShareLineup`, and `SharePitcher` transport models, seeded game import, website roster download routes, and URL inventory documentation. Repository search did not identify a checked-in `.ScoreKeep_Players` fixture; the checked-in source fixture is the seeded `.ScoreKeep_Games` file.

Confirmed purchase and allowance evidence includes current-year product ID construction from `com.komakode.ScoreKeep.SeasonPass` plus the current calendar year, local Keychain entitlement expiration under `seasonPassMaxExpirationISO8601`, StoreKit transaction listening, restore/status messaging for a non-renewing season pass, `freeGameCreatesRemainingKC` with default two remaining creates, and `mlbDownloadCountKC` with download-count behavior and a four-download policy described in Document 25.

Confirmed verification evidence includes a placeholder Swift Testing unit test, UI tests that launch the app and capture a launch screenshot, the shared scheme, StoreKit configuration, the acceptance fixture catalog, the seeded game fixture, URL and compatibility documentation, and limited explicit accessibility labels. These are starting evidence, not complete release coverage.

<!-- MARK: - 4. Approved Architecture From Documents 1-27 -->
## 4. Approved Architecture From Documents 1-27

The approved architecture establishes one canonical baseball meaning, one scoring and replay authority, staged persistence migration, compatibility adapters for legacy files and records, application services for workflow coordination, generated output as derived projections, purchase and allowance state separate from baseball data, accessibility as a phase-by-phase acceptance requirement, and verification fixtures as release evidence rather than optional tests.

Documents 17 through 27 specifically require that SwiftUI presentation stop owning baseball rules, persistence transactions, compatibility interpretation, purchase decisions, allowance consumption, and generated-output policy. Views may temporarily remain as legacy presentation or may call rewritten services after routing is approved, but they should not become the authority for domain, scoring, migration, entitlement, or report truth.

The design series does not approve new baseball rules, new compatibility formats, new product identifiers, new persistence schemas, new source modules, new service protocols, new CI providers, remote configuration, analytics, paid tooling, or staffing schedules. Implementation tasks must not hide those decisions inside code.

<!-- MARK: - 5. Readiness Principles -->
## 5. Readiness Principles

Evidence comes before replacement. A legacy behavior may be replaced only after its product meaning, compatibility obligation, migration risk, and regression evidence are understood well enough to verify the rewritten path.

One authority owns each behavior at a time. Legacy and rewritten presentation may coexist temporarily, but legacy and rewritten writers may not both perform the same scoring, persistence, import, export, purchase, allowance, generated-output, or migration side effect for the same operation.

Small phases are safer than broad rewrites. Each phase should be reviewable, reversible where practical, and focused on one architectural purpose. Cleanup follows proven replacement; it does not precede compatibility and migration evidence.

Compatibility comes before cleanup. Supported `.ScoreKeep_Players`, `.ScoreKeep_Games`, seeded data, document opening, deep links, roster downloads, existing SwiftData records, photos, logos, purchases, allowances, and generated files remain protected unless a later approved policy explicitly changes support.

Migration comes before retirement. Legacy storage, import routes, export routes, counters, and generated-output paths are retired only after the rewritten authority has evidence for preserving supported data and preventing duplicate side effects.

Verification comes before routing. A rewritten component may exist internally before it is user-routed, but it should not become the production authority until fixtures, exploratory checks, build health, accessibility acceptance, and release blockers are satisfied.

Accessible acceptance is not deferred. Each phase must include VoiceOver, Dynamic Type, keyboard or alternate-input considerations where applicable, focus and interruption recovery, color-independent meaning, and device-class behavior appropriate to that phase.

Architectural readiness differs from code-writing readiness. Architectural readiness means the approved documents define the authority boundary, behavior, risks, and acceptance evidence. Code-writing readiness additionally requires repository baseline, task scope, fixtures or scenarios, migration safety, rollback expectations, and no unresolved design question disguised as an implementation assumption.

<!-- MARK: - 6. Sources of Truth -->
## 6. Sources of Truth

Approved design documents define architecture, responsibility boundaries, and product meaning. Functional specifications define user-visible requirements. The verification and regression catalog defines scenarios that must be represented as evidence. Repository evidence defines current behavior, compatibility inputs, migration risks, and source-control baseline.

Legacy behavior is evidence. It is authoritative only where it reflects an approved product contract or compatibility obligation. Compatible files and existing persisted data are user-owned evidence that the rewrite must continue to interpret safely. StoreKit configuration is evidence of configured products and local purchase-test behavior, not a license to invent future products or prices.

Implementation code executes the approved design after a task is accepted. Tests and fixtures verify approved meaning; they do not independently redefine baseball rules, migration policy, compatibility meaning, entitlement truth, or accessibility obligations. If a fixture and an approved design materially disagree, the disagreement must be resolved explicitly before implementation proceeds.

<!-- MARK: - 7. Implementation Readiness Checklist -->
## 7. Implementation Readiness Checklist

Before substantive rewrite implementation begins, the implementation task should confirm the current branch, working-tree status, baseline build state, supported targets and deployment versions, current startup path, SwiftData model surface, persistence source, compatibility file paths, scoring entry points, purchase products, allowance counters, existing fixtures, critical missing fixtures, legacy side-effect writers, debug-only behavior, data backup and recovery expectations, and phase-specific release blockers.

The task should also identify the governing design documents, affected workflows, proposed authority change, legacy authority retained, side effects touched, migration implications, rollback or disable strategy, accessibility acceptance, and verification evidence. No unresolved architectural question should be hidden as an implementation assumption.

For this repository, confirmed starting items include `ScoreKeepApp` startup, `Game`-scoped SwiftData model container injection, `.ScoreKeep_Players` and `.ScoreKeep_Games` import/export routes, `ScoreKeep.storekit`, Keychain-backed entitlement and counters, seed-game import, placeholder tests, UI launch tests, and a currently successful build. Missing or incomplete readiness evidence includes broad scoring fixtures, roster compatibility fixtures, migration fixtures from representative installed data, accessibility workflow evidence, and generated-output semantic comparison fixtures.

<!-- MARK: - 8. Rewrite Workstream Map -->
## 8. Rewrite Workstream Map

The major workstreams implied by Documents 17 through 27 are canonical baseball domain, scoring and replay, persistence and migration, compatibility import and export, application-service workflow coordination, presentation and prepared state, live scoring interaction, team and player management, roster and lineup management, game setup, generated reports and output, purchases, entitlements and allowances, network roster acquisition, accessibility and inclusive interaction, and verification fixtures and release acceptance.

These workstreams are related but not interchangeable. Canonical baseball meaning feeds scoring. Scoring feeds reports, scorecards, live game state, correction, and export projections. Persistence and compatibility protect existing data. Application services coordinate user intent, transactions, idempotency, and purchase interruptions. Presentation displays prepared outcomes and collects intent. Accessibility applies to every user-routed workflow.

Workstreams may proceed in parallel when they do not introduce competing authorities or irreversible side effects. Fixture curation, repository inventory, presentation-state sketching, accessibility scenario design, and compatibility decode inspection can proceed alongside domain foundations. Authoritative writes, routing changes, persistence migration, allowance consumption, and live-scoring cutover require mandatory sequencing.

<!-- MARK: - 9. Dependency Ordering -->
## 9. Dependency Ordering

Canonical baseball meaning must precede scoring projection. Scoring replay must precede authoritative correction UI. Persistence boundaries must precede physical migration. Compatibility decoding must precede import replacement. Compatibility encoding must precede export replacement. Application services must precede rerouting complex workflows whose current views directly coordinate persistence, purchases, navigation, and generated output.

Purchase policy must precede paywall and allowance rerouting. Generated-output semantics must precede report UI replacement. Accessibility semantics should be developed alongside prepared presentation state rather than added afterward. Fixtures must precede or accompany behavior replacement, and release acceptance must precede removal of coexistence paths.

Mandatory sequencing applies wherever a phase would create or mutate records, consume allowances, import files, export files, migrate data, change purchase decisions, or become the live scoring authority. Parallel work is safer where it reads, classifies, previews, verifies, or prepares state without changing the accepted user-facing writer.

<!-- MARK: - 10. Phase Model -->
## 10. Phase Model

Every implementation phase should define scope, entry criteria, introduced authority, retained legacy authority, side effects affected, compatibility obligations, required fixtures, required verification, accessibility acceptance, migration implications, rollback or disable strategy, exit criteria, release impact, documentation updates, and conditions that block progression.

Each phase should state whether it adds a new authority, replaces an existing authority, introduces coexistence, retires a legacy path, changes persistence, changes compatibility, changes product policy, or changes user-visible behavior. A phase that does none of those things may still be useful, but it should not be described as a cutover.

Exit requires evidence. Compile success is necessary but not sufficient. A happy-path UI check is necessary for routed presentation work but not sufficient. Side effects must not be duplicated, compatibility obligations must be satisfied, migration obligations must be known, accessibility acceptance must pass, release blockers must be resolved, and rollback expectations must be documented.

<!-- MARK: - 11. Phase 0 - Baseline Stabilization and Evidence Capture -->
## 11. Phase 0 - Baseline Stabilization and Evidence Capture

Phase 0 confirms the implementation baseline before architectural replacement. It identifies branch, working tree, build result, warnings, target and deployment settings, current source directories, startup path, current persistence records, import/export routes, scoring surfaces, generated-output paths, StoreKit products, allowance counters, debug-only behavior, tests, fixtures, and documentation evidence.

No production behavior is replaced in this phase. If a compile failure exists, it is recorded as preexisting baseline evidence and handled through a separate production-source fix before rewrite authority work begins. The current inspection for Document 28 found a successful Xcode build and no returned warning entries, so no preexisting compile failure is recorded here.

Phase 0 should capture critical compatibility files, representative persisted-data examples where safe and privacy-appropriate, current generated-output examples where useful, and missing fixture needs. It should document uncertain or unsupported behavior rather than cleaning broadly. It should not create fixtures as part of Document 28; fixture creation is later implementation work.

Exit requires an understandable baseline, a clean or explicitly preserved working tree, known build state, inventory of legacy side-effect writers, critical missing fixtures identified, and no unresolved baseline issue blocking the first authority phase.

<!-- MARK: - 12. Phase 1 - Canonical Baseball Domain Foundation -->
## 12. Phase 1 - Canonical Baseball Domain Foundation

Phase 1 establishes canonical baseball meaning independent from SwiftUI, SwiftData storage shape, StoreKit, networking, report layout, and compatibility transport models. It covers teams, players, rosters, lineups, games, innings, counts where represented, base occupancy, scoring events, pitcher responsibility, substitutions, lifecycle status, identity, ordering, unknown values, unsupported values, and validation boundaries.

This phase introduces conceptual domain authority only after it can represent approved meaning from Documents 18 and 19. Legacy SwiftData models and current views remain the production authority for writes until acceptance passes and routing is later approved. Existing `Game`, `Atbat`, `Lineup`, `Pitcher`, `Team`, and `Player` evidence informs migration and compatibility risks but does not constrain canonical type layout.

Exit requires domain scenarios for identity, historical snapshots, duplicate names, reused numbers, incomplete lineups, unknown pitchers, substitutions, and supported scoring events. It must not change baseball rules, file formats, persistence schemas, or production routing.

<!-- MARK: - 13. Phase 2 - Scoring, Replay, and Correction Authority -->
## 13. Phase 2 - Scoring, Replay, and Correction Authority

Phase 2 establishes deterministic scoring and replay. It covers command validation, event application, derived game state, inning transitions, base occupancy, batter progression, pitcher projections, substitution effects, replay, correction, downstream recalculation, duplicate prevention, idempotency, invalid transitions, and comparison with accepted specifications and regression fixtures.

The rewritten scorer may become authoritative only for a bounded workflow after it proves representative outcomes, boundary innings, third-out behavior, base advancement, batter and pitcher projections, substitutions, corrections, replay determinism, duplicate-command handling, persistence-failure behavior, interruption recovery, and accessibility operation. Until then, legacy scoring remains the active production writer.

This phase may initially run in read-only comparison mode against legacy records and fixtures. It must not double-write scoring events merely to keep legacy and rewritten scoring synchronized unless an explicit reconciliation design and verification plan approve that temporary behavior.

<!-- MARK: - 14. Phase 3 - Persistence Boundary and Migration Foundation -->
## 14. Phase 3 - Persistence Boundary and Migration Foundation

Phase 3 separates canonical records from persistence implementation and prepares safe migration. It defines read and write boundaries, transaction success and failure, identity preservation, relationship integrity, ordering, photos and logos, existing local data, repeated migration, interrupted migration, corrupted records, recovery, coexistence with legacy persistence, and purchase-state separation.

This phase does not select or invent a concrete future persistence schema. It proves that legacy records can be read or adapted without destructive mutation and that future writes can be described as coherent user-visible transactions. SwiftData evidence remains migration input; it is not required to define canonical domain shape.

Exit requires migration gates for empty store, small representative structure, large structure, missing optional values, duplicate identities, photos and logos, interrupted migration, repeated migration, failed migration, recovery behavior, semantic comparison, no purchase-state mutation, and no silent allowance reset.

<!-- MARK: - 15. Phase 4 - Compatibility Import and Export -->
## 15. Phase 4 - Compatibility Import and Export

Phase 4 replaces compatibility routes only after decode-only verification proves `.ScoreKeep_Players` and `.ScoreKeep_Games` behavior. It covers validation, review, conflict handling, confirmation, persistence handoff, compatible export, round-trip evidence, malformed input, unsupported input, user cancellation, existing-data protection, ownership access without entitlement, seeded game behavior, and coexistence with legacy import/export paths.

Decode and classification should precede import application. Encoding should be proven before export replacement. Existing routes through `ImportPlayersView`, `ImportService`, `ShareContentView`, document opening, downloaded roster files, and seed import are evidence of obligations and duplicate-authority risk.

Compatibility routes should not be retired until fixture-backed evidence passes for known legacy files, current generated files, optional fields, unknown values, ordering, IDs, media, malformed input, unsupported input, round trip, cross-version opening where supported, cancellation, conflict handling, and no entitlement lock on owned source data.

<!-- MARK: - 16. Phase 5 - Application-Service Workflow Coordination -->
## 16. Phase 5 - Application-Service Workflow Coordination

Phase 5 introduces application services as workflow authorities. It covers team creation and editing, player creation and editing, roster and lineup management, game setup, game creation, scoring, correction, substitution, import, export, roster download, report generation, purchase interruption, and resume behavior.

Views transition from directly coordinating side effects to submitting product intents and displaying prepared outcomes. Services coordinate validation, persistence transactions, idempotency, purchase gating, allowance consumption, generated-output requests, import plans, and recovery. They do not own baseball rules or presentation layout.

Exit requires service-level workflow verification for duplicate prevention, cancellation, interruption, validation, unchanged-record assertions, purchase interruption, and recovery. Legacy views may remain presentation entry points if they call approved service boundaries instead of directly owning side effects.

<!-- MARK: - 17. Phase 6 - Presentation and Navigation Replacement -->
## 17. Phase 6 - Presentation and Navigation Replacement

Phase 6 replaces presentation incrementally across lists, forms, game setup, team and player editing, roster management, lineup selection, game history, correction, import review, reports, paywalls, error recovery, and iPhone and iPad navigation. Presentation replacement must not change baseball meaning, persistence semantics, entitlement truth, allowance policy, generated-output derivation, or compatibility.

Each screen cutover requires same product capability, accepted baseball meaning, validation, error recovery, pending-state preservation, device-class behavior, orientation handling, Dynamic Type, VoiceOver, keyboard where applicable, offline state, interruption and resume, no hidden compatibility route loss, and no duplicate side effects.

Legacy and rewritten presentation may coexist temporarily. Rewritten presentation may call documented legacy boundaries only where the side effect remains intentionally legacy-owned. Legacy presentation may call rewritten services after the service authority is accepted.

<!-- MARK: - 18. Phase 7 - Live Scoring Cutover -->
## 18. Phase 7 - Live Scoring Cutover

Live scoring is a distinct high-risk cutover. It affects current batter and pitcher context, count where represented, outs, base occupancy, inning, score, rapid repeated actions, additional-choice actions, duplicate prevention, correction and undo, backgrounding, resume, persistence failure, accessibility, and device-class behavior.

The rewritten live scorer should become authoritative only when scoring cutover gates pass. Those gates include representative scoring outcomes, boundary innings, third-out behavior, base advancement, batter projections, pitcher projections, substitution effects, corrections, replay determinism, duplicate commands, persistence failure, resume after interruption, accessibility operation, and comparison against approved specifications and regression fixtures.

Rollback must be defined before cutover. If a routed live-scoring workflow cannot safely write, resume, or prevent duplicates, routing should return to the last accepted authority without downgrading or corrupting records, losing newly created scoring facts, or consuming allowances incorrectly.

<!-- MARK: - 19. Phase 8 - Generated Output and Reports -->
## 19. Phase 8 - Generated Output and Reports

Phase 8 replaces hitting statistics, pitching statistics, scorecards, PDFs, print, share, screenshot/image output where supported, and saved generated output where applicable. Generated output is derived from canonical facts and scoring replay; it is not source baseball data and must not repair or mutate records by being opened.

This phase covers derived-output boundaries, source scope, determinism, formatting variability, purchase gating, existing data access, accessibility, failure, cancellation, and separation from compatible source-data export. It must distinguish semantic comparison from fragile byte or pixel comparison for PDF and report artifacts.

Exit requires generated-output verification for statistical correctness, source-record scope, warnings, long names, empty data, pagination, sharing, saving, failure, cancellation, accessibility, purchase gating where policy applies, and unchanged source records.

<!-- MARK: - 20. Phase 9 - Purchases, Entitlements, and Allowances -->
## 20. Phase 9 - Purchases, Entitlements, and Allowances

Phase 9 migrates purchase and allowance behavior to the boundaries established in Document 25. It covers current-season product discovery, price loading, purchase, pending, cancellation, failure, entitlement recognition, restore or check status, offline-known and offline-uncertain access, prior-season access, free game allowance, MLB download allowance, qualifying-action boundaries, idempotency, existing Keychain evidence, preserved pending workflows, and no baseball-data ownership changes.

Each purchase gate must have one accepted decision path. Each allowance category must have one writer. Current evidence includes StoreKit product identifiers for 2025 and 2026, current-year product construction, Keychain entitlement expiration, free game counter, MLB download counter, and debug reset behavior. Those are migration evidence, not a future schema requirement.

Exit requires product discovery, current-season classification, wrong-season prevention, localized price, success, pending, cancellation, failure, restore, status unavailable, offline-known access, offline uncertainty, prior-season access, qualifying actions, failed actions, duplicate prevention, existing Keychain state, reinstall uncertainty, existing records remaining accessible, and no dual allowance writer.

<!-- MARK: - 21. Phase 10 - Accessibility Completion Across Rewritten Workflows -->
## 21. Phase 10 - Accessibility Completion Across Rewritten Workflows

Accessibility must be included in every prior phase, but Phase 10 consolidates cross-workflow verification. It covers VoiceOver, Dynamic Type, keyboard navigation, pointer, Switch Control and Voice Control considerations, Increased Contrast, Differentiate Without Color, Reduced Motion, focus restoration, gesture alternatives, live-scoring efficiency, import review, correction, reports, purchases, iPhone, and iPad.

This phase closes gaps; it does not postpone basic accessibility until the end. Any core workflow already routed before this phase should have phase-local accessibility acceptance. Phase 10 verifies consistency across rewritten workflows and resolves cross-screen issues such as focus traps, inconsistent labels, noisy live announcements, gesture-only operations, color-only meaning, and large-text clipping.

Exit requires workflow-based accessibility evidence, not only static label inspection.

<!-- MARK: - 22. Phase 11 - Legacy Retirement and Cleanup -->
## 22. Phase 11 - Legacy Retirement and Cleanup

Phase 11 removes or isolates legacy paths only after proven replacement. Retirement requires evidence that the rewritten authority is active, compatibility passes, migration passes, user data is preserved, fixtures cover retired behavior, no alternate legacy side-effect path remains necessary, no old purchase or allowance writer remains active, debug resets are isolated, no deep links or file routes still depend on the legacy path, rollback needs are understood, and documentation reflects final authority.

Cleanup should not be used to make the new architecture appear complete before evidence exists. It should follow accepted replacement and be scoped to obsolete code, duplicated calculations, dead routes, obsolete compatibility shims, or view-local side effects that no longer own a workflow.

Exit requires understandable diffs, no unrelated fixes hidden in cleanup, successful build and verification, and a clear statement of what legacy authority was retired.

<!-- MARK: - 23. Phase 12 - Release Candidate and Rewrite Completion -->
## 23. Phase 12 - Release Candidate and Rewrite Completion

Phase 12 is the release-candidate phase. It verifies build identity, migration rehearsal, compatibility, scoring regression, replay and correction, persistence, import and export, purchases and allowances, offline behavior, interruption and resume, generated output, accessibility, device classes, known issues, release blockers, support diagnostics, rollback strategy, and post-release observation without inventing analytics.

Rewrite complete means product authority has moved to the approved architecture: canonical baseball meaning is authoritative and verified, scoring and replay are deterministic, persistence and migration preserve supported user data, compatible files remain usable, application services coordinate workflows, presentation no longer owns business policy, live scoring is correct and accessible, reports are derived accurately, purchases and allowances are honest and separate from baseball data, existing records remain accessible without current entitlement, offline and interrupted workflows recover safely, legacy side-effect authorities are retired, verification covers critical workflows, debug or test behavior does not leak into release, and any remaining legacy code has an explicit justified role.

Completion is a product condition, not a source-tree aesthetic condition.

<!-- MARK: - 24. Vertical Slices Versus Layer Completion -->
## 24. Vertical Slices Versus Layer Completion

Implementation should use a controlled combination of architectural foundations and vertical workflow slices. Building the entire domain without exercising workflows risks producing unused abstractions and missing transaction boundaries. Replacing UI before domain authority exists risks preserving duplicate baseball rules inside new presentation. Migrating persistence before compatibility is understood risks losing user-owned files and records. Completing one workflow with both legacy and rewritten writers risks duplicate side effects. Waiting until the end to test integration risks discovering migration, purchase, accessibility, and generated-output failures too late.

The recommended model is foundation first where authority is mandatory, then narrow vertical slices that exercise that authority without broad routing. For example, domain meaning and scoring replay should exist before live scoring cutover, but a read-only score projection slice can expose integration risks early. Compatibility decode can run before import application. Generated report projections can be compared before report UI replacement.

This is not a sprint schedule or staffing plan. It is a sequencing model to control authority, evidence, and side effects.

<!-- MARK: - 25. Coexistence Rules -->
## 25. Coexistence Rules

Each behavior has one accepted authority at a time. Use one authoritative reader where interpretation differs, one authoritative writer for each side effect, one scoring authority per game action, one persistence authority per accepted record transaction, one import application path, one export encoder per selected compatibility contract, one purchase decision path per gated action, one allowance writer per allowance category, and one generated-output request coordinator.

No mirrored writes should be used merely to keep two systems synchronized unless explicitly designed and verified. Legacy presentation may call rewritten services. Rewritten presentation may temporarily call approved legacy boundaries only where documented. Cross-path behavior must be fixture-backed.

Coexistence should be visible in task reports. A task should state which authority is active, which legacy path remains, which side effects are routed, and what prevents duplicate writes.

<!-- MARK: - 26. Routing and Feature Cutover -->
## 26. Routing and Feature Cutover

A workflow becomes routed to rewritten authority only after internal development routing, debug-only routing if used, release routing, user-data consistency, deep links, file-open routes, scene restoration, app launch, existing navigation, pending workflows, and rollback are understood.

This plan does not invent feature-flag services, remote configuration, or analytics. Routing may be as simple or as structured as implementation later approves, but the important requirement is that routed workflows cannot bypass validation, duplicate side effects, or strand user data.

Debug-only routing must not leak into release and must not modify production records in a way that release code cannot read. Deep links and file-open routes require special care because they can enter workflows outside ordinary navigation.

<!-- MARK: - 27. Rollback and Disable Strategy -->
## 27. Rollback and Disable Strategy

Each phase should be reversible when practical without downgrading or corrupting user data, losing newly created records, resetting purchases, resetting allowances, producing incompatible exports, replaying side effects, or duplicating games or imports.

Read-only or comparison-mode phases are easiest to disable. User-routed writers require stronger rollback design. Irreversible persistence or compatibility changes require stronger entry criteria, migration fixtures, recovery expectations, and explicit release acceptance before becoming authoritative.

Rollback does not require a concrete version-control or deployment mechanism in this document. It requires product-level clarity about what happens to records created or touched by the phase if routing is disabled.

<!-- MARK: - 28. Data Migration Gates -->
## 28. Data Migration Gates

No persistence migration may become authoritative until source versions are identified and representative fixtures exist for empty database, small real-world structure, large structure, missing optional values, duplicate identities, photos and logos, interrupted migration, repeated migration, failed migration, recovery behavior, post-migration semantic comparison, purchase-state separation, and no silent allowance reset.

Migration must preserve supported teams, players, rosters, games, lineups, scoring events, substitutions, pitcher records, media, preferences where supported, and compatibility evidence. It must not fabricate records, fabricate entitlement, reset allowances, hide existing data, or convert uncertainty into definitive loss.

If migration cannot prove preservation for a category, implementation should pause or classify that category with an explicit warning and approved policy before release routing.

<!-- MARK: - 29. Compatibility Gates -->
## 29. Compatibility Gates

Import or export replacement requires gates for known legacy files, current generated files where applicable, optional fields, unknown values, ordering, IDs, photos and logos, malformed input, unsupported input, round-trip behavior, cross-version opening where supported, user cancellation, conflict handling, and no entitlement lock on owned source data.

`.ScoreKeep_Players` and `.ScoreKeep_Games` are compatibility contracts. Transport models are evidence and exchange shapes, not canonical domain models. Export must read source records without mutating them. Import must decode and review before permanent writes. Local compatible files remain user-owned source data.

The missing checked-in `.ScoreKeep_Players` fixture is a release-evidence gap and should be handled before roster import/export replacement is claimed complete.

<!-- MARK: - 30. Scoring Cutover Gates -->
## 30. Scoring Cutover Gates

Rewritten scoring becomes authoritative only after gates pass for representative scoring outcomes, boundary innings, third-out behavior, base advancement, batter projections, pitcher projections, substitution effects, corrections, replay determinism, duplicate commands, persistence failure, resume after interruption, accessibility operation, and comparison against accepted specifications and regression fixtures.

The gate must include unchanged-record assertions. A scoring command should change only the accepted game facts and derived projections expected for that command. It must not mutate purchase state, consume unrelated allowances, duplicate at-bats, create duplicate games, rewrite unrelated teams or players, or alter generated files as source truth.

If replay is nondeterministic or correction produces inconsistent downstream results, progression stops.

<!-- MARK: - 31. Purchase and Allowance Cutover Gates -->
## 31. Purchase and Allowance Cutover Gates

Purchase and allowance services become authoritative only after gates pass for product discovery, current-season classification, wrong-season prevention, localized price, success, pending, cancellation, failure, restore, status unavailable, offline-known access, offline uncertainty, prior-season access, qualifying actions, failed actions, duplicate prevention, existing Keychain state, reinstall uncertainty, existing records remaining accessible, and no dual allowance writer.

Every gate must distinguish purchase state from baseball ownership. Existing teams, players, games, compatible imports, compatible exports, and local records remain accessible according to approved policy regardless of current entitlement. Allowances change only after successful qualifying actions.

If two paths can decrement the same allowance, progression stops until one writer is isolated or retired.

<!-- MARK: - 32. Presentation Cutover Gates -->
## 32. Presentation Cutover Gates

Before a rewritten screen replaces a legacy screen, it must provide the same accepted product capability, the same approved baseball meaning, validation, error recovery, pending-state preservation, device-class behavior, orientation support where applicable, Dynamic Type, VoiceOver, keyboard support where applicable, offline state, interruption and resume, no hidden compatibility route loss, and no duplicate side effects.

Presentation may improve layout and interaction, but it must not quietly change scoring rules, persistence transactions, entitlement truth, allowance policy, import/export meaning, or report derivation. Device-specific iPhone and iPad branches may differ visually but must preserve capability and baseball meaning.

If a new presentation path cannot prove its side effects are routed through the accepted authority, it should remain internal or disabled.

<!-- MARK: - 33. Documentation-to-Implementation Traceability -->
## 33. Documentation-to-Implementation Traceability

Implementation tasks should reference governing design documents, relevant numbered sections, repository evidence, fixtures, acceptance scenarios, open questions, migration risk, and release blockers. No issue tracker is prescribed.

Each task should state whether it adds a new authority, replaces an existing authority, introduces coexistence, retires a legacy path, changes persistence, changes compatibility, changes product policy, or changes user-visible behavior. It should also state which behaviors remain legacy-owned and why.

When implementation decisions differ materially from the design documents, the documents should be updated through an explicit documentation task rather than allowing code to silently become the new architecture.

<!-- MARK: - 34. Implementation Task Size -->
## 34. Implementation Task Size

Implementation tasks should be small enough to review completely, verify independently, revert safely, identify authority changes, avoid unrelated cleanup, avoid mixing migration with UI replacement and purchase changes unnecessarily, keep source and tests aligned, and preserve a clean build.

A good task boundary has one primary purpose. It may touch several files if the workflow requires it, but it should not combine unrelated production fixes, broad formatting, project setting churn, fixture invention, and authority cutover in one change.

No line-count or duration limit is defined here. Reviewability, verification, reversibility, and authority clarity are the important constraints.

<!-- MARK: - 35. Separate Fixes From Rewrite Work -->
## 35. Separate Fixes From Rewrite Work

Unrelated production defects discovered during planning or implementation should be handled separately. Examples include preexisting compile failures, unrelated warnings, broken project references, stale generated files, unrelated UI defects, source-control display inconsistencies, or debug-only problems outside the phase scope.

A defect fix should have its own diagnosis, smallest behavior-preserving change, verification, and commit where practical. It should not be hidden inside a rewrite phase or documentation commit.

If a preexisting compile failure blocks phase verification, implementation should pause and record the failure as baseline evidence. The fix belongs in a separate production-source task because otherwise the phase result cannot be attributed clearly.

<!-- MARK: - 36. Build Health and Warning Policy -->
## 36. Build Health and Warning Policy

Each implementation phase should begin from a known build status and end with a verified build for the affected target or targets. Documentation-only changes should not modify build state. Target-specific compilation, test compilation, release configuration checks where relevant, type-checker failures, new warnings, and existing warnings should be reported honestly.

This document does not invent a zero-warning policy. New warnings introduced by a phase should generally block completion unless explicitly accepted. Existing warnings, if any, should be recorded as baseline or handled separately rather than mixed into unrelated rewrite work.

For Document 28, the baseline build succeeded and no warning entries were returned by the inspected build log.

<!-- MARK: - 37. Source-Control Discipline -->
## 37. Source-Control Discipline

Implementation phases should confirm branch before work, inspect working tree, preserve unrelated user changes, keep one coherent task per commit where practical, review the diff before commit, avoid build products and user-specific Xcode state, avoid force-push without explicit instruction, directly verify the remote branch after pushing, and treat local remote-tracking status separately from actual GitHub state.

No source changes should be made merely to clear an Xcode Source Control display. Git configuration must not be modified as part of rewrite implementation unless a separate approved task requires it. Branch reset, branch recreation, and manual editing of `.git` are not part of this plan.

Documentation-only commits should change only the intended documentation file unless the task explicitly approves additional documentation updates.

<!-- MARK: - 38. Verification Expectations Per Phase -->
## 38. Verification Expectations Per Phase

Every phase should identify domain verification, persistence verification, compatibility verification, workflow verification, presentation verification, accessibility verification, offline verification, interruption verification, purchase and allowance verification where applicable, unchanged-record assertions, regression fixtures, manual exploratory checks, and release blockers.

A phase should not proceed solely because a happy-path test passes. It should include failure, cancellation, duplicate, offline, interruption, accessibility, and migration-adjacent checks when those conditions affect the phase.

Verification may combine automated tests, fixtures, manual exploratory checks, build verification, local StoreKit checks, controlled file samples, and documentation review. The mechanism is less important than the evidence boundary and repeatability.

<!-- MARK: - 39. Performance and Responsiveness Readiness -->
## 39. Performance and Responsiveness Readiness

Implementation readiness must consider live-scoring responsiveness, large game histories, large rosters, replay of long games, persistence save latency, import of complete files, PDF generation, Dynamic Type layout, VoiceOver announcement volume, app launch while purchase status refreshes, and network download progress.

This document does not invent numeric thresholds. It requires that performance work preserve baseball correctness, transaction boundaries, idempotency, compatibility, and accessibility. Optimization cannot turn cached projections into independent authorities or hide stale derived output as current truth.

Performance evidence should be gathered where a phase introduces a user-routed workflow or long-running operation.

<!-- MARK: - 40. Privacy and Safety During Implementation -->
## 40. Privacy and Safety During Implementation

Fixtures and diagnostics should use synthetic or deliberately approved data. Implementation work should avoid committing private youth-player data, real receipts, credentials, support-case files, personal photos, logos without permission, temporary exports, screenshots with private rosters, raw migration dumps, or unnecessary logs.

Temporary import and export files should be isolated and removed when no longer needed. StoreKit test data should remain controlled. Migration diagnostics should identify affected records without exposing unrelated private data. Support sharing should remain user-chosen.

No analytics or telemetry is invented by this plan.

<!-- MARK: - 41. Cost and Tooling Constraints -->
## 41. Cost and Tooling Constraints

ScoreKeep should prefer built-in, free, or low-cost implementation and verification tools unless a paid tool has clearly justified value and explicit approval. This document does not require paid CI, testing services, analytics, feature-flag platforms, crash-reporting services, or migration services.

External tooling decisions remain implementation choices. A tool may help verification or release management, but it must not become a hidden architectural dependency without approval and documentation.

<!-- MARK: - 42. Implementation Progress Reporting -->
## 42. Implementation Progress Reporting

A completed implementation task should report governing document and sections, exact files changed, authority introduced or replaced, legacy path retained or retired, behavioral decisions, assumptions, unresolved questions, verification performed, build result, test result, migration or compatibility result, accessibility result where applicable, commit hash, push verification, local tracking status, working-tree status, and confirmation that unrelated files were not changed.

For routing or cutover tasks, the report should explicitly state how duplicate side effects are prevented and how rollback or disable would preserve user records, purchases, allowances, imports, exports, and generated output.

For documentation-only tasks, the report should confirm that production source code, tests, fixtures, seeded data, StoreKit configuration, project settings, schemes, build configurations, Git configuration, and `.git` contents were not modified.

<!-- MARK: - 43. Pause Conditions -->
## 43. Pause Conditions

Progression to the next phase should stop for unresolved baseball-rule ambiguity, unsupported compatibility assumption, unknown persistence migration behavior, data loss, nondeterministic replay, duplicate side effects, dual allowance writers, wrong-season purchase behavior, existing records becoming inaccessible, inability to verify the remote branch after a push, preexisting build failure obscuring the phase result, missing critical fixture, accessibility failure in a core workflow, unrelated changes mixed into the phase, or material disagreement between architecture documents and implementation.

Pause does not mean the rewrite failed. It means the next irreversible or user-routed step is not safe until evidence, policy, or a separate fix resolves the blocker.

The pause reason should be recorded in product-facing terms and linked to the affected authority boundary.

<!-- MARK: - 44. Exit Criteria for Each Phase -->
## 44. Exit Criteria for Each Phase

A phase exits only when its authority is explicit, required verification passes, compatibility obligations are satisfied, migration obligations are satisfied or explicitly not in scope, accessibility acceptance is satisfied, side effects are not duplicated, legacy coexistence is documented, rollback expectations are known, release blockers are resolved, documentation is updated where decisions changed, and the working tree and commit scope are understandable.

If a phase introduces a user-routed writer, exit also requires unchanged-record assertions and duplicate-prevention evidence. If a phase touches import, export, migration, purchases, allowances, or live scoring, exit requires targeted failure and interruption checks.

Exit criteria should be evaluated before cleanup and before routing broader workflows through the new authority.

<!-- MARK: - 45. Legacy Mapping to Phases -->
## 45. Legacy Mapping to Phases

`ScoreKeepApp` maps to Phase 0 and later routing phases. It currently owns startup, scene-phase refresh, model-container injection, deep-link parsing, environment-object creation, announcement presentation, and seeded-game import. Its behavior provides startup and route evidence. Retirement or replacement requires app launch, deep-link, seed, purchase-refresh, and scene-resume evidence.

SwiftData model classes such as `Game` and `Atbat` map to Phases 1 through 3. They provide persisted-record evidence, scoring-row evidence, stored-score evidence, substitution-array evidence, and migration risk. They should be preserved as supported data sources until canonical interpretation and migration pass acceptance.

Live scoring views and scorecard drawing paths map to Phases 2, 6, and 7. They provide current workflow evidence and risks around fixed-size assumptions, view-local scoring state, scorecard coordinates, and duplicate calculations. They should retire only after rewritten scoring, presentation, correction, persistence, and accessibility gates pass.

`ImportPlayersView`, `ImportService`, `ShareContentView`, document-opening helpers, downloaded roster handling, and seeded-game import map to Phase 4 and Phase 5. They provide compatibility evidence and show possible duplicate import responsibilities. Retirement requires decode, review, conflict, persistence, cancellation, export, round-trip, deep-link, and file-open evidence.

Reporting and PDF files map to Phase 8. They provide generated-output behavior, statistical calculation evidence, screenshot/share workflows, and risks from duplicated formulas. Retirement requires shared replay-derived projections and generated-output verification.

`PurchaseManager`, `PaywallView`, `PremiumBadgeView`, `KeychainBackedCounter`, game creation gates, report gates, and roster-download gates map to Phase 9. They provide StoreKit, entitlement, allowance, debug reset, and UI evidence. Retirement requires one purchase decision path and one allowance writer per category.

Tests, fixtures, `ScoreKeep.storekit`, the seeded game, URL inventory, and the acceptance catalog map to Phase 0 and all verification gates. They provide baseline evidence but are not yet sufficient release coverage for scoring, migration, roster compatibility, accessibility, purchase interruption, or generated-output semantics.

<!-- MARK: - 46. Legacy Risks -->
## 46. Legacy Risks

Confirmed risks include views and presentation workflows coordinating persistence, import/export, purchases, reports, and navigation directly; multiple import paths; stored scores and replay-derived scores coexisting; substitution evidence stored in parallel arrays; transport models close to persisted models; current-year purchase assumptions; Keychain counters with separate writers in presentation workflows; debug reset evidence described in existing documentation; fixed frames, line limits, and minimum scale factors in dense views; limited explicit accessibility labels; placeholder tests; and missing checked-in roster compatibility fixture evidence.

Risks to verify include whether any live scoring path can perform duplicate side effects during repeated actions or resume, whether best-effort saves can be followed by allowance decrement in failure cases, whether generated output ever mutates source records, whether import/export logic is duplicated beyond the inspected paths, whether deep links and file-open paths converge on one import review boundary, whether release build settings isolate debug-only behavior, and whether existing real-world data contains unsupported migration shapes not represented by current fixtures.

These risks should guide verification and phase entry criteria. They should not be used as permission for broad cleanup before evidence exists.

<!-- MARK: - 47. Risks and Open Questions -->
## 47. Risks and Open Questions

Unresolved implementation questions include exact canonical model implementation, persistence technology and migration mechanism, application-service organization, coexistence routing mechanism, fixture formats, feature-cutover method, whether internal debug routing is needed, how long rollback paths must remain, which released data versions require migration fixtures, PDF comparison strategy, supported device matrix, CI tooling, performance acceptance thresholds, keyboard command policy, accessibility automation limits, and whether implementation begins with domain foundations or a narrowly selected vertical slice after Phase 0.

Additional questions include media snapshot policy for historical games, exact handling of incomplete pitcher responsibility, exact report formula decisions where prior documents left product policy open, whether roster download allowance should count at download handoff or import confirmation, and how to represent stale generated output if retained in-app.

These questions should not be settled silently in production code. Each requires repository evidence, product approval, fixture evidence, or a follow-up design decision.

<!-- MARK: - 48. Proposed Phase Summary -->
## 48. Proposed Phase Summary

1. Phase 0 captures baseline evidence. New authority: none. Legacy authority retained: all current production behavior. Main gate: known branch, build, inventory, and fixture gaps. Main risk: cleanup before evidence.
2. Phase 1 establishes canonical baseball meaning. New authority: domain meaning in accepted scope. Legacy authority retained: production writes and presentation. Main gate: identity, lineup, participant, and validation scenarios. Main risk: speculative model details.
3. Phase 2 establishes scoring and replay. New authority: deterministic scoring for accepted scope. Legacy authority retained: live scoring writer until cutover. Main gate: replay, correction, duplicate, and boundary fixtures. Main risk: two scoring writers.
4. Phase 3 establishes persistence and migration boundaries. New authority: read/write transaction boundary for accepted scope. Legacy authority retained: existing storage until migration acceptance. Main gate: migration preservation and recovery. Main risk: irreversible data change.
5. Phase 4 replaces compatibility import/export. New authority: compatibility codecs and import/export planning. Legacy authority retained: current routes until fixture evidence passes. Main gate: decode, encode, review, round trip, malformed input. Main risk: unreadable user-owned files.
6. Phase 5 introduces workflow services. New authority: application-service coordination. Legacy authority retained: views not yet routed. Main gate: idempotent workflow verification. Main risk: hidden duplicate side effects.
7. Phase 6 replaces presentation and navigation. New authority: prepared presentation state for accepted screens. Legacy authority retained: uncut screens and side effects. Main gate: same capability and accessibility. Main risk: UI changing policy.
8. Phase 7 cuts over live scoring. New authority: rewritten live scoring writer. Legacy authority retained: none for routed scoring action. Main gate: scoring cutover gates. Main risk: corrupt or duplicate game events.
9. Phase 8 replaces generated output and reports. New authority: replay-derived report projections. Legacy authority retained: uncut outputs. Main gate: statistical and output semantics. Main risk: stale or inconsistent reports.
10. Phase 9 replaces purchases and allowances. New authority: purchase and allowance service decisions. Legacy authority retained: none for routed gates. Main gate: one decision path and one counter writer. Main risk: wrong access or duplicate allowance consumption.
11. Phase 10 completes cross-workflow accessibility. New authority: accessibility acceptance across rewritten workflows. Legacy authority retained: none for completed routed workflows. Main gate: workflow-based accessibility evidence. Main risk: core workflows inaccessible despite visual success.
12. Phase 11 retires legacy paths. New authority: already active rewritten authorities. Legacy authority retained: only justified compatibility-only code. Main gate: no remaining needed side-effect path. Main risk: removing compatibility before evidence.
13. Phase 12 completes release candidate. New authority: final integrated rewritten product. Legacy authority retained: only explicit justified role or none. Main gate: release acceptance. Main risk: undiscovered integration, migration, or accessibility failure.

<!-- MARK: - 49. Recommended Next Step -->
## 49. Recommended Next Step

The next safe step is a narrow Phase 0 implementation-readiness task focused on baseline verification and fixture-curation planning.

This task should prepare implementation but introduce no new production authority. It should preserve the current app behavior while producing the concrete evidence needed for the first authority phase: final baseline inventory, fixture gap list, representative compatibility-file needs, safe persisted-data sample policy, current side-effect writer map, debug-only behavior list, and phase-entry blockers.

The evidence that must exist first is the clean `scorekeep-next` branch, known build state, tracked design documents through Document 28, repository inventory, and agreement that fixture creation or production-source fixes will be separate tasks. It must not change production source, tests, fixtures, StoreKit configuration, project settings, build settings, import/export formats, generated output, or purchase policy.

This recommendation is safer than beginning canonical implementation immediately because the repository already shows missing roster fixture evidence, multiple import paths, placeholder tests, and high-risk live scoring and purchase side effects. A focused Phase 0 readiness task will make the first implementation cut reviewable and prevent unresolved compatibility or migration assumptions from becoming code.

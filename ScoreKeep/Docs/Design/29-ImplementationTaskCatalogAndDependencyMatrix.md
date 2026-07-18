# ScoreKeep Technical Design — 29 Implementation Task Catalog and Dependency Matrix

<!-- MARK: - 1. Purpose -->
## 1. Purpose

This document converts the approved ScoreKeep rewrite phases into an ordered catalog of small implementation tasks that can later be given to Codex one task at a time. It is a planning document only. It does not implement production code, tests, fixtures, migrations, compatibility codecs, services, routing, StoreKit changes, project settings, schemes, build settings, or cleanup.

Documents 1 through 28 remain the approved design and planning authority. Repository source is evidence for current behavior, compatibility, migration, and implementation risk. Legacy code is coexistence and regression evidence, not architecture to reproduce. Existing tests and fixtures are verification evidence, not independent product specifications.

The catalog is not a schedule, staffing plan, sprint plan, release calendar, or implementation itself. Its purpose is to make future implementation requests small, reviewable, dependency-aware, and safe for user-owned baseball data, compatibility files, purchases, allowances, accessibility, and generated output.

<!-- MARK: - 2. Repository Evidence Inspected -->
## 2. Repository Evidence Inspected

The active branch was confirmed as `scorekeep-next`, the working tree was clean before this document was created, and a safe dry-run fetch from `origin scorekeep-next` completed before writing. The tracked design-document path is `ScoreKeep/Docs/Design`; the Xcode group-style path includes an additional displayed `ScoreKeep` component, so new design files must be created in the tracked Git path rather than inferred from the group display. Existing sibling design documents use filenames such as `27-VerificationFixtureAndReleaseAcceptanceDesign.md` and `28-ImplementationReadinessAndPhasedRewritePlan.md`, so this document is placed beside them as `29-ImplementationTaskCatalogAndDependencyMatrix.md`.

Confirmed startup and routing evidence includes `ScoreKeepApp`, SwiftUI `WindowGroup`, device-specific routing to `StartView` and `StartPhoneView`, app-scoped `PurchaseManager`, `AppRouter`, `AnnouncementCenter`, scene-phase purchase and announcement refresh, `scorekeep://share?tab=download` deep-link parsing, `onOpenURL` handling, and a hidden seeding runner that imports `seededGame.ScoreKeep_Games` through `ImportService` when `hasSeededInitialGame` is false.

Confirmed persistence evidence includes SwiftData `@Model` records such as `Game` and `Atbat`, with the app injecting a model container for `Game`. `Game` stores identity, date, location, highlights, stored scores, Everyone Hits and inning settings, optional home and visiting teams, players, at-bats, lineups, pitchers, and replacement/incoming player arrays. `Atbat` stores result strings, base and out strings, inning, sequence, scorecard column, RBIs, outs, sacrifice flags, stolen-base count, earned-run flag, notes, and end-of-inning state.

Confirmed scoring and report evidence includes scoring, score display, drawing, correction, replacement, report, PDF, and export files that read or write `Atbat`, `Game.hscore`, `Game.vscore`, `maxbase`, `outAt`, inning, sequence, and result strings. Report and PDF paths derive statistics and printable scorecards from persisted rows.

Confirmed compatibility evidence includes `.ScoreKeep_Players` and `.ScoreKeep_Games` declarations in `Info.plist`, an additional `UTType.myCustomFile` declaration in `Common/Extensions.swift`, export file creation in `ShareContentView`, decode and import paths in `ImportService` and `ImportPlayersView`, downloaded roster handling in `DownloadFiles`, seeded game import, document-open routing from startup views, and URL inventory documentation. Repository inspection found one checked-in `.ScoreKeep_Games` fixture at `ScoreKeep/Seed/seededGame.ScoreKeep_Games`; no checked-in `.ScoreKeep_Players` fixture was found.

Confirmed purchase and allowance evidence includes `PurchaseManager`, current-year product ID construction from `com.komakode.ScoreKeep.SeasonPass` plus the current calendar year, local Keychain entitlement storage under `seasonPassMaxExpirationISO8601`, StoreKit transaction listening, restore/status messaging for a non-renewing season pass, `freeGameCreatesRemainingKC` with default two remaining game creations, `mlbDownloadCountKC` with four-download policy behavior, game-creation allowance consumption in `ScoreContentView`, MLB download allowance consumption in `ShareContentView`, and debug-only free-game reset behavior in `ScoreContentView`.

Confirmed generated-output and media evidence includes `GeneratePDF`, `PdfView`, report views, screenshot views, `Manual.pdf`, generated PDF saving to the Documents directory, report screenshot/share handoff, player photos, team logos, and media carried through compatibility transport models.

Confirmed verification evidence includes placeholder Swift Testing coverage in `ScoreKeepTests/ScoreKeepTests.swift`, basic XCTest UI launch and performance tests in `ScoreKeepUITests`, a shared scheme, StoreKit configuration, seeded game fixture, acceptance fixture catalog, URL inventory, and limited explicit accessibility labels. This evidence is sufficient to plan implementation tasks; it is not sufficient to claim rewrite readiness.

<!-- MARK: - 3. Architectural Position -->
## 3. Architectural Position

Implementation proceeds through individually reviewable tasks. Each task has one primary outcome and introduces, prepares, verifies, routes, replaces, or retires one clearly identified authority. Tasks should not mix domain, persistence, presentation, purchase, migration, generated output, and compatibility changes unless an approved phase explicitly requires a controlled vertical slice.

A task that changes an authoritative side effect must identify the previous authority, the new authority, the retained legacy path, the side effect involved, and the verification gate that prevents duplicated or lost behavior. A task cannot retire a legacy path before replacement verification passes. A task cannot introduce a second active writer for the same scoring event, persisted record transaction, import application, export file, allowance counter, purchase decision, migration action, or generated-output request.

Tasks cannot silently broaden product behavior, change baseball rules, change compatibility formats, reset user data, reset entitlements, reset allowances, invent product identifiers, invent source directories, invent target/module boundaries, or hide unrelated cleanup in implementation work. Documentation-only, fixture-only, test-only, production-source, migration, routing, and cleanup tasks should remain separate where practical.

Every implementation task should leave the repository buildable and understandable unless it is explicitly documented as an intermediate non-routable foundation task. Verification tasks should precede or accompany risky cutovers. Unrelated defects discovered during a task are handled separately.

<!-- MARK: - 4. Standard Task Entry Contract -->
## 4. Standard Task Entry Contract

Every catalog task is identified by a stable phase-based task number, such as `0.1`, `1.4`, or `12.20`. The number is stable for future prompt generation and is not a schedule, sprint, priority score, or staffing assignment.

Every future implementation prompt derived from this catalog must include the following task information:

| Field | Required content |
| --- | --- |
| Task number and title | Stable number plus human-readable title. |
| Governing phase | Phase 0 through Phase 12 from Document 28. |
| Governing design documents | Design document numbers and relevant sections by title where known. |
| Purpose | The single primary outcome of the task. |
| Repository evidence to inspect | Current files, docs, fixtures, tests, project settings, or generated outputs that may be read. |
| Prerequisites | Prior task numbers, verification gates, or explicit design decisions required before work begins. |
| Scope | What may be changed or produced. |
| Explicit exclusions | What must not be changed, including unrelated cleanup. |
| Authority | Authority introduced, prepared, verified, routed, replaced, or retired. |
| Legacy authority retained | Current path that remains active until later cutover or retirement. |
| Side effects involved | Record writes, file writes, import application, export generation, purchase decisions, allowance writes, migration, generated output, or routing. |
| Data or compatibility risk | User data, file compatibility, migration, purchase, allowance, media, or generated-output risk. |
| Required fixture or test evidence | Fixtures, scenarios, test coverage, manual evidence, or comparison harness needed. |
| Required verification | Build, test, fixture, compatibility, migration, accessibility, purchase, generated-output, or direct remote verification as applicable. |
| Accessibility obligations | Basic workflow accessibility for routed user-facing work; explicit no-user-facing-change statement for non-UI work. |
| Build expectations | Whether a full build, code diagnostics, tests, or no build is required. |
| Exit criteria | Observable completion conditions and unchanged-record expectations. |
| Blockers | Conditions that must stop the task rather than be guessed through. |
| Rollback or disable considerations | How the change can be disabled, reverted, or left non-routed without data damage. |
| Recommended commit scope | One coherent task per commit where practical. |
| Task kind | Documentation-only, fixture-only, test-only, production-source, migration, routing, cleanup, or controlled vertical slice. |

The task rows below use compact language. The standard contract above applies to every row. When a row says "inspect listed evidence," it means read enough repository evidence to make claims supportable and preserve unrelated user work. When a row says "no production routing," the task may prepare or verify an authority but must not make it the active user path.

<!-- MARK: - 5. Task Boundary Rules -->
## 5. Task Boundary Rules

Preferred task boundaries are one coherent authority, one fixture set, one workflow outcome, one verification harness, one routing preparation step, or one retirement step. Avoid tasks as broad as "rewrite scoring," "replace persistence," "redesign UI," "add accessibility," or "implement purchases." Also avoid tasks so small that they create commits with no observable architectural progress.

Foundation tasks may create non-routed internal capability only after prerequisites exist. Comparison tasks may read legacy records and produce evidence but must not double-write. Routing tasks must be separate from foundation implementation unless the approved phase explicitly requires a controlled vertical slice. Retirement tasks occur only after replacement verification passes.

Documentation-only, fixture-only, test-only, production-source, migration, routing, and cleanup work should be split unless combining them is the only safe way to prove one user-visible transaction. Production fixes discovered during implementation are separate tasks and commits where practical.

<!-- MARK: - 6. Phase 0 Task Catalog - Baseline Stabilization and Evidence Capture -->
## 6. Phase 0 Task Catalog - Baseline Stabilization and Evidence Capture

Phase 0 captures evidence and establishes verification readiness. It does not replace production behavior.

| Task | Purpose and scope | Evidence to inspect | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 0.1 Baseline build and test-compilation record | Confirm current build/test baseline and record failures without fixing unrelated issues. | Project, scheme, tests, build log. | Clean branch inspection. | Prepares build evidence; no authority change; all legacy paths retained. | Build result recorded; test compilation state recorded; no source edits unless separate approved fix. | documentation-only or test-infrastructure evidence |
| 0.2 Authoritative side-effect writer inventory | Inventory current writers for scoring, persistence, import, export, purchases, allowances, generated output, seeding, deep links, and debug resets. | `ScoreKeepApp`, SwiftUI views, sharing, reports, purchase, Keychain, model files. | 0.1 preferred. | Prepares side-effect map; legacy remains active. | Inventory names previous writer and side effect; no code changes. | documentation-only |
| 0.3 Data model and persistence entry inventory | Inventory SwiftData records, model container setup, relationship loading, save points, deletes, media, and seeded data. | `Objects`, startup, edit/list/scoring/import files. | 0.2. | Prepares persistence boundary evidence. | Inventory distinguishes stored facts, derived values, compatibility evidence, and unknowns. | documentation-only |
| 0.4 Scoring and correction entry inventory | Map current scoring event creation, edit, correction, replacement, score display, and report recalculation paths. | Score, edit score, drawing, replacement, report files. | 0.2. | Prepares scoring authority evidence. | Entry points and duplicate writer risks documented. | documentation-only |
| 0.5 Compatibility route inventory | Map `.ScoreKeep_Players`, `.ScoreKeep_Games`, document open, deep link, download, seed, import, export, and share routes. | `Info.plist`, `Extensions`, sharing, import, startup, URL docs. | 0.2. | Prepares compatibility authority evidence. | Supported routes, unknowns, and malformed handling gaps documented. | documentation-only |
| 0.6 Purchase and allowance writer inventory | Map product loading, entitlement recognition, restore/status, free game counter, MLB download counter, debug reset, and paywall interruptions. | `PurchaseManager`, `KeychainBackedCounter`, paywall, score/share views, StoreKit. | 0.2. | Prepares purchase/allowance authority evidence. | Writer list separates game and download allowances. | documentation-only |
| 0.7 Generated-output inventory | Map report, PDF, screenshot, print/share, file save, and source-data export separation. | Reporting, PDF, screenshot, share files, `Manual.pdf`. | 0.2. | Prepares generated-output authority evidence. | Derived-output paths and source mutation risks documented. | documentation-only |
| 0.8 Accessibility baseline inventory | Inventory labels, values, focus, Dynamic Type, color-only meaning, touch target, keyboard, iPhone, and iPad gaps. | Current views, reports, paywall, import, scoring, UI tests. | 0.1. | Prepares accessibility evidence. | Major gaps and existing labels documented; no UI edits. | documentation-only |
| 0.9 Representative `.ScoreKeep_Players` fixture curation | Add or curate reviewed roster compatibility fixtures after choosing support location. | Export route, download route, import route, docs. | 0.5 and fixture location decision. | Prepares compatibility fixture authority; legacy import retained. | Fixtures decode with current legacy path or gaps documented; no production code changes. | fixture-only |
| 0.10 Additional `.ScoreKeep_Games` fixture curation | Add or curate representative game fixtures beyond seeded game. | Seeded game, import/export, scoring/report evidence. | 0.5. | Prepares game compatibility fixtures; legacy import retained. | Fixtures include ordinary, completed, in-progress, substitution, pitcher, and score mismatch cases where available. | fixture-only |
| 0.11 Malformed and unsupported fixture curation | Add malformed, unsupported, wrong-extension, HTML, empty, truncated, future-required, and media-corrupt inputs. | Import routes, download routes, document-opening routes. | 0.9 or 0.10. | Prepares failure evidence; no active import replacement. | Fixture meanings and expected safe failures documented. | fixture-only |
| 0.12 Scoring regression scenario capture | Capture representative scoring, replay, correction, runner, inning, pitcher, substitution, and long-game scenarios. | Existing scoring views, reports, acceptance catalog. | 0.4. | Prepares scoring fixture evidence; legacy scoring retained. | Scenario expectations separated from legacy implementation details. | fixture-only or documentation-only |
| 0.13 Test persistence isolation setup | Establish isolated test persistence behavior without changing production persistence. | Test targets, SwiftData setup, seeded data behavior. | 0.1 and 0.3. | Prepares verification infrastructure. | Tests can run without mutating user data; no production routing. | test-only |
| 0.14 Controlled date, season, debug, and regression run baseline | Establish deterministic date/season verification, record debug-only reset behavior, and baseline regression run. | Purchase, allowance, StoreKit, date formatting, debug code, tests. | 0.1, 0.6, 0.13. | Prepares purchase and regression evidence. | Controlled-state approach documented; no entitlement or allowance reset in production data. | test-only or documentation-only |

<!-- MARK: - 7. Phase 1 Task Catalog - Canonical Baseball Domain Foundation -->
## 7. Phase 1 Task Catalog - Canonical Baseball Domain Foundation

Phase 1 introduces canonical baseball meaning in non-routed foundations. It must not choose concrete source directories, persistence schemas, or public APIs beyond what an implementation task explicitly approves.

| Task | Purpose and scope | Evidence to inspect | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 1.1 Stable identity and ordering semantics | Define and verify identity and ordering meaning for teams, players, games, participants, events, lineups, pitchers, and substitutions. | Docs 18/19/20/21; `Game`, `Player`, `Team`, `Atbat`, import/export. | Phase 0 inventories. | Introduces non-routed domain meaning; SwiftData legacy writes remain active. | Duplicate names, reused numbers, doubleheaders, sequence ordering, and imported IDs represented without routing. | production-source foundation or test-only |
| 1.2 Team meaning foundation | Represent reusable team and game-side meaning. | `Team`, `Game`, import/export, reports, media. | 1.1. | Prepares team authority; legacy team records retained. | Current roster and historical side meaning are separable. | foundation |
| 1.3 Player meaning foundation | Represent reusable player and game participant meaning. | `Player`, `Atbat`, roster, reports, photos. | 1.1. | Prepares player authority; legacy player writes retained. | Duplicate names/numbers and historical participation remain distinct. | foundation |
| 1.4 Roster membership meaning | Represent current roster membership apart from game participation. | Team/player list/edit/import/paste views. | 1.2, 1.3. | Prepares roster authority; legacy roster writes retained. | Roster edits do not imply historical game changes. | foundation |
| 1.5 Lineup meaning | Represent game-specific lineup facts and incomplete lineups. | Starting lineup, edit lineup, score setup, import lineups. | 1.3, 1.4. | Prepares lineup authority; legacy lineup writes retained. | Everyone Hits and traditional evidence can be represented without routing. | foundation |
| 1.6 Batting-order semantics | Represent batting slot order, progression hints, unknowns, and historical lineup changes. | `Player.batOrder`, lineup views, scoring, import. | 1.5. | Prepares batting authority; legacy progression retained. | Batting order is not roster sort order or player property alone. | foundation |
| 1.7 Defensive position semantics | Represent position, unknown position, pitcher-only participation, and display values. | Player edit, lineup, pitcher staff, reports. | 1.3. | Prepares defensive-position meaning; legacy fields retained. | Unknown and blank are distinct from position values. | foundation |
| 1.8 Game identity and status | Represent game identity, settings, lifecycle, sample/import origin, in-progress and completed states. | `Game`, score/game list/edit, seeded import. | 1.1, 1.2, 1.3. | Prepares game authority; legacy game writes retained. | Draft, ready, in-progress, completed, imported, and interrupted meanings are expressible where approved. | foundation |
| 1.9 Inning and half-inning semantics | Represent inning number, top/bottom, expected innings, extra or shortened states. | `Atbat.inning`, score views, reports, docs 19. | 1.8. | Prepares inning authority; legacy inning values retained. | Inning evidence can be interpreted without changing records. | foundation |
| 1.10 Count and outs semantics | Represent count where supported, outs, impossible outs, and third-out context. | Scoring UI, `Atbat.outs`, reports. | 1.9. | Prepares outs authority; legacy scoring retained. | Zero through three outs and invalid fourth-out state can be validated. | foundation |
| 1.11 Base occupancy semantics | Represent runner identity, base occupancy, scored runners, runner outs, and impossible duplicate occupancy. | Score views, `maxbase`, `outAt`, reports. | 1.3, 1.10. | Prepares runner/base authority; legacy runner interpretation retained. | Bases empty and all occupied-base combinations can be described. | foundation |
| 1.12 Scoring-event meaning | Represent supported recorded play facts and preserved unsupported legacy values. | `Atbat`, Common result strings, scoring/report/export. | 1.6, 1.11. | Prepares event authority; legacy `Atbat` writes retained. | Supported and unsupported result strings are distinguishable. | foundation |
| 1.13 Pitcher responsibility meaning | Represent pitcher appearances, unknown pitchers, inherited context, and projection inputs. | `Pitcher`, pitcher views/reports, scoring. | 1.8, 1.12. | Prepares pitcher authority; legacy pitcher records retained. | Appearance boundary and aggregate evidence are separable. | foundation |
| 1.14 Substitution meaning | Represent incoming/outgoing participant, role, timing, batting slot, and ambiguous legacy arrays. | Replacement view, `Game.replaced`, `Game.incomings`, reports. | 1.5, 1.12. | Prepares substitution authority; legacy arrays retained. | Ambiguous substitutions stay warning/repair evidence. | foundation |
| 1.15 Domain validation boundary | Define validation outcomes without persistence, routing, or UI ownership. | Docs 18/19/27 and Phase 0 scenarios. | 1.1-1.14. | Introduces non-routed validation authority. | Valid, warning, incomplete, repair, unsupported, rejected, and contradictory cases verified. | foundation/test |
| 1.16 Legacy-to-canonical mapping for verification | Map legacy records and transport evidence into canonical meaning for comparison only. | SwiftData models, import/export, seeded game, fixtures. | 1.15, 0.9, 0.10. | Prepares adapter evidence; legacy remains active; no writes. | Current evidence can be interpreted or classified without mutation. | test-only or foundation |

<!-- MARK: - 8. Phase 2 Task Catalog - Scoring, Replay, and Correction -->
## 8. Phase 2 Task Catalog - Scoring, Replay, and Correction

Phase 2 establishes deterministic scoring and replay. Foundation, comparison, routing, and retirement remain separate.

| Task | Purpose and scope | Evidence to inspect | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 2.1 Accepted scoring command vocabulary | Define supported scoring commands from approved behavior only. | Docs 19/27, Common result strings, scoring UI, reports. | 1.12, 0.12. | Prepares command authority; legacy UI choices retained. | Vocabulary maps existing supported choices and preserves unsupported values. | documentation/test/foundation |
| 2.2 Scoring command validation | Validate command context without writes. | Score views, domain validation, fixtures. | 2.1, 1.15. | Introduces non-routed validation authority. | Invalid batter, runner, out, inning, lineup, and pitcher states rejected or warned. | foundation/test |
| 2.3 Deterministic event application | Apply one accepted event to state in memory. | Docs 19, Atbat evidence, fixtures. | 2.2. | Introduces non-routed event authority; legacy `Atbat` writer active. | Same input produces same output and no side effects. | foundation/test |
| 2.4 Count transition handling | Handle count where supported and preserve unsupported count expectations. | Scoring UI/docs. | 2.3. | Prepares count authority. | Count behavior does not invent unapproved baseball rules. | foundation/test |
| 2.5 Out transition handling | Handle outs, double/triple plays, third out, and invalid fourth-out states. | `Atbat.outs`, reports, docs 19. | 2.3. | Introduces out transition authority. | Boundary out fixtures pass. | foundation/test |
| 2.6 Base-runner transition handling | Handle batter and runner advancement, runner outs, scores, steals, and duplicate occupancy. | `maxbase`, `outAt`, scoring/report files. | 2.3, 1.11. | Introduces base-state transition authority. | Occupancy fixtures pass; incomplete legacy evidence classified. | foundation/test |
| 2.7 Run and score calculation | Derive runs, RBIs, score, and third-out scoring validity. | `hscore`, `vscore`, `maxbase`, reports. | 2.5, 2.6. | Introduces derived-score authority non-routed. | Replay-derived score compared to stored score evidence. | foundation/test |
| 2.8 Inning transition calculation | Derive top/bottom and inning progression. | `Atbat.inning`, score views, reports. | 2.5, 2.7. | Introduces inning transition authority. | Third-out and inning-boundary scenarios pass. | foundation/test |
| 2.9 Batter projection | Derive current and next batter from lineup and events. | Lineup views, `Player.batOrder`, scoring. | 2.8, 1.6. | Introduces batter projection authority. | Progression survives inning transitions and substitutions. | foundation/test |
| 2.10 Pitcher projection | Derive active pitcher and responsibility warnings. | Pitcher views, pitcher reports, docs 19. | 2.8, 1.13. | Introduces pitcher projection authority. | Unknown, changed, and incomplete pitcher scenarios classified. | foundation/test |
| 2.11 Replay from initial state | Replay ordered facts from initial state. | Seeded game, fixtures, legacy records. | 2.3-2.10. | Introduces replay authority non-routed. | Full replay is deterministic and checkpoint-independent where tested. | foundation/test |
| 2.12 Correction planning | Plan correction effects before persistence. | Edit/correction paths, reports, docs 23. | 2.11. | Prepares correction authority; legacy correction retained. | Affected downstream events and projections identified without mutation. | foundation/test |
| 2.13 Correction application | Apply accepted correction to an in-memory fact set. | Correction fixtures. | 2.12. | Introduces non-routed correction authority. | Prior facts preserved or superseded explicitly; no unrelated changes. | foundation/test |
| 2.14 Downstream recalculation | Regenerate score, state, reports, exports, and warnings after correction. | Reports, export, score views. | 2.13. | Prepares projection authority. | Downstream projections refresh from facts only. | foundation/test |
| 2.15 Invalid correction rejection | Reject impossible, unsafe, or unsupported corrections. | Correction fixtures and docs 27. | 2.13. | Introduces rejection authority. | Failed corrections preserve last accepted state. | test/foundation |
| 2.16 Duplicate command prevention | Prevent repeated scoring/correction intent from creating duplicates. | Score UI repeated taps, app services docs. | 2.3, 2.13. | Prepares idempotency authority; legacy writer retained. | Duplicate scenario produces existing result or safe rejection. | foundation/test |
| 2.17 Long-game replay verification | Verify long games, extra innings, substitutions, pitchers, and reports. | Additional fixtures, seeded game. | 2.11, 2.14. | Verifies replay authority. | Long-game scenarios pass within acceptable correctness expectations. | test-only |
| 2.18 Legacy-versus-rewritten comparison harness | Compare rewritten replay against legacy records and reports without changing records. | Legacy models, reports, fixtures. | 2.11, 0.12. | Prepares comparison authority; no production routing. | Agreements and discrepancies classified. | test-only |
| 2.19 Scoring-authority cutover preparation | Define gates, routing plan, rollback, and no-dual-writer protection for scoring. | Docs 19/23/28, comparison results. | 2.18, Phase 3 persistence prep. | Prepares cutover; legacy remains active. | Cutover checklist complete; no user routing yet. | documentation/routing prep |
| 2.20 Scoring-authority routing and legacy retirement split | Route only after gates, then retire legacy scoring in a later separate task. | Live scoring, correction, reports, exports, tests. | 2.19, Phase 7 routing gates. | Routes new scoring authority; legacy retirement remains separate until Phase 11. | No duplicate scoring writer; rollback defined. | routing then cleanup later |
| 2.21 Renewed scoring-authority readiness after persistence foundations | Reassess scoring-authority readiness after canonical scoring persistence design, schema implementation, transaction adapter, persisted replay verification, and disposable rehearsal. | Task 2.20 baseline; scoring authority baselines; Phase 3 canonical scoring persistence evidence; scoring UI one-writer evidence. | 3.25 and no active 7.21 routing. | Reopens scoring readiness only as a gate; production scoring remains Legacy. | Command-family readiness reassessed; at most one bounded candidate selected; exact persistence mapping, authoritative Legacy parity, correction support, UI one-writer boundary, manual regression, and explicit production activation decision recorded. | documentation/routing prep |

Tasks 2.19 and 2.20 remain completed preparation-only or blocked verdicts. They exposed a dependency gap rather than authorizing immediate production routing: canonical events are value-only, event ordering is not durably authoritative, operation identity is not persisted, duplicate and conflict classifications are not durable, corrections and supersessions are not persisted, replay after relaunch lacks an exact canonical source, current `Atbat` and `Game` mappings are lossy or ambiguous for scoring authority, no versioned-schema task yet authorizes new scoring persistence structures, no bounded scoring transaction adapter yet authorizes one-save writes, no disposable scoring persistence rehearsal exists, and later routing gates cannot succeed until those foundations are complete. Task 3.20 is not a substitute for canonical scoring persistence, migration completion alone does not enable scoring routing, and Team routing approval does not enable scoring routing.

<!-- MARK: - 9. Phase 3 Task Catalog - Persistence and Migration Foundation -->
## 9. Phase 3 Task Catalog - Persistence and Migration Foundation

Phase 3 prepares persistence and migration boundaries without selecting a new persistence technology unless separately approved.

| Task | Purpose and scope | Evidence to inspect | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 3.1 Persistence boundary inventory | Identify read/write/save/delete/load boundaries and transaction risks. | SwiftData models, views, import, reports. | 0.3. | Prepares persistence authority evidence. | All known writers and implicit saves documented. | documentation-only |
| 3.2 Canonical-to-persisted mapping | Map canonical facts to persisted evidence conceptually. | Docs 18/20, models. | Phase 1. | Prepares persistence mapping; no schema selection. | Mapping distinguishes facts, derived values, compatibility evidence. | foundation/test |
| 3.3 Persisted-to-canonical mapping | Interpret legacy records into canonical meaning read-only. | `Game`, `Atbat`, `Lineup`, `Pitcher`, import fixtures. | 1.16, 3.1. | Prepares read adapter; legacy storage retained. | No mutation on read; warnings classified. | foundation/test |
| 3.4 Transaction result classification | Define success, failure, partial, stale projection, recovery, and retry outcomes. | Docs 20/23, save points. | 3.1. | Prepares transaction authority. | Classification supports user-visible unchanged-record assertions. | foundation/test |
| 3.5 Save failure handling foundation | Verify failed save behavior without corrupting prior state. | ModelContext save callers. | 3.4, 0.13. | Prepares persistence failure authority. | Failed writes do not consume allowances or mutate unrelated records. | test/foundation |
| 3.6 Reload and round-trip verification | Verify saved records reload with identity, ordering, relationships, and media. | SwiftData records, fixtures. | 3.2-3.5. | Verifies persistence boundary. | Round-trip scenarios pass or classify gaps. | test-only |
| 3.7 Relationship integrity verification | Verify teams, players, games, atbats, lineups, pitchers, replacements, and incoming players. | Models/import/export. | 3.6. | Verifies relationship authority. | Missing and ambiguous relationships produce diagnostics. | test-only |
| 3.8 Ordering preservation verification | Verify event, batting, lineup, pitcher, and import/export ordering. | Sort descriptors, `seq`, `col`, `batOrder`. | 3.6. | Verifies ordering authority. | Stable ordering preserved without relying on presentation only. | test-only |
| 3.9 Photos and logos persistence verification | Verify media load, save, import, export, replacement, and failure behavior. | Team/player media, PDF/report/export/import. | 3.6. | Verifies media persistence authority. | Media failures do not make baseball facts unusable. | test-only |
| 3.10 Deletion and repair boundary | Define safe delete, deactivation, archive, and explicit repair behavior. | Edit/list views, docs 20. | 3.4, 3.7. | Prepares deletion/repair authority; legacy behavior retained. | No implicit destructive repair on read/report/export. | foundation/test |
| 3.11 Migration-source inventory | Inventory versions, records, preferences, seed, files, media, purchase separation. | Models, AppStorage, Keychain, seed. | 3.1. | Prepares migration evidence. | Source categories and privacy-safe examples documented. | documentation-only |
| 3.12 Representative migration fixtures | Curate privacy-safe existing-store examples and expected outcomes. | Local fixture decisions, docs 20/27. | 3.11. | Prepares migration fixture authority. | Fixtures cover small, large, missing, duplicate, media, and warning cases. | fixture-only |
| 3.13 Empty-store migration | Verify launch/migration behavior for no existing baseball data. | Startup, SwiftData, seed. | 3.11. | Verifies migration path; no legacy retirement. | Empty store remains usable; seed behavior understood. | test/migration |
| 3.14 Existing-store migration | Verify representative existing records remain understandable. | 3.12 fixtures. | 3.3, 3.12. | Verifies migration interpretation. | Existing teams, players, games, media, reports, exports preserved or classified. | migration/test |
| 3.15 Interrupted migration | Verify interruption/restart recovery. | Migration fixtures and persistence boundary. | 3.14. | Prepares recovery authority. | Interrupted migration does not duplicate or hide records. | migration/test |
| 3.16 Repeated migration | Verify idempotency of repeated migration/interpretation. | Migration fixtures. | 3.14. | Verifies idempotency authority. | Repeated runs do not duplicate records, purchases, or allowances. | migration/test |
| 3.17 Failed migration and recovery | Verify safe failure, diagnostics, and prior usable state. | Corrupt fixtures, docs 20. | 3.15. | Verifies recovery authority. | Failure preserves recoverable prior state. | migration/test |
| 3.18 Purchase and allowance separation | Verify baseball persistence does not mutate Keychain entitlement or counters. | PurchaseManager, Keychain counters, game/download flows. | 3.4, 0.6. | Verifies separation authority. | Baseball save/migration failure never resets entitlement or allowances. | test-only |
| 3.19 Persistence-authority cutover preparation and routing | Prepare then route bounded persistence authority only after verification gates. | 3.6-3.18 evidence. | 3.18. | Routes persistence authority for bounded workflows; legacy retained where unrouted. | One writer per transaction; rollback defined. | routing |
| 3.20 Legacy persistence retirement | Retire legacy persistence adapters only after replacement and migration evidence. | Phase 11 evidence. | 3.19 plus Phase 11 gate. | Retires legacy persistence authority. | No active route depends on retired writer. | cleanup |
| 3.21 Canonical scoring persistence requirements and schema decision | Define the durable canonical scoring facts and decide whether a next schema version or other approved storage shape is required. | Docs 17-24, 26-28; scoring and persistence baselines; `Game`, `Atbat`, `Lineup`, `Pitcher`; SwiftData save/autosave documentation. | 2.20 blocked verdict, 3.19. | Prepares scoring persistence design; Legacy scoring and current production storage remain active. | Exact durable facts, event identity and ordering policy, operation identity, correction and supersession semantics, payload/versioning strategy, Legacy coexistence, difficult runner-out ambiguity preservation, schema-version decision, and no-production-routing boundary documented. | documentation-only |
| 3.22 Versioned canonical scoring persistence implementation | Implement only the approved storage and migration foundation for canonical scoring persistence. | 3.21 design decision; production startup and migration baselines; current schema records. | 3.21 and explicit schema approval. | Introduces non-routed canonical scoring storage if approved; Legacy production scoring retained. | Next schema version added only when required; migration stage explicit; no synthesized canonical history for Legacy games; original baseball facts and fingerprints unchanged; new canonical storage initially empty; startup recovery intact; production scoring remains Legacy. | production-source/migration |
| 3.22A Frozen V2 Store Verification Architecture Decision | Decide the smallest safe architecture for trustworthy production verification of a frozen V2 store without constructing runtime-effective V2 and V3 SwiftData schemas together. | Task 3.22 blocked stabilization state at commit 702120289bccaef6b58658fd0e964aa5469a7aa0; Task 3.22 blocker record; V1/V2/V3 schema declarations; startup, recovery, metadata, backup, journal, diagnostics, target, packaging, test-plan, fixture, and platform evidence; authoritative Apple documentation where needed. | Blocked Task 3.22 stabilization state. | Prepared architecture decision only; production scoring remained Legacy; Task 3.23 remains blocked. | One design document titled Frozen V2 Store Verification Architecture evaluated an authoritative frozen Core Data V2 model, a dedicated V2-only verification target or helper boundary, and recovery-verification redesign; compared production feasibility, data safety, documented API support, complexity, App Store compatibility, testability, and maintenance; selected the prerequisite implementation and testing tasks required before Task 3.22 completion; no candidate implementation, Core Data model, target, production startup or recovery change, schema change, migration execution, simulator launch, Task 3.23 implementation, or Legacy scoring retirement occurred in Task 3.22A. | documentation-only |
| 3.22B Frozen V2 evidence and fixture acquisition | Obtain authoritative frozen V2 store evidence and representative fixtures required by the selected Task 3.22A architecture. | Document 31; exact V2 metadata/hash inventory; source-family fingerprints; historical or archived-build V2 store fixtures; optional V2-only test-target evidence for fixture generation. | 3.22A. | Prepares evidence only; production scoring remains Legacy; Task 3.23 remains blocked. | Exact frozen V2 metadata evidence and representative fixture provenance are recorded; no production startup, migration, schema, Core Data model reconstruction, or scoring adapter implementation. | fixture/test-prep |
| 3.22C Metadata-gated copied-workspace migration boundary | Implement source identity and copied-workspace safety for frozen V2 migration without semantically opening V2 in the current V3 app target. | Document 31; metadata assessment; store-family preservation; migration journal; production startup and recovery blockers. | 3.22B. | Restores a production-capable migration boundary; production scoring remains Legacy; Task 3.23 remains blocked. | Exact V2 metadata gate, canonical-entity absence gate, verified source backup, copied temporary workspace, journal evidence, and fail-closed unsupported states are implemented and tested; active source is never migrated in place. | production-source/migration |
| 3.22D V3 destination semantic verification and rollback reconciliation | Implement post-migration V3 verification, canonical-zero checks, verified-candidate eligibility, rollback, and completed-journal recovery for the selected boundary. | Document 31; migration baseline capture; retention; completed-journal recovery; source preservation tests. | 3.22C. | Verifies migrated V3 destination before later acceptance; production scoring remains Legacy; Task 3.23 remains blocked. | V3 destination open, record counts, stable identities, relationships, ordering, score, substitution, media, team-creation evidence, canonical-zero counts, rollback, verified-candidate eligibility, and recovery classifications are tested; active-store replacement remains outside Task 3.22. | production-source/test |
| 3.22E Migration acceptance tests and manual verification | Prove the selected architecture across normal, failed, repeated, interrupted, unsupported, and rollback states. | Document 31; Tasks 3.22B-3.22D; fixtures; migration/recovery tests; manual device or archived-store evidence when authorized. | 3.22B, 3.22C, 3.22D. | Verifies the Task 3.22 migration boundary; production scoring remains Legacy; Task 3.23 remains blocked. | Automated fixture evidence and the recorded manual-verification limitation show source preservation, copied migration, V3 verification, canonical-zero preservation, rollback, interruption recovery, repeated-start idempotency, and purchase separation. | test/migration |
| 3.22F Temporary duplicate-checksum diagnostic cleanup | Remove or permanently fence obsolete V2-plus-V3 hosted diagnostic detours only after the selected architecture is implemented and verified. | Document 31; Task 3.22 blocker construction audit; retained diagnostics; source-level blocker tests. | 3.22C, 3.22D, 3.22E. | Cleans up unsafe detours; production scoring remains Legacy; Task 3.23 remains blocked. | No retained production or hosted path constructs runtime-effective V2 and V3 schemas together unless a separately approved isolated boundary owns that construction; useful metadata and source-preservation diagnostics remain. | cleanup/test |
| 3.23 Scoring transaction, correction, supersession, and idempotency adapter | Add a bounded non-routed adapter for canonical scoring writes, retries, corrections, and supersessions. | 3.22 storage evidence; scoring command/correction/idempotency baselines; SwiftData context/save evidence. | 3.22. | Prepares scoring transaction authority; no production UI caller. | Dedicated context; autosave disabled; one explicit save for pending inserts, changes, and deletes; durable duplicate and conflict evidence; fresh-context reconciliation; correction and supersession atomicity; exact repeat produces one event; conflicting duplicate rejected; no managed objects escape the boundary. | production-source/test |
| 3.24 Persisted scoring replay and migration verification | Verify canonical scoring replay from persisted evidence after relaunch and across malformed or legacy-adjacent states. | 3.22-3.23; scoring fixtures; malformed/unsupported fixtures; difficult runner-out evidence; migration baselines. | 3.23. | Verifies persisted replay authority; Legacy production scoring retained. | Deterministic ordering after relaunch; malformed evidence fails closed; correction relationships validated; no managed objects escape persistence boundary; difficult runner-out history remains explicit without invention; no existing game receives synthesized canonical events. | test/migration |
| 3.25 Disposable canonical scoring persistence rehearsal | Rehearse canonical scoring persistence in an isolated nonproduction store or disposable identity. | 3.22-3.24; startup recovery; scoring authority baselines; relevant fixtures. | 3.24. | Rehearses scoring persistence only; no production routing. | Isolated nonproduction store or disposable identity proven; event persistence, correction, idempotency, relaunch, and difficult runner-out preservation pass; production data not accessed; production scoring remains Legacy. | migration/test |

### Task 3.22 Completion Record - Versioned Canonical Scoring Persistence

Task 3.22 is complete after final review of Tasks 3.22A through 3.22F. The completed storage implementation declares V1 with six Legacy baseball models (`Game`, `Team`, `Player`, `Atbat`, `Lineup`, `Pitcher`), V2 with those six plus `TeamCreationOperationEvidenceRecord`, and V3 with those seven plus the five canonical scoring storage models (`CanonicalGameHistoryRecord`, `CanonicalScoringOperationEvidenceRecord`, `CanonicalScoringEventEnvelopeRecord`, `CanonicalScoringEventPayloadRecord`, `CanonicalScoringCorrectionRecord`). Production scoring remains Legacy, no production writer synthesizes canonical scoring rows, and Task 3.23 remains blocked until separately authorized.

Independent diagnostics already showed V2 and V3 can each be constructed separately, and a disposable V2-to-V3 proof was obtained with zero canonical history, event, payload, operation, or correction records synthesized. That proof is useful evidence but is not sufficient architecture for the hosted current-target environment because repeated hosted runtime attempts failed with `NSInvalidArgumentException: Duplicate version checksums detected`.

The blocker is runtime-effective historical schema expansion. In the current V3 app or hosted test process, constructing historical V2 through SwiftData can expand to the same effective 12-model inventory as V3. Registering that effective V2 together with V3, including through `ScoreKeepProposedCanonicalScoringStorageMigrationPlan`, hosted V2-to-V3 tests, semantic verification paths, schema diagnostics, disposable migration helpers, or production recovery branches, can trigger duplicate checksums. Hosted V2-plus-V3 migration tests are therefore invalid and must be replaced only by source-level or inventory assertions that state the missing proof.

Production startup cannot safely semantically open frozen V2 through the V3 app target. The repository has no independent frozen V2 `NSManagedObjectModel`, and it has no existing isolated seven-model V2 target. Metadata equality, version identifiers, SQLite table presence, and hash inventory comparison are useful diagnostics, but metadata-only evidence is insufficient semantic proof because it does not prove SwiftData can open the copied source and preserve relationships, counts, and stored values under an authoritative frozen model.

The stabilization boundary was fail closed at `semanticVerifierUnavailable.currentTargetV2AndV3DuplicateEffectiveChecksums`. Normal production startup may open V3 directly or create a new empty V3 store where authorized, but it must not construct V2 and V3 together or silently skip required recovery verification. Task 3.22A authorized the Path C substitute instead of an independent frozen V2 semantic open: exact metadata identity, source-family discovery and preservation, copied-workspace migration, V3 semantic reconciliation, canonical-zero verification, and retained rollback. Production scoring remains Legacy and Task 3.23 remains blocked.

Construction audit disposition:

| File and symbol | Target | Registered schemas or effective inventory | Disposition | Duplicate-checksum risk |
| --- | --- | --- | --- | --- |
| `ScoreKeepProposedVersionedSchema.ScoreKeepProposedCanonicalScoringStorageMigrationPlan` | ScoreKeep | Declares V2 and V3 | Required schema declaration, but unsafe when used in hosted current-target runtime | Yes when passed to `ModelContainer` |
| `ScoreKeepProposedContainerFactory.construct` | ScoreKeep | V3 only for new or existing V3; V2 sources now fail closed | Required production code | No retained normal path constructs V2 plus V3 |
| `ScoreKeepProductionStartupHost.runProductionMigration` | ScoreKeep | Production startup now supports no-store and V3 direct only | Required production code | No, V2 classifications fail closed before migration |
| `ScoreKeepCompletedJournalRecoveryRouter.route` and `ScoreKeepProductionStartupHost` completed-journal switch | ScoreKeep | V3 direct open only; V1/V2 recovery blocked | Required production recovery routing | No normal routed call reaches V2-plus-V3 helpers |
| `ScoreKeepCompletedJournalV2SourceBaseline.make` | ScoreKeep | No SwiftData V2 open; throws blocker | Required fail-closed semantic verifier boundary | No |
| `ScoreKeepCompletedJournalV2SourceBaseline.proposedV2Container` | ScoreKeep | No longer opens V2; throws blocker | Obsolete detour retained only as cleanup candidate | No after stabilization |
| `ScoreKeepProductionStartupHost.recoverCompletedJournalV2Target` | ScoreKeep | Would delegate to V2-source migration orchestration, but the completed-journal switch now fails closed before calling it | Deferred cleanup after blocker resolution | No normal routed call |
| `ScoreKeepProductionStartupHost.recoverActiveV1ThroughFreshV3`, `proposedV2MigratingFromV1Container`, `automaticV2MaterializationContainer`, `proposedV3MigratingFromV2Container` | ScoreKeep | Retained V1-to-V2 scaffolding; V3-from-V2 helper now throws blocker before `ModelContainer` construction | Deferred cleanup after blocker resolution; fenced from normal startup | No V2-plus-V3 registration after stabilization |
| `ScoreKeepSchemaDiagnosticReporter` under `-ScoreKeepSchemaDiagnostic` | ScoreKeep | Inventory-only V2/V3 schema reporting moved out of `ScoreKeepApp`; hosted migration open explicitly not performed; redundant launch-only prints removed | Useful bounded diagnostic | No retained migration open |
| `ScoreKeepPhysicalMigrationExecutor.freshProposedComparison` | ScoreKeep `SCOREKEEP_MIGRATION_TEST` support | Checks retained backup metadata as V2 and opens only the copied V3 target for baseline comparison | Diagnostic-only | No retained V2-plus-V3 open |
| `VersionedCanonicalScoringPersistenceTests.v2ToV3RuntimeMigrationProofRequiresIsolatedV2Boundary` | ScoreKeepTests | Source-level assertion only | Valid retained blocker coverage | No |
| `ScoreKeepProposedContainerFactoryTests` V2/unversioned cases | ScoreKeepTests | V3-only new-store construction; V2/unversioned inputs fail closed | Valid retained blocker coverage | No |
| `CompletedJournalRecoveryRoutingTests` V2/V1 recovery cases | ScoreKeepTests | Source-level fail-closed assertions | Valid retained blocker coverage | No |
| `IsolatedUnversionedProductionStoreSupport.proposedV2Container` and `IsolatedVersionedTeamCreationEvidenceSupport` | ScoreKeepTests | V1/V2-only helpers for pre-V3 compatibility tests | Requires future relocation to isolated V2-only target if selected with V3 migration tests | Single-schema use is acceptable; selected V2-plus-V3 use is invalid |
| `ProposedV3SchemaInventoryTests` | ScoreKeepTests | Declared inventory only, no `ModelContainer` migration | Valid retained inventory coverage | No runtime registration |

Cleanup candidates inspected: `-ScoreKeepSchemaDiagnostic` launch support is useful diagnostic and retained as inventory-only with launch-only noise removed; SQLite/version-hash metadata diagnostics are useful diagnostic and retained with the caveat that they are not semantic proof; temporary schema inventory tests are retained; physical migration post-migration comparison now metadata-checks the V2 backup and opens only the V3 target instead of reporting the old duplicate-checksum blocker; parallel recovery detours in `ScoreKeepProductionStartupHost` are retained as legacy compatibility blockers because interrupted development journals may still classify through them; navigation-route compile repair is unrelated and retained.

Task 3.22A decision record: Document 31, `Frozen V2 Store Verification Architecture`, selects metadata-gated copied-workspace migration with V3 destination semantic verification and retained rollback as the production architecture. A V2-only target is allowed only as supporting test or fixture evidence unless a separate production extension architecture is approved. An authoritative frozen Core Data V2 model is deferred unless an exact historical model artifact or fixture-proven supported reconstruction is obtained. Tasks 3.22B through 3.22F are completed prerequisites for Task 3.22 completion. Production scoring remains Legacy, and Task 3.23 remains blocked.

Task 3.22C implementation record: the production boundary now identifies frozen Proposed V2 only by exact persistent-store metadata from the Task 3.22B evidence, preserves the complete source family, creates an operation-scoped copied workspace from the verified backup, attempts V3 candidate construction only in that workspace, and stops at destination verification pending. The boundary did not perform Task 3.22D semantic reconciliation, active-store replacement, canonical scoring writes, Legacy scoring retirement, Task 3.22 completion, or Task 3.23. Later Tasks 3.22D through 3.22F and final review completed the remaining prerequisite evidence. Production scoring remains Legacy, and Task 3.23 remains blocked.

Task 3.22D implementation record: the copied-workspace V3 candidate is now opened only through the current V3 schema boundary, verified against exact V3 persistent-store metadata evidence, reconciled against supplied pre-migration baseline facts, checked for Legacy counts, stable identities, relationships, ordering, score, substitution, media, team-creation evidence, source and backup immutability, and explicit zero rows in all five canonical scoring models. Missing baseline evidence, unreadable candidates, metadata mismatches, count mismatches, identifier mismatches, relationship mismatches, unexpected canonical rows, source or backup identity changes, journal inconsistency, unsupported evidence, and interruption fail closed with durable journal diagnostics. A passing candidate is marked only as destination verified and eligible for later acceptance; it is not promoted to the active store by this task. Later Tasks 3.22E and 3.22F supplied the remaining prerequisite evidence. Production scoring remains Legacy, and Task 3.23 remains blocked.

Task 3.22E acceptance record: fixture-based automated acceptance now exercises the frozen V2 fixture through exact metadata qualification, complete source-family preservation, copied-workspace V3 candidate construction, destination verification, Legacy count and baseline reconciliation, canonical-zero checks, interruption/resume, fail-closed metadata, preservation, migration, verification, and completed-journal recovery classifications. The passing acceptance boundary leaves the source fixture copy and retained V2 backup unchanged, marks the V3 candidate only as destination verified and eligible for later acceptance, prohibits baseball writes, and does not promote or replace the active source. Manual simulator or device verification was not performed because this task did not use a real or archived historical V2 store family and did not authorize isolated active-container launch with user data. Task 3.22F and final review completed the remaining prerequisite evidence. Production scoring remains Legacy, and Task 3.23 remains blocked.

Task 3.22F cleanup record: obsolete duplicate-checksum investigation scaffolding was reduced without changing migration semantics. The retained `-ScoreKeepSchemaDiagnostic` path is inventory-only and no longer emits launch-only noise or describes an attempted hosted migration; `ScoreKeepPhysicalMigrationExecutor.freshProposedComparison` now verifies the retained backup by supported metadata and opens only the copied V3 target for baseline comparison. The `semanticVerifierUnavailable.currentTargetV2AndV3DuplicateEffectiveChecksums` classification remains as legacy diagnostic compatibility and active fail-closed recovery meaning for unsupported V1/V2 semantic-open paths. Source preservation, exact V2 and V3 metadata gates, copied-workspace migration, destination verification, canonical-zero checks, rollback retention, fixture evidence, acceptance tests, Legacy production scoring, and the Task 3.23 block remain unchanged.

Final Task 3.22 review accepted the Path C safety substitute for the missing independent frozen V2 semantic open: exact metadata identity, source-family discovery and preservation, operation-scoped copied-workspace migration, V3 semantic reconciliation, canonical-zero verification, and retained rollback. Task 3.22 intentionally ends with the V3 candidate marked destination verified and eligible for later acceptance, without production promotion, active-store replacement, canonical scoring writes, or Legacy scoring retirement. Task 3.22 is complete; Task 3.23 remains blocked until separately authorized.

### Task 3.23 Completion Record - Scoring Transaction, Correction, Supersession, and Idempotency Adapter

Task 3.23 is complete as a bounded non-routed canonical scoring transaction adapter. The implemented boundary accepts value-only approved scoring requests, uses a dedicated SwiftData `ModelContext` with autosave disabled, performs duplicate and conflict lookup before insertion, allocates a game-scoped commit sequence inside the transaction, inserts canonical history, operation evidence, event envelope, payload, and accepted correction evidence as one pending graph, performs one explicit save for accepted mutations, and verifies completion through a fresh context. Returned results are value-only and no managed objects escape the boundary.

Idempotency is durable through `CanonicalScoringOperationEvidenceRecord.operationIdentity` and request fingerprints. Exact retries return deterministic already-applied evidence without duplicate canonical rows. Reuse of one operation identity for different payload or correction evidence fails closed as a conflict. Save failure rolls back pending inserts and reconciles by fresh durable lookup; near-concurrent duplicates converge to one accepted operation. Validation failure creates no durable canonical rows.

Corrections are append-only replacement operations. A correction creates a new operation, a new replacement event, a new payload, and a `CanonicalScoringCorrectionRecord` that identifies the original target and replacement event. The original event and payload remain unchanged. Missing targets, wrong-game targets, self-supersession, fingerprint mismatch, and already superseded targets fail closed. The current policy allows one accepted supersession per original event; replay interpretation and active corrected-state synthesis remain Task 3.24 or later work.

Production scoring remains Legacy. No SwiftUI scoring control, Legacy scoring writer, report, statistics, import/export, migration, startup promotion, or scoring-authority route calls this adapter. No V1 or V2 schema changed, no sixth canonical model was added, no historical Legacy game receives synthesized canonical history, and no selected Task 3.23 test constructs runtime-effective V2 and V3 together.

<!-- MARK: - 10. Phase 4 Task Catalog - Compatibility Import and Export -->
## 10. Phase 4 Task Catalog - Compatibility Import and Export

Phase 4 replaces compatibility import/export only after decode, validation, preview, and round-trip evidence pass. It must not invent new file keys or formats.

| Task | Purpose and scope | Evidence to inspect | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 4.1 `.ScoreKeep_Players` fixture coverage | Build roster fixture coverage. | Share/import/download routes. | 0.9. | Prepares roster compatibility evidence. | Fixture meanings reviewed; no production routing. | fixture-only |
| 4.2 `.ScoreKeep_Games` fixture coverage | Build game fixture coverage. | Seeded game, import/export, reports. | 0.10. | Prepares game compatibility evidence. | Fixtures include supported game shapes and warnings. | fixture-only |
| 4.3 Decode-only compatibility layer | Decode roster/game files without writes. | `Share*` transport models, ImportService. | 4.1, 4.2. | Introduces decode authority non-routed; legacy import retained. | Valid fixtures decode; invalid fixtures fail safely. | foundation/test |
| 4.4 Semantic validation | Validate decoded meaning before persistence. | Docs 21/27, domain/scoring. | 4.3, Phase 1. | Prepares validation authority. | Unsupported, ambiguous, missing, and conflicting values classified. | foundation/test |
| 4.5 Unknown and optional value handling | Preserve optional/future/unknown evidence safely. | Transport models and fixtures. | 4.4. | Prepares compatibility evidence authority. | Optional unknowns do not corrupt supported meaning. | foundation/test |
| 4.6 Malformed-file handling | Reject empty, truncated, HTML, unrelated, corrupt, and wrong-shape files safely. | Malformed fixtures, import routes. | 4.3, 0.11. | Verifies failure authority. | No local records changed on decode failure. | test-only |
| 4.7 Unsupported-file handling | Classify unsupported future or wrong file types. | Fixtures, UTType/plist routes. | 4.6. | Verifies unsupported authority. | Unsupported files explain limitation and preserve records. | test-only |
| 4.8 Import preview state | Prepare preview state for decoded records and warnings. | ImportPlayersView, docs 21/23. | 4.4. | Prepares preview authority; no writes. | Preview identifies created/updated/skipped/conflicts. | foundation/presentation prep |
| 4.9 Conflict review | Support duplicate/ambiguous/conflicting record review. | Existing import matching, docs 21. | 4.8. | Prepares conflict authority. | Conflict choices are explicit; no automatic destructive merge. | foundation/test |
| 4.10 Import confirmation | Apply a complete import plan coherently. | Persistence boundary, ImportService. | 4.9, Phase 3 transactions. | Introduces import application authority for bounded route. | Confirmed import writes only accepted plan; cancellation unchanged. | production-source/test |
| 4.11 Import cancellation | Verify cancel before confirmation leaves state unchanged. | Import presentation/service. | 4.8. | Verifies cancellation authority. | Existing records, media, purchases, allowances unchanged. | test-only |
| 4.12 Import persistence transaction | Verify import writes are coherent and recoverable. | Persistence, fixtures. | 4.10. | Verifies import transaction authority. | Partial failure classification and recovery verified. | test/migration |
| 4.13 Duplicate prevention | Prevent repeated import confirmation/download callback from duplicating records. | ImportService duplicate checks, UI. | 4.10. | Verifies idempotency authority. | Repeat request creates no duplicate team/player/game. | test-only |
| 4.14 Roster export | Project canonical roster meaning to existing `.ScoreKeep_Players` format. | ShareContentView, transport models. | 4.1, Phase 1/3 mapping. | Prepares export authority; legacy export retained. | Export does not mutate source records. | foundation/test |
| 4.15 Game export | Project canonical game meaning to existing `.ScoreKeep_Games` format. | ShareContentView, reports, scoring. | 4.2, Phase 2/3 mapping. | Prepares game export authority. | Export preserves supported game meaning and warnings. | foundation/test |
| 4.16 Round-trip verification | Verify import-export-import semantic preservation. | Fixtures, exports. | 4.14, 4.15. | Verifies compatibility authority. | Source meaning preserved; byte identity not assumed. | test-only |
| 4.17 Ownership-preserving access without entitlement | Verify source-data import/export is not blocked by current entitlement. | Purchase gates, import/export UI. | 4.10, 4.14. | Verifies ownership boundary. | Existing owned source data accessible independent of purchase state. | test-only |
| 4.18 File-open routing | Route file URLs and deep links through consistent validation/review. | Startup views, `onOpenURL`, Info.plist. | 4.8, 4.10. | Routes compatibility review; legacy routing retained until cutover. | Deep links do not bypass validation; file opens do not mutate before confirmation. | routing |
| 4.19 Import-route cutover | Route imports to accepted compatibility authority. | All import entry points. | 4.18, 4.12, 4.13. | Replaces import authority; legacy retained only if documented fallback. | One import writer; rollback defined. | routing |
| 4.20 Export-route cutover | Route exports to accepted compatibility authority. | Share/export entry points. | 4.16, 4.17. | Replaces export authority. | One export encoder per selected format; no source mutation. | routing |
| 4.21 Legacy codec retirement | Retire obsolete decode/encode paths after routed evidence passes. | Phase 11 gates. | 4.19, 4.20, Phase 11. | Retires legacy codec authority. | No active route depends on retired codec. | cleanup |

<!-- MARK: - 11. Phase 5 Task Catalog - Application-Service Workflow Coordination -->
## 11. Phase 5 Task Catalog - Application-Service Workflow Coordination

Phase 5 introduces workflow coordination boundaries. It must not invent concrete service names in this document; future implementation tasks choose concrete code shape only after inspecting repository coupling.

| Task | Purpose and scope | Current legacy coordinator evidence | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 5.1 Team creation workflow coordination | Coordinate create-team validation, persistence, media, navigation, and errors. | `ScoreContentView.addBlankTeam`, team list/edit views. | Phase 3 boundary. | Prepares workflow authority; legacy view retained. | Duplicate taps and failed saves do not create incoherent teams. | production-source/test |
| 5.2 Team editing workflow coordination | Coordinate current team edits without rewriting history. | `EditTeamView`, team/player/report paths. | 5.1, Phase 1 team meaning. | Prepares team-edit authority. | Historical games remain understandable. | production-source/test |
| 5.3 Player creation workflow coordination | Coordinate player creation, roster membership, media, and validation. | Player edit/list/roster views. | Phase 1 player/roster meaning. | Prepares player-create authority. | Duplicate names/numbers remain distinct. | production-source/test |
| 5.4 Player editing workflow coordination | Coordinate current player edits without rewriting historical participation. | `EditPlayerView`, reports, imports. | 5.3. | Prepares player-edit authority. | Completed game participation preserved. | production-source/test |
| 5.5 Roster editing workflow coordination | Coordinate add/remove/reorder/availability and paste/import handoff. | PlayersOnTeam, paste, roster views. | 5.1-5.4. | Prepares roster authority. | Roster changes do not mutate game facts. | production-source/test |
| 5.6 Batting-order change coordination | Coordinate roster hints vs game lineup batting order. | Player `batOrder`, lineup/setup/scoring. | 5.5, Phase 1 lineup. | Prepares batting-order workflow authority. | Batting order meaning is scoped to correct workflow. | production-source/test |
| 5.7 Lineup setup workflow coordination | Coordinate game-specific lineups and readiness. | StartingLineup/EditLineup/Game setup. | Phase 1 lineup, Phase 3. | Prepares lineup setup authority. | Incomplete lineups are explicit and recoverable. | production-source/test |
| 5.8 Game setup workflow coordination | Coordinate teams, date, location, inning count, Everyone Hits, pitchers, purchase gate. | `GameView`, `ScoreContentView`, edit game. | 5.7, Phase 9 prep for gates. | Prepares setup authority. | Setup failure does not create misleading records or consume allowance. | vertical slice/test |
| 5.9 Game creation workflow coordination | Coordinate accepted game creation transaction and allowance timing. | `ScoreContentView.handleCreateGame`. | 5.8, Phase 3 transaction, Phase 9 allowance prep. | Prepares game-creation authority. | Allowance consumes only after successful qualifying create. | vertical slice/test |
| 5.10 Live scoring workflow coordination | Coordinate scoring intents, validation, persistence, projection refresh, duplicate prevention. | `EditScoreView`, score views. | Phase 2, Phase 3. | Prepares scoring workflow authority; legacy scoring retained. | No production routing until Phase 7 gates. | production-source/test |
| 5.11 Correction workflow coordination | Coordinate correction planning, confirmation, persistence, and projection refresh. | Edit/correction score paths. | Phase 2 correction, Phase 3. | Prepares correction authority. | Canceled/failed correction leaves accepted state unchanged. | production-source/test |
| 5.12 Substitution workflow coordination | Coordinate substitutions and pitcher-related participation. | Replacement and pitcher staff views. | Phase 1 substitution/pitcher, Phase 2 replay. | Prepares substitution authority. | Earlier plays are not rewritten by future substitution. | production-source/test |
| 5.13 Game completion workflow coordination | Coordinate completion, warnings, final state, reports readiness. | Score/edit game views. | Phase 2 replay. | Prepares lifecycle authority. | Completion does not fabricate missing innings or hide warnings. | production-source/test |
| 5.14 Existing-game reopening coordination | Coordinate loading existing games, stale projections, repair warnings, and resume. | Game list/detail/scoring/report routes. | Phase 2 replay, Phase 3 read mapping. | Prepares reopen authority. | Opening does not implicitly repair or mutate records. | production-source/test |
| 5.15 Import workflow coordination | Coordinate acquisition, decode, preview, conflict, confirmation, persistence. | ImportPlayersView, ImportService, ShareContentView. | Phase 4 preview/application. | Prepares import workflow authority. | No writes before confirmation. | production-source/test |
| 5.16 Export workflow coordination | Coordinate export scope, validation, encoding, handoff, failure. | ShareContentView, reports. | Phase 4 export prep. | Prepares export workflow authority. | Export does not mutate source data or purchase state. | production-source/test |
| 5.17 MLB roster download coordination | Coordinate manifest, download, import review, allowance, offline/error states. | DownloadFiles, ShareContentView. | Phase 4 import review, Phase 9 allowance prep. | Prepares roster download authority. | Download allowance consumes only after qualifying success. | vertical slice/test |
| 5.18 Generated-output workflow coordination | Coordinate reports, PDFs, screenshots, share/print, purchase gates, failures. | Report/PDF/screenshot views. | Phase 8 projections, Phase 9 gates. | Prepares generated-output authority. | Generated failure leaves source records unchanged. | production-source/test |
| 5.19 Purchase interruption coordination | Preserve pending workflow through paywall, purchase, cancel, failure, and resume. | Paywall, PurchaseManager, gated views. | Phase 9 purchase state. | Prepares interruption authority. | Pending user work preserved and revalidated. | production-source/test |
| 5.20 Restore/status-check coordination | Coordinate restore/check status without mutating baseball records. | PurchaseManager, paywall. | Phase 9 entitlement. | Prepares restore workflow authority. | Restore uncertainty is not data loss or success. | production-source/test |
| 5.21 Allowance-backed continuation and pending restoration | Coordinate continuation after free allowance and app interruption. | Keychain counters, score/share flows. | 5.9, 5.17, Phase 9. | Prepares allowance workflow authority. | Idempotent continuation; no duplicate counter write. | vertical slice/test |

<!-- MARK: - 12. Phase 6 Task Catalog - Presentation and Navigation Replacement -->
## 12. Phase 6 Task Catalog - Presentation and Navigation Replacement

Phase 6 replaces presentation incrementally. Presentation tasks must not change domain, persistence, purchase, compatibility, generated-output, or migration authority unless routed through accepted services.

| Task | Purpose and scope | Evidence to inspect | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 6.1 Startup and root navigation | Replace or prepare startup/root routing without changing model container, seed, purchase, or deep-link behavior. | `ScoreKeepApp`, Start views, router. | Phase 5 routing boundaries. | Presentation authority only; legacy root retained until routed. | iPhone/iPad launch, deep links, announcements, seeding unchanged. | presentation/routing |
| 6.2 Team list presentation | Present team list prepared state. | TeamView/Start views. | 5.1. | Presentation replaces list only; team writes through accepted boundary. | Sorting/search/accessibility pass. | presentation |
| 6.3 Team editing presentation | Present team edit form and validation. | EditTeamView. | 5.2. | Presentation only. | Historical warning/validation shown; no direct hidden writes. | presentation |
| 6.4 Player editing presentation | Present player edit form and media state. | EditPlayerView/EditAllPlayerView. | 5.4. | Presentation only. | Duplicate names and media states accessible. | presentation |
| 6.5 Roster management presentation | Present roster membership, paste, active/inactive, and ordering. | PlayersOnTeam, Paste, roster views. | 5.5. | Presentation only. | Reorder alternatives and Dynamic Type pass. | presentation |
| 6.6 Lineup editing presentation | Present lineup setup and incomplete states. | StartingLineup/EditLineup. | 5.7. | Presentation only. | Incomplete lineup warnings clear and accessible. | presentation |
| 6.7 Game list and history presentation | Present game list, history, filters, warnings. | GameView/list views. | 5.14. | Presentation only. | Opening games does not repair records. | presentation |
| 6.8 Game setup presentation | Present setup state, purchase/allowance gate, validation. | GameView/EditGameView. | 5.8, 5.9. | Presentation only. | Failed/canceled setup preserves form state. | presentation |
| 6.9 Live-scoring shell presentation | Present prepared scoring state without owning baseball rules. | EditScoreView, ScoreGameView, PlayersToScoreView. | 5.10, Phase 2. | Presentation shell only; legacy live scoring retained until Phase 7. | Enabled actions reflect service state. | presentation |
| 6.10 Correction review presentation | Present correction effects, warnings, confirm/cancel. | EditScore/correction paths. | 5.11. | Presentation only. | Focus restoration and cancel behavior pass. | presentation |
| 6.11 Import review presentation | Present decoded records, conflicts, warnings, confirm/cancel. | ImportPlayersView. | 5.15, Phase 4. | Presentation only. | No write before confirmation; accessible review. | presentation |
| 6.12 Export presentation | Present scope, validation, progress, share handoff, failures. | ShareContentView. | 5.16. | Presentation only. | Export failure does not mutate records. | presentation |
| 6.13 Reports and statistics presentation | Present report projections and warnings. | Report/Pitcher report views. | Phase 8 projection prep. | Presentation only. | Statistics derive from accepted projection. | presentation |
| 6.14 Paywall presentation | Present purchase state, price, restore, cancel, pending. | PaywallView, PurchaseManager. | Phase 9 state prep. | Presentation only. | Pending workflow retained; accessible purchase UI. | presentation |
| 6.15 Error and recovery presentation | Present validation, persistence, migration, import, purchase, and generated-output errors. | Existing alerts/prints. | Phase 5 services. | Presentation only. | Errors distinguish unchanged state, accepted facts, and recovery needs. | presentation |
| 6.16 Offline and uncertain-state presentation | Present offline roster download, StoreKit, entitlement, and import uncertainty. | DownloadFiles, PurchaseManager, announcements. | 5.17, Phase 9. | Presentation only. | Offline-known and offline-uncertain are distinct. | presentation |
| 6.17 iPhone layout acceptance | Verify compact layouts for routed rewritten screens. | StartPhoneView, compact device UI. | Relevant presentation tasks. | Presentation verification. | No clipping/overlap; workflows equivalent. | test/presentation |
| 6.18 iPad layout acceptance | Verify regular layouts, split view, pointer, and keyboard context. | StartView, NavigationSplitView. | Relevant presentation tasks. | Presentation verification. | Device-class differences do not change product meaning. | test/presentation |
| 6.19 Keyboard and focus behavior | Verify focus order, restoration, keyboard alternatives, and no traps. | Forms, scoring, import, correction. | Relevant presentation tasks. | Accessibility/presentation verification. | Keyboard and focus outcomes pass where applicable. | test/presentation |
| 6.20 Navigation and deep-link routing | Route navigation and deep links through accepted boundaries. | `onOpenURL`, AppRouter, file open. | 6.1, Phase 4 file routing. | Routes presentation; no side-effect bypass. | Deep links cannot bypass validation or duplicate writers. | routing |

<!-- MARK: - 13. Phase 7 Task Catalog - Live Scoring Cutover -->
## 13. Phase 7 Task Catalog - Live Scoring Cutover

Phase 7 is the high-risk live-scoring cutover. Explicit cutover gates are mandatory before production routing changes.

| Task | Purpose and scope | Evidence to inspect | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 7.1 Prepared live-game state | Prepare current state for score, inning, outs, runners, batter, pitcher, warnings. | Score views, Phase 2 replay. | 5.10, 6.9. | Prepares live state authority; legacy live retained. | State agrees with replay and legacy comparison where expected. | production-source/test |
| 7.2 Semantic score state | Present score and line state from scoring authority. | ScoreGameView, reports. | 7.1, 2.7. | Prepares score display authority. | Stored score mismatch classified, not hidden. | production-source/test |
| 7.3 Enabled action state | Enable/disable scoring actions from validation. | Scoring controls. | 7.1, 2.2. | Prepares action-state authority. | Invalid actions unavailable with accessible reason. | production-source/test |
| 7.4 Scoring action submission | Submit ordinary scoring commands through accepted workflow. | EditScoreView and service boundary. | 7.3, 5.10. | Prepares scoring writer; legacy remains active until internal route. | One accepted event per intent. | production-source/test |
| 7.5 Additional-choice scoring actions | Handle runner movement, RBI, outs, earned-run, and other extra choices. | Existing additional-choice UI. | 7.4, 2.6, 2.7. | Prepares additional-choice authority. | Incomplete choices held, not saved as final facts. | production-source/test |
| 7.6 Rapid repeated input | Verify repeated taps, delayed UI updates, and retries. | Scoring UI and idempotency. | 7.4. | Verifies duplicate prevention. | No duplicate events. | test-only |
| 7.7 Duplicate prevention | Enforce idempotency across persistence retry and resume. | Phase 5/3 idempotency. | 7.6, 2.16. | Verifies scoring writer guard. | Duplicate command returns existing outcome or safe rejection. | test/production |
| 7.8 Persistence agreement | Verify scoring writes reload and replay identically. | Persistence, scoring fixtures. | 7.4, Phase 3. | Verifies scoring persistence authority. | Reloaded game matches accepted state. | test-only |
| 7.9 Correction entry | Route correction entry from live scoring to accepted correction workflow. | Correction UI. | 5.11, 6.10. | Prepares correction route. | Correction does not bypass replay. | routing/test |
| 7.10 Substitution entry | Route substitutions from live scoring to accepted workflow. | Replacement/Pitcher views. | 5.12. | Prepares substitution route. | Substitution affects current/future state only. | routing/test |
| 7.11 Background and resume | Verify scene interruption, save completion, and resume state. | Scene phase, scoring workflows. | 7.8. | Verifies resume authority. | No lost or duplicated event after interruption. | test-only |
| 7.12 Long-session behavior | Verify long games, many events, memory/performance, and navigation. | Long-game fixtures. | 7.11, 2.17. | Verifies live-scoring robustness. | Long session remains correct and usable. | test-only |
| 7.13 VoiceOver operation | Verify live scoring with VoiceOver semantics and announcements. | Scoring UI. | 7.3-7.5. | Accessibility verification. | Equivalent scoring without duplicate activation. | test/presentation |
| 7.14 Dynamic Type | Verify large text live scoring layouts. | iPhone/iPad score UI. | 7.3-7.5. | Accessibility verification. | No core action clipping or overlap. | test/presentation |
| 7.15 Keyboard or alternate input | Verify keyboard/pointer/alternate input where applicable. | iPad scoring UI. | 7.3-7.5. | Accessibility verification. | Alternate input produces same scoring results. | test/presentation |
| 7.16 iPhone verification | Verify complete live-scoring workflow on compact layout. | iPhone route. | 7.1-7.15. | Device acceptance. | Compact route passes scoring gates. | test-only |
| 7.17 iPad verification | Verify complete live-scoring workflow on regular layout. | iPad route. | 7.1-7.15. | Device acceptance. | iPad route passes scoring gates. | test-only |
| 7.18 Legacy comparison | Compare routed candidate against legacy outcomes and fixtures. | Harness, legacy records. | 7.1-7.17, 2.18. | Verifies cutover readiness. | Differences classified as expected, defect, or open question. | test-only |
| 7.19 Internal routing | Route live scoring internally/debug-only after gates, no production exposure if unsafe. | Routing boundary. | 7.18. | Internal routing authority; legacy production retained. | Disable path and no-dual-writer proof documented. | routing |
| 7.20 Production routing and legacy live-scoring retirement split | Route production only after acceptance; retire legacy later in Phase 11. | All live scoring routes. | 7.19 and explicit cutover approval. | Replaces live scoring authority; legacy retained only as rollback until retirement. | One live-scoring writer; rollback without data corruption. | routing then cleanup later |
| 7.21 Bounded production scoring routing after renewed persistence gate | Route at most one explicitly approved scoring command family to canonical production scoring after renewed readiness proves persistence foundations. | 2.21 readiness; 3.21-3.25 evidence; live scoring UI; manual regression evidence. | 2.21, 7.19, explicit production activation approval. | Routes only the approved bounded scoring authority; Legacy retained for all unrouted scoring and rollback. | One production scoring writer; no production caller invokes unrouted adapter paths; exact persistence mapping and correction behavior proven; rollback/disable documented; no existing game receives synthesized canonical history. | routing |

<!-- MARK: - 14. Phase 8 Task Catalog - Reports and Generated Output -->
## 14. Phase 8 Task Catalog - Reports and Generated Output

Phase 8 treats reports and generated files as derived output, separate from source-data export.

| Task | Purpose and scope | Evidence to inspect | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 8.1 Hitting-statistics projection | Derive hitting stats from scoring replay. | ReportView, Common result strings. | Phase 2 replay. | Prepares hitting projection authority; legacy reports retained. | Semantic totals match approved fixtures. | foundation/test |
| 8.2 Pitching-statistics projection | Derive pitching stats from replay and pitcher appearances. | PitcherRpt/ShowPitchRpt, Pitcher model. | Phase 2 pitcher projection. | Prepares pitching projection authority. | Unknown/incomplete pitcher states warned. | foundation/test |
| 8.3 Scorecard projection | Derive scorecard from ordered facts and warnings. | drawCard/drawAtbat/ScoreGame. | Phase 2 replay. | Prepares scorecard projection authority. | Scorecard does not own event truth. | foundation/test |
| 8.4 Report scope preparation | Define selected teams/games/player scopes and warnings. | Report selection views. | 8.1-8.3. | Prepares report workflow authority. | Scope errors do not mutate source records. | production-source/test |
| 8.5 PDF generation boundary | Generate PDFs from projections only. | GeneratePDF, PdfView. | 8.3, 8.4. | Prepares PDF authority; legacy PDF retained. | PDF generation failure leaves source unchanged. | production-source/test |
| 8.6 Print handoff | Verify print output handoff and cancellation. | PdfView/system print. | 8.5. | Prepares print handoff authority. | Cancellation/failure safe. | test/presentation |
| 8.7 Share handoff | Verify share handoff for generated reports/PDFs/screenshots. | ShareLink/report/screenshot paths. | 8.5. | Prepares share authority. | Share failure does not alter source data. | test/presentation |
| 8.8 Failure and cancellation | Classify output failure/cancel states. | Report/PDF save paths. | 8.5. | Verifies failure authority. | Source records and purchases unchanged. | test-only |
| 8.9 Generated-output accessibility | Verify reading order, labels, contrast, and alternatives. | Reports/PDF/scorecard. | 8.1-8.5. | Accessibility verification. | Generated output has accessible semantic equivalent where applicable. | test/presentation |
| 8.10 Long-name and pagination handling | Verify long names, large rosters, pagination, clipping. | GeneratePDF/report views. | 8.5. | Layout verification. | No unreadable truncation of essential facts. | test-only |
| 8.11 Semantic comparison | Compare generated output by baseball meaning rather than fragile bytes. | Fixtures, generated PDFs/reports. | 8.1-8.5. | Verifies output authority. | Expected totals, scope, and warnings match. | test-only |
| 8.12 Purchase gating | Route generated-output gates through purchase authority. | Paywall/report routes. | Phase 9 purchase state. | Prepares gate authority. | Existing source-data access remains separate. | production-source/test |
| 8.13 Existing-data access | Verify existing games and generated output access policy. | Docs 25, report routes. | 8.12. | Verifies ownership boundary. | Purchase uncertainty does not hide owned records. | test-only |
| 8.14 Separation from source-data export and routing | Ensure report generation does not replace `.ScoreKeep_*` source export. | ShareContentView, reports. | Phase 4 export, 8.5. | Routes generated-output authority. | Generated output and compatible export remain distinct. | routing/test |
| 8.15 Legacy report retirement | Retire duplicate report/PDF calculation paths after semantic evidence. | Phase 11 gates. | 8.14, Phase 11. | Retires legacy generated-output authority. | No active route uses retired calculation. | cleanup |

<!-- MARK: - 15. Phase 9 Task Catalog - Purchases, Entitlements, and Allowances -->
## 15. Phase 9 Task Catalog - Purchases, Entitlements, and Allowances

Phase 9 preserves purchase honesty and separates access state from baseball data. Game allowance and MLB download allowance writers remain separate unless a future approved implementation unifies only their policy interface.

| Task | Purpose and scope | Evidence to inspect | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 9.1 Product discovery | Discover current-season product and product-unavailable states. | PurchaseManager, StoreKit config. | 0.6. | Prepares product authority; legacy manager retained. | No hard-coded future price/product invention. | production-source/test |
| 9.2 Current-season classification | Classify current, prior, wrong, future, missing season. | Product ID prefix/year logic. | 9.1. | Prepares season authority. | Wrong season not presented as current access. | production-source/test |
| 9.3 Localized price state | Prepare loading, available, unavailable price states. | Product display/paywall. | 9.1. | Prepares price authority. | No stale or invented prices. | production-source/test |
| 9.4 Purchase request | Start purchase with preserved originating workflow. | Paywall, PurchaseManager. | 9.1-9.3, Phase 5 interruption. | Prepares purchase request authority. | No premium success before entitlement recognition. | production-source/test |
| 9.5 Purchase pending | Handle pending without success, allowance use, or duplicate action. | StoreKit pending path. | 9.4. | Verifies pending authority. | Pending workflow preserved. | test-only |
| 9.6 Purchase cancellation | Handle cancellation as ordinary outcome. | PurchaseManager/paywall. | 9.4. | Verifies cancellation authority. | Workflow and allowances unchanged. | test-only |
| 9.7 Purchase failure | Handle failure and retry. | PurchaseManager/paywall. | 9.4. | Verifies failure authority. | Failure does not mutate baseball records. | test-only |
| 9.8 Entitlement recognition | Recognize confirmed current-season entitlement. | Keychain entitlement, StoreKit transaction. | 9.4. | Introduces entitlement authority. | Entitlement changes access only, not records. | production-source/test |
| 9.9 Restore or Check Status | Classify restore/status outcomes. | `restore`, AppStore sync, local entitlement. | 9.8. | Prepares restore authority. | No data ownership confusion. | production-source/test |
| 9.10 Offline-known entitlement | Preserve previously confirmed access offline. | Keychain, scene refresh. | 9.8. | Prepares offline-known authority. | Offline does not erase active local evidence. | test-only |
| 9.11 Offline uncertainty | Classify unknown/unavailable status honestly. | StoreKit/network failure. | 9.9. | Prepares uncertainty authority. | Uncertainty is not no purchase or success. | test-only |
| 9.12 Prior-season recognition | Recognize prior pass without current access. | Product suffix/expiration. | 9.2, 9.8. | Prepares prior-season authority. | Prior purchase not sold as current access. | test-only |
| 9.13 Wrong-season prevention | Block purchase/use of wrong-season product. | Product ID guard. | 9.2. | Verifies prevention authority. | Wrong product clears unsafe state and explains issue. | test-only |
| 9.14 Existing Keychain-state interpretation | Interpret existing entitlement and counters conservatively. | `seasonPassMaxExpirationISO8601`, counters. | 9.8. | Prepares migration evidence. | Invalid values do not fabricate access or reset data silently. | test/migration |
| 9.15 Free game allowance | Read and present free game allowance. | `freeGameCreatesRemainingKC`, ScoreContentView. | 9.14. | Prepares free-game allowance authority; legacy writer retained. | Remaining count shown without reset except debug-only behavior classification. | production-source/test |
| 9.16 MLB download allowance | Read and present MLB download allowance. | `mlbDownloadCountKC`, ShareContentView. | 9.14. | Prepares download allowance authority. | Count and limit policy verified separately from game allowance. | production-source/test |
| 9.17 Qualifying-action identity | Define what counts as successful game create or roster download. | Score/create and download/import flows. | 9.15, 9.16, Phase 5. | Prepares qualifying-action authority. | Failed/canceled/pending actions do not consume allowances. | foundation/test |
| 9.18 Allowance idempotency | Prevent duplicate allowance consumption. | Keychain counter, repeated taps, retries. | 9.17. | Verifies allowance writer guard. | Duplicate qualifying intent consumes at most once. | test-only |
| 9.19 Game-creation allowance transaction | Route game-create allowance write after successful persisted create. | ScoreContentView, persistence. | 5.9, 9.18. | Replaces game allowance writer. | One game allowance writer; rollback defined. | routing/test |
| 9.20 Roster-download allowance transaction | Route roster-download allowance write after successful qualifying download/import boundary as approved. | ShareContentView, DownloadFiles, import review. | 5.17, 9.18. | Replaces download allowance writer. | One download allowance writer; exact timing documented. | routing/test |
| 9.21 Paywall interruption and resume | Resume gated workflows after entitlement or allowance path. | Paywall, game/report/download flows. | 9.4-9.20. | Routes interruption authority. | Revalidation prevents duplicate actions. | routing/test |
| 9.22 Purchase-routing, allowance-writer, legacy retirement split | Route purchase/allowance decisions, then retire legacy counters/writers later. | All gated workflows. | 9.21 and Phase 11 gates. | Replaces purchase/allowance authority; legacy retirement separate. | No dual allowance writer; no reset. | routing then cleanup |

<!-- MARK: - 16. Phase 10 Task Catalog - Accessibility Consolidation -->
## 16. Phase 10 Task Catalog - Accessibility Consolidation

Phase 10 consolidates cross-workflow accessibility after individual workflows already include basic accessibility acceptance. It does not defer accessibility until the end.

| Task | Purpose and scope | Evidence to inspect | Prereq | Authority and legacy | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- | --- |
| 10.1 VoiceOver semantic review | Review labels, values, traits, announcements across rewritten workflows. | Routed rewritten screens. | Phase 6/7/8/9 routed workflows. | Accessibility verification authority. | Essential workflows understandable by VoiceOver. | test/presentation |
| 10.2 Focus order | Verify logical focus order. | Forms, scoring, import, paywall. | 10.1. | Accessibility verification. | No confusing order or traps. | test |
| 10.3 Focus restoration | Verify return focus after sheets, errors, corrections, purchases. | Presentation flows. | 10.2. | Accessibility verification. | Focus returns to meaningful control/state. | test |
| 10.4 Dynamic Type | Verify large text across workflows. | iPhone/iPad UI. | Relevant presentation tasks. | Accessibility verification. | Essential text and controls do not overlap. | test |
| 10.5 Increased Contrast | Verify contrast-sensitive states. | UI/report screens. | Relevant presentation tasks. | Accessibility verification. | Meaning remains readable. | test |
| 10.6 Differentiate Without Color | Verify color-independent meaning. | Score, reports, warnings, paywall. | Relevant presentation tasks. | Accessibility verification. | No color-only decisions. | test |
| 10.7 Reduced Motion | Verify animation alternatives and motion safety. | Navigation/scoring/report UI. | Relevant presentation tasks. | Accessibility verification. | Motion reduction does not remove status. | test |
| 10.8 Touch-target and spacing review | Verify tappable controls and dense score UI. | Scoring, toolbar, forms. | Relevant presentation tasks. | Accessibility verification. | Targets usable on iPhone/iPad. | test |
| 10.9 Gesture alternatives | Verify non-gesture alternatives. | Reordering, scorecard, correction. | Relevant presentation tasks. | Accessibility verification. | Required actions are not gesture-only. | test |
| 10.10 Reordering alternatives | Verify roster/lineup order alternatives. | Roster/lineup UI. | Phase 6 roster/lineup. | Accessibility verification. | Reordering possible without drag-only interaction. | test |
| 10.11 Keyboard navigation | Verify Full Keyboard Access where applicable. | iPad workflows. | Phase 6 keyboard. | Accessibility verification. | Keyboard can complete essential workflows. | test |
| 10.12 Pointer behavior | Verify pointer/trackpad behavior. | iPad controls. | Phase 6 iPad. | Accessibility verification. | Pointer targets and hover/focus states coherent. | test |
| 10.13 Switch Control and Voice Control review | Review essential workflows for alternate control. | Core workflows. | 10.1-10.12. | Accessibility verification. | No essential action lacks an accessible path. | test |
| 10.14 Live-scoring announcement strategy | Verify scoring state announcements are useful and not noisy. | Live scoring. | Phase 7 accessibility. | Accessibility verification. | Announcements avoid duplicate commands and preserve context. | test |
| 10.15 Correction accessibility | Verify correction review and cascade explanation. | Correction UI. | Phase 7 correction. | Accessibility verification. | Correction effects and cancel/confirm accessible. | test |
| 10.16 Import review accessibility | Verify conflict review, warning, confirm/cancel. | Import UI. | Phase 4/6 import. | Accessibility verification. | Import review can be completed accessibly. | test |
| 10.17 Report accessibility | Verify reports, PDFs, screenshots alternatives. | Phase 8 output. | Phase 8. | Accessibility verification. | Generated facts have accessible reading path. | test |
| 10.18 Purchase accessibility | Verify paywall, price, pending, restore, errors. | Phase 9 UI. | Phase 9. | Accessibility verification. | Purchase outcomes distinguish states accessibly. | test |
| 10.19 iPhone and iPad accessibility acceptance | Run device-class accessibility acceptance. | Routed workflows. | 10.1-10.18. | Accessibility acceptance authority. | Compact and regular layouts pass. | test |
| 10.20 Cross-workflow accessibility regression run | Run full accessibility regression across routed workflows. | All rewritten workflows. | 10.19. | Accessibility release evidence. | Remaining gaps classified before release. | test |

<!-- MARK: - 17. Phase 11 Task Catalog - Legacy Retirement and Cleanup -->
## 17. Phase 11 Task Catalog - Legacy Retirement and Cleanup

Phase 11 cleanup occurs only after replacement evidence passes. Cleanup tasks are not a place for unrelated fixes or broad refactors.

| Task | Purpose and scope | Required predecessor | Authority affected | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- |
| 11.1 Retire legacy scoring authority | Remove or isolate obsolete scoring writer/calculation paths only for operations with proven canonical replacements. | 7.21 for every affected operation plus Phase 11 gate. | Retires legacy scoring authority, distinct from Task 3.20 persistence-adapter retirement. | Every affected operation has routed canonical proof, migration/compatibility evidence, report/export parity, correction support, and no active route writing legacy scoring. | cleanup |
| 11.2 Retire legacy persistence adapters | Remove obsolete persistence adapters/writers. | Phase 3 migration/persistence acceptance. | Retires legacy persistence authority. | Existing data migration/read evidence remains valid. | cleanup |
| 11.3 Retire legacy import paths | Remove obsolete import application routes. | Phase 4 import-route cutover. | Retires legacy import authority. | File-open/download/seed imports still route safely. | cleanup |
| 11.4 Retire legacy export paths | Remove obsolete export encoders. | Phase 4 export-route cutover. | Retires legacy export authority. | Roster/game export and round trip still pass. | cleanup |
| 11.5 Retire legacy purchase decision paths | Remove obsolete purchase-state decisions from views. | Phase 9 routing. | Retires legacy purchase decision authority. | Paywall/status/gates still pass. | cleanup |
| 11.6 Retire legacy allowance writers | Remove obsolete free-game and download counter writers. | 9.19 and 9.20. | Retires allowance writer authority. | One writer per allowance remains; no counter reset. | cleanup |
| 11.7 Retire duplicate generated-output paths | Remove obsolete report/PDF calculations. | Phase 8 routing. | Retires generated-output authority. | Semantic report/PDF verification passes. | cleanup |
| 11.8 Remove obsolete debug reset behavior | Remove or isolate debug-only resets that can affect release state. | Phase 9 allowance acceptance. | Retires debug reset authority. | Release build cannot reset user counters. | cleanup |
| 11.9 Remove dead routing | Remove unused navigation, deep link, and file-open routes. | Phase 6/4 routing acceptance. | Retires routing authority. | No supported route lost. | cleanup |
| 11.10 Remove obsolete compatibility shims | Remove no-longer-needed compatibility shims after migration/export evidence. | Phase 4 and Phase 3 acceptance. | Retires compatibility shim authority. | Supported files remain readable/exportable. | cleanup |
| 11.11 Remove unused presentation state | Remove stale SwiftUI state that no longer owns side effects. | Presentation replacements accepted. | Retires presentation state. | No behavior change beyond accepted replacement. | cleanup |
| 11.12 Review deep links and file-open routes | Verify final deep link and file-open map. | 11.3, 11.9. | Verifies routing authority. | Deep links and files route only through accepted boundaries. | cleanup/test |
| 11.13 Review stored-data migration dependencies | Verify no removed code is needed for existing records. | 11.2, migration evidence. | Verifies migration dependency. | Existing stores remain readable. | cleanup/test |
| 11.14 Update documentation | Update approved docs only if implementation evidence requires catalog/design amendments. | Retirement evidence. | Documentation authority. | Documentation changes are separate and accurate. | documentation-only |
| 11.15 Full regression acceptance after cleanup | Run complete regression after retirement. | 11.1-11.14. | Release evidence. | Build, tests, fixtures, compatibility, migration, accessibility, purchase, generated output pass or blockers recorded. | test |

<!-- MARK: - 18. Phase 12 Task Catalog - Release Candidate and Rewrite Completion -->
## 18. Phase 12 Task Catalog - Release Candidate and Rewrite Completion

Phase 12 verifies rewrite completion. It does not invent App Store submission procedures beyond repository and approved product evidence.

| Task | Purpose and scope | Prereq | Authority and evidence | Verification and exit | Kind |
| --- | --- | --- | --- | --- | --- |
| 12.1 Release build verification | Verify release build identity and build health. | Phase 11 acceptance. | Build evidence. | Release configuration builds without unintended debug behavior. | test |
| 12.2 Full scoring regression | Run accepted scoring scenarios. | Phase 7. | Scoring evidence. | Scoring blockers classified. | test |
| 12.3 Replay and correction regression | Run replay/correction scenarios. | Phase 2/7. | Replay evidence. | Corrections preserve facts and recalc projections. | test |
| 12.4 Migration rehearsal | Rehearse supported migration cases. | Phase 3. | Migration evidence. | Empty/existing/interrupted/repeated/failed cases pass or block. | migration/test |
| 12.5 Compatibility regression | Run `.ScoreKeep_Players` and `.ScoreKeep_Games` fixture regression. | Phase 4. | Compatibility evidence. | Decode/encode/round-trip/malformed results pass. | test |
| 12.6 Import and export acceptance | Verify full import/export workflows. | 12.5. | Workflow evidence. | Owned source-data access preserved. | test |
| 12.7 Purchase and allowance acceptance | Verify product, entitlement, restore, counters, gates. | Phase 9. | Purchase evidence. | No reset, no dual writer, honest states. | test |
| 12.8 Offline acceptance | Verify offline-known, offline-uncertain, downloads, purchase status. | Phase 9/5. | Offline evidence. | Offline states preserve records and pending work. | test |
| 12.9 Interruption and resume acceptance | Verify background, purchase interruption, import/export/scoring resume. | Phase 5/7/9. | Resume evidence. | No duplicate or lost side effects. | test |
| 12.10 Generated-output review | Verify reports, PDFs, screenshots, print/share. | Phase 8. | Output evidence. | Semantic output passes and source records unchanged. | test |
| 12.11 Accessibility acceptance | Run accessibility acceptance. | Phase 10. | Accessibility evidence. | Gaps classified; blockers resolved. | test |
| 12.12 iPhone device-class review | Review compact device workflows. | Phase 6/7/10. | Device evidence. | iPhone workflows pass. | test |
| 12.13 iPad device-class review | Review regular device workflows. | Phase 6/7/10. | Device evidence. | iPad workflows pass. | test |
| 12.14 Known-issue classification | Classify remaining issues. | 12.1-12.13. | Release evidence. | Blockers separated from accepted known issues. | documentation/test |
| 12.15 Release-blocker review | Decide whether blockers prevent release recommendation. | 12.14. | Release evidence. | No hidden blocker remains unresolved. | documentation/test |
| 12.16 Debug and test behavior audit | Audit debug-only, seeded, fixture, StoreKit test behavior. | 12.1. | Configuration evidence. | Test/debug behavior does not leak into release. | test |
| 12.17 Support-diagnostic review | Verify supportable diagnostics without analytics invention. | Phase 3/4/9/12. | Diagnostics evidence. | Errors are privacy-conscious and actionable. | test/documentation |
| 12.18 Final legacy-authority audit | Confirm no unintended legacy writer remains. | Phase 11. | Authority evidence. | Side-effect inventory shows one writer per behavior. | documentation/test |
| 12.19 Rewrite-completion evidence | Assemble evidence that approved architecture owns product behavior. | 12.1-12.18. | Completion evidence. | Evidence supports rewrite-complete claim. | documentation-only |
| 12.20 Release recommendation | Recommend release, no-release, or release with explicit known issues. | 12.19. | Final acceptance evidence. | Recommendation tied to evidence, not time estimates. | documentation-only |

<!-- MARK: - 19. Dependency Matrix -->
## 19. Dependency Matrix

The matrix is conceptual. Future prompts must still inspect the repository before changes.

| Task group | Required predecessor | May proceed in parallel with | Authority affected | Verification gate | Cutover dependency | Retirement dependency |
| --- | --- | --- | --- | --- | --- | --- |
| Phase 0 inventories | Clean branch/status inspection | Fixture curation planning | Evidence only | Build/test/inventory records | None | None |
| Phase 0 fixtures | Route inventories and fixture location decision | Accessibility and generated-output inventories | Verification evidence | Fixture decode or documented gaps | None | None |
| Phase 1 domain foundations | Phase 0 model/scoring/compatibility inventories | Compatibility decode-only work after fixture coverage | Canonical meaning | Domain scenarios and mapping checks | No routing before Phase 2/3/5 | No retirement |
| Phase 2 scoring foundations | Phase 1 event, runner, inning, lineup, pitcher meaning | Persistence read mapping and scoring fixtures | Scoring/replay meaning | Scoring/replay/correction fixtures | Phase 7 live-scoring gates | Phase 11 scoring retirement |
| Phase 3 persistence boundary | Phase 0 persistence inventory and Phase 1 mapping | Compatibility decode and migration fixtures | Persistence/migration | Round-trip, transaction, migration evidence | Workflow routing after Phase 5 | Phase 11 persistence retirement |
| Phase 3 canonical scoring persistence | 3.21 design before 3.22 schema/storage, the frozen V2 verification architecture decision and completed 3.22A-3.22F prerequisite implementation before final 3.22 acceptance, 3.22 before 3.23 adapter, 3.23 before 3.24 replay verification, 3.24 before 3.25 rehearsal | Non-routed presentation and report projection work that does not write scoring facts | Canonical scoring event, operation, correction, supersession, idempotency, and replay persistence | Versioned storage, frozen V2 verification decision, one-save adapter, relaunch replay, malformed fail-closed, disposable rehearsal | 2.21 renewed scoring readiness, then 7.21 bounded production scoring routing | 11.1 scoring retirement only after routed proof for every affected operation |
| Phase 4 compatibility decode | Compatibility fixtures | Domain mapping, malformed fixtures | Decode/validation | Decode, validation, safe failure | Import/export routing after application transaction evidence | Phase 11 codec retirement |
| Phase 4 import/export application | Phase 3 transaction boundary and Phase 4 decode/preview | Presentation import/export preparation | Import/export writer | Confirmation/cancel/round-trip/idempotency | File-open and import/export cutovers | Phase 11 import/export retirement |
| Phase 5 application services | Relevant domain, scoring, persistence, purchase, compatibility boundaries | Presentation preparation for non-routed screens | Workflow coordination | Service-level idempotency and unchanged-record checks | Required before high-risk routing | Retire direct view side effects in Phase 11 |
| Phase 6 presentation | Relevant Phase 5 workflow boundary | Accessibility review, generated-output projections | Presentation only | Device, accessibility, no-side-effect checks | Navigation/deep-link routing after service gates | Retire legacy presentation state in Phase 11 |
| Phase 7 live scoring | Phase 2 scoring, Phase 3 persistence, Phase 5 scoring workflow, Phase 6 shell | Reports semantic verification and accessibility review | Live scoring writer | Cutover gate: comparison, persistence, duplicate, resume, accessibility | Internal then production routing | Phase 11 live-scoring retirement |
| Phase 8 generated output | Phase 2 replay/projections and Phase 5 output workflow | Purchase gating and presentation output screens | Derived output | Semantic report/PDF/share/failure checks | Generated-output routing | Phase 11 output retirement |
| Phase 9 purchases/allowances | Phase 0 purchase inventory and Phase 5 interruption points | Presentation paywall preparation | Purchase decision and allowance writers | StoreKit, Keychain, season, idempotency, no-reset checks | Gate and counter routing | Phase 11 purchase/counter retirement |
| Phase 10 accessibility | Routed or near-routed rewritten workflows | Release-candidate fixture runs | Accessibility acceptance | Workflow accessibility evidence | Blocks release acceptance where essential workflows fail | None |
| Phase 11 cleanup | Replacement routed and verified | Documentation updates | Retired legacy authority | Full regression after cleanup | None | Requires replacement evidence |
| Phase 12 release candidate | Phase 11 cleanup and acceptance | Known-issue documentation | Release evidence | Full acceptance matrix | None | Final legacy audit |

Cutover-specific dependencies:

| Cutover | Must not begin until | Required gate | Legacy retained until |
| --- | --- | --- | --- |
| Scoring authority | Domain, replay, persistence, workflow, comparison evidence pass. | No duplicate scoring writer; replay and correction fixtures pass. | Phase 11 scoring retirement. |
| Canonical scoring persistence | 3.21-3.25 pass, including storage decision, versioned implementation if required, transaction adapter, persisted replay verification, and disposable rehearsal. | Durable event ordering, operation identity, duplicate/conflict evidence, correction/supersession evidence, relaunch replay, and one explicit save with autosave controlled. | Phase 11 scoring retirement only after production routing proof. |
| Persistence authority | Transaction, round-trip, migration, purchase separation evidence pass. | Existing records reload and migrate safely. | Phase 11 persistence retirement. |
| Import authority | Decode, preview, conflict, confirmation, cancel, duplicate evidence pass. | No write before confirmation; malformed files safe. | Phase 11 import retirement. |
| Export authority | Projection, encoding, round-trip, ownership evidence pass. | Export does not mutate source records. | Phase 11 export retirement. |
| Live scoring | Internal routing, long session, device, resume, duplicate, accessibility evidence pass, plus 2.21 renewed readiness after 3.21-3.25 for any canonical production scoring route. | Explicit production routing approval; at most one bounded candidate in 7.21 until broader evidence exists. | Phase 11 live-scoring retirement. |
| Purchase and allowance | Product, entitlement, Keychain, idempotency, workflow preservation evidence pass. | One writer per allowance; no reset. | Phase 11 purchase/counter retirement. |
| Generated output | Semantic projections, PDF/share/failure/accessibility evidence pass. | Generated output separated from source-data export. | Phase 11 report retirement. |

<!-- MARK: - 20. Critical Path -->
## 20. Critical Path

The conceptual critical path is:

1. Phase 0 baseline evidence, side-effect inventory, fixture gaps, and persistence isolation.
2. Phase 1 canonical domain foundations for identity, game participation, lineup, event, runner, pitcher, and substitution meaning.
3. Phase 2 scoring, replay, correction, duplicate prevention, and legacy comparison harness.
4. Phase 3 persistence boundary, round-trip verification, migration fixtures, and purchase/allowance separation.
5. Phase 3 canonical scoring persistence sequence: requirements and schema decision, versioned implementation if required, scoring transaction/idempotency adapter, persisted replay verification, and disposable rehearsal.
6. Phase 2 renewed scoring-authority readiness after canonical scoring persistence foundations.
7. Phase 5 application-service coordination for game setup, game creation, live scoring, correction, substitution, and resume.
8. Phase 6 live-scoring shell and navigation preparation.
9. Phase 7 internal live-scoring routing, bounded production scoring routing, and cutover gates.
10. Phase 4 migration and compatibility acceptance for import/export and file-open routes, where not already completed earlier.
11. Phase 9 purchase and allowance cutover for game creation, MLB downloads, paywall interruption, and restore/status behavior.
12. Phase 8 generated-output semantic acceptance and routing.
13. Phase 10 accessibility consolidation across routed workflows.
14. Phase 11 legacy retirement and cleanup.
15. Phase 12 release-candidate acceptance and release recommendation.

This path refines Document 28 by making live scoring depend on domain, scoring, canonical scoring persistence, application-service coordination, presentation shell, and cutover gates. Compatibility fixture work, purchase verification, generated-output semantic comparison, and accessibility review can start earlier, but they still block final release if unresolved.

<!-- MARK: - 21. Parallel Workstreams -->
## 21. Parallel Workstreams

Parallel work is safe when it reads, classifies, previews, verifies, or prepares state without changing the accepted user-facing writer. It becomes risky when two tasks can write the same records, consume the same allowance, route the same import/export action, or calculate the same authoritative score.

Safe parallel workstreams after Phase 0 inventories include compatibility fixture curation, malformed fixture curation, accessibility baseline review, generated-output semantic inventory, purchase-state inventory, migration fixture planning, and non-routed presentation preparation.

Safe parallel workstreams after Phase 1 domain foundations include decode-only compatibility work, persisted-to-canonical read mapping, scoring scenario tests, and generated-output projection planning.

Safe parallel workstreams after Phase 2 replay exists include report projection verification, export projection verification, live-scoring prepared-state work, and correction review presentation, provided none of them become active writers.

Canonical scoring persistence design, frozen V2 verification architecture decision, implementation, adapter, persisted replay verification, disposable rehearsal, renewed scoring readiness, production routing, and Legacy scoring retirement must remain ordered as 3.21, Task 3.22A architecture decision, completed Task 3.22 storage and migration foundation, 3.23, 3.24, 3.25, 2.21, 7.21, and 11.1 for affected scoring operations. The architecture-decision task did not itself complete or resume Task 3.22; Tasks 3.22B through 3.22F supplied the required prerequisite evidence. Task 3.20 may retire only obsolete persistence adapters with replacement and migration evidence; it does not authorize canonical scoring persistence or Legacy scoring removal.

Unsafe parallel work includes two active scoring writers, two import application paths, two export encoders for the same selected format, two allowance writers for the same allowance category, physical migration while legacy code still writes uncoordinated records, and presentation replacement that bypasses accepted application-service validation.

<!-- MARK: - 22. One-Authority and Coexistence Protections -->
## 22. One-Authority and Coexistence Protections

For every side effect, a task must identify the active authority before and after the change. Side effects include scoring event creation, scoring correction, game creation, team/player/roster writes, lineup writes, pitcher writes, substitution writes, import application, export file creation, generated PDF/report/screenshot creation, purchase decision, entitlement recognition, allowance consumption, seed import, migration, repair, deletion, and routing.

Legacy and rewritten code may coexist as long as only one active writer owns a side effect for one operation. Read-only comparison is allowed. Preview is allowed. Non-routed foundations are allowed. Mirrored writes are not allowed unless a later approved design explicitly defines reconciliation and rollback.

Retirement requires replacement verification, route audit, migration/compatibility evidence, no hidden deep-link or file-open dependency, no purchase or allowance reset, and full regression after cleanup.

<!-- MARK: - 23. Production Fixes Discovered During Implementation -->
## 23. Production Fixes Discovered During Implementation

If a future task discovers an unrelated production defect, the defect must be diagnosed separately. It must not be hidden inside the current implementation task. A minimal behavior-preserving fix is preferred. Verification must be specific to the defect. The fix should receive a separate commit where practical.

Examples include compile failures, unrelated warnings, broken project references, stale Xcode state, broken scheme state, unrelated import failures, unrelated accessibility defects, and stale generated files. The catalog dependency state changes only if the defect affects readiness for the current or downstream task.

If a repository or formatting tool changes unrelated files, revert only tool-created unrelated changes. Do not discard preexisting user work.

<!-- MARK: - 24. Task Completion Reporting -->
## 24. Task Completion Reporting

Future implementation task reports must include task number and title, governing design documents and sections, exact files changed, authority introduced/prepared/replaced/routed/retired, legacy path retained, behavior preserved or intentionally changed, assumptions, unresolved questions, build result, test result, fixture result, compatibility result, migration result where applicable, accessibility result where applicable, purchase or allowance result where applicable, commit hash, commit message, GitHub push result, direct remote verification, local tracking status, final working-tree status, and confirmation that unrelated files did not change.

Reports must state whether production source, tests, fixtures, seeded data, StoreKit configuration, project settings, schemes, build configurations, existing documents, Git configuration, or files inside `.git` changed. If any of those changed, the report must explain why the task allowed it.

<!-- MARK: - 25. Source-Control Requirements for Future Tasks -->
## 25. Source-Control Requirements for Future Tasks

Future implementation prompts must confirm `scorekeep-next`, inspect the working tree before changes, preserve unrelated user work, avoid force push, avoid editing files inside `.git`, review the complete diff, commit one coherent task, push to `origin`, and verify the actual remote `scorekeep-next` branch directly.

Stale `origin/scorekeep-next` must be treated separately from the actual GitHub push result. If direct remote verification shows the new commit but local tracking is stale, do not push again. Run `git fetch origin scorekeep-next`, then recheck local `HEAD`, local `origin/scorekeep-next`, and the directly verified remote head. Avoid repushing solely because Xcode displays "ahead." Do not delete, recreate, reset, or force-push branches. Do not modify Git configuration or manually edit anything inside `.git`.

The authoritative success condition is that the directly verified remote `scorekeep-next` branch contains the new commit.

<!-- MARK: - 26. Risks and Open Questions -->
## 26. Risks and Open Questions

Exact implementation task boundaries may need adjustment where repository code is tightly coupled, especially in live scoring, import/export, reports, and purchase-gated workflows.

Fixture work may require a dedicated support directory, but this document does not choose that directory. The exact canonical implementation structure, exact persistence technology, exact coexistence routing mechanism, exact migration source versions, exact PDF comparison method, exact accessibility automation coverage, exact device matrix, exact allowance timing for roster downloads, and whether any task requires a temporary compatibility adapter remain unresolved implementation choices.

The current repository shows no checked-in `.ScoreKeep_Players` fixture, so roster compatibility readiness depends on deliberate fixture curation. The seeded `.ScoreKeep_Games` file provides useful game evidence but is not broad enough for scoring, migration, and import/export release acceptance.

Current purchase code derives the current product ID from the calendar year. Future tasks must control date and season state in verification without inventing product identifiers or resetting user entitlement.

The current debug-only free-game reset behavior is repository evidence and risk. Future tasks must classify and eventually isolate or retire it without resetting real user allowances.

The task catalog itself may need an update process as implementation reveals new evidence. Such updates should be documentation-only tasks that explain why a dependency changed.

<!-- MARK: - 27. Recommended First Implementation Task -->
## 27. Recommended First Implementation Task

Recommended next implementation task after this amendment: `3.21 Canonical scoring persistence requirements and schema decision`.

This is the required next task because Task 2.20 completed as a blocked preparation verdict and confirmed that production scoring cannot route until exact canonical scoring-event persistence, durable operation identity, correction and supersession evidence, idempotency evidence, relaunch-safe replay source, and schema-version policy are designed. Task 3.20 remains Legacy persistence retirement and is not authority to invent scoring persistence.

Task 3.21 may inspect Documents 17 through 24 and 26 through 29, scoring and persistence verification baselines, current SwiftData model evidence, current scoring route evidence, and Apple SwiftData save/autosave documentation. It may produce a documentation-only requirements and schema-decision artifact or update the catalog if repository convention requires it.

Task 3.21 must not implement code, schemas, migrations, adapters, tests, production routing, Legacy retirement, or synthesized canonical history for existing games. Verification should confirm the branch, working tree, authoritative evidence inspected, no unsupported implementation claims, documentation-only diff, and that production scoring remains Legacy.

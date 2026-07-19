# ScoreKeep Technical Design — 23 Application Services and Workflow Design

<!-- MARK: - 1. Purpose -->
## 1. Purpose

This document defines the application-services layer for the ScoreKeep rewrite. Application services coordinate user intentions across SwiftUI presentation, canonical domain records, scoring-engine replay, persistence and migration, import/export compatibility, scorecard projections, reports and PDFs, purchases and free allowances, settings, error recovery, navigation, and workflow-state preservation.

The design follows Documents 17 through 22. It treats legacy code as behavioral and compatibility evidence, not as the architecture to preserve. It does not define concrete Swift types, production APIs, protocols, actors, dependency-injection frameworks, database implementations, or source files.

The purpose of the layer is to keep SwiftUI views from owning baseball rules, persistence transactions, compatibility interpretation, entitlement decisions, or generated-output policy. Views and view models may collect intent and display prepared state. Application services decide how that intent is validated, coordinated, persisted, refreshed, warned about, rejected, or resumed.

<!-- MARK: - 2. Application-Service Principles -->
## 2. Application-Service Principles

Application services receive explicit user intent from views or view models. They request domain or scoring-engine validation, coordinate persistence transactions, call compatibility adapters, report generators, purchase services, or system handoff services, and return prepared results, warnings, failures, and next workflow state.

They do not contain SwiftUI presentation. They do not duplicate baseball calculations. They do not let views directly mutate authoritative records. They do not make purchase state, transient screen state, generated files, or compatibility transport fields into baseball truth.

Services should preserve user-owned records, keep existing compatibility expectations visible, and make unsafe states explicit. When a workflow cannot complete, the observable result should say whether nothing changed, the accepted fact set changed, derived projections failed to refresh, or recovery is required.

<!-- MARK: - 3. Scope and Responsibilities -->
## 3. Scope and Responsibilities

Application services own workflow coordination. In scope are creating and editing teams, players, rosters, games, lineups, scoring events, runner movement, pitcher changes, substitutions, corrections, lifecycle changes, imports, exports, roster downloads, reports, PDFs, printing, sharing, purchases, free allowances, settings, media replacement, deletion, sample data, announcements, warnings, recovery, and resume behavior.

Out of scope are baseball-rule authority, physical persistence implementation, SwiftUI layout, StoreKit implementation details, file-format declarations, report drawing details, PDF rendering mechanics, network endpoint invention, product identifier invention, and database schema design.

Services define responsibilities, inputs, outputs, workflow boundaries, transaction expectations, idempotency expectations, and observable behavior. They should remain product-facing enough that implementation choices can change without changing the intended user workflow.

<!-- MARK: - 4. Architectural Position -->
## 4. Architectural Position

Application services sit below presentation and view models and above domain, scoring, persistence, compatibility, reports, purchases, settings, media, network acquisition, and system handoff boundaries.

Presentation collects selections, form values, taps, navigation requests, cancellation requests, and review choices. Services convert those intentions into validated application actions. Domain and scoring components answer baseball questions. Persistence reads and writes accepted facts. Compatibility adapters translate legacy files and records. Report and PDF generators create derived output. Purchase services answer entitlement questions.

The dependency direction protects baseball truth. A scorecard, report, export, or share sheet may be requested from a service, but none of those surfaces should independently decide what happened in the game.

<!-- MARK: - 5. Commands, Queries, and Workflow Intent -->
## 5. Commands, Queries, and Workflow Intent

Application services should distinguish commands from queries. Commands change recorded facts or durable non-baseball state. Queries read, replay, project, preview, or prepare output without changing authoritative records.

Command examples include create team, edit player, create game, prepare lineup, record play, change pitcher, record substitution, correct event, complete game, apply import, delete record, deactivate record, archive record, replace media, change preference, and consume a completed free allowance.

Query examples include load game list, derive current game state, generate scorecard projection, produce batting or pitching report, preview import, check purchase status, determine remaining free allowance, preview export scope, and compute warnings. This distinction does not prescribe a command bus or CQRS implementation.

<!-- MARK: - 6. Service Inputs and Outputs -->
## 6. Service Inputs and Outputs

Service inputs should identify the user intent, selected record identity, current workflow state, relevant form choices, confirmation state, compatibility source, purchase context, cancellation request, and the latest known projection version where needed.

Service outputs should identify the accepted result, unchanged prior state, warnings, failures, repair requirements, refreshed projections, generated-output references, next workflow state, navigation recommendation, retry eligibility, and supportable diagnostics.

Outputs should be prepared for presentation without becoming presentation. A view should not need to recalculate score, infer next batter, inspect raw import transport fields, decrement counters, or decide whether a failed save consumed a free allowance.

<!-- MARK: - 7. Validation Boundaries -->
## 7. Validation Boundaries

Application services coordinate validation but do not own every rule. They ask the scoring engine for baseball validation, persistence for record availability and write readiness, compatibility adapters for transport interpretation, purchase services for entitlement state, media handlers for image usability, and system services for file or network availability.

Services own workflow-level validation. They decide whether a validated baseball result can be saved now, whether warnings require review, whether a paywall must interrupt the action, whether a destructive action has been confirmed, and whether an import plan is complete enough to apply.

Validation should preserve prior facts until a command is accepted. A failed validation should return product-language reasons and recovery options rather than partially applied records.

<!-- MARK: - 8. Transaction and Persistence Boundaries -->
## 8. Transaction and Persistence Boundaries

Application services define user-visible transaction boundaries. A completed plate appearance, runner movement set, pitcher change, substitution, correction, game creation, import application, deletion, media replacement, or allowance consumption should either complete coherently or leave the prior state usable.

Persistence owns the storage mechanics. The service owns the accepted fact set and the order in which validation, write, projection refresh, allowance update, and completion reporting become visible.

Derived projection refresh may fail after recorded facts are safely written. That failure should not corrupt the accepted facts. The service result should distinguish accepted facts from stale or failed derived output and request a later refresh or repair where needed.

<!-- MARK: - 9. Scoring Workflow Service -->
## 9. Scoring Workflow Service

The scoring workflow service receives scoring intent, identifies the selected game and current replay state, validates batter, pitcher, runners, inning, half inning, outs, lineup context, and game lifecycle, and builds proposed recorded facts.

It asks the scoring engine to apply or replay the proposed facts. The engine outcome may be valid, valid with warnings, incomplete but usable, repair required, unsupported compatibility state, or rejected. The service persists only accepted facts coherently, regenerates projections, and returns the next current-game state.

The service must prevent duplicate plate appearances from repeated taps, retries, interrupted saves, restored presentation state, or delayed UI updates. A second request for the same pending intent should resolve to the existing accepted result or a clear duplicate-prevention outcome, not another scoring event.

<!-- MARK: - 10. Plate-Appearance Completion Workflow -->
## 10. Plate-Appearance Completion Workflow

Completing a plate appearance begins with the selected batter, scoring result, batter destination, outs, RBI decisions, earned-run decisions where applicable, fielding notes, and any runner movement choices already made or still pending.

The service should preserve incomplete choices as workflow state until the user confirms the completed play. It should not save a visible placeholder as final baseball history merely because a scorecard cell was selected.

After confirmation, the service validates the proposed play through the engine, persists the complete recorded fact set, refreshes current batter, runners, score, outs, inning, pitcher responsibility, scorecard projection, and reports where needed, and returns the next scoring context.

<!-- MARK: - 11. Runner-Movement Workflow -->
## 11. Runner-Movement Workflow

Runner movement belongs to the scoring fact set, not to scorecard drawing. The service should identify starting base occupancy from replay, collect movement for the batter and each active runner, validate scoring and out decisions, and preserve runner identity.

Multiple runners, stolen bases, pinch runners, runner outs, double plays, triple plays, and third-out run decisions must be handled as explicit workflow data. The service should reject, hold incomplete, or request repair when the requested movement creates duplicate occupancy, fourth-out state, or a scored runner still on base.

Accepted runner movement refreshes score, base state, inning transition, batter progression, pitcher responsibility, scorecard cells, reports, PDFs, and exports from replay.

<!-- MARK: - 12. Inning-Transition Workflow -->
## 12. Inning-Transition Workflow

Inning transitions should be consequences of accepted scoring facts and lifecycle decisions. The service asks the scoring engine whether a half inning ended, whether bases should clear, which side bats next, and which batter is due up when the side returns.

Ordinary third-out transitions can proceed from replay. Shortened games, suspended games, mercy-rule endings, administrative endings, or user-declared completion require explicit lifecycle intent rather than invented outs.

The returned state should make top or bottom half, inning number, outs, score, current batter, current pitcher, and pending warnings clear enough that presentation can resume without reconstructing baseball state.

<!-- MARK: - 13. Game Setup Workflow -->
## 13. Game Setup Workflow

Game setup coordinates selected home and visiting teams, date, location, inning count, Everyone Hits setting, roster availability, game-time snapshots, initial lineups, initial pitchers where known, and draft or ready state.

Before scoring begins, setup changes may revise intended facts. After scoring begins, equivalent changes become corrections, substitutions, pitcher changes, or lifecycle actions. The service owns that boundary so a setup screen cannot silently rewrite historical plays.

Creating a game may be purchase-gated or allowance-gated, but entitlement state remains separate from baseball facts. A free game creation should be counted only after the game is successfully created as an accepted record.

<!-- MARK: - 14. Lineup Preparation Workflow -->
## 14. Lineup Preparation Workflow

Lineup preparation collects batting slots, selected participants, Everyone Hits behavior, bench context, late or unknown participants, and any accepted incomplete setup decisions.

The service validates that each side has an interpretable batting path for the requested workflow. It may return ready, ready with warnings, incomplete but intentionally accepted, or not ready. It should not infer lineup identity from mutable roster sort order or `Player.batOrder` alone.

Once scoring exists, lineup changes should route through substitution or correction workflows. Earlier plate appearances remain attached to the participants who actually recorded them.

<!-- MARK: - 15. Substitution Workflow -->
## 15. Substitution Workflow

The substitution workflow records incoming participant, outgoing participant when known, side, batting slot when applicable, role, effective game point, and whether the change is a pinch hitter, pinch runner, permanent replacement, defensive replacement, or other supported participation change.

The service should validate the active lineup and current replay state before accepting the substitution. It should identify when a substitution affects base running, batting order, fielding context, or only historical participation.

Batter substitution entry is owned by `ReplacementView` and routes to `LiveScoringWorkflowCoordinator.submitSubstitution`. Live pitcher-change entry is owned by `PitchersStaffView` and routes to `submitPitcherChange`. Both hand off stable identities to Task 5.12 through value-only review state (`LiveScoringShellPresentation.SubstitutionReviewState` and `PitcherChangeReviewState`). Confirmation invokes the workflow exactly once; cancellation performs no mutation. Accepted results contain non-nil refreshed authoritative state. Direct-writer mutations and saves have been removed from the accepted routed paths, while historical pitcher editing remains separate. Legacy remains the authoritative persistence layer, canonical substitution remains non-routed, and Task 7.11 has not begun.

Accepted substitutions affect current and future interpretation. They must not rewrite earlier plate appearances, runner outcomes, pitcher responsibility, or reports except through an explicit correction.

Task 5.12 establishes `LiveScoringWorkflowCoordinator` as the initial accepted Legacy substitution workflow owner for supported batter replacement and pitcher responsibility changes. The stable target boundaries are game, outgoing participant, and incoming participant. The workflow safely mutates Legacy `Game.replaced`, `Game.incomings`, `Player.batOrder`, inserts `Pitch Hitter` placeholders, and updates `Pitcher` state below presentation. Persistence happens once, with full rollback on failure. The presentation layer routing (Task 7.10) remains unauthorized.

<!-- MARK: - 16. Pitcher-Change Workflow -->
## 16. Pitcher-Change Workflow

The pitcher-change workflow records the defensive side, incoming pitcher participant, outgoing pitcher period where known, effective inning, outs, batter context, and unknown or incomplete pitcher state.

The service asks replay for the current defensive side and current game point. It should preserve partial innings, zero-out appearances, between-inning changes, mid-inning changes, unknown pitchers, and correction of prior pitcher markers.

Accepted pitcher changes refresh current pitcher, pitcher responsibility, pitching reports, earned-run decision prompts, scorecard context, PDFs, and exports. Aggregate pitching totals remain projections, not independently edited service results.

<!-- MARK: - 17. Correction Workflow -->
## 17. Correction Workflow

Corrections modify underlying recorded facts, not scorecard cells or report totals. The workflow loads the selected event by stable identity and preserves the prior fact set until confirmation.

The service validates the proposed correction, replays downstream state, identifies affected warnings or later events, and persists the corrected fact set coherently only after acceptance. It should explain whether later events remain valid, become warning-limited, or require repair.

After persistence, the service refreshes scorecards, reports, PDFs, exports, current batter, runners, score, inning, outs, lineup state, substitutions, pitcher responsibility, and navigation context. The user should return to the corrected event or the next current-game state, not to a stale coordinate.

Task 5.11 establishes `LiveScoringWorkflowCoordinator` as the initial accepted Legacy correction workflow owner for supported replacement of an existing scored `Atbat`. The stable target boundary is `Game.ident` plus `Atbat.ident`, with an optional value snapshot of the original Legacy at-bat facts to detect stale review state before mutation. The workflow reloads the current Legacy game and at-bat from the supplied V4 `ModelContext`, verifies game ownership and active game membership, rejects missing, stale, wrong-game, placeholder, and unsupported targets, and keeps presentation from becoming the accepted-correction writer for this coordinated boundary.

Correction planning and validation are delegated to the existing Task 2.12 through Task 2.15 canonical correction foundations as non-routed planning evidence. Accepted mutation remains Legacy: the coordinator updates the target `Atbat`, runs the repository-approved Legacy downstream recalculation for sequence, inning, outs, base projection, end-of-inning, and pitcher markers in memory, persists with one explicit save, and returns refreshed value state. The workflow does not create Legacy correction operation evidence; durable correction idempotency remains unauthorized and therefore unsupported beyond stale-target validation. Cancellation and planning rejection perform no mutation or save. Persistence failure restores the prior accepted Legacy at-bat, score, and pitcher-marker state before returning failure.

Production correction authority remains Legacy. The Task 5.11 workflow does not invoke canonical transaction writing, write canonical scoring records, route production correction reads through canonical replay, synthesize historical records, alter schemas, activate canonical scoring, implement correction-review presentation, or route live-scoring correction entry. Task 6.10 is the completed presentation-only follow-on boundary, and Task 7.9 remains the later correction-entry route.

Task 6.10 adds the presentation-only correction review boundary above this workflow. `LiveScoringShellPresentation` owns value-only review state, original/proposed summary display, confirmation and cancellation availability, in-progress guarding, typed outcome presentation, stale-target and validation feedback, and accepted-state cleanup. Confirmation delegates to `LiveScoringWorkflowCoordinator.submitCorrection` with the retained stable `Game.ident`, target `Atbat.ident`, and original `LegacyCorrectionSnapshot`; cancellation delegates nowhere. The presentation boundary does not mutate Legacy models, save a context, write Legacy scoring-operation evidence, write canonical records, synthesize historical records, or broaden correction semantics.

Task 7.9 routes the prepared correction review boundary from live scoring without changing correction authority. `PlayersToScoreView` owns live-scoring correction entry, target classification, value-only draft handoff, review presentation, workflow submission callback, and accepted refresh consumption. The target-selection boundary is stable `Game.ident` plus `Atbat.ident`; row index, display text, and object memory identity are not authority. Entry fails closed for no target, an already active review, deleted or inactive target, wrong-game target, placeholder or unsupported target, and unsupported replacement. Accepted confirmation still uses `LiveScoringWorkflowCoordinator.submitCorrection`, which revalidates the snapshot, replaces the Legacy at-bat result only after validation, recalculates Legacy downstream state, saves once, and returns refreshed state. The entry layer does not patch score, inning, outs, bases, runners, lineup, pitcher attribution, reports, or statistics. It writes no correction operation evidence, no canonical records, and no historical backfill. Task 7.10 substitution entry has not begun.

<!-- MARK: - 18. Replay and Projection Refresh -->
## 18. Replay and Projection Refresh

Replay and projection refresh is a query unless it is part of an accepted command's completion. The service loads complete game input, requests scoring-engine replay, and produces current-game state, warnings, scorecard projection, report projections, export readiness, and support diagnostics.

Opening a scorecard, report, game list, or export preview must not repair records automatically. Repairs require explicit command intent.

Projection caches may exist, but the service result should identify whether projections are fresh, stale, unavailable, warning-limited, or blocked by repair. Cached projections must not override recorded facts.

<!-- MARK: - 19. Game Lifecycle Workflow -->
## 19. Game Lifecycle Workflow

The game lifecycle workflow coordinates created, configured, ready to score, in progress, interrupted, completed, archived, imported historical, and sample-origin states where supported by the product.

Lifecycle changes may be commands when they record user decisions, such as mark complete, suspend, resume, archive, delete draft, or accept imported historical game. The service should distinguish derived readiness from explicit user declarations.

Completing a game should validate completion readiness, unresolved warnings, score state, inning state, pitcher warnings, and report readiness. Completion should not fabricate missing innings or hide unresolved compatibility limitations.

<!-- MARK: - 20. Team Management Workflow -->
## 20. Team Management Workflow

Team management services coordinate creating, editing, sorting, searching, archiving, deleting, and restoring team visibility where supported. They preserve stable identity and current roster meaning.

Editing current team details should not silently rewrite historical game-side snapshots. If a workflow intentionally refreshes historical display metadata, that should be an explicit future decision with review.

Deletion or archival should explain effects on current lists and historical games. A team that appears in past games should remain understandable even when removed from ordinary active workflows.

<!-- MARK: - 21. Player Management Workflow -->
## 21. Player Management Workflow

Player management services coordinate creating, editing, sorting, searching, deactivating, deleting, and replacing player media. They preserve stable identity, duplicate names, duplicate numbers, current roster membership, and historical participation.

Editing a current player should not silently change who batted, ran, pitched, or substituted in a historical game. Game-time participant snapshots protect reports, scorecards, PDFs, and exports after current roster edits.

Deletion or deactivation should be scoped. A player can be removed from current availability without erasing completed game participation or breaking reports.

<!-- MARK: - 22. Roster Management Workflow -->
## 22. Roster Management Workflow

Roster management services coordinate adding players to teams, removing players from current rosters, reordering lineup hints, filtering active players, and preparing available participants for game setup.

Roster order and player availability are current management concepts. Game-specific batting order belongs to lineup preparation and game participation. The service should keep those meanings distinct.

Large rosters, duplicate names, duplicate numbers, guests, temporary players, and inactive players should remain selectable or reviewable according to the workflow without identity collapse.

<!-- MARK: - 23. Roster Paste Workflow -->
## 23. Roster Paste Workflow

The roster paste workflow coordinates pasted text, delimiter choices, column mapping, preview rows, validation, warnings, duplicate analysis, confirmation, and accepted roster updates.

Parsing should occur before permanent writes. Invalid rows, incomplete rows, duplicate players, unknown columns, and media-free records should be reported in preview. Confirmation should identify which records will be created, updated, skipped, or left for review.

Successful paste import is a roster command. Canceled, malformed, rejected, or failed paste work must not create partial players or consume unrelated allowances.

<!-- MARK: - 24. Import Workflow Coordination -->
## 24. Import Workflow Coordination

Import services coordinate source acquisition, decode, compatibility adaptation, validation, conflict analysis, user choices, import-plan creation, confirmation, persistence, and completion summary.

Files, downloaded rosters, seeded resources, and document-open deliveries should enter the same staged import boundary. No permanent baseball write should occur before final confirmation of a complete import plan, except where a later product decision explicitly defines a safe partial policy.

Import completion should report created, updated, skipped, detached, warning-limited, rejected, or repair-required records. Failure before confirmation leaves local records unchanged.

<!-- MARK: - 25. Import Conflict-Resolution Workflow -->
## 25. Import Conflict-Resolution Workflow

Conflict-resolution services prepare review choices for duplicate names, duplicate numbers, duplicate team names, same-date games, changed media, missing references, score mismatches, unsupported results, lineup conflicts, substitution conflicts, and pitcher conflicts.

Names, dates, teams, locations, and jersey numbers are matching hints, not authoritative identity. Strong matches may be applied automatically only when identity evidence and baseball meaning are unambiguous. Ambiguous or conflicting matches require explicit user choice.

Resolution choices become part of the import plan. Applying an import without a complete plan should be rejected or left awaiting review.

<!-- MARK: - 26. Export Workflow Coordination -->
## 26. Export Workflow Coordination

Export services load canonical records, validate selected scope, generate compatibility projections, create output, hand it to the system, and report completion or cancellation without modifying source records.

Roster and game exports should preserve supported compatibility meaning while keeping transport fields separate from authoritative records. Warnings or unsupported values may block export, export with limitations, or require review depending on the selected scope.

Repeated export generation must not be mistaken for duplicate baseball records. Generated files are output artifacts, not new games, teams, players, or scoring events.

<!-- MARK: - 27. Report Generation Workflow -->
## 27. Report Generation Workflow

Report generation services load selected game or collection scope, request replay or report projections, validate warnings, apply purchase gating where applicable, and return prepared report output or failure.

Reports are queries unless a later workflow explicitly saves a generated artifact outside baseball truth. They must not repair records, rewrite totals, change scores, or consume allowances merely by opening a preview.

A correction or migration interpretation change should cause later reports to regenerate from the revised replay result. Stale report values are invalid output, not alternate truth.

<!-- MARK: - 28. Scorecard and PDF Generation Workflow -->
## 28. Scorecard and PDF Generation Workflow

Scorecard and PDF generation services request scorecard projections from replay, apply layout or pagination requirements, call PDF generation, and return generated output references, warnings, or failures.

Scorecard cells and PDF rows are derived projections. They may link to event identity for correction, but they are not editable baseball records.

Failed PDF generation should leave source records unchanged and should not consume a qualifying free action unless product policy explicitly defines successful generated output as the counted event.

<!-- MARK: - 29. Printing and System Sharing Workflow -->
## 29. Printing and System Sharing Workflow

Printing and system sharing services prepare output, hand it to system interfaces, observe completion or cancellation where available, and report the result without mutating source records.

System cancellation is not failure of baseball data. Destination failure, unavailable printer, revoked file access, or share cancellation should leave teams, players, games, reports, purchases, and allowances unchanged unless the qualifying action was already successfully completed by product policy.

The service should preserve workflow context so the user can retry, choose another destination, or return to the previous report or game.

<!-- MARK: - 30. Website Roster Download Workflow -->
## 30. Website Roster Download Workflow

Website roster download services coordinate manifest loading, team selection, network acquisition, local staging, import review, purchase gating, free-download allowance, failure handling, and offline behavior.

Downloaded content remains untrusted until it passes import classification and review. A successful network download alone should not create baseball records. It should stage a candidate roster source for the normal import workflow.

A free download allowance should be consumed only after the qualifying download/import action completes according to product policy. Failed network requests, offline state, invalid files, canceled review, duplicate prevention, or rejected imports must not consume the allowance.

<!-- MARK: - 31. Deep-Link Workflow -->
## 31. Deep-Link Workflow

Deep-link services parse known route intent, preserve navigation prefill state, and route into the appropriate workflow without bypassing validation. Existing `scorekeep://share?tab=download&prefill=...` behavior remains compatibility evidence.

A deep link may preselect a download team or open a sharing route. It must not download, import, overwrite, purchase, or mutate records without the same confirmations required from in-app navigation.

Unsupported links should fail safely with no record mutation and a navigation state that keeps local data accessible.

<!-- MARK: - 32. Purchase-Gated Action Workflow -->
## 32. Purchase-Gated Action Workflow

Application services may ask purchase services whether a gated action is available. Purchase and entitlement state remain separate from baseball facts.

When access is unavailable, the service should return a paywall-required result that preserves the intended workflow, selected records, pending command input, and idempotency key where applicable. A successful purchase should allow the user to return to the pending action safely.

Canceled, failed, pending, unavailable, or uncertain purchases must not create baseball records, hide existing local data, rewrite records, or consume allowances.

<!-- MARK: - 33. Free-Allowance Coordination -->
## 33. Free-Allowance Coordination

Free-allowance services answer remaining allowance as a query and consume allowance only as part of a successful qualifying command. Qualifying free actions may include game creation or roster download where current product rules define them.

Canceled, failed, rejected, duplicated, interrupted, invalid, or paywall-abandoned actions must not consume allowances. Importing an existing file or accessing existing data should not consume a creation or download allowance unless a product specification explicitly says so.

Allowance consumption should be idempotent. Retrying completion after a successful counted action should not decrement the counter again.

<!-- MARK: - 34. Purchase Status and Restore Workflow -->
## 34. Purchase Status and Restore Workflow

Purchase status and restore services coordinate StoreKit state through purchase services and return product-facing access state, uncertainty, errors, and retry options.

Status checks are queries. They should not mutate baseball records, reset allowances, or alter historical access meaning. Restore success may update entitlement state, but it should not complete a pending baseball command unless the preserved workflow explicitly resumes and passes validation.

Offline or unavailable purchase status should leave local baseball workflows available according to existing access and free allowance rules. It should not block reviewing or exporting user-owned existing records unless a separate product rule requires gating generated output.

<!-- MARK: - 35. Settings and Preference Workflow -->
## 35. Settings and Preference Workflow

Settings services coordinate sorting, filtering, display preferences, report preferences, announcement dismissal, paste mappings, and other non-baseball preference state.

Preferences may affect presentation or default choices, but they must not change historical baseball facts. Resetting preferences must not delete teams, players, games, media, purchases, imports, reports, or compatibility evidence.

Preference changes that require refreshed projections should trigger derived-output refresh only. They should not rewrite scoring events or stored game history.

<!-- MARK: - 36. Media Selection and Replacement Workflow -->
## 36. Media Selection and Replacement Workflow

Media services coordinate selecting, validating, replacing, removing, importing, exporting, and displaying player photos and team logos. Media failure must not make baseball facts unusable.

Replacing current player or team media should affect current records and future presentation according to policy. Historical game identity should remain readable even if current media changes, becomes invalid, or is removed.

Invalid, missing, oversized, denied, or canceled media selection should return warnings or safe failure without deleting the related team, player, or game.

<!-- MARK: - 37. Deletion, Deactivation, and Archival Workflow -->
## 37. Deletion, Deactivation, and Archival Workflow

Deletion, deactivation, and archival services coordinate scope review, destructive confirmation, relationship analysis, transaction expectation, and completion summary.

Deleting a draft is different from deleting a completed game. Removing a player from a roster is different from deleting historical participant meaning. Archiving a team or game is different from destroying records.

The service should reject or require repair for destructive actions that would leave historical games, reports, imports, or exports misleading. Unrelated records, purchases, preferences, media, and generated output should remain unchanged.

<!-- MARK: - 38. Sample and Seeded-Data Workflow -->
## 38. Sample and Seeded-Data Workflow

Sample and seeded-data services coordinate first-launch import, duplicate prevention, sample-origin classification, user deletion, migration, and verification role.

The seeded game is compatibility evidence and should flow through the same interpretation, warning, replay, reporting, and export boundaries as other game records. It should not receive hidden special rules that mask compatibility defects.

If a user deletes sample data, it should not be recreated without user intent or a documented onboarding reset workflow. App interruption during seeding must not duplicate the sample game.

<!-- MARK: - 39. Announcement Workflow -->
## 39. Announcement Workflow

Announcement services coordinate remote announcement fetch, local dismissal state, availability windows, call-to-action routing, offline failure, and safe presentation state.

Announcements are not baseball records. Fetch failure, malformed remote content, dismissal, or route failure must not affect local teams, players, games, purchases, imports, exports, reports, or settings unrelated to announcements.

Deep-link or download actions launched from an announcement should enter the same service workflows and validation boundaries as ordinary user navigation.

<!-- MARK: - 40. Error Classification and Recovery Coordination -->
## 40. Error Classification and Recovery Coordination

Application services should classify errors in product terms: validation rejected, incomplete but recoverable, warning accepted, repair required, storage unavailable, write failed safely, projection refresh failed, import canceled, export canceled, purchase unavailable, media unavailable, network unavailable, and recovery required.

Recovery results should identify whether prior state is unchanged, the command completed, derived output is stale, or a retry is safe. Raw technical failures should be retained only as support diagnostics where appropriate.

A failed command should not leave presentation guessing whether a record changed. The service result must make the committed state clear enough for views to navigate, show retry, or preserve workflow state.

<!-- MARK: - 41. Warning and Repair Workflow -->
## 41. Warning and Repair Workflow

Warning services preserve uncertainty without pretending the record is fully verified. Repair services intentionally change recorded facts or compatibility interpretation after review.

Warnings may include unknown pitcher, incomplete lineup, unsupported result, stored-score mismatch, ambiguous substitution, missing media, duplicate identity, or offline network failure. Repairs may assign missing participants, correct event order, pair substitutions, map unsupported values, or classify records as compatibility-limited.

Opening a report, scorecard, export preview, or game list should not perform repair. Repair is an explicit command with validation, confirmation where needed, coherent persistence, and projection refresh.

<!-- MARK: - 42. Interruption and Resume Behavior -->
## 42. Interruption and Resume Behavior

Services should define what happens when the app backgrounds, terminates, restarts, resizes, loses file access, loses network, or returns from a paywall or system share sheet.

Confirmed baseball facts should survive interruption. Incomplete workflow state should either be resumable, safely discarded with explanation, or preserved as a draft that is not baseball truth.

Resume should restore the latest coherent game state from replay, not from stale screen counters. Pending imports, exports, purchases, reports, and media operations should return to review, retry, cancellation, or completion summary according to the last committed state.

<!-- MARK: - 43. Workflow State Preservation -->
## 43. Workflow State Preservation

Services should distinguish authoritative baseball facts, persisted drafts, application workflow state, transient presentation state, external system state, and purchase or allowance state.

Authoritative baseball facts include game setup, participants, lineups, scoring events, runner outcomes, substitutions, pitcher appearances, corrections, and lifecycle decisions. Persisted drafts are saved incomplete setup or review work. Application workflow state includes pending import plan, pending scoring intent, selected correction event, pending paywall return, or report generation progress.

Transient presentation state includes selected tab, expanded rows, scroll position, highlighted cell, and temporary button state. External system state includes share sheet, document picker, printer, StoreKit sheet, network request, and file security scope. Workflow state may need preservation across interruption, but it must not become baseball truth.

<!-- MARK: - 44. Idempotency and Duplicate Prevention -->
## 44. Idempotency and Duplicate Prevention

Services must prevent duplicate scoring events, duplicate imports, duplicate game creation, duplicate allowance consumption, and repeated export generation being mistaken for separate baseball records.

High-risk commands should carry enough stable intent context to recognize retries after repeated taps, delayed saves, app restoration, or network retry. A duplicate command should return the original accepted result or a duplicate-prevention warning when possible.

Idempotency applies to side effects separately. Persisting a game, consuming an allowance, refreshing a projection, and handing a generated file to the system should not each be repeated blindly just because presentation retried the workflow.

<!-- MARK: - 45. Concurrency and Competing Actions -->
## 45. Concurrency and Competing Actions

Services should define ownership boundaries when two actions compete for the same game, team, player, import plan, allowance, or generated output. This design does not prescribe a concurrency framework.

Observable guarantees should include one accepted writer for a game fact set, no two simultaneous plate-appearance completions for the same current batter, no lineup replacement while scoring writes are pending, no import application while the same record is being destructively edited, and no duplicate allowance consumption from parallel requests.

Legacy and rewritten workflows must not both write incompatible facts for the same feature. Coexistence should route each fact set through one accepted writer until legacy behavior is retired.

<!-- MARK: - 46. Progress and Cancellation -->
## 46. Progress and Cancellation

Services should provide progress for longer work such as import review, large export, PDF generation, migration, report generation, media processing, or remote download.

Cancellation should be honored before permanent writes when safe. After a coherent write has completed, cancellation should not roll back into an unclear state; it should return a completion or post-write recovery result.

Progress state is workflow state. It should not be saved as baseball fact, and losing progress UI should not imply that accepted records were lost.

<!-- MARK: - 47. Offline Behavior -->
## 47. Offline Behavior

Application services should preserve local-first behavior. Creating and editing local teams, players, games, lineups, scoring, corrections, local reports, local exports, local imports, and review of existing records should remain available offline where the product supports them.

Network-only workflows such as roster downloads, remote announcements, online purchase refresh, and external links should fail clearly when offline without changing local baseball records.

Returning online may refresh entitlement, announcements, or downloadable roster listings. It must not overwrite offline scoring work or silently import remote data.

<!-- MARK: - 48. Accessibility Responsibilities -->
## 48. Accessibility Responsibilities

Application services support accessibility by returning complete, structured workflow state that views can describe without recalculating baseball meaning.

Prepared results should include current batter, score, inning, outs, runners, warnings, destructive scope, import conflicts, purchase state, progress, cancellation availability, and completion summaries in a form suitable for VoiceOver, larger text, keyboard navigation, high contrast, and color-independent presentation.

Accessibility workflows must reach the same service commands and validation boundaries as touch workflows. Alternate input should not bypass duplicate prevention, confirmation, repair review, or allowance rules.

<!-- MARK: - 49. Privacy and Security Boundaries -->
## 49. Privacy and Security Boundaries

Services should minimize personal and filesystem information in diagnostics, provenance, support summaries, and generated output. Youth-player names, photos, local paths, document locations, purchase account details, and unrelated records should not be exposed unnecessarily.

Security-scoped documents, downloaded files, media selections, and generated outputs are external or staged resources until accepted by a workflow. File access failure should not damage local records.

Purchases and allowances should not store or expose credentials. Import and export should be deliberate, and no unnecessary upload should occur as part of local scoring, reports, or migration.

<!-- MARK: - 50. Observability and Supportability -->
## 50. Observability and Supportability

Application services should produce supportable outcomes: workflow name, record category, affected record identity at a privacy-conscious level, validation classification, warning category, compatibility format, interpretation version where useful, whether local data changed, and whether retry is safe.

Observability should help diagnose duplicate prevention, failed saves, import warnings, export failures, purchase uncertainty, PDF failures, migration warnings, and projection refresh issues.

Diagnostics must not become user-visible implementation jargon by default. Presentation can translate service classifications into product language while retaining enough support context for troubleshooting.

<!-- MARK: - 51. Determinism and Repeatability -->
## 51. Determinism and Repeatability

The same authoritative facts, compatibility interpretation policy, purchase state, and user intent should produce the same service outcome. Replay queries should not depend on view order, screen size, selected tab, incidental fetch order, or current network state except where the workflow explicitly asks for network information.

Deterministic services support corrections, report agreement, export round trips, migration verification, idempotency, and acceptance fixtures.

Where time or external state matters, such as purchase status, downloaded manifest, or generated file timestamp, the service should isolate that input from baseball replay so unchanged games remain unchanged.

<!-- MARK: - 52. Performance and Scale -->
## 52. Performance and Scale

Services should keep ordinary live scoring immediate while preserving correctness. Large rosters, long batting orders, extra innings, many substitutions, many pitchers, large imports, media-heavy rosters, and long reports should remain usable with progress where noticeable.

Optimization must not weaken transaction boundaries, replay correctness, or recovery. Cached projections, checkpoints, and prepared summaries must be invalidated or reconciled after scoring, corrections, migration interpretation changes, settings that affect presentation, and relevant media changes.

Services should avoid forcing optional media, remote announcements, purchase refresh, or generated-output work onto critical live-scoring paths.

<!-- MARK: - 53. Legacy Workflow Mapping -->
## 53. Legacy Workflow Mapping

Repository inspection shows legacy workflows where SwiftUI views directly create or modify SwiftData records. Examples include game creation and free-counter handling in `ScoreContentView`, lineup and placeholder at-bat creation in `StartingLineupView`, pitcher insertion and deletion in pitcher staff views, replacement insertion in `ReplacementView`, paste import writes in `PasteView`, and direct team/player/game deletion in edit views.

Current scorecard and scoring display paths mutate `Atbat.col`, `Atbat.seq`, `Atbat.inning`, `Atbat.outs`, `endOfInning`, `colbox`, and `batbox` while calculating visible totals. Pitcher marker updates are derived and saved from at-bat order and current display context. Reports and PDF generation recalculate from legacy at-bat fields and substitution arrays.

Import and export evidence shows decode, matching, persistence, generated files, share handoff, downloads, paywall presentation, and free counters mixed into views and services. Imports match by names in some paths, create teams and players during import, append `replaced` and `incomings` arrays, and save multiple times while importing child records. These patterns are migration evidence for the service boundary; they are not coupling to preserve.

<!-- MARK: - 54. Migration and Coexistence -->
## 54. Migration and Coexistence

Application services should be introduced beside legacy workflows and routed feature by feature after fixture-backed acceptance. A feature should have one accepted writer for each fact set during coexistence.

Legacy records may remain physically unchanged while services load them through compatibility adapters and replay them through the scoring engine. New canonical writes should be bounded to accepted workflows and should not assume every old record has already migrated.

Retiring legacy writes should follow verification that scoring, corrections, reports, PDFs, exports, imports, purchases, allowances, and recovery behavior agree with the service path. Cleanup should wait until equivalent behavior is accepted.

<!-- MARK: - 55. Verification Strategy -->
## 55. Verification Strategy

Verification should map service workflows to acceptance fixtures and regression scenarios. Required scenarios include ordinary plate appearance, rapid repeated scoring taps, failed save, correction replay, extra innings, large lineup, substitution-heavy game, pitcher-change-heavy game, interrupted scoring, duplicate import, malformed import, export cancellation, failed PDF, offline roster download, purchase cancellation, failed purchase, allowance not consumed after failure, app termination during a workflow, seeded game, and accessibility scoring workflow.

Expected evidence should include accepted facts, unchanged prior state after failure, warnings, repair requirements, refreshed projections, current batter, runners, score, pitcher responsibility, import summary, export result, generated-output result, allowance state, purchase state, and resume behavior.

Service verification should prove that views no longer need to mutate authoritative records directly, duplicate baseball calculations, or decide entitlement side effects.

<!-- MARK: - 56. Risks and Open Questions -->
## 56. Risks and Open Questions

Recommendations are to define service boundaries around product workflows rather than source files, keep scoring-engine replay authoritative, preserve compatibility evidence, count free actions only after successful completion, and make idempotency explicit for scoring, imports, game creation, and allowance consumption.

Unresolved questions include the exact persistence mechanism for workflow drafts, the final physical migration schedule, the amount of historical media snapshotting, detailed purchase rules for each generated output, whether partial import application is ever allowed, exact report gating policy, and how much service diagnostic detail should be user-visible.

These are implementation or product-policy choices. They should not be presented as settled facts until follow-on designs or specifications resolve them.

<!-- MARK: - 57. Success Criteria -->
## 57. Success Criteria

This design succeeds when application services receive explicit intent, validate through the proper authorities, persist accepted facts coherently, refresh projections from replay, preserve workflow state safely, prevent duplicates, coordinate purchases and allowances separately from baseball facts, and return clear results for presentation.

SwiftUI views should no longer directly mutate authoritative baseball records, calculate scores or pitcher responsibility, patch scorecard cells, interpret compatibility files, decrement counters, or decide import/export transaction outcomes.

Existing user-owned records, compatibility files, seeded data, purchases, preferences, media, reports, and offline workflows remain protected while rewritten services replace legacy workflows incrementally.

<!-- MARK: - 58. Recommended Next Design Document -->
## 58. Recommended Next Design Document

The recommended next design document is `24-ReportingAndGeneratedOutputDesign.md`.

Reports and generated output should follow because the application-service boundaries now define how canonical replay results are requested, scoped, generated, refreshed after corrections, gated where applicable, shared, and kept separate from authoritative baseball records.

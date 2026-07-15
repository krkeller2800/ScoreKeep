# Persistence-Authority Cutover Preparation Baseline

<!-- MARK: 1. Scope And Non-Routing Boundary -->
## 1. Scope And Non-Routing Boundary

This baseline completes only the preparation portion of implementation-catalog task 3.19, Persistence-authority cutover preparation and routing. It introduces cutover-preparation vocabulary, route classifications, gate definitions, one-writer readiness rules, and a reviewable route inventory.

No production persistence route was changed. No production writer was enabled, replaced, shadowed, retired, or disabled. No production ModelContainer, SwiftData model, relationship, delete rule, external-storage attribute, VersionedSchema, SchemaMigrationPlan, store URL, startup path, StoreKit path, Keychain path, allowance counter, entitlement logic, UI, accessibility behavior, fixture, import route, export route, report route, media route, or scoring route changed.

The new source is side-effect free. It contains no SwiftData access, no store URL, no save, no insert, no delete, no migration execution, no feature flag, no StoreKit access, no Keychain access, and no UI behavior.

<!-- MARK: 2. Evidence Reviewed -->
## 2. Evidence Reviewed

Repository evidence reviewed for this preparation includes the current SwiftData model declarations for Game, Team, Player, Atbat, Lineup, and Pitcher; ScoreKeepApp startup and seeded import behavior; ModelContext insert, update, delete, save, and fetch sites; game, team, player, roster, lineup, scoring, pitcher, substitution, import, seed, media, delete, report, export, purchase, entitlement, and allowance workflows; compatibility transport and fixture evidence; and the existing canonical persistence and migration support types.

Governing design and verification evidence includes Documents 18, 20, 21, 23, 25, 27, 28, and 29, plus the Phase 3 baselines for persistence boundary and mapping, save and round-trip verification, media deletion and repair boundaries, migration sources and empty stores, existing-store migration and recovery, and purchase separation. Phase 2 replay and correction evidence was reviewed only as persistence-adjacent evidence; this run does not begin scoring cutover preparation.

<!-- MARK: 3. Current Production Persistence Authority -->
## 3. Current Production Persistence Authority

The current production baseball persistence authority is legacy SwiftData reached through SwiftUI environment ModelContext values and ImportService. Production startup installs the current unversioned SwiftData model container through the app entry point. The active persisted baseball records are Game, Team, Player, Atbat, Lineup, and Pitcher.

Current production write behavior is distributed across views and ImportService. Some routes use explicit saves, some rely on bound model mutation and implicit SwiftData persistence, and some swallow or log save failures without durable transaction classification.

Purchase and allowance state is not baseball persistence authority. StoreKit remains authoritative for product transactions, and Keychain-backed values remain authoritative for entitlement and allowance counters.

<!-- MARK: 4. Complete Production Route Inventory -->
## 4. Complete Production Route Inventory

ModelContainer startup is a legacy startup writer and migration gate. It opens or initializes the current unversioned SwiftData store and currently has no production source-version policy, migration-progress marker, rollback design, or startup decision router.

Empty-store initialization is currently implicit through SwiftData startup. Test-only empty-store verification exists, but no production startup migration route or completion marker exists.

Game creation is a legacy writer. It reads selected teams and, in the score workflow, entitlement and free-game allowance state. It inserts Game, changes home and visiting team relationships, explicitly attempts save, and currently may decrement allowance after calling the legacy write without separate durable proof that the baseball transaction is complete.

Game editing is a legacy writer and cleanup/delete route. It mutates Game date, location, highlights, everyone-hits, and team relationships through bound SwiftData models. Invalid games can be deleted on dismiss. Save and rollback are not classified.

Team creation and editing is a legacy writer and media writer. It inserts Team, mutates display fields and logo bytes, checks duplicates, may delete invalid or duplicate teams, and may delete players when deleting teams. Team logo is externally stored media on Team.

Player creation and editing is a legacy writer and media writer. It inserts Player, mutates name, number, position, batting direction, batting order, team relationship, and photo bytes. It includes direct player delete routes and duplicate or blank cleanup on dismiss.

Roster changes are legacy writers. Team roster workflows insert, update, delete, and renumber players; mutate Player.team and Team.players; and rely on mixed explicit and implicit save behavior.

Lineup changes are legacy writers and destructive writers. StartingLineupView can insert Lineup and placeholder Atbat records, mutate Lineup.players and Player.batOrder, update Atbat batting order and sequence, append Game.players and Game.atbats, and delete existing at-bats during lineup replacement.

Scoring-event creation is a legacy writer. PlayersToScoreView and ScoreGameView insert Atbat records, mutate result, max base, out location, RBI, sacrifice, stolen base, earned-run, play record, end-of-inning, sequence, inning, outs, and scorecard column evidence, and delete unaccepted or duplicate at-bats.

Score and game-state projection writes are derived projection writers. Scoring views recalculate Atbat sequence, column, inning, outs, max base, score-display-derived state, and Pitcher boundary markers. These writes are currently persisted but are not canonical source authority by themselves.

Correction persistence is legacy direct edit/delete behavior. No production correction supersession record, canonical correction command store, or idempotent correction persistence authority exists.

Pitcher changes are legacy writers and cleanup writers. PitchersStaffView and scoring projections insert, update, and delete Pitcher records and mutate Game.pitchers and boundary marker fields.

Substitutions are legacy writers. ReplacementView mutates Player.batOrder, Game.replaced, Game.incomings, Game.atbats, Game.players, Atbat.batOrder, and Atbat.seq, and inserts substitution marker at-bats. Pairing currently depends on parallel relationship arrays.

Compatibility imports are compatibility import writers. ImportService and import views read compatibility files and existing records, upsert teams and players, insert games, at-bats, lineups, pitchers, replacement arrays, incoming arrays, and media, and save at multiple helper boundaries.

Seeded-game insertion is a seed writer and compatibility import writer. Startup reads the bundled seeded game and hasSeededInitialGame preference, then uses ImportService to write the seeded graph and sets a preference after import returns.

Media replacement and removal is a media writer. Player.photo and Team.logo are optional externally stored Data fields, replaced through PhotosPicker, pasteboard, compatibility import, or direct nil replacement. No separate media transaction authority exists.

Game deletion is a legacy destructive writer. GameView manually deletes related at-bats, pitchers, lineups, then the game. Relationship delete behavior remains partly implicit SwiftData behavior.

Team deletion is a legacy destructive writer. The team list prevents deletion when associated games are found, deletes players for some team delete routes, then deletes the team.

Player deletion is a legacy destructive writer. Player deletion checks at-bat and pitcher references in some routes, removes from team relationships in some routes, deletes player records, and can renumber remaining batting order.

Event deletion is a legacy destructive writer. ScoreGameView and lineup replacement can reset or delete Atbat records and mutate Game.atbats without persisted correction supersession evidence.

Report and export reads are read-only with respect to baseball source records. They read games, teams, players, at-bats, lineups, pitchers, replacements, incoming players, and media, then produce generated output outside baseball source authority.

Startup cleanup or normalization is not a general production migration route. Seed insertion exists at startup, and localized cleanup such as blank pitcher cleanup exists in view workflows. No production startup repair or normalization authority exists.

Purchase, entitlement, and allowance routes are outside baseball persistence cutover. StoreKit and Keychain remain their own authorities.

<!-- MARK: 5. Route Classifications -->
## 5. Route Classifications

Read only: report and export reads.

Legacy writer: model startup, empty-store initialization, game creation, game editing, team creation and editing, player creation and editing, roster changes, lineup changes, scoring-event creation, correction persistence, pitcher changes, substitutions, and startup cleanup or normalization.

Legacy destructive writer: game editing invalid cleanup, lineup replacement, correction deletion, game deletion, team deletion, player deletion, and event deletion.

Derived projection writer: score and game-state projection writes, including event sequencing, inning and outs projection, max-base adjustment, and pitcher marker updates.

Compatibility import writer: compatibility imports and seeded-game insertion.

Seed writer: seeded-game insertion and startup seed behavior.

Media writer: team logo and player photo replacement or removal.

Delete or cleanup writer: game, team, player, event, pitcher, lineup replacement, and localized cleanup routes.

Purchase or allowance writer outside baseball persistence: StoreKit entitlement and Keychain allowance routes.

Candidate for first bounded routing: simple team creation and editing, with strong preference for the simple team-creation subset only after all gates pass.

Must remain legacy until later: scoring-event persistence, correction persistence, score projections, and other scoring-adjacent writes.

Blocked by migration or schema decision: startup, empty-store classification, imports, seeded insertion, existing-store behavior, and any route whose target schema or source classification is unknown.

Blocked by unsupported canonical meaning: scoring, correction, pitcher responsibility, substitution timing, full runner movement, and ambiguous legacy evidence.

Blocked by missing rollback or user review: destructive deletes, lineup replacement, imports, substitution ambiguity, and any route involving duplicate, broken, unsupported, or contradictory evidence.

Not part of baseball persistence cutover: StoreKit, Keychain entitlement evidence, allowance counters, generated reports, PDFs, screenshots, and export files.

<!-- MARK: 6. Proposed Future Persistence Authority Boundary -->
## 6. Proposed Future Persistence Authority Boundary

The smallest supportable future persistence authority is a transaction adapter or coordinator that sits below UI workflows and above the physical SwiftData write. It should coordinate canonical validation, canonical-to-persisted mapping, source-version and migration-readiness status, stable transaction identity, save attempt, save result classification, reload when required, canonical interpretation of the saved result, relationship and ordering verification, media result classification, purchase and allowance separation, and final transaction disposition.

It must not own baseball scoring-rule interpretation, which belongs to canonical scoring. It must not own UI presentation, StoreKit verification, Keychain counters, report rendering, export encoding, import parsing, or repair decisions that require user review. It must not be introduced as a production service until schema, source-version, startup, rollback, disable, review, and purchase-separation gates are approved.

<!-- MARK: 7. One-Writer Rule -->
## 7. One-Writer Rule

A future cutover must permit exactly one active baseball persistence writer for a given transaction. Shadow production writes to both legacy and new paths are prohibited. A failed new write must not automatically fall back to legacy unless an explicitly designed, idempotent, reviewed fallback exists. Read-only comparison is allowed.

Routing decisions must be deterministic and diagnosable. Writer identity must be recorded or inspectable in diagnostic evidence. Duplicate invocation must not create duplicate records. Allowances must be consumed only after the accepted baseball transaction is proven complete. Entitlement checks remain separate from record persistence. Legacy retirement can occur only after replacement verification passes.

Future tests must prove that a routed transaction records one writer identity, that legacy and new writer probes cannot both increment, that duplicate transaction identity is classified as already applied, that failed new writes do not invoke legacy writes, and that read-only comparisons do not mutate records.

<!-- MARK: 8. Schema Decision Gate -->
## 8. Schema Decision Gate

Production schema work must not begin until the team decides whether the current unversioned schema can remain unchanged for initial authority routing or whether a new versioned schema is required. The gate must classify the current unversioned production store, define the first explicit schema identity if one is needed, and list which models belong in each schema version.

For each proposed change, the gate must classify it as no schema change, automatic-migration compatible, lightweight migration, custom migration, canonical reconstruction outside physical migration, or unsupported. The gate must explicitly address relationship changes, optionality changes, delete-rule changes, external-storage behavior, stable identity preservation, ordering preservation, media behavior, store-opening failure, and compatibility with installed app versions.

No version number, VersionedSchema, or SchemaMigrationPlan is chosen in this run.

<!-- MARK: 9. Source-Version Policy Gate -->
## 9. Source-Version Policy Gate

A future production startup or migration path must safely classify a new store, current unversioned ScoreKeep store, previously initialized empty store, populated current-model store, unknown store version, store that cannot open, store with metadata but no baseball records, store with only preferences or separate purchase state, partially migrated store, completed migration marker present, completion marker absent, unsupported future version, and corrupt or contradictory source evidence.

Container opening alone must not be treated as proof that the store is safe to write. Source classification must be durable enough to prevent accidental duplicate migration, unsafe writes to an uncertain store, and confusion between baseball records and purchase or preference state.

<!-- MARK: 10. Migration Progress Gate -->
## 10. Migration Progress Gate

Future production migration requires durable progress evidence before it can run. Minimum evidence includes stable migration operation identity, source identity, source version classification, target version classification, current phase, last proven completed phase, record-category counts, completion marker, failure or interruption marker, verification status, rollback eligibility, and user-review requirement.

Progress evidence could live in a separate metadata record, sidecar metadata store, or other approved store metadata location, but it must not be confused with baseball records. It must survive app termination, prevent duplicate migration on repeated startup, prove completion only after verification and completion-marker persistence, and treat uncertain completion as not successful.

No production progress storage is implemented in this run.

<!-- MARK: 11. Startup Gate -->
## 11. Startup Gate

Future startup must distinguish store opens and no migration is required, empty store initialization, migration required and safe to begin, migration already complete, migration interrupted and resumable, migration interrupted and rollback required, migration failed but source remains usable, migration status uncertain, unsupported source, unknown source version, store cannot open, user review required, read-only access permitted, and app must stop before writing.

Production writes are forbidden whenever source version is unknown, migration is required but not complete, migration status is uncertain, rollback or review is required, source is unsupported, source cannot open, completion marker is missing or contradictory, purchase separation fails, or the active writer cannot be determined.

<!-- MARK: 12. Failure And Uncertainty Gate -->
## 12. Failure And Uncertainty Gate

Future behavior must classify container creation failure, source read failure, validation failure, record-write failure, relationship-write failure, ordering-write failure, media-write failure, save failure, reload failure, verification failure, completion-marker failure, purchase-separation failure, app termination, process crash, device storage failure, and completion uncertain.

Uncertain outcome must never be reported as success. A partial target must not become authoritative. Source preservation has priority. Retry safety, rollback availability, and user-review need must be explicit. Allowances and entitlements remain unchanged. No silent destructive repair is allowed.

Current repository evidence supports test-only failure classification and recovery scenarios. It does not yet provide production backup, production rollback, production progress storage, or production repair execution.

<!-- MARK: 13. Disable Plan -->
## 13. Disable Plan

Disable means a future mechanism prevents the new persistence authority from receiving additional writes. It is separate from rollback. For initial adapter work without schema change, disable can likely be schema-independent because legacy SwiftData remains the active writer, but this must be proven before routing.

A disable mechanism must prove that only legacy writer receives future writes after disable, that no duplicate writes occur during transition, that pending or uncertain new-authority transactions are not silently retried through both writers, and that allowances remain unchanged unless a baseball transaction has already been accepted.

No disable mechanism is implemented in this run.

<!-- MARK: 14. Rollback And Recovery Plan -->
## 14. Rollback And Recovery Plan

Rollback means restoring the prior usable persistence authority or store state after a failed or unsafe cutover. Recovery means preserving source state and choosing a safe next action when rollback is not available or outcome is uncertain.

If a future route changes only an isolated transaction adapter and not schema, rollback may mean disabling the new writer and preserving the legacy store. If a physical schema change is introduced, rollback may require source preservation or backup and may become impossible for legacy code. Rollback success must be proven by source usability, active writer identity, absence of duplicate writes, reconciled progress evidence, and unchanged allowance and entitlement state.

Rollback is prohibited when source state is missing, completion is contradictory, target has become the only readable copy without approved backup, or user review is required. No rollback mechanism is implemented in this run.

<!-- MARK: 15. User Review And Repair Gate -->
## 15. User Review And Repair Gate

Duplicate identity requires preservation and user review before write routing; repair tooling is required before automatic merge or deletion.

Missing identity requires preserve or reject routing; identity must not be fabricated.

Broken participant, lineup, pitcher, and team relationships require preserve in read-only mode, repair assessment, or user review before routing.

Ambiguous substitution timing, conflicting event order, incomplete runner movement, third-out run ambiguity, and pitcher responsibility ambiguity require user review or deferred migration; they must not be silently normalized.

Stored-score mismatch may preserve and continue with warning when source facts are usable, but it must not overwrite coherent replay evidence without policy. Unsupported result and unsupported stored score reject routing until policy exists.

Malformed media can preserve baseball facts with warning when owner identity is safe, but media replacement routing requires media-specific failure classification.

Orphan candidates and contradictory team side evidence require read-only preservation, review, or repair tooling. No repair UI or repair execution is added in this run.

<!-- MARK: 16. Purchase Entitlement And Allowance Gate -->
## 16. Purchase Entitlement And Allowance Gate

Baseball migration must never contain receipts or signed transactions. StoreKit remains authoritative for product transactions. Entitlement evidence remains outside baseball record migration. Keychain allowance counters remain outside SwiftData migration.

Game creation allowance can be consumed only after a successful accepted game transaction is proven complete. MLB download allowance is not changed by persistence migration. Failed, interrupted, rejected, uncertain, rolled-back, or disabled persistence operations must not consume an allowance. Purchase-separation failure blocks cutover. Missing baseball data does not imply missing entitlement. Migration retry must not decrement counters again.

No StoreKit, Keychain, allowance, or entitlement behavior changed in this run.

<!-- MARK: 17. Candidate First Routed Transaction -->
## 17. Candidate First Routed Transaction

Simple team creation is the safest later first bounded route if and only if all gates are satisfied. It has low relationship complexity, no scoring involvement, no import involvement, no delete requirement for the initial bounded path, no allowance involvement, straightforward identity and duplicate checks, and focused verification feasibility.

New game creation is plausible but riskier because the score workflow currently couples game creation to free-game allowance consumption. It must wait until allowance-after-save proof exists.

Simple player creation is plausible but riskier than team creation because roster membership, batting order, player media, and reference checks appear across several workflows.

A narrowly bounded non-destructive update may be possible later, but bound implicit save behavior and rollback proof must be designed first.

The recommended candidate is one isolated production-compatible simple team-creation transaction adapter without routing it. It should be implemented only after schema and source-version gates show whether versioned schema work is needed first.

<!-- MARK: 18. Routes Explicitly Deferred -->
## 18. Routes Explicitly Deferred

Scoring-event persistence is deferred because canonical scoring storage, command idempotency, projection boundaries, and one-writer scoring proof are not routed.

Correction persistence is deferred because no production correction supersession record or persisted correction command identity exists.

Import application is deferred because it writes broad graphs with multiple intermediate save points and needs whole-graph transaction proof, rollback, and user-review policy.

Roster or lineup replacement is deferred because it mutates ordering and can delete existing at-bats and substitution evidence.

Pitcher and substitution persistence is deferred because pitcher responsibility, substitution timing, and parallel-array pairing remain ambiguous in some legacy evidence.

Media replacement is deferred as a first route because it needs media-specific failure and rollback behavior.

Deletes are deferred because they are destructive, relationship effects are partly implicit, and rollback is missing.

Bulk seed insertion and existing-store physical migration are deferred because startup source-version, progress, rollback, and completion-marker policies are missing.

Any transaction that consumes an allowance before durable save proof is deferred.

<!-- MARK: 19. Acceptance Checklist -->
## 19. Acceptance Checklist

Before any route is enabled, the route must be inventoried, current writer identified, proposed writer identified, exactly one writer guaranteed, stable transaction identity available, canonical validation available, mapping supported, save result classified, fresh reload verified where needed, relationship verification passed, ordering verification passed, media behavior classified, migration state known, source version known, schema decision complete, disable path defined, rollback or recovery path defined, user-review requirement resolved, duplicate prevention verified, allowance boundary verified, entitlement separation verified, failure injection passed, interruption test passed, repetition test passed, production build passed, full tests passed, no legacy route retirement required for the initial bounded test, monitoring or diagnostic evidence available, and explicit approval received.

Unresolved items are not marked complete in this run. The current acceptance disposition is preparation only for the cutover model, and blocked for production routing.

<!-- MARK: 20. Legacy Retirement Boundary -->
## 20. Legacy Retirement Boundary

Task 3.20 remains deferred. Legacy persistence cannot be retired until replacement routes are implemented and verified, one-writer enforcement is proven, migration behavior is production-safe, rollback or disable behavior is proven, user-owned data has been verified, all required production routes have moved, reports, imports, exports, scoring, media, and deletion dependencies are understood, compatibility requirements are preserved, and a release and support plan exists.

No legacy code is modified or removed in this run.

<!-- MARK: 21. Relationship To Scoring Cutover -->
## 21. Relationship To Scoring Cutover

Persistence preparation clarifies that canonical scoring facts eventually need a supported persisted representation, replay and correction results need durable transaction identities before they can become persisted facts, duplicate scoring commands must be prevented by idempotency evidence, failed scoring saves must preserve the prior accepted game, allowance consumption must wait for save proof, stored legacy scores remain comparison evidence, and old and new scoring writers cannot both run.

Task 2.19 scoring-authority cutover preparation is not started. Production scoring routes remain legacy.

<!-- MARK: 22. Current Blockers -->
## 22. Current Blockers

Current blockers are production schema decision, source-version policy, migration progress storage, startup decision policy, production disable mechanism, rollback or recovery mechanism, user-review and repair workflow, stored-score adjudication policy, substitution timing policy, pitcher responsibility policy, game-time media policy, allowance-after-save proof for game creation, one-writer diagnostic proof, and explicit approval for any routing.

Production migration remains blocked. Production persistence routing remains blocked. Legacy retirement remains blocked. Scoring cutover remains blocked.

<!-- MARK: 23. Staged Gate Results -->
## 23. Staged Gate Results

Stage A passed for preparation: material production persistence routes were inventoried from repository evidence.

Stage B passed for preparation: current legacy SwiftData authority, proposed future persistence authority boundary, and one-writer rule were defined without routing.

Stage C passed for preparation: schema, source-version, migration-progress, and startup gates were defined as blockers without implementation.

Stage D passed for preparation: failure, uncertainty, disable, rollback, recovery, and review gates were defined without implementation.

Stage E passed for preparation: purchase, entitlement, and allowance separation requirements were defined and kept outside baseball migration.

Stage F passed for preparation: simple team creation was identified as the safest later bounded candidate, with no route enabled.

Stage G passed for preparation: acceptance checklist, legacy-retirement boundary, scoring-cutover boundary, and exact next recommendation were recorded.

<!-- MARK: 24. Authority Introduced And Legacy Authority Retained -->
## 24. Authority Introduced And Legacy Authority Retained

This run introduces persistence-cutover preparation authority, route classification authority, one-writer gate authority, schema readiness vocabulary, migration readiness vocabulary, startup readiness vocabulary, disable and rollback readiness vocabulary, user-review readiness vocabulary, purchase-separation readiness vocabulary, and a reviewable acceptance checklist.

Legacy production SwiftData authority remains active. StoreKit, Keychain, allowance, entitlement, report, export, import, media, scoring, UI, accessibility, fixture, and startup authorities remain unchanged.

<!-- MARK: 25. Exact Next Implementation Recommendation -->
## 25. Exact Next Implementation Recommendation

Review the completed Phase 3 evidence and this task 3.19 preparation before authorizing any persistence or scoring routing.

If the cutover gates conclude that a versioned schema is required, implement the first explicit production persistence schema and migration-policy foundation before any routed writer.

If schema and source-version evidence supports keeping the current schema for an initial bounded route, implement one isolated production-compatible simple team-creation persistence transaction adapter without routing it.

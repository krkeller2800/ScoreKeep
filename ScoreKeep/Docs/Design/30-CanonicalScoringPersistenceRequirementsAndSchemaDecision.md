# Canonical Scoring Persistence Requirements and Schema Decision

<!-- MARK: - 1. Purpose -->
## 1. Purpose

This document completes implementation-catalog Task 3.21. It defines the durable persistence requirements and schema decision for canonical scoring authority so that Task 3.22 can implement storage without inventing missing semantics.

The decision is documentation only. It does not add SwiftData models, change the active container, migrate a store, route production scoring, persist canonical scoring events, retire Legacy scoring, or synthesize canonical history.

<!-- MARK: - 2. Scope -->
## 2. Scope

The scope is the durable boundary for future canonical scoring persistence:

- What canonical scoring facts must be persisted as authority.
- What remains deterministically derived by replay.
- Game ownership, event identity, operation identity, event ordering, payload representation, and versioning.
- Correction, supersession, idempotency, retry, uncertain-commit, and fresh-context reconciliation evidence.
- Replay source-of-truth requirements.
- Legacy coexistence and mixed-history classification.
- Difficult runner-out ambiguity preservation.
- Schema-version and migration implications for the next task.
- Transaction requirements for the later scoring persistence adapter.

The following work remains out of scope:

- Task 3.22 versioned canonical scoring persistence implementation.
- Task 3.23 scoring transaction, correction, supersession, and idempotency adapter.
- Task 3.24 persisted scoring replay and migration verification.
- Task 3.25 disposable canonical scoring persistence rehearsal.
- Task 2.21 renewed scoring-authority readiness.
- Task 7.21 bounded production scoring routing.
- Task 3.20 Legacy persistence retirement.
- Task 11.1 Legacy scoring retirement.

<!-- MARK: - 3. Repository Evidence -->
## 3. Repository Evidence

The design is grounded in the following repository evidence:

- Document 29 contains Task 3.21 and defines the dependency chain 3.21 -> 3.22 -> 3.23 -> 3.24 -> 3.25 -> 2.21 -> 7.21 -> 11.1.
- Documents 17 through 24 require recorded baseball facts to remain distinct from replay projections, reports, scorecards, imports, exports, and workflow routes.
- Document 20 requires fail-closed persistence and migration behavior, explicit source preservation, and no silent data repair.
- Documents 21, 22, and 24 treat compatibility files, scorecards, and reports as consumers or evidence, not as the canonical scoring source.
- Documents 26 through 28 keep inclusive interaction, verification, and phased implementation separate from production cutover.
- `ScoringAuthorityCutoverPreparationBaseline.md` records that production scoring remains Legacy, canonical production scoring has no caller, and difficult runner-out ambiguity must be preserved without inventing run validity, force/timing classification, RBI, pitcher responsibility, substitution timing, or completed-at-bat status.
- `ScoringAuthorityRoutingAndRetirementSplitBaseline.md` records that no command family is production eligible, current Game and Atbat persistence is lossy or ambiguous for canonical authority, canonical scoring events are not durably stored, correction and supersession are not durably stored, and durable idempotency/retry evidence is absent.
- `CorrectionAndIdempotencyBaseline.md` records that correction and idempotency are currently value-only and in-memory; persistent audit and persistent idempotency storage remain deferred.
- `LongGameReplayAndLegacyComparisonBaseline.md` records deterministic replay, explicit ordering evidence, duplicate-sequence failure, duplicate-event-identity failure, unsupported raw value preservation, classified comparison, and no SwiftData fetch-order dependency.
- `ProductionStartupRecoveryBaseline.md` records that Proposed V2 is the active production schema after successful startup, startup fails closed, simple manual Team creation is routed through a canonical one-writer transaction service, and scoring remains unchanged.
- `ScoreKeepProposedVersionedSchema.swift` defines Proposed V1 as Game, Team, Player, Atbat, Lineup, and Pitcher, and Proposed V2 as V1 plus TeamCreationOperationEvidenceRecord.
- `ScoreKeepProductionStartupHost.swift` opens Proposed V2 for current production startup and injects the active container into the app after startup succeeds.
- `CanonicalScoringCommand.swift`, `CanonicalScoringEventMeaning.swift`, `CanonicalEventApplication.swift`, `CanonicalGameReplay.swift`, and `CanonicalCorrectionPlanning.swift` define the current value-only canonical scoring event, replay, correction, and idempotency evidence.
- Apple SwiftData documentation confirms that autosave can implicitly save the main context, that `save()` writes pending changes, that rollback discards pending changes, that relationships need explicit delete rules when nullify is not sufficient, and that unique attributes and indexes are available but implementation details must still be verified by Task 3.22.

No production store, physical-device store, simulator, or build was used for this design.

<!-- MARK: - 4. Current Persistence Gap -->
## 4. Current Persistence Gap

Production persistence is currently adequate for the active Legacy scoring route but inadequate for canonical scoring authority.

The current gap is:

- Proposed V2 is active production storage after successful startup.
- Proposed V2 contains Game, Team, Player, Atbat, Lineup, Pitcher, and TeamCreationOperationEvidenceRecord.
- There are no persistent canonical scoring event, operation, correction, supersession, history, payload, replay, or scoring-idempotency models.
- Legacy Game and Atbat fields compact scoring information into display, report, and compatibility shapes that do not preserve all canonical facts.
- Current canonical commands and replay operate on value evidence only.
- Correction, supersession, duplicate command prevention, and replay recalculation are currently in-memory and non-routed.
- Production scoring remains Legacy.
- Canonical production scoring remains disabled.
- Task 3.20 remains not started.

Task 3.22 therefore requires a new schema version before any canonical scoring authority can be persisted.

<!-- MARK: - 5. Canonical Event Inventory -->
## 5. Canonical Event Inventory

The persistent design must account for every existing canonical scoring event family, including families that remain non-routable.

The common authoritative payload for every family is:

- Stable event identity.
- Stable game identity.
- Game-scoped ordering evidence.
- Inning context when supplied as recorded evidence.
- Team side.
- Batter identity when the event is a plate-appearance event or otherwise records batter context.
- Runner identities and base locations when the event asserts runner movement or runner out evidence.
- Result evidence.
- Outs evidence.
- Batter advancement.
- Runner advancement.
- Run evidence.
- RBI evidence.
- Earned-run evidence.
- Sacrifice evidence.
- Stolen-base evidence.
- End-of-half evidence.
- Historical display evidence when needed for Legacy comparison.
- Unsupported raw Legacy evidence when present.
- Source classification.

The common replay-derived facts are:

- Current count state.
- Current base occupancy.
- Current outs state.
- Current half-inning.
- Current score projection.
- Current and next batter projection.
- Active pitcher projection.
- Downstream score, inning, base, batter, and pitcher effects.
- Report and scorecard aggregates.

The common persistence gap is that none of these canonical scoring event families are durably stored today.

### Batter reaches base

- Purpose: Record a batter reaching first, second, or third on supported on-base result evidence such as Single, Double, Triple, Walk, Hit By Pitch, Dropped 3rd Strike, Catcher Interference, Fielder's Choice, or Error.
- Existing Swift type: `CanonicalScoringCommandIntent.batterReaches` and `CanonicalScoringEventEvidence`.
- Authoritative payload fields: batter identity, result evidence, destination base, runner destinations, RBI evidence, sacrifice evidence, stolen-base evidence, earned-run evidence, pitcher responsibility evidence when supplied, ordering evidence, and raw Legacy evidence when applicable.
- Stable identities referenced: game, event, operation, batter, runners, pitcher when supplied, and lineup/player identities carried by participant evidence.
- Facts directly asserted: batter destination, result label/classification, supplied runner destinations, supplied run/RBI/earned/sacrifice/stolen evidence, source, and ordering.
- Facts derived during replay: resulting base occupancy, score, outs, inning, next batter, and pitcher projection.
- Validation prerequisites: stable game identity, stable event identity, valid batter context, valid destination, valid ordering, valid runner identities for supplied movements, and no unsupported result contradiction.
- Correction behavior: can be replaced by another event or removed through correction planning; correction requires target game and event identity and recalculates downstream batter, base, score, inning, and pitcher projections as required by changed facts.
- Ordering requirements: participates in game-scoped deterministic sequence.
- At-bat completion: can complete a plate appearance.
- Outs: can change outs only through supplied runner-out or related outs evidence, not by batter reach alone.
- Innings: can change innings only when associated outs evidence reaches the boundary.
- Score: can change score through supplied runner scores or batter scoring in special evidence.
- Runner state: can change base occupancy.
- Pitcher responsibility: can affect pitcher responsibility only when explicit responsibility evidence exists.
- Unresolved ambiguity: can carry unsupported or conflicting raw evidence and unresolved run/RBI/pitcher evidence.
- Current persistence coverage: Legacy Atbat fields may contain a compact result, max base, RBI, earned-run, stolen-base, inning, sequence, and display text, but not exact canonical identity, operation, correction, runner identity, or replay-safe payload.
- Persistence gap: requires canonical event, payload, operation, and history storage.

### Home run

- Purpose: Record a batter home run and any supplied runner scoring evidence.
- Existing Swift type: `CanonicalScoringCommandIntent.homeRun` and `CanonicalScoringEventEvidence`.
- Authoritative payload fields: batter identity, home-run result evidence, runner destinations/scores, RBI evidence, earned-run evidence, pitcher responsibility evidence when supplied, ordering evidence, and source.
- Stable identities referenced: game, event, operation, batter, runners, pitcher when supplied.
- Facts directly asserted: batter scores, result is Home Run, supplied runner scoring, supplied RBI/earned/pitcher evidence.
- Facts derived during replay: final score, cleared/remaining bases, batter progression, inning state, and report totals.
- Validation prerequisites: stable game and event identity, valid batter identity, legal ordering, and valid runner identities for supplied scores.
- Correction behavior: replace or remove; replacement recalculates downstream score and base state.
- Ordering requirements: participates in deterministic game-scoped sequence.
- At-bat completion: can complete a plate appearance.
- Outs: does not assert an out unless contradictory supplied evidence is rejected.
- Innings: ordinarily does not change innings except through explicit compatible end evidence.
- Score: can change score.
- Runner state: can clear occupied bases for supplied scoring runners and batter.
- Pitcher responsibility: can affect responsibility only through explicit evidence.
- Unresolved ambiguity: can preserve incomplete run validity or pitcher responsibility evidence.
- Current persistence coverage: Legacy Atbat can store Home Run, max base, RBI, earned-run, inning, and sequence, but not exact canonical payload, event identity, operation identity, correction chain, or runner identities.
- Persistence gap: requires canonical event and operation storage.

### Batter out

- Purpose: Record a batter out result such as Ground Out, Fly Out, Line Out, Foul Out, Strikeout, Strikeout Looking, Sacrifice Fly, or Sacrifice Bunt.
- Existing Swift type: `CanonicalScoringCommandIntent.batterOut` and `CanonicalScoringEventEvidence`.
- Authoritative payload fields: batter identity, out result evidence, outs evidence, runner movements, RBI/sacrifice/stolen/earned evidence, pitcher responsibility evidence when supplied, ordering evidence, and source.
- Stable identities referenced: game, event, operation, batter, runners, pitcher when supplied.
- Facts directly asserted: batter result, out count evidence, supplied runner movements or scores, sacrifice markers, and source.
- Facts derived during replay: total outs, inning transition, score projection, next batter, and base occupancy.
- Validation prerequisites: stable identities, legal result evidence, valid out count, valid sequence, and valid runner evidence for associated movement.
- Correction behavior: replace or remove; recalculation may affect inning, batter progression, score, base, and pitcher projections.
- Ordering requirements: deterministic sequence.
- At-bat completion: can complete a plate appearance.
- Outs: can change outs.
- Innings: can change innings when outs reach the half-inning boundary.
- Score: can change score through supplied runner scores or RBI evidence.
- Runner state: can change runner state when movement is supplied.
- Pitcher responsibility: can affect pitcher responsibility only through explicit evidence.
- Unresolved ambiguity: can preserve run validity ambiguity for third-out situations.
- Current persistence coverage: Legacy Atbat stores compact result, outs, outAt, sacrifice markers, inning, sequence, and display text, but not full canonical relationships or correction evidence.
- Persistence gap: requires canonical event and correction-ready identity storage.

### Runner advances

- Purpose: Record a specific runner moving from one base to another without scoring.
- Existing Swift type: `CanonicalScoringCommandIntent.runnerAdvances` and `CanonicalScoringEventEvidence`.
- Authoritative payload fields: runner identity, from base, to base, stolen-base marker, ordering evidence, inning context, team side, and source.
- Stable identities referenced: game, event, operation, runner, originating reach event when available, and player identity carried by runner evidence.
- Facts directly asserted: runner movement and stolen-base evidence.
- Facts derived during replay: base occupancy and downstream run potential.
- Validation prerequisites: stable runner identity, legal source and destination bases, stable game and event identity, and ordering.
- Correction behavior: replace or remove; recalculates base and potentially score/inning if downstream events depend on the runner.
- Ordering requirements: deterministic sequence and explicit placement among intervening events.
- At-bat completion: does not by itself complete the current plate appearance.
- Outs: does not change outs.
- Innings: does not change innings.
- Score: does not change score.
- Runner state: changes runner state.
- Pitcher responsibility: does not affect pitcher responsibility unless future explicit evidence is added.
- Unresolved ambiguity: can preserve unresolved runner-source evidence if the runner identity is valid but score responsibility is incomplete.
- Current persistence coverage: Legacy Atbat may imply stolen base or max-base changes but does not reliably identify a runner across intervening batters.
- Persistence gap: requires stable runner identity and event sequence storage.

### Runner scores

- Purpose: Record a specific runner scoring from a base.
- Existing Swift type: `CanonicalScoringCommandIntent.runnerScores` and `CanonicalScoringEventEvidence`.
- Authoritative payload fields: runner identity, source base, RBI evidence, run evidence, earned-run evidence when supplied, pitcher responsibility evidence when supplied, ordering evidence, and source.
- Stable identities referenced: game, event, operation, runner, originating reach event when available, and pitcher when supplied.
- Facts directly asserted: runner scored, source base, and supplied run/RBI/earned/pitcher evidence.
- Facts derived during replay: score total, base occupancy, report totals, and downstream state.
- Validation prerequisites: stable runner identity, legal source base, valid ordering, and noncontradictory score evidence.
- Correction behavior: replace or remove; recalculates score and base state.
- Ordering requirements: deterministic sequence.
- At-bat completion: does not by itself complete the current plate appearance unless attached to a plate-appearance event.
- Outs: does not change outs.
- Innings: does not change innings by itself.
- Score: changes score.
- Runner state: removes or moves the runner from base occupancy.
- Pitcher responsibility: can affect responsibility only through explicit evidence.
- Unresolved ambiguity: can preserve unresolved run validity, RBI, earned-run, or pitcher responsibility evidence.
- Current persistence coverage: Legacy RBI and score fields are aggregates or compact fields and do not preserve runner identity or scoring causality.
- Persistence gap: requires canonical event and payload storage.

### Runner out

- Purpose: Record a specific runner being put out at a base, including delayed runner-out evidence after intervening batters.
- Existing Swift type: `CanonicalScoringCommandIntent.runnerOut` and `CanonicalScoringEventEvidence`.
- Authoritative payload fields: runner identity, from base, out-at base, out evidence, ordering evidence, inning context, team side, and ambiguity classifications.
- Stable identities referenced: game, event, operation, runner, originating reach event when available.
- Facts directly asserted: the runner, the source base, the out location, and the out evidence.
- Facts derived during replay: total outs, half-inning transition, base occupancy, next batter, and score validity where safe.
- Validation prerequisites: stable runner identity, legal bases, valid ordering, valid game identity, and noncontradictory out evidence.
- Correction behavior: replace or remove; recalculates outs, inning, base, score, and batter projections.
- Ordering requirements: must preserve position after intervening events and before the boundary it causes.
- At-bat completion: may leave the current batter incomplete.
- Outs: can change outs.
- Innings: can change innings when it is the third out.
- Score: can affect score validity but must not invent run validity.
- Runner state: removes the identified runner from base occupancy.
- Pitcher responsibility: not inferred without explicit evidence.
- Unresolved ambiguity: explicitly supported for third-out run validity, current-batter completion, RBI, pitcher responsibility, and timing/force facts.
- Current persistence coverage: Legacy Atbat `outAt`, `outs`, `endOfInning`, and display text are not enough to identify the original runner after intervening batters.
- Persistence gap: requires stable runner identity, event sequence, and ambiguity evidence.

### Multiple outs

- Purpose: Record an out-count change when a command carries multiple outs.
- Existing Swift type: `CanonicalScoringCommandIntent.multipleOuts` and `CanonicalScoringEventEvidence`.
- Authoritative payload fields: out count, ordering evidence, participant evidence when available, team side, inning context, and source.
- Stable identities referenced: game, event, operation, batter/runner identities when supplied.
- Facts directly asserted: requested out count and any supplied participants.
- Facts derived during replay: resulting outs, inning transition, base occupancy when supported, and batter progression when supported.
- Validation prerequisites: legal out count, stable event and game identity, valid ordering, and no contradictory participant evidence.
- Correction behavior: replace or remove; recalculates outs and inning downstream.
- Ordering requirements: deterministic sequence.
- At-bat completion: only when supported participant evidence proves plate-appearance completion.
- Outs: changes outs.
- Innings: can change innings.
- Score: does not establish score by itself.
- Runner state: only changes runner state when explicit runner evidence exists.
- Pitcher responsibility: not inferred.
- Unresolved ambiguity: can preserve unsupported participant shape or incomplete out causality.
- Current persistence coverage: Legacy Atbat outs can compact this but cannot prove participant identities or correction scope.
- Persistence gap: requires typed canonical payload and validation.

### End half inning

- Purpose: Record an explicit end-of-half-inning boundary.
- Existing Swift type: `CanonicalScoringCommandIntent.endHalfInning` and `CanonicalScoringEventEvidence`.
- Authoritative payload fields: end-of-half evidence, ordering evidence, inning context, team side, and source.
- Stable identities referenced: game, event, operation.
- Facts directly asserted: explicit boundary evidence.
- Facts derived during replay: next half-inning, cleared bases, next batting side, and next batter projection.
- Validation prerequisites: stable identities, valid ordering, and compatibility with current outs or accepted boundary policy.
- Correction behavior: replace or remove; recalculates inning, base, score, and batter projections downstream.
- Ordering requirements: must be sequenced after the events that justify or require the boundary.
- At-bat completion: does not by itself prove current batter completion.
- Outs: may coexist with third-out evidence but does not invent missing out causality.
- Innings: changes inning boundary.
- Score: does not change score.
- Runner state: clears or resets state through replay boundary rules.
- Pitcher responsibility: not inferred.
- Unresolved ambiguity: can preserve boundary evidence without inventing the missing out or batter result.
- Current persistence coverage: Legacy `endOfInning` is a compact marker, not canonical event authority.
- Persistence gap: requires canonical event storage and replay validation.

### Unsupported legacy evidence

- Purpose: Preserve unsupported, unknown, conflicting, or raw Legacy scoring evidence without silently treating it as active canonical authority.
- Existing Swift type: `CanonicalScoringCommandIntent.unsupportedLegacy`, `ScoringEventResultEvidence.unknownRawResult`, `ScoringEventResultEvidence.unsupportedRawResult`, `ScoringEventResultEvidence.conflicting`, and `CanonicalScoringEventEvidence.unsupportedRawLegacyEvidence`.
- Authoritative payload fields: raw unsupported evidence, classification, source, game identity, event identity, ordering evidence if known, and diagnostic codes.
- Stable identities referenced: game, event, operation when created by a future canonical route.
- Facts directly asserted: that unsupported evidence existed and how it was classified.
- Facts derived during replay: no scoring state may be derived unless a supported payload is also present and validated.
- Validation prerequisites: stable identity for persisted evidence and explicit unsupported classification.
- Correction behavior: can be targeted only by supported correction shapes; unsupported correction shape is rejected and recorded as operation evidence.
- Ordering requirements: sequence is preserved if the unsupported evidence is part of the history; replay may fail closed.
- At-bat completion: unsupported unless explicit supported payload exists.
- Outs: unsupported unless explicit supported payload exists.
- Innings: unsupported unless explicit supported payload exists.
- Score: unsupported unless explicit supported payload exists.
- Runner state: unsupported unless explicit supported payload exists.
- Pitcher responsibility: unsupported.
- Unresolved ambiguity: preserved explicitly.
- Current persistence coverage: Legacy raw fields exist only in Legacy storage and compatibility fixtures.
- Persistence gap: future canonical persistence must record classification, not normalize it away.

<!-- MARK: - 6. Durable-Fact Classification -->
## 6. Durable-Fact Classification

Canonical storage must distinguish persisted authority from replay projections.

Persisted authoritative facts:

- Event family and payload.
- Result evidence.
- Batter destination.
- Runner movement and runner-out evidence.
- Run, RBI, earned-run, sacrifice, stolen-base, and pitcher-responsibility evidence when explicitly supplied.
- Out evidence.
- End-of-half evidence.
- Unsupported raw evidence and ambiguity classifications.
- Source classification.
- Correction intent for accepted corrections.
- Supersession links.

Persisted identities and relationships:

- Game identity.
- Canonical history identity.
- Event identity.
- Operation identity.
- Correction identity.
- Correction operation identity.
- Batter identity.
- Pitcher identity when supplied.
- Runner identity.
- Lineup/player identity where participant evidence needs it.
- Originating reach event identity when available.
- Original target event identity.
- Replacement or correcting event identity.
- Superseding event identity.
- Stable relationship between canonical history and Game.
- Stable relationship between events, operations, corrections, payloads, and the canonical history.

Deterministically derived replay state:

- Count effects.
- Current outs after applying ordered events.
- Base occupancy after applying ordered events.
- Inning transitions.
- Score totals.
- Batter progression.
- Pitcher projection.
- Report totals.
- Scorecard placement.
- Active event list after applying correction selection.

Diagnostic-only evidence:

- Privacy-safe identity prefixes or hashes.
- Fresh-context verification results.
- Request fingerprints.
- Replay failure classifications.
- Migration verification evidence.
- Source-preservation evidence.
- Interrupted or uncertain-commit diagnostic codes.

Explicitly unresolved ambiguity:

- Third-out run validity when evidence is incomplete.
- Force-out or timing-play classification when not supplied.
- RBI validity when not supplied.
- Earned-run and pitcher-responsibility attribution when not supplied.
- Current-batter completion after runner-out boundary when not supported.
- Substitution timing when not supplied.
- Unsupported raw result evidence.

Unsupported and not persistable as active canonical authority yet:

- Any command family that Task 2.20 left non-routable.
- Any payload whose future event version is unsupported by the app.
- Any correction shape outside replace-event or remove-event semantics currently recognized by correction planning.
- Any Legacy-only inferred fact that lacks stable identity or unambiguous causality.

Operation evidence must be persisted for these states:

- Accepted.
- Rejected.
- Exact duplicate.
- Conflicting duplicate.
- Interrupted.
- Committed.
- Commit outcome uncertain.
- Reconciled.
- Verification completed.

Correction evidence must persist or classify:

- Original event.
- Correction intent.
- Replacement event when accepted.
- Supersession.
- Rejection.
- Unsupported correction shape.
- Chained-correction handling.

Replay projections must not be persisted merely because they are convenient to query. A redundant projection is allowed only if a later task documents a concrete performance or compatibility need and defines a consistency policy against canonical replay.

<!-- MARK: - 7. Legacy Field Assessment -->
## 7. Legacy Field Assessment

No current Legacy field can safely remain authoritative for canonical scoring.

Game fields:

- `Game.id`: exact identity reference only when stable and preserved; not event authority.
- Date, location, highlights, settings, and inning count: compatible game metadata, not scoring authority.
- Home and visiting team relationships: identity references and game setup evidence.
- `hscore` and `vscore`: deterministic projection or compatibility evidence; not canonical authority.
- Atbat, Lineup, Pitcher, Player, replaced, and incoming relationships: relationship evidence; array order is not canonical event order.

Atbat fields:

- `Atbat.id`: exact identity reference only for Legacy records or compatibility mapping; not a canonical event identity unless a future migration explicitly maps it, which this design rejects for existing games.
- `result`: compatible but lossy result text.
- `maxbase`: compatible but lossy batter or runner advancement evidence.
- `outAt`: ambiguous runner-out or batter-out evidence.
- `inning`: compatible but lossy context.
- `seq`: compatible source-order evidence, but not sufficient canonical sequence authority because duplicate and missing cases are already classified by replay.
- `col`: deterministic presentation projection.
- `rbis`, `outs`, `sacFly`, `sacBunt`, `stolenBases`, and `earnedRun`: compact scoring evidence or projections that lack full causality.
- `playRec`: display or Legacy narrative evidence.
- `endOfInning`: compatible boundary evidence but not sufficient canonical inning authority.
- Game, team, and player relationships: identity references only, not full canonical payload.

Team fields:

- `Team.id`: exact identity reference only.
- Name, coach, details, logo, and players: roster or display evidence, not scoring-event authority.
- Games relationship: ownership evidence for Legacy navigation, not canonical scoring history.

Player fields:

- `Player.id`: exact identity reference only.
- Name, number, position, batting direction, and bat order: player or roster evidence; mutable display and lineup fields are not scoring-event authority.
- Atbats relationship: Legacy relationship evidence, not canonical event sequence.

Lineup fields:

- `Lineup.id`: identity reference only.
- Everyone-hits, inning, team, players, and game relationships: lineup evidence that can seed replay input, but substitution timing and batter progression remain derived or unresolved unless explicit canonical evidence exists.

Pitcher fields:

- `Pitcher.id`: identity reference only.
- Player, team, game, innings, and aggregate statistics: pitcher-appearance or report evidence; not canonical event responsibility unless explicit event responsibility evidence exists.

Substitution storage:

- Replaced and incoming player lists are compatible but ambiguous for canonical substitution timing and role. They cannot be canonical scoring authority.

Score-related storage:

- Stored scores and report totals are deterministic projections or Legacy compatibility evidence. They remain useful for comparison and fail-closed mismatch classification, but not as the canonical source.

Fields that must remain Legacy projections rather than canonical sources include Atbat result/maxbase/outAt/seq/col/rbis/outs/playRec/endOfInning, Game hscore/vscore, Pitcher aggregate statistics, report totals, scorecard placement, and substitution lists.

<!-- MARK: - 8. Game Ownership -->
## 8. Game Ownership

Selected design: a dedicated canonical game-history model owns canonical scoring history and stores both a SwiftData relationship to Game and the stable game UUID.

Requirements:

- Every canonical event belongs to exactly one canonical game history.
- Every operation belongs to exactly one canonical game history.
- Every correction belongs to exactly one canonical game history.
- The canonical history belongs to exactly one Game.
- The stable game UUID is stored on the history and child records for fresh-context verification and diagnostics.
- Correction targets cannot cross games.
- Event sequence uniqueness is scoped to one canonical game history.
- Replay fetches one history and one game's child records only.
- Relationship-array order is irrelevant.
- Presence of an event never implies production canonical authority.

Advantages:

- Keeps canonical scoring separate from Legacy fields and avoids adding convenience scoring fields to Game.
- Provides a durable header for history state, completion, version, and Legacy coexistence classification.
- Supports fresh-context verification through stable game UUID even if a SwiftData relationship is missing or corrupt.
- Makes game deletion behavior explicit.
- Limits replay fetch scope.

Risks:

- Task 3.22 must implement and verify relationship delete rules and uniqueness constraints carefully.
- If a Game relationship is missing but stable game UUID remains, replay must fail closed rather than reattach silently.
- Existing Legacy games will usually have no canonical history header until a future route intentionally initializes one.

Deletion behavior:

- Deleting a Game through an approved game-deletion route may cascade-delete its canonical history, events, payloads, operations, and corrections because they are owned game data.
- Deleting an event independently is prohibited for normal scoring and correction flows.
- Removing a scoring fact is represented by correction/supersession evidence, not physical deletion.
- Administrative repair, if ever needed, is outside this task and must be separately approved.

Migration behavior:

- Proposed V2 stores migrate to the next schema without creating canonical histories for existing Legacy games.
- Empty stores migrate safely with empty canonical storage.
- A future canonical game can create an initialized history record before the first event.

Fresh-context verification:

- Fetch the Game by stable UUID.
- Fetch at most one canonical history for that stable UUID.
- Validate the relationship and the stored game UUID agree.
- Fail closed on missing relationship, duplicate history, wrong-game relationship, unsupported history version, or mixed-authority state.

Rejected ownership designs:

- Stable game UUID only without relationship: easier to migrate but weaker deletion behavior and relationship validation.
- Relationship only without stable UUID: unsafe for replay diagnostics, correction validation, and fresh-context verification.
- Embedding canonical metadata in Game: mixes Legacy and canonical authority and encourages production routing inference from Game fields.

<!-- MARK: - 9. Event Identity -->
## 9. Event Identity

Selected design: event identity is a stable value identity generated before insertion and stored independently from SwiftData object identity.

Requirements:

- Stable across relaunch.
- Stable across fresh-context fetch.
- Unique globally or, at minimum, unique within the canonical history.
- Not based on SwiftData persistent object identity.
- Not based on sequence.
- Supports correction and supersession.
- Supports duplicate detection.
- Supports privacy-safe diagnostics through a short prefix or hash, not full-value logging.

Decision:

- Use globally unique event identity values for newly created canonical events.
- Also store the owning game UUID and history relationship.
- Enforce uniqueness on event identity where SwiftData permits it.
- Transactionally validate that the event belongs to the expected game/history.
- Treat any same-game event identity reuse with identical payload as duplicate evidence only if it belongs to the same operation result.
- Treat same-game event identity reuse with different payload as contradictory duplicate evidence.
- Treat cross-game event identity reuse as corruption or conflicting import evidence unless a future import design explicitly authorizes retaining external identities in a namespaced field.

Generation timing:

- The caller or transaction request supplies the proposed event identity before validation.
- The transaction validates the identity and inserts it only after operation duplicate/conflict lookup and payload validation.
- The transaction must not allocate a new event identity when reconciling a retry for an existing operation.

Imported or migrated events:

- Existing Legacy games receive no synthesized canonical event identity during schema migration.
- A future import design may retain external identity only in a separate namespaced field and must still assign a local canonical event identity.

Random UUID alone is not sufficient for operation idempotency because retries, response loss, rejected operations, and conflicting reuse require operation evidence and request fingerprints.

<!-- MARK: - 10. Operation Identity and Idempotency -->
## 10. Operation Identity and Idempotency

Selected design: persist explicit scoring operation evidence separate from event envelopes.

Operation identity requirements:

- Stable across relaunch.
- Stable across retry.
- Supplied with the value-only request.
- Distinct from event identity.
- Scoped to exactly one game/history.
- Not based on timestamp, UI instance, memory state, SwiftData object identity, or sequence.
- Shared by correction retries when retrying the same correction request.

The operation evidence record must contain:

- Operation identity.
- Game UUID and history relationship.
- Operation kind: scoring event, correction, or unsupported/rejected attempt.
- Request fingerprint using a deterministic canonical value representation.
- Expected event identity or correction target identity.
- Accepted event identity when one was inserted.
- Correction identity when one was inserted.
- Allocated commit sequence when one was inserted.
- Disposition: accepted, rejected, exact duplicate, conflicting duplicate, interrupted, committed, commit outcome uncertain, reconciled, or verification completed.
- Rejection or diagnostic codes.
- Privacy-safe identity prefix/hash for diagnostics.
- Evidence schema version.

Classification rules:

- First accepted request: insert operation evidence, event payload, and any correction evidence in one transaction.
- Exact duplicate request: same operation identity, same game, same fingerprint, same expected identities, and same recorded result; return the recorded value result without creating a new event.
- Conflicting reuse: same operation identity but different fingerprint, game, target, payload, or proposed identity; reject and persist conflict classification when safe.
- Retry after response loss: lookup operation identity in a fresh context and return the committed result if evidence is complete.
- Retry after relaunch: same as response-loss retry; no memory registry is allowed.
- Interrupted operation: classify from durable operation/event/correction evidence and verification markers.
- Committed operation with missing response: operation and event/correction exist and fresh-context verification succeeds.
- Rejected operation: operation evidence persists rejection with no active event.
- Correction retry: operation identity and correction identity must match the prior correction request.
- Concurrent duplicate: one transaction wins the unique operation identity; the loser re-fetches and classifies exact duplicate or conflict.

Data required to distinguish exact duplicate from conflict:

- Operation identity.
- Game UUID.
- Operation kind.
- Deterministic request fingerprint.
- Proposed event identity.
- Target event identity for corrections.
- Replacement event identity for corrections.
- Payload family and payload version.
- Correction operation shape.
- Expected original event fingerprint when supplied.

Rejected strategies:

- Embedding operation fields only in an event envelope: cannot represent rejected requests, interrupted saves, or correction attempts without an event.
- Depending on event identity for idempotency: cannot classify rejected operations or response-loss retry safely.
- Depending on timestamps or UI state: nondeterministic and not replay-safe.

<!-- MARK: - 11. Event Ordering -->
## 11. Event Ordering

Selected design: game-scoped monotonic integer commit sequence, allocated inside the scoring transaction, plus correction replay-slot semantics.

Requirements:

- Stable across relaunch.
- Deterministic fetch sorting.
- Unique within one canonical history.
- Detects duplicate positions.
- Detects gaps.
- Does not rely on timestamps.
- Does not rely on SwiftData relationship-array order.
- Correction does not reorder unrelated history.
- Retry does not allocate a duplicate sequence.
- Concurrent requests are serialized by operation lookup and sequence allocation in one transaction.

Commit sequence:

- Every inserted event envelope receives a game-scoped monotonic `commitSequence`.
- The canonical history stores the last committed sequence as metadata and transaction evidence.
- The uniqueness invariant is history plus commit sequence.
- If SwiftData cannot enforce the compound uniqueness directly, Task 3.22 must add transaction validation and fresh-context verification.

Correction replay order:

- The original event retains its original commit sequence and payload.
- A replacement event receives its own commit sequence for audit.
- The correction record points to the original event and replacement event.
- Replay selects the active event for the original event's replay slot.
- The replacement event's payload is applied at the original event's replay position when the supersession is active.
- The replacement event's own commit sequence remains audit order, not a second replay position.
- A removal correction leaves the original sequence slot inactive and triggers replay from that boundary.

Gap and collision handling:

- Duplicate commit sequence is corruption or concurrent-write conflict.
- Sequence gap is incomplete history unless explicitly justified by future approved repair evidence.
- Missing payload at a sequence is incomplete or corrupt history.
- Active replacement without a valid original target is contradictory supersession.

Rejected strategies:

- Timestamp ordering: not authority and can change under clock skew or concurrent writes.
- Predecessor identity only: useful for diagnostics but harder to fetch, gap-check, and reconcile after retries.
- Logical token only: not currently supported by repository evidence and would still need a deterministic sortable value.

<!-- MARK: - 12. Payload Representation -->
## 12. Payload Representation

Selected design: one event envelope plus one versioned canonical payload record per event, using stable encoded value payload and explicit scalar discriminators.

The event envelope stores:

- Event identity.
- Game UUID.
- History relationship.
- Commit sequence.
- Event family discriminator.
- Event envelope version.
- Active/superseded/removed status.
- Source classification.
- Operation relationship.
- Payload relationship.
- Privacy-safe diagnostic identity.

The payload record stores:

- Payload identity.
- Event relationship.
- Event family discriminator.
- Payload version.
- Scoring semantics version.
- Stable canonical encoded payload.
- Payload fingerprint.
- Unsupported or ambiguity classification when present.
- Decoder diagnostic state when validation fails.

Stable encoding requirements:

- The encoded payload must be a deterministic value representation of existing canonical evidence fields.
- Keys and enum raw values must be stable and versioned.
- Encoding must not include SwiftData object identity, memory addresses, localized strings, timestamps, or UI-only values.
- The payload fingerprint must be computed from the stable canonical value representation.
- Task 3.22 must add test vectors for every existing event family and representative unsupported evidence.

Decoder failure behavior:

- Invalid payload fails closed.
- Unsupported future payload version fails closed as unsupported future version.
- Unsupported future event family fails closed.
- Unknown optional diagnostic fields may be ignored only when the payload version explicitly permits compatibility.
- No malformed event may be silently skipped.

Migration policy:

- Old payload versions are decoded through compatibility logic when supported.
- Payloads are not rewritten in place during ordinary replay.
- In-place payload migration requires a later explicit migration task and pre/post verification.
- A SwiftData schema migration is required when persistent model fields, relationships, constraints, or indexes change; event semantic changes alone do not automatically require a schema migration.

Alternative evaluation:

- One model per canonical event family: exact and queryable but high schema complexity, more migration churn, and many relationships for unsupported families.
- Wide nullable envelope: simple fetch shape but high invalid-combination risk and large validation burden.
- Opaque event log only: compact but weak queryability and risky without stable encoding and version rules.
- Envelope plus typed child payload models: exact but still creates many schema entities and relationship/delete-rule surface.
- Selected envelope plus versioned canonical payload record: keeps identity, ordering, operation, correction, and fetch indexes queryable while preserving exact family payloads through stable encoding and test vectors.

This is not approval to persist arbitrary opaque blobs. The encoded payload is canonical only if Task 3.22 implements deterministic encoding, version discriminators, fail-closed decoder behavior, future-version handling, migration policy, and test vectors.

<!-- MARK: - 13. Versioning -->
## 13. Versioning

Versioning is separate across storage, envelope, payload, and scoring semantics.

SwiftData schema version:

- Stored in the versioned schema declaration.
- Changes when persistent models, fields, relationships, constraints, or indexes change.
- The next required schema is Proposed V3.

Event envelope version:

- Stored on every event envelope.
- Changes when envelope fields or envelope-level interpretation changes.
- Unsupported future envelope versions fail closed.

Event payload version:

- Stored on every payload record.
- May vary by event family.
- Changes when the stable payload representation for a family changes.
- Replay may combine supported payload versions if compatibility decoders exist.
- Unsupported future payload versions fail closed.

Scoring semantics version:

- Stored on payload or history when replay semantics change independently from storage shape.
- Does not automatically require a SwiftData schema change.
- Replay must reject or classify unsupported future semantics.

History format version:

- Stored on the canonical game-history header.
- Defines the compatible set of envelope, payload, operation, correction, and classification rules for that history.

Fail-closed rules:

- Unsupported future history version: unsupported future version.
- Unsupported future envelope version: unsupported future payload/history.
- Unsupported future payload version: unsupported future payload.
- Unsupported semantics version: replay failure or unsupported future version.
- Mixed supported and unsupported payloads: history is not complete and canonical authority must not route.

<!-- MARK: - 14. Correction and Supersession -->
## 14. Correction and Supersession

Selected design: immutable event payloads with explicit correction records, supersession relationships, operation evidence, and mutable status metadata only.

Durable correction requirements:

- Preserve original event identity and payload.
- Preserve correction operation identity.
- Preserve correction identity.
- Preserve target game identity.
- Preserve target original event identity.
- Preserve replacement event identity for accepted replace-event corrections.
- Preserve active versus superseded or removed authority.
- Preserve rejection evidence for rejected correction operations in operation evidence.
- Preserve unsupported correction shape classification.
- Preserve downstream recalculation boundary.

Accepted replace-event correction:

- Inserts or references a correction operation evidence record.
- Inserts a replacement event with its own event identity and commit sequence.
- Inserts a correction record linking original event and replacement event.
- Marks the original event status as superseded.
- Marks the replacement as active for the original replay slot.
- Records earliest replay position from the original event sequence.

Accepted remove-event correction:

- Inserts or references a correction operation evidence record.
- Inserts a correction record targeting the original event.
- Marks the original event status as removed or superseded by removal.
- Does not physically delete the original payload.
- Records earliest replay position from the original event sequence.

Rejected correction:

- Persists operation evidence with rejection or unsupported classification.
- Does not alter event active status.
- Does not insert active replacement payload.

Duplicate correction:

- Same operation identity and same request fingerprint returns the prior correction result.
- Same correction target and same payload with a different operation identity is a semantic repeat and requires explicit classification.
- Same operation identity with different target or payload is a conflicting duplicate.

Conflicting correction:

- Missing target: rejected.
- Cross-game target: rejected.
- Duplicate target identity: contradictory.
- Already superseded target: rejected unless the request targets the current active replacement under a future explicit chained-correction policy.
- Stale expected original event: rejected.
- Unsupported correction shape: rejected or unsupported.

Chained-correction policy:

- The current supported policy is to correct the currently active event only.
- A correction of an already superseded original event is rejected as stale.
- A later task may define explicit chain traversal, but Task 3.22 must not invent it.

Physical deletion is not the normal correction mechanism.

<!-- MARK: - 15. Immutable History -->
## 15. Immutable History

Selected policy: committed canonical scoring history is append-only for event payloads and operation facts.

Allowed after commit:

- Event status metadata may change from active to superseded or removed as part of an accepted correction.
- Correction verification metadata may be completed.
- Operation reconciliation metadata may be completed.
- History verification status may be updated.

Prohibited after commit:

- Editing an event payload in place.
- Editing a request fingerprint in place.
- Reassigning an event to another game.
- Reassigning an operation to another game.
- Reordering committed sequences.
- Physically deleting an event to represent correction.

Corruption handling:

- Unsupported or contradictory records fail closed.
- Administrative repair is outside this task and requires a later approved design.
- Replay must not silently skip malformed records.

Deletion:

- Independent event deletion is prohibited.
- Approved Game deletion may cascade delete owned canonical history.
- Retention after Legacy retirement follows game retention unless a future retention design says otherwise.

<!-- MARK: - 16. Canonical History Classification -->
## 16. Canonical History Classification

Selected design: use a dedicated canonical game-history header. Do not derive canonical authority from event presence alone.

History classifications:

- Legacy-only: no canonical history header exists for the Game, or a future explicit header marks Legacy-only without active canonical authority.
- Canonical history initialized but empty: header exists, format version is supported, no events exist, and canonical authority is not complete.
- Canonical history present but incomplete: header exists, events or operations exist, but completion/verification invariants are incomplete.
- Canonical history complete: header exists, versions are supported, event/operation/correction invariants verify, and completion evidence marks canonical authority complete for the intended boundary.
- Canonical history corrupt: duplicate identity, duplicate sequence, missing relationship, invalid payload, contradictory correction, wrong-game ownership, or other invariant failure.
- Mixed authority: Legacy scoring evidence and canonical authority evidence conflict or appear in a state not approved by a routing task.
- Unsupported future version: history, envelope, payload, or semantics version is newer than this app supports.

Header responsibilities:

- Game identity.
- History identity.
- History-format version.
- Creation operation when applicable.
- Initialized status.
- Active authority or completion status.
- Last committed sequence.
- Verification status.
- Legacy coexistence classification.
- Diagnostic codes.

Rejected designs:

- Deriving state solely from events: unsafe because one event would appear to create canonical authority.
- Embedding history metadata in Game: mixes Legacy and canonical storage and increases risk of accidental routing inference.
- Using only operation evidence: cannot represent initialized-empty history or Legacy-only classification clearly.

<!-- MARK: - 17. Replay Requirements -->
## 17. Replay Requirements

Persisted replay source of truth is the canonical game history plus its event envelopes, payload records, operation evidence, and correction records.

Task 3.24 must reconstruct state as follows:

1. Fetch exactly one Game by stable game UUID.
2. Fetch exactly one canonical game history for that Game when canonical history is expected.
3. Validate history relationship and stored game UUID.
4. Fetch operations, event envelopes, payloads, and corrections scoped to that history only.
5. Sort events by commit sequence for audit validation.
6. Validate event identity uniqueness.
7. Validate operation identity uniqueness.
8. Validate sequence uniqueness and gaps.
9. Validate payload family, payload version, and semantics version.
10. Validate correction relationships and same-game ownership.
11. Select active events for replay slots after applying correction/supersession records.
12. Decode value-event payloads into `CanonicalScoringEventEvidence`.
13. Replay deterministically with no timestamp or relationship-array-order authority.
14. Return a value-only replay result and classification.

Required failure classifications:

- No canonical history.
- Complete canonical history.
- Incomplete canonical history.
- Unsupported future payload.
- Duplicate event identity.
- Duplicate operation identity.
- Sequence gap.
- Sequence collision.
- Wrong-game ownership.
- Missing correction target.
- Contradictory supersession.
- Invalid payload.
- Mixed Legacy/canonical evidence.
- Replay failure.

No malformed event may be silently skipped. If replay cannot safely apply one event, the history is incomplete, unsupported, contradictory, corrupt, or failed according to the detected condition.

<!-- MARK: - 18. Legacy Coexistence -->
## 18. Legacy Coexistence

Existing Legacy games remain Legacy-only after the schema migration.

Coexistence rules:

- Existing Legacy games remain readable.
- Existing Legacy games receive no synthesized canonical events during schema migration.
- Existing Legacy games retain current production scoring behavior.
- Existing Legacy games retain current report and statistics behavior.
- Existing baseball data is preserved unchanged.
- A game does not become canonically authoritative merely because one canonical event exists.
- Mixed authority fails closed until a later routing task explicitly approves the transition.
- Task 3.22 must not activate production canonical scoring.

Durable marker:

- The canonical game-history header is the durable marker of canonical history state.
- No header means Legacy-only unless a future repair or migration design explicitly records otherwise.
- Header completion and verification status, not event presence, determines whether canonical history can be considered complete.

Legacy projections:

- Legacy Atbat, Game score fields, scorecards, reports, and export compatibility records remain projections or compatibility evidence.
- Canonical replay may compare against those values later, but must not treat them as canonical source facts.

<!-- MARK: - 19. Difficult Runner-Out Boundary -->
## 19. Difficult Runner-Out Boundary

The selected design can represent the difficult runner-out case without inventing unsupported baseball facts.

Persisted facts:

- Original reach event identity, payload, batter identity, runner identity, destination base, and commit sequence.
- Stable runner identity that can survive intervening events.
- Intervening events with their own event identities and sequences.
- Later runner-out event identity, payload, runner identity, from base, out-at base, out evidence, and commit sequence.
- Third-out evidence when supplied by the runner-out event and replay state.
- End-half evidence when explicitly present or replay-derived from supported out state.
- Score evidence that was explicitly supplied.
- Ambiguity classification for unresolved run validity, current-batter completion, RBI, pitcher responsibility, force/timing, or substitution timing.

Replay-derived facts:

- The original runner remains on base through intervening events when replay evidence supports it.
- The later runner-out removes that runner.
- The third out ends the current half-inning.
- Base occupancy and batting side reset for the next half-inning.
- Next batter progression is derived only when lineup and event evidence safely support it.

Facts not invented:

- Force-out classification.
- Timing-play classification.
- Run validity.
- RBI.
- Pitcher responsibility.
- Completed at-bat status for the current batter.
- Substitution timing.

Result:

- The case is representable because canonical storage persists stable runner identity, event identity, event order, runner-out payload, third-out evidence, and ambiguity classification separately from replay projections.

<!-- MARK: - 20. Relationships and Delete Rules -->
## 20. Relationships and Delete Rules

Every relationship must have explicit cardinality, optionality, inverse, delete rule, ownership, and stable value identity.

Canonical history to Game:

- Cardinality: one history belongs to one Game; a Game may have zero or one canonical history under the current design.
- Optionality: history relationship to Game is required for valid canonical history.
- Inverse: Game may expose history only if Task 3.22 can do so without Legacy coupling; otherwise history stores the relationship and stable game UUID.
- Delete rule: Game deletion cascades to history through the approved game-deletion route.
- Ownership: Game owns history.
- Stable ID: game UUID stored on history.
- Missing relationship: corrupt or incomplete history, not silently repaired.

Scoring event to canonical history:

- Cardinality: many events to one history.
- Optionality: event history relationship required.
- Inverse: history may hold unordered events; array order irrelevant.
- Delete rule: history cascades to events.
- Ownership: history owns events.
- Stable ID: event identity and game UUID stored on event.
- Missing relationship: corrupt.

Payload to scoring event:

- Cardinality: one payload to one event.
- Optionality: required for valid active or superseded event.
- Inverse: event owns payload.
- Delete rule: event cascades to payload.
- Ownership: event owns payload.
- Stable ID: payload identity and event identity stored.
- Missing relationship: invalid payload or incomplete history.

Operation evidence to canonical history:

- Cardinality: many operations to one history.
- Optionality: required.
- Inverse: history may hold unordered operations.
- Delete rule: history cascades to operations.
- Ownership: history owns operation evidence.
- Stable ID: operation identity and game UUID stored.
- Missing relationship: corrupt.

Operation evidence to event:

- Cardinality: zero or one accepted event for a scoring operation; correction operations may link to correction evidence instead.
- Optionality: optional because rejected operations have no event.
- Delete rule: no action or nullify is not sufficient for correctness; Task 3.22 must select an implementation that preserves operation evidence while event deletion remains prohibited.
- Stable ID: accepted event identity stored on operation evidence.
- Missing accepted event relationship with stored event identity: incomplete or uncertain commit requiring reconciliation.

Correction to canonical history:

- Cardinality: many corrections to one history.
- Optionality: required for accepted correction evidence.
- Delete rule: history cascades to corrections.
- Stable ID: correction identity and game UUID stored.

Correction to original event:

- Cardinality: one original event per accepted correction.
- Optionality: required.
- Delete rule: original event deletion is prohibited; if missing, replay fails closed.
- Stable ID: original event identity stored.

Correction to replacement event:

- Cardinality: zero or one replacement event.
- Optionality: required for replace-event correction, absent for remove-event correction.
- Delete rule: replacement event deletion is prohibited; if missing for replacement correction, replay fails closed.
- Stable ID: replacement event identity stored when applicable.

Event to existing Player, Lineup, Pitcher, or Team:

- Direct relationships are not selected for canonical event payloads.
- Stable value identities are stored instead.
- This avoids mutable relationship coupling and keeps replay value-only.

No relationship may depend on array order for replay or authority.

<!-- MARK: - 21. Uniqueness and Indexes -->
## 21. Uniqueness and Indexes

Correctness-enforcing uniqueness requirements:

- One canonical history per game UUID.
- Unique event identity.
- Unique operation identity.
- Unique correction identity.
- Unique history plus commit sequence.
- At most one active supersession for a target event.
- One payload per event.

Performance-only indexes:

- Game UUID to history lookup.
- History plus active status plus replay sequence for replay fetch.
- History plus commit sequence for audit validation.
- Operation identity for retry lookup.
- Event identity for correction target lookup.
- Correction target event identity for active-event selection.
- Event family for diagnostics and selective verification.
- History classification for migration and startup verification.

Invariants that may require transaction validation because SwiftData support must be verified:

- Compound uniqueness for history plus commit sequence.
- Compound uniqueness for game plus operation identity if global uniqueness is not used.
- One active supersession per original event.
- Same-game ownership across correction original and replacement events.
- Payload family matching envelope family.
- Operation fingerprint matching result evidence.

SwiftData documentation confirms unique attributes and indexes exist, but Task 3.22 must verify the exact macro support, compound uniqueness shape, generated schema, and migration behavior in this project before relying on any single SwiftData constraint.

No index is approved solely for convenience. Each index must support replay fetch, correction lookup, retry lookup, startup verification, or migration verification.

<!-- MARK: - 22. Transaction Requirements -->
## 22. Transaction Requirements

Task 3.23 must implement a scoring transaction adapter with this contract.

Required adapter behavior:

- Accept a value-only request.
- Require stable game identity, operation identity, and proposed event identity before mutation.
- Use a dedicated `ModelContext`.
- Set autosave disabled for the transaction context.
- Avoid the SwiftUI environment main context for writes.
- Perform operation duplicate/conflict lookup before sequence allocation.
- Validate game/history ownership before insertion.
- Validate payload family and request fingerprint before insertion.
- Allocate sequence inside the transaction.
- Insert operation evidence, event envelope, payload, and correction/supersession evidence as one unit when accepted.
- Roll back before commit on validation failure.
- Perform one explicit save for accepted mutations.
- Produce value-only result data.
- Run fresh-context verification after save.
- Reconcile uncertain commits from durable evidence.
- Prevent managed models from escaping.
- Avoid UI save.
- Avoid production callers until later routing approval.

Invariants enforced inside one transaction:

- Operation identity uniqueness.
- Event identity uniqueness.
- Game/history ownership.
- Sequence allocation and uniqueness.
- Payload validity.
- Correction target same-game validation.
- Correction active-target validation.
- Supersession uniqueness.
- History last-committed-sequence update.
- Operation result and event/correction evidence consistency.

No in-memory registry may be required for correctness.

<!-- MARK: - 23. Reconciliation -->
## 23. Reconciliation

Durable evidence must permit deterministic uncertain-commit classification.

Cases:

- Save throws before commit: rollback if possible, then fresh-context lookup by operation identity.
- Save may have committed but response was lost: fresh-context lookup by operation identity and event/correction identity.
- App terminates immediately after save: retry after relaunch performs fresh-context lookup.
- Fresh-context lookup finds matching operation and complete result evidence: classify as committed and return the recorded result.
- Fresh-context lookup finds matching operation with conflicting fingerprint: classify as conflicting duplicate.
- Sequence allocated but event absent: classify as interrupted or corrupt; do not blindly reinsert.
- Event present but completion evidence absent: classify as commit outcome uncertain and verify event/payload/correction consistency.
- Correction partly represented: classify as incomplete correction evidence and fail closed until repaired by an approved task.
- Retry after relaunch: same deterministic lookup; no memory state.

Required durable fields:

- Operation identity.
- Request fingerprint.
- Game UUID.
- Operation kind.
- Proposed event identity.
- Accepted event identity.
- Correction identity.
- Original and replacement event identities for corrections.
- Commit sequence.
- Operation disposition.
- Verification status.
- Diagnostic codes.

Blind reinsertion is prohibited whenever any durable evidence for the operation, event, sequence, or correction target exists.

<!-- MARK: - 24. Schema Decision -->
## 24. Schema Decision

Decision: a new schema is required.

Reason:

- Production storage currently has no canonical scoring persistent models.
- Canonical scoring requires new persistent models, relationships, constraints, and indexes.
- Existing Legacy fields cannot be canonical scoring authority.

Proposed next sequential schema:

- Proposed V3, following Proposed V2.

Proposed new persistent-model count:

- Five.

Proposed models:

- Canonical game-history header.
- Canonical scoring operation evidence.
- Canonical scoring event envelope.
- Canonical scoring event payload.
- Canonical scoring correction/supersession evidence.

Existing models:

- Game unchanged.
- Team unchanged.
- Player unchanged.
- Atbat unchanged.
- Lineup unchanged.
- Pitcher unchanged.
- TeamCreationOperationEvidenceRecord unchanged.

Expected migration type:

- Additive model migration appears intended, but lightweight migration is not proven by this design.
- Task 3.22 must verify generated schema, uniqueness/index support, relationship delete rules, V2-to-V3 migration, interrupted migration behavior, and startup recovery.

Circumstances requiring custom migration:

- SwiftData cannot add the selected relationships, uniqueness, or indexes through lightweight migration.
- Existing stores require relationship backfill or data repair.
- Compound uniqueness or delete rules require data transformation.
- Task 3.22 discovers generated schema incompatibility.

Production container changes required in Task 3.22:

- Add Proposed V3 schema declaration.
- Include the five new canonical scoring models.
- Add V2-to-V3 migration stage.
- Update Proposed container factory and startup host to open V3 only after migration verification.
- Preserve fail-closed startup behavior.

Startup recovery implications:

- Startup must continue to fail closed.
- Source preservation and backup policy remain active.
- Opening a V2 store under V3 must not create canonical histories or events.
- Relaunch after completed migration must open the new schema.

Disposable migration-test implications:

- Task 3.22 must verify empty-store migration.
- Task 3.22 must verify populated V2-store migration.
- Task 3.22 must verify interrupted migration recovery.
- Task 3.22 must verify repeated migration idempotency.
- Task 3.22 must verify no production scoring route is enabled.

<!-- MARK: - 25. Migration Requirements -->
## 25. Migration Requirements

Task 3.22 migration invariants:

- Existing Game records unchanged.
- Existing Team records unchanged.
- Existing Player records unchanged.
- Existing Lineup records unchanged.
- Existing Atbat records unchanged.
- Existing Pitcher records unchanged.
- Existing TeamCreationOperationEvidenceRecord records unchanged.
- Existing counts unchanged.
- Existing fingerprints unchanged.
- Existing relationships unchanged.
- No canonical events synthesized.
- No canonical histories silently activated.
- New canonical storage begins empty for Legacy games.
- Proposed V2 stores migrate safely.
- Empty stores migrate safely.
- Repeated migration is idempotent.
- Interrupted migration remains recoverable.
- Startup remains fail closed.
- Source preservation and backup policy remain active.
- Completed migration relaunch opens Proposed V3.
- Difficult runner-out Legacy evidence remains unchanged.

Migration evidence to capture:

- Pre/post record counts for all existing models.
- Pre/post stable identities for existing records.
- Pre/post relationship counts for Game, Team, Player, Lineup, Atbat, and Pitcher.
- Pre/post Legacy score and Atbat field fingerprints.
- Count of canonical history records after migration for existing Legacy stores: zero unless a fixture explicitly created one under V3.
- Count of canonical event, payload, operation, and correction records after V2 migration: zero.
- Migration journal/source preservation state.
- Startup route and active schema evidence.
- Relaunch open evidence.
- Failure classification for interrupted migration.

<!-- MARK: - 26. Alternatives -->
## 26. Alternatives

Alternative: reuse Legacy Game and Atbat fields as canonical authority.

- Accepted benefits: no schema change, current UI/report compatibility, minimal implementation.
- Rejected because: fields are lossy and ambiguous; they lack event identity, operation identity, correction/supersession evidence, stable runner identity across intervening batters, durable idempotency, payload versioning, and replay-safe ordering. Task 2.20 already identifies current Game and Atbat persistence as unsafe for canonical authority.

Alternative: separate canonical event persistence with history, operation, correction, and payload records.

- Accepted benefits: preserves exact canonical facts, separates Legacy coexistence, supports replay, correction, idempotency, retry reconciliation, versioning, and migration safety.
- Accepted risks: requires a new schema and careful migration/constraint verification.
- Decision: selected.

Alternative: opaque serialized event log only.

- Accepted benefits: small schema, easy event-family expansion.
- Rejected as a standalone design because: weak queryability, hard operation/correction lookup, difficult sequence validation, risky decoder failure behavior, and insufficient SwiftData relationship/delete-rule clarity. Stable encoded payload is accepted only inside a queryable envelope/history/operation/correction design.

Alternative: one SwiftData model per canonical event family.

- Accepted benefits: strong field-level exactness and queryability.
- Rejected because: high schema complexity, many future migrations for event-family changes, complex correction relationships, and more invalid cross-model edge cases. Current repository evidence does not require family-specific queries that justify this burden.

Alternative: wide nullable event envelope.

- Accepted benefits: one fetch shape and direct scalar fields.
- Rejected because: many invalid field combinations, hard validation, and ongoing nullable-field burden for unsupported or future event families.

Selected rationale:

- Correctness: identity, ordering, operation, correction, and replay invariants are explicit.
- Exactness: stable payload encoding preserves canonical value facts.
- Migration safety: new models are additive and do not mutate Legacy records.
- Correction: original and replacement evidence are both retained.
- Idempotency: durable operation evidence exists for accepted and rejected requests.
- Replay: deterministic fetch and validation rules are explicit.
- Legacy coexistence: history header prevents accidental authority.
- Implementation complexity: five models are bounded for Task 3.22.
- Future extensibility: payload versions and event family discriminators support future event additions without changing Legacy fields.

<!-- MARK: - 27. Proposed Model Inventory -->
## 27. Proposed Model Inventory

The names below are proposed for Task 3.22 and may be adjusted to match repository conventions. Responsibilities and invariants are normative.

Canonical game-history header:

- Responsibility: own one game's canonical scoring history and classify coexistence/verification state.
- Identity: stable history identity and stable game UUID.
- Required attributes: history identity, game UUID, history format version, initialized status, authority/completion status, last committed sequence, verification status, Legacy coexistence classification, evidence schema version, diagnostic codes.
- Optional attributes: creation operation identity, verification completed timestamp if a later task approves non-authoritative diagnostics.
- Relationships: required Game relationship; unordered events, operations, and corrections.
- Uniqueness: one history per game UUID.
- Indexes: game UUID, classification, verification status.
- Delete rules: owned by Game; cascades to child canonical records when Game deletion is approved.
- Version fields: history format version and evidence schema version.
- Invariants: relationship Game UUID must match stored game UUID; event presence does not imply complete canonical authority.
- Prohibited responsibilities: storing replay projections, Legacy score fields, or UI state.

Canonical scoring operation evidence:

- Responsibility: persist idempotency, request fingerprint, retry, rejection, and reconciliation evidence.
- Identity: stable operation identity.
- Required attributes: operation identity, game UUID, operation kind, request fingerprint, disposition, evidence schema version, verification status, diagnostic codes.
- Optional attributes: proposed event identity, accepted event identity, correction identity, target event identity, replacement event identity, commit sequence, rejection reason, privacy-safe identity prefix/hash.
- Relationships: required history; optional accepted event; optional correction.
- Uniqueness: operation identity.
- Indexes: operation identity, game UUID plus disposition, verification status.
- Delete rules: history cascades; event deletion prohibited.
- Version fields: evidence schema version.
- Invariants: same operation identity cannot represent two fingerprints; rejected operations may have no event.
- Prohibited responsibilities: storing event payload authority or replay projections.

Canonical scoring event envelope:

- Responsibility: persist event identity, ownership, ordering, event family, active status, and envelope-level version.
- Identity: stable event identity.
- Required attributes: event identity, game UUID, commit sequence, event family, envelope version, active/superseded/removed status, source classification, evidence schema version, diagnostic identity prefix/hash.
- Optional attributes: originating operation identity, superseded-by correction identity, replay-slot original event identity for replacements.
- Relationships: required history; required payload; optional operation; optional correction links.
- Uniqueness: event identity and history plus commit sequence.
- Indexes: history plus commit sequence, history plus active status plus sequence, event identity, event family.
- Delete rules: history cascades; independent event deletion prohibited.
- Version fields: envelope version and evidence schema version.
- Invariants: payload family matches event family; commit sequence is immutable after commit.
- Prohibited responsibilities: storing mutable replay state or Legacy display-only fields as authority.

Canonical scoring event payload:

- Responsibility: persist the exact value payload for one canonical event.
- Identity: stable payload identity or event identity-derived payload identity.
- Required attributes: payload identity, event identity, event family, payload version, scoring semantics version, stable encoded payload, payload fingerprint.
- Optional attributes: unsupported classification, ambiguity classification, decoder diagnostic state.
- Relationships: required event.
- Uniqueness: one payload per event.
- Indexes: event identity, event family, payload version.
- Delete rules: event cascades to payload.
- Version fields: payload version and scoring semantics version.
- Invariants: encoded payload must decode deterministically for supported versions; invalid payload fails closed.
- Prohibited responsibilities: storing SwiftData object identity, UI state, localized strings, or timestamps as authority.

Canonical scoring correction/supersession evidence:

- Responsibility: persist accepted correction relationships and active replay-slot authority.
- Identity: stable correction identity.
- Required attributes: correction identity, game UUID, correction operation identity, original event identity, correction operation shape, disposition, earliest replay sequence, evidence schema version.
- Optional attributes: replacement event identity, expected original event fingerprint, rejection diagnostic if a later task chooses to persist rejected correction rows.
- Relationships: required history; required original event for accepted correction; optional replacement event for replace-event correction; required operation evidence.
- Uniqueness: correction identity; one active supersession per original event.
- Indexes: correction identity, original event identity, replacement event identity, operation identity.
- Delete rules: history cascades; event deletion prohibited.
- Version fields: evidence schema version.
- Invariants: original and replacement events must belong to the same history; already superseded target is rejected under current policy.
- Prohibited responsibilities: physically deleting original events or rewriting original payloads.

<!-- MARK: - 28. Task 3.22 Boundary -->
## 28. Task 3.22 Boundary

Task 3.22 may implement:

- Proposed V3 schema declaration.
- The five proposed persistent models.
- V2-to-V3 migration stage.
- Proposed container factory and startup updates required to open V3.
- Schema and migration verification for empty and populated stores.
- Constraints, indexes, relationships, and delete-rule verification.
- Test vectors for stable payload encoding and decoding if model implementation includes payload fields.

Task 3.22 must not implement:

- Production scoring routes.
- Scoring transaction adapter.
- Persisted replay adapter.
- Correction transaction adapter.
- Canonical history synthesis for existing Legacy games.
- Legacy persistence retirement.
- UI scoring changes.
- Report routing changes.
- Physical-device migration.
- Task 3.20, 3.23, 3.24, 3.25, 2.21, 7.21, or 11.1.

Unresolved Task 3.22 verification questions:

- Whether SwiftData compound uniqueness can directly enforce history plus commit sequence in this project.
- Whether SwiftData relationship delete rules generate the intended cascade and deny behavior for the proposed graph.
- Whether the additive V3 migration is lightweight in practice.
- Whether selected indexes are supported on the exact stored fields.
- Whether stable encoded payload data should be stored as String or Data after deterministic encoding tests.
- Whether privacy-safe identity prefixes should be stored or computed from stored identities.
- Whether rejected correction attempts need a correction row or operation evidence alone is sufficient for the first implementation.

These are implementation verification questions, not open semantic decisions.

<!-- MARK: - 29. Acceptance Criteria -->
## 29. Acceptance Criteria

Task 3.21 acceptance criteria are satisfied by this document:

- Exhaustive durable-fact inventory is defined.
- Legacy-field assessment is explicit.
- Event-payload strategy is selected.
- Ownership model is selected.
- Event identity is selected.
- Operation identity is selected and separate from event identity.
- Ordering strategy is selected.
- Correction and supersession model is selected.
- Canonical-history classification is selected.
- Immutable-history policy is selected.
- Relationship and delete-rule policy is selected.
- Uniqueness and index policy is selected.
- Schema-version decision is explicit.
- Migration invariants are defined.
- Transaction requirements are defined for Task 3.23.
- Replay requirements are defined for Task 3.24.
- Difficult runner-out proof is provided.
- Alternative analysis is provided.
- Task 3.22 implementation boundary is precise.
- Production scoring remains Legacy.
- Canonical production scoring remains disabled.
- No SwiftData schema was implemented by this task.
- No production data was accessed by this task.
- No canonical history was synthesized by this task.

<!-- MARK: - 30. Final Verdict -->
## 30. Final Verdict

Canonical scoring authority requires a new Proposed V3 schema with five new canonical scoring persistence models:

- Canonical game-history header.
- Canonical scoring operation evidence.
- Canonical scoring event envelope.
- Canonical scoring event payload.
- Canonical scoring correction/supersession evidence.

The approved design is:

- Dedicated history ownership through a canonical game-history model related to Game and backed by stable game UUID.
- Stable globally unique event identity distinct from SwiftData object identity and sequence.
- Stable operation identity distinct from event identity, backed by durable request fingerprints and operation evidence.
- Game-scoped monotonic commit sequence for audit order, with correction replay-slot semantics for replacements.
- Event envelope plus versioned stable canonical payload record.
- Separate schema, envelope, payload, semantics, and history-format versioning.
- Immutable event payload history with explicit correction/supersession evidence.
- Replay from persisted canonical history only, never from relationship-array order, timestamps, stored scores, or Legacy projections.
- Legacy-only games remain Legacy-only after migration and receive no synthesized canonical history.
- Difficult runner-out ambiguity is representable through stable runner identity, event sequence, runner-out payload, third-out evidence, and explicit ambiguity classifications.

Task 3.22 should implement only the Proposed V3 storage and migration boundary. It must not route production scoring, persist live scoring commands, synthesize canonical history, retire Legacy storage, or begin Task 3.20.

<!-- MARK: - 31. Task 3.23 Implementation Boundary -->
## 31. Task 3.23 Implementation Boundary

Task 3.23 implements `CanonicalScoringTransactionAdapter` as the first production-compiled but non-routed canonical scoring write boundary. The adapter owns transaction coordination for accepted value-only scoring requests. SwiftUI, Legacy scoring views, reports, statistics, imports, exports, startup migration, and scoring-authority routing do not call it.

Transaction ownership is one dedicated SwiftData `ModelContext` per adapter request with autosave disabled. Accepted requests perform duplicate/conflict lookup, target validation, sequence allocation, pending graph insertion, one explicit save, and fresh-context verification. Validation failures and unsupported commands do not create durable operation evidence. Save failures roll back pending inserts and reconcile by durable operation lookup before allowing safe retry.

Durable idempotency is `CanonicalScoringOperationEvidenceRecord.operationIdentity` plus a request fingerprint over the operation mode, game identity, event identity, payload fingerprint, correction identity, target identity, and expected target fingerprint. Exact retries return deterministic already-applied results. Conflicting reuse of an operation identity fails closed. Near-concurrent duplicates converge through persistent uniqueness and fresh-context reconciliation.

Corrections are append-only replacement operations. A correction writes a new operation, replacement event envelope, payload, and correction/supersession record that references the original event and replacement event. The original event and payload are not rewritten or deleted. Missing, wrong-game, already superseded, self-referential, or fingerprint-mismatched targets fail closed. One accepted supersession per original event is enforced by adapter validation because compound uniqueness remains outside the iOS 17.6 schema boundary.

The schema remains Proposed V3 with exactly five canonical scoring models. No V1 or V2 schema changed, no sixth canonical model was added, no Legacy history was backfilled, and production scoring remains Legacy. Persisted replay, corrected active-state synthesis, report/statistics routing, production scoring cutover, historical-game backfill, and Legacy scoring retirement remain later tasks.

<!-- MARK: - 32. Task 3.24 Persisted Replay Verification Boundary -->
## 32. Task 3.24 Persisted Replay Verification Boundary

Task 3.24 implements `CanonicalPersistedScoringReplayVerifier` as a read-only, production-compiled, non-routed verification boundary after canonical scoring persistence. The verifier opens a fresh SwiftData context with autosave disabled, fetches one game's canonical history, event envelopes, payloads, operation evidence, and correction records from Proposed V3 storage, and returns immutable value-only replay evidence. It does not call Legacy scoring, route production scoring, mutate canonical rows, mutate Legacy `Game` or `Atbat` rows, repair malformed histories, synthesize historical canonical records, calculate reports or statistics, or expose managed objects.

Persisted audit order is the game-scoped monotonic `commitSequence`; timestamp order, SwiftData relationship-array order, stored scores, and Legacy projections remain non-authoritative. Effective history is derived by applying accepted replacement correction links to the original replay slot. The original event remains in audit history as superseded, the replacement remains in audit history at its own commit sequence, and the replacement appears in effective history at the original replay sequence. One accepted supersession per original event remains the supported policy; branching and circular supersession evidence fail closed.

Replay validation checks game and history ownership, supported history/envelope/payload/semantics versions, sequence gaps and collisions, required envelope-payload-operation association, payload identity and family agreement, payload fingerprint agreement, correction target ownership, replacement existence, correction operation evidence, cross-game references, self-supersession, branching supersession, circular supersession, exact retry collapse, and read-only behavior. Failure results are bounded sanitized classifications such as no canonical history, incomplete canonical history, unsupported future version, missing payload, missing operation evidence, sequence gap, wrong-game ownership, missing correction target, cross-game supersession, self-supersession, circular supersession, branching supersession conflict, fingerprint mismatch, invalid payload, unsupported canonical schema state, and persistence read failure.

Task 3.24 test evidence uses isolated synthetic V3 stores, including file-backed reopen verification. It proves persisted first operation replay from fresh contexts, repeated replay stability, file-backed reopen stability, exact retry appearing once, deterministic multi-operation ordering, cross-game exclusion, empty/no-history behavior, envelope-payload-operation association, malformed fail-closed cases, append-only correction audit history, replacement effective history, correction retry idempotency, read-only canonical and Legacy counts, Legacy coexistence, no historical canonical backfill, and no selected runtime construction of effective V2 and V3 together. Production scoring remains Legacy, and disposable rehearsal, renewed scoring-authority readiness, production scoring routing, reporting/statistics migration, historical canonical backfill, and Legacy scoring retirement remain later tasks.

<!-- MARK: - 33. Task 3.25 Disposable Rehearsal Boundary -->
## 33. Task 3.25 Disposable Rehearsal Boundary

Task 3.25 verifies the Task 3.23 transaction adapter and Task 3.24 replay verifier together through an automated, file-backed, disposable V3 integration rehearsal. The rehearsal creates only synthetic game context and uses a temporary store URL outside production paths. It does not launch production startup, use an active simulator container, mutate user data, promote migrated stores, route scoring controls, dual-write Legacy scoring, backfill historical games, retire Legacy scoring, or expand the schema.

The approved scenario persists a first accepted scoring operation, a second distinct accepted scoring operation, an exact retry of the first operation, a correction replacement for the first event, and an unrelated other-game operation. The writing container is released before replay, then a fresh V3 container reopens the same store. Replay evidence must show deterministic commit-sequence audit ordering, one retry-visible event only once, append-only original and replacement audit entries, replacement effective history at the original replay slot, other-game exclusion, repeated replay equality, no replay writes, and unchanged Legacy `Game`, `Team`, `Player`, `Atbat`, `Lineup`, and `Pitcher` snapshots.

Failure coverage is intentionally bounded to rehearsal-level risks: conflicting reuse of an operation identity and a missing correction target fail closed in the disposable store without claiming success, adding unintended canonical rows, mutating Legacy rows, touching production paths, or interfering with cleanup. Lower-level malformed payload, sequence, operation, and supersession cases remain covered by Task 3.23 and Task 3.24 tests.

Completion evidence is automated test evidence only. Xcode hosted unit-test execution may launch the ScoreKeep app process, so the app entry point uses `ScoreKeepLaunchIsolation` to detect XCTest before production startup and render an inert host view. This prevents `ScoreKeepProductionStartupHost`, production `ModelContainer` construction, migration recovery UI, seeding, StoreKit startup tasks, entitlement refresh tasks, and ordinary simulator store access during the hosted unit-test run. Manual simulator or device rehearsal is omitted because the disposable file-backed integration boundary satisfies the catalog without manual active-container launch, user data, production startup, or a separate manual procedure. Remaining work before scoring-authority readiness and production routing is Task 2.21 renewed readiness, then any later explicitly approved Task 7.21 bounded routing decision.

<!-- MARK: - 34. Legacy Scoring Operation Evidence Authority -->
## 34. Legacy Scoring Operation Evidence Authority

This section completes implementation-catalog Task 7.7A as a documentation-only schema decision for durable Legacy scoring-operation evidence. It does not implement production code, tests, schema declarations, migration code, recovery code, routing, canonical writes, historical backfill, or Task 7.7 duplicate-prevention behavior.

The confirmed Task 7.7 blocker is that durable idempotency across persistence retry and resume cannot be implemented from current Legacy persisted evidence. Document 29 defines Task 7.7 as enforcing idempotency across persistence retry and resume. `LiveScoringWorkflowCoordinator.SaveAction` is a throwing save closure, `submitScoringAction` mutates `Atbat.result` and related ordinary-result defaults before calling `save`, and `submitAdditionalChoiceScoringAction` mutates `Atbat.result`, `maxbase`, `outAt`, `rbis`, `stolenBases`, `earnedRun`, `playRec`, and end-of-inning evidence before calling `save`. On thrown save, the coordinator restores in-memory fields, but that restoration does not prove the database did not commit.

Legacy persisted model evidence is insufficient for durable operation reconciliation. `Game` stores game identity, scores, teams, players, at-bats, lineups, pitchers, and substitution arrays. `Atbat` stores scoring facts and projections such as result, max base, base-path out, inning, sequence, column, RBI, outs, sacrifice, stolen-base, earned-run, play record, and end-of-inning state. `Player` and `Pitcher` store roster, participant, appearance, and aggregate evidence. None stores a scoring-operation identity, request fingerprint, accepted outcome reference, conflict classification, or completion proof for a retryable live-scoring submission.

The selected responsibility is `Legacy scoring-operation evidence`: durable application/persistence evidence associated with the Legacy live-scoring writer. It may prove that a logical Legacy scoring submission was accepted, rejected, conflicted, or unresolved. It must not become a third baseball-fact authority. Legacy `Atbat`, `Game`, `Player`, and `Pitcher` facts remain the production baseball facts for ordinary scoring until a later routing decision changes that authority.

This responsibility is preferable to mutable `Atbat` facts alone because current `Atbat` fields cannot distinguish first acceptance, exact retry, conflicting reuse, and committed-but-unacknowledged success. It is preferable to an in-memory registry because Task 7.7 requires resume across fresh workflow instances or relaunch. It is preferable to canonical shadow writing because Documents 29, 30, and the renewed Task 2.21 readiness baseline keep `CanonicalScoringTransactionAdapter` non-routed for ordinary production scoring and prohibit ordinary canonical writes, dual writes, and historical canonical backfill. It is preferable to overloading an unrelated field because display, scoring, and projection fields would become ambiguous and would mix baseball facts with operation evidence. It is preferable to modifying V3 in place because `ScoreKeepProposedVersionedSchema.V3` is the established 12-model versioned schema and repository policy adds persisted responsibility through a later schema version rather than silently changing a frozen version.

<!-- MARK: - 35. Minimum Durable Evidence and Identity Lifecycle -->
## 35. Minimum Durable Evidence and Identity Lifecycle

The later implementation should persist only the minimum evidence required for Task 7.7:

- Stable logical operation identity.
- Deterministic request fingerprint.
- Target game identity.
- Target at-bat identity.
- Submission family, such as ordinary result or additional-choice final submission.
- Accepted-result classification.
- Accepted-outcome reference or sufficient authoritative link to the Legacy `Atbat` outcome.
- Completion or disposition state.
- Ordering or creation evidence only when required to reconcile same-target attempts safely.
- Conflict detection evidence.

The durable evidence must not add analytics, UI state, navigation state, display strings, general audit text, full request snapshots, raw errors, purchase evidence, allowance evidence, or duplicated canonical baseball-event history without a separately proven need.

Operation identity is owned by the application-service submission boundary for the Legacy writer, not by SwiftData object identity, not by `Atbat.ident` alone, not by current time, not by mutable score projections, and not by display text. The identity is created before the first persistence attempt for a logical scoring intent. It is retained with the pending submission through retry. Resume means rebuilding enough workflow state after interruption or failure to reuse the same operation identity for the same logical intent, target game, target at-bat, submission family, and payload. A genuinely new user intent receives a new identity.

Exact retry is recognized by the same operation identity, same game, same target at-bat, same submission family, and same request fingerprint, with durable accepted evidence. Conflicting reuse is the same operation identity with a different fingerprint, target, game, family, or accepted facts; it must fail closed and must not overwrite accepted Legacy scoring facts. Operation identity may be cleared from transient UI state only after the durable disposition is accepted, rejected, conflicted, or explicitly unresolved in a way that the later implementation can reconcile from storage.

The request fingerprint is a deterministic semantic fingerprint of the submitted Legacy scoring operation. It must cover operation identity, target game identity, target at-bat identity, submission family, selected Legacy result, additional-choice values when present, and any accepted-outcome reference required to return the same result. It must not depend on current time, memory addresses, localized display text, relationship-array order, mutable replay projections, or regenerated per-callback values.

<!-- MARK: - 36. Retry Resume Reconciliation and Atomicity -->
## 36. Retry Resume Reconciliation and Atomicity

Task 7.7 requires an application/persistence boundary that resolves uncertain save outcomes. The later implementation must save the Legacy scoring mutation and its operation evidence atomically. If the operation evidence saves without the Legacy mutation, or the Legacy mutation saves without operation evidence, retry and resume remain unsafe.

After any thrown or uncertain save, the owner must perform a fresh-context lookup before deciding whether retry is safe. The lookup must compare exact operation identity and request fingerprint. When exact accepted evidence exists, the boundary returns the existing accepted outcome rather than attempting a second mutation. When the identity exists with different facts, the boundary returns a safe conflict. Retry is allowed only when authoritative persisted evidence proves no prior accepted operation exists for the identity and target.

The reconciliation owner must be a fresh-context Legacy scoring-operation evidence lookup associated with the Legacy writer. No such owner exists today. In-memory restoration of `Atbat` fields is useful for presentation cleanup but is not durable noncommit proof. A thrown `ModelContext.save()` or injected `SaveAction` error is completion-uncertain unless durable lookup proves otherwise.

The canonical adapter is precedent for the shape of the boundary, not an authorized production writer for ordinary Legacy scoring. `CanonicalScoringTransactionAdapter` owns operation identity, request fingerprinting, duplicate lookup, one explicit save, rollback, fresh-context verification, exact retry, and conflict classification for canonical rows. Ordinary production scoring still does not call that adapter, does not write canonical records, and does not read canonical replay as its active production source.

The supported retry and resume lifetime for the later Legacy evidence is the lifetime needed to protect a logical operation across the persistence retry and workflow resume cases in Task 7.7. The evidence should remain durable after acceptance so delayed duplicate callbacks, scene interruption, process termination, and future reconciliation can identify already accepted operations. Retention beyond that idempotency and support boundary is a later policy question and must not become broad analytics or audit logging by default.

<!-- MARK: - 37. Correction Deletion and Substitution Boundary -->
## 37. Correction Deletion and Substitution Boundary

Legacy scoring-operation evidence records that an original operation reached a disposition. It must not be silently erased merely because mutable Legacy scoring facts later change through correction, deletion, replacement, or substitution workflows.

For Task 7.7, the required evidence covers initial ordinary and additional-choice live-scoring submission idempotency only. If a later correction, deletion, replacement, or substitution workflow requires durable idempotency, that later workflow should receive a separate operation identity and separately authorized operation-evidence semantics. This decision does not expand into canonical correction history and does not authorize rewriting canonical or Legacy history as an audit log.

Accepted-outcome references may become historical if the target `Atbat` is later corrected, deleted, or replaced. The original operation evidence should remain durable as proof of the original accepted, rejected, conflicted, or unresolved submission, while the later authorized workflow owns any new baseball mutation and its own idempotency. Substitution evidence remains Legacy `Game.replaced`, `Game.incomings`, player order, affected `Atbat` ordering, and pitcher participation evidence until a later substitution authority changes that boundary.

<!-- MARK: - 38. Schema Version Migration Rollback and Retirement Decision -->
## 38. Schema Version Migration Rollback and Retirement Decision

A new schema version is required before Task 7.7 can be implemented. Adding persisted Legacy scoring-operation evidence is a new stored responsibility. It must not modify V1, V2, or V3 in place. `ScoreKeepProposedVersionedSchema.V1` remains six Legacy models, V2 remains those six plus `TeamCreationOperationEvidenceRecord`, and V3 remains those seven plus exactly five canonical scoring storage models, for exactly 12 models.

The later versioned implementation should define a new version after V3 that contains all existing V3 responsibilities plus one Legacy scoring-operation evidence responsibility. The design consequence is a 13-model destination schema, stated here only as an approved future design requirement, not as an implemented fact. No schema has changed in this task.

Migration source is V3 and migration destination is the new version. Empty stores migrate with empty Legacy scoring-operation evidence. Existing Legacy games migrate without synthesized operation evidence and without historical canonical backfill, because current Legacy records cannot prove historical operation identities or request fingerprints. Canonical-zero preservation remains required for Legacy-origin history: migration must not create canonical histories, operations, events, payloads, or corrections for ordinary Legacy games.

Migration and recovery must follow the repository's established source-preservation and fail-closed policy. The protected source store family must be preserved before migration work. Failed or interrupted migration must retain source and backup evidence, avoid partially promoting an unverified target, and classify recovery without fabricating operation evidence. Unsupported source versions, unknown metadata, contradictory stores, incomplete sidecars, or unavailable semantic verification must fail closed. Rollback compatibility must preserve the ability to keep using the prior Legacy-authoritative data or a retained backup according to the existing migration retention boundary.

The evidence is eventually retired or ignored only when Legacy ordinary scoring is retired by a later approved routing and cleanup sequence. Until then it belongs to the Legacy writer and remains distinct from canonical scoring authority. Even after canonical routing, historical Legacy operation evidence may remain support or compatibility evidence rather than baseball-event truth.

<!-- MARK: - 39. Task 7.7 Prerequisites and Current Production Boundary -->
## 39. Task 7.7 Prerequisites and Current Production Boundary

Task 7.7 remains blocked. Its exact prerequisite is completion of a separately authorized versioned implementation task that adds the new schema version, durable Legacy scoring-operation evidence model, atomic Legacy writer boundary, fresh-context reconciliation owner, migration, recovery, rollback, and focused persistence verification. Document 29 catalogs that implementation as Task 7.7B, `Versioned Legacy scoring operation evidence implementation`.

Task 7.7B must prove at least these acceptance points before Task 7.7 resumes:

- Legacy scoring mutation and operation evidence save atomically.
- Exact retry returns the existing accepted outcome.
- Conflicting operation-identity reuse fails closed.
- Thrown or uncertain save performs fresh-context lookup before retry.
- Retry is allowed only when durable evidence proves no prior accepted operation exists.
- Migration from V3 preserves Legacy facts, keeps canonical scoring rows zero for Legacy-origin history, and creates no historical backfill.
- Failed and interrupted migration retain source and backup evidence and recover fail-closed.
- Rollback or disable behavior does not corrupt existing Legacy scoring facts.
- Correction, deletion, replacement, and substitution remain outside Task 7.7 unless separately authorized.

Production scoring remains Legacy. Ordinary scoring performs no canonical writes. No historical canonical backfill exists. V3 remains exactly 12 models. No schema has yet changed. Canonical operation evidence is precedent but is not authorized as the Legacy production writer. The new evidence is not a baseball-fact source of truth. Task 7.8 has not begun.

# Persistence Boundary and Mapping Baseline

<!-- MARK: 1. Scope And Evidence -->
## 1. Scope And Evidence

This Phase 3 baseline records persistence evidence only. It introduces no production route, writer, schema, migration, model-container change, StoreKit change, Keychain change, import/export cutover, report routing, or UI behavior change.

Evidence reviewed for this baseline includes the canonical domain model, persistence and migration design, import/export compatibility design, application services design, purchase entitlement and allowance design, verification fixture design, rewrite readiness plan, implementation task catalog, SwiftData model declarations, current ModelContext use, compatibility transport structures, import services, seeded import, reporting and export reads, media fields, AppStorage preferences, StoreKit purchase state, Keychain allowance counters, test-store isolation, and legacy-to-canonical verification mapping.

Evidence classes used below are authoritative stored fact, derived persisted value, compatibility evidence, presentation or cache value, relationship evidence, ordering evidence, media evidence, preference evidence, purchase or allowance evidence outside baseball persistence, implicit write, explicit save, delete or destructive action, and unknown or ambiguous persistence behavior.

<!-- MARK: 2. Current Stored Shape -->
## 2. Current Stored Shape

The active baseball store is SwiftData-backed. Game is the model-container root and references teams, players, at-bats, lineups, pitchers, replaced players, and incoming players. Team and Player carry reusable roster data plus external-storage media. Atbat carries scoring event evidence and several derived or compatibility values. Lineup stores a game, team, inning, everyone-hits flag, and ordered players. Pitcher stores game, team, player, start/end markers, and aggregate values.

Game scores, pitcher totals, at-bat column, sequence, inning, and outs are persisted but are partly derived or recalculated by scoring workflows. They are compatibility and reconciliation evidence until future persistence work defines authoritative canonical storage.

Purchase and allowance state is separate from baseball persistence. StoreKit and the Keychain store entitlement and allowance state. Baseball persistence failure must not consume allowances or reset entitlements.

<!-- MARK: 3. Boundary Inventory -->
## 3. Boundary Inventory

App startup and model-container setup:

- Initiating workflow: app launch.
- Source: ScoreKeepApp and SeederView.
- Reads: StoreKit products and transactions, Keychain counters, AppStorage preferences, bundled seeded game data if needed.
- Inserts and updates: seeded import can insert or update teams, players, games, at-bats, lineups, pitchers, replacements, and incoming players.
- Relationships changed: all imported game relationships.
- Save behavior: ImportService performs explicit saves; AppStorage seed flag is set after seeded import succeeds.
- Failure handling: seeded import errors are caught and logged; the seed flag is not set after failure.
- Outcome and risk: production-active until cutover; repeated partial import is possible if intermediate import saves occur before final completion.

Game creation:

- Initiating workflow: new game creation from game lists and score flows.
- Reads: selected or existing home and visiting teams; allowance state in score creation flow.
- Inserts and updates: Game records with identity, date, location, innings, everyone-hits flag, teams, and empty relationships.
- Save behavior: explicit save uses optional try handling in several routes.
- Outcome and risk: production-active and must remain active; swallowed save errors can make success uncertain, and allowance decrement may occur even when save completion is not proven.

Game editing:

- Initiating workflow: edit game sheet.
- Reads: all teams for selection and the bound game.
- Updates: date, location, inning count, everyone-hits, teams, and highlights.
- Relationships changed: home and visiting team references.
- Save behavior: mostly implicit SwiftData save through bound model mutation; team creation from this flow explicitly saves.
- Failure handling: no deterministic transaction result.
- Outcome and risk: production-active; direct relationship mutation can leave ambiguous partial state if interrupted.

Team creation and editing:

- Initiating workflow: team list, team selection, add-team controls, and edit team sheet.
- Reads: existing teams and players.
- Inserts and updates: Team records, display fields, coach/details, logo media.
- Deletes: blank or duplicate team cleanup and explicit team deletion.
- Relationships changed: team players and games.
- Save behavior: creation and destructive deletion generally save explicitly; edit fields and media mostly rely on implicit save.
- Failure handling: errors are usually ignored or only logged.
- Outcome and risk: production-active; media replacement is direct field mutation without a separate media transaction.

Player creation and editing:

- Initiating workflow: player list, roster-on-team, all-player edit, lineup, replacement, and player edit views.
- Reads: players, teams, at-bats, pitchers, and selected team relationships.
- Inserts and updates: Player identity, name, number, position, batting direction, batting order, team, photo.
- Deletes: player deletion when not referenced by at-bats or pitchers; blank or duplicate cleanup on edit dismissal.
- Relationships changed: Player.team and Team.players.
- Save behavior: creation and some deletes save explicitly; field edits, team assignment, photos, and some delete paths rely on implicit save.
- Outcome and risk: production-active; batting order is duplicated and recalculated in several workflows.

Roster and starting lineup changes:

- Initiating workflow: starting lineup and roster editing.
- Reads: game, teams, players, lineups, at-bats, replacements, incoming players.
- Inserts and updates: Lineup records and placeholder Atbat records for lineup rows.
- Deletes: replacing an existing lineup can delete at-bats and remove replacements and incoming players for the team.
- Relationships changed: Game.lineups, Lineup.players, Game.players, Game.atbats, Game.replaced, Game.incomings.
- Save behavior: explicit saves occur during lineup creation and per placeholder event; some order mutations are implicit.
- Outcome and risk: production-active; partial lineup replacement can remove scoring or substitution evidence before a complete replacement lineup is proven.

Scoring-event creation and score updates:

- Initiating workflow: score grid and scoring event editor.
- Reads: game, team, player, at-bats, pitchers, lineups, replacements, and incoming players.
- Inserts and updates: Atbat records for events and placeholders; result, bases, RBI, outs, earned-run flag, play record, end-of-inning marker, column, sequence, inning, stored score projection fields, and pitcher markers.
- Deletes: duplicate or deleted at-bat cleanup.
- Relationships changed: Game.atbats and Game.players.
- Save behavior: event creation, sequence recalculation, and pitcher marker updates explicitly save in loops; bound editor mutations also rely on implicit save.
- Outcome and risk: production-active; scoring projection writes derived values and can update pitchers during navigation or recalculation.

Correction:

- Initiating workflow: current production correction is direct editing or deletion of existing persisted scoring evidence.
- Reads: existing event, game, team, player, and related derived projections.
- Inserts and updates: same Atbat fields used by scoring; no persisted canonical correction or supersession record exists.
- Deletes: event deletion from editor.
- Save behavior: mixed explicit and implicit save depending on route.
- Outcome and risk: production-active legacy behavior only; future canonical correction remains non-routed in this run.

Pitcher changes:

- Initiating workflow: pitcher staff and edit pitcher flows plus scoring recalculation.
- Reads: players, teams, games, pitchers, at-bats.
- Inserts and updates: Pitcher identity, player, team, game, start/end markers, aggregate statistics, won flag.
- Deletes: blank pitcher cleanup and explicit pitcher deletion.
- Relationships changed: Game.pitchers.
- Save behavior: explicit saves in creation, deletion, cleanup, and marker updates; edit fields may be implicit.
- Outcome and risk: production-active; marker projection can be stale if event order changes.

Substitutions:

- Initiating workflow: replacement flow.
- Reads: team players, game players, at-bats, replaced players, incoming players.
- Inserts and updates: substitution marker at-bats and player batting orders.
- Relationships changed: Game.replaced and Game.incomings parallel arrays, Game.atbats, Game.players.
- Save behavior: explicit saves during marker creation and final substitution application; some order changes happen before explicit save.
- Outcome and risk: production-active; substitution pairing depends on parallel-array order and is ambiguous when counts diverge.

Import application:

- Initiating workflow: document import, share import, and older import view.
- Reads: JSON compatibility files, existing teams, players, and games.
- Inserts and updates: teams, players, games, at-bats, lineups, pitchers, replacement arrays, incoming arrays, media.
- Relationships changed: imported game graph and roster relationships.
- Save behavior: ImportService performs multiple explicit saves; older import helpers also save within child import steps.
- Failure handling: errors may be logged or thrown at individual decode/application points, but no single transaction result exists.
- Outcome and risk: production-active; partial imports can be persisted before the entire graph is complete.

Seeded-game application:

- Initiating workflow: first app launch after install or reset when seed flag is false.
- Reads: bundled seeded compatibility game.
- Inserts and updates: same as ImportService game import.
- Relationships changed: complete imported game graph.
- Save behavior: explicit ImportService saves plus AppStorage seed flag after success.
- Outcome and risk: production-active; the seed flag is preference evidence and must not substitute for baseball transaction proof.

Deletes and destructive actions:

- Initiating workflow: game, team, player, pitcher, lineup, and at-bat deletion routes.
- Reads: related records to determine delete eligibility or cascade-like cleanup.
- Deletes: game graph pieces, teams, players, pitchers, at-bats, lineup-related evidence, generated files for downloads.
- Relationships changed: parent arrays and model deletion.
- Save behavior: several delete routes save explicitly, but some rely on implicit SwiftData persistence.
- Outcome and risk: production-active; destructive cleanup often spans multiple records without a classified partial outcome.

Media replacement:

- Initiating workflow: photo picker and pasteboard image replacement for players and teams.
- Reads: selected PhotosPickerItem, pasteboard image, current team or player.
- Updates: Player.photo and Team.logo external-storage data.
- Save behavior: direct bound field mutation with implicit persistence.
- Outcome and risk: production-active; media failures are not classified separately from record edits.

Report and export reads:

- Initiating workflow: share/export, score report, pitcher report, PDF generation, screenshot generation, and MLB download/import staging.
- Reads: teams, players, games, at-bats, lineups, pitchers, replacements, incoming players.
- Writes: generated JSON, PDF, JPG, downloaded files, and temporary files outside baseball source records.
- Save behavior: no intended baseball source save during report/export reads.
- Outcome and risk: production-active; reads must not perform destructive repair, and generated output must not be treated as authoritative source.

<!-- MARK: 4. Canonical To Persisted Mapping -->
## 4. Canonical To Persisted Mapping

Team maps to Team identity, display fields, logo, players, and games as direct stored fact, relationship evidence, and media evidence.

Reusable player maps to Player identity, display fields, batting direction, position, photo, team, and related game evidence as direct stored fact, relationship evidence, and media evidence.

Roster membership maps to Player.team and Team.players as relationship evidence with duplicated direct team identity in compatibility transport.

Game participant maps to Game.players plus lineup, at-bat, pitcher, and substitution references. The representation is relationship evidence with ambiguity because participant meaning can originate from several workflows.

Game identity and configuration maps directly to Game identity, date, location, highlights, innings, and everyone-hits.

Game sides map to Game.hteam and Game.vteam relationships.

Lineup maps to Lineup identity, game, team, inning, everyone-hits, and players. Batting order maps to Player.batOrder, Atbat.batOrder, Lineup.players order, and compatibility order. Ordering remains ambiguous where these disagree.

Defensive position maps to Player.position as direct stored fact and compatibility-only display evidence.

Scoring event maps to Atbat identity, game, team, player, result, maxbase, batting order, outAt, inning, sequence, column, RBI, outs, sacrifice markers, stolen bases, earned-run flag, play record, and end-of-inning marker.

Inning and half maps to Atbat.inning and Lineup.inning, with half-inning encoded by convention rather than a structural persisted field.

Outs maps to Atbat.outs and outAt, with some projection behavior recalculating derived persisted values.

Base and runner evidence maps to Atbat result, maxbase, stolen bases, outAt, and play record. Runner identity and base occupancy are partly inferred and ambiguous.

Score maps to Game.hscore and Game.vscore as derived persisted and compatibility evidence. Stored score is not canonical authority by itself.

Pitcher appearance and responsibility maps to Pitcher relationships, start/end markers, aggregate stats, and win flag. Some fields are direct stored fact and some are derived persisted values.

Substitution maps to Game.replaced and Game.incomings as parallel relationship arrays. Pairing is compatibility evidence and ambiguous when order or counts diverge.

Correction and supersession evidence is missing from current persistence and requires future schema or adapter decisions.

Media maps to Team.logo and Player.photo external-storage fields. Replacement has no separate transaction or provenance record.

Ordering maps to Player.batOrder, Atbat.seq, Atbat.col, Lineup.players order, and substitution parallel-array order. Future work must not rely only on fetch order or presentation order.

<!-- MARK: 5. Persisted To Canonical Read-Only Mapping -->
## 5. Persisted To Canonical Read-Only Mapping

The new Phase 3 interpreter builds on LegacyCanonicalVerificationMapping. It is read-only, deterministic, side-effect free, independent of production ModelContext, safe for isolated tests, and unable to fabricate identity.

Supported representative interpretation covers Team, Player, roster membership, Game identity, Lineup, Atbat scoring event, Pitcher appearance, substitution parallel arrays, stored score snapshots, ordering diagnostics through validation, and media byte-count references where safely representable through existing snapshots.

Interpretation dispositions are fully interpreted, interpreted with warnings, partial, unsupported, contradictory, unresolved, and rejected for future write. Unsupported raw evidence remains preserved for comparison. Missing identity remains missing. Broken relationships and ambiguous substitution pairing remain diagnosable. Negative stored scores and other future-write blockers are rejected rather than repaired.

<!-- MARK: 6. Transaction Result Classification -->
## 6. Transaction Result Classification

The Phase 3 transaction vocabulary distinguishes success, success with warnings, no change, duplicate or already applied, validation rejection, save failure, partial or uncertain outcome, stale projection, relationship failure, ordering failure, media failure, interrupted operation, recovery available, retry safe, retry unsafe, unsupported, contradictory, and unresolved.

Each result can carry stable validation findings, an operation identity, affected record identities, whether prior accepted state remains usable, retry safety, explicit reload requirement, repair or review requirement, whether a future workflow may continue, allowance and entitlement invariants, whether save completion is proven, and whether uncertainty exists because save completion cannot be proven.

Success is not reduced to a Boolean. Partial or uncertain outcomes cannot be reported as success. Save failures and interrupted operations require explicit uncertainty handling. Stale projections require reload or recomputation before continuation. Relationship, ordering, media, contradictory, unsupported, and unresolved outcomes remain distinct.

<!-- MARK: 7. Risks And Unchanged-Record Rules -->
## 7. Risks And Unchanged-Record Rules

Active writers remain in game creation, game editing, team creation and editing, player creation and editing, roster and lineup changes, scoring, score projection updates, pitcher changes, substitutions, imports, seeded import, deletes, and media replacement.

Primary transaction risks are duplicate writers, mixed implicit and explicit save behavior, swallowed save errors, partial import and lineup replacement, destructive cleanup without a coherent result, derived persisted values becoming mistaken for source facts, ambiguous substitution pairing, duplicated ordering fields, media replacement without separate failure classification, and allowance decrement when game save completion is not proven.

Future save work must preserve these rules:

- Failed or rejected baseball persistence must not consume an allowance.
- Baseball persistence must not reset purchases or entitlements.
- A failed operation must not mutate unrelated records.
- A partial or uncertain outcome must not be reported as success.
- Derived values must not silently become authoritative facts.
- Reading, reporting, or exporting must not perform destructive repair.
- Missing identities must not be fabricated.
- Duplicate identities must not be silently merged.
- Relationship ambiguity must remain diagnosable.
- Ordering must not depend only on presentation or fetch order.

<!-- MARK: 8. Deferred Work -->
## 8. Deferred Work

This baseline deliberately does not implement save failure handling, round-trip persistence, relationship verification, ordering verification, media persistence writes, deletion repair, migration, schema changes, model-container changes, production routing, cutover, import/export routing, report routing, StoreKit changes, Keychain changes, UI changes, fixture changes, or production scoring routing.

The next consolidated run should cover tasks 3.5 through 3.8: save failure, round-trip, relationship, and ordering verification. The following consolidated run should cover tasks 3.9 through 3.10: media persistence and deletion or repair boundaries.

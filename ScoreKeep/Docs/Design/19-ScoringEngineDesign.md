# ScoreKeep Technical Design — 19 Scoring Engine Design

## 1. Purpose

ScoreKeep needs one authoritative scoring engine because the current scoring behavior is distributed across screens, stored `Atbat` rows, reports, scorecards, pitcher calculations, substitution tools, correction flows, exports, and stored score fields. Those paths can interpret the same game differently. A play may update a visible score, a report may recalculate from `maxbase`, a pitcher report may infer responsibility from pitcher markers, and an export may preserve legacy values whose meaning is not identical to the current screen state.

The engine defined here interprets canonical recorded facts and produces coherent derived game state. It establishes one place where game readiness, event validity, baseball time, runner state, inning transitions, batting order, pitcher attribution, substitutions, corrections, warnings, reports, and exportable meaning are evaluated together.

This document defines scoring behavior and boundaries for the rewritten application. It does not define concrete Swift types, SwiftUI layouts, SwiftData schemas, database tables, file encodings, or production source code. It also does not attempt to define every professional baseball statistical formula. It defines what the scoring authority owns so that implementation, persistence, presentation, reports, and migration can align around the same baseball meaning.

## 2. Engine Responsibilities

The scoring engine validates whether a game is ready for scoring, validates event inputs, orders recorded facts, replays the game, derives current score, derives inning and half inning, derives outs, derives base occupancy, determines the current and next batter, applies lineup history, applies substitutions, applies pitcher appearances, attributes scoring events to the active pitcher, derives batting and pitching projections, produces scorecard and report projections, exposes warnings, unsupported states, and repair requirements, and recalculates downstream state after corrections.

The engine owns the interpretation of recorded baseball facts. It should answer what the game state is after any accepted event, what changed because of a correction, what cannot be safely interpreted, and what downstream projections can be trusted.

The engine does not own navigation, SwiftUI presentation, purchases, permissions, file picking, document security scope, sharing sheets, PDF layout, print dialogs, persistent storage transactions, or user-interface alerts. Application services may ask the engine to interpret facts and may persist an accepted application action, but the engine itself should not open files, save records, present screens, or decide entitlement policy.

## 3. Engine Inputs

The engine requires canonical inputs that identify the game and define its recorded baseball facts: game identity and settings, home and visiting game-side participation, game participants and historical snapshots, starting lineups and batting slots, lineup mode, pitcher appearances, substitutions, ordered scoring events, batter outcomes, runner outcomes, user-entered RBI and earned-run decisions, lifecycle decisions, compatibility evidence, unsupported or unknown legacy values, and correction and supersession state.

Authoritative recorded facts include selected sides, game-time participants, expected inning count, lineup rule, starting lineup, scored events, runner outcomes, substitutions, pitcher appearance boundaries, scorer decisions, and explicit lifecycle decisions such as completion or suspension. These are the facts the engine replays.

Legacy values are authoritative only when they cleanly map to a canonical fact. Values such as legacy `Atbat.result`, `maxbase`, `outAt`, inning, sequence, RBI count, outs, stolen bases, earned-run flag, play notes, `endInning`, lineup records, pitcher start and end markers, `Game.replaced`, `Game.incomings`, `hscore`, and `vscore` may be evidence for reconstruction. Unsupported strings, ambiguous arrays, stale totals, scorecard columns, and incomplete markers should be preserved as compatibility evidence and classified rather than silently promoted into verified facts.

## 4. Engine Outputs

Engine outputs are immutable or read-only product projections from the perspective of consumers. They include current game state, score by team, inning-by-inning score, current inning and half inning, outs, base occupancy, current batter, next batter, current pitcher, active batting lineup, bench and participation state, batting totals, pitching totals, scorecard projection, box-score projection, report projections, export-ready canonical meaning, warning and validation summaries, replay or correction diagnostics, and completion readiness.

Outputs must not become competing stored authorities. A stored cache, report row, PDF, list summary, or exported field may be produced from an engine result, but it should not later override recorded facts unless an explicit repair action changes those facts. If an output disagrees with a replay result, the disagreement is a validation or reconciliation problem, not a second truth.

## 5. Event Ordering and Baseball Time

The engine determines order from game-wide event sequence, inning number, top or bottom half, order within a half inning, lineup events, pitcher-change timing, substitution timing, runner substitutions, corrections, superseded or deleted events, imported legacy sequence values, and legacy scorecard columns.

Canonical event order should be explicit enough to replay the game deterministically. Inning and half inning locate a fact in baseball time. Sequence and within-half ordering decide the order of application. Lineup, pitcher, substitution, and runner-substitution events must be ordered relative to scoring events because they affect the participants and responsibility active at a play.

Scorecard columns are presentation evidence and not the sole authoritative event order. Legacy columns can help reconstruct how a scorecard was displayed, but they cannot safely decide baseball chronology when they conflict with sequence, inning, half inning, or correction state. Ambiguous ordering should produce warnings or repair requirements rather than silent guessing.

## 6. Initial Game State

Before the first play, the conventional initial state is zero score, first inning, top half, zero outs, empty bases, visiting team batting, and the first eligible visiting batter due up. Starting pitcher state is known when a pitcher appearance or setup fact identifies the home defensive pitcher. If the starting pitcher is not known, the engine should preserve an unknown pitcher state and warn where pitching projections are affected.

Initial lineup validation checks that each batting side has an interpretable starting order according to the selected lineup mode. Traditional and Everyone Hits lineups may have different eligibility expectations, but each active batting slot should be understandable. Incomplete but intentionally accepted setup may be usable with warnings, while a draft game that lacks required sides or any interpretable batting path is not ready for scoring.

Imported or resumed games may begin replay from existing recorded facts instead of assuming an untouched empty game. Even then, replay conceptually starts from a known starting condition or from a verified checkpoint whose inputs are equivalent to replaying from the beginning.

## 7. Event Application Model

Applying one recorded scoring event is a staged conceptual process:

1. Validate event context.
2. Identify active batter and defensive pitcher.
3. Verify starting runner state.
4. Apply batter outcome.
5. Apply runner outcomes.
6. Determine outs.
7. Determine runs that count.
8. Apply RBI and earned-run decisions.
9. Update pitcher responsibility.
10. Update batting-order progression.
11. Determine inning transition.
12. Produce the resulting coherent state.

This sequence describes engine responsibility, not required production code. A completed event either produces a coherent resulting state or is rejected, held incomplete, or accepted with explicit warnings. The engine should not partially apply a play in a way that leaves consumers believing an incoherent state is current.

## 8. Batter Result Handling

Supported batter-result categories include single, double, triple, home run, walk, hit by pitch, catcher interference, error, fielder's choice, dropped third strike, ground out, fly out, line out, foul out, strikeout, strikeout looking, sacrifice fly, sacrifice bunt, batter out on the base path, unsupported legacy result, and unknown result.

Canonical categories define scoring meaning. Preserved legacy strings define compatibility evidence. A legacy string should map to a canonical category only when the meaning is understood. Unsupported or unknown strings remain visible to validation, reporting, and export logic rather than being collapsed into an ordinary out or hit.

The known `Sacrifise` versus `Sacrifice` compatibility issue must be interpreted consistently. The engine should recognize the legacy spelling where its intended meaning is clear, preserve the original evidence for round-trip or review, and avoid losing the exact legacy value during migration or export.

## 9. Runner State and Advancement

Starting runner state is derived from previous events and substitutions. It may be bases empty, runners on individual bases, or multiple occupied bases, but there must be exactly one active runner per occupied base. Each runner should have an identifiable source, even if that source is an unknown participant.

Runner outcomes describe forced advancement, optional advancement, holding, scoring, being put out, base-path outs, stolen bases, multiple runner outcomes on one play, multiple runs, pinch runners, unknown runner identity, inherited runners, and corrections to runner movement. Batter advancement and preexisting runner advancement are related but distinct facts.

The engine must detect impossible duplicate occupancy, a runner remaining after scoring, a runner remaining after being retired, and one runner occupying multiple bases. Such states require rejection, incompleteness, warning, or repair depending on whether the contradiction prevents coherent replay.

## 10. Outs and Inning Transitions

A play may add zero, one, two, or three outs. The engine must support double plays, triple plays, batter outs, runner outs, third-out transition, clearing bases, switching batting sides, advancing from top to bottom, advancing to the next inning, preserving each team's next batting position, extra innings, shortened games, mercy-rule completion, suspended games, and imported unusual inning states.

When the third out is recorded, the current half inning ends. Bases clear, the batting side switches, and the next batter for the side coming to bat is preserved from that side's batting-order progression. A transition from the top half moves to the bottom of the same inning. A transition from the bottom half moves to the top of the next inning unless a completion decision ends the game.

The engine should detect impossible fourth-out states and contradictory inning states, such as a half inning with four active outs, a bottom half before any top half in an ordinary game, or imported inning markers that conflict with event order. Unusual but real game endings should be represented through lifecycle decisions, not fake outs.

## 11. Runs, RBIs, and Third-Out Validation

The engine interprets one run on a play, multiple runs on a play, scoring without RBI, force-play third outs, batter-runner third outs before first base, timing plays where a run may count, user-entered RBI decisions, user-entered run-count decisions where legacy data is incomplete, imported runs inferred from `maxbase == Home`, and stored score mismatch.

The design should support ScoreKeep's practical scorer-directed workflow without becoming a complete professional baseball rulebook. The engine should validate whether recorded scorer decisions are plausible against the outs, runner movement, and third-out context. When a recorded run or RBI conflicts with baseball state, the result should be a warning, repair requirement, or rejection depending on severity.

Legacy scoring that infers runs from `maxbase == Home` should be reconstructed cautiously. If complete runner outcomes are missing, the engine may preserve an inferred run as compatibility evidence while warning that the event-derived state is incomplete. Stored `hscore` and `vscore` mismatches are reconciliation issues, not automatic proof that replay is wrong.

## 12. Batting Order Progression

Current and next batter derive from starting lineup, batting slots, lineup mode, completed applicable plate appearances, and lineup history. Traditional lineup and Everyone Hits lineup both cycle after the final active slot, but they may differ in who is eligible to occupy those slots.

Batting order progression must preserve next batter between innings. Bench players, late arrivals, guest players, unknown lineup occupants, pinch hitters, permanent replacements, corrected batter identity, deleted or inserted scoring events, and incomplete lineup states all affect how the next batter is derived.

The batting order does not derive from roster sort order, import order, alphabetical order, jersey number order, or mutable `Player.batOrder` alone. `Player.batOrder` may be compatibility evidence or a roster setup hint, but game-time batting progression is a replay result from lineup facts and plate appearances.

## 13. Substitution Effects

Substitution events can represent pinch hitter, pinch runner, permanent batting-slot replacement, defensive replacement, re-entry, pitcher-related substitution, substitution before a play, substitution during an interruption, correction of substitution timing, correction of incoming or outgoing participant, and imported parallel `replaced` and `incomings` evidence.

Earlier participation must be preserved. A substitution affects current and future interpretation from its effective point; it does not rewrite plate appearances, runner outcomes, pitcher responsibility, or scorecard meaning that occurred earlier unless an explicit correction changes the prior fact.

Invalid re-entry, ambiguous slot replacement, missing outgoing participant, missing incoming participant, malformed timing, or mismatched legacy parallel arrays should produce warnings or repair requirements. Ambiguous legacy substitution evidence should be classified for repair or compatibility-only preservation rather than converted into a misleading canonical substitution.

## 14. Pitcher Appearance Application

Pitcher appearances interact with ordered scoring events through starting pitcher, unknown starting pitcher, pitcher added after scoring begins, mid-inning change, between-inning change, zero-out appearance, partial inning, multiple relief pitchers, pitcher re-entry where supported, unknown pitcher corrected later, event attribution to the active pitcher, inherited runners, earned and unearned run decisions, incomplete pitcher history, and imported start and end markers.

Recorded appearance facts are pitcher identity when known, defensive side, start point, end point when known, and correction state. Pitching totals are derived projections from replayed events, appearance periods, runner responsibility, and scorer decisions.

The engine should attribute each scoring event to the active defensive pitcher or to an unknown pitcher state when the period is incomplete. Inherited runner responsibility and earned-run decisions should remain visible and correctable. The design does not define complete pitching statistical formulas, but it requires that all pitching projections come from the same replay result.

## 15. Corrections and Replay

The authoritative correction approach is deterministic replay from ordered recorded facts. Editing a batter result, editing runner movement, changing outs, changing runs or RBIs, changing earned-run status, changing pitcher assignment, changing batter identity, changing substitution timing, deleting an event, superseding an event, inserting a missing event, correcting inning or half inning, and correcting lineup history all create a revised fact set that must be replayed.

Replay recalculates downstream score, inning totals, outs, runners, batter progression, substitutions, pitcher responsibility, statistics, scorecards, reports, and export projections. Unrelated prior facts should remain preserved. A correction may identify newly invalid downstream events when their assumed starting runners, pitcher, batting slot, or inning no longer matches the replayed state.

Opening a report or scorecard does not repair records automatically. Repairs must be explicit application actions that intentionally change recorded facts or compatibility interpretation. Review surfaces may show diagnostics, but they should not mutate history simply because a projection was requested.

## 16. Replay Strategy

Full replay starts from the initial game state and applies all active ordered facts. This is the correctness baseline and the required conceptual behavior for validation, corrections, reports, exports, and migration verification.

Bounded replay may begin from a verified earlier checkpoint or unaffected point only when an implementation proves that replay from that point produces identical results to full replay. Correctness takes priority over optimization. A checkpoint is invalidated when an earlier event, lineup fact, pitcher appearance, substitution, correction, compatibility interpretation, or game setting changes in a way that can affect later state.

This document does not specify a caching implementation. Cached projections and checkpoints may improve performance, but they cannot become independent authorities.

## 17. Validation Outcomes

Engine validation outcomes include valid, valid with warnings, incomplete but usable, repair required, unsupported compatibility state, rejected as unsafe, and internally contradictory.

An unknown pitcher may be incomplete but usable with pitching warnings. An incomplete lineup may be usable if the scorer intentionally accepted it and the current batter can be identified, or repair required if batting progression is impossible. An unsupported legacy result may be an unsupported compatibility state. A stored-score mismatch may be valid with warnings or repair required depending on event completeness. An impossible runner state, missing required participant reference, ambiguous substitution, overlapping pitcher appearances, duplicate event order, or invalid inning transition may be repair required, rejected as unsafe, or internally contradictory.

Application services and views consume these outcomes without containing the underlying baseball rules. They may decide whether to show review, block completion, request repair, or continue scoring, but the engine owns the rule evaluation.

## 18. Warning and Repair Model

Warnings preserve uncertainty while allowing continued review or scoring when safe. Repairs intentionally change recorded facts or compatibility interpretation. A warning may say that a pitcher is unknown, optional media is missing, an optional legacy value is unsupported, a stored score does not match replay, participant matching is ambiguous, lineup players are missing, or a result string is invalid but preserved.

Repair is required when the game cannot be safely interpreted without changing or classifying data. Examples include impossible base state, malformed substitution history, duplicate scoring event order, inconsistent pitcher period, missing required participant, or a result string that blocks event application.

Repairs should be scoped, explicit, reviewable, and fixture-backed. A repair should identify what fact or interpretation changes, what projections will be recalculated, and what original compatibility evidence is preserved for historical review or round-trip needs.

## 19. Completion Determination

The engine can derive completion readiness from expected inning count reached, home team leading after a completed top half where applicable, tied game requiring extra innings, mercy-rule ending, shortened official game, suspended game, interrupted game declared final, forfeit or administrative ending, incomplete scoring warnings, unknown pitcher warnings, unresolved earned-run decisions, and completion readiness projection.

The engine may recommend or validate completion, but it should not invent the user's decision to declare an unusual game final. Shortened official games, mercy-rule games, forfeits, suspended games, and interrupted games declared final require lifecycle intent. The engine should explain whether the current baseball state supports ordinary completion, requires extra innings, or contains unresolved warnings that should be reviewed before finalization.

## 20. Statistics and Report Projection

Batting, pitching, team, scorecard, box-score, PDF, and export projections must consume the same replay result. Batting totals, pitching totals, runs, hits, errors, line score, scorecard cells, substitution notation, pitcher participation, unknown or unsupported values, incomplete game status, corrected games, historical games, and multi-game aggregation boundaries all derive from replayed facts.

A game report, scorecard, PDF, export, and on-screen score summary should agree for the same fact set and interpretation policy. If a game is corrected, those projections regenerate from replay. Multi-game aggregation should combine verified game-level projections while preserving each game's warnings and scope; it should not aggregate directly from stale stored totals.

This section does not duplicate report specifications or define presentation layouts. It defines the dependency: reports and exports consume authoritative engine projections.

## 21. Compatibility Interpretation

The engine interprets legacy ScoreKeep evidence without silently rewriting unsupported values into misleading canonical facts. `Atbat` maps to a recorded scoring event when its batter, side, result, base, outs, RBI, stolen-base, earned-run, note, inning, sequence, and scorecard evidence can be understood. `result` maps to a canonical category when supported and remains preserved evidence when unsupported. `maxbase` can indicate batter destination or legacy score evidence, especially when it is `Home`. `outAt` can indicate batter or runner out context but may be insufficient for multiple outs.

Legacy inning values, sequence, and column help reconstruct baseball time and scorecard presentation. Sequence and inning evidence should be preferred for replay order when coherent, while column remains presentation evidence. RBIs, outs, stolen bases, earned-run flag, `playRec`, and `endInning` may map cleanly when they agree with event context; otherwise they become warnings or repair inputs.

Lineup records, pitcher start and end markers, `Game.replaced`, `Game.incomings`, `hscore`, and `vscore` require reconstruction. Lineups can seed batting slots and lineup mode. Pitcher markers can seed appearance periods. Parallel substitution arrays can suggest incoming and outgoing participants but may lack timing and role. Stored scores are reconciliation evidence, not unquestioned authority.

## 22. Stored Score Reconciliation

The engine compares legacy `hscore` and `vscore` with replay-derived runs. Exact agreement increases confidence and may allow the stored values to be treated as matching cached projections. Missing stored score is acceptable when event-derived scoring is complete. Event-derived score incomplete means stored score should be preserved as compatibility evidence and reported with limitations.

If stored score is greater than derived score, possibilities include missing scoring events, legacy user-authored final score, incomplete runner reconstruction, or stale data. If stored score is less than derived score, possibilities include corrected events not reflected in stored totals, stale fields, or misinterpreted legacy scoring. Both cases require warnings or repair decisions.

Replay-derived scoring should be authoritative when event facts are complete and coherent. For imported historical games with incomplete events, the engine should preserve stored scores as compatibility evidence, expose the limitation in reports and exports, and avoid silently discarding either source. A user-authored final score may be supported as a lifecycle or administrative fact only when explicitly represented and reviewed.

## 23. Error and Failure Boundaries

The engine reports failure without changing persisted records. Failures include invalid input event, failed replay, missing required participant, contradictory game sides, impossible runner state, invalid event order, ambiguous lineup progression, invalid substitution history, invalid pitcher history, unsupported result, and corrupted compatibility evidence.

The engine should return explicit outcomes to application services. It should not present UI alerts, perform persistence transactions, partially save repaired state, or hide errors by manufacturing default baseball facts. Application services decide whether to preserve prior state, ask for repair, reject an action, or continue with warnings.

## 24. Determinism and Repeatability

The same canonical facts and interpretation policy must produce the same engine result. Replay should not depend on current date, view order, list sort, screen size, selected tab, network state, purchase state, report currently open, or incidental persistence fetch order.

Deterministic behavior supports correction, report consistency, exports, migration verification, and fixture-based testing. A user correcting the same event twice should see the same downstream effects. A report generated today and a report generated later from unchanged facts should agree.

## 25. Performance Considerations

Ordinary play completion should feel immediate. Long games, large lineups, extra innings, many substitutions, and many pitchers must remain usable and safe. Correction replay should provide honest progress if the work becomes noticeable. Report generation should reuse authoritative projections where appropriate.

Optimization cannot weaken correctness. Cached projections, checkpoints, precomputed report summaries, and stored list values must be invalidated or reconciled when relevant facts change. A fast stale answer is not acceptable as a baseball authority.

## 26. Verification Strategy

Verification should connect this engine design to acceptance fixtures and regression scenarios. Required coverage includes regulation completed game, in-progress game, extra-inning game, large lineup, substitution-heavy game, pitcher-change-heavy game, correction game, runner-state matrix, third-out run cases, duplicate event, stored-score mismatch, unsupported result, `Sacrifise` compatibility, malformed lineup, missing participant, third-team imported game, round-trip export, and seeded game.

Expected results should compare current state, reports, exports, reopened state, warnings, and repair outcomes. Verification should prove that live scoring, correction replay, report generation, export meaning, and compatibility interpretation are consuming the same engine result.

## 27. Migration and Coexistence

The new engine can interpret adapted legacy records before persistence is redesigned. Compatibility adapters can translate legacy records into canonical in-memory interpretation while preserving original evidence. Legacy views may continue temporarily while new views use the engine for bounded workflows.

Report comparison, export comparison, fixture-backed routing changes, preservation of legacy records, and avoidance of big-bang transformation are required. Duplicated calculations should be retired only after acceptance shows that the engine path preserves supported behavior and exposes legacy uncertainty honestly.

Coexistence should protect existing users. Legacy records remain readable, compatibility evidence remains available, and routing changes are introduced only when fixture and regression evidence show that the engine provides the safer authority for the affected workflow.

## 28. Risks and Open Questions

The preferred model is plate-appearance-first with broader play-event capacity, but the exact boundary for steals or other between-batter events remains open. Recording steals as part of a plate appearance may preserve current workflow, while standalone runner events may better represent some baseball situations.

Open questions include pitcher responsibility for inherited runners, scorer-entered versus derived earned-run decisions, handling incomplete historical games, interpreting legacy substitution arrays, user-authored final scores, unsupported result round trips, checkpoint or incremental replay optimization, exact statistical formulas, and the balance between recreational flexibility and strict baseball validation.

These questions should be resolved by product policy, fixtures, and compatibility evidence. The engine should not invent unsupported baseball rules merely to make an ambiguous record look clean.

## 29. Success Criteria

The scoring engine design succeeds when it establishes one deterministic authority for current score, inning, outs, runners, current batter, next batter, lineup state, substitutions, pitcher participation, statistics, reports, scorecards, PDFs, exports, and corrections.

It should preserve unknown and legacy evidence honestly, protect historical records, support replay after corrections, expose invalid states safely, and remain independent of SwiftUI and persistence implementation. Unsupported legacy data should be preserved or identified rather than silently converted, and stored score fields should be reconciled as evidence rather than treated as unquestioned authority.

## 30. Recommended Next Design Document

The recommended next design document is `20-PersistenceAndMigrationDesign.md`.

Persistence and migration should follow because the canonical domain model and scoring-engine interpretation now define what data must be preserved, how legacy records are interpreted, which values are recorded facts versus projections, and what transaction and migration guarantees are needed to protect existing ScoreKeep records during the rewrite.

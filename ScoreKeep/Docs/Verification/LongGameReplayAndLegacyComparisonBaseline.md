# Long-Game Replay and Legacy Comparison Baseline

<!-- MARK: - 1. Purpose -->
## 1. Purpose

This note records the non-routed Phase 2 verification baseline for implementation-catalog tasks 2.17 Long-game replay verification and 2.18 Legacy-versus-rewritten comparison harness.

The run is test-only. It adds no production scoring route, persistence adapter, migration, UI, import route, export route, report route, PDF route, fixture rewrite, stored-score repair, or cutover preparation.

<!-- MARK: - 2. Scenarios Tested -->
## 2. Scenarios Tested

Long replay coverage uses synthetic verification evidence with fixed UUIDs and explicit event order where existing compatibility fixtures are too compact to carry runner movement, extra-inning, substitution timing, or correction facts.

Scenarios covered:

- Ordinary multi-inning replay with 17 ordered events across visiting and home halves.
- Extra-inning replay with 16 ordered events, repeated three-player lineup cycles, and a pitcher-change projection.
- Checkpoint independence on a longer sequence at early, midgame, inning-boundary-adjacent, and near-final positions.
- Substitution and correction scenario with 3 scoring events, supported substitution evidence, one accepted in-memory correction, and repeated correction idempotency.
- Long stress replay with 64 ordered events, repeated half-inning cycles, deterministic scoring, and shallow replay result behavior.
- Failure and unsupported evidence for duplicate sequence, missing batter, invalid runner, impossible outs, contradictory base occupancy, unsupported result, ambiguous substitution evidence, and stored-score mismatch.

<!-- MARK: - 3. Determinism Results -->
## 3. Determinism Results

Representative long replay inputs were replayed repeatedly and produced equal final semantic state and equal event summaries.

The inputs use fixed identities, explicit ordering, no current date, no random identifiers, no network, no persistence, and no SwiftData fetch order. Source order is supplied through event sequence evidence.

<!-- MARK: - 4. Checkpoint-Independence Results -->
## 4. Checkpoint-Independence Results

Checkpoint replay was verified by replaying the complete long sequence, replaying a prefix, replaying the suffix from the prefix final projected state and next event sequence, and comparing final semantic state.

The verified checkpoint positions cover early game, middle of the game, a boundary-adjacent point, and a near-final point. The suffix replay matched full replay for score, inning, batting side, outs, base occupancy, and applied event count.

No persisted checkpoints, nested replay histories, production caches, or global mutable state were added.

<!-- MARK: - 5. Correction And Idempotency Results -->
## 5. Correction And Idempotency Results

The correction scenario replaces an accepted home-run event with a ground-out event in memory, recalculates downstream replay state, and verifies that score projection changes from one visiting run to zero visiting runs.

The repeated correction invocation is classified by idempotency as a prior accepted correction and does not create a duplicate corrected fact. The active event count remains unchanged and exactly one superseded event is retained in the in-memory correction result.

<!-- MARK: - 6. Legacy Comparison Dimensions -->
## 6. Legacy Comparison Dimensions

The test-only comparison harness reads compatibility fixture bytes, decodes ShareGame evidence, maps legacy records to canonical verification evidence, constructs canonical replay input in memory, and compares shallow dimensions without modifying any fixture or source record.

Compared dimensions include game identity, event count, event ordering, replay disposition, stored score, unsupported raw values, relationship evidence, and pure report-derived run and count totals.

The harness classifies outcomes as agreement, agreement with warnings, explainable difference, unsupported comparison, incomplete comparison, ambiguous comparison, contradictory comparison, unsafe comparison, or requires review. It does not reduce comparison to a Boolean pass or fail.

<!-- MARK: - 7. Agreements -->
## 7. Agreements

Read-only comparison completed for these valid fixtures:

- MinimalValid.ScoreKeep_Games.
- InProgressGame.ScoreKeep_Games.
- CompletedGame.ScoreKeep_Games.
- MultipleAtbats.ScoreKeep_Games.
- LineupGame.ScoreKeep_Games.
- PitcherGame.ScoreKeep_Games.
- MissingOptionalValues.ScoreKeep_Games.

The valid fixtures agree on game identity and event counts. Minimal score evidence agrees with replay. In-progress, completed, multiple-at-bat, lineup, and pitcher fixtures produce classified replay and report dimensions suitable for later cutover evaluation, with warnings or limitations where legacy evidence is compact or derived.

<!-- MARK: - 8. Classified Discrepancies -->
## 8. Classified Discrepancies

The harness classifies stored-score mismatches, replay score limitations, duplicate event identity, duplicate sequence, relationship uncertainty, unsupported raw result values, unsupported stored scores, and report-derived run differences as evidence rather than silently normalizing either side.

Synthetic unsupported-result and duplicate-event-identity scenarios are explicitly marked as synthetic verification evidence, not compatibility fixtures.

<!-- MARK: - 9. Unsupported Or Unsafe Comparisons -->
## 9. Unsupported Or Unsafe Comparisons

Read-only comparison completed for these malformed or unsupported fixtures:

- BrokenAtbatRelationship.ScoreKeep_Games.
- BrokenLineupRelationship.ScoreKeep_Games.
- BrokenPitcherRelationship.ScoreKeep_Games.
- DuplicateAtbatID.ScoreKeep_Games.
- UnsupportedScoreValue.ScoreKeep_Games.

Broken relationship fixtures require review, repair, unsupported handling, or unsafe-comparison classification before any future write route. Duplicate event identity is contradictory evidence. Negative stored score is unsupported or unsafe stored-score evidence.

<!-- MARK: - 10. Report And Export Coverage -->
## 10. Report And Export Coverage

Covered report evidence is pure, test-isolated calculation from legacy at-bat fields: runs inferred from Home max-base values, hits from current hit result strings, RBI totals, strikeout counts, and walk counts.

Not covered: production report views, report routing, scorecard drawing, screenshots, PDFs, generated files, export encoding, export routing, visual parity, pagination, presentation formatting, report rounding, and production file generation.

No report or export source was modified.

<!-- MARK: - 11. Performance And Resource Observations -->
## 11. Performance And Resource Observations

The representative long stress replay uses 64 events and completes inside the focused test without crash, stack exhaustion, runaway collection growth, or retained full state history.

Replay result size remains shallow: event summaries are proportional to input events, final projected state contains only final state summaries, and no per-event nested state history is retained.

The timing assertion is intentionally broad and only guards against obvious hangs or accidental extreme behavior at representative size.

<!-- MARK: - 12. Phase 2 Readiness Assessment -->
## 12. Phase 2 Readiness Assessment

Tasks 2.1 through 2.18 are complete for the non-routed canonical scoring foundation.

Representative long games replay deterministically. Extra innings, repeated lineup cycles, independent home and visiting progression, pitcher-change projection, supported substitution classification, correction recalculation, and idempotency remain verified at the current non-routed boundaries.

The comparison harness provides read-only evidence for later cutover evaluation. It does not declare legacy or rewritten output universally correct. Agreements, explainable differences, unsupported comparisons, incomplete comparisons, contradictions, and unsafe comparisons remain explicit.

<!-- MARK: - 13. Remaining Cutover Blockers -->
## 13. Remaining Cutover Blockers

Scoring-rule blockers remain for unresolved or incomplete legacy evidence such as full runner movement reconstruction, third-out run validity, ambiguous substitution timing and role, full pitcher responsibility statistics, and report dimensions beyond pure count totals.

Persistence prerequisites still block task 2.19. Phase 3 persistence boundary, transaction, migration, relationship, ordering, media, interrupted migration, repeated migration, failed migration, and purchase-separation evidence are not complete in this run.

Production scoring routing remains unsafe and premature until Phase 3 persistence preparation and later routing gates are complete.

<!-- MARK: - 14. Recommended Next Work -->
## 14. Recommended Next Work

Perform a Phase 2 completion and Phase 3 consolidation review before producing task 2.19.

Begin the consolidated Phase 3 persistence foundation; do not route scoring authority yet.

# Batter and Pitcher Projection Baseline

<!-- MARK: 1. Scope -->
## 1. Scope

This baseline records the non-routed canonical projection authority introduced for implementation catalog tasks 2.9 and 2.10. The projection authority is side-effect-free and does not replace production scoring, SwiftData persistence, views, reports, imports, exports, corrections, or user data workflows.

<!-- MARK: 2. Batter Projection -->
## 2. Batter Projection

The batter projection accepts immutable canonical game, team-side, lineup, batting-slot, recorded-event, substitution, and validation evidence. It projects current batter, next batter, current slot, next slot, wraparound, traditional lineup behavior, and Everyone Hits behavior without using current roster order, display sorting, jersey numbers, SwiftData fetch order, current date, device state, or UI state.

Projection keeps home and visiting batting progressions independent. Inning changes do not reset the batting order, and opposing-side events do not advance the requested side. Duplicate slots, conflicting slots, invalid participants, unresolved event batters, missing event sequence, duplicate event sequence, unknown lineup mode, empty lineups, missing slots, gaps, and unsupported slot evidence are reported as diagnostics rather than repaired or fabricated.

Known substitution evidence can replace a participant at a known batting slot only when the incoming participant, outgoing participant, slot, order, role, and side evidence are sufficient. Ambiguous substitution evidence is preserved as unresolved.

<!-- MARK: 3. Pitcher Projection -->
## 3. Pitcher Projection

The pitcher projection accepts immutable canonical game, defensive-side, pitcher-appearance, pitcher-change, event-responsibility, and validation evidence. It projects starting pitcher, relief appearances, active pitcher, appearance order, pitcher-only participants, batter/pitcher dual-role participants, explicit pitcher changes, and responsibility warnings without calculating pitching statistics or rewriting historical responsibility.

Projection distinguishes missing starters, multiple starters, missing appearance order, duplicate appearance order, invalid pitcher identity, team-side conflicts, missing incoming pitcher, missing outgoing pitcher, same incoming and outgoing pitcher, event responsibility for prior pitchers, missing event pitcher relationships, invalid event pitcher identities, and run or earned-run markers without a resolvable pitcher.

<!-- MARK: 4. Replay Preparation -->
## 4. Replay Preparation

The projection APIs return separate result values and do not mutate input lineups, events, appearances, substitutions, teams, players, game state, or validation findings. Results include disposition, resolved participant where available, slot or appearance evidence, diagnostics, validation findings, source evidence used, source evidence ignored, replay continuation status, and future production-stop status.

Full deterministic replay, checkpoints, correction planning, correction application, downstream recalculation, duplicate-command prevention, production routing, and persistence remain deferred.

<!-- MARK: 5. Verification Evidence -->
## 5. Verification Evidence

Focused Swift Testing coverage exercises first and next batter projection, wraparound, independent home and visiting progression, inning-boundary behavior, traditional and Everyone Hits lineups, incomplete and unsafe batting evidence, historical lineup immutability, safe and ambiguous substitutions, starting and relief pitchers, pitcher changes, event responsibility warnings, deterministic repeated invocation, immutable inputs, and fixture-backed evidence.

Fixtures used by the focused coverage include LineupGame.ScoreKeep_Games and PitcherGame.ScoreKeep_Games. Existing regression and fixture baselines remain unchanged.

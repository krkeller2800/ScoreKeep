# Late-Game Scoring Performance Investigation

## Purpose

This note preserves the ScoreKeep 6.0 late-game scoring performance investigation so the optimization work can resume after 6.0 without repeating the profiling effort. The investigation was diagnostic only. No optimization was implemented as part of the 6.0 release cleanup.

## Observed Symptoms

On an older iPad running iPadOS 17, live scoring performance degraded as a game accumulated history:

- Early innings felt immediate. Accepting a first-inning at-bat dismissed the at-bat sheet almost immediately.
- A small delay became perceptible around innings 3-4.
- By innings 7-9, the delay after committing an at-bat was obvious.
- Opening a completed game with a full realistic scorecard also took materially longer than opening a brand-new game.

A new iPhone 16e showed no perceptible slowdown in the same workflow. The legacy ScoreKeep app showed a similar progressive slowdown on the older iPad, which suggests the issue is likely inherited from the live-scoring architecture rather than a narrow rewrite regression.

The older iPad was useful as a stress-test device because it made scaling costs visible that newer hardware masked. It exposed both game-open delay and post-at-bat delay under realistic completed-game state.

## Measurement Approach

Debugger-attached measurement was rejected because it distorted the behavior being measured. With Xcode attached, the older iPad slowed dramatically, taps became unreliable, game selection could fail, and console traffic affected the timing. Those conditions were not representative of normal untethered use.

The successful measurement approach used temporary DEBUG-only timing blocks and workload counters, then wrote completed blocks to `Documents/ScoreKeep-Performance-Log.txt` inside the app container. This allowed the instrumented build to be installed, the Xcode debug session to be stopped, ScoreKeep to be launched directly on the iPad, and the resulting log to be retrieved afterward.

The temporary instrumentation captured timing for game open, scoring submission, projection refresh, runner reconstruction, statistics preparation, scorecard drawing, dismissal timing, and related workload counts such as displayed at-bats, completed at-bats processed, rendered rows and cells, pitchers, lineups, and save calls.

## Measured Baselines

Representative untethered measurements on the older iPad:

- Brand-new game open: about 889 ms until the scorecard became interactive.
- Completed-game open: about 2247 ms until the scorecard became interactive.
- Brand-new game scoring action: about 679 ms from user action until sheet dismissal.
- Completed-game scoring action: about 1892 ms from user action until sheet dismissal.

The workload grew with the completed game:

- More displayed and completed at-bats.
- More projection and statistics work.
- More runner-state reconstruction.
- More scorecard drawing and summary work.
- More persistence operations.

Rendering work increased, but the measurements did not support rendering as the sole or dominant explanation for the full delay.

## Root-Cause Findings

The late-game scoring slowdown was traced to repeated whole-game refresh work during one accepted scoring action.

The observed sequence was:

1. The user accepted a scoring result.
2. The scoring mutation ran.
3. An explicit post-submit refresh ran.
4. The same mutation then caused multiple SwiftUI observers to fire.
5. Those observers invoked `refreshLiveScoringWorkflow` again.
6. Each refresh entered the same expensive projection path.

The expensive path included:

- `refreshLiveScoringWorkflow`
- `refreshProjections`
- `sequenceGame`
- `updateMaxBases`
- `updatePitcherMarkers`

`sequenceGame` processed the historical game state and performed one persistence save per displayed at-bat. In the measured late-game case, one refresh produced roughly 40 saves. The completed-game scoring action performed roughly three refreshes, producing about 120 saves total.

This explains the measured scaling:

- Small game: about 20 save calls during a scoring action.
- Completed game: about 120 save calls during a scoring action.

The same whole-game projection path was also used during game open, which explains why completed-game open time and post-at-bat refresh time scaled together.

## Required Work vs. Likely Redundant Work

Required work for correctness:

- Apply the accepted scoring mutation exactly once.
- Reconstruct runner and base state after the mutation.
- Recompute derived score, inning, pitcher, and scorecard state from current persisted evidence.
- Preserve pitcher marker behavior.
- Preserve correction behavior.
- Publish one coherent updated state to the UI.
- Persist the state needed by existing 6.0 behavior.

Likely redundant work:

- Multiple full `refreshLiveScoringWorkflow` executions caused by the same scoring transaction.
- Multiple entries through the same projection path after the explicit post-submit refresh has already produced the required derived state.
- Repeated per-at-bat save sequences within same-transaction duplicate refreshes.

The investigation did not prove that every save inside one refresh is unnecessary. It did prove that running the whole refresh path multiple times for the same scoring transaction is redundant from a user-observable state perspective.

## 6.0 Release Decision

For 6.0, the decision was to preserve correct behavior and avoid introducing late-stage architectural risk. No optimization should be made before release. Some older-hardware late-game slowdown is accepted for release safety.

The optimization should be revisited after 6.0 with a broader regression-testing budget, because this path touches scoring mutation, correction, runner reconstruction, pitcher markers, persistence, and SwiftUI publication.

## Post-6.0 Phase 1 Design

The recommended first optimization phase is a local refresh transaction gate, equivalent to Option A from the design investigation:

- Retain the explicit post-submit refresh.
- Treat that explicit refresh as the authoritative same-transaction refresh.
- Suppress only observer-triggered refreshes caused by the same scoring transaction.
- Do not depend on SwiftUI observer ordering for correctness.
- Preserve correction and pitcher refresh paths.
- Preserve existing scoring results, runner behavior, inning progression, scorecard layout, pitcher markers, projection results, and persistence semantics.

Expected effect for the measured completed-game scoring action:

- Refresh count reduced from about 3 to 1.
- Persistence save calls reduced from about 120 to about 40.
- User-action-to-dismissal time should drop materially on older hardware, while preserving the existing one-refresh behavior.

This phase is lower risk than removing the explicit refresh because it keeps the known post-submit authority and only ignores same-transaction duplicate observer work.

## Deferred Phase 2

A separate later phase should investigate batching persistence so `sequenceGame` does not save once per displayed at-bat. That is a higher-risk persistence change and should not be combined with the first refresh-consolidation phase.

Phase 2 risks include save-failure behavior, partial mutation recovery, SwiftData observation timing, correction recovery, and whether existing UI state depends on intermediate persistence side effects.

## Regression Risks

The first optimization phase must explicitly protect:

- Scoring correctness for hits, walks, outs, runner advances, inning transitions, and score changes.
- Correction workflows, including after-submission refresh and downstream recalculation.
- Pitcher marker updates and pitcher-stat boundaries.
- Runner reconstruction and base occupancy after each accepted action.
- Active-game synchronization and restoration.
- SwiftUI presentation state, including at-bat sheet dismissal and selected game navigation.
- Existing persistence semantics after a completed transaction.
- Horizontal scorecard synchronization and existing scorecard layout.

## Focused Verification Plan

Automated verification should include:

- Focused live-scoring workflow tests around accepted scoring actions.
- Correction tests that prove downstream state remains refreshed.
- Pitcher marker tests that cover pitcher changes and late-game boundaries.
- Runner reconstruction tests for occupied bases, runner outs, and inning-ending plays.
- Save-count diagnostics in DEBUG-only tests to prove refresh count changes without changing stored baseball facts.

Manual verification should include:

- Open a brand-new game, score a simple single or out, and confirm immediate dismissal and correct scorecard state.
- Open a completed imported game, score the same simple action, and confirm the same visible scoring result with fewer refreshes.
- Repeat a correction in a late-game scorecard and confirm derived runner, pitcher, inning, and scorecard state.
- Confirm launch does not auto-open a game without restoration state.
- Confirm returning to an active scoring session still restores the intended game when restoration state exists.
- Confirm no production canonical scoring routing, schema migration, import/export behavior, allowance behavior, or report generation behavior changes.

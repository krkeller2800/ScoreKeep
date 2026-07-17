# Scoring Authority Cutover Preparation Baseline

<!-- MARK: 1. Purpose -->
## 1. Purpose

This baseline records implementation-catalog Task 2.19, scoring-authority cutover preparation. The task prepares explicit scoring authority, route inventory, one-writer rules, readiness classification, diagnostics, and activation blockers only. It does not route production scoring to canonical scoring, does not persist canonical scoring events, does not replace Legacy scoring calculations, and does not change real-game scoring behavior.

<!-- MARK: 2. Current Legacy Production Authority -->
## 2. Current Legacy Production Authority

Production scoring remains Legacy. Current scoring writes still originate from SwiftUI scoring views and the active SwiftData environment context. `PlayersToScoreView` selects or creates `Atbat` rows, `ScoreGameView` mutates result, base, out, RBI, sacrifice, stolen-base, earned-run, play-record, delete, and end-of-inning fields, and `PlayersToScoreView` recalculates sequence, inning, outs, max-base, and pitcher markers. Reports and statistics continue to read Legacy records.

<!-- MARK: 3. Scoring Route Inventory -->
## 3. Scoring Route Inventory

The preparation inventory covers game start, current batter selection, pitcher selection and changes, balls and strikes, batter out, batter reaches base, runner advance, runner scores, runner thrown out, stolen base and caught stealing, pickoff, hit by pitch, sacrifice, RBI evidence, inning transition, third out, substitution, correction or undo, score recalculation, resuming an in-progress game, saving at-bat history, and statistics/report reads.

Every route records initiating surface, current authority, mutation owner, context source, save behavior, autosave participation, persisted models and fields, ordering assumptions, score assumptions, runner identity handling, pitcher responsibility handling, correction behavior, failure behavior, canonical support, future eligibility, and blockers.

<!-- MARK: 4. Authority Policy -->
## 4. Authority Policy

`CanonicalScoringAuthorityPolicy` is deterministic and value-only. It selects before mutation, returns an immutable decision for one scoring action, never permits Legacy and canonical mutation together, never permits canonical mutation in production, and fails closed for unsupported action, ambiguous evidence, recovery required, persistence unavailable, and rejected validation states. Canonical preparation flags and simple-Team production routing do not enable scoring.

<!-- MARK: 5. One-Writer Rule -->
## 5. One-Writer Rule

`CanonicalScoringOneWriterAssessment` represents the future rule that one scoring action must have one selected authority, one transaction owner, at most one persistence context, no Legacy plus canonical shadow write, no fallback after canonical mutation starts, no view-issued second save, no autosave secondary commit, and no managed models escaping the boundary. Current production remains Legacy-only; the future canonical route remains blocked.

<!-- MARK: 6. Command-Family Readiness Matrix -->
## 6. Command-Family Readiness Matrix

The readiness matrix classifies ball, strike, foul, batter out, batter reaches first, batter reaches later base, runner advance, runner scores, runner out, stolen base, caught stealing, pickoff, hit by pitch, sacrifice, RBI, inning transition, third-out transition, pitcher change, player substitution, correction, and score recalculation.

No command family is production route eligible. Ball, strike, foul, and pickoff are absent or unsupported. Batter out, batter reaches, hit by pitch, and inning transition have stronger in-memory canonical support but remain blocked by persistence mapping, Legacy parity, and UI boundary gaps. Runner movement, runner scoring, runner out, third-out transition, pitcher change, substitutions, corrections, RBI, sacrifice, stolen base, caught stealing, and score recalculation remain partial, lossy, ambiguous, unsupported, or not proven for production routing.

<!-- MARK: 7. Persistence Mappings -->
## 7. Persistence Mappings

The mapping assessment covers Game, Atbat, Lineup, Pitcher, Player, Team, substitution arrays, stored score fields, ordering and sequence fields, and canonical scoring events. Team and Player identity evidence maps exactly for reusable identity, but scoring meaning still depends on related records. Game, Atbat, stored score, and ordering fields are compatible but lossy. Lineup, Pitcher, and substitution array evidence is ambiguous. Canonical scoring events are unsupported because no production schema field persists them in this task.

<!-- MARK: 8. Legacy Parity -->
## 8. Legacy Parity

Legacy/canonical parity remains comparison-only and non-Boolean. Existing comparison outcomes distinguish match, explainable difference, ambiguous Legacy evidence, unsupported canonical mapping, contradiction, mismatch requiring review, and not proven. The preparation does not fix, repair, or reinterpret Legacy records during comparison.

<!-- MARK: 9. Difficult Runner-Out Boundary -->
## 9. Difficult Runner-Out Boundary

The delayed runner-out third-out gate explicitly preserves stable runner identity, originating at-bat identity, intervening at-bat order, later runner-out evidence, third-out classification, inning boundary, active batter completion evidence, next-batter evidence, score evidence, and run-validity ambiguity. It prohibits invented run validity, pitcher responsibility, substitution timing, completed-at-bat status, and next batter when evidence is insufficient.

<!-- MARK: 10. Correction And Idempotency -->
## 10. Correction And Idempotency

Correction preparation remains non-routed. Existing canonical correction and idempotency foundations classify equivalent repeated requests, conflicting repeated requests, correction target identity, ordering, replay after correction, duplicate suppression, and rejection without partial mutation in memory. Production correction remains direct Legacy Atbat edit/delete/reset behavior because no persisted canonical supersession or idempotency record exists.

<!-- MARK: 11. UI Integration Boundary -->
## 11. UI Integration Boundary

The real scoring UI was not modified. The future boundary requires value intent from the view, stable persisted identifiers, an in-progress game state, repeated-tap suppression, no view mutation before accepted outcome, no second save, deterministic feedback, failure preserving scoring work, safe correction routing, and no scoring-interface redesign.

<!-- MARK: 12. Diagnostics -->
## 12. Diagnostics

`CanonicalScoringAuthorityDiagnostics` reports selected authority, command family, readiness status, validation status, replay status, correction status, persistence mapping status, Legacy parity status, and stable diagnostic code. Diagnostics contain no player names, team names, raw database records, paths, operation UUIDs, raw exceptions, receipts, Keychain values, or device identifiers.

<!-- MARK: 13. Focused Tests -->
## 13. Focused Tests

Codex focused scoring-authority tests passed 12 tests, 0 failed, 0 skipped. Coverage included route inventory, production Legacy default, absent canonical approval, fail-closed unsupported/ambiguous/recovery/persistence/rejected states, simple-Team separation, one-writer rejection cases, readiness matrix coverage, persistence mappings, delayed runner-out third-out evidence, diagnostics privacy, correction route blocking, and non-Boolean Legacy parity.

Existing focused scoring and boundary tests passed 26 tests, 0 failed, 0 skipped. Coverage included canonical command vocabulary and validation, event application, replay, long replay, correction/idempotency, Legacy/canonical comparison, persistence scoring-route blockers, simple-Team separation, and immutable route decisions.

<!-- MARK: 14. Full Regression -->
## 14. Full Regression

Manual Xcode gate was reported as passed for the normal ScoreKeep scheme on the established concrete iPad simulator, including the affected scoring-authority suite, the full normal test plan, and the normal Debug build.

<!-- MARK: 15. Production Build -->
## 15. Production Build

Codex `BuildProject` passed for the normal ScoreKeep project build. Manual Xcode normal Debug build was reported as passed. A separate build-for-testing command was not available through the provided Xcode tools in this session.

<!-- MARK: 16. Active Routing Status -->
## 16. Active Routing Status

Production scoring remains Legacy. No production caller invokes canonical scoring commands, event application, replay, correction, or canonical event persistence. Proposed V2 production startup remains the active container authority after successful startup, and simple-Team production routing remains separate from scoring.

<!-- MARK: 17. Explicit Blockers -->
## 17. Explicit Blockers

Activation is blocked by absent production scoring approval, disabled canonical production route, incomplete persistence mapping, incomplete Legacy parity, incomplete UI boundary, incomplete one-writer production integration, ambiguous delayed runner-out third-out evidence, ambiguous pitcher responsibility, ambiguous substitution timing, ambiguous score/run validity, missing persisted canonical events, and missing persisted correction/idempotency evidence.

<!-- MARK: 18. Deferred Activation -->
## 18. Deferred Activation

A later task must explicitly authorize production scoring routing, provide a value-only application service, prove one writer through a single transaction owner and context, persist or intentionally map canonical facts without loss, verify fresh persisted completion, preserve failure state, and pass full manual regression immediately before activation. This task does not provide an ordinary-user toggle, remote flag, analytics dependency, CloudKit flag, subscription gate, or hidden activation path.

<!-- MARK: 19. Task 3.20 Prohibition -->
## 19. Task 3.20 Prohibition

Task 3.20 Legacy persistence retirement remains not started. Legacy scoring code, Legacy persistence, imports, purchases, allowances, media, reports, statistics, generated output, and existing production startup behavior were not retired or replaced.

<!-- MARK: 20. Final Verdict -->
## 20. Final Verdict

Task 2.19 is preparation-only with the manual Xcode gate reported as passed. The repository now has an explicit fail-closed scoring-authority preparation boundary, production scoring remains Legacy, canonical production scoring remains disabled, one-writer rules are represented, difficult runner-out evidence remains explicit, correction/idempotency remains non-routed, persistence mapping blockers are documented, and activation is deferred to a later authorized task.

# Scoring Authority Routing and Legacy Retirement Split Baseline

<!-- MARK: 1. Task Interpretation -->
## 1. Task Interpretation

Task 2.20 treats scoring-authority routing and Legacy-scoring retirement as separate decisions. Routing may proceed only for one fully gated command family. Legacy retirement remains a later task and cannot follow automatically from any single candidate.

<!-- MARK: 2. Current Production Authority -->
## 2. Current Production Authority

Production scoring remains Legacy. The scoring UI continues to mutate current SwiftData `Atbat`, `Game`, `Pitcher`, `Player`, `Lineup`, and substitution evidence through existing Legacy paths. Canonical production scoring approval is absent, and the authority policy keeps canonical scoring disabled.

<!-- MARK: 3. Readiness Reassessment -->
## 3. Readiness Reassessment

All twenty-one command families remain classified. Ball, strike, foul, and pickoff are absent or unsupported. Batter out, batter reaches first, batter reaches later base, hit by pitch, and inning transition have stronger canonical semantics, validation, and replay evidence, but production routing is still blocked by lossy persistence mapping, missing persisted correction or idempotency evidence, incomplete Legacy parity, and incomplete UI one-writer boundaries. Runner advance, runner scores, runner out, stolen base, caught stealing, sacrifice, RBI, third-out transition, pitcher change, player substitution, correction, and score recalculation remain partial, ambiguous, lossy, unsupported, or not proven.

<!-- MARK: 4. Candidate Ranking -->
## 4. Candidate Ranking

The deterministic ranking records at most three plausible candidates: batter out, hit by pitch, and inning transition. Batter out is smallest among the plausible stored scoring effects but can touch out and inning evidence and maps through compatible-but-lossy `Atbat` fields. Hit by pitch persists through result and max-base fields but can affect runner state and lacks exact parity. Inning transition has canonical transition support but mutates projection ordering, out, inning, column, and end markers through Legacy projection paths.

<!-- MARK: 5. Selected Candidate Verdict -->
## 5. Selected Candidate Verdict

No candidate is selected. Each plausible candidate fails at least one mandatory production gate before any disposable rehearsal or production route can safely begin.

<!-- MARK: 6. Completed Gates -->
## 6. Completed Gates

The completed Task 2.20 gates are evidence-only: route inventory still covers every production scoring route, readiness remains deterministic, the no-candidate verdict is explicit, diagnostics use a stable privacy-safe code, the difficult runner-out boundary remains preserved, and Legacy-retirement is split from routing.

<!-- MARK: 7. Remaining Blockers -->
## 7. Remaining Blockers

Blocking evidence remains canonical production route disabled, canonical event persistence absent, idempotency persistence missing, persistence mapping incomplete, Legacy parity incomplete, UI boundary incomplete, and one-writer proof incomplete. These blockers are mandatory stop conditions for production routing.

<!-- MARK: 8. Authority Policy -->
## 8. Authority Policy

All scoring routes default to Legacy before mutation. The policy never permits Legacy and canonical scoring to mutate the same action. Simple-Team production routing and migration completion do not enable scoring. Test compilation conditions do not enable production scoring.

<!-- MARK: 9. One-Writer Boundary -->
## 9. One-Writer Boundary

The candidate canonical one-writer boundary is not complete. There is no production scoring application service that accepts only value intent, captures stable persisted identifiers, selects an immutable authority, owns exactly one transaction, disables autosave secondary commits, verifies fresh persisted completion, and returns a value outcome without managed models escaping.

<!-- MARK: 10. Persistence Mapping -->
## 10. Persistence Mapping

No selected candidate has exact authoritative persistence mapping. `Atbat` can represent many Legacy facts but not canonical event identity, supersession, durable operation identity, or complete runner responsibility. Game score and ordering fields remain compatible but lossy. Lineup, pitcher, and substitution evidence remains ambiguous. Canonical scoring events remain unsupported in the production schema.

<!-- MARK: 11. Correction -->
## 11. Correction

Correction remains blocked for production routing. In-memory canonical correction foundations exist, but there is no exact persisted correction target, duplicate-correction record, conflicting-correction record, replay-preserving supersession record, relaunch-preserved corrected state, or durable retry proof for a routed candidate.

<!-- MARK: 12. Legacy Parity -->
## 12. Legacy Parity

Legacy parity remains non-Boolean evidence. Current comparison can classify exact match, explainable non-authoritative difference, ambiguous Legacy evidence, unsupported canonical mapping, contradiction, and mismatch requiring review, but no selected candidate has exact authoritative parity across accepted, rejected, repeated, corrected, relaunched, incomplete, malformed, and ambiguous states.

<!-- MARK: 13. Difficult Runner-Out Protection -->
## 13. Difficult Runner-Out Protection

The difficult delayed runner-out third-out boundary remains explicit and unchanged. Task 2.20 does not reorder at-bats, detach runners, alter inning transition, change score, complete an unfinished batter, select a different next batter, or invent run validity.

<!-- MARK: 14. Disposable Rehearsal -->
## 14. Disposable Rehearsal

No disposable canonical scoring rehearsal was performed because no candidate passed the mandatory persistence, correction, idempotency, Legacy parity, and one-writer gates. Rehearsing a blocked route would add ceremony without proving production eligibility.

<!-- MARK: 15. Production Routing Decision -->
## 15. Production Routing Decision

Production canonical scoring routing remains disabled. No production scoring action is routed canonically. Production scoring authority remains Legacy for every write route, and read-only reports/statistics remain Legacy-derived.

<!-- MARK: 16. Legacy-Retirement Split -->
## 16. Legacy-Retirement Split

Because no candidate is routed, the candidate-specific Legacy path is retained as pre-mutation disable fallback, retained for unsupported historical states, and marked deprecated-but-active only as future planning evidence. It is not isolated from normal production routing and is not eligible for removal in this task.

<!-- MARK: 17. Operations Remaining Legacy -->
## 17. Operations Remaining Legacy

All scoring families remain Legacy: ball, strike, foul, batter out, batter reaches first, batter reaches later base, runner advance, runner scores, runner out, stolen base, caught stealing, pickoff, hit by pitch, sacrifice, RBI, inning transition, third-out transition, pitcher change, player substitution, correction, and score recalculation. Legacy scoring controls, mutation helpers, compatibility mappings, stored-field handling, reports, statistics, runner logic, pitcher logic, substitution logic, and correction logic remain active.

<!-- MARK: 18. Tests -->
## 18. Tests

Focused Task 2.20 tests cover deterministic candidate ranking, no-candidate selection, blocked route gates, production routing disabled, difficult runner-out preservation, Legacy-retirement split, all scoring families remaining Legacy, and Task 3.20 not started.

<!-- MARK: 19. Full Regression -->
## 19. Full Regression

Manual Xcode gate was reported as passed for the normal ScoreKeep scheme on the established concrete iPad simulator, including the affected Task 2.20 suite, the full normal test plan, and the normal Debug build.

<!-- MARK: 20. Production Build -->
## 20. Production Build

Codex `BuildProject` passed for the normal project build. Manual Xcode normal Debug build was reported as passed. This task does not change startup, production persistence routing, or scoring UI code.

<!-- MARK: 21. Startup And Team Routing Boundary -->
## 21. Startup And Team Routing Boundary

Production startup remains unchanged. Proposed V2 startup authority and simple-Team production routing remain separate from scoring. Task 2.20 does not alter startup recovery, migration policy, or simple-Team routing approval.

<!-- MARK: 22. Excluded Domains -->
## 22. Excluded Domains

Task 2.20 does not change imports, media, purchases, allowances, reports, statistics, generated output, production persistence schema, physical-device app containers, or existing game interpretation.

<!-- MARK: 23. Task 3.20 Prohibition -->
## 23. Task 3.20 Prohibition

Task 3.20 remains not started. Legacy persistence retirement and Legacy scoring removal require a later explicit task with replacement proof for every active route.

<!-- MARK: 24. Final Verdict -->
## 24. Final Verdict

Task 2.20 is preparation-only and blocked for production routing. No command family is genuinely eligible under the current models because exact persistence, persisted correction/idempotency, exact Legacy parity, and one-writer application proof are not all present. Legacy scoring remains the production authority, and Legacy retirement is split out for later work.

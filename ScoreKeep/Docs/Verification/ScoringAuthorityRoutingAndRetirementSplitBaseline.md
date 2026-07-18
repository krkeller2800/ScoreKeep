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

<!-- MARK: 25. Renewed Task 2.21 Authority -->
## 25. Renewed Task 2.21 Authority

Renewed Task 2.21 is authorized by Document 29 as `2.21 Renewed scoring-authority readiness after persistence foundations`. Its purpose is to reassess scoring-authority readiness after canonical scoring persistence design, versioned schema implementation, transaction adapter, persisted replay verification, and disposable rehearsal. The task is documentation/routing prep only. It reopens scoring readiness only as a gate, requires Task 3.25 and no active Task 7.21 routing, and keeps production scoring Legacy.

Task 7.21 is not begun by this review. It remains a later routing task titled `Bounded production scoring routing after renewed persistence gate`.

<!-- MARK: 26. Renewed Evidence Inspected -->
## 26. Renewed Evidence Inspected

The renewed review inspected Documents 17 through 31 where relevant, the Document 29 catalog and dependency matrix, Documents 30 and 31, the five canonical scoring storage models, `ScoreKeepProposedVersionedSchema`, `CanonicalScoringTransactionAdapter`, `CanonicalPersistedScoringReplayVerifier`, `DisposableCanonicalScoringRehearsalTests`, `CanonicalScoringTransactionAdapterTests`, `CanonicalPersistedScoringReplayVerifierTests`, `ScoreKeepLaunchIsolation`, production startup and container factory boundaries, active test-plan membership, scoring UI, substitution and pitcher workflows, report/statistics/export readers, and existing scoring-authority preparation baselines.

The branch evidence starts from commit `18e0fe42d63fbe56b2b6723300e59dc0101b6d1a`. The working tree contained only untracked Xcode user-state under `ScoreKeep.xcodeproj/xcuserdata/karlkeller.xcuserdatad/xcschemes/` and an untracked `ScoreKeep.xcodeproj/project.pbxproj.backup`; both remain outside this documentation task.

<!-- MARK: 27. Canonical Persistence Readiness -->
## 27. Canonical Persistence Readiness

Canonical persistence is complete enough for a later bounded routing plan. V3 declares the seven Legacy persistence responsibilities plus exactly five canonical scoring models: `CanonicalGameHistoryRecord`, `CanonicalScoringOperationEvidenceRecord`, `CanonicalScoringEventEnvelopeRecord`, `CanonicalScoringEventPayloadRecord`, and `CanonicalScoringCorrectionRecord`.

`CanonicalScoringTransactionAdapter` owns a dedicated operation context, disables autosave, validates value-only scoring requests, performs duplicate and conflict lookup before insertion, allocates a game-scoped commit sequence, inserts history, operation, event, payload, and accepted correction evidence as one pending graph, performs one explicit save, and verifies through a fresh context. Durable operation identity is `CanonicalScoringOperationEvidenceRecord.operationIdentity` plus a request fingerprint. Exact retries return already-applied evidence; conflicting identity reuse fails closed. Validation failure and save failure do not leave partial canonical transactions after rollback and fresh durable reconciliation.

Correction and supersession are append-only. A correction writes a new operation, replacement event, payload, and correction record while preserving the original event and payload. Missing targets, wrong-game targets, fingerprint mismatch, self-supersession, and already superseded targets fail closed. No historical Legacy game receives synthesized canonical history.

<!-- MARK: 28. Replay Readiness -->
## 28. Replay Readiness

Persisted replay is complete enough for a later bounded routing plan. `CanonicalPersistedScoringReplayVerifier` reads through a fresh context with autosave disabled, returns value-only audit entries, effective entries, correction links, classifications, and diagnostics, and reports `replayPerformedWrites` from context state.

Replay orders audit history by game-scoped `commitSequence`, preserves original and replacement events in audit history, resolves effective history by replacement links at the original replay slot, excludes other games, and treats no-history Legacy games as no canonical history rather than backfilling records. Malformed evidence fails closed for missing payload, missing operation evidence, fingerprint mismatch, unsupported versions, sequence gaps or collisions, wrong ownership, cross-game supersession, self-supersession, branching supersession, circular supersession, invalid payload, unsupported schema state, and read failure.

<!-- MARK: 29. Migration And Compatibility Readiness -->
## 29. Migration And Compatibility Readiness

Migration and compatibility are complete enough for this readiness gate. Task 3.22 accepted the Path C safety substitute selected by Document 31: exact Proposed V2 metadata qualification, source-family preservation, copied-workspace migration, V3 destination semantic verification, Legacy reconciliation, canonical-zero verification for all five canonical scoring models, rollback retention, and fail-closed unsupported-source behavior.

The retained boundary does not semantically open frozen V2 through the current V3 app target and does not construct runtime-effective V2 and V3 schemas together in any retained successful path. The accepted substitute is weaker than an independent frozen V2 semantic open, but it preserves the protected source family, verifies the copied V3 destination, records diagnostics, and blocks unsupported states. Atomic production promotion, historical canonical backfill, and production scoring routing remain outside the completed migration boundary.

<!-- MARK: 30. Rehearsal Readiness -->
## 30. Rehearsal Readiness

Task 3.25 proves the adapter and replay verifier together in a disposable file-backed V3 store. The rehearsal accepts a first Single, a second Walk, an exact retry of the first operation, a Double replacement correction, and an unrelated other-game event. Reopened replay is deterministic, excludes the other game, preserves append-only audit history, selects replacement effective history, keeps Legacy snapshots unchanged, and removes the disposable store family after the test.

Failure rehearsal covers conflicting operation-identity reuse and a missing correction target. Both fail closed without unintended canonical rows and without mutating Legacy `Game`, `Team`, `Player`, `Atbat`, `Lineup`, or `Pitcher` snapshots. The rehearsal does not route production scoring.

<!-- MARK: 31. Production Isolation Readiness -->
## 31. Production Isolation Readiness

Production isolation is complete for readiness review. `ScoreKeepProposedVersionedSchema.productionBoundaryStatement` states that Proposed V3 is a storage target only and production scoring remains Legacy. Source inspection and tests confirm `PlayersToScoreView`, `ScoreGameView`, `ScoreContentView`, report/setup views, and `ScoreKeepProductionStartupHost` do not call `CanonicalScoringTransactionAdapter` or `CanonicalPersistedScoringReplayVerifier`.

The production UI still writes through Legacy SwiftData models. `ScoreKeepLaunchIsolation` sends XCTest-hosted execution to an inert unit-test host mode before ordinary production startup, so hosted unit tests bypass `ScoreKeepProductionStartupHost`, production container construction, seeding, migration recovery UI, StoreKit startup tasks, entitlement refresh tasks, and ordinary simulator store access. The active test plan lists only `ScoreKeepTests`.

<!-- MARK: 32. Production Scoring Mutation Inventory -->
## 32. Production Scoring Mutation Inventory

Current production scoring mutation remains Legacy:

- Game opening and scoring entry: `ScoreContentView.destinationView` routes real games to `EditScoreView`, which owns team selection, reports, pitcher screens, lineup, replacement flow, and scoring shell navigation.
- At-bat selection and creation: `PlayersToScoreView.doAtbat` selects an existing `Atbat` for a scorecard cell or inserts a placeholder `Atbat`, appends it to `Game.atbats`, and saves through the environment `ModelContext`.
- Batter result, on-base, out, RBI, steal, earned-run, recorded-play, correction, and deletion: `ScoreGameView` mutates the bound `Atbat`, resets first-column events, removes unaccepted later-column events, deletes events on disappear, recalculates end-of-inning markers, and relies on Legacy SwiftData persistence.
- Score, inning, sequence, base, and pitcher projections: `PlayersToScoreView.seqGame`, `updMaxBases`, and `updatePitcherMarkers` mutate `Atbat.col`, `Atbat.seq`, `Atbat.inning`, `Atbat.outs`, `Atbat.maxbase`, and `Pitcher` boundary markers, with explicit saves in projection loops.
- Pitcher changes: `PitchersStaffView` and `EditPitcherView` insert, update, and delete `Pitcher` rows and update `Game.pitchers`.
- Substitutions: `ReplacementView.doSubs` mutates `Game.replaced`, `Game.incomings`, `Player.batOrder`, affected `Atbat` ordering, and inserts `Pitch Hitter` placeholder `Atbat` rows.
- Reports, statistics, export, scoreboards, and game display: `ReportView`, `ShowReportView`, pitcher report views, `GeneratePDF`, scorecard drawing, and `ShareContentView` read Legacy `Atbat`, `Game`, `Pitcher`, `Player`, `Team`, `Lineup`, replacement, and incoming evidence. They do not consume canonical persisted replay.

No stable production operation identity is currently owned at the UI or application-service boundary. Task 3.23 payload semantics support a narrow ordinary plate-appearance candidate such as a simple batter-reaches or batter-out event, but the active UI still mutates Legacy records before any canonical command boundary.

<!-- MARK: 33. Routing Prerequisites -->
## 33. Routing Prerequisites

Already defined: canonical storage inventory, operation evidence, request fingerprinting, one explicit save, fresh-context verification, exact retry, conflict detection, append-only replacement correction storage, replay audit/effective semantics, no historical canonical backfill, Legacy retention until Phase 11, and no production caller for canonical persistence.

Partially defined: the first candidate family can be bounded to a simple ordinary plate-appearance command, but exact UI intent mapping, Legacy parity fixtures, correction mapping, undo/delete behavior, substitution coexistence, score/inning projection coexistence, report/statistics coexistence, and manual regression acceptance are not yet proven for production routing.

Unresolved before Task 7.21 can route anything: explicit production activation approval; completion of Task 7.19 internal routing; exact command family to route first; Legacy-authoritative versus canonical-authoritative behavior for the routed slice; whether shadow writing is allowed; canonical failure policy; user-visible failure behavior; UI/application ownership of operation identity; sequence ownership during real repeated interactions; repeated-tap and concurrency policy; correction, undo, deletion, and substitution mapping; transaction ordering across multiple scoring actions; rollback or feature-disable mechanism; observability and diagnostics; staged deployment; report/statistics coexistence; and acceptance/manual testing.

<!-- MARK: 34. Readiness Classification -->
## 34. Readiness Classification

Final classification: Conditionally ready, with named prerequisites.

The canonical scoring persistence and replay foundation is sufficiently complete, tested, isolated, recoverable, and compatible to permit planning of a limited production scoring-routing boundary while retaining Legacy authority and rollback. It is not yet ready for production routing implementation until the prerequisites in section 33 are explicitly resolved by Task 7.21 or its required predecessors. Production scoring remains Legacy, no historical canonical backfill exists, and Task 7.21 has not begun.

<!-- MARK: 35. Task 7.21 Boundary -->
## 35. Task 7.21 Boundary

Task 7.21 is titled `Bounded production scoring routing after renewed persistence gate`. Its authorized scope is to route at most one explicitly approved scoring command family to canonical production scoring after renewed readiness proves persistence foundations. Its dependencies are Task 2.21, Task 7.19, and explicit production activation approval.

This renewed Task 2.21 review satisfies the persistence-readiness dependency for Task 7.21 planning. Task 7.21 is not ready to start routing code yet because Task 7.19 internal routing evidence and explicit production activation approval are not complete, and the section 33 routing policies remain unresolved. Task 7.21 must not mark existing games with synthesized canonical history and must retain Legacy for all unrouted scoring and rollback.

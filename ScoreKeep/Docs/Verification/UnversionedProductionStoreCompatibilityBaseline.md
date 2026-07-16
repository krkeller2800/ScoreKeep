# Unversioned Production Store Compatibility Baseline

<!-- MARK: - 1. Purpose And Verdict -->
## 1. Purpose And Verdict

This run verifies whether a store created by ScoreKeep's actual current unversioned production-style SwiftData container can be recognized and transitioned through the proposed V1-to-V2 schema plan whose V2 adds TeamCreationOperationEvidenceRecord.

Compatibility verdict: Proven compatible for stores created by the exact current unversioned production-style container construction used in this repository state.

Recommended direction: Direction A - Direct V1-to-V2 Transition Proven for the exact current unversioned container source. Do not route production schema migration yet because source-version authority, migration-state/progress policy, rollback or disable behavior, user outcome handling, diagnostics, and archive/device evidence policy remain separate production gates.

<!-- MARK: - 2. Repository And Baseline Evidence -->
## 2. Repository And Baseline Evidence

Preflight confirmed repository root `/Volumes/XcodeSSD/Users/karldev/Documents/ScoreKeep`, branch `scorekeep-next`, local HEAD `cf7fd69458f78a8387f73dd66dd9635296d1a0bf`, direct GitHub `scorekeep-next` head `cf7fd69458f78a8387f73dd66dd9635296d1a0bf`, and stale local tracking `origin/scorekeep-next` at `99568ed133d601ae3d0ce9f58f861aa84fa0b37d` before edits.

Baseline discovery before edits found 448 tests, all enabled. The baseline full test plan passed 448 passed, 0 failed, 0 skipped, 0 expected failures, 0 not run. The active production build passed before edits.

<!-- MARK: - 3. Exact Current Unversioned Store Producer -->
## 3. Exact Current Unversioned Store Producer

Production startup remains `ScoreKeepApp` with SwiftUI `.modelContainer(for: Game.self)`. The isolated producer uses the same current unversioned model graph inferred from `Game.self`, with `ModelConfiguration(url:)` supplying only a disposable on-disk store URL. It does not use Proposed V1, Proposed V2, a migration plan, or an in-memory store when creating source stores.

The unavoidable difference from active startup is the explicit test-owned URL. The production Documents directory, app production store location, AppStorage seed state, StoreKit, Keychain, user data, and production startup route are not opened or copied.

<!-- MARK: - 4. Current Models And Proposed Schemas -->
## 4. Current Models And Proposed Schemas

The active production model graph remains Game, Team, Player, Atbat, Lineup, and Pitcher. Proposed V1 contains that same model set. Proposed V2 adds only TeamCreationOperationEvidenceRecord. The proposed V1-to-V2 plan remains an isolated lightweight migration plan and is not referenced by production startup.

TeamCreationOperationEvidenceRecord remains independent operation metadata. No operation-evidence records are created automatically by the migration.

<!-- MARK: - 5. Disposable Store Safety And Privacy -->
## 5. Disposable Store Safety And Privacy

All stores are newly created under test-owned temporary directories. Fixtures use synthetic names, fixed UUIDs, fixed dates, deterministic record values, and tiny deterministic media bytes. No personal information, real photos, receipts, signed transactions, Keychain values, account data, device identifiers, production stores, or user app containers are used.

Every migration or recognition experiment uses a copied store family. Disposable destination directories must be empty before use. SQLite, WAL, SHM, and generated store files are not tracked.

<!-- MARK: - 6. Source Scenarios And Baselines -->
## 6. Source Scenarios And Baselines

Source scenarios cover empty, minimal, representative populated, and edge-evidence stores. The minimal store has one game, two teams, four players, one lineup, one at-bat, one pitcher, stable relationships, stored scores, and small media. The representative store adds a second game, extra team, reusable player, additional lineup, multiple at-bats, multiple pitcher records, substitution evidence, stored scores, ordering evidence, and media. The edge-evidence store adds missing optional values, unsupported raw values, duplicate ordering evidence, ambiguous substitution arrays, nil media, and stored-score mismatch evidence where physically representable.

Baseline snapshots record counts, stable identities, game-team relationships, roster membership, game participants, lineup membership, at-bat ordering, scorecard columns, batting order evidence, pitcher-game links, substitution arrays, stored scores, media byte fingerprints, unsupported evidence, ambiguous evidence, and purchase/allowance probes.

<!-- MARK: - 7. Duplicate Identity Incident And Correction -->
## 7. Duplicate Identity Incident And Correction

The focused repeatability test initially crashed with a fatal duplicate-key dictionary error for UUID `00000000-0000-0000-0000-000000006301`. That UUID belongs only to `Game` as `UnversionedCompatibilityIDs.gameOne`. Fresh source inspection and first-open migrated-copy inspection each found exactly one matching Game and no Team, Player, Atbat, Lineup, Pitcher, or operation-evidence target identity collision.

The root cause was stale disposable destination reuse: deterministic temporary names allowed the same fixed fixture graph to be inserted again into a prior disposable store. The snapshot helper also incorrectly built `Dictionary(uniqueKeysWithValues:)` before validating duplicates.

The correction detects duplicate stable identities by model category before constructing unique-key dictionaries, returns deterministic diagnostics containing model category, stable identity, and occurrence count, rejects non-empty disposable destinations, and makes repeatability tests use distinct fresh source and copy URLs with path separation assertions. No uniquing closure silently keeps or drops duplicate records.

<!-- MARK: - 8. Proposed V1 Recognition Result -->
## 8. Proposed V1 Recognition Result

Fresh copies of exact current unversioned stores open successfully as Proposed V1 for empty, minimal, representative, and edge-evidence scenarios. Record counts and semantic snapshots match the unversioned source baselines. The untouched source remains unchanged. Repeated Proposed V1 recognition-only opening of a representative copy is stable.

No unknown-version, checksum, schema mismatch, or persistent-store refusal was observed in the focused evidence. Recognition was verified semantically; raw framework metadata was not rewritten manually or inspected through unsupported mutation.

<!-- MARK: - 9. Direct Proposed V2 Migration Result -->
## 9. Direct Proposed V2 Migration Result

Fresh copies of exact current unversioned stores open successfully with Proposed V2 and the proposed V1-to-V2 migration plan for empty, minimal, representative, and edge-evidence scenarios. SwiftData recognizes the unversioned source as compatible with the proposed V1 model set and opens the V2 target without data loss.

All expected games, teams, players, at-bats, lineups, and pitchers remain. Stable UUIDs, game sides, roster memberships, game participants, lineup membership, event order, sequence, scorecard columns, batting orders, pitcher evidence, stored scores, substitution arrays, media owner fingerprints, unsupported values, and ambiguous evidence are preserved. TeamCreationOperationEvidenceRecord count is zero after migration.

<!-- MARK: - 10. Repeat Open And Fresh Copy Result -->
## 10. Repeat Open And Fresh Copy Result

A migrated Proposed V2 target can be opened repeatedly through fresh containers without duplicate records, repeated evidence-row creation, semantic drift, or repeated-migration effects visible in snapshots. Operation-evidence uniqueness remains available after migration by inserting and reloading one deterministic evidence record.

Independent-copy repeatability uses different fresh source URLs and different fresh copied target URLs for each attempt. The minimal direct transition passes across independent attempts, and UUID `00000000-0000-0000-0000-000000006301` occurs exactly once in every expected Game collection.

<!-- MARK: - 11. Automatic Evolution Comparison -->
## 11. Automatic Evolution Comparison

A copy of an exact current unversioned store also opens with an unversioned current-model-plus-TeamCreationOperationEvidenceRecord container. Baseball data is preserved and the evidence table is empty. The automatically evolved result is later recognizable through Proposed V2 in focused verification.

This remains comparison evidence only. It is not the recommended production direction because it creates a less explicit transitional format and does not replace the need for source-version, migration-state, rollback, disable, and diagnostic policies.

<!-- MARK: - 12. Conversion Fallback Result -->
## 12. Conversion Fallback Result

The test-only store-copy compatibility conversion fallback was verified even though direct Proposed V2 transition passed. The old/current unversioned container reads the source, a new Proposed V2 target is created, supported records are reconstructed with stable identities, relationships, ordering, stored scores, substitution evidence, unsupported values, ambiguous evidence, and media fingerprints preserved, and evidence records remain empty.

Repeated target open is stable. Conversion write failure preserves the original source and discards only the target. This fallback is persisted-evidence reconstruction, not physical schema migration, and is not production-ready without progress storage, backup, atomic replacement, rollback, disk-space, startup policy, and user-review behavior.

<!-- MARK: - 13. Failure And Recovery Classifications -->
## 13. Failure And Recovery Classifications

Non-empty disposable destination now produces controlled rejection. Duplicate stable identity in source or migrated snapshot produces deterministic duplicateStableIdentity diagnostics rather than a process-level fatal error. Missing source store family produces source-copy failure classification. Conversion failure preserves the source and requires target discard. Safe retry requires a fresh source copy and fresh destination.

Potential source-open failure, Proposed V1 recognition failure, unknown source version, Proposed V2 migration failure, verification mismatch, media mismatch, repeated-open inconsistency, and migration-created duplicate remain represented as deterministic failure or diagnostic paths rather than raw-log success claims. No unresolved crash or repeated timeout remains in focused verification.

<!-- MARK: - 14. Purchase And Allowance Separation -->
## 14. Purchase And Allowance Separation

Purchase and allowance verification uses scalar probes only. No StoreKit receipt, signed transaction, product identifier, Keychain value, entitlement state, free-game allowance, MLB download allowance, or purchase marker enters the SwiftData source or target stores.

Successful recognition, direct migration, automatic comparison, conversion fallback, repeat open, duplicate diagnostics, and failure classifications preserve the purchase and allowance probes unchanged. Missing baseball records are never interpreted as missing purchase state.

<!-- MARK: - 15. Non-Routing Proof -->
## 15. Non-Routing Proof

Active production startup remains `.modelContainer(for: Game.self)`. The active production model list remains unchanged. No migration plan is passed at production startup. Proposed schemas remain unreferenced by ScoreKeepApp. TeamView, production writers, StoreKit, Keychain, allowance counters, entitlement logic, UI, accessibility, imports, exports, reports, media routes, scoring routes, and team-creation routing remain unchanged.

The new code introduces compatibility assessment vocabulary and test support only. It does not add a production backup service, startup router, source-version provider, migration-progress store, raw SQLite migrator, metadata rewriter, production conversion service, feature flag, shadow write, or fallback route.

<!-- MARK: - 16. Historical Build And Device Evidence -->
## 16. Historical Build And Device Evidence

Repository history contains version-labelled commits before the rewrite baseline, and the inspected current startup/model files match the `scorekeep-rewrite-baseline-2026-07-13` tag for the relevant paths. This supports exact-current-container evidence for the present repository state.

This run did not build an archived prior app, launch a historical simulator app, copy a simulator app container from a prior build, or use a physical device. Therefore released-build and device-copy proof remains a limitation if future acceptance requires evidence from a particular App Store build artifact or physical-device store. No actual user data was accessed.

<!-- MARK: - 17. Source Version Authority Implications -->
## 17. Source Version Authority Implications

A future startup authority must distinguish absent store, current unversioned store, Proposed V1-recognized store, Proposed V2 migrated store, automatically evolved but not formally versioned store, completed store-copy conversion, interrupted conversion, unknown model version, unsupported future version, unusable store, verification required, and read-only fallback.

This run proves that exact current unversioned stores can be recognized and migrated in isolation, but it does not implement production source-version authority, startup routing, progress records, rollback, disable behavior, user-review policy, or diagnostics.

<!-- MARK: - 18. Staged Gate Results -->
## 18. Staged Gate Results

Stage A passed: an on-disk source store is created through the exact current unversioned production-style container construction, not Proposed V1.

Stage B passed: empty, minimal, representative, and edge-evidence source baselines are captured through fresh contexts.

Stage C passed: Proposed V1 recognition and direct Proposed V2 migration succeed on fresh copied stores.

Stage D passed: repeat open, stable semantics, no duplicate baseball records, no evidence rows, and operation-evidence uniqueness are verified.

Stage E passed as comparison evidence: automatic current-model-plus-evidence opening works and is later Proposed V2-recognizable.

Stage F passed as fallback evidence: store-copy compatibility conversion preserves supported semantics but is not needed for the recommended direct path.

Stage G was limited: no archive-built prior app, historical simulator launch, physical-device store, or user production store was used.

Stage H passed for exact-current-container evidence: verdict is Proven compatible and recommendation is Direction A, with production routing still blocked by separate operational gates.

<!-- MARK: - 19. Remaining Blockers -->
## 19. Remaining Blockers

Before production schema transition or team-creation routing, ScoreKeep still needs production source-version authority, migration-state and progress policy, startup write gates, rollback or disable behavior, user-review and retry outcomes, dedicated transaction context handoff, privacy-preserving diagnostics, routed UI verification, and release/device evidence policy if required.

Do not recommend team-creation routing until production schema transition, source-version authority, migration-state provider, disable path, dedicated transaction context, user outcome integration, diagnostics, and routing gates are all proven ready.

<!-- MARK: - 20. Exact Next Recommendation -->
## 20. Exact Next Recommendation

Next, design the production source-version and migration-state authority for the direct V1-to-V2 transition without routing it. The design should define startup classification, migration progress, interruption handling, rollback or disable behavior, verification requirements, user-review outcomes, and diagnostics. If release acceptance requires installed-build proof beyond repository-current evidence, create one disposable archive-built or simulator-created prior-app store and run the same transition against a copy.

# Existing-Store Migration and Recovery Baseline

<!-- MARK: - 1. Purpose and Strategy -->
## 1. Purpose and Strategy

This baseline completes implementation-catalog tasks 3.14 through 3.18 as a test-only Phase 3 migration-verification run. It introduces populated-store migration verification, interruption verification, repeated-migration idempotency verification, failed-migration recovery verification, and purchase or allowance separation verification.

The selected strategy is test-only compatibility conversion plus persisted-evidence reconstruction into disposable isolated current-model SwiftData targets. The source is immutable synthetic persisted-style evidence built from repository model, fixture, mapping, and compatibility evidence. The target is a fresh in-memory isolated test store using the current Game, Team, Player, Atbat, Lineup, and Pitcher model declarations.

No production store is opened or copied. No production startup route, ModelContainer initialization, SwiftData model, relationship, delete rule, external-storage attribute, StoreKit path, Keychain path, allowance counter, entitlement logic, UI, or accessibility behavior is changed.

<!-- MARK: - 2. Physical Migration Boundary -->
## 2. Physical Migration Boundary

This run is not a physical schema migration. It does not introduce a VersionedSchema, SchemaMigrationPlan, migration stage, production progress table, backup service, startup router, or cutover flag.

Physical schema migration means SwiftData moves an existing on-disk store from one declared schema version to another. Compatibility conversion means legacy or persisted-style evidence is interpreted, classified, and written into a separate target representation. Persisted-evidence reconstruction means stable identities and supported relationships are re-created in a disposable target store while unsupported evidence remains visible as diagnostics.

Repository evidence currently supports compatibility conversion and persisted-evidence reconstruction only. A production physical migration remains blocked until a versioned target schema, source-version policy, progress mechanism, rollback policy, and user-review policy are approved.

<!-- MARK: - 3. Populated Source Coverage -->
## 3. Populated Source Coverage

Focused tests cover minimal populated source, in-progress game, completed game, multiple games, multiple teams, reusable players, rosters, lineups, multiple scoring events, multiple innings through event evidence, pitcher evidence, substitution evidence, stored score evidence, ordering evidence, optional missing values, photos, logos, unsupported raw values, broken relationship evidence, duplicate identity evidence, and conflicting ordering evidence.

The conversion preserves stable game, team, player, scoring-event, lineup, and pitcher identities where present. It preserves home and visiting game-side meaning, roster membership, lineup participation, batting order evidence, event sequence, scorecard column evidence, pitcher appearance evidence, substitution array pairing where aligned, media owner identity, and stored scores as comparison evidence.

<!-- MARK: - 4. Record Counts and Semantic Verification -->
## 4. Record Counts and Semantic Verification

The minimal populated source converts to one game, three teams, four players, one at-bat, one lineup, and one pitcher in an isolated target. Fresh reload verifies the game identity, home side, visiting side, event sequence, scorecard column, stored score evidence, team identities, player identities, roster membership, lineup identity, and pitcher identity.

The completed representative source verifies media byte ownership, substitution pair order, pitcher evidence, stored-score agreement, and deterministic target reload. The multiple-game source verifies that games remain distinct and reusable players remain reusable without duplicating player identity.

Semantic comparison is by stable identifiers and stored meaning after fresh-context reload, not object-memory identity or incidental fetch order.

<!-- MARK: - 5. Relationship and Ordering Outcomes -->
## 5. Relationship and Ordering Outcomes

Broken team, player, lineup, and pitcher relationship evidence is preserved as warning or review evidence. The harness does not invent missing links, assign participants by name or jersey number, merge duplicate identities, silently align ambiguous substitution arrays, or silently reorder events.

Duplicate identity evidence is counted and classified. Duplicate or conflicting event-order evidence remains visible. Duplicate sequence evidence can remain in the target as compatibility evidence when its source identity is distinct, and the result requires review rather than pretending the ordering is clean.

<!-- MARK: - 6. Stored Score Reconciliation -->
## 6. Stored Score Reconciliation

Stored scores remain legacy comparison evidence. Tests classify stored score agreement, stored score mismatch, replay unable to establish score, unsupported stored score, and absent stored score through shallow reconciliation vocabulary.

A stored-score mismatch does not automatically block migration when the underlying supported facts remain preservable. The stored value is not rewritten to match replay, and replay-derived score is not hidden when available.

<!-- MARK: - 7. Pitcher Substitution Runner and Media Limits -->
## 7. Pitcher Substitution Runner and Media Limits

Pitcher evidence preserves player, team, game, start and end markers, aggregate compatibility fields, and ordering by explicit appearance boundary evidence. Full pitcher responsibility reconstruction remains limited by the current persisted shape and remains future work.

Substitution evidence preserves Game.replaced and Game.incomings pairing when arrays are aligned. Mismatched arrays, missing participant references, role, timing, and batting-slot ambiguity remain compatibility warnings or review items.

Runner and base evidence remains limited to current Atbat result, maxbase, outAt, stolen base, RBI, out, inning, and sequence fields. Complete runner movement and responsibility are not fabricated.

Media verification uses deterministic tiny test bytes. Valid player photos and team logos preserve owner identity after reload. Nil media remains nil. Malformed media is classified without invalidating otherwise usable baseball facts.

<!-- MARK: - 8. Interruption Outcomes -->
## 8. Interruption Outcomes

Deterministic interruption points cover before isolated target creation, before supported target writes, before unsupported evidence preservation, before target save, before reload, before canonical interpretation, and before completion marker.

Interrupted migration preserves source usability, leaves completion unproven, marks reload or review requirements, keeps target state classified, preserves purchase and allowance probes, and avoids reporting partial targets as successful.

Partial-target retry is verified. A retry against a target that already contains the same stable source identities reports already migrated rather than duplicating games, teams, players, lineups, at-bats, pitchers, substitutions, or media ownership.

<!-- MARK: - 9. Repeated Migration Outcomes -->
## 9. Repeated Migration Outcomes

Repeated execution is verified for successful migration, warning migration, interrupted migration, failed migration followed by restart, already migrated source, same operation identity, different operation identity for the same source, conflicting operation identity, empty source, and unsupported source.

Stable identity prevents duplicate games, teams, players, scoring events, lineups, pitchers, substitution evidence, and media ownership. Empty source produces no seed records. Conflicting repeated intent is rejected for review.

No random identifier, timestamp, memory address, array index alone, name alone, jersey number alone, or hash value is used as durable duplicate authority.

<!-- MARK: - 10. Failure Injection and Recovery -->
## 10. Failure Injection and Recovery

Injected failures cover source read failure, source validation failure, target creation failure, record-write failure, relationship-write failure, ordering-write failure, media-write failure, save failure, reload failure, verification failure, completion-marker failure, and purchase-separation failure.

Outcomes distinguish no target, empty target, partial target, saved but unverified target, verified but incomplete completion marker, recovery available, retry safety, retry uncertainty, target unusable, target review-required, source usable, and completion uncertain.

Recovery verification covers discarding an isolated incomplete target, reopening source evidence, restarting from the immutable source snapshot, preserving prior accepted isolated state, and requiring review rather than automatic repair where certainty is missing.

<!-- MARK: - 11. Purchase and Allowance Separation -->
## 11. Purchase and Allowance Separation

Purchase and allowance verification uses test probes only. It does not read or write StoreKit, Keychain, PurchaseManager, AppStorage, production counters, receipts, signed transactions, or production entitlement state.

Successful migration, successful migration with warnings, interrupted migration, repeated migration, failed migration, recovery, empty source, and populated source all preserve non-default purchase, entitlement, season-pass, free-game allowance, and MLB download allowance probe values.

Missing baseball records do not imply missing entitlement. Duplicate baseball records do not consume an allowance. Migration does not decrement free-game count or increment MLB download count. Migration input and output contain no receipt or signed transaction data.

If a probe changes unexpectedly, the result is purchaseSeparationFailure, completion is not proven, the source remains usable, the target requires review, and the baseball migration does not attempt entitlement repair.

<!-- MARK: - 12. Staged Gate Results -->
## 12. Staged Gate Results

Stage A passed: the test-only strategy was chosen and documented, one minimal populated source converted into a fresh isolated target, semantic identity was verified after reload, and the minimal migration test passed twice individually.

Stage B passed: representative in-progress, completed, multi-game, relationship, ordering, pitcher, substitution, media, and stored-score scenarios passed.

Stage C passed: duplicate identity, broken relationships, conflicting ordering, unsupported raw value, malformed source, partial migration, review classification, no identity fabrication, and no silent repair passed.

Stage D passed: deterministic interruptions preserved source usability and avoided false completion.

Stage E passed: repeated execution created no duplicate records and classified already-migrated, empty, unsupported, failed, interrupted, and conflicting intent cases.

Stage F passed: deterministic failures classified rollback, recovery, retry, review, and uncertainty.

Stage G passed: purchase, entitlement, season-pass, free-game allowance, and MLB download allowance probes remained unchanged across success, warning, interruption, repetition, failure, and recovery.

Stage H passed by inspection and focused assertions: no production store was opened, no production route changed, no production schema was introduced, no identity was fabricated, unsupported evidence remained visible, and no purchase or allowance state changed.

<!-- MARK: - 13. Authority Introduced and Legacy Authority Retained -->
## 13. Authority Introduced and Legacy Authority Retained

This run introduces test-only populated-store migration authority, test-only interruption verification authority, test-only repeated-migration and idempotency authority, test-only failed-migration and recovery authority, and verified purchase, entitlement, and allowance separation across populated migration outcomes.

Legacy production persistence, startup seeding, import/export, StoreKit, Keychain, allowance counters, entitlement logic, UI, accessibility behavior, and production ModelContainer authority remain active and unchanged.

<!-- MARK: - 14. Remaining Production Blockers -->
## 14. Remaining Production Blockers

Production migration remains blocked by the absence of an approved physical target schema, versioned SwiftData source schema, SchemaMigrationPlan, progress storage design, startup routing policy, production rollback mechanism, user review or repair workflow, game-time media snapshot policy, stored-score adjudication policy, substitution timing reconstruction policy, pitcher responsibility reconstruction policy, and final cutover gates.

Generated PDFs, screenshots, report-derived values, current inning, outs, runner projections, current or next batter, pitcher projections, and report totals remain derived or compatibility evidence. They are not migrated as baseball authority in this run.

<!-- MARK: - 15. Exact Task 3.19 Prerequisites -->
## 15. Exact Task 3.19 Prerequisites

Before task 3.19 begins, perform a complete Phase 3 evidence and cutover-readiness review. Confirm all Phase 3 baselines, populated migration tests, failure and recovery tests, purchase-separation tests, full test plan, production build, and source-control state remain clean.

Task 3.19 may prepare persistence-authority cutover gates only. It must not route persistence or scoring authority in the same run. It must not introduce production migration routing, production SchemaMigrationPlan, production VersionedSchema, startup migration, production backup, production repair executor, entitlement migration, UI, accessibility changes, legacy persistence retirement, scoring cutover preparation, report routing, or export routing.

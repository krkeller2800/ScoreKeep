# Save, Round-Trip, Relationship, and Ordering Baseline

<!-- MARK: - 1. Isolated Store Approach -->
## 1. Isolated Store Approach

Tasks 3.5 through 3.8 use disposable in-memory SwiftData containers created only by the test target. The harness uses the current production model declarations for Game, Team, Player, Atbat, Lineup, and Pitcher, but it does not initialize ScoreKeepApp, production ModelContainer creation, seeding, AppStorage, StoreKit, Keychain-backed counters, production Documents data, media folders, import routes, export routes, or user-owned records.

Each test creates its own isolated store and reloads through a fresh ModelContext where practical. No persistent test state is shared between tests.

<!-- MARK: - 2. Failure-Injection Approach -->
## 2. Failure-Injection Approach

Save failure verification uses a test-only save boundary that accepts a deterministic save closure. The success path calls ModelContext.save in the isolated context. The failure path throws a fixed test error before reporting through CanonicalPersistenceTransactionResult.

The mechanism does not swizzle SwiftData, corrupt stores, simulate disk-full behavior, change filesystem permissions, route production writers, or alter production save semantics.

<!-- MARK: - 3. Save Outcomes Tested -->
## 3. Save Outcomes Tested

The verification covers successful save, success with warnings, validation rejection before save, deterministic save failure, partial or uncertain outcome classification, stale projection, interrupted operation, duplicate or already-applied operation, relationship failure, ordering failure, unsupported evidence, contradictory evidence, unresolved evidence, safe retry, and unsafe retry.

Failed and rejected operations preserve the prior accepted state where the isolated evidence can prove that behavior. Uncertain completion is classified explicitly and requires reload.

<!-- MARK: - 4. Round-Trip Concepts Tested -->
## 4. Round-Trip Concepts Tested

Round-trip tests cover an empty isolated store, a minimal game, an in-progress representative game, and a completed representative game. Saved evidence includes one game, two teams, four players, scoring events, one lineup, pitcher appearances, replacement and incoming-player arrays, stored score evidence, fixed identities, fixed timestamps, optional values, and unsupported raw legacy values through read-only interpretation.

Reload comparison is semantic. It checks stable identity, team sides, player participation, event sequence, scorecard columns, batting order, lineup membership, pitcher order, substitution pair order, stored score evidence, and deterministic repeated reloads without relying on fetch order as authority.

<!-- MARK: - 5. Relationship Integrity Findings -->
## 5. Relationship Integrity Findings

Valid game-team, game-player, game-atbat, game-lineup, game-pitcher, and replacement/incoming relationships survive isolated save and reload. Missing home-team evidence, missing batter evidence, duplicate identity evidence, wrong-side lineup or pitcher evidence, broken substitution pairs, and ambiguous substitution arrays are classified through existing canonical persisted-evidence interpretation.

Current model declarations require non-optional Atbat, Lineup, and Pitcher relationships, so physically broken required child references are represented as read-only evidence snapshots rather than invalid SwiftData objects. No test repairs, deletes, merges, reassigns, fabricates identities, or rewrites arrays.

<!-- MARK: - 6. Ordering Preservation Findings -->
## 6. Ordering Preservation Findings

Explicit event sequence and scorecard column evidence survive reload. Batting order survives reload where explicitly stored. Reversed lineup array order is not treated as authoritative when explicit batting order differs. Pitcher appearance order is compared from explicit boundary evidence. Replacement and incoming-player arrays remain aligned when counts match, and unequal arrays remain diagnosable.

Duplicate event sequences, conflicting sequence order, duplicate batting slots, missing presentation-only order, fetch-only order, and imported source-file order are classified without resequencing records.

<!-- MARK: - 7. Gaps and Ambiguous Legacy Evidence -->
## 7. Gaps and Ambiguous Legacy Evidence

Current persisted evidence does not represent every canonical concept directly. Runner identity, complete base-state movement, lineup history after substitutions, full substitution timing and role, pitcher responsibility beyond stored boundary fields, correction supersession, and full media persistence remain incomplete or compatibility-only evidence.

Unsupported raw values can be preserved and classified. Ambiguous substitution arrays and incomplete pitcher relationships are not repaired automatically.

<!-- MARK: - 8. Allowance and Entitlement Separation -->
## 8. Allowance and Entitlement Separation

Save-failure tests use a separate immutable probe for free-game allowance, MLB download allowance, and entitlement markers. Baseball persistence save success, warning, validation rejection, deterministic failure, partial or uncertain result, relationship failure, ordering failure, unsupported result, contradictory result, unresolved result, and interruption classifications all require allowance and entitlement state to remain unchanged.

The tests do not read or write Keychain, StoreKit, PurchaseManager state, AppStorage, or production counters.

<!-- MARK: - 9. Remaining Task 3.9-3.10 Prerequisites -->
## 9. Remaining Task 3.9-3.10 Prerequisites

Task 3.9 should add media persistence verification for photos, logos, media replacement, invalid media, and media failure behavior without changing baseball facts. Task 3.10 should verify deletion, deactivation, archival, explicit repair, and no automatic destructive repair boundaries.

This baseline intentionally introduces no production writer, route, schema, migration, repair behavior, deletion behavior, StoreKit behavior, Keychain behavior, allowance behavior, entitlement behavior, UI behavior, accessibility behavior, or media write path.

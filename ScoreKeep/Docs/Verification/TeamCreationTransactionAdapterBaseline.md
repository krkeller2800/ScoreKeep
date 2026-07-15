# Team Creation Transaction Adapter Baseline

<!-- MARK: - 1. Candidate Selection -->
## 1. Candidate Selection

Simple team creation was selected because task 3.19 identified it as the safest bounded candidate for a future persistence-authority route. It has explicit stable identity, direct display fields, no scoring involvement, no import graph, no allowance consumption, no delete requirement, and low relationship complexity when limited to an empty reusable team record.

This run implements only an isolated production-compatible candidate adapter. It does not route production workflows, replace the legacy writer, create a feature flag, shadow write, perform comparison writes, or authorize cutover.

<!-- MARK: - 2. Supported Request Boundary -->
## 2. Supported Request Boundary

The request is an immutable shallow value. It carries stable operation identity, stable team identity, team name, coach, details, expected duplicate policy, isolated source classification, known invocation fingerprints, unsupported evidence field names, purchase and allowance probes, and gate state.

The request does not carry ModelContext, ModelContainer, live Team objects, SwiftUI bindings, closures, dates, random identity generation, StoreKit transactions, Keychain values, players, rosters, games, lineups, imports, scoring evidence, substitutions, pitchers, deletes, repair, or migration execution.

Logo creation is deferred from this first adapter. Team logo storage remains media evidence and must receive separate media-transaction review before routing.

<!-- MARK: - 3. Validation Behavior -->
## 3. Validation Behavior

Validation runs before insert or save. It rejects missing operation identity, missing or blank team name, dirty transaction context, unsupported request fields, unsupported source classification, conflicting operation identity evidence, gate failures, purchase-separation failure, and allowance-boundary failure.

Duplicate lookup is also completed before insert. Matching existing team meaning returns duplicate already applied. Conflicting existing meaning is contradictory and review-required. Duplicate lookup failure is unresolved and performs no insert.

<!-- MARK: - 4. Context Cleanliness Requirement -->
## 4. Context Cleanliness Requirement

The adapter requires a dedicated clean ModelContext. It checks `ModelContext.hasChanges` before insertion and rejects any context with preexisting pending changes. It does not inspect, save, discard, or roll back user-owned unrelated pending changes.

Future routing must provide a dedicated transaction boundary. Passing a production main context with pending view edits remains unsafe and is rejected by design.

<!-- MARK: - 5. Save Boundary -->
## 5. Save Boundary

The adapter performs exactly one isolated SwiftData insert and one explicit save for the supported success path. It maps the canonical request into the current Team model fields: identity, name, coach, details, empty players, empty games, and nil logo.

The adapter does not call the legacy team writer, production views, production environment injection, StoreKit, Keychain, imports, exports, repair, migration, or production startup code.

<!-- MARK: - 6. Rollback Behavior -->
## 6. Rollback Behavior

When save fails before completion is proven, the adapter rolls back only the changes it introduced in a clean context. Rollback completion and rollback uncertainty are classified separately.

A completed rollback preserves the prior accepted isolated context state and marks retry safe. Rollback uncertainty requires review and does not claim retry safety. Uncertain save completion is never reported as success and blocks blind retry.

<!-- MARK: - 7. Fresh Reload Verification -->
## 7. Fresh Reload Verification

After save succeeds, the adapter captures stable identifiers, stops using the inserted Team instance as proof, creates a fresh ModelContext from the same isolated container, fetches by stable team identity, verifies exactly one matching team, interprets the persisted team through existing persisted-to-canonical mapping, and verifies supported semantic meaning.

Reload failure is classified as stale projection requiring review. Semantic verification failure is contradictory and review-required.

<!-- MARK: - 8. Duplicate and Idempotency Behavior -->
## 8. Duplicate and Idempotency Behavior

The adapter prevents duplicate creation through stable operation identity evidence and stable team identity lookup. First invocation creates one team. Exact repeat returns duplicate already applied when the same operation fingerprint and matching persisted team are present. Different operation identity with matching team meaning also returns duplicate already applied and does not insert.

Same operation identity with conflicting request evidence is rejected before save. Same team identity with conflicting persisted meaning is contradictory and review-required. Failed save followed by safe retry creates at most one team. Uncertain completion remains review-required and not blindly retry-safe.

<!-- MARK: - 9. Failure Injection -->
## 9. Failure Injection

Deterministic external injection covers insert preparation failure, duplicate lookup failure, save failure, completion uncertainty, rollback uncertainty, reload failure, semantic verification failure, purchase-separation failure, and allowance-boundary failure.

Failure injection does not corrupt stores, change file permissions, fill disk, kill the process, alter production stores, access production data, or depend on XCTest inside production source.

<!-- MARK: - 10. Unchanged-Record Proof -->
## 10. Unchanged-Record Proof

Focused tests use isolated in-memory SwiftData containers with fixed identities. Success tests insert an unrelated graph containing team, player, game, at-bat, lineup, pitcher, relationships, ordering evidence, and media. Fresh snapshots prove only the requested team was added.

Other teams, players, games, lineups, at-bats, pitchers, relationships, ordering, media, purchase probes, entitlement probes, free-game allowance probes, and MLB download allowance probes remain unchanged. No automatic repair occurs.

<!-- MARK: - 11. Purchase and Allowance Separation -->
## 11. Purchase and Allowance Separation

The adapter does not import StoreKit, call PurchaseManager, access Keychain, read receipts, write entitlement state, read or write `freeGameCreatesRemainingKC`, read or write `mlbDownloadCountKC`, consume a game allowance, or infer entitlement from baseball records.

Tests use immutable probe values for success, validation rejection, duplicates, save failure, rollback uncertainty, reload failure, semantic verification failure, and injected separation failures.

<!-- MARK: - 12. Migration and Schema Gates -->
## 12. Migration and Schema Gates

The adapter remains disabled when schema state is unknown, source-store version is unknown, migration is incomplete, migration completion is uncertain, one-writer proof is absent, disable path is undefined, rollback or recovery policy is unresolved, purchase separation fails, or allowance boundary fails.

For isolated tests, a ready test gate state is supplied explicitly. The adapter does not mark production readiness complete and does not bypass task 3.19 gates.

<!-- MARK: - 13. Non-Routing Proof -->
## 13. Non-Routing Proof

No production view calls the adapter. No production environment injects it. No startup code constructs it. No feature flag enables it. No shadow write, comparison write, or fallback write exists.

Tests scan production Swift files, excluding the adapter source itself, for references to the adapter and request construction. They also verify the task 3.19 route manifest still classifies team creation as legacy SwiftData current authority and candidate future bounded routing only.

<!-- MARK: - 14. Limitations -->
## 14. Limitations

The adapter supports only simple reusable team creation. It does not support logo creation, players, rosters, games, lineups, imports, scoring, substitutions, pitchers, media transformation, deletes, repair, migration execution, StoreKit, Keychain, UI state, or production routing.

The operation fingerprint evidence is shallow and supplied externally. A routed future implementation must decide durable idempotency evidence before production use.

<!-- MARK: - 15. Prerequisites Before Routing Authorization -->
## 15. Prerequisites Before Routing Authorization

Before any routing authorization, reviewers must confirm every task 3.19 cutover gate, including schema decision, source-version policy, migration state policy, startup write policy, one-writer proof, disable path, rollback and recovery policy, user review policy for conflicts, durable idempotency evidence, purchase and allowance separation, no production data access during verification, and legacy writer disable behavior.

Routing must be a separate approved task. It should route only simple team creation through exactly one writer with an immediate disable path, and it must not combine routing with migration, scoring, imports, media, deletes, or legacy retirement.

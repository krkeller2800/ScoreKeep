# Production Migration Evidence and Source Preservation Baseline

<!-- MARK: 1. Current Non-Routed Boundary -->
## 1. Current Non-Routed Boundary

This run adds production-compatible migration evidence and source-preservation infrastructure only. `ScoreKeepApp` remains on `.modelContainer(for: Game.self)`, the active production model list remains Game, Team, Player, Atbat, Lineup, and Pitcher, and no production startup route constructs the proposed factory, journal, source-preservation executor, or orchestrator.

<!-- MARK: 2. Split Evidence Design -->
## 2. Split Evidence Design

Pre-open evidence is stored in an explicitly injected file-backed sidecar journal. It is readable before any target SwiftData container opens and records migration operation identity, source identity, source classification, target schema, phase, backup verification, disable state, ownership, recovery, retry, and stable diagnostic codes.

Post-open completion is also recorded in the sidecar journal for this run. The design intentionally does not overload team-operation evidence and does not add a migration-completion SwiftData model to Proposed V2.

<!-- MARK: 3. Pre-Open Journal Format -->
## 3. Pre-Open Journal Format

The journal has deterministic schema version 1 and stores only privacy-safe scalar evidence. It excludes store contents, team and player names, baseball statistics, media, receipts, entitlement values, allowance values, Keychain values, raw framework errors, full paths, and full logs.

Writes use a fresh temporary file, flush and close with `FileHandle.synchronize()`, then replace or move into the journal path. If a replacement attempt fails, the prior valid journal remains independently loadable.

<!-- MARK: 4. Post-Open Completion Decision -->
## 4. Post-Open Completion Decision

Post-open completion remains sidecar-based in this run. Proposed V2 is already the proven V1-plus-`TeamCreationOperationEvidenceRecord` target. Adding a migration-completion model to V2 would silently mutate the tested migration target. Creating Proposed V3 would broaden this run beyond the requested foundation, so it is deferred.

<!-- MARK: 5. Schema-Version Integrity Decision -->
## 5. Schema-Version Integrity Decision

Proposed V1 remains the current baseball model representation. Proposed V2 remains V1 plus team-operation evidence only. No Proposed V2 checksum, model list, migration plan, relationship, delete rule, external-storage behavior, or active production container changed.

<!-- MARK: 6. Journal Transition Rules -->
## 6. Journal Transition Rules

The journal enforces monotonic transitions from preflight through source classification, source preservation, backup verification, migration attempt, container construction, post-open verification, and completion. It rejects backward movement, operation identity replacement, source identity replacement, completion without verified backup when required, completion without post-open verification, and erasing uncertainty.

<!-- MARK: 7. Store-Family Discovery -->
## 7. Store-Family Discovery

Store-family discovery is based on the supplied SQLite store URL and observed related filenames. It classifies the primary file, WAL sidecar, SHM sidecar, missing optional sidecars, missing primary store, unexpected related files, redacted source-directory identity, and deterministic store-family diagnostic identity.

<!-- MARK: 8. Source-Closure Requirement -->
## 8. Source-Closure Requirement

Source preservation requires caller-supplied closure evidence: source container released, source context released, test authority released source access, and no other known source authority intentionally open. The executor does not guess and does not copy a live production store.

<!-- MARK: 9. Preservation Execution -->
## 9. Preservation Execution

The executor accepts only explicit source and backup URLs, rejects production-intended locations in tests, requires a fresh backup destination, discovers the source family, copies every discovered member with the original filenames, verifies source and backup file correspondence, and never deletes or replaces the source. It removes only incomplete test-owned backups when the caller explicitly permits that policy.

<!-- MARK: 10. Backup Verification -->
## 10. Backup Verification

Backup verification checks primary presence, file count, filename correspondence, file size, SHA-256 content fingerprint, distinct source and backup directories, source immutability, and semantic reopen through a fresh restore copy. Empty, minimal, representative, and media-bearing disposable stores were covered.

<!-- MARK: 11. Disable-State Persistence -->
## 11. Disable-State Persistence

Disable state is durable journal evidence. The default remains legacy route required. Missing state fails closed. Proposed authorization requires explicit supplied authorization evidence. Disabled, recovery-only, unsafe, and future unknown states block writes and do not automatically switch routes.

<!-- MARK: 12. Startup Ownership -->
## 12. Startup Ownership

Startup ownership is separate from route preference. It records no owner, legacy selected, proposed selected, migration in progress, recovery owner, uncertain, conflicting owners, and released. Claiming legacy then proposed for the same startup operation produces conflicting ownership and blocks writes.

<!-- MARK: 13. Orchestrator Sequence -->
## 13. Orchestrator Sequence

The non-routed orchestrator loads and reconciles the journal, resolves disable state, claims migration ownership, records source classification, preserves and verifies the source, copies the verified backup to a fresh disposable target, records migration attempt, constructs Proposed V2 through the existing factory, runs injected post-open verification, records sidecar completion, evaluates write readiness, and releases ownership.

<!-- MARK: 14. Interruption Handling -->
## 14. Interruption Handling

Interruption injection is supported after journal creation, disable-state resolution, ownership claim, source classification, backup copy start, backup copy completion, backup verification, migration-attempt recording, construction begins, construction returns, verification starts, verification passes, completion recording starts, completion recording succeeds, and ownership finalization.

Fresh journal instances retain the same operation identity and reconcile each phase deterministically.

<!-- MARK: 15. Recovery Classifications -->
## 15. Recovery Classifications

Recovery classifications include retry preflight with the same operation identity, reuse verified backup, discard incomplete disposable target, verify existing target, require manual review, no recovery required, and writes remain prohibited. Destructive production restore, production store replacement, automatic retry, and legacy reopening after Proposed migration begins are not implemented.

<!-- MARK: 16. Disposable Restore Proof -->
## 16. Disposable Restore Proof

Disposable tests create exact current unversioned stores, capture semantic baselines, close source access through explicit evidence, preserve and verify backup families, restore a copy to a fresh location, reopen through the old/current unversioned container, compare semantic snapshots, migrate a distinct target copy through Proposed V2, and confirm the original source remains unchanged.

<!-- MARK: 17. Diagnostic And Privacy Boundary -->
## 17. Diagnostic And Privacy Boundary

Persisted diagnostics are bounded stable codes such as journal unreadable, unsupported version, source active, backup mismatch, construction failed, verification failed, disable active, ownership conflict, and recovery required. Raw error text, full paths, record contents, media, purchase state, allowance values, and diagnostic logs are not persisted.

<!-- MARK: 18. Production Path Assessment -->
## 18. Production Path Assessment

The sidecar journal location, production backup location, retention policy, disk-space preflight, data-protection class, app-support path construction, production cleanup policy, and production user-outcome handling remain for a later active-container transition run. File coordination is not used for closed disposable store families; future production activation must reassess whether app extensions or other processes can access the store family.

<!-- MARK: 19. Active-Production Non-Routing Proof -->
## 19. Active-Production Non-Routing Proof

Focused boundary tests prove active startup still uses `.modelContainer(for: Game.self)`, Proposed V2 remains the proven team-evidence target, TeamView and production writers do not reference the migration foundation, and the new foundation does not reference StoreKit, Keychain, PurchaseManager, AppStorage, application support, document directory, SwiftUI, allowances, entitlements, UI, imports, exports, reports, or generated output.

<!-- MARK: 20. Remaining Blockers -->
## 20. Remaining Blockers

Verdict: Ready for a separate active-container transition run.

Before activation, ScoreKeep still needs production app-support journal path proof, production backup directory and retention policy, disk-space preflight, data-protection decision, production recovery and user-outcome integration, production diagnostics presentation or support path, production cleanup policy, and explicit approval for the active container route.

<!-- MARK: 21. Exact Next Implementation Recommendation -->
## 21. Exact Next Implementation Recommendation

Next implement the active production-container transition preparation run that injects the production journal and backup paths, proves disk-space and data-protection behavior, wires user outcomes and diagnostics, and still keeps Proposed V2 disabled until explicit activation approval. Do not route team creation or any baseball writer until the active container transition, production recovery behavior, dedicated context handoff, user outcome integration, diagnostics, and one-writer route are all proven.

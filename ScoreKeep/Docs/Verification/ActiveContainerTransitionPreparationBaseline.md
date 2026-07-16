# Active Container Transition Preparation Baseline

<!-- MARK: - 1. Current Active Startup Boundary -->
## 1. Current Active Startup Boundary

ScoreKeep remains on the legacy unversioned SwiftData startup route. `ScoreKeepApp` still constructs the active app container with `.modelContainer(for: Game.self)`. This preparation introduces no active Proposed V2 route, no production migration orchestrator construction, no production journal creation, no production backup, no production cleanup, and no baseball writer routing.

<!-- MARK: - 2. Production Migration Directory Layout -->
## 2. Production Migration Directory Layout

The production-compatible layout is rooted under an explicitly supplied Application Support root. The active store descriptor is `default.store` under that root, matching SwiftData default-store evidence inferred from disposable `ModelConfiguration(url:)` behavior and not from opening user data. Migration artifacts live under `ScoreKeepMigrationControl-v1` with versioned child roots for `Journal-v1`, `VerifiedBackups-v1`, `TemporaryTargets-v1`, `IncompleteTargets-v1`, `RecoveryCopies-v1`, `Diagnostics-v1`, `ManualReview-v1`, and `CleanupStaging-v1`.

<!-- MARK: - 3. Path Validation and Containment -->
## 3. Path Validation and Containment

Path validation standardizes paths, resolves existing symlinks, and checks containment by path components rather than raw string prefixes. It rejects traversal outside the supplied root, source equals backup, backup nested inside the active store family, temporary target equality with the active store, journal placement inside disposable targets, cleanup outside the migration-control root, and cleanup without an injected test-owned root.

<!-- MARK: - 4. Production Store Discovery Assessment -->
## 4. Production Store Discovery Assessment

The exact production store path is classified as framework-default path inferred from disposable equivalence. The preparation does not open, enumerate, copy, inspect, or derive facts from the user's production store. A later activation run must obtain the active store URL through a safe platform/container construction boundary before closing and preserving it.

<!-- MARK: - 5. Directory Creation Policy -->
## 5. Directory Creation Policy

Read-only dry assessment creates nothing. Migration-control root creation is allowed only during authorized transition preflight. The journal parent may be created before migration intent is recorded. Operation backup directories are created only after operation identity is known. Temporary targets are created only after backup verification. Recovery directories are created only for recovery classifications. Cleanup staging requires explicit cleanup authorization. Existing unexpected files block use, and non-empty operation directories require reconciliation.

<!-- MARK: - 6. Capacity Provider -->
## 6. Capacity Provider

Capacity preflight accepts an injected destination or volume and prefers `volumeAvailableCapacityForImportantUsage` when available. Query failure, unsupported volume, read-only volume, unavailable capacity, uncertain capacity, changed-capacity classifications, overflow, and contradictory inputs fail closed.

<!-- MARK: - 7. Required Space Calculation -->
## 7. Required Space Calculation

Required bytes are deterministic and overflow-safe. The formula accounts for complete source store family bytes, one verified backup copy, one temporary migration target, one restore verification copy, migration growth allowance, journal and diagnostic overhead, copy/replacement overhead, existing retained artifacts, a percentage safety margin, and a fixed minimum reserve. The calculation uses explicit nonnegative byte inputs and does not assume all reported free space can be consumed.

<!-- MARK: - 8. Capacity Policy and Failure Behavior -->
## 8. Capacity Policy and Failure Behavior

Capacity results report required bytes, available bytes, reserve bytes, surplus or deficit, confidence, stable diagnostic code, and proceed/stop policy. Insufficient space before backup stops before source copy. Capacity loss after backup or during verification blocks migration continuation, retains evidence, and does not delete verified backups automatically. Cleanup candidates do not reduce required space unless separately assessed and authorized.

<!-- MARK: - 9. File Protection Inventory -->
## 9. File Protection Inventory

The implementation can inspect and apply protection on disposable files where the platform supports `FileAttributeKey.protectionKey`. macOS and simulator behavior is not treated as physical-device iOS Data Protection proof. Directory inheritance, replacement, and copy behavior remain device-acceptance items.

<!-- MARK: - 10. Selected Protection Policy -->
## 10. Selected Protection Policy

The journal and diagnostic state use complete-until-first-user-authentication so startup reconciliation can run after first unlock. Backups, sidecars, temporary targets, and recovery copies inherit active-store protection, falling back to complete-until-first-user-authentication only for injected tests without source protection evidence. Mandatory protection application failure blocks activation where protection is required.

<!-- MARK: - 11. Protection Platform Limitations -->
## 11. Protection Platform Limitations

The repository can prove policy selection, injected application boundaries, and supported resource verification. It cannot prove pre-first-unlock physical-device behavior, background startup while protected data is unavailable, simulator-versus-device equivalence, file coordination semantics, or App Extension sharing behavior. Those remain physical-device acceptance blockers.

<!-- MARK: - 12. Retention Categories -->
## 12. Retention Categories

Retention categories include active, completed, uncertain, and recovery-required journals; verified backups; pending and failed backups; temporary and incomplete targets; active Proposed V2 store; recovery copies; diagnostic state; manual-review evidence; cleanup-eligible items; cleanup-prohibited items; and unknown artifacts.

<!-- MARK: - 13. Cleanup Policy and Executor Limits -->
## 13. Cleanup Policy and Executor Limits

Cleanup assessment is pure and side-effect free. It considers role, journal phase, disable state, startup ownership, verification status, generation, authorization, operation identity, and containment. The executor removes only explicitly eligible test-owned artifacts under the migration-control root. It cannot clean everything, cannot delete active source, active target, required journals, retained backups, uncertain evidence, recovery-required evidence, wrong-operation artifacts, symlink escapes, unknown files, or production paths.

<!-- MARK: - 14. Production Diagnostic Presentation -->
## 14. Production Diagnostic Presentation

Diagnostic presentation values contain stable diagnostic codes, startup disposition, migration phase, record availability, write-disabled state, retry safety, recovery requirement, backup verification, storage insufficiency, device-unlock requirement, restart appropriateness, and support appropriateness. They intentionally exclude full paths, team or player names, record counts, media details, StoreKit or Keychain evidence, raw exceptions, SQLite details, implementation type names, and operation UUIDs.

<!-- MARK: - 15. Startup User Outcome Mapping -->
## 15. Startup User Outcome Mapping

Startup outcomes map legacy startup, prepared-but-disabled state, insufficient or unavailable capacity, protection unavailability, backup requirements and failures, migration ready/in-progress/interrupted/completed, constructed container, verification pending, uncertain completion, recovery required, temporary disable, read-only records, retry permitted or prohibited, restart required, support/manual review, and fatal configuration defects into deterministic workflow policy.

<!-- MARK: - 16. Read-Only and Recovery Behavior -->
## 16. Read-Only and Recovery Behavior

Normal record display is allowed only for legacy normal startup, prepared-disabled legacy reads, completed migration, or explicit read-only records. Writes, scoring, imports, and team creation are blocked for recovery, uncertainty, disabled, insufficient-storage, protection, and retry states. Failed Proposed V2 startup does not imply safe legacy reopening of the same migrated store.

<!-- MARK: - 17. Exclusive Startup Selection -->
## 17. Exclusive Startup Selection

Startup selection is centralized as one value: legacy active, Proposed prepared but disabled, Proposed authorized for transition, Proposed active, Proposed temporarily disabled after activation, recovery only, unsafe, or unknown. The compiled/default selection remains legacy active. Missing state before any migration attempt fails closed to legacy; missing state after a migration attempt is unsafe.

<!-- MARK: - 18. Activation Authorization -->
## 18. Activation Authorization

Production transition authorization is separate from startup selection and defaults to absent. It requires Proposed V2 support, resolved production layout, passed capacity preflight, verified or accepted protection policy, permitting disable state, no unresolved prior migration, supported source classification, source preservation, one-writer ownership, diagnostics and outcomes, explicit release authorization, and accepted rollback/downgrade policy.

<!-- MARK: - 19. One-Writer Activation Seam -->
## 19. One-Writer Activation Seam

The later activation seam selects either legacy or Proposed. Legacy constructs the current legacy container and does not construct Proposed, claim migration ownership, or alter artifacts. Proposed does not construct legacy, resolves journal and disable state, claims ownership, preserves source, constructs Proposed V2 through the orchestrator, verifies startup, returns one authority, and keeps baseball writes disabled until readiness passes. This run adds vocabulary only.

<!-- MARK: - 20. Backup Path Policy -->
## 20. Backup Path Policy

Verified backups live under `VerifiedBackups-v1` in operation-specific directories named from non-personal operation generation and UUID evidence. Backup family files are isolated from active store discovery, protected at least as strongly as the source policy, retained after success and failure according to evidence, and never overwritten merely because a new migration begins.

<!-- MARK: - 21. Downgrade and Release-Reversion Policy -->
## 21. Downgrade and Release-Reversion Policy

An older unversioned build is not proven safe to open a Proposed V2 store. Code rollback and data rollback are distinct. Verified backup retention is required through at least one release interval. A release-level disable may stop new writers, but it must not silently reopen legacy over migrated data after a migration attempt.

<!-- MARK: - 22. Environment Simulation Results -->
## 22. Environment Simulation Results

The test support builds an injected Application Support simulation under a disposable root with active-store, migration-control, journal, backup, temporary-target, recovery, and diagnostic locations. It rejects non-empty roots and never uses the real Application Support path.

<!-- MARK: - 23. Existing Orchestrator Integration -->
## 23. Existing Orchestrator Integration

The existing migration orchestrator runs successfully against the injected layout after capacity preflight. The path resolver supplies non-overlapping paths, backup retention is assessed after success, temporary targets are cleanup-assessed rather than automatically removed, startup outcome mapping matches the orchestrator result, and the active production app remains unconnected.

<!-- MARK: - 24. Production Path Dry Assessment -->
## 24. Production Path Dry Assessment

Dry assessment computes intended production paths from an injected root, validates containment, classifies roles, and returns redacted diagnostic values. It creates no directories, opens no stores, enumerates no production files, copies no files, writes no journals, and applies no file protection.

<!-- MARK: - 25. Platform Limitations -->
## 25. Platform Limitations

Resolved by repository evidence: active startup remains legacy, Proposed V2 is non-routed, path construction is injected, diagnostics are private, and cleanup is test-owned. Covered by platform APIs where available: capacity query and file-protection attributes. Requiring simulator or device verification: SwiftData default active-store URL derivation. Physical-device blockers: Data Protection before first unlock, low-storage behavior, file coordination, background startup, and protected-data availability.

<!-- MARK: - 26. Physical-Device Acceptance Plan -->
## 26. Physical-Device Acceptance Plan

A later device run should use a production-style unversioned test store, restart before first unlock, launch after first unlock, background during preflight, terminate after backup, terminate during migration, simulate safe low-storage conditions, complete migration, relaunch repeatedly, verify backup retention, verify diagnostic presentation, and confirm writes remain disabled until readiness passes. It must not manufacture dangerously low storage or use user data.

<!-- MARK: - 27. Active Production Non-Routing Proof -->
## 27. Active Production Non-Routing Proof

Focused source-reference tests prove `ScoreKeepApp` still contains `.modelContainer(for: Game.self)` and does not reference the path resolver, capacity preflight, file protection, retention, cleanup, outcome policy, activation selection, Proposed V2 factory, Proposed V2 schema, or migration orchestrator. TeamView and production writers remain unrouted. StoreKit, Keychain, allowances, entitlements, UI, accessibility, imports, exports, reports, and media are unchanged.

<!-- MARK: - 28. Remaining Blockers -->
## 28. Remaining Blockers

The readiness verdict is blocked pending specific physical-device and production-path proof. Blockers are exact active-store URL derivation without opening user data, physical-device Data Protection behavior, protected-data availability before and after first unlock, file coordination and multi-process sharing proof, safe low-storage acceptance, and release-level downgrade/rollback signoff.

<!-- MARK: - 29. Exact Next Implementation Recommendation -->
## 29. Exact Next Implementation Recommendation

Next, run a separate physical-device and production-path proof task that derives the exact active SwiftData store URL without opening user data, verifies Data Protection and capacity behavior under safe test conditions, and records startup recovery presentation requirements. Do not route team creation, scoring, imports, writers, or Proposed V2 until that proof and recovery presentation are complete.

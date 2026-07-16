# Physical Device Migration Proof Preparation Baseline

<!-- MARK: - 1. Physical-Device Purpose -->
## 1. Physical-Device Purpose

This preparation establishes a disposable physical-device update proof for transitioning an exact current unversioned SwiftData store to Proposed V2. The run prepares a Legacy migration-test app for manual import and baseline capture, plus a Proposed migration-test build mode that must not be installed or launched until the manual baseline checkpoint is complete.

<!-- MARK: - 2. Disposable App Identity -->
## 2. Disposable App Identity

Both migration-test modes use the disposable bundle identifier `com.komakode.ScoreKeepMigrationTest` and display name `ScoreKeep Migration Test`. This identifier differs from production `Komakode.ScoreKeep`, creates a separate iOS sandbox, and does not share App Groups, CloudKit, Keychain groups, entitlements, or production data containers. No production app sandbox or records were inspected.

<!-- MARK: - 3. Configuration And Scheme Design -->
## 3. Configuration And Scheme Design

The safe implementation uses the existing app target plus checked-in build-setting override files because direct project-file editing while Xcode is open is prohibited. `MigrationTestLegacy.xcconfig` defines `SCOREKEEP_MIGRATION_TEST` and `SCOREKEEP_MIGRATION_TEST_LEGACY`. `MigrationTestProposed.xcconfig` defines `SCOREKEEP_MIGRATION_TEST` and `SCOREKEEP_MIGRATION_TEST_PROPOSED`. Both override the bundle identifier and display name to the same disposable app identity.

<!-- MARK: - 4. Signing Boundary -->
## 4. Signing Boundary

Automatic development signing remains the intended signing path. The app target already uses team `7U8E86JT3B`, and the user selected that team for test targets. No provisioning profiles, certificates, device identifiers, or signing artifacts are tracked. The migration-test override files are not App Store or TestFlight configurations.

<!-- MARK: - 5. Production Isolation -->
## 5. Production Isolation

Production Debug and Release builds define no migration-test compile conditions. Production bundle identifier, display name, document types, URL types, StoreKit configuration, startup model container, imports, team creation, scoring, and writers remain unchanged. The test-only overlay is wrapped in `#if SCOREKEEP_MIGRATION_TEST` and is absent from normal production compilation.

<!-- MARK: - 6. Legacy Test Startup -->
## 6. Legacy Test Startup

Legacy migration-test mode still uses the same unversioned startup path as production: `ScoreKeepApp` with `.modelContainer(for: Game.self)`. It does not construct Proposed V2, does not run the migration plan, does not create a migration journal, does not create a backup, and does not route rewritten writers. It adds only a compile-time test banner, diagnostics, and baseline-capture action.

<!-- MARK: - 7. Proposed Test Startup Preparation -->
## 7. Proposed Test Startup Preparation

Proposed migration-test mode is prepared but disabled. Its safety classifier reports `proposedMigrationDisabledPendingManualBaseline`, proposed write readiness is prohibited, and no authorization path permits migration during this preparation run. It is intentionally not installed or launched before the user returns the Legacy baseline summary.

<!-- MARK: - 8. Store-Path Observation -->
## 8. Store-Path Observation

The diagnostic surface resolves the disposable app Application Support root through the app sandbox and classifies the expected active store as `default.store` using the existing production-path layout policy. It checks only the store-family filenames `default.store`, `default.store-wal`, and `default.store-shm` inside that disposable sandbox and displays only role and filenames, not full paths.

<!-- MARK: - 9. Protected-Data Observation -->
## 9. Protected-Data Observation

The migration-test overlay observes protected data availability using platform protected-data notifications. It records available, unavailable, became-available, will-become-unavailable, or unknown states. Legacy mode displays this evidence without changing startup behavior. Proposed mode remains disabled and must not begin migration while protected data is unavailable.

<!-- MARK: - 10. Import-File Plan -->
## 10. Import-File Plan

The disposable app keeps the existing document type declarations and import behavior for `.ScoreKeep_Games` and `.ScoreKeep_Players`. The user will import `Cardinals at Tigers on Apr 4, 2026.ScoreKeep_Games` and `Blue Jays 2.ScoreKeep_Players` manually from iCloud Drive through the normal app interface. The files are not embedded in the app target.

<!-- MARK: - 11. Baseline-Capture Behavior -->
## 11. Baseline-Capture Behavior

Legacy migration-test mode exposes `Capture Migration Baseline`. It fetches Game, Team, Player, Lineup, Atbat, and Pitcher records through the active disposable legacy ModelContext, records counts and deterministic fingerprints, and writes a JSON sidecar under `ScoreKeepMigrationTestDiagnostics-v1` inside the disposable sandbox. It does not mutate baseball records.

<!-- MARK: - 12. Difficult Runner-Sequence Evidence -->
## 12. Difficult Runner-Sequence Evidence

Baseline capture attempts to identify a candidate third-out inning boundary from persisted at-bats where `endOfInning` is true and outs are at least three. It records runner/player identity fingerprints where the compact model supports it, originating and intervening at-bat fingerprints, runner-out evidence, third-out classification, next-batter evidence, and stored score evidence. Unsupported or ambiguous facts are recorded explicitly instead of fabricated.

<!-- MARK: - 13. Device Diagnostics -->
## 13. Device Diagnostics

The diagnostic summary reports mode, bundle classification, container mode, protected-data state, store role and filename, store-family members, file-protection classifications when available, journal and backup presence, migration phase, startup ownership, disable state, write readiness, capacity diagnostic, baseline status, and stable diagnostic codes. It excludes full sandbox paths, raw records, receipts, Keychain values, operation UUIDs, and raw errors.

<!-- MARK: - 14. Update-Preservation Design -->
## 14. Update-Preservation Design

Legacy and Proposed override files use the same bundle identifier, display name, signing team expectation, and app target. Installing Proposed later over Legacy should update the same disposable app sandbox instead of replacing production ScoreKeep. Proposed installation must not require deleting Legacy first and must not be run before the manual checkpoint.

<!-- MARK: - 15. Low-Storage Boundary -->
## 15. Low-Storage Boundary

This preparation uses only actual volume capacity observation and deterministic required-space estimation from the disposable store family. It does not fill the device, create large files, delete user files, or begin migration. Proposed test mode retains a policy path for later deterministic insufficient-capacity simulation, separate from physical device capacity observation.

<!-- MARK: - 16. File-Coordination Assessment -->
## 16. File-Coordination Assessment

Repository evidence shows no app extension, no tracked entitlements, no App Group, and no Cloud-synchronized active SwiftData store configuration. Current ownership is single-process app ownership. Closing and releasing the active ModelContainer before preservation remains mandatory. NSFileCoordinator is not claimed to make live SQLite copying safe and is not added in this run.

<!-- MARK: - 17. Manual Import Checklist -->
## 17. Manual Import Checklist

1. Confirm the app is named `ScoreKeep Migration Test`.
2. Confirm the banner says `Legacy Store` and `Disposable Test Data Only`.
3. Import `Cardinals at Tigers on Apr 4, 2026.ScoreKeep_Games`.
4. Import `Blue Jays 2.ScoreKeep_Players`.
5. Open the imported game.
6. Confirm both teams and logos appear.
7. Confirm starting lineups appear.
8. Confirm at-bat history is present.
9. Confirm five pitching substitutions are present.
10. Confirm two player substitutions are present.
11. Locate the runner-out third-out inning.
12. Note the runner, inning, batter at the time, and next inning's first batter.
13. Confirm the final score.
14. Open the Blue Jays roster and confirm players appear.
15. Optionally make one small manual edit such as coach or team details.
16. Return to the app and tap `Capture Migration Baseline`.
17. Confirm the baseline reports complete or reports any ambiguity.
18. Force-quit the disposable test app.
19. Relaunch it.
20. Confirm the imported game and roster remain.
21. Do not delete the app.
22. Do not install or run the Proposed build yet.
23. Return the displayed baseline summary to ChatGPT.

<!-- MARK: - 18. Later Migration Test Sequence -->
## 18. Later Migration Test Sequence

The later physical proof will cover Legacy import and baseline, normal relaunch, device lock after first unlock, protected-data observation while locked, unlock observation, Proposed installation over Legacy, migration start while unlocked, termination after verified backup, relaunch reconciliation, successful migration, repeated Proposed launch, baseline comparison, backup retention, legacy fallback prohibition after migration begins, safe low-storage classification without filling the device, device restart and first-unlock behavior when feasible, and downgrade or reversion warning.

<!-- MARK: - 19. Active-Production Non-Routing Proof -->
## 19. Active-Production Non-Routing Proof

Focused tests prove production and disposable bundle identifiers differ, normal compilation defaults to production mode, migration modes require the disposable bundle identity, Legacy mode is legacy-only, Proposed mode is disabled, diagnostics are redacted, baseline capture requires the disposable Legacy safety pairing, baseline capture does not mutate records, and `ScoreKeepApp` still contains the legacy `.modelContainer(for: Game.self)` startup guarded from test-only UI by compile conditions.

<!-- MARK: - 20. Remaining Manual Checkpoint -->
## 20. Remaining Manual Checkpoint

The preparation must stop after the Legacy migration-test build is ready or installed. The user must complete imports, visual verification, baseline capture, force-quit, relaunch, persistence verification, and return the displayed baseline summary. No Proposed build may be installed or launched before that checkpoint.

<!-- MARK: - 21. Exact Next Action After Baseline Return -->
## 21. Exact Next Action After Baseline Return

After the user returns the Legacy baseline summary, compare the baseline status, counts, fingerprints, substitution evidence, difficult runner-sequence classification, protected-data observations, store-family evidence, and capacity diagnostic. Only then decide whether to proceed with the separate Proposed physical-device migration proof. Do not begin task 3.20 or task 2.19.

<!-- MARK: - 22. Physical Proposed Migration Execution Proof -->
## 22. Physical Proposed Migration Execution Proof

The user installed Proposed over the disposable Legacy app without deleting the app. The pre-migration Proposed checkpoint confirmed `disposableMigrationTest`, protected data available, baseline reloaded as `completeOrReviewAmbiguity`, active legacy store family `default.store`, `default.store-shm`, and `default.store-wal`, journal absent, backup absent, phase not started, proposed writes prohibited, and capacity sufficient.

After explicit manual authorization, the physical-device migration completed in the disposable sandbox. The screen reported journal `completionRecorded`, backup `verifiedBackupPresent`, post-migration baseline `matchesStoredLegacyBaseline`, writes `prohibited`, and runner sequence `thirdOutBoundaryCapturedWithAmbiguity`. The proof did not access production ScoreKeep data, did not enable production migration startup, and did not enable rewritten baseball writer routes.

<!-- MARK: - 23. Reinstall And Relaunch Persistence Proof -->
## 23. Reinstall And Relaunch Persistence Proof

The Proposed test build was reinstalled over the same disposable migrated app to verify terminal-state persistence. The copied summary reported journal `completionRecorded`, backup `present`, readiness `completedMigrationRecorded`, post-migration baseline `matchesStoredLegacyBaseline`, and diagnostic code `migration.completed.reauthorizationBlocked`. A repeated force-quit and physical iPhone relaunch preserved the same terminal state.

The persisted baseline remained `currentUnversionedLegacySwiftData` with games `2`, teams `4`, players `144`, lineups `4`, at-bats `111`, pitchers `11`, score fingerprint `c53703e9def116cb`, substitutions fingerprint `debbc0c51f669deb`, and runner sequence `thirdOutBoundaryCapturedWithAmbiguity`.

<!-- MARK: - 24. Final Physical Proof Boundary -->
## 24. Final Physical Proof Boundary

The physical proof confirms that the prepared migration orchestration can preserve the full disposable legacy store family, create and retain a verified backup, persist a completion journal, reopen Proposed V2 in a fresh context, compare migrated data against the stored Legacy baseline, keep proposed writes prohibited, and block repeat migration authorization after completion. The disposable test app must remain installed until any later retention, backup, or restart checks are intentionally scheduled. Production ScoreKeep startup remains legacy-only.

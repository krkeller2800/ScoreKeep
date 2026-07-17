# Production Startup Recovery Baseline

<!-- MARK: 1. Purpose -->
## 1. Purpose

This baseline records the bounded production startup recovery follow-on for activated Proposed startup. The work adds deterministic, user-facing fail-closed handling for startup states where ScoreKeep cannot safely expose the normal writable interface.

<!-- MARK: 2. Repository Evidence -->
## 2. Repository Evidence

Preflight confirmed branch `scorekeep-next`, local HEAD `5a29687e411ac2e54974de9e6063e99d289ac83d`, and direct GitHub branch head `5a29687e411ac2e54974de9e6063e99d289ac83d`. The only pre-existing untracked state was Xcode user-state under `xcuserdata`, which remains untracked and untouched.

<!-- MARK: 3. Startup Outcome Inventory -->
## 3. Startup Outcome Inventory

The production host now distinguishes protected data unavailable, capacity insufficient or unavailable, interrupted retryable migration, recovery-required migration evidence, corrupt journal, unsupported journal, incomplete source family, backup verification failure, Proposed open failure, post-migration verification failure, completion-record failure, retry blocked, retry in progress, and completed startup. Non-completed durable journal phases are classified before migration resumes.

<!-- MARK: 4. User-Facing State Model -->
## 4. User-Facing State Model

`ScoreKeepProductionStartupRecoveryPresentation` separates diagnostic code, title, explanation, allowed actions, retry policy, and privacy-safe support summary. It is value-based, deterministic, testable without stores, and exposes no raw `Error`, path, UUID, journal body, schema terminology, or baseball record data to the view.

<!-- MARK: 5. Protected-Data Handling -->
## 5. Protected-Data Handling

Production startup checks protected-data availability before resolving the production layout, opening stores, copying stores, or starting migration. When protected data is unavailable, the normal writable UI is blocked and the recovery surface asks the user to unlock the device. Protected-data availability notifications transition only to a retry-ready state; they do not start a migration automatically.

<!-- MARK: 6. Capacity Handling -->
## 6. Capacity Handling

Capacity is assessed before preservation or target creation for an existing source family. Insufficient, safety-margin, unavailable, unsupported, read-only, query-failed, and overflow capacity states fail closed before mutation. Retry is offered only as an explicit user action and performs a fresh reassessment.

<!-- MARK: 7. Interrupted Migration Recovery -->
## 7. Interrupted Migration Recovery

Startup launch classifies non-completed durable journal evidence and does not resume automatically. Retry reuses the same durable operation identity. The orchestrator now resumes forward-only from recorded phases, preserving existing journal, backup, source, and target evidence instead of regressing the journal or recreating backup evidence.

<!-- MARK: 8. Corrupt Evidence Handling -->
## 8. Corrupt Evidence Handling

Corrupt, unreadable, unsupported, contradictory, or manually reviewable evidence remains fail-closed. The app does not delete, repair, rewrite, or discard the journal, backup, source, or target automatically. Retry is prohibited where existing recovery policy requires manual review or writes to remain prohibited.

<!-- MARK: 9. Proposed Open Failure -->
## 9. Proposed Open Failure

Completed-journal startup opens only the Proposed target. If that open fails, startup reports a recovery state and does not open Legacy as a competing writer. Source, backup, journal, and target evidence remain preserved.

<!-- MARK: 10. Retry Behavior -->
## 10. Retry Behavior

The recovery screen provides one explicit retry boundary. Retry re-enters startup through durable state, coalesces repeated taps with an in-progress guard, disables retry while active, does not reset app data, does not delete evidence, and opens the normal ScoreKeep interface only after successful completion and Proposed container open.

<!-- MARK: 11. Support Summary -->
## 11. Support Summary

Blocked startup includes Copy Support Summary. The summary reports app version/build, startup outcome, protected-data state, capacity classification, source classification, backup status, migration phase category, target verification category, retry policy, and stable diagnostic code. It omits paths, filenames, UUIDs, device identifiers, baseball data, receipts, Keychain values, and raw errors.

<!-- MARK: 12. Normal Successful Launch -->
## 12. Normal Successful Launch

Successful startup still opens the existing ScoreKeep interface. No recovery screen, migration-test checkpoint, or test banner remains over normal production UI. Existing normal UI layout and workflows were not redesigned.

<!-- MARK: 13. One-Container Authority -->
## 13. One-Container Authority

The startup host exposes one active `ModelContainer` to the normal interface. Blocked states expose no normal writable UI. Completed startup opens Proposed only after completed durable evidence or successful fail-closed migration verification. Legacy is not opened as a competing writer after Proposed mutation may have begun.

<!-- MARK: 14. Routing Boundaries -->
## 14. Routing Boundaries

Simple manual Team creation remains routed through the canonical Proposed transaction service after successful startup. Game creation and editing, team editing, team deletion, player workflows, lineups, pitchers, at-bats, substitutions, scoring, imports, media, reports, generated output, purchases, and allowances remain unchanged.

<!-- MARK: 15. Focused Tests -->
## 15. Focused Tests

Codex focused verification passed 21 tests, 0 failed, 0 skipped. Coverage included production recovery presentation mapping, support summary privacy, protected-data/capacity actions, fail-closed outcome mapping, orchestrator interruption handling, retry resume from verified backup with the same operation identity, startup boundary tests, startup outcome policy tests, and simple-team routing tests.

<!-- MARK: 16. Full Regression -->
## 16. Full Regression

Manual Xcode gate was reported as passed for the affected startup/recovery suite and the full normal test plan on the normal ScoreKeep scheme and established concrete iPad simulator. No physical iPhone gate was required for this follow-on.

<!-- MARK: 17. Production Build -->
## 17. Production Build

Codex `BuildProject` passed for the normal production build. Manual Xcode normal Debug build was reported as passed.

<!-- MARK: 18. Deferred Work -->
## 18. Deferred Work

Task 3.20 Legacy persistence retirement remains not started. Task 2.19 Scoring-authority cutover preparation remains not started. The exact next implementation task is Task 2.19 Scoring-authority cutover preparation only after accepting this startup recovery baseline and preserving the current bounded routing boundary.

<!-- MARK: 19. Final Verdict -->
## 19. Final Verdict

Production startup recovery is implemented for the activated bounded Proposed startup. Startup continues to fail closed, user-facing recovery states are deterministic and privacy-safe, retry is explicit and durable-state based, one-container authority is preserved, simple-team routing remains active after successful startup, and all other production workflows remain on their previous behavior.

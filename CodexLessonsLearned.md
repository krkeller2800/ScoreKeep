# Codex lessons learned for ScoreKeep

This guidance consolidates the completed external audits `ScoreKeep-Xcode-Codex-Lessons-Audit.txt` and `ScoreKeep-Desktop-Codex-Lessons-Audit.txt`. The audits are the evidence; this document is a working reference, not a new transcript review. A repeated command or resumed task is not a separate incident. Where an investigation stopped short of runtime proof, the lesson preserves that limit.

## Working context and verification

### 1. Confirm the checkout before investigating

- **Problem:** Work on a current-app crash began in the Legacy checkout; other work occurred on detached or dirty checkouts.
- **Historical evidence:** The wrong-checkout start was corrected before edits. The Desktop repair then proceeded in the current ScoreKeep repository on `scorekeep-next`.
- **What worked:** Check the absolute repository root, branch or detached HEAD, and worktree status against the product and version named in the task.
- **Future rule:** Verify those three facts at the start and again before Git changes when context has shifted.
- **Scope:** General Codex/Xcode. **Environment:** Desktop Codex.

### 2. Classify Xcode execution failures before diagnosing the app

- **Problem:** Restricted shell runs produced CoreSimulator service/log denials, DerivedData and cache permission errors, plugin-server failures, and unavailable simulator destinations. Some resembled compile or runtime defects.
- **Historical evidence:** These failures recurred in both histories; Xcode-native builds and tests sometimes succeeded where sandboxed `xcodebuild` or `simctl` failed. The audits do not establish that every `xcodebuild` failure was environmental.
- **What worked:** Use the connected Xcode build/test tools when available. For a shell gate, inspect the first causal error, discover an installed destination for tests, and use an appropriate writable DerivedData location or generic simulator destination for build-only checks when needed. Record manual Xcode verification if simulator execution remains blocked.
- **Future rule:** Distinguish tool, destination, and sandbox failures from source or test failures. After a confirmed denial, stop retrying the same blocked route and switch to a viable gate.
- **Scope:** General Codex/Xcode. **Environment:** Both.

### 3. Discover tests and prove that the intended cases ran

- **Problem:** A guessed focused selector returned a green result with zero tests; filenames and display names did not reliably identify active-plan tests.
- **Historical evidence:** Xcode history repeatedly used test-list discovery before successful focused runs. Desktop history contains one confirmed zero-test selector result; it does not prove a recurring zero-test rate.
- **What worked:** Query the active test plan or discovery output, copy exact identifiers or suite names, and inspect the executed count and named cases across XCTest and Swift Testing output.
- **Future rule:** Treat a zero-test success as no verification. Require a positive count that includes the intended tests.
- **Scope:** General Codex/Xcode. **Environment:** Both.

### 4. Start focused, then triage broad results by failure

- **Problem:** Full plans took substantial time and combined task regressions, stale assertions, UI or environment failures, and unrelated issues. One broad run stalled after test execution.
- **Historical evidence:** Xcode history recorded plans above 1,300 tests and a release run with mixed failures. Desktop history recorded a stalled release run with reported test issues; repeated retries belonged to the same task.
- **What worked:** Use diagnostics, changed-area tests, adjacent regressions, and a build before a full plan unless release scope calls for the full gate. Save the complete failure list, group failures, and reproduce plausible regressions with focused runs.
- **Future rule:** Choose the smallest meaningful gate during triage. Run the full plan when change scope or release criteria justify it; never treat an aggregate failure count as a diagnosis.
- **Scope:** General Codex/Xcode. **Environment:** Both.

### 5. Check the current contract and fixture before changing production

- **Problem:** Old PDF text expectations, position capitalization, schema versions, roster normalization, and live-scoring fixture assumptions produced failures that did not by themselves prove product defects.
- **Historical evidence:** Multiple Xcode incidents and two Desktop tasks exposed stale expectations or fixture setup. PDF symbol extraction was also an unreliable assertion mechanism. These findings do not make every test failure stale.
- **What worked:** Compare assertions with current requirements and implementation, verify fixture preconditions and schema, and use a focused probe. For PDFs, combine semantic assertions with rendered evidence when visual content matters.
- **Future rule:** Establish expected current behavior before editing production; change a test or fixture only when evidence shows its expectation is stale, and change production only for a reproduced defect.
- **Scope:** ScoreKeep-specific. **Environment:** Both.

### 6. Preserve the build/test command's own result

- **Problem:** `xcodebuild` output piped to `rg`, `tail`, or an optional formatter could leave the shell reporting the filter's status; short snippets also concealed failed or zero-test runs.
- **Historical evidence:** Desktop release commands returned successful shell summaries alongside failed tests, and interrupted runs had already emitted test results. Xcode history recorded an absent formatter in a validation pipeline.
- **What worked:** Check helper availability, save the full log, capture `xcodebuild`'s own exit status, and inspect test counts, issues, and result markers separately.
- **Future rule:** Never infer a passing gate from a filtered line or pipeline status alone. Report command exit, executed tests, and assertion outcome distinctly.
- **Scope:** General Codex/Xcode. **Environment:** Both.

### 7. On timeout or stall, resume only unfinished work

- **Problem:** Large evidence generation, Xcode operations, and runner finalization timed out or stopped responding, encouraging blind full retries.
- **Historical evidence:** Xcode history recorded a combined render/write timeout and an unresponsive session. Desktop history recorded test execution with reported issues followed by a stalled runner; its internal stall cause was not established.
- **What worked:** Inspect process and saved result state, preserve completed output, split expensive steps, and rerun the smallest unfinished operation. Bound a runner that has stopped making progress.
- **Future rule:** A timeout is an unknown process state, not proof that earlier work failed. Report completed test results separately from runner finalization.
- **Scope:** General Codex/Xcode. **Environment:** Both.

### 8. Resolve Xcode navigator paths to real files

- **Problem:** A navigator path or an extra `ScoreKeep` component was passed to shell or patch tools, causing failed reads and edits.
- **Historical evidence:** The Xcode audit found this in several independent tasks. Xcode project organization paths and filesystem paths were not interchangeable.
- **What worked:** Locate the actual file first; use Xcode tools with their navigator path or filesystem tools with a confirmed absolute path.
- **Future rule:** Never translate a navigator path mechanically. Resolve it before the first edit.
- **Scope:** General Codex/Xcode. **Environment:** Xcode Codex.

## ScoreKeep data, UI, and delivery

### 9. Establish migration source provenance and classification

- **Problem:** Source type names, nominal version labels, or newly built “legacy” fixtures were treated as evidence of how a persisted SwiftData store would open.
- **Historical evidence:** The Xcode migration program showed that persisted metadata, versioned versus unversioned schemas, source classification, and the selected container plan matter. Desktop migration work showed that a Legacy/V1-recognizable success did not establish active-V2 startup success.
- **What worked:** Inspect authentic or faithful store metadata and the production classifier; distinguish no-store startup, Legacy migration, and already active versioned-store startup. Use read-only store inspection when the question concerns persisted values, rather than inferring them from screenshots.
- **Future rule:** Name the physical source store, its provenance and classification, and the exact source schema for every migration claim. Do not accept a fixture as legacy from its Swift type names alone.
- **Scope:** ScoreKeep-specific. **Environment:** Both.

### 10. Exercise production startup and independent migration verification

- **Problem:** A factory-only result or a successful Legacy rehearsal could mask a separate startup route. A proposed schema-target change could not satisfy a verifier that lacked an independent pre-migration baseline.
- **Historical evidence:** Desktop history recorded a disposable active-V2 replay whose copied workspace opened as V4 but failed destination verification and prohibited writes; it did not prove customer data loss. The authentic Legacy rehearsal used a different source and route. Xcode history likewise tied migration outcomes to the selected production container path.
- **What worked:** Replay a disposable copy through normal startup. Record preflight classification, backup schema, copied workspace schema, factory target, journal phase, destination evidence, and write-readiness. Preserve and compare the SQLite store, WAL, SHM, and support files; verify the original separately from migration completion.
- **Future rule:** Require authentic source data, a backup of the whole store family, the actual production entry path, and independent baseline/destination evidence before calling a route safe or changing its target. State the exact route tested and any unresolved route separately.
- **Scope:** ScoreKeep-specific. **Environment:** Both.

### 11. Compare SwiftData data through durable domain facts

- **Problem:** Migration comparisons treated inverse relationship materialization or array traversal order as identity and signaled false differences. Parallel substitution relationships lacked a durable pairing key.
- **Historical evidence:** Desktop fixtures differed in `Team.games` materialization and `Lineup.players` order while canonical team links and batting-order scalars matched. Xcode history found that UUID sorting could invent substitution pairing that the model never stored.
- **What worked:** Populate intended fixture links, compare canonical game/team relationships and explicitly sorted domain fields, and use category-level diagnostics before weakening safety checks.
- **Future rule:** Do not infer semantic order or pairs from unordered SwiftData relationships or UUID sorting. Add a durable key before exact ordered replay is required.
- **Scope:** ScoreKeep-specific. **Environment:** Both.

### 12. Verify UI interaction in the configuration where it fails

- **Problem:** Builds and logic tests could not prove visual timing, accessibility, or tap behavior; a defensive-fielder hit-target defect appeared in Release but not Debug.
- **Historical evidence:** Desktop history established the current-app Release overlap, while similar Legacy source did not prove a Legacy runtime reproduction because final tap interaction was not performed. Xcode history found Device Interaction could be unavailable for an installed simulator when its service required a newer runtime.
- **What worked:** Check the device-interaction runtime before planning automation, exercise the actual Release artifact and taps when possible, and leave a precise manual gate for behavior tools cannot drive.
- **Future rule:** Do not claim Release or visual interaction is verified from source similarity, a Debug run, or a build alone. Separate proven automated results from remaining device checks.
- **Scope:** ScoreKeep-specific. **Environment:** Both.

### 13. Carry SwiftUI dependencies through every presentation route

- **Problem:** `EditScoreView` gained a required `PurchaseManager` environment object, but one live-scoring destination presented it without that dependency and crashed.
- **Historical evidence:** Desktop history records one production incident, not a recurring class count. The repair supplied the existing app-scoped object at the destination, passed eight focused tests, and built successfully.
- **What worked:** Trace every producer and presenter, including alternate navigation and iPad routes, then inject the dependency at the ownership boundary with a focused destination regression.
- **Future rule:** When a destination adds an `EnvironmentObject`, audit every production presentation route that can reach it.
- **Scope:** ScoreKeep-specific. **Environment:** Desktop Codex.

### 14. Stage exact work and verify the remote independently

- **Problem:** Unrelated Xcode files and unfinished changes coexisted with tasks; sandboxed `.git` writes could block staging or tracking-ref updates. Local `origin/*` could be stale even after a successful push, and DNS denial left remote state unknown.
- **Historical evidence:** Both audits recorded unrelated work, index or ref restrictions, and remote-tracking mismatches. Desktop release work confirmed a stale tracking ref with a direct remote query.
- **What worked:** Inspect status and staged versus unstaged diffs, stage explicit paths or hunks, obtain permitted Git metadata access only when needed, then compare the commit with a direct remote ref/SHA query. Record final worktree status separately.
- **Future rule:** Preserve all pre-existing work. Verify the exact staged diff before commit and the exact remote SHA after push; do not equate local tracking status or sandbox DNS failure with remote state.
- **Scope:** General Codex/Xcode. **Environment:** Both.

### 15. Update the established persistent report exactly

- **Problem:** Required external reports were sometimes omitted from read-only task completion or updated through a failed patch pattern; alternate filenames would not satisfy the workflow.
- **Historical evidence:** Both audits recorded report-handling corrections. The current `AGENTS.md` already contains the full report rule, including the exact Codex path and verification commands.
- **What worked:** Replace the established file in place with `apply_patch`, keep it outside the repository commit, then verify that exact path with `test -r` and `wc -l`.
- **Future rule:** Follow the existing `AGENTS.md` persistent-report instructions, including for repository read-only tasks; do not duplicate them or create another “latest” report.
- **Scope:** ScoreKeep-specific. **Environment:** Both.

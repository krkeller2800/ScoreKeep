# Simple Team Production Routing Baseline

<!-- MARK: 1. Authorization And Scope -->
## 1. Authorization And Scope

This baseline covers the first bounded production persistence route: simple manual team creation through the canonical team-creation transaction adapter. The simple Team request now includes the Team display fields and optional Team logo data. No scoring, player, game, lineup, pitcher, at-bat, substitution, import-file reconciliation, purchase, allowance, report, generated-output, deletion, or retirement route is authorized here.

<!-- MARK: 2. Prior Physical Migration Proof -->
## 2. Prior Physical Migration Proof

The prior physical-iPhone disposable migration proof remains the prerequisite evidence for this work. It proved source-store preservation, backup verification, durable journal completion, Proposed V2 open, fresh-context comparison, force-quit survival, completion reauthorization blocking, and preservation of the difficult third-out runner evidence as ambiguous.

<!-- MARK: 3. Production Startup Transition -->
## 3. Production Startup Transition

ScoreKeep now enters through `ScoreKeepProductionStartupHost`. Production activation is enabled after the successful disposable physical-iPhone rehearsal. Normal production starts through the fail-closed migration orchestrator: it opens a completed Proposed target when completion evidence already exists, runs the authorized startup migration when no completed journal exists, and blocks startup instead of falling back if preservation, migration, open, or verification cannot be proven.

<!-- MARK: 4. Single Container Authority -->
## 4. Single Container Authority

The startup host exposes one ModelContainer to the normal app interface. The disposable Proposed rehearsal path opens the completed Proposed target from the migration journal. The production path opens the Proposed V2 target only after completed journal evidence or successful fail-closed startup migration verification, preserving one active container authority.

<!-- MARK: 5. Route Approval -->
## 5. Route Approval

Route approval is local and deterministic. `simpleTeamCreationProductionEnabled` is true for the first authorized production route: simple manual Team creation through the canonical Proposed route. The disposable rehearsal path remains separately enabled for the migration-test bundle only.

<!-- MARK: 6. TeamView Integration -->
## 6. TeamView Integration

Team creation now starts from `AddTeamDraftView`, opened by Team list, game/score toolbar, edit-game, and paste-lineup entry points. The draft holds name, coach, details, and optional logo data as value state until Save creates a `SimpleTeamCreationSubmission`. Add Team presents Back on the leading side and Save on the trailing side; untouched Back exits immediately, while dirty Back requires Discard New Team or Keep Editing confirmation and performs no SwiftData insert. Standard Team list/game-list Add routes replace the Add destination with normal `EditTeamView` after Save so Players become available only after the Team exists.

<!-- MARK: 7. One Writer Enforcement -->
## 7. One Writer Enforcement

Converted UI entry points perform no Team insertion and no ModelContext save before the user presses Save. The route service and adapter own persistence for successful creation; the old blank-placeholder helpers are no longer reachable from Team list, ContentView, ScoreContentView, EditGameView, or PasteView.

<!-- MARK: 8. Operation Identity Lifecycle -->
## 8. Operation Identity Lifecycle

AddTeamDraftView creates one operation identity and one team identity for the current value submission. Repeated taps are disabled while submission is active. A retry with unchanged values reuses the same pending identity. Editing values before a later attempt creates a new intended submission identity.

<!-- MARK: 9. Context Ownership -->
## 9. Context Ownership

The route service creates a coordinator backed by `TeamCreationSwiftDataEvidenceStore`. The executor invokes `CanonicalTeamCreationTransactionAdapter.applyUsingDedicatedOperationContext`, which creates the operation ModelContext internally.

<!-- MARK: 10. Autosave Exclusion -->
## 10. Autosave Exclusion

The adapter disables autosave on the dedicated operation context and on its fresh reload context. AddTeamDraftView does not depend on autosave for creation.

<!-- MARK: 11. Save And Rollback -->
## 11. Save And Rollback

The adapter continues to provide one explicit baseball save, rollback for pre-commit save failure, no false rollback after commit, and fresh-context verification before success is returned.

<!-- MARK: 12. Split Outcomes -->
## 12. Split Outcomes

The app service maps created, already-completed, validation failure, conflict, route-disabled, migration-required, persistence-unavailable, failed-before-commit, evidence-reconciliation-required, and ambiguity outcomes to value-only UI behavior.

<!-- MARK: 13. Durable Evidence -->
## 13. Durable Evidence

The Proposed route records operation evidence in Proposed V2 using scalar operation metadata. The UI receives no managed Team from the adapter and no operation identity is shown to the user.

<!-- MARK: 14. Reconciliation -->
## 14. Reconciliation

Repeat submissions use the coordinator and evidence store to reconcile prior completion without inserting a duplicate Team. Conflicting operation or team identity reuse fails closed.

<!-- MARK: 15. UI Behavior -->
## 15. UI Behavior

AddTeamDraftView closes after untouched Back dismissal or explicit Discard New Team confirmation. On verified success or an already-completed result, standard Team Add routes transition to `EditTeamView` for the created Team; caller-specific sheet routes such as Edit Game and Paste still receive the created Team and dismiss for assignment/selection. Edit Game re-fetches the created Team by stable identity in its own context and saves the game assignment before continuing. Failures and Keep Editing preserve entered text and selected/pasted logo data. Empty-name and duplicate-name validation use the shared draft validation before submission.

<!-- MARK: 16. Compatibility -->
## 16. Compatibility

Team editing, team deletion, imports, sample fixtures, and migration reconstruction are not routed by this change. The compatible legacy creation branch remains in source for pre-mutation disable and later retirement review.

<!-- MARK: 17. Disposable Physical iPhone Rehearsal -->
## 17. Disposable Physical iPhone Rehearsal

The disposable Proposed app opened the normal ScoreKeep interface from the completed migration journal. One temporary Team was created, appeared exactly once, survived force-quit and relaunch, and remained present exactly once. The Copy Summary action now returns the current simple-team routing summary instead of the old migration checkpoint summary.

The final physical-iPhone rehearsal checkpoint passed with: disposable bundle confirmed, completed migration journal recognized, Simple-Team Route proposed, dedicated operation context used, autosave disabled, exactly one baseball save, fresh-context verification passed, durable evidence recorded, TeamView second save absent, exactly one routed temporary Team persisted, routed Team present exactly once after relaunch, other workflows remaining Legacy behavior, production data not accessed, Post-Migration Baseline `authorizedAdditiveChangeMatches`, and Stored Legacy Baseline `completeOrReviewAmbiguity`.

The authorized-additive comparison proved that the original migrated baseball data remained intact and that the only approved additions were exactly one routed Team and exactly one completed operation-evidence record.

<!-- MARK: 18. Production Activation Gate -->
## 18. Production Activation Gate

Activation source changes are prepared. Production startup migration is enabled through the fail-closed orchestrator, simple manual Team creation is routed to Proposed V2, and all other workflows retain Legacy-compatible behavior. The final Team-standardization focused tests, build, and manual iPhone/iPad workflow gates are green. Commit and push remain a separate operator action.

<!-- MARK: 19. Focused Tests -->
## 19. Focused Tests

Pre-implementation focused baselines passed: team-creation selected suites passed 68 tests, persistence-authority selected suites passed 46 tests, and startup/migration selected suites passed 32 tests. After implementation, the new simple-team routing and adjacent focused suites passed 54 tests. The routing-summary repair added focused coverage proving that the current routing summary and immutable migration baseline are separate data sources. The authorized-additive comparison repair adds focused coverage for exact post-migration baseline match, one authorized additive Team plus evidence, duplicate Team rejection, changed original Team rejection, changed game/lineup/at-bat/pitcher rejection, and unexpected relationship, score, substitution, media, or evidence rejection. The final Team-standardization focused Xcode run passed 39 tests, 0 failed, 0 skipped, including Add/Edit draft lifecycle, logo persistence, Edit Game persistence/availability, Paste handoff, and source-route assertions.

After activation, Codex desktop compiled the full app and test bundle with `build-for-testing` successfully, without running simulator tests. Focused test execution stayed in the manual Xcode gate because CoreSimulator access is unavailable in the Codex desktop environment. The final manual Xcode Physical migration test preparation suite passed 19 tests, 0 failed, 0 skipped.

<!-- MARK: 20. Full Regression -->
## 20. Full Regression

Pre-implementation full normal regression passed: 550 tests, zero failures. After the routing-summary repair, the manual Xcode full normal test plan on the normal ScoreKeep scheme and established iPad simulator passed 556 tests, 0 failed, 0 skipped. The final fresh full normal Xcode simulator regression gate on the normal ScoreKeep scheme and established iPad simulator passed 562 tests, 0 failed, 0 skipped.

<!-- MARK: 21. Production Build -->
## 21. Production Build

Pre-implementation normal Debug production build passed. A post-implementation Debug build also passed before the manual rehearsal stop. After the authorized-additive comparison repair, the disposable Proposed configuration build passed. After production activation, the normal Debug production build passed and the disposable Proposed configuration build passed again. The final Team-standardization Xcode project build passed.

<!-- MARK: 22. Active Route Status -->
## 22. Active Route Status

Production simple-team routing is active for simple manual Team creation only. Disposable Proposed normal-UI rehearsal remains enabled for the migration-test bundle when completed migration evidence is already present.

<!-- MARK: 23. Operations Remaining Legacy -->
## 23. Operations Remaining Legacy

Game creation and editing, team deletion, player workflows, lineups, pitchers, at-bats, substitutions, scoring, imports, player media, reports, generated output, purchases, and allowances retain their current legacy behavior. Existing Team editing now uses the shared Team form and explicit unsaved-changes confirmation instead of disappearance-driven cleanup.

<!-- MARK: 24. Task 3.20 Prohibition -->
## 24. Task 3.20 Prohibition

Task 3.20 remains not started. No legacy persistence code, compatibility type, backup, journal, rollback path, disable path, or legacy TeamView branch was deleted.

<!-- MARK: 25. Task 2.19 Prohibition -->
## 25. Task 2.19 Prohibition

Task 2.19 remains not started. No production scoring command, event, replay, or scoring-engine persistence route was added.

<!-- MARK: 26. Rollback And Disable Capability -->
## 26. Rollback And Disable Capability

The local production activation constant remains the pre-mutation disable path. Disabling it before a Proposed operation starts returns normal production startup to the Legacy-compatible route without rewriting or deleting existing data. The legacy compatible creation branch remains available before a Proposed operation starts.

<!-- MARK: 27. Final Verdict -->
## 27. Final Verdict

Activation complete for this task. The disposable normal-UI routing behavior passed on physical iPhone, the Copy Summary action targets the current simple-team routing summary, and the migration comparison accepts exact post-migration matches and the authorized additive routed-Team/evidence state while preserving `mismatchRequiresReview` for unexplained differences. Production activation source is enabled for the first authorized simple-Team route. Team-standardization manual verification passed for iPhone Add/Edit Team, logo controls, Add Team to Players, Edit Game Add Team on iPhone and iPad, and Paste Create Team. Final focused and full manual Xcode gates are green, with Task 3.20 and Task 2.19 still not started.

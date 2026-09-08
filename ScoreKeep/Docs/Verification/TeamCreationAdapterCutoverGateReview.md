# Team Creation Adapter Cutover-Gate Review

<!-- MARK: - 1. Review Scope -->
## 1. Review Scope

This review evaluates the isolated simple team-creation transaction adapter for later bounded production-routing preparation. It does not route the adapter, change the legacy team-creation workflow, add a feature flag, add shadow or fallback writes, introduce production migration, change schema, begin task 3.20, or begin task 2.19.

Preflight evidence: repository root `/Volumes/XcodeSSD/Users/karldev/Documents/ScoreKeep`; branch `scorekeep-next`; local HEAD `31f593bb41054e0067351ed4ee1e54ee24a5102a`; direct GitHub `scorekeep-next` head `31f593bb41054e0067351ed4ee1e54ee24a5102a`; local `origin/scorekeep-next` `06f6ff17e733846ae1e800c78a2a83674e89b141`; branch status ahead of stale local tracking by 3; working tree clean before edits. Direct GitHub head equaled local HEAD, so the stale tracking ref was not treated as a blocker.

Baseline verification before edits discovered 391 tests, 391 enabled, 0 disabled. The complete test plan passed: 391 passed, 0 failed, 0 skipped, 0 expected failures, 0 not run. The active production build passed.

<!-- MARK: - 2. Governing Evidence -->
## 2. Governing Evidence

Reviewed evidence includes Documents 20, 21, 23, 25, 27, 28, and 29; `PersistenceBoundaryAndMappingBaseline.md`; `SaveRoundTripRelationshipOrderingBaseline.md`; `MediaDeletionRepairBaseline.md`; `MigrationSourcesFixturesAndEmptyStoreBaseline.md`; `ExistingStoreMigrationRecoveryBaseline.md`; `PersistenceCutoverPreparationBaseline.md`; `TeamCreationTransactionAdapterBaseline.md`; `CanonicalTeamCreationTransaction.swift`; `CanonicalPersistenceCutoverPreparation.swift`; `CanonicalPersistenceTransactionResult.swift`; `CanonicalPersistenceMapping.swift`; `CanonicalTeamCreationTransactionTests.swift`; `Team.swift`; production team creation views; startup `ScoreKeepApp`; current purchase and allowance code references.

Repository evidence establishes that production baseball persistence remains legacy SwiftData through SwiftUI environment contexts and `ImportService`, while purchase and allowance state remain outside baseball persistence. Test evidence establishes only isolated disposable-store behavior unless explicitly stated otherwise.

<!-- MARK: - 3. Current Production Workflow -->
## 3. Current Production Workflow

The current ordinary reusable-team creation path is `AddTeamDraftView`: it collects name, coach, details, and optional logo data in value state, validates non-empty and duplicate names, and creates a `SimpleTeamCreationSubmission` only when the user presses Save. Add Team presents Back and Save, hides the system Back control, lets untouched Back exit immediately, and requires Discard New Team or Keep Editing confirmation for dirty Back. None of those dismissal paths insert SwiftData records.

Production team creation entry points in `ContentView`, `TeamContentView`, `EditGameView`, and `PasteView` now open the same draft route instead of inserting `Team(name: "", coach: "", details: "")` before navigation or selection. Standard Team list Add routes transition from Add draft to normal `EditTeamView` after Save so Players become available only after the Team exists. `EditGameView` presents the draft in a sheet so the current game remains alive, re-fetches the created Team by stable identity in its own context, and selects the created Team for the originating New Game home or visiting role when launched from a team selector. `PasteView` selects the created team after success without resetting pasted/import setup state. `ScoreContentView` no longer exposes a separate general Add Team toolbar route.

`EditTeamView` edits a bound `Team` through the same `TeamFormContent`, can mutate `name`, `coach`, `details`, and `logo`, checks duplicate names excluding the current team, and presents Save Changes, Discard Changes, or Keep Editing before leaving with dirty edits. Player addition from the team edit view inserts `Player` records. Team deletion can delete related players and save. Roster and delete behaviors remain outside the bounded adapter review.

<!-- MARK: - 4. Adapter Boundary -->
## 4. Adapter Boundary

The adapter accepts an immutable request with operation identity, team identity, name, coach, details, duplicate policy, source classification, known invocation fingerprints, unsupported evidence field names, purchase and allowance probes, and gate state. It rejects missing identity, blank name, dirty transaction context, unsupported evidence, unsupported source, conflicting operation identity, failed gate state, and purchase or allowance probe changes before insertion.

On the supported isolated success path, it performs one `Team` insert, one explicit save, creates a fresh reload context from the same container, fetches by team identity, requires exactly one matching team, verifies fields, verifies optional logo data and empty relationships, interprets persisted evidence through canonical mapping, and returns a shallow deterministic transaction result. The adapter remains non-routed and always reports `routingRemainsDisabled`.

<!-- MARK: - 5. Production Call-Site Comparison -->
## 5. Production Call-Site Comparison

Compatible boundary: `AddTeamDraftView` collects the supported creation fields: name, coach, details, and optional logo data. The current `Team` initializer can represent stable identity, display fields, empty players, empty games, and optional logo data, and the draft route hands a stable team identity to the submission before persistence.

Remaining mismatches: production duplicate detection is still name-based before submission while the adapter's duplicate handling is identity-based; production still has no durable retry evidence beyond the routed service lifetime; roster, game relationships, import reconciliation, and deletion remain outside adapter scope.

Routing must not broaden the adapter to cover blank edit helpers, imports, seeds, media, roster, deletion, player, game, scoring, correction, report, export, purchase, or allowance routes.

<!-- MARK: - 6. Gate-By-Gate Findings -->
## 6. Gate-By-Gate Findings

Adapter correctness: Satisfied for isolated testing only. Repository evidence: `CanonicalTeamCreationTransaction.swift` validates, inserts once, saves once, reloads, verifies, classifies duplicates, classifies save/reload/semantic failures, and keeps routing disabled. Test evidence: 23 isolated adapter tests cover validation, dirty context, exactly-one insert, save failure, rollback, reload, duplicate, uncertainty, purchase probes, and non-routing. Missing evidence: production source support, durable operation evidence, production route acceptance. Blocking consequence: isolated correctness does not permit routing. Required next action: keep non-routed and add production policy before routing.

Production call-site compatibility: Satisfied for ordinary team creation. Repository evidence: `AddTeamDraftView` maps name, coach, details, and optional logo data into `SimpleTeamCreationSubmission`; converted entry points open that draft route without first inserting blank teams. Test evidence: focused draft-flow and source-routing tests verify no blank placeholder insert remains in the converted routes. Remaining out-of-scope evidence: roster, deletion, and import-file reconciliation.

Dedicated context: Partially satisfied. Repository evidence: production views obtain shared environment context from `.modelContainer(for: Game.self)`; isolated adapter can receive a separate context. Test evidence: isolated tests use clean disposable contexts. Missing evidence: production factory for a clean transaction context, actor policy, result handoff without live model reuse. Blocking consequence: shared context routing is unsafe. Required next action: design dedicated context creation without wiring it in this run.

Context cleanliness: Satisfied for isolated testing only. Repository evidence: adapter rejects `context.hasChanges` before insertion. Test evidence: dirty-context test proves rejection and no rollback of incoming changes. Missing evidence: production guarantee that no unrelated view edits share the same context, autosave behavior under routing, concurrent shared-context mutation policy. Blocking consequence: future route must create a fresh context per transaction. Required next action: keep dirty-context rejection and require a clean transaction boundary.

One writer: Satisfied for ordinary team creation surfaces converted in this phase. Repository evidence: `AddTeamDraftView` is the shared creation form and the converted views no longer call blank `Team` insert helpers before navigation or selection. Test evidence: focused tests assert the shared draft route and absence of the removed placeholder writes. Remaining legacy writers include out-of-scope import-file reconciliation and team deletion/editing behavior.

Duplicate and concurrency safety: Not satisfied. Repository evidence: adapter duplicate lookup is sequential and field-based after stable identity lookup; no production serialization, uniqueness constraint, or durable operation store exists. Test evidence: isolated sequential duplicate tests pass. Missing evidence: simultaneous submissions from one or more contexts, repeated taps, cancellation, app suspension. Blocking consequence: two near-simultaneous requests could both pass lookup before save proof. Required next action: add serialization, UI submit disabling, durable identity policy, or store-level uniqueness before routing.

Durable or otherwise proven idempotency: Not satisfied. Repository evidence: operation identity is request data and known fingerprints are externally supplied; no durable operation identity exists in production. Test evidence: exact repeat and conflicting repeat are simulated within isolated test state. Missing evidence: cross-launch identity, retry after termination, recovery after uncertain completion. Blocking consequence: uncertain completion could duplicate after restart. Required next action: design durable operation evidence or a proven equivalent cross-launch policy.

Schema readiness: Partially satisfied. Repository evidence: current `Team` stores identity, name, coach, details, players, games, and external logo; accepted simple fields fit the current record. Missing evidence: persisted operation identity, schema-version policy, formal no-schema-change decision. Blocking consequence: record fields alone are ready, but operation-level idempotency is not. Required next action: decide no-schema-change routing for team record fields and separately resolve operation evidence storage.

Source-version and migration-state readiness: Not satisfied. Repository evidence: startup opens the current unversioned SwiftData store; baselines say production lacks source-version policy, migration progress storage, startup decision policy, and unsupported-future handling. Test evidence: migration verification is isolated and fixture-backed only. Missing evidence: production write gate proving store current, migration complete, not future unsupported, not uncertain recovery. Blocking consequence: write routing cannot trust store state. Required next action: add source-version and migration-state policy before routing.

Save completion proof: Partially satisfied. Repository evidence: adapter reloads from a fresh context and verifies exactly one matching team by stable team identity and supported fields. Missing evidence: operation-level proof that this invocation created the record, prior matching record distinction, production UI waiting for reload. Blocking consequence: team-level existence is not operation-level completion proof. Required next action: keep success behind reload proof and add operation evidence before uncertain retry.

Disable path: Not satisfied. Repository evidence: no feature flag, route selector, remote config, or local persisted disable exists. The safest supported later option is a centralized compile-time route choice for the bounded simple route. It would prevent new adapter writes by compiling the route to legacy or adapter, cannot change after release, does not affect completed transactions, and avoids automatic fallback after adapter failure. Missing evidence: implemented selector and diagnostics. Blocking consequence: no immediate disable mechanism exists. Required next action: define compile-time centralized route choice in a later routing-preparation task.

Rollback and recovery: Partially satisfied. Repository evidence: created simple teams are readable by legacy code because fields use current `Team`; no schema rollback is needed for those records. Adapter rollback is isolated for save failure before proof. Missing evidence: production route rollback, uncertain completion recovery, disable recovery, user review of conflicting evidence. Blocking consequence: routing cannot define support behavior after uncertainty. Required next action: define recovery by identity lookup and route rollback as code-route rollback, not automatic deletion.

User-review policy: Not satisfied. Repository evidence: adapter classifies existing matching team, conflicting team, duplicate operation, reload failure, uncertainty, save failure, unsupported fields, and gate failures; production UI has no mapping for these outcomes. Missing evidence: which outcomes close the form, leave it open, show retry, block retry, or require review. Blocking consequence: users could receive false success or unsafe retry choices. Required next action: design outcome-to-UI policy without routing.

Purchase and allowance separation: Satisfied. Repository evidence: simple team creation has no entitlement requirement and no allowance consumption; purchase and allowance routes are separate; game-creation allowance is coupled to game creation, not team creation. Adapter evidence uses probes and does not access purchase or secure allowance stores. Test evidence: isolated purchase/allowance probe tests pass. Missing evidence: none blocking for simple team route. Required next action: keep team creation separate from game-creation and MLB-download allowances.

Diagnostic sufficiency: Partially satisfied. Repository evidence: adapter result types carry operation identity, team identity, validation findings, save result, rollback result, reload result, semantic verification result, idempotency result, affected identities, retry safety, review need, and separation findings. Missing evidence: production writer identity, disable state, durable operation identity, route-level recovery, privacy-preserving local diagnostics. Blocking consequence: routed failures would be hard to diagnose. Required next action: define local diagnostics before routing without logging media bytes, purchase evidence, secure counter values, or raw store content.

Test adequacy: Partially satisfied. Test evidence: 23 adapter tests cover isolated validation, dirty context, save failure, rollback, reload, exactly-one verification, exact repeat, conflicting repeat, unrelated records, purchase and allowances, non-routing, and deterministic results. Missing or unable to prove production behavior: concurrent invocation, cross-launch retry, shared production context, autosave interaction, operation identity durability, disable behavior, production user review, rollback after routing. Blocking consequence: isolated tests cannot justify routing. Required next action: add policy-backed routing-preparation tests after the missing implementation decisions exist.

<!-- MARK: - 7. Dedicated-Context Assessment -->
## 7. Dedicated-Context Assessment

A future route can probably create a dedicated transaction context from the same container, but the production app currently exposes only shared environment context values to views. There is no reviewed production boundary for creating one clean context per team submission, awaiting completion, and then communicating success by stable identity rather than a live `Team` model.

The gate is not satisfied by isolated tests. Production must avoid returning inserted objects from one context into navigation that expects objects from another context. The likely result handoff is stable team identity plus a list refresh or fetch in the view-owned context after transaction completion.

<!-- MARK: - 8. Context-Cleanliness Assessment -->
## 8. Context-Cleanliness Assessment

Rejecting every context with changes is correct but sufficient only when the future caller always supplies a newly created transaction boundary. The adapter cannot distinguish its own pending changes from unrelated pending changes before insertion because it intentionally rejects any incoming dirty state. The check, insert, save, and rollback are main-actor isolated in the adapter, but that does not serialize separate contexts against the same store.

Autosave and implicit view-bound mutations remain production concerns. A future route should use a clean context for every transaction and should avoid rollback on a shared context because rollback could discard unrelated registered changes.

<!-- MARK: - 9. One-Writer Routing Seam -->
## 9. One-Writer Routing Seam

The bounded routing seam for ordinary creation is now `AddTeamDraftView.saveTeam`. The draft route builds `SimpleTeamCreationSubmission` from value state, including optional selected or pasted logo data, and lets the adapter result control whether the form closes, whether success is handed back to the caller, and whether entered values remain visible after failure.

No fallback legacy write follows adapter failure in the converted ordinary creation surfaces. Repeated actions reuse the pending operation identity while values are unchanged. `ContentView`, `TeamContentView`, `EditGameView`, and `PasteView` open the shared draft route instead of creating blank placeholder teams; `ScoreContentView` keeps game-list routing and no longer owns a general Add Team route.

<!-- MARK: - 10. Durable-Idempotency Assessment -->
## 10. Durable-Idempotency Assessment

Current idempotency is transaction-lifetime or test-supplied in-memory idempotency only. Production has no durable operation identity across repeated taps, view recreation, navigation changes, suspension, termination, save uncertainty, retry after relaunch, duplicate team identity, or conflicting request reuse.

Stable team identity helps detect an existing team after relaunch if the same identity is known, but production does not currently create or preserve that identity before write. Name matching is not durable idempotency. Routing remains blocked because uncertain completion could lead to duplicate creation after restart.

<!-- MARK: - 11. Schema And Migration Assessment -->
## 11. Schema And Migration Assessment

Team-record schema readiness is partially satisfied: the adapter writes only fields present on the current `Team` model. The current schema can represent a simple created team and the legacy code can read it.

Durable operation-idempotency schema readiness is not satisfied: no operation identity, completion marker, or transaction evidence is persisted. General production migration readiness is not satisfied: the app lacks formal source-version, migration-progress, startup write, unsupported-future, and uncertain-recovery policies. No VersionedSchema or SchemaMigrationPlan was added.

<!-- MARK: - 12. Save-Completion Assessment -->
## 12. Save-Completion Assessment

Fresh reload and exactly-one semantic verification prove team-level existence for one stable team identity. They do not prove operation-level authorship when a prior matching team already exists or when an uncertain invocation is retried without durable operation evidence.

Production success must wait until reload proof is complete. Reload failure after save must remain review-required. Save and reload must use the same container and store. The additional reload is acceptable for a bounded simple team route only after UI policy is defined.

<!-- MARK: - 13. Disable Assessment -->
## 13. Disable Assessment

The smallest later disable mechanism supported by the current project is a centralized compile-time route choice for only the bounded named-team route. It prevents new adapter writes by excluding the adapter route from the compiled production path. It cannot be changed after release, does not affect already-completed transactions, and can restore legacy writing in a later release only if the route selector is exclusive.

A remote or local persisted feature state would require additional infrastructure and diagnostics not present today. Automatic fallback after adapter failure is not recommended because it creates dual-writer risk and can duplicate uncertain transactions.

<!-- MARK: - 14. Rollback And Recovery Assessment -->
## 14. Rollback And Recovery Assessment

For this route, rollback primarily means code-route rollback or disable, not deleting created teams. Successfully created simple teams are readable by legacy code. If no schema change is made, reverting to the legacy writer in a later release is feasible from a record-shape perspective.

Uncertain completion should be resolved by identity lookup and, when operation evidence is added, operation lookup. A created team should not be automatically deleted. Conflicting existing evidence requires review. Save failure before proof can be retried only when rollback completion is proven.

<!-- MARK: - 15. User-Review Assessment -->
## 15. User-Review Assessment

A future user-facing route must define outcomes for existing matching team, existing conflicting team, duplicate team identity, duplicate operation identity, conflicting operation reuse, reload failure, completion uncertainty, save failure, schema or migration gate failure, unsupported requested field, and disabled adapter.

Only proven success or already-applied matching evidence should close the creation workflow. Save failure with completed rollback may leave the form open with retry. Conflicts, unsupported fields, migration/schema failures, reload failure, and uncertain completion require review or blocked retry. Returning to legacy behavior should happen only in a later explicitly authorized release, not as an automatic fallback.

<!-- MARK: - 16. Purchase And Allowance Assessment -->
## 16. Purchase And Allowance Assessment

Simple team creation is not an allowance-consuming action, does not require entitlement, does not access purchase services, does not access secure counters, does not alter free-game allowance, does not alter MLB download allowance, and does not become coupled to game-creation allowance merely because teams are used by games.

Production team creation has no hidden purchase or allowance side effect in the inspected routes. Routing must preserve this separation.

<!-- MARK: - 17. Concurrency Assessment -->
## 17. Concurrency Assessment

Two near-simultaneous production submissions could use separate contexts, both pass duplicate lookup, both insert the same stable team identity if supplied, and both attempt save. There is no store-level uniqueness guarantee or transaction actor in the current evidence.

Protection likely requires a combination of main-actor UI submission disabling, a transaction actor or equivalent serialization for the route, durable operation identity, stable team identity generated before submission, and post-save duplicate reconciliation. Sequential isolated tests do not prove duplicate safety.

<!-- MARK: - 18. Diagnostic Assessment -->
## 18. Diagnostic Assessment

After bounded routing, diagnostics must identify which writer executed, operation identity, team identity, validation disposition, save attempt, save result, reload result, duplicate classification, completion uncertainty, disable state, and recovery requirement.

Current result types provide useful local diagnostic evidence but not production route evidence. Diagnostics must preserve privacy by avoiding team details where unnecessary, media bytes, purchase evidence, secure counter evidence, full user data, and raw store content. No production logging or telemetry was added.

<!-- MARK: - 19. Test-Adequacy Assessment -->
## 19. Test-Adequacy Assessment

The 23 adapter tests directly cover dirty context, save failure, rollback, reload failure, exactly-one verification, exact repeat, conflicting repeat, unrelated records, purchase and allowance probes, and production non-routing. They indirectly cover shallow deterministic result values and unchanged records.

Simulated-only coverage includes duplicate lookup failure, completion uncertainty, rollback uncertainty, semantic verification failure, purchase separation failure, and allowance boundary failure. Missing or unable-to-prove coverage includes concurrent production invocation, cross-launch retry, shared production context, autosave interaction, operation identity durability, disable behavior, user review, and rollback after routing.

Focused review tests were added to verify mandatory gate coverage, unresolved status blocking, isolated-only blocking, unsafe blocking, unknown blocking, non-mandatory identification, out-of-scope routes, legacy writer retention, adapter non-routing, deterministic evaluation, unchanged review inputs, pure review dependency boundaries, and final verdict/document consistency.

<!-- MARK: - 20. Staged-Gate Results -->
## 20. Staged-Gate Results

Stage A passed for review: production team-creation call paths and writes were documented.

Stage B passed for review with blockers: adapter and call-site comparison found a narrow compatible named-team subset and several incompatible adjacent workflows.

Stage C passed for review with blockers: dedicated context, schema, source version, migration state, and save proof were assessed as not ready for routing.

Stage D passed for review with blockers: one-writer seam was identified; durable idempotency, concurrency, disable, rollback, and recovery remain unresolved.

Stage E passed for review with blockers: user outcomes and diagnostics are not production-ready; purchase and allowance separation is satisfied.

Stage F passed for review with blockers: isolated tests are adequate for adapter evidence but inadequate for production routing proof.

Stage G passed for review: exactly one verdict and ordered blockers are recorded, and routing remains disabled.

<!-- MARK: - 21. Overall Verdict -->
## 21. Overall Verdict

Overall verdict: Blocked pending specific implementation or policy work.

Routing remains disabled. The adapter is not ready for bounded routing preparation because mandatory gates remain partially satisfied, satisfied only for isolated testing, not satisfied, or otherwise unresolved. The review does not classify the adapter as unsafe in its isolated state, but it would be unsafe to route without resolving the blockers below.

<!-- MARK: - 22. Exact Blockers -->
## 22. Exact Blockers

1. Durable operation identity and cross-launch idempotency are missing.
2. Duplicate and concurrency protection for repeated or simultaneous submissions is missing.
3. Source-version and migration-state production write gates are missing.
4. Disable mechanism for the bounded route is missing.
5. User-review and retry policy for adapter outcomes is missing.
6. Dedicated production transaction context creation and result handoff are not designed.
7. Context-cleanliness guarantee is isolated-only.
8. One-writer routing seam is identified but not implemented.
9. Save proof is team-level only, not operation-level.
10. Schema decision is incomplete for durable operation evidence.
11. Rollback and recovery policy is incomplete for uncertain completion and route disable.
12. Production diagnostics are incomplete.
13. Test coverage does not prove shared-context, autosave, cross-launch, concurrent, disable, or routed UI behavior.

<!-- MARK: - 23. Exact Next Implementation -->
## 23. Exact Next Implementation

The exact next implementation should address the highest-priority blockers without routing the adapter: design durable operation identity and retry/recovery policy for simple team creation; design route-level concurrency protection and repeated-submit behavior; define source-version and migration-state write gates; define a centralized compile-time route choice and diagnostics plan; define user-review outcomes for every adapter result.

Only after those policies are reviewed should a separate bounded routing-preparation task add tests for the policy. Actual routing must remain a later separate task.

<!-- MARK: - 24. Authority Introduced And Legacy Authority Retained -->
## 24. Authority Introduced And Legacy Authority Retained

This run introduces only team-creation cutover-gate review authority, deterministic gate-status evaluation, readiness evidence, an ordered blocker list, and focused review tests.

Legacy SwiftData team creation remains active. No production writer, route, model, relationship, schema, container, migration, purchase service, secure counter, allowance, entitlement, UI, accessibility behavior, source record, fixture, import, export, report, media workflow, scoring workflow, or deletion workflow changed. No production store or user data was opened.

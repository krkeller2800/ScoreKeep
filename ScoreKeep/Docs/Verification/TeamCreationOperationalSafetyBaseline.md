# Team Creation Operational Safety Baseline

<!-- MARK: - 1. Operational Blockers Addressed -->
## 1. Operational Blockers Addressed

This baseline adds the non-routed operational-safety foundation required before any future simple team-creation transaction adapter can be considered for bounded production routing. It addresses stable operation identity vocabulary, deterministic request fingerprints, operation evidence phases, an evidence-store protocol, a production-compatible serialization actor, source-version and migration-state write gates, centralized route-choice diagnostics, disable-policy classification, deterministic workflow outcomes, retry classifications, and operation-level completion-proof levels.

No production workflow is routed. TeamView, TeamContentView, ContentView, production insert/save calls, SwiftData models, relationships, schema, ModelContainer setup, StoreKit, Keychain, allowance counters, entitlement logic, UI, accessibility behavior, fixtures, imports, exports, reports, PDFs, source records, and production user data remain unchanged.

<!-- MARK: - 2. Operation Identity Lifecycle -->
## 2. Operation Identity Lifecycle

The foundation defines a stable `CanonicalTeamCreationOperationIdentity` supplied before transaction execution. It is distinct from team identity, model persistent identity, team name, view identity, array position, timestamps, and random identity generated inside transaction processing.

A future routed form must create one operation identity when a new creation intent begins, preserve it through repeated taps while the form remains active, preserve it through transaction uncertainty, reuse it for a deliberate retry of the same intent, replace it only when the user intentionally begins a different creation intent, and never silently regenerate it after an uncertain result.

<!-- MARK: - 3. Request Fingerprint -->
## 3. Request Fingerprint

`CanonicalTeamCreationSemanticRequestFingerprint` is deterministic semantic evidence derived from team identity, trimmed lowercased supported team name, coach, details, source classification, and explicitly supplied sorted options. It deliberately excludes operation identity and uses length-prefixed field encoding rather than Swift runtime hash values.

Focused tests prove that matching semantic requests produce the same fingerprint, changed meaning produces a different fingerprint, dictionary iteration order does not affect the fingerprint, repeated calculation is deterministic, locale/current date are not inputs, and the original request remains unchanged.

<!-- MARK: - 4. Evidence Phases -->
## 4. Evidence Phases

The operation-evidence vocabulary covers prepared, in progress, save attempted, save outcome uncertain, persisted team verified, completed, rejected, conflicting, failed safely, failed with uncertain completion, review required, disabled, and superseded by explicit policy.

Each evidence record may carry operation identity, team identity, semantic request fingerprint, phase, completion-proof classification, final disposition, retry classification, review requirement, and stable diagnostic codes. It does not carry ModelContext, ModelContainer, live Team instances, closures, raw errors, StoreKit or Keychain evidence, full store snapshots, or user-interface text.

<!-- MARK: - 5. Evidence-Store Boundary -->
## 5. Evidence-Store Boundary

`CanonicalTeamCreationOperationEvidenceStore` defines the production-compatible boundary for looking up evidence by operation identity, looking up relevant evidence by team identity, beginning an operation, advancing phases, marking completion proven, marking completion uncertain, marking safe failure, detecting conflicting reuse, and preserving evidence for reconciliation.

This run does not choose or implement production storage. The test-only implementation persists JSON in an isolated temporary test-owned file and proves protocol semantics across new coordinator instances, new support instances, simulated relaunch, repeated invocation, and conflicting invocation. This proves required semantics but does not resolve the production schema or storage decision.

<!-- MARK: - 6. Serialization Policy -->
## 6. Serialization Policy

`CanonicalTeamCreationCoordinator` is an actor responsible only for serializing team-creation intents. It accepts an immutable request, checks supplied write-readiness state, consults operation evidence, serializes by operation identity and team identity, distinguishes matching duplicate requests from conflicting reuse, returns proven prior completion where safe, blocks uncertain prior completion, and invokes only an injected transaction executor when processing is permitted.

The coordinator has no SwiftData dependency, no global singleton, no production caller, and no embedded writer. The existing transaction adapter remains usable as an injected executor in isolated tests.

<!-- MARK: - 7. Concurrent-Request Behavior -->
## 7. Concurrent-Request Behavior

Focused tests prove that two simultaneous matching requests with the same operation identity execute the injected transaction at most once, conflicting simultaneous requests with the same operation identity do not both execute, two operation identities targeting the same team identity with matching meaning execute at most once, and same-team conflicting meaning is rejected without duplicate accepted creation.

Tests also cover repeated request while the first is in progress, repeat after completion, repeat after safe failure, repeat after uncertain completion, no duplicate accepted result, and deterministic outcomes.

<!-- MARK: - 8. Cross-Instance and Simulated-Relaunch Behavior -->
## 8. Cross-Instance and Simulated-Relaunch Behavior

The isolated evidence store reloads evidence from a test-owned file. Focused tests prove operation evidence survives evidence-store recreation, coordinator recreation, and simulated relaunch.

A repeated request after preserved completion returns a proven duplicate without executor invocation. A repeated request after preserved uncertain completion blocks blind retry and does not invoke the executor.

<!-- MARK: - 9. Source-Version and Migration-State Gates -->
## 9. Source-Version and Migration-State Gates

`CanonicalTeamCreationWriteReadinessSnapshot` represents store-open success, source-version classification, migration state, read-only access, write prohibition, cutover approval, and disable state. It can represent supported current source, unknown source version, unsupported future version, migration not required, migration complete, migration in progress, migration interrupted, migration failed, migration completion uncertain, recovery required, read-only only, writes prohibited, cutover approval absent, and disable active.

Coordinator tests prove transaction execution is blocked when the snapshot is not explicitly write-ready. Unknown source version, unsupported future version, migration in progress, interrupted migration, uncertain migration, recovery required, read-only state, absent approval, write prohibition, store-open failure, and adapter disable prevent executor invocation.

<!-- MARK: - 10. Route-Choice Diagnostics -->
## 10. Route-Choice Diagnostics

The centralized route-choice value supports legacy writer active, adapter prepared but disabled, adapter eligible for isolated verification, adapter eligible for bounded routing after explicit authorization, adapter temporarily disabled, and unsafe or blocked.

For the current repository state, `CanonicalTeamCreationRouteChoice.currentNamedTeamCreation` remains legacy writer active. Tests prove the current route remains legacy, the adapter is not production routed, TeamView still contains the legacy insert/save path, and production sources do not reference the coordinator or operational request.

<!-- MARK: - 11. Disable Policy -->
## 11. Disable Policy

The future disable policy requires preventing new adapter transactions, preserving existing operation evidence, allowing reconciliation of previously uncertain operations, never executing both writers, never automatically retrying through legacy, allowing later legacy restoration only through explicit one-writer configuration, and remaining diagnosable.

This run defines the policy only. It does not implement production disable wiring, remote configuration, UserDefaults, AppStorage, a feature flag framework, or automatic fallback.

<!-- MARK: - 12. User Outcomes -->
## 12. User Outcomes

`CanonicalTeamCreationWorkflowOutcome` classifies deterministic future workflow outcomes for created and verified, existing matching team, duplicate request already completed, validation rejected, conflicting existing team, operation already in progress, save failed safely, completion uncertain, store not writable, migration incomplete, adapter disabled, internal verification failure, and review required.

For each outcome, the policy states whether the form may close, whether entered values must remain available, whether retry may be offered, whether retry must reuse the same operation identity, whether a new operation identity is prohibited, whether user review is required, and whether legacy fallback is prohibited. No user-facing wording or UI was added.

<!-- MARK: - 13. Completion Proof Levels -->
## 13. Completion Proof Levels

Completion proof levels distinguish no proof, team existence observed, semantic team match observed, operation evidence and semantic team match observed, completion marker recorded, conflicting evidence, and completion uncertain.

Tests prove that team existence alone, semantic team match alone, and operation evidence plus semantic team match do not prove operation completion. The strongest supported proof requires matching operation identity evidence, matching team identity, matching semantic request fingerprint, exactly one matching persisted team, fresh-context semantic verification, and completion evidence recorded.

<!-- MARK: - 14. Retry Policy -->
## 14. Retry Policy

Retry classifications cover retry permitted using the same operation identity, retry prohibited because completion is uncertain, retry unnecessary because completion is proven, retry blocked by conflict, retry blocked by migration or source state, retry blocked while operation is in progress, review required before retry, and new intent requiring a new operation identity.

Safe failure permits only explicit same-operation retry. Uncertain completion blocks blind retry and prohibits silent replacement of operation identity. No automatic retry was added.

<!-- MARK: - 15. Production Schema Decision Assessment -->
## 15. Production Schema Decision Assessment

The implementation evidence shows durable operation evidence needs a production storage decision before routing. Current Team fields can represent the accepted simple team record, but team identity alone is not sufficient operation evidence because it cannot prove which invocation created the record after uncertainty or relaunch.

Possible storage options remain a new SwiftData model, a field on Team, a separate non-SwiftData journal, another durable storage mechanism, or further decision work. This run does not select an option, does not modify schema, and does not add VersionedSchema or SchemaMigrationPlan. This blocker remains open.

<!-- MARK: - 16. Non-Routing Proof -->
## 16. Non-Routing Proof

No production caller was added. TeamView and all production team-creation routes remain unchanged. The legacy writer remains active. The adapter remains disabled and non-routed. The coordinator has no production caller and no global singleton. No shadow writes, fallback writes, production feature toggles, production evidence store, production migration path, production schema change, or production logging system was added.

Source-inspection tests assert production sources do not reference the coordinator or operational request and that the current route choice remains legacy.

<!-- MARK: - 17. Staged-Gate Results -->
## 17. Staged-Gate Results

Stage A passed: identity, fingerprint, evidence vocabulary, outcome, retry, completion proof, write gate, route choice, and disable policy values were added and tested.

Stage B passed: test-only durable evidence persists across support recreation and simulated relaunch without production storage.

Stage C passed: coordinator serialization was implemented; the simplest matching concurrent-request test passed twice individually.

Stage D passed: conflicting operations, same-team races, safe failure, and uncertain completion behavior were verified.

Stage E passed: source-version and migration-state gates block executor invocation unless explicitly write-ready.

Stage F passed: current route remains legacy and adapter remains disabled.

Stage G passed: production TeamView and team-creation routes remain unchanged, the coordinator has no production caller, no production evidence store was selected, no schema changed, no production store was accessed, and remaining blockers are documented.

<!-- MARK: - 18. Remaining Blockers -->
## 18. Remaining Blockers

Production routing remains blocked by the unresolved durable evidence-storage decision, production source-version authority, production migration-state provider, production disable wiring, production user-outcome UI mapping, production transaction context creation and result handoff, production diagnostics, and routed UI verification.

The operational foundation resolves the prior non-routed policy and coordination gaps in testable form. It does not resolve production evidence persistence, production migration readiness, or production routing authorization.

<!-- MARK: - 19. Exact Next Implementation Recommendation -->
## 19. Exact Next Implementation Recommendation

The exact next implementation should decide the durable operation-evidence storage mechanism for simple team creation without routing the adapter. It should compare a new SwiftData operation model, a Team-attached field, a separate non-SwiftData journal, and any other durable storage candidate against operation-level completion proof, migration impact, disable/reconciliation behavior, privacy, recovery after uncertain completion, and compatibility with current unversioned stores.

Do not route the adapter until durable evidence, concurrency, migration gating, disable policy, user outcomes, dedicated transaction context, and diagnostics are all proven ready in production-compatible form.

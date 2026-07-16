# Production Schema Transition and Startup Readiness Baseline

<!-- MARK: 1. Current Active Startup Boundary -->
## 1. Current Active Startup Boundary

Active production startup remains the legacy unversioned SwiftData route in `ScoreKeepApp` with `.modelContainer(for: Game.self)`. The active production model list remains Game, Team, Player, Atbat, Lineup, and Pitcher as inferred from the current app container. No production startup code references the proposed factory, Proposed V2 schema, V1-to-V2 migration plan, migration evidence authority, or startup readiness values.

This run does not claim production transition occurred. It adds only a non-routed foundation for a later, separate transition run.

<!-- MARK: 2. Proposed Container-Factory Boundary -->
## 2. Proposed Container-Factory Boundary

`ScoreKeepProposedContainerFactory` constructs a Proposed V2 `ModelContainer` only from explicit inputs: injected store location, writability mode, proposed schema selection, migration-plan selection, startup intent, route choice, source classification, and optional test failure injection. It uses `ScoreKeepProposedVersionedSchema.V2` and `ScoreKeepProposedTeamCreationEvidenceMigrationPlan` with an explicitly supplied `ModelConfiguration` URL.

The factory does not infer default production URLs, does not read app environment state, does not access StoreKit, Keychain, UI, logging, allowances, entitlements, imports, exports, reports, media routes, or production startup, and does not report startup success merely because a container initialized. Successful construction remains verification-pending.

<!-- MARK: 3. Factory Inputs And Results -->
## 3. Factory Inputs And Results

Factory inputs include `ScoreKeepStartupStoreLocation`, `ScoreKeepStartupWritabilityMode`, `ScoreKeepProposedSchemaSelection`, `ScoreKeepProposedMigrationPlanSelection`, `ScoreKeepStartupIntent`, `ScoreKeepSourceStoreClassification`, `ScoreKeepSchemaRouteChoice`, and `ScoreKeepProposedContainerFactoryInjection`.

Construction dispositions classify new empty Proposed V2 store, compatible unversioned source transitioned to Proposed V2, existing Proposed V2 store, read-only diagnosis, unavailable source, unknown source version, unsupported future schema, migration in progress, interrupted migration, safe migration failure, uncertain completion, verification pending, verification failure, recovery required, writes prohibited, route-disabled, unsafe, and internal configuration error. Raw framework errors remain internal and user-facing diagnostics are stable classification codes.

<!-- MARK: 4. Store-Location Classifications -->
## 4. Store-Location Classifications

Store locations distinguish production-intended application store, disposable test store, disposable source copy, disposable migration target, read-only diagnostic copy, and unsupported or unknown location. Production-intended location can be represented but is rejected by the factory in this run. Tests supply only disposable URLs.

Fresh disposable destinations can require absence of an existing store family. Non-empty destinations are classified unsafe where freshness is required. Source and target identities remain separate, and generated SQLite, WAL, SHM, or temporary store files are not tracked.

<!-- MARK: 5. Source-Store Classifications -->
## 5. Source-Store Classifications

Source classifications cover absent store, empty current unversioned store, populated current unversioned store, Proposed V1-recognizable store, existing Proposed V2 store, automatically evolved comparison store, converted Proposed V2 store, unknown version, unsupported future version, unreadable store, contradictory metadata, migration evidence exists, missing, uncertain, and read-only diagnosis required.

The implementation does not identify source version from filenames. It relies on explicit repository-supported classification inputs and the proven disposable open behavior. Unknown, unsupported, unreadable, contradictory, uncertain, and read-only-required classifications block write readiness.

<!-- MARK: 6. Migration-State Authority -->
## 6. Migration-State Authority

`ScoreKeepStartupMigrationSnapshot` is an immutable, shallow startup authority. It represents not assessed, no migration required, migration required, preflight in progress, source snapshot verified, source preservation required, migration permitted, construction in progress, container constructed, post-open verification required, post-open verification passed, completion recording required, completed, interrupted, failed safely, completion uncertain, recovery required, disabled, unsupported, read-only, and writes prohibited.

The snapshot carries classifications and optional operation identity only. It never carries live containers, contexts, model objects, raw errors, or store contents.

<!-- MARK: 7. Migration-Operation Identity -->
## 7. Migration-Operation Identity

`ScoreKeepMigrationOperationIdentity` is distinct from team-operation identity, store URL, schema version, current launch, and timestamp alone. It combines stable source-store identity evidence, source schema classification, target schema classification, application migration generation, and an explicit operation UUID generated before migration begins.

The same identity must be reused for reconciliation after interruption or uncertain completion. A replacement identity must not be generated merely because completion is uncertain.

<!-- MARK: 8. Migration-Evidence Boundary -->
## 8. Migration-Evidence Boundary

`ScoreKeepMigrationOperationEvidenceAuthority` defines durable evidence semantics: lookup by operation identity, lookup current evidence by store identity, begin preflight, record source classification, record source preservation, record migration attempt, record construction result, record post-open verification, record completion, record safe failure, record uncertain completion, record recovery requirement, and record disable state.

The test-only `IsolatedStartupMigrationEvidenceSupport` preserves evidence across fresh authority instances, rejects phase regression, rejects conflicting operation reuse, rejects conflicting store identity, and stores no baseball records.

<!-- MARK: 9. Production Evidence-Storage Assessment -->
## 9. Production Evidence-Storage Assessment

The selected assessment is split pre-open and post-open evidence design. Evidence required before the target opens cannot live only inside the unopened target store. Evidence inside the target may help after successful open but cannot prove pre-open progress alone.

UserDefaults or AppStorage are not treated as transactional evidence. Keychain is not selected because migration evidence is not secure small-value entitlement state. A sidecar journal remains plausible but has coordination and atomicity concerns. External backup metadata is not migration-completion proof by itself. Production storage is not implemented in this run.

<!-- MARK: 10. Startup Preflight -->
## 10. Startup Preflight

Pure preflight requires classified store location, expected source family presence or absence, disposable or production-intended path validation, no incompatible concurrent source container, known source-preservation policy, known transition direction, known target schema, known migration plan, known operation identity, reconciled prior evidence, known route disable state, known write authorization, no recovery requirement, no unsupported future version, no contradictory source evidence, and no user-data test boundary violation.

Unsafe preflight states prevent container construction. This run enforces the production-location rejection, route-disabled rejection, unsupported source rejection, and non-empty disposable target rejection needed for the non-routed foundation.

<!-- MARK: 11. Source-Preservation Policy -->
## 11. Source-Preservation Policy

The later active transition must preserve the source store family, including WAL and SHM sidecars where present, after the source container is closed. Destination freshness, copy failure, free-space failure, copy verification, original source immutability, retention until target verification passes, recovery after construction failure, recovery after verification failure, and cleanup only after explicit success policy must be proven before routing.

This run does not add a production backup service or replacement executor. Disposable tests use fresh test-owned stores and reject non-empty destinations where freshness is required.

<!-- MARK: 12. Container Construction And Disposable Results -->
## 12. Container Construction And Disposable Results

Focused tests verified explicit disposable URL construction for a new empty Proposed V2 store, empty unversioned source, minimal unversioned source, representative populated unversioned source, edge-evidence unversioned source, existing Proposed V2 store, repeated Proposed V2 open, read-only existing V2 diagnosis, non-empty destination rejection, unsupported future classification, route-disabled classification, production-intended location rejection, and deterministic injected uncertainty.

Migrated disposable stores preserve stable UUIDs, counts, relationships, lineup membership, ordering, stored scores, substitution evidence, photos, logos, unsupported evidence, and empty team-operation-evidence storage after migration.

<!-- MARK: 13. Post-Open Verification -->
## 13. Post-Open Verification

Post-open verification remains separate from container construction. Focused tests create fresh contexts through the existing disposable snapshot helpers, verify expected model types are queryable, compare baseball record counts, sample stable identities, load relationships and ordering evidence, verify media fingerprints, verify stored scores and substitutions, confirm operation-evidence storage is queryable, confirm no evidence rows are automatically created, and repeat-open existing V2 stores.

No destructive repair is performed.

<!-- MARK: 14. Write-Readiness Gate -->
## 14. Write-Readiness Gate

`ScoreKeepWriteReadinessEvaluator` permits future baseball writes only when source classification is supported, construction succeeded, required migration completed, post-open verification passed, completion evidence reconciled, uncertainty absent, recovery absent, route active, Proposed V2 active for that container, store writable, one-writer policy available, diagnostics identify the authority, and explicit production cutover approval is supplied.

Any uncertainty, recovery requirement, disabled route, unsupported source, read-only store, missing completion evidence, missing verification, missing one-writer policy, or missing production approval blocks writes. Current repository default remains legacy startup active and writes through the new authority prohibited.

<!-- MARK: 15. Startup Outcomes -->
## 15. Startup Outcomes

Startup outcomes classify legacy startup active, proposed startup prepared but disabled, new empty Proposed V2 ready, existing store migrated and verified, existing Proposed V2 verified, read-only recovery mode, source unsupported, migration blocked, migration failed safely, completion uncertain, verification failed, recovery required, retry permitted with same identity, retry prohibited, user review required, application startup must stop before writes, and fatal configuration defect.

Each outcome records whether app content may be shown, baseball records may be read, baseball records may be written, legacy startup may be used, automatic fallback is prohibited, retry is safe, source preservation must remain, and diagnostics are required. No UI text or production startup behavior was added.

<!-- MARK: 16. Disable And Fallback Policy -->
## 16. Disable And Fallback Policy

The centralized future route choice classifies legacy unversioned production startup, Proposed V2 prepared but disabled, Proposed V2 eligible for isolated verification, Proposed V2 eligible for bounded production transition, Proposed V2 active, Proposed V2 disabled after activation, recovery-only, and unsafe. The current value remains legacy.

Automatic fallback after a Proposed V2 migration attempt begins is prohibited. The same store must not be opened through two incompatible active containers. Disabling future writes must not erase evidence. Code-route rollback and data rollback remain distinct. A migrated V2 store must not be reopened by incompatible legacy code unless later proof establishes safety.

<!-- MARK: 17. Diagnostics And Privacy -->
## 17. Diagnostics And Privacy

Diagnostics include factory path, route choice, store-location kind, source classification, optional redacted migration diagnostic token, target schema, construction disposition, verification disposition, write-readiness disposition, disable state, recovery requirement, and stable diagnostic codes.

Diagnostics do not include baseball record contents, team or player names, media, receipts, Keychain values, full store URLs, raw framework errors, database dumps, or personal file paths where avoidable. No production logging or telemetry was added.

<!-- MARK: 18. Failure Classifications -->
## 18. Failure Classifications

Deterministic external failure injection covers preflight failure, source-classification failure, source-preservation failure, container-construction failure, migration failure, construction completion uncertain, post-open verification failure, completion-evidence failure, disable state activated, recovery required, read-only store, unsupported future source, and conflicting migration evidence.

Tests do not simulate failure by disk corruption, permission changes, actual user stores, process killing, manual SQLite modification, or metadata rewriting.

<!-- MARK: 19. Interruption And Reconciliation Behavior -->
## 19. Interruption And Reconciliation Behavior

Reconciliation classifies no prior evidence as safe to start, preflight/source-classified/source-preserved evidence as safe to resume with the same identity, attempted or construction-recorded evidence as safe to verify without repeating migration, safe failure as retry requiring a fresh source copy, completed evidence as completion proven, unreadable target after completion as completion uncertain, uncertain evidence as completion uncertain, recovery evidence as recovery required, disable evidence as review required, and unsupported source as unsupported.

No recovery, retry, deletion, merge, repair, or legacy fallback is executed automatically.

<!-- MARK: 20. Active Production Non-Routing Proof -->
## 20. Active Production Non-Routing Proof

Focused source-reference tests prove `ScoreKeepApp` still uses `.modelContainer(for: Game.self)` and does not reference the new factory, Proposed schemas, migration plan, or migration evidence authority. TeamView and TeamContentView do not reference the factory. The team-creation route manifest still reports legacy SwiftData as the current authority. The central startup route default remains legacy.

The new factory and evidence files do not reference StoreKit, Keychain, PurchaseManager, allowance, entitlement, SwiftUI, import/export services, PDF/report paths, or production startup. No production store or user data was opened.

<!-- MARK: 21. Staged-Gate Results -->
## 21. Staged-Gate Results

Stage A passed: active startup inventory confirmed the existing legacy production container and route remain unchanged.

Stage B passed: factory inputs, outputs, source classifications, startup states, diagnostics, outcomes, and write-readiness evaluation were implemented and tested.

Stage C passed: disposable Proposed V2 construction was verified for new, exact unversioned, existing V2, repeated-open, read-only, blocked, unsupported, and injected-failure scenarios.

Stage D passed: migration evidence protocol, test-only durable authority, cross-instance behavior, conflict rejection, interruption, and reconciliation were verified.

Stage E passed: post-open disposable verification preserved stable baseball evidence and kept team-operation-evidence storage empty.

Stage F passed: disabled, uncertain, recovery, read-only, unsupported, unsafe, and write-prohibited states remain blocked.

Stage G passed: active production startup, model container, team writer, adapter, coordinator, SwiftData operation-evidence store, StoreKit, Keychain, allowances, entitlements, UI, accessibility, imports, exports, reports, media, and scoring remain unchanged and non-routed.

Stage H verdict: Blocked pending specific production evidence-storage or recovery work.

<!-- MARK: 22. Remaining Blockers -->
## 22. Remaining Blockers

Before active container transition, ScoreKeep still needs implemented production split evidence storage, production source-preservation and backup execution, production recovery and rollback executor, production disable wiring, startup user-outcome integration, production diagnostic presentation or support path, explicit one-writer verification for the active store, and release-level policy for reopening or reverting migrated V2 stores.

The current foundation is ready for a separate active production-container transition preparation run, but it is not safe to activate production transition yet.

<!-- MARK: 23. Exact Next Implementation Recommendation -->
## 23. Exact Next Implementation Recommendation

Next, implement production migration evidence storage and source-preservation execution in a non-routed run, including a concrete split pre-open and post-open evidence design, source store-family backup/copy verification, recovery classification backed by durable evidence, disable-state persistence, privacy-safe diagnostics, and tests that prove no production startup routing occurs.

Do not route team creation or any baseball writer until the active production-container transition, durable migration evidence, source preservation, disable path, dedicated transaction context, user outcome integration, diagnostics, and one-writer verification are all proven.

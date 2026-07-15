# Durable Team Creation Operation Evidence Baseline

<!-- MARK: - 1. Purpose And Storage Decision -->
## 1. Purpose And Storage Decision

This run proves a non-routed SwiftData operation-evidence foundation for simple team creation. SwiftData evidence was selected over Team-only proof because Team existence cannot prove which operation created the record after relaunch or uncertainty. It was selected over a separate file journal because a small SwiftData model can share transaction context with Team in isolated proof, can use SwiftData uniqueness for operation identity, and can later participate in a schema migration decision. No production route was changed.

<!-- MARK: - 2. Current Production Schema Boundary -->
## 2. Current Production Schema Boundary

The active production startup remains `ScoreKeepApp` with `.modelContainer(for: Game.self)`. The active production model declarations remain Game, Team, Player, Atbat, Lineup, and Pitcher. No production VersionedSchema, SchemaMigrationPlan, migration startup, evidence store construction, writer route, TeamView integration, adapter route, StoreKit path, Keychain path, allowance path, entitlement path, UI, accessibility behavior, import route, export route, report route, source record, or fixture route was changed.

<!-- MARK: - 3. Proposed Evidence Model -->
## 3. Proposed Evidence Model

The proposed model is `TeamCreationOperationEvidenceRecord`, a separate SwiftData model outside Team and other baseball facts. It stores operation identity, target team identity, semantic request fingerprint, operation phase, completion proof, final disposition, retry classification, review flag, stable diagnostic codes, source classification, and evidence schema version. Operation identity uses `@Attribute(.unique)`.

<!-- MARK: - 4. Stored And Excluded Fields -->
## 4. Stored And Excluded Fields

Stored fields are scalar operation metadata only. Excluded fields include team name, coach, details, logo bytes, players, games, lineups, receipts, entitlements, allowances, Keychain data, raw errors, UI messages, full requests, full transaction results, full baseball snapshots, retry history, diagnostic logs, closures, ModelContext, and ModelContainer. This keeps evidence proportionate for idempotency and reconciliation.

<!-- MARK: - 5. Relationship Decision -->
## 5. Relationship Decision

The evidence model has no relationship to Team, and Team has no relationship to evidence. Target team identity is stored as a stable UUID scalar. This avoids cascade deletion, relationship migration, live model retention, and deletion ambiguity. Operation evidence remains historical transaction evidence even if the Team is later edited or deleted.

<!-- MARK: - 6. Uniqueness Policy -->
## 6. Uniqueness Policy

Operation identity is uniquely enforceable through SwiftData `@Attribute(.unique)`. Team identity is searchable but not globally unique as operation evidence because multiple historical operations may target the same team identity. Conflicting reuse of the same operation identity with a different semantic fingerprint is rejected. Name, time, array order, Swift hash values, and current object identity are not uniqueness authorities.

<!-- MARK: - 7. Proposed Schemas -->
## 7. Proposed Schemas

Proposed V1 represents the current known baseball model set: Game, Team, Player, Atbat, Lineup, and Pitcher. Proposed V2 adds only TeamCreationOperationEvidenceRecord. Proposed V1 is a formal isolated representation of the current model set, not proof that every previously released installed store carries explicit V1 metadata.

<!-- MARK: - 8. Isolated Migration Behavior -->
## 8. Isolated Migration Behavior

The isolated migration plan is a lightweight V1-to-V2 migration. Empty V1 stores open as V2 with no evidence records. Populated V1 stores preserve the representative baseball graph, stable identities, relationships, ordering, photos, logos, and media ownership while leaving the added evidence table empty. The populated migration test passed twice individually.

<!-- MARK: - 9. Current Unversioned Store Limitation -->
## 9. Current Unversioned Store Limitation

The installed production-store question remains blocked. Synthetic Proposed V1 tests do not prove that current unversioned ScoreKeep stores can later be opened as explicit Proposed V1 and migrated to Proposed V2. The assessment is: requires device-copy testing or archive-built prior-app verification, plus production-store metadata inspection where safe.

<!-- MARK: - 10. SwiftData Evidence Store Behavior -->
## 10. SwiftData Evidence Store Behavior

`TeamCreationSwiftDataEvidenceStore` implements the existing operation-evidence protocol with an injected ModelContainer. It creates fresh ModelContext values internally, fetches by operation identity, fetches by team identity, begins operations, advances phases, marks completion, marks uncertainty, marks safe failure, detects conflicts, saves explicitly, survives fresh contexts and fresh containers, and returns immutable canonical evidence values.

<!-- MARK: - 11. Phase Transitions -->
## 11. Phase Transitions

Allowed transitions include prepared to in progress, in progress to save attempted, save attempted to uncertain, save attempted to persisted-team-verified, save attempted to completed for the existing coordinator path, persisted-team-verified to completed, in progress to failed safely, save attempted to failed safely, safe failure to prepared for same-operation retry, and supported states to review or conflict. Backward movement and terminal replacement are rejected.

<!-- MARK: - 12. Same-Context Transaction Design -->
## 12. Same-Context Transaction Design

The isolated same-context proof inserts prepared or save-attempted evidence and Team in one clean dedicated ModelContext and performs one explicit save. Fresh reload verifies exactly one Team and exactly one evidence record with matching operation identity, team identity, request fingerprint, and Team meaning. This proves the practical atomic boundary only when evidence and Team use the same ModelContainer, same clean context, and one explicit save.

<!-- MARK: - 13. Completion Tradeoff -->
## 13. Completion Tradeoff

A one-save protocol can atomically persist Team plus save-attempted evidence, but it cannot honestly record post-reload completion proof in the same save because completion proof depends on fresh verification. The supported direction is two-stage completion: one save for Team plus attempted evidence, then a second verified save for completion marker after fresh reload. This is not fully atomic, and crash windows remain classified.

<!-- MARK: - 14. Crash Windows -->
## 14. Crash Windows

Before any save, prepared-only, and Team-inserted-before-save windows are safe retry when no records persisted. During save or after save before reload is completion uncertain. After reload before completion update requires reconciliation. After completion update is completed when Team is present. Relaunch with prepared evidence is safe retry; save-attempted evidence is uncertain; Team present with incomplete evidence requires reconciliation; complete evidence with missing Team requires review; Team present with missing evidence requires review.

<!-- MARK: - 15. Reconciliation Behavior -->
## 15. Reconciliation Behavior

Reconciliation compares operation evidence, Team existence, Team semantic meaning, operation identity, team identity, request fingerprint, and completion phase. It classifies no prior evidence, prepared with no Team, safe failure with no Team, matching Team with incomplete evidence, completed match, conflicting Team meaning, completed evidence with missing Team, uncertain evidence, fingerprint conflict, duplicate Team records, retry prohibition, safe retry, and review required. It never deletes, merges, rewrites, retries, repairs, or invokes the legacy writer.

<!-- MARK: - 16. Coordinator Concurrency And Relaunch -->
## 16. Coordinator Concurrency And Relaunch

The existing actor coordinator was verified with the SwiftData-backed store in isolated tests. Matching concurrent requests execute at most once. Recreated coordinators and fresh store access preserve completion. Conflicting operation reuse is blocked. Same-team matching competing operations do not duplicate accepted execution. Completed evidence avoids executor re-entry. Uncertain evidence blocks blind retry. Safe failure permits same-operation retry only.

<!-- MARK: - 17. Retention Policy -->
## 17. Retention Policy

Retention classifications are active, uncertain, review required, completed recently, completed eligible for future cleanup, failed safely eligible for future cleanup, must retain for unresolved reconciliation, must retain for conflict, and never delete automatically during read. Automatic production cleanup is not implemented. Minimum retained evidence must protect cross-launch duplicate creation, delayed retry, uncertain completion, app restoration, and conflicting operation reuse.

<!-- MARK: - 18. Team Lifecycle Behavior -->
## 18. Team Lifecycle Behavior

Operation evidence remains historical. Later Team edits do not rewrite evidence. Later Team deletion does not cascade-delete evidence. Reusing the same team name does not affect evidence because name is not stored and not identity. Team identity should not be reused for a different Team. A user creating a new Team after deleting an earlier one requires a new operation identity and team identity.

<!-- MARK: - 19. Purchase And Allowance Separation -->
## 19. Purchase And Allowance Separation

The evidence model and store contain no StoreKit receipt, signed transaction, product identifier, entitlement state, season-pass state, Keychain data, free-game allowance, MLB download allowance, or purchase marker. Tests use probes only. Team creation remains non-allowance-consuming.

<!-- MARK: - 20. Privacy Boundary -->
## 20. Privacy Boundary

Persisted evidence is limited to IDs, fingerprint, phase, disposition, retry/review classifications, diagnostic code raw values, source, and schema version. It avoids user-entered descriptive text, media, raw errors, full requests, database snapshots, and logs. No telemetry or production logging was added.

<!-- MARK: - 21. Non-Routing Proof -->
## 21. Non-Routing Proof

Focused source-reference tests verify ScoreKeepApp does not reference the proposed schemas, migration plan, operation evidence model, or SwiftData evidence store. Existing operational-safety tests continue to verify the current route choice remains legacy and TeamView does not reference the coordinator or operational request. No production operation evidence is written.

<!-- MARK: - 22. Staged Gate Results -->
## 22. Staged Gate Results

Stage A passed: independent scalar evidence is supportable. Stage B passed: evidence model, transitions, reconciliation, retention, and crash classification exist. Stage C passed: Proposed V1 and V2 are isolated. Stage D passed: isolated V1-to-V2 behavior is verified. Stage E passed: SwiftData evidence store persists and reloads. Stage F passed: same-context save and crash windows are classified. Stage G passed: coordinator concurrency and relaunch behavior are verified. Stage H passed: production boundary remains unchanged and unversioned-store risk remains explicit.

<!-- MARK: - 23. Remaining Blockers -->
## 23. Remaining Blockers

Production schema routing remains blocked by the unproven current unversioned installed-store path, lack of production source-version authority, lack of production migration-state provider, lack of production disable wiring, lack of production user-outcome UI mapping, lack of production transaction-context construction and handoff, lack of production diagnostics, and lack of routed UI verification. Do not route until those are resolved.

<!-- MARK: - 24. Exact Next Recommendation -->
## 24. Exact Next Recommendation

Next, prove whether a current unversioned installed ScoreKeep store from an archive-built prior app can be safely classified and opened under the proposed V1/V2 route using device-copy or archived-app fixtures. In parallel, design but do not route production source-version and migration-state providers, disable behavior, user-outcome mapping, and dedicated transaction-context handoff. Do not recommend adapter routing yet.

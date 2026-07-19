# Frozen V2 Store Verification Architecture

<!-- MARK: - 1. Purpose -->
## 1. Purpose

This document completes implementation-catalog Task 3.22A. It decides how ScoreKeep should safely identify, verify, and migrate a frozen Proposed V2 persistent store without constructing runtime-effective V2 and V3 SwiftData schemas together inside the current V3 application target.

The decision is documentation only. It does not implement the selected architecture, create a Core Data model, add a target, change production startup or recovery routing, alter schemas, execute migration, run a simulator, resume Task 3.22, or begin Task 3.23.

The investigation question is intentionally split into separate guarantees:

- Source-version identification: deciding whether the store is the historical source version expected by the migration.
- Source semantic verification: proving that source records, relationships, and stored values are readable under an authoritative source model.
- Migration execution: transforming only a copied workspace into the destination schema.
- Destination semantic verification: proving the migrated V3 store preserves required Legacy facts and has empty canonical scoring history.
- Rollback safety: proving that failure or interruption preserves a recoverable pre-migration source family.

Those guarantees are not interchangeable. Metadata identity can identify a store but cannot prove semantic readability. A successful destination open can prove V3 readability but cannot, by itself, prove that every source relationship was independently valid before migration. Rollback evidence can preserve user data without proving source semantic correctness.

<!-- MARK: - 2. Scope and Non-Goals -->
## 2. Scope and Non-Goals

The scope is the smallest production-capable architecture that lets Task 3.22 resume without reintroducing the current duplicate-checksum failure mode.

The work evaluates three paths:

- Path A: include an authoritative frozen seven-entity Proposed V2 Core Data model independent of the current SwiftData V3 target.
- Path B: create an isolated V2-only verification target or helper boundary.
- Path C: redesign the recovery-verification requirement around source identity, copied-workspace migration, destination semantic verification, and deterministic rollback.

The decision also defines prerequisite implementation and testing tasks that must be approved and completed before Task 3.22 may resume.

The following remain out of scope:

- Implementing any candidate architecture.
- Generating or checking in an `.xcdatamodeld`, compiled `.mom`, generated managed object model, mapping model, helper executable, framework, app extension, or new target.
- Changing `ScoreKeepProposedVersionedSchema`, production container construction, production startup, completed-journal recovery, migration orchestration, schema diagnostics, StoreKit configuration, bundled resources, app entitlements, or Xcode project settings.
- Running a build, tests, simulator, physical migration, or actual store migration.
- Reclassifying Task 3.22 as complete.
- Beginning Task 3.23 or routing canonical scoring writes.
- Retiring Legacy scoring.

<!-- MARK: - 3. Established Task 3.22 Blocker -->
## 3. Established Task 3.22 Blocker

Document 29 records Task 3.22 as blocked, not complete. The completed portion of Task 3.22 introduced the Proposed V3 storage declaration: Proposed V1 contains `Game`, `Team`, `Player`, `Atbat`, `Lineup`, and `Pitcher`; Proposed V2 adds `TeamCreationOperationEvidenceRecord`; Proposed V3 adds `CanonicalGameHistoryRecord`, `CanonicalScoringOperationEvidenceRecord`, `CanonicalScoringEventEnvelopeRecord`, `CanonicalScoringEventPayloadRecord`, and `CanonicalScoringCorrectionRecord`.

Production scoring remains Legacy. No production writer synthesizes canonical scoring history. Task 3.23 remains blocked because it depends on completed and verified Task 3.22 storage.

The blocker is runtime-effective historical schema expansion. In the current V3 application or hosted test process, constructing historical V2 through SwiftData can expand to the same effective 12-model inventory as V3. Registering that effective V2 together with V3, including through `ScoreKeepProposedCanonicalScoringStorageMigrationPlan` or hosted V2-to-V3 migration construction, can terminate with `NSInvalidArgumentException: Duplicate version checksums detected`.

Current production stabilization therefore fails closed at `semanticVerifierUnavailable.currentTargetV2AndV3DuplicateEffectiveChecksums`. Normal startup can create a new V3 store where authorized or open an existing V3 store directly, but it must not semantically open frozen V2 through the current V3 app target.

Document 29 also records that the repository has no independent frozen V2 `NSManagedObjectModel` and no existing isolated seven-model V2 target. Metadata equality, version identifiers, SQLite table presence, and hash inventory comparison are useful diagnostics but are not a semantic source-open proof.

<!-- MARK: - 4. Repository Evidence -->
## 4. Repository Evidence

Task catalog evidence:

- `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md` places Task 3.22A immediately after Task 3.22 and before Task 3.23.
- The same document preserves Task 3.22 as blocked and Task 3.23 as blocked.
- The Task 3.22 construction audit lists `ScoreKeepProposedCanonicalScoringStorageMigrationPlan` as unsafe when used in hosted current-target runtime, `ScoreKeepProposedContainerFactory.construct` as V3-only for supported production paths, production startup as no-store or V3-direct only, and completed-journal V1/V2 recovery as fail-closed.

Design evidence:

- Document 17 sets the rewrite boundary around evidence-first replacement and migration, not destructive replacement.
- Document 18 defines canonical domain meaning separately from persistence mechanics.
- Document 19 keeps scoring authority separate from persistence storage and production routing.
- Document 20 requires data preservation, explicit migration outcomes, no silent repair, interruption recovery, rollback, and no irreversible destructive migration before verification.
- Document 21 keeps import/export compatibility as explicit interpretation rather than hidden repair.
- Document 22 treats scorecard presentation as a projection, not as source authority.
- Document 23 keeps workflow routing separate from persistence authority.
- Document 24 treats reporting and generated output as consumers of stored facts.
- Document 25 keeps purchase entitlement and allowance state separate from baseball persistence.
- Document 26 requires error and recovery states to remain understandable and accessible.
- Document 27 requires migration verification for existing installed-app data, repeated/interrupted/failed migration, recovery, rollback, no fabricated records, and no purchase or allowance mutation.
- Document 28 requires evidence before replacement, compatibility before cleanup, migration before retirement, verification before routing, and reversible rollback boundaries.
- Document 30 records the canonical scoring persistence requirement and the decision to add five canonical scoring storage models while production scoring remains Legacy. Its earlier references to Proposed V2 as active production storage are superseded by the Task 3.22 blocker state in Document 29 and the current code.

Schema evidence:

- `ScoreKeepProposedVersionedSchema.ScoreKeepProposedVersionedSchema.V1` declares the six Legacy models.
- `ScoreKeepProposedVersionedSchema.ScoreKeepProposedVersionedSchema.V2` declares the six Legacy models plus `TeamCreationOperationEvidenceRecord`.
- `ScoreKeepProposedVersionedSchema.ScoreKeepProposedVersionedSchema.V3` declares the V2 models plus the five canonical scoring storage models.
- `ScoreKeepProposedTeamCreationEvidenceMigrationPlan` declares the V1-to-V2 lightweight migration.
- `ScoreKeepProposedCanonicalScoringStorageMigrationPlan` declares the V2-to-V3 lightweight migration, but Document 29 and retained tests classify hosted current-target use as unsafe.

V2 persisted model evidence:

- `Game` is a SwiftData model with a stable UUID identity, date/location/highlight/score/game settings, optional home and visitor teams, player/at-bat/lineup/pitcher collections, and replacement collections.
- `Team` is a SwiftData model with identity, name, coach, details, player/game collections, and external-storage logo data.
- `Player` is a SwiftData model with identity, name, number, position, batting direction/order, optional team, at-bat collection, and external-storage photo data.
- `Atbat` is a SwiftData model with identity, required game/team/player relationships, result and advancement fields, inning/sequence/column values, RBI/out/sacrifice/stolen-base/earned-run/play-record/end-of-inning fields.
- `Lineup` is a SwiftData model with identity, everyone-hits flag, required game/team relationships, inning, and players.
- `Pitcher` is a SwiftData model with identity, required player/team/game relationships, inning/out/batter range fields, aggregate pitching statistics, and win flag.
- `TeamCreationOperationEvidenceRecord` is a SwiftData model with unique `operationIdentity` and scalar team-creation operation evidence fields. Its boundary intentionally excludes team relationships, purchase or allowance state, and media fields.

V3 canonical addition evidence:

- `CanonicalGameHistoryRecord` records game history status and owns event, operation, and correction records.
- `CanonicalScoringOperationEvidenceRecord` records operation identity, request fingerprint, status, result, diagnostics, and optional event/correction relationships.
- `CanonicalScoringEventEnvelopeRecord` records event identity, history/game identity, sequence, commit status, supersession state, and a payload relationship.
- `CanonicalScoringEventPayloadRecord` records payload identity, event identity, payload bytes, schema version, fingerprint, and optional classification fields.
- `CanonicalScoringCorrectionRecord` records correction identity, game/history identity, original and replacement event identities, correction status, reason, fingerprint, and optional relationships.
- `CanonicalScoringPersistenceModelBoundary.implementationModelNames` lists exactly those five models.
- `CanonicalScoringPersistenceModelBoundary.uniquenessSupport` records the current iOS 17.6 boundary for scalar uniqueness.

Production construction evidence:

- `ScoreKeepProposedContainerFactory.construct` accepts only `.proposedV3`, rejects the production-intended application store route, requires explicit URLs, rejects nonfresh fresh destinations, and supports only no-store, existing V3, and converted V3 classifications.
- The same factory returns `semanticVerifierUnavailableCurrentTargetV2AndV3DuplicateEffectiveChecksums` for existing or converted V2 classifications.
- The factory constructs a V3 `ModelContainer` without a migration plan for supported current production routes.
- `ScoreKeepProductionStartupHost.runProductionMigration` supports only no-store and V3-direct classifications in current startup. V1 and V2 active sources block before migration.
- `ScoreKeepProductionStartupHost.proposedV3MigratingFromV2Container` now throws the duplicate-checksum semantic-verifier blocker.
- `ScoreKeepCompletedJournalRecoveryRouter.route` and the completed-journal switch open V3 target or active stores directly but block V1/V2 recovery paths.

Metadata, backup, journal, and diagnostics evidence:

- `ScoreKeepProductionStoreMetadataAssessment.assess` reads persistent-store metadata with Core Data and uses `NSStoreModelVersionHashesKey` and `NSStoreModelVersionIdentifiersKey` to classify no-store, Proposed V1, Proposed V2, Proposed V3, unknown, unreadable, and contradictory stores.
- `ScoreKeepCoreDataVersionHashEvidence` stores entity version-hash entries and a digest for comparison.
- `ScoreKeepCompletedJournalV2SourceBaseline.make` revalidates V2 metadata and then throws `semanticVerifierUnavailable("currentTargetV2AndV3DuplicateEffectiveChecksums")`.
- `ScoreKeepCompletedJournalV2SourceRevalidator` compares source-family identity, model identifiers, entity names, version hashes, and sidecar state, while allowing version-stable sidecar changes.
- `ScoreKeepStoreFamilyDiscovery` identifies the primary store, WAL, SHM, unexpected related files, byte counts, and SHA-256 fingerprints.
- `ScoreKeepSourcePreservationExecutor.preserve` requires closed source evidence, copies the whole discovered store family to a fresh backup directory, verifies file identity before and after copy, and can run an optional semantic restore verifier on a restored copy.
- `ScoreKeepMigrationOrchestrator` records journal phases, preserves the source, copies backup to a target workspace, constructs the destination container, runs post-open verification, records completion, and maps failures to recovery-required states.
- `ScoreKeepMigrationJournalStore` writes journal records through a temporary file and replace/move pattern.
- `ScoreKeepMigrationRetention` prohibits active source and target cleanup, retains verified backups and recovery/manual-review material, and limits temporary cleanup to explicit safe categories.
- `ScoreKeepProductionMigrationPaths` separates active store, control root, journal, backups, temporary targets, incomplete targets, recovery, diagnostics, manual-review, and cleanup roots.
- `ScoreKeepMigrationBaselineCapture` captures record counts, stable identity, relationship, ordering, score, substitution, media, import, difficult-runner, team-operation-evidence, and canonical scoring row counts.
- `ModelContext.sqliteCommand` in `Extensions.swift` is only a diagnostic string for invoking `sqlite3`; the repository has no SQLite semantic verifier that can replace SwiftData or Core Data semantic opening.

Test and project evidence:

- `VersionedCanonicalScoringPersistenceTests.v2ToV3RuntimeMigrationProofRequiresIsolatedV2Boundary` is a source-level assertion that the hosted test must not construct the unsafe V2-to-V3 runtime migration.
- `ScoreKeepProposedContainerFactoryTests` verify V3 construction and V2/unversioned fail-closed dispositions.
- `CompletedJournalRecoveryRoutingTests` verify V3 direct recovery and fail-closed V1/V2 recovery routes.
- `ProposedV3SchemaInventoryTests` verify declared V2/V3 inventory counts and the declared V2-to-V3 migration stage without constructing hosted migration.
- `ProductionSourcePreservationFocusedTests`, `ProductionStartupRecoveryTests`, `CanonicalFailedMigrationRecoveryTests`, `ProductionMigrationPathTests`, `ProductionStoreMetadataAssessmentTests`, and `ProductionStartupStorePreflightTests` cover source preservation, recovery, path separation, metadata classification, and startup preflight.
- The test plan contains `ScoreKeepTests`; no separate V2-only verification target is currently listed.
- The Xcode project contains app, unit-test, and UI-test native targets, with no existing V2-only helper target, app extension target, framework target, command-line target, entitlements file, Core Data model resource, `.mom`, `.momd`, checked-in SQLite store fixture, or CloudKit entitlement reference.
- The app deployment target is iOS 17.6; current test target deployment settings differ and include iOS 18.2 entries, matching Document 28's warning that deployment settings require care.
- Bundled resources include `ScoreKeep.storekit`, migration test xcconfig files, and JSON compatibility fixtures. No tracked Core Data model artifact or historical store fixture was found.

<!-- MARK: - 5. Required Safety Guarantees -->
## 5. Required Safety Guarantees

The architecture must preserve these guarantees separately:

- Source identity: the active store family must be identified as the historical source version expected by the migration.
- Source-family completeness: the primary store must exist, and WAL/SHM/unexpected related files must be accounted for.
- Source immutability before commit: the original active source family must not be mutated by verification or migration attempts.
- Source semantic readability: when claimed, the source must open under an authoritative source model and preserve expected records, values, and relationships.
- Migration compatibility: the migration must be attempted only through a supported API path and only against a copied workspace.
- Destination readability: the migrated destination must open as V3 through the production V3 container boundary.
- Destination semantic correctness: the migrated destination must preserve all required V2 facts and relationships and must not synthesize canonical scoring rows.
- Canonical-zero guarantee: all five canonical scoring storage tables must remain empty after migration from Legacy history.
- Journaled idempotency: startup, retry, completion, failure, and recovery must be classified by operation evidence rather than by implicit side effects.
- Candidate acceptance boundary: Task 3.22 may mark a copied V3 candidate destination verified and eligible for later acceptance; active-store replacement is later work and may occur only after separate authorization and successful destination verification.
- Rollback safety: the untouched source backup must be retained or controlled-retained so recovery can return to a known pre-migration family.
- Interruption safety: interrupted attempts must not duplicate records, hide records, partially promote an unverified target, or lose the prior source.
- Purchase separation: baseball persistence and migration must not mutate StoreKit, entitlement, or allowance state.

The strictest original requirement would include pre-migration source semantic opening under frozen V2. The current repository cannot satisfy that requirement in the V3 app target. The architecture decision must therefore either find an independent authoritative source model, introduce a production-safe isolation boundary, or explicitly redesign the guarantee while naming the protection lost.

<!-- MARK: - 6. Frozen Core Data V2 Model Evaluation -->
## 6. Frozen Core Data V2 Model Evaluation

Path A would include an authoritative frozen seven-entity Proposed V2 `NSManagedObjectModel` that is independent of current-target SwiftData schema expansion. The model would be used to open a copied V2 store through documented Core Data APIs without registering the current V3 SwiftData migration plan in the same operation.

No exact frozen V2 Core Data model exists in the repository. The inspected source, project, test plan, bundled resources, fixtures, and tracked files contain no `.xcdatamodeld`, `.xcdatamodel`, compiled `.mom`, `.momd`, generated managed-object model, mapping model, checked-in SQLite store fixture, or historical Core Data artifact for Proposed V2.

The SwiftData source declarations prove many user-level model facts: model names, declared properties, relationship properties, uniqueness on `TeamCreationOperationEvidenceRecord.operationIdentity`, external storage on team logos and player photos, and the five V3 additions. They do not prove the exact historical Core Data representation that SwiftData generated for V2 at runtime.

An exact frozen model would need to match every persistence-affecting detail used by the historical store, including:

- Entity names and managed-object class names.
- Attribute names, value types, optionality, default values, and value transformer choices.
- Relationship names, destinations, optionality, cardinality, inverses, and delete rules.
- Unique constraints and any indexes or generated support entities.
- Transient fields and external-storage behavior.
- Renaming identifiers and version-hash modifiers, if any.
- Configuration membership.
- SwiftData-generated details not explicit in the source declarations.
- Model version hashes matching the historical V2 store metadata.

Repository-proven details are limited to the Swift source declarations and current diagnostics. Publicly documented details include that Core Data stores model-version hash metadata and uses model compatibility for migration/opening decisions. Inferred details include likely entity and property mapping from SwiftData to Core Data. Unknown details include the complete SwiftData-generated Core Data model graph, relationship inverse choices where not explicitly declared, generated backing entities or properties, any implicit defaults, and whether future OS releases would generate the same representation from the same Swift source.

Apple documents `NSManagedObjectModel`, persistent-store metadata, model version hashes, and Core Data migration APIs. Apple does not document SwiftData's complete generated Core Data model representation as a stable reconstruction contract. Relying on recreated SwiftData internals would therefore depend on unsupported implementation details.

Historical V2 metadata can validate candidate entity names and version hashes, but metadata alone does not contain enough information to reconstruct a complete model. A hash match can show compatibility evidence for hashed model descriptions; it does not reveal all original declarations, relationship semantics, migration policy, or business invariants. A mismatch would disqualify a reconstructed model. A match would still need fixtures and read/fetch/reconciliation tests before production trust.

If an exact frozen V2 model artifact were obtained from an authoritative source, Core Data could be a supported way to open a copied V2 store, read metadata, and perform model compatibility checks. Verification must use a copied store family or copied restore workspace rather than the protected source, because opening a SQLite persistent store may interact with WAL/SHM sidecars, file locks, metadata, journaling, pragmas, or migration options. Read-only opening through documented options can reduce mutation risk, but the architecture should still treat copied workspaces as the safety boundary.

Path A could prove source semantic readability if the exact model existed and verified fixtures opened correctly. It could also help prove absence of V3 canonical entities in the source and preservation of V2 records before migration. It would not by itself prove destination semantic correctness, operation idempotency, atomic replacement, or rollback. It might support migration execution through Core Data if supported source and destination models plus mapping were exact, but the repository currently lacks the required model evidence.

Path A is therefore not selected for production. It should be revisited only if an exact historical V2 model artifact or an independently generated and fixture-proven V2 model can be obtained through supported evidence.

<!-- MARK: - 7. V2-Only Target Evaluation -->
## 7. V2-Only Target Evaluation

Path B would isolate frozen V2 verification by compiling only the seven V2 models and minimal verification support:

- `Game`
- `Team`
- `Player`
- `Lineup`
- `Atbat`
- `Pitcher`
- `TeamCreationOperationEvidenceRecord`
- Minimal store-family, metadata, baseline, and semantic-read code

The project currently has app, unit-test, and UI-test targets only. A new V2-only target could take several forms, but their production value differs.

A separate test-only target could provide genuine isolation for CI and fixture evidence if it links only the seven V2 models and minimal support. It could create or open V2 fixtures, verify V2 record readability, and prevent the current V3 test process from registering V2 and V3 together. That is useful supporting evidence. It is not production verification unless its result is generated from the user's actual production store during app startup.

A separate framework linked into the main app would not provide reliable runtime isolation by itself. Once linked into the same application process, V2-only framework code and V3 app code share the same binary, process, SwiftData runtime, and linked model types. If V3 models are present in the process or reachable through relationships and schema construction, the architecture can lose the isolation it was meant to provide. This is an architectural inference based on the repository-observed duplicate-checksum failure and the lack of an Apple-documented SwiftData per-framework schema isolation contract.

An app extension is production-available in the App Store sense, but it is not a small on-demand migration helper. iOS extensions are system-invoked extension points with their own lifecycle, sandboxing, signing, entitlements, and extension contexts. Sharing the store family with the containing app would require an App Group container or explicit data movement. Startup migration would need reliable request/response coordination, lifecycle handling, file coordination, and failure recovery while the containing app also owns the production data path. The repository currently has no app-extension target, app-group entitlement, shared-container storage plan, or IPC protocol. Adding those pieces solely to verify a local SwiftData schema would materially expand project and operational complexity.

An iOS application cannot rely on launching an arbitrary helper executable or command-line process for App Store production startup migration. Apple's documented iOS app launch and extension models do not provide a containing app with a general-purpose local helper-process mechanism comparable to a desktop command-line helper. A test command-line helper could be useful on macOS or CI, but it would not be a production iOS migration boundary.

Path B can therefore provide production verification only if implemented as an app extension with a supported extension point and shared data design, and that is not the smallest durable solution for this app. A V2-only test target remains useful as supporting evidence, fixture acquisition, and regression proof. It should not be selected as the production migration architecture for Task 3.22 unless the project separately accepts the app-extension/shared-container complexity.

<!-- MARK: - 8. Recovery-Requirement Redesign Evaluation -->
## 8. Recovery-Requirement Redesign Evaluation

Path C asks whether pre-migration semantic opening of frozen V2 is truly required, or whether a different boundary can provide adequate protection without relying on unsupported SwiftData runtime construction.

The approved persistence documents require data preservation, compatibility before cleanup, no silent repair, explicit failures, rollback, and verification before routing. They do not require that every guarantee be proven by the same mechanism. A redesigned boundary can preserve the intent if it is explicit about what it proves and what it cannot prove.

The production-capable redesign is:

- Identify the source by exact persistent-store metadata and store-family evidence.
- Preserve the untouched source family before any migration attempt.
- Copy the preserved source backup to a fresh migration workspace.
- Attempt migration only against the copied workspace.
- Fail closed on migration errors, metadata contradictions, incomplete store families, nonfresh destinations, source changes, or journal uncertainty.
- Open only the migrated destination as V3 in the current app target.
- Run destination semantic verification against V3.
- Reconcile source-identity evidence, destination record counts, stable identities, relationships, ordering, scores, substitution evidence, media evidence, team-creation evidence, and canonical-zero counts.
- Atomically replace the active store only after destination verification succeeds.
- Retain or controlled-retain the untouched V2 backup and operation journal for rollback and manual review.

This redesign proves source identity through exact version-hash inventory and entity inventory, not through source semantic opening. It proves migration compatibility by successfully migrating a copied workspace through the approved migration path. It proves destination readability by opening the migrated destination as V3. It proves destination semantic correctness by reconciling V3-visible data against captured baseline evidence and business invariants. It proves rollback safety by never mutating the protected source before successful destination verification and by retaining a verified backup family.

The redesign does not prove source semantic readability before migration. It cannot prove that an independently frozen V2 semantic opener would have read every source row and relationship. It also cannot prove the absence of all possible latent V2 corruption before the migration attempt. Those failures would be discovered during copied-workspace migration, V3 open, destination reconciliation, or manual-review diagnostics instead of during a pre-migration V2 open.

The lost protection is therefore specific: without a frozen V2 semantic open, the app cannot independently distinguish "this source is valid V2 but migration failed" from some classes of "this source metadata looks like V2 but stored content is unreadable or semantically inconsistent" until the copied migration or destination verification fails. Because the original source and backup remain intact, this is a recoverability and diagnostics weakening, not a destructive data-loss weakening.

The combination of exact metadata identity, untouched source backup, copied-workspace migration, successful V3 semantic verification, record and relationship reconciliation, canonical-zero verification, and rollback preservation is weaker than full pre-migration V2 semantic verification. It is acceptable for production if the implementation treats the weakness as an explicit fail-closed boundary, records diagnostics, retains rollback material, and requires fixtures and tests before Task 3.22 resumes.

<!-- MARK: - 9. Apple Platform Constraints -->
## 9. Apple Platform Constraints

The following platform conclusions are supported by current Apple primary documentation. Each fact is classified by support level.

SwiftData schema and migration:

- `VersionedSchema`: documented Apple guarantee that a type represents a specific version of a SwiftData schema and declares its version and models.
- `SchemaMigrationPlan`: documented Apple guarantee that a migration plan describes schema evolution through a list of versioned schemas and migration stages.
- `MigrationStage`: documented Apple guarantee that a migration stage describes migration between two versions of the same schema and can be lightweight or custom.
- `ModelContainer`: documented Apple guarantee that the container manages persistent storage for schema models and accepts a migration plan and configurations.
- SwiftData relationship auto-inclusion: documented Apple guidance in "Preserving your app's model data across launches: Configure the model storage" says SwiftData needs the runtime model list and can include destination model types through relationships.
- SwiftData generated Core Data representation stability: unknown or unsupported. Apple documentation does not make the complete generated Core Data model graph a stable reconstruction contract.

SwiftData read-only configuration:

- `ModelConfiguration` `allowsSave`: documented Apple guarantee that configuration can control whether saves are allowed.
- Using `allowsSave` as proof that opening never affects SQLite sidecars or metadata: unknown or unsupported. It is not sufficient as the source-preservation boundary.

Core Data model compatibility and metadata:

- `NSStoreModelVersionHashesKey`: documented Apple guarantee that persistent-store metadata can contain model-version hash information for the model used to create the store.
- `NSStoreModelVersionIdentifiersKey`: documented Apple guarantee that metadata can contain developer-defined version identifiers; Core Data does not depend on those identifiers at runtime by default.
- `NSPropertyDescription.versionHash`: documented Apple guarantee that persistence-affecting property description values contribute to version hashes.
- Model compatibility and migration: documented Apple guarantee that schema-affecting model changes make stores incompatible unless migrated through supported migration behavior.
- Exact V2 semantic reconstruction from SwiftData declarations: architectural inference and unsupported unless backed by an exact artifact or fixture-proven generated model.

Core Data store opening and migration:

- `NSPersistentStoreCoordinator.addPersistentStore`: documented Apple guarantee that a coordinator can add a store of a specified type at a URL with store options.
- `NSReadOnlyPersistentStoreOption`: documented Apple guarantee that Core Data has a read-only persistent-store option.
- `NSSQLiteStoreType`: documented Apple guarantee for SQLite persistent stores.
- `NSSQLitePragmasOption`: documented Apple guarantee that SQLite pragmas can be supplied as store options.
- `metadataForPersistentStore(ofType:at:options:)`: documented Apple guarantee for reading persistent-store metadata.
- `NSMigrationManager.migrateStore`: documented Apple guarantee that Core Data can migrate from a source URL to a destination URL when source model, destination model, and mapping are supplied.
- Lightweight migration: documented Apple guarantee that Core Data can infer mappings for supported model changes when requested.
- Staged migration: documented Apple guarantee that successful staged migrations depend on properly versioned object models and explicit stages.
- Migration against a copied store family: architectural inference built from documented URL-based store APIs and repository source-preservation requirements. Apple documents URL-based stores and migration, while this repository supplies the copy/backup safety policy.

SQLite store-family handling:

- SQLite persistent store type and SQLite pragmas are documented Apple APIs.
- Complete WAL/SHM mutation behavior for every open/read-only/metadata path: unknown or unsupported as a no-mutation guarantee. The repository must therefore use copied workspaces and source-family fingerprints instead of relying on an in-place no-write assumption.

CloudKit:

- "Preserving your app's model data across launches: Configure the model storage" documents that a SwiftData container can be configured for CloudKit and that entitlements can affect sync behavior.
- Repository observation: the project grep found no CloudKit entitlement, entitlements file, or CloudKit configuration reference. CloudKit is therefore not an active constraint for this decision.

iOS helper and extension feasibility:

- iOS app launch: documented Apple guarantee that the system launches the application process and app lifecycle through the app entry point.
- App extensions: documented Apple guarantee that extensions run through supported extension points and extension contexts, not as arbitrary containing-app helper executables.
- App Group container: documented Apple guarantee that `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` provides shared-container access when the entitlement is valid.
- Containing app launching arbitrary local helper executable for App Store startup migration: unknown or unsupported. This is not a valid production assumption.
- App extension as migration verifier: possible only as an architectural inference requiring a supported extension point, signing, entitlements, lifecycle, IPC, shared storage, and file coordination. It is not a documented generic migration-helper facility.

Apple source titles consulted:

- "SchemaMigrationPlan" supports SwiftData migration-plan structure.
- "VersionedSchema" supports SwiftData versioned schema declarations.
- "MigrationStage" supports lightweight and custom migration-stage semantics.
- "ModelContainer" supports container construction with schema, migration plan, and configurations.
- "ModelConfiguration" supports read-only save configuration, storage URL, app group, and CloudKit configuration facts.
- "Preserving your app's model data across launches: Configure the model storage" supports runtime model-list, relationship inclusion, persistent storage configuration, app group, and CloudKit behavior.
- "NSStoreModelVersionHashesKey" supports model-version-hash metadata.
- "NSStoreModelVersionIdentifiersKey" and "versionIdentifiers" support version-identifier metadata and its limited runtime role.
- "NSPropertyDescription.versionHash" supports persistence-affecting version-hash inputs.
- "NSManagedObjectModel: Changing models" supports model compatibility and migration requirements for schema changes.
- "Store options: Constants" supports Core Data read-only, SQLite pragma, file-protection, and migration store options.
- "NSPersistentStoreCoordinator.addPersistentStore" supports explicit Core Data store opening with options.
- "metadataForPersistentStore(ofType:at:options:)" supports metadata reads.
- "Core Data: Data model migration", "Migrating your data model automatically", "NSMigrationManager.migrateStore", and "Staged migrations" support Core Data migration behavior and constraints.
- "App extensions", "App Extension Support", and `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` support extension lifecycle and shared-container facts.
- "Responding to the launch of your app", "About the app launch sequence", and "UIApplication" support the iOS app-process launch boundary.

<!-- MARK: - 10. Comparative Decision -->
## 10. Comparative Decision

Path A is strong only if an exact frozen V2 model exists or can be reconstructed through supported evidence. It would use documented Core Data concepts and could prove source semantic readability on a copied store. It currently fails the "actual historical V2 store" and "documented API reliance" criteria because the repository lacks the required model artifact and SwiftData's generated Core Data representation is not a documented reconstruction contract. Reconstructing the model from Swift source would be high-risk, maintenance-heavy, and fixture-dependent.

Path B is useful for isolation evidence but weak as a small production architecture. A V2-only test target can prevent hosted V3-process schema collisions and can prove fixtures. A framework linked into the main app does not preserve process-level isolation. An app extension could be production-shippable only with significant extension-point, App Group, IPC, lifecycle, signing, and recovery complexity. An arbitrary helper process is not a supported iOS production assumption. Path B therefore scores well for testability and fixture support, but poorly for smallest production feasibility and operational recoverability.

Path C is the smallest production-capable architecture. It relies on documented metadata reads, existing repository source-family preservation, copied workspaces, existing V3 container construction, destination semantic verification, journaled recovery, and rollback retention. It does not depend on undocumented SwiftData generated-model reconstruction or an iOS helper process. It is weaker than full source semantic opening, but it keeps that weakness explicit and preserves recoverability by never mutating the protected source before the candidate is verified and retained for later acceptance.

The decision is a bounded combination: select Path C for production, with a narrowly scoped Path B test-only evidence task allowed as supporting fixture and regression infrastructure. Do not select Path A for production unless an exact frozen V2 model artifact is later obtained and independently verified. Do not select a production app-extension or helper-process boundary for Task 3.22.

<!-- MARK: - 11. Recommended Architecture -->
## 11. Recommended Architecture

The recommended architecture is metadata-gated copied-workspace migration with V3 destination semantic verification and retained rollback, supported by optional V2-only test evidence.

Production uses:

- Core Data persistent-store metadata reads to identify a Proposed V2 source by exact entity-name and version-hash inventory.
- Store-family discovery to account for the primary SQLite store, WAL, SHM, and unexpected related files.
- Source preservation to copy the complete family to a fresh backup location and verify byte-count and fingerprint identity.
- A fresh copied migration workspace derived from the verified backup, not the active source.
- The approved V2-to-V3 migration path only against that copied workspace.
- V3-only destination opening in the current app target after migration.
- Destination semantic verification using existing and expanded baseline evidence.
- No active-store replacement during Task 3.22; any later replacement requires separate authorization and successful destination verification.
- Permanent or controlled retention of the untouched V2 backup and journal evidence.
- Fail-closed recovery states for any identity, migration, verification, replacement, journal, or retention uncertainty.

This proves:

- The source family matched the expected frozen V2 metadata identity before migration.
- The complete source family was copied and the source did not change during preservation.
- The active source was not used as the migration scratchpad.
- The copied workspace migrated into a V3 store that the current app can open.
- The migrated destination preserved required Legacy-visible counts, identities, relationships, ordering, score evidence, substitution evidence, media evidence, team-creation evidence, and difficult-runner ambiguity evidence to the extent captured by the verifier.
- The five canonical scoring storage models remain empty after migration.
- Failures leave the active source or verified backup available for recovery.

This cannot prove:

- Independent pre-migration semantic readability under an authoritative frozen V2 model.
- That a reconstructed V2 Core Data model would match the historical store.
- That every latent source corruption can be diagnosed before migration.
- That SwiftData's generated Core Data representation is stable across future OS versions.
- That a linked framework or current app target provides V2 runtime isolation.

Required repository additions are documentation and later implementation only after approval:

- A source-identity gate that treats exact V2 metadata and canonical-zero absence as necessary but not sufficient evidence.
- A copied-workspace migration path that never opens or migrates the active source in place.
- A destination verifier that reconciles V3 data and canonical-zero counts.
- Journal and rollback updates that make the redesigned guarantee explicit.
- Fixture and automated-test coverage for the weaker source-read boundary and stronger rollback boundary.
- Optional V2-only test infrastructure for fixture generation and regression proof, with no production routing.

<!-- MARK: - 12. Source Identification and Verification Workflow -->
## 12. Source Identification and Verification Workflow

The production source workflow must classify evidence in this order:

- Discover the active store family through `ScoreKeepStoreFamilyDiscovery`.
- Reject missing primary stores, unexpected unsupported family states, contradictory metadata, stale incomplete targets, nonfresh workspaces, and unsafe production-intended direct construction.
- Read persistent-store metadata through `ScoreKeepProductionStoreMetadataAssessment.assess`.
- Require exact Proposed V2 model-version-hash evidence for the seven V2 entities.
- Require that V3 canonical entities are absent from the source metadata and source inventory.
- Record model identifiers but do not treat identifiers alone as compatibility proof.
- Record store-family fingerprints before preservation.
- Preserve the full source family to a fresh backup directory through `ScoreKeepSourcePreservationExecutor`.
- Verify backup family identity against the pre-copy source family.
- Re-read source-family fingerprints after preservation and reject source changes.
- Record journal evidence for the source identity and backup identity.

This workflow proves source identity and source-family preservation. It does not claim source semantic readability. The user-facing recovery or diagnostic language must reflect that distinction when a V2 migration fails.

Semantic source verification remains unavailable in production until one of these separately approved conditions is met:

- An exact frozen V2 model artifact is obtained and verified.
- A supported production isolation boundary is approved and implemented.
- The redesigned Path C guarantee is accepted as the production requirement for Task 3.22.

<!-- MARK: - 13. Migration and Destination Verification Workflow -->
## 13. Migration and Destination Verification Workflow

Migration must operate only on a copied workspace:

- Copy the verified V2 backup family to a fresh temporary migration target.
- Run the approved migration path against that copied target only.
- Treat any migration error as fail closed and preserve source/backup evidence.
- Never promote a target whose migration, open, or verification state is uncertain.
- Open the migrated target as V3 through the current production V3 container boundary.
- Disable autosave where the repository's migration-verification boundary requires explicit saves.
- Run destination semantic verification before any later authorized active-store replacement.

Destination semantic verification must include:

- V3 store open succeeds.
- V2-origin model counts are preserved or explicitly reconciled.
- Stable identities are preserved for games, teams, players, at-bats, lineups, pitchers, and team-creation evidence.
- Required relationships remain connected or are explicitly classified.
- Batting order, lineup, pitcher, inning, sequence, score, substitution, media, import/export compatibility, and difficult-runner evidence remain consistent with captured baselines.
- Team-creation operation evidence remains intact.
- All five canonical scoring model counts are zero.
- No production scoring event, operation, payload, history, or correction rows are synthesized from Legacy games.
- Purchase, entitlement, allowance, and StoreKit state remain outside the baseball migration.

Destination verification proves destination readability and destination semantic correctness within the repository-defined baseline. It also provides migration compatibility evidence because the copied V2 workspace became a V3 store that passed the verifier. It does not retroactively prove a separate frozen V2 source semantic open.

<!-- MARK: - 14. Backup, Rollback, and Interruption Boundaries -->
## 14. Backup, Rollback, and Interruption Boundaries

The active V2 source family must remain protected until the copied destination has migrated, opened, verified, and recorded completion evidence.

Rollback and interruption boundaries are:

- The active source is never the migration scratchpad.
- The verified source backup is retained before migration begins.
- The journal records operation identity, source classification, source-family identity, backup identity, target schema, migration phase, post-open verification disposition, completion disposition, retry classification, recovery classification, and diagnostic codes.
- Replacement of the active store is atomic and occurs only after destination verification succeeds.
- A completed journal with V3 target evidence may recover by opening the verified V3 target.
- A completed or interrupted journal with V1/V2 target evidence remains fail-closed until the redesigned implementation explicitly supports the Path C recovery boundary.
- Temporary and incomplete targets are never promoted without verification.
- Recovery and manual-review directories are retained according to `ScoreKeepMigrationRetention`.
- Cleanup cannot remove the active source or verified backup.
- Source-family sidecar changes are diagnostic evidence, not permission to continue blindly.

This boundary proves rollback safety and interruption safety. It also limits the harm of losing pre-migration V2 semantic opening: a copied migration failure leaves the original source and verified backup available for future recovery, support diagnostics, or a later exact-model verifier.

<!-- MARK: - 15. Testing and Fixture Strategy -->
## 15. Testing and Fixture Strategy

Task 3.22 completion required direct automated evidence for the redesigned architecture; manual simulator or device evidence remained outside scope because no real or archived historical V2 user store was authorized.

Required fixtures:

- Empty/no-store startup fixture.
- Existing V3 direct-open fixture.
- Frozen V2 metadata fixture with the exact seven-entity version-hash inventory.
- Representative V2 store family fixture with teams, players, games, at-bats, lineups, pitchers, team-creation evidence, media sidecars or external-storage payloads, and difficult-runner or ambiguous scoring evidence where available.
- Interrupted migration fixture or generated scenario with journal and incomplete target state.
- Failed migration fixture or generated scenario that preserves source and backup.
- Contradictory metadata fixture.
- Incomplete store-family fixture.
- Future/unknown schema fixture.
- Canonical-zero verification fixture proving that V3 canonical tables are empty after Legacy migration.

The repository currently has JSON compatibility fixtures but no tracked historical SQLite V2 store fixture. Fixture acquisition is therefore a blocking prerequisite.

Required automated tests:

- Source metadata identity accepts only exact frozen V2 hash and entity inventory.
- Metadata-only evidence is reported as source identity, not source semantic readability.
- V3 canonical entity presence in the source rejects V2 classification.
- Missing primary, incomplete sidecars, unexpected related files, contradictory metadata, future schema, and unreadable metadata fail closed.
- Source preservation copies the complete family, verifies fingerprints, and rejects source changes.
- Migration uses copied workspace URLs, not the active source URL.
- Migration failure preserves active source and verified backup.
- V3 destination open succeeds only after copied-workspace migration.
- Destination record counts, stable identities, relationships, ordering, score, substitution, media, team-creation evidence, and difficult-runner evidence reconcile.
- Canonical history, event, payload, operation, and correction counts remain zero.
- Completed-journal recovery distinguishes verified V3 target, V2 source backup, incomplete target, and uncertain states.
- Repeated startup after success is idempotent.
- Purchase entitlement and allowance state remain untouched.
- Existing fail-closed tests continue to prove that the current V3 target does not construct V2 and V3 together.

Optional supporting tests:

- A V2-only test target can compile only the seven V2 models and minimal verification support to generate or open fixtures.
- That target must be test-only unless a separate production extension architecture is approved.
- The V2-only target must not link V3 canonical models or the V3 migration plan.

Required manual verification:

- Run on a real or archived historical V2 store family obtained from a pre-V3 app build or preserved user-consented fixture.
- Verify source preservation, copied-workspace migration, destination V3 open, canonical-zero counts, rollback after induced failure, and restart after interruption.
- Verify no StoreKit, entitlement, or allowance mutation occurs during baseball migration.

<!-- MARK: - 16. Required Follow-Up Tasks -->
## 16. Required Follow-Up Tasks

These tasks are the smallest bounded prerequisites recommended by this decision. They are cataloged in Document 29 and must be approved before implementation.

Task 3.22B: Frozen V2 evidence and fixture acquisition

- Purpose: obtain authoritative frozen V2 store evidence and representative fixtures.
- Allowed scope: collect exact V2 metadata/hash inventory, source-family fingerprints, privacy-safe V2 SQLite store fixtures or generated archived-build fixtures, and optional V2-only test-target evidence for fixture generation.
- Explicit exclusions: no production startup changes, no production migration, no schema alteration, no Core Data reconstruction claimed as authoritative without fixture proof, no Task 3.23 work.
- Dependencies: Task 3.22A.
- Completion evidence: fixtures and metadata evidence are checked in or documented with reproducible generation steps, and their provenance is recorded.
- Task 3.22 completion prerequisite: yes.
- Task 3.23: remains blocked.

Task 3.22C: Metadata-gated copied-workspace migration boundary

- Purpose: implement the production source-identity and copied-workspace safety boundary selected by this document.
- Allowed scope: source classification, exact V2 metadata gate, canonical-entity absence gate, source-family preservation, copied temporary workspace, journal evidence, and fail-closed dispositions.
- Explicit exclusions: no source semantic V2 open in the V3 app target, no app extension/helper process, no canonical scoring writer, no Legacy scoring retirement.
- Dependencies: Task 3.22B.
- Completion evidence: code review and tests prove active source is not migrated in place and every unsupported source state fails closed.
- Task 3.22 completion prerequisite: yes.
- Task 3.23: remains blocked.

Task 3.22D: V3 destination semantic verification and rollback reconciliation

- Purpose: implement post-migration V3 semantic verification and rollback/recovery evidence.
- Allowed scope: V3 open verification, counts, stable identities, relationships, ordering, score, substitution, media, team-creation evidence, canonical-zero checks, completed-journal recovery, verified-candidate eligibility, retention, and manual-review classification.
- Explicit exclusions: no pre-migration V2 semantic open, no new scoring persistence adapter, no production scoring route.
- Dependencies: Task 3.22C.
- Completion evidence: automated tests prove verified-candidate eligibility only after V3 destination verification and prove rollback after failures; production promotion remains outside Task 3.22.
- Task 3.22 completion prerequisite: yes.
- Task 3.23: remains blocked.

Task 3.22E: Migration acceptance tests and manual verification

- Purpose: prove the selected architecture across normal, failed, repeated, interrupted, and unsupported migration states.
- Allowed scope: automated migration/recovery tests, fixture-based acceptance tests, manual device or archived-store verification, and documented acceptance results.
- Explicit exclusions: no simulator or physical migration outside the approved test procedure, no production routing of canonical scoring, no Task 3.23 adapter.
- Dependencies: Task 3.22B, Task 3.22C, and Task 3.22D.
- Completion evidence: passing automated tests and recorded manual-verification limitation show source preservation, copied migration, V3 destination verification, canonical-zero preservation, rollback, interruption recovery, and purchase separation.
- Task 3.22 completion prerequisite: yes.
- Task 3.23: remains blocked.

Task 3.22F: Temporary duplicate-checksum diagnostic cleanup

- Purpose: remove or permanently fence obsolete V2-plus-V3 hosted diagnostic detours after the selected architecture is implemented and verified.
- Allowed scope: cleanup of unreachable duplicate-producing helpers, retained inventory diagnostics, and tests that document the remaining boundary.
- Explicit exclusions: no behavior cleanup before Tasks 3.22C through 3.22E pass, no deletion of useful source-preservation or metadata diagnostics, no Task 3.23 work.
- Dependencies: Task 3.22C, Task 3.22D, and Task 3.22E.
- Completion evidence: retained tests prove no production or hosted path constructs runtime-effective V2 and V3 schemas together unless a separately approved isolated boundary owns that construction.
- Task 3.22 completion prerequisite: yes.
- Task 3.23: remains blocked.

<!-- MARK: - 17. Risks and Open Questions -->
## 17. Risks and Open Questions

Remaining risks:

- Path C intentionally weakens source semantic verification. It must be described as source identity plus destination verification, not as frozen V2 semantic opening.
- Exact historical V2 version hashes are required. Without real V2 metadata evidence, implementation cannot safely distinguish historical V2 from a lookalike or future schema.
- Destination reconciliation is only as strong as the baselines it captures. Missing relationship, media, lineup, pitcher, or difficult-runner checks would weaken the safety case.
- WAL/SHM and SQLite sidecar behavior cannot be treated as nonmutating during in-place opens. Copied workspaces remain mandatory.
- Future SwiftData or Core Data behavior could change generated hashes or migration behavior. Fixtures and explicit metadata evidence reduce but do not remove this portability risk.
- A V2-only test target can become misleading if it accidentally links V3 models or shared support that constructs V3 schemas.
- An app extension production helper would add new lifecycle and shared-container failure modes if later selected.

Open questions:

- What exact historical V2 store fixture or archived-build process will provide authoritative V2 metadata and representative data?
- Will the implementation use only SwiftData's approved V2-to-V3 migration path on a copied workspace, or will a later approved Core Data artifact change the migration executor?
- Which difficult-runner and Legacy scoring ambiguity fixtures are available from real data rather than synthetic data?
- What retention duration and user-facing recovery path are required for untouched V2 backups after successful migration?
- Should a V2-only test target be mandatory for fixture acquisition, or can archived-build fixture generation provide enough evidence without a target addition?

<!-- MARK: - 18. Task 3.22 Completion Criteria -->
## 18. Task 3.22 Completion Criteria

Task 3.22 may be marked complete only after all of the following are true:

- Task 3.22A is accepted as the architecture decision.
- Task 3.22B provides authoritative frozen V2 metadata evidence and representative fixtures.
- Task 3.22C implements metadata-gated source identity and copied-workspace migration boundaries without opening frozen V2 semantically in the current V3 app target.
- Task 3.22D implements V3 destination semantic verification, canonical-zero checks, verified-candidate eligibility, rollback, and completed-journal recovery for the selected boundary.
- Task 3.22E provides automated acceptance evidence and a recorded manual-verification limitation for success, failure, interruption, retry, rollback, unsupported sources, and purchase separation.
- Task 3.22F removes or permanently fences obsolete duplicate-checksum diagnostics and unreachable detours after the verified-candidate proof exists.
- No retained production or hosted test path constructs runtime-effective V2 and V3 SwiftData schemas together in the current V3 app target.
- Production scoring remains Legacy.
- No production writer synthesizes canonical scoring history for Legacy games.
- Task 3.23 remains blocked until Task 3.22 is complete and verified.

Final review confirms these criteria are met through the approved Path C boundary and Tasks 3.22A through 3.22F. Task 3.22 is complete. Task 3.23 remains blocked until separately authorized.

<!-- MARK: - 19. Task 3.22B Fixture Acquisition Evidence -->
## 19. Task 3.22B Fixture Acquisition Evidence

Task 3.22B acquired one representative synthetic frozen Proposed V2 store-family fixture under `ScoreKeep/Docs/Verification/Fixtures/FrozenV2/RepresentativeSyntheticV2`. Its evidence manifest is `FrozenV2SyntheticEvidence.json`, and its standalone regeneration support is under `ScoreKeep/Docs/Verification/Fixtures/FrozenV2/Support`.

The fixture provenance is commit `91dd5c3fd26301e47f898dfaeedbde9cde35a3d9`, the immediate pre-V3 runtime source inspected for this task. At that commit, `ScoreKeepProposedVersionedSchema` declared V1 and V2 only; V2 declared `Game`, `Team`, `Player`, `Atbat`, `Lineup`, `Pitcher`, and `TeamCreationOperationEvidenceRecord`; no V3 canonical scoring models or V2-to-V3 canonical scoring migration plan were linked into the fixture generator. The generator is committed as `GenerateFrozenV2SyntheticFixture.swift.txt` so it is available for review and regeneration without becoming app-target source.

The committed fixture family contains `FrozenV2Synthetic.sqlite`, `FrozenV2Synthetic.sqlite-shm`, and `FrozenV2Synthetic.sqlite-wal`. The manifest records exact Core Data persistent-store model-version hashes, store version identifier `2.0.0`, SHA-256 digests and byte counts for every family member, expected V2 record counts, expected relationship facts, and zero expectations for all five V3 canonical scoring models.

The fixture data is deterministic and synthetic. It contains synthetic team, player, game, at-bat, lineup, pitcher, replacement, and team-creation operation evidence values only. No real production store, simulator store, protected recovery backup, personal application data, device identifier, account identifier, secret, credential, signing material, real team history, or real game history was used.

This evidence supports Tasks 3.22C through 3.22E for metadata-gated source identity, store-family preservation, copied-workspace migration, fixture rollback/interruption tests, and destination canonical-zero verification. It does not prove independent pre-migration source semantic opening inside the current V3 app target, and it must not be used to justify constructing runtime-effective V2 and V3 SwiftData schemas together in the current hosted target.

Task 3.22B is accepted as completed prerequisite evidence for Tasks 3.22C through 3.22F and final Task 3.22 completion. Task 3.23 remains blocked, production scoring remains Legacy, and no production writer synthesizes canonical scoring history for Legacy games.

<!-- MARK: - 20. Task 3.22C Implementation Boundary -->
## 20. Task 3.22C Implementation Boundary

Task 3.22C implements the metadata-gated copied-workspace boundary selected by this document. Production V2 qualification now requires exact Core Data persistent-store metadata for the frozen seven-entity Proposed V2 inventory, including exact entity count, exact entity names, exact version-hash bytes from the Task 3.22B manifest, store version identifier `2.0.0`, and absence of the five V3 canonical scoring model names. V1, V3, missing, altered, extra, unknown, unreadable, malformed, and unsupported metadata remain distinct fail-closed outcomes.

The production boundary preserves the complete discovered source store family before migration work, verifies the preserved backup by file identity, creates an operation-scoped copied workspace from the verified backup, and runs the candidate V3 construction only against that copied workspace. The active source and retained backup are not used as migration scratchpads, are not promoted, and are not replaced by Task 3.22C.

The migration journal now records explicit copied-workspace phases: `workspaceCreationStarted`, `workspaceVerified`, and `destinationVerificationPending`. Retry preserves the same operation identity, reuses an already verified backup, and deterministically recreates incomplete copied workspaces under the operation target directory. A V2 candidate that opens as V3 stops at `destinationVerificationPending` with `pendingTask3.22D`; no completion, write-readiness, active-store replacement, canonical history synthesis, or Legacy scoring retirement is claimed.

Destination semantic reconciliation, canonical-zero proof after migration, rollback reconciliation, acceptance evidence, temporary diagnostic cleanup, and final Task 3.22 review were deferred to and completed by Tasks 3.22D through 3.22F and final review. Atomic production replacement and completed-journal promotion remain outside the accepted Task 3.22 boundary. Production scoring remains Legacy, and Task 3.23 remains blocked.

<!-- MARK: - 21. Task 3.22D Destination Verification Boundary -->
## 21. Task 3.22D Destination Verification Boundary

Task 3.22D implements the post-migration destination verification boundary without promoting the candidate to production. The verifier opens only the operation-scoped copied V3 candidate through the current V3 schema, then requires exact V3 persistent-store metadata evidence for the seven migrated Legacy model responsibilities plus the five canonical scoring storage model responsibilities. Successful container construction alone remains insufficient.

Verification reconciles the candidate against supplied pre-migration baseline facts for Legacy record counts, stable identity fingerprints, relationship fingerprints, ordering fingerprints, score evidence, substitution evidence, media ownership evidence, team-creation operation evidence, and source and backup store-family identities. The boundary does not recapture a V2 source baseline from the migrated candidate and does not semantically open the protected V2 source in the current V3 app target. If approved source-baseline facts are missing, verification fails closed as unsupported verification evidence.

Canonical-zero verification explicitly checks `CanonicalGameHistoryRecord`, `CanonicalScoringEventEnvelopeRecord`, `CanonicalScoringEventPayloadRecord`, `CanonicalScoringOperationEvidenceRecord`, and `CanonicalScoringCorrectionRecord`. Only model-present-with-zero-records qualifies. Missing or unreadable canonical evidence and unexpected canonical rows fail closed; no canonical records are deleted, synthesized, or repaired by this task.

The migration journal now distinguishes destination verification in progress, V3 metadata verified, Legacy reconciliation verified, canonical-zero verified, destination verification succeeded, destination verification failed, candidate eligible for later acceptance, and rollback still available. Failure classifications include unreadable candidate, metadata mismatch, count mismatch, identifier mismatch, relationship mismatch, unexpected canonical records, missing canonical model evidence, source or backup immutability mismatch, journal inconsistency, unsupported verification evidence, and interrupted verification.

A successful Task 3.22D result marks the candidate destination verified and eligible for later acceptance only. The active V2 source and retained V2 backup remain unchanged, rollback remains retained, normal production replacement is not performed by this task, production scoring remains Legacy, Tasks 3.22E and 3.22F provide the remaining acceptance and diagnostic-cleanup evidence, and Task 3.23 remains blocked.

<!-- MARK: - 22. Task 3.22E Migration Acceptance Evidence -->
## 22. Task 3.22E Migration Acceptance Evidence

Task 3.22E adds acceptance-level automated tests to the existing frozen V2 fixture evidence suite. The tests use the committed Task 3.22B synthetic frozen V2 store family only by copying all family members into isolated temporary directories. They do not mutate the checked-in fixture, production stores, simulator application data, protected recovery backups, StoreKit state, entitlement state, allowance state, schemas, scoring authority, or project schemes.

The primary acceptance scenario starts from a copied frozen V2 fixture, qualifies exact V2 metadata, confirms the discovered source family, preserves the source family, constructs the V3 candidate only from the operation-scoped copied workspace, captures approved destination baseline evidence, resumes with the same operation identity, verifies exact V3 destination metadata, reconciles Legacy counts and baseline fingerprints, confirms all five canonical scoring models have zero rows, and leaves the candidate unpromoted. The resulting journal reaches `destinationVerificationSucceeded` with `candidateEligibleForLaterAcceptance`; writes remain prohibited, rollback remains available from the verified V2 backup, the source copy remains V2, the retained backup remains V2, and the candidate remains V3.

The acceptance failure coverage verifies missing, altered, extra, wrong-version, V1, V3, unknown, malformed, unreadable, and unsupported metadata boundaries before source migration; preservation semantic mismatch; container construction failure; interrupted destination verification; recovery classifications for destination verification pending, interrupted, verified-but-unpromoted, failed verification with retained candidate, missing or invalid candidate, mismatched operation evidence, and repeated blocked states. The coverage also confirms existing clean V3 metadata remains a no-migration source state rather than a V2 migration path.

The duplicate-checksum safety audit confirms the selected acceptance path and production candidate construction do not build a hosted V2 schema, do not pass the V2-to-V3 migration plan through a current-target construction, and continue to rely on the V3-only copied-workspace candidate opening. Existing blocker tests continue to assert that hosted current-target V2-plus-V3 construction remains fenced.

Manual simulator or device verification was not performed for Task 3.22E. The only available committed source is synthetic fixture evidence, and no approved procedure in this task authorizes placing the fixture into active user application data or launching against the user's simulator data. The explicit manual evidence boundary therefore remains unclaimed until a separately approved disposable active-container procedure or real archived historical V2 store family is available.

Task 3.22E does not authorize candidate promotion, active-store replacement, retained-backup deletion, canonical scoring writes, Legacy scoring retirement, or Task 3.23. Task 3.22E is accepted as prerequisite evidence for Task 3.22F and final Task 3.22 review. Production scoring remains Legacy, and no production writer synthesizes canonical scoring history for Legacy games.

<!-- MARK: - 23. Task 3.22F Duplicate-Checksum Diagnostic Cleanup -->
## 23. Task 3.22F Duplicate-Checksum Diagnostic Cleanup

Task 3.22F cleans up temporary duplicate-checksum investigation scaffolding after Tasks 3.22C through 3.22E established the selected migration boundary and automated acceptance evidence. The cleanup does not change V1, V2, or V3 schema declarations; does not promote a candidate store; does not route canonical scoring; does not synthesize canonical scoring history; and does not retire Legacy scoring.

Retained diagnostics are bounded to supported evidence: exact Core Data persistent-store metadata, model-version-hash inventory, source-family discovery, source preservation, copied-workspace migration evidence, V3 destination verification, rollback and recovery journal state, sanitized Core Data/SQLite error classification, and fixture digests. These diagnostics identify source and destination boundaries but do not claim that the current V3 app target can semantically open frozen V2.

Removed or reduced temporary scaffolding includes launch-only schema diagnostic prints, `ScoreKeepApp` ownership of schema/migration diagnostic internals, wording that implied a hosted V2-to-V3 migration attempt, and the physical migration comparison branch that reported the duplicate-checksum blocker whenever a retained backup was present. The comparison now metadata-checks the retained backup as frozen V2 and opens only the copied V3 target for baseline comparison.

Legacy compatibility states remain for `semanticVerifierUnavailable.currentTargetV2AndV3DuplicateEffectiveChecksums` and blocked V1/V2 recovery helpers. They are retained because interrupted development journals and fail-closed recovery presentations may still need to decode or report those states, but they are not active successful migration behavior and do not construct V2 and V3 together.

The final supported boundary remains metadata-gated copied-workspace migration with V3 destination semantic verification, canonical-zero checks, unchanged source and backup evidence, rollback retention, and write prohibition until later approval. Final review accepts exact metadata identity, source preservation, copied migration, V3 semantic reconciliation, canonical-zero verification, and rollback as the safety substitute for the unavailable independent frozen V2 semantic open. Task 3.22 is complete with the candidate destination verified and eligible for later acceptance but not promoted or production-routed. Task 3.23 remains blocked, production scoring remains Legacy, and no production writer synthesizes canonical scoring history for Legacy games.

<!-- MARK: - 24. Task 7.7B V4 Compatibility Boundary -->
## 24. Task 7.7B V4 Compatibility Boundary

Task 7.7B adds `ScoreKeepProposedVersionedSchema.V4` with version identifier `4.0.0` after the frozen V3 boundary. V3 remains unchanged at exactly 12 models: the six Legacy baseball models, `TeamCreationOperationEvidenceRecord`, and the five canonical scoring storage models. V4 contains all 12 V3 responsibilities plus exactly one new model, `LegacyScoringOperationEvidenceRecord`, for a final 13-model inventory.

The V4 addition does not reopen the resolved V2/V3 duplicate-checksum failure mode. V1 and V2 declarations remain unchanged. V3 is not modified in place. The existing frozen V2 metadata-gated copied-workspace migration and V3 destination verification boundary remain valid for Task 3.22 evidence, and V2/V3 hosted construction remains fenced.

The V3-to-V4 migration is lightweight and creates no historical Legacy scoring-operation evidence rows. Existing Legacy facts, team-creation evidence, media and ordering behavior, and canonical scoring rows are preserved as existing rows. The migration performs no canonical backfill and no Legacy scoring-history backfill. Destination verification and baseline comparison now include the Legacy scoring-operation evidence count so unexpected rows fail closed where that evidence is part of the verification boundary.

The Task 7.7B completion correction routes production persistence to V4 without weakening the frozen V2 source-preservation policy. V3 remains a frozen source and compatibility schema, production container construction targets V4, supported V3 stores migrate to V4 through copied-workspace migration, V4 destination metadata is verified exactly, existing V4 stores open directly, and unsupported sources still fail closed with rollback/source evidence preserved.

Task 7.7B provides a production-compiled but non-routed adapter and fresh-context lookup for future Legacy duplicate-prevention integration. It does not route ordinary scoring to Legacy operation evidence, does not route ordinary scoring to canonical replay, does not activate canonical scoring writes, and does not retire Legacy persistence. Production scoring remains Legacy, Task 7.7 is unblocked but not started, and Task 7.8 has not begun.

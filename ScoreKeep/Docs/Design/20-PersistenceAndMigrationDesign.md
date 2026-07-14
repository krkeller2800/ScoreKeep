# ScoreKeep Technical Design — 20 Persistence and Migration Design

## 1. Purpose

Persistence and migration require a dedicated design because the rewritten ScoreKeep architecture must protect user-owned records while changing how baseball meaning is represented and interpreted. The rewrite cannot assume that cleaner canonical concepts make existing SwiftData records, `.ScoreKeep_Players` files, `.ScoreKeep_Games` files, seeded data, media, reports, preferences, or purchase-related state disposable.

The current application carries persistence risks that affect migration safety. Legacy SwiftData records can combine current roster data and historical participation. SwiftUI views directly read and mutate persistence objects. Relationships may be incomplete or ambiguous. Identity is sometimes inferred from names. Some workflows carry fixed-size assumptions. Stored scores may disagree with replay-derived scoring. Lineups may not round-trip fully. Substitutions are represented through parallel arrays. Pitcher markers and aggregate totals can mix recorded evidence with derived values. Photos and logos are stored with baseball records. Imported legacy and malformed records may still contain user-owned evidence. App upgrades must account for unknown existing user data instead of assuming a clean install.

The purpose of this design is to preserve user-owned data while allowing the rewritten canonical domain and scoring engine to replace legacy behavior incrementally. It defines persistence responsibilities, migration guarantees, transaction boundaries, compatibility adaptation, validation, repair, and recovery behavior. It does not define concrete SwiftData declarations, production migration code, database transactions, Swift types, fixtures, tests, or implementation scaffolding.

## 2. Persistence Principles

User data preservation takes priority over internal cleanup. Existing records remain readable before destructive transformation. Migrations must not silently invent baseball facts. Stable identity must be preserved or assigned safely. Historical participation must remain understandable. Recorded facts and derived projections remain separate. Migration is version-aware and fixture-backed. Failed migration preserves a recoverable prior state.

Storage implementation must not leak into SwiftUI views. Compatibility evidence must not be discarded merely because it is not canonical. Preference reset and purchase state must not affect baseball records. No big-bang migration is required.

Physical storage shape may differ from canonical domain shape. A legacy record can remain physically unchanged while a compatibility adapter interprets it into canonical game input. A future store can persist canonical facts more directly without requiring every old record to be transformed at launch.

## 3. Persistence Responsibilities

The persistence layer is responsible for reading existing records, writing accepted changes, preserving stable identity, loading complete canonical game input, maintaining event order, preserving relationships, preserving historical snapshots, storing unknown and unsupported compatibility evidence, storing migration status and warnings where needed, preserving media references or media data, supporting safe deletion and archival, providing explicit transaction outcomes, preventing unintended partial writes, supporting application restart and recovery, and supporting later export and compatibility adaptation.

Persistence does not own baseball scoring rules, report calculations, current score calculation, UI presentation, navigation, purchases, file selection, entitlement decisions, or conflict-resolution policy presentation. Those responsibilities belong to the scoring engine, report services, application services, presentation, purchase services, document workflows, and user-facing review workflows.

## 4. Existing Data Inventory

Migration must account for reusable teams, reusable players, games, at-bats or scoring rows, lineups, pitchers, replacement and incoming-player relationships, stored home and visiting scores, photos, logos, sample or seeded data, settings and preferences, announcements and dismissal state, purchase-related state, free-use counters, imported files, exported compatibility files, historical and completed games, and incomplete and interrupted games.

Baseball records include teams, players, games, lineups, scoring rows, pitcher participation, substitutions, historical snapshots, media attached to teams or players, and compatibility evidence needed to explain those records. Preferences include sorting, filtering, display choices, paste mappings, report display options, announcement dismissal, sample-data state, and other non-baseball settings. Licensing state includes current-season entitlement, prior-season entitlement, restore status, and free-use counters. Generated output includes PDFs, reports, exported files, screenshots, and temporary previews. Temporary UI state includes navigation selections, sheet state, and transient form choices.

This design does not claim every category currently uses the same storage technology. Each category must be inventoried from repository evidence before implementation chooses a migration path.

## 5. Persistence Boundary

The canonical domain defines baseball meaning. Persistence stores enough facts and evidence to reconstruct that meaning. Compatibility adapters interpret legacy storage and transport records. Application services coordinate accepted writes and transaction boundaries. The scoring engine consumes canonical facts and does not directly depend on legacy persistence objects. SwiftUI views consume prepared application state and do not directly decide migration or repair behavior.

This boundary allows legacy records to remain physically unchanged while being interpreted canonically during early migration phases. A legacy `Game`, `Atbat`, `Lineup`, or `Pitcher` record can be read, adapted, classified, and replayed without changing the stored row. Later physical migration can persist canonical facts after fixture-backed acceptance proves the interpretation is safe.

## 6. Record Identity Preservation

Valid legacy team UUIDs, player UUIDs, and game UUIDs should be preserved. Scoring-event identifiers should be preserved when available. When legacy identity is absent, malformed, duplicated, or unreliable, migration should assign stable local identity and keep the original compatibility identifier separate from canonical identity.

Name-only matching is not safe. Duplicate player names, duplicate team names, reused jersey numbers, doubleheaders, same teams on the same date, imported detached participants, unknown teams and players, guest players, and temporary players must remain distinguishable. Migration must never silently merge records merely because names, numbers, teams, dates, locations, or roster positions match.

Compatibility identifiers are evidence, not automatic authority. A decoded legacy identifier can support a match when it is valid and consistent with the record being interpreted. If evidence conflicts, the record should be classified for warning, repair, or conflict resolution rather than merged.

## 7. Complete Game Persistence Unit

One game can be interpreted coherently only when the persistence layer can load the complete game input: game identity and settings, lifecycle state, home and visiting game-side participation, game-time team snapshots, game participants, game-time player snapshots, starting lineups and batting slots, substitutions, pitcher appearances, ordered scoring events, runner outcomes, RBI and earned-run decisions, notes, completion or interruption decisions, compatibility evidence, migration warnings, media references where needed, stored-score evidence, and provenance.

Loading only a `Game` row without dependent facts is not enough for canonical replay. The scoring engine needs the full ordered context that explains who played, who batted, who pitched, what happened, what was derived, what was imported, and what remains uncertain.

## 8. Recorded Facts and Derived Values

Recorded facts may be persisted. Derived values should normally be recomputed by the scoring engine. Recorded facts include game settings, teams, participants, lineup decisions, substitutions, pitcher appearance boundaries, scoring events, runner outcomes, RBI and earned-run decisions, notes, lifecycle decisions, provenance, and compatibility evidence.

Derived values include score, inning totals, outs, runners, current batter, next batter, hits, errors, batting totals, pitching totals, reports, box scores, scorecards, PDFs, and game-list summaries. Derived-value caching may be used for performance, but cached projections must be invalidatable, reconcilable, and never treated as independent authority.

Legacy `hscore` and `vscore` should be preserved as compatibility or reconciliation evidence where needed. When they agree with replay-derived scoring, they can increase confidence. When they disagree, the mismatch is a migration warning, repair question, or compatibility limitation rather than proof that either source should be silently discarded.

## 9. Historical Snapshot Strategy

Historical games must remain understandable after a team rename, player rename, jersey-number change, position change, batting-direction change, player transfer, team roster change, player deactivation, team archive, photo replacement, logo replacement, or reusable-record deletion where allowed.

Persistence should preserve game-time text identity for teams and participants: team name, side role, player name, jersey number, batting direction, position, and any other display facts required to understand a report, scorecard, export, or correction. These snapshots protect history from current roster edits.

Photos and logos may be represented as current-record references, optional game-time snapshots, export-time choices, or compatibility evidence. The final media snapshot policy remains open. The minimum requirement is that historical participant and team identity remains readable even if current photos or logos are replaced, removed, invalid, or unavailable.

## 10. Migration Stages

Migration should proceed in stages: inventory and baseline verification; legacy read-only interpretation; canonical in-memory adaptation; warning and compatibility classification; rewritten reads using canonical projections; rewritten writes for bounded workflows; persistence of canonical facts; background or explicit migration where appropriate; verification against legacy and canonical fixtures; routing replacement; legacy write retirement; and legacy storage cleanup only after acceptance.

Each stage can be introduced without transforming every existing record immediately. Read-only interpretation proves that legacy records can be understood. In-memory adaptation proves canonical meaning before storage changes. Bounded canonical writes limit risk to accepted workflows. Physical migration can wait until fixtures, reports, exports, and recovery behavior show that the canonical path preserves supported meaning.

## 11. Read Compatibility Before Physical Migration

Legacy records can be read through adapters before schema changes. Adapters translate legacy `Game`, `Team`, `Player`, `Atbat`, `Lineup`, and `Pitcher` records, reconstruct substitutions, reconcile scores, preserve result strings, preserve unsupported values, classify missing references, retain media, and identify warnings.

The adapter should produce either a canonical interpretation or an explicit failure classification. It must not mutate legacy records merely by reading them. Reading a report, opening a game, previewing an import, or building a canonical projection should never become an implicit destructive migration.

## 12. Canonical Write Strategy

New rewritten workflows should persist accepted facts coherently when creating teams, creating players, creating games, setting lineups, recording plays, recording runner outcomes, recording substitutions, recording pitcher appearances, correcting events, changing lifecycle state, importing compatible records, replacing media, deleting or archiving records, changing preferences, or changing purchase-related state.

A canonical write should either complete coherently or leave the prior persisted state intact from the user's perspective. The design does not prescribe concrete database transactions or APIs. It requires application services to define the accepted fact set, validation result, persisted outcome, and recovery behavior for each write.

## 13. Transaction Boundaries

Conceptual transaction boundaries are required for high-risk workflows: creating a complete record, completing a plate appearance, applying runner outcomes, changing pitcher, recording a substitution, applying a correction, replacing a lineup, importing a roster, importing a game, resolving conflicts, deleting a game, deleting or deactivating a player, replacing media, migrating one game, and migrating a collection.

Atomicity is defined from the user's perspective. A plate appearance must not save the run but lose the out. A runner outcome write must not advance one runner and lose the batter destination. A substitution must not save the incoming player but lose the outgoing relationship. A pitcher change must not create an active pitcher without the effective boundary. An import must not leave an unexplained partially merged roster. A correction must not update reports while leaving the underlying event unchanged.

## 14. Write Failure Behavior

Write failures include validation failure before write, write failure before any change, write failure after partial internal work, storage unavailable, storage full, app interruption during write, device restart, migration interruption, imported file disappearance, media write failure, failed derived-cache update, and failed cleanup after successful canonical write.

The user-visible prior state must remain usable. If a partial result can exist internally, it must be detectable and recoverable rather than presented as complete. Failed derived-cache updates should not invalidate the accepted recorded facts. Failed cleanup after a successful canonical write should be diagnosable and retryable without rolling the application into an incoherent baseball state.

## 15. Migration Versioning

Migration and interpretation need identifiable versions. Relevant versions include storage version, canonical interpretation version, compatibility adapter version, migration outcome version, fixture expectation version, and report or projection regeneration version after interpretation changes.

The app must know whether a record has not been examined, is legacy readable, has canonical interpretation, has warnings, has been physically migrated, needs repair, is compatibility-only, was rejected, or was created by a newer unsupported version. This design does not prescribe version-number formats or SwiftData migration APIs. It requires migration status to be explicit enough that launch, reports, exports, support diagnostics, and future releases do not guess.

## 16. Migration Outcomes

Migration outcomes should be explicit: unchanged legacy record, successfully interpreted, fully migrated, migrated with warnings, partially understood, repair required, conflict resolution required, compatibility-only preservation, unsupported future record, corrupted and rejected, migration failed safely, and user canceled migration or repair.

An unchanged legacy record remains readable through legacy or compatibility paths. A successfully interpreted record can be projected canonically without physical migration. A fully migrated record can be read as canonical facts. A warning is not a failure when the record remains understandable. A partially understood record may allow limited display or export with limitations. Repair-required and conflict-resolution-required records remain preserved but need review before trusted replay. Compatibility-only records preserve evidence without claiming complete canonical meaning. Unsupported future records and corrupted records should avoid unsafe mutation. Failed or canceled migration must preserve a recoverable prior state.

## 17. Migration Warnings and Diagnostics

Migration diagnostics should be product classifications, not raw technical errors. Categories include score mismatch, duplicate team identity, duplicate player identity, missing participant, missing team, third-team game reference, incomplete lineup, missing lineup player list, unsupported result, legacy sacrifice spelling, ambiguous substitution, overlapping pitcher appearances, invalid inning encoding, duplicate event sequence, invalid media, missing media, incomplete stored relationships, and malformed optional values.

Diagnostics must preserve enough context for review without exposing unrelated records. A warning should identify the affected record, the affected field or baseball concept, and the consequence for replay, report, export, or repair. User-facing presentation should translate diagnostics into understandable review language rather than exposing storage exceptions or implementation names.

## 18. Repair Strategy

Repair is an explicit operation separate from reading. Repairs may assign a missing participant, assign a missing team, choose between duplicate records, preserve records separately, correct event order, correct lineup membership, pair substitution participants, select a pitcher period, accept or replace stored scores, map an unsupported result, remove invalid optional media, reconstruct game-time snapshots, or mark a record compatibility-only.

Repairs must be scoped, reviewable, reversible or recoverable where practical, and verified by fixtures. Opening a report or game must not silently perform a destructive repair. A repair should state what evidence is being changed or classified, what original evidence remains preserved, and which projections must be regenerated.

## 19. Legacy Score Reconciliation

Legacy `hscore` and `vscore` should be stored or preserved as original compatibility evidence where necessary and compared with scoring-engine replay. Agreement means the stored evidence and replay-derived score align. Mismatch may indicate incomplete event history, stale totals, an imported historical game, a user-authored final score, incomplete runner reconstruction, or a migration interpretation defect.

Complete coherent event history should control derived scores. When event history is incomplete, ScoreKeep should preserve both the stored score evidence and the limitation. Reports and exports should identify whether the score is replay-derived, stored compatibility evidence, or a reviewed user-authored final score. Physical migration should preserve enough evidence for later corrections and reconciliation.

## 20. Lineup Migration

Lineup migration must preserve starting lineups, Everyone Hits flag, batting order, `Player.batOrder` evidence, missing exported lineup player lists, bench players, duplicate slots, unknown players, late participants, lineup changes before scoring, lineup changes after scoring, substitution-driven slot history, and imported lineups.

`Player.batOrder` may be a setup hint or compatibility value, but game-time batting order is a game fact. Lineup changes before scoring can be setup revisions. Lineup changes after scoring are historical events or corrections. Migration must not invent lineup membership when legacy evidence is missing. Incomplete lineup history should be classified explicitly so scoring, reports, and exports know whether batting progression is verified or limited.

## 21. Substitution Migration

Substitution migration must interpret `Game.replaced`, `Game.incomings`, special result strings or markers, pinch hitters, pinch runners, defensive replacements, pitcher changes, ordering and timing, batting-slot relationship, mismatched array counts, missing participants, ambiguous roles, and corrected substitutions.

Substitution history can be reconstructed when incoming and outgoing participants, side, effective timing, and role can be understood consistently with scoring events and lineup state. If the evidence lacks timing, role, participant identity, or array alignment, the data should remain warning, repair-required, or compatibility-only evidence. Migration must not convert ambiguous parallel arrays into misleading canonical substitution facts.

## 22. Pitcher Migration

Pitcher migration must preserve pitcher identity, team, start inning, start out, start batter, end inning, end out, end batter, aggregate strikeouts, walks, hits, runs, win marker, unknown pitcher state, missing player references, overlapping periods, incomplete periods, and disagreement with scoring events.

Appearance boundaries are recorded evidence. Aggregate pitching totals are derived or reconciliation values where appropriate. A pitcher period that can be aligned with event order can become canonical appearance evidence. Overlapping, incomplete, or contradictory periods should produce warnings or repair requirements. Missing player references should create unknown or detached pitcher participation rather than silently attaching to the wrong player.

## 23. Scoring Event Migration

Legacy `Atbat` rows migrate into canonical scoring-event evidence. Relevant values include batter, team, result, `maxbase`, `outAt`, inning, half inning reconstruction, sequence, column, RBIs, outs, stolen bases, sacrifice values, earned-run flag, notes or `playRec`, `endInning`, placeholder rows, substitution markers, duplicate scoring rows, missing participant references, unsupported results, and incomplete runner movement.

Not every legacy row may map one-to-one to a fully canonical play without warnings. Some rows may represent plate appearances, substitutions, placeholders, runner evidence, scorecard presentation, or unsupported compatibility values. Migration should preserve original evidence, map supported values conservatively, and classify incomplete runner movement or unsupported results.

## 24. Runner-State Reconstruction

Runner-state reconstruction may use batter destination, runs inferred from `Home`, prior base occupancy, runner advancement evidence, outs, steals, pinch runners, end-of-inning markers, missing runner identity, multiple runner movement, impossible occupancy, corrections, and incomplete records.

Reconstruction must be conservative. If runner movement cannot be determined safely, ScoreKeep should preserve the event and mark the resulting projection incomplete rather than inventing movement. Impossible occupancy, missing runner identity, or contradictory outs should become warnings, repair requirements, or rejected replay state depending on severity.

## 25. Media Persistence and Migration

Media handling must account for player photos, team logos, imported base64 media, missing media, invalid media, oversized media, replacement, removal, historical reports, export, detached imported records, and migration failure.

Media failure must not make baseball facts unusable. Invalid, missing, oversized, or failed media can be warned, skipped, replaced, or repaired while preserving teams, players, games, and scoring evidence. Media migration must not silently attach an image to the wrong player or team. This design does not define image compression algorithms, storage APIs, or concrete media folders.

## 26. Deletion, Deactivation, and Archival

Persistence must distinguish deleting a draft record, deleting a completed game, deactivating a player, removing a player from a roster, deleting a reusable player, archiving a team, deleting a reusable team, preserving historical game participants, removing photos or logos, clearing preferences, and deleting sample data.

Historical references must remain readable. Deletion must be scoped and confirmed by application workflows. Persistence should reject or classify unsafe deletion rather than cascading silently through unrelated history. A reusable player can be removed from current roster lists without erasing that player from completed game participation. Clearing preferences must not delete baseball records.

## 27. Import Persistence Boundary

The import pipeline should decode without changing local records, validate, adapt to canonical evidence, identify conflicts, allow user resolution, summarize intended changes, persist accepted records coherently, report completion or failure, and preserve provenance and warnings.

Roster imports and full-game imports both follow this boundary. Cancellation before confirmation leaves local records unchanged. Confirmed import should create or update only the accepted teams, players, games, media, and compatibility evidence. Missing references, duplicate identities, malformed values, and unsupported results should be classified before persistence rather than discovered through partial writes.

## 28. Export Persistence Boundary

Exports should read canonical records without modifying them. Export consumes a coherent canonical game or roster projection plus compatibility evidence required by the selected format.

Export must not repair records silently, mutate identity, change local media, change stored scores, alter purchase state, consume unrelated allowances, modify historical records, or persist generated report output as baseball truth. Records with warnings or unsupported values may export with limitations, compatibility evidence, or user review depending on the format. Export failure should not change the source record.

## 29. Purchase and Preference Separation

Purchase state, free counters, and preferences remain outside canonical baseball persistence. This includes current-season entitlement, prior-season entitlement, free game allowance, free roster-download allowance, purchase uncertainty, restore status, sorting, filtering, paste mappings, report display choices, announcements, and sample-data state.

Changing or resetting these values must not modify teams, players, games, lineups, scoring events, media, or reports. Baseball migration must not reset or fabricate purchase state or allowances. Purchase uncertainty may affect which actions are available, but it must not damage existing baseball records.

## 30. Seeded and Sample Data

Seeded-game and sample-data behavior must account for first-launch detection, duplicate prevention, identifying sample origin, importing or creating seeded data once, app updates, user deletion, onboarding reset, compatibility fixture role, migration alongside user data, and avoiding recreation without user intent.

The checked-in seeded game should remain a canonical compatibility fixture. It should be migrated or interpreted alongside user data without receiving special rules that hide compatibility defects. If a user deletes sample data, launch behavior should not recreate it unless the user intentionally resets onboarding or asks for sample restoration. This task does not inspect or alter seeded data.

## 31. App Update and Launch Behavior

Launch behavior should detect storage state, identify migration or interpretation need, preserve local access where safe, perform safe read adaptation, defer risky repair, show progress when noticeable, recover after interruption, avoid repeated migration loops, avoid duplicate sample import, keep local scoring available when unaffected, and distinguish optional migration warnings from launch-blocking corruption.

Launch should not prescribe a specific launch-screen UI. Conceptually, ordinary readable records should remain accessible. Records that require review can be marked for repair. Shared storage failures or corruption that prevents safe access may block only the affected workflows where possible.

## 32. Interruption Recovery

Migration recovery must handle app backgrounding, app termination, device restart, low storage, system update, interrupted import, interrupted canonical write, interrupted media migration, interrupted batch migration, and process failure after some records complete.

Migration progress can be recorded conceptually so completed records are not duplicated and incomplete records can be retried safely. A checkpoint may identify a record as not started, in progress, completed, failed safely, or needing review. This design does not specify concrete checkpoint storage. The requirement is that interruption does not leave users with duplicate records, unexplained partial imports, or inaccessible prior state.

## 33. Batch Migration Strategy

Batch migration should process one record at a time where possible, use deterministic order, isolate independent failures, report progress, support cancellation where safe, allow retry, preserve records with warnings, preserve records requiring user repair, preserve unprocessed records, avoid all-or-nothing migration when unnecessary, and maintain atomicity where related records must move together.

A failed historical game should not prevent unrelated valid teams and games from remaining usable unless a shared storage failure affects everything. Related facts that make one game coherent should be migrated as a unit, while unrelated teams, games, rosters, and media should not be held hostage by one malformed record.

## 34. Coexistence With Legacy Writes

Legacy and new code may coexist during replacement. The design must account for legacy reads, legacy writes, canonical reads, canonical writes, dual interpretation, routing boundaries, report comparison, feature-specific replacement, preventing two writers from producing incompatible facts, avoiding duplicated records, deciding when a legacy writer must be retired, and compatibility-only adapters.

Uncontrolled dual-write behavior should be avoided. If temporary dual-write is later used, it must have an explicit reconciliation and verification policy. A workflow should have one accepted writer for each fact set, with routing changed only after the canonical path satisfies fixtures, reports, exports, and recovery requirements.

## 35. Observability and Supportability

Migration status should be diagnosable without exposing sensitive data. Useful support context may include app version, record type, migration classification, warning category, compatibility format, visible file name, record count, whether local data changed, and whether retry is safe.

Users should not be required to provide full rosters, game files, photos, or purchase information unless voluntarily needed for support. Diagnostic behavior must not alter records. Support summaries should identify affected records and warning categories without exposing unrelated players, youth information, media, or purchase credentials.

## 36. Security and Privacy

Migration should be local-first. Import is deliberate. Export is deliberate. No unnecessary upload should occur. Media handling must account for photos, logos, youth-player information, support data minimization, preserving original files when practical, avoiding unrelated record exposure, scoped repair review, no purchase credential collection, and deletion limitations for files already shared outside the device.

Migration and repair screens should identify only the affected records and required context. A repair for one roster should not reveal unrelated teams. A media repair should not upload or disclose images unless the user explicitly chooses a sharing or support path.

## 37. Performance and Scale

Launch should not be blocked unnecessarily. Ordinary records should load promptly. Large historical databases should remain manageable. Long games should remain replayable. Large rosters should remain usable. Media should not block baseball migration. Batch migration should show progress if noticeable. Cancellation and retry should be safe. Optimization must not weaken recoverability. Migrations should avoid repeatedly reprocessing verified records.

This design does not invent unsupported hard limits. Scale expectations should be verified with fixtures and representative local data before implementation sets product limits.

## 38. Verification Strategy

Persistence and migration require fixture-backed verification for the seeded game, minimal roster, full roster with media, duplicate-name roster, duplicate-number roster, malformed roster, regulation completed game, in-progress game, extra-inning game, large-lineup game, substitution-heavy game, pitcher-change-heavy game, correction game, missing participant, missing team, third-team game, stored-score mismatch, missing lineup players, invalid media, unsupported result, `Sacrifise` compatibility, duplicate scoring event, interrupted migration, failed write, and round-trip export.

Verification should compare legacy interpretation, canonical interpretation, scoring-engine result, reports, export meaning, warnings, and migration outcome. A record should not be accepted as migrated merely because it decodes. It must preserve baseball meaning, identity, warnings, and recovery behavior.

## 39. Release and Rollback Strategy

Rewritten persistence should be introduced incrementally. Existing records should be backed by compatibility adapters. Migration acceptance should precede legacy retirement. Failure should be isolated. Routing should be reversible where practical. Original records or evidence should be preserved. Irreversible destructive migration should be avoided before verification. A recovery release should be possible if a migration defect is found. Known data-loss risk should block release. Active legacy and new persistence paths should be documented.

This design does not define App Store deployment mechanics or Git branch policy. It defines release safety in product terms: supported records remain readable, failures are recoverable, and cleanup waits for acceptance.

## 40. Risks and Open Questions

Recommendations and open questions remain for the final physical storage model, SwiftData evolution versus a new canonical store, whether canonical and legacy records coexist physically, how much original legacy data to retain after migration, game-time photo and logo snapshots, dual-write risks, user-visible repair workflow, stored user-authored final scores, incomplete historical games, unsupported result round trips, substitution reconstruction, pitcher responsibility reconstruction, migration of already merged name-based records, fixture directory and expected-result ownership, and practical batch and media limits.

These are unresolved implementation and product decisions. The design recommends resolving them through repository evidence, fixtures, acceptance criteria, and focused follow-on design rather than inventing storage fields or migration code here.

## 41. Success Criteria

This design succeeds when existing supported records remain accessible, canonical game input can be loaded coherently, stable identity is preserved, historical games remain understandable, scoring-engine replay works from persisted facts, corrections persist coherently, imports do not damage unrelated records, exports do not modify source records, failed writes leave a usable prior state, migration outcomes are explicit, warnings are preserved, unsupported data is not silently rewritten, purchase and preference state remain separate, migration is fixture-backed and release-safe, and SwiftUI does not own migration logic.

## 42. Recommended Next Design Document

The recommended next design document is `21-ImportExportCompatibilityDesign.md`.

Import, export, document opening, website roster downloads, conflict resolution, version tolerance, and round-trip behavior should follow because persistence boundaries and migration guarantees are now defined. The next design should specify how transport formats and user-facing compatibility workflows preserve canonical meaning without mutating source records unexpectedly.

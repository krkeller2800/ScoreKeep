# Migration Sources, Fixtures, and Empty-Store Baseline

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This document completes implementation-catalog tasks 3.11 Migration-source inventory, 3.12 Representative migration fixtures, and 3.13 Empty-store migration from Document 29.

The run introduces migration-source inventory authority, representative migration fixture authority, non-routed migration input and result vocabulary, and test-only empty-store migration verification. It does not begin task 3.14, does not migrate populated existing stores, does not route a schema migration plan into production, and does not change the production ModelContainer.

No production data, production Keychain state, StoreKit receipt, AppStorage value, user media, generated report, or real store copy was used as a fixture.

<!-- MARK: - 2. Current Store and Schema Evidence -->
## 2. Current Store and Schema Evidence

Production startup creates the active SwiftData container through ScoreKeepApp with modelContainer for Game. The active production model declarations remain Game, Team, Player, Atbat, Lineup, and Pitcher. This run did not edit those models, their relationships, delete rules, external-storage attributes, or startup container construction.

Game currently stores UUID identity, date, location, highlights, stored home and visiting scores, Everyone Hits, inning count, optional home and visiting teams, players, at-bats, lineups, pitchers, replaced players, and incoming players.

Team currently stores UUID identity, display fields, players, games, and external-storage logo data. Player currently stores UUID identity, display fields, team, at-bats, batting order hint, and external-storage photo data. Atbat stores identity, game/team/player relationships, result strings, base evidence, inning, sequence, scorecard column, RBI, outs, sacrifice, stolen-base, earned-run, play-note, and end-of-inning evidence. Lineup stores identity, game/team relationships, inning, Everyone Hits, and players. Pitcher stores identity, player/team/game relationships, appearance boundary markers, aggregate values, and win evidence.

<!-- MARK: - 3. Historical Evidence Found -->
## 3. Historical Evidence Found

Historical schema evidence in the repository is the current unversioned SwiftData model shape plus compatibility transport models ShareTeam, SharePlayer, ShareGame, ShareAtbat, ShareLineup, and SharePitcher. No separate checked-in versioned SwiftData schema or production SchemaMigrationPlan was found or introduced.

Compatibility fixtures and catalogs under Docs/Verification/Fixtures provide reviewed historical and malformed source evidence. The production seeded game remains under Seed and is treated as production seed evidence, not copied as a migration fixture.

Git history was not needed to identify a prior distinct SwiftData schema because the current repository already contains the current model declarations, compatibility fixtures, fixture catalogs, baseline documents, and migration design evidence required for tasks 3.11 through 3.13.

<!-- MARK: - 4. Migration-Source Inventory -->
## 4. Migration-Source Inventory

Baseball SwiftData store sources are Games, Teams, reusable Players, game participants through Game.players and relationship references, rosters through Team.players and Player.team, lineups through Lineup and lineup player arrays, batting order through Player.batOrder, Atbat.batOrder, lineup order, and event sequence, defensive positions through Player.position, scoring events through Atbat, innings through Atbat.inning and Lineup.inning, outs through Atbat.outs and Atbat.outAt, runners and base evidence through Atbat.maxbase, result, outAt, stolenBases, and prior event order, stored scores through Game.hscore and Game.vscore, pitchers through Pitcher, substitutions through Game.replaced and Game.incomings, and photos and logos through external-storage Data fields.

Compatibility and transport sources are ScoreKeep_Players, ScoreKeep_Games, shared player and team structures, shared game structures, imported lineups, transport media, malformed and unsupported fixture inputs, seeded game input, downloaded roster data, route metadata, document type declarations, UTType declarations, deep-link prefill, and URL inventory evidence.

Seed and sample sources are the production seededGame.ScoreKeep_Games resource and the hasSeededInitialGame preference. Seed application is production startup behavior and remains separate from empty-store migration. Empty-store verification proves isolated migration does not silently seed records.

Preference sources include selectedGameCriteria, selectedPlayerCriteria, selectedPitcherCriteria, selectedTeamCriteria, hasSeededInitialGame, hasDismissedSeedHint_Game, announcement dismissal or presentation state where persisted, and other UserDefaults or AppStorage values found in presentation workflows. These are not baseball records and must preserve unchanged unless a later settings migration explicitly owns them.

Purchase, entitlement, and allowance sources include ScoreKeep.storekit, PurchaseManager product ID construction, seasonPassMaxExpirationISO8601 Keychain entitlement evidence, StoreKit transaction listening, freeGameCreatesRemainingKC, mlbDownloadCountKC, PaywallView contexts, report gates, game creation gate, and roster-download gate. Baseball migration must not read receipts, fabricate entitlements, reset season passes, decrement allowances, or treat missing baseball records as missing purchase access.

Generated-output and cached-output sources include reports, PDF generation, screenshots, Manual.pdf, print/share handoff, generated files saved outside source records, and report display projections. They are derived or external output and must not become canonical baseball authority.

<!-- MARK: - 5. Inventory Classification -->
## 5. Inventory Classification

Must migrate or be interpreted for later migration: stable identities, game settings, team and player records, roster membership, game participants, lineups, scoring events, ordered event evidence, pitcher evidence, substitution evidence, media attached to baseball records, stored-score evidence as reconciliation data, and compatibility provenance needed to explain imported records.

Must preserve unchanged: production source stores during this run, compatibility fixtures, production seed, StoreKit configuration, Keychain entitlement state, free-game allowance, MLB download counter, UserDefaults preferences, AppStorage preferences, generated output, source export files, and user media.

Read-only interpretation only: current SwiftData records, compatibility transport files, seeded game evidence, malformed fixture evidence, stored scores before replay reconciliation, unsupported result strings, missing optional values, duplicate identities, broken relationships, conflicting ordering, and media validity.

Reconstructable or recalculable derived values: current score, inning totals, outs projections, current runners, current or next batter, report totals, scorecard cells, generated reports, PDFs, game-list summaries, and aggregate pitcher or batter statistics where replay evidence is complete enough.

Requires future schema decision: game lifecycle status, game-time media snapshot policy, correction or supersession storage, explicit runner outcomes, canonical substitution roles and timing, canonical pitcher responsibility detail, migration progress persistence, and physical canonical storage shape.

Must remain outside baseball migration: purchases, entitlements, allowance counters, StoreKit receipts or transactions, Keychain material, AppStorage sorting and first-run preferences, presentation-only state, network cache state, generated output, debug resets, and UI navigation state.

<!-- MARK: - 6. Baseball Facts Requiring Preservation -->
## 6. Baseball Facts Requiring Preservation

Preservation candidates include game identity, team identity, player identity, game side relationships, game-time team and player display evidence, roster membership evidence, lineup evidence, batting order evidence, defensive position evidence, scoring event identity and result evidence, inning and sequence evidence, scorecard column evidence, runner/base/out evidence, RBI and earned-run choices, stored-score evidence, pitcher appearance evidence, substitution arrays, notes, highlights, and media ownership.

Uncertain, missing, duplicated, malformed, stale, unsupported, or contradictory values must not be silently discarded. They require warnings, read-only preservation, repair assessment, user review, or future schema decisions depending on severity.

<!-- MARK: - 7. Derived Values Eligible for Recalculation -->
## 7. Derived Values Eligible for Recalculation

Derived values may be recalculated after migration when recorded evidence is coherent: replay score, inning state, outs, current runners, next batter, pitcher projection, batting totals, pitching totals, scorecard projections, report rows, PDF contents, and list summaries.

Stored Game.hscore and Game.vscore remain compatibility or reconciliation evidence until replay confirms agreement or produces a warning. They must not silently override coherent event history and must not be discarded when event history is incomplete.

<!-- MARK: - 8. Compatibility Evidence -->
## 8. Compatibility Evidence

ScoreKeep_Players fixtures cover minimal valid rosters, complete rosters, media rosters, missing optional values, duplicate conflicts, malformed JSON, and wrong content. ScoreKeep_Games fixtures cover minimal valid games, in-progress games, completed games, multiple at-bats, lineup games, pitcher games, missing optional values, duplicate conflicts, seed-compatible synthetic shape, malformed JSON, and wrong content.

Malformed and unsupported fixtures cover empty files, wrong roots, missing required keys, invalid UUIDs, invalid dates, invalid base64, non-image media, duplicate IDs, broken relationships, unsupported values, unknown fields, extension/content mismatches, unsupported extensions, lowercase extensions, and double-extension route risks.

These fixtures are evidence for migration classification and later task 3.14 populated-store interpretation. They are not loaded into production and are not renamed copies of production user data.

<!-- MARK: - 9. Media Evidence -->
## 9. Media Evidence

Team.logo and Player.photo are external-storage Data properties in the current SwiftData model. ShareTeam.logo and SharePlayer.photo carry base64 Data in compatibility files. Media can be missing, empty, valid, non-image, malformed, oversized, stale, or attached to duplicate or broken owner evidence.

Media failure must not make baseball facts unusable. Empty-store migration creates no media. Populated media migration remains deferred to task 3.14 and later media handling tasks.

<!-- MARK: - 10. Preference Evidence -->
## 10. Preference Evidence

Preferences include sort criteria, first-run seed state, seed-hint dismissal, announcement state where persisted, presentation choices, and other AppStorage or UserDefaults values. Preferences may affect UI presentation or first-run workflow, but they do not define team identity, player identity, scoring events, or migration success.

Empty-store migration tests use test probes and isolated UserDefaults evidence only. Production preferences are not read, reset, or rewritten.

<!-- MARK: - 11. Purchase, Entitlement, and Allowance Separation -->
## 11. Purchase, Entitlement, and Allowance Separation

Purchase evidence is outside baseball migration. The migration input contains only marker probes and count probes, not receipts, signed transactions, StoreKit products, account data, or Keychain values. Empty-store migration must leave freeGameCreatesRemainingKC, mlbDownloadCountKC, season-pass entitlement evidence, and purchase state unchanged.

A purchase-separation probe change produces purchaseSeparationFailure and blocks a successful migration claim. Missing baseball records are not evidence that purchases are missing.

<!-- MARK: - 12. Fixture Selection and Privacy Review -->
## 12. Fixture Selection and Privacy Review

Representative migration fixtures are a compact manifest over existing curated fixtures plus immutable Swift fixture expectations. Categories cover empty source, minimal valid store, in-progress game, completed game, multiple records, multiple teams and reusable players, roster and lineup relationships, multiple scoring events, pitcher evidence, substitution evidence, ordering evidence, optional values, media, stored scores, duplicate identity, broken relationship, conflicting ordering, unsupported raw value, malformed or incomplete evidence, and purchase and allowance probes.

The fixture format is deterministic Swift expectations plus existing small checked-in JSON compatibility fixtures. It uses fixed identities, fixed dates where JSON fixtures need dates, explicit ordering, no random IDs, no current time, no network access, no production store copies, no real photos, no real purchase data, and tiny synthetic media bytes only.

Privacy review: fixture names are synthetic, media is synthetic, no email addresses are present, no account identifiers are present, no device identifiers are present, no StoreKit receipts or signed transactions are present, no Keychain material is present, and no production database was copied.

<!-- MARK: - 13. Migration Vocabulary -->
## 13. Migration Vocabulary

The run adds CanonicalMigrationSourceClassification, CanonicalMigrationTargetClassification, CanonicalMigrationMode, CanonicalMigrationDisposition, CanonicalMigrationRecordCounts, CanonicalMigrationPurchaseAllowanceProbe, CanonicalMigrationInput, CanonicalMigrationFinding, CanonicalMigrationResult, and CanonicalMigrationClassifier.

The vocabulary builds on CanonicalPersistenceTransactionResult by embedding the existing transaction result in migration output. It does not introduce a second transaction-result system, a production coordinator, a migration audit table, a production backup service, a production repair executor, or a new writer.

<!-- MARK: - 14. Empty-Store Behavior -->
## 14. Empty-Store Behavior

Empty-store classification distinguishes truly empty new store, empty existing store, metadata-only store, preferences-only store, purchase-or-allowance-only store, previously initialized empty store, populated existing store, unknown source version, unsupported source, and unable-to-open source.

The test-only empty-store path uses IsolatedPersistenceEnvironment and in-memory SwiftData. It establishes that the current target model can load in a fresh isolated context, creates no baseball records, creates no media, performs no seed import, preserves probes unchanged, and can run repeatedly without duplicates.

The first empty-store execution returns emptySourceInitialized. Repeated execution against the same initialized empty target returns noChange. A fresh-context reload remains empty and loadable.

<!-- MARK: - 15. Migration-Result Behavior -->
## 15. Migration-Result Behavior

Results record source and target classification, record counts, findings, transaction result, before and after purchase/allowance probes, source usability, target usability, retry safety, reload need, review or repair need, produced-record status, no-op status, and completion proof.

Unsupported source, unknown version, unexpected target records, purchase-separation failure, injected initialization failure, and interrupted initialization are classified explicitly. Failure and interruption preserve prior state and avoid claiming successful completion.

<!-- MARK: - 16. Automatic Versus Explicit Migration Assessment -->
## 16. Automatic Versus Explicit Migration Assessment

Current empty-store initialization with the current model is compatible with automatic container creation because no existing populated store is transformed and no schema evolution is routed. This is not evidence that future populated existing-store migration can rely on automatic migration.

Likely explicit decisions remain for versioned schema, lightweight migration, custom migration stages, canonical reconstruction, relationship repair assessment, ordering repair assessment, media handling, stored-score reconciliation, and purchase or allowance separation. Purchase and allowance state is outside SwiftData schema migration.

No production SchemaMigrationPlan or versioned schema routing was introduced.

<!-- MARK: - 17. Staged-Gate Results -->
## 17. Staged-Gate Results

Stage A passed: baseball records, relationships, ordering, media, seed data, preferences, purchases, entitlements, and allowances are inventoried and classified.

Stage B passed: the representative fixture manifest covers required conditions, uses existing fixtures where appropriate, and documents privacy and determinism.

Stage C passed: shallow migration input, result, finding, classification, disposition, and test support were added without production routing.

Stage D passed: truly empty source initialization produces an empty loadable target and no baseball records.

Stage E passed: preference-like, purchase, entitlement, and allowance probes remain unchanged.

Stage F passed: repeated execution, no duplicate records, unsupported source, unknown version, injected failure, interruption, retry, recovery, and unexpected-record classifications are verified.

Stage G passed: repair remains assessment-only, no populated existing store was migrated, no production route changed, and prerequisites for task 3.14 are documented.

<!-- MARK: - 18. Exact Prerequisites for Task 3.14 -->
## 18. Exact Prerequisites for Task 3.14

Task 3.14 may begin only after reviewing this inventory, fixture manifest, existing compatibility fixture catalogs, malformed fixture catalog, current SwiftData model evidence, CanonicalPersistenceMapping, CanonicalPersistenceTransactionResult, CanonicalPersistenceRepairAssessment, LegacyCanonicalVerificationMapping, isolated persistence support, and empty-store migration tests.

Task 3.14 must define populated-store interpretation without production routing, must use representative fixtures rather than production stores, must preserve original evidence, must classify duplicate identities and broken relationships before any write, must keep purchase and allowance probes outside baseball migration, and must not add production SchemaMigrationPlan routing without a separate approved task.

Blockers for 3.14 are unresolved physical schema target, game-time media snapshot policy, migration progress storage, repair UI or user-review policy, explicit versioning policy for existing unversioned stores, stored-score reconciliation policy, substitution timing reconstruction policy, pitcher responsibility reconstruction policy, and whether populated migration remains read-only interpretation or introduces a test-only physical conversion harness.

<!-- MARK: - 19. Deferrals and Legacy Authority Retained -->
## 19. Deferrals and Legacy Authority Retained

Deferred work includes task 3.14 existing-store migration, interrupted populated migration, repeated populated migration, failed populated migration and recovery, full purchase and allowance migration separation beyond probes, production SchemaMigrationPlan routing, production backup or restore, production migration UI, startup migration, production repair execution, persistence cutover, scoring cutover preparation, and legacy persistence retirement.

Legacy persistence, startup seeding, compatibility import/export, StoreKit, Keychain, allowance counters, reports, UI, accessibility behavior, and production ModelContainer authority remain active and unchanged.

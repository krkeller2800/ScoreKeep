# Stable Identity and Ordering Baseline

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This note completes implementation-catalog task `1.1 Stable identity and ordering semantics` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The task introduces a small non-routed foundation for stable identity evidence, duplicate/conflict classification, explicit ordering evidence, and substitution ambiguity classification. It does not route production workflows through the new types and does not change SwiftData models, persistence, scoring, imports, exports, purchases, allowances, reports, presentation, fixtures, StoreKit configuration, or compatibility formats.

<!-- MARK: - 2. Source Location -->
## 2. Source Location

Production source path: `ScoreKeep/Common/StableIdentityAndOrdering.swift`.

The file is placed under the existing `Common` source area because the repository has no existing canonical domain source hierarchy, and `Objects` contains active SwiftData persistence models. This keeps the foundation available to the app target without implying persistence ownership or creating a broad new module/package.

Test support path: `ScoreKeepTests/TestSupport/StableIdentityAndOrderingTestSupport.swift`.

Focused tests live in `ScoreKeepTests/StableIdentitySemanticsTests.swift`, `ScoreKeepTests/StableOrderingSemanticsTests.swift`, and `ScoreKeepTests/CompatibilityIdentityEvidenceTests.swift`.

<!-- MARK: - 3. Legacy Evidence Inspected -->
## 3. Legacy Evidence Inspected

Identity evidence inspected: `Team.ident`, `Player.identifier`, `Game.ident`, `Atbat.ident`, `Lineup.ident`, `Pitcher.ident`, transport `id` fields, duplicate fixture identifiers, invalid UUID fixtures, team and player names, jersey numbers, team membership, game teams, dates, and locations.

Ordering evidence inspected: `Player.batOrder`, `Atbat.seq`, `Atbat.col`, `Atbat.inning`, `Lineup.players`, `Pitcher.startInn`, `Pitcher.sOuts`, `Pitcher.sBats`, `Pitcher.endInn`, `Pitcher.eOuts`, `Pitcher.eBats`, source-file array order, SwiftData fetch/display sort descriptors, and `Game.replaced` / `Game.incomings` arrays.

Compatibility evidence inspected: current `ShareTeam`, `SharePlayer`, `ShareGame`, `ShareAtbat`, `ShareLineup`, and `SharePitcher` structures; roster and game fixture catalogs; malformed duplicate-identifier and conflicting-identifier fixtures; compatibility route inventory; and scoring regression scenario catalog.

<!-- MARK: - 4. Identity Semantics -->
## 4. Identity Semantics

Stable identity evidence is represented by concept plus imported identifier evidence plus display evidence. Valid imported UUIDs are preserved as evidence. Missing identifiers remain missing. Invalid identifier strings remain invalid evidence.

Names, team names, jersey numbers, dates, locations, lineup slots, array positions, and display sort values are not identity. They are display or matching evidence only.

The foundation classifies same valid identifier with matching evidence, same valid identifier with conflicting evidence, different identifiers with matching display, different identifiers with different display, missing identifiers, invalid identifiers, and unresolved equivalence.

Duplicate classification distinguishes exact repeated evidence, duplicate identifier with matching content, duplicate identifier with conflicting content, different identifiers with matching display, missing identifier, invalid identifier, and unresolved equivalence. Classification does not merge or delete records.

<!-- MARK: - 5. Ordering Semantics -->
## 5. Ordering Semantics

Ordering evidence is represented with an explicit order kind, optional integer value, and optional source index. Event sequence, lineup slot, batting order, pitcher appearance order, substitution order, source-file order, persistence fetch order, and display sort order are distinct kinds.

Ordering classification distinguishes ordered evidence, missing order, duplicate order values, conflicting order evidence, and ambiguity. Comparison returns ordered-before, ordered-after, same-position, missing-evidence, ambiguous, or incomparable-order-kinds.

Duplicate sequence values are not made safe by source order. Source-file order can be retained as evidence, but it is not canonical baseball order when sequence evidence is missing or contradictory.

<!-- MARK: - 6. Substitution Semantics -->
## 6. Substitution Semantics

Known substitution pairs can be classified as complete ordered evidence when incoming participant, outgoing participant, order, and timing, slot, or role evidence exist.

Legacy parallel `replaced` and `incomings` arrays remain ambiguous when counts match but timing, role, and baseball context are absent. Unequal counts are contradictory. Empty or missing participant evidence is incomplete.

The foundation does not repair, migrate, or pair legacy arrays for production use.

<!-- MARK: - 7. Tests Added -->
## 7. Tests Added

Team identity tests cover same identifier matching values, same identifier conflicting values, different identifiers with the same name, missing imported identifier, invalid imported identifier, and name change without identity change.

Player identity tests cover same identifier matching evidence, conflicting jersey or team evidence, same full name with different identifiers, same last-name risk, reused jersey numbers, changed jersey number, player appearing for different teams, missing identity, and invalid identity.

Game identity tests cover same teams and date with different identifiers, doubleheader distinction, same identifier with conflicting game evidence, and team/date matching as non-canonical identity.

Ordering tests cover increasing event sequence, duplicate sequence, missing sequence, conflicting order, source-order evidence, stable repeated evaluation, lineup slot separation, pitcher appearance separation, display-sort separation, and substitution ambiguity.

Compatibility evidence tests decode existing fixtures to prove imported UUID preservation, same-name records remaining distinct, duplicate player identifiers, duplicate at-bat identifiers, conflicting team identifiers, missing identity classification, and no SwiftData persistence writes from fixture classification.

<!-- MARK: - 8. Production Routing Status -->
## 8. Production Routing Status

No production workflow uses the new foundation after this task. App startup, model-container creation, team and player editing, game creation, live scoring, corrections, imports, exports, reports, PDFs, purchases, allowances, seeding, deep links, and file-open routing remain legacy-owned.

The new file has no SwiftData annotations, no model-container references, no import/export entry points, no StoreKit or Keychain access, no filesystem writes, and no random identifier generation during comparison.

<!-- MARK: - 9. Equality Hashing and Comparison -->
## 9. Equality Hashing and Comparison

Swift equality and hashing for identity evidence mean exact equality of concept, imported identifier evidence, and display-evidence array. Hash values are not persistent or compatibility identifiers.

Identity classification is explicit and does not imply that display-equal records are the same identity. Ordering does not use `Comparable`; it returns explicit comparison outcomes so ambiguous or incomplete evidence is not forced into a total order.

<!-- MARK: - 10. Limitations Risks and Next Task -->
## 10. Limitations Risks and Next Task

Limitations: this task does not introduce the full canonical model graph, team authority, player authority, roster authority, lineup authority, game authority, scoring authority, persistence migration, compatibility adapters, or routed workflow behavior.

Risks: later tasks must avoid weakening these semantics when mapping legacy records. In particular, name-based import matching, same-team same-date duplicate checks, `Player.batOrder`, scorecard columns, and substitution arrays must remain evidence until a later accepted authority safely interprets them.

Recommended next task: `1.2 Team meaning foundation`.

Task `1.2` should use stable identity and ordering to prepare reusable team and game-side meaning while current `Team`, `Game.vteam`, `Game.hteam`, import, export, and report paths remain the active legacy authorities. It must not change persistence schemas, compatibility formats, production routing, game creation, imports, exports, reports, or user data. According to Document 29, the task following `1.2` is `1.3 Player meaning foundation`.

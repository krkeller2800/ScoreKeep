# Team Meaning Baseline

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This note completes implementation-catalog task `1.2 Team meaning foundation` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The task introduces a small non-routed foundation for reusable team meaning, team display evidence, and game-specific home/visiting team-side participation. It does not route production workflows through the new types and does not change SwiftData models, persistence, scoring, imports, exports, purchases, allowances, reports, PDFs, presentation, fixtures, StoreKit configuration, seed behavior, compatibility formats, or user records.

<!-- MARK: - 2. Source Location -->
## 2. Source Location

Production source path: `ScoreKeep/Common/CanonicalTeamMeaning.swift`.

The file is a focused sibling of `ScoreKeep/Common/StableIdentityAndOrdering.swift`. Task `1.1` already established `Common` as the non-routed foundation location, and keeping team meaning in a sibling avoids turning the identity file into a monolith while avoiding a new module, package, or persistence-looking hierarchy.

Test support path: `ScoreKeepTests/TestSupport/CanonicalTeamMeaningTestSupport.swift`.

Focused tests live in `ScoreKeepTests/CanonicalTeamMeaningTests.swift`, `ScoreKeepTests/TeamSideMeaningTests.swift`, and `ScoreKeepTests/CompatibilityTeamEvidenceTests.swift`.

<!-- MARK: - 3. Legacy Evidence Inspected -->
## 3. Legacy Evidence Inspected

Legacy team evidence inspected: `Team.ident`, `Team.name`, `Team.coach`, `Team.details`, `Team.players`, `Team.games`, external `Team.logo`, `Game.vteam`, `Game.hteam`, team list creation and deletion, team editing, game setup pickers, roster import, game import, seeded import, roster export, game export, report and PDF team names and logos, scorecard and scoreboard team-side labels, duplicate team checks, name-based fetches, current sorting, and fixture catalogs.

Compatibility evidence inspected: `ShareTeam`, `.ScoreKeep_Players` fixtures, `.ScoreKeep_Games` fixtures, malformed relationship fixtures, conflicting team identity fixtures, duplicate conflict fixtures, missing optional value fixtures, imported logo/media evidence, and compatibility route inventory.

<!-- MARK: - 4. Reusable Team Semantics -->
## 4. Reusable Team Semantics

`ReusableCanonicalTeam` represents a reusable team identity with current display evidence, current roster evidence, and source classification. Valid UUID identity determines reusable-team equality and hashing. Missing and invalid identifiers remain explicit evidence and are not merged with valid teams.

Team display name, coach, details, logo/media evidence, roster evidence, game side role, file order, display sorting, and game date do not define reusable team identity.

<!-- MARK: - 5. Team Display Semantics -->
## 5. Team Display Semantics

`TeamDisplayEvidence` separates name, coach, details, and logo evidence from identity. Text evidence distinguishes missing from present blank values. Logo evidence distinguishes missing, present data, and invalid/unreadable media evidence.

Display conflicts can be classified for the same valid identifier without changing the reusable identity or mutating current records.

<!-- MARK: - 6. Game-Side Semantics -->
## 6. Game-Side Semantics

`GameSideTeamParticipation` represents one team's side participation in one game. Roles are limited to `home`, `visiting`, and `unresolved`. A side can resolve to a reusable team, unknown evidence, missing evidence, or conflicting evidence.

`CanonicalTeamMeaningClassifier.classifyGameSides` classifies complete distinct sides, the same reusable team assigned to both sides, missing home side, missing visiting side, both sides unresolved, unresolved side role, and contradictory side evidence. It does not normalize contradictory evidence into a valid side.

<!-- MARK: - 7. Historical Evidence Boundary -->
## 7. Historical Evidence Boundary

Historical game-side display evidence is stored separately from current reusable team display evidence in the semantic type. A current team rename, coach change, details change, logo change, or roster count change does not imply a new reusable identity and does not rewrite historical side evidence.

This task does not implement persistence snapshots or change current historical behavior. It only represents the distinction needed by later read, migration, report, and export work.

<!-- MARK: - 8. Compatibility Evidence -->
## 8. Compatibility Evidence

Compatibility tests read existing fixtures without mutation: `CompleteRoster.ScoreKeep_Players`, `MinimalValid.ScoreKeep_Games`, `CompletedGame.ScoreKeep_Games`, `ConflictingTeamIdentity.ScoreKeep_Games`, `BrokenTeamRelationship.ScoreKeep_Players`, `DuplicateConflict.ScoreKeep_Games`, `MissingOptionalValues.ScoreKeep_Players`, and `MissingOptionalValues.ScoreKeep_Games`.

Fixture evidence is interpreted as imported or historical team evidence only. No transport structures, fixture files, import routes, export routes, keys, encoding, decoding, matching, or persistence behavior were changed.

<!-- MARK: - 9. Identity Media and Roster Boundaries -->
## 9. Identity Media and Roster Boundaries

Media does not define identity. Missing or invalid logo evidence does not invalidate baseball identity. Different logo evidence for the same valid team identifier is classifiable as display/media conflict.

Current roster evidence is represented only as a relationship or imported roster reference count. The foundation does not model roster membership semantics, roster editing authority, historical player participation, or roster-to-game inference. Task `1.4` remains responsible for roster membership meaning.

<!-- MARK: - 10. Equality Hashing and Determinism -->
## 10. Equality Hashing and Determinism

`ReusableCanonicalTeam` equality and hashing use valid reusable team identity when both sides have valid identifiers. For missing or invalid identifiers, equality and hashing require exact unresolved evidence. Hash values are not persistent identifiers.

Game-side role is separate from reusable team identity. A reusable team and a game-side participation value are different semantic types and do not compare equal merely because they share an identifier. Repeated evaluation, source order changes, display sorting, and home/visiting role do not redefine reusable identity.

<!-- MARK: - 11. Tests Added -->
## 11. Tests Added

Reusable team tests cover same valid identifier with matching display, changed name, changed coach, changed logo, conflicting display evidence, same-name teams with different identifiers, missing identifier, invalid identifier, duplicate matching evidence, duplicate conflicting evidence, blank name, missing name, blank coach, missing details, missing logo, invalid logo evidence, display changes, and roster evidence separation.

Game-side tests cover home and visiting roles, the same reusable team participating as home and visiting in different games, distinct teams on home and visiting sides, same team assigned to both sides, missing home, missing visiting, both sides unresolved, unresolved role, contradictory side evidence, historical display differing from current display, roster changes not altering historical side identity, logo changes not altering baseball meaning, and distinct game identities for same teams.

Compatibility tests cover read-only interpretation of the listed fixtures, imported team identifiers, imported display and media evidence, missing optional values, malformed relationship evidence, conflicting team identity, duplicate conflict evidence, deterministic repeated classification, and isolated-store non-mutation.

<!-- MARK: - 12. Production Routing Status -->
## 12. Production Routing Status

No production workflow references the new foundation after this task. App startup, model-container creation, team lists, team editors, player editors, roster workflows, game creation, game editing, live scoring, imports, exports, reports, PDFs, downloads, seed logic, purchases, allowances, navigation, and deep links remain legacy-owned.

The new source has no SwiftData annotations, no model-container references, no import/export entry points, no StoreKit or Keychain access, no filesystem writes, no migration behavior, and no random identifier generation during classification.

<!-- MARK: - 13. Limitations Risks and Next Task -->
## 13. Limitations Risks and Next Task

Limitations: this task does not introduce full team authority, roster authority, game authority, player authority, persistence adapters, migration, compatibility adapters, reports, UI, services, production routing, or history snapshot persistence.

Risks: later tasks must preserve the distinction between current reusable teams and historical game sides when mapping legacy records. Name-based matching, current roster relationships, current logos, and current team edits remain legacy evidence until accepted replacement tasks route new authorities.

Recommended next task: `1.3 Player meaning foundation`.

Task `1.3` should use stable identity and the team-side foundation to prepare reusable player and game-participant meaning while current `Player`, roster editing, at-bat, report, import, export, photo, and media writers remain active. It must not change persistence schemas, compatibility formats, production routing, reports, user data, purchases, allowances, or task `1.4` roster membership meaning. According to Document 29, the task following `1.3` is `1.4 Roster membership meaning`.

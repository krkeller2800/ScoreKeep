# Roster Membership Baseline

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This note completes implementation-catalog task `1.4 Roster membership meaning` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The task introduces a small non-routed foundation for current roster membership, relationship identity evidence, duplicate and conflict classification, empty and incomplete roster evidence, imported membership evidence, and the boundary between current roster membership and historical game participation. It does not route production workflows through the new types and does not change SwiftData models, persistence, migrations, team or player editing, roster UI, game setup, lineups, scoring, imports, exports, reports, PDFs, purchases, allowances, StoreKit, media storage, fixture files, compatibility formats, seed behavior, or user records.

<!-- MARK: - 2. Source Location -->
## 2. Source Location

Production source path: `ScoreKeep/Common/CanonicalRosterMembership.swift`.

The file is a focused sibling of `ScoreKeep/Common/StableIdentityAndOrdering.swift`, `ScoreKeep/Common/CanonicalTeamMeaning.swift`, and `ScoreKeep/Common/CanonicalPlayerMeaning.swift`. Tasks `1.1` through `1.3` established `Common` as the non-routed foundation location. Keeping roster membership in a sibling avoids expanding identity, team, or player meaning into a monolith, avoids the active SwiftData `Objects` area, and avoids creating a new module, package, or source hierarchy.

Test support path: `ScoreKeepTests/TestSupport/CanonicalRosterMembershipTestSupport.swift`.

Focused tests live in `ScoreKeepTests/CanonicalRosterMembershipTests.swift`, `ScoreKeepTests/RosterMembershipConflictTests.swift`, `ScoreKeepTests/HistoricalRosterBoundaryTests.swift`, and `ScoreKeepTests/CompatibilityRosterEvidenceTests.swift`.

<!-- MARK: - 3. Legacy Evidence Inspected -->
## 3. Legacy Evidence Inspected

Legacy roster evidence inspected: `Team.players`, `Player.team`, `Player.identifier`, `Player.name`, `Player.number`, `Player.position`, `Player.batDir`, `Player.batOrder`, `Player.photo`, `Team.logo`, `Game.players`, `Game.vteam`, `Game.hteam`, `Game.lineups`, `Game.replaced`, `Game.incomings`, team list and deletion behavior, player list and deletion behavior, team edit roster display, player edit team selection, paste import/update behavior, roster import/update behavior, roster export, game import, game setup, starting lineup selection, batting-order mutation, duplicate-name and last-name matching, duplicate-number behavior, null team selection, media replacement, and deletion checks against at-bats and pitchers.

Compatibility evidence inspected: `SharePlayer`, `ShareTeam`, `ShareGame`, nested team/player transport, downloaded roster path, roster export path, game export path, `.ScoreKeep_Players` fixtures, `.ScoreKeep_Games` fixtures, malformed relationship fixtures, duplicate identity fixtures, missing optional value fixtures, current compatibility route inventory, stable identity baseline, team meaning baseline, and player meaning baseline.

<!-- MARK: - 4. Current Membership Semantics -->
## 4. Current Membership Semantics

`CurrentRosterMembership` represents a current roster relationship between one reusable team and one reusable player. Valid team identity plus valid player identity determines comparable membership identity for non-routed semantic evaluation. Missing, invalid, unknown, detached, duplicate, and conflicting evidence remains explicit and is not merged or repaired.

Roster membership is distinct from reusable team identity and reusable player identity. A team rename, player rename, roster change, jersey-number change, position change, batting-order change, display sort change, or media change does not create a new reusable team or player identity. A player can have no current team while still retaining valid reusable identity and valid historical participation evidence.

<!-- MARK: - 5. Relationship Identity and Equality -->
## 5. Relationship Identity and Equality

When both sides have valid team and player identities, `CurrentRosterMembership` equality and hashing use the team/player relationship only. Mutable evidence such as jersey number, position, roster order, batting order, media, and source classification does not redefine membership identity. For missing or invalid relationship identity, equality and hashing require exact unresolved evidence.

Hash values are not persistent identifiers and must not be used as compatibility IDs. The current repository does not contain a separate explicit roster-membership identifier, so this foundation does not invent one and does not treat array index, jersey number, name, batting order, display order, or source-file order as identity.

<!-- MARK: - 6. Duplicate and Conflict Classification -->
## 6. Duplicate and Conflict Classification

`CanonicalRosterMembershipClassifier` classifies exact repeated evidence, same team/player matching evidence, same team/player conflicting evidence, same player on different current teams, distinct memberships, missing team identity, invalid team identity, missing player identity, invalid player identity, unresolved equivalence, duplicate player identity, duplicate jersey number, duplicate roster order, mixed team evidence, and conflicting nested team evidence.

Classification does not merge, delete, normalize, or repair records. Same-name players with different identifiers remain distinct memberships. Same-last-name players with different identifiers remain distinct. Same-number players with different identifiers remain distinct. Same player on multiple current teams is classifiable as conflicting current evidence rather than automatically resolved.

<!-- MARK: - 7. Empty and Incomplete Roster Meaning -->
## 7. Empty and Incomplete Roster Meaning

`TeamRosterMembershipSet` represents a team with zero, one, or multiple membership entries. Empty rosters classify as empty evidence and, when a valid team identity exists, as a team with an empty roster. Missing team identity, missing player identity, invalid identities, unknown identities, detached imported player evidence, blank number, missing number, blank position, unknown position, duplicate order, and duplicate jersey number remain representable.

Empty or incomplete evidence is not automatically invalid. The foundation classifies the condition honestly so later workflow, import, migration, lineup, and validation tasks can decide whether review, warning, repair, or rejection is appropriate.

<!-- MARK: - 8. Historical Participation Boundary -->
## 8. Historical Participation Boundary

`PlayerWithoutCurrentRosterMembership` represents a reusable player with no current team and optional historical participation evidence. Game participation remains represented by `GamePlayerParticipation` from task `1.3`; it is a different semantic type from current roster membership.

Current roster removal does not erase historical game participation. Current roster addition does not fabricate historical participation. Current player rename, team rename, number change, position change, media change, or roster movement does not rewrite game-time participant display evidence. Historical games, game-side participants, lineups, at-bats, pitcher appearances, substitutions, reports, PDFs, and exports remain outside this task.

<!-- MARK: - 9. Number Position Order and Media Boundaries -->
## 9. Number Position Order and Media Boundaries

`RosterMembershipDisplayEvidence` preserves jersey-number evidence, position evidence, roster-order evidence, batting-order evidence, and media evidence separately from relationship identity.

Jersey number is membership/display evidence, not identity. Duplicate numbers on one roster are classifiable. Position is raw evidence for later defensive-position work, not baseball legality validation. Batting order is preserved as evidence only and does not define roster membership. Roster order is separate from membership identity, player identity, batting order, lineup order, jersey-number sorting, alphabetical sorting, and import file order. Missing or invalid media does not invalidate membership.

<!-- MARK: - 10. Compatibility Evidence -->
## 10. Compatibility Evidence

Compatibility tests read existing fixtures without mutation: `MinimalValid.ScoreKeep_Players`, `CompleteRoster.ScoreKeep_Players`, `MissingOptionalValues.ScoreKeep_Players`, `DuplicateConflict.ScoreKeep_Players`, `DuplicatePlayerID.ScoreKeep_Players`, `BrokenTeamRelationship.ScoreKeep_Players`, `EmptyArray.ScoreKeep_Players`, `CompletedGame.ScoreKeep_Games`, `LineupGame.ScoreKeep_Games`, and `BrokenLineupRelationship.ScoreKeep_Games`.

Fixture evidence is interpreted as imported roster evidence, imported game evidence, historical participant evidence, or unresolved relationship evidence only. No transport structures, fixture files, import routes, export routes, Codable keys, matching rules, download behavior, persistence application, or review UI were changed.

<!-- MARK: - 11. Tests Added -->
## 11. Tests Added

Current-membership tests cover valid team/player membership, exact repeated evidence, same team/player with changed jersey number, changed position, changed roster order, membership display changes, same-name players, same-last-name players, same-number players, duplicate numbers, same player on different teams, same player on two current teams, player without current team, and deterministic repeated evaluation.

Conflict tests cover exact duplicate membership, duplicate matching evidence, conflicting number, conflicting position, conflicting order, missing team identity, invalid team identity, missing player identity, invalid player identity, unresolved evidence, detached imported evidence, empty rosters, one-player rosters, multiple-player rosters, blank number, missing number, blank position, unknown position, media conflicts, and batting-order conflicts.

Historical tests cover current roster removal, current roster addition, current number change, current position change, current player rename, current team rename, game participant separation, and same player appearing historically for another team.

Compatibility tests cover read-only interpretation of the listed fixtures, imported membership evidence, missing optional roster values, duplicate player identity, duplicate jersey number, broken nested team evidence, empty arrays, game participants absent from current roster evidence, lineup fixture separation, and mixed team evidence without transport mutation.

<!-- MARK: - 12. Production Routing Status -->
## 12. Production Routing Status

No production workflow references the new foundation after this task. App startup, model-container creation, team lists, team editors, player lists, player editors, roster screens, paste workflows, download workflows, game setup, starting lineup selection, live scoring, corrections, imports, exports, reports, PDFs, seed logic, purchases, allowances, navigation, and deep links remain legacy-owned.

The new source has no SwiftData annotations, no model-container references, no filesystem writes, no import/export entry points, no StoreKit or Keychain access, no migration behavior, no production adapter, and no random identifier generation during classification.

<!-- MARK: - 13. Limitations Risks and Next Task -->
## 13. Limitations Risks and Next Task

Limitations: this task does not introduce full roster authority, lineup authority, batting-order authority, defensive-position authority, game authority, scoring authority, persistence adapters, migration, compatibility adapters, import/export replacement, reports, UI, services, production routing, deletion behavior, repair behavior, or historical snapshot persistence.

Risks: later tasks must preserve the distinction between current roster membership, reusable team identity, reusable player identity, game-side participation, game-player participation, lineup participation, batting order, position, jersey number, roster order, and media. Name-based import matching, last-name matching, jersey-number matching, mutable `Player.batOrder`, current `Player.team`, `Team.players`, lineup mutation, game imports, paste updates, current media, and legacy deletion behavior remain active legacy evidence until accepted replacement tasks route new authorities.

Recommended next task: `1.5 Lineup meaning`.

Task `1.5` should use stable identity, team meaning, player meaning, and roster membership to prepare game-specific lineup meaning while current starting-lineup, edit-lineup, scoring setup, import, and lineup writers remain active. It must not change production lineups, batting progression, scoring, persistence, compatibility formats, imports, exports, reports, roster UI, game setup, or task `1.6 Batting-order semantics`. According to Document 29, the task following `1.5` is `1.6 Batting-order semantics`.

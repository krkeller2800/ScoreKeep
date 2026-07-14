# Player Meaning Baseline

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This note completes implementation-catalog task `1.3 Player meaning foundation` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The task introduces a small non-routed foundation for reusable player meaning, player display evidence, game-specific player participation, role evidence, historical evidence boundaries, incomplete and conflicting player evidence, and media separation. It does not route production workflows through the new types and does not change SwiftData models, persistence, scoring, rosters, lineups, imports, exports, reports, PDFs, purchases, allowances, photos, media behavior, presentation, fixtures, StoreKit configuration, seed behavior, compatibility formats, or user records.

<!-- MARK: - 2. Source Location -->
## 2. Source Location

Production source path: `ScoreKeep/Common/CanonicalPlayerMeaning.swift`.

The file is a focused sibling of `ScoreKeep/Common/StableIdentityAndOrdering.swift` and `ScoreKeep/Common/CanonicalTeamMeaning.swift`. Tasks `1.1` and `1.2` established `Common` as the non-routed foundation location. Keeping player meaning in a sibling avoids expanding either prior foundation into a monolith, avoids the active SwiftData `Objects` area, and avoids creating a new module, package, or source hierarchy.

Test support path: `ScoreKeepTests/TestSupport/CanonicalPlayerMeaningTestSupport.swift`.

Focused tests live in `ScoreKeepTests/CanonicalPlayerMeaningTests.swift`, `ScoreKeepTests/GameParticipantMeaningTests.swift`, and `ScoreKeepTests/CompatibilityPlayerEvidenceTests.swift`.

<!-- MARK: - 3. Legacy Evidence Inspected -->
## 3. Legacy Evidence Inspected

Legacy player evidence inspected: `Player.identifier`, `Player.name`, `Player.number`, `Player.position`, `Player.batDir`, `Player.batOrder`, `Player.team`, `Player.atbat`, external `Player.photo`, `Game.players`, `Game.replaced`, `Game.incomings`, `Atbat.player`, `Lineup.players`, `Pitcher.player`, player list creation and deletion, player editing, roster paste/import, lineup selection, live scoring current batter evidence, pitcher workflows, replacement workflows, score display, reports, PDFs, roster export, game export, seeded game data, duplicate checks, name and last-name matching, jersey-number matching, player sorting, and fixture catalogs.

Compatibility evidence inspected: `SharePlayer`, nested team/player transport, `ShareGame.players`, `ShareAtbat.player`, `ShareLineup.players`, `SharePitcher.player`, `ShareGame.replaced`, `ShareGame.incomings`, `.ScoreKeep_Players` fixtures, `.ScoreKeep_Games` fixtures, malformed relationship fixtures, duplicate player identity fixtures, missing optional value fixtures, invalid media fixtures, compatibility route inventory, stable identity baseline, team meaning baseline, and scoring regression scenario catalog.

<!-- MARK: - 4. Reusable Player Semantics -->
## 4. Reusable Player Semantics

`ReusableCanonicalPlayer` represents a reusable player identity with current display evidence, current roster evidence boundary, and source classification. Valid UUID identity determines reusable-player equality and hashing. Missing and invalid identifiers remain explicit evidence and are not merged with valid players.

Player name, last name, jersey number, position, batting direction, batting order, current team, current roster membership, lineup slot, batter role, pitcher role, substitution role, photo/media evidence, file order, display sorting, and game participation do not define reusable player identity.

<!-- MARK: - 5. Player Display Semantics -->
## 5. Player Display Semantics

`PlayerDisplayEvidence` separates name, jersey number, position text, batting-direction text, and photo/media evidence from identity. Text evidence distinguishes missing from present blank values and unknown unsupported text. Media evidence distinguishes missing, present data, and invalid or unreadable media evidence.

Display conflicts can be classified for the same valid identifier without changing the reusable identity or mutating current records. Jersey number is display and participation evidence, not identity. Position is raw evidence for later defensive-position work, not interpreted baseball legality. Batting direction is current compatibility and display evidence, not a new value system.

<!-- MARK: - 6. Game-Participant Semantics -->
## 6. Game-Participant Semantics

`GamePlayerParticipation` represents one player's participation evidence in one game. It is distinct from `ReusableCanonicalPlayer`. It can carry participant identity evidence, game identity evidence, reusable-player resolution, team or game-side evidence, historical display evidence, role evidence, lineup participation evidence, plate-appearance evidence, pitcher appearance evidence, substitution evidence, and source classification.

A reusable player can appear in multiple games, for different teams in different historical contexts, and with different game-time name, jersey number, position, batting direction, photo evidence, and roles. A game participant can be missing, invalid, duplicate, conflicting, unknown, or imported detached evidence without mutating the reusable player.

<!-- MARK: - 7. Historical Evidence Boundary -->
## 7. Historical Evidence Boundary

Historical participant display evidence is stored separately from current reusable player display evidence in the semantic type. Current player rename, number change, team change, position change, batting-direction change, photo change, roster removal, or deletion evidence does not imply a new reusable identity and does not rewrite historical participant evidence.

This task does not implement persistence snapshots, deletion behavior, repair behavior, or historical-game migration. It only represents the distinction needed by later read, migration, report, export, lineup, pitcher, substitution, and scoring work.

<!-- MARK: - 8. Team and Roster Boundary -->
## 8. Team and Roster Boundary

`PlayerRosterEvidence` keeps current roster relationship evidence separate from reusable player identity. `PlayerTeamEvidence` distinguishes current reusable-team evidence, game-side evidence, missing team evidence, unknown team evidence, and conflicting team evidence.

A player's current team relationship does not redefine player identity. Current roster membership remains separate from historical game participation. Jersey-number duplication on one roster does not merge players. Task `1.4 Roster membership meaning` remains responsible for current roster membership authority.

<!-- MARK: - 9. Role Evidence -->
## 9. Role Evidence

`PlayerParticipantRole` represents roster-member, lineup-participant, batter, pitcher, substitute, replaced-participant, and unresolved role evidence. Roles are held as a set so one participant can carry more than one role.

Array placement alone does not fabricate a role. Source-file order, roster order, lineup order, display sorting, and jersey-number sorting remain evidence only until later lineup, batting-order, pitcher, substitution, and scoring tasks define stronger meaning.

<!-- MARK: - 10. Compatibility Evidence -->
## 10. Compatibility Evidence

Compatibility tests read existing fixtures without mutation: `CompleteRoster.ScoreKeep_Players`, `MinimalValid.ScoreKeep_Players`, `MediaRoster.ScoreKeep_Players`, `DuplicateConflict.ScoreKeep_Players`, `DuplicatePlayerID.ScoreKeep_Players`, `MissingOptionalValues.ScoreKeep_Players`, `InvalidBase64Photo.ScoreKeep_Players`, `CompletedGame.ScoreKeep_Games`, `MultipleAtbats.ScoreKeep_Games`, `LineupGame.ScoreKeep_Games`, `PitcherGame.ScoreKeep_Games`, `BrokenAtbatRelationship.ScoreKeep_Games`, `BrokenLineupRelationship.ScoreKeep_Games`, and `BrokenPitcherRelationship.ScoreKeep_Games`.

Fixture evidence is interpreted as imported roster evidence, imported game evidence, or unresolved historical participant evidence only. No transport structures, fixture files, import routes, export routes, keys, encoding, decoding, matching, or persistence behavior were changed.

<!-- MARK: - 11. Identity Media and Equality -->
## 11. Identity Media and Equality

Media does not define identity. Missing or invalid photo evidence does not invalidate baseball identity. Different photo evidence for the same valid player identifier is classifiable as display/media conflict.

`ReusableCanonicalPlayer` equality and hashing use valid reusable player identity when both sides have valid identifiers. For missing or invalid identifiers, equality and hashing require exact unresolved evidence. Hash values are not persistent identifiers. A reusable player and a game participant are distinct semantic types. Participant equality includes game, participant, role, team, historical display, and participation evidence because those values define game-specific evidence.

<!-- MARK: - 12. Tests Added -->
## 12. Tests Added

Reusable player tests cover same valid identifier with matching display, changed name, changed jersey number, changed position evidence, changed batting-direction evidence, changed photo evidence, conflicting display evidence, same-name players with different identifiers, same last-name risk, same jersey-number risk, missing identifier, invalid identifier, duplicate matching evidence, duplicate conflicting evidence, blank values, missing values, unknown position and batting-direction text, invalid photo evidence, display changes, and current team/roster separation.

Game participant tests cover reusable player participation in distinct games, batter evidence, pitcher evidence, lineup evidence, substitute and replaced-player role evidence, multiple role evidence, historical display differing from current reusable display, current roster removal, missing reusable identity, invalid identity, duplicate identity, conflicting evidence, unknown participant, imported detached participant, unresolved role, missing or invalid game identity, and array placement as non-role evidence.

Compatibility tests cover read-only interpretation of the listed fixtures, imported player identifiers, imported display and media evidence, missing optional values, invalid media, malformed child relationships, duplicate and conflicting player identity evidence, deterministic repeated classification, source-order independence, display-sort independence, jersey-number-sort independence, current-team independence, game-role separation, and isolated-store non-mutation.

<!-- MARK: - 13. Production Routing Status -->
## 13. Production Routing Status

No production workflow references the new foundation after this task. App startup, model-container creation, player lists, player editors, team editors, roster workflows, lineup workflows, game creation, game editing, live scoring, corrections, pitcher workflows, replacement workflows, imports, exports, reports, PDFs, downloads, seed logic, purchases, allowances, navigation, and deep links remain legacy-owned.

The new source has no SwiftData annotations, no model-container references, no import/export entry points, no StoreKit or Keychain access, no filesystem writes, no migration behavior, no production adapter, and no random identifier generation during classification.

<!-- MARK: - 14. Limitations Risks and Next Task -->
## 14. Limitations Risks and Next Task

Limitations: this task does not introduce full player authority, roster authority, lineup authority, batting-order authority, defensive-position authority, game authority, scoring authority, pitcher authority, substitution authority, persistence adapters, migration, compatibility adapters, reports, UI, services, production routing, deletion behavior, repair behavior, or history snapshot persistence.

Risks: later tasks must preserve the distinction between current reusable player information, current roster membership, game-time participant evidence, and compatibility transport evidence when mapping legacy records. Name-based import matching, last-name matching, jersey-number matching, mutable `Player.batOrder`, current team relationships, current photos, and legacy substitution arrays remain active legacy evidence until accepted replacement tasks route new authorities.

Recommended next task: `1.4 Roster membership meaning`.

Task `1.4` should use stable identity, team meaning, and player meaning to prepare current roster membership semantics while current team/player list, edit, import, paste, and roster writers remain active. It must not change historical game participation, persistence schemas, compatibility formats, production routing, reports, user data, purchases, allowances, or task `1.5 Lineup meaning`. According to Document 29, the task following `1.4` is `1.5 Lineup meaning`.

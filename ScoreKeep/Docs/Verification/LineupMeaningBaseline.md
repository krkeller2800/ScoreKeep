# Lineup Meaning Baseline

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This note completes implementation-catalog task `1.5 Lineup meaning` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The task introduces a small non-routed foundation for game-specific lineup meaning, lineup-entry evidence, lineup membership, traditional and Everyone Hits mode evidence, incomplete lineup classification, duplicate and conflict classification, raw batting-slot evidence, roster-boundary evidence, and historical lineup boundaries. It does not route production workflows through the new types and does not change SwiftData models, persistence, migrations, lineup editing, game setup, score setup, scoring, imports, exports, reports, PDFs, purchases, allowances, StoreKit, media storage, fixture files, compatibility formats, seed behavior, UI, navigation, accessibility behavior, or user records.

<!-- MARK: - 2. Source Location -->
## 2. Source Location

Production source path: `ScoreKeep/Common/CanonicalLineupMeaning.swift`.

The file is a focused sibling of `ScoreKeep/Common/StableIdentityAndOrdering.swift`, `ScoreKeep/Common/CanonicalTeamMeaning.swift`, `ScoreKeep/Common/CanonicalPlayerMeaning.swift`, and `ScoreKeep/Common/CanonicalRosterMembership.swift`. Tasks `1.1` through `1.4` established `Common` as the non-routed foundation location. Keeping lineup meaning in a sibling avoids expanding identity, team, player, or roster membership into a monolith, avoids the active SwiftData `Objects` area, and avoids creating a new module, package, or source hierarchy.

Test support path: `ScoreKeepTests/TestSupport/CanonicalLineupMeaningTestSupport.swift`.

Focused tests live in `ScoreKeepTests/CanonicalLineupMeaningTests.swift`, `ScoreKeepTests/LineupConflictAndCompletenessTests.swift`, `ScoreKeepTests/HistoricalLineupBoundaryTests.swift`, and `ScoreKeepTests/CompatibilityLineupEvidenceTests.swift`.

<!-- MARK: - 3. Legacy Evidence Inspected -->
## 3. Legacy Evidence Inspected

Legacy lineup evidence inspected: `Lineup.ident`, `Lineup.everyoneHits`, `Lineup.game`, `Lineup.team`, `Lineup.inning`, `Lineup.players`, `Game.ident`, `Game.everyOneHits`, `Game.lineups`, `Game.players`, `Game.vteam`, `Game.hteam`, `Game.replaced`, `Game.incomings`, `Player.identifier`, `Player.team`, `Player.batOrder`, `Player.number`, `Player.position`, starting-lineup creation and update behavior, first-inning placeholder at-bat creation, lineup update deletion behavior, score setup, game creation, current team/player roster editing, roster order and display sorting, pitcher setup overlap, replacement arrays, report and scorecard use of `Atbat.batOrder`, and the `99` non-hitting sentinel.

Compatibility evidence inspected: `ShareLineup`, `ShareGame.lineups`, `SharePlayer.batOrder`, `ShareAtbat.batOrder`, `SharePitcher`, roster and game import paths, game export path that currently omits lineup player lists, fixture catalogs, malformed fixture catalog, compatibility route inventory, scoring regression scenario catalog, and the prior stable identity, team, player, and roster membership baselines.

<!-- MARK: - 4. Game-Specific Lineup Semantics -->
## 4. Game-Specific Lineup Semantics

`CanonicalGameLineup` represents lineup evidence for one game context. It carries lineup identity evidence, game identity evidence, side evidence, team evidence, mode evidence, entries, source classification, and raw inning evidence.

A lineup entry is represented separately as `LineupEntryEvidence`. It connects lineup context to participant evidence, optional raw batting-slot evidence, optional source-order evidence, raw position evidence, historical display evidence, pitcher-role evidence, substitution-boundary evidence, and source classification.

Reusable player identity, current roster membership, game participant evidence, lineup membership, batting-slot evidence, defensive-position evidence, pitcher evidence, substitution evidence, source order, display order, and historical lineup evidence remain separate semantic concepts.

<!-- MARK: - 5. Identity and Equality Semantics -->
## 5. Identity and Equality Semantics

Valid lineup UUID evidence controls `CanonicalGameLineup` equality and hashing. Mutable participant display evidence, player names, jersey numbers, batting slots, source order, defensive positions, roster order, display sorting, Everyone Hits mode, and entry count do not redefine lineup identity.

Missing or invalid lineup identity remains explicit unresolved evidence. For missing or invalid identity, equality and hashing require exact unresolved evidence. Hash values are not persistent identifiers and must not be used as compatibility IDs.

Identity comparison classifies same valid identifier with matching evidence, same valid identifier with conflicting game or side evidence, different identifiers with matching visible evidence, missing identity, invalid identity, and unresolved equivalence. Lineups are not automatically merged.

<!-- MARK: - 6. Side and Team Semantics -->
## 6. Side and Team Semantics

Lineup side evidence can represent home, visiting, unresolved, missing, conflicting, game-side participation, or side inferred only from array position. Team evidence can represent game-side team participation, reusable team identity, missing, unknown, invalid, or conflicting evidence.

The classifier detects missing side, unresolved side, conflicting side, lineup team identity conflicts with game-side identity, participant side conflicts with lineup side, and same lineup evidence applied to both sides. Contradictory side evidence is classified, not normalized.

<!-- MARK: - 7. Entry and Membership Semantics -->
## 7. Entry and Membership Semantics

Lineup participant evidence can represent game participants, reusable players, current roster memberships, missing player identity, invalid player identity, unknown participants, historical players, players absent from the current roster, participants on the wrong game side, unresolved game-side participants, and imported detached evidence.

Classification distinguishes valid members, missing participants, invalid participants, unresolved participants, detached imported participants, players absent from current roster, historical player evidence, wrong game side, unresolved game side, missing slot, invalid slot, unsupported slot, non-hitting sentinel, conflicting slot, conflicting position, source-order evidence, pitcher-role evidence, and substitution-boundary evidence.

Duplicate participants are detected without merging or deletion. Same-name players and same-number players remain distinct when their identities differ.

<!-- MARK: - 8. Traditional and Everyone Hits Evidence -->
## 8. Traditional and Everyone Hits Evidence

`LineupModeEvidence` represents traditional, Everyone Hits, unknown, missing, unsupported, and ambiguous mode evidence.

Traditional evidence can carry known distinct slots, missing slots, duplicate slots, gaps, fewer than nine entries, more than nine entries, player-without-slot evidence, unresolved-player-with-slot evidence, conflicting slot evidence, and preserved non-hitting sentinel values such as `99` where repository evidence supports them.

Everyone Hits evidence can carry more than nine participants, current roster overlap, omitted current roster members, participants not on the current roster, duplicate participants, missing participants, conflicting slots, and incomplete imported evidence. The foundation does not assume Everyone Hits means current roster and lineup are identical.

<!-- MARK: - 9. Complete Empty and Incomplete Classifications -->
## 9. Complete Empty and Incomplete Classifications

Lineup classification returns explicit set outcomes rather than one Boolean. It can classify one lineup, multiple lineups, empty lineup, complete lineup, incomplete lineup, missing game, invalid game, missing side, unresolved side, conflicting side, team-side conflict, participant-side conflict, missing participant, invalid participant, duplicate lineup, duplicate participant, repeated exact participant, conflicting participant slot, conflicting participant side, conflicting participant position, duplicate slot, missing slot, invalid slot, unsupported raw evidence, ambiguous evidence, contradictory evidence, unresolved evidence, imported evidence, traditional evidence, Everyone Hits evidence, unknown mode evidence, omitted roster member, participant absent from current roster, and historical evidence.

Completeness is intentionally conservative. The foundation does not hardcode a nine-player rule, does not validate defensive legality, does not implement batter progression, and does not repair duplicate or missing slots.

<!-- MARK: - 10. Roster and Historical Boundaries -->
## 10. Roster and Historical Boundaries

Current roster membership remains distinct from lineup membership. A current roster member can be omitted from lineup evidence. A lineup participant can be absent from the current roster. A historical player can remain in lineup evidence after roster removal or team changes.

Current player rename, jersey-number change, team change, roster removal, roster addition, `Player.batOrder` change, photo change, and position change do not rewrite historical lineup identity or membership. The foundation represents the distinction only; it does not add persistence snapshots.

<!-- MARK: - 11. Batting Position Pitcher and Substitution Boundaries -->
## 11. Batting Position Pitcher and Substitution Boundaries

Raw batting-slot evidence can be known, missing, invalid, unsupported, non-hitting sentinel, or conflicting. It remains separate from player identity, roster order, source-file order, display order, and batting progression.

Raw position evidence can be present, blank, missing, unknown, or conflicting. It is preserved only as lineup evidence for later defensive-position work.

Pitcher-role evidence and substitution-boundary evidence are preserved only where lineup evidence requires them. The foundation does not implement active pitcher projection, pitcher statistics, substitution transactions, replacement pairing, or substitution timing.

<!-- MARK: - 12. Ordering Semantics -->
## 12. Ordering Semantics

Source-file order is represented explicitly as `OrderEvidence(kind: .sourceFile, ...)`. Batting-slot evidence remains separate from source order, roster order, display sort, jersey-number sort, defensive-position sort, batter progression, and substitution chronology.

The foundation does not add `Comparable` and does not force a total order when slots are missing, duplicated, conflicting, or ambiguous. Repeated classification is deterministic and does not depend on dictionary order, SwiftData fetch order, current date, locale, time zone, network, or random identifier generation.

<!-- MARK: - 13. Compatibility Evidence -->
## 13. Compatibility Evidence

Compatibility tests read existing fixtures without mutation: `LineupGame.ScoreKeep_Games`, `CompletedGame.ScoreKeep_Games`, `MinimalValid.ScoreKeep_Games`, `MissingOptionalValues.ScoreKeep_Games`, `DuplicateConflict.ScoreKeep_Games`, `BrokenLineupRelationship.ScoreKeep_Games`, `ConflictingTeamIdentity.ScoreKeep_Games`, `MultipleAtbats.ScoreKeep_Games`, `PitcherGame.ScoreKeep_Games`, `CompleteRoster.ScoreKeep_Players`, `MinimalValid.ScoreKeep_Players`, and `DuplicatePlayerID.ScoreKeep_Players`.

Fixture evidence is interpreted as imported lineup evidence, imported game evidence, roster-boundary evidence, historical participant evidence, missing evidence, unsupported evidence, or unresolved relationship evidence only. No transport structures, Codable keys, fixture files, import routes, export routes, matching rules, download behavior, persistence application, or review UI were changed.

<!-- MARK: - 14. Tests Added -->
## 14. Tests Added

Lineup identity tests cover matching valid identifiers, display changes, conflicting game evidence, conflicting team-side evidence, distinct identifiers with identical entries, missing identity, invalid identity, duplicate lineup evidence, and unresolved equivalence.

Game and side tests cover home lineup, visiting lineup, distinct sides, same lineup evidence applied to both sides, missing game identity, invalid game identity, missing side, unresolved side, team-side conflicts, and participant-side conflicts.

Membership, traditional, Everyone Hits, completeness, historical, ordering, and compatibility tests cover duplicate participants, same-name players, same-number players, omitted roster members, participants absent from current roster, missing participants, invalid participants, missing slots, duplicate slots, sentinel values, more or fewer than nine entries, empty lineups, incomplete lineups, unsupported evidence, ambiguous evidence, contradictory evidence, current record edits not rewriting historical facts, deterministic source-order preservation, and read-only fixture interpretation.

<!-- MARK: - 15. Production Routing Status -->
## 15. Production Routing Status

No production workflow references the new foundation after this task. App startup, model-container creation, team and player editors, roster screens, game setup, score setup, starting-lineup selection, edit-lineup behavior, live scoring, current-batter selection, next-batter selection, corrections, pitcher workflows, replacement workflows, imports, exports, reports, PDFs, seed logic, purchases, allowances, navigation, and deep links remain legacy-owned.

The new source has no SwiftData annotations, no model-container references, no filesystem writes, no import/export entry points, no StoreKit or Keychain access, no migration behavior, no production adapter, no UI, and no random identifier generation during classification.

<!-- MARK: - 16. Limitations Risks and Next Task -->
## 16. Limitations Risks and Next Task

Limitations: this task does not introduce batting-order progression, current or next batter projection, defensive-position authority, pitcher responsibility, substitution authority, game authority, scoring authority, persistence adapters, migration, compatibility adapters, import/export replacement, reports, UI, services, production routing, deletion behavior, repair behavior, or historical snapshot persistence.

Risks: later tasks must preserve the distinction between reusable player identity, current roster membership, game participation, lineup membership, batting slot, defensive position, pitcher participation, substitution history, display order, source order, and historical evidence. Name-based import matching, current `Player.batOrder`, current `Lineup.players`, current lineup export limitations, first-inning placeholder at-bats, `Game.replaced`, `Game.incomings`, reports, PDFs, and scorecard calculations remain active legacy evidence until accepted replacement tasks route new authorities.

Recommended next task: `1.6 Batting-order semantics`.

Task `1.6` should use lineup meaning to prepare batting-slot order and progression semantics while current `Player.batOrder`, lineup sorting, current-batter, next-batter, scoring, import, export, and report writers remain active. It must not route production scoring, rewrite `Player.batOrder`, change current lineup editing, change scoring, change imports or exports, or begin defensive-position authority. According to Document 29, the task following `1.6` is `1.7 Defensive position semantics`.

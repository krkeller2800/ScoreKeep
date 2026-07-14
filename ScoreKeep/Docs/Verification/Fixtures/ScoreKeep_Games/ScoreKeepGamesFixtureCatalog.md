# ScoreKeep Games Fixture Catalog

<!-- MARK: - 1. Purpose and Authority -->
## 1. Purpose and Authority

This catalog completes implementation-catalog task `0.10 Additional .ScoreKeep_Games fixture curation` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The fixture set is reviewed verification evidence for later deterministic game compatibility, scoring replay, persistence, migration, import, export, duplicate, and failure tests. It does not change production behavior, add a file format, approve new compatibility fields, import records, retire a legacy route, replace the production seed, or make legacy behavior the future architecture.

The governing evidence is Documents 19, 20, 21, 27, 28, and 29, `ScoreKeep/Docs/CompatibilityRouteInventory.md`, `ScoreKeep/Common/CommonData.swift`, `ScoreKeep/Sharing Data/ImportPlayersView.swift`, `ScoreKeep/Sharing Data/ImportService.swift`, `ScoreKeep/Sharing Data/ShareContentView.swift`, `ScoreKeep/Objects/Game.swift`, `ScoreKeep/Objects/Atbat.swift`, `ScoreKeep/Objects/Lineup.swift`, `ScoreKeep/Objects/Pitcher.swift`, `ScoreKeep/Objects/Player.swift`, `ScoreKeep/Objects/Team.swift`, and the production seed at `ScoreKeep/Seed/seededGame.ScoreKeep_Games`.

<!-- MARK: - 2. Fixture Location Decision -->
## 2. Fixture Location Decision

Fixture directory: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games`.

Catalog path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/ScoreKeepGamesFixtureCatalog.md`.

Repository inspection confirmed the established roster fixture sibling at `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players` and confirmed no existing `ScoreKeep_Games` fixture sibling. Repository search found one existing `.ScoreKeep_Games` file at `ScoreKeep/Seed/seededGame.ScoreKeep_Games`; that file remains a production seed route and is intentionally separate from verification-only fixtures. These new files are not app resources, are not added to project membership, and do not participate in first-launch seeding.

<!-- MARK: - 3. Confirmed Game File Structure -->
## 3. Confirmed Game File Structure

Current `.ScoreKeep_Games` content decodes as one top-level JSON object matching `ShareGame`.

Confirmed `ShareGame` keys are `id`, `date`, `location`, `highLights`, `hscore`, `vscore`, `everyOneHits`, `numInnings`, `vteam`, `hteam`, `players`, `atbats`, `lineups`, `pitchers`, `replaced`, and `incomings`. `id` is a UUID string. `date` is a string; current evidence uses string ISO-style values and does not require a `Date` decoder. Scores and inning count are integers. `everyOneHits` is a Boolean. `vteam` and `hteam` are required nested `ShareTeam` values. Arrays are required by Codable when absent from hand-authored JSON, even though the Swift structs have default values.

Confirmed nested structures:

| Type | Confirmed keys and representation |
| --- | --- |
| `ShareTeam` | `id`, `name`, `coach`, `details`, `players`, `games`, `logo`; `id` is UUID string, `logo` is base64 `Data`, and empty string decodes as empty data. |
| `SharePlayer` | `id`, `name`, `number`, `position`, `batDir`, `batOrder`, `team`, `atbats`, `photo`; `team` may be `null`, `photo` is base64 `Data`, and empty string decodes as empty data. |
| `ShareAtbat` | `id`, `game`, `team`, `player`, `result`, `maxbase`, `batOrder`, `outAt`, `inning`, `seq`, `col`, `rbis`, `outs`, `sacFly`, `sacBunt`, `stolenBases`, `earnedRun`, `playRec`, and `endOfInning`. `inning` decodes as `CGFloat` from JSON numbers, including fractional half-inning evidence such as `1.5`. |
| `ShareLineup` | `id`, `everyoneHits`, `game`, `team`, `inning`, and `players`. Current export creates lineups without preserving `players`, but current decode and import structures support the `players` array when present. |
| `SharePitcher` | `id`, `player`, `team`, `game`, `startInn`, `sOuts`, `sBats`, `endInn`, `eOuts`, `eBats`, `strikeOuts`, `walks`, `hits`, `runs`, and `won`. |

Confirmed current routes decode with `JSONDecoder` only. There is no schema version, root-shape classifier, content-type check, unknown-field policy, semantic validator, or isolated import transaction in the current user-routed path.

<!-- MARK: - 4. Required, Optional, and Unsupported Fields -->
## 4. Required, Optional, and Unsupported Fields

Required for current JSON decoding: every non-optional stored property listed in the transport structs, including array keys. Required game relationships: `vteam` and `hteam`. Required child relationships: at-bats require a nested team and player, lineups require a nested team, and pitchers require a nested player and team.

Confirmed optional or nullable fields are limited by the transport structs: `SharePlayer.team`, `ShareAtbat.game`, `ShareLineup.game`, and `SharePitcher.game` may be `null`. Blank strings are accepted for current string fields but are not necessarily approved product meaning. Empty arrays are accepted. Empty base64 strings decode as empty `Data`.

Unsupported or not serialized as first-class game fields: game lifecycle status, completed flag, current count, balls, strikes, explicit current batter, explicit current pitcher state separate from pitcher records, base occupancy, half-inning enum, play-by-play runner identities, explicit score progression per event, substitution timing, substitution role, and compatibility version.

Case-variant decision: no case-variant `.ScoreKeep_Games` fixture was created in task 0.10. Device-specific filename case behavior is a route-level file-open concern and belongs with malformed and unsupported fixture expansion or route tests, not the core game structure set.

Unsupported-extension decision: no wrong-extension fixture was created in task 0.10. Document 29 separates malformed and unsupported fixture curation into task `0.11`, which should cover wrong extension routing without changing the game decoder contract.

<!-- MARK: - 5. Fixture Inventory -->
## 5. Fixture Inventory

| Filename | Category | Expected decoder result | Primary purpose |
| --- | --- | --- | --- |
| `MinimalValid.ScoreKeep_Games` | Valid minimal game | Decode as one `ShareGame` with two teams and one player per side | Smallest current-contract game with required keys, sides, players, and empty child arrays. |
| `InProgressGame.ScoreKeep_Games` | Valid in-progress representative game | Decode as one `ShareGame` with stored score and two at-bats | Exercises partial event evidence without inventing missing game-status fields. |
| `CompletedGame.ScoreKeep_Games` | Valid completed representative game | Decode as one `ShareGame` with final stored score, at-bats, lineup evidence, and pitcher evidence | Exercises compact completed-game compatibility evidence. |
| `MultipleAtbats.ScoreKeep_Games` | Valid ordered event game | Decode as one `ShareGame` with four ordered at-bats | Exercises event ordering, repeated batter appearance, score evidence, and supported result strings. |
| `LineupGame.ScoreKeep_Games` | Valid lineup game | Decode as one `ShareGame` with a lineup containing players | Exercises current lineup transport where player lists are present. |
| `PitcherGame.ScoreKeep_Games` | Valid pitcher game | Decode as one `ShareGame` with two pitcher records | Exercises pitcher identity, team association, appearance boundaries, and aggregate evidence. |
| `MissingOptionalValues.ScoreKeep_Games` | Valid missing or optional values | Decode as one `ShareGame` with blank strings, empty arrays, `team: null`, and zero inning count | Exercises confirmed optional and blank values without omitting required keys. |
| `DuplicateConflict.ScoreKeep_Games` | Valid duplicate or conflict-oriented game | Decode as one `ShareGame` with same-team same-date conflict setup | Supports later duplicate detection by visiting team, home team, and date. |
| `SeedCompatibility.ScoreKeep_Games` | Valid seed-pattern compatibility fixture | Decode as one `ShareGame` using the same root contract as the production seed | Provides synthetic seed-route structure evidence without copying production seed data. |
| `MalformedJSON.ScoreKeep_Games` | Malformed game input | Reject during JSON parsing | Exercises truncated JSON rejection before persistence. |
| `WrongContent.ScoreKeep_Games` | Wrong content with game extension | Reject before `ShareGame` decode succeeds | Exercises extension-is-not-content risk with synthetic HTML. |

All newly created names, teams, identifiers, dates, fields, and file contents are synthetic. No real youth-player names, user-created teams, photos, logos, locations, contact information, purchase records, private files, live URLs, or personal records are included.

<!-- MARK: - 6. Minimal Valid Game -->
## 6. Minimal Valid Game

Exact filename: `MinimalValid.ScoreKeep_Games`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/MinimalValid.ScoreKeep_Games`.

Purpose: establish the smallest reviewed game that the current `ShareGame` decoder should accept while still carrying the required game envelope, two side teams, and minimum player structure.

Provenance: hand-authored from `ShareGame`, `ShareTeam`, and `SharePlayer` stored properties in `CommonData.swift`, with the root object confirmed by `ImportPlayersView.decodeGame()` and `ImportService.decodeGame(from:)`.

Expected decoder result: one game dated `2026-04-01T18:00:00Z`, visiting team `Fixture Minimal Visitors`, home team `Fixture Minimal Home`, one player on each side, empty at-bats, empty lineups, empty pitchers, and no substitution arrays.

Expected validation result: valid compatibility game evidence under the current decoder. Later rewrite validation may classify it as an unscored or setup-only game rather than completed.

Expected review behavior: local file-open should preview one incoming game with date and team names. Current preview does not display full player or child details.

Expected persistence result if confirmed: current import should create or resolve two teams, create side players, create the game record, and create no at-bats, lineups, pitchers, replacements, or incoming players. This task did not perform persistence.

Required preexisting state: none for decode. No destination game is required.

Compatibility route exercised: local game import, seed-style decode shape, and later decode-only compatibility tests.

Scoring or replay relevance: establishes the empty-event baseline for replay readiness and validation warnings.

Migration relevance: provides minimum relationship evidence for game identity, side teams, and participants.

Known limitations: does not cover event ordering, stored-score reconciliation, lineups, pitchers, substitution evidence, media, export byte shape, or import duplicate behavior.

Current risks: current import may create records through multiple save points after user confirmation; no isolated transaction evidence exists in this task.

Follow-up verification need: decode-only test, review-state test, and isolated import test after persistence isolation exists.

<!-- MARK: - 7. Representative In-Progress Game -->
## 7. Representative In-Progress Game

Exact filename: `InProgressGame.ScoreKeep_Games`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/InProgressGame.ScoreKeep_Games`.

Purpose: represent a not-complete game using only fields actually serialized by the current transport contract.

Provenance: hand-authored from current transport fields and supported result strings in `CommonData.swift`. It records stored score evidence, two side teams, several players, and two early at-bats.

Expected decoder result: one game dated `2026-04-02T18:00:00Z`, stored score `Fixture Progress Home 1`, `Fixture Progress Visitors 2`, and at-bats for `Single` and `Walk`.

Expected validation result: valid transport evidence. Later semantic validation should note that in-progress state, current count, base occupancy, current batter, and current pitcher are not serialized as independent fields and must be derived or classified from event evidence where possible.

Expected review behavior: current review should show one incoming game. It should not show current count, base occupancy, or current batter because those fields are absent from the current preview.

Expected persistence result if confirmed: current import should create teams, players, game, and two at-bats after confirmation, subject to current force-unwrap relationship assumptions. This task did not perform persistence.

Required preexisting state: none for basic decode. Destination duplicate behavior depends on an existing local game with the same visiting team, home team, and date.

Compatibility route exercised: current game decoder and local game import preview.

Scoring or replay relevance: later replay can compare stored score evidence with the two serialized at-bats and classify any incomplete-event limitations.

Migration relevance: prepares partial-game and interrupted-game interpretation.

Known limitations: does not store balls, strikes, base occupancy, current batter, current pitcher, or explicit in-progress status because the current transport does not contain those fields.

Current risks: stored score may not be fully derivable from the compact event sequence; that mismatch should become later validation evidence rather than a production fix in this task.

Follow-up verification need: replay classification for partial games and stored-score mismatch handling.

<!-- MARK: - 8. Representative Completed Game -->
## 8. Representative Completed Game

Exact filename: `CompletedGame.ScoreKeep_Games`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/CompletedGame.ScoreKeep_Games`.

Purpose: provide a compact completed-game compatibility example with final stored score, both sides, multiple players, multiple at-bats, lineup evidence, and pitcher evidence.

Provenance: hand-authored from current transport fields and current supported result strings. It intentionally avoids claiming byte-for-byte export provenance.

Expected decoder result: one game dated `2026-04-03T18:00:00Z`, stored final score home 3 and visitors 2, three at-bats, one lineup record, and one pitcher record.

Expected validation result: valid transport evidence. Later validation should distinguish direct imported fields from derived replay projections.

Expected review behavior: current review should show one incoming game. It does not currently preview at-bats, lineups, pitchers, or score reconciliation details.

Expected persistence result if confirmed: current import should create or resolve teams and players, then create the game, at-bats, lineup, and pitcher after confirmation. This task did not perform persistence.

Required preexisting state: none for decode. Duplicate behavior requires preexisting same visiting team, home team, and date.

Compatibility route exercised: full game import structure within current supported fields.

Scoring or replay relevance: provides final-score reconciliation, multiple events, lineup, and pitcher evidence for later scoring and replay tests.

Migration relevance: prepares complete-game relationship loading and stored-score preservation.

Known limitations: no explicit completed status exists in `ShareGame`; completion is represented only by stored score, expected innings, highlight text, and event evidence.

Current risks: current lineup export can lose lineup player lists, and current import preview does not surface child-record warnings before persistence.

Follow-up verification need: semantic replay, projection, report, and persistence round-trip tests.

<!-- MARK: - 9. Multiple At-Bats or Scoring Events -->
## 9. Multiple At-Bats or Scoring Events

Exact filename: `MultipleAtbats.ScoreKeep_Games`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/MultipleAtbats.ScoreKeep_Games`.

Purpose: provide a small human-reviewable ordered at-bat sequence for later deterministic ordering and replay verification.

Provenance: hand-authored from `ShareAtbat` fields and supported result strings `Single`, `Ground Out`, `Double`, and `Strikeout`.

Expected decoder result: one game dated `2026-04-04T18:00:00Z` with four at-bats ordered by `seq` values 1 through 4 and a repeated appearance by `Fixture Morgan Sequence`.

Expected validation result: valid transport evidence. Later validation should verify whether event order is taken from `seq`, inning, column, or a defined combination.

Expected review behavior: current review should present one incoming game but does not show the event stream.

Expected persistence result if confirmed: current import should create four at-bats except placeholder rows matching the current skip condition; this fixture contains no placeholder row. This task did not perform persistence.

Required preexisting state: none for decode.

Compatibility route exercised: game at-bat decode and import child handling.

Scoring or replay relevance: prepares ordering, repeated batter, score progression, and replay-input tests.

Migration relevance: prepares migration classification for event order, scorecard column, and repeated participant evidence.

Known limitations: it does not include unsupported result strings, runner identity, full base-state transitions, or score-by-event fields because the current format does not serialize a full runner model.

Current risks: current import force unwraps at-bat team and player resolution in `ImportPlayersView`; malformed references should be tested later in isolation.

Follow-up verification need: decode-only and replay-order tests after the compatibility layer exists.

<!-- MARK: - 10. Lineup Data -->
## 10. Lineup Data

Exact filename: `LineupGame.ScoreKeep_Games`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/LineupGame.ScoreKeep_Games`.

Purpose: exercise current lineup transport where `ShareLineup.players` are present and tied to one side team.

Provenance: hand-authored from `ShareLineup` fields. Repository evidence shows current transport supports the `players` array and current import consumes it, but current export uses `ShareLineup(everyoneHits:team:inning:)` and therefore omits lineup players.

Expected decoder result: one game dated `2026-04-05T18:00:00Z` with one visiting-side lineup at inning 1 and two lineup players.

Expected validation result: valid transport evidence representing the intended current compatibility contract when lineup players are present.

Expected review behavior: current review should show one incoming game and does not preview lineup details.

Expected persistence result if confirmed: current import should resolve the lineup team and append lineup players that match or can be created through the import path. This task did not perform persistence.

Required preexisting state: none for decode.

Compatibility route exercised: lineup decode and game child import.

Scoring or replay relevance: prepares batting-order and lineup-mode verification.

Migration relevance: prepares incomplete-lineup and lineup-player-list preservation checks.

Known limitations: this fixture does not reproduce the current export defect as the only valid shape. It documents that export-generated lineups may lose player lists, while the transport contract can carry them.

Current risks: current import force unwraps the lineup team in `ImportPlayersView`; missing or third-team lineup references should be tested later in isolated failure fixtures.

Follow-up verification need: round-trip export test to prove and classify lineup player-list loss.

<!-- MARK: - 11. Pitcher Data -->
## 11. Pitcher Data

Exact filename: `PitcherGame.ScoreKeep_Games`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/PitcherGame.ScoreKeep_Games`.

Purpose: exercise current pitcher transport with pitcher identity, team association, appearance boundaries, aggregate statistics, and win marker.

Provenance: hand-authored from `SharePitcher` fields and `Pitcher` model evidence.

Expected decoder result: one game dated `2026-04-06T18:00:00Z` with two pitcher records, one for each side.

Expected validation result: valid transport evidence. Later semantic validation should distinguish appearance boundary facts from aggregate or derived pitching totals.

Expected review behavior: current review should show one incoming game and does not preview pitcher details.

Expected persistence result if confirmed: current import should create pitcher records attached to resolved teams and players. This task did not perform persistence.

Required preexisting state: none for decode.

Compatibility route exercised: pitcher decode and game child import.

Scoring or replay relevance: prepares pitcher responsibility, appearance ordering, and aggregate-stat reconciliation.

Migration relevance: prepares pitcher relationship integrity and incomplete-period checks.

Known limitations: no explicit pitcher-change event timing exists beyond start/end inning, outs, and batter counters.

Current risks: current import can create detached player/team objects in some pitcher paths and uses multiple saves; relationship integrity needs isolated tests.

Follow-up verification need: pitcher-period validation, overlap detection, and persistence round-trip tests.

<!-- MARK: - 12. Missing or Optional Values -->
## 12. Missing or Optional Values

Exact filename: `MissingOptionalValues.ScoreKeep_Games`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/MissingOptionalValues.ScoreKeep_Games`.

Purpose: exercise values confirmed as nullable, blank, zero, or empty without creating a fixture expected to crash the importer.

Provenance: hand-authored from current Codable evidence. `SharePlayer.team` is optional and is represented as `null`; string fields remain present but blank; arrays remain present and empty; `numInnings` is zero because the transport allows an integer but later validation may warn.

Expected decoder result: one game dated `2026-04-07T18:00:00Z` with blank location and highlights, zero inning count, one player with blank number, position, and batting direction, `team: null`, one empty lineup, and no at-bats or pitchers.

Expected validation result: valid under current decoding. Later rewrite validation should classify blank or zero baseball values separately from malformed JSON.

Expected review behavior: current review should show one incoming game. It does not currently surface blank field warnings.

Expected persistence result if confirmed: current import may create teams and a player with blank fields. This task did not perform persistence.

Required preexisting state: none for decode.

Compatibility route exercised: optional player team evidence, blank strings, empty arrays, and zero integer values.

Scoring or replay relevance: prepares validation of incomplete setup and unready game states.

Migration relevance: prepares optional/blank-field classification without data loss.

Known limitations: it does not omit non-optional keys and does not use `null` for non-optional strings, arrays, UUIDs, integers, or `Data`.

Current risks: the distinction between architecturally optional values and accidentally permissive legacy behavior remains unresolved until rewrite validation is implemented.

Follow-up verification need: explicit validation rules for blank strings, zero innings, and absent optional team evidence.

<!-- MARK: - 13. Duplicate or Conflict Scenario -->
## 13. Duplicate or Conflict Scenario

Exact filename: `DuplicateConflict.ScoreKeep_Games`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/DuplicateConflict.ScoreKeep_Games`.

Purpose: provide a structurally valid game that can trigger current duplicate or conflict behavior when destination state already contains a game with the same visiting team, home team, and date.

Provenance: hand-authored from the duplicate behavior documented in `CompatibilityRouteInventory.md` and implemented in `ImportPlayersView.sharedGamesBoss` and `ImportService.importShareGames`.

Expected decoder result: one game dated `2026-04-08T18:00:00Z` with visiting team `Fixture Conflict Visitors`, home team `Fixture Conflict Home`, stored score 4-4, and same jersey number evidence on one player per side.

Expected validation result: valid compatibility game evidence. Same-team same-date is not malformed by itself; duplicate behavior depends on local state.

Expected review behavior: with no destination state, current review should show one incoming game. With a preexisting local game matching visiting team, home team, and exact date, current UI detects a duplicate and shows an alert asking the user to delete the existing game before import.

Expected persistence result if confirmed: destination-state dependent. With no duplicate, current import may create records. With a duplicate, current user-routed path should avoid creating the game and show the duplicate alert; service path skips duplicates. This task did not perform persistence.

Required preexisting state: for conflict behavior, create an isolated local game with visiting team `Fixture Conflict Visitors`, home team `Fixture Conflict Home`, and date `2026-04-08T18:00:00Z`.

Compatibility route exercised: current game duplicate matching by team names and date.

Scoring or replay relevance: prepares doubleheader and duplicate-game distinction tests.

Migration relevance: prepares identity matching tests that must not rely solely on team names and date.

Known limitations: the fixture itself cannot create a conflict without destination state and does not include setup code.

Current risks: current matching may reject legitimate same-team same-date doubleheaders and does not use stable game identifiers for matching.

Follow-up verification need: isolated duplicate review and no-persistence assertions.

<!-- MARK: - 14. Invalid Content Fixtures -->
## 14. Invalid Content Fixtures

Exact filename: `MalformedJSON.ScoreKeep_Games`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/MalformedJSON.ScoreKeep_Games`.

Purpose: represent a realistic truncated game file. Expected decoder result is JSON parse failure before `ShareGame` decoding succeeds. Expected validation, review, and persistence results are rejection, no reviewable game records, and no persistence.

Exact filename: `WrongContent.ScoreKeep_Games`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games/WrongContent.ScoreKeep_Games`.

Purpose: represent wrong content saved with the game extension. The content is small synthetic HTML, not copied from any website. It has no scripts, tracking, external dependencies, private content, or live URLs. Expected decoder result is failure before `ShareGame` decoding succeeds. Expected validation, review, and persistence results are rejection, no reviewable game records, and no persistence.

Required preexisting state: none.

Compatibility route exercised: malformed local file, wrong-content local file, and extension-is-not-content risk.

Scoring or replay relevance: none beyond proving invalid files do not become replay inputs.

Migration relevance: prepares corrupted compatibility-source classification.

Known limitations: these fixtures do not cover empty files, unrelated valid JSON, unsupported future required structure, wrong extension routing, case variants, or media corruption.

Current risks: current decode failure is alert-based and does not have a separate no-persistence verifier in this task.

Follow-up verification need: decode-only rejection tests, route-level file-open tests, and no-persistence assertions.

<!-- MARK: - 15. Seed, Media, Substitution, and Export Decisions -->
## 15. Seed, Media, Substitution, and Export Decisions

Seed compatibility decision: `ScoreKeep/Seed/seededGame.ScoreKeep_Games` was inspected as production seed evidence and left unchanged. It is structurally compatible with the same `ShareGame` root contract and includes nested teams, players, at-bats, lineups, pitchers, and arrays. It appears to carry real professional team/player names, so it was not copied into verification fixtures. `SeedCompatibility.ScoreKeep_Games` is a fully synthetic seed-pattern fixture that preserves the root contract and seed-route style without participating in first-launch seeding.

Media decision: no game-specific media fixture was created. `ShareTeam.logo` and `SharePlayer.photo` use the same base64 `Data` representation already covered by the roster media fixture. Game files can carry media through nested teams and players, but adding media here would not add game-specific compatibility coverage. Later media persistence and game export tests should decide whether a game-specific media fixture is needed.

Substitution decision: no `SubstitutionGame.ScoreKeep_Games` fixture was created. The current transport has `replaced` and `incomings` arrays, and current import appends matching players from those arrays, but the format does not explicitly store substitution timing, role, batting slot, inning, or one-to-one pairing. Documents 19, 20, and 21 treat these arrays as ambiguous substitution evidence. A fixture that pretends they are complete substitution events would invent semantics. Substitution verification is deferred to canonical scoring, migration, or later compatibility-warning fixtures.

Export-round-trip decision: no `ExportRoundTrip.ScoreKeep_Games` fixture was created. Current game export is owned by `ShareContentView.generateGame()`, which reads live SwiftData state and writes app Documents through the production route. No existing isolated non-mutating export harness or safe deterministic fixture-generation path was found. Current export also omits lineup player lists. A manually authored file would not be honest exporter provenance. Later task `4.16 Round-trip verification` should generate export evidence from isolated persistence after task `0.13 Test persistence isolation setup` or an equivalent safe harness exists.

Seed-derived fixture: `SeedCompatibility.ScoreKeep_Games` is synthetic and does not duplicate the production seed. Production seed and verification fixture responsibilities remain separate: seed supports app first-launch behavior, while fixtures support later compatibility tests.

<!-- MARK: - 16. Unsafe Decode and Current Risk Evidence -->
## 16. Unsafe Decode and Current Risk Evidence

Current unsafe assumptions found in user-routed game import:

| Area | Current evidence | Risk prepared for later verification |
| --- | --- | --- |
| At-bat team and player resolution | `ImportPlayersView.doAtbats` force unwraps `team!` and `player!` after name lookup. | Missing team, third-team at-bat, unknown player, or unexpected order may crash or fail unsafely. |
| Lineup team resolution | `ImportPlayersView.doLineups` force unwraps `team!` and silently omits unmatched lineup players. | Missing lineup team can crash; missing lineup players can lose lineup meaning. |
| Pitcher relationships | `ImportPlayersView.doPitchers` creates team/player fallbacks but does not clearly attach all fallback records to the imported side. | Pitcher relationship integrity and detached player handling need isolated tests. |
| Replacement and incoming arrays | `doReplaced` and `doIncomings` append matching players only when team and player names resolve. | Substitution evidence can be silently dropped and lacks timing or pairing. |
| Duplicate game matching | Current UI checks visiting team name, home team name, and exact date. | Same-team same-date doubleheaders can be treated as duplicates. |
| Lineup export | `ShareContentView.getLineups` does not include `lineup.players`. | Export may lose lineup player lists silently. |
| Game child preview | Current game review previews date and team names, not at-bats, lineups, pitchers, substitutions, or warnings. | Users cannot inspect all imported child evidence before confirmation. |
| Transaction boundary | Current import saves across teams, players, at-bats, lineups, pitchers, and final game relationships without an isolated transaction plan. | Partial import or save failure may leave incoherent records. |

Malformed or incomplete crash-inducing scenarios were not executed against the normal app. They should be added only after a decode-only and isolated persistence harness exists.

<!-- MARK: - 17. Validation, Limits, and Next Task -->
## 17. Validation, Limits, and Next Task

Validation performed for this catalog task should include JSON syntax checks for all intended valid fixtures, structural field checks against the current transport model, confirmation that malformed and wrong-content files fail for the intended reason, repository diff review, and `git diff --check`. Current production decoder execution is optional only if it can run non-mutatively; persistence import must not be run against real user data.

Current production decoder execution decision: full user-routed production import was not performed because it would require app UI and could proceed toward real SwiftData writes after confirmation. Non-mutating syntax and structural validation are sufficient for this fixture-only task unless an existing safe decoder harness is available.

Isolated persistence decision: no isolated persistence import was available or created in this task. No fixture was imported into real user data.

The fixture set prepares later verification for force-unwrap failures, duplicate team/date matching, lineup export information loss, multiple at-bat ordering, team and player relationship integrity, pitcher relationship integrity, seed compatibility, export and reimport, missing optional values, malformed game data, wrong content with a valid extension, cold- and warm-launch file-open behavior, duplicated game import implementations, persistence transaction safety, replay, and correction.

Recommended next task: `0.11 Malformed and unsupported fixture curation`.

Why it should follow: tasks `0.9` and `0.10` now provide representative roster and game compatibility fixtures. Task `0.11` can extend failure coverage across malformed, unsupported, wrong-extension, empty, truncated, future-required, and media-corrupt inputs without changing production behavior.

Dependencies: it depends on the completed roster fixture set under `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players` and this game fixture set under `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games`.

Authority prepared: failure classification and compatibility rejection evidence for later Phase 4 decode, validation, preview, and no-persistence tests.

What it may change: only additional verification fixtures and their catalog evidence, if Document 29 task scope allows.

What it must not change: production import/export behavior, document routes, UTI declarations, project membership, seed behavior, persistence models, scoring, replay, migration, StoreKit configuration, existing fixtures, or user data.

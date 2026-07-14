# ScoreKeep Players Fixture Catalog

<!-- MARK: - 1. Purpose and Authority -->
## 1. Purpose and Authority

This catalog completes implementation-catalog task `0.9 Representative .ScoreKeep_Players fixture curation` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The fixture set is reviewed verification evidence for later deterministic compatibility tests. It does not change production behavior, add a file format, approve new compatibility fields, import records, retire a legacy route, or make legacy behavior the future architecture.

The governing evidence is Documents 21, 27, 28, and 29, `ScoreKeep/Docs/CompatibilityRouteInventory.md`, `ScoreKeep/Common/CommonData.swift`, `ScoreKeep/Sharing Data/ImportPlayersView.swift`, `ScoreKeep/Sharing Data/ImportService.swift`, `ScoreKeep/Sharing Data/ShareContentView.swift`, `ScoreKeep/Objects/Player.swift`, `ScoreKeep/Objects/Team.swift`, and the existing seeded game location at `ScoreKeep/Seed/seededGame.ScoreKeep_Games`.

<!-- MARK: - 2. Fixture Location Decision -->
## 2. Fixture Location Decision

Fixture directory: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players`.

Catalog path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players/ScoreKeepPlayersFixtureCatalog.md`.

Document 29 identifies task 0.9 as fixture-only and requires choosing a support location before adding roster fixtures. Document 27 identifies `ScoreKeep/Docs/Verification/16-AcceptanceFixturesAndRegressionScenarios.md` as the acceptance fixture catalog and states that no checked-in `.ScoreKeep_Players` fixture existed during inspection. Repository inspection found no tracked roster fixture directory and found the only checked-in `.ScoreKeep_Games` file at `ScoreKeep/Seed/seededGame.ScoreKeep_Games`, which is a production seed route and not an appropriate location for new verification-only roster fixtures. The chosen path stays under the existing verification documentation tree, avoids production resources, and avoids creating a new top-level hierarchy.

<!-- MARK: - 3. Confirmed Roster File Structure -->
## 3. Confirmed Roster File Structure

Current `.ScoreKeep_Players` content decodes as a top-level JSON array of `SharePlayer`.

Confirmed `SharePlayer` keys are `id`, `name`, `number`, `position`, `batDir`, `batOrder`, `team`, `atbats`, and `photo`. `id` is a UUID string. `number`, `position`, and `batDir` are strings. `batOrder` is an integer. `team` is an optional nested `ShareTeam` value and may decode as `null`; current export writes a nested team object. `atbats` is an array. `photo` is base64-encoded `Data`; an empty string decodes as empty data.

Confirmed `ShareTeam` keys used by roster fixtures are `id`, `name`, `coach`, `details`, `players`, `games`, and `logo`. `id` is a UUID string. `players` and `games` are arrays. `logo` is base64-encoded `Data`; an empty string decodes as empty data. Current roster export writes team evidence on each player and uses empty nested arrays for the simple roster path.

The current decoder sorts decoded players by `batOrder` before preview. It performs Codable decoding only, without schema-version checks, body validation before download allowance increment, or a separate content classifier. Current import matching compares existing players by full name or matching last name.

<!-- MARK: - 4. Fixture Inventory -->
## 4. Fixture Inventory

| Filename | Category | Expected decoder result | Primary purpose |
| --- | --- | --- | --- |
| `MinimalValid.ScoreKeep_Players` | Valid minimal roster | Decode as one `SharePlayer` | Smallest current-contract roster with required keys and nested team evidence. |
| `CompleteRoster.ScoreKeep_Players` | Valid complete roster | Decode as four sorted `SharePlayer` records | Ordinary compact roster with multiple players, numbers, positions, batting directions, batting order, and team metadata. |
| `MediaRoster.ScoreKeep_Players` | Valid media roster | Decode as one `SharePlayer` with non-empty photo and logo data | Exercises supported base64 `Data` representation using a tiny synthetic PNG payload. |
| `MissingOptionalValues.ScoreKeep_Players` | Valid missing or optional values | Decode as one `SharePlayer` with `team == nil` and blank strings | Exercises optional team evidence and blank current fields while preserving required keys. |
| `DuplicateConflict.ScoreKeep_Players` | Valid duplicate or conflict-oriented roster | Decode as two `SharePlayer` records | Exercises duplicate jersey number and current full-name or last-name matching risk. |
| `MalformedJSON.ScoreKeep_Players` | Malformed roster input | Reject during JSON parsing | Exercises truncated JSON rejection before persistence. |
| `WrongContent.ScoreKeep_Players` | Wrong content with roster extension | Reject before `[SharePlayer]` decode succeeds | Exercises HTML or server-error content saved with the compatibility extension. |

All names, teams, identifiers, media, and file contents are synthetic. No real youth-player names, user-created teams, photos, logos, account identifiers, purchase records, private files, live URLs, or personal contact data are included.

<!-- MARK: - 5. Minimal Valid Roster -->
## 5. Minimal Valid Roster

Exact filename: `MinimalValid.ScoreKeep_Players`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players/MinimalValid.ScoreKeep_Players`.

Purpose: establish the smallest reviewed roster that the current `[SharePlayer]` decoder should accept.

Provenance: hand-authored from `SharePlayer` and `ShareTeam` stored properties in `CommonData.swift`, with the root array confirmed by `ImportPlayersView.decodePlayers()` and `ImportService.decodePlayers(from:)`.

Expected decoder result: one player named `Fixture Minimal Batter`, team evidence named `Fixture Minimal Club`, empty `atbats`, and empty media.

Expected validation result: valid compatibility roster evidence under the current decoder. Later rewrite validation may warn only if it adds review messaging for minimal metadata.

Expected review result: local file-open, downloaded-file handoff, or direct decoder review should present one incoming player. A destination team named from the filename or resolved from nested team evidence may be shown depending on route.

Expected persistence result if confirmed: create or update one team and one player according to the current import button path. This task did not perform persistence.

Required preexisting state: none for basic decode. No existing local team is required.

Compatibility route exercised: local roster import, downloaded roster handoff after file save, and roster decoder coverage.

Known limitations: does not cover multiple players, conflicts, media, export byte shape, or missing values.

Risks: current route derives the import team name from the filename, so later tests must distinguish filename-derived team behavior from nested team evidence.

Follow-up verification need: decode-only test, review-state test, and isolated import test once test persistence isolation exists.

<!-- MARK: - 6. Complete Roster -->
## 6. Complete Roster

Exact filename: `CompleteRoster.ScoreKeep_Players`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players/CompleteRoster.ScoreKeep_Players`.

Purpose: provide a compact ordinary roster large enough to exercise order, multiple player identities, player numbers, positions, batting directions, and team metadata.

Provenance: hand-authored from current transport fields and export evidence in `ShareContentView.generatePlayers()`. It uses the same root array and per-player nested team shape as current roster export, without claiming byte-for-byte exporter production.

Expected decoder result: four players sorted by `batOrder` values 1 through 4 for `Fixture Complete Club`.

Expected validation result: valid compatibility roster evidence with no media.

Expected review result: preview should list four incoming players and preserve their visible values.

Expected persistence result if confirmed: create or update one team and four players according to the selected current import strategy. This task did not perform persistence.

Required preexisting state: none for basic import. If a local `Fixture Complete Club` exists, current review offers `Imported` and `Current` strategies.

Compatibility route exercised: roster import, roster preview ordering, and later export/import semantic comparison.

Known limitations: does not include a full real-world roster scale, at-bats, nested team players, nested games, or media.

Risks: current import matching uses full name or last name and may update existing players if the destination state contains matching names.

Follow-up verification need: isolated persistence test confirming player count, ordering, and field preservation.

<!-- MARK: - 7. Media Roster -->
## 7. Media Roster

Exact filename: `MediaRoster.ScoreKeep_Players`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players/MediaRoster.ScoreKeep_Players`.

Purpose: exercise the currently supported media representation for roster transport.

Provenance: hand-authored from the `Data` fields `SharePlayer.photo` and `ShareTeam.logo`, which current export encodes through `JSONEncoder` and current import decodes through `JSONDecoder`. The payload is a tiny deterministic synthetic PNG used for both logo and photo.

Expected decoder result: one player with non-empty `photo` data and nested team evidence with non-empty `logo` data.

Expected validation result: valid JSON and valid base64 `Data`. Later media display tests should verify whether the image renderer accepts the PNG payload.

Expected review result: roster preview should decode the player; media may be available as imported data where the UI displays it.

Expected persistence result if confirmed: current import paths can assign incoming non-empty player photo and team logo data. This task did not perform persistence.

Required preexisting state: none for decode. Existing local team or player media creates a conflict-review scenario for later tasks.

Compatibility route exercised: roster decoder and media-bearing roster import/export compatibility.

Known limitations: one tiny synthetic image does not prove large images, corrupted media, orientation metadata, image format coverage, copyright provenance, or storage behavior.

Risks: current compatibility has no media size validation or image validation stage beyond base64 `Data` decoding.

Follow-up verification need: media display, persistence, export preservation, and corrupted-media rejection fixtures in later compatibility tasks.

<!-- MARK: - 8. Missing or Optional Values -->
## 8. Missing or Optional Values

Exact filename: `MissingOptionalValues.ScoreKeep_Players`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players/MissingOptionalValues.ScoreKeep_Players`.

Purpose: exercise values that repository evidence supports as optional or blank without making the file malformed.

Provenance: hand-authored from current Codable evidence. `team` is optional in `SharePlayer`, so the fixture records it as `null`. `number`, `position`, and `batDir` are required string keys but may contain empty strings. `photo` and `atbats` remain present because the current decoder requires those keys.

Expected decoder result: one player named `Fixture Blank Values`, blank number, blank position, blank batting direction, `batOrder` 51, no team evidence, empty `atbats`, and empty photo data.

Expected validation result: valid under current decoding. Later rewrite validation may classify missing team evidence or blank baseball hints as warnings rather than malformed JSON.

Expected review result: preview should show one incoming player; route-level team naming may fall back to the file stem.

Expected persistence result if confirmed: current import may create or use a team derived from filename and create a player with blank values. This task did not perform persistence.

Required preexisting state: none for decode.

Compatibility route exercised: decode of optional team evidence and blank current fields.

Known limitations: this fixture does not omit non-optional JSON keys because repository evidence shows current Codable decoding requires them. It does not prove `null` for non-optional strings, arrays, UUIDs, integers, or `Data`.

Risks: the distinction between architecturally optional values and accidentally permissive legacy behavior remains unresolved until rewrite validation is implemented.

Follow-up verification need: explicit validation rules for blank values, absent optional team evidence, and import review warnings.

<!-- MARK: - 9. Duplicate or Conflict Scenario -->
## 9. Duplicate or Conflict Scenario

Exact filename: `DuplicateConflict.ScoreKeep_Players`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players/DuplicateConflict.ScoreKeep_Players`.

Purpose: provide a valid roster that can trigger duplicate or conflict review in later isolated import tests.

Provenance: hand-authored from current transport fields and the matching behavior documented in `CompatibilityRouteInventory.md` and implemented in `ImportPlayersView.sharedPlayersBoss`, `ImportPlayersView.currentPlayersBoss`, and `ImportService.upsertSharedPlayers`.

Expected decoder result: two players on `Fixture Conflict Club`, both using jersey number `8`, with different full names, batting order values, batting directions, and positions.

Expected validation result: valid compatibility roster. Duplicate jersey numbers are not malformed.

Expected review result: with no destination state, preview should show two distinct incoming players. With a preexisting local player whose full name or last name matches either incoming player, current import paths may update that local player depending on `Imported` or `Current` strategy.

Expected persistence result if confirmed: destination-state dependent. Without matching local players, current import should create two players. With a preexisting local `Fixture Gamma Conflict` or another same-last-name player on the destination team, current matching may treat an incoming player as a match. This task did not perform persistence.

Required preexisting state: for conflict behavior, create an isolated local team derived from the fixture file stem or target route and at least one local player sharing the last name `Conflict` or exact full name with an incoming player.

Compatibility route exercised: duplicate-name and last-name matching risk, duplicate number preservation, review-before-persistence workflows.

Known limitations: the fixture itself cannot create a conflict without destination state. It does not add setup code.

Risks: current last-name matching can merge unrelated players. Later rewrite behavior must review ambiguous matches rather than treating this legacy behavior as approved architecture.

Follow-up verification need: isolated import-review scenario with controlled destination state and explicit expected conflict choices.

<!-- MARK: - 10. Invalid Content Fixtures -->
## 10. Invalid Content Fixtures

Exact filename: `MalformedJSON.ScoreKeep_Players`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players/MalformedJSON.ScoreKeep_Players`.

Purpose: represent a realistic truncated roster file. Expected decoder result is JSON parse failure before `[SharePlayer]` decoding succeeds. Expected validation, review, and persistence results are rejection, no reviewable roster records, and no persistence.

Exact filename: `WrongContent.ScoreKeep_Players`.

Exact relative path: `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Players/WrongContent.ScoreKeep_Players`.

Purpose: represent downloaded or opened wrong content saved with the roster extension. The content is small synthetic HTML, not copied from any website. Expected decoder result is failure before `[SharePlayer]` decoding succeeds. Expected validation, review, and persistence results are rejection, no reviewable roster records, and no persistence.

Required preexisting state: none.

Compatibility route exercised: malformed local file, malformed downloaded file, and extension-is-not-content risk.

Known limitations: these fixtures do not cover empty files, unrelated valid JSON objects, unsupported future required structure, wrong extension routing, or media corruption.

Risks: current download route can save wrong content and increment allowance before import decode. These fixtures prepare later tests but do not fix that behavior.

Follow-up verification need: decode-only rejection tests, route-level download validation tests, and no-persistence assertions.

<!-- MARK: - 11. Deferred Fixture Categories and Route Decisions -->
## 11. Deferred Fixture Categories and Route Decisions

Export round-trip fixture: not created in this task. Repository evidence shows roster export is owned by `ShareContentView.generatePlayers()`, which reads SwiftData state through the live view and writes app Documents through the production route. No existing isolated non-mutating export harness or test persistence setup was found. Creating a manually authored file and naming it exporter-produced would overstate provenance. A later export-verification task should produce this fixture from current or rewritten export code using isolated persistence.

Case-variant fixtures: not created in this task. `CompatibilityRouteInventory.md` records device-specific case behavior: iPad lowercases path extension and has a filename fallback, while iPhone and `ShareContentView.isValidImportURL` compare exact extension strings. Case variants are routing tests rather than content-contract fixtures, and permanent case-variant files can be brittle across filesystems.

Unsupported-extension fixture: not created in this `.ScoreKeep_Players` fixture set. Unsupported extension behavior is a route-classification concern and should be represented by test setup or a separately named non-contract sample in a later routing task.

Unsupported future fields: not created in this task because the requested fixtures must not add unsupported JSON fields. Later task `0.11 Malformed and unsupported fixture curation` can add future-format simulations when expected behavior is explicitly defined.

Existing decoder verification: valid fixture syntax and structure can be checked non-mutating through JSON parsing and direct `[SharePlayer]` decode. Full import verification needs isolated persistence and was not performed here.

<!-- MARK: - 12. Recommended Next Task -->
## 12. Recommended Next Task

Recommended next task: `0.10 Additional .ScoreKeep_Games fixture curation`.

Game fixture curation should follow roster fixture curation because the seeded game is the only existing checked-in `.ScoreKeep_Games` source fixture and does not cover the range of game compatibility risks identified in Documents 21, 27, 28, 29, and `CompatibilityRouteInventory.md`.

Lessons that carry forward are fixture-only scope, synthetic data, placement under verification evidence rather than production resources, explicit catalog provenance, no real persistence import during curation, and separation between content fixtures and routing tests.

Game-specific risks to cover include ordinary unscored games, completed games, in-progress games, missing team or player references, third-team references, lineup omissions, substitutions, pitcher records, stored-score mismatch, malformed game JSON, wrong content, export round trip, and seeded-game separation.

Task 0.10 must not change production source, import or export behavior, seeded game data, scoring behavior, persistence, project settings, or route handling.

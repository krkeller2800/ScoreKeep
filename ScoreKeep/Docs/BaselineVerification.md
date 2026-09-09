# ScoreKeep Baseline Verification

Date: July 13, 2026
Branch: `scorekeep-next`

This document is a factual baseline audit of the existing application before re-engineering. Production source code, compatibility files, and `CurrentState.md` were not modified.

## 1. Development environment

| Item | Result |
| --- | --- |
| Current Git branch | `scorekeep-next` |
| Git status before creating this document | `## scorekeep-next...origin/scorekeep-next`; no short-status file changes reported |
| Xcode version | Xcode 26.5, build 17F42 |
| Swift version | Apple Swift 6.3.2, swift-driver 1.148.6, target `arm64-apple-macosx26.0` |
| Available schemes | `ScoreKeep` |
| Project targets reported by `xcodebuild -list` | `ScoreKeep`, `ScoreKeepTests`, `ScoreKeepUITests` |
| Build configurations | `Debug`, `Release` |
| Available simulator destinations | Command-line destination discovery could only report placeholders because CoreSimulatorService was unavailable: `Any iOS Device`, `Any iOS Simulator Device` |

Environment discovery commands used:

```sh
git branch --show-current
git status --short --branch
xcodebuild -version
swift --version
xcodebuild -list
xcodebuild -scheme ScoreKeep -showdestinations
xcrun simctl list devices available
```

Simulator discovery infrastructure issue:

- `xcrun simctl list devices available` failed with `CoreSimulatorService connection became invalid` and `Unable to locate device set`.
- `xcodebuild -showdestinations` completed, but logged CoreSimulator connection failures and reported only placeholder destinations.
- The sandbox also denied manual escalation for simulator access, so physical simulator device names could not be verified from this session.

## 2. Build verification

Clean Debug build command:

```sh
/usr/bin/time -p xcodebuild -scheme ScoreKeep -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/ScoreKeepDerivedData clean build
```

| Item | Result |
| --- | --- |
| Destination | `generic/platform=iOS Simulator` |
| Build duration | `real 6.30`, `user 0.60`, `sys 0.26` |
| Clean result | `** CLEAN SUCCEEDED **` |
| Build result | `** BUILD FAILED **` |
| Exit code | 65 |
| Build target reached | `ScoreKeep` application target |

Failure:

- `ScoreKeep/Common/Launch Screen.storyboard`: `error: iOS 26.5 Platform Not Installed.`
- The failure occurred during `CompileStoryboard`.

Warnings and diagnostics observed:

| Category | Observed |
| --- | --- |
| Compiler warnings | No Swift compiler warnings were observed before the storyboard failure. |
| Linker warnings | No linker warnings were observed before the storyboard failure. |
| Build setting warnings | No project build setting warnings were observed before the storyboard failure. |
| Xcode/CoreSimulator infrastructure warnings | `DVTFilePathFSEvents: Failed to start fs event stream`; `CoreSimulatorService connection became invalid`; `Unable to discover any Simulator runtimes`; `simdiskimaged` unavailable/crashed; Xcode `DVTAssertions` warnings about property-list type detection. |

The build copied bundled compatibility and documentation resources before failing, including `seededGame.ScoreKeep_Games`, `ScoreKeep.storekit`, `CurrentState.md`, `ScoreKeep-URL-Inventory.md`, and `Manual.pdf`.

## 3. Test verification

Test discovery:

- Xcode MCP `GetTestList` for active scheme/test plan `ScoreKeep` returned `0 tests (0 enabled, 0 disabled)`.
- Static test source files contain test methods:
  - `ScoreKeepTests.swift`: `ScoreKeepTests.example()` using the Swift Testing framework.
  - `ScoreKeepUITests.swift`: `ScoreKeepUITests.testExample()` and `ScoreKeepUITests.testLaunchPerformance()` using XCTest UI testing.
  - `ScoreKeepUITestsLaunchTests.swift`: `ScoreKeepUITestsLaunchTests.testLaunch()` using XCTest UI testing.

Commands attempted:

```sh
/usr/bin/time -p xcodebuild test -scheme ScoreKeep -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/ScoreKeepDerivedData -only-testing:ScoreKeepTests
/usr/bin/time -p xcodebuild test -scheme ScoreKeep -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/ScoreKeepDerivedData -only-testing:ScoreKeepUITests
```

| Target | Discovered by active test plan | Executed | Passed | Failed | Skipped | Infrastructure issues |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `ScoreKeepTests` | 0 | 0 | 0 | 0 | 0 | `xcodebuild: error: Scheme ScoreKeep is not currently configured for the test action.` CoreSimulator also unavailable. |
| `ScoreKeepUITests` | 0 | 0 | 0 | 0 | 0 | `xcodebuild: error: Scheme ScoreKeep is not currently configured for the test action.` CoreSimulator also unavailable. |

The existing source files contain placeholder tests, but the active scheme/test plan does not expose enabled tests to the Xcode test-list tool and `xcodebuild test` cannot run because the scheme is not configured for the test action.

## 4. Compatibility file verification

### Repository artifacts

Search result:

- `ScoreKeep/Seed/seededGame.ScoreKeep_Games`
- No checked-in `.ScoreKeep_Players` files were found.
- No other checked-in `.ScoreKeep_Games` files were found.

### Codable compatibility structures

Compatibility structs are defined in `Common/CommonData.swift`:

| Type | Root use | Required fields under current synthesized `Codable` decoding |
| --- | --- | --- |
| `ShareGame` | `.ScoreKeep_Games` root object | `id`, `date`, `location`, `highLights`, `hscore`, `vscore`, `everyOneHits`, `numInnings`, `vteam`, `hteam`, `players`, `atbats`, `lineups`, `pitchers`, `replaced`, `incomings` |
| `SharePlayer` | `.ScoreKeep_Players` array element and nested player object | `id`, `name`, `number`, `position`, `batDir`, `batOrder`, `team`, `atbats`, `photo` |
| `ShareTeam` | Nested team object | `id`, `name`, `coach`, `details`, `players`, `games`, `logo` |
| `ShareAtbat` | Nested game at-bat object | `id`, `game`, `team`, `player`, `result`, `maxbase`, `batOrder`, `outAt`, `inning`, `seq`, `col`, `rbis`, `outs`, `sacFly`, `sacBunt`, `stolenBases`, `earnedRun`, `playRec`, `endOfInning` |
| `ShareLineup` | Nested game lineup object | `id`, `everyoneHits`, `game`, `team`, `inning`, `players` |
| `SharePitcher` | Nested game pitcher object | `id`, `player`, `team`, `game`, `startInn`, `sOuts`, `sBats`, `endInn`, `eOuts`, `eBats`, `strikeOuts`, `walks`, `hits`, `runs`, `won` |

Important decoding detail: because these structs rely on synthesized `Codable`, stored properties with default values are still decoded with `decode`, not `decodeIfPresent`. Missing keys can fail decoding even when a Swift default exists.

### `.ScoreKeep_Games`

Producer:

- `ShareContentView.generateGame()` encodes a single `ShareGame`.
- `ShareContentView.saveGame()` writes `"<fileName>.ScoreKeep_Games"`.

Consumers:

- `ImportService.decodeSeededGame(from:)` decodes a single `ShareGame` from the bundled seed file.
- `ImportService.decodeGame(from:)` decodes a single `ShareGame` from an external security-scoped URL.
- `ImportPlayersView.decodeGame()` also decodes a single `ShareGame`.

Root JSON structure:

- Object.
- The checked-in seed root is one `ShareGame`, not an array.

Date format:

- `ShareGame.date` is a `String`.
- Current code parses it with `ISO8601DateFormatter`.
- The seed uses `2025-11-01T22:00:00Z`, which parses successfully.

UUID format:

- `id` fields are JSON strings decoded as Swift `UUID`.
- The seed uses uppercase canonical UUID strings such as `1FB19F8F-54B3-4F1C-9125-CF33B82A19C6`.

Image encoding:

- `Data` fields (`logo`, `photo`) encode/decode as base64 JSON strings.
- Empty data appears as an empty string.
- The seed decodes non-empty team logos to byte counts `6326` and `5372`.

Seed decode result using standalone Swift `JSONDecoder` and the current share structs:

- `decoded=true`
- Teams: `Dodgers at Blue Jays`
- Date: `2025-11-01T22:00:00Z`, ISO parse `true`
- Top-level players: `18`
- Visiting team players: `29`
- Home team players: `28`
- At-bats: `18`
- Lineups: `2`
- Pitchers: `1`
- Replaced: `0`
- Incomings: `0`

Import/export preservation assessment:

- Most scalar game, team, player, at-bat, pitcher, and replacement fields are included in `ShareGame`.
- `ShareContentView.getLineups(lineups:)` creates `ShareLineup(everyoneHits:team:inning:)` but does not pass `players`, so exported lineups lose their player list.
- `ShareContentView.getTempTeam(team:)` returns only `ShareTeam(name:)` for nested player teams; nested player team coach/details/logo are not preserved in those references.
- Import maps objects by team/player names and may create or merge teams/players rather than preserving original object identity.
- Export then import should preserve scoring plays and most visible game state, but it should not be assumed to preserve every relationship or all team metadata exactly.

### `.ScoreKeep_Players`

Producer:

- `ShareContentView.generatePlayers()` encodes `[SharePlayer]`.
- `ShareContentView.savePlayers()` writes `"<fileName>.ScoreKeep_Players"`.
- MLB downloads save downloaded roster files as `"<team>.ScoreKeep_Players"`.

Consumers:

- `ImportService.decodePlayers(from:)` decodes `[SharePlayer]`.
- `ImportPlayersView.decodePlayers()` decodes `[SharePlayer]`.

Root JSON structure:

- Array of `SharePlayer` objects.

Required fields:

- Same as `SharePlayer` above: `id`, `name`, `number`, `position`, `batDir`, `batOrder`, `team`, `atbats`, `photo`.

Date format:

- Player files do not carry a root date field.

UUID format:

- `id` must be a Swift `UUID` string.

Image encoding:

- `photo` and nested `team.logo` are `Data` encoded as base64 JSON strings; empty data is an empty string.

Import/export preservation assessment:

- Player name, number, position, batting direction, batting order, photo, and a nested team object are exported.
- Import intentionally merges into existing teams/players by exact name or last name, using either "Imported" or "Current" overwrite strategies.
- Export then import is not a strict round trip because merge behavior can overwrite or preserve existing non-blank fields depending on user choice.

### StoreKit configuration

File: `ScoreKeep.storekit`

Root structure:

- StoreKit configuration dictionary with `identifier`, `appPolicies`, `nonRenewingSubscriptions`, `products`, `settings`, `subscriptionGroups`, and `version`.

Products:

- Non-renewing subscription `com.komakode.ScoreKeep.SeasonPass2025`, display price `4.99`.
- Non-renewing subscription `com.komakode.ScoreKeep.SeasonPass2026`, display price `4.99`.

Implementation usage:

- `PurchaseManager` loads season pass products by product ID prefix `com.komakode.ScoreKeep.SeasonPass`.
- Paywall and gating use `purchaseManager.isSeasonPassActive`.

### Document type declarations

File: `ScoreKeep/Info.plist`

Declared document types:

| Document type | UTI | Extension | Role | Handler rank |
| --- | --- | --- | --- | --- |
| ScoreKeep Players | `com.komakode.scorekeep` | `ScoreKeep_Players` | `Editor` | `Owner` |
| ScoreKeep Games | `com.komakode.scorekeep.games` | `ScoreKeep_Games` | `Editor` | `Owner` |

UTExportedTypeDeclarations:

- Both conform to `public.data`.
- Both use MIME type `application/octet-stream`.

Discrepancies:

- `Info.plist` declares players UTI `com.komakode.scorekeep`, while `Extensions.swift` defines `UTType.myCustomFile` as `com.komakode.scorekeep.ScoreKeep_Players`.
- The games document type contains key `nNSUbiquitousDocumentUserActivityType`, which appears to be misspelled with a leading `n`.

### URL scheme declarations

File: `ScoreKeep/Info.plist`

- URL scheme: `scorekeep`
- URL name: `com.komakode.scorekeep`
- Role: `Editor`

Implementation:

- `ScoreKeepApp`, `StartView`, `StartPhoneView`, and `ShareContentView` parse `scorekeep://share?tab=download&prefill=...`.
- File URLs are separately routed as imports when the last path component or extension contains `ScoreKeep_Players` or `ScoreKeep_Games`.

## 5. Manual versus implementation

Manual read method: PDFKit extracted text from `ScoreKeep/Reporting/Manual.pdf`. The manual has 15 pages and includes a table of contents.

| Feature | Documented | Implemented | Reachable in current UI | Notes |
| --- | --- | --- | --- | --- |
| Teams | Yes | Yes | Yes | `TeamContentView`, `TeamView`, `EditTeamView`; team logo selection is implemented. |
| Players | Yes | Yes | Yes | `PlayerContentView`, `PlayersOnTeamView`, `EditPlayerView`; player photo selection is implemented. |
| Lineups | Yes | Yes | Yes | ScoreKeep 6.1 retires the legacy game-specific Starting Lineup screen. Pregame drag-and-drop preparation remains in Team Default Batting Order, which saves the Team default for newly materialized/future games; live scorecard dropdowns own safe game-time lineup correction. |
| Games | Yes | Yes | Yes | Game creation/editing appears in `ScoreContentView`, `GameView`, and `EditGameView`. |
| Scoring | Yes | Yes | Yes | `EditScoreView`, `PlayersToScoreView`, `ScoreGameView`; manual describes selecting scorecard square and recording at-bat. |
| Pitchers | Yes | Yes | Yes | `PitcherContentView`, `PitchersStaffView`, `EditPitcherView`; manual describes start/end inning/out/batter markers. |
| Substitutions | Yes | Yes | Yes | `ReplacementView` reachable from `EditScoreView` as `Replace Players`; manual uses "Replacement Player". |
| Reports | No, not in extracted table of contents | Yes | Yes, gated | `Hit Stats` and `Pitch Stats` are reachable from `EditScoreView`, guarded by premium access. |
| PDF generation | No, not in extracted manual content except bundled manual viewing | Yes | Yes, gated | `PDF` button in `EditScoreView` calls `PDFGenerator`; report PDF views exist. |
| Sharing | Yes | Yes | Yes | Manual documents sharing lineups/team or game files; implementation uses `ShareContentView` and `ShareLink`. |
| Importing | Yes | Yes | Yes | Manual documents opening shared file and choosing Imported/Current; implementation handles `.ScoreKeep_Players` and `.ScoreKeep_Games`. |
| MLB downloads | No | Yes | Yes, gated after free limit | `ShareContentView` defaults to `Download MLB Teams`, reads a compatibility manifest, downloads `.ScoreKeep_Players`, and gates free users after 4 downloads. |
| Purchases | No | Yes | Yes | `PaywallView`, `PurchaseManager`, and StoreKit config implement non-renewing season passes and premium gates for downloads/reports/PDF/game limits. |
| Paste roster | Yes | Yes | Yes | `PasteView` is reachable from navigation and implements copied roster ingestion. |
| Manual viewing | Not applicable | Yes | Yes | `PdfView` displays bundled `Manual.pdf`. |

Manual discrepancies:

- Manual documents "Share a Line Up", but implementation supports sharing both teams/players and games.
- Manual documents import primarily as "Line Up", but implementation imports both player roster files and full game files.
- Manual does not mention MLB team downloads, purchase gating/season pass, report screens, or generated scorecard PDF.
- Manual says imported players can be removed by swiping "from left to right"; SwiftUI deletion is implemented with `onDelete`, normally swipe-to-delete.
- Manual contains typos such as "Payer" and "pithing"; implementation labels differ in places.

## 6. Scoring calculation inventory

The application has multiple independent calculation sites. They should be treated as baseline behavior until regression tests are added.

| Calculation | File | Type/function | Inputs | Outputs | Duplicate implementations / differences |
| --- | --- | --- | --- | --- | --- |
| Base advancement and occupied bases | `PlayersToScoreView.swift` | `PlayersToScoreView.updMaxBases()` | Current team at-bats, `result`, `maxbase`, `outAt`, inning, `Common.onresults` | Mutates `Atbat.maxbase`; updates `InnStatus` flags | Similar base-state drawing logic exists in `GeneratePDF.doStats`; this function actively mutates max bases. |
| Outs and inning sequencing | `PlayersToScoreView.swift` | `PlayersToScoreView.seqGame()` | Sorted at-bats by `(col, seq)`, `Common.outresults`, `outAt`, `endOfInning` | Mutates `col`, `inning`, `outs`, `seq`; updates `colbox`, `batbox`, `totbox` | Independent from `ScoreGameView.setEndOfInning()` and `GeneratePDF.calcInning()`. Uses `endOfInning` as part of inning transition. |
| Runs | `PlayersToScoreView.swift` | `seqGame()` | `atbat.maxbase == "Home"` | `BoxScore.runs` in column, batter, total boxes | Same run rule repeated in report/PDF code. |
| Hits | `PlayersToScoreView.swift` | `seqGame()` | `Common.hitresults.contains(atbat.result)` | `BoxScore.hits` | Same rule repeated in report/PDF code. |
| Walks, strikeouts, HR, stolen bases | `PlayersToScoreView.swift` | `seqGame()` | Result text and `stolenBases` | `BoxScore.walks`, `strikeouts`, `HR`, `stoleBase` | Same concepts repeated in reporting and PDF totals. |
| End-of-inning detection | `ScoreGameView.swift` | `ScoreGameView.setEndOfInning()` | Game/team at-bats, `Common.outresults`, `outAt`, existing `inning` values | Mutates all same-team at-bats' `endOfInning`; toggles current `sacFly` sentinel between `0` and `-1` | Independent from `PlayersToScoreView.seqGame()`; contains tautological condition `atbat.team == atbat.team`. |
| Earned runs | `ScoreGameView.swift` | `onChange(of: atbat.result)`, earned-run toggle | At-bat result and user button | Mutates `Atbat.earnedRun` | Default is true; `Dropped 3rd Strike` and `Error` automatically mark unearned. Pitcher stats count earned vs unearned from this flag. |
| Pitcher start/end markers | `PlayersToScoreView.swift` | `updatePitcherMarkers()` | Opponent pitchers, current batter `inning`, `outs`, `seq` | Mutates pitcher `startInn`, `sOuts`, `sBats`, `endInn`, `eOuts`, `eBats` | Manual editing also exists in `EditPitcherView`. This function derives markers live during scoring. |
| Manual pitcher marker editing | `EditPitcherView.swift` | View pickers bound to `Pitcher` fields | User picker selections | Mutates pitcher inning/out/batter fields | These fields feed pitching stat calculations. |
| Hitting player stats | `ReportView.swift` | `ReportView.doStats(player:)` | Team at-bats and result strings | `PlayerStats` with at-bats, runs, hits, singles/doubles/triples/HR, walks, HBP, dropped third strike, fielder's choice, strikeouts | Duplicated in `ShowReportView.doStats`. Uses misspelled result strings `"Sacrifise fly"` and `"Sacrifise Bunt"`, while `Common` uses `"Sacrifice Fly"` and `"Sacrifice Bunt"`, so sacrifice counts may be zero. |
| Batting average / OBP / SLG | `ReportView.swift` | `PlayerStatsRow.body` | `PlayerStats` | Formatted AVG/OBP/SLG integers scaled by 1000 | `ReportView` has denominator guards and uses `Double`; `ShowReportView` uses integer arithmetic and only guards `atbats == 0`, so OBP denominator zero is not separately guarded. |
| Hitting PDF stats | `ShowReportView.swift` | `ShowReportView.doStats(player:)` and `generatePDF()` | Team at-bats and result strings | PDF rows with AVG, OBP, SLG, OPS-like display fields | Duplicates `ReportView`; uses integer arithmetic for averages. |
| Scorecard PDF at-bat totals | `GeneratePDF.swift` | `PDFGenerator.getTots(atbat:colbox:batbox:totbox:)` | Each at-bat, `Common.hitresults`, result text, `stolenBases` | Mutates PDF `BoxScore` arrays | Similar to `PlayersToScoreView.seqGame()` but indexes batter totals with `batOrder - 1`; live view uses `batOrder`. |
| Box scores | `GeneratePDF.swift` | `drawBoxScore(game:)`, `doBoxScore(game:doTeam:)`, `calcInning(game:)` | Full game at-bats, team names, `Common.hitresults`, `Common.outresults`, `outAt` | Drawn inning/runs/hits/errors summary | Errors are credited to the fielding/opposite team: for home display, errors count visiting team's `Error` result; for visiting display, errors count home team's `Error` result. No persistent `Game.hscore`/`vscore` update observed. |
| Game completion/current inning | `GeneratePDF.swift` | `calcInning(game:)` | Home and visitor outs counted from result/outAt | Current inning string for PDF | No explicit persistent game-complete state found. Manual code comments in `ImportDisplayView` mention final logic but are commented out. |
| Pitching stats | `PitcherRptView.swift` | `doPitchers(pitcher:)`, `sumData(stats:)` | Opponent at-bats, pitcher start/end inning/out/batter fields, `earnedRun` | `PitchStats`: ERA, innings, ER/UER, hits, HR, Ks/Ksl, BB, singles/doubles/triples, HBP | Duplicated in `ShowPitchRptView` and `GeneratePDF`. This version uses `Int($0.inning + 1)` and `>=` for run window start. |
| Pitching PDF stats | `ShowPitchRptView.swift` | `doPitchers(pitcher:)`, `sumData(stats:)` | Same as `PitcherRptView` | Pitching stats PDF data | Mostly duplicates `PitcherRptView`. |
| Scorecard PDF pitching stats | `GeneratePDF.swift` | `doPitchers(oAtbats:pitcher:)` | Opponent at-bats, pitcher markers | `PitchStats` for scorecard PDF | Uses `(Common.outresults.contains(result) || outAt != "Safe")` for innings and `Int(inning.rounded(.up))`; run/hit windows use `>` start comparison for some values, not `>=`. |
| RBIs | `ScoreGameView.swift` | RBI picker bound to `Atbat.rbis` | User selected RBI count | Persists `Atbat.rbis` | No independent RBI aggregation found in reports/PDF inventory; value is exported/imported in `ShareAtbat`. |
| Stolen bases | `ScoreGameView.swift` and `PlayersToScoreView.swift` | Picker bound to `Atbat.stolenBases`; `seqGame()` totals | User selected stolen-base count, on-base result | Persisted on at-bat and totalled in box score arrays | Export/import preserves `stolenBases`; hitting report views do not include SB. |
| Stored game score fields | `Game.swift`, `ShareGame` | `hscore`, `vscore` fields | Constructor/import/export values | Stored integers | New games start at 0. No audited calculation updates these fields from at-bats; active scoring appears to derive runs from `Atbat.maxbase == "Home"`. |

## 7. Remaining unknowns

- Real named iPhone simulator destinations could not be listed because CoreSimulatorService was unavailable in this execution environment.
- A full app build could not complete because storyboard compilation failed with `iOS 26.5 Platform Not Installed` after CoreSimulator/Interface Builder service failures.
- Tests could not execute because the `ScoreKeep` scheme is not configured for the test action and the active test plan reported zero enabled tests.
- No checked-in `.ScoreKeep_Players` fixture exists, so player-file decoding was verified from the code contract rather than from a repository fixture.
- Runtime UI reachability was assessed statically because the app could not be built/launched in the available simulator environment.
- Export/import preservation was assessed from code paths, not by a live round-trip through SwiftData, because the build/test environment was blocked.

## 8. Recommended regression test scenarios before re-engineering

1. Decode `seededGame.ScoreKeep_Games` with `ShareGame` and import it into an empty in-memory SwiftData store.
2. Export the seeded game and compare decoded scalar fields, at-bats, pitchers, teams, players, replacements, and lineups against the imported source.
3. Add a `.ScoreKeep_Players` fixture with logo/photo data and verify `[SharePlayer]` decoding, import with both `Imported` and `Current` overwrite strategies, and export back to JSON.
4. Score a half inning with singles, walks, errors, fielder's choices, runner advancement, a base-path out, and three outs; verify `inning`, `outs`, `seq`, `col`, `endOfInning`, runs, hits, and errors.
5. Verify automatic unearned-run behavior for `Error` and `Dropped 3rd Strike`, plus manual earned/unearned toggling.
6. Verify RBI values are preserved through edit, export, import, and reporting expectations.
7. Verify stolen bases are preserved and included in live/PDF box-score totals.
8. Verify substitutions: replaced player is struck/marked, incoming player is indented, and scoring after replacement attaches to the incoming player.
9. Verify pitcher transitions at start of game, mid-inning, and end of inning; compare `PitcherRptView`, `ShowPitchRptView`, and `GeneratePDF` pitching stat output for the same game.
10. Verify batting stats with hits, walks, HBP, sacrifice fly/bunt, dropped third strike, and fielder's choice; include a test that exposes the `"Sacrifise"` spelling mismatch.
11. Verify scorecard PDF box score against live `PlayersToScoreView` totals.
12. Verify `Game.hscore` and `Game.vscore` expectations: whether they are intentionally archival/import fields or should mirror calculated at-bat runs.
13. Verify URL routing for `scorekeep://share?tab=download&prefill=...` and file import routing for both `.ScoreKeep_Players` and `.ScoreKeep_Games`.
14. Verify StoreKit season pass states against report/PDF/download/game-limit gates.
15. Verify MLB manifest decoding and a downloaded roster file import without relying on website HTML parsing.

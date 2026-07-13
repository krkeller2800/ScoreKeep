# ScoreKeep Current-State Inventory

This document is a factual inventory of the current ScoreKeep implementation for a controlled re-engineering effort. It cites the relevant file and type/function names for each finding.

## 1. Project Structure

### Xcode targets

- `ScoreKeep`: main iOS app target. Native target is declared in `ScoreKeep.xcodeproj/project.pbxproj`; app entry point is `ScoreKeep/ScoreKeep/ScoreKeepApp.swift` (`ScoreKeepApp`).
- `ScoreKeepTests`: unit test target in `ScoreKeep/ScoreKeepTests/ScoreKeepTests.swift`; currently contains the default `@Test func example()` placeholder.
- `ScoreKeepUITests`: UI test target in `ScoreKeep/ScoreKeepUITests/ScoreKeepUITests.swift` and `ScoreKeep/ScoreKeepUITests/ScoreKeepUITestsLaunchTests.swift`; currently contains default launch/performance tests.

No app extensions, widgets, watch targets, or supporting app-extension targets were found in `ScoreKeep.xcodeproj/project.pbxproj`.

### Build configurations and settings

- Project configurations: `Debug` and `Release`, declared in `ScoreKeep.xcodeproj/project.pbxproj`.
- `Debug` uses `ScoreKeep/ScoreKeep/Debug.xcconfig`, which sets `SWIFT_OPTIMIZATION_LEVEL[config=Debug] = -Onone`, full Swift reflection metadata, incremental compilation, `DEBUG`, no symbol stripping, and `ONLY_ACTIVE_ARCH = YES`.
- App target:
  - Bundle identifier: `Komakode.ScoreKeep`.
  - Marketing version: `5.040`.
  - Current project version: `1`.
  - Swift version: `5.0`.
  - Supported platforms: `iphoneos iphonesimulator`.
  - Targeted device family: `1,2` (iPhone and iPad).
  - Deployment target: `17.6`.
  - Info plist: `ScoreKeep/ScoreKeep/Info.plist`.
  - App icon asset name: `icon`.
- Test targets:
  - `ScoreKeepTests` bundle id: `Komakode.ScoreKeepTests`, deployment target `18.2`.
  - `ScoreKeepUITests` bundle id: `Komakode.ScoreKeepUITests`; deployment target is inherited/not explicitly visible in the grep output.

### Dependencies

- Apple frameworks used directly include SwiftUI, SwiftData, StoreKit, PDFKit, UIKit, Security, MessageUI, AVFoundation, UniformTypeIdentifiers, and Foundation.
- `StoreKit.framework` is explicitly linked in `ScoreKeep.xcodeproj/project.pbxproj`; StoreKit configuration is `ScoreKeep/ScoreKeep.storekit`.
- No Swift Package Manager references (`XCRemoteSwiftPackageReference`, `Package.swift`, `Package.resolved`) were found.
- A `ScoreKeep/Frameworks/StoreKit.framework/Headers` folder is present in the project structure, but the Xcode project links StoreKit from `SDKROOT` (`System/Library/Frameworks/StoreKit.framework`) rather than from a vendored binary.

## 2. Application Architecture

### App entry point and global objects

- `ScoreKeep/ScoreKeep/ScoreKeepApp.swift`
  - `ScoreKeepApp` creates global `@StateObject`s: `PurchaseManager`, `AppRouter`, and `AnnouncementCenter`.
  - It installs `.modelContainer(for: Game.self)`, which makes SwiftData infer and include the model graph reachable from `Game`.
  - It chooses `StartView` for iPad and `StartPhoneView` for iPhone using `UIDevice.type`.
  - It loads StoreKit products, refreshes entitlements, and fetches remote announcements in `.task` and when `scenePhase` becomes active.
  - It handles `scorekeep://share?tab=download&prefill=...` deep links through `parseDeepLink(_:)` and `AppRouter.destination`.
  - `SeederView` imports `seededGame.ScoreKeep_Games` once when `@AppStorage("hasSeededInitialGame")` is false.

### Navigation structure

- iPad uses `ScoreKeep/ScoreKeep/List Data/StartView.swift` (`StartView`) with a `NavigationSplitView`.
  - Sidebar buttons switch boolean flags for Games, Teams, Paste in Players, Help Documentation, Share Data, import, and screenshot.
  - Detail screens include `ScoreContentView`, `TeamContentView`, `PasteView`, `PdfView`, `ShareContentView`, `ImportPlayersView`, and `ScreenShotView`.
- iPhone uses `ScoreKeep/ScoreKeep/List Data/StartPhoneView.swift` (`StartPhoneView`) with a `TabView`.
  - Tabs: Games (`ScoreContentView`), Teams (`TeamContentView`), Paste (`PasteView`), Help (`PdfView`), Share (`ShareContentView`).
  - File imports are presented as a `fullScreenCover`.
- Games and scoring are routed through `ScoreKeep/ScoreKeep/Content Views/ScoreContentView.swift`.
  - `ScoreContentView` shows `GameView`.
  - It navigates to `EditGameView` for blank/incomplete/edit-mode games.
  - It navigates to `EditScoreView` for scoring.
- Scoring screens:
  - `EditScoreView` owns the game scoring shell and toolbar actions.
  - `PlayersToScoreView` renders the scoring grid and creates/selects `Atbat` records.
  - `ScoreGameView` is the per-plate-appearance scoring sheet.
  - `StartingLineupView` creates/updates lineup and initial `Atbat` placeholder rows.
  - `ReplacementView` handles substitutions and "Pitch Hitter" rows.
  - `PitcherContentView` and `PitchersStaffView` handle pitcher entry.

### Major screens and workflows

- Game list/create/edit/score:
  - `ScoreContentView`, `GameView`, `EditGameView`, `EditScoreView`.
- Team list/edit/player management:
  - `TeamContentView`, `TeamView`, `EditTeamView`, `PlayersOnTeamView`, `PlayerView`, `EditPlayerView`, `EditAllPlayerView`, `EditLineupView`.
- Scoring grid and drawings:
  - `PlayersToScoreView`, `ScoreGameView`, `ScoreGameView`, `drawAtbatView.swift`, `drawCardView.swift`.
- Roster import from clipboard:
  - `PasteView`.
- Share/download/import:
  - `ShareContentView`, `ImportPlayersView`, `ImportService`, `DownloadFiles`, `ImportDisplayView`.
- Reports/PDF/screenshots:
  - `PDFGenerator` in `GeneratePDF.swift`, `PdfView`, `ReportView`, `ShowReportView`, `PitcherRptView`, `ShowPitchRptView`, `ScreenShotView`, `ScreenshotMaker*`.
- Purchases:
  - `PurchaseManager`, `PaywallView`, `PremiumBadgeView`, `KeychainBackedCounter`, `KeychainService`.
- Announcements:
  - `AnnouncementCenter`, `AnnouncementSheet`.

### Responsibility boundaries

- The app has no centralized domain layer for baseball scoring. Scoring rules and state mutation are distributed across `PlayersToScoreView.seqGame()`, `PlayersToScoreView.updMaxBases()`, `PlayersToScoreView.updatePitcherMarkers()`, `ScoreGameView.setEndOfInning()`, `StartingLineupView.doLineup()`, `ReplacementView.doSubs()`, and reporting functions in `GeneratePDF.swift`.
- Persistence is accessed directly from SwiftUI views through `@Environment(\.modelContext)`, `@Query`, `FetchDescriptor`, and direct mutation of SwiftData model instances.
- Import/export compatibility uses both older view-local code in `ImportPlayersView` and newer service code in `ImportService`; both should be treated as current behavior until rewritten and regression-tested.
- StoreKit and entitlement logic is isolated in `PurchaseManager`, but feature gating is implemented in view code (`ScoreContentView`, `EditScoreView`, `ShareContentView`).

## 3. Data Model and Persistence

### Persistence technology

- Persistence is SwiftData. `ScoreKeepApp` installs `.modelContainer(for: Game.self)`.
- Persisted models use `@Model` in:
  - `ScoreKeep/ScoreKeep/Objects/Game.swift` (`Game`)
  - `ScoreKeep/ScoreKeep/Objects/Team.swift` (`Team`)
  - `ScoreKeep/ScoreKeep/Objects/Player.swift` (`Player`)
  - `ScoreKeep/ScoreKeep/Objects/Atbat.swift` (`Atbat`)
  - `ScoreKeep/ScoreKeep/Objects/Lineup.swift` (`Lineup`)
  - `ScoreKeep/ScoreKeep/Objects/Pitcher.swift` (`Pitcher`)
- External binary storage:
  - `Team.logo` uses `@Attribute(.externalStorage) var logo: Data?`.
  - `Player.photo` uses `@Attribute(.externalStorage) var photo: Data?`.

### Persisted model types

- `Game`
  - Fields: `ident`, `date`, `location`, `highLights`, `hscore`, `vscore`, `everyOneHits`, `numInnings`, optional `vteam`, optional `hteam`, `players`, `atbats`, `lineups`, `pitchers`, `replaced`, `incomings`.
  - `hscore` and `vscore` are stored but current displayed scores are usually recalculated from `Atbat.maxbase == "Home"` (`GameView.scoreSummary(for:)`, `PDFGenerator.doBoxScore(game:doTeam:)`).
- `Team`
  - Fields: `ident`, `name`, `coach`, `details`, `players`, `games`, `logo`.
- `Player`
  - Fields: `identifier`, `name`, `number`, `position`, `batDir`, `batOrder`, optional `team`, `atbat`, `photo`.
- `Atbat`
  - Fields: `ident`, non-optional `game`, `team`, `player`, `result`, `maxbase`, `batOrder`, `outAt`, `inning`, `seq`, `col`, `rbis`, `outs`, `sacFly`, `sacBunt`, `stolenBases`, `earnedRun`, `playRec`, `endOfInning`.
- `Lineup`
  - Fields: `ident`, `everyoneHits`, non-optional `game`, `team`, `inning`, `players`.
- `Pitcher`
  - Fields: `ident`, non-optional `player`, `team`, `game`, start/end inning/out/batter markers, `strikeOuts`, `walks`, `hits`, `runs`, `won`.

### Relationships and identity

- SwiftData relationships are represented by direct model references and arrays; no inverse annotations or delete rules are declared in the model files.
- UUID fields exist (`Game.ident`, `Team.ident`, `Player.identifier`, etc.) but no `@Attribute(.unique)` constraints are declared.
- Many queries and duplicate checks use names/dates/locations instead of UUIDs:
  - `TeamView.checkForDup()` uses exact `Team.name`.
  - `PlayerView.checkForDup(pname:)` uses `team.name + player.name`.
  - `PlayersToScoreView` filters `Atbat` by `atbat.team.name`, `atbat.game.date`, and `atbat.game.location`.
  - `ImportService.importShareGames(_:)` treats a duplicate game as same visiting team, home team, and date.
  - `GameView.scoreSummary(for:)` uses team names for score grouping.

### UserDefaults / AppStorage keys

- `hasSeededInitialGame`: one-time seed import flag (`ScoreKeepApp`, `GameView`).
- `hasDismissedSeedHint_Game`: sample-game hint dismissal (`GameView`).
- `selectedGameCriteria`: game sort preference (`ContentView`, `ScoreContentView`).
- `selectedTeamCriteria`: team sort preference (`TeamContentView`).
- `selectedPlayerCriteria`: player sort preference in mostly unfinished `PlayerContentView`.
- `selectedPitcherCriteria`: pitcher picker sort (`PitcherContentView`).
- `selectedPlayerTCriteria`: team/player sort preference (`EditTeamView`, `PlayerView`).
- `selectedShareCriteria`: share roster sort (`ShareContentView`).
- `delimeters`, `theTags`: paste delimiter labels/tokens (`PasteView`).
- `dismissedMessageIDsData`: JSON-encoded dismissed announcement IDs (`AnnouncementCenter`).

### Keychain keys

- `seasonPassMaxExpirationISO8601`: local entitlement expiration (`PurchaseManager`).
- `freeGameCreatesRemainingKC`: free game creation counter (`ScoreContentView` via `KeychainBackedCounter`).
- `mlbDownloadCountKC`: free MLB roster download counter (`ShareContentView` via `KeychainBackedCounter`).

### Migration/versioning

- No explicit SwiftData schema versioning, migration plan, or model version files were found.
- The seed import is controlled only by `hasSeededInitialGame`; if the seed import partially succeeds and the flag is set or if models change incompatibly, there is no recovery/migration logic.

### Data-loss and crash assumptions

- Deleting a game in `GameView.delete(_:)` manually deletes associated `Atbat`, `Pitcher`, and `Lineup` rows, then deletes the `Game`.
- Updating an existing lineup in `StartingLineupView` warns that team at-bats will be deleted, then deletes at-bats for that team and removes substitution state.
- `PasteView.deleteAllPlayersOnSelectedTeam()` deletes `Player` rows but only counts related `Atbat`/`Pitcher` records; it does not delete those related records, despite the alert text saying it will.
- Team/player deletion checks use names, not model identity (`TeamView.teamOnGame(team:)`, `PlayerView.playedInGame(player:)`, `PlayersOnTeamView.playedInGame(player:)`), so duplicate names across teams can block or permit unintended operations.
- Non-optional relationships in `Atbat`, `Lineup`, and `Pitcher` can crash import or reporting paths if a referenced model is missing; old `ImportPlayersView` force unwraps teams/players during game import.

## 4. Baseball Scoring Behavior

### Representation

- Games are `Game` rows with two teams, date/location, highlights, an `everyOneHits` flag, and arrays for players, at-bats, lineups, pitchers, replaced players, and incoming players.
- Teams are `Team` rows with players and games.
- Batting order is `Player.batOrder`; `99` means not hitting in many views (`PlayerView`, `PlayersOnTeamView`, `StartingLineupView`, `ReplacementView`).
- Initial lineup creation in `StartingLineupView.doLineup()` creates one placeholder `Atbat` per batting player with `result = "Result"`, `maxbase = "No Bases"`, `outAt = "Safe"`, `inning = 1`, `col = 1`, and sequence/batting order.
- Plate appearances are `Atbat` rows. Key strings come from `Common` in `CommonData.swift`:
  - On-base results: `Hit By Pitch`, `Dropped 3rd Strike`, `Catcher Interference`, `Walk`, hits, `Fielder's Choice`, `Error`.
  - Out results: `Ground Out`, `Fly Out`, `Line Out`, `Foul Out`, `Strikeout`, `Strikeout Looking`, `Sacrifice Fly`, `Sacrifice Bunt`.
  - Hits: `Single`, `Double`, `Triple`, `Home Run`.
- Runs are represented by `Atbat.maxbase == "Home"`, not by a separate run event.
- Hits are inferred from `Common.hitresults`.
- Errors are represented as `Atbat.result == "Error"` for the batting team; team errors are counted against the opposing team in `PDFGenerator.doBoxScore(game:doTeam:)`.
- Outs are inferred from `Common.outresults.contains(result)` or `outAt != "Safe"`.
- Bases are represented by `Atbat.maxbase` values `No Bases`, `First`, `Second`, `Third`, `Home`.
- Base-path outs are `Atbat.outAt` values `Safe`, `First`, `Second`, `Third`, `Home`.
- RBIs, stolen bases, sacrifice flags, earned-run flag, play record, and end-of-inning flag are fields on `Atbat`.
- Pitchers are `Pitcher` rows with inning/out/batter start and end markers. `PlayersToScoreView.updatePitcherMarkers()` derives markers from the current batting team's at-bats.
- Substitutions are represented in `Game.replaced`, `Game.incomings`, changed `Player.batOrder`, and inserted `Atbat` rows with `result = "Pitch Hitter"` (`ReplacementView.doSubs()`).

### Rule implementation locations

- `PlayersToScoreView.seqGame()`
  - Recomputes columns, sequences, inning fraction, outs, and box-score totals.
  - Saves inside the loop for each at-bat.
- `PlayersToScoreView.updMaxBases()`
  - Automatically advances `maxbase` based on result and occupied bases.
  - Updates `InnStatus` for base occupancy display.
- `PlayersToScoreView.updatePitcherMarkers()`
  - Initializes and advances pitcher start/end markers for opponent pitchers.
- `ScoreGameView`
  - Presents the scoring sheet.
  - Mutates `Atbat.result`, `rbis`, `stolenBases`, `maxbase`, `outAt`, `earnedRun`, `playRec`.
  - Deletes empty non-lineup at-bats on Done/Delete.
  - `setEndOfInning()` clears and recalculates `endOfInning`.
  - `checkForCol1Dup()` deletes duplicate first-column at-bats for the same player.
- `StartingLineupView.doLineup()`
  - Creates or updates `Lineup` and first-column placeholder `Atbat` rows.
  - Updating an existing lineup deletes at-bats for that team first.
- `ReplacementView.doSubs()`
  - Inserts "Pitch Hitter" at-bats and shifts sequence/batting order.
- `GeneratePDF.swift`, `ReportView`, `ShowReportView`, `PitcherRptView`, and `ShowPitchRptView`
  - Recalculate many stats independently for reports.

### Undo/correction/completion/restoration

- There is no general undo stack.
- Correction is done by reopening a cell in `PlayersToScoreView`, mutating or deleting the associated `Atbat` in `ScoreGameView`.
- Deleting an at-bat:
  - For `col != 1`, `ScoreGameView` removes it from `game.atbats` and deletes it on disappear.
  - For `col == 1`, it resets the placeholder fields to `Result`, `No Bases`, `Safe`.
- Game completion is inferred in `GameView.scoreSummary(for:)` as `inning >= 9 && winner != ""`; there is no persisted completion flag.
- Game restoration is normal SwiftData persistence plus one-time seeded import; there is no explicit restoration service.

### Duplicated logic

- Score/stat calculations are duplicated in `PlayersToScoreView`, `drawCardView.swift`, `GeneratePDF.swift`, `ReportView`, `ShowReportView`, `PitcherRptView`, and `ShowPitchRptView`.
- Team/player duplicate logic appears in `TeamView`, `EditTeamView`, `PlayerView`, `PlayersOnTeamView`, `EditPlayerView`, `StartingLineupView`, and `PasteView`.
- Deep-link parsing appears in `ScoreKeepApp`, `StartView`, `StartPhoneView`, and `ShareContentView`.
- Import game/player logic exists in both `ImportPlayersView` and `ImportService`.

## 5. Import and Export Compatibility

### File formats and document types

- `ScoreKeep/ScoreKeep/Info.plist` declares:
  - Document type `ScoreKeep Players`, UTI `com.komakode.scorekeep`, extension `ScoreKeep_Players`, MIME `application/octet-stream`.
  - Document type `ScoreKeep Games`, UTI `com.komakode.scorekeep.games`, extension `ScoreKeep_Games`, MIME `application/octet-stream`.
  - URL scheme `scorekeep`.
- `Extensions.swift` also declares `UTType.myCustomFile` as `UTType(exportedAs: "com.komakode.scorekeep.ScoreKeep_Players")`; this differs from the plist UTI `com.komakode.scorekeep`.
- Exported files are JSON written with custom extensions:
  - Team roster: `"{team}.ScoreKeep_Players"` from `ShareContentView.savePlayers(playerData:fileName:)`.
  - Game: `"{visitor} at {home} on {date}.ScoreKeep_Games"` from `ShareContentView.saveGame(gameData:fileName:)`.
  - PDF scorecard/report: `"{visitor} at {home} on {date}.pdf"` from `PDFGenerator.savePDF(data:fileName:)`.

### Codable external structures and field names

Declared in `ScoreKeep/ScoreKeep/Common/CommonData.swift`:

- `SharePlayer`: `id`, `name`, `number`, `position`, `batDir`, `batOrder`, `team`, `atbats`, `photo`.
- `ShareGame`: `id`, `date`, `location`, `highLights`, `hscore`, `vscore`, `everyOneHits`, `numInnings`, `vteam`, `hteam`, `players`, `atbats`, `lineups`, `pitchers`, `replaced`, `incomings`.
- `ShareTeam`: `id`, `name`, `coach`, `details`, `players`, `games`, `logo`.
- `ShareAtbat`: `id`, `game`, `team`, `player`, `result`, `maxbase`, `batOrder`, `outAt`, `inning`, `seq`, `col`, `rbis`, `outs`, `sacFly`, `sacBunt`, `stolenBases`, `earnedRun`, `playRec`, `endOfInning`.
- `ShareLineup`: `id`, `everyoneHits`, `game`, `team`, `inning`, `players`.
- `SharePitcher`: `id`, `player`, `team`, `game`, `startInn`, `sOuts`, `sBats`, `endInn`, `eOuts`, `eBats`, `strikeOuts`, `walks`, `hits`, `runs`, `won`.

These use synthesized `Codable`; exact JSON field names are the Swift property names above.

### Import behavior

- `StartView` accepts imports when extension or filename contains `scorekeep_players` or `scorekeep_games` case-insensitively.
- `StartPhoneView` and `ShareContentView.isValidImportURL(_:)` require exact extensions `ScoreKeep_Players` or `ScoreKeep_Games`.
- `ImportPlayersView.decodePlayers()` decodes `[SharePlayer]`.
- `ImportPlayersView.decodeGame()` decodes a single `ShareGame`.
- `ImportService.decodeSeededGame(from:)` decodes a single `ShareGame` and wraps it in an array.
- For player imports into an existing team, the UI exposes two overwrite strategies:
  - `Imported`: incoming non-blank fields overwrite current values.
  - `Current`: current non-blank fields are preserved and incoming values fill blanks.
- Game import duplicate detection uses same visiting team, home team, and date.
- Newer `ImportService.importShareGames(_:)` normalizes team names and rejects game child records that reference more than two teams.
- Older `ImportPlayersView` game import force unwraps teams and players in `doAtbats`, `doLineups`, and `doPitchers`; malformed files can crash.

### Website endpoints and downloaded resources

- `https://komakode.com/Teams/index.json`
  - Used by `ShareContentView.getFileNames()` and `DownloadFiles.fetchTeamsIndex(from:)`.
  - Expected schema: top-level `updated: String?`, `divisions: [ { name, teams: [ { name, url } ] } ]`.
  - Each team URL from the manifest must be directly downloadable and usually points to a `.ScoreKeep_Players` roster file.
- `https://komakode.com/Teams/message.json`
  - Used by `AnnouncementCenter.refresh()`.
  - Expected schema: `RemoteMessageEnvelope(messages: [RemoteMessage], version: Int?)`; `RemoteMessage` fields are `id`, `ctaTitle`, `ctaURL`, `title`, `body`, `start`, `end`, with ISO-8601 dates.
- `mailto:comment@KomaKode.com?...`
  - Used by `ShareContentView.sendEmail(openUrl:)` for roster request email.
- `https://komakode.com/Privacy%20Policy`
  - Paywall privacy link.
- `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`
  - Paywall EULA link.
- `https://apps.apple.com/account/subscriptions`
  - StoreKit non-renewing subscription management fallback.

### Deep links

- URL scheme: `scorekeep`.
- Supported deep link: `scorekeep://share?tab=download&prefill={teamName}`.
- Handled by `ScoreKeepApp.parseDeepLink(_:)`, `StartView.parseDeepLink(_:)`, `StartPhoneView.parseDeepLink(_:)`, and `ShareContentView.parseDeepLink(_:)`.
- `ShareContentView.applyDestination(_:)` switches to "Download MLB Teams" and optionally preselects the manifest team name.

## 6. Networking

- `AnnouncementCenter.refresh()` uses `URLSession.shared.data(from:)` against `https://komakode.com/Teams/message.json`.
  - Non-2xx or errors are silently ignored.
  - Offline behavior: no announcement shown.
  - Privacy: app contacts the KomaKode website on launch/foreground without user action.
- `ShareContentView.getFileNames()` fetches `https://komakode.com/Teams/index.json` twice: once through `fetchIndexUpdated(from:)` and once through `DownloadFiles.fetchTeamsIndex(from:)`.
  - Errors show "Unable to load teams. Please check your connection and try again."
  - Offline behavior: roster picker is empty/error state; Retry button calls `getFileNames()`.
- `DownloadFiles.fetchTeamsIndex(from:)`
  - Uses a `URLSessionConfiguration` with `waitsForConnectivity = true`.
  - Retries transient `URLError`s up to two attempts with 0.8 second backoff.
  - Validates 2xx HTTP status.
- `DownloadFiles.downloadFile(from:to:)`
  - Downloads the roster file URL from the manifest and moves it to Documents, replacing any file with the same destination name.
  - Only spaces are manually percent-encoded before URL construction.
- StoreKit networking is handled through `Product.products(for:)`, `product.purchase()`, `Transaction.updates`, and `AppStore.sync()` in `PurchaseManager`.

## 7. User Interface Inventory

### Primary workflows

- Create/select/score games: `ScoreContentView` -> `GameView` -> `EditScoreView`.
- Edit game metadata: `EditGameView`.
- Create/edit/delete teams: `TeamContentView`, `TeamView`, `EditTeamView`.
- Manage team players: `PlayersOnTeamView`, `PlayerView`, `EditPlayerView`, `EditAllPlayerView`.
- Paste roster from clipboard: `PasteView`.
- Create/update lineup: `StartingLineupView`.
- Score an at-bat: `PlayersToScoreView` grid opens `ScoreGameView`.
- Add/edit pitchers: `PitcherContentView`, `PitchersStaffView`, `EditPitcherView`.
- Substitute players: `ReplacementView`.
- Share rosters/games and download MLB teams: `ShareContentView`.
- Import received files: `ImportPlayersView`.
- Generate/share PDFs and stat reports: `EditScoreView`, `PDFGenerator`, `ReportView`, `ShowReportView`, `PitcherRptView`, `ShowPitchRptView`, `PdfView`.
- Paywall/purchase: `PaywallView`.
- Remote announcements: `AnnouncementSheet`.

### Dialogs, sheets, menus, toolbar actions

- Add Team, Sort, Score/Edit segmented picker, Upgrade, Search: `ScoreContentView`.
- Delete Game confirmation: `GameView`.
- Add Pitcher, PDF, Replace Players, Lineup, Pitch Stats, Hit Stats: `EditScoreView`.
- Scoring sheet with Done/Delete/RBI/Steal/result/base/out/earned-run/fielder buttons: `ScoreGameView`.
- Lineup update destructive alert: `StartingLineupView`.
- Delete players destructive alert: `PasteView`.
- Paywall sheet/full-screen presentation: `ScoreContentView`, `EditScoreView`, `ShareContentView`.
- Share sheet through `ShareLink`: `ShareContentView`, `EditScoreView`, report views.

### iPhone vs iPad behavior

- Device split is based on `UIDevice.current.localizedModel` via `UIDevice.type`.
- iPad uses `StartView` `NavigationSplitView`; iPhone uses `StartPhoneView` `TabView`.
- Search is generally visible by default on iPad and toggled by a toolbar magnifier on iPhone.
- Some report screens switch implementation by device:
  - `EditScoreView` uses `ShowPitchRptView` on iPad and `PitcherRptView` on iPhone.
  - `EditScoreView` uses `ReportView` on iPad and `ShowReportView` on iPhone.
- Paywall is a sheet on iPad and full-screen cover on iPhone in `ShareContentView.PaywallPresentation`.

### Accessibility

- Some controls set labels, e.g. `ScoreContentView` free counter and search/upgrade buttons.
- Most custom grid controls, image buttons, and drawing-based score cells do not expose explicit accessibility labels or actions.
- Large portions of the UI use fixed frames, `Text` inside image backgrounds, custom drawings, and color-coded state; accessibility support is incomplete.

### SwiftUI and UIKit/PDF usage

- Most UI is SwiftUI.
- UIKit is used for images, pasteboard, screenshots, PDF rendering, and some color manipulation (`Extensions.swift`, `PasteView`, `ScreenshotMaker*`, `GeneratePDF.swift`).
- PDFKit is used by `PdfView`.
- `ScreenshotMakerView` bridges UIKit through `UIViewRepresentable`.

## 8. App Store and Purchase Behavior

- `ScoreKeep/ScoreKeep.storekit` declares non-renewing subscriptions:
  - `com.komakode.ScoreKeep.SeasonPass2025`, display price `4.99`.
  - `com.komakode.ScoreKeep.SeasonPass2026`, display price `4.99`.
  - StoreKit app internal ID `6748364014`, developer team `7U8E86JT3B`.
- `PurchaseManager`
  - Builds product ID from current calendar year: `com.komakode.ScoreKeep.SeasonPass{year}`.
  - Only accepts purchases for the current-year product ID.
  - Computes entitlement expiration as local end-of-year for the product ID suffix.
  - Stores the max expiration date in Keychain under `seasonPassMaxExpirationISO8601`.
  - Refreshes entitlement state by comparing stored expiration with `Date()`.
  - Listens for `Transaction.updates` in a detached task.
  - `restorePurchases()` calls `AppStore.sync()` but notes that non-renewing purchases do not restore active access on a new device without local entitlement.
- `PaywallView`
  - Shows current-year dynamic title/subtitle, loaded product price, buy button, "Check Purchase Status", privacy and EULA links.
- Gated features:
  - More than two free user-created games: `ScoreContentView` uses `freeGameCreatesRemainingKC`.
  - More than four free MLB downloads: `ShareContentView` uses `mlbDownloadCountKC`.
  - PDF/report generation from `EditScoreView` requires premium.
- Debug behavior:
  - `ScoreContentView.onAppear` resets `freeGameCreatesRemainingKC` to 2 in `#if DEBUG`, which affects local/debug builds.

## 9. Stability and Maintenance Risks

### Force unwraps and unsafe indexing

- `Extensions.swift`: `Image.scaleImage(iHeight:imageData:)` force unwraps `UIImage(data:)`.
- `EditScoreView`: force unwraps `game.vteam!`, `game.hteam!`, and `screenshotMaker.screenshot()!`.
- `ShareContentView`: force unwraps `team!`, `game.vteam!`, `game.hteam!`, `FileManager...first!`, and indexes `[0]` after `getPlayers(players:)` in `getAtbats`/`getPitchers`.
- `ImportPlayersView`: force unwraps `team!`, `player!`, `teams.first(...)!`, and `team = teams.first(...)!`.
- `GeneratePDF.swift`: force unwraps `UIImage.preparingThumbnail(...)!` and `game.hteam!.name`/`game.vteam!.name` in `calcInning(game:)`.
- `PlayersToScoreView.seqGame()` indexes fixed arrays `colbox[col]` and `batbox[atbat.batOrder]` with runtime values. `colbox` and `batbox` are fixed at 20 items; extra innings/columns or batting order values can exceed bounds.
- `ReplacementView.doSubs()` uses `rplPlayers[replacedIdx-1]`, `incPlayers[incomingIdx-1]`, and `newseq[atbat.col]`; large column values can exceed `newseq` count.
- `PasteView` updater functions index `player.components(separatedBy: delimeter)[idx-1]`; inconsistent rows or stale picker indexes can crash.

### Threading/concurrency

- Many `URLSession.dataTask` callbacks dispatch manually to main (`ShareContentView`, `DownloadFiles`) while other state is mutated directly in async SwiftUI tasks.
- `PurchaseManager.startListeningForTransactions()` uses `Task.detached` with a weak `@MainActor` object; calls are awaited back onto main actor, which is appropriate but should be regression-tested.
- `KeychainBackedCounter` imports Combine despite otherwise using Swift concurrency; saves are debounced with a task and errors are swallowed.

### SwiftUI identity and state risks

- Several lists use names or mutable UUID fields as identity while records can be edited (`ForEach(displayedGames, id: \.ident)`, `ForEach(teams, id: \.ident)`, many default `ForEach(players)`).
- Device branching through `UIDevice.type == "iPhone"`/`"iPad"` depends on localized model strings rather than idiom.
- Global style mutations (`UISegmentedControl.appearance().selectedSegmentTintColor`) occur in multiple `.onAppear` handlers.
- Some files declare top-level `@Query` variables outside a view (`ContentView.swift`, `TeamContentView.swift`), which is unusual and may be dead or problematic.

### Persistence risks

- No explicit delete rules or inverse relationships are declared; many deletes are manual and inconsistent.
- Frequent saves inside loops (`PlayersToScoreView.seqGame()`, import functions, lineup creation) increase partial-update risk.
- Matching by team/player name can corrupt or merge data when names duplicate or change.
- `Game.hscore` and `Game.vscore` are persisted but not consistently maintained; current score is inferred from at-bats.
- Multiple creation paths create blank placeholder `Team`, `Game`, and `Player` records; cleanup depends on view disappearance logic.

### Large/tightly coupled files

- `ShareContentView.swift`: routing, downloading, paywall, export, import presentation, and JSON conversion.
- `GeneratePDF.swift`: PDF layout and stat calculations in one large class.
- `PlayersToScoreView.swift`: scoring grid rendering, sequencing, base advancement, pitcher marker updates, persistence.
- `PasteView.swift`: clipboard parsing, custom delimiter persistence, import/update/delete behavior.
- `ImportPlayersView.swift`: UI plus decoding and import logic, overlapping with `ImportService`.

### Dead, duplicate, or unfinished code

- `PlayerContentView` has its main `PlayerView` navigation commented out and currently renders an empty `VStack` with toolbar/search only.
- `ContentView` appears to duplicate part of `ScoreContentView` and may be legacy/unused from current app entry.
- `DownloadFiles.fetchFileList(from:)` is legacy HTML/string parsing and appears unused by current `ShareContentView`.
- `ImportService` duplicates and improves behavior that remains in `ImportPlayersView`.
- Several buttons/screens are commented out in `StartView` and `StartPhoneView` (score tab/screenshot).
- Tests are placeholders and do not cover current domain behavior.

## 10. Compatibility Requirements for Rewrite

### Data that must remain readable

- SwiftData stores containing `Game`, `Team`, `Player`, `Atbat`, `Lineup`, and `Pitcher` with the fields listed above.
- External binary `Team.logo` and `Player.photo` data.
- Existing `@AppStorage` and Keychain keys:
  - `hasSeededInitialGame`, `hasDismissedSeedHint_Game`, sort preferences, `delimeters`, `theTags`, `dismissedMessageIDsData`.
  - `seasonPassMaxExpirationISO8601`, `freeGameCreatesRemainingKC`, `mlbDownloadCountKC`.
- Seed file format `seededGame.ScoreKeep_Games` as a single `ShareGame`.

### User workflows that must remain available

- Create teams and players manually.
- Paste/import roster data from clipboard with configurable delimiter and field mapping.
- Create games with date, location, home/visitor teams, and everyone-hits flag.
- Set and update lineups.
- Score plate appearances with current result strings, base/out values, RBIs, stolen bases, earned/unearned runs, and fielding play records.
- Add pitchers and track pitcher start/end markers.
- Substitute players and preserve replaced/incoming display.
- View scores, box score, batting stats, pitching stats, and PDF scorecards.
- Share rosters and games.
- Open/import `.ScoreKeep_Players` and `.ScoreKeep_Games` files from other apps.
- Download MLB team rosters from the KomaKode manifest.
- Purchase/check current-year Season Pass.

### External formats and URLs that must not break

- File extensions: `.ScoreKeep_Players`, `.ScoreKeep_Games`, `.pdf`.
- Plist document UTIs: `com.komakode.scorekeep`, `com.komakode.scorekeep.games`.
- JSON field names in `SharePlayer`, `ShareGame`, `ShareTeam`, `ShareAtbat`, `ShareLineup`, and `SharePitcher`.
- `https://komakode.com/Teams/index.json` manifest schema and direct roster URLs.
- `https://komakode.com/Teams/message.json` announcement schema.
- `scorekeep://share?tab=download&prefill=...`.
- Paywall links to KomaKode privacy policy and Apple standard EULA.
- StoreKit product ID convention `com.komakode.ScoreKeep.SeasonPass{year}`.

### App Store identity/settings to preserve

- Bundle identifier `Komakode.ScoreKeep`.
- Developer team `7U8E86JT3B`.
- iPhone/iPad support (`TARGETED_DEVICE_FAMILY = "1,2"`).
- StoreKit app/product IDs, especially 2026 product `com.komakode.ScoreKeep.SeasonPass2026`.
- Current document types and URL scheme.
- Deployment target compatibility decision: current app target is iOS `17.6`; test target is `18.2`.

### Bugs/fragile behavior that should become regression tests

- Import malformed or incomplete `.ScoreKeep_Games` files without crashing.
- Import a game where child records reference a third team; `ImportService` rejects this, old UI code may crash.
- Import duplicate games by same teams/date and ensure behavior matches current user expectation.
- Export then re-import a scored game with substitutions, pitchers, earned runs, and base-path outs.
- Lineup update deletes only the intended team's at-bats and preserves other team/game data.
- Batting orders beyond 19 or extra-inning columns do not crash fixed-size arrays.
- Team/player rename or duplicate names do not corrupt game associations.
- Free-game and free-download counters persist and gate correctly across launches.
- Non-renewing Season Pass entitlement remains active until local end of product year.
- Offline startup/download behavior does not block app use.
- `PasteView` handles inconsistent delimiter rows and stale field picker indexes without array crashes.

## Files Inspected

Inspected directly:

- `ScoreKeep.xcodeproj/project.pbxproj`
- `ScoreKeep/ScoreKeep.storekit`
- `ScoreKeep/ScoreKeep/Info.plist`
- `ScoreKeep/ScoreKeep/Debug.xcconfig`
- `ScoreKeep/ScoreKeep/ScoreKeepApp.swift`
- `ScoreKeep/ScoreKeep/Common/CommonData.swift`
- `ScoreKeep/ScoreKeep/Common/Extensions.swift`
- `ScoreKeep/ScoreKeep/Common/PaywallView.swift`
- `ScoreKeep/ScoreKeep/Content Views/ContentView.swift`
- `ScoreKeep/ScoreKeep/Content Views/ScoreContentView.swift`
- `ScoreKeep/ScoreKeep/Content Views/TeamContentView.swift`
- `ScoreKeep/ScoreKeep/Content Views/PlayerContentView.swift`
- `ScoreKeep/ScoreKeep/Content Views/PitcherContentView.swift`
- `ScoreKeep/ScoreKeep/Disply graphics/PlayersToScoreView.swift`
- `ScoreKeep/ScoreKeep/Disply graphics/ScoreGameView.swift`
- `ScoreKeep/ScoreKeep/Edit Data/EditGameView.swift`
- `ScoreKeep/ScoreKeep/List Data/StartView.swift`
- `ScoreKeep/ScoreKeep/List Data/StartPhoneView.swift`
- `ScoreKeep/ScoreKeep/List Data/GameView.swift`
- `ScoreKeep/ScoreKeep/List Data/TeamView.swift`
- `ScoreKeep/ScoreKeep/List Data/PlayerView.swift`
- `ScoreKeep/ScoreKeep/List Data/PlayersOnTeamView.swift`
- `ScoreKeep/ScoreKeep/Objects/Game.swift`
- `ScoreKeep/ScoreKeep/Objects/Team.swift`
- `ScoreKeep/ScoreKeep/Objects/Player.swift`
- `ScoreKeep/ScoreKeep/Objects/Atbat.swift`
- `ScoreKeep/ScoreKeep/Objects/Lineup.swift`
- `ScoreKeep/ScoreKeep/Objects/Pitcher.swift`
- `ScoreKeep/ScoreKeep/Objects/PurchaseManager.swift`
- `ScoreKeep/ScoreKeep/Player org/PasteView.swift`
- `ScoreKeep/ScoreKeep/Player org/StartingLineupView.swift`
- `ScoreKeep/ScoreKeep/Player org/ReplacementView.swift`
- `ScoreKeep/ScoreKeep/Player org/PitchersStaffView.swift`
- `ScoreKeep/ScoreKeep/Reporting/GeneratePDF.swift`
- `ScoreKeep/ScoreKeep/Sharing Data/AnnouncementCenter.swift`
- `ScoreKeep/ScoreKeep/Sharing Data/DownloadFiles.swift`
- `ScoreKeep/ScoreKeep/Sharing Data/ImportService.swift`
- `ScoreKeep/ScoreKeep/Sharing Data/ImportPlayersView.swift`
- `ScoreKeep/ScoreKeep/Sharing Data/KeychainBackedCounter.swift`
- `ScoreKeep/ScoreKeep/Sharing Data/KeychainService.swift`

Also enumerated through Xcode project tooling:

- Remaining Swift support/reporting/drawing/screenshot/test files, assets, `Manual.pdf`, `Launch Screen.storyboard`, seed game file, and preview content.

## Parts Not Fully Analyzed

- Asset catalog image contents were not visually inspected.
- `Manual.pdf` and `Untitled 14.rtf` contents were not parsed.
- The seeded game JSON payload was identified as a compatibility input but not fully decoded/listed field by field.
- Drawing/reporting files outside `GeneratePDF.swift` were inventoried by type/function search but not line-by-line audited to the same depth as model, scoring, import/export, networking, and purchase code.
- No build or test run was performed because the requested task was an inventory and source-code changes were not made.


# Compatibility Route Inventory

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This inventory completes catalog task `0.5 Compatibility route inventory` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`. It records repository-grounded evidence for current `.ScoreKeep_Players`, `.ScoreKeep_Games`, document-open, deep-link, download, seed, import, export, and share routes without changing production behavior.

This document treats Documents 1-29 as approved planning authority and current source as evidence of existing behavior and compatibility obligations. It does not introduce a new production authority, retire a legacy path, create fixtures, change file formats, normalize identifiers, or approve a future implementation design.

The chosen path is `ScoreKeep/Docs/CompatibilityRouteInventory.md`. Document 29 identifies the tracked documentation path as `ScoreKeep/Docs/Design` for design documents, but task 0.5 is an evidence inventory rather than a new numbered design document. Existing sibling evidence documents already live in `ScoreKeep/Docs`, including `ScoreKeep/Docs/ScoreKeep-URL-Inventory.md`, `ScoreKeep/Docs/BaselineVerification.md`, and `ScoreKeep/Docs/CurrentState.md`; therefore this inventory belongs beside those evidence documents instead of in production source or a new hierarchy.

<!-- MARK: - 2. Repository Baseline and Evidence Inspected -->
## 2. Repository Baseline and Evidence Inspected

The branch was confirmed as `scorekeep-next`, an explicit checkout of `scorekeep-next` reported that the branch was already current, and the working tree was clean before this document was created. A safe dry-run fetch from `origin scorekeep-next` completed before edits. The baseline Xcode build was run before the documentation change and succeeded.

Primary route evidence inspected:

| Evidence area | Repository evidence |
| --- | --- |
| Task authority | `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`, especially task 0.5, Phase 0, dependency ordering, source-control rules, and recommended next task. |
| Compatibility design | `ScoreKeep/Docs/Design/21-ImportExportCompatibilityDesign.md`, especially compatibility contracts, file acquisition, classification, website roster download, deep links, sharing, purchase boundary, and verification strategy. |
| Workflow design | `ScoreKeep/Docs/Design/23-ApplicationServicesAndWorkflowDesign.md`, especially import, export, roster download, seed, purchase, allowance, cancellation, and interruption boundaries. |
| Fixture design | `ScoreKeep/Docs/Design/27-VerificationFixtureAndReleaseAcceptanceDesign.md` and `ScoreKeep/Docs/Verification/16-AcceptanceFixturesAndRegressionScenarios.md`. |
| Readiness plan | `ScoreKeep/Docs/Design/28-ImplementationReadinessAndPhasedRewritePlan.md`, especially Phase 0, Phase 4, coexistence, and source-control expectations. |
| File declarations | `ScoreKeep/Info.plist`; `ScoreKeep/Common/Extensions.swift`. |
| Startup and routing | `ScoreKeep/ScoreKeepApp.swift`; `ScoreKeep/List Data/StartView.swift`; `ScoreKeep/List Data/StartPhoneView.swift`. |
| Import and preview | `ScoreKeep/Sharing Data/ImportPlayersView.swift`; `ScoreKeep/Sharing Data/ImportDisplayView.swift`; `ScoreKeep/Sharing Data/ImportService.swift`. |
| Download and network | `ScoreKeep/Sharing Data/ShareContentView.swift`; `ScoreKeep/Sharing Data/DownloadFiles.swift`; `ScoreKeep/Sharing Data/AnnouncementCenter.swift`; `ScoreKeep/Sharing Data/AnnouncementSheet.swift`. |
| Export and share | `ScoreKeep/Sharing Data/ShareContentView.swift`; report and PDF share references found in `ScoreKeep/Reporting`. |
| Transport models | `ScoreKeep/Common/CommonData.swift`. |
| Seed and fixtures | `ScoreKeep/Seed/seededGame.ScoreKeep_Games`; `ScoreKeep/Docs/Verification/16-AcceptanceFixturesAndRegressionScenarios.md`; existing test files. |
| URL evidence | `ScoreKeep/Docs/ScoreKeep-URL-Inventory.md`. |

No checked-in `.ScoreKeep_Players` fixture was found during repository search. The checked-in `.ScoreKeep_Games` compatibility file is `ScoreKeep/Seed/seededGame.ScoreKeep_Games`.

<!-- MARK: - 3. File Types, Identifiers, and Route Strings -->
## 3. File Types, Identifiers, and Route Strings

Confirmed current declarations and hard-coded identifiers:

| Identifier | Category | Repository evidence | Notes |
| --- | --- | --- | --- |
| `.ScoreKeep_Players` | Roster filename extension | `ScoreKeep/Info.plist` lines 69-75; `ShareContentView.savePlayers` lines 487-496; `ShareContentView` download path lines 303-309; startup file checks in `StartView` and `StartPhoneView`. | Current roster compatibility extension. Export, download, local validation, and file-open checks all reference it. |
| `.ScoreKeep_Games` | Game filename extension | `ScoreKeep/Info.plist` lines 90-96; `ShareContentView.saveGame` lines 539-548; startup file checks; seed lookup in `ScoreKeepApp` lines 82-95. | Current game compatibility extension. |
| `com.komakode.scorekeep` | Exported players UTI and document type | `ScoreKeep/Info.plist` lines 14-19 and 61-76. | Declared as document type content type and exported type identifier for player files. |
| `com.komakode.scorekeep.games` | Exported games UTI and document type | `ScoreKeep/Info.plist` lines 28-33 and 84-96. | Declared as document type content type and exported type identifier for game files. |
| `application/octet-stream` | MIME type | `ScoreKeep/Info.plist` lines 73-76 and 94-96. | Declared for both compatibility file types. No runtime MIME check was found. |
| `com.komakode.scorekeep.ScoreKeep_Players` | Additional exported UTType | `ScoreKeep/Common/Extensions.swift` lines 53-58. | This differs from the players UTI in `Info.plist`. No active route in the inspected import/export code was found that uses `UTType.myCustomFile`. |
| `scorekeep` | Custom URL scheme | `ScoreKeep/Info.plist` lines 36-46. | App-level, iPad, iPhone, and share-view parsers recognize the scheme. |
| `scorekeep://share?tab=download&prefill=...` | Deep-link route | `ScoreKeepApp.parseDeepLink` lines 100-111; `StartView.parseDeepLink` lines 187-198; `StartPhoneView.parseDeepLink` lines 132-143; `ShareContentView.parseDeepLink` lines 703-714; URL inventory lines 75-78. | Only `host == "share"` and `tab == "download"` produce a route. `prefill` is optional. |
| `https://komakode.com/Teams/index.json` | Roster manifest URL | `ShareContentView.getFileNames` lines 601-631; URL inventory lines 11-15 and 59-66. | Active remote manifest source for downloadable rosters. |
| `teams[].name` and `teams[].url` | Manifest fields | `DownloadFiles.IndexTeam` lines 23-26; `ShareContentView.getFileNames` lines 623-628. | Team names populate the picker and map to direct roster URLs. |
| `https://komakode.com/Teams/message.json` | Announcement URL | `AnnouncementCenter` lines 32-50; `AnnouncementSheet` lines 33-37; URL inventory lines 17-21 and 67-69. | Announcement CTAs may open URLs, including possible deep links, through system URL opening. |
| `seededGame.ScoreKeep_Games` | Bundled game seed | `ScoreKeepApp.SeederView` lines 82-95; fixture catalog lines 63-75. | Seeded route is separate from ordinary user import. |

Current repository declarations are limited to exported type declarations; no `UTImportedTypeDeclarations` entry was found. Case handling is route-dependent: `StartView.isImportFileURL` lowercases the path extension and also checks the lowercased filename for compatibility substrings, while `StartPhoneView.isImportFileURL` and `ShareContentView.isValidImportURL` compare exact extension strings.

<!-- MARK: - 4. Transport Models and Decoders -->
## 4. Transport Models and Decoders

Compatibility transport shapes are defined in `ScoreKeep/Common/CommonData.swift`:

| Transport type | Evidence | Current route use |
| --- | --- | --- |
| `SharePlayer` | `CommonData.swift` lines 190-200. | Root array for `.ScoreKeep_Players`; nested player evidence in `ShareTeam`, `ShareGame`, at-bats, lineups, pitchers, replacements, and incomings. |
| `ShareGame` | `CommonData.swift` lines 201-218. | Root object for `.ScoreKeep_Games`; carries game metadata, teams, players, at-bats, lineups, pitchers, replacements, and incomings. |
| `ShareTeam` | `CommonData.swift` lines 219-227. | Team evidence for roster files, game sides, nested players, nested games, coach/details, and logo. |
| `ShareAtbat` | `CommonData.swift` lines 228-248. | Game scoring-event transport evidence. |
| `ShareLineup` | `CommonData.swift` lines 249-256. | Game lineup transport evidence. |
| `SharePitcher` | `CommonData.swift` lines 257-273. | Pitcher appearance transport evidence. |

Current user-routed import decoding is owned by `ImportPlayersView`, not by `ImportService`. `ImportPlayersView.decodePlayers()` reads the selected URL with `Data(contentsOf:)`, decodes `[SharePlayer]`, sorts by `batOrder`, and reports decoding errors through alerts. `ImportPlayersView.decodeGame()` reads the selected URL and decodes a single `ShareGame`, returning it as a one-element array. Both functions request security-scoped access around the read.

`ImportService` contains duplicated decode helpers for external player and game URLs, but current source search did not find those helpers called by the user-routed startup or share-download path. `ImportService.decodeSeededGame(from:)` is active for the bundled seed route. `ImportService.importShareGames(_:)` is active for seed persistence and is a competing game import implementation relative to `ImportPlayersView.sharedGamesBoss(_:)`.

Repository evidence does not show schema-version checks, root-shape classification before decoding, content-type checks, JSON field validation beyond Codable decoding, or validation of downloaded file body before the import review is presented.

<!-- MARK: - 5. Local Roster Import Route -->
## 5. Local Roster Import Route

Route identifier: local roster file import for `.ScoreKeep_Players`.

Flow:

User opens or receives file -> system delivers file URL to app `onOpenURL` -> `StartView` or `StartPhoneView` recognizes roster extension -> `ImportPlayersView` appears -> `decodePlayers()` decodes `[SharePlayer]` -> `showSharedPlayers` previews rows and allows deletion from the pending import list -> user taps `Import`, `Imported`, or `Current` -> `sharedPlayersBoss` or `currentPlayersBoss` writes SwiftData `Team` and `Player` records -> alert reports completion or save/read error.

| Inventory field | Current evidence |
| --- | --- |
| User entry point | System file open-in or equivalent external file URL, handled by `StartView.onOpenURL` lines 133-147 or `StartPhoneView.onOpenURL` lines 86-101. |
| Trigger | A non-`scorekeep` URL whose extension or name is accepted as a roster file. |
| Accepted file category | Roster compatibility file. |
| Expected extension | `.ScoreKeep_Players`. |
| Declared type | `com.komakode.scorekeep`, document label `ScoreKeep Players`, MIME `application/octet-stream` in `Info.plist`. |
| Source location | External file URL; security-scoped access is requested in `StartPhoneView` and again during `ImportPlayersView.decodePlayers()`. |
| Destination location | SwiftData `Team` and `Player` records in the app model container. |
| Current coordinator | Presentation-owned `ImportPlayersView`. |
| Decoder reached | `ImportPlayersView.decodePlayers()`. |
| Validation reached | Codable decoding and route extension checks only. No separate compatibility validator was found. |
| Review or preview reached | `showSharedPlayers` previews decoded rows; existing team players are shown through `PlayersOnTeamView`. |
| Confirmation requirement | A user tap is required on `Import`, `Imported`, or `Current` before roster writes. |
| Persistence writer reached | `sharedPlayersBoss`, `currentPlayersBoss`, and `getCurrentPlayers` insert or mutate teams and players and call `modelContext.save()`. |
| Cancellation behavior | Back/dismiss before tapping import leaves decoded preview state only; no permanent roster write was found before confirmation except team creation can occur in `getCurrentPlayers` only after a writer path is called. |
| Failure behavior | Decode errors show alerts and return empty arrays. Save errors show alerts. There is no evidence of rollback for partial writes after a save failure. |
| Duplicate handling | Existing team detection is based on filename-derived team name. Existing player matching uses full name or last-name matching. Existing-team import offers `Imported` versus `Current` overwrite strategy. |
| Purchase or allowance involvement | No purchase or allowance gate was found for local file import. |
| Network dependency | None for local file import. |
| Temporary-file involvement | Only external/security-scoped source access; no local staging copy found. |
| Deep-link involvement | None. `scorekeep:` URLs are explicitly separated from file import at startup. |
| File-open involvement | Yes. |
| Handles rosters or games | Rosters. |
| Status | Active and user-routed. |
| Compatibility risk | Name and last-name duplicate matching can merge unrelated players; iPad and iPhone extension checks differ; decode errors are surfaced but no independent validation or conflict plan exists. |
| Fixture relevance | Task 0.9 must include minimal roster, complete roster, duplicate names, duplicate numbers, missing optional values, media-bearing roster, malformed roster, wrong content with `.ScoreKeep_Players`, unsupported extension, exported-then-reimported roster, and filename case variants. |

<!-- MARK: - 6. Local Game Import Route -->
## 6. Local Game Import Route

Route identifier: local game file import for `.ScoreKeep_Games`.

Flow:

User opens or receives file -> system delivers file URL to app `onOpenURL` -> `StartView` or `StartPhoneView` recognizes game extension -> `ImportPlayersView` appears -> `decodeGame()` decodes one `ShareGame` -> `showSharedGame` previews date and teams -> user taps `Import` or `Get Game` -> `sharedGamesBoss` imports teams, players, game, at-bats, lineups, pitchers, replacements, and incoming players through SwiftData writes.

| Inventory field | Current evidence |
| --- | --- |
| User entry point | External file URL delivered to startup view `onOpenURL`. |
| Trigger | A non-`scorekeep` URL accepted as a game file. |
| Accepted file category | Game compatibility file. |
| Expected extension | `.ScoreKeep_Games`. |
| Declared type | `com.komakode.scorekeep.games`, document label `ScoreKeep Games`, MIME `application/octet-stream` in `Info.plist`. |
| Source location | External file URL. |
| Destination location | SwiftData `Team`, `Player`, `Game`, `Atbat`, `Lineup`, `Pitcher`, `Game.replaced`, and `Game.incomings`. |
| Current coordinator | Presentation-owned `ImportPlayersView`. |
| Decoder reached | `ImportPlayersView.decodeGame()`. |
| Validation reached | Codable decode, duplicate check by visiting team, home team, and date, plus runtime force unwraps during child import. |
| Review or preview reached | `showSharedGame` previews date and team names/logos only; current games list is shown beside it. |
| Confirmation requirement | A user tap on `Import` or `Get Game` is required before game import writes. |
| Persistence writer reached | `sharedGamesBoss`, `sharedPlayersBoss`, `doAtbats`, `doLineups`, `doPitchers`, `doReplaced`, and `doIncomings`. |
| Cancellation behavior | Back/dismiss before tapping import leaves decoded preview state only. |
| Failure behavior | Decode failure shows a generic read alert. Child import functions use force-unwrapped teams and players in several places, so malformed game relationships may crash or fail unsafely; this is a fixture-catalog risk. |
| Duplicate handling | Existing game detection uses visiting team name, home team name, and exact date. If duplicate exists, the route shows an alert asking the user to delete the existing game before importing. |
| Purchase or allowance involvement | No purchase or allowance gate was found for local game import. A comment in `ImportPlayersView` notes imported game creation should be treated carefully relative to free counters, but the import route itself does not decrement `freeGameCreatesRemainingKC`. |
| Network dependency | None for local file import. |
| Temporary-file involvement | Only external/security-scoped source access; no local staging copy found. |
| Deep-link involvement | None. |
| File-open involvement | Yes. |
| Handles rosters or games | Games, with nested teams and players. |
| Status | Active and user-routed. |
| Compatibility risk | Duplicate game matching may skip legitimate same-team same-date games; child import force unwraps can fail on missing or third-team references; partial saves occur across child import functions without a single transaction boundary. |
| Fixture relevance | Game fixture work after task 0.5 must include missing team/player reference, third-team reference, duplicate same-date games, substitution-heavy games, pitcher-heavy games, score mismatch, missing lineup players, malformed game, and exported-then-reimported game. |

<!-- MARK: - 7. External File-Open Routing -->
## 7. External File-Open Routing

There are three confirmed `onOpenURL` layers relevant to file-open behavior:

| Layer | Evidence | Behavior |
| --- | --- | --- |
| App-level | `ScoreKeepApp` lines 51-55. | Parses only custom `scorekeep` deep links and sets `router.destination`. It does not route file URLs to import. |
| iPad root | `StartView` lines 133-147 and 176-184. | Separates `scorekeep` URLs from file URLs. For file URLs, accepts lowercased path extensions `scorekeep_players` and `scorekeep_games`, plus a lowercased filename fallback containing those strings. Presents import in the detail column. |
| iPhone root | `StartPhoneView` lines 86-116 and 127-130. | Separates `scorekeep` URLs from file URLs. For file URLs, accepts exact path extensions `ScoreKeep_Players` and `ScoreKeep_Games`, requests security-scoped access, and presents import in a full-screen cover. |

Cold-launch and warm-launch findings are uncertain. Repository evidence confirms that app-level, iPad, and iPhone `onOpenURL` handlers exist, but this documentation task did not run device-level file-open scenarios. It is therefore unresolved whether cold-launch file URLs always reach the same startup view handler as warm-launch file URLs. The app-level handler currently ignores non-`scorekeep` file URLs, so if the system delivers a cold-launch file URL only to that layer, file import would not be routed by the inspected code. If the system delivers the file URL to the active `StartView` or `StartPhoneView`, the route should proceed to `ImportPlayersView`.

Route differences:

| Difference | Evidence | Compatibility implication |
| --- | --- | --- |
| Case handling differs by device | `StartView.isImportFileURL` lowercases and uses filename fallback; `StartPhoneView.isImportFileURL` compares exact strings. | Uppercase/lowercase extension variants may work on iPad but fail on iPhone. |
| Security-scoped access differs | `StartPhoneView` calls `startAccessingSecurityScopedResource()` before presenting import; `StartView` does not. `ImportPlayersView` also starts access during decode. | External file permission behavior may differ by device and launch state. |
| Presentation differs | iPad uses detail route and `columnVisibility = .detailOnly`; iPhone uses `fullScreenCover`. | Cancellation and resume behavior should be verified separately. |
| App-level file handling absent | `ScoreKeepApp.onOpenURL` handles only `parseDeepLink`. | Cold-launch file delivery is an unresolved risk. |

Recommended fixture relevance: task 0.9 should exercise both direct file opening and share/download handoff for `.ScoreKeep_Players` on iPhone and iPad where practical, including exact-case and case-variant filenames.

<!-- MARK: - 8. MLB Roster Download Route -->
## 8. MLB Roster Download Route

Route identifier: MLB roster download to roster import.

Flow:

User opens Share Data or deep link routes to Share/Download -> `ShareContentView` selects `Download MLB Teams` -> `getFileNames()` fetches `https://komakode.com/Teams/index.json` -> `DownloadFiles.fetchTeamsIndex` decodes `updated`, `divisions`, `teams[].name`, and `teams[].url` -> user selects a team -> route gates four free downloads unless premium is active -> selected `teams[].url` is downloaded by `DownloadFiles.downloadFile` -> file is moved from the URLSession temporary location to app Documents as `\(down).ScoreKeep_Players` -> `ShareContentView` sets local `url` and `doImport = true` -> `ImportPlayersView` previews and imports roster -> non-premium download counter is incremented immediately after successful file download and before import review/confirmation.

| Inventory field | Current evidence |
| --- | --- |
| User entry point | Share tab/Share Data screen; deep link may navigate to this workflow. |
| Trigger | Selecting a downloaded team in `ShareContentView` after manifest load. |
| Accepted file category | Downloaded roster compatibility file. |
| Expected extension | Local destination is forced to `.ScoreKeep_Players` regardless of remote URL extension. |
| Declared type | Same roster document type declarations as local import; no runtime UTI check found. |
| Source location | Direct URL from manifest `teams[].url`. |
| Destination location | App Documents directory, destination file `\(down).ScoreKeep_Players`. |
| Current coordinator | `ShareContentView` for UI, gating, manifest, and import presentation; `DownloadFiles` for network retrieval and file move; `ImportPlayersView` for decode/review/write. |
| Decoder reached | `ImportPlayersView.decodePlayers()` after the full-screen import cover appears. |
| Validation reached | Manifest JSON decode and local extension/file-exists check before presentation; roster content validation occurs only through `[SharePlayer]` decode. No body validation occurs before allowance increment. |
| Review or preview reached | `ImportPlayersView` and `showSharedPlayers`, after download. |
| Confirmation requirement | Roster persistence still requires user import tap. Download itself starts after team selection. |
| Persistence writer reached | Same as local roster import. |
| Cancellation behavior | Canceling import after successful download does not undo the local downloaded file and does not undo the counter increment by repository evidence. |
| Failure behavior | Manifest errors show a user-facing retry message. Download errors are printed only in the inspected catch block. Invalid downloaded content can still be saved and counted, then fail at import decode. |
| Duplicate handling | Download destination overwrites any existing same-name file in Documents before moving the new file. Roster duplicate handling after import follows local roster import behavior. |
| Purchase or allowance involvement | `KeychainBackedCounter(key: "mlbDownloadCountKC", defaultValue: 0)` in `ShareContentView`; non-premium users are blocked at four downloads; `mlbCounter.increment()` occurs after successful download and before import confirmation. Premium users see unlimited downloads. |
| Network dependency | Required for manifest and selected roster download. |
| Temporary-file involvement | `URLSession.shared.download(from:)` creates a temporary file that `DownloadFiles.downloadFile` moves into Documents, overwriting any existing destination. |
| Deep-link involvement | Optional. Deep links can open the download workflow and optionally prefill a team name. |
| File-open involvement | No system file-open handoff; the downloaded local file is routed internally to import. |
| Handles rosters or games | Rosters only. |
| Status | Active and user-routed. |
| Compatibility risk | Download allowance is counted before roster content decode and before import confirmation; downloaded HTML or wrong content can be saved as `.ScoreKeep_Players`; existing downloaded file can be overwritten; selected-team names must match manifest names exactly for prefill. |
| Fixture relevance | Task 0.9 should consider a pinned roster from the live manifest, wrong-content HTML saved with `.ScoreKeep_Players`, malformed downloaded roster, duplicate local team roster, and downloaded-then-canceled import behavior. |

<!-- MARK: - 9. Roster Export and Share Route -->
## 9. Roster Export and Share Route

Route identifier: roster export to `.ScoreKeep_Players` and system share sheet.

Flow:

User opens Share Data -> selects `Share Your Teams` -> selects a `Team` -> `generatePlayers()` fetches players for that team and encodes `[SharePlayer]` with nested `ShareTeam` evidence and media -> `savePlayers(playerData:fileName:)` writes `\(team.name).ScoreKeep_Players` to app Documents -> toolbar `ShareLink(item: playerURL)` hands the file URL to the system share sheet.

| Inventory field | Current evidence |
| --- | --- |
| User entry point | `ShareContentView`, `Share Your Teams` segment. |
| Trigger | Selecting a team from the picker. |
| Accepted/exported file category | Roster compatibility file. |
| Expected extension | `.ScoreKeep_Players`. |
| Declared type | Same roster document type in `Info.plist`. |
| Source records | SwiftData `Team` and `Player` records; `getPlayers()` fetches by selected team name. |
| Encoder reached | `JSONEncoder().encode(sharePlayers)` in `generatePlayers()`. |
| File creation | `savePlayers` writes into app Documents with selected team name as filename stem. |
| Destination or share handoff | `ShareLink(item: playerURL)` gives the file URL to the system. |
| Confirmation requirement | Selecting a team creates the export file immediately; system sharing requires user action on `ShareLink`. |
| Cancellation behavior | System share cancellation is handled by the system; no app callback or cleanup was found. Source records are not mutated by export. |
| Failure behavior | Encode failure returns empty `Data`; write failure prints an error and returns nil. No user-facing export failure alert was found for roster write failure. |
| Duplicate handling | Existing Documents file with the same name is overwritten by `Data.write(to:)` default behavior if allowed by the filesystem; no explicit duplicate naming was found. |
| Purchase or allowance involvement | No purchase or allowance gate was found for roster export. |
| Network dependency | None. |
| Temporary-file involvement | App Documents file is created; no temporary export file was found. |
| Deep-link involvement | None. |
| File-open involvement | Exported file can reenter the file-open route if shared/opened as `.ScoreKeep_Players`. |
| Handles rosters or games | Rosters. |
| Status | Active and user-routed. |
| Compatibility risk | Exported file includes current selected team/player data and media but no version metadata; encode failure can produce empty data; exported filename derives from team name. |
| Fixture relevance | Task 0.9 should include exported-then-reimported roster, roster with media, media-free roster, missing optional fields, duplicate player names, duplicate numbers, and filename characters from team names. |

<!-- MARK: - 10. Game Export and Share Route -->
## 10. Game Export and Share Route

Route identifier: game export to `.ScoreKeep_Games` and system share sheet.

Flow:

User opens Share Data -> selects `Share Your Games` -> selects a `Game` -> `generateGame()` creates one `ShareGame` from the selected game, teams, players, at-bats, lineups, pitchers, replacements, and incomings -> `saveGame(gameData:fileName:)` writes a `.ScoreKeep_Games` file into app Documents -> toolbar `ShareLink(item: gameURL)` hands the file URL to the system share sheet.

| Inventory field | Current evidence |
| --- | --- |
| User entry point | `ShareContentView`, `Share Your Games` segment. |
| Trigger | Selecting a game from the picker. |
| Accepted/exported file category | Game compatibility file. |
| Expected extension | `.ScoreKeep_Games`. |
| Declared type | Same game document type in `Info.plist`. |
| Source records | SwiftData `Game`, `Team`, `Player`, `Atbat`, `Lineup`, `Pitcher`, replacement, and incoming records. |
| Encoder reached | `JSONEncoder().encode(shareGame)` in `generateGame()`. |
| File creation | `saveGame` writes into app Documents with a filename stem based on visiting team, home team, and formatted date. |
| Destination or share handoff | `ShareLink(item: gameURL)` gives the file URL to the system. |
| Confirmation requirement | Selecting a game creates the export file immediately; system sharing requires user action on `ShareLink`. |
| Cancellation behavior | System share cancellation is handled by the system; no app callback or cleanup was found. Source records are not intentionally mutated by export. |
| Failure behavior | Encode failure returns empty `Data`; write failure prints an error and returns nil. No user-facing export failure alert was found for game write failure. |
| Duplicate handling | Existing Documents file with the same name may be overwritten by the file write. |
| Purchase or allowance involvement | No purchase or allowance gate was found for game source-data export. |
| Network dependency | None. |
| Temporary-file involvement | App Documents file is created; no temporary export file was found. |
| Deep-link involvement | None. |
| File-open involvement | Exported file can reenter the file-open route if shared/opened as `.ScoreKeep_Games`. |
| Handles rosters or games | Games. |
| Status | Active and user-routed. |
| Compatibility risk | `getLineups` constructs `ShareLineup` without passing `players`, so exported game lineups can lose player lists; `getPlayers(players:)` only appends players whose `team != nil`; encode failure can produce empty data. |
| Fixture relevance | Game fixture curation should include round-trip game export, lineup-player preservation, substitutions, pitchers, score mismatch, game with media, and exported-then-reimported file behavior. |

<!-- MARK: - 11. Seed and Sample Game Route -->
## 11. Seed and Sample Game Route

Route identifier: first-launch bundled seed game.

Flow:

App starts -> `ScoreKeepApp` injects hidden `SeederView` after model context exists -> if `@AppStorage("hasSeededInitialGame")` is false, bundle lookup finds `seededGame.ScoreKeep_Games` -> `ImportService.decodeSeededGame(from:)` decodes one `ShareGame` -> `ImportService.importShareGames(_:)` writes teams, players, game, at-bats, lineups, pitchers, replacements, and incomings -> `hasSeededInitialGame` is set true after success.

| Inventory field | Current evidence |
| --- | --- |
| User entry point | App launch; not ordinary user file import. |
| Trigger | First run or any launch with `hasSeededInitialGame == false`. |
| Accepted file category | Bundled `.ScoreKeep_Games` seed. |
| Expected extension | `.ScoreKeep_Games`. |
| Source location | App bundle resource `seededGame.ScoreKeep_Games`. |
| Destination location | SwiftData records. |
| Current coordinator | `ScoreKeepApp.SeederView` and `ImportService`. |
| Decoder reached | `ImportService.decodeSeededGame(from:)`. |
| Validation reached | Codable decode and `ImportService` two-team checks for child game content. |
| Review or preview reached | None. This route bypasses `ImportPlayersView` review. |
| Confirmation requirement | None. It is automatic once the launch condition is met. |
| Persistence writer reached | `ImportService.importShareGames(_:)` and helpers. |
| Cancellation behavior | No user cancellation. If seeding fails, the catch logs the failure and the app may try again on a future launch because the flag remains false. |
| Failure behavior | Errors are logged with `os_log`; no user-facing alert was found. |
| Duplicate handling | `ImportService.importShareGames` skips an incoming game if visiting team, home team, and date match an existing game in its cache. The `hasSeededInitialGame` flag prevents ordinary repeat import after success. |
| Purchase or allowance involvement | None found. |
| Network dependency | None. |
| Temporary-file involvement | None. |
| Deep-link involvement | None. |
| File-open involvement | No system file-open; bundle resource lookup only. |
| Handles rosters or games | Games. |
| Status | Active seeded/sample route. |
| Compatibility risk | Seed path uses `ImportService`, while user game import uses `ImportPlayersView`, so validation, duplicate handling, preview, error behavior, and partial-save behavior differ. |
| Fixture relevance | The existing seed should remain unchanged and can inform game compatibility fixtures, but it must not be classified as ordinary user import without separate route evidence. |

<!-- MARK: - 12. Deep Links and Custom URLs -->
## 12. Deep Links and Custom URLs

Confirmed custom URL route:

`scorekeep://share?tab=download&prefill=...`

Flow:

System opens custom URL -> app-level or startup view parser checks `scheme == "scorekeep"`, `host == "share"`, and query `tab == "download"` -> parser returns `.shareDownloadTeams(prefill:)` -> root view observes router destination -> iPad opens `ShareContentView` in the detail column; iPhone selects the Share tab -> `ShareContentView.applyDestination` activates `Download MLB Teams`, fetches manifest if needed, and sets `down` to the prefill value when the manifest map contains it -> selecting or setting `down` triggers the roster download route.

| Inventory field | Current evidence |
| --- | --- |
| User entry point | Custom URL opened by system, external app, announcement CTA, or manually constructed link. |
| Trigger | `scorekeep` scheme with `share` host and `tab=download`. |
| Accepted file category | No file is accepted directly by deep link; route targets roster download UI. |
| Expected extension | None at deep-link stage. Download later creates `.ScoreKeep_Players`. |
| Declared type or identifier | `scorekeep` URL scheme in `Info.plist`; `AppRouter.Destination.shareDownloadTeams(prefill:)`. |
| Source location | URL query parameters. |
| Destination location | Share/download presentation state. |
| Current coordinator | Duplicated parsers in `ScoreKeepApp`, `StartView`, `StartPhoneView`, and `ShareContentView`; shared `AppRouter` carries destination. |
| Decoder or parser reached | `parseDeepLink(_:)` variants; no compatibility file decoder reached directly. |
| Validation reached | Scheme, host, and tab checks only. Prefill is accepted as a string and later checked against `teamURLMap`. |
| Review or preview reached | Download import review only if the route causes a roster download and import presentation. |
| Confirmation requirement | Deep link does not itself import. It may preselect a team after manifest load; setting `down` can start download when a matching prefill exists. |
| Persistence writer reached | None directly; roster import writer is reached only after download and user import confirmation. |
| Cancellation behavior | Unsupported or malformed links return nil and do not route. |
| Failure behavior | Missing manifest match leaves pending prefill until map update or no import occurs. Unsupported host/tab silently do nothing by repository evidence. |
| Duplicate handling | None directly. |
| Purchase or allowance involvement | Deep link can route to a download flow that enforces `mlbDownloadCountKC`. |
| Network dependency | Manifest/download route requires network after navigation. |
| Temporary-file involvement | Only after download starts. |
| Deep-link involvement | Yes. |
| File-open involvement | No. Custom URL routes are explicitly separated from file import. |
| Handles rosters or games | Download workflow handles rosters only. |
| Status | Active, duplicated parser implementation. |
| Compatibility risk | Parser duplication can diverge; deep-link prefill may trigger selected-team download through `down` state once manifest arrives; route behavior should be verified on cold and warm launch. |
| Fixture relevance | Task 0.9 should not create deep-link fixtures, but roster fixtures should later be exercised through a prefilled download route when a pinned source exists. |

Announcement route note: `AnnouncementSheet` uses `openURL` on remote `ctaURL` values from `message.json`. Repository evidence confirms this can hand arbitrary valid URLs to the system opener, but no compatibility-specific CTA value is hard-coded in app source. Any announcement deep-link behavior therefore depends on remote content and must be verified separately from the static app route.

<!-- MARK: - 13. Share and External Handoff -->
## 13. Share and External Handoff

Confirmed source-data handoffs are `ShareLink(item: playerURL)` and `ShareLink(item: gameURL)` in `ShareContentView`. They hand app-created Documents files to the system share sheet. The repository does not declare specific destinations such as Mail, Messages, Files, or AirDrop in source; those are system-controlled destinations once the share sheet is presented.

Generated-output handoffs were found in report and PDF views, including `ShareLink` in `PitcherRptView`, `ShowPitchRptView`, `PdfView`, `ReportView`, `ShowReportView`, and `EditScoreView`. These are generated reports/PDFs, not `.ScoreKeep_Players` or `.ScoreKeep_Games` source-data routes. They remain relevant because generated output must not be mistaken for importable compatibility source data.

Share cancellation and destination failure behavior are not handled by custom completion callbacks in the inspected source-data export routes. Source data is not intentionally mutated by share handoff, and the generated file remains in Documents after handoff. Whether a user saves, sends, cancels, or fails in a destination app is outside current app code by repository evidence.

Compatibility risk: exported files are created before system handoff, so failed or canceled shares can leave stale export files in Documents. This is output-artifact behavior, not a baseball record mutation. Task 0.9 should treat exported files as possible source examples for round-trip roster fixtures.

<!-- MARK: - 14. Authority and Side-Effect Inventory -->
## 14. Authority and Side-Effect Inventory

Current authorities and side-effect writers:

| Responsibility | Current authority or path | Evidence | Duplicated or competing path |
| --- | --- | --- | --- |
| Decoding roster files | `ImportPlayersView.decodePlayers()` for active user-routed imports. | `ImportPlayersView` lines 220-250. | `ImportService.decodePlayers(from:)` exists but no active caller was found. |
| Decoding game files | `ImportPlayersView.decodeGame()` for active user-routed imports. | `ImportPlayersView` lines 251-274. | `ImportService.decodeGame(from:)` exists but no active caller was found; `decodeSeededGame` is active for seed. |
| Applying roster imports | `ImportPlayersView.sharedPlayersBoss` and `currentPlayersBoss`. | `ImportPlayersView` lines 275-330. | `ImportService.importPlayers` and `upsertSharedPlayers` duplicate similar behavior but are not found in the active UI route. |
| Applying user game imports | `ImportPlayersView.sharedGamesBoss` and child `do*` functions. | `ImportPlayersView` lines 331-441. | `ImportService.importShareGames` is active for seed and duplicates game import logic with different validation and duplicate behavior. |
| Applying seeded game import | `ScoreKeepApp.SeederView` plus `ImportService.importShareGames`. | `ScoreKeepApp` lines 74-99; `ImportService` lines 68-135. | User import path uses `ImportPlayersView`, not `ImportService`. |
| Encoding roster files | `ShareContentView.generatePlayers()`. | `ShareContentView` lines 469-486. | No competing roster encoder found. |
| Encoding game files | `ShareContentView.generateGame()`. | `ShareContentView` lines 521-537. | No competing game source-data encoder found. |
| Creating roster export file | `ShareContentView.savePlayers()`. | `ShareContentView` lines 487-500. | No competing `.ScoreKeep_Players` writer found. |
| Creating game export file | `ShareContentView.saveGame()`. | `ShareContentView` lines 539-552. | No competing `.ScoreKeep_Games` export writer found. |
| Opening externally supplied files | `StartView` and `StartPhoneView` `onOpenURL` handlers. | `StartView` lines 133-147; `StartPhoneView` lines 86-116. | `ScoreKeepApp.onOpenURL` handles only deep links, creating cold-launch uncertainty. |
| Routing deep links | Duplicated `parseDeepLink` functions and `AppRouter`. | `ScoreKeepApp`, `StartView`, `StartPhoneView`, `ShareContentView`. | Parser duplication is confirmed. |
| Downloading roster files | `DownloadFiles.downloadFile(from:to:)`. | `DownloadFiles` lines 111-134. | Legacy `fetchFileList(from:)` exists but no active caller found. |
| Incrementing roster-download allowance | `ShareContentView` `mlbCounter.increment()` after successful download. | `ShareContentView` lines 288-316. | No second MLB download counter writer found during this task. |
| Creating temporary compatibility files | URLSession temporary download then move to Documents in `DownloadFiles`; export files directly in Documents. | `DownloadFiles` lines 121-132; `ShareContentView.savePlayers/saveGame`. | No separate staging directory found. |
| Sharing exported compatibility files | `ShareLink` in `ShareContentView`. | `ShareContentView` lines 408-423. | System destinations are outside app control. |

Current side effects occur in presentation views and helper services. No route currently provides a single compatibility import plan, transaction boundary, conflict-resolution object, or authoritative service layer as described by the design documents.

<!-- MARK: - 15. Risks, Gaps, and Unresolved Questions -->
## 15. Risks, Gaps, and Unresolved Questions

Confirmed current risks:

| Risk | Evidence |
| --- | --- |
| Multiple import implementations exist. | User imports route through `ImportPlayersView`; seed imports route through `ImportService`; `ImportService` also has unused external decoders and import methods. |
| File-open behavior differs by device. | iPad extension checks are case-insensitive with filename fallback; iPhone checks exact extension. |
| Cold-launch file routing is unresolved. | `ScoreKeepApp.onOpenURL` ignores non-`scorekeep` URLs, while startup views handle files. System delivery order was not verified in this documentation task. |
| Roster duplicate matching can merge unrelated players. | `sharedPlayersBoss` and `currentPlayersBoss` match by full name or last-name component. |
| Game duplicate matching can skip legitimate distinct games. | `sharedGamesBoss` checks visiting team, home team, and date only. |
| Game import has force-unwrapped references. | `doAtbats`, `doLineups`, and related functions use forced team/player access. |
| Roster download allowance is counted before import confirmation. | `mlbCounter.increment()` runs after file download succeeds and before `ImportPlayersView` decode/confirmation. |
| Downloaded wrong content can be saved with a roster extension. | `DownloadFiles.downloadFile` moves the downloaded body to Documents without content validation. |
| Export encode failure can produce empty data. | `generatePlayers()` and `generateGame()` return `Data()` on encode failure. |
| Game export can lose lineup player lists. | `getLineups` creates `ShareLineup(everyoneHits:team:inning:)` without passing `players`. |
| Parser duplication can diverge. | Four `parseDeepLink` implementations exist for the same route. |
| Declared player UTI mismatch exists. | `Info.plist` declares `com.komakode.scorekeep`; `Extensions.swift` declares `com.komakode.scorekeep.ScoreKeep_Players`. |

Risks requiring verification rather than current-state claims:

| Risk requiring verification | Reason it remains unresolved |
| --- | --- |
| Whether cold-launch and warm-launch file-open behavior match. | Requires app launch/file-open scenario execution, not just source inspection. |
| Whether all exported roster files round-trip. | Requires fixture export/import execution. |
| Whether all exported game files round-trip. | Known lineup risk exists, but full round-trip behavior requires fixtures. |
| Whether temporary downloaded files survive interruption. | Source shows move from URLSession temp to Documents after download, but interruption timing was not executed. |
| Whether announcement CTA deep links remain supported in production content. | Source supports opening CTA URLs, but current remote message content was not fetched for this task. |
| Whether local tracking in Xcode reflects direct remote branch after push. | Must be verified after commit and push. |

Unresolved questions:

1. Which externally opened file route is authoritative during cold launch: app-level `onOpenURL`, root-view `onOpenURL`, or both.
2. Whether iOS delivers security-scoped file URLs differently on iPad and iPhone for this app's current scene setup.
3. Whether extension matching should intentionally remain more permissive on iPad than iPhone.
4. Whether downloaded roster allowance should count at acquisition, review presentation, or confirmed import.
5. Whether remote roster files currently include content that older releases produced or only current export shape.
6. Whether any App Store release produced `.ScoreKeep_Players` or `.ScoreKeep_Games` variants not represented by current transport structs.
7. Where future compatibility fixtures should live; Document 29 leaves the fixture-location decision to later task work.
8. Whether the additional `UTType.myCustomFile` declaration is used by any platform handoff outside the inspected source.
9. Whether seed import should remain automatic or become reviewable in the rewritten workflow; this task does not decide that.

<!-- MARK: - 16. Fixture Implications and Recommended Next Task -->
## 16. Fixture Implications and Recommended Next Task

Task 0.9 can safely proceed because the confirmed roster-relevant routes are now identified: local file-open roster import, downloaded MLB roster import, roster export/share, deep-link navigation into download, and exported-then-reopened roster flow. Fixture curation can select source examples without guessing which extension, manifest route, decoder, preview, confirmation button, persistence writer, or allowance boundary exists today.

Task 0.9 should consider these source examples:

| Fixture need | Route evidence it should exercise |
| --- | --- |
| Minimum valid `.ScoreKeep_Players` fixture | Local roster file import through `StartView` and `StartPhoneView`, decoded by `ImportPlayersView.decodePlayers()`. |
| Representative complete roster fixture | Roster export through `ShareContentView.generatePlayers()` and reimport through `ImportPlayersView`. |
| Roster with photos and team logo | `SharePlayer.photo` and `ShareTeam.logo` transport fields, `showSharedPlayers`, and roster persistence writers. |
| Missing optional-value fixture | Current import overwrite strategies for blank number, position, batting direction, batting order, photo, coach, details, and logo. |
| Unknown optional-value fixture | Codable tolerance for additive fields must be confirmed with actual files. |
| Malformed roster fixture | Decode failure alerts in `ImportPlayersView.decodePlayers()`. |
| Unsupported-extension fixture | Device-specific startup file checks. |
| Wrong-content fixture such as HTML | Download route that saves bodies as `.ScoreKeep_Players` before decode. |
| Duplicate/conflict fixture | Existing-team route with `Imported` and `Current` choices; duplicate name and last-name matching risk. |
| Exported-then-reimported fixture | `ShareContentView.savePlayers()` -> `ShareLink` or file-open -> `ImportPlayersView`. |
| Filename and extension variants | iPad case-insensitive/fallback behavior and iPhone exact-case behavior. |

Fixture curation must not change production source, tests, seeded data, StoreKit configuration, document type declarations, URL schemes, import/export behavior, purchase or allowance behavior, or persistence. It must not define new JSON fields or schemas. It should preserve historical files unchanged once selected and document expected outcomes separately.

Recommended next task: `0.9 Representative .ScoreKeep_Players fixture curation`.

This recommendation is not blocked by repository evidence. The following task after roster fixture curation, per Document 29, is `0.10 Additional .ScoreKeep_Games fixture curation` after task 0.5 evidence and roster fixture-location decisions are available.

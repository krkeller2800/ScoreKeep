# ScoreKeep Verification Specification — 16 Acceptance Fixtures and Regression Scenario Catalog

## 1. Overview

This catalog defines the acceptance fixtures and regression scenarios required to verify the rewritten ScoreKeep application before release. It is the authoritative list of controlled verification data, representative records, compatibility files, product states, and historical-risk scenarios that must produce observable evidence of release readiness.

Fixtures provide repeatable product evidence for scoring correctness, data preservation, import and export compatibility, historical-record safety, error recovery, purchases, accessibility, offline operation, and release readiness. A fixture is controlled verification data created for review and testing. It is not production user data and must not contain unnecessary personal information.

This document describes what fixture data and scenarios must exist, what each one represents, what risk or workflow it verifies, and which observable results determine acceptance. It creates no app implementation, fixture files, build assets, or test assets.

## 2. Catalog Principles

Every fixture must have a specific verification purpose tied to a user-visible workflow, compatibility contract, or known risk. A reviewer should be able to understand the fixture from its name, description, source data, and expected results without relying on hidden implementation details.

Expected outcomes must be documented before a fixture is used for release acceptance. These outcomes must be explicit enough that two reviewers can reach the same pass or fail decision from visible app state, saved records, import summaries, exports, reports, purchases, or recovery state.

Fixtures should avoid unnecessary personal information. If real historical records are adopted, they must be deliberately sanitized and approved before becoming canonical verification data.

Historical compatibility files must remain unchanged after adoption as canonical fixtures. If an older file exposes a compatibility weakness, the fixture should remain available and the expected behavior should describe whether the rewritten app accepts, repairs, warns, or rejects it safely.

Malformed fixtures must be unmistakably labeled and stored separately from valid fixtures. Generated expected output should be reproducible from saved source data. New defects should create new regression scenarios. Fixtures must cover ordinary use and historically fragile behavior, and a fixture must not be replaced merely because the rewritten implementation changes.

## 3. Fixture Classification

Baseline valid roster fixtures verify that ordinary team and player files can be imported, displayed, edited, exported, and re-imported without losing baseball meaning.

Baseline valid game fixtures verify that a game record with teams, date, identity, and setup state can be opened, saved, exported, and reported even before scoring begins.

Complete scored game fixtures verify end-to-end scoring, final state, line score, batting totals, pitching totals, scorecards, and generated reports.

In-progress game fixtures verify relaunch, resume, current batter, current pitcher, outs, runners, inning, and next-play continuity.

Interrupted or suspended game fixtures verify non-final status, pause and resume behavior, and later completion without corrupting saved scoring state.

Extra-inning game fixtures expose fixed-size inning assumptions and report truncation risks.

Large-lineup game fixtures expose batting-order limits and selection, scoring, substitution, and report behavior beyond small rosters.

Substitution-heavy game fixtures verify historical participation, incoming and outgoing players, pinch hitters, pinch runners, replacements, and lineup continuity.

Pitcher-change-heavy game fixtures verify pitcher markers, partial innings, mid-inning changes, earned and unearned runs, and agreement among pitching presentations.

Media-bearing roster fixtures verify team logos, player photos, import, export, display, and report behavior when media exists.

Media-free roster fixtures verify that empty media is valid and does not produce broken images, crashes, or false errors.

Duplicate-containing import fixtures verify conflict review and prevent unsafe identity decisions based only on name, number, teams, or date.

Malformed import fixtures verify safe rejection, repair, warnings, and recovery from invalid or hostile files.

Unsupported-future-format simulation fixtures verify that unknown optional metadata is ignored when safe and unsupported required structure is rejected clearly.

Historical legacy file fixtures verify records produced by earlier ScoreKeep releases and compatibility resources.

Purchase-state scenarios verify free allowances, season access, unavailable products, pending purchases, canceled purchases, failed purchases, and offline entitlement uncertainty.

Offline scenarios verify the local-first workflows that should remain available without a network.

Accessibility scenarios verify that critical tasks can be completed with assistive settings and alternate input.

Interruption and recovery scenarios verify coherent state after app closure, device restart, file disappearance, failed save, failed report generation, failed media selection, failed network operations, and repeated retries.

## 4. Existing Repository Fixtures

| Item | Current path | Current purpose | Canonical fixture suitability | Limitations | Must not change accidentally |
| --- | --- | --- | --- | --- | --- |
| Seeded game | `ScoreKeep/Seed/seededGame.ScoreKeep_Games` | Bundled first-launch sample game and current checked-in game compatibility file. | Suitable as an existing canonical historical game fixture after expected results are frozen. | It is the only checked-in `.ScoreKeep_Games` fixture found and does not cover all game shapes. Baseline verification decoded it as Dodgers at Blue Jays, dated `2025-11-01T22:00:00Z`, with 18 top-level players, 18 at-bats, 2 lineups, and 1 pitcher. | File name, extension, JSON meaning, embedded team/player/game identities, scoring records, and media payloads. |
| Store product configuration | `ScoreKeep.storekit` | Local product-state configuration for season pass verification. | Suitable as a product-state fixture source, not as baseball data. | It verifies configured product identifiers only; live App Store availability and account state still require separate review. | Product identifier convention for current season access and any products required by the release. |
| Bundled manual | `ScoreKeep/Reporting/Manual.pdf` | Local help documentation loaded and shared by the app. | Suitable as a reporting/help resource fixture. | It is not a scoring or import fixture and expected text coverage is not defined here. | Resource name, extension, bundle availability, and share/open behavior. |
| Document type declarations | `ScoreKeep/Info.plist` | Declares player and game document types and exported identifiers. | Suitable as a compatibility contract reference. | It is not fixture data. It must be verified through import/export files. | `.ScoreKeep_Players`, `.ScoreKeep_Games`, `com.komakode.scorekeep`, and `com.komakode.scorekeep.games`. |
| Deep-link route | App route contract `scorekeep://share?tab=download&prefill=...` | Opens share/download flow with optional team prefill. | Suitable as a product-state and compatibility scenario. | It is not file data and must be verified through launched app behavior. | Scheme, host, tab query, optional prefill behavior, and consistent route handling. |
| Remote roster contract | `https://komakode.com/Teams/index.json` and roster URLs ending in `.ScoreKeep_Players` | Discovers and downloads roster files. | Suitable as a compatibility scenario and source for future canonical roster fixtures. | Network availability and remote content can change, so release verification needs pinned local copies for canonical fixtures. | Manifest path, JSON shape, team URL meaning, and `.ScoreKeep_Players` extension. |
| Remote announcement contract | `https://komakode.com/Teams/message.json` | Supplies app announcements. | Suitable as an offline/error scenario. | Not a baseball record fixture. | Endpoint availability, JSON shape, and safe failure when unavailable. |

No checked-in `.ScoreKeep_Players` fixture was found during baseline verification, and the current project inventory did not identify one. Any roster fixture required for release must therefore be added later as a deliberate fixture-data task.

## 5. Canonical Roster Fixtures

Minimal Valid Roster: one team, a small number of players, all required team and player fields present, no photos, and no logo. Expected behavior is accept, display the team and players, export successfully, decode again, and re-import without changing player count, names, numbers, positions, batting directions, batting orders, or team assignment.

Full Valid Roster: complete team details, full player details, batting directions, positions, numbers, batting orders, team logo, and player photos. Expected behavior is accept, preserve visible fields and media, export and re-import with media intact, and produce the same roster meaning after round trip.

Duplicate-Name Roster: two players with the same name but distinct identities, numbers, positions, or batting orders. Expected behavior is require conflict review or preserve distinct players; it must not silently merge players solely by name.

Duplicate-Number Roster: multiple players sharing a jersey number. Expected behavior is accept with distinct players; jersey number must not be treated as unique identity.

Incomplete Roster: valid team and players with optional details, media, positions, numbers, or batting directions missing. Expected behavior is accept with warnings where useful, preserve blanks, and distinguish warnings from blocking errors.

Invalid Roster: missing required team or player identity, invalid identity values, or invalid root structure. Expected behavior is reject safely or require repair, with no partial import that leaves ambiguous records.

Large Roster: realistic high player count with varied names, numbers, batting orders, positions, photos, and blank optional values. Expected behavior is responsive search, sorting, lineup selection, import, export, conflict review, and round trip without truncation or duplication.

Every roster fixture must document expected import result, warnings, conflict handling, exported field preservation, media preservation, and round-trip meaning.

## 6. Canonical Game Fixtures

Minimal Valid Game: two valid teams, date, location, game identity, inning configuration, and no scored plate appearances. Expected behavior is open, edit, export, import, and report as an unscored or draft game without inventing scoring events.

Regulation Completed Game: complete ordinary game in which both teams bat through multiple innings and produce a known final score with hits, walks, strikeouts, errors, runs, and outs. Expected behavior is the primary end-to-end acceptance game, with expected final score, inning-by-inning score, batting totals, pitching totals, and report output documented.

In-Progress Game: saved mid-inning with runners on base, fewer than three outs, known current batter, known next batter, and known pitcher. Expected behavior is relaunch and resume into the same inning, outs, runners, current batter, next batter, pitcher, and score.

Interrupted or Suspended Game: saved during a delay with a clear non-final status. Expected behavior is pause, reopen, resume, and complete without treating the game as final until the user declares or completes it.

Extra-Inning Game: extends beyond regulation innings. Expected behavior is no fixed-size inning failure, no report truncation, correct line score, and preserved extra-inning plays after export and import.

Shortened Game: ends before expected inning count because of mercy rule, weather, time limit, or declared final status. Expected behavior is final status that preserves the shortened reason and does not require nonexistent innings.

Large-Lineup Game: batting order beyond historical fixed-array limits. Expected behavior is scoring, lineup display, substitutions, reports, and export without index crashes or dropped players.

Substitution-Heavy Game: multiple pinch hitters, pinch runners, permanent replacements, incoming players, and outgoing players. Expected behavior is historical participation and lineup continuity across every affected report and correction.

Pitcher-Change-Heavy Game: multiple pitchers, mid-inning changes, between-inning changes, starts, endings, and partial innings. Expected behavior is consistent pitching results across screen reports and generated output.

Correction Scenario Game: plays intentionally designed to be edited, reassigned, or deleted. Expected behavior is downstream recalculation of score, outs, runners, batting totals, pitching totals, line score, and reports.

Every game fixture must document expected score, inning state, outs, runners, current batter, next batter, pitcher, lineup state, substitutions, and major statistical outcomes.

## 7. Scoring Event Matrix

The release scoring-event matrix must include single, double, triple, home run, walk, hit by pitch, catcher interference, error, fielder's choice, dropped third strike, ground out, fly out, line out, foul out, strikeout, strikeout looking, sacrifice fly, sacrifice bunt, batter out at a base, runner out at first, runner out at second, runner out at third, runner out at home, double play, triple play, one run on a play, multiple runs on a play, zero-RBI scoring play, stolen base, multiple stolen bases where supported, earned run, unearned run, play notes or fielding notation, end-of-inning play, and third out with a potential run.

For each event, the fixture catalog must state the required starting situation, the user-visible scoring action, the expected saved result, expected score, outs, runner state, report effect, and correction scenario. The correction scenario must verify that editing, deleting, or reassigning the event updates subsequent state and reports.

## 8. Runner-State Fixtures

Runner-state fixtures must cover bases empty, runner on first, runner on second, runner on third, first and second, first and third, second and third, bases loaded, forced advancement, optional advancement, runner scoring, runner put out, multiple runners advancing, multiple runners scoring, double-play cleanup, triple-play cleanup, third-out run validation, impossible duplicate occupancy, runner remaining after scoring, and runner remaining after being put out.

Valid outcomes must preserve one runner per base, correct scoring, correct outs, and correct batter progression. Invalid outcomes must be rejected or corrected before saving, including duplicate base occupancy, scored runners still occupying a base, retired runners still occupying a base, fourth-out states, and runs incorrectly counted after a third out that prevents the run.

## 9. Lineup and Substitution Fixtures

Lineup and substitution fixtures must include traditional lineup, Everyone Hits lineup, bench players, missing lineup position, duplicate lineup position, player selected twice, late-arriving player, guest player, pinch hitter, pinch runner, permanent replacement, defensive-only replacement, pitcher entering without batting-order change where supported, re-entry, invalid re-entry, wrong substitute correction, substitution timing correction, lineup update before scoring, lineup update after scoring, and imported substitution history.

Expected behavior must document active lineup, bench state, historical participation, incoming and outgoing players, batting-order continuity, whether already-scored records remain attached to the correct participant, and how corrections affect later batters without rewriting earlier participation.

## 10. Pitcher Fixtures

Pitcher fixtures must include known starting pitcher, unknown starting pitcher, starting pitcher added after scoring begins, mid-inning pitching change, pitcher change between innings, multiple relief pitchers, unknown pitcher corrected later, pitcher marker correction, earned and unearned runs, partial inning, zero outs recorded, one out recorded, two outs recorded, pitching across multiple innings, imported pitcher history, and inconsistent pitcher history.

Expected behavior must document current pitcher, pitcher start and end points, partial innings, batters faced where visible, hits, walks, strikeouts, runs, earned runs, unearned runs, win marker where supported, and warnings or repair behavior for inconsistent imported pitcher history. Pitching results must be compared across every supported on-screen report and generated PDF presentation.

## 11. Statistics and Report Fixtures

Expected-output fixtures must exist for final score, inning-by-inning line score, runs, hits, errors, batting totals, pitching totals, batting average, on-base percentage, slugging percentage, ERA, scorecard, box score, batting report, pitching report, PDF scorecard, and historical or multi-game report where supported.

Each fixture must identify the source game, expected values, known incomplete values, how corrections change expected output, and which views must agree. Screen reports, exported data, generated PDFs, and re-opened game state must not disagree about the same baseball fact.

The regression set must explicitly include a scenario exposing the historical `Sacrifise` versus `Sacrifice` result mismatch identified during baseline verification. Expected behavior is that accepted sacrifice results are represented consistently in scoring, saved records, correction flows, and reports.

## 12. Import Compatibility Fixtures

Canonical import fixtures must include current valid `.ScoreKeep_Players`, current valid `.ScoreKeep_Games`, the existing seeded game, older valid roster, older valid game, duplicate roster, duplicate game, third-team reference inside a game, missing player reference, missing team reference, invalid UUID, invalid date, missing required key, empty optional media, valid base64 media, invalid media, unsupported result string, unknown optional value, truncated file, wrong root JSON structure, wrong extension with valid-looking content, valid extension with invalid content, and future-version metadata simulation.

Expected import results must be classified as accept, accept with warnings, require conflict resolution, require repair, or reject safely. Rejection must leave existing records unchanged. Repair must be explicit and reviewable. Conflict resolution must identify which existing and incoming records are affected.

## 13. Export and Round-Trip Fixtures

Round-trip fixtures must include basic roster, full roster with photos and logo, basic game, completed scored game, game with substitutions, game with multiple pitchers, game with earned and unearned runs, game with base-path outs, extra-inning game, interrupted game, unknown player or pitcher, and corrected game.

Each scenario must verify the same baseball meaning through local record, export, decode, re-import, and regenerated reports. Required preserved meaning includes team identity, player identity, lineup state, substitutions, pitcher history, plate appearances, scoring results, outs, runners, inning state, media where applicable, and reportable totals.

Known baseline limitations that the rewrite must correct include exported lineup player lists being lost, nested team metadata being incomplete in some references, and import matching that can merge or skip records by names, teams, and date rather than stable identity.

## 14. Error and Recovery Scenarios

Recovery scenarios must include app closes during scoring, app closes during an incomplete plate appearance, app backgrounds after a completed play, device restarts, battery loss, app closes during import review, app closes after import confirmation, app closes during export, file disappears during import review, save fails, report generation fails, PDF generation fails, photo selection fails, permission denied, network fails during download, purchase status cannot be confirmed, repeated retry, and multiple simultaneous errors.

Expected recovery state must be coherent. Completed plays should remain completed, incomplete plays should be clearly recoverable or discarded without corrupting totals, confirmed imports should not duplicate on retry, unconfirmed imports should not partially appear, failed exports should not alter source records, failed reports should leave records unchanged, and repeated errors should remain understandable to the user.

## 15. Purchase and Allowance Scenarios

Product-state scenarios must include two free game creations available, one free game creation remaining, zero free game creations remaining, failed creation does not decrement allowance, canceled creation does not decrement allowance, imported game does not decrement allowance unless explicitly specified otherwise, four free roster downloads available, last free roster download, failed download does not decrement allowance, invalid downloaded file does not decrement allowance, purchase canceled, purchase failed, purchase pending, current-season access active, prior-season access expired, wrong-season product offered, product unavailable, price unavailable, status check unavailable, active access while offline, and reinstall or device-change uncertainty.

Expected behavior must state visible allowance, visible access state, available action, error or warning text, and whether retry is offered. Baseball records must remain unchanged in every purchase-state scenario.

## 16. Offline Scenarios

Offline scenarios must include launch while offline, open existing game offline, create new game offline, score complete game offline, correct completed game offline, generate local report offline, export locally offline, import local file offline, attempt roster download offline, attempt purchase offline, attempt status check offline, announcement refresh offline, and return online after prolonged offline use.

Expected behavior is that local records, local scoring, local corrections, local reports, local exports, and local file imports remain available unless the release specification says otherwise. Network-only features must fail clearly without changing local baseball records. Returning online must refresh network-dependent state without overwriting offline scoring work.

## 17. Accessibility Scenarios

Accessibility scenarios must include VoiceOver game-list navigation, VoiceOver team and player management, VoiceOver lineup creation, VoiceOver live scoring, VoiceOver correction, VoiceOver import conflict review, VoiceOver destructive confirmation, VoiceOver purchase status, maximum supported larger text, high contrast, reduced motion, color-independent scoring state, external keyboard form entry, focus order, orientation or window change during accessibility use, and accessible reports and generated previews.

Each scenario must identify the critical task the user must complete, the required starting record, the expected visible or spoken state, the expected saved result, and any blocking accessibility failure. Color must not be the only signal for scoring state, warnings, destructive actions, or purchase access.

## 18. Performance and Scale Scenarios

Scale categories should be named Small, Typical, Large, and Stress. Practical limits remain to be established during implementation and release verification; this catalog does not invent unsupported hard limits.

Representative scale fixtures and scenarios must cover many teams, many seasons, many players, large roster, long batting order, extra-inning game, many substitutions, many pitchers, long scoring session, large photos, many photos and logos, large import, long report, years of historical games, repeated searches and sorts, and rapid repeated taps.

Expected behavior must define whether the app remains responsive, whether progress is visible for longer work, whether memory-heavy media remains usable, whether reports complete or fail clearly, and whether rapid repeated actions create duplicate records.

## 19. Historical Defect Regression Register

| Risk | User-visible risk | Required regression scenario | Expected safe behavior | Release severity |
| --- | --- | --- | --- | --- |
| Fixed-size colbox and batbox indexing | Scoring can crash or omit plays when inning or batter columns exceed assumptions. | Large-lineup and extra-inning scored game. | No crash, no truncation, complete scoring grid and reports. | Blocker |
| Fixed-size substitution sequence indexing | Heavy substitutions can crash or attach replacement to the wrong sequence. | Substitution-heavy game with corrections. | Historical participation remains correct. | Blocker |
| Paste row component indexing | Pasted roster rows can crash or misread fields. | Malformed and incomplete pasted roster rows. | Invalid rows are rejected or warned without corrupting roster. | High |
| Force-unwrapped team and player references during import | Import can crash when references are missing. | Missing team, missing player, and third-team game imports. | Reject or repair safely with no partial ambiguous records. | Blocker |
| Force-unwrapped images | Missing or invalid media can crash display or reports. | Media-free and invalid-media fixtures. | Placeholder or warning, no crash. | High |
| Game import referencing a third team | Imported game can attach plays to an unexpected team or fail unsafely. | Third-team reference inside game fixture. | Reject or require repair before import. | Blocker |
| Missing lineup players in exported game data | Exported games can lose lineup meaning after round trip. | Round-trip game with complete lineups. | Lineup players survive export and re-import. | Blocker |
| Team and player matching by name | Duplicate names can merge unrelated records. | Duplicate-name roster and duplicate team scenario. | Require conflict review or preserve identities. | Blocker |
| Duplicate game matching by teams and date | Distinct games can be skipped or merged. | Doubleheader or same-teams same-date duplicate game. | Require conflict review or preserve distinct games. | High |
| Inconsistent manual deletion behavior | User may believe related records were deleted when they remain. | Player and team deletion with related scoring records. | Destructive confirmation accurately states result and preserves valid related records. | High |
| Player deletion leaving related records | Reports or scoring can reference deleted players. | Delete player with existing at-bats and pitcher records. | Deletion is blocked, repaired, or leaves readable historical records. | Blocker |
| Stored game scores differing from calculated scores | Lists, reports, and game detail can disagree. | Completed game with stored score mismatch. | Visible reports agree or identify repaired score source. | High |
| Duplicate scoring records | Score and reports can double count or show duplicate rows. | Duplicate first-column and rapid repeated scoring scenario. | Duplicates are prevented or corrected visibly. | High |
| Sacrifice spelling mismatch | Sacrifice plays can be omitted from reports or corrections. | `Sacrifise` versus `Sacrifice` scoring fixture. | Accepted sacrifice values are consistent across app state and reports. | High |
| Pitching calculation differences between report implementations | Pitching reports can disagree. | Pitcher-change-heavy game with earned and unearned runs. | All supported pitching views and PDFs agree. | Blocker |
| Incorrect or incomplete document UTI behavior | Shared files may not open or may open in the wrong flow. | Open valid player and game files by extension and declared document type. | Correct import review opens consistently. | High |
| Duplicate deep-link parsing | Same link may route differently by device or entry point. | `scorekeep://share?tab=download&prefill=...` on supported device classes. | One consistent destination and prefilled team state. | Medium |
| Debug free-counter reset behavior | Release allowance could reset unexpectedly. | Fresh install, relaunch, and release build allowance scenario. | Allowance persists according to product rules. | Blocker |
| Missing test action configuration | Release evidence may be absent even when source files exist. | Release verification checklist review. | Required acceptance evidence is collected regardless of placeholder configuration. | Medium |
| Simulator or platform build-environment limitations | Build or verification may fail for infrastructure reasons. | Build-environment readiness scenario. | Infrastructure limitation is recorded separately from product failure. | Medium |

## 20. Canonical Expected Results

Expected results must document expected score, expected inning, expected outs, expected runners, expected next batter, expected current pitcher, expected lineup state, expected substitutions, expected batting totals, expected pitching totals, expected reports, expected import summary, expected export meaning, expected purchase allowance, and expected error or warning.

Expected results must use concrete values where possible, including team names, player names or fixture identities, inning, half-inning, outs, base occupancy, run totals, hit totals, error totals, pitcher totals, and visible warnings. They must be explicit enough that two reviewers can independently reach the same pass or fail decision.

## 21. Fixture Maintenance Rules

Canonical fixtures are version-controlled. Historical fixtures are not casually rewritten. Changes require an explanation that identifies why the fixture changed, which expected results changed, and which release risk is affected.

New product behavior may add fixtures. New defects require regression scenarios. Removed behavior requires an approved specification change. Personal or production user records must not become fixtures without deliberate sanitization and authorization.

Fixture names should describe purpose. Malformed fixtures must be unmistakably labeled. Expected results must change with fixture changes. Obsolete fixtures should be archived or retired visibly rather than silently deleted.

## 22. Release Fixture Set

Every release must verify at least the minimal roster, full roster with media, regulation completed game, in-progress game, extra-inning game, large-lineup game, substitution-heavy game, pitcher-change-heavy game, correction game, legacy roster, legacy game, malformed roster, malformed game, duplicate roster, duplicate game, round-trip export game, offline scenario, purchase allowance scenario, accessibility live-scoring scenario, and historical defect regression set.

Additional fixtures may be required based on release scope. Any feature touching imports, exports, scoring, substitutions, pitchers, reports, purchases, media, accessibility, offline behavior, or compatibility contracts must expand the release fixture set enough to cover the changed behavior and related existing workflows.

## 23. Completion Criteria

This fixture and regression catalog is complete enough to support implementation and release work when every major workflow maps to at least one scenario, every known high-risk baseline defect maps to a regression scenario, existing compatibility resources are inventoried, missing canonical fixtures are identified, expected results are documented, the release fixture set is defined, privacy and sanitization requirements are addressed, and no app files or fixture data changed in this task.

The current catalog identifies the checked-in seeded game, product configuration, bundled manual, document type contracts, deep-link route, remote roster contract, and remote announcement contract. It also identifies missing canonical roster, game, import, export, malformed, historical, purchase, offline, accessibility, scale, and expected-output fixtures that must be created or adopted in later fixture-data tasks.

Unresolved fixture-policy questions remain: where canonical fixture files should live, who approves sanitized historical records, whether live remote roster downloads should be pinned into local fixtures for release verification, how legacy files from older releases will be collected, and which practical scale limits define Small, Typical, Large, and Stress for ScoreKeep releases.

# ScoreKeep Functional Specification — 15 Acceptance Testing and Verification

## 1. Overview

Acceptance testing for ScoreKeep verifies that the rewritten application satisfies the functional and non-functional specifications through observable product behavior. It defines the release-level evidence needed to trust ScoreKeep with real baseball records, live scoring, reports, imports, exports, purchases, media, preferences, and recovery situations.

The purpose of acceptance verification is to answer whether a user can complete supported workflows correctly, understand what happened, recover from ordinary failures, and preserve their records over time. Verification must focus on user-visible outcomes rather than internal design, source structure, or implementation technique.

Release confidence comes from exercising complete workflows, representative data, edge cases, compatibility files, interrupted operations, and previously risky scenarios. A release is not acceptable merely because individual screens open; it must preserve coherent baseball state across the full lifecycle of teams, players, games, scoring events, reports, imports, exports, purchases, media, and preferences.

Regression prevention is part of acceptance testing. Existing supported behavior, known compatibility expectations, and previously corrected defects must remain verified before public release. When a feature changes, acceptance verification must confirm both the intended new behavior and the continued safety of related existing workflows.

## 2. Acceptance Principles

Verification must occur before release. A public build is acceptable only when the major workflows described in the functional specifications have been exercised and their outcomes are known.

Acceptance criteria must be observable. A pass or failure should be determined from visible app behavior, saved records, generated output, import and export results, purchase state, or recovery state that a user or reviewer can inspect.

User-visible outcomes are authoritative for acceptance. Internal completion, hidden state, or assumed success is not sufficient when the product does not show the user a coherent result.

Regression protection must cover ordinary workflows and historically risky areas. Live scoring, game correction, import compatibility, export safety, purchase gating, media handling, and data preservation require repeated verification across releases.

Compatibility preservation is required for existing ScoreKeep data and workflows. Supported historical files, seeded records, document-opening behavior, deep links, photos, logos, reports, and purchase meaning must either continue to work or fail with clear product-language explanation and safe recovery options.

## 3. Application Verification

Launching ScoreKeep must open the application into a usable local state. Existing teams, players, games, imports, reports, preferences, and purchase status should not be lost or rewritten during launch.

The app must handle shutdown and relaunch without losing confirmed records. After closing and reopening, the user should see the latest coherent saved state for teams, players, games, scoring progress, media, preferences, and purchase-related status.

Resume behavior must return the user to a reasonable state. If the app was in a list, editor, game setup flow, scoring view, report flow, import review, export flow, or purchase flow, the resumed state should either continue safely or explain why the previous transient state cannot continue.

Backgrounding during ordinary work must not corrupt records. If the user backgrounds the app during team editing, player editing, lineup setup, scoring, correction, import review, export preparation, report generation, or purchase interaction, returning to the app should preserve confirmed data and clearly identify any incomplete action.

Recovery after termination, restart, or resource pressure must preserve the latest coherent baseball state. Partial work should not appear as confirmed unless it was safely completed.

Multiple launches must produce consistent results. Repeated launch, quit, resume, and relaunch cycles should not duplicate seeded records, duplicate purchases, alter preferences unexpectedly, or change saved baseball facts.

## 4. Team and Player Verification

Creating a team must produce a selectable team record with the expected name, coach information, details, logo state, player membership, and game participation state.

Editing a team must update only the intended team. Existing players, historical games, reports, imports, exports, and unrelated teams should remain unchanged except where the user-visible workflow explicitly says they will be affected.

Deleting a team must require clear confirmation and affect only the selected scope. Historical records that must remain understandable should not silently become misleading or inaccessible without explanation.

Creating a player must preserve the entered name, number, position, batting details, team association, photo state, active status, and any other supported visible fields.

Editing a player must update the intended current player record while preserving historical participation. Past games and reports should remain understandable after name, number, position, photo, batting information, or team membership changes.

Deleting or making a player inactive must not silently erase historical participation. The app should distinguish current roster availability from past game involvement.

Player photos and team logos must be selectable, replaceable, removable, displayed where supported, and safely handled when missing or invalid. Removing media must not delete the related player or team.

Search, sort, and filtering must return understandable results for teams and players. Empty results, inactive records, duplicate names, changed numbers, and large rosters should be handled without losing context.

Historical participation must remain visible where relevant. A player who appears in a past lineup, substitution, pitcher record, at-bat, scorecard, box score, or report should remain identifiable even when current roster status changes.

## 5. Game Lifecycle Verification

Game creation must produce a coherent draft or setup state with the selected teams, date, location, inning settings, lineup expectations, and scoring options.

Draft games must remain distinguishable from ready, scoring, completed, archived, or imported games. A draft should not be presented as ready for scoring until required setup is complete.

Setup verification must confirm teams, players, lineups, pitchers where required, batting order, home and visitor designation, innings, and any everyone-hits behavior needed for the game.

A ready game must open into a scoring state with the correct teams, score, inning, half inning, outs, batter, lineup context, pitcher context where applicable, and runner state.

A scoring game must preserve each confirmed plate appearance and transition to the next coherent game state. The app must not create duplicate batters, phantom outs, unexpected runners, or unexplained score changes.

Completing a game must mark the game as complete while preserving the final score, innings, lineups, at-bats, substitutions, pitchers, notes, statistics, scorecards, reports, and exportable source data.

Correction workflows must update the selected game and affected derived results without requiring unrelated innings or records to be rebuilt.

Archiving a game must remove it from ordinary active workflows only as designed, while preserving review, reporting, export, and historical participation behavior where supported.

Deleting a game must require clear confirmation and must not delete unrelated teams, players, photos, logos, preferences, purchases, or other games.

## 6. Live Scoring Verification

Plate appearances must record the selected batter, inning, sequence, result, outs, runner movement, RBI attribution, pitcher context, and team score consistently.

Hits must advance batters and runners according to the selected scoring result and must update score, hits, player statistics, pitcher statistics, scorecards, box scores, reports, and exports consistently.

Walks must preserve batter and runner advancement, pitcher attribution, earned-run implications where supported, and inning state.

Strikeouts must update outs, batter statistics, pitcher statistics, inning progression, and reporting outputs consistently.

Errors must preserve the baseball distinction between reaching safely, run scoring, outs, earned-run handling where supported, and defensive result notation.

Sacrifice flies and sacrifice bunts must affect at-bat status, outs, runner movement, RBI handling, statistics, and reports according to the product scoring rules.

Double plays and triple plays must record the correct out count, inning transition, runner removal, batter result, score impact, and report notation.

Steals must record runner advancement and statistics without creating unrelated plate appearances or changing the batter incorrectly.

Wild pitches and passed balls must advance runners, affect scoring context, and remain visible in the saved play record where supported.

Pitching changes must preserve the inning, outs, current batter, runner state, prior pitcher record, new pitcher record, and reporting attribution.

Substitutions must preserve lineup order, historical participation, current batter context, defensive or batting role where supported, and later reports.

Extra innings must remain scoreable and reportable without fixed-inning assumptions causing crashes, truncation, or misleading totals.

## 7. Statistics Verification

Batting statistics must match saved plate appearances, corrections, substitutions, sacrifices, walks, strikeouts, hits, RBIs, runs, and other supported scoring facts.

Pitching statistics must match saved pitcher participation, batters faced, innings or outs, strikeouts, walks, hits, runs, earned-run handling where supported, pitcher changes, and game result attribution.

Team statistics must match the team’s saved games, player participation, scoring events, corrections, and selected reporting scope.

Game statistics must agree across game summary, scorecard, box score, reports, PDFs, exports, and reopened game state.

Season or multi-game statistics must include the intended games and exclude drafts, deleted games, unrelated teams, or unsupported records according to the visible scope.

Reports must use the current saved game or selected reporting scope. Generated summaries should not contradict the source records.

Consistency verification must compare statistics across visible app views and generated outputs. A release-blocking failure exists when the same saved baseball fact produces conflicting totals without explanation.

## 8. Import Verification

Roster file imports must show the apparent file scope, teams, players, photos, logos, duplicates, conflicts, skipped records, and required user choices before permanent changes occur.

Game file imports must preserve supported teams, players, lineups, at-bats, pitchers, substitutions, scores, innings, photos, logos, and reporting meaning where available.

Compatibility verification must include supported existing `.ScoreKeep_Players` and `.ScoreKeep_Games` behavior, seeded records, website roster files, document-opening workflows, and deep-link entry points.

Duplicate records must not be merged silently when ambiguity matters. The user should be able to understand which records are new, matched, skipped, replaced, or left unresolved.

Conflicts must be presented in product language. Name conflicts, changed numbers, changed teams, duplicate dates, mismatched photos, unsupported fields, and incompatible game facts should not damage unrelated local records.

Imported media must be reviewed before replacing local photos or logos. Missing, unreadable, oversized, unexpected, or ambiguous media should be skipped or rejected safely.

Legacy files must either import with preserved supported meaning or fail with a clear explanation. Silent truncation, invented values, or misleading success are not acceptable.

Malformed files must fail safely. Wrong file types, corrupted data, incomplete records, unsupported future content, and interrupted imports must leave unrelated local data unchanged.

## 9. Export Verification

Roster export must include the selected teams, players, supported player details, active or inactive status where applicable, photos or logos where explicitly included, and no unrelated records.

Game export must include the selected game’s teams, players, lineups, at-bats, pitchers, substitutions, score, innings, and supported media or metadata needed for later compatible use.

Report generation must produce outputs that match the saved source records and selected scope.

PDF output must be readable, complete for the selected scope, shareable through supported destinations, and consistent with in-app reports.

Share sheet behavior must require deliberate user action. Canceling or failing a share operation must leave source records unchanged.

File output must use understandable names and supported file types where practical. Export failures, unavailable destinations, permission denial, and storage issues must not alter source data.

Round-trip validation must confirm that supported exported rosters and games can be reopened or reimported without losing supported baseball meaning.

## 10. Purchase Verification

Free limits must be visible, understandable, and enforced without deleting or hiding user-owned baseball records.

Premium access must unlock the intended premium capabilities while preserving existing data, local scoring, imports, exports, reports, photos, logos, and preferences according to the purchase specification.

Restore behavior must recover valid purchase status when available and explain unavailable or failed restoration without changing baseball records.

Expiration must not delete teams, players, games, scoring events, reports already created, photos, logos, exports, imports, or preferences. Existing records remain user-owned.

Season changes must preserve the intended meaning of the configured StoreKit season product and any related allowances.

Allowance behavior must be predictable. Successful qualifying actions may consume allowance only as specified, while canceled, failed, blocked, or incomplete actions must not consume allowance.

Purchase loading failure, cancellation, network unavailability, StoreKit errors, and account uncertainty must not block ordinary local access to existing baseball data.

## 11. Offline Verification

Offline scoring must allow users to create or open local games, enter plays, correct mistakes, change pitchers, substitute players, complete games, and preserve results without network access.

Offline reports must be available where they depend only on local records and local system capabilities.

Offline imports must work for local files where system permissions allow access. Remote roster downloads or remote compatibility files may be unavailable with clear status.

Offline exports must work for local destinations where system permissions allow access. Network-only destinations may be unavailable without changing source records.

Offline corrections must update saved local game state consistently and remain visible after relaunch.

Unavailable network features must be identified honestly. Remote announcements, roster downloads, purchase refreshes, external links, online support paths, and remote files may fail without blocking local records.

Reconnection must not rewrite local baseball records unexpectedly or duplicate prior actions.

## 12. Accessibility Verification

VoiceOver must allow users to identify major navigation areas, teams, players, forms, scoring controls, game state, alerts, confirmations, reports, import reviews, export choices, and purchase status.

Dynamic Type must preserve readable text and operable controls across supported sizes. Critical workflows must not require clipped text, hidden buttons, or inaccessible overflow to complete.

Contrast must be sufficient for reading and decision-making. Scores, selected players, warnings, disabled states, errors, inning state, runner state, and purchase state must not rely on low-contrast presentation.

Reduced Motion must avoid requiring animation to understand state changes. Users should be able to score, correct, import, export, and purchase without motion-dependent cues.

Keyboard and external input verification must cover navigation, selection, form entry, confirmation, cancellation, and recovery where supported by the platform.

Reachability must be preserved on supported iPhone and iPad layouts. Critical live-scoring controls, destructive confirmations, import choices, and correction actions should remain operable.

Reports must remain understandable with accessibility features enabled. Generated reports and PDFs should preserve readable structure where supported by the output format.

## 13. Performance Verification

Responsiveness must be acceptable for launch, navigation, team lists, player lists, game lists, setup, live scoring, corrections, reports, imports, exports, media display, and purchase status presentation.

Large rosters must remain searchable, sortable, selectable, editable, importable, exportable, and usable in lineup workflows without visible stalls that make the app appear unavailable.

Long games must remain scoreable, correctable, reportable, exportable, and reopenable. Saved state should remain consistent after many plate appearances.

Large reports must generate with honest progress or status where needed and must not alter source games if generation fails or is canceled.

Extra innings must remain responsive and accurate. The app should not assume a fixed inning count that causes truncation, crashes, or incorrect reports.

Large imports must show scope, conflicts, skipped records, and practical limits before permanent changes occur. Failure must leave unrelated records unchanged.

Repeated actions, rapid taps, slow media loading, and delayed system responses must not create duplicate saves, duplicate purchases, duplicate imports, duplicate exports, or duplicate scoring events.

## 14. Compatibility Verification

Existing fixtures must be verified before release. Supported seeded games, historical game files, roster files, and known compatibility samples must open, import, export, and report according to the compatibility requirements.

Historical games must remain understandable after app updates, player edits, team edits, media changes, purchase changes, and reporting changes.

Older exports must either remain compatible or fail with clear explanation and safe alternatives. Unsupported fields or formats must not be presented as fully imported when they are not.

Document opening must route supported files to the correct review or import workflow and must reject unsupported files safely.

Deep links must open supported destinations, preserve encoded or prefilled values where applicable, and fail safely when incomplete, malformed, or unsupported.

Photos must remain associated with the intended players across supported import, export, display, report, replacement, and removal workflows.

Logos must remain associated with the intended teams across supported import, export, display, report, replacement, and removal workflows.

## 15. Error Recovery Verification

Interrupted saves must either complete as coherent records or preserve the prior usable state. Partial records must not appear as confirmed baseball facts.

Interrupted scoring must preserve the last coherent scoring state. On return, the user should be able to continue or understand what action remains unresolved.

Import failures must leave unrelated local records unchanged and must explain what failed, what was skipped, and whether any records were changed.

Export failures must leave source records unchanged and must identify the failed destination, permission, file, or scope where practical.

Purchase failures must leave baseball records unchanged, preserve prior known access where appropriate, and avoid consuming allowances for failed or canceled actions.

Permission failures for files, photos, sharing, network access, or external destinations must explain what the user can do next without damaging records.

Recovery behavior must be repeatable. Reopening the app after a failure should show the same coherent saved state rather than a different or more damaged state.

## 16. Security and Privacy Verification

Ownership verification must confirm that teams, players, rosters, games, scoring events, lineups, pitcher records, substitutions, photos, logos, reports, imports, exports, and preferences remain user-owned product data.

Sharing verification must confirm that files, reports, PDFs, photos, logos, rosters, and game records leave the app only through deliberate user action.

Permission verification must confirm that denied file, photo, media, network, and sharing permissions produce understandable behavior without changing unrelated records.

Media verification must confirm that photos and logos are included, omitted, replaced, removed, imported, exported, and reported only according to the visible user choice.

Deletion verification must confirm that destructive actions are scoped, confirmed, recoverable where practical, and do not remove unrelated records.

Purchase separation verification must confirm that purchase status, expiration, restore failure, cancellation, and allowance behavior do not delete, rewrite, hide, or corrupt baseball data.

Privacy verification must confirm that error messages, support paths, announcements, external links, imports, exports, and purchase workflows do not expose unrelated teams, players, photos, logos, or game records.

## 17. Regression Verification

Previously fixed defects must be represented in release verification until the affected behavior is no longer supported or the risk is intentionally retired.

Legacy crash scenarios must be rechecked when they involve launch, data loading, game scoring, lineup setup, pitcher changes, substitutions, reports, imports, exports, media, purchases, or compatibility files.

Known edge cases must include large rosters, duplicate player names, repeated jersey numbers, missing teams, missing players, missing pitchers, extra innings, incomplete lineups, malformed imports, canceled exports, unavailable purchase services, missing photos, missing logos, and interrupted saves.

Historical bugs must be verified at the user-behavior level. The acceptance record should describe the scenario, expected result, actual result, and release decision without relying on internal design.

Regression verification must expand when new failures are found. A recurring issue should become part of the acceptance set until there is confidence that related workflows remain stable.

## 18. Release Verification Checklist

Complete-game scoring must be verified from game creation through final report, including ordinary plays, pitcher changes, substitutions, corrections, completion, relaunch, and export.

Reports must be verified for game summaries, scorecards, box scores, pitcher reports, PDFs, screenshots where supported, and consistency with saved source records.

Imports must be verified for rosters, games, compatibility fixtures, duplicates, conflicts, media, malformed files, cancellation, and safe failure.

Exports must be verified for rosters, games, reports, PDFs, share-sheet behavior, files, cancellation, and round-trip compatibility.

Purchases must be verified for free limits, premium state, restore, expiration, season changes, allowance behavior, cancellation, failure, and offline uncertainty.

Offline behavior must be verified for local scoring, corrections, reports, imports, exports, preferences, and unavailable network features.

Accessibility must be verified for major workflows, live scoring, forms, destructive actions, reports, Dynamic Type, VoiceOver, contrast, reduced motion, and reachable controls.

Compatibility must be verified for supported existing records, seeded data, document opening, deep links, photos, logos, reports, and older exports.

No data loss is the final release gate. Any acceptance result that loses, corrupts, hides, duplicates, or misleadingly changes user-owned baseball records must block release unless explicitly accepted as a known issue with a safe user-facing mitigation.

## 19. Acceptance Requirements

ScoreKeep can be released only when core workflows pass acceptance verification or have documented non-blocking exceptions. Core workflows include launch, local data access, team and player management, game setup, live scoring, corrections, reports, imports, exports, purchases, offline use, compatibility, accessibility, and recovery.

Blocking failures include data loss, data corruption, duplicate confirmed actions, incorrect scoring state, contradictory reports, unsafe imports, unsafe exports, purchase behavior that changes baseball data, inaccessible core workflows, unsupported silent compatibility loss, and failures that prevent ordinary local scoring.

Known issues may remain only when they are documented, scoped, understandable to affected users, and do not compromise data integrity, scoring accuracy, purchase separation, compatibility safety, or core accessibility.

Required signoff must confirm that acceptance verification was completed, release-blocking failures were resolved or formally deferred, compatibility expectations were reviewed, and the release decision is based on observed product behavior.

## 20. Validation Requirements

Each acceptance item must have observable pass or fail criteria. The expected outcome should identify the visible state, saved record, generated output, imported result, exported file, purchase state, accessibility behavior, or recovery state that proves the requirement was met.

Expected outcomes must be specific enough to prevent ambiguous success. For example, a scored play passes only when the visible game state, saved game state, statistics, reports, and reopened game agree where those outputs apply.

Failure behavior must be verified as deliberately as success behavior. Canceled, denied, malformed, interrupted, offline, unsupported, expired, and unavailable situations should leave records safe and produce understandable user-facing results.

Recovery expectations must describe what the user sees after relaunch, resume, retry, cancel, correction, permission change, purchase restore, or import/export failure.

Validation records should preserve enough context to explain the release decision, including the workflow, data used, expected result, actual result, and whether the result blocks release.

## 21. Data Integrity Requirements

Verification must confirm that data never changes unexpectedly. Teams, players, games, lineups, at-bats, pitchers, substitutions, photos, logos, reports, imports, exports, preferences, and purchase-related state should change only through visible supported workflows.

Reports must match saved games. Game summaries, scorecards, box scores, pitcher reports, PDFs, screenshots, exports, and reopened games should represent the same source facts.

Imports must be safe. Compatible imports should preserve supported meaning, while unsupported, malformed, conflicting, duplicate, or interrupted imports must avoid damaging unrelated local records.

Exports must be safe. Exporting or sharing must not change source records, include unrelated records, or imply that previously shared files can be recalled by later local edits.

Corrections must be consistent. Changing a saved scoring event must update affected scores, statistics, lineups, pitcher records, reports, exports, and visible game state without unrelated changes.

Purchases must never alter baseball data. Premium access, expiration, restore, cancellation, failure, season changes, and allowance behavior must remain separate from ownership and integrity of baseball records.

## 22. Exceptional Situations

Long tournaments must remain manageable across many teams, players, games, reports, imports, exports, and repeated launch cycles.

Large historical databases must remain searchable, reviewable, reportable, and compatible within practical product limits. When limits are reached, the app should explain them before unsafe failure.

Multiple interruptions during scoring, editing, import, export, report generation, purchase, or media selection must preserve the latest coherent state and avoid duplicate actions.

Platform updates must not silently delete, corrupt, or hide supported local records. Compatibility and permission changes should be disclosed in product language where they affect user workflows.

Repeated installs, restores, and account changes must distinguish local records, restored records, exported records, purchase state, and unrecoverable data honestly.

Large imports must provide clear scope, conflict, duplicate, skipped-record, and media behavior before permanent changes are made.

Storage pressure must not produce misleading success. Failed saves, reports, imports, exports, media changes, and generated files should leave source records unchanged or clearly mark incomplete work as incomplete.

Accessibility changes during use must not lose current work. Changing text size, contrast, motion, input method, orientation, or window size should preserve coherent app state and operable controls.

## 23. Completion Criteria

ScoreKeep can be considered fully verified for public release when acceptance verification demonstrates that all major workflows satisfy the applicable functional and non-functional specifications.

Completion requires verified launch, resume, local data access, team management, player management, game creation, lineup setup, live scoring, pitcher changes, substitutions, corrections, completion, reports, PDFs, imports, exports, purchases, offline behavior, accessibility, compatibility, security, privacy, recovery, performance, and regression scenarios.

Completion also requires no unresolved release-blocking failures, no unexplained data loss, no contradictory saved baseball state, no unsafe compatibility behavior, no purchase-driven data loss, and no inaccessible core workflow.

Any remaining known issues must be documented with scope, user impact, workaround or mitigation, release decision, and owner. Known issues that threaten data integrity, scoring accuracy, core local use, or user ownership of records block completion.

The final acceptance decision must be based on observed product behavior and preserved verification evidence. A release is complete only when ScoreKeep can be trusted during active scoring and over time with the user’s baseball records.

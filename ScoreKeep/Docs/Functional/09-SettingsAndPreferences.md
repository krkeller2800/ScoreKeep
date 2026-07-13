# ScoreKeep Functional Specification — 09 Settings and Preferences

## 1. Overview

Settings and preferences describe how ScoreKeep remembers user choices that make ordinary workflows faster, clearer, and more personal. They include remembered list sorting, search and filter behavior, game creation defaults, lineup and scoring conveniences, roster-paste setup, import and export choices, report presentation, announcements, sample-data prompts, device presentation, accessibility interaction, and reset behavior.

Preferences reduce repeated setup. A user who sorts players by number, uses a familiar roster-paste delimiter, dismisses an announcement, prefers a certain report view, or commonly creates games with the same inning count should not need to repeat those choices every time when remembering them is safe.

Preferences do not change the factual meaning of baseball records. Teams, players, games, scoring events, lineups, substitutions, pitchers, reports, photos, logos, purchases, and free-use allowances remain governed by their own product rules. A setting may influence how information is shown, which defaults appear first, or which prompts are repeated, but it must not silently rewrite baseball history or become the source of truth for baseball facts.

## 2. Preference Principles

Preferences improve convenience but do not become baseball data. A remembered list sort, filter, search, paste delimiter, report tab, announcement dismissal, or display choice is presentation or workflow state, not a team, player, game, lineup, scoring event, pitcher assignment, statistic, purchase, or allowance.

A preference should never silently corrupt, merge, overwrite, or rewrite saved records. If applying a remembered choice would affect local baseball data, imported data, game setup, lineup meaning, or scoring results, the user must be able to review the effect before it becomes permanent.

Defaults should be understandable and reversible. Users should be able to see important defaults before they rely on them, change them when needed, and recover from a stale choice without losing data.

Important destructive behavior should not rely only on a remembered preference. Deleting teams, deleting players, deleting games, replacing rosters, overwriting imported values, replacing lineups, clearing scoring data, or resetting purchase-related state requires explicit confirmation regardless of prior choices.

Preferences should remain consistent across launches when practical. A user should generally return to familiar list sorting, paste setup, report presentation, and dismissed message state after closing and reopening the app.

Missing, unsupported, invalid, or corrupted preferences should fall back safely. The user should receive a usable default, and baseball records should remain unchanged.

Device-specific presentation preferences should not change game meaning. iPhone and iPad may present navigation, search, sheets, reports, and scorekeeping layouts differently, but the same saved game must represent the same baseball record.

## 3. Sorting Preferences

ScoreKeep should remember list sorting choices where they help users repeatedly find information. Sorting may apply to games, teams, players, pitchers, shared rosters, downloaded roster lists, and report rows where the product provides sortable views.

Game sorting may include concepts such as date, team matchup, location, status, recent activity, or other visible game identity. A remembered game sort changes only the order of the game list. It does not change game dates, game status, scoring order, inning sequence, or historical meaning.

Team sorting may include concepts such as team name, coach, recent use, active status, or other visible team attributes. A remembered team sort helps browsing and selection but does not rename teams, merge teams, archive teams, or choose teams for a game without user review.

Player sorting may include concepts such as name, jersey number, batting order, position, active status, or roster grouping. A remembered player sort is presentation only. It must not change batting order, lineup order, player availability, team membership, or game participation unless the user is explicitly editing a lineup or roster field.

Pitcher sorting may include concepts such as name, jersey number, team, current game participation, or recent use. A remembered pitcher sort does not assign a pitcher to a game or alter pitcher participation markers.

Shared roster sorting may include team name, player name, roster source, file date, or other visible sharing information. Downloaded roster list sorting may include division, team name, manifest order, recently selected team, or search relevance. These sorts help the user choose a roster but must not cause automatic download or import.

Report sorting may include player name, jersey number, batting order, stat totals, pitcher order, or other displayed report columns where supported. Sorting within a report changes presentation only. It must not change the statistic value, scoring record, pitcher attribution, lineup history, or generated report meaning.

The active sort should be visible enough that the user understands why a list appears in that order. When a remembered sort is applied, the user should be able to change it without hunting for hidden state.

If a prior sort option is no longer supported, ScoreKeep should fall back to a safe default appropriate to the list and avoid treating the old value as an error that blocks the workflow. The user may be informed when a removed sort meaning affects visible behavior.

Search and sort should work together predictably. Searching narrows visible results, and sorting orders the matching results. Clearing search should restore the sorted full list rather than changing baseball records or resetting the user's intentional sort unless the workflow explicitly uses temporary sorting.

List sorting is presentation only. It has no effect on authoritative game order, scoring sequence, at-bat sequence, lineup batting order, substitution timing, pitcher participation, or report calculations unless the user enters an explicit editing workflow for that baseball data.

## 4. Search and Filtering Preferences

Search and filtering help users find records quickly without changing the records themselves. Search text, active filters, and list visibility should be treated as view state unless the user explicitly changes a team, player, game, import, or report record.

Remembered search state may be useful within a focused workflow, such as returning from a player detail view to the same filtered roster, returning from a team detail view to the same team search, or preserving a downloaded roster search while the user compares options. Long-lived search text should be used carefully because it can make expected records appear missing.

Clearing search should be direct and visible. When search text is cleared, the list should show all records allowed by the active filters and current sort.

Active versus inactive player filters may reasonably persist for roster management because users often prefer normal views to hide inactive players. When inactive players are hidden, the UI should make that filter visible so the user understands why a player may not appear. Lineup preparation should make inactive-player inclusion explicit when it affects availability.

Completed versus in-progress game filters may persist in game lists when useful. In-progress, interrupted, completed, archived, and historical games should remain discoverable. A filter must not prevent resume or review workflows from making a relevant game visible when the user follows a direct link or action.

Archived item filters may persist when the product supports archive views. Archived teams, players, or games should not disappear permanently because of a hidden filter. The user should be able to reveal archived items and understand whether they are browsing active or archived records.

Downloaded roster filters may include division, team name, roster source, downloaded state, or manifest grouping. These filters may persist while the user remains in the download workflow. They should reset or become clearly visible when stale filters would make the roster list appear empty.

Report scope filters may include game, team, player, date range, batting report, pitching report, completed games only, or other supported scopes. A report scope may persist within the reporting workflow when it helps repeated review, but it must be visible because scope changes the set of records summarized. A report filter does not change underlying statistics; it changes which saved records are included in the report view.

Device-specific search presentation may differ. iPhone may use a toolbar search entry, sheet, or compact search field, while iPad may keep search visible in a sidebar or list. The same search text and filters should produce equivalent results when applied to the same data.

Temporary filters should reset when leaving workflows where persistence would be confusing, such as one-time import review, one-time conflict review, a transient file picker, or a quick scoring selection. Filters that represent durable user intent, such as hiding inactive roster entries or preferring completed-game views, may persist when the active filter is visible and reversible.

## 5. Game Creation Defaults

Game creation defaults should reduce repeated setup without hiding important game identity. Defaults are starting suggestions for a new game, not confirmation that the suggested values are correct.

The game date should default to the current date. The user should be able to change it before saving or scoring when the game is scheduled for a different date, imported from history, resumed later, or entered after the fact.

The expected inning count may default to a common baseball value and may remember the user's last selected count when that matches repeated recreational use. The inning count should remain visible before scoring because it affects completion prompts and game review expectations.

Everyone Hits may have a default or remember the user's last safe choice. The selected behavior must still be visible before lineup preparation and scoring. If Everyone Hits changes which players bat, the user must be able to review that effect before a lineup is treated as ready.

Traditional lineup behavior may be available as a default alternative where supported. Switching between Everyone Hits and a traditional lineup should be a visible game setup choice, not a hidden preference that unexpectedly changes who bats.

Recently used teams may be suggested when safe, such as making recent teams easier to select or offering quick picks. ScoreKeep must not silently guess home or visiting teams when the wrong choice could cause the user to score the wrong game. Identity-sensitive choices require user review.

Location may be remembered or suggested when the same user commonly scores at the same field, but it should remain editable and should not be treated as proof that two games are duplicates or the same event. Notes and highlights should normally begin blank unless the user explicitly chooses a reusable note pattern.

Starting pitcher expectations may be remembered only as workflow assistance, such as prompting the user to add starting pitchers or showing a recent pitcher selection. A pitcher should not be assigned to a game without user review because that affects reports.

Last-used game settings may be remembered when they are visible and safe, including inning count, lineup mode, or other non-identity setup values. Values that identify the actual event, especially teams and game identity, must still be reviewed before scoring.

ScoreKeep must not silently guess teams, pitchers, lineups, location, or other identity-sensitive choices when doing so could cause the wrong game to be scored. Convenience defaults should speed setup, not bypass confirmation of the matchup.

## 6. Lineup and Scoring Preferences

Lineup and scoring preferences may help users begin common workflows faster, but they must not silently change baseball outcomes or remove required review.

Everyone Hits default may be remembered for new games or lineups when visible before scoring. The user should understand which players are included in the batting order before the first scored plate appearance.

Traditional lineup default may be remembered where the product supports it. A remembered traditional mode should not automatically bench players without a visible lineup review.

Scoring assistance may suggest likely bases reached, forced runner advancement, inning transitions, earned-run defaults for obvious cases, or next expected batter. Suggestions must remain correctable. The saved scoring result is the user's confirmed game record, not the suggestion itself.

Automatic runner advancement suggestions should be treated as assistance. They may prefill likely base movement for common results, but the user must be able to change runner destinations, outs, runs, RBIs, stolen bases, and earned-run decisions before the play is treated as complete.

Confirmation prompts may be remembered only when doing so does not hide destructive behavior. It may be reasonable to reduce repeated low-risk reminders, but deleting plays, replacing lineups, changing completed scoring, ending innings with unusual states, or discarding meaningful work should continue to require clear user intent.

Last-used scoring choices may be remembered where safe, such as returning to the last open scoring view, preserving a selected report tab, or keeping a chosen scoring assistance setting. A remembered result, base, RBI count, steal count, pitcher, or batter must not be silently applied to a new play without user confirmation.

Visibility of incomplete scoring warnings should be reliable. Users may be allowed to continue with incomplete pitcher information, unresolved earned-run decisions, unknown players, or incomplete lineups, but the unresolved state should remain visible and correctable.

Resume behavior for in-progress games should return the user to the saved game context: teams, score, inning, outs, runners, current batter, pitcher state, lineup state, and recent scoring context where practical. Resume behavior is restoration of the saved game state, not a preference that changes scoring.

## 7. Roster Paste Preferences

Roster paste preferences let users reuse a familiar setup for converting copied text into player records. They are convenience choices for parsing and previewing pasted roster text, not commands to alter roster data without review.

Delimiter choices may be remembered. Common delimiters may include tab, comma, space, semicolon, line breaks, or user-defined tokens. The active delimiter should be visible before applying pasted data.

Field mapping labels may be remembered. A user who maps columns to player name, number, position, batting information, or other supported roster fields should be able to reuse that arrangement when the pasted source follows the same pattern.

Saved custom tokens may be supported for repeated sources. Custom tokens should be shown in ordinary labels, editable, and removable. An invalid custom token should not crash the workflow or cause silent roster changes.

The last-used import arrangement may be restored when the user returns to paste. Restoration should make the current delimiter, column interpretation, and preview clear so stale settings do not surprise the user.

Preview before applying is required. ScoreKeep should show how rows and fields will be interpreted before creating, updating, deleting, or replacing roster entries. The user should be able to cancel after seeing the preview without changing local roster data.

Inconsistent rows should be handled safely. Rows with missing fields, extra fields, blank names, invalid numbers, or mismatched delimiters should be highlighted for review, skipped, or held for correction rather than silently creating corrupted player records.

Resetting paste preferences should restore default delimiter and mapping behavior without deleting teams, players, pasted preview text, or already saved roster records. If resetting occurs during an active paste review, the user should be able to regenerate the preview before applying changes.

Roster data must be preserved when paste settings are wrong. A stale delimiter, stale field mapping, or invalid custom token should not cause accidental roster corruption. Bulk replacement, overwrite, or deletion requires explicit confirmation after preview.

## 8. Import and Export Preferences

Import and export preferences may remember choices that reduce repeated file handling, but they must never bypass validation, conflict review, or confirmation for destructive replacement or merging.

Last import location may be remembered when supported by system workflows. Remembering a location should only help the user browse back to a familiar place; it should not automatically import files or trust files from that location.

Last export destination may be suggested where supported. The user should still control the actual destination through system sharing or saving workflows. A failed, canceled, or unavailable destination should leave source data unchanged.

Preferred conflict strategy may be remembered only as a suggested default. Choices such as keep current values, apply imported values, create separate records, skip conflicts, or review each conflict must remain visible before import changes local records.

Current versus imported value preference may be preselected for roster import when the user has made that choice repeatedly. Review is still required before imported values overwrite current values, before current values block expected imported updates, or before a merge affects historical clarity.

File naming suggestions may remember prior naming style or use visible baseball context such as team names, game date, matchup, or report type. Suggested names should be editable and should not change source data.

Report export format may remember the user's last supported output type when multiple formats are available. Format preference changes generated output only. It must not change the saved game, statistics, or compatible source export.

Downloaded roster destination may remember the user's last selected team, download workflow tab, or preferred import target when safe. A downloaded roster must still be validated and reviewed before it creates or updates local teams or players.

Repeated import warnings may be reduced only when they are informational and non-destructive. Warnings about overwriting values, replacing rosters, merging records, duplicate games, unsupported data, or possible data loss should remain visible before the action is confirmed.

Any remembered import choice that could cause destructive replacement, merging, duplicate creation, or historical ambiguity requires review before it is applied.

## 9. Report and Display Preferences

Report and display preferences change how saved baseball data is presented. They must not change statistic meaning, scoring facts, report scope without visible indication, or generated source data.

Preferred report type may be remembered, such as scorecard, batting report, pitching report, summary report, or PDF preview where supported. Opening a report may return to the last selected type when the choice is applicable to the current game or team.

Last selected batting or pitching report may be remembered within reporting workflows. If the prior report type is not valid for the current data, ScoreKeep should fall back to a safe report view and show available alternatives.

Scorecard presentation preferences may include viewing detail level, compact versus expanded rows, scorecard page orientation where supported, or other user-visible display choices. These preferences affect presentation only. They must not change at-bats, innings, base paths, runs, RBIs, outs, or substitutions.

Sorting within reports may persist when useful. The active report sort should be visible because sorting can change the user's interpretation of ranking, batting order, or pitcher order. Sorting must not change totals or calculations.

Printable or PDF presentation preferences may include page fit, detail level, visible summary sections, or last selected printable view where supported. Generated output should still identify the game or report scope and reflect the saved data at generation time.

Viewing details versus summaries may be remembered. A user may prefer compact report summaries or expanded scoring details. Hidden detail should remain accessible and should not be treated as missing data.

Device-specific report layout may vary between iPhone and iPad. A larger device may show more columns or side-by-side report context, while a smaller device may use stacked navigation. The statistics and report meaning must remain the same.

Text size and accessibility settings should interact with report display. Larger text may require fewer columns, wrapping, pagination, or alternate summaries. Accessibility adaptation should preserve statistic meaning and avoid truncating critical baseball context.

## 10. Announcement Preferences

Announcements may be remote or bundled messages that tell users about relevant updates, roster availability, purchase information, support notices, compatibility changes, or other ScoreKeep news. Announcements are informational. They must never alter baseball data, purchases, free allowances, or licensing state.

ScoreKeep should show announcements that are relevant to the current app version, date, user context, and supported product behavior. Announcements should not prevent local scorekeeping, roster management, game review, import, export, or correction.

A user should be able to dismiss an announcement. Dismissal should remove that announcement from repeated ordinary display unless the announcement is updated, replaced, or intentionally shown again through user action.

Dismissed announcements should be remembered by announcement identity. A new announcement identifier represents a new message and may be shown even if an older message was dismissed. Reusing an identifier for different content should be treated carefully because it can hide information users have not seen.

Date-limited announcements should respect their active period. Future announcements should not appear early, expired announcements should stop appearing, and missing date information should be handled conservatively.

Offline behavior should be non-blocking. If remote announcements cannot be loaded, ScoreKeep should continue local workflows without showing technical failure unless the user directly opens an announcement or news area that needs a retry state.

Invalid announcement data should be ignored or shown as unavailable without breaking the app. Malformed titles, bodies, identifiers, dates, links, or actions should not crash ScoreKeep or block scorekeeping.

Deep links or calls to action may open supported ScoreKeep workflows or external destinations. They should not bypass import validation, purchase confirmation, roster download review, or user-owned data protections.

Announcements must never block local scorekeeping. A user should be able to dismiss, skip, or ignore announcements and continue scoring, reviewing, importing, exporting, or correcting data.

Users should have control over repeated display. When an announcement has been dismissed, ScoreKeep should not show it repeatedly unless it is materially new, time-critical, manually reopened, or governed by a clearly visible reminder choice.

## 11. Sample Data and Onboarding Preferences

Sample data and onboarding preferences help new users learn ScoreKeep without risking user-created records. They may control first-run prompts, sample game import, hints, and help visibility.

First-run sample game behavior should introduce the app with a useful example when appropriate. The sample game should be identifiable as sample data so users do not confuse it with their own scored games.

One-time import of bundled sample data should avoid duplicates. If the sample has already been imported, ScoreKeep should not keep creating additional copies on each launch. If the user deletes sample data intentionally, the app should not recreate it without a visible user action or reset of onboarding state.

Sample hints may explain that a seeded or sample game exists, that the user can delete or ignore it, or that it can be used to learn reports and scoring. Hints should be dismissible.

Dismissing hints should be remembered so the user is not repeatedly interrupted. Dismissed hints should be recoverable through help or reset behavior when practical.

Users should be able to reopen help later. Onboarding dismissal should not remove the manual, help documentation, support links, or other learning material.

Sample data should be distinguishable from user-created data. The user should be able to tell whether a game or roster came from a sample, import, download, or manual creation when that distinction affects trust or cleanup.

Resetting onboarding may restore hints, first-run explanations, or sample prompts, but it must not overwrite user data or duplicate sample records without confirmation.

Sample behavior must never overwrite user-created teams, players, games, scoring events, photos, logos, imports, or purchases. If sample data conflicts with local data, ScoreKeep should preserve local data and ask before creating anything new.

## 12. Device and Presentation Preferences

Device and presentation preferences describe how ScoreKeep adapts user-visible navigation and layout across iPhone, iPad, and changing window sizes. These preferences affect usability, not baseball meaning.

ScoreKeep should provide device-appropriate navigation. iPhone may favor tabs, compact stacks, and full-screen workflows. iPad may use sidebars, split views, larger scorekeeping surfaces, or side-by-side review when practical. Core capabilities should remain available on both device types.

Orientation expectations should support real scorekeeping conditions. iPhone may primarily use portrait-oriented flows, while iPad may make wider layouts useful. Orientation or window changes should not lose the current game, search, import review, lineup draft, or scoring context.

Search presentation may vary by device. A compact device may hide search until requested, while a larger device may keep search visible. Search behavior and results should remain consistent when the same search and filters are applied.

Sheet versus full-screen presentation may vary by device and workflow. Paywalls, import review, editing, reports, help, and roster selection may use presentation styles appropriate to available space. Presentation style must not change the underlying action or confirmation requirement.

Remembered view state may be preserved where practical, such as the selected tab, selected sidebar item, last report type, active sort, or open workflow. Restoration should not force the user into a destructive action or hide that an in-progress game needs review.

Core capabilities should not depend on device type. Creating teams, managing players, creating games, scoring, lineups, substitutions, pitchers, reports, import, export, purchases, announcements, and help should remain functionally available where supported by the product.

Device adaptation should not depend on localized device-name text. From the user's perspective, ScoreKeep should behave according to actual presentation needs and available screen space, not fragile device labels.

When window size changes, ScoreKeep should adapt safely. Controls should remain reachable, active forms should remain coherent, and in-progress scoring should keep the same saved baseball state.

## 13. Accessibility Preferences

ScoreKeep should respect system accessibility choices rather than requiring users to duplicate them in app-specific settings unless a ScoreKeep-specific preference adds real value.

Larger text should be supported throughout lists, forms, scoring screens, reports, paywalls, announcements, and import review. When text grows, the interface should preserve essential baseball context instead of clipping names, scores, inning state, bases, or confirmation language.

VoiceOver should be able to identify meaningful controls and state, including teams, players, score, inning, outs, runners, current batter, pitcher state, lineup status, scoring controls, destructive confirmations, report totals, import conflicts, and purchase gates.

Increased contrast should improve readability of scorekeeping state, list selection, warnings, buttons, and report values. Color alone should not be the only way to identify batting side, active team, base occupancy, warning state, premium gate, or selected result.

Reduced motion should be respected. Animations, transitions, announcement presentation, report changes, or scoring-state updates should not rely on motion to communicate essential information.

Color differentiation should be available for users who cannot rely on color distinctions. Important scoring-state differences should also use labels, shapes, positions, or text.

Button labels should be clear for screen readers and visual users. Icon-only controls should have accessible names that communicate their action, especially for search, sorting, editing, scoring, deleting, sharing, report generation, import, and paywall actions.

Scoring-state clarity is critical. Accessibility adaptation should make the live game state understandable: current inning, half inning, outs, score, base runners, batting team, current batter, pitcher, and incomplete warnings.

Dynamic accessibility changes while the app is open should be handled coherently. If the user changes text size, contrast, VoiceOver, reduced motion, or other relevant system settings during a session, ScoreKeep should adapt without losing current work or changing baseball data.

## 14. Reset Behavior

Reset behavior lets users clear non-data preferences when the app feels cluttered, stale, or confusing. Reset must clearly distinguish preferences from baseball records, purchases, free allowances, imported files, and generated external output.

Reset sorting and display preferences may clear remembered sorts, report presentation, selected tabs, view state, search presentation, and other non-data display choices. It must not change teams, players, games, lineups, substitutions, pitchers, scoring events, statistics, reports derived from saved games, photos, or logos.

Reset roster-paste preferences may clear custom delimiters, field mappings, labels, and last-used paste arrangements. It must not delete saved rosters, pasted players already applied, teams, imported files, or game participation.

Reset dismissed hints may allow onboarding hints or sample-data explanations to appear again. It must not recreate deleted sample records or overwrite user-created data without explicit user action.

Reset announcement dismissals may allow previously dismissed announcements to appear again when they are still relevant and active. It must not alter announcement content, purchases, free allowances, baseball records, or local data.

Reset game creation defaults may clear remembered inning count, lineup-mode defaults, last-used safe settings, location suggestions, and similar setup conveniences. It must not delete draft games, in-progress games, completed games, teams, lineups, or scoring progress.

Reset all non-data preferences may combine safe preference resets. It should be explained as a reset of presentation and workflow conveniences, not as a data deletion tool.

Preference reset must never delete teams, players, games, scoring events, purchases, free-use allowances, imported files, photos, logos, compatible exported files, or generated external files. It must never falsely reset licensing state or make the user appear to have new free-use allowances.

Licensing state and free allowances are not ordinary resettable preferences. Purchase recognition, season access, free game creation allowances, and free roster download allowances follow purchase and licensing rules and must not be cleared by a preference reset.

## 15. Settings Validation

Unsupported saved sort options should fall back to a safe default for the affected list. The user should still be able to view records and choose a new supported sort.

An invalid custom delimiter should be rejected, ignored, or replaced with a safe default before paste data is applied. The user should see a preview and be able to correct the delimiter.

Missing field mapping should block or warn before pasted roster rows are applied when the missing mapping affects required player identity. Optional fields may be left blank when that is clear.

A stale imported-value preference should not decide conflicts silently. If the prior keep-current or apply-imported choice no longer matches the current import context, ScoreKeep should ask again.

An invalid report preference should fall back to a report type supported by the current data. The app should not show an empty or misleading report as if it were valid.

Announcement identifier conflicts should be handled conservatively. If different messages share an identifier, ScoreKeep should avoid hiding materially new information merely because an older message was dismissed. If the conflict cannot be resolved, showing a safe current message is preferable to blocking the app.

Invalid onboarding state should recover without duplicating sample data or hiding all help. The user should be able to reach help, and sample import should require safe duplicate handling.

A device presentation preference that is no longer supported should fall back to a layout appropriate to the current device and window. The app should preserve current work and data.

Preference values outside supported ranges should be clamped, reset, or ignored depending on the visible meaning. Examples include impossible inning defaults, invalid report display choices, unsupported filter states, or inaccessible display options.

Corrupted preference data should not block app launch or local scorekeeping. ScoreKeep should use safe defaults, preserve baseball records, and provide user-visible recovery when the corruption affects visible behavior.

## 16. Data Integrity Requirements

ScoreKeep must protect baseball records and licensing meaning throughout settings and preference behavior.

- Preferences never become authoritative baseball records.
- Resetting preferences never deletes teams, players, games, lineups, substitutions, pitchers, scoring events, or scoring history.
- Sort choices never change batting order.
- Display choices never change statistics.
- Search and filters never delete hidden records.
- Stale import preferences never silently merge or overwrite data.
- Invalid preferences fall back safely.
- Announcement state never affects purchases, free allowances, or user data.
- Sample-data state never overwrites user-created records.
- Preference changes either apply coherently or leave the prior usable state unchanged.
- Licensing state and free allowances are not ordinary resettable preferences.
- Roster-paste preferences never apply roster changes without preview and confirmation where needed.
- Game creation defaults never silently choose identity-sensitive teams, pitchers, or lineups.
- Accessibility and device presentation choices never change game meaning.
- Reset all non-data preferences means non-data only.

## 17. Exceptional Situations

**Preferences fail to load:** ScoreKeep should use safe defaults and keep local scorekeeping available. Baseball records, purchases, free allowances, imports, and reports should remain accessible according to their own rules.

**Preferences are corrupted:** Corrupted preferences should be ignored, repaired, or reset to defaults without deleting baseball records. If the user-visible effect matters, ScoreKeep should explain that preferences were reset or need review.

**App update removes an old option:** Removed sorts, filters, report views, lineup defaults, or presentation choices should fall back to supported defaults. The user should be able to choose a new option.

**User changes device:** Device-specific presentation may adapt to the new device. Data meaning should remain unchanged, and settings that no longer apply should fall back safely.

**User reinstalls the app:** Preferences may or may not be restored depending on system behavior and backups. ScoreKeep should not assume missing preferences mean baseball data, purchases, or free allowances were intentionally reset.

**User resets preferences accidentally:** The reset should affect only non-data preferences. The user may need to choose sorts, paste mappings, hints, or display choices again, but teams, players, games, purchases, and free allowances remain intact.

**Custom delimiter no longer matches pasted data:** Paste preview should reveal mismatched rows. The user should be able to change delimiter or mapping before applying data. Existing rosters should remain unchanged until the user confirms a valid operation.

**Announcement data is malformed:** The malformed announcement should be ignored or shown as unavailable without blocking scorekeeping or modifying local data.

**Sample data already exists:** ScoreKeep should avoid duplicate sample imports. If the user asks to restore sample data, the app should show duplicate risk and preserve user-created records.

**Search or filter hides expected records:** The active search or filter should be visible enough that the user can clear it. Hidden records should not be treated as deleted.

**Device rotates or changes window size:** The current workflow should adapt without losing entered text, selected records, import review, lineup work, report scope, or in-progress scoring context.

**Accessibility settings change during use:** ScoreKeep should adapt presentation while preserving current work and saved baseball state. Essential scoring controls and report values should remain reachable.

**Preference reset occurs while a game is in progress:** The reset should not change the game, current score, inning, outs, runners, batter, lineup, substitutions, pitchers, or scoring events. Any display defaults changed by the reset should apply only where safe and should not interrupt live scoring.

# ScoreKeep Functional Specification — 10 User Interface and Navigation

## 1. Overview

The ScoreKeep user interface and navigation system should make baseball scorekeeping fast, understandable, and recoverable. It should help users move between preparation, live play, review, correction, reporting, sharing, help, purchases, and settings without losing the context of the baseball work they are doing.

The interface must support three broad phases: preparing teams and games before play, keeping score during live play, and reviewing, correcting, reporting, and sharing afterward.

Preparation workflows emphasize clear choices, complete rosters, correct teams, valid lineups, and readiness before scoring begins. Post-game workflows emphasize finding saved records, understanding completed games, correcting mistakes, generating reports, exporting data, and sharing results.

Live scorekeeping has the highest need for speed, clarity, and minimal interruption. During play, ScoreKeep should keep the current baseball state visible, make the next scoring action easy to reach, avoid unnecessary prompts, and preserve in-progress work if the user pauses, changes device size, backgrounds the app, or temporarily leaves the scoring screen.

Navigation differences between iPhone and iPad are acceptable when they fit each device. The same user-facing capabilities should remain available, discoverable, and consistent in meaning on both device families.

## 2. Navigation Principles

Users should always understand where they are in ScoreKeep, what record they are viewing or editing, and what action will happen next. Lists, details, sheets, dialogs, reports, scoring workflows, and settings should identify their current game, team, player, import, report, or preference context when that context matters.

Major functional areas should be easy to reach without requiring users to remember hidden paths. Games, teams, rosters, paste, import, export, reports, help, purchases, announcements, and settings should be discoverable through visible navigation or clearly labeled actions.

Navigation must not discard unsaved or partially completed work. If a user attempts to leave a meaningful draft, ScoreKeep should either preserve it, save it coherently after explicit confirmation, or ask whether to discard it.

Back, Done, Cancel, Close, and Save actions must have consistent meanings. Back returns to the previous navigation context. Done completes the current focused task when required information is valid. Cancel abandons uncommitted changes after warning when meaningful work would be lost. Close dismisses a read-only or already preserved surface. Save commits valid edits.

Destructive actions must be visually and verbally distinct from ordinary actions. A destructive action should name the affected record or workflow and should not be placed where users can mistake it for Done, Close, or ordinary navigation.

Modal presentation should be reserved for focused tasks that temporarily require attention, such as scoring a plate appearance, choosing a pitcher, editing a lineup, resolving an import conflict, confirming a destructive action, reviewing a paywall, selecting a photo, or reading help. Modal surfaces should not become a hidden substitute for primary navigation.

Navigation should preserve context when returning from details. If a user opens a player from a filtered team roster, opens a game from a searched game list, or opens a report from a completed game, returning should restore the relevant list, search, sort, filter, and selection where practical.

Existing games and data should never become hidden behind premium gates. A premium prompt may block creation of new gated content or access to premium-only operations, but it should preserve the originating workflow and continue to allow review of existing local records.

iPhone and iPad may present navigation differently while preserving equivalent capabilities. A compact phone layout may use stacked navigation and focused screens, while an iPad may use persistent lists, details, and side-by-side review. The baseball meaning and available core workflows should remain equivalent.

## 3. Primary Functional Areas

Games are the primary entry point for creating, configuring, scoring, resuming, reviewing, correcting, deleting, and reporting on games. The games area should make each game's status clear and should provide direct access to live scoring when a game is ready or in progress.

Teams are the primary area for creating and maintaining team identity, including name, coach information, details, and logo where supported. Team navigation should lead naturally to roster management and game selection without confusing team records with one specific game's lineup.

Players and rosters cover player creation, player details, active and inactive roster membership, photos, numbers, positions, batting preferences, and roster cleanup. Roster management represents the team-level pool of players, not the batting order for a single game unless the user enters a game setup or lineup workflow.

Roster paste provides a fast way to convert copied player text into roster data. It should support delimiter and field mapping review before any player records are created, updated, replaced, or removed.

Import covers opening compatible ScoreKeep files, reviewing imported content, resolving conflicts, and applying accepted changes. Import should make source, target, conflicts, skipped records, and changed records understandable before local data changes.

Export and sharing cover sending or saving games, rosters, reports, PDFs, and compatible files through supported sharing destinations. Export should identify the records being shared and should not change the source records.

MLB roster downloads provide access to remotely available roster data where supported. Downloading should show available teams or roster sources, premium or free-use status when relevant, download progress, validation results, and import review before local roster records change.

Reports provide scorecards, batting reports, pitching reports, summaries, and generated document previews where supported. Reports should clearly identify their scope, such as game, team, player, completed games, or date range.

Help and documentation provide the manual, instructions, support information, and relevant explanations. Help should remain reachable from major workflows, especially when users are setting up a game, importing data, scoring, or interpreting reports.

Purchases and premium status show available products, current entitlement state, remaining free-use allowances where applicable, restoration status, and upgrade actions. Purchase navigation should not hide existing local data or cause users to lose the task that led to the paywall.

Settings and preferences cover remembered choices such as sorting, search, paste setup, report display, announcements, sample prompts, game defaults, and reset behavior. Settings should expose preferences as reversible workflow aids rather than baseball data.

Announcements appear where applicable to communicate relevant product news, roster availability, support notices, compatibility changes, or purchase information. Announcements should be dismissible and should never block local scorekeeping.

## 4. iPhone Navigation

iPhone navigation should be compact and task-focused. Major areas should be reachable through a tab, menu, or equivalent primary navigation structure that keeps Games, Teams, Paste or roster input, Help, Sharing, Import, Reports, Purchases, and Settings discoverable.

Drill-down navigation should move from broad lists to details and focused workflows. A user should be able to open a game from the game list, open game setup, begin scoring, review a completed game, and return to the prior list context without unexpected resets.

Full-screen focused workflows are appropriate on iPhone when the task requires attention or space, including live scoring, import review, report preview, lineup editing, substitution recording, and paywall review. Full-screen presentation should include clear Done, Cancel, Close, or Back behavior.

Returning to the previous context should restore the user's place where practical. Search text, active filter, selected team, selected game, and report scope should not be lost simply because a detail screen was opened.

Search may appear as a visible search field, toolbar action, or focused search surface. Activating search should make it clear which list is being searched. Clearing search should return the list to the same sort and filter state.

Toolbars on iPhone should prioritize the current task. The most important action should be reachable without crowding; less frequent actions may be grouped in a menu if their labels remain clear. Destructive actions should not be hidden in a way that makes them easy to select accidentally.

Live-scoring access should be direct from ready or in-progress games. If a game is incomplete, the user should be guided to the missing setup step rather than left at a dead end. Resuming scoring should restore the current inning, batter, score, outs, runners, pitcher, and recent play context where practical.

Import may use a focused presentation that guides file selection, validation, review, conflict resolution, and confirmation. Canceling import should return to the previous screen without changing local records unless changes were already explicitly applied.

Reports may use compact navigation with selectable report types, previews, sharing actions, and return paths to the originating game or team. Report scope should remain visible even when only one report panel fits onscreen.

Paywall presentation on iPhone should explain the gated action, current premium status, available products, and restoration option. Dismissing the paywall should return to the action that opened it when possible.

Help access should be available from primary navigation and from relevant workflows. Help should not trap the user away from the game, team, import, report, or scoring context that led to it.

## 5. iPad Navigation

iPad navigation may use a sidebar, split-view, or equivalent wider presentation where appropriate. Persistent lists and detail content should help users browse games, teams, rosters, imports, reports, and help without repeatedly losing context.

Persistent list and detail context should allow a selected game, selected team, selected report, or selected import to remain visible while the user reviews related information. When selection changes, the detail area should identify the new context clearly.

Wider scoring layouts may show more baseball context at once, such as score, inning, batting order, runners, current pitcher, recent plays, and scoring controls. A wider layout should improve speed and clarity without changing scoring meaning.

Side-by-side review is useful when comparing lists to details, import values to current values, report summaries to scorecards, or roster entries to player details. Side-by-side views should still provide focused editing when the task requires confirmation or concentrated input.

Search should be visible or quickly accessible in list-oriented iPad areas. Users should be able to tell whether they are searching games, teams, players, downloaded rosters, imports, or reports.

Toolbars may contain more actions on iPad, but they should remain context-specific. Actions that affect the selected game, team, player, report, or import should be grouped or labeled so users do not apply them to the wrong record.

Sheets and popovers are appropriate for contained choices, such as sort selection, filter selection, pitcher choice, player choice, photo selection, help snippets, or simple settings. Larger workflows such as import review, lineup editing, report preview, and live scoring may use larger surfaces when needed.

Resizing and multitasking should preserve active work. When the app moves between full screen, Split View, Stage Manager, portrait, landscape, narrow widths, and wide windows, the current selection, form state, scoring context, import review, and report scope should remain understandable.

Landscape and portrait adaptation may change how many columns, panels, or controls are visible at once. The available workflows should remain equivalent and no core capability should disappear solely because of orientation.

Returning to prior selections should be predictable. If a user opens a player from a team roster, switches to another area, and returns, ScoreKeep should restore the selected team and list context where practical unless the record no longer exists.

All core capabilities available on iPhone should have equivalent access on iPad, including game creation, scoring, correction, team and player management, paste, import, export, reports, help, purchases, settings, and announcements.

## 6. Adaptive Layout Behavior

ScoreKeep should adapt to iPhone and iPad without changing baseball records. A device-specific layout may alter navigation, density, panel count, and control placement, but it must preserve the same game, team, player, lineup, scoring, import, report, and purchase meanings.

Portrait and landscape layouts should keep essential controls reachable. On smaller or narrower layouts, less frequent actions may move into menus or focused screens, but the user should still be able to complete the active workflow.

Split View, Stage Manager, narrow windows, and wide windows should preserve active work during resizing. A user should not lose a draft game, partially edited team, lineup selection, import review, report scope, or active scoring state because the window size changes.

Larger text should be supported without hiding critical baseball state. If less information fits onscreen, ScoreKeep should prioritize current game context, essential actions, labels, validation messages, and accessible navigation over decorative presentation.

Keyboard appearance should not hide required fields, Save or Done actions, scoring controls needed to complete the current play, or warnings that determine whether data will change. If space becomes constrained, the active field and relevant action should remain reachable.

External keyboard use should support efficient movement through fields and visible focus. Keyboard interaction should not accidentally trigger destructive actions without explicit confirmation.

Dynamic resizing should never alter baseball data. It should not reorder batting lineups, advance innings, change scores, apply imports, save forms, dismiss unresolved changes, or duplicate records.

The current game, lineup, import review, report scope, and form state should remain understandable after any layout change. If a view must simplify due to size, it should preserve the user's place and provide a clear path back to details.

## 7. Game List and Game Navigation

The game list should show saved games in a way that makes identity and status clear. Visible game identity may include date, home team, visiting team, location, score, completion state, and recent activity where available.

Users should be able to sort and search games. Sorting and searching change only the visible order or subset of games; they do not change game dates, teams, scoring order, status, or statistics.

Game status should distinguish created, configured, ready, in-progress, interrupted, completed, and archived games where those states apply. Users should always be able to distinguish games that are complete from games expected to continue.

Creating a game should lead to a setup workflow that gathers required game identity and rules before scoring. Premium creation limits should be visible when they block or warn about new game creation, and the user's current list context should remain available.

Opening an existing game should take the user to the most appropriate view for that game. A draft game should open setup or editing. A ready game should offer scoring. An in-progress or interrupted game should offer resume. A completed game should open review, reports, or correction options.

Resuming scoring should restore the current baseball context, including score, inning, outs, runners, current batter, next batter, pitcher, batting order context, and recent scoring context where practical.

Reviewing completed games should emphasize recorded results, scorecards, reports, statistics, and corrections. Review should not restart scoring unless the user explicitly chooses a correction or reopen action.

Correcting games should clearly identify that saved scoring data may change. Correction workflows should preserve the original context until the user confirms specific changes.

Deleting games should require confirmation that names the game and explains whether at-bats, pitchers, lineups, and reports derived from that game will no longer be available. The game should remain unchanged if the user cancels.

Sample games should be identifiable as sample data. Users should be able to open, learn from, report on, ignore, or delete sample games without confusing them with manually scored games.

Premium creation limits should never hide existing games. If the user has reached a free creation limit, ScoreKeep may block additional game creation or show an upgrade path, but saved games must remain reviewable, exportable where allowed, and correctable according to product rules.

## 8. Team, Player, and Roster Navigation

The team list should provide access to team creation, team details, roster management, search, sorting, import, paste, and deletion where allowed. Team identity should remain clear even when teams share similar names.

Team detail should show the team's visible information and provide a clear path to its roster. Team-level edits should affect the team record only after valid changes are saved or confirmed.

The player list should show players within the current team context where applicable, including active and inactive status. Users should be able to search and sort players by visible fields such as name, number, position, or roster status when supported.

Player detail should show and edit player identity, number, position, batting-related information, photo where supported, active status, and related roster context. Editing a player should not silently change historical scoring records unless a specific product rule makes that effect visible.

Roster editing should manage the team-level pool of available players. It is separate from game-specific lineup editing, which determines who bats or participates in a particular game. Users should not need to infer whether they are changing a roster or a game lineup.

Active and inactive players should be distinguishable. Removing a player from active use should differ from deleting the player record. Inactive players should remain discoverable through visible filters or roster views when their historical participation matters.

Adding players should allow manual entry, roster paste, import, or download paths where supported. The chosen path should lead back to the originating team when practical.

Deletion protection should prevent accidental loss of players or teams that are used in historical games when product rules require preservation. If deletion is blocked, ScoreKeep should explain why and provide a safe alternative such as making the player inactive.

Roster paste should show the selected team, parsed rows, field mappings, invalid rows, duplicates, replacements, and skipped records before applying changes. Applying paste changes should be explicit.

Importing and downloading rosters should lead through validation and review before local team or player records are changed. Users should understand whether records will be added, updated, skipped, merged, or replaced.

Returning from player detail, roster paste, import, or download review should preserve the same team and list context where practical, including search, sort, filter, and scroll position when supported.

## 9. Game Setup and Lineup Navigation

Creating or editing game details should let the user review the game date, location, teams, notes or highlights where supported, inning count, lineup mode, and other visible game rules before scoring begins.

Selecting teams should clearly distinguish home and visiting teams. ScoreKeep should not silently guess a matchup when the wrong choice could cause the user to score the wrong game.

Reviewing rosters should help the user confirm that the selected teams have the needed players. Missing players should lead to roster management, paste, import, or download workflows without losing the draft game.

Selecting game rules should be visible before lineups are treated as ready. Rules that affect batting order, number of innings, or who participates should be reviewable and changeable before scoring starts.

Preparing lineups should identify the team being edited, eligible players, batting order, inactive players, substitutions where relevant, and any missing or duplicated batting positions. Lineup work should remain distinct from editing the team's permanent roster.

Choosing pitchers should identify the pitcher, team, starting context, and any missing pitcher information. A game may allow scoring with unresolved pitcher information only if the unresolved state remains visible and correctable.

Reviewing readiness should summarize missing teams, empty rosters, incomplete lineups, missing pitchers, invalid batting order, or other issues that may affect scoring. Warnings should distinguish blocking errors from non-blocking concerns.

Users should be able to return to earlier setup steps without losing completed work. Team choices, rule choices, roster additions, lineup selections, and pitcher choices should remain in the draft setup unless the user explicitly resets or replaces them.

Beginning scoring should require enough setup to preserve coherent baseball state. If preparation is incomplete, ScoreKeep should explain what is missing and offer direct paths to fix it or continue when product rules allow.

Draft setup should be preserved across ordinary navigation, temporary interruptions, and device resizing where practical. Canceling a draft should require confirmation when meaningful setup work would be lost.

## 10. Live Scorekeeping Interface

The live scorekeeping interface should keep essential baseball state visible: home and visiting teams, the team at bat, current inning and half inning, outs, score, current batter, next batter, batting order context, base runners, current pitcher, recent scoring context, and any incomplete or uncertain scoring state.

The current game identity should be clear enough that a user can confirm they are scoring the correct matchup. The team at bat and half inning should be visually and textually understandable without relying only on color.

Opening a plate appearance should be fast and direct from the current batter context. The user should not need to navigate away from live scoring to begin ordinary scoring for the next batter.

Recording a result should present supported outcomes clearly. Common results should be easy to reach, and less common outcomes should remain available without crowding the primary scoring path.

Completing a play should allow the user to confirm or adjust batter result, bases reached, outs, runs, RBIs, stolen bases, earned-run status where applicable, base-runner movement, and end-of-inning state before the record is treated as complete.

Moving to the next batter should happen only after the current play is coherent or the user explicitly accepts an unresolved state. If the next batter is uncertain, ScoreKeep should show the uncertainty rather than silently choosing a hidden result.

Changing pitchers should be reachable during live scoring. The workflow should identify the outgoing and incoming pitchers, team, inning, outs, and batter context where relevant.

Recording substitutions should identify replaced and incoming players, team, batting order impact, and effective context. Substitutions should not silently delete unrelated roster or scoring data.

Correcting prior plays should be available from live scoring or review when product rules allow. Corrections should make clear which play is being changed and should update dependent visible state coherently after confirmation.

Pausing or leaving scoring should preserve the current scoring context. If a plate appearance or correction is incomplete, ScoreKeep should either preserve the draft, ask before discarding it, or require completion before leaving.

Resuming later should return to a coherent live-scoring state with the saved score, inning, outs, runners, current batter, current pitcher, batting order, and recent play context where practical.

Live scoring should prioritize speed and clarity over decorative presentation. Visual styling should never make scoring actions harder to find, reduce contrast for critical state, or interrupt play with unnecessary confirmations.

## 11. Forms and Data Entry

Forms used to edit teams, players, games, lineups, pitchers, substitutions, scoring events, paste mappings, imports, and settings should use clear labels that describe the visible field or choice. Required and optional fields should be distinguishable before the user attempts to save.

Validation timing should fit the task. Immediate validation is appropriate for obviously invalid values such as empty required names, invalid numbers, duplicate batting positions, or unsupported file choices. Final validation should also occur before Save, Done, Apply, Import, or Start Scoring.

Keyboard behavior should keep the active field, validation message, and completion action reachable. Entered text should remain intact when the keyboard appears, disappears, or the device size changes.

Done should complete the focused task when valid. Cancel should abandon uncommitted changes only after warning when meaningful work would be lost. Save should commit valid changes. Close should dismiss read-only or already preserved content.

Selection controls should show the current choice and the available alternatives. Team, player, pitcher, lineup, report, import, and settings selections should not silently change other records without visible review.

Numeric entry should accept only meaningful values for the field. Jersey numbers, batting order, innings, outs, runs, RBIs, stolen bases, and other numeric fields should show validation feedback when values are missing, out of range, duplicated, or inconsistent.

Date entry should make the selected date clear and editable. Changing a game date should not change scoring records unless the user saves the game edit according to product rules.

Photos and logos should allow selection, preview, replacement, and removal where supported. Removing an image should be a visible choice and should not delete the team or player.

Unsaved-change handling should protect meaningful work. If the user edits a form and attempts to leave, ScoreKeep should ask whether to save, discard, or continue editing when those choices apply.

Forms should avoid accidental dismissal. Gestures, outside taps, navigation changes, incoming prompts, and layout changes should not silently save incomplete or invalid destructive changes.

## 12. Keyboard and Focus Behavior

The keyboard should appear when text entry is active and should dismiss through clear user actions such as Done, field completion, navigation, or tapping an appropriate non-entry area when no work would be lost.

Users should be able to move between fields in a predictable order. The focus order should match the visible form order and should not skip required fields or jump to unrelated controls.

Done controls should finish entry for the current field or form according to context. On compact screens, Done should not obscure the form-level Save, Apply, or Cancel choices.

iPhone compact input should keep the active field and the next meaningful action visible. If the keyboard covers required controls, the layout should move or provide a reachable completion path.

iPad field navigation should support efficient editing across larger forms. Visible focus should make it clear which field will receive typing or external keyboard input.

External keyboard use should support field movement, text editing, search entry, and selection where appropriate. Destructive actions should still require explicit confirmation and should not be triggered by ordinary typing.

Select-all behavior is useful for fields that users commonly replace entirely, such as search text, pasted roster text, file names, player numbers, and simple labels. Select-all should not cause accidental deletion without the user editing or confirming the change.

Controls required to complete scoring, save a form, apply an import, or resolve a warning should not be covered by the keyboard. If a keyboard toolbar is present, it should not obscure scoring controls or validation messages.

Entered text should be preserved during layout changes, keyboard dismissal, device rotation, Split View resizing, and temporary navigation unless the user explicitly cancels or discards it.

## 13. Sheets, Dialogs, Popovers, and Full-Screen Workflows

Presentation style should match the user's task. Small choices may use compact presentation, focused edits may use sheets, contextual choices may use popovers on larger devices, and tasks requiring sustained attention may use full-screen workflows.

Scoring a plate appearance may use a focused workflow so the user can record the result, base movement, outs, runs, and special scoring details without losing sight of the game context.

Editing a lineup, recording a substitution, and selecting a pitcher should clearly identify the game, team, current inning or batting context when relevant, and the effect of the choice.

Import review and conflict resolution should provide enough space to compare current and incoming values, identify skipped or invalid records, and confirm the final effect before applying changes.

The paywall should explain the gated action, premium status, available upgrade or restore actions, and how dismissal returns to the originating workflow. It should not erase prepared game, import, export, report, or scoring context.

Reports and help may use focused presentation when the user needs to read, preview, share, or return to a workflow. Closing a report or help surface should return to the originating area where practical.

Photo or logo selection should identify whether the image applies to a team or player. Canceling selection should leave the existing image unchanged.

Destructive confirmation should use a clear dialog or equivalent focused presentation that names the action, affected records, consequences, and safe cancellation path.

Every focused presentation should provide clear dismissal actions. Dismissal should not lose meaningful work without warning, and completing a task should return to the workflow that opened it.

Stacked presentations should remain understandable. ScoreKeep should avoid ambiguous layers where users cannot tell which sheet or dialog owns the current action. When multiple requests occur together, the most urgent user-visible decision should be presented first.

## 14. Toolbars and Actions

Toolbars and action areas should present commands that belong to the current context. Actions should be consistently placed where practical across games, teams, players, imports, reports, and settings.

Add should create a new record or begin a new workflow within the current area. Edit should modify the selected record. Delete should remove or mark a record according to product rules and should always be distinguished from ordinary actions.

Search, Sort, and Filter should affect only the visible list or report results. Their active state should be clear enough that users understand why records appear or disappear.

Share, Import, Export, Reports, and PDF actions should identify the source record or scope before work begins or before output is generated. They should preserve context after completion or cancellation.

Lineup, Pitcher, and Substitution actions should be available where those game workflows are relevant. They should identify the current game and team context before changing participation.

Settings, Help, and Premium upgrade actions should be reachable without displacing the user's active work. Returning from them should restore the originating context when practical.

Toolbar labels, icons, or accessibility names should be clear. Icon-only actions should have meaningful accessible names and should not rely solely on visual recognition.

Duplicate conflicting actions should be avoided. If the same command appears in more than one place, each instance should have the same meaning and operate on the same visible context.

Disabled actions should be explained when necessary, especially when a game is not ready, a selection is missing, a premium limit applies, a file is unavailable, or validation is incomplete.

After an action completes, the current context should be preserved where practical. Creating a player should return to the relevant roster, generating a report should return to the selected scope, and dismissing a paywall should return to the attempted action.

## 15. Search, Sorting, and Filtering

Search activation should make the search scope clear. Users should know whether they are searching games, teams, players, rosters, downloaded rosters, imports, reports, or help.

Clearing search should be direct and visible. Clearing search should restore all records allowed by the active sort and filters without altering underlying baseball data.

Sort selection should show the current sort and available sort choices. Changing sort changes only presentation order unless the user is explicitly editing a baseball order such as a lineup.

Filter selection should show the current filter state. Active filters should be indicated when they hide archived games, inactive players, completed games, downloaded rosters, invalid import rows, or other records.

Empty results should explain whether the list is empty because there are no records or because search or filters hide matching records. Users should be able to clear search or adjust filters from the empty state.

Archived, inactive, completed, or hidden records should remain discoverable through visible filter controls when product rules allow them to be viewed.

Returning from detail screens should restore the prior search, sort, and filter context where practical. A user who opens a searched player or filtered game should not return to an unrelated list state.

Device-specific presentation may differ. iPhone may use compact search and filter surfaces, while iPad may keep search and filters visible near persistent lists. Applying the same search, sort, and filter should produce equivalent results on the same data.

Search, sorting, and filtering must never alter underlying baseball data. They should not change batting order, statistics, scoring sequence, team membership, game status, import decisions, or purchase state.

## 16. Status, Feedback, and Progress

ScoreKeep should provide honest status for saving, importing, exporting, downloading, purchasing, generating reports, creating PDFs, applying corrections, completing a game, failed operations, offline states, warnings, and success confirmations.

Saving feedback should indicate whether the change was saved, could not be saved, or remains pending. ScoreKeep should not show success before the meaningful user-facing change is complete.

Importing and downloading should show progress when work takes noticeable time. Validation failures, skipped records, conflicts, unavailable network, canceled operations, and applied changes should be distinguishable.

Exporting, sharing, report generation, and PDF creation should identify the selected scope and show whether output was created, canceled, shared, saved, or failed. A failed export should leave source records unchanged.

Purchasing feedback should distinguish loading products, unavailable products, purchase in progress, purchase success, restoration success, cancellation, failure, and current premium status. No false premium success should be shown.

Applying corrections should identify whether saved game data changed. If a correction fails, the user should know whether the prior record remains unchanged or whether partial work needs review.

Completing a game should show completion state clearly and should distinguish completion from simply leaving the scoring screen. If a game is expected to continue, it should not appear completed.

Failed operations should provide a clear retry path when retry is meaningful. Offline states should explain which actions require connection and which local workflows remain available.

Warnings should be specific and proportional. Live scoring should avoid unnecessary blocking; however, warnings about losing work, deleting records, applying imports, or changing completed scoring should remain clear.

Success confirmations should be brief and should not interrupt live scoring unless the user needs to know that baseball data changed or a workflow completed.

## 17. Empty States and First Use

When there are no games, ScoreKeep should explain the next useful action, such as creating a game, opening sample data, importing a game, or reading help. The empty state should not block access to help, import, purchases, or settings.

When there are no teams, ScoreKeep should guide the user to create a team, paste a roster, import players, download a roster where supported, or use help. A missing team state should not imply that existing games are gone.

An empty team roster should explain how to add players manually, paste players, import players, or download a roster. It should distinguish an empty roster from a filtered roster that hides inactive players.

When there are no reports, ScoreKeep should explain what records are needed to generate reports, such as a selected game, completed scoring, or available team data. It should not create sample reports without user intent.

When there are no downloaded rosters, ScoreKeep should explain whether no roster source is available, the network is unavailable, premium limits apply, or the list is filtered.

No search results should offer clearing search or adjusting filters. It should not suggest creating duplicate records unless the user explicitly wants to add a new record.

When no premium product is available, the premium area should explain that products cannot currently be loaded and should offer retry or restore where appropriate. Existing local data should remain accessible.

When there is no Internet connection, ScoreKeep should identify online-only actions that are unavailable while preserving local scoring, review, roster editing, reports from local data, and help that is bundled locally.

When sample data is available, it should be clearly labeled as sample data and offered as a learning aid. Sample data should not be imported repeatedly or confused with user-created games.

## 18. Destructive Actions and Confirmations

Deleting games, deleting teams, deleting players, removing players from rosters, replacing lineups, deleting scoring events, resetting scoring placeholders, replacing roster data, applying imports, resetting preferences, and canceling incomplete work require clear user intent when meaningful data could change or be lost.

Confirmations should explain what will change. A game deletion should identify the game. A team deletion should identify the team. A roster replacement should identify the team and whether existing players will be added, updated, removed, or left unchanged.

Confirmations should explain what will remain. Removing a player from active roster use may preserve historical scoring records. Resetting preferences should not delete teams, players, games, imports, reports, purchases, or local baseball records.

Confirmations should explain whether historical records are affected. If a player, team, lineup, pitcher, substitution, or scoring event appears in saved games, ScoreKeep should make the historical effect clear or block the destructive action according to product rules.

Confirmations should explain whether the action can be canceled safely. Before the destructive action is applied, Cancel should leave the prior data unchanged. After an action is applied, ScoreKeep should not imply undo is available unless it truly is.

Replacing lineups should warn if scoring events, placeholder at-bats, substitutions, pitcher context, or batting order records may change. The user should be able to review before replacement.

Deleting scoring events or applying corrections should identify the affected play, inning, batter, and dependent score or runner changes where practical.

Applying imports should require confirmation after review when records will be created, updated, merged, replaced, skipped, or deleted. Import confirmation should not be hidden behind a generic Done action.

Canceling incomplete work should ask when meaningful draft data would be lost, including forms, draft game setup, lineup preparation, paste mappings, import review, report configuration, and incomplete scoring events.

## 19. Accessibility and Inclusive Interaction

Interactive controls should have meaningful VoiceOver labels and accessible names. Labels should describe the action or state, such as add player, start scoring, current batter, visiting score, delete game, restore purchases, or clear search.

The interface should support larger text without hiding critical baseball state or required actions. When space is constrained, ScoreKeep should prioritize readable labels, current scoring context, validation messages, and completion controls.

Contrast should be sufficient for ordinary and critical states. Outs, inning, score, base runners, team at bat, disabled actions, destructive actions, warnings, and premium status should remain legible.

Reduced motion settings should be respected. Navigation and status changes should remain understandable without relying on animation.

State should not rely only on color. Current team at bat, active filters, invalid fields, destructive actions, selected players, base occupancy, and completed versus in-progress games should also use text, labels, shape, position, or other non-color indicators.

Controls should be reachable for one-handed use where practical on iPhone and should remain reachable under larger text and keyboard conditions. Critical live-scoring actions should not require precise gestures without accessible alternatives.

Focus order should be clear and meaningful. VoiceOver and keyboard focus should move through navigation, lists, forms, scoring controls, dialogs, and reports in an order that matches the visible task.

Button names should be specific. Generic labels such as OK should be avoided when a specific action such as Save Game, Apply Import, Delete Player, Start Scoring, or Keep Editing would better describe the result.

Accessible scoring state should include inning, half inning, outs, score, current batter, runners, current pitcher, and unresolved state. Users should be able to score live play under accessibility settings without losing speed or clarity.

Reports and confirmations should be accessible. Tables, summaries, generated previews, destructive confirmations, and import conflict reviews should expose meaningful labels and reading order.

Dynamic accessibility changes should be handled during active work. If the user changes text size, contrast, motion, or other accessibility settings, ScoreKeep should preserve the current workflow and adapt without changing baseball data.

## 20. Navigation State Preservation

ScoreKeep should preserve selected primary area, selected team, selected game, search and sort context, report scope, import review, draft lineup, partially completed forms, in-progress scoring, current scoring context, and recent play context where practical.

Across ordinary navigation, returning to a prior area should restore the user's recent context unless doing so would show invalid or deleted content. A user who moves from a team roster to help and back should generally return to the same team roster.

Across app backgrounding, meaningful active work should remain recoverable. In-progress scoring, draft game setup, lineup preparation, import review, and partially completed forms should not be silently discarded because the app was interrupted.

Across device resizing, rotation, Split View changes, or Stage Manager changes, ScoreKeep should preserve the active record, selected area, form text, scoring state, report scope, and import decisions.

State that may safely reset includes temporary menus, transient visual highlights, completed success messages, dismissed noncritical progress indicators, and short-lived search text in workflows where persistence would be confusing. Resetting these states should not change baseball records.

If preserved state points to a record that no longer exists, ScoreKeep should recover visibly. It may return to the nearest valid list, show that the selected record is unavailable, and preserve other valid context such as the primary area or search where appropriate.

Paywalls should preserve originating workflow state. If a user attempts a gated action, opens the paywall, and cancels or completes purchase, ScoreKeep should return to the game, roster, import, export, report, or download action that led there when practical.

Recent play context should remain available enough to help users resume scoring confidently after leaving and returning. This includes the last recorded play, current batter, next batter, score, inning, outs, runners, and pitcher context where practical.

## 21. Validation Requirements

If a navigation destination is missing, ScoreKeep should show a safe message and provide a route back to a relevant list or primary area. It should not leave the user on a blank or broken screen without explanation.

If a deep link targets unavailable content, ScoreKeep should explain that the target cannot be opened and offer a nearby valid destination, such as games, teams, import, sharing, or help.

If a selected game is unavailable, deleted, invalid, or no longer matches the active workflow, ScoreKeep should return to the game list or show a recoverable unavailable state. It should not create a duplicate game as a side effect of navigation.

If a selected team is deleted or unavailable, roster and player workflows should show a clear recovery path to the team list. Partially completed work should be preserved only when it can still be meaningfully applied.

Invalid sheet state should be recoverable. If a sheet lacks its required game, team, player, import, report, or purchase context, ScoreKeep should dismiss or replace it with a visible recovery message rather than allowing meaningless actions.

Duplicate modal presentation should not duplicate actions or records. If two requests attempt to open the same workflow, ScoreKeep should present one clear workflow or queue the later request visibly.

An active workflow should not be hidden behind another view without a return path. If scoring, import review, lineup editing, or purchase confirmation is active, the user should be able to return, complete, or cancel it intentionally.

Unreachable actions should be disabled or explained. If an action cannot run because a selection is missing, validation failed, a premium limit applies, a file is unavailable, or the device is offline, ScoreKeep should say what is needed.

Keyboard coverage of required controls should be detected from the user's perspective. If the user cannot reach Save, Done, Apply, Start Scoring, or a required field, the layout should provide a visible path to reach it.

Unsupported window sizes should show a usable reduced layout or a clear explanation of what size is needed. Unsupported size handling should not alter data or dismiss work.

Inconsistent selected tab, sidebar, or primary area state should recover to a valid selection. The user should not see a detail screen that does not match the active primary area without explanation.

Attempting to dismiss meaningful unsaved work should trigger save, discard, or continue-editing choices where appropriate.

Attempting to open a gated feature should preserve context. The paywall should identify the gated action and return to the originating workflow without losing prepared work.

## 22. Data Integrity Requirements

Navigation never changes baseball data by itself. Moving between lists, details, sheets, reports, help, settings, and purchases should not create, modify, delete, or duplicate records unless the user performs a confirming action.

Layout changes never alter records. Rotation, resizing, larger text, Split View, Stage Manager, keyboard appearance, and device-specific presentation must not change teams, players, games, lineups, at-bats, pitchers, substitutions, reports, imports, purchases, or preferences except for intentional view preferences.

Dismissing a screen never silently discards meaningful work. Drafts, form edits, lineup work, import review, paste mappings, report configuration, and incomplete scoring events should be saved, preserved, or explicitly discarded according to visible user choice.

Returning from detail preserves list context where practical. Search, sort, filters, selected team, selected game, selected player, and scroll context should not be lost without reason.

Live-scoring state remains coherent during navigation. Leaving and returning should not advance batters, change innings, alter outs, move runners, change pitchers, or complete a play without explicit user action.

Duplicate presentations do not duplicate actions or records. Opening a creation, import, paste, scoring, purchase, or report workflow more than once should not create duplicate games, players, imports, scoring events, purchases, or generated records.

Paywalls preserve the originating workflow. A premium prompt should not erase a draft game, download selection, import review, export scope, report setup, or live-scoring context.

Search and sort never change batting order or statistics. They affect visible presentation only unless the user is in a clearly identified editing workflow for baseball order.

Forms either save coherently or leave prior data unchanged. Invalid, incomplete, canceled, or failed forms should not partially apply destructive changes without visible explanation.

Destructive actions require explicit intent. Deleting, replacing, resetting, applying imports, and discarding meaningful work should not happen through accidental navigation or ambiguous dismissal.

Accessibility adaptation never changes baseball meaning. Larger text, VoiceOver, contrast changes, reduced motion, and focus changes should preserve records and scoring state.

Device changes never create duplicate games, players, imports, or scoring events. Backgrounding, reopening, rotating, resizing, or switching windows should restore or recover state without unintended duplication.

## 23. Exceptional Situations

If the app backgrounds during scoring, the user should be able to return to the same game context where practical. Incomplete plate appearances should be preserved or clearly marked as incomplete rather than silently completed or discarded.

If the app returns to a different window size, ScoreKeep should adapt the visible layout while preserving the current area, selected record, form state, scoring context, import review, or report scope.

If the device rotates during a form, entered text, selections, validation messages, and unsaved-change state should remain intact. The user should not have to re-enter data because orientation changed.

If the user dismisses a sheet accidentally, ScoreKeep should protect meaningful work. It should restore the sheet, keep the draft available, or ask before discarding when the task involved scoring, form edits, lineups, imports, paste review, or destructive confirmation.

If the keyboard covers a required action, the user should be able to move the content, dismiss the keyboard, or use a visible Done or Save path without losing entry.

If a selected record is deleted elsewhere in the workflow, ScoreKeep should explain that the record is no longer available and return to a valid list or selection. It should preserve unrelated work where possible.

If a deep link targets unavailable content, ScoreKeep should show a recoverable message and provide access to the relevant primary area rather than failing silently.

If a paywall opens during a prepared action, ScoreKeep should preserve the prepared game, roster download, export scope, report setup, or import selection. After dismissal or purchase, the user should be returned to the prepared action where practical.

If import review is interrupted, the user should be able to resume review or restart safely. Local data should not change unless the user already confirmed applying changes.

If report generation is interrupted, ScoreKeep should explain whether the report was generated, canceled, or failed. The source game, team, player, and statistics should remain unchanged.

If the user changes accessibility settings, the interface should adapt while preserving active work. Live scoring should remain usable and current baseball state should remain clear.

If navigation state becomes invalid, ScoreKeep should recover to a valid primary area, explain unavailable content when useful, and avoid creating replacement records automatically.

If the user returns after device restart, ScoreKeep should restore saved records and recover in-progress scoring or drafts where practical. Unsaved transient choices may reset only when baseball data is unchanged and the user can continue safely.

If multiple modal requests occur together, ScoreKeep should present a single clear next decision or workflow. Destructive confirmations, paywalls, import conflicts, scoring sheets, and system choices should not overlap in a way that obscures which action will occur.

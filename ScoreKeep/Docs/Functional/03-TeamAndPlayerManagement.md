# ScoreKeep Functional Specification

## 03. Team and Player Management

## 1. Overview

Teams and players are reusable records that support the scorekeeping workflow before, during, and after games. They let users prepare rosters in advance, select teams quickly when creating games, build lineups, identify batters and pitchers during live scoring, produce meaningful reports, and share roster information with other ScoreKeep users.

Teams and players exist independently of games because the same team and roster may be used repeatedly across a season, across multiple games, and across imported or shared records. A user should not need to recreate a team for every game, and routine roster maintenance should remain separate from live scoring. This separation also protects historical games: a player can change number or position in the future without making earlier scorecards confusing or inaccurate.

The product should preserve established ScoreKeep workflows for creating teams, adding players, editing roster details, pasting or importing roster data, downloading compatible roster files, sharing rosters, and using teams in games. The rewritten application should make those workflows more reliable by clarifying validation, avoiding accidental merges, protecting historical games, and giving users understandable choices when imported or edited data conflicts with existing records.

## 2. Team Lifecycle

A team begins when the user creates it manually, imports it from a compatible roster file, downloads it from a supported roster source, or accepts it as part of an imported game. The team should have enough identifying information for the user to recognize it in lists, game setup, reports, and sharing workflows. Creation should be lightweight, but the application should warn when the new team appears to duplicate an existing team.

After creation, the user may edit team information such as name, coach, logo, notes, or other descriptive details. Ordinary Team add and edit forms use explicit Save behavior with visible field affordances for Team Name, Coach, and multiline Details. Standard iPad Add Team routes present the shared form in a sheet-style presentation, while iPhone keeps the pushed compact route. Edits should be saved intentionally and should not silently alter unrelated teams. If the team has already appeared in games, the application should make clear when a change affects future display and when historical game records are preserved.

The team roster is maintained over time. Users can add players, edit player details, remove players from the active roster, mark players inactive when appropriate, and resolve duplicates. Roster maintenance should support pregame preparation as well as mid-season changes. The application should let users add a missing player quickly when discovered shortly before a game without forcing them through unnecessary setup.

A team becomes active in the game workflow when it is selected as a home or visiting team. Once used in a game, the team is part of that game's historical record. Later team edits should not damage prior games, lineups, scorecards, statistics, or reports.

Teams can be shared through compatible ScoreKeep roster workflows. Sharing a team should create a portable roster record that another user can import while preserving meaningful team and player information. Sharing should not modify the local team.

Teams can be imported from compatible ScoreKeep roster or game files. Importing should identify possible matches, show conflicts, and let the user confirm whether to create a new team, update an existing team, or skip the import. Imported data should not silently overwrite local information.

Long-term maintenance should support teams across seasons. Users may keep a team and update its roster, rename it for a new season, duplicate or branch it when they need a separate seasonal record, or archive older information when supported. The product should help users avoid mixing unrelated teams that happen to share a name.

Deleting a team is destructive and must require confirmation. If the team is referenced by games, the application should protect those games. The user should be told why deletion is blocked, limited, or converted into an archival or inactive state. Deleting a team must not silently delete historical games or unrelated player records.

## 3. Player Lifecycle

A player begins when the user adds the player manually, imports the player from a compatible roster file, downloads a roster containing the player, accepts the player as part of an imported game, or creates the player during pregame preparation. The player record should represent the person or roster entry that can be reused across games.

The user may edit player information over time, including name, jersey number, position, batting information, photo, and team membership. Ordinary roster add and edit screens use draft state and explicit Save before creating or changing the persisted player. Clean Back exits immediately; Back with meaningful unsaved changes requires a discard-or-keep-editing choice for new players and a save, discard, or keep-editing choice for existing players. Edits should be straightforward for routine corrections and seasonal updates. When a player has appeared in games, the application should preserve the meaning of prior game participation even if the player record changes later.

Assigning a player to a team makes the player available for that team's roster, lineup preparation, scorekeeping, pitching selection, substitutions, reports, and sharing. A player may be active on the roster, inactive for current participation, or temporarily available for a specific game depending on product-supported workflow.

A player record is different from a player's participation in an individual game. The player record describes reusable identity and roster information. Game participation describes how that player was used in a specific game: batting order, whether the player appeared in the lineup, pitcher participation, substitutions, scoring events, and game-specific results. Changing a player record should not retroactively rewrite game-specific participation unless the user is explicitly correcting that historical game.

Players can be shared as part of team roster sharing and can be imported from compatible files. Import should detect likely duplicates, preserve user choice, and avoid silent merging when two players share a name or number.

Deleting a player is destructive and must require confirmation. If the player is referenced by games, scorecards, pitching records, substitutions, or reports, the application should protect those historical records. The preferred behavior should be to prevent deletion, mark the player inactive, or remove the player from future roster use while preserving past games.

## 4. Team Requirements

A team must have a clear identity that lets the user distinguish it from other teams. The team name is the primary user-visible identifier and should be required before the team is used in a game. Blank or placeholder team names should not be allowed to move into live scoring without correction.

Team coach information, logos, and notes are optional descriptive details. They help users organize teams and make reports or roster lists easier to recognize. Optional details should never block scoring unless a future product rule explicitly requires them.

Team organization should support browsing, searching, sorting, and selecting teams for games. Users should be able to find teams quickly even when they have accumulated many teams across seasons. The application should make active or recently used teams easy to identify without hiding older teams.

Team uniqueness should be based on more than a name alone when practical from the user's perspective. Two legitimate teams may share the same name, especially across seasons, divisions, towns, or imported files. The application should warn about likely duplicates but allow the user to keep separate teams when they are genuinely different.

Teams should be reusable across seasons while still supporting seasonal differences. A user may continue using the same team record when the team is meaningfully the same, or create a separate seasonal team when roster, name, coach, or historical tracking needs differ. The product should make either choice understandable.

## 5. Player Requirements

A player record must have enough identity for the user to recognize the player in rosters, lineups, scoring screens, pitcher selection, substitutions, and reports. A player name should be required before the player is used in a game. The application should allow common baseball roster realities such as shared last names, temporary nicknames, unknown first names, and duplicate jersey numbers when confirmed by the user.

Jersey number, position, batting information, and photo are roster-level details. They describe the player generally and help with lineup preparation and scorekeeping. These details may change over time and should be editable without corrupting earlier game records.

Team membership describes where the player belongs for roster and lineup purposes. A player may move teams, return after absence, or be temporarily added for a game. The product should make it clear whether the user is changing a reusable roster record or only adjusting participation in a specific game.

Active versus inactive participation should distinguish players who remain known to the team from players currently available for games. An inactive player should be retained for history and possible future use, but should not clutter normal lineup selection unless the user chooses to include inactive players.

Long-term player history should protect scored games, reports, and statistics. Renaming a player, changing a number, updating a position, or replacing a photo should not make past games ambiguous. Information that describes what happened in a specific game belongs to that game, including lineup order, substitution role, pitcher use, at-bat results, bases, outs, RBIs, stolen bases, and earned-run decisions.

## 6. Roster Management

Users should be able to add players from the team roster view, during pregame preparation, substitution preparation, and from supported import or paste workflows. Ordinary Team to Players roster add uses the shared player draft form for name, number, position, batting direction, batting order, team association, and photo selection or paste, and it creates no placeholder player before Save. Standard iPad Add Player uses the same sheet-style presentation language as standard iPad Add Team, while iPhone keeps the pushed compact roster route. The substitution screen should use that toolbar Add Player route instead of an inline quick-entry row. Adding a player should require only the information necessary to identify and use the player, with optional details available when the user has time.

Removing a player from a roster should be different from deleting the player's historical identity. If a player no longer participates, the user should be able to remove the player from active roster use or mark the player inactive without damaging games where that player appeared.

Editing players should be available from roster and preparation workflows. Users should be able to correct misspellings, numbers, positions, batting details, and photos. If an edit affects a player with game history, the application should preserve historical meaning and warn when the change may make older games harder to interpret.

Roster sorting should support common user expectations such as name, number, batting order, position, and active status where applicable. Searching should work well for large rosters and should help users find players by name or other visible roster details.

Large rosters should remain usable. Lists should be scannable, search should be responsive, and lineup preparation should not require scrolling through irrelevant inactive players unless the user chooses to include them.

Temporary players should be supported for realistic game-day situations. A user may need to add a substitute, call-up, guest player, or unknown player shortly before or during a game. The application should allow fast entry while encouraging the user to resolve incomplete details later.

When a missing player is discovered before a game, the user should be able to add the player without losing the current game setup. The new player should become available for lineup selection immediately after saving.

Duplicate players require careful handling. The application should warn when a new or imported player appears to match an existing player on the same team or in the same import context. The user should be able to merge only when they are confident the records represent the same person, keep both when they are different people, or skip an imported duplicate.

## 7. Team and Player Validation

Validation should help users catch mistakes without blocking legitimate baseball scenarios.

Duplicate teams should be detected when names and surrounding context suggest the same team already exists. The application should show enough information for the user to decide whether to use the existing team, create a separate team, rename the incoming team, or cancel.

Duplicate players should be detected within a team and during import. A likely duplicate may share a name, number, or imported identity with an existing player, but the application must not assume that matching names or numbers always represent the same person. Users should be given clear choices before records are merged or overwritten.

Missing required information should be caught before the affected record is used in a game. A team needs a usable team name. A player needs a usable player name. Optional details such as coach, notes, logo, photo, position, jersey number, and batting information should not block ordinary use unless they are needed for a selected workflow.

Invalid roster situations should be explained in baseball terms. Examples include a game team with no available players, a lineup that does not contain enough players for the selected game rules, duplicate batting-order positions, or players marked unavailable who are still selected for the lineup.

Conflicting information should be resolved with user confirmation. If an imported player has a different number or position than an existing player, the application should show the conflict and ask whether to keep current information, apply imported information, create a separate player, or skip the conflict.

Imported data conflicts should never be resolved by silent destructive changes. The user should be told what will be added, updated, skipped, or left unresolved before the import changes local records. If the application cannot safely decide, it should preserve local data and ask the user.

## 8. Team and Player History

Historical games should remain understandable even when team and player information changes later. A scorecard from an earlier game should still communicate who played, which teams played, and what happened in that game.

Renamed teams should not make prior games appear to have been played by a different team unless the user intentionally updates historical display. If a team changes its name for a future season, the application should help the user decide whether to rename the reusable team or create a separate team record for the new season.

Renamed players should preserve prior participation. Correcting a spelling mistake may reasonably improve historical display, but changing a player's name because a different person now occupies the roster spot should not overwrite older games.

Jersey number changes should be treated as time-sensitive roster information. A player may wear one number in an earlier game and another later. Historical games should remain clear about the number used at the time when that information is available or relevant.

Position changes should support both general roster updates and game-specific roles. A player's usual position may change during a season, but game reports and scorecards should reflect the role recorded for the game when that distinction matters.

Team logo changes should affect future identity and presentation without destroying historical clarity. If a historical report uses a logo, the user should not be surprised by old games appearing with an unrelated future logo when the product can preserve or explain the difference.

Reused jersey numbers are common and must be supported. A number may belong to different players across seasons or even within large organizations. The application must not treat a shared number as proof that two player records are the same person.

## 9. Import and Export Expectations

ScoreKeep must continue to support compatible roster and game files created by previous versions where the data can be safely understood. Existing ScoreKeep roster files should remain importable, and exported roster files should remain useful for sharing teams and players with other ScoreKeep users.

Import should begin with validation. The application should confirm that the selected file appears to be a compatible ScoreKeep roster or game file before changing local data. Invalid files should be rejected with a clear explanation and should not partially modify local teams or players.

Conflict resolution should be explicit. When imported teams or players resemble existing records, the application should show likely matches and let the user choose whether to update existing records, create new records, skip records, or preserve current values. The choice should be understandable to non-technical users.

Duplicate detection should account for common real-world ambiguity. Matching team names, player names, or jersey numbers can indicate duplicates, but they can also be legitimate separate records. The application should warn and assist rather than silently merge.

User confirmation is required before imported data overwrites local information, removes local information, changes active rosters, or affects records used by games. Import summaries should describe the expected result before the user commits.

Data preservation is required. Import should retain as much compatible team and player information as possible, including names, roster details, photos, logos, and relevant game participation when importing games. Unsupported or invalid portions should be reported rather than silently discarded when the omission affects user understanding.

Partial imports should be allowed only when safe and clearly explained. If some players import successfully and others fail validation, the user should know which records were imported, skipped, or require attention. The application should avoid leaving a roster in a misleading half-updated state.

Export should be non-destructive. Sharing a roster or game should not change local teams, players, games, lineups, or statistics. Exported records should use established ScoreKeep naming and document workflows so users can continue sending files through familiar sharing paths.

## 10. Data Integrity Requirements

ScoreKeep must protect team and player information throughout creation, editing, import, export, game setup, scoring, and deletion.

- The application must never silently merge unrelated players.
- The application must never silently merge unrelated teams.
- Historical game records must remain protected when roster details change.
- Removing a player from a current roster must not erase that player's past game participation.
- Deleting a team or player must require confirmation and must explain the effect on related records.
- Destructive actions must be limited to the user's intended team, player, roster, or import operation.
- Import operations must preserve existing local information unless the user explicitly chooses to replace it.
- Related information should remain consistent across team lists, rosters, lineups, scoring views, reports, and shared files.
- The application should prevent accidental roster loss during paste, import, bulk update, and deletion workflows.
- Compatible previous ScoreKeep data should remain readable and usable whenever it can be safely interpreted.
- If an operation cannot be completed safely, the application should leave existing local records unchanged or clearly explain what changed.

## 11. Exceptional Situations

**Duplicate imports:** When an imported roster or game contains teams or players that appear to already exist, the application should pause for user confirmation. The user should be able to update existing records, create separate records, skip duplicates, or cancel the import.

**Missing player information:** If a player lacks required identifying information, the application should ask the user to complete the missing information before the player is used in a lineup or game. If the player comes from an import, the user should be able to fix, skip, or keep the record inactive until resolved.

**Missing team information:** If a team lacks a usable name or other required identity, it should not be used for game setup until corrected. Imported records with missing team information should be rejected or held for user repair rather than merged into an unrelated team.

**Corrupted import files:** A file that cannot be read as a compatible ScoreKeep roster or game should not alter local data. The user should receive a clear error and, where possible, guidance to request a new file from the sender.

**Team deletion while referenced by games:** The application should protect referenced games. The user should be prevented from deleting the team outright, offered an archival or inactive option, or shown a clear explanation of what must be done before deletion is allowed.

**Player deletion while referenced by games:** The application should protect scored games, lineups, pitcher participation, substitutions, reports, and scorecards. The expected behavior is to keep historical participation intact and allow the player to be removed only from future roster use unless the user is explicitly correcting a game.

**Empty rosters:** A team may exist with an empty roster while being created or organized, but it should not move into a ready-to-score game state without user confirmation and a clear path to add players. Empty-roster teams should be easy to identify in setup.

**Extremely large rosters:** Large rosters should remain searchable and manageable. The application should avoid workflows that require the user to manually inspect every player before finding the intended one.

**Mid-season roster changes:** Users should be able to add new players, deactivate departed players, update numbers, and change positions during a season. These changes should affect future use while preserving prior games unless the user intentionally edits historical game participation.

**Shared names and reused numbers:** The application should support players with the same name, teams with the same name, and reused jersey numbers. It should warn about ambiguity but allow valid real-world cases after user confirmation.

**Roster replacement by paste or import:** Replacing many players at once can cause accidental data loss. The application should summarize the impact and require confirmation before removing, overwriting, or deactivating existing roster entries.

**Import canceled by user:** Canceling an import before final confirmation should leave all existing local teams and players unchanged. Before applying an import, the user should be able to review the proposed additions, updates, skips, conflicts, and removals. The import should become permanent only after the user confirms the complete operation. If an unexpected failure occurs while applying a confirmed import, ScoreKeep should avoid leaving a misleading partially updated roster. The user should receive a clear result explaining whether the import completed, made no changes, or requires recovery. Existing local records must remain usable and understandable after any failed or canceled import.

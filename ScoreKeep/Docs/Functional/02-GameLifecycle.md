# ScoreKeep Functional Specification

## 02. Game Lifecycle

## 1. Overview

The game lifecycle describes how a baseball game moves through ScoreKeep from initial creation to long-term review, sharing, and archival. A game begins as a planned event with basic identifying information, becomes configured when teams and game options are selected, becomes ready when lineups and pitchers have been reviewed, moves into active scorekeeping when play begins, and ends when the final score and related statistics are available for review.

Each lifecycle stage exists to reduce mistakes and preserve user confidence. Before the first pitch, the application should help the user confirm the right teams, rosters, batting orders, pitchers, and game settings. During live play, the application should prioritize fast scoring, clear correction paths, and durable progress saving. After the game, the application should make scores, statistics, reports, and sharing available without requiring the user to re-enter or reconstruct scoring information.

The lifecycle must preserve compatibility with established ScoreKeep workflows. Users must still be able to create games from teams, prepare lineups, score plate appearances, track pitchers, record substitutions, generate reports, share game files, import compatible game files, and return later to review or correct saved games. The rewritten application should make those workflows more explicit and reliable while continuing to respect existing ScoreKeep data and exported game records.

A game should never depend on Internet access for its core lifecycle. Network-dependent capabilities may enhance sharing, downloads, announcements, or purchases, but creating, preparing, scoring, completing, reopening, reviewing, and locally sharing a game must remain possible using locally available data.

## 2. Lifecycle States

### Created

**Purpose:** Establish a new game record that the user can configure before scoring begins.

**Entry conditions:** The user starts a new game, or a compatible imported game is accepted as a new local game. The game may contain only minimal information at this point.

**Allowed user actions:**

- Enter or update basic game details.
- Select or change home and visiting teams.
- Add a missing home or visiting team from the originating team selector and return with the new team selected for that same role.
- Cancel creation before meaningful game data has been entered.
- Save the game as a draft for later preparation.
- Import additional compatible game information when applicable.

**Exit conditions:** The game has enough identifying information to be saved and distinguished from other games, or the user cancels creation.

**Possible transitions:**

- To Configured when required game details and teams are selected.
- To Archived when an imported completed game is accepted directly for review.
- To discarded draft only after user confirmation when user-entered information would otherwise be lost.

### Configured

**Purpose:** Define the game matchup and settings before lineup and scoring preparation.

**Entry conditions:** The game has the required basic information and valid home and visiting teams.

**Allowed user actions:**

- Change game details before scoring starts.
- Verify team rosters.
- Add or edit players needed for the game.
- Choose game-level settings such as inning count and everyone-hits behavior.
- Start lineup preparation.
- Delete the game after confirmation.

**Exit conditions:** The user confirms the game setup and moves into lineup, pitcher, and pregame review.

**Possible transitions:**

- To Ready to Score when teams, rosters, lineups, and initial pitcher expectations have been reviewed.
- To Created if required information is removed or the matchup becomes incomplete.
- To Archived if the game is imported as an already completed historical game.

### Ready to Score

**Purpose:** Confirm that the game can be scored immediately without hidden setup work during the first plate appearance.

**Entry conditions:** The game has home and visiting teams, usable rosters, valid batting order information, and any initial pitching information required by the user workflow.

**Allowed user actions:**

- Review both teams, batting orders, and pitcher assignments.
- Adjust lineup order before the first scored plate appearance.
- Confirm everyone-hits or traditional lineup rules.
- Return to game configuration when the matchup or settings are wrong.
- Begin scoring.

**Exit conditions:** The user records the first scoring event or explicitly returns to setup.

**Possible transitions:**

- To In Progress when scoring begins.
- To Configured when pregame setup needs changes.
- To Archived only for imported or historical games that should not enter live scoring.

### In Progress

**Purpose:** Support live scorekeeping while the baseball game is actively being played.

**Entry conditions:** The user begins recording plate appearances or resumes a previously started game that has not been completed.

**Allowed user actions:**

- Record plate appearances, results, bases reached, outs, runs, RBIs, stolen bases, earned-run state, and fielding notes.
- Advance innings according to scoring events and user-confirmed inning endings.
- Record pitching changes and pitcher participation.
- Record substitutions and replacement-player relationships.
- Correct previously entered scoring events.
- Generate available in-game views of score and statistics.
- Save and exit without completing the game.
- Mark the game as interrupted, suspended, or complete when appropriate.

**Exit conditions:** The game reaches a final result, the user pauses scoring, the user exits, or an exceptional situation interrupts active use.

**Possible transitions:**

- To Temporarily Interrupted when play or scoring pauses and the game is expected to resume.
- To Completed when the final score and game ending are confirmed.
- To Ready to Score only if all scoring information is removed or the game is intentionally reset after confirmation.
- To Archived after completion and review.

### Temporarily Interrupted

**Purpose:** Preserve game progress when play or scorekeeping stops before the game is complete.

**Entry conditions:** The user exits during scoring, the game is suspended, weather delays play, the app closes unexpectedly, the device restarts, or the user intentionally marks the game as paused.

**Allowed user actions:**

- Resume scoring from the last saved state.
- Review the current score, inning, lineups, pitchers, and last recorded play.
- Add notes about the interruption when supported by the product scope.
- Correct scoring information entered before the interruption.
- Mark the game complete if play officially ends at that point.
- Leave the game saved for later.

**Exit conditions:** The user resumes scoring, marks the game complete, or archives the game as historical/incomplete according to user intent.

**Possible transitions:**

- To In Progress when scoring resumes.
- To Completed when the interrupted game is officially final.
- To Archived when the user chooses to retain the interrupted game for records without further scoring.

### Completed

**Purpose:** Represent a game whose final score and scoring events are available for review, reports, statistics, and sharing.

**Entry conditions:** The user confirms that the game has ended, or an imported game is accepted as complete. The game should have a final score that can be explained by its scoring information.

**Allowed user actions:**

- Review the final score, line score, box score, batting statistics, pitching statistics, and scorecard.
- Generate reports or PDFs when available to the user.
- Share compatible game files and reports.
- Reopen the game for corrections or notes.
- Archive the game for long-term storage.

**Exit conditions:** The user archives the game, reopens it for editing, or leaves it available in the completed game list.

**Possible transitions:**

- To Archived after review or sharing.
- To In Progress or a correction mode when the user reopens the game for scoring changes.
- To Temporarily Interrupted if the user determines the game was not actually final.

### Archived

**Purpose:** Preserve a game as a long-term record while keeping it available for review, reports, export, and future compatibility.

**Entry conditions:** A completed, interrupted, imported, or historical game is retained after active scoring is no longer expected.

**Allowed user actions:**

- View game details, score, statistics, scorecard, and reports.
- Share compatible game files or generated reports.
- Reopen for correction when user permissions and product rules allow.
- Delete only after explicit confirmation.

**Exit conditions:** The game is reopened for correction, exported/shared, or deleted after confirmation.

**Possible transitions:**

- To Completed when an archived game is reopened for post-game review.
- To In Progress or correction mode when scoring information must be changed.
- To deleted only through a confirmed destructive action.

## 3. Typical Workflow

A typical user begins by creating a new game before arriving at the field or shortly before first pitch. The user enters the basic game details, chooses the visiting and home teams, confirms the date and location, and selects the game settings that affect scoring, such as the expected number of innings or whether every player bats.

Next, the user prepares the game. They verify that both teams have the expected players, add missing players if needed, and arrange the batting order for each team. The user identifies starting pitchers when they want pitcher statistics to be tracked from the beginning. Before scoring starts, the user reviews the matchup, lineups, and settings so mistakes can be corrected before the first plate appearance.

When the game starts, the user records each plate appearance from the scoring view. For each batter, the user records the result, base reached, outs, runner advancement, RBIs, stolen bases, earned-run state, and fielding notes as needed. Between plate appearances, the application keeps the visible score, inning, outs, runners, and team batting order understandable enough for the user to continue scoring quickly.

During the game, the user may correct an earlier play, record a substitution, change pitchers, or pause because play is delayed. If the user leaves the application or the device loses power, the game should reopen with the last saved progress intact. The user should not need to remember which play was last recorded because the application should make the resumed state clear.

At the end of the game, the user confirms completion, reviews the final score and statistics, and generates any available reports. The completed game remains available for later review. The user may share a compatible ScoreKeep game file, share a report, or return later to correct a mistake without losing the historical record of the game.

## 4. Creating a Game

### Required Information

A new game requires enough information for the user to identify and score the matchup. At minimum, ScoreKeep should require distinct home and visiting teams, a game date, and a saved game identity that can be distinguished from other games. The application should prevent a game from moving into scoring when the matchup is incomplete or ambiguous.

### Optional Information

Optional information may include location, game notes or highlights, expected inning count, everyone-hits behavior, initial pitcher choices, and other descriptive details that help the user organize or review the game later. Optional information should not block creation unless it is required by a selected game setting.

### Default Values

Defaults should reduce setup time without hiding important assumptions. The game date should default to the current date. Scores should begin at zero. The expected inning count should default to a common baseball value while allowing supported recreational variations. Optional text should begin blank. Team and roster choices should not be silently guessed when doing so could cause the user to score the wrong game.

### Validation Rules

The application should validate that the home and visiting sides are selected, that the selected sides are not accidentally the same team unless the user explicitly confirms a supported practice or intra-squad scenario, and that required game details are usable. It should warn about likely duplicates, such as the same teams on the same date, while allowing legitimate doubleheaders or replayed games when the user confirms intent.

Validation must protect compatibility with existing ScoreKeep data. Imported games may contain historical values, incomplete optional details, or older conventions. The application should accept compatible historical data whenever it can do so without corrupting the user's records, and should explain what cannot be imported or used.

### User Expectations

Creating a game should feel lightweight. Users should be able to create a game quickly and return later to finish preparation. A user who starts creation by mistake should be able to cancel before meaningful data is saved. A user who has entered teams or other details should receive confirmation before that work is discarded.

## 5. Preparing a Game

Preparing a game includes all user-visible work needed before the first scored plate appearance.

**Team selection:** The user selects the home and visiting teams. The application should clearly show which team is home and which is visiting, and should make it difficult to reverse them accidentally. If teams are imported or renamed, the user should still be able to distinguish the intended matchup.

**Roster verification:** The user reviews each team's roster and confirms that needed players are present. Missing players can be added before scoring. Existing players can be edited when details such as name, number, batting direction, position, or photo are wrong. Roster changes made during preparation should not damage other games that used earlier roster information.

**Lineup preparation:** The user creates or reviews batting orders for both teams. The application should support existing ScoreKeep expectations for batting order, everyone-hits behavior, and players who are present but not currently batting. Updating a lineup after scoring data exists is potentially destructive and must be confirmed with a clear explanation of the impact.

**Pitcher preparation:** The user can identify starting pitchers and review pitcher information before scoring begins. If the user chooses not to enter pitcher information before the first pitch, the application should still allow scorekeeping and should provide a clear way to add pitcher information later.

**Optional game settings:** The user reviews settings such as inning count, everyone-hits behavior, and other game options supported by the product. Settings that affect scoring should be visible before the game starts and should require confirmation if changed after scoring begins.

**User review before first pitch:** Before entering live scoring, the application should provide a clear pregame review of the teams, batting order, pitchers, and key settings. The user should be able to return to any preparation step from this review. Once scoring begins, the application should treat the game as active and protect existing scoring information from accidental setup changes.

## 6. Live Scorekeeping

During a live game, ScoreKeep should keep the user focused on recording baseball events accurately and quickly.

**Recording plate appearances:** The user records each batter's result, including hits, walks, hit by pitch, errors, fielder's choice, strikeouts, sacrifices, and other supported ScoreKeep result values. The application should preserve established ScoreKeep scoring terminology so existing users and imported games remain understandable.

**Runner advancement:** The user records bases reached, runners scoring, base-path outs, stolen bases, RBIs, earned-run state, and relevant play notes. The visible game state should make it clear who is on base, how many outs there are, and what inning is being scored. Automatic assistance may be provided, but the user must be able to correct the final scored result.

**Innings:** The application should track half innings, outs, batting order progression, and end-of-inning decisions in a way the user can understand. It should support regulation games and expected recreational variations, including shortened games and extra innings, without corrupting score or statistics.

**Pitching changes:** The user can add pitchers, change pitchers, and review pitcher participation during the game. Pitcher statistics should be based on the scoring events assigned to each pitcher's participation period. If pitcher information is incomplete, the application should make that visible rather than silently producing misleading results.

**Substitutions:** The user can record replacement players and preserve the relationship between outgoing and incoming players. Substitution behavior should support established ScoreKeep workflows, including visible replaced/incoming player context and continued scoring after the substitution.

**Corrections:** The user can reopen a scored event and correct the result, bases, outs, RBIs, stolen bases, earned-run state, notes, or related scoring details. Corrections should update dependent score and statistics consistently. Deleting or resetting a scoring event should be explicit and limited to the intended event.

**Temporary interruptions:** The user may pause scoring because of rain delay, suspended play, changing devices, app interruption, or ordinary navigation away from the game. The application should preserve progress and show enough context on return for the user to continue safely.

**Saving progress:** Progress should be saved frequently enough that unexpected app closure, device restart, or battery loss does not cause meaningful scoring loss. The user should not need to perform a special save action after every plate appearance. When a manual save or done action is present, it should reinforce confidence but should not be the only protection against data loss.

## 7. Completing a Game

A game is considered complete when the baseball game has officially ended and the user confirms that the current scoring record represents the final result. Completion may occur after the scheduled number of innings, after extra innings, after a mercy rule, after a shortened official game, after a forfeit or other administrative ending, or after an interrupted game is declared final.

Before completion is finalized, ScoreKeep should provide a final review. The review should show the final score, inning or game-ending context, team totals, and any visible warnings about incomplete lineups, missing pitcher information, or unresolved scoring placeholders. The user should be able to return to scoring to fix mistakes before confirming completion.

After completion, statistics should be available from the scored game information. The application should provide batting statistics, pitching statistics, box-score views, scorecards, and available reports according to product rules and user entitlement. Statistics shown in different views should agree with each other because they should reflect the same scored game facts.

Completed games should be shareable through compatible ScoreKeep game files and available report formats. Sharing a completed game should not modify the game. If report generation or PDF output is premium-gated, that gate must not prevent the user from accessing, reviewing, correcting, or exporting their own compatible game data where export is part of the supported data workflow.

Future editing should remain possible, but completed games should be treated as historical records. The application should make it clear when the user is reopening a completed game for changes that may alter final score, statistics, or reports.

## 8. Reopening a Game

A completed or archived game may be reopened when the user needs to correct a scoring mistake, add or revise notes, complete missing pitcher information, regenerate reports, or resolve an import issue discovered after review.

Reopening a game should preserve historical accuracy by making the current status clear. The user should understand whether they are reviewing the game, editing descriptive information, or changing scoring events that affect the final score and statistics. Changes to scored events should cause all dependent visible results to refresh consistently.

Correcting mistakes should be allowed because scorekeeping errors are common during live play. The application should support targeted correction of the affected play without forcing the user to rebuild unrelated innings, lineups, pitchers, or substitutions.

Adding notes or descriptive information should not require the game to become an active live game again. Regenerating reports should use the current saved game record and should not alter scoring information.

When a reopened game is saved, shared, or archived again, the revised state becomes the user's current authoritative record. The application should avoid silently preserving conflicting old totals, stale reports, or outdated generated output as if they were still current.

## 9. Data Integrity Requirements

ScoreKeep must protect user data throughout the game lifecycle.

- The application must never silently discard scoring information.
- Destructive actions such as deleting a game, deleting scoring events, replacing an existing lineup with scored at-bats, deleting roster data used by games, or overwriting imported data must require clear confirmation.
- Deletion should describe what will be removed and should not remove unrelated teams, players, games, lineups, pitchers, substitutions, or scoring events.
- The application should protect against accidental deletion through confirmation, clear labels, and recoverable workflows where practical.
- Completed and archived games should preserve historical accuracy. Later roster edits, player renames, or team changes should not unintentionally rewrite the meaning of earlier scored games.
- Related game information must remain synchronized. Scores, inning totals, batting statistics, pitching statistics, reports, and scorecards should reflect the same underlying scoring record.
- Partial operations should not leave a game corrupted. If an import, lineup update, substitution, scoring correction, or report generation cannot finish, the user should retain a usable prior state or receive clear guidance about what changed.
- Imported games must be validated before they alter local records. Invalid or incomplete imported data should be rejected or quarantined with a user-readable explanation rather than partially merged into unrelated games.
- Duplicate team or player names must be handled carefully so data from different teams, seasons, or imports is not accidentally merged.
- Progress during live scoring must be preserved across normal navigation, app backgrounding, unexpected closure, and device restart as far as the platform allows.
- Every scoring action should either complete successfully or leave the game unchanged.

## 10. Exceptional Situations

**App unexpectedly closes:** When the user returns, the game should reopen from the last saved progress with visible context such as teams, score, inning, outs, current lineup position, and recent scoring information. The user should not be asked to recreate plays that were already saved.

**Device restarts:** Locally saved games should remain available after restart. Any in-progress game should be resumable from the last durable state.

**Battery loss:** Battery loss should be treated like an unexpected closure. The application should preserve completed scoring events and avoid relying on a final manual save as the only protection.

**Internet unavailable:** Core game lifecycle capabilities must remain available. Users should be able to create, prepare, score, complete, review, correct, and locally share compatible files without Internet access. Network-only features should show clear offline or retry messaging without blocking local data.

**Rain delay:** The user should be able to pause or simply leave the game in progress, return later, review the current state, and resume scoring without changing the score or inning accidentally.

**Suspended game:** The user should be able to retain the game as temporarily interrupted for later continuation. If the suspended game is later declared final, the user should be able to mark it complete while preserving the recorded scoring information.

**User exits during scoring:** Exiting the scoring view should not imply game completion or data deletion. The game should remain in progress or temporarily interrupted and should be easy to resume from the game list.

**Invalid imported game:** A game file that cannot be read as a compatible ScoreKeep game should not alter local game data. The user should receive a clear message that the file could not be imported.

**Missing imported data:** If an imported game is missing teams, players, lineups, pitchers, or scoring references required for a usable game, the application should explain the problem and avoid partial import that would create misleading scores or unusable reports. When safe recovery is possible, the user should be told what was recovered and what remains incomplete.

## 11. Lifecycle Diagram

```text
Create
   ↓
Configure
   ↓
Prepare Teams, Rosters, Lineups, Pitchers
   ↓
Ready to Score
   ↓
Score Game
   ↓
In Progress ──→ Temporarily Interrupted ──→ Resume Scoring
   ↓                         │
Complete Game                │
   ↓                         │
Final Review ←───────────────┘
   ↓
Reports / Statistics / Sharing
   ↓
Archive
   ↓
Review Later ──→ Reopen for Correction ──→ Final Review
```

Imported games may enter the lifecycle at Created, Configured, Completed, or Archived depending on the completeness and status of the imported record. Invalid imports must not enter the lifecycle until the user receives an explanation and chooses a valid recovery path, if one is available.

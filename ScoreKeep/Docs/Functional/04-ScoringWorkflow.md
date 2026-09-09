# ScoreKeep Functional Specification — 04 Scoring Workflow

## 1. Overview

The scoring workflow describes how a user records baseball events during a live game. It begins when pregame preparation is complete enough for play to be scored and continues through each plate appearance, runner movement, pitching change, substitution, correction, interruption, and inning transition until the game is complete or paused for later continuation.

Live scorekeeping must remain fast, accurate, recoverable, and understandable throughout an entire baseball game. The user may be scoring from the stands, dugout, or press area while also watching the field, responding to substitutions, and correcting mistakes. ScoreKeep should help the user keep pace with play without sacrificing the integrity of the game record.

The product should preserve established ScoreKeep workflows for selecting batters, recording results, identifying bases reached, recording outs, advancing runners, entering RBIs, stolen bases, earned-run decisions, play notes, pitcher participation, substitutions, and corrections. The rewritten application should make those workflows clearer and more predictable while keeping existing ScoreKeep games and scoring terminology understandable.

The scoring workflow is part of the larger game lifecycle. It should respect the game setup, lineups, rosters, pitchers, and game settings prepared before first pitch, while still allowing realistic game-day changes when the baseball game does not follow the planned setup.

## 2. Beginning Live Scoring

Live scoring begins when the user chooses to score a prepared game. Before the first scoring event, the application should show enough context for the user to confirm that the correct game is active: visiting team, home team, date or location when useful, expected inning count, lineup status, and current scoring state.

The transition from pregame preparation should be deliberate. If lineups or pitcher information are incomplete, the user should see that before the first plate appearance. The application should allow scoring to begin when the user intentionally accepts an incomplete but usable setup, because recreational games often start before every detail is known.

Pregame drag-and-drop lineup preparation remains available before game creation/scoring through Team -> Default Batting Order. Saving there updates the reusable Team default order, and a subsequently created or newly materialized game uses that order.

The initial game state should be clear and conventional. The game begins in the first inning with no outs, no runners on base, a zero score, and the visiting team batting first unless the user is resuming or correcting a game whose saved state says otherwise. The first batter should be the first eligible batter in the visiting lineup according to the selected lineup rules.

The user should understand which batter is expected next before opening the scoring controls. If the batting order is wrong, the user should have a visible way to correct lineup or batter selection before recording a play. ScoreKeep should not silently guess a different batter when the saved batting order is ambiguous.

ScoreKeep 6.1 lineup-slot correction allows eligible Player identities to be corrected directly from the live scorecard while the shared lineup-slot coordinator proves the slot remains safe.
This is a lineup-entry correction, not a substitution, and it uses the shared lineup-slot safety and mutation path rather than the retired Starting Lineup screen.

Beginning the first inning should not require the user to perform hidden setup. Any required scoring state should be visible through ordinary scoring screens. If the game is resumed later, the user should return to the saved inning, outs, runners, batter, score, and team at bat rather than being forced back to the first batter.

## 3. Recording a Plate Appearance

A plate appearance begins when the user selects or confirms the batter to be scored. The application should show the batter's team, lineup position, and any visible player information needed to distinguish similar players. The user should be able to move to the correct batter when the expected batter is not the player at the plate.

The user records the batter's result using baseball terms consistent with ScoreKeep compatibility. Supported results should include common hit results such as single, double, triple, and home run; non-hit on-base results such as walk, hit by pitch, error, fielder's choice, dropped third strike, and catcher interference; and out results such as ground out, fly out, line out, foul out, strikeout, strikeout looking, sacrifice fly, and sacrifice bunt.

After choosing the result, the user records the bases reached by the batter. The batter may remain without a base on an out, reach first, second, third, or home, or be recorded out on a base path when the play requires it. The application may suggest a likely base from the selected result, but the user must be able to correct the final base state.

The user records outs for the play. Outs may come from the batter, one or more runners, or both. The scoring workflow should support ordinary one-out plays, double plays, triple plays, sacrifices, force outs, tag outs, and outs made at any base including home plate. The user should be able to complete the play only when the resulting out count and base state are understandable.

Runner advancement should be recorded as part of the same play when existing runners move because of the batter's result, a force, a hit, an error, a stolen base, defensive indifference where supported, or a correction. The user should be able to identify which runners advanced, which runners scored, and which runners were put out.

RBIs should be recorded when runs score and the user determines that the batter should receive credit. The workflow should allow zero or more RBIs on a play, including plays where runs score without an RBI. The application should avoid assuming every scoring runner creates an RBI when the result or baseball situation makes that uncertain.

Stolen bases should be recorded when a runner advances by steal as part of or around the plate appearance. The user should be able to enter stolen-base counts or runner-specific stolen-base information according to the supported ScoreKeep workflow. Stolen bases should not be confused with ordinary advancement on a batted ball.

Earned and unearned run decisions should be available when a run scores and pitcher reporting requires the distinction. If the user does not yet know whether a run is earned, the application should allow the user to continue scoring while making incomplete earned-run decisions visible for later correction.

Play notes should allow the user to preserve meaningful scoring context such as fielding sequence, unusual rulings, scorer decisions, injuries, or explanation for a correction. Notes should be optional and should not slow routine scoring.

Completing the play should update the visible score, outs, base runners, batter progression, pitcher participation, and inning state consistently. The user should not see one part of the application show a changed score while another part still reflects the previous play as if both were current.

## 4. Runner Management

Runner management must make the end of each play clear. The user should always be able to determine which bases are occupied, which players occupy them, which runners scored, and which runners were retired.

Existing runners should carry forward from the prior completed play. When the next play starts, the application should show the runners on base before the user records the batter's result. The user should not need to reconstruct base occupancy from memory.

Forced runners should advance according to the baseball situation when the batter reaches safely and bases are occupied, but automatic assistance must remain correctable. If the application suggests forced advancement, the user should be able to override it when the actual play included an out, extra advancement, or a nonstandard ruling.

Multiple runners may score on one play. The workflow should allow the user to record each scoring runner and keep the score, RBI count, earned-run decision, and pitcher responsibility understandable. A play that scores more than one run should not require duplicate batter records just to account for each runner.

Double plays and triple plays should be recordable without leaving impossible base states. The user should be able to identify multiple outs on the same play, including the batter and any affected runners. After the play is completed, the bases and out count should reflect the final baseball situation.

Runner corrections should be targeted and understandable. If a runner was advanced to the wrong base, scored incorrectly, or marked out by mistake, the user should be able to correct that runner's outcome without rebuilding unrelated plate appearances whenever practical.

Base occupancy should never silently contain two active runners on the same base or a runner on a base after that runner has scored or been put out. If the user's scoring choices create an impossible state, the application should ask for correction before treating the play as complete.

At the end of each play, ScoreKeep should present a coherent end-of-play state: inning, outs, score, runners, next batter, pitcher, and team at bat. This state becomes the starting point for the next plate appearance and must be preserved if the user leaves and returns.

## 5. Outs and Innings

The scoring workflow should track outs in baseball terms. Each completed play may add zero, one, two, or three outs depending on the result and runner outcomes. The user should be able to see the current number of outs before and after recording a play.

When the third out is recorded, the half inning should end. The application should make the third-out transition clear before moving to the next half inning, especially when runners also scored on the play or when the third out affects whether a run counts.

End-of-half-inning behavior should clear the bases, advance the batting side, preserve the score, and move to the next appropriate batter for the team coming to bat. The user should understand whether the game is moving from top to bottom, bottom to next inning, or into a completion review.

Inning transitions should support regulation baseball flow and common recreational variations. The expected inning count should guide completion prompts, but it should not prevent scoring extra innings or a shortened official game when the real game requires it.

Extra innings should continue the same scoring workflow with the next inning number, correct batting order, current score, and ordinary runner management unless a future supported rule explicitly defines a different starting runner or inning rule.

Shortened games should be supported when a game ends before the expected inning count because of weather, darkness, time limit, forfeit, administrative decision, or league rule. The user should be able to preserve the scoring record and mark the game complete or interrupted according to the actual status.

Mercy-rule games should allow the user to end the game with the current score and inning context. The application should not require artificial outs or fake plate appearances just to reach the scheduled inning count.

Suspended games should preserve the exact scorekeeping state at interruption: inning, half inning, outs, runners, batter context, pitcher, lineups, and scored plays. When resumed later, the game should reopen to that state rather than treating the game as complete.

## 6. Pitching Changes

The scoring workflow should support pitcher participation from the beginning of the game through the final out. A starting pitcher may be selected before live scoring or added when scoring begins. If no starting pitcher is known, the application should still allow scoring and make the missing pitcher information visible.

Mid-inning pitching changes should be recordable at the point they occur. The user should be able to identify the outgoing pitcher, incoming pitcher, inning, outs, batter context, and batting team situation. Pitcher participation should remain understandable in reports after the game.

Multiple pitchers may appear for either team. ScoreKeep should preserve each pitcher's participation period so batting results, runs, hits, walks, strikeouts, and other pitching-related statistics can be attributed according to the scored game record.

An unknown pitcher should be allowed when the user cannot identify the defensive player during live scoring. The unknown status should be visible and correctable later. Reports should avoid presenting unknown or incomplete pitcher assignments as if they were fully verified.

Correcting pitcher assignments should update dependent pitching statistics consistently. If the user moves a plate appearance from one pitcher responsibility period to another, the affected pitcher totals should refresh based on the corrected record.

Pitcher participation should not require the user to stop scoring a live play. The workflow should permit a quick pitching change entry and return the user to the current batter, outs, runners, and score without losing the scoring context.

## 7. Substitutions

Substitutions should support realistic offensive and defensive changes while preserving a readable history of who appeared in the game. The user should be able to record the outgoing player, incoming player, team, role, and timing of the substitution.

Offensive substitutions include pinch hitters, pinch runners, and lineup replacements that affect batting order or base running. When a pinch hitter appears, the application should make clear which lineup position is being occupied and how future plate appearances will proceed. When a pinch runner enters, the application should show which runner was replaced and which base the new runner occupies.

Defensive substitutions should allow the user to record participation changes that matter for game history and reports. Defensive substitution details should not corrupt offensive batting order or already scored plate appearances.

Re-entry should be supported where the selected game rules allow it. If re-entry is not supported for the active game, the application should warn the user before accepting a substitution that would make the participation history ambiguous.

Recording substitutions should be quick enough for live play. The user should not have to abandon the current scoring context, and the application should return to the correct batter, pitcher, runners, outs, and inning after the substitution is saved.

Historical preservation is required. A substitution should not rewrite earlier plate appearances as if the incoming player had taken them. Scorecards, reports, and game review should remain clear about which player was involved in each recorded event.

## 8. Correcting Scoring

Scorekeeping mistakes are expected during live baseball. The application should support correction without making the user lose confidence in the game record.

The user should be able to edit a previously recorded play and correct the batter result, bases reached, runner advancement, outs, RBIs, stolen bases, earned-run decision, pitcher assignment, substitution context, or notes when those details were entered incorrectly.

Deleting a play should be explicit. The user should understand whether they are removing a scored plate appearance, resetting an unscored placeholder, or canceling a partially entered play. Deleting one play must not silently delete unrelated plays, lineups, pitchers, teams, or players.

After a correction, the game should replay or recalculate dependent information in a way that produces a consistent scorekeeping state. Score, inning totals, outs, batting order progression, base runners, pitcher statistics, scorecards, and reports should reflect the corrected scoring record.

Corrections should affect only the intended plays. Editing a single batter's result should not alter another batter's play unless the correction necessarily changes downstream state such as base occupancy, inning transition, or pitcher responsibility. When downstream effects are expected, the application should make them understandable.

If a correction creates an incomplete or inconsistent state, the application should guide the user to resolve it before presenting the game as fully current. The user should be able to keep scoring when safe, but unresolved scoring issues should remain visible.

User confidence is the priority. The application should make it clear what changed, preserve completed scoring data whenever possible, and avoid requiring destructive resets for ordinary scoring mistakes.

## 9. Live Game State

During scoring, the user should always understand the current baseball situation. The scoring screen should make the active game state visible without requiring the user to leave the workflow.

The current inning should be visible, including whether the game is in the top or bottom half. The user should be able to identify whether the game is in regulation, extra innings, a shortened state, or a suspended/resumed state when that status matters.

The current number of outs should be visible before recording a play and after completing it. Third-out situations should be especially clear because they affect inning transitions and whether runs count.

The current batter should be visible with enough context to distinguish the player from teammates. The batting order should show where the batter fits and who is expected next, especially after substitutions or corrections.

The score should be visible for both teams and should update when scoring plays are completed. The displayed score should be explainable by the recorded scoring events.

Base runners should be visible by base and by player. The user should be able to see whether first, second, and third are occupied, who occupies each base, and how that state changes after a play.

The current pitcher should be visible when known. If pitcher information is missing, unknown, or potentially incomplete, the application should show that state rather than hiding the uncertainty.

The team at bat should be visible at all times. The user should not have to infer from color, side, or roster order alone which team is batting.

## 10. Data Integrity Requirements

ScoreKeep must protect scoring data throughout live play, correction, interruption, and review.

- The application must never silently lose scoring data.
- Every scoring change must update dependent information consistently, including score, outs, inning state, base runners, batting order, pitcher participation, statistics, reports, and scorecards.
- Corrections must affect only the intended plays except where the user is clearly informed about necessary downstream scoring effects.
- Historical scoring must remain understandable after roster edits, substitutions, pitcher corrections, game reopening, import, export, and report generation.
- Progress should be preserved frequently enough that normal navigation, app backgrounding, device sleep, app closure, or device restart does not cause meaningful loss of completed scoring events as far as the platform allows.
- The application must not present misleading intermediate scoring states as final or authoritative.
- Destructive scoring actions must require clear user intent and should explain what will be removed, reset, or recalculated.
- A completed play should either be saved as a coherent baseball event or leave the prior game state unchanged.
- Imported or reopened games should preserve compatible scoring records and should show incomplete or unsupported scoring details when they affect user understanding.
- Reports and statistics should derive from the current saved scoring record and should not silently rely on stale totals.

## 11. Exceptional Situations

**App closes:** If the app closes during scoring, the user should be able to reopen the game from the last durable state. Completed plays should remain available, and any incomplete play should be recoverable, clearly unfinished, or safely discarded with explanation.

**Device sleeps:** Device sleep should not imply game completion, cancellation, or data loss. When the device wakes, the scoring screen should show the saved inning, outs, score, runners, batter, pitcher, and team at bat.

**User leaves scoring screen:** Leaving the scoring screen should preserve progress and return the game to the list or previous navigation state as an in-progress game. The user should be able to resume without re-entering completed plays.

**Wrong batter selected:** The user should be able to correct the batter before or after completing a play. If changing the batter affects batting order progression or lineup state, the application should make that effect clear.

**Wrong result entered:** The user should be able to reopen the play and change the result. Dependent bases, outs, RBIs, score, pitcher statistics, and inning state should update consistently after the correction.

**Wrong inning:** If scoring was entered in the wrong inning or half inning, the user should be able to correct the affected plays or inning transition without losing unrelated game data. The application should show any downstream effects on batting order, outs, score, and base state.

**Duplicate scoring:** If the same batter or play appears to have been entered twice, the application should let the user remove or reset the duplicate intentionally. Duplicate cleanup should not remove legitimate repeated plate appearances by the same player.

**Undoing mistakes:** The workflow should support practical recovery from recent mistakes through editing, deleting, or resetting the affected scoring event. A full undo stack is not required by this specification, but ordinary scoring mistakes should not force the user to abandon the game.

**Interrupted game:** Rain delay, darkness, time limit, injury, device interruption, or other stoppage should leave the game in an in-progress or suspended state unless the user marks it complete. The saved state should be clear enough to resume later.

**Resuming later:** When the user resumes an interrupted or previously saved game, the application should show the current scorekeeping context and continue from the next expected scoring action. The user should be able to review recent plays before recording the next plate appearance.

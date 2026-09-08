# ScoreKeep Functional Specification — 05 Lineups and Substitutions

## 1. Overview

Lineups define how players from a selected team participate in a specific game. They bridge reusable roster management and live scorekeeping by turning a team roster into the batting order, participation list, and substitution context used during that game.

ScoreKeep 6.1 adds a slot-based lineup direction documented in `ScoreKeep/Docs/LineupAndScoringDesign.md`.
When no game-specific lineup exists, roster/import `Player.batOrder` is the default lineup source.
Users do not need to construct a perfect lineup before scoring: they may accept the imported/default lineup, prepare it before the game, or correct individual Player identities on the fly while persisted evidence proves the slot remains safe.
There is no separate on-the-fly mode and lineup slots should not be represented by fake Unknown Player records.

A lineup determines which players are eligible to bat, the order in which they bat, and how the expected batter advances throughout the game. It also provides the game-specific player context needed for scorecards, batting statistics, pitching records, substitutions, corrections, and reports.

Lineups are separate from rosters. A roster describes players who belong to a team over time. A lineup describes how selected players from that roster, plus any game-specific additions, are used in one game. Changing a lineup should not rewrite the reusable roster unless the user intentionally performs a roster-management action.

Substitutions change the current and future lineup state without rewriting previous game history. When a player is replaced, earlier plate appearances, runner appearances, defensive participation, and pitching records must remain attributed to the player who actually participated at that time. The current lineup should reflect the present game situation, while historical lineup states remain understandable for review and reporting.

## 2. Lineup Concepts

A batting order is the sequence in which a team's hitters are expected to bat. The batting order advances from one hitter to the next as plate appearances are completed and cycles back to the first position after the final batting position.

The starting lineup is the initial set of players assigned to batting order positions before the game begins. The starting lineup represents the user's best known game setup at the time live scoring starts.

Bench players are players available to participate in the game but not currently occupying an active batting position. Bench players may come from the reusable roster, a game-specific addition, or an imported game record. Bench status is specific to the game and should not imply that the player is inactive on the team roster.

An Everyone Hits lineup includes every selected hitter in the batting order. In this mode, the batting order may be longer than a traditional defensive lineup, and players may bat even when they are not currently assigned to a defensive position.

A Traditional lineup uses a fixed batting order size according to the selected game rules or user choice. Players outside that active batting order are bench players unless they enter through a substitution or other supported participation change.

The active lineup is the lineup state that applies at the current point in the game. It identifies the current batting order positions, current occupants of those positions, current runner substitutions where applicable, and other participation details needed for live scoring.

A defensive lineup, where supported, describes the players currently assigned to defensive roles or fielding positions. Defensive lineup information may overlap with the batting order, but it is not always the same thing. In Everyone Hits games, for example, a player may be in the batting order without being on defense in the current half inning.

A lineup is different from a roster. The roster is reusable team information. The lineup is game-specific participation information. A player can be on the roster without appearing in a lineup, and a player can be added to a game lineup as a temporary or guest participant without necessarily becoming a permanent roster member.

A game-specific lineup is tied to one game only. It should preserve the batting order, substitutions, defensive participation, pitcher changes, and corrections that occurred in that game. A reusable roster may help create many lineups, but a lineup should not be shared across games as if it were the roster itself.

## 3. Creating a Lineup

Creating a lineup begins by selecting players for a specific game. The user should be able to choose players from the selected team's roster and add a missing or temporary player when necessary. Player selection should preserve enough identity to distinguish players with similar names, shared jersey numbers, or incomplete details.

The user chooses the batting order for the selected players. In Everyone Hits mode, the selected hitters form the batting order. In Traditional mode, the user identifies the active batting positions and leaves other available players on the bench unless they enter later.

Validation should help the user detect lineup mistakes before live scoring begins. The application should warn about duplicate batting positions, duplicate players, missing required player identity, an empty lineup, incomplete batting order, unsupported lineup mode, or a lineup that cannot produce a clear first batter.

Duplicate prevention is required. The same player should not silently occupy multiple batting positions unless a future supported rule explicitly allows a special case and the user confirms it. The application should distinguish legitimate players who share a name or number from accidental duplicate selection.

Missing player handling should support realistic game preparation. If a player is missing from the roster, the user should be able to add that player for the game without losing the lineup being built. The application should make clear whether the new player is being added only for this game or also to the reusable roster when that distinction is supported.

Everyone Hits behavior should include every selected hitter in the batting order and should make the order complete enough to identify the first batter and next batter. Players may be marked as unavailable, absent, or removed from the active game when supported, but those states should be visible before scoring begins.

Traditional lineup behavior should identify active batting positions and available bench players. The application should not assume that an unselected roster player is part of the batting order. A player who later enters the batting order should do so through a substitution or correction that preserves timing.

Saving drafts should be supported when the lineup is not ready for live scoring. A draft lineup may be incomplete, but its incomplete status should remain visible. Returning to a saved draft should restore selected players, order, mode, and unresolved validation issues.

Editing before first pitch should be flexible. Until live scoring begins, the user should be able to reorder, add, remove, or replace players without creating substitution history, because the game record has not yet established participation.

## 4. Editing Before the Game

Before the first pitch or first recorded scoring event, lineup editing is preparation rather than live substitution. The user should be able to change the lineup to match the actual starters without implying that players entered or exited during the game.

Reordering hitters should update the planned batting order. The user should be able to move a hitter to a different batting position and have the remaining order stay understandable. Reordering should not create duplicate batting positions or leave gaps unless the lineup is intentionally saved as an incomplete draft.

Adding players should allow late roster changes, guest players, or players discovered during pregame. Added players should become available for the selected game immediately after their required identifying information is provided.

Removing players before the game should remove them from the planned lineup or bench for that game only unless the user separately chooses a roster action. Removing a player from a pregame lineup must not delete the player from the reusable roster or from historical games.

Replacing players before the game should be treated as correcting the planned lineup. The replacement should occupy the intended batting position or bench status without creating a mid-game substitution record.

Editing batting order should include assigning, clearing, or correcting batting positions. The application should prevent the same batting position from being assigned to more than one active hitter without resolution.

Switching lineup modes should be allowed before scoring begins when the resulting lineup can be validated. If switching between Everyone Hits and Traditional changes who is in the active batting order, the user should understand which players will bat and which players will be on the bench.

Validation before the game should identify lineup issues that would make live scoring ambiguous. The user may be allowed to proceed with an incomplete but usable setup when recreational play requires it, but unresolved issues should remain visible.

Confirmations should be required when a pregame edit discards meaningful work, removes multiple selected players, changes lineup mode in a way that alters participation, or resolves conflicts by replacing existing selections.

## 5. Lineup Behavior During the Game

During the game, the active lineup determines the current batter and the next expected batter for the team at bat. The current batter should be the player occupying the correct batting order position according to completed plate appearances, substitutions, corrections, and the selected lineup mode.

The next batter should be understandable before and after each plate appearance. Completing a plate appearance should advance the batting order to the next eligible batting position unless the inning ends or a correction changes the expected progression.

Cycling the batting order should follow baseball expectations. After the final batting position, the order returns to the first batting position. This cycling continues across innings and should preserve the correct next batter when a half inning ends.

Everyone Hits progression should advance through the full selected batting order. If every selected player bats, the next batter after the final selected hitter is the first selected hitter, subject to substitutions, removals, late arrivals, or rule-specific participation changes.

Traditional progression should advance through the active batting positions. Bench players do not bat until they enter the batting order through a supported substitution or correction. A replacement player occupies the batting order position of the player being replaced unless the selected rules define another behavior.

New innings should continue from the saved batting order position for the team coming to bat. A new inning should not reset the batting order to the leadoff hitter unless the previous game state requires that result.

Continuing after interruptions should restore the same active lineup, current batter context, next batter, runners, substitutions, defensive state where applicable, and unresolved lineup issues that existed when the game was saved.

Corrections affecting batting order should update the current and future batter progression consistently. If a prior plate appearance is inserted, deleted, reassigned, or corrected to a different batter, the downstream batting order and current game state should remain explainable.

## 6. Offensive Substitutions

Offensive substitutions include pinch hitters, pinch runners, and permanent batting-order replacements. They should identify the team, incoming player, outgoing player or runner, batting order position where applicable, base occupied where applicable, inning, half inning, outs, and surrounding batter context.

A pinch hitter bats in place of the player currently due in a batting order position. The lineup should make clear whether the pinch hitter becomes the permanent occupant of that batting position or is a temporary appearance under the selected rules.

A pinch runner replaces a runner already on base. The substitution should preserve which runner was replaced, which base was occupied, and when the change occurred. The previous runner's completed offensive history must remain attributed to that previous player.

Permanent replacements occupy the relevant batting order position for future plate appearances. A permanent replacement should not change prior plate appearances by the outgoing player. Future scoring should use the replacement as the expected batter when that batting position comes up.

Temporary replacements, if supported by the selected rules, should be clearly labeled so the user can understand whether the original player may return and how future batting order progression will work. If temporary replacement is not supported, the application should not present the change as temporary.

Maintaining batting order is required. A substitution should not create an extra batting position, skip a batting position, or reorder unrelated hitters unless the user is explicitly correcting the lineup and confirms the downstream effect.

Recording timing is required for historical meaning. The substitution record should preserve when the change occurred relative to inning, outs, batter, runner state, and scored events so reports and later review can explain participation.

Historical preservation is required. Offensive substitutions must not rewrite previous at-bats, plate appearances, runs, runner appearances, or scorecard entries as if the incoming player had always occupied that lineup position.

## 7. Defensive Substitutions

Defensive substitutions record changes to defensive participation. A defensive replacement may enter the field for another player, change a fielding position, or participate only on defense depending on the selected lineup mode and game rules.

Position changes should be distinguishable from player replacements. A player moving from one defensive position to another is different from a new player entering the game. The game history should remain clear about both the player and the defensive role when that information is recorded.

Pitcher substitutions are a special defensive change because they affect pitching participation, pitcher statistics, and reporting. A pitcher substitution should identify the outgoing pitcher, incoming pitcher, timing, defensive team, and surrounding game situation. It should not corrupt batting order unless the selected rules link the pitching change to an offensive lineup change.

Defensive-only changes should be supported where the selected lineup mode and rules allow them. In Everyone Hits games, for example, defensive participation may change without changing the batting order. In Traditional games, a defensive replacement may also affect the batting order depending on the rules selected for the game.

Interaction with batting order should be explicit. A defensive change should not silently replace a hitter in the batting order unless that is the intended substitution behavior. If the defensive change also changes future batting order participation, the user should understand that effect before the change is saved.

Historical preservation is required for defensive substitutions. Prior defensive participation, pitching responsibility, and scored plays should remain attributed to the players who were active at that time. Later position changes should not make earlier plays appear to have involved different players.

## 8. Re-entry Rules

ScoreKeep may support different baseball rule sets, including recreational, youth, school, tournament, or user-defined rules. This specification does not require enforcement of a single official ruleset.

Re-entry behavior depends on the selected rules for the game. Some rules may allow starters to re-enter, allow free defensive substitutions, allow courtesy runners, allow everyone to bat, or prohibit a removed player from returning. The product should describe the selected behavior in baseball terms when it affects a substitution.

Invalid substitutions should be explained clearly. If a player is not eligible to enter, re-enter, run, bat, pitch, or replace another player under the selected rules, the application should tell the user why the substitution is invalid and what information must be changed to proceed.

Historical participation must remain understandable regardless of ruleset. Even when rules allow flexible substitution, reports and game review should make clear who batted, ran, pitched, played defense, left the game, returned, or remained on the bench at relevant points.

When rule enforcement is incomplete or the user intentionally overrides a warning, the resulting game record should preserve enough context to explain what was recorded. The application should avoid presenting uncertain rule compliance as verified.

## 9. Lineup Corrections

Lineup corrections fix mistakes in the game-specific lineup or substitution history. They are different from ordinary live substitutions because they change the recorded understanding of what happened or when it happened.

Correcting batting order should allow the user to fix a wrong batting sequence, wrong active hitter, incorrect lineup mode, or mistaken batting position. The application should show when the correction affects later expected batters, scored plate appearances, or inning transitions.

Correcting substitution timing should allow the user to move a substitution to the point where it actually occurred. If the timing change affects which player received a plate appearance, run, pitcher responsibility, or defensive participation, those downstream effects should be made understandable.

Correcting player identity should allow a user to replace an incorrectly selected player with the player who actually participated. Historical scoring should update to the corrected player only where the correction applies, not across unrelated games or unrelated appearances.

Correcting lineup mistakes should support common problems such as a player entered in the wrong batting position, a bench player accidentally included as a starter, a starter omitted from the lineup, or an Everyone Hits order entered incorrectly.

Downstream effects should be handled carefully. A lineup correction may affect current batter, next batter, base runners, substitutions, pitcher attribution, scorecards, reports, and statistics. The application should keep dependent scoring consistent and visible after the correction.

User confirmation is required when a correction changes completed scoring events, reassigns historical participation, changes future batting order, removes substitution history, or recalculates dependent statistics.

Maintaining scoring consistency is required. After a lineup correction, the game should have a coherent current state and a readable history. The correction should not leave impossible base occupancy, duplicate active hitters in one batting position, missing current batter context, or reports that disagree with saved scoring events.

## 10. Validation Requirements

Validation should protect lineup meaning before scoring, during live substitutions, during corrections, and during import or export of game records.

Duplicate batting positions should be detected whenever more than one active hitter is assigned to the same batting position. The user should be required to resolve the conflict before the lineup is treated as valid for scoring.

Missing players should be detected when a batting position, bench entry, runner, defensive role, or substitution references a player that cannot be identified. The application should allow repair when possible and should avoid treating an unknown player as verified.

Duplicate players should be detected when the same player appears more than once in a way that conflicts with the selected lineup mode or rules. The application should distinguish true duplicate use from two different players who share a name or jersey number.

An empty lineup should not be treated as ready for live scoring. If scoring is allowed with minimal setup, the application should still make the empty or incomplete lineup state visible and require enough information to identify scored participants.

Invalid substitutions should be detected when a substitution conflicts with the selected rules, current game state, player availability, batting order, base occupancy, pitcher participation, or historical participation.

Impossible batting order should be detected when the application cannot determine a current or next batter from the saved game state. The user should be guided to correct the lineup, scored play, or substitution that created the ambiguity.

Unsupported rule combinations should be detected when selected lineup mode, re-entry behavior, substitution type, defensive participation, or scoring workflow cannot work together in a meaningful way.

Incomplete lineup should be visible when required batting positions, player identities, or substitution details are missing. Incomplete data may be saved as a draft or unresolved issue, but it should not be presented as complete.

Lineup slots should not use fake Unknown Player records. When the correct batter is absent from the roster, the user should add a real Player through the standard Add Player workflow.

## 11. Data Integrity Requirements

ScoreKeep must protect lineup and substitution meaning throughout preparation, live scoring, correction, import, export, reporting, and later review.

- Historical plate appearances must never change players silently.
- Substitutions must preserve the history of outgoing and incoming players.
- Previous lineup states must remain understandable after later substitutions or corrections.
- The current lineup must always reflect the current saved game state.
- Editing a lineup must not corrupt scoring, base runners, batting order progression, pitcher participation, scorecards, reports, or statistics.
- Import and export must preserve lineup meaning when compatible data is available.
- Reports must use the saved lineup and substitution history rather than stale or reconstructed assumptions.
- Lineup corrections must update dependent scoring consistently.
- Pregame lineup editing must remain separate from live substitution history.
- Roster edits must not silently alter game-specific lineup history.
- Deleted, inactive, renamed, imported, or merged players must not make historical game participation ambiguous.
- A completed substitution should either save as a coherent participation change or leave the prior game state unchanged.
- The application should preserve enough timing context to explain who was active for each scored event.
- If lineup data cannot be fully interpreted, the game should show the uncertainty rather than inventing a misleading lineup state.

## 12. Exceptional Situations

**Player arrives late:** The user should be able to add the player to the game according to the selected rules. The application should make clear whether the player joins the batting order, remains on the bench, enters defensively, or is unavailable until a valid substitution occurs.

**Player leaves early:** The user should be able to remove or mark the player unavailable according to the selected rules. Future batting order behavior should remain clear, and earlier participation should remain preserved.

**Wrong lineup entered:** The user should be able to correct the lineup before the game without creating substitution history. If scoring has already occurred, the correction should explain downstream effects on completed plate appearances, current batter, and reports.

**Wrong substitute selected:** The user should be able to correct the substitute identity or timing. The correction should affect only the relevant participation period and should preserve unrelated scoring events.

**Duplicate lineup position:** If two players occupy the same batting position, the application should require resolution before the order is treated as ready. If discovered mid-game, the user should be able to correct the position and understand affected scoring.

**Missing player:** If a needed player is absent from the roster or game record, the user should be able to add or identify the player without losing current lineup work. Unknown or incomplete identity should remain visible until resolved.

**Guest player:** A guest player should be usable in a game lineup when needed. The application should distinguish game-specific guest participation from permanent roster membership when that distinction is supported.

**Imported lineup conflicts:** Imported games or rosters may contain duplicate players, missing identities, unsupported lineup modes, or substitution records that do not map cleanly to current product behavior. Import should preserve understandable data, identify conflicts, and avoid silent destructive changes.

**Interrupted game:** An interrupted game should preserve the active lineup, batting order position, substitutions, runners, pitcher, inning, outs, and unresolved lineup issues so the game can be reviewed or resumed.

**Resuming later:** Resuming a saved game should restore the lineup state from the interruption point. The user should not need to rebuild the batting order or re-enter substitutions already saved.

**Mid-game lineup correction:** When a lineup mistake is discovered during scoring, the user should be able to correct it without abandoning the game. The application should preserve completed scoring wherever possible and make any required recalculation or reassignment understandable.

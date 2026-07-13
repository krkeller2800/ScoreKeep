# ScoreKeep Functional Specification — 06 Statistics and Reporting

## 1. Overview

Statistics and reporting describe how ScoreKeep presents the meaning of a scored baseball game after scoring data has been saved. Reports help users review a single game, compare team performance, understand player batting and pitching results, preserve scorecard history, and share generated output with others.

Statistics and reports must derive from saved scoring data. They should summarize, organize, and explain the game record, but they must never become independent sources of truth. If a user corrects the saved game, the affected statistics, scorecards, reports, box scores, and generated output should reflect the corrected saved record.

Reporting should remain consistent with the rest of ScoreKeep. Game setup, lineups, substitutions, pitcher participation, plate appearances, runner movement, scoring corrections, imports, and exports all affect what reports can accurately show. When source data is incomplete or uncertain, reports should make that uncertainty understandable rather than presenting unsupported totals as verified.

The purpose of reporting is practical baseball review. A user should be able to understand what happened in a game, how the teams scored, how players performed, and what historical record was preserved without needing to inspect implementation details or reconstruct calculations manually.

## 2. Statistical Philosophy

ScoreKeep should use one authoritative game record for reporting. The saved game, including its scoring events, lineups, substitutions, pitcher participation, corrections, and game status, is the source from which all statistics and reports are derived.

Reports should not maintain separate permanent totals that can drift away from the saved game. If the same statistic appears in a game report, scorecard, batting report, pitching report, box score, or generated PDF, the meaning should be consistent everywhere it appears.

Duplicate calculations with conflicting meanings should be avoided. When ScoreKeep presents a statistic in more than one place, those views should refer to the same baseball concept. If different report types intentionally present different scopes, such as one-game totals versus historical totals, that scope should be clear.

Historical accuracy is required. Reports should preserve what was recorded for the game as it was actually scored, including substitutions, unknown participants, incomplete pitcher assignments, and later corrections. Later roster edits, player renames, or team changes should not make historical game reports misleading.

Consistency across reports is a core requirement. The final score, inning totals, team totals, player totals, pitcher totals, scorecard entries, and generated output should all agree with the saved game record. A user should not see one report imply a different result from another report for the same saved game.

## 3. Game Statistics

Game statistics summarize the overall result and inning-by-inning progress of a scored game. They should identify the teams involved, the final score when the game is complete, and the scoring state when the game is incomplete, suspended, interrupted, or still in progress.

The final score represents the runs credited to each team by the saved scoring record. It should be understandable from the inning totals and individual scoring events. A completed game should not show a final score that cannot be reconciled with the saved runs.

The line score presents scoring by inning for each team. It should show runs scored in each completed half inning and preserve meaningful inning context for extra innings, shortened games, suspended games, and games ended by rule or user decision.

Runs, hits, and errors are team-level game concepts that support ordinary baseball review and box score interpretation. Reports should distinguish team totals from individual player totals and should not imply certainty for values that were not supported by the saved scoring data.

Inning totals should reflect the saved sequence of scoring events. They should remain consistent after corrections that change runs, outs, inning transitions, or scoring attribution.

Team totals should aggregate the saved game data for each team. Totals may include runs, hits, errors, batting totals, pitching totals, and other supported summary values. Team totals should agree with the related player and pitcher reports when the underlying data supports that comparison.

Box score concepts should provide a compact summary of the game. A box score may include team line score, runs, hits, errors, batting summaries, pitching summaries, and other supported game-level values. A box score should summarize the game record; it should not create a separate official record apart from the saved game.

## 4. Batting Statistics

Batting statistics describe offensive participation and outcomes for players in a saved game or supported historical scope. They should be based on recorded plate appearances, batting results, runner outcomes, and corrections.

Plate appearances represent completed offensive opportunities for a batter according to the saved scoring record. Reports should preserve the order and identity of plate appearances well enough to support scorecards, batting summaries, and historical review.

At bats, hits, singles, doubles, triples, home runs, walks, strikeouts, hit by pitch, sacrifice flies, sacrifice bunts, RBIs, runs scored, and stolen bases are supported batting concepts. Reports should present these terms consistently across game reports, team reports, batting reports, scorecards, and generated output.

Hits should be distinguishable by type when the saved game supports that detail. Singles, doubles, triples, and home runs should remain visible as separate batting outcomes where appropriate while still contributing to broader batting review.

Walks and hit by pitch should be reported as offensive events distinct from batted-ball hits. Strikeouts should be reported consistently with the scoring workflow and should preserve meaningful distinctions when the saved record supports them.

Sacrifice flies and sacrifice bunts should be preserved as scored batting outcomes. Reports should not collapse sacrifices into generic outs when that would reduce the historical meaning of the game record.

RBIs should represent runs credited to a batter by the saved scoring record. Runs scored should represent runners crossing home plate as recorded in the game. Reports should preserve the distinction between a player driving in a run and a player scoring a run.

Stolen bases should be reported when recorded for a runner. They should remain distinct from ordinary advancement on hits, errors, force situations, or other play outcomes.

Batting average, on-base percentage, and slugging percentage are supported batting rate statistics. This specification intentionally does not define formulas. The required behavior is that each rate statistic use one consistent meaning wherever it appears, derive from the saved game data, and refresh when relevant scoring data is corrected.

## 5. Pitching Statistics

Pitching statistics describe pitcher participation and outcomes attributed to pitchers in the saved game record. They should reflect pitcher assignments, pitching changes, batter results, runs, earned-run decisions, corrections, and any supported participation history.

Innings pitched should describe pitcher participation in the game. Reports should handle starting pitchers, relief pitchers, mid-inning changes, incomplete innings, and interrupted games in a way that remains understandable to the user.

Hits allowed, runs, earned runs, unearned runs, walks, strikeouts, and home runs allowed are supported pitching concepts. These values should be attributed according to the saved scoring record and pitcher participation history.

Earned and unearned runs should reflect the scorer's saved decisions where supported. If earned-run information is missing, unresolved, or unsupported for part of a game, reports should avoid presenting that portion as fully verified.

ERA is a supported pitching rate statistic. This specification intentionally does not define formulas. The required behavior is that ERA use one consistent meaning wherever it appears, derive from saved pitching and scoring data, and refresh when relevant game data is corrected.

Pitcher participation should remain historically clear. Reports should show which pitchers appeared in the game when that information is available and should preserve unknown or incomplete pitcher states when the user could not identify the pitcher during scoring.

Winning pitcher and losing pitcher may be supported where the saved game and product behavior provide enough information. When supported, these labels should be derived from the saved game record and should not be presented when ScoreKeep cannot determine them reliably.

## 6. Scorecards

Scorecards provide a traditional baseball scorekeeping view of the saved game. They should help users review batter sequence, inning progression, runner movement, defensive notation, scoring decisions, substitutions, and unusual plays.

A traditional scorecard should preserve the relationship between each batter and the inning in which the plate appearance occurred. It should show the sequence of batters in a way that supports historical review of how the game unfolded.

Batter sequence should follow the saved lineup, substitutions, corrections, and completed plate appearances. If a player entered as a substitute, appeared as a pinch hitter, pinch runner, or replacement, or participated under an incomplete identity, the scorecard should preserve that context where supported.

The inning layout should make clear which plate appearances occurred in each inning and half inning. Extra innings, shortened games, suspended games, and incomplete games should remain understandable without inventing artificial scoring events.

Runner progression should reflect saved runner movement, including bases reached, advances, outs on the bases, stolen bases, scoring plays, and corrections. A scorecard should not show runner advancement that conflicts with the saved scoring record.

Defensive notation should preserve recorded fielding information, outs, play notes, and scoring descriptions where supported. The notation should help explain the play but should not override the underlying scoring event.

Printable scorecards should reflect the saved game at the time they are generated. A printed scorecard is generated output from the game record, not a separate editable source of truth.

Scorecards should support historical review. A user returning to an old game should be able to understand the recorded sequence of events, including incomplete or unknown data, without the report silently replacing missing information with assumptions.

## 7. Reports

Game reports summarize one saved game. They may include final score or current score, line score, team totals, batting summaries, pitching summaries, scorecard information, notes, and supported generated output.

Team reports summarize team performance across a supported scope. They should identify the games, players, and dates included when that scope matters. Team reports should derive from saved game records rather than detached season totals.

Batting reports present offensive statistics for players. They may be game-specific or historical, depending on the selected scope. Batting reports should preserve the distinction between player totals, team totals, and game totals.

Pitching reports present pitcher participation and pitching statistics. They should handle multiple pitchers, unknown pitchers, pitcher corrections, and incomplete pitching data without implying unsupported certainty.

Summary reports provide compact views of important game, team, batting, or pitching information. They should use the same statistical meanings as detailed reports and should not introduce conflicting totals.

Historical reports review saved games over time. They should remain understandable after roster edits, player corrections, team changes, imports, and later application versions. Historical scope should be clear enough for users to know what games or records are included.

PDF reports may be generated where supported. A PDF report should be a generated representation of the saved game or selected reporting scope. It should reflect the current saved data at generation time and should not become the authoritative data record.

## 8. Report Generation

Reports may be generated when a user views a report, opens a completed or in-progress game, requests a scorecard, creates a PDF, exports output, shares output, prints output, or reviews historical statistics.

Report generation should use the current saved game record and related saved data. If a game is corrected after a report has been viewed or generated, affected reports should regenerate or clearly indicate that the previous output no longer reflects the current saved game.

Regeneration after corrections is required for dependent statistics and reports. Corrections to scoring events, runs, hits, outs, RBIs, stolen bases, pitcher assignments, earned-run decisions, lineups, substitutions, or player identities should update affected game statistics, scorecards, batting reports, pitching reports, box scores, and generated output.

Consistency is required across generated forms. A viewed report, exported report, shared report, printed report, and PDF report should not disagree when generated from the same saved data at the same point in time.

Exporting should preserve the meaning of the generated report. Exported output should identify enough context for the user to understand the game or reporting scope it represents.

Sharing should distribute generated output or compatible game data without changing the source game record. Sharing a report should not alter saved scoring data.

Printing should produce a representation of the saved report content. A printing failure should not change the saved game or mark the report as successfully preserved.

## 9. Corrections

Statistics after corrections should reflect the corrected saved game. If a correction changes a plate appearance, run, hit, error, RBI, stolen base, pitcher assignment, earned-run decision, lineup state, substitution, or game status, the dependent statistics should update accordingly.

Report regeneration should occur for affected report content after corrections. A user should not need to manually find and repair stale report totals after changing the saved game.

Historical consistency must be preserved. Corrections should change the relevant historical record intentionally, not create parallel versions of the same game with conflicting statistics unless a future feature explicitly supports versioned history.

User expectations should be clear. When the user corrects a completed game, ScoreKeep should treat the corrected saved game as the authoritative record going forward. Previously exported, printed, or shared reports may continue to exist outside the application, but newly generated reports should reflect the current saved game.

Reports generated before later corrections should not be treated as current inside the application. If ScoreKeep retains generated output, it should indicate when the output does not reflect the latest saved game data or should regenerate it from the current record.

## 10. Validation Requirements

Validation should protect the meaning of statistics and reports before presenting them as reliable.

Impossible statistics should be detected when report data cannot be reconciled with the saved game. Examples include runs that do not match scoring events, inning totals that do not match the final score, base states that cannot follow from recorded plays, or pitcher totals that cannot be attributed to any participation period.

Missing data should remain visible when it affects report interpretation. Reports should not silently fill missing player identity, pitcher identity, scoring details, inning context, or earned-run decisions with unsupported assumptions.

Incomplete games should be reported as incomplete, in progress, interrupted, suspended, shortened, or otherwise not final when the saved game status requires that distinction. Their statistics may still be useful, but reports should not present them as completed final records unless the user marks them that way.

Unknown players should be allowed in reports when the saved game includes unknown or incomplete participation. The report should preserve the uncertainty and should allow later correction through the game record where supported.

Unknown pitchers should be visible in pitching reports and game reports when pitcher identity or participation is incomplete. Unknown pitcher data should not be merged into a named pitcher without an explicit correction.

Unsupported values should be preserved or identified when imported or older game data contains scoring details that the current product cannot fully interpret. Reports should show what can be understood and avoid presenting unsupported values as if they were fully converted.

Imported games should be validated for compatible statistics, scoring events, lineups, substitutions, pitcher participation, and reportable totals. Import should preserve compatible statistics and identify incomplete or unsupported data that affects reporting.

## 11. Data Integrity Requirements

ScoreKeep must protect reporting integrity across scoring, correction, import, export, sharing, printing, and historical review.

- Reports must never become the source of truth.
- Statistics must always derive from saved game records.
- All report views for the same saved data must agree.
- Corrections must regenerate affected statistics, scorecards, reports, box scores, and generated output.
- Reports must never silently become stale.
- Imported games must preserve compatible statistics and identify unsupported or incomplete reporting data.
- Historical reports must remain understandable after roster edits, player edits, team edits, imports, substitutions, and corrections.
- Generated output must reflect the saved game or selected reporting scope at generation time.
- A report should not invent missing player, pitcher, inning, or scoring information.
- A generated PDF, printout, export, or shared file should not alter the saved game record.
- Rate statistics and totals should use consistent meanings across all reports.
- Incomplete games and incomplete statistics should remain distinguishable from completed, verified records.
- Corrections to completed games should update future reports without corrupting unrelated games.
- Deleted, renamed, imported, or merged teams and players must not make historical reports ambiguous.

## 12. Exceptional Situations

**Correcting completed games:** A user may discover a mistake after a game is marked complete. The correction should update the saved game and regenerate affected statistics and reports while preserving unrelated historical data.

**Regenerating reports:** A report may need to be regenerated after scoring corrections, lineup corrections, pitcher changes, player identity corrections, import repair, or game status changes. Regeneration should use the current saved record.

**Unknown pitcher:** If the pitcher is unknown for part or all of a game, pitching reports should show the unknown state rather than assigning the results to a named pitcher without support.

**Missing player:** If a scored participant cannot be identified, batting reports, scorecards, and game reports should preserve the missing or unknown identity and allow the saved game to be corrected where supported.

**Interrupted game:** An interrupted game may have useful partial statistics. Reports should show the game status and avoid presenting the result as a completed final game unless the saved status supports that conclusion.

**Imported historical game:** Imported games may contain older scoring conventions, incomplete player identities, unsupported values, or precomputed totals. Reports should preserve compatible meaning and identify uncertainty rather than silently rewriting history.

**Incomplete statistics:** Some reports may lack enough data for a statistic. Missing or incomplete values should be distinguishable from zero values.

**Printing failure:** If printing fails, the saved game and generated report data should remain unchanged. The user should not be led to believe a printed copy was successfully produced.

**Export failure:** If export fails, the saved game should remain unchanged and the report should not be marked as successfully exported.

**Report generated before later corrections:** A previously generated report may no longer match the saved game after corrections. New report views and generated output should reflect the corrected saved game, and any retained older output should be identifiable as older or regenerated.

# ScoreKeep Functional Specification — 12 Error Handling and Recovery

## 1. Overview

Error handling and recovery define how ScoreKeep responds when a user action cannot complete normally, when entered information is invalid or incomplete, when an external service is unavailable, or when the application is interrupted. The purpose is to protect baseball records, preserve user confidence, explain what happened, and keep the user close to the work they were doing.

An error message should make the current situation understandable. The user should know which action or record was affected, whether saved data changed, what can be done next, and whether it is safe to continue. ScoreKeep should avoid vague failure states that leave the user guessing whether a team, player, game, lineup, score, report, import, export, purchase, or preference was changed.

Live scoring has the highest need for speed and context preservation. Errors during a game should prevent misleading baseball states without interrupting the scorekeeper unnecessarily. When a problem does not affect the current play, current inning, current batter, outs, runners, or score, the application should let scoring continue and present the issue at a safe moment.

Error handling is part of the product experience. It must respect existing requirements for data ownership, offline operation, import review, compatibility, purchase honesty, accessibility, media fallback, and destructive-action confirmation. An error response is successful only when it leaves the user's baseball work coherent and recoverable.

## 2. Error-Handling Principles

ScoreKeep must never report success before an operation has actually completed. A team should not appear saved, an import should not appear applied, a purchase should not appear active, and an export should not appear available until the observable result is true.

Meaningful failure must not be hidden. If a requested action did not complete, the user should receive an understandable notice unless the failure is harmless, expected, and already represented by the current visible state.

User-facing errors should use baseball and product language rather than technical language. The user should not need to understand internal file details, purchase-system terminology, image decoding, or service mechanics to decide what to do next.

When an operation cannot complete, ScoreKeep should preserve the prior usable state. A failed save should keep the editable values available. A failed import should leave local records unchanged. A failed report should leave the source game unchanged. A failed purchase should leave the user's work and allowances intact.

Warnings and blocking errors must be distinct. A warning explains a condition the user may choose to accept, such as a missing optional player photo, incomplete pitcher assignment, or skipped optional imported data. A blocking error prevents completion because the saved result would be misleading, destructive, inaccessible, or incoherent.

Network and service failures must not block unrelated local work. If roster downloads, remote announcements, purchase checks, or external links fail, the user should still be able to create and edit local teams, score games, review saved records, generate reports from local data where allowed, and open compatible local files.

ScoreKeep should avoid repeated or cascading error messages. If several errors stem from the same root problem, the user should see a clear summary instead of a sequence of competing alerts. Repeated automatic retries should not create repeated interruptions.

Recovery should be proportional to the problem. A missing optional image should not require abandoning an import. A corrupted game file may require rejecting that import. A possible duplicate should require review before local data changes. A live-scoring inconsistency should require correction before the game is presented as current.

Error language should not blame the user. Messages should describe the condition and the next action, not assign fault.

An error should preserve context. The user should remain oriented to the selected game, team, player, import source, report scope, purchase action, or settings area that produced the error.

## 3. Error Categories

An informational notice confirms a condition that does not require correction, such as a canceled share sheet, a completed import with no conflicts, or an unavailable announcement that does not affect local work. It should not block the workflow longer than necessary.

A non-blocking warning identifies a condition that may affect completeness or presentation but does not make the saved result misleading. Examples include a report generated without optional media, a game with an unknown pitcher, or an imported older file with unsupported optional data. The user may continue after understanding the limitation.

A validation error prevents a form, scoring event, import choice, lineup, substitution, export, purchase action, or preference change from completing because required information is missing, contradictory, or unsafe. The error should identify the specific field, record, or scoring choice that needs attention.

A recoverable operation failure occurs when the requested action could not complete but the user can retry, choose another path, or keep editing. Examples include failed PDF generation, temporary file access failure, interrupted download, or a save failure where current values remain available.

A blocking data-integrity error occurs when continuing would risk damaging or misrepresenting baseball records. Examples include an impossible scoring state, unsafe roster replacement, import data that cannot be matched coherently, or a correction that would leave a game with contradictory inning and runner state. The user should be guided to a safe prior state or a focused repair choice.

A compatibility error occurs when a file or record cannot be safely understood by the current app. ScoreKeep should distinguish wrong file types, corrupted files, unsupported future files, malformed older files, and partially understandable records.

A network or service error occurs when ScoreKeep cannot reach or use an external dependency such as a roster download source, remote announcement source, purchase service, external website, or sharing destination. Local data should remain available.

A purchase-status error occurs when product details, purchase completion, entitlement recognition, restore behavior, or free-use allowance status cannot be confirmed. ScoreKeep should be honest about uncertainty and should not consume allowances or grant access without a confirmed basis.

A permission or access error occurs when the app cannot reach a user-selected photo, file, share destination, restricted Apple account capability, or device feature. The user should be able to choose another source, continue without the optional item, or return to unaffected work.

An unexpected application interruption occurs when ScoreKeep closes, is terminated, the device restarts, the window closes, or the user returns after a long absence. Recovery should restore the latest coherent work state that can be presented honestly.

## 4. Error Message Requirements

Error messages should use plain language with a clear title and concise explanation. The title should name the problem in product terms, such as "Game Not Saved", "Import Needs Review", "Purchase Could Not Be Confirmed", or "Photo Access Denied".

The message should identify the affected record or action when that matters. If a team, player, game, report, export, roster file, download, purchase, or setting was involved, the user should not have to infer which one failed.

The message should state whether data changed. If nothing was saved, say so. If some records were imported and others skipped, summarize that. If a report failed but the source game is unchanged, make that clear.

Recovery actions should be visible and specific. Useful actions include Try Again, Keep Editing, Cancel, Return to Game, Return to List, Choose Another File, Continue Without Image, Use Current Values, Skip Record, Save as Draft, Check Status, or Contact Support. A vague "OK" should be avoided when a clearer action exists.

Retry should appear only when retrying can reasonably help and can be performed safely. A corrupted file may need Choose Another File instead of Try Again. A temporary network timeout may support Try Again. A repeated purchase-status uncertainty may support Check Status or Return to Data.

A cancel or return path should be available unless the user must resolve the problem to avoid data loss or misleading game state. Canceling should leave unconfirmed changes unchanged.

Help or support should be offered when the user cannot reasonably resolve the problem from the current screen, when the same operation repeatedly fails, when purchase recognition remains uncertain, or when a compatible file appears damaged.

Raw technical codes must not be the primary explanation. Additional details may be available when they help troubleshooting, support, or file identification, but they should not replace the human-readable message.

## 5. Validation Errors

Team validation should identify missing or unusable team identity, unsafe duplicate resolution, invalid replacement choices, or destructive roster effects before saving. Valid entered details should remain in place so the user can correct only the affected value.

Player validation should identify missing player name, unsafe duplicate player match, ambiguous team assignment, invalid roster membership, or conflicting player details. Existing entered numbers, positions, batting information, photos, and notes should not be cleared because one field needs correction.

Roster validation should distinguish between incomplete but usable rosters and rosters that cannot be saved or imported coherently. Duplicate names and reused numbers should trigger review when ambiguous, not automatic rejection.

Game validation should identify missing teams, unclear game identity, invalid inning settings, unsafe duplicate game choices, or inconsistent game status. A draft game setup should be preserved when validation fails.

Lineup validation should identify missing batting order, duplicate active lineup positions, unavailable players, everyone-hits conflicts, or substitutions that make the lineup ambiguous. The user should see the affected lineup position or player.

Batting-order validation should preserve valid ordered players while identifying the missing, duplicated, skipped, or invalid slot. The user should not need to rebuild an entire batting order for one correction.

Pitcher validation should identify missing, unknown, conflicting, or impossible pitcher participation when it affects reports or scoring clarity. Missing pitcher information may be a warning when the game can still be scored, but impossible pitcher history should require correction before being treated as authoritative.

Substitution validation should identify the outgoing player, incoming player, team, lineup position, timing, and re-entry concern that prevents completion. Valid substitution context should remain available.

Scoring-event validation should identify the specific result, base, runner, out, RBI, earned-run, inning, batter, or pitcher condition that makes the play incomplete or impossible. The current play should remain editable.

Runner-state validation should prevent impossible base occupancy, such as two active runners on the same base, a runner active after scoring, or a runner active after being put out. The user should be guided to fix the affected runner or play.

Import validation should identify wrong file type, corrupted content, unsupported future data, malformed older content, duplicate records, ambiguous matches, invalid lineups, invalid pitcher history, impossible scoring data, unsupported values, or imported media issues before local records are changed.

Export validation should identify unavailable destinations, invalid export scope, unsupported output choice, or missing source data before starting output generation when possible.

Paste mapping validation should identify unmapped required fields, unusable rows, ambiguous columns, duplicate player results, or skipped lines while preserving the pasted text and valid mappings.

Report validation should identify missing report scope, unavailable source game, incomplete report inputs, premium gating, or output limitations. The source baseball data should remain unchanged.

Settings validation should identify unsupported preference values or reset choices before applying them. User preferences should not be cleared by a failed validation.

Purchase validation should identify product unavailable, price unavailable, status unavailable, wrong-season product, restricted account, or unavailable purchase service. The intended premium action should remain recoverable.

## 6. Live-Scoring Errors

If the wrong batter is selected or expected, ScoreKeep should let the user correct the batter before completing the play when the batting order would otherwise become misleading. If the play has already been completed, correction should preserve existing scoring context and explain any downstream effects.

If the wrong result is entered, the user should be able to edit the plate appearance and correct the result, bases reached, outs, RBIs, runner movement, earned-run state, and notes without rebuilding unrelated plays when practical.

If the wrong inning or half inning is active, ScoreKeep should prevent completion of new scoring events that would attach to the wrong game segment unless the user intentionally corrects or confirms the inning context.

If the number of outs is wrong, the application should identify whether the current play, prior play, or inning transition needs correction. It should not silently advance or rewind innings in a way that hides the issue.

Impossible base occupancy should block completion of the affected play until the base runners are understandable. The user should be able to choose which runner is safe, out, scored, or returned.

Duplicate play detection should warn when the same batter, result, inning, sequence, or scoring action appears to have been recorded twice. The user should be able to keep both only when the baseball context supports it, or remove the accidental duplicate without affecting unrelated plays.

A missing pitcher should not automatically block live scoring when the pitcher is unknown, but the missing status should remain visible and correctable. If pitcher assignment is required for a specific report or correction, the user should be asked to resolve it at that point.

An invalid substitution should not be applied if it would make lineup history, batting order, runner identity, or participation misleading. The user should be returned to the substitution choice with the current game context preserved.

An incomplete plate appearance should be recoverable. If the user leaves or the app is interrupted before completion, ScoreKeep should either preserve the draft play for completion or return to the last completed coherent game state.

A failed save during live scoring should be presented carefully. The application should state whether the play was saved, whether the previous game state is still active, and what the user can do next. It must not advance the visible game as if the failed play is authoritative.

If the app is interrupted during a play, returning should restore the latest coherent state: either the editable in-progress play when practical or the game state before that play began. Completed scoring events should not be lost silently.

## 7. Data-Operation Failures

Creating records should either create a coherent team, player, game, lineup, pitcher entry, substitution, or scoring event, or leave the prior list and form values available. A failed create should not leave an unnamed or misleading record as if it were valid.

Editing records should either apply the confirmed changes to the intended record or keep the prior saved record intact while preserving the user's editable values for correction. A failed edit should not partially rename or reassign unrelated baseball history.

Deleting records should require explicit intent and should either complete clearly or leave the prior record available. If deletion fails, the user should not be told the record is gone.

Saving games should leave a coherent saved game state. If saving cannot complete, ScoreKeep should make clear whether the latest scoring event, correction, lineup, pitcher change, or substitution was saved.

Applying corrections should identify affected scoring context. If a correction cannot be applied coherently, the original scored game should remain usable and the attempted correction should remain understandable for further editing or cancellation.

Replacing lineups should require confirmation and should protect historical scoring. If replacement fails or is canceled, the prior lineup should remain active.

Updating rosters should not silently remove players, photos, logos, team assignments, or historical participation. Failed roster updates should preserve the prior roster and the user's intended edits where practical.

Applying substitutions should either record a clear substitution history or leave the previous lineup and participation state intact. Failed substitutions should not strand a runner, batter, or lineup slot in an ambiguous state.

Recording pitchers should either preserve the intended pitcher participation context or leave the prior pitcher history visible. Failed pitcher changes should not assign plate appearances to the wrong player.

Resetting preferences should be explicit and reversible where practical. If a reset fails, the previous preferences should remain in effect and the user should know which reset did not complete.

## 8. Import and Compatibility Errors

A wrong file type should be rejected before local records change. The user should be told that the selected file is not a supported ScoreKeep roster or game file and should be offered Choose Another File or Cancel.

A corrupted file should be rejected when ScoreKeep cannot safely determine its baseball contents. If some high-level identity can be read, the message may include it, but the app should not invent missing teams, players, lineups, or scoring events.

A missing file or unavailable file should leave local records unchanged and return the user to file selection, import source selection, or the previous screen.

An unsupported future file should be handled honestly. If the file appears to come from a newer ScoreKeep format, the user should be told that this version cannot safely import it. Local records should remain unchanged.

A malformed older file should be imported only when the resulting record remains understandable. Older files with missing optional content may be imported with warnings. Older files with missing required baseball identity or impossible scoring data should require repair, skipping, or rejection.

A partial file should not be treated as a command to delete local data. ScoreKeep may allow repair, import usable records with warnings, skip selected records, or reject the file depending on whether the remaining data is understandable.

Duplicate rosters and duplicate games should trigger review. The user should be able to keep both, update selected values where supported, skip the incoming record, or cancel. ScoreKeep should not silently merge unrelated records by name alone.

Ambiguous team or player matches should require visible comparison and user choice. Similar names, reused numbers, changed photos, and changed teams are normal and must not force automatic merging.

Invalid lineup history, invalid pitcher history, impossible scoring data, and unsupported scoring values should be identified before import is applied. ScoreKeep should reject the unsafe record or preserve it only with warnings that make the limitation clear.

Imported media errors should not crash import review. Missing, unreadable, corrupted, unsupported, or oversized photos and logos may be skipped, replaced, kept current, or imported with warnings according to the user's choice and the safety of the baseball data.

ScoreKeep should preserve unknown data only when doing so avoids misleading the user. Unknown participants, unsupported optional values, and incomplete historical context should remain visible rather than being silently converted into incorrect known facts.

Local records should remain unchanged until the user confirms the import result. If import fails after confirmation, the completion message should make clear what, if anything, changed and what remains unresolved.

## 9. Export, Sharing, and Report Failures

Failure to create an export should leave the selected team, roster, game, score, lineup, pitcher history, substitutions, photos, logos, purchase state, and preferences unchanged.

Failure to save to Files should distinguish between output-generation failure and destination failure. If the export was generated but could not be saved to the selected destination, the user should be able to choose another destination or cancel without changing source records.

Share sheet cancellation is not an error. The user should return to the report, export, game, roster, or sharing screen with source data unchanged.

Share destination failure should explain that the selected destination could not receive the item. ScoreKeep should offer another share path or return to the source workflow when appropriate.

PDF generation failure should identify the selected report, game, or scorecard scope and state that the source baseball data was not changed. Missing optional media should normally produce a warning or fallback rather than a failed PDF when a text-only output remains understandable.

Report generation failure should preserve the report scope and source records. The user should be able to adjust the scope, retry, return to the game, or continue reviewing data.

Printing failure should not alter the generated report or source records. The user should be able to retry printing, share another way, or return to the report.

Unavailable destinations and interrupted output generation should leave the user at a recoverable point. The user should not need to reselect unrelated teams, games, date ranges, or report options after a transient output failure.

## 10. Network and Download Errors

No Internet connection should be explained in ordinary language for network-dependent workflows such as roster downloads, remote announcements, purchase checks, and external links. Local scoring, local rosters, local reports, local imports, and saved records should remain available.

Server unavailable and timeout conditions should support Try Again when retrying may succeed. The user should also be able to return to local work without repeated prompts.

An invalid roster manifest should prevent roster download selection from proceeding until a valid roster list is available. The error should not reduce download allowances or alter local rosters.

A missing roster file should identify the selected roster when possible and should not create a partial team unless the user later imports a valid file.

Download interruption should preserve the user's selected roster source and free-use or premium context. Retrying should not create duplicate downloads, duplicate imports, or repeated allowance reduction.

If a website or service returns the wrong content, ScoreKeep should reject it as unsupported or invalid and leave local records unchanged.

Remote announcement failure should be quiet and non-blocking unless the announcement was directly requested. Announcements should never block live scoring or local data review.

Retry behavior should be visible and bounded. ScoreKeep may offer Try Again, but it should not keep retrying in a way that creates repeated alerts, repeated allowance changes, or unclear status.

Offline local operation should remain the default expectation for core workflows. Network failure must not prevent unrelated local scorekeeping, game review, correction, report review based on local data, or compatible local file handling.

## 11. Purchase and Licensing Errors

If a product is unavailable, ScoreKeep should say that current-season premium access cannot be offered right now. The user's intended action should remain available to resume after product information becomes available when the action is otherwise allowed.

If a price is unavailable, ScoreKeep should not invent or reuse stale pricing as a purchase promise. The paywall should state that the price could not be loaded and should offer retry or return actions.

Purchase cancellation should not be presented as a failure. The user should return to the prior workflow with current work preserved and no allowance reduction.

Purchase failure should explain that the purchase did not complete and should not grant access, reduce free allowances, change existing saved records, or discard the intended premium action.

Purchase pending should be shown as unresolved rather than successful. The user should know that access may not be available yet and should be able to check status later.

If purchase succeeds but access is delayed, ScoreKeep should state that purchase status is being confirmed and should not require the user to repeat paid actions unnecessarily. Existing work should remain intact.

If status checking is unavailable, ScoreKeep should distinguish uncertainty from no purchase found. It should not reset recognized access without a clear basis, and it should not consume allowances because status could not be checked.

Prior-season and wrong-season products should be labeled clearly. A prior-season purchase should not be shown as active current-season access, and a future or wrong-season product should not be sold or activated as if it covered the user's intended current action.

Restore or recognition uncertainty should be honest. The user should be guided to check status, verify account context where appropriate, return to local data, or contact support without losing work.

Incorrect free allowance display should be handled conservatively. ScoreKeep should not reduce a counter below zero, should not make the user's access worse because of display uncertainty, and should offer status check or support when the allowance appears wrong.

## 12. Permission and Access Errors

Photo access denied should explain that ScoreKeep cannot select the requested image source. The user should be able to continue without an image, keep the existing image, choose another available source, or return to the team or player form.

File access denied should leave local records unchanged and return the user to the import, export, or sharing context. The user should be able to choose another file or destination when available.

If a selected file is no longer available, ScoreKeep should state that the file cannot be opened now and should offer Choose Another File or Cancel. Import review should not apply stale or partial data.

If a share destination is unavailable, ScoreKeep should keep the generated item or source context available when practical and let the user choose another destination or return.

A restricted Apple account should be explained in terms of unavailable purchase or account services. Local data should remain accessible.

If purchase services are unavailable, ScoreKeep should preserve the intended premium action and allow local data review. It should not present the failure as a completed purchase or as proof that no purchase exists.

If an external link is unavailable, ScoreKeep should let the user stay in the current ScoreKeep workflow. Help, purchases, announcements, and downloads should not leave the app in a dead-end state.

Unsupported device capability should be presented as a feature limitation, not a data error. Unaffected ScoreKeep features should remain usable.

## 13. Unexpected App Interruption

If the app closes unexpectedly, returns from background after termination, the device restarts, battery is lost, the device sleeps, a window or scene closes, an app update occurs, or the user returns after a long interruption, ScoreKeep should restore the latest coherent work state it can present honestly.

An in-progress game should reopen with the saved scorekeeping context: selected game, current inning, top or bottom half, outs, base runners, current batter, batting order context, current pitcher when known, score, recent completed plays, and completion or interruption status.

Completed scoring events should remain completed. Recovery should not duplicate the last play, drop a completed play silently, advance the batting order twice, or lose runs and outs that were already confirmed.

If interruption occurred during a plate appearance, ScoreKeep should restore either the editable draft play or the prior completed game state. The app should make the state clear so the user does not unknowingly score the same play twice.

Draft game setup should preserve selected teams, date, location, inning count, lineup setup, and other entered values where practical. If a draft cannot be restored fully, the user should know what remains missing.

Lineup preparation should preserve selected players, batting order, everyone-hits choice, pitcher preparation, and unresolved validation messages where practical.

Forms should preserve valid entered values after interruption when practical. Returning should not clear a team name, player details, paste mapping, report scope, or settings choice without warning.

Import review should be preserved where practical, including selected source, detected records, conflicts, chosen resolutions, warnings, and unapplied status. If the source file is no longer available, local records should remain unchanged and the user should be told that review cannot continue.

Report scope should be preserved where practical, including selected game, team, player, date range, report type, and output choice. Interrupted output generation should not alter source data.

Recovery should avoid false certainty. If ScoreKeep cannot determine whether the last requested action completed, it should show the safest known state and guide the user to verify or retry without duplicating data.

## 14. Retry Behavior

Retry is appropriate when the likely problem is temporary and retrying can be done without duplicate records, duplicate scoring events, repeated allowance reduction, or destructive side effects.

Network downloads may offer Try Again after connection loss, timeout, server unavailability, missing response, or interrupted transfer. Retrying should preserve the selected roster and should not count as a successful download until the roster file is actually available for the intended workflow.

Product loading and purchase status checks may offer Try Again or Check Status. Retrying should not imply purchase success and should not consume free allowances.

Exports and report generation may offer Try Again when the source data remains available and the previous attempt did not change source records. If the destination failed, Choose Another Destination may be clearer than Try Again.

Image selection may offer retry when the image source is temporarily unavailable or the selected image cannot be read. The user should also be able to choose another source, keep the existing image, or continue without image.

File access may offer retry when access might be restored. If the file is gone, moved, unsupported, or denied, choosing another file is the safer action.

Failed saves may offer retry only when repeating the save cannot create duplicates, advance scoring state again, reduce counters again, or apply conflicting partial changes. If retry cannot be guaranteed safe from the user's perspective, the app should preserve editing state and guide the user to a safe correction or return path.

Automatic retry loops should be limited and should not repeatedly interrupt the user. The user should see clear retry status, a cancel or return option, and preservation of previous work.

## 15. Recovery Choices

Try Again should repeat the same requested action when retrying is safe and likely useful.

Keep Editing should return the user to the current form, scoring event, lineup, substitution, import review, report scope, or settings screen with entered values preserved.

Cancel should abandon unconfirmed work and leave saved records unchanged. If canceling would discard meaningful entered work, the user should be warned.

Return to Game should take the user back to the selected game and latest coherent scoring or review state.

Return to List should take the user back to the relevant game, team, player, report, or import list with search, sort, filter, and selection context preserved where practical.

Use Current Values should preserve existing local values when imported, downloaded, or conflicting data cannot safely replace them.

Skip Record should omit a selected imported team, player, game, media item, or row while preserving other review choices when the remaining import stays understandable.

Choose Another File should reopen the relevant file-selection path after wrong type, missing file, access denial, corruption, or unsupported content.

Continue Without Image should let the user complete a team, player, import, report, export, or scorecard without optional media.

Save as Draft should preserve meaningful incomplete setup, lineup, import preparation, or report scope when completion is blocked but the work can remain useful later.

Contact Support should be offered when recovery is unclear, repeated failures occur, purchase status remains uncertain, or a compatible user-owned file appears damaged.

Recovery actions should use specific labels. "OK" may be acceptable only for simple informational notices where no better action is available.

## 16. Partial Success and Warnings

When an operation completes with warnings, ScoreKeep should summarize what succeeded, what was skipped, what remains unresolved, whether local data changed, and what the user should do next.

A roster import with skipped players should identify the imported team, the number of players imported, the skipped players when names are available, and whether local records were created or updated. Skipped players should not be silently lost from the user's understanding.

A game import with unknown participants should preserve the game only when it remains understandable. The completion summary should identify unknown teams, players, pitchers, substitutes, or runners that need review.

A report generated without optional media should state that the report was created and that missing logos or photos were omitted. The source game, roster, and media records should remain unchanged.

A download that completes but requires import review should not be presented as a completed roster import. The user should understand that the file is available for review and that local roster records have not changed until import is confirmed.

A historical file with unsupported optional data may be imported with warnings when the baseball record remains understandable. The summary should explain which optional information could not be used.

A save completed with unresolved non-blocking information should be honest. For example, a game may be saved with an unknown pitcher or incomplete earned-run decision if the uncertainty remains visible for later correction.

Partial success should never hide destructive effects. If records were created, updated, skipped, or left unchanged, the completion summary should say so in ordinary language.

## 17. Destructive Failure Protection

Any operation that could delete data, replace a roster, replace a lineup, reassign historical participation, merge records, apply an import, remove media, reset preferences, or delete a completed game must require explicit user intent before the destructive effect occurs.

The confirmation should name the affected record or workflow. Users should see which team, player, game, lineup, import, media item, preference group, or completed game is affected.

If a destructive operation fails, the prior state should remain usable. A failed roster replacement should leave the previous roster intact. A failed lineup replacement should leave the previous lineup active. A failed media removal should leave the previous image or placeholder state clear.

If a destructive operation is canceled, unconfirmed data should remain unchanged. Canceling import application should leave local teams, players, games, photos, logos, lineups, substitutions, pitcher records, and preferences as they were before confirmation.

Merge and reassignment operations require special care. If ScoreKeep cannot show the user what records will be combined or reassigned, the operation should not proceed.

Deleting a completed game should be treated as high impact. If deletion fails or is canceled, the completed game should remain visible and usable.

Destructive failure protection applies even when the original problem was an error. Recovery should not require risky cleanup, forced deletion, or silent replacement unless the user clearly chooses it.

## 18. Support and Diagnostic Information

ScoreKeep should offer support when the user cannot reasonably recover from the current screen, when a compatible file cannot be imported, when purchase recognition remains uncertain, when the same action repeatedly fails, or when local data appears inconsistent after interruption.

Support guidance should help the user describe the affected workflow in human terms: creating a game, scoring a play, importing a roster, exporting a game, generating a report, checking purchase status, selecting a photo, or opening a file.

When appropriate, the user may be asked to provide the app version, device type, operating-system version, affected team, affected game, file name, approximate time of failure, selected action, and human-readable error summary.

Support information should be privacy-conscious. The user should not be required to share player photos, private rosters, full game files, purchase details, or personal information unless they choose to do so for troubleshooting.

The user should not need to understand internal mechanics. Any detailed information offered for support should supplement, not replace, the plain-language explanation.

This specification defines only the user-facing support behavior and information expectations.

## 19. Accessibility Requirements

Errors, warnings, notices, and recovery actions must be readable by VoiceOver. The message should identify the affected record, severity, and available actions without relying on visual position alone.

When validation fails, focus should move to or identify the relevant field, lineup position, player, runner, import conflict, purchase action, report scope, or settings choice where practical.

Larger text should be supported without hiding the error title, explanation, affected record, and recovery actions. Critical actions should remain reachable.

High contrast and color-independent severity are required. Blocking errors, warnings, and informational notices should not be distinguished only by color. Text, icons, labels, or layout should communicate severity.

Recovery actions must be accessible through assistive technologies and external input methods where supported. Button labels should be specific enough to make sense when read out of visual context.

Critical messages should not disappear before they can be understood. Non-transient messages are required when data may not have changed as expected, when a game state is inconsistent, or when a destructive action failed.

ScoreKeep should avoid rapid repeated announcements. If several errors occur together, a summary should be presented rather than a stream of overlapping alerts.

For accessibility users during live scoring, recovery should clearly state the current game state after an error: inning, half inning, outs, runners, batter, pitcher when known, score, and whether the last play was saved.

## 20. Error State Preservation

After an error, ScoreKeep should preserve the selected game when the error occurred in game setup, live scoring, correction, report generation, export, or game review.

The selected team should remain available after team editing, roster management, logo selection, import conflict review, report filtering, or export failure.

The selected player should remain available after player editing, photo selection, lineup assignment, substitution selection, pitcher selection, paste review, or import conflict failure.

Current form values should remain available after validation errors, failed saves, permission denials, network failures, purchase gates, and interruptions unless the user explicitly discards them.

Search and sort context should remain available after returning from errors in lists, details, import review, report selection, and sharing.

Draft lineup context should be preserved after validation errors, substitutions, pitcher changes, interrupted setup, or failed save.

Current scoring state should be preserved after scoring validation errors, failed play saves, app interruption, correction failure, or invalid substitution.

Import review should preserve the selected source, parsed records, conflicts, choices, warnings, and unapplied status when practical.

Export scope and report scope should remain available after output failures, destination failures, share cancellation, premium gating, or permission issues.

The intended premium action should be preserved after paywall dismissal, purchase cancellation, purchase failure, product loading failure, or status uncertainty.

Download selection should remain available after network failure, invalid manifest, interrupted transfer, wrong content, or purchase gating, unless the source is no longer available.

The user should not need to reconstruct unrelated work after resolving an error.

## 21. Validation Requirements

The error-handling experience itself should be validated against false success messages. ScoreKeep must not state that a record, import, export, report, purchase, or save succeeded when the visible result did not complete.

Every blocking error should provide at least one useful recovery action. A dead-end alert that only dismisses itself without preserving context is not acceptable for meaningful failures.

Repeated alert loops should be prevented. If the same error appears again immediately after dismissal, the app should provide a stable path such as Keep Editing, Cancel, Return to Game, or Contact Support.

Contradictory status messages should be avoided. The app should not show "Saved" and "Save Failed" for the same action without explaining the distinction.

Errors must not hide current work. A message should not trap the user away from an active game, import review, form, report scope, or purchase action unless staying would risk data loss or misleading state.

Retry must not duplicate data. Repeating a failed create, import, scoring event, export, download, or allowance-sensitive action should not create duplicate records or repeated counter reductions.

Warnings must not be presented as blocking errors when the user can safely continue. Blocking errors must not be presented as harmless warnings when continuing would make records misleading.

Technical messages without user explanation are not acceptable as the primary error presentation.

Error actions must target the correct record. A recovery action opened from one game, team, player, import, report, or purchase action should not apply to another without clear user selection.

An error should disappear or update after successful recovery. Stale errors should not continue to imply failure after the user has resolved the problem.

When multiple errors compete for presentation, ScoreKeep should prioritize the one that most affects data integrity, live scoring state, or the user's current action. Lower-priority notices may be summarized or deferred.

Critical messages should remain available long enough to be understood. If a critical message cannot be displayed normally, ScoreKeep should use the safest fallback: preserve current work, avoid changing data, and return the user to a coherent state with a visible explanation when possible.

## 22. Data Integrity Requirements

Errors must never silently change baseball data.

Failed actions should leave a usable prior state. If the action cannot complete coherently, the previous game, team, player, roster, lineup, pitcher history, substitution, report scope, import review, or preference state should remain understandable.

Canceled operations should leave unconfirmed data unchanged.

Retry must not duplicate records, scoring events, imports, downloads, exports, or allowance changes.

Failed purchases must not consume free allowances, grant false access, or erase recognized valid access.

Failed exports must not modify source teams, players, games, lineups, scoring events, media, reports, purchases, or preferences.

Failed imports must not partially merge unrelated records. If an import partially succeeds, the completion summary must identify what changed and what did not.

Error presentation must not advance innings, batters, scores, runners, pitcher responsibility, substitution history, or game completion status.

Recovery must never invent missing baseball facts. Unknown pitchers, unknown players, missing lineup details, incomplete scoring context, and unsupported imported data should remain visible or require user resolution.

User-owned data must remain accessible during service failures. Network, purchase, announcement, external-link, and remote-roster failures must not lock local records.

Error handling must not reset purchase state, free allowances, settings, photos, logos, or preferences unintentionally.

A recovered workflow must remain coherent and understandable. The user should be able to continue from a clear game state, form state, import state, report state, or list state.

## 23. Exceptional Situations

When multiple errors occur together, ScoreKeep should present the highest-impact issue first and summarize related lower-impact issues. Data-integrity and live-scoring errors take priority over notices, announcements, optional media warnings, or background service failures.

When an error appears during live scoring, the app should avoid blocking the scorekeeper unless the current game state would become misleading. Non-urgent errors should be deferred or summarized at a natural stopping point.

If an error appears behind another sheet or while another alert is visible, the user should not miss it. ScoreKeep should present a coherent sequence or summary after the current focused task is resolved.

If the app closes before the user responds to an error, returning should restore the safest known state and, when needed, repeat or summarize the unresolved issue. It should not assume the user accepted a destructive or ambiguous action.

If the same operation repeatedly fails, ScoreKeep should stop treating each attempt as a new surprise. It should offer a clearer path such as Keep Editing, Choose Another File, Return to Game, Check Status, or Contact Support.

If an error message itself cannot load supporting details, ScoreKeep should still provide the basic plain-language problem, state that the details are unavailable, and preserve work.

If the recovery target has been deleted or is no longer available, the app should explain that the original record or source cannot be found and return the user to the nearest safe list, game, team, import, or report context.

When network returns after an offline error, ScoreKeep may let the user retry the network-dependent action, but it should not automatically apply imports, purchases, downloads, or destructive changes without user confirmation.

When purchase status changes after an error, ScoreKeep should update the visible status honestly and return the user to the intended action when that action can continue safely.

If an import source disappears during review, local records should remain unchanged unless the user had already confirmed a completed import. The user should be told that review cannot continue from the missing source.

If the user chooses to continue with warnings, ScoreKeep should preserve those warnings where they affect later understanding. Continuing with unknown participants, missing optional media, or unsupported optional historical data should not convert warnings into false completeness.

If the user cannot complete recovery immediately, ScoreKeep should preserve current work where practical and provide a safe return path. The user should not be forced into destructive cleanup or repeated prompts simply because recovery must happen later.

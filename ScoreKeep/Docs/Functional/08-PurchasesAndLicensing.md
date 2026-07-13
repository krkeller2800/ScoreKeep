# ScoreKeep Functional Specification — 08 Purchases and Licensing

## 1. Overview

Purchases and licensing define how ScoreKeep offers premium access while preserving a useful free scorekeeping experience. The purchase model supports continued development of the application, roster-download services, reporting improvements, compatibility maintenance, and long-term preservation of ScoreKeep workflows.

Premium access should expand what a user can do during the current baseball season without turning the application into a recurring subscription product. Users should understand what is free, what requires premium access, which season the purchase covers, and what happens when that season ends.

Licensing behavior must protect user ownership of existing data. A purchase requirement may limit creation of new premium output, expanded convenience features, or additional use beyond free allowances, but it must not lock users out of their own teams, players, games, scoring records, compatible files, corrections, or exported data.

The purchase experience should be honest and low-friction. ScoreKeep should explain why access is limited, show the correct season and price before purchase, preserve the user's current work, and return the user to the intended feature after purchase, cancellation, or failure when that remains appropriate.

## 2. Product Model

ScoreKeep uses a current-season premium model. A user may purchase premium access for the baseball season currently supported by the application. That access expands the user's available capabilities for the relevant season period, including gated creation, reporting, PDF, roster-download, or other premium conveniences defined by product rules.

The purchase is not a recurring subscription in user-facing terms. It does not automatically renew, and users should not be told to expect automatic billing in a future season. Each season's premium access is a separate purchase opportunity when that season is offered.

The access period should be clear before purchase. The product presentation should identify the season, the effective access period, and any known expiration behavior in ordinary language. The current baseline treats a season purchase as active through the end of the purchased season period.

Future-season purchases may be offered when a new season becomes available. A future-season purchase should not confuse users about access to the current season, and a current-season purchase should not imply automatic access to future seasons unless a future product rule explicitly grants it.

Existing-season access should remain understandable after the season changes. A prior-season purchase may remain visible as purchase history or as an expired entitlement, but it should not be presented as active current-season premium access after its season period ends.

Pricing should be presented clearly before the user purchases. The user should see the price supplied for the current-season product and should not need to infer cost from promotional copy, outdated documentation, or prior seasons. The current baseline StoreKit configuration uses a displayed price of `4.99` for the 2025 and 2026 season passes; this is a current default, not a guarantee that every future season will use the same price.

Product naming should be season-specific and direct. User-facing names should communicate that the purchase is a ScoreKeep season pass or current-season premium access for a named year or season. Product text must avoid confusing subscription language, renewal promises, or claims that future purchases are automatic.

Existing compatible product identifiers and season meaning must remain supported where they are part of current user expectations, purchase recognition, App Store history, or migration behavior.

## 3. Free Experience

Free users should retain meaningful core ScoreKeep functionality. The free experience should allow users to learn the app, prepare teams, score within supported allowances, review their saved records, move their own compatible files, and keep local baseball data useful over time.

A free user should be able to access existing teams and players. Existing roster records should remain viewable and editable, including corrections to names, numbers, positions, batting information, team details, photos, logos, and other supported roster information.

A free user should be able to access existing games. Saved games should remain visible in the game list, reviewable, correctable, and usable as historical records. The user should be able to open completed, interrupted, imported, or in-progress games that already belong to them.

A free user should be able to view and correct existing data. Corrections to existing teams, players, games, lineups, substitutions, pitchers, scoring events, notes, and statistics must not be blocked merely because premium access is inactive.

A free user should be able to use core local scorekeeping within the supported free limit. Creating and scoring new games may be limited by a free allowance, but games created within the free allowance should be usable for ordinary scoring, saving, review, and correction.

A free user should be able to import compatible user-owned data. Compatible ScoreKeep roster and game files received from another app, another device, a backup, or another ScoreKeep user should remain importable when the import workflow is otherwise supported. Import review of user-owned compatible files must not become a premium-only data recovery path.

A free user should be able to export user-owned compatible data. Exporting existing roster and game data in compatible ScoreKeep formats should remain available so users can preserve, transfer, or back up their own records. Premium rules may limit generated premium output such as specialized PDFs or reports, but they must not prevent users from moving their own compatible baseball records.

A free user should be able to open existing ScoreKeep files. Opening `.ScoreKeep_Players` and `.ScoreKeep_Games` files should route to validation and review rather than to a purchase requirement.

A free user should be able to review existing statistics and game history where those views are not specifically premium-gated. If a particular generated report is premium-gated, the gate must not block ordinary access to the underlying game, score, roster, or scoring corrections.

A free user should retain offline access to local data. Existing local teams, players, games, scoring history, imports, and compatible files should remain available without Internet or Apple purchase-service access.

Free limits may restrict creation of new records beyond an allowance or generation of premium output. They must not become data locks. The governing principle is that purchase state can limit future premium activity, but it cannot take away access to user-owned records that already exist.

## 4. Premium Capabilities

Premium access may be required for capabilities that expand ScoreKeep beyond the free experience. These capabilities should be discoverable, clearly labeled when gated, and explained in terms of the added value they provide.

Established premium examples include creating games beyond the free allowance. The current baseline allows a free user to create a limited number of games before premium access is required for additional new game creation.

Premium access may be required for generating premium reports. Batting reports, pitching reports, summary reports, historical reports, or other enhanced reporting experiences may be premium-gated when the product design designates them as premium output.

Premium access may be required for generating scorecard PDFs or other shareable PDF output. This gate may apply to newly generated premium output, but it must not prevent the user from viewing, correcting, or exporting their own compatible source game data.

Premium access may be required for expanded MLB roster downloads. The current baseline allows a free number of MLB roster downloads and then requires premium access for additional downloads.

Premium access may be required for other explicitly designated premium conveniences, such as expanded download sources, advanced report formats, additional generated output, or time-saving features that do not block ownership of existing data.

This specification defines product behavior and gating principles. It does not permanently guarantee that every named feature must always be premium-gated. Future product decisions may move a capability into or out of premium access as long as free-user data rights, compatibility, honest messaging, and seasonal purchase expectations remain protected.

## 5. Purchase Workflow

The purchase workflow usually begins when a user discovers a premium feature. The user may tap a gated report, attempt to create a game beyond the free allowance, request a scorecard PDF, try to download an MLB roster after the free allowance has been used, or open an upgrade entry point directly.

Before purchase, the application should explain why access is limited. The explanation should connect the gate to the user's intended action, such as additional game creation, premium report generation, scorecard PDF generation, or expanded roster downloads. The message should avoid blaming the user or hiding the reason behind generic errors.

The paywall should show the correct season and price. It should identify the current-season premium access being offered, the season period it covers, and the price available at the time of purchase. If the product or price cannot be loaded, the paywall should say that purchase is unavailable rather than inventing a price or confirming access.

The user should be able to start the purchase from the paywall. While purchase confirmation is pending, ScoreKeep should show a waiting or processing state that does not imply success before confirmation.

On successful purchase confirmation, active premium access should be reflected promptly. The user should be told that access is available and should be returned to the intended feature when that workflow can continue safely.

If the user cancels, the app should return to the previous workflow without treating cancellation as an error. The intended feature may remain unavailable if premium access is still required, but the user's current game, lineup, scoring, import, export, or report work should remain intact.

If the purchase fails, the app should show a clear failure message and leave the prior state unchanged. The user should be able to retry when appropriate, check status when appropriate, or return to their data without losing work.

If purchase status is uncertain, the app should state that access could not be confirmed. It should not show premium access as active without a confirmed basis, and it should not consume free allowances because a purchase attempt failed, was canceled, or remained unresolved.

The user should not lose work when encountering a purchase gate. Gating should occur before a gated action begins, after preserving current work, or at a safe transition point. The user should be able to return to the intended feature after purchase or cancellation without reconstructing a game, lineup, scorecard, import review, report selection, or roster selection.

## 6. Entitlement Behavior

After a successful purchase, active premium access should become available for the relevant season. The user should be able to use gated premium capabilities without repeatedly seeing the paywall for the same active entitlement.

Premium access should remain active through the end of the relevant season period. The current baseline treats a season pass as valid until the end of the purchased calendar year, but the product requirement is that the access period be presented clearly and honored consistently.

Recognized premium access should persist across ordinary app launches. Closing and reopening ScoreKeep should not require the user to purchase again when active access is already recognized.

Recognized premium access should persist after device restart. Restarting the device should not erase active access from the user's perspective when the application has a confirmed basis for continuing access.

Recognized premium access should remain available while temporarily offline. If the app already recognizes active current-season access, a temporary network or Apple-service outage should not unnecessarily remove access.

Expired access should be handled clearly. When the purchased season period ends, gated premium capabilities may require a new current-season purchase, but existing local data and existing compatible files must remain accessible.

Future-season purchase behavior should be explicit. If a future-season product is available before or during a transition period, the app should make clear which season the user is buying and when that access applies.

Previously purchased season behavior should distinguish history from active access. A prior-season purchase may explain why the user had premium features in the past, but it should not be represented as active current-season access once expired.

Purchase status uncertainty should be shown honestly. If the app cannot determine whether access is active, it should present the uncertainty, allow checking status when possible, avoid false confirmation, and preserve user data. It should not silently delete entitlement history or consume allowances because status could not be verified.

This specification does not prescribe storage, receipt validation, transaction handling, or entitlement algorithms. It defines how entitlement state should appear and behave from the user's perspective.

## 7. Restoring and Checking Purchase Status

ScoreKeep should give users a clear way to check purchase status. This action should be separate from buying again and should be labeled in a way that distinguishes status checking from a new purchase.

When a user reinstalls the app, ScoreKeep should help them understand whether current-season premium access can be recognized for the same Apple account. If status cannot be confirmed automatically, the app should explain the limitation and offer an appropriate status-check path.

When a user moves to another device, the app should communicate that purchase status may depend on the same Apple account and the nature of the season purchase. It should not imply that access has been restored until active access is actually recognized.

Using the same Apple account should be the expected path for checking prior purchase status. If the user is signed into a different Apple account, the app should explain that purchase status may not match the account that made the purchase.

Non-recurring purchase limitations must be communicated honestly. A season purchase should not be described like an auto-renewing subscription that automatically follows the user forever. If the platform does not guarantee automatic restoration in the same way as other purchase types, the app should avoid stronger claims than it can verify.

The application should distinguish between checking status and purchasing again. A user concerned about duplicate purchase should be guided to check status before buying when practical. The purchase button should not be the only visible path when the user believes they already bought current-season access.

When status checking succeeds, ScoreKeep should show the recognized active access or clearly state that no active current-season access was found. When checking fails because Apple services, network access, account state, or device state are unavailable, the app should say that status could not be checked rather than claiming no purchase exists.

The application must avoid false claims that access has been restored. Restoration, recognition, or activation should be shown only when the app has a confirmed basis for active current-season access.

## 8. Free-Use Limits

Free-use limits describe allowances available without active premium access. They should be framed as product allowances, not as hidden penalties or irreversible locks.

The free game creation allowance lets a free user create a limited number of new games. The current baseline default is two free user-created games. This number is a current product default rather than an immutable architectural constant.

A game should count against the free game creation allowance only after a qualifying new game creation succeeds. Opening an existing game, editing an existing game, correcting scoring data, viewing reports, importing an existing user-owned game file, canceling game creation, or failing validation should not reduce the allowance.

Duplicate game creation attempts should not accidentally consume extra allowance. If the app detects that a creation attempt failed, was canceled, was not saved, or resulted in the user keeping the prior state, the counter should not be reduced.

The free MLB roster download allowance lets a free user download a limited number of roster files from the supported MLB roster-download workflow. The current baseline default is four free downloads. This number is a current product default rather than an immutable architectural constant.

A roster download should count against the free MLB roster download allowance only after a qualifying download succeeds far enough to provide the user with the intended roster file or enter the supported import path. Merely viewing the roster list, selecting a team, failing to load the manifest, losing network connection, canceling, or receiving an invalid file should not reduce the allowance.

Canceled operations should not reduce allowances. Failed operations should not reduce allowances. Operations blocked before they begin should not reduce allowances. Retrying after a failure should not reduce allowances until a qualifying action succeeds.

Duplicate attempts should be handled carefully. If the same roster is requested repeatedly because of an error, slow connection, unclear confirmation, or app interruption, the app should avoid accidental repeated counter reduction.

Reinstallation expectations should be honest. Free-use allowance state may not necessarily reset just because the app is reinstalled, and it may not necessarily be recoverable in every device or account condition. The user should receive clear messaging when the app can determine remaining uses and honest uncertainty when it cannot.

Remaining-use messaging should be clear before a user reaches a limit. ScoreKeep should show remaining free games or downloads in ordinary language when the allowance affects an action. At zero remaining uses, the app should explain that premium access is required for additional qualifying actions.

Free counters must not drop below zero. If a counter appears incorrect, the app should avoid making the user's situation worse and should offer a clear path to retry, check purchase status, or contact support.

Debug, testing, review, or development behavior must not affect production user allowances. Test resets, simulated counters, and sandbox purchase behavior must not reduce or distort real production allowances.

## 9. Premium Gating Rules

A paywall may appear before a gated action begins. For example, it may appear before creating an additional game beyond the free allowance, before generating a premium report, before creating a scorecard PDF, or before downloading an MLB roster after the free allowance has been used.

A paywall may appear at the point where a free limit is reached. The user should be told that the free allowance has been used and that premium access is required for additional qualifying actions.

A paywall may appear after preserving current work. If the user reaches a gate from game setup, live scoring, report selection, import review, or roster download, the app should preserve enough state for the user to return without rebuilding the workflow.

A paywall must never appear merely because the user is viewing owned data. Viewing existing teams, players, games, scorecards, game history, compatible imported records, or ordinary saved baseball facts should not require premium access.

A paywall must never appear during correction of existing data. Correcting an existing team, player, game, lineup, substitution, pitcher entry, or scoring event must remain available regardless of active premium status.

A paywall must never appear during import review of user-owned compatible files. The user should be able to validate, preview, and decide whether to import compatible ScoreKeep roster or game files without being forced to pay just to recover or inspect their own data.

A paywall must never appear during export of user-owned compatible game or roster data. Exporting compatible ScoreKeep data is part of the user's ownership and preservation path. Premium gates may apply to newly generated premium output, but not to the source data export required for user ownership.

A paywall must never block access to completed games. Completed and archived games should remain openable, reviewable, correctable, and shareable through compatible data workflows after premium expiration.

After purchase, the user should return to the intended workflow when the action can continue safely. After cancellation, the user should return to the prior screen or a clear non-premium alternative without losing work. After failure or uncertainty, the app should keep the prior state and explain the next available action.

Repeated paywall presentation should be avoided. A user with recognized active access should not see the same gate repeatedly. A user who cancels should not be trapped in a loop that prevents navigation back to existing data.

## 10. User-Owned Data Rights

Existing local data remains accessible after premium expiration. Teams, players, games, lineups, substitutions, pitchers, at-bats, photos, logos, notes, and saved baseball history should remain available even when current-season premium access is inactive.

Existing games remain reviewable and correctable. A user should be able to reopen a saved game, inspect scoring events, correct mistakes, update pitcher information, repair substitutions, and review the score without purchasing again.

Existing teams and players remain editable. A user should be able to fix roster details, update team information, correct player names or numbers, and preserve historical clarity without premium access.

Compatible user-owned files remain importable and exportable. ScoreKeep should continue to open, review, import, and export supported `.ScoreKeep_Players` and `.ScoreKeep_Games` data according to compatibility rules, regardless of active premium status.

Premium expiration must not delete, hide, or corrupt records. It must not remove local teams, games, players, scorecards, imports, photos, logos, counters, or existing compatible files. It must not rewrite baseball history to reflect licensing state.

Generated premium output already saved outside the app remains the user's file. A PDF, report, export, printout, or shared file created while premium access was active remains outside the app according to the destination where the user saved or sent it. Expiration should not claim ownership over or invalidate that external file.

Purchase state must not become part of the authoritative baseball record. Scores, at-bats, lineups, substitutions, pitcher participation, reports, and compatible exports should derive from baseball data, not from whether the user currently has premium access.

If purchase state changes while the app is open, the change may affect future gated actions, but it must not invalidate the current saved baseball record or interrupt ordinary review and correction of existing data.

## 11. Offline Behavior

Existing local data should remain available when Internet access or Apple purchase services are unavailable. Users should be able to view, edit, correct, and score existing local records according to ordinary product rules without a network connection.

Already recognized premium status should remain available while temporarily offline. If ScoreKeep has a confirmed active current-season entitlement, a short-term network outage should not unnecessarily remove premium capabilities.

Purchase attempts while offline should fail gracefully or be unavailable before the user begins the purchase. The app should explain that purchase requires network or Apple service access and should not imply that the purchase succeeded.

Status checks while offline should explain that purchase status cannot currently be checked. The app should avoid treating a network failure as proof that the user does not own access.

Offline messaging should be clear and specific. The user should be able to distinguish between unavailable purchase services, unavailable roster downloads, unavailable price loading, and ordinary local data access.

The app should avoid unnecessary loss of access. Temporary Apple service failures, network outages, captive portals, airplane mode, or server unavailability should not erase recognized active access or block user-owned local data.

The app should avoid false confirmation. It should not show purchase success, restored access, or an active entitlement unless there is a confirmed basis for that state. When confirmation is pending or unavailable, the app should say so.

Offline access does not require every network-dependent feature to work. MLB roster downloads, purchase attempts, price loading, status checks, remote announcements, and external web links may require connectivity, but their failure must not damage local data or consume free allowances.

## 12. Pricing and Season Changes

Current-season product presentation should identify the season being sold. The paywall, upgrade prompts, and purchase status screens should use consistent season naming so the user understands whether the product is for the current year, a future season, or a prior season.

Year-to-year changes are expected. The price, product name, availability date, access period, premium feature set, or product presentation may change in future seasons. Any change should be presented before purchase and should avoid surprising users who bought a prior-season pass.

New season availability should be clear. When a new season product is available, the app should offer that season's purchase and explain that it is separate from prior-season access unless the product rules explicitly say otherwise.

Old season expiration should be clear. When a season period ends, active premium capabilities for that season may expire. The app should communicate that expiration without suggesting that user-owned data has expired.

Users with prior-season purchases should be treated respectfully. The app may acknowledge prior purchase history when it can do so, but it should distinguish expired prior-season access from current-season premium access.

If the current-season product is unavailable, the app should say that purchase is currently unavailable. It should not show an outdated prior-season product as if it were current, and it should not require purchase to access existing data.

Price changes should be shown before purchase. If the current season's price differs from a prior season, the user should see the current price in the purchase presentation and should not be told that an old price still applies unless it actually does.

ScoreKeep should avoid subscription language. It should not describe the purchase as renewing, automatically billing, managed like a recurring subscription, or continuing indefinitely unless future product behavior explicitly changes.

ScoreKeep should avoid unexpected renewal expectations. The user should understand that future-season access may require a future purchase and that no automatic renewal is promised by the current non-recurring seasonal model.

## 13. Corrections and Support

If a purchase completed but access is not shown, the app should provide a clear status-check path and preserve the user's current work. The user should not be forced to purchase again without first having a way to check active status where possible.

If a purchase is canceled, the app should return the user to the prior workflow and explain that premium access was not activated. Cancellation should not consume free allowances or alter user data.

If a purchase fails, the app should state that the purchase did not complete and should leave the previous state unchanged. The user should be able to retry when conditions improve or return to existing data.

If the user is concerned about duplicate purchase, the app should guide the user to check status before buying again when practical. Messaging should distinguish a new purchase from a status check.

If the wrong season is shown, the app should prevent purchase if practical and explain that the current-season product is not available or cannot be confirmed. The user should not be encouraged to buy a product that will not grant the intended current-season access.

If a premium feature remains gated after purchase, the app should offer a status check, explain any delay or uncertainty, and keep the user's work available. It should avoid repeated paywalls when the user is actively trying to resolve recognized purchase status.

If restored status is uncertain, the app should say that status could not be confirmed. It should not state that access is restored, not restored, or expired without a confirmed basis.

The user contact or support path should be available from purchase-related failure states. Support messaging should tell users what information is useful without requiring them to understand technical purchase details.

While purchase issues are unresolved, ScoreKeep should preserve work. Games, lineups, scoring progress, import review, export selection, report selection, and roster download choices should remain recoverable where practical.

## 14. Validation Requirements

Wrong season product presentation should be detected before purchase. If the app can tell that the product does not match the intended current season, it should explain the mismatch and avoid presenting the product as valid current-season access.

A missing current-season product should produce a clear unavailable state. The app should not show a purchase button that implies a current-season purchase is ready when the current-season product cannot be found.

An unavailable price should be shown honestly. If the price cannot be loaded, the app should avoid displaying stale or guessed pricing and should explain that purchase information is currently unavailable.

An unconfirmed purchase should not unlock premium access. Pending, interrupted, canceled, failed, or uncertain purchases should be represented by a waiting, canceled, failed, or uncertain state rather than by active access.

An expired entitlement should not unlock current-season premium features. The app should explain that prior access has expired while preserving existing user data.

Conflicting purchase state should be resolved conservatively and visibly. If different screens or checks imply different access states, the app should avoid both false denial and false confirmation, tell the user status is being checked or is uncertain, and preserve work.

A free-use counter must never go below zero. If the remaining-use count is inconsistent, the user should see a stable, understandable message rather than negative allowances.

A counter must not be reduced after a failed action. Failed game creation, failed download, failed report generation, failed purchase, failed import, canceled operation, or validation rejection should leave the relevant free allowance unchanged.

Premium access must not be shown without a confirmed basis. Promotional copy may describe benefits, but active premium state should be shown only when recognized for the relevant season.

Premium access must not be denied despite recognized active access. Once active current-season access is recognized, gated current-season premium features should become available without repeated paywall blocks.

Repeated paywall presentation should be detected as a user experience problem. The app should not trap users in repeated gates after cancellation, failure, or recognized access.

Unsupported device or account states should produce clear messaging. If purchase, status checking, or account validation cannot proceed because the device, account, restrictions, region, Apple services, or network state is unsupported, the app should explain what the user can do next without damaging local data.

## 15. Data Integrity Requirements

ScoreKeep must protect baseball records, free allowances, purchase state meaning, and user workflows throughout purchase and licensing behavior.

- Purchase state never changes baseball records.
- Premium expiration never deletes user data.
- Failed or canceled purchases never consume free allowances.
- A gated action either completes or leaves the prior state unchanged.
- Free-use counters change only after successful qualifying actions.
- Purchase status uncertainty is shown honestly.
- Existing data remains accessible regardless of active premium status.
- Product identifiers and season meaning remain compatible where required.
- Paywall presentation never causes loss of game, lineup, scoring, import, or report work.
- Debug or testing behavior must not affect production user allowances.
- Premium gating never blocks ordinary viewing or correction of user-owned records.
- Compatible roster and game import/export remains available for user-owned data.
- Generated premium output reflects saved baseball data at generation time and does not become the authoritative record.
- Purchase status, entitlement state, and free counters remain separate from scores, statistics, lineups, substitutions, and game history.

## 16. Exceptional Situations

**User reaches free game limit:** The app should explain that the free game creation allowance has been used and that premium access is required for additional new game creation. Existing games remain accessible, correctable, and exportable.

**User reaches free download limit:** The app should explain that the free MLB roster download allowance has been used and that premium access is required for additional roster downloads. Existing rosters, imported files, and local data remain available.

**Purchase canceled:** The app should close or dismiss the purchase flow, preserve the user's current work, and leave premium access inactive unless it was already active before the attempt.

**Purchase fails:** The app should show that the purchase did not complete, preserve prior state, avoid reducing free allowances, and allow retry or status check when appropriate.

**Purchase succeeds but access is delayed:** The app should show that access is being confirmed or that status is not yet reflected, preserve the intended workflow, and provide a check-status path without requiring the user to recreate work.

**App closes during purchase:** On return, the app should show the best known state honestly. It should not assume success or failure without confirmation, and it should preserve user data and free allowances.

**Device restarts after purchase:** On next launch, recognized active access should be available if confirmation was completed. If status is uncertain, the app should explain that it needs to check purchase status when services are available.

**User is offline:** Existing local data and already recognized premium access should remain available. Purchase attempts, price loading, status checks, and roster downloads should show offline or retry messaging without altering local records.

**Current-season product unavailable:** The app should show that purchase is currently unavailable, avoid presenting a wrong-season product as current, and allow access to existing data.

**User owns a prior-season product:** The app should explain that the prior-season purchase is not current-season access if the season has expired. User-owned data from that period remains accessible.

**User changes devices:** The app should let the user check purchase status with the same Apple account when possible and should explain any uncertainty or limitation without claiming restoration before confirmation.

**User reinstalls the app:** The app should preserve or recover recognized status when possible, provide status checking, and explain that user-owned data availability may depend on local backups, imported files, or system restore behavior. Purchase state must not be represented dishonestly.

**Apple account changes:** The app should explain that purchase status may be tied to the Apple account used for purchase. It should not claim active access from another account unless current-season access is recognized.

**Free counter appears incorrect:** The app should avoid negative or destructive behavior, show the remaining-use state it can support, and provide a path to check premium status or contact support.

**Premium access expires during app use:** The app may require premium access for future gated actions after expiration, but it should not interrupt viewing, correction, scoring already in progress, import review, or export of user-owned compatible data in a way that loses work.

**User opens existing data after expiration:** The app should open existing teams, players, games, and compatible files normally. Premium expiration may affect new premium output or expanded actions, not access to the user's existing baseball records.

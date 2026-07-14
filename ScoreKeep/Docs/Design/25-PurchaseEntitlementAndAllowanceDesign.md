# ScoreKeep Technical Design — 25 Purchase, Entitlement, and Allowance Design

<!-- MARK: - 1. Purpose -->
## 1. Purpose

Purchases, seasonal entitlements, free-use allowances, restore behavior, pending transactions, offline status, and gated actions need a dedicated design because they affect user access without owning the baseball records that users create. ScoreKeep's rewrite must keep product access decisions honest while preserving teams, players, rosters, games, lineups, scoring events, pitcher records, substitutions, photos, logos, imports, exports, and existing generated output.

Purchase state controls designated capabilities. It may allow or block future game creation beyond a free allowance, network roster downloads beyond a free allowance, or currently gated generated output. It never owns, deletes, rewrites, hides, repairs, migrates, or reinterprets baseball records.

The current implementation shows the architectural risk. StoreKit product loading, local entitlement storage, free counters, paywall presentation, navigation, report gates, download gates, and game-creation gates are distributed through presentation workflows. Those behaviors are product and compatibility evidence, but the rewrite needs a product-facing purchase and allowance boundary so views do not decide entitlement truth, consume counters prematurely, lose pending user work, or treat purchase uncertainty as data ownership.

<!-- MARK: - 2. Design Principles -->
## 2. Design Principles

Baseball records remain user-owned. Purchase state is separate from baseball facts. Existing local data remains accessible regardless of current entitlement, expired entitlement, restore uncertainty, offline status, price loading failure, or product unavailability.

Free allowances change only after successful qualifying actions. Failed, canceled, pending, duplicated, interrupted, blocked, or rejected actions do not consume allowances. Purchase success is never reported before confirmation, and entitlement recognition may require a separate confirmed step after purchase completion.

Purchase uncertainty is distinct from no purchase. Restore of purchase access is separate from restoration of baseball data. Offline operation preserves local baseball workflows, and previously confirmed access should not disappear merely because status cannot be refreshed.

Seasonal products must be identified honestly. A current-season product, prior-season purchase, future product, missing product, and wrong-season product are different user-facing states. ScoreKeep must not sell or present a prior or wrong season as current access.

<!-- MARK: - 3. Scope and Responsibilities -->
## 3. Scope and Responsibilities

The purchase and allowance subsystem owns product discovery, price availability, purchase requests, pending state, cancellation, failure, entitlement recognition, restore, expiration, season interpretation, free counters, gated-action decisions, offline uncertainty, support classifications, and purchase-facing diagnostics.

It owns the policy question of whether a requested action may proceed with confirmed entitlement, a remaining free allowance, no access, or uncertain status. It also owns conservative handling of allowance inconsistencies, duplicate prevention for counted actions, and user-facing status language for purchase outcomes.

It does not own baseball calculations, source-record ownership, scoring mutation, report calculation, import interpretation, file generation, SwiftUI layout, concrete StoreKit implementation, persistence schemas, or source file placement. Those remain with the domain, scoring engine, application services, compatibility, reporting, persistence, presentation, and platform infrastructure designs.

<!-- MARK: - 4. Architectural Position -->
## 4. Architectural Position

Presentation and view models display purchase state, remaining allowance, paywall messages, recovery choices, and progress. They collect purchase, restore, retry, dismiss, and continue intents. They do not decide product truth or decrement durable allowances directly.

Application services coordinate the originating workflow. A service asks purchase services for a decision for the requested action, preserves pending workflow state, applies a paywall interruption when needed, and resumes only after confirmed access or a valid free allowance result. The originating service remains responsible for preserving selected teams, games, rosters, report scopes, form values, validation state, and idempotency context.

Purchase services communicate with StoreKit or external purchase infrastructure, classify product and transaction status, and expose product-facing purchase state. Entitlement policy interprets confirmed access and season context. Allowance policy interprets durable free counters and counted-action identity. Persistence stores purchase and allowance state separately from canonical baseball persistence. Baseball domain records, generated-output workflows, import, export, roster download, and report workflows consume purchase decisions but do not become purchase records.

<!-- MARK: - 5. Purchase-State Model -->
## 5. Purchase-State Model

Observable purchase states should include Unknown, Loading, Available for purchase, Price unavailable, Product unavailable, Purchase in progress, Purchase pending, Purchase canceled, Purchase failed, Entitled, Not entitled, Prior-season entitlement, Wrong-season product, Restore in progress, Restore completed, Restore found no applicable purchase, Status unavailable, Offline-known entitlement, and Offline-uncertain entitlement.

Authoritative states are those based on confirmed product, transaction, entitlement, or durable local evidence. Entitled, Not entitled, Prior-season entitlement, Wrong-season product, Restore completed, and Restore found no applicable purchase are authoritative only when backed by reliable current evidence. Temporary states include Loading, Purchase in progress, Restore in progress, and delayed product discovery. Uncertain states include Unknown, Status unavailable, Price unavailable, Product unavailable when caused by service failure, Offline-uncertain entitlement, and stale local recognition.

User-facing classifications should avoid raw StoreKit language. Pending is neither success nor failure. Canceled is an ordinary user outcome. Offline-known entitlement differs from Offline-uncertain entitlement. Product unavailable differs from no purchase found.

<!-- MARK: - 6. Entitlement Model -->
## 6. Entitlement Model

Entitlement is permission to use designated gated capabilities for the applicable season and product policy. It is not ownership of teams, players, rosters, games, lineups, scoring events, pitcher records, substitutions, photos, logos, imports, exports, existing reports, or preferences.

Expiration or uncertainty cannot delete, hide, rewrite, invalidate, or relabel owned records. A user without current entitlement may be blocked from a future premium action, but existing local records remain reviewable, correctable, scoreable where already created, and exportable through compatible source-data workflows according to the functional specifications.

Entitlement changes are product-state changes. They may update availability of gates, visible badges, price prompts, and recovery actions. They must not mutate baseball facts, migrate baseball data, create reports by themselves, or mark source records as premium-owned.

<!-- MARK: - 7. Seasonal Product Model -->
## 7. Seasonal Product Model

Current repository evidence shows non-renewing seasonal products in the StoreKit configuration for `com.komakode.ScoreKeep.SeasonPass2025` and `com.komakode.ScoreKeep.SeasonPass2026`, each named as a ScoreKeep year-specific Season Pass and described as scoring games through that year with full MLB download access. Source code builds the current product identifier from the stable prefix `com.komakode.ScoreKeep.SeasonPass` plus the current calendar year, and current entitlement expiration is computed from the product identifier suffix as local end of that year.

Current-season access means confirmed access for the season the app is currently selling and gating. Prior-season access means a recognized purchase whose season no longer covers current premium actions. A future or wrong-season product must not be presented as current access. Season transitions must distinguish expired history from active access and must avoid silently activating the wrong year.

This design does not invent additional product identifiers. Future yearly identifiers must remain compatible with existing recognition expectations or receive an explicit migration policy. Product text, paywalls, and support diagnostics should identify season classification honestly before purchase.

<!-- MARK: - 8. Product Discovery and Availability -->
## 8. Product Discovery and Availability

Product loading asks purchase infrastructure for the intended current-season product and waits for confirmed product information. Product unavailable means the requested product could not be found or offered. Price unavailable means product identity may be known but localized price information cannot be safely presented. Delayed response and offline loading are temporary or uncertain states, not proof that the user lacks access.

Unsupported storefront, account restrictions, StoreKit service failure, network loss, or unavailable App Store state should be classified as product or status unavailability. Stale product information should not be used to promise a current price, current season, or current availability.

Retry should be offered when safe and useful. The app must not invent prices, reuse obsolete prices as purchase promises, or imply purchase readiness before the current product and price are confirmed.

<!-- MARK: - 9. Price Presentation -->
## 9. Price Presentation

Price presentation must use confirmed localized product information supplied by purchase infrastructure. The current StoreKit configuration contains `4.99` display prices for the 2025 and 2026 season passes, but that is repository evidence for the current configuration, not an architectural constant or future promise.

When price is loading, the UI should show a pending state. When price is unavailable, the paywall should say that price could not be loaded and offer retry or return actions. It should not hard-code a price, infer price from prior years, or present a stale value as current.

Price presentation belongs to prepared purchase state and purchase infrastructure. Presentation may format the prepared price but must not assume product availability, localization, currency, or season validity.

<!-- MARK: - 10. Purchase Request Workflow -->
## 10. Purchase Request Workflow

The conceptual purchase workflow begins by preserving the originating gated action. The app records the requested action, selected scope, entered data, validation status, and idempotency context before interrupting the user with purchase UI.

The app then confirms current product and price availability, starts the purchase request, and represents pending, success, cancellation, or failure honestly. After a reported purchase completion, the app verifies entitlement before exposing premium access or resuming the gated action.

The originating action resumes only after confirmed access or another valid policy path exists. It must be revalidated before completion because teams, rosters, games, report scopes, files, network status, and allowance state may have changed during the purchase. Duplicate qualifying actions must be avoided across repeated taps, delayed callbacks, retries, and resumed workflows.

<!-- MARK: - 11. Purchase Success -->
## 11. Purchase Success

Confirmed success requires a reliable purchase outcome plus a confirmed basis for entitlement recognition. A transaction result by itself may be observable before the app has translated it into active seasonal access. The user-facing state should distinguish purchase confirmation from entitlement recognition when those stages are separate.

The application must not show premium success, dismiss a gate as solved, decrement allowances as if premium failed, or resume a paid action before confirmed access exists. If verification cannot complete, the outcome is uncertainty or failure to confirm, not success.

On confirmed access, application services may resume the preserved action after revalidation. The success message should describe active access in product terms, including the applicable season where relevant.

<!-- MARK: - 12. Purchase Pending -->
## 12. Purchase Pending

Pending transactions are unresolved. Pending is not success and not failure. The app should explain that access is not yet available or is awaiting approval unless entitlement was already confirmed through another path.

The originating workflow should remain preserved. The user should have a later status-check path without being forced into repeated purchase attempts. A pending state must not consume free allowances, create duplicate downloads, generate paid output, or create extra games solely because the user attempted to buy.

When the app later receives status updates, it should reconcile the last confirmed state and resume only after entitlement is recognized and the pending action is still valid.

<!-- MARK: - 13. Purchase Cancellation -->
## 13. Purchase Cancellation

Cancellation is an ordinary user outcome, not an application failure. It means the purchase did not activate new access through that attempt.

Cancellation must preserve the originating workflow, entered data, selected scope, validation state, and local baseball records. It must leave allowances unchanged and return the user to a coherent location: the preserved form, report selection, roster download selection, game setup, or a clear non-premium alternative.

The app should not show alarming error language for cancellation. It may explain that premium access was not activated and that the gated action remains unavailable without entitlement or allowance.

<!-- MARK: - 14. Purchase Failure -->
## 14. Purchase Failure

Purchase failure covers unavailable service, rejected transaction, account restriction, network loss, invalid product state, verification failure, wrong-season product, or other non-success outcomes. Failure must be user-facing in product language and preserve recovery choices.

Failure must not grant access, consume allowances, change baseball records, erase the attempted action, or discard prepared work. If a retry may help, retry should begin from the preserved workflow and current product state. If retry is unsafe or not useful, the app should offer check status, return to data, or contact support.

Failure diagnostics may retain raw platform details for support, but raw errors are not the primary user explanation.

<!-- MARK: - 15. Entitlement Recognition -->
## 15. Entitlement Recognition

Entitlement recognition is the step where confirmed access becomes visible to application services. Services should receive a product-facing classification, not raw transaction details.

The model distinguishes confirmed active entitlement, previously recognized entitlement, status currently unavailable, no applicable entitlement found, prior-season entitlement, and conflicting or stale recognition. Previously recognized entitlement can support offline-known access when still within the accepted policy. Status unavailable must not be collapsed into no entitlement.

Uncertainty must not be represented as definitive loss of access without reliable basis. A temporary purchase-service outage should not reset valid access, hide existing data, or force the user to buy again.

<!-- MARK: - 16. Restore Workflow -->
## 16. Restore Workflow

Restore or status check begins with explicit user intent or an appropriate recovery path. The workflow should show progress, query purchase infrastructure, refresh local recognition where possible, and return an honest result.

Outcomes include restore in progress, active access recognized, restore completed with no applicable current-season purchase, prior-season purchase found, status unavailable, failure, and cancellation where the platform or user flow supports it. A no-applicable-purchase result is authoritative only when status was successfully checked.

Restoring purchase access does not restore deleted or missing baseball records. It does not import teams, players, games, photos, logos, reports, or exported files. If local records are absent after reinstall or device change, purchase restore and baseball-data recovery must be explained separately.

<!-- MARK: - 17. Purchase Status Refresh -->
## 17. Purchase Status Refresh

Purchase status refresh may occur manually through a user-visible check or automatically at app launch, foregrounding, transaction updates, or paywall display. It is a query unless it updates durable purchase-state recognition based on confirmed evidence.

Status refresh must not change baseball facts, consume allowances, duplicate transactions, complete pending baseball actions without revalidation, or reset valid access merely because a service is temporarily unavailable.

Automatic refresh should be quiet when it succeeds or remains uncertain without affecting the current workflow. Manual refresh should return visible status and recovery choices.

<!-- MARK: - 18. Offline Entitlement Behavior -->
## 18. Offline Entitlement Behavior

When offline with previously confirmed current-season access, the app should preserve offline-known entitlement according to the accepted cached-access policy. Existing local data and supported local premium capabilities should not vanish solely because purchase services cannot be reached.

When offline with previously confirmed prior-season access, the app should preserve the historical classification but not present it as current access. With no known entitlement, the app may require entitlement or allowance for future gated actions but must keep local records accessible. With uncertain or unavailable status, the app should communicate uncertainty rather than no purchase.

Pending transactions remain pending offline. Expired cached state should be classified carefully, with local records still accessible. Local scoring, correction, roster management, game review, local compatible import, compatible source-data export, and local workflows should not depend unnecessarily on online entitlement refresh. Network roster download, purchase attempts, price loading, and live status checks may be unavailable.

<!-- MARK: - 19. Expiration Behavior -->
## 19. Expiration Behavior

Expiration affects designated future or premium actions. It may require a new current-season purchase before additional gated game creation, roster downloads beyond allowance, or premium generated output where product policy requires entitlement.

Expiration must not delete or hide existing teams, players, games, scoring history, lineups, substitutions, pitcher records, photos, logos, preferences, imports, compatible exports, or existing local records. It must not make completed games unopenable or corrections unavailable for owned records.

Previously generated reports and files remain user-created output. Files already shared, saved, printed, or exported outside the app remain governed by their destination. In-app retained generated output, if any, should remain distinguishable as generated artifacts, not source records.

<!-- MARK: - 20. Gated-Action Model -->
## 20. Gated-Action Model

A gated action is a user-requested capability that requires confirmed entitlement or a remaining free allowance. Repository and specification evidence support gates for creating games beyond the free allowance, MLB roster downloads beyond the free allowance, and current report, PDF, batting statistics, and pitching statistics actions in scoring views. The exact generated-output policy remains partly unresolved and must not be broadened without product approval.

Every gate decision should identify the requested action, current entitlement state, remaining allowance, whether the action may proceed, whether a paywall is required, whether status is uncertain, and how the originating workflow is preserved.

Gate decisions are deterministic product decisions. They do not create, edit, or delete baseball records by themselves.

<!-- MARK: - 21. Pending Gated Action -->
## 21. Pending Gated Action

A pending gated action is the preserved state of user work interrupted by a paywall, purchase request, restore, or status uncertainty. It may include selected game, selected team, selected roster, requested report, PDF scope, download selection, prepared form data, validation state, visible warning state, and idempotency context.

For game creation, pending state includes selected teams, date, location, game settings, and whether the creation is user-initiated or seed/sample-origin. For roster download, it includes manifest team selection and resolved source where known. For reports, it includes game, team, report type, output destination intent, and current replay warning state.

After purchase or restore, the action must be revalidated before completion. A paywall cannot blindly replay a stored tap because source records, network files, allowance counts, or entitlement may have changed.

<!-- MARK: - 22. Paywall Boundary -->
## 22. Paywall Boundary

The paywall presents purchase state and available actions. It does not own the originating workflow, decrement allowances, create games, start downloads, generate reports, or mutate source records.

The paywall must explain the gated capability, current access state, product availability, price when confirmed, restore or status-check option, remaining free allowance where applicable, and dismissal behavior. It should identify the season being offered and avoid subscription or renewal claims that do not match the product.

Dismissing the paywall returns to the preserved workflow or a coherent prior location. A paywall that loses selected teams, report scope, download selection, or entered setup data has crossed its boundary.

<!-- MARK: - 23. Free-Allowance Model -->
## 23. Free-Allowance Model

Free allowances are durable non-baseball product state. Repository and specification evidence identify two current allowance categories: free user-created games and free MLB roster downloads. The current free game creation default is two remaining creates stored by a Keychain-backed counter named `freeGameCreatesRemainingKC`. The current MLB download implementation stores usage count in `mlbDownloadCountKC` with a free limit of four downloads.

This design does not invent new counters. Allowance state should represent zero, remaining count, unavailable count, uncertain state, and invalid persisted state. A remaining-count model and a used-count model may coexist during migration, but the user-facing decision must be clear.

Invalid persisted state includes negative values, unreadable data, mismatched display and durable state, or duplicate counted-action records. Invalid state should be handled conservatively and separately from baseball data.

<!-- MARK: - 24. Qualifying Actions -->
## 24. Qualifying Actions

A qualifying action consumes allowance only after it completes successfully according to product policy. Starting an action, opening a form, viewing a paywall, beginning a purchase, downloading partial bytes, receiving invalid content, previewing import review, or canceling does not qualify.

Game creation qualifies only when a coherent accepted game record exists by product policy. Roster download qualification is less settled: functional requirements say it should count only after the download succeeds far enough to provide the intended roster file or enter the supported import path. Repository code currently increments after a successful file download and setting the import URL, before import review is confirmed.

Generating output qualifies only if a future policy explicitly defines generated output as a counted event. No new generated-output allowance is defined here. Unsupported product rules must remain open rather than inferred from UI placement.

<!-- MARK: - 25. Allowance Consumption Boundary -->
## 25. Allowance Consumption Boundary

Allowance consumption should occur as part of the successful qualifying workflow outcome, coordinated with the application-service transaction boundary. The accepted action and allowance update must be observable as one coherent product result: a successful action is not counted twice, and a failed action is not counted at all.

For game creation, record persistence and allowance decrement must agree. If game persistence fails or validation rejects the game, the allowance remains unchanged. If the game is accepted and counted, retries should recognize the prior accepted result.

For roster downloads, download validation, file availability, and import handoff must be classified before counting. If policy later requires import confirmation, the decrement moves to import completion. For generated output, no decrement occurs unless a future policy explicitly defines successful generated output as a counted allowance category.

<!-- MARK: - 26. Allowance Idempotency -->
## 26. Allowance Idempotency

Allowance idempotency protects users from repeated taps, retries, app restart, delayed callbacks, transaction retries, duplicate download requests, or resumed workflows consuming an allowance more than once.

Each qualifying action should carry an idempotency context meaningful to the originating workflow. A game creation context may identify the accepted creation request. A roster download context may identify the selected roster source and completed download/import boundary. A generated-output context, if later counted, must identify the source scope and output request.

A retried successful action should return the previously accepted allowance result where possible. Duplicate prevention should be visible as a safe outcome, not as a hidden extra decrement or unexplained denial.

<!-- MARK: - 27. Failed and Canceled Allowance Actions -->
## 27. Failed and Canceled Allowance Actions

Allowances do not change for validation failure, purchase cancellation, purchase failure, download failure, invalid downloaded file, import cancellation, import rejection, duplicate prevention, game-creation failure, storage failure, PDF or report failure unless a future policy explicitly defines otherwise, or interrupted work that did not complete.

This invariant applies regardless of where the failure is detected. A network error, file validation error, rejected import review, failed save, or canceled system sheet leaves allowance state unchanged unless a previously completed qualifying outcome had already been accepted.

If the app cannot determine whether a prior action completed, it should classify the state as uncertain and avoid making the user's access worse while support or repair determines the accepted result.

<!-- MARK: - 28. Imported Data and Allowances -->
## 28. Imported Data and Allowances

Opening or importing user-owned compatible files should not consume game-creation allowances. Functional requirements state that compatible ScoreKeep roster and game files remain user-owned and accessible, and that importing existing user-owned data must not become a premium-only data recovery path.

Import review, validation, conflict resolution, and source-data import are ownership-preserving workflows. They may create local records from a user's compatible file after confirmation, but that is recovery or transfer of owned source data, not a new premium game creation in the free allowance sense unless a future policy explicitly says otherwise.

The remaining unresolved product rule is whether any special network-acquired roster import should count only at download handoff or import confirmation. This does not affect user-owned local file imports.

<!-- MARK: - 29. Roster Download Allowance -->
## 29. Roster Download Allowance

Roster-download allowance applies to the supported MLB roster-download workflow. Manifest loading, viewing the team list, selecting a team, resolving the URL, and starting the network request do not qualify by themselves.

A network response that fails, returns no file, returns HTML or an invalid file, cannot be saved, or cannot enter the supported import path does not consume allowance. Import review cancellation or rejection should not consume allowance if product policy defines completion at confirmed import. Repository behavior currently increments after successful download and URL preparation, before import review is confirmed; that is product evidence and a migration risk.

The accepted rule for the rewrite should be explicit before implementation: either count at successful compatible file acquisition into the import path, or count at confirmed import completion. The functional specification leans toward successful download far enough to provide the intended roster file or enter the supported import path, while still requiring invalid files and failures to consume none.

<!-- MARK: - 30. Game-Creation Allowance -->
## 30. Game-Creation Allowance

Free game creation is consumed only after a coherent accepted game record exists according to product policy. Opening game setup, selecting teams, entering date or location, presenting validation, passing a paywall, or creating temporary form state is not enough.

Repository behavior currently creates a game in `ScoreContentView` and then decrements the free counter for non-premium user-initiated creation; seed creation is exempt. Because persistence uses a best-effort save, the rewrite must make the transaction boundary explicit so a failed save does not consume allowance.

Failed, canceled, duplicated, or interrupted creation does not consume allowance. Duplicate game prevention must distinguish an accidental repeated tap from an intentional separate game.

<!-- MARK: - 31. Report and Generated-Output Gating -->
## 31. Report and Generated-Output Gating

Repository evidence shows report and generated-output gates in scoring views: PDF generation, pitching statistics, and hitting statistics check premium status and show the paywall with a reports context when access is inactive. The paywall text also describes coach-ready PDF reports. Baseline documentation references premium gates for downloads, reports, PDFs, and game limits.

Document 24 defines reports and generated output as derived projections from baseball facts, not source records. Current evidence supports generated-output gating as a product behavior, but this design does not invent a new generated-output allowance or broaden gates to ordinary data review.

Existing records remain accessible. Source-data export remains separate from generated-output gating. Unresolved policy questions include exactly which report, PDF, screenshot, print, share, or generated-output paths require current entitlement.

<!-- MARK: - 32. Import and Export Ownership Boundary -->
## 32. Import and Export Ownership Boundary

Compatible user-owned source data remains separate from premium ownership. Document 21 defines `.ScoreKeep_Players` and `.ScoreKeep_Games` as compatibility contracts for source baseball records. Purchase state must not prevent safe review or ownership-preserving access to existing compatible records.

Source-data import decodes and applies user-owned baseball records after validation and confirmation. Source-data export writes compatible roster or game files from owned records. Generated reports are derived output and may be premium-gated where product policy says so. Network roster downloads are purchase-gated conveniences after free allowance. Purchase-gated conveniences must not become hidden data locks.

The boundary protects users who need to move records, recover from device changes with exported files, or inspect shared ScoreKeep files without buying access merely to reach their own data.

<!-- MARK: - 33. Existing-Data Access -->
## 33. Existing-Data Access

Users can continue to review, open, correct, score already-created in-progress games, inspect historical games, manage existing rosters, edit teams and players, repair owned records, and export compatible source data regardless of current entitlement.

A gate may prevent creating new gated content, generating premium output, or using network convenience beyond allowance. It cannot hide existing teams, players, games, scoring history, photos, logos, preferences, imports, or compatible exports.

Existing local data should remain available offline. Purchase service failure, expired access, account changes, restore uncertainty, and product unavailability must not turn owned baseball records into inaccessible content.

<!-- MARK: - 34. Purchase and Baseball-Data Separation -->
## 34. Purchase and Baseball-Data Separation

Purchase changes never alter scores. Purchase changes never alter lineups. Purchase changes never alter pitcher history. Purchase changes never alter substitutions. Purchase changes never delete media. Allowance changes never create or delete baseball records by themselves.

Restore does not migrate or restore baseball data. Baseball migration does not fabricate entitlement. Importing a file does not prove purchase ownership. Purchase success does not repair a corrupted game. Entitlement expiration does not rewrite reports or scoring facts.

These invariants should be visible in application-service outcomes and release verification. Every purchase-state scenario must assert that baseball facts remain unchanged unless a separate confirmed baseball command occurred.

<!-- MARK: - 35. Persistence Boundary -->
## 35. Persistence Boundary

Durable purchase and allowance state is separate from canonical baseball persistence. Relevant product state may include known entitlement classification, season context, last confirmed access basis, remaining allowance or used count, counted-action identifiers, uncertainty status, restore outcome, and support diagnostics.

This design does not define concrete storage keys or schemas. Repository evidence shows current Keychain-backed state for `seasonPassMaxExpirationISO8601`, `freeGameCreatesRemainingKC`, and `mlbDownloadCountKC`, but those are legacy evidence, not required future schema.

A preference reset must not reset purchases or allowances unless an explicit product workflow says so. A baseball migration must not reset product state, and product-state repair must remain separate from baseball records.

<!-- MARK: - 36. App Launch Behavior -->
## 36. App Launch Behavior

App launch should load local baseball data promptly while purchase status is loading, unavailable, or refreshing. Optional purchase refresh must not block access to local records, game lists, roster management, correction, compatible imports, or compatible exports.

Launch may refresh products, entitlement recognition, transaction updates, and announcements in the background. Failure to refresh purchase state should produce uncertainty or cached recognition where policy allows, not false entitlement loss or launch loops.

The app should avoid repeated paywalls, repeated allowance resets, false access loss, and repeated product-loading alerts caused by purchase-service failure. Debug or review-only reset behavior must not leak into release launch behavior.

<!-- MARK: - 37. App Reinstall and Device Change -->
## 37. App Reinstall and Device Change

Reinstall and device change require separate explanations for restored purchase entitlement, locally persisted allowance state, system-backup-restored baseball records, exported files reopened manually, and data that cannot be recovered.

Purchase status may be checked through the purchase infrastructure and Apple account context, but that does not restore teams, players, games, photos, logos, reports, or exported files. Baseball records may be present because a system backup restored local data or because the user imports exported ScoreKeep files.

Free counters and local records may not be reconstructable reliably after reinstall or device replacement. The app should report uncertainty honestly and avoid promising resets or recovery that the product cannot guarantee.

<!-- MARK: - 38. Apple Account and Storefront Changes -->
## 38. Apple Account and Storefront Changes

When Apple account or storefront context changes, product availability, price, restore result, and entitlement recognition may change or become uncertain. The app should avoid exposing credentials or making assumptions about account identity.

Local baseball records remain accessible. A different account may affect purchase recognition, but it does not delete local records or prove that the user never bought access.

Entitlement uncertainty should be communicated without claiming definitive loss or success prematurely. Recovery may include check status, verify account context in ordinary language, return to data, retry later, or contact support.

<!-- MARK: - 39. Error Classification -->
## 39. Error Classification

Purchase and allowance errors should use product-language classifications: Product unavailable, Price unavailable, Purchase failed, Purchase pending, Purchase canceled, Status unavailable, Restore unavailable, No applicable purchase found, Current-season access not found, Prior-season access found, Wrong-season product, Restricted account, Offline uncertainty, Allowance inconsistency, and Duplicate completion prevented.

Raw StoreKit, network, keychain, file, or system errors are support diagnostics, not primary user explanations. User-facing messages should state whether access changed, whether data changed, whether allowance changed, and what recovery choices are safe.

Error classification should preserve the originating workflow. A purchase error tied to a roster download should identify that download context; a report gate should preserve report scope; a game-creation gate should preserve setup state.

<!-- MARK: - 40. Recovery Actions -->
## 40. Recovery Actions

Appropriate recovery choices include Try Again, Check Status, Restore Purchases, Return to Data, Continue With Free Allowance, Return to Pending Action, Cancel, and Contact Support.

Retry is offered only when safe and useful. Check Status is appropriate when the user may already have access or a pending purchase. Continue With Free Allowance is appropriate only when the gate decision confirms remaining allowance and the action can be counted safely. Return to Data is always important when purchase services fail but owned records remain accessible.

Recovery must preserve the originating workflow and avoid duplicate purchases or allowance changes. A recovery action should never blindly repeat a side effect without checking the last confirmed state.

<!-- MARK: - 41. Allowance Inconsistency Recovery -->
## 41. Allowance Inconsistency Recovery

Allowance inconsistency includes negative counters, missing counters, stale values, duplicate consumption records, disagreement between display and durable state, unreadable persisted data, and uncertain reinstall behavior.

The app must not make access worse merely because the counter display is uncertain. It should avoid silently resetting counters in release builds, avoid dropping below zero, and avoid converting uncertainty into denial without policy support. Repair behavior should be explicit, diagnosable, and conservative.

Support or repair behavior remains separate from baseball data. Fixing a counter cannot create or delete games, imports, reports, teams, or players.

<!-- MARK: - 42. Interruption and Resume -->
## 42. Interruption and Resume

Interruption may occur while product loading, purchasing, pending transaction handling, restore, status refresh, gated action preservation, allowance consumption, download, game creation, report generation, or import review is in progress.

On resume, the app should determine the last confirmed state before proceeding. It should not repeat side effects blindly. A completed purchase still needs entitlement recognition. A completed game creation should not create another game. A completed counted download should not decrement again. A failed or unknown outcome should preserve work and request recovery.

Resume behavior should restore the user's context where practical: selected game, selected team, selected roster, report scope, form entries, validation warnings, and paywall state.

<!-- MARK: - 43. Concurrency and Duplicate Prevention -->
## 43. Concurrency and Duplicate Prevention

Observable guarantees should include one active purchase request per intended product action, one accepted allowance consumption per qualifying action, no parallel game creations consuming the same allowance twice, no duplicate roster downloads from repeated callbacks, no pending action resumed twice, and no conflicting status refresh overwriting confirmed access with temporary uncertainty.

This design does not prescribe a concurrency framework. It requires product-level coordination so user-visible outcomes remain coherent when multiple screens, callbacks, scene-phase changes, transaction updates, retries, or repeated taps occur.

Confirmed access should win over temporary uncertainty unless reliable evidence supersedes it. Duplicate-prevention outcomes should be diagnosable for support without exposing credentials or unrelated records.

<!-- MARK: - 44. Determinism -->
## 44. Determinism

The same confirmed entitlement state, allowance state, requested action, and product policy should produce the same gating decision. Network timing, screen size, selected tab, incidental list order, or current SwiftUI view structure must not change allowance or ownership policy.

External status may change over time. When it does, the decision should be traceable to the observed state used: product availability, entitlement classification, allowance count, season classification, and requested action.

Deterministic gate decisions make fixture-backed verification possible and prevent contradictory behavior between iPhone, iPad, launch routes, deep links, and report screens.

<!-- MARK: - 45. Offline Operation -->
## 45. Offline Operation

Offline local workflows remain available: open existing games, score already-created local games, correct completed games, manage local teams and players, review history, generate local reports where policy allows, export compatible source data, and import compatible local files.

Network-dependent purchase workflows may not be available offline: product loading, price refresh, purchase requests, status checks, restore checks, MLB roster manifest loading, and roster download. Their failure must not damage local data or consume allowances.

Previously confirmed access should not vanish solely because the device is offline. Status uncertainty should never lock users out of existing local baseball records.

<!-- MARK: - 46. Privacy and Security -->
## 46. Privacy and Security

Purchase workflows should avoid collecting credentials, passwords, unnecessary account details, unrelated baseball records, photos, rosters, reports, or files. StoreKit or system account infrastructure owns credentials; ScoreKeep should receive product-facing status only.

Support diagnostics should minimize purchase and personal information. Useful classifications include season, entitlement status, requested gate, allowance category, retry safety, app version, and platform context. Full account identifiers, receipts, player records, youth information, media, or unrelated files should not be exposed by default.

Purchase events should not upload player, roster, game, photo, logo, report, or scoring data. Account changes, purchase failures, and restore uncertainty must not alter local baseball data.

<!-- MARK: - 47. Accessibility -->
## 47. Accessibility

Purchase, restore, paywall, allowance, pending, failure, and uncertainty states must be accessible through VoiceOver, larger text, keyboard input, high contrast, and color-independent presentation.

Accessible descriptions should clearly identify the gated action, current entitlement, price availability, remaining allowance, purchase progress, pending state, recovery options, and whether baseball data changed. A user should not need color, animation, or icon shape alone to understand access state.

Paywall dismissal, Check Status, Try Again, Continue With Free Allowance, Return to Data, and Contact Support should have clear focus order and labels. Dynamic price and season text must remain readable at supported text sizes.

<!-- MARK: - 48. Observability and Supportability -->
## 48. Observability and Supportability

Privacy-conscious diagnostics may include product category, season classification, entitlement classification, allowance category, remaining count or used count, requested gated action, transaction outcome classification, whether local data changed, whether allowance changed, whether retry is safe, app version, and platform context.

Diagnostics should not expose credentials, full account identifiers, purchase receipts, player records, roster contents, game details, photos, logos, or unrelated files by default. If support needs user data, that must be a deliberate user-chosen sharing path.

Support summaries should distinguish purchase access recovery from baseball-data recovery and should identify unresolved uncertainty rather than forcing false conclusions.

<!-- MARK: - 49. Legacy Purchase and Allowance Mapping -->
## 49. Legacy Purchase and Allowance Mapping

Repository evidence identifies the StoreKit configuration as product evidence: non-renewing 2025 and 2026 season passes, year-specific product identifiers, displayed price evidence, App Store internal IDs, and non-family-shareable configuration.

`PurchaseManager` is purchase-service evidence and migration risk. It loads only the current-year product by prefix convention, stores a max local expiration in Keychain, computes local end-of-year entitlement from product ID suffix, listens for transaction updates, handles pending and canceled outcomes through messages, and notes that non-renewing purchases do not automatically restore active access on a new device without local entitlement.

`PaywallView` is presentation behavior. It derives displayed year from loaded product ID or current year fallback, shows localized product display price when loaded, offers Buy Season Pass and Check Purchase Status, and has contexts for game limit, download limit, and reports.

`ScoreContentView` maps to free game allowance evidence and migration risk. It uses `freeGameCreatesRemainingKC` with default two, gates non-premium user-initiated game creation, exempts seeded creation, decrements after create call, and contains DEBUG reset behavior.

`ShareContentView` maps to roster-download allowance and gating evidence. It uses `mlbDownloadCountKC` with default zero and limit four, disables selection at four for non-premium users, shows paywall for download limit, downloads from the KomaKode manifest, increments after successful file download and import URL preparation, and presents import review after download.

`EditScoreView` maps to generated-output gating evidence. PDF, Pitch Stats, and Hit Stats actions require active season pass and present the reports paywall when inactive. These are gates, not allowance counters.

<!-- MARK: - 50. Legacy Risks -->
## 50. Legacy Risks

Legacy risks include counter decrement before confirmed successful persistence, debug counter reset behavior, product identifier drift, prior-season product shown as current through fallback display, false success if purchase completion and entitlement recognition are conflated, purchase uncertainty interpreted as no access, and paywall interruption losing workflow context.

Additional risks include local data hidden by gates, duplicate decrement after retry, network download counted despite invalid file or canceled import review, restore presented as baseball-data recovery, purchase logic duplicated across views, and status refresh overwriting confirmed access with temporary uncertainty.

Generated-output gates also risk overreaching into source-data ownership if report, PDF, screenshot, share, print, compatible export, and ordinary game review are not separated clearly.

<!-- MARK: - 51. Migration and Coexistence -->
## 51. Migration and Coexistence

The rewritten purchase and allowance layer can coexist with legacy gates during incremental replacement only if each gated action has one accepted decision path and one accepted allowance writer. A view may keep presenting legacy UI while application services become the authority for the gate decision.

Existing durable state should be interpreted and preserved before replacing legacy writes. The rewrite must map current Keychain entitlement and counters into the new classification without resetting users or fabricating access. Debug reset behavior must be excluded from release behavior.

Routing changes require fixture-backed verification. Legacy code should be retired only after purchase, allowance, offline, restore, and data-ownership behavior pass acceptance for each replaced workflow.

<!-- MARK: - 52. Verification Strategy -->
## 52. Verification Strategy

Verification uses the acceptance fixture and regression catalog. Required scenarios include two free game creations available, one free game creation remaining, zero game creations remaining, successful game creation consumes one, failed game creation consumes none, canceled game creation consumes none, repeated completion consumes once, four roster downloads available, last free roster download, failed network download consumes none, invalid downloaded file consumes none, canceled import review consumes none, purchase canceled, purchase failed, purchase pending, current-season access active, prior-season access expired, wrong-season product, product unavailable, price unavailable, status unavailable, restore success, restore uncertainty, offline known access, offline uncertainty, reinstall or device-change uncertainty, existing records remain accessible, no purchase state changes baseball facts, and debug or release counter persistence regression.

Expected evidence should include visible state, gating decision, preserved workflow, allowance count, entitlement state, retry behavior, remote verification where applicable, and unchanged baseball records.

Every scenario should state whether source records changed, whether allowance changed, whether entitlement changed, whether the user can return to pending work, and whether support diagnostics are sufficient without exposing private data.

<!-- MARK: - 53. Release Requirements -->
## 53. Release Requirements

Release blockers include purchase-driven data loss, existing records becoming inaccessible, false purchase success, wrong-season activation, failed or canceled action consuming allowance, duplicate allowance consumption, restore changing baseball records, offline access incorrectly removed, counter reset in release behavior, paywall discarding prepared work, and purchase uncertainty treated as definitive entitlement loss.

Release also blocks on product identifier mismatch that could sell the wrong season, status refresh that erases valid access during temporary service failure, and any gate that prevents compatible source-data import or export of owned records.

Known non-blocking issues must be documented and must not compromise data ownership, purchase honesty, or allowance integrity.

<!-- MARK: - 54. Risks and Open Questions -->
## 54. Risks and Open Questions

Unresolved issues include the exact seasonal product transition policy, product-identifier ownership and provisioning process, exact qualifying moment for roster-download allowance, whether generated reports or PDFs are gated in every surface, reinstall behavior for local counters, offline grace or cached-access policy, pending transaction handling, user-facing allowance repair, support escalation policy, retention of counted-action identifiers, and how long status uncertainty may be tolerated.

Additional open questions include whether prior-season access should be visible in status screens, whether a successful roster download or confirmed roster import is the counted event, how to classify generated screenshots, and how to reconcile current used-count download storage with remaining-count presentation.

These are not settled facts. They require product decisions, fixture expectations, and implementation acceptance before release.

<!-- MARK: - 55. Success Criteria -->
## 55. Success Criteria

The design succeeds when purchase status is honest, seasonal access is correct, existing baseball records remain accessible, free allowances change only after successful qualifying actions, retries do not duplicate purchases or decrements, paywalls preserve workflow context, restore is separate from baseball-data recovery, offline local workflows remain available, purchase failures never alter baseball data, and purchase and allowance behavior is fixture-backed and release-safe.

Success also requires that presentation can change without changing entitlement truth, product loading can fail without corrupting local work, and support can diagnose access issues without unnecessary private baseball data.

The resulting architecture should make every gate explainable from requested action, entitlement classification, allowance state, season policy, and preserved workflow context.

<!-- MARK: - 56. Recommended Next Design Document -->
## 56. Recommended Next Design Document

The recommended next design document is `26-AccessibilityAndInclusiveInteractionDesign.md`.

Documents 17 through 25 then define architecture, canonical baseball meaning, scoring replay, persistence, compatibility, scorecard presentation, application-service workflows, generated output, purchases, entitlements, and allowances. Accessibility and inclusive interaction should follow because it cuts across every major rewritten workflow and requires concrete design boundaries before implementation begins.

That document should address live scoring, correction, import review, paywalls, reports, offline states, destructive actions, larger text, VoiceOver, keyboard operation, color-independent status, and device-class differences as product architecture rather than late UI cleanup.

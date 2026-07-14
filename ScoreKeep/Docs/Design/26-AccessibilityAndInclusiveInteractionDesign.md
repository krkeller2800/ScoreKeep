# ScoreKeep Technical Design — 26 Accessibility and Inclusive Interaction Design

<!-- MARK: - 1. Purpose -->
## 1. Purpose

Accessibility and inclusive interaction need a dedicated design because ScoreKeep's core value is created during time-sensitive, error-prone baseball workflows: setting up teams, building lineups, scoring live plate appearances, correcting prior events, reviewing imports, producing reports, handling purchase gates, and recovering from interruption. These workflows must remain usable for people with differing vision, hearing, motor control, dexterity, cognition, language fluency, device familiarity, and situational constraints.

Accessibility is an architectural and product requirement, not late presentation cleanup. A user who cannot use the visual scorecard, cannot perform drag-and-drop, needs larger text, uses VoiceOver, uses Switch Control, uses Voice Control, navigates with a hardware keyboard, needs higher contrast, or works one-handed at a field must be able to reach the same meaningful baseball outcomes through supported interaction paths.

This design defines boundaries and observable guarantees. It does not invent concrete Swift types, protocols, actors, persistence schemas, source-file organization, keyboard shortcuts, analytics, new file formats, new product identifiers, or new baseball rules. It extends Documents 17 through 25 by requiring the rewritten architecture to expose stable semantic actions and prepared state that multiple presentation and input methods can consume without changing baseball truth.

<!-- MARK: - 2. Repository Evidence and Scope -->
## 2. Repository Evidence and Scope

The tracked design-document path is `ScoreKeep/Docs/Design`, and existing sibling documents use filenames such as `24-ReportingAndGeneratedOutputDesign.md` and `25-PurchaseEntitlementAndAllowanceDesign.md`. Document 26 belongs beside those files and follows the same numbered-section and MARK-comment convention.

Current repository behavior is compatibility and risk evidence, not architecture to reproduce. Confirmed evidence includes SwiftUI navigation stacks, a `NavigationSplitView` and iPhone tab entry points, iPhone/iPad branches using `UIDevice.type`, full-screen covers for lineup, pitcher, replacement, and report workflows, sheets for scoring and paywall presentation, forms and lists for editing and import review, table-like report rows, custom scorecard drawing, StoreKit paywall presentation, Keychain-backed free counters, import and download workflows, screenshot/share output, alerts for errors and destructive lineup updates, and orientation-change handling in scoring views.

Accessibility support in the current code is limited and uneven. Confirmed explicit accessibility labels exist for a small set of purchase and toolbar elements, including the free-game counter, search, upgrade, active Season Pass badge, displayed price, and a download-limit marker. The repository does not show a comprehensive semantic accessibility model for scorecards, live scoring, custom drawing, import tables, report tables, lineup reordering, score correction, or generated PDFs.

<!-- MARK: - 3. Architectural Position -->
## 3. Architectural Position

Accessibility is a cross-cutting product responsibility owned by the same architecture that owns correctness, compatibility, workflow preservation, and purchase honesty. It must be considered when defining commands, queries, prepared presentation state, warnings, correction workflows, report projections, import previews, paywall decisions, and release verification.

Canonical baseball data and scoring truth remain independent of presentation accommodations. Device class, input method, text size, contrast settings, VoiceOver state, reduced-motion settings, pointer availability, or keyboard availability must not change scoring rules, baseball calculations, entitlement truth, allowance consumption, persistence meaning, import interpretation, export compatibility, or generated-output facts.

Accessible presentation must expose the same meaningful baseball actions and information as the visual presentation. Views do not reinterpret baseball facts to make them accessible. Application services and domain logic provide stable semantic actions, validation results, and prepared state; SwiftUI presentation, platform accessibility infrastructure, and alternate input methods present and invoke those meanings.

<!-- MARK: - 4. Accessibility Principles -->
## 4. Accessibility Principles

ScoreKeep requires equivalent access, not merely equality of visible controls. Equality of controls means the same button or table appears to everyone. Equivalence of outcome means users can create the team, complete the lineup, score the plate appearance, understand the current game state, correct the mistake, review the import, generate the allowed report, or recover from a paywall interruption with the same baseball meaning and side effects.

Semantic clarity is required. Accessibility metadata, visible labels, error messages, and status summaries must describe product meaning: batter, pitcher, inning, count, base occupancy, scoring event, substitution, import conflict, purchase state, allowance state, and warning consequence. They must not expose only internal control names, source-field names, or visual layout positions.

Interaction must be predictable, recoverable, and honest. Focus order should follow baseball workflow order, status changes should be communicated without overwhelming live scoring, destructive actions must explain consequences before commitment, and failed or canceled actions must state whether baseball records, purchase state, or allowance state changed.

<!-- MARK: - 5. Responsibility Boundaries -->
## 5. Responsibility Boundaries

The baseball domain and scoring engine own baseball rules, canonical facts, command validation, replay, derived state, warnings, and deterministic results. They do not own accessibility labels, focus movement, visual color, touch layout, or platform-specific input behavior.

Application services own workflow intent, transaction boundaries, idempotency, duplicate prevention, validation coordination, interruption recovery, purchase-gated action coordination, and prepared state requests. They must expose product-meaningful actions and results that are usable by touch, VoiceOver, keyboard, Switch Control, Voice Control, pointer, and other supported input paths.

Prepared presentation state owns screen-readable summaries, semantic grouping hints, status text, enabled/disabled explanations, validation messages, table row meanings, report descriptions, and state summaries. SwiftUI presentation owns layout, visible controls, platform accessibility modifiers, focus restoration, announcement timing, and adaptation to device class and system settings. Persistence, compatibility, import/export, generated-output, purchase, entitlement, allowance, and verification subsystems retain the responsibilities established in Documents 17 through 25 and must not absorb alternate accessibility-specific domain logic.

<!-- MARK: - 6. Semantic Interaction Model -->
## 6. Semantic Interaction Model

Every user-visible baseball concept must have a semantic representation independent of visual placement. Team and player identity include name, role, number where available, current or historical participation, and ambiguity warnings. Batter and pitcher context includes current participant identity, side, batting-order or pitcher-appearance context, and unknown or missing status when applicable.

Game state semantics include inning, half-inning, out count, ball and strike count where represented, base occupancy, score, current plate appearance, recent scoring event, enabled and disabled scoring actions, game status, validation warnings, correction state, and replay limitation. The same semantic state must be available to the visual scorecard, accessible summaries, reports, correction review, and generated output projections.

Non-baseball workflow semantics include import conflict, malformed or unsupported file, purchase state, allowance state, offline or uncertain state, pending gated action, and destructive-action consequence. These meanings should be communicated through text, state values, grouping, enabled/disabled explanations, and recovery choices rather than color, icon, animation, or spatial position alone.

<!-- MARK: - 7. Live Scoring Accessibility -->
## 7. Live Scoring Accessibility

Live scoring must support rapid repeated interaction while protecting baseball correctness. The user needs quick access to common scoring actions, but each accepted action must still be a validated baseball command with idempotency protection. Alternate input paths must not create duplicate at-bats, skip validation, or produce different runner, out, inning, score, pitcher, or allowance results.

The current live scoring evidence includes `PlayersToScoreView`, `ScoreGameView`, and custom scorecard drawing. These views use dense player rows, a scoring sheet, fixed-size pickers and buttons, color-coded backgrounds, geometry-positioned bases, and drawn scorecard graphics. The rewrite must preserve the product workflow while replacing visual-only dependencies with semantic current-state summaries and accessible action paths.

After a scoring action, ScoreKeep should communicate enough context for continued scoring: batter, pitcher where known, inning and half-inning, outs, count where represented, runners, score changes, and next available actions. The design must balance complete information with efficiency: repeated live scoring should not force the user to listen to an entire scoreboard after every tap, but the current state and recent consequence must remain available on demand and after meaningful mutations.

<!-- MARK: - 8. Live Scoring Focus and Duplicate Prevention -->
## 8. Live Scoring Focus and Duplicate Prevention

VoiceOver focus after a scoring action should move to a meaningful next location: the next batter, the current plate-appearance state, a required runner choice, or a confirmation/recovery control. Focus must not disappear into custom drawing, return to a stale row, or trigger repeated scoring through delayed focus changes.

Actions that require additional choices, such as runner outcomes, recorded outs, earned-run decisions, or fielder selection, must expose the pending state and the required choice semantically. Canceling that choice must leave baseball facts unchanged unless an earlier command was already accepted and clearly reported.

Duplicate prevention is required for touch, VoiceOver activation, Switch Control scanning, Voice Control commands, pointer clicks, keyboard selection, app foregrounding, and delayed callbacks. The same application-service idempotency model described in Documents 23 and 25 must protect live scoring from repeated activation caused by focus restoration, announcement timing, or resume behavior.

<!-- MARK: - 9. Score Correction and Replay -->
## 9. Score Correction and Replay

Score correction must be accessible because a live scoring app is only trustworthy when mistakes can be repaired. Selecting a prior scoring event must identify the source event, its inning and half-inning, batter, pitcher or unknown pitcher state, runner outcomes, outs, score effect, and downstream derived state. A visual timeline or scorecard cell alone is not enough.

Before accepting a correction, ScoreKeep must describe what will change and what may be recalculated: score, inning, outs, base occupancy, batting totals, pitching responsibility, pitcher records, lineup projections, report values, and warnings. Destructive or cascading corrections require confirmation in product language and must provide a safe cancellation path.

After correction, focus should return to a meaningful place: the corrected event, refreshed current game state, or the next actionable item. The result must distinguish recorded facts from derived projections. Replayed score and statistics are regenerated; the correction command, not the accessibility path, is the source mutation.

<!-- MARK: - 10. Rosters, Lineups, Teams, and Players -->
## 10. Rosters, Lineups, Teams, and Players

Roster and lineup workflows must support creating and editing teams and players, selecting starters and substitutes, editing batting order, selecting defensive positions, handling duplicate-player warnings, reviewing photos and logos, and managing long names and numbers. Team identity cannot depend on color or logo alone.

Current repository evidence shows table-like editing with fixed column widths, small headers, color-coded columns, `FocusState` on some text fields, image/logo display, and dense player rows. `StartingLineupView` explicitly instructs users to hold and drag players to change batting order and swipe left to delete. Those are migration risks, not future requirements.

The rewrite must provide non-drag alternatives for batting-order changes and non-swipe alternatives for deletion or removal. Empty and incomplete rosters should be represented as valid workflow states with clear next actions. Lineup changes during a game must explain whether recorded at-bats, substitutions, pitcher appearances, reports, or projections will be affected before the change is accepted.

<!-- MARK: - 11. Game Setup and Workflow Preservation -->
## 11. Game Setup and Workflow Preservation

Game setup must make team selection, home and away designation, date, time, location, game settings, validation, and creation status accessible. The home/away distinction must be textual and semantic, not only spatial, color-based, or logo-based.

Purchase or allowance interruption must preserve entered setup data, selected teams, validation state, duplicate-prevention context, and focus where practical. Returning from a paywall, cancellation, pending purchase, failed purchase, restore, or free-allowance path must state whether a game was created, whether an allowance changed, and where the user can continue.

Duplicate prevention applies to setup as much as live scoring. A repeated create activation from VoiceOver, keyboard, pointer, or resume must not create multiple games or consume multiple free creates. The accepted creation result should be observable as one coherent product outcome.

<!-- MARK: - 12. Import Review and Compatibility Workflows -->
## 12. Import Review and Compatibility Workflows

Import review must explain file source, file type, compatibility classification, validation errors, previewed teams, players, rosters, games, photos, logos, conflicts, unsupported fields, malformed data, progress, cancellation, and final import outcome. It must clearly distinguish imported source data from derived reports or projections.

Current repository evidence includes security-scoped file reading, player and game JSON decode paths, decode-error alerts, side-by-side current/imported review in `ImportPlayersView`, fixed-width preview rows in `ImportDisplayView`, swipe-to-delete for imported players, and MLB roster download handoff through `ShareContentView` and `DownloadFiles`. These show the workflows to support and the risk of relying on tables or side-by-side comparison as the only review form.

This design does not invent new import policies. Replace, merge, skip, cancel, or overwrite choices are available only where existing specifications support them. Compatible user-owned local files must remain ownership-preserving, and entitlement state must not block access to existing user-owned records or compatible source-data recovery.

<!-- MARK: - 13. Generated Output and Reports -->
## 13. Generated Output and Reports

Reports must be accessible as derived projections, not alternate sources of baseball truth. Report selection, hitting statistics, pitching statistics, scorecards, PDFs, print workflows, share workflows, table semantics, reading order, repeated headers, large text, high contrast, and color-independent status indicators must be designed together.

Current repository evidence includes batting and pitching report views, screenshot capture, `ShareLink`, PDF generation, manual PDF viewing, dense report tables with abbreviated headers, fixed widths, color-highlighted headers, and duplicated statistical calculations. Documents 22 and 24 already require shared replay-derived report projections and accessible report descriptions; Document 26 makes those requirements cross-cutting.

The rewrite should provide screen-readable summaries for report projections and table rows. It must not promise that every exported PDF is automatically fully accessible unless a future approved requirement and verification support that claim. PDF, screenshot, print, and share outputs need explicit accessibility verification policies, especially for scorecards and dense statistical tables.

<!-- MARK: - 14. Purchases, Entitlements, and Allowances -->
## 14. Purchases, Entitlements, and Allowances

Purchase accessibility follows Document 25. Product and season identification, localized price, purchase progress, pending purchase, cancellation, failure, confirmed entitlement, prior-season entitlement, restore or status check, remaining free allowance, uncertain or offline status, paywall dismissal, and return to the preserved action must be communicated in product language.

Current repository evidence includes a StoreKit paywall with product-year text, display price, buy button, status-check button, progress indicators, error alerts, legal links, free-game and MLB-download counters, premium badges, and report/download/game gates. Some of those elements have accessibility labels; the rewrite requires full purchase-state semantics rather than isolated labels.

Purchase status must not be communicated by color, icon, animation, or badge alone. Every gated-action return path must confirm whether baseball data changed and whether allowance or entitlement state changed. Pending and uncertain states must not be described as success or no purchase without evidence.

<!-- MARK: - 15. Errors, Warnings, Confirmations, and Destructive Actions -->
## 15. Errors, Warnings, Confirmations, and Destructive Actions

Errors and warnings must use product language, clear consequences, safe recovery choices, predictable initial focus, coherent reading order, and explicit state-change reporting. A user should know whether the issue is a warning, failure, pending state, uncertainty, validation rejection, or destructive confirmation.

Current repository evidence includes simple error alerts, decode-error messages, purchase-error alerts, image-save errors, and a destructive lineup-update alert that warns recorded at-bats will be deleted. The rewrite must make these patterns consistent and must preserve entered work when an error or warning interrupts a workflow.

Critical actions cannot be dismissible traps or ambiguous confirmations. Destructive actions must state what records or projections are affected, what remains unchanged, and how to cancel. Repeated modal presentation must not strand VoiceOver, keyboard, or Switch Control users.

<!-- MARK: - 16. VoiceOver Requirements -->
## 16. VoiceOver Requirements

VoiceOver requirements are workflow-based. Meaningful labels, values, traits, grouping, useful hints, dynamic state updates, focus restoration, announcement timing, adjustable controls, reorder actions, modal behavior, lists, tables, scorecards, and custom baseball controls must be evaluated in complete workflows, not only by static label inspection.

Labels should name product meaning: "visiting team batting, top of third, one out", "runner on second", "current batter", "lineup position four", "purchase pending", or "import conflict". Values should expose current state. Hints should be used only where they reduce uncertainty and should not repeat the label.

VoiceOver output must avoid duplicate or noisy speech during live scoring. Users need access to full context, but rapid scoring requires concise announcements and a way to request detail. Custom-drawn scorecards and bases require semantic equivalents because drawn shapes do not provide enough baseball meaning on their own.

<!-- MARK: - 17. Dynamic Type and Text Layout -->
## 17. Dynamic Type and Text Layout

Dynamic Type support requires reflow rather than clipping for essential workflows. Horizontal controls should become vertical or scrollable where needed, and essential information must not disappear through truncation, tiny fixed columns, or minimum scale factors that make text unreadable.

Current repository evidence shows many fixed frames, dense HStacks, table-like rows, `.lineLimit(1)`, `.minimumScaleFactor`, abbreviated report headers, fixed toolbar button widths, and device-specific iPhone/iPad branches. These are migration risks for large text, compact screens, landscape/portrait changes, and long names.

This design does not invent a specific minimum font-size policy. Observable outcomes are required instead: core actions remain reachable, current game state remains understandable, forms remain editable, alerts and sheets remain readable, scoreboards and scorecards preserve meaning, and reports provide accessible alternatives when dense visual tables cannot scale.

<!-- MARK: - 18. Color, Contrast, and Visual Differentiation -->
## 18. Color, Contrast, and Visual Differentiation

Meaning must remain available through text, shape, position, symbol, or semantic value in addition to color. Team colors, home/away indicators, balls, strikes, outs, base occupancy, warnings, errors, selected rows, disabled controls, purchase states, import conflicts, statistical trends, and generated-report statuses cannot depend on color alone.

Current repository evidence shows red and yellow table headers, blue-tinted controls, green/red scoring buttons, gray base shapes, blue selected team names, red limit markers, and premium badges. These visual treatments may remain as supplemental cues only when semantic and textual meaning is also present.

The rewrite must verify light and dark appearance, increased contrast, and Differentiate Without Color. Disabled controls must explain unavailable actions where the consequence is not obvious, especially for gated purchase actions, validation-blocked scoring actions, and unavailable network downloads.

<!-- MARK: - 19. Motor Accessibility and Touch Interaction -->
## 19. Motor Accessibility and Touch Interaction

Core workflows must support sufficient target size and spacing, accidental-activation prevention, one-handed operation where practical, and alternatives to precise gestures. Repeated scoring taps need safeguards against accidental duplicate events without slowing expert users unnecessarily.

Essential actions cannot require drag-and-drop, swipe, long press, multi-finger gestures, timing-sensitive taps, hover, or visual spatial relationships. Where the visual interaction is still available, the equivalent action must be reachable through semantic controls that work with VoiceOver, Switch Control, Voice Control, pointer, trackpad, and keyboard where supported.

Confirmation placement should reduce accidental destructive activation. Undo and correction must be available for mistaken scoring or lineup choices according to the correction boundaries in prior documents. Timeouts and progress states must not silently abandon user work.

<!-- MARK: - 20. Keyboard and Focus Navigation -->
## 20. Keyboard and Focus Navigation

Keyboard and focus navigation must follow logical workflow order through forms, lists, tables, toolbars, sheets, popovers, menus, score-entry controls, report views, import review, and purchase presentation. Focus should be visible where the platform supports visible keyboard focus, and keyboard users must not encounter traps.

Full Keyboard Access, tab navigation, directional navigation, Escape or cancellation behavior, default actions, and modal dismissal should produce product outcomes consistent with touch. This design does not approve a concrete shortcut set; shortcut policy remains an unresolved product decision unless a future design settles it.

Focus restoration matters after modal dismissal, scoring mutation, correction, import completion, purchase return, failed save, and app resume. Focus should return to the preserved workflow location or a meaningful refreshed state, not to a stale button, hidden row, or unrelated toolbar item.

<!-- MARK: - 21. Motion, Animation, Sound, and Haptics -->
## 21. Motion, Animation, Sound, and Haptics

Motion and sensory feedback are supplemental. Reduced Motion must be respected for score transitions, navigation changes, modal presentation, progress indicators, and repeated event feedback where animation is present. Flashing or rapid animation must not be required to understand scoring results, warnings, import conflicts, or purchase state.

Current repository evidence shows use of `withAnimation`, orientation-change animation, progress views, and button press scale effects in custom styles. It does not establish sound or haptic product features. Therefore this design does not invent sound or haptic requirements beyond requiring that silent operation remain possible and that no essential state be communicated only through sound or haptics.

Live scoring should avoid sensory overload. Feedback for repeated events should confirm accepted commands and important warnings without creating a stream of announcements, flashes, or animations that makes field use impractical.

<!-- MARK: - 22. Cognitive Accessibility -->
## 22. Cognitive Accessibility

Cognitive accessibility requires consistent terminology, stable control placement, plain-language errors, progressive disclosure, preserved workflow context, clear current state, undo and correction, reduced memory burden, and consequences explained before destructive changes.

ScoreKeep should use ordinary language where it is clearer than baseball jargon, while preserving efficient expert workflows and accepted baseball terms where they carry precise meaning. Abbreviations in dense reports and scorecards need accessible expansions or summaries.

Users should be able to distinguish current facts from proposed changes: selected lineup versus saved lineup, imported preview versus accepted import, pending correction versus accepted correction, generated report versus source records, and purchase attempt versus confirmed entitlement.

<!-- MARK: - 23. Device-Class and Orientation Differences -->
## 23. Device-Class and Orientation Differences

iPhone compact layouts, iPad regular-width layouts, portrait, landscape, keyboard-attached iPad, pointer interaction, split views, sheets, full-screen covers, and sidebars may differ visually. They must not differ in baseball capability, entitlement meaning, allowance meaning, import interpretation, or source-record ownership.

Current repository evidence includes `NavigationSplitView` on iPad-oriented entry points, iPhone `TabView` entry points, iPhone/iPad branches in many views, full-screen covers for several workflows, and orientation-change handling that forces detail-only scoring layout. These are confirmed behavior and migration risk.

Essential workflows must not end in inaccessible "best viewed in landscape" dead ends. When visual layout order changes, semantic order and focus order should remain coherent. Dense scorecards and reports may need different visual presentations by device class, but they must expose the same underlying baseball meaning.

<!-- MARK: - 24. Offline and Interrupted Operation -->
## 24. Offline and Interrupted Operation

Offline and interrupted operation must preserve existing local records, live scoring where local state permits, corrections, local compatible imports, compatible source-data exports, reports where policy allows, purchase uncertainty, network roster download status, app backgrounding, scene interruption, and meaningful return focus.

Current repository evidence includes local SwiftData records, keychain-backed counters, network roster download with retry behavior, scene-phase purchase loading, and orientation/interruption-sensitive scoring views. Document 25 already distinguishes offline-known entitlement from offline-uncertain entitlement; Document 26 requires those states to be communicated accessibly.

Resume behavior must avoid duplicate scoring, duplicate game creation, duplicate purchase actions, duplicate downloads, duplicate imports, and duplicate allowance consumption. If the app cannot determine whether a prior action completed, the accessible status must communicate uncertainty without worsening user-owned records.

<!-- MARK: - 25. Privacy and Inclusive Interaction -->
## 25. Privacy and Inclusive Interaction

Accessibility metadata should expose the information needed for the current user task without adding unnecessary private player, youth, team, photo, logo, purchase, diagnostic, or support data outside the intended context. Labels and summaries may need player names and numbers during roster or scoring workflows, but they should not create extra data exports or telemetry.

Current repository evidence includes player photos/logos, team logos, screenshot generation, share workflows, purchase diagnostics through user-facing errors, and support-relevant import errors. This design does not invent analytics collection or accessibility telemetry.

Screen recordings, screenshots, system announcements, and lock-screen exposure should be considered only where supported by product evidence and platform behavior. User-chosen sharing remains explicit; accessibility work must not silently broaden what baseball records or media are shared.

<!-- MARK: - 26. Localization and Language Resilience -->
## 26. Localization and Language Resilience

User-facing strings should be localizable and resilient to long translations, locale-sensitive dates and numbers, product seasons and prices, baseball abbreviations, VoiceOver pronunciation, layout expansion, and generated-report language. Strings should avoid concatenated sentence fragments that cannot be translated naturally.

Current repository evidence shows English strings throughout views, localized date formatting in several places, StoreKit display price usage, and baseball abbreviations in scoring and reports. It does not establish supported non-English languages, so this design does not claim any current language support.

The rewrite should separate product meaning from literal control text so localization can change labels without changing commands, baseball facts, compatibility files, or report projections. Generated output should use the same language policy as on-screen reports where product requirements approve it.

<!-- MARK: - 27. Accessibility State and Persistence -->
## 27. Accessibility State and Persistence

Most accessibility behavior should come from system settings and platform infrastructure: VoiceOver, Dynamic Type, increased contrast, Differentiate Without Color, Reduced Motion, Switch Control, Voice Control, Full Keyboard Access, pointer behavior, and related settings. The current repository does not establish ScoreKeep-specific persistent accessibility preferences.

System accessibility preferences must not be copied into canonical baseball records, compatibility files, import/export payloads, scoring events, lineups, pitcher records, purchase records, or allowance records. Presentation may adapt to settings; domain and persistence meaning remains unchanged.

If future ScoreKeep-specific accessibility preferences are approved, they must be presentation preferences only. They cannot change baseball rules, scoring command semantics, entitlement truth, allowance consumption, import interpretation, or generated-output facts.

<!-- MARK: - 28. Determinism and Baseball Correctness -->
## 28. Determinism and Baseball Correctness

Alternate input paths must produce the same validated baseball command and result as touch interaction. VoiceOver, keyboard, Switch Control, Voice Control, pointer, trackpad, touch, and other supported interaction methods must not create separate scoring rules or alternate persistence semantics.

The scoring engine and application services are the shared authority. Accessible controls invoke the same prepared actions, receive the same validation warnings, and commit through the same transaction and replay boundaries. The accessibility layer must not calculate score, outs, runner movement, batting totals, pitching totals, entitlement, or allowance independently.

This also applies to correction, import, export, report generation, game setup, lineup editing, roster download, and purchase-gated workflows. If two input methods request the same command from the same state, they should receive the same accepted result, rejection, warning, or uncertainty classification.

<!-- MARK: - 29. Accessibility and Compatibility -->
## 29. Accessibility and Compatibility

Accessibility improvements must not silently break legacy file compatibility or existing user-owned records. Compatible imports and exports remain governed by Document 21. Persistence and migration remain governed by Document 20. Presentation accommodations may add summaries, labels, grouping, or alternate views, but they must not rewrite source records or compatibility payloads.

Legacy fields and visual scorecard coordinates may remain compatibility evidence, but accessible presentation should consume adapted canonical facts and prepared projections. An accessible summary of a legacy game must identify unknown, unsupported, or warning-limited data rather than guessing missing facts.

Generated accessible descriptions are derived output. They may be regenerated from source facts and replay, but they must not become repair instructions, source records, or compatibility-file authority.

<!-- MARK: - 30. Verification Strategy -->
## 30. Verification Strategy

Accessibility verification must be fixture-backed and workflow-based. It should combine source fixtures, UI automation where appropriate, manual assistive-technology passes, Dynamic Type and contrast runs, keyboard navigation checks, and comparison of baseball results across input paths.

Verification must check baseball results, focus order, spoken context, visible context, preserved workflow, absence of clipping in essential surfaces, color-independent meaning, duplicate prevention, purchase honesty, allowance integrity, and unchanged source records where no baseball command occurred.

Static accessibility-label inspection is insufficient. A control may be labeled and still be unusable if focus order is wrong, state is ambiguous, Dynamic Type clips the button, a required action is swipe-only, the scorecard has no semantic equivalent, a paywall loses entered setup data, or alternate input produces different baseball results.

<!-- MARK: - 31. Required Verification Scenarios -->
## 31. Required Verification Scenarios

Verification fixtures and release testing should cover creating and editing a team with VoiceOver, creating a complete roster, editing batting order without drag-and-drop, setting up a game at large text sizes, scoring a plate appearance with VoiceOver, repeated scoring actions without duplicate events, correcting a prior scoring event, performing a substitution, and reviewing inning, score, outs, count where represented, and base occupancy.

Import, export, report, and purchase scenarios should cover importing a compatible roster, handling a malformed import, exporting compatible source data, opening hitting and pitching statistics, generating or reviewing a report where policy permits, encountering a paywall, purchasing, canceling, failing, pending, restoring, checking status, continuing with a free allowance, and preserving existing data without entitlement.

Environment scenarios should cover offline operation, resume after interruption, destructive-action confirmation, large accessibility text sizes, increased contrast, Differentiate Without Color, Reduced Motion, hardware keyboard navigation, iPhone portrait, iPhone landscape, iPad regular width, dark appearance, and light appearance.

<!-- MARK: - 32. Release Requirements -->
## 32. Release Requirements

Accessibility failures in core scoring and correction workflows are release concerns, not optional polish. A release should be blocked when a core scoring action is unavailable through an accessible interaction path, live game state is incorrect or ambiguous, an event cannot be corrected accessibly, critical controls are unreachable by VoiceOver or keyboard where applicable, or keyboard/focus traps block workflow completion.

Release should also be blocked when essential meaning is communicated only by color, large text makes core actions unusable, destructive actions have unclear consequences, a paywall or purchase flow strands the user or loses pending work, alternate input produces different baseball results, or accessibility changes cause data loss or compatibility regression.

Duplicate scoring, purchase, download, import, game-creation, or allowance side effects caused by focus, repeated activation, app resume, or delayed announcements are release blockers. Lower-priority improvements may include polish to secondary labels, non-critical report formatting, or convenience navigation after core workflows have verified equivalent outcomes.

<!-- MARK: - 33. Legacy Mapping and Risks -->
## 33. Legacy Mapping and Risks

Relevant legacy evidence includes `ScoreGameView`, `PlayersToScoreView`, `drawAtbatView`, and `drawCardView` for live scoring and custom scorecard graphics; `EditScoreView` for scoring navigation, reports, orientation handling, and paywall gates; `StartingLineupView`, `ReplacementView`, and `PitchersStaffView` for lineup, substitution, and pitcher workflows; `ImportPlayersView`, `ImportDisplayView`, `ShareContentView`, and `DownloadFiles` for import, export, sharing, and roster downloads; `ReportView`, `PitcherRptView`, `ShowReportView`, `ShowPitchRptView`, `GeneratePDF`, and `PdfView` for generated output; and `PaywallView`, `PurchaseManager`, `PremiumBadgeView`, and `KeychainBackedCounter` for purchase and allowance behavior.

Specific migration risks confirmed by inspection include fixed frames, dense scoreboards and tables, icon-only search buttons in some places, color-coded state, drag-only lineup reordering instructions, swipe-only deletion instructions in import review, custom drawings without broad semantic equivalents, focus loss risk after score mutation, repeated announcements risk in live scoring, Dynamic Type clipping risk from dense layouts, iPad/iPhone behavior drift, full-screen covers and sheets that may not restore focus, and purchase/error messages that do not consistently state whether baseball data or allowances changed.

The rewrite does not need to preserve inaccessible implementation patterns. It needs to preserve user-owned records, baseball meaning, compatible file behavior, and verified product outcomes while retiring or wrapping risky presentation patterns.

<!-- MARK: - 34. Migration and Coexistence -->
## 34. Migration and Coexistence

Accessible presentation can be introduced incrementally while legacy and rewritten workflows coexist, but each baseball command needs one semantic action path through application services. The same validation and transaction boundary must apply regardless of whether the command started from a legacy visual route or a rewritten accessible route.

Accessibility wrappers, prepared summaries, alternate tables, or scorecard descriptions must not become alternate domain logic. They consume prepared state and invoke shared commands. Verification must prove no duplicate side effects before a legacy route is retired or a rewritten route becomes primary.

Incremental replacement must not make a previously usable workflow inaccessible. During coexistence, focus and announcement ownership should be explicit for each workflow so sheets, full-screen covers, split views, and resumed actions do not compete for state or create duplicate commands.

<!-- MARK: - 35. Open Product Questions -->
## 35. Open Product Questions

The exact supported Dynamic Type range for the densest scoring surfaces remains unresolved. The rewrite must decide whether the traditional scorecard remains visually dense at the largest sizes with alternate summaries, reflows into a different structure, or uses a separate accessible review mode backed by the same projection.

The appropriate VoiceOver announcement frequency during rapid scoring remains unresolved. Users need enough state to continue scoring accurately, but complete announcements after every event may be too slow for field use. This requires workflow testing with real scoring scenarios.

The semantic representation of the traditional scorecard, accessible alternatives to lineup and batting-order drag operations, keyboard command policy, expectations for exported PDFs, alternate-text summaries for generated scorecards, treatment of team colors and logos, landscape-only legacy surfaces, older supported OS behavior, localization scope, and user research with assistive technologies remain open decisions.

<!-- MARK: - 36. Assumptions -->
## 36. Assumptions

This design assumes ScoreKeep remains an iPhone and iPad app based on repository project settings showing iPhone and iPad targeted device families and iPhone OS deployment targets. It assumes the rewrite continues the architectural boundaries in Documents 17 through 25 and treats legacy SwiftUI code as behavior and compatibility evidence.

It assumes system accessibility settings are the primary source of user accessibility preferences because the repository does not show ScoreKeep-specific persistent accessibility settings. It assumes local baseball records remain user-owned regardless of purchase state, as established by prior functional and design documents.

It assumes generated output accessibility will be verified by report type and output channel rather than promised globally. It also assumes keyboard behavior, PDF accessibility scope, and large-text scorecard policy need product decisions before implementation.

<!-- MARK: - 37. Success Criteria -->
## 37. Success Criteria

Document 26 succeeds when accessibility is treated as a core architectural boundary in the rewrite, when semantic baseball actions are shared across input methods, and when presentation accommodations preserve baseball truth, compatibility, purchase honesty, allowance integrity, and user-owned records.

A rewritten core scoring workflow should be usable without relying solely on the visual scorecard. A rewritten correction workflow should allow a user to identify, understand, confirm, or cancel changes accessibly. Roster, lineup, import, report, purchase, and error workflows should preserve context and communicate outcomes honestly.

Verification should demonstrate equivalent outcomes across supported input methods and settings. Remaining unresolved decisions should be documented as product questions, not hidden as implementation details.

<!-- MARK: - 38. Recommended Next Design Document -->
## 38. Recommended Next Design Document

The next design document should be `ScoreKeep Technical Design — 27 Testing, Fixture Architecture, and Release Verification Design`.

Documents 17 through 26 define the major domain, scoring, persistence, compatibility, presentation, workflow, reporting, purchase, allowance, and accessibility boundaries. The next architectural need is a unified verification design that turns those boundaries into executable fixtures, regression scenarios, acceptance gates, release blockers, and migration confidence across legacy coexistence and rewritten workflows.

Document 27 should specify how baseball fixtures, compatibility files, import/export round trips, scoring replay, generated reports, purchase-state simulations, accessibility workflows, offline/interruption cases, and release acceptance are organized and maintained without making tests the source of product policy.

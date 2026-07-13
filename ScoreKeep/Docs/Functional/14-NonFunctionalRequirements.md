# ScoreKeep Functional Specification — 14 Non-Functional Requirements

## 1. Overview

Non-functional requirements define the quality standards ScoreKeep must meet while providing its baseball, roster, reporting, import, export, purchase, and support features. They describe how well the product must work, how safely it must preserve user records, and how consistently it must behave across ordinary and exceptional use.

ScoreKeep must not merely provide features. It must provide them with sufficient reliability, responsiveness, accuracy, accessibility, compatibility, recoverability, maintainability, and usability for real scorekeeping work.

Live scoring and protection of user-owned baseball data are the highest priorities. A rewritten application is successful only when users can trust it during an active game and can trust it over time with teams, players, rosters, lineups, scoring events, photos, logos, reports, imports, exports, purchase status, and preferences.

## 2. Quality Priorities

Product quality should be judged in the following priority order:

1. Prevent loss or corruption of baseball records.
2. Preserve accurate and understandable scoring state.
3. Keep live scoring responsive and usable.
4. Maintain compatibility with existing ScoreKeep data and workflows.
5. Support offline operation for local baseball work.
6. Provide accessible and understandable interaction.
7. Produce consistent statistics, scorecards, box scores, reports, and PDFs.
8. Keep purchase and network failures from blocking local data.
9. Support safe future maintenance and expansion.

When two quality goals conflict, the choice that best protects user-owned records and scoring accuracy should prevail. Convenience, presentation, optional media, remote information, purchase status, and cosmetic behavior must not take precedence over preserving a coherent baseball record.

Performance improvements are acceptable only when they preserve confirmed data, avoid duplicate actions, and keep the user aware of work that is still pending. Compatibility changes are acceptable only when existing records remain accessible, intentionally migrated, or clearly disclosed as unsupported.

## 3. Reliability

ScoreKeep should launch reliably into a usable state. Failure to load optional media, remote announcements, purchase information, or external content must not prevent users from opening local records and continuing ordinary baseball workflows.

Opening saved teams, players, games, rosters, lineups, pitcher records, scoring history, preferences, and reports should produce repeatable results. A saved record should not sometimes appear complete and sometimes appear damaged unless the underlying record truly cannot be understood.

Creating teams and players should preserve entered information through validation and correction. A failed save should leave the user able to continue editing instead of losing valid entered values.

Creating games should produce a clear draft or playable game state. If required setup is incomplete, the app should identify what is missing without creating misleading records.

Live scoring should not crash during ordinary play entry, inning transitions, lineup use, pitcher changes, substitutions, corrections, or completion of a game. Repeated ordinary use should produce consistent saved results.

Saving completed plays should either complete with a coherent scoring event or leave the prior playable state intact. A partial operation must not leave a phantom at-bat, duplicate run, duplicated out, ambiguous runner, or misleading inning transition.

Lineup changes, pitcher changes, and substitutions should be reliable enough for use during an active game. If a change cannot be completed safely, the previous scoring context should remain usable.

Corrections should reliably update the affected game state without requiring users to rebuild unrelated innings or records. Reports and summaries created after a correction should reflect the corrected source record.

Imports should fail safely. Invalid, malformed, unsupported, ambiguous, or interrupted imports should not damage unrelated local records. Exports should fail without altering the source records.

Report and PDF generation should leave the source game unchanged whether generation succeeds, is canceled, or fails. Purchase failures should not alter baseball records or consume allowances for unsuccessful qualifying actions.

Settings should apply predictably and remain separate from baseball records. Preference problems should not delete or rewrite teams, players, games, lineups, scoring events, media, reports, or purchase-related state.

The app should recover safely after interruption, including backgrounding, termination, device restart, window closure, low-resource conditions, or returning after a long absence. The user should return to the latest coherent state that can be represented honestly.

## 4. Data Integrity and Durability

Teams, players, rosters, games, lineups, scoring events, pitchers, substitutions, photos, logos, reports, preferences, and purchase-related state should be preserved according to their product meaning. A record that was confirmed by the user should remain available unless the user deliberately deletes it or an explicitly disclosed unsupported condition prevents access.

Confirmed scoring events should remain saved across ordinary launches, interruptions, and device restarts. The saved game should remain understandable as a sequence of baseball facts, including score, inning, outs, runners, batting order, pitcher participation, and substitutions.

Partial operations must not leave misleading records. If a team, player, game, play, lineup, substitution, pitcher change, import, export, report, or setting cannot be completed, the app should either preserve the prior state or clearly mark the incomplete state as not yet authoritative.

Corrections should update dependent information consistently. Scores, runs, hits, errors, outs, base runners, pitcher records, batting statistics, pitching statistics, scorecards, box scores, and reports should not contradict the corrected game record.

Deletion should affect only confirmed target records. Deleting a photo should not delete a player. Deleting a logo should not delete a team. Deleting a report output should not delete the source game. Removing a player from current roster use should not silently erase historical participation.

App updates must not silently delete supported data. If existing records require a compatibility transition, the user should receive an honest explanation and a safe path for review, correction, export, or support where practical.

Preference resets must not affect baseball records. Premium expiration must not affect data ownership. Purchase uncertainty, restore failure, cancellation, or service unavailability must not delete, hide, or rewrite user-owned baseball data.

Historical records should remain understandable after later edits. Changes to current player details, team information, photos, logos, lineups, or preferences should not silently change the meaning of past games and reports.

## 5. Performance and Responsiveness

App launch should reach a usable local state without unnecessary delay from optional media, remote announcements, purchase checks, or network availability. If a remote feature is still loading, local records should remain available.

Opening game lists, team lists, player lists, and roster views should support normal browsing, searching, sorting, and selection without visible stalls that make the app feel unavailable. Large but realistic collections should remain manageable.

Beginning live scoring should be quick enough for use at the field. The app should not require avoidable waiting between game setup, lineup confirmation, pitcher selection, and the scoring screen.

Recording a plate appearance, completing a play, advancing to the next batter, changing pitchers, recording substitutions, and opening corrections should feel immediate in ordinary game sizes. When work may take longer, the interface should show honest progress or status.

The user interface must remain responsive during local operations. Long-running report generation, import review, export preparation, image processing, or compatibility checks should not make unrelated visible controls appear broken.

Optional images should not delay live scoring. Player photos and team logos should enhance display, reports, and recognition, but missing, large, or slow-loading images must not prevent play entry.

Large rosters, long batting orders, extra-inning games, many substitutions, many pitchers, and long scoring histories should remain usable. The app should communicate practical limits before failure rather than becoming unresponsive or creating unsafe records.

Repeated taps must not create duplicate actions. Buttons, scoring controls, saves, imports, exports, purchases, and report generation should make pending state clear enough to prevent accidental duplication.

## 6. Live-Scoring Responsiveness

Live scoring has a dedicated quality standard because it occurs under time pressure. The current game state should remain visible, including teams, score, inning, half inning, outs, current batter, runners, lineup context, and pitcher context where relevant.

Common scoring actions should require minimal delay and minimal navigation. The app should keep pace with real baseball play and should not force repeated transitions for routine plate appearances.

Save behavior should protect records without interrupting every plate appearance unnecessarily. The user should be able to complete a play and continue scoring with confidence that the prior play was captured or that an unresolved issue is visible.

Pitching changes and substitutions should return quickly to scoring. The user should not have to rediscover the active game, lineup, inning, or batter after making a change.

Corrections should remain available during scoring without rebuilding unrelated innings. Correcting a prior play should update affected totals and state while preserving the user's orientation in the game.

Backgrounding, rotation, window changes, and temporary interruption should not lose the current scoring context. On return, the app should show the latest coherent state and make any unresolved action clear.

Performance should remain acceptable in extra-inning games, large lineups, and games with many substitutions or pitcher changes. Network access must never be required to record local plays.

## 7. Accuracy and Consistency

Scores, runs, hits, errors, outs, innings, base runners, batting order, lineups, pitcher participation, batting statistics, pitching statistics, scorecards, box scores, reports, PDFs, imported games, and exported games should all represent the same saved game facts.

The same saved game should produce consistent results in every view. A score summary, scoring grid, scorecard, box score, report, PDF, export, and reopened game should not disagree about the same recorded play.

Reports should not use stale or contradictory totals. If a correction changes a run, hit, error, out, runner movement, pitcher attribution, lineup position, or substitution history, all affected outputs generated afterward should reflect the corrected record.

Missing data should remain visibly missing rather than becoming invented facts. Unknown pitchers, incomplete optional media, missing player details, skipped imported values, or unsupported optional content should be represented honestly.

Historical reports should remain explainable from the saved game record. A user should be able to understand why a total, score, lineup entry, pitcher result, or participation value appears without needing hidden or contradictory state.

Imported and exported games should preserve supported baseball meaning. Compatibility behavior must not silently reinterpret scores, lineups, pitcher participation, substitutions, photos, logos, or statistical facts.

## 8. Offline Operation

ScoreKeep should support reliable local use without Internet access. Existing teams, existing players, existing games, new local game setup, live scoring, corrections, lineups, pitchers, substitutions, local reports, local imports, local exports where system destinations permit, preferences, and bundled help should remain available offline.

Network-only features may become unavailable offline. Roster downloads, remote announcements, external links, purchase refreshes, and online support paths may show unavailable status, but they must not block local records or local scoring work.

Offline state should be honest. The app should distinguish unavailable remote information from missing local records, failed local data access, or purchase uncertainty.

A user who remains offline for days should still be able to maintain local teams, score games, review records, and prepare local outputs within the normal limits of the product. Reconnection should not rewrite local baseball records unexpectedly.

## 9. Scalability and Data Volume

ScoreKeep should remain usable as users accumulate many teams, many seasons, many players, large rosters, many completed games, extra-inning games, long batting orders, many substitutions, many pitchers, large imported files, photos, logos, and historical reports.

Lists should remain searchable and sortable. Large collections should not make ordinary navigation unusable or force users to remember exact record locations.

Fixed-size assumptions must not cause crashes or data loss. Batting orders beyond legacy limits should remain safe, extra innings should remain safe, and reports should remain usable for realistic long games.

Large imported files should be reviewed in a way that lets users understand scope, conflicts, skipped records, and practical limits before local data changes. Large photos and logos should not block unrelated scoring and roster workflows.

The app should communicate practical limits rather than fail unpredictably. When a record, file, roster, game, report, or media item is too large or too complex to complete safely, the user should receive a clear explanation and a safe next action.

## 10. Accessibility Quality

Accessibility is a release requirement, not an optional enhancement. Core workflows should be usable with VoiceOver, larger text, high contrast, reduced motion, color-independent state, reachable controls, meaningful focus order, accessible forms, accessible scoring controls, accessible reports, and accessible warnings and confirmations.

Live scoring should remain usable under supported accessibility settings. The user should be able to identify the current game state, select scoring actions, complete plays, correct mistakes, change pitchers, record substitutions, and return to the game without inaccessible controls or hidden state.

Text should remain readable and controls should remain operable when larger text or constrained layouts are active. Controls should not depend only on color, position, animation, or visual styling to communicate state.

Forms should identify required fields, invalid values, selected records, destructive actions, and recovery choices in accessible language. Alerts and confirmations should expose their purpose, affected records, and available actions.

Reports and generated summaries should remain understandable to users relying on accessibility features. Dynamic accessibility changes should not require restarting the app or losing current work.

## 11. Usability and Learnability

ScoreKeep should be learnable by users who understand baseball without requiring them to understand product internals. Major workflows should be discoverable, including creating teams, adding players, setting lineups, creating games, scoring plays, correcting mistakes, changing pitchers, recording substitutions, importing, exporting, reporting, and managing premium access.

Baseball terminology should be clear and consistent. Action names should remain consistent across screens so users do not have to learn different terms for the same product behavior.

Game status should be understandable at a glance. The app should make clear whether a game is a draft, ready to score, currently being scored, completed, corrected, imported, or being reviewed.

The distinction between roster membership, lineup position, current game participation, substitution history, and historical participation should be visible where it matters. Users should not have to infer whether a player is on a team, in a lineup, active in the current game, or preserved only in history.

Destructive confirmations should be clear and scoped. Empty states should be useful. Mistakes should be recoverable where practical, especially during scoring, lineup setup, import review, and report generation.

Help should be available in context for workflows that are uncommon, risky, or compatibility-sensitive. Returning users should be able to resume familiar workflows without unnecessary onboarding or hidden state.

## 12. Compatibility

ScoreKeep should preserve compatibility with existing local ScoreKeep data, `.ScoreKeep_Players`, `.ScoreKeep_Games`, existing document-opening behavior, existing deep links, the existing website roster manifest, existing downloadable roster files, existing announcement behavior, the existing StoreKit season product meaning, existing iPhone and iPad support, existing photos and logos, and historical reports.

Compatibility changes require explicit migration planning and verification. Unsupported data should be disclosed in product language, including the affected file, record, or feature scope where practical.

Silent truncation is not acceptable. If a record contains information that cannot be supported, the app should preserve what can be safely preserved, disclose what was skipped or unsupported, and avoid presenting partial data as complete.

Existing document-opening and deep-link workflows should either continue to work or fail with an understandable explanation and a safe alternative where practical.

Legacy compatibility verification is required before release. Established roster and game fixtures should be used to confirm that supported records still open, import, export, and report correctly.

This document does not define file formats or migration details. It defines the quality expectation that compatible user records remain understandable and safe.

## 13. Platform and Device Support

ScoreKeep should provide equivalent core functionality on supported iPhone and iPad sizes. Layout differences may improve presentation, but they must not alter baseball meaning, remove required actions, or change saved game state.

Portrait and landscape, Split View, Stage Manager, narrow windows, wide windows, external keyboards, touch interaction, system share workflows, current supported iOS versions, and future supported platform updates should be verified for core workflows.

Unsupported sizes or constrained layouts should fail safely. The app should preserve work and explain limitations rather than hiding critical controls, overlapping content, or losing active scoring context.

Device-name localization must not determine capability. Platform behavior should be based on supported product capabilities and verified layouts, not on fragile device labels.

Platform updates require regression verification. Changes in window behavior, sharing, document opening, purchase services, permissions, accessibility, or media handling should be reviewed before release.

## 14. Error Handling and Recoverability

Failures should provide honest status, clear recovery action, preservation of context, no false success, no repeated alert loops, no duplicated actions after retry, safe handling of network failures, safe handling of purchase failures, safe handling of invalid files, recovery after interruption, and a support path for unresolved problems.

A failed operation should tell the user what happened, which record or action was affected, whether saved data changed, and what can be done next. If the app cannot know whether an external operation completed, it should state uncertainty rather than claiming success.

Recovery should return the user as close as possible to the affected game, team, player, import, export, report, purchase action, or setting. Live scoring recovery should preserve the active game context whenever safe.

The Error Handling and Recovery specification is the detailed authority for failure categories, user-facing messages, validation errors, live-scoring errors, import and export failures, purchase failures, interruptions, and support paths.

## 15. Security and Privacy Quality

ScoreKeep should preserve user data ownership, deliberate sharing, careful handling of optional media, imported-file review, understandable permissions, limited support information, purchase-state separation, clear data retention expectations, and honest backup and transfer expectations.

Teams, players, rosters, games, lineups, scoring events, pitcher records, substitutions, reports, photos, logos, imports, exports, and preferences are user-owned product data. Purchase status may affect access to selected capabilities, but it must not determine ownership of existing baseball records.

Sharing should occur only through visible user action. Imported files should be reviewed before they change local records. Optional photos and logos should not become hidden requirements or leave the app merely because they are stored locally.

Security behavior should protect records without locking users out of their own compatible data. Support information should help diagnose the visible problem without exposing unrelated sensitive records.

The Security, Privacy, and Data Protection specification is the detailed authority for ownership, data minimization, media, import review, export privacy, permissions, support, retention, device changes, and purchase separation.

## 16. Maintainability

ScoreKeep should remain maintainable as a product. Baseball rules and calculations should have one consistent meaning throughout scoring, correction, reporting, importing, exporting, and display.

Duplicate behavior should be reduced where it creates inconsistent results or makes future changes unsafe. Major functional responsibilities should remain understandable to future maintainers and reviewers.

Changes should be isolated enough to verify without rewriting unrelated workflows. Compatibility behavior should be documented so supported legacy records do not depend on accidental behavior.

Product rules should not be hidden only in screen behavior. Scoring meaning, lineup meaning, pitcher attribution, substitution history, import decisions, export meaning, premium gates, and report facts should be understandable as product rules.

New features should not require rewriting unrelated workflows. Legacy behavior should be retained only when required for compatibility or approved product behavior.

Documentation should remain synchronized with intentional product changes. When a release changes scoring, data ownership, compatibility, accessibility, error handling, reporting, purchase gating, or platform support, the relevant product documentation should be updated.

## 17. Testability

ScoreKeep should be verifiable through repeatable product checks. Baseball calculations should be testable independently of presentation. Import and export should support round-trip verification. Game lifecycle transitions should be verifiable from setup through completion and later review.

Scoring corrections should be verifiable, including their effects on score, outs, runners, innings, batting order, statistics, pitcher attribution, scorecards, box scores, and reports.

Lineup history, substitution history, pitcher participation, batting statistics, pitching statistics, and report values should be verifiable against saved game facts.

Premium gates should be verifiable without changing baseball data. Offline behavior should be verifiable for local records, scoring, corrections, imports, exports, reports, preferences, and bundled help.

Accessibility should be evaluated for core workflows, including live scoring, forms, lists, reports, warnings, and confirmations.

Failures and interruptions should be safely simulated. Legacy roster and game files should be retained as regression fixtures so compatibility can be verified before release.

## 18. Observability and Supportability

Failures should be diagnosable without exposing sensitive data. Support summaries should identify the app version, workflow, affected visible record or file where appropriate, and visible error condition.

Users should not need to understand internal implementation to request help. Repeated failures should provide a support path that preserves context and distinguishes local data issues, compatibility issues, purchase uncertainty, permission problems, and network unavailability.

Compatibility and import failures should identify the affected file and scope. The user should know whether the whole file was rejected, some records were skipped, a duplicate needs review, media was omitted, or unsupported content was found.

Purchase uncertainty should remain separate from baseball-data support. A purchase problem should not be reported as a data-loss problem unless local records are actually affected.

Diagnostic behavior must not alter user records, consume allowances, complete purchases, change scorekeeping state, or rewrite imported data.

## 19. Release Readiness

A rewritten ScoreKeep release is ready only when product quality has been verified for supported configurations and no known data-loss defects remain unresolved.

Release readiness requires a clean build for supported configurations, a usable verification action, core regression checks passing, legacy roster and game files verified, existing user data migration verified, live scoring tested through complete games, extra innings tested, long batting orders tested, lineups and substitutions tested, pitcher changes tested, reports and PDFs verified, imports and exports round-trip verified, free limits and premium gates verified, offline operation verified, accessibility review completed, crash-prone legacy scenarios covered, and documentation updated.

Release review should confirm that optional media failures, network failures, purchase failures, invalid files, interrupted operations, constrained layouts, and platform-specific behavior do not put local baseball records at risk.

A release should not proceed when a known defect can delete, corrupt, hide, duplicate, or materially misrepresent user-owned baseball records in a supported workflow.

## 20. Acceptance Metrics

Acceptance measures should focus on observable outcomes tied to product needs. ScoreKeep should demonstrate no data loss during supported interruption scenarios, no crash during supported game lengths and roster sizes, consistent score and statistics across views, successful opening of established compatibility fixtures, and safe rejection of invalid files.

Free counters should change only after qualifying successful actions. Existing data should remain accessible after premium expiration. Core workflows should work offline. Critical accessibility tasks should be completable. Repeated scoring and correction should not create duplicate records.

Saved games should reopen with the same understandable state. Reports and PDFs generated from a saved game should match that game's facts. Import cancellation should leave local records unchanged. Export failure should leave source data unchanged.

Measurable targets should be added where they reflect real user experience or safety needs. Arbitrary numbers should not replace product judgment, but quality failures should be reproducible and tied to clear acceptance outcomes.

## 21. Validation Requirements

Non-functional quality failures should be treated as release-blocking or remediation-required when they risk data safety, live scoring, accessibility, compatibility, or user trust.

Validation should specifically cover noticeable scoring lag, repeated duplicate actions, inconsistent report values, data missing after restart, extra-inning crash, long-lineup crash, large-roster list unusability, inaccessible controls, unexpectedly blocked offline workflows, legacy file opening failures, app updates that make records inaccessible, purchase failures that block existing data, error recovery that loses context, layout changes that lose active work, and report generation that changes source data.

When validation finds a failure, the release decision should account for severity, affected workflow, recoverability, compatibility impact, accessibility impact, and risk to user-owned records. Workarounds are acceptable only when they are visible, reliable, and do not shift unreasonable risk to users.

Known data-loss, data-corruption, score-misrepresentation, or inaccessible-core-workflow defects should not be deferred into a release without an explicit product decision and clear user protection.

## 22. Data Integrity Requirements

Quality optimizations must never weaken baseball-data integrity. Performance improvements must not skip required confirmation, hide pending state, or create duplicate scoring events.

Background work must never create duplicate records, complete unintended actions, or silently alter game state. Compatibility updates must never silently truncate records.

Layout adaptations must not change game state. Reports must never become independent sources of truth. Testing, diagnostics, and support behavior must never alter production allowances or user records.

Failed migrations should preserve recoverable prior data. Release updates must never knowingly ship with unresolved data-loss defects in supported workflows.

Maintainability changes should preserve documented user behavior unless an approved specification changes it. When product behavior intentionally changes, compatibility, documentation, validation, and user communication should be updated together.

## 23. Exceptional Situations

ScoreKeep should handle exceptional situations with safe, understandable product behavior. These situations include very large rosters, games extending far beyond regulation innings, long scoring sessions, limited available device storage, repeated backgrounding, network unavailability for days, years of historical games, partially malformed legacy data, extremely large optional images, report generation taking longer than expected, unavailable purchase service, platform updates changing system behavior, accessibility settings creating very constrained layouts, app updates encountering old or unusual records, and multiple windows where supported.

A very large roster or long historical list should remain searchable, sortable, and cancellable where appropriate. A game far beyond regulation should not crash or corrupt innings, batting order, pitcher records, substitutions, or reports.

Limited storage should be communicated honestly before or during operations that need space for imports, exports, reports, media, or updates. The app should preserve existing records when new output cannot be created.

Repeated backgrounding should not duplicate actions, lose current scoring context, or create partial records. Long network outages should not block local scoring and review.

Partially malformed legacy data should be rejected, skipped, or held for review according to its risk. Extremely large images should not block live scoring. Long report generation should show honest status and should not change source records.

Purchase service unavailability should keep existing data accessible. Platform changes should trigger regression verification. Highly constrained accessibility layouts should preserve control reachability and prevent overlap that hides critical state.

Multiple windows should preserve coherent record ownership and avoid conflicting edits where supported. If simultaneous work cannot be represented safely, the app should communicate the limitation before records are put at risk.

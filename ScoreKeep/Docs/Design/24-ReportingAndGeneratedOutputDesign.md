# ScoreKeep Technical Design — 24 Reporting and Generated Output Design

<!-- MARK: - 1. Purpose -->
## 1. Purpose

Reporting and generated output need a dedicated design because they are where users confirm whether ScoreKeep's recorded game still makes baseball sense after scoring, correction, import, migration, sharing, printing, or review. A report is often treated by the user as the visible result of the game, even though architecturally it must remain a derived projection.

Current repository evidence shows why this boundary matters. Batting reports, pitching reports, scorecard PDF generation, score summaries, screenshot output, and share workflows calculate or capture output directly from legacy records in several places. Runs are often counted from `Atbat.maxbase == "Home"`, batting and pitching totals are recalculated in report views and PDF views, pitcher windows are inferred from marker fields, and stored scores remain available as legacy fields. Those behaviors are product and compatibility evidence, but they are not the architecture to preserve.

Generated output is derived from canonical recorded facts and scoring-engine replay. Reports, PDFs, scorecards, summaries, box scores, screenshots where supported, printed output, and exported summaries must not become independent sources of baseball truth. Opening, previewing, printing, sharing, screenshotting, or regenerating output must not mutate source records. Corrections change recorded facts through application services, replay the game, and regenerate affected projections.

<!-- MARK: - 2. Reporting Principles -->
## 2. Reporting Principles

ScoreKeep has one baseball truth: canonical recorded facts interpreted by the scoring engine. Reports are projections from that truth. Generated output is read-only from the perspective of baseball records. It may be saved, shared, printed, or retained as an external artifact, but it cannot override scoring events, lineups, substitutions, pitcher appearances, participants, or lifecycle state.

No reporting workflow may mutate source records merely because output was requested. A report preview may expose warnings, stale output, unsupported legacy values, or repair needs, but repair requires a separate confirmed command.

Outputs must be consistent with each other. Game summaries, line scores, box scores, batting reports, pitching reports, scorecards, PDFs, exports, reopened games, and accessible descriptions should agree for the same saved facts and interpretation policy. If a correction changes facts, later generated output must reflect the corrected replay.

Incomplete data remains visibly incomplete. Unknown pitchers, missing participants, incomplete lineups, unsupported results, score mismatches, ambiguous substitutions, and compatibility-limited games should not be hidden by formatting. Purchase gates may limit designated generated output or advanced reports, but they do not control ownership of source baseball data.

<!-- MARK: - 3. Scope and Responsibilities -->
## 3. Scope and Responsibilities

The reporting subsystem owns report preparation, selected scope, projection selection, formatting requirements, output-generation requests, pagination requirements, warning placement, accessible report descriptions, preview state, generated-output identity, and sharing preparation.

It also owns conceptual consistency between report surfaces: on-screen summaries, batting and pitching reports, box scores, scorecards, PDFs, printed output, screenshot/image output where supported, and export summaries. It should define what warnings accompany a report and what output can be produced from a warning-limited game.

The subsystem does not own scoring rules, statistical authority, persistence writes, SwiftUI navigation, StoreKit behavior, import compatibility authority, file-format authority, or concrete drawing mechanics. It asks application services for prepared report state, consumes replay-derived projections, and returns output artifacts or failures without changing baseball facts.

<!-- MARK: - 4. Architectural Position -->
## 4. Architectural Position

Presentation collects report choices and displays prepared report state. Application services load the selected game, team, player, season, or date range; request replay and projection data; apply purchase or allowance checks where product policy requires; coordinate PDF, print, share, or screenshot workflows; and return prepared output or failure.

The canonical domain defines recorded facts and historical identity. The scoring engine replays those facts and produces derived game, scorecard, batting, pitching, line-score, and warning projections. Persistence loads source records and may store non-authoritative caches or retained output metadata only as derived data. Compatibility adapters preserve legacy evidence and expose limitations. Report projections format the replay result for each output category.

PDF generation, printing, image capture, and system sharing consume report projections. They are output channels, not baseball interpreters. A system share sheet or print dialog may succeed, fail, or be canceled without changing the source game.

<!-- MARK: - 5. Report Categories -->
## 5. Report Categories

Supported conceptual categories are game summary, line score, box score, batting report, pitching report, scorecard, team report, player report, historical or multi-game report, PDF output, printed output, export summary, and screenshot or image output where supported by repository evidence.

The current repository contains batting report and pitching report views, generated report PDFs, scorecard PDF generation, manual PDF viewing, screenshot capture helpers used by report views, and system sharing through `ShareLink`. It also contains score summaries and scorecard drawing paths. These support the categories above as product evidence.

This design does not invent standings, league leaderboards, spray charts, advanced analytics, cloud dashboards, video reports, or new public file formats. Future report types require separate product evidence, specification, and verification.

<!-- MARK: - 6. Report Inputs -->
## 6. Report Inputs

Authoritative report inputs are canonical game facts, replay result, home and visiting participants, lineups, substitutions, pitcher appearances, scoring events, runner outcomes, accepted corrections, lifecycle status, warning state, selected report scope, media choices, and compatibility evidence.

Reports may also consume preferences that affect presentation, such as sorting, visible sections, media inclusion, page size, or output destination. Preferences affect formatting, not baseball meaning.

Legacy fields such as `Atbat.result`, `maxbase`, `outAt`, `inning`, `seq`, `col`, `rbis`, `outs`, `sacFly`, `sacBunt`, `stolenBases`, `earnedRun`, `playRec`, `endOfInning`, `Game.hscore`, `Game.vscore`, pitcher start and end markers, `Game.replaced`, and `Game.incomings` are compatibility evidence. They are report inputs only after adaptation and replay classification.

<!-- MARK: - 7. Report Projection Model -->
## 7. Report Projection Model

A report projection is immutable prepared output. It represents one interpretation of a selected source scope at a specific interpretation policy. Views, PDF generation, print output, share workflows, and accessibility descriptions consume the projection without recalculating baseball facts.

Projection identity should distinguish report type, source game or collection identity, source interpretation version, report scope, warning state, generated-at context where appropriate, and presentation-affecting preferences. A projection for one game summary is not interchangeable with a projection for a multi-game team report.

Projection staleness is a first-class state. If source facts, corrections, lineup history, pitcher appearances, substitutions, migration interpretation, compatibility policy, or relevant report preferences change, existing projections and generated previews become stale. Stale projections can be discarded, refreshed, or shown with clear status, but they cannot override fresh replay.

<!-- MARK: - 8. Recorded Facts Versus Report Values -->
## 8. Recorded Facts Versus Report Values

Recorded facts include who played, who batted, who pitched, what events were accepted, runner outcomes, scoring decisions, substitutions, pitcher appearances, lineup history, lifecycle decisions, and preserved compatibility evidence.

Report values include score, hits, errors, RBIs, batting averages, on-base percentage, slugging percentage, pitching totals, line score, box-score rows, scorecard cells, PDF rows, printed labels, and accessible summaries. These values are derived from replay or shared statistical projections.

For example, a saved play and runner outcome are facts; the run total and line-score inning total are report values. A pitcher appearance boundary is a fact; innings pitched, earned runs, and ERA are report values. A scorecard cell may link back to a recorded event, but the cell itself is not the event.

<!-- MARK: - 9. Game Summary Design -->
## 9. Game Summary Design

A game summary presents the visible identity and current derived state of one game: teams, date, location, lifecycle status, score, inning status, completion state, warnings, and links to available reports or generated output.

The summary must say whether the score is replay-derived, warning-limited, compatibility-limited, or affected by stored-score mismatch. It should not imply finality for an in-progress, interrupted, suspended, draft, imported historical, or compatibility-limited game.

Report links from a game summary request prepared report projections through application services. They do not load raw records into views for local recalculation.

<!-- MARK: - 10. Line Score Design -->
## 10. Line Score Design

The line score presents inning-by-inning runs, final totals where applicable, extra innings, shortened games, incomplete games, stored-score mismatch, and compatibility-limited games.

Inning totals derive from replayed scoring events and runner outcomes. Extra innings extend the line score instead of relying on fixed inning labels. Shortened or suspended games should show the lifecycle decision or limitation rather than fabricating empty regulation innings.

When legacy `hscore` or `vscore` disagrees with replay-derived scoring, the line score must not silently pick the convenient value. It should expose the mismatch and identify whether the report is replay-derived, stored-score evidence only, or blocked pending repair.

<!-- MARK: - 11. Box Score Design -->
## 11. Box Score Design

The box score presents batting and pitching sections, team totals, participant identity, substitutions, unknown participants, and consistency with source facts. It should be generated from the same replay result that drives the game summary, line score, batting report, pitching report, and scorecard.

Batting sections should preserve game-time participant identity, batting slots, incoming and outgoing participants, pinch hitters, pinch runners where represented, and unknown or detached imported players. Pitching sections should use the shared pitching projection described in this design.

Team totals must reconcile with row totals or expose warnings when they cannot. Unknown participants should remain visible instead of being merged into blank or guessed rows.

<!-- MARK: - 12. Batting Report Design -->
## 12. Batting Report Design

The batting report covers plate appearances, at-bats, hits, hit types, walks, strikeouts, sacrifices, RBIs, runs, stolen bases, batting average, on-base percentage, slugging percentage, and unknown or unsupported values where ScoreKeep supports them.

Current report evidence calculates many of these values directly in `ReportView` and `ShowReportView`, including averages, OBP, SLG, OPS, hit types, walks, strikeouts, hit by pitch, dropped third strike, fielder's choice, stolen bases, and legacy sacrifice spellings. Those calculations are evidence of product behavior and migration risk, not the future authority.

Formula policy remains fixture-backed and shared. This design does not settle unsupported formula questions beyond requiring one shared statistical projection for every batting report, PDF, scorecard total, export summary, and accessible description.

<!-- MARK: - 13. Pitching Report Design -->
## 13. Pitching Report Design

The pitching report covers pitcher appearances, innings or outs recorded, batters faced where supported, hits, walks, strikeouts, runs, earned runs, unearned runs, inherited runners, pitcher changes, unknown pitchers, and winning-pitcher indicators where supported.

Current repository evidence shows pitching calculations duplicated in `PitcherRptView`, `ShowPitchRptView`, and `GeneratePDF`. They infer windows from pitcher start and end markers, count runs from `maxbase == "Home"`, use earned-run flags, and compute ERA locally. The rewritten design requires all pitching presentations to use one shared replay-derived pitching projection.

Unknown pitchers, incomplete pitcher periods, zero-out appearances, mid-inning changes, and compatibility-limited pitcher histories must be visible in every pitching output. A report must not attach a pitching result to a named player without supported appearance evidence.

<!-- MARK: - 14. Team Report Design -->
## 14. Team Report Design

Team reports span one or more games for a selected team. The report scope should identify the team identity, date or season filter where present, included games, excluded games, warning state, and whether imported or compatibility-limited records are included.

Draft games, deleted games, archived games, imported historical games, compatibility-limited games, and incomplete games require explicit inclusion policy. The report should not silently aggregate games that have unresolved warnings or incompatible interpretation.

Historical team identity matters. A renamed current team must not rewrite old game reports. Team reports should use game-time team participation and stable identity rather than only the current team name.

<!-- MARK: - 15. Player Report Design -->
## 15. Player Report Design

Player reports cover a selected player across games or scopes where supported. They preserve historical participation despite current roster changes, names, numbers, positions, photos, or team membership.

The source identity for a historical row is the game participant or safely linked reusable player, not a mutable display name alone. Duplicate names, reused numbers, guests, unknown players, and detached imported participants must remain distinguishable.

If a current player is merged, renamed, deleted from active roster use, or assigned new media, historical player report output should remain explainable from the saved game records and their game-time snapshots.

<!-- MARK: - 16. Historical and Multi-Game Report Design -->
## 16. Historical and Multi-Game Report Design

Historical and multi-game reports define date range, season, team, player, completed-game filtering, imported historical records, warning behavior, and aggregation boundaries.

Aggregation should combine verified game-level projections, not raw stale totals. A game with unknown pitcher, incomplete lineup, unsupported result, score mismatch, ambiguous substitution, or incomplete runner movement may be included with warnings, excluded by scope policy, or blocked depending on report purpose.

Completed-game filtering must not imply that imported or legacy records are complete unless lifecycle and replay evidence support that conclusion. Draft, in-progress, interrupted, suspended, shortened, and compatibility-limited games require visible scope labels.

<!-- MARK: - 17. Scorecard Report Relationship -->
## 17. Scorecard Report Relationship

The scorecard projection and broader reporting consume the same replay result. The scorecard must not calculate a competing score, line score, batting total, pitching total, or warning set.

Document 22 defines scorecard presentation, coordinate behavior, live and historical review, print/PDF scorecards, accessibility, fixed-size retirement, and legacy scorecard mapping. This document references that design instead of duplicating its visual rules.

Reports may use scorecard-derived summaries such as line score, batter row totals, pitcher context, warnings, and pagination hints. Those values remain derived projections from replay.

<!-- MARK: - 18. Statistics Calculation Boundary -->
## 18. Statistics Calculation Boundary

Statistics are derived by the scoring engine or shared statistical projection services using replayed facts. Reports and views must not implement duplicate formulas.

This boundary applies to score, runs, hits, errors, RBIs, batting averages, on-base percentage, slugging percentage, OPS where supported, innings pitched, ERA, earned and unearned runs, strikeouts, walks, hit by pitch, stolen bases, sacrifices, and pitcher responsibility.

Presentation may format a prepared value, sort a prepared row, or hide/show optional columns. It may not decide which events count toward the value.

<!-- MARK: - 19. Statistical Formula Policy -->
## 19. Statistical Formula Policy

Statistical formulas should be defined once, documented, fixture-backed, and shared across on-screen reports, PDFs, scorecards, exports, and accessible descriptions.

Formula policy must cover batting average, on-base percentage, slugging percentage, ERA, innings pitched representation, sacrifices, errors, walks, hit by pitch, unknown data, unsupported legacy results, and compatibility-limited records. It should state how incomplete data affects denominators and display.

This design does not settle unsupported baseball-policy questions. Exact formula choices for inherited-run responsibility, user-entered earned-run decisions, administrative scores, or incomplete historical games should be resolved through product policy and verification fixtures.

<!-- MARK: - 20. Correction and Regeneration Behavior -->
## 20. Correction and Regeneration Behavior

Accepted corrections change recorded facts and force replay. All affected summaries, line scores, box scores, batting reports, pitching reports, scorecards, PDFs generated after the correction, exports, and reopened game state must refresh from the revised replay result.

Reports should preserve user workflow context where practical, such as returning to the same report type or selected event after correction. Context preservation is presentation state, not baseball truth.

If regeneration fails after facts were accepted, the service result should distinguish accepted source changes from failed or stale derived output. Source records remain the authority.

<!-- MARK: - 21. Stale Generated Output -->
## 21. Stale Generated Output

A report or PDF generated before later corrections is a snapshot of the facts and interpretation available at generation time. Existing external files remain unchanged. Newly generated output reflects current facts.

In-app retained generated output, if the product retains it, should be identified as a derived artifact with source scope, generated time where useful, warning state, and interpretation version. It should not be silently presented as current after source facts change.

Whether retained in-app generated output needs visible stale indicators is an open policy question. The minimum requirement is that stale retained output cannot become the source for reports, exports, or corrections.

<!-- MARK: - 22. Warning and Limitation Model -->
## 22. Warning and Limitation Model

Warnings include unknown pitcher, missing participant, incomplete lineup, unsupported result, `Sacrifise` compatibility, stored-score mismatch, incomplete runner movement, ambiguous substitution, incomplete pitcher period, and compatibility-limited game.

Warnings must appear consistently across relevant outputs. A box score should not hide an unknown pitcher that appears in the scorecard. A PDF should not omit a score mismatch that appears in the game summary. An export summary should not imply full compatibility when a report is warning-limited.

Warnings should identify consequence: limited pitching totals, limited batting totals, incomplete line score, unverified substitution history, unsupported result preserved, or output blocked pending repair.

<!-- MARK: - 23. Incomplete Games -->
## 23. Incomplete Games

Reports may be generated for draft, ready, in-progress, interrupted, suspended, shortened, completed, imported historical, and compatibility-limited games when the selected output can honestly represent the state.

Incomplete reports must not imply finality. A line score for an in-progress game should show current replay state. A game summary for a draft or ready game should identify setup status. A shortened or suspended game should show lifecycle context rather than fake innings.

Compatibility-limited historical games may show available facts and warnings. They should not invent missing runner movement, participants, pitcher periods, or finality.

<!-- MARK: - 24. Unknown and Detached Participants -->
## 24. Unknown and Detached Participants

Reports must identify unknown players, unknown pitchers, guest players, detached imported participants, and missing legacy references in user-understandable terms.

Unknown is not blank, zero, or guessed. An unknown pitcher affects pitching reports and pitcher responsibility. An unknown batter or runner affects batting totals, participation history, and scorecard explanations. Detached imported participants preserve historical game meaning even when they cannot attach safely to a current roster player.

Generated output should include enough team, side, batting slot, number, role, and warning context to avoid merging unrelated participants.

<!-- MARK: - 25. Substitution Reporting -->
## 25. Substitution Reporting

Batting reports, box scores, scorecards, and historical reports should represent incoming and outgoing participants, batting slots, timing, pinch hitters, pinch runners, defensive replacements, and ambiguous legacy substitutions.

A substitution affects current and future participation from its effective point. It must not rewrite earlier plate appearances, runner outcomes, or pitcher responsibility. Reports should preserve earlier and later participant identity separately.

Legacy `Game.replaced`, `Game.incomings`, player `batOrder` changes, and `Pitch Hitter` rows are compatibility evidence. If timing, role, pairing, or batting slot cannot be reconstructed safely, reports should show warning-limited substitution history rather than guessed certainty.

<!-- MARK: - 26. Pitcher Change Reporting -->
## 26. Pitcher Change Reporting

Pitcher change reporting defines appearance boundaries, mid-inning changes, between-inning changes, zero-out appearances, partial innings, re-entry where supported, and incomplete pitcher histories.

Pitching reports, box scores, scorecards, PDFs, and export summaries should consume one pitcher appearance projection. That projection should identify active pitcher periods, event attribution, inherited runner responsibility where supported, earned and unearned run decisions, unknown pitchers, and warning-limited periods.

If a legacy pitcher period has incomplete or contradictory markers, reports should preserve the evidence and limitation instead of assigning events to the wrong pitcher.

<!-- MARK: - 27. Stored Score Reconciliation -->
## 27. Stored Score Reconciliation

Reports must compare `hscore` and `vscore` with replay-derived score where legacy fields are available. Stored scores are compatibility evidence or reviewed final-score evidence only when a later policy explicitly accepts that role.

When stored and replay scores agree, reports may treat the agreement as confidence in the projection. When they disagree, output must expose the mismatch and avoid silently choosing a convenient value.

For imported historical games with incomplete event history, reports may show stored-score evidence with limitations. For coherent event histories, replay-derived score is the report authority.

<!-- MARK: - 28. Unsupported Legacy Results -->
## 28. Unsupported Legacy Results

Reports should classify supported categories, preserved legacy spellings, unsupported results, unknown results, and compatibility-only evidence. Unsupported values must not be converted into ordinary hits, outs, or notes merely to complete a table.

The known `Sacrifise` spelling variants are compatibility evidence. When their intended sacrifice meaning is clear, they should map consistently while preserving original evidence where round trip or support requires it.

Unknown or unsupported result rows may appear in reports with warning state and excluded or limited statistical treatment according to the shared formula policy.

<!-- MARK: - 29. Generated Output Model -->
## 29. Generated Output Model

Generated outputs are snapshots derived from a specific saved fact set and interpretation policy. They include PDFs, printed pages, shared report files, screenshots or images where supported, and export summaries.

Generated output identity should include output type, source scope, warning state, interpretation version where useful, generated time where useful, selected media policy, and destination status when observable. The source facts remain immutable unless a separate correction or repair command changes them.

External files are outside ScoreKeep's control after sharing or saving. Later corrections regenerate future output but cannot update already shared files.

<!-- MARK: - 30. PDF Generation Design -->
## 30. PDF Generation Design

PDF generation consumes a source projection, selected scope, pagination rules, warning state, media choices, readable labels, and output identity. It must support large lineups, extra innings, long reports, substitutions, pitcher-heavy games, and warning summaries without silent truncation.

Current source evidence uses `UIGraphicsPDFRenderer`, PDFKit preview, and direct drawing from legacy records in scorecard and report PDF paths. The rewritten design should preserve product behavior where supported while feeding PDF generation from canonical projections.

PDF failure leaves source records unchanged. If storage, rendering, media, pagination, or file handoff fails, the user should be able to retry, choose another output path, or return to the report without data mutation.

<!-- MARK: - 31. Printed Output Design -->
## 31. Printed Output Design

Printed output is a generated snapshot. It should include page identity, game or report identity, headers, page numbers where useful, pagination, grayscale-readable content, warning presentation, and cancellation behavior.

Printing must not repair compatibility evidence, update stored scores, mark games complete, or save baseball facts. Print cancellation is not a data failure.

Reports should remain understandable in black and white. Color can enhance meaning, but text, symbols, labels, and layout must carry the same information.

<!-- MARK: - 32. Screenshot and Image Output -->
## 32. Screenshot and Image Output

Screenshot or image generation is supported only where repository evidence supports it. Current report views use screenshot helpers to capture batting and pitching report views on iPad, save JPEG files in the app documents area, and share them through `ShareLink`.

Generated images remain output artifacts, not source baseball records. They may capture the current visible report and therefore inherit visible scope, warnings, accessibility limitations, and stale-output concerns.

If screenshot generation fails, source records, reports, purchases, and allowances remain unchanged. A captured image should not be reimported or interpreted as baseball data.

<!-- MARK: - 33. File Naming and Output Identity -->
## 33. File Naming and Output Identity

Generated file names should be understandable to users. They may use visible game, team, player, report type, date, or scope context. Existing evidence includes scorecard PDF names derived from visiting team, home team, and date, plus generic batting and pitching report PDF names.

Names should be editable where system workflows permit. The app should avoid exposing private filesystem paths, internal identifiers, implementation class names, or raw diagnostics as user-facing names.

Name collisions should not overwrite source records. Output replacement, duplicate naming, and destination behavior belong to generated-output workflow policy, not baseball truth.

<!-- MARK: - 34. Media Inclusion -->
## 34. Media Inclusion

Generated output may optionally include team logos and player photos where supported by the selected report. Media improves recognition but is not identity authority.

Missing, invalid, oversized, revoked, or unsupported media should degrade safely. A report, PDF, printout, or image should remain understandable through text labels, team names, player names, numbers, roles, and warning state even without images.

Media inclusion must not mutate source records, repair invalid media, or attach an image to a different player or team. Historical media snapshot policy remains unresolved and should be handled consistently with persistence and scorecard designs.

<!-- MARK: - 35. Sharing and System Handoff -->
## 35. Sharing and System Handoff

Sharing hands prepared output to Files, Mail, Messages, AirDrop, print, and other system destinations where available. The system destination owns delivery after handoff.

Cancellation is not an error. Destination failure, unavailable printer, revoked file access, or share-sheet dismissal leaves source context and records unchanged.

Application services should preserve report context so the user can retry, choose another destination, or return to the originating game, team, player, or report scope.

<!-- MARK: - 36. Purchase-Gated Reports and Output -->
## 36. Purchase-Gated Reports and Output

Purchase gating is separate from report calculation. Existing source records remain accessible and owned by the user. Premium gates may apply only to specifically designated generated output or advanced reports according to product policy.

When access is unavailable, the report workflow should preserve pending scope and return a paywall-required state. Canceled, failed, pending, unavailable, or uncertain purchase actions must not alter reports, records, generated files, or allowances.

The exact report gating policy is unresolved and belongs in the purchase entitlement and allowance design.

<!-- MARK: - 37. Free-Allowance Behavior -->
## 37. Free-Allowance Behavior

Allowance handling appears in current product behavior around qualifying actions such as game creation or roster download. This design describes allowance behavior only where reports or generated output are actually allowance-sensitive by product policy.

No allowance is consumed for failed, canceled, blocked, unavailable, or incomplete generation. Opening a preview, checking report availability, or encountering warnings should not decrement a counter.

This document does not invent a new allowance policy for reports, PDFs, screenshots, printing, or sharing. A future purchase design should define any designated generated-output allowance explicitly.

<!-- MARK: - 38. Offline Reporting -->
## 38. Offline Reporting

Reports that can be generated from local saved records should work offline. This includes local game summaries, line scores, box scores, batting reports, pitching reports, scorecards, and local generated output where platform services do not require network access.

Network-only destinations or services may be unavailable offline. Roster downloads, remote announcements, online entitlement refresh, cloud-only share destinations, and external links may fail without blocking local report review.

Offline report output still uses the same local facts, replay, warnings, and purchase state available on the device. Returning online must not silently rewrite reports or source records.

<!-- MARK: - 39. Accessibility Design -->
## 39. Accessibility Design

Report accessibility must support VoiceOver, larger text, high contrast, reduced motion, color-independent meaning, report tables, summaries, warnings, generated previews, and accessible navigation.

Reports should expose baseball meaning, not only visual table structure. Users should be able to identify report scope, teams, players, innings, totals, warnings, page context, and available actions.

PDF previews, printed summaries, and screenshot workflows should not be the only way to access report information. Where generated output is visual, the app should preserve accessible on-screen report state.

<!-- MARK: - 40. Accessible Report Descriptions -->
## 40. Accessible Report Descriptions

Accessible descriptions should speak meaningful baseball content for report rows, totals, innings, player results, pitcher lines, warnings, and scopes.

A batting row description should identify the player, team or side, relevant totals, and limitations. A pitcher row should identify pitcher, appearance or scope, innings or outs, runs, earned and unearned runs, hits, walks, strikeouts, and warning state where present. A line-score description should identify inning totals and whether the game is final or in progress.

Descriptions should not merely expose grid coordinates. They should distinguish unknown participants, unsupported results, score mismatches, incomplete games, and compatibility-limited output.

<!-- MARK: - 41. Adaptive Presentation -->
## 41. Adaptive Presentation

Reports must adapt across iPhone, iPad, compact and wide widths, portrait and landscape, Split View, Stage Manager, and larger-text settings. The same report meaning must remain available across layouts.

Compact layouts may use focused rows, section summaries, tabs, filters, or drill-in detail. Wide layouts may show side-by-side summaries and tables. Layout changes are presentation events and must not change source facts, report calculations, warning state, or selected scope.

Report scope and context should remain visible enough that users do not share or print the wrong game, team, player, or date range.

<!-- MARK: - 42. Large Reports and Pagination -->
## 42. Large Reports and Pagination

Large reports include many innings, large lineups, many players, many games, many substitutions, many pitchers, and long historical scopes. They require scrolling, pagination, grouping, filtering, or multi-page output without silent truncation.

PDF and printed output should include continuation pages, repeated headers where useful, report identity, page identity, and warning summaries. Extra innings and Everyone Hits lineups must not depend on fixed-size arrays or fixed page assumptions.

When a report is too large or complex to generate safely, the app should fail with a clear safe state rather than producing partial output that looks complete.

<!-- MARK: - 43. Performance and Responsiveness -->
## 43. Performance and Responsiveness

Report preview, regeneration after correction, PDF generation, large reports, media processing, progress, and cancellation should remain responsive enough for field and post-game use.

Ordinary local report preview should feel prompt. Longer generation should show honest progress and allow cancellation before irreversible generated-output steps where safe.

Correctness takes priority over stale cached output. A fast answer that disagrees with replay is not acceptable as report authority.

<!-- MARK: - 44. Caching and Invalidation -->
## 44. Caching and Invalidation

Report projections and generated previews may be cached conceptually for performance. Caches are not authoritative and must be invalidatable.

Invalidation triggers include scoring changes, corrections, lineup changes, pitcher changes, substitutions, lifecycle changes, migration interpretation changes, compatibility adapter changes, stored-score reconciliation changes, media changes relevant to selected output, and preferences that affect report presentation.

Cache state should distinguish fresh, stale, warning-limited, failed, and unavailable. Source records remain authoritative even when cache refresh fails.

<!-- MARK: - 45. Error and Recovery Model -->
## 45. Error and Recovery Model

Errors include failed report generation, failed PDF generation, printing failure, destination failure, unavailable source game, projection failure, replay failure, storage pressure, permission denial, invalid media, and app interruption.

Source records remain unchanged. The workflow result should identify whether no output was created, output was created but handoff failed, source projection failed, output is stale, retry is safe, or repair is required.

Recovery should return the user to the originating game, team, player, report, or scope where practical. A failed report must not appear as an empty completed report.

<!-- MARK: - 46. Report Consistency Validation -->
## 46. Report Consistency Validation

Scorecards, summaries, box scores, batting reports, pitching reports, PDFs, exports, and reopened games must agree for the same facts and interpretation policy.

Validation should compare scores, inning totals, batting totals, pitcher totals, participant identity, lineup and substitution history, warnings, lifecycle state, stored-score reconciliation, and output scope.

If two outputs disagree, the defect should be classified as projection error, stale cache, compatibility interpretation problem, formula mismatch, or warning-policy gap. It should not be resolved by patching one visible report value.

<!-- MARK: - 47. Privacy and Data Protection -->
## 47. Privacy and Data Protection

Reports and generated output may contain player names, youth-player information, jersey numbers, photos, team logos, locations, notes, scores, and game history. Sharing must be deliberate and scoped.

Generated output should not expose unrelated teams, unrelated players, hidden diagnostics, local filesystem paths, purchase account details, or private support context. Warning summaries should include enough context to explain selected output without leaking unrelated records.

External files cannot be recalled once shared. The app should treat generated output as user-visible disclosure and avoid unnecessary upload for local reporting.

<!-- MARK: - 48. Observability and Supportability -->
## 48. Observability and Supportability

Reporting diagnostics should be privacy-conscious. Useful support context includes report type, selected scope, source record category, interpretation version, warning classification, generation outcome, failure category, destination category where safe, and whether source data changed.

Diagnostics should help distinguish report calculation mismatch, stale cache, PDF generation failure, media failure, print cancellation, share destination failure, storage pressure, and purchase-gating interruption.

Support data must not include full rosters, youth-player details, media, filesystem paths, or purchase credentials unless the user deliberately shares them for support.

<!-- MARK: - 49. Legacy Reporting Mapping -->
## 49. Legacy Reporting Mapping

Repository inspection identifies batting reports in `ReportView` and `ShowReportView`, pitching reports in `PitcherRptView` and `ShowPitchRptView`, scorecard and PDF drawing in `GeneratePDF`, PDF preview in `PdfView`, screenshot helpers in `ScreenShots`, and share workflows using `ShareLink`.

Canonical fact evidence includes legacy at-bat result strings, player references, team references, RBIs, stolen bases, earned-run flags, play notes, pitcher marker fields, and clear supported destination or out values when coherent. Derived output includes report rows, batting totals, pitching totals, box-score totals, scorecard cells, PDF rows, screenshots, and shared files.

Compatibility evidence includes `maxbase`, `outAt`, `col`, `seq`, legacy inning values, `endOfInning`, `hscore`, `vscore`, `Game.replaced`, `Game.incomings`, `Pitch Hitter` rows, stored pitcher start and end markers, `Sacrifise` spelling differences, and generated file naming conventions.

Duplicated calculation and migration risk includes direct calculation from `Atbat`, use of `maxbase == "Home"` for runs, duplicated pitcher calculations across report and PDF paths, report-specific SwiftUI state, fixed drawing dimensions, fixed inning tendencies, stored-score usage, screenshot output from visible views, and report/PDF generation that currently lives close to presentation.

<!-- MARK: - 50. Calculation Duplication Retirement -->
## 50. Calculation Duplication Retirement

Duplicated report and PDF calculations should be retired only after shared replay projections pass fixture-backed acceptance. Retirement before acceptance risks changing product behavior without evidence.

The replacement path should compare legacy report values, scorecards, PDFs, exports, and reopened state against canonical projections. Differences should be classified as accepted correction, legacy limitation, formula-policy decision, compatibility warning, or defect.

Once one report type has an accepted calculation authority, legacy duplicate formulas for that report should be isolated or removed so future changes do not update one path while leaving another stale.

<!-- MARK: - 51. Migration and Coexistence -->
## 51. Migration and Coexistence

Rewritten reports can coexist with legacy reports during incremental replacement. A report type should have one accepted calculation authority at a time for production routing.

Early coexistence may generate both legacy and canonical projections for fixtures and selected records, compare outputs, and expose differences to verification. Legacy views remain behavior references and compatibility evidence, not hidden second authorities.

Routing changes occur only after comparison against fixtures, scorecards, exports, PDFs, reopened state, warning behavior, accessibility expectations, large-report cases, and source-record preservation.

<!-- MARK: - 52. Verification Strategy -->
## 52. Verification Strategy

Verification should map this design to acceptance fixtures and regression scenarios. Required scenarios include regulation completed game, in-progress game, extra innings, large lineup, Everyone Hits, substitution-heavy game, pitcher-change-heavy game, correction game, double play, triple play, multiple runs, third-out run, unknown pitcher, missing player, unsupported result, `Sacrifise`, score mismatch, incomplete game, seeded game, PDF generation, printing, accessibility, offline generation, purchase cancellation, failed generation, and source-record preservation.

Expected evidence should compare game summary, line score, box score, batting report, pitching report, scorecard, PDF output, export summary, reopened game state, warning state, generated-output failure behavior, and unchanged source records.

Verification should also cover screenshot/image output where supported, large media, generated-file naming, share cancellation, storage pressure, stale output, and report regeneration after correction.

<!-- MARK: - 53. Risks and Open Questions -->
## 53. Risks and Open Questions

Unresolved questions include exact statistical formulas, inherited-run responsibility, user-authored final scores, multi-game aggregation policy, report gating policy, stale retained output indicators, media snapshot policy, practical pagination limits, screenshot-output support, and legacy unsupported result round trips.

Additional risks include preserving historical reports while retiring duplicated calculations, interpreting incomplete runner movement, reconciling stored scores, matching current players to historical participation, and ensuring generated output remains accessible when visual density is high.

These issues should be resolved through product policy, fixtures, and focused follow-on designs rather than by allowing reports to invent independent baseball truth.

<!-- MARK: - 54. Success Criteria -->
## 54. Success Criteria

This design succeeds when ScoreKeep has one report authority, report agreement with replay, correction regeneration, no source mutation from generated output, safe warning behavior, accessible output, offline local reporting, large-report safety, compatible historical records, and fixture-backed verification.

Reports, PDFs, scorecards, summaries, box scores, exports, printed output, screenshots where supported, and reopened games should all derive from canonical facts and scoring-engine replay.

Generated artifacts should be useful to users without becoming editable baseball records or hidden authorities.

<!-- MARK: - 55. Recommended Next Design Document -->
## 55. Recommended Next Design Document

The recommended next design document is `25-PurchaseEntitlementAndAllowanceDesign.md`.

It should follow because Documents 18 through 24 define baseball truth, replay, persistence, compatibility, scorecard presentation, workflow orchestration, and generated output. Purchase entitlement and allowance coordination should then define StoreKit-facing state, seasonal access, free counters, pending gated actions, offline access, restore behavior, and separation from baseball ownership.

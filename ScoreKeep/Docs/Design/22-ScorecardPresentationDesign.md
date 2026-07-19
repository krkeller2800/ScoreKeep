# ScoreKeep Technical Design — 22 Scorecard Presentation Design

<!-- MARK: - 1. Purpose -->
## 1. Purpose

This document defines how ScoreKeep presents scorecards from canonical game facts and scoring-engine replay. It is a technical design document for live scorecards, historical review, correction workflows, iPhone and iPad presentation, printed scorecards, PDF scorecards, accessible scorecard descriptions, and legacy scorecard compatibility.

The scorecard is a projection. It summarizes authoritative game facts in a familiar baseball scorekeeping form, but scorecard cells are not authoritative scoring records. Opening, scrolling, selecting, printing, sharing, exporting, or regenerating a scorecard must not mutate the game. Corrections modify recorded facts through application services and then regenerate the scorecard projection.

This design follows Documents 17 through 21. The canonical domain model defines baseball meaning, the scoring engine replays saved facts, persistence preserves records and compatibility evidence, and import/export maps transport data without making file formats authoritative. The scorecard presentation consumes those boundaries rather than replacing them.

<!-- MARK: - 2. Scorecard Design Principles -->
## 2. Scorecard Design Principles

The scorecard must explain the game without becoming the game. It should show batter sequence, inning progression, results, runner movement, outs, runs, RBIs, substitutions, pitcher context, notes, warnings, and incomplete information from the same replay result used by the live scoring screen, reports, PDFs, exports, and reopened game state.

The scorecard should preserve ScoreKeep terminology and historical compatibility. Legacy result strings, scorecard columns, inning values, sequence values, `maxbase`, `outAt`, `playRec`, `endOfInning`, `hscore`, and `vscore` may help explain existing records. They must not become the sole authority for event order, score, runner movement, or baseball state when canonical facts and replay can provide stronger evidence.

The presentation may evolve substantially from the current visual layout. Equivalent baseball meaning and core actions must remain available on iPhone, iPad, print, PDF, accessibility, and historical review surfaces, even when each surface uses a different layout.

<!-- MARK: - 3. Scope and Responsibilities -->
## 3. Scope and Responsibilities

Scorecard presentation owns visual arrangement, navigation, selection context, accessible descriptions, print layout, PDF layout requirements, warning placement, and links into review or correction workflows. It does not own scoring rules, event mutation, persistence transactions, import repair, export compatibility decisions, purchase policy, or generated-file handoff.

The scoring engine owns replayed game state, current and next batter, base occupancy, inning and half inning, score, outs, lineup progression, substitution effects, pitcher responsibility, statistics, report projections, scorecard projections, warnings, and downstream replay after corrections.

Application services own user actions that change facts: scoring a play, editing a play, correcting runner movement, changing pitcher assignment, correcting substitutions, deleting or superseding an event, resolving legacy ambiguity, and regenerating projections after accepted changes.

<!-- MARK: - 4. Scorecard as a Projection -->
## 4. Scorecard as a Projection

A scorecard projection is generated from canonical game facts and scoring-engine replay. The projection may contain cells, rows, columns, labels, symbols, summaries, warnings, and accessible descriptions, but those values are derived presentation output.

Scorecard cells are not authoritative scoring records. They may carry stable references back to recorded event identity and projection coordinates so a user can review or correct the underlying event, but editing the cell itself is not a baseball write.

Score, outs, runners, lineup progression, substitutions, pitcher responsibility, statistics, reports, PDFs, and exports must agree with the same replay result. If a scorecard disagrees with a report or export, the defect is in projection generation, compatibility interpretation, or stale output handling. The answer is not to patch a visible cell independently.

<!-- MARK: - 5. Authoritative Inputs -->
## 5. Authoritative Inputs

Authoritative inputs include game identity and settings, home and visiting game sides, game-time team snapshots, game participants, starting lineups, lineup mode, pitcher appearances, substitutions, recorded scoring events, batter outcomes, runner outcomes, user-entered RBI decisions, earned-run decisions, notes, lifecycle state, correction and supersession state, and compatibility evidence preserved during import or migration.

Legacy `Atbat` values are important evidence. Observed fields include `result`, `maxbase`, `batOrder`, `outAt`, `inning`, `seq`, `col`, `rbis`, `outs`, `sacFly`, `sacBunt`, `stolenBases`, `earnedRun`, `playRec`, and `endOfInning`. These values can map to canonical facts when coherent and can remain compatibility evidence when incomplete.

Legacy `Game.hscore` and `Game.vscore` are stored score evidence. They should be compared with replay-derived runs and line score. Agreement increases confidence; disagreement creates warning, repair, or compatibility-limited presentation rather than an automatic visual override.

<!-- MARK: - 6. Scorecard Projection Outputs -->
## 6. Scorecard Projection Outputs

The scorecard projection should produce team-side sections, batting rows, historical batting-slot occupants, inning and half-inning columns, event placements, result notation, runner paths, outs, run and RBI markers, substitution markers, pitcher context, end-of-inning markers, warnings, selected-event context, and accessible descriptions.

It should also produce summaries used by reports and generated output: line score, score by team, per-inning runs and hits where supported, batter row totals, pitcher participation context, incomplete-data indicators, legacy limitation notes, and pagination hints for print and PDF.

Outputs should be immutable from the perspective of views. They may be cached or retained for performance, but cached scorecard projections must be invalidated after scoring, correction, lineup change, pitcher change, import repair, settings that affect presentation, or interpretation-version changes.

<!-- MARK: - 7. Scorecard Coordinate Model -->
## 7. Scorecard Coordinate Model

The conceptual coordinate model identifies where a projected entry appears without making the coordinate the source of baseball truth. A coordinate should support team side, batting slot, historical slot occupant, inning, half inning, plate-appearance order, event identity, scorecard column, and event placement within that column.

The model must support multiple plate appearances by the same batting slot in one inning, extra innings, large batting orders, substitutions, pinch hitters, pinch runners, pitcher changes, corrections, and unknown participants. It must not preserve fixed-size arrays or fixed maximum inning assumptions as architectural requirements.

Legacy `col`, `seq`, and `inning` values may be compatibility evidence for reconstructing historical display and event order. They must be reconciled with event identity, half inning, sequence, lineup progression, correction state, and replay result. A legacy grid coordinate alone is not canonical baseball truth.

<!-- MARK: - 8. Innings, Columns, and Event Placement -->
## 8. Innings, Columns, and Event Placement

Inning columns should be generated from replayed event order and baseball time. The projection should place each plate appearance in the half inning where it occurred and should preserve order within that half inning. A team can have more than one column for the same inning when the batting order turns over and the layout needs additional visible space.

The current implementation calculates and mutates `Atbat.col`, `Atbat.seq`, and `Atbat.inning` from visible at-bat order, and scorecard drawing sorts by `col` and `seq`. That behavior is compatibility evidence and an observed risk because display placement and saved state are intertwined.

The rewritten design should derive placement from replay first, then use legacy column evidence only to preserve old visual meaning where it does not contradict replay. Ambiguous placement should show warning or repair state rather than inventing certainty.

<!-- MARK: - 9. Batting Rows and Lineup Slots -->
## 9. Batting Rows and Lineup Slots

Batting rows represent game-specific batting slots and historical occupants. A row should identify the batting slot, starting occupant, later occupants, and the specific participant attached to each event. Rows are not current roster rows, and they are not determined by mutable player sort order.

Traditional batting order should show active lineup slots and bench context. Everyone Hits should show the full selected batting order. Large batting orders must remain scrollable, searchable, printable, and reportable without index failure or row truncation.

Earlier plate appearances remain attached to the participant who actually recorded them. Later substitutions, roster edits, player renames, guest-player cleanup, or correction of future lineup state must not visually rewrite earlier history.

<!-- MARK: - 10. Current Batter and Next Batter Presentation -->
## 10. Current Batter and Next Batter Presentation

The live scorecard should make the current batter and next batter easy to identify from replayed batting-order progression. It should show enough participant context to distinguish duplicate names, shared numbers, unknown players, guest players, and substituted players.

Current batter and next batter are replay outputs, not values inferred from the selected cell alone. If the scorecard is scrolled to an older inning, the live context should remain available separately so reviewing history does not confuse the user about the present play.

When batting progression is incomplete or ambiguous, the scorecard should show that uncertainty and route the user to lineup or correction review. It should not silently guess a current batter from the visible row or first available roster player.

<!-- MARK: - 11. Plate Appearance Presentation -->
## 11. Plate Appearance Presentation

Each completed plate appearance should show the batter result, batter destination, runner effects where available, outs, RBIs, runs, stolen bases, earned-run decision where relevant, pitcher context, and recorded defensive or play notation.

An incomplete plate appearance should appear as incomplete, selected, or pending according to workflow state. It should not be counted as final scorecard history until recorded facts are accepted. If a placeholder exists for compatibility or live editing, it must remain visibly different from a completed event.

Each entry should retain a stable link to event identity so review and correction workflows can open the recorded facts. Coordinates such as row and column may help navigation, but event identity is the reliable reference.

<!-- MARK: - 12. Batter Result Notation -->
## 12. Batter Result Notation

Supported notation should cover single, double, triple, home run, walk, hit by pitch, catcher interference, error, fielder's choice, dropped third strike, ground out, fly out, line out, foul out, strikeout, strikeout looking, sacrifice fly, sacrifice bunt, batter out on the base path, runner out on the base path, stolen base, unknown result, and unsupported legacy result.

The notation should preserve established ScoreKeep terms and abbreviations where they are already meaningful, including result strings such as `Single`, `Double`, `Triple`, `Home Run`, `Walk`, `Hit By Pitch`, `Dropped 3rd Strike`, `Catcher Interference`, `Fielder's Choice`, `Error`, `Ground Out`, `Fly Out`, `Line Out`, `Foul Out`, `Strikeout`, `Strikeout Looking`, `Sacrifice Fly`, and `Sacrifice Bunt`.

The known `Sacrifise` versus `Sacrifice` compatibility requirement must be honored. Legacy misspellings should be recognized when the intended sacrifice category is clear, preserved as compatibility evidence where needed for round trip or support, and presented consistently in scorecards, reports, correction flows, PDFs, and exports.

<!-- MARK: - 13. Runner Path Presentation -->
## 13. Runner Path Presentation

Runner paths should be derived from explicit runner outcomes where available. The projection should show batter destination, existing runner advancement, runner scoring, runner outs, stolen bases, pinch-runner replacement, multiple runners moving on one play, multiple runners scoring, double-play cleanup, triple-play cleanup, third-out run decisions, and incomplete runner evidence.

Legacy `maxbase` can explain batter destination and legacy run evidence, especially when it is `Home`. Legacy `outAt` can explain a base-path out. These fields are incomplete for multiple runners and multiple outs, so they should produce warnings when the runner path cannot be reconstructed safely.

The scorecard should avoid invented certainty. If a legacy record implies a run but lacks runner identity or advancement detail, the scorecard may show a limited or inferred marker with warning context, but reports, PDFs, and exports must use the same warning state.

<!-- MARK: - 14. Outs and Defensive Notation -->
## 14. Outs and Defensive Notation

Out presentation should distinguish batter outs, runner outs, multiple outs, end-of-inning outs, and base-path outs. Ground outs, fly outs, line outs, foul outs, strikeouts, strikeouts looking, sacrifice outs, fielder's choice outs, and dropped-third-strike outs should remain understandable.

Defensive notation should preserve recorded `playRec` or equivalent play notes without turning them into authoritative scoring state. The current code appends fielder-number notation for common fielding buttons and draws that notation inside scorecard cells. That is useful presentation evidence and should remain available where recorded.

Color, shape, symbol count, and text should not be the only separate signals. Outs must be understandable in printed output, PDF output, VoiceOver descriptions, high contrast, and color-independent modes.

<!-- MARK: - 15. Runs, RBIs, and Scoring Decisions -->
## 15. Runs, RBIs, and Scoring Decisions

Run markers should derive from replayed runner outcomes and scorer decisions. Multiple runs on one play and zero-RBI scoring plays must be representable. A run may score without an RBI, and the scorecard should preserve that distinction.

RBI markers should reflect recorded RBI decisions rather than assuming that every run creates an RBI. Earned and unearned run decisions should remain visible when relevant to pitcher reporting, especially when the scorer has not completed the decision.

Third-out run cases require explicit treatment. If a runner appears to score on a play with the third out, replay determines whether the run counts or whether the scorer decision requires warning or repair. The scorecard should show the outcome and warning state, not silently count or remove the run based only on a drawn path.

<!-- MARK: - 16. Stolen Bases and Runner-Only Events -->
## 16. Stolen Bases and Runner-Only Events

Stolen bases should be displayed as runner movement, not as ordinary batter advancement. The current model stores a stolen-base count on `Atbat`; that is compatibility evidence and can support legacy display, but runner-specific steal facts should drive rewritten projections when available.

Runner-only events may occur around a plate appearance or between plate appearances. The scoring engine design leaves the exact boundary open, so the scorecard design should allow a projected event that has runner movement without forcing it into a misleading batter result.

When legacy data records only a stolen-base count without runner identity, the scorecard should preserve the evidence and warn if the affected runner path cannot be identified. It should not attach the steal to a guessed runner.

<!-- MARK: - 17. Double Plays and Triple Plays -->
## 17. Double Plays and Triple Plays

Double plays and triple plays should show multiple outs on one event, the affected batter or runners, defensive notation, base cleanup, score effect, and inning transition where applicable. The scorecard should support plays where the batter is out, one or more runners are out, or a run attempt is affected by the third out.

The projection should clear retired runners and preserve remaining runners according to replay. It should detect impossible fourth-out states, duplicate base occupancy, and runners remaining active after being retired.

Legacy evidence may have only one `outAt` value and an out count. That can be insufficient for complete multiple-out explanation. The scorecard should show compatible notation where possible and warnings where runner-specific cleanup cannot be verified.

<!-- MARK: - 18. End-of-Inning Presentation -->
## 18. End-of-Inning Presentation

End-of-inning presentation should identify the third-out event, clear the bases for the next half inning, preserve the next batter for the returning offensive side, and show the line-score effect. A visible end-of-inning divider may be used, but it is derived from replay.

Legacy `endOfInning` values are presentation and compatibility evidence. Current code recalculates and mutates `endOfInning` from counted outs and then draws a red divider. The rewritten design should derive the marker from replay and preserve legacy evidence only where useful for interpreting old records.

If the half inning ends through shortened-game, mercy-rule, suspension, or administrative completion rather than exactly three outs, the scorecard should present the lifecycle decision instead of inventing fake outs.

<!-- MARK: - 19. Extra-Inning Presentation -->
## 19. Extra-Inning Presentation

Extra innings should continue the ordinary coordinate and replay model without a fixed maximum inning requirement. The scorecard should support additional innings in live, historical, printed, PDF, accessible, report, and export contexts.

The current `Common.innAbr` list and PDF drawing loops show historical fixed-size tendencies, including inning labels through a finite list and scorecard grid loops. These are compatibility and regression risks, not architectural limits.

When an output surface cannot fit all innings on one page or viewport, it should paginate, scroll, collapse, or navigate while preserving the same event identities and baseball meaning.

<!-- MARK: - 20. Large-Lineup Presentation -->
## 20. Large-Lineup Presentation

Large batting orders should be first-class. The projection must support more rows than historical `batbox` or screen assumptions without losing events, totals, substitutions, or accessibility descriptions.

Current live scorecard state initializes `colbox` and `batbox` with fixed counts and indexes by column and batting order in some paths. PDF generation has moved toward dynamic counts in places, but visible scorecard paths still expose fixed-size regression risks. The rewrite should retire fixed-size scorecard requirements.

Large-lineup presentation may use vertical scrolling, row headers, sticky current-batter context, search, slot grouping, page breaks, or compact summaries. The chosen layout must preserve batting order and historical participant identity.

<!-- MARK: - 21. Everyone Hits Presentation -->
## 21. Everyone Hits Presentation

Everyone Hits should show every selected hitter in the batting order and preserve progression through the full order. It should not treat non-defensive participants as invalid simply because they are not in a traditional defensive lineup.

Bench, unavailable, late-arriving, guest, and removed participants should remain distinguishable from active Everyone Hits slots. If the lineup changes after scoring begins, earlier appearances remain attached to their actual participants.

Reports, PDFs, printouts, exports, and accessible descriptions should all indicate the selected lineup mode where it affects interpretation. The scorecard should not silently compress Everyone Hits into a traditional nine-player assumption.

<!-- MARK: - 22. Substitution Presentation -->
## 22. Substitution Presentation

Substitution presentation should show incoming participant, outgoing participant when known, role, team side, batting slot when applicable, effective timing, and later active occupant. It should also preserve corrected, ambiguous, or legacy-limited substitution state.

The current repository stores substitutions partly through `Game.replaced`, `Game.incomings`, player `batOrder` adjustments, and inserted `Pitch Hitter` at-bat rows. These are observed compatibility concepts. They should be interpreted conservatively and migrated toward explicit historical substitution facts.

A substitution affects current and future scorecard rows and entries. It must not rewrite earlier plate appearances, runner appearances, pitcher responsibility, or reports as if the incoming participant had always occupied the slot.

<!-- MARK: - 23. Pinch Hitter Presentation -->
## 23. Pinch Hitter Presentation

A pinch hitter should appear at the batting slot and plate appearance where they actually batted. The scorecard should identify the substituted participant, the replaced participant when known, and whether the pinch hitter became the later occupant of that slot.

Legacy `Pitch Hitter` result rows are compatibility evidence. The spelling and row behavior should be understood as an observed legacy marker, not a canonical batter result category. A rewritten projection should present the baseball role clearly while preserving the legacy evidence for imported or migrated records.

Corrections may change pinch hitter identity, timing, or permanence. After correction, downstream batting order and scorecard rows regenerate from the revised facts.

<!-- MARK: - 24. Pinch Runner Presentation -->
## 24. Pinch Runner Presentation

A pinch runner should be shown as a runner replacement at a specific base and game point. The replaced runner's prior batting and running history remains attached to the replaced participant, while later runner movement from that base belongs to the pinch runner.

The scorecard should show the substitution context near the affected event or runner path and should preserve which base was occupied. If the pinch runner later scores, is put out, or is replaced again, those outcomes attach to the runner who was active at that time.

Legacy evidence may not contain enough detail to identify the base, timing, or outgoing runner. Such cases should be warning, repair-required, or compatibility-limited rather than guessed.

<!-- MARK: - 25. Pitcher Change Presentation -->
## 25. Pitcher Change Presentation

Pitcher changes should be visible in live and historical scorecards because they affect review, pitching reports, earned-run decisions, and player responsibility. The scorecard should show current pitcher in live context and historical pitcher assignment for events where that is meaningful.

Current code derives pitcher markers from at-bat order, inning, outs, and batter sequence, and stores start and end markers on pitcher records. That behavior is compatibility evidence and should be reconciled with canonical pitcher appearance facts.

Unknown pitcher state is valid. The scorecard should show missing or incomplete pitcher assignment as warning context, allow correction through a pitcher workflow, and avoid assigning events to a named pitcher without support.

<!-- MARK: - 26. Unknown and Incomplete Participants -->
## 26. Unknown and Incomplete Participants

Unknown players, unknown pitchers, detached imported participants, guest players, and missing legacy references should remain visible and correctable. The scorecard should distinguish unknown from blank, zero, default, or not applicable.

For batting rows, unknown or incomplete participants can occupy a batting slot when the real game was scored before identity was known. For reports and historical review, the game-time participant state should remain understandable and should not depend solely on current roster data.

Warnings should explain impact: unknown batter affects batting totals and event identity; unknown pitcher affects pitching projections; missing substitution participant affects lineup history; detached imported participant affects roster attachment but may still preserve game history.

<!-- MARK: - 27. Unsupported and Legacy Results -->
## 27. Unsupported and Legacy Results

Unsupported legacy results should be preserved as evidence and shown honestly. They must not be collapsed into ordinary hits, outs, safe states, or generic notes merely to make the grid complete.

The projection should classify unknown result, unsupported result, supported result with legacy spelling, supported result with incomplete runner evidence, and supported result with warning. Each classification should be available to live scorecard, historical review, reports, PDFs, exports, and accessibility.

The scorecard may display a compact unsupported marker, but selection should open review details with the preserved legacy value and available repair choices. Export should follow the compatibility policy from Document 21.

<!-- MARK: - 28. Live Scorecard Interaction -->
## 28. Live Scorecard Interaction

The live scorecard should make it easy to identify current inning and half inning, current batter, next batter, current pitcher, outs, score, base runners, recent completed play, selected scorecard cell or event, incomplete play, and warnings requiring later correction.

The live scorecard may be interactive. Tapping or selecting a cell should open an explicit scoring, review, or correction workflow. Selection alone must not alter baseball records, advance batting order, change a result, repair a warning, or regenerate persisted data.

Live scorecard interaction should support quick return to scoring. A user scoring from the field should be able to review the last play, inspect a warning, correct a mistake, and return to the current batter without losing context.

<!-- MARK: - 29. Historical Scorecard Review -->
## 29. Historical Scorecard Review

Historical scorecard review presents a saved game as replayed from current accepted facts and compatibility interpretation. It should show game identity, teams, date, location, score, line score, lineups, substitutions, pitcher context, event sequence, notes, warnings, and completion or interruption state.

Review must not mutate the game. Opening an old scorecard, scrolling through innings, expanding event details, printing, sharing, or generating a PDF must not repair legacy fields or update stored totals as a side effect.

If a historical game is incomplete or compatibility-limited, the scorecard should present the usable projection and warnings together. It should not pretend unsupported results, missing runner movement, unknown pitchers, or score mismatches are fully verified.

<!-- MARK: - 30. Scorecard Correction Workflow -->
## 30. Scorecard Correction Workflow

Selecting a prior event should open review of the recorded facts that produced the scorecard entry. The user should be able to edit batter result, runner movement, outs, runs or RBIs, earned-run decisions, batter identity, pitcher assignment, substitution timing, notes, and unsupported legacy interpretation where supported.

Deleting or superseding an event should be explicit. The workflow should distinguish deleting a completed plate appearance, canceling an incomplete placeholder, replacing a legacy marker, and correcting a substitution or pitcher boundary.

The scorecard must not directly patch its own cells. It requests a correction to underlying facts through application services, receives validation or warning outcomes, and then displays a regenerated projection.

Task 6.10 establishes `LiveScoringShellPresentation` as the correction review presentation owner prepared for later routing. The review state is value-only: it retains the stable `Game.ident`, target `Atbat.ident`, the original `LegacyCorrectionSnapshot`, the proposed `LegacyCorrectionReplacement`, supported original/proposed summary fields, confirmation and cancellation availability, in-progress state, typed outcome state, optional user-facing status text, and refreshed authoritative state returned by the workflow. It does not retain mutable SwiftData models as presentation authority.

The Task 6.10 review summary is intentionally bounded to facts already available from the accepted Task 5.11 request and snapshot boundary: batter display text supplied by the caller, inning/half-inning display, original and proposed result, RBI, outs, base-path text, earned-run decision, stolen-base count, and fielder-play notation. It does not calculate downstream score, runners, inning progression, batting order, pitcher markers, reports, or replay effects in presentation.

Confirming a review uses the retained stable game and at-bat identities plus the retained original snapshot to call `LiveScoringWorkflowCoordinator.submitCorrection` through a supplied submission boundary. The presentation layer guards against repeated in-progress confirmation, waits for the typed workflow result, maps accepted, canceled, validation rejected, missing, stale, wrong-game, unsupported, persistence-failed, recalculation-failed, and refreshed-state-unavailable outcomes, clears pending review only after acceptance, and exposes the refreshed authoritative state for the later presenting owner. It never mutates `Game` or `Atbat`, saves a `ModelContext`, writes operation evidence, writes canonical records, synthesizes history, or performs correction planning.

Canceling a review clears presentation state without workflow submission, mutation, save, operation evidence, canonical write, or historical backfill. Stale, rejected, wrong-game, unsupported, and failed outcomes are not reported as accepted; they preserve the current accepted Legacy game state, expose bounded user-facing status text, and allow dismissal. Confirmation and cancellation labels and status text are distinct so VoiceOver can distinguish original/proposed facts, discover confirm and cancel controls, and read stale or failure state without relying on color alone.

Task 7.9 routes live-scoring correction entry through `PlayersToScoreView`, the existing live-scoring shell owner. Selecting an already scored Legacy at-bat opens the existing score-entry sheet in correction-entry mode, where draft result, base-path, RBI, stolen-base, earned-run, and fielder-play values are held as transient presentation state rather than written through the bound `Atbat`. A supported draft prepares the Task 6.10 value-only review state with stable `Game.ident`, `Atbat.ident`, the retained `LegacyCorrectionSnapshot`, and the proposed `LegacyCorrectionReplacement`.

The correction review is presented with the current sheet/navigation conventions and remains value-only until confirmation. Confirmation delegates through `LiveScoringShellPresentation.confirmCorrectionReview` to `LiveScoringWorkflowCoordinator.submitCorrection`; cancellation dismisses without workflow submission. Accepted results refresh the live scorecard from the authoritative Legacy workflow result and the shell's existing refresh path. No-target, stale, deleted, wrong-game, unsupported, rejected, or failed outcomes are not accepted and preserve the previously accepted presentation and persisted state. `ScoreGameView` delete and placeholder-reset behavior remains isolated and unchanged, durable correction idempotency remains unsupported, production correction remains Legacy, canonical correction services remain non-routed, and Task 7.10 substitution entry has not begun.

<!-- MARK: - 31. Correction Replay and Refresh -->
## 31. Correction Replay and Refresh

After an accepted correction, the scoring engine replays downstream game state. The refreshed projection should update score, line score, inning totals, outs, runners, current batter, next batter, lineup state, substitutions, pitcher responsibility, batting and pitching statistics, reports, PDFs, exports, and warnings.

Downstream warnings should be visible when a correction changes assumptions that later events depended on. Examples include a runner no longer being on the expected base, a substitution no longer applying at the assumed time, a pitcher period becoming ambiguous, or a third-out run decision needing review.

The refresh should preserve selection context where practical by returning to the corrected event identity, not merely the same row and column. If the event was deleted or superseded, the scorecard should explain the new selected context.

<!-- MARK: - 32. Recent Play and Current-State Context -->
## 32. Recent Play and Current-State Context

The live scorecard should include recent completed play context so the user can confirm what just happened before recording the next play. Recent play context may include batter, result, bases reached, runners moved, outs, runs, RBIs, pitcher, notes, and warning state.

Current-state context should remain visible during live scoring and correction review: inning, half inning, score, outs, runners, current batter, next batter, current pitcher, and team at bat.

Historical review can show selected-event context instead of current live context, but it should still make clear whether the user is looking at the game's current replay end state or an earlier event.

<!-- MARK: - 33. iPhone Scorecard Presentation -->
## 33. iPhone Scorecard Presentation

iPhone presentation should prioritize current scoring context and readable event detail. A focused current-inning or current-batter view may be primary, with horizontal or vertical navigation to earlier innings and a compact overview for orientation.

The iPhone scorecard should support focused event detail, quick return to live scoring, reachable controls, clear current batter and next batter presentation, warning badges, larger-text adaptation, and efficient correction entry. A full desktop-like grid is not required if it compromises usability.

Equivalent baseball meaning and core actions must remain available: review events, select entries, correct facts, inspect runner paths, view substitutions, generate reports or PDFs where allowed, and understand warnings.

<!-- MARK: - 34. iPad Scorecard Presentation -->
## 34. iPad Scorecard Presentation

iPad presentation can use a wider scorecard grid with persistent game-state context. It should support side-by-side scorecard and event detail, lineup context, recent-play context, report or correction panels, and easier navigation across innings.

Window resizing and Stage Manager require the iPad layout to adapt between compact and wide presentations. The scorecard should preserve selection, scroll position, event identity, current-game context, and warning visibility when the window changes.

The wider layout should not assume unlimited space. Large lineups, extra innings, substitutions, and accessibility settings still require scrolling, paging, or responsive density choices.

<!-- MARK: - 35. Adaptive Layout and Window Resizing -->
## 35. Adaptive Layout and Window Resizing

Adaptive layout should preserve baseball meaning across device class, orientation, split view, Stage Manager, print preview, PDF preview, larger text, and external display sizes. A resize is a presentation event, not a baseball event.

The coordinate model should remain stable by event identity and projected location even when cell size, row grouping, frozen headers, visible columns, or detail panels change. Selection should follow the same event where possible.

Layouts must avoid fixed-size assumptions for rows, columns, innings, or batter counts. When space is constrained, the scorecard should navigate or summarize rather than truncate authoritative events.

<!-- MARK: - 36. Search, Navigation, and Selection Context -->
## 36. Search, Navigation, and Selection Context

Search should help users find players, batting slots, innings, result categories, runs, substitutions, pitchers, warnings, notes, unsupported results, and corrected events. Search is a navigation tool and must not alter facts.

Navigation should support jumping to current inning, next batter, previous play, scoring plays, substitutions, pitcher changes, warnings, extra innings, and selected player appearances. iPhone may use focused navigation; iPad may use sidebars or panes; print and PDF use pagination and indexes where useful.

Selection context should identify the selected event, coordinate, batter, inning, result, warning state, and available actions. If a selected cell represents no event, the selection should remain visibly empty and should not create a placeholder until the user starts an explicit scoring action.

<!-- MARK: - 37. Scorecard Editing Boundaries -->
## 37. Scorecard Editing Boundaries

The scorecard may offer entry points for scoring, review, correction, substitution, pitcher change, notes, or report generation. The boundary is that any baseball change flows through application services and replay, not through direct cell mutation.

Presentation-only settings such as zoom, visible columns, row grouping, color theme, print scale, selected detail panel, or scroll position may be stored as preferences when appropriate. These settings must not change score, lineups, participants, events, or compatibility evidence.

Destructive actions such as deleting an event, removing a substitution, changing batter identity, or correcting a pitcher assignment require explicit workflows that explain downstream effects and preserve prior state on failure.

<!-- MARK: - 38. Scorecard and Reports Consistency -->
## 38. Scorecard and Reports Consistency

The scorecard, batting reports, pitching reports, game reports, line score, box score, PDFs, exports, and reopened game state must agree for the same saved facts and interpretation policy.

Current repository evidence shows duplicated calculations: runs are often derived from `maxbase == "Home"`, outs from result lists or `outAt`, and pitching windows from inning and sequence markers. The rewrite should replace duplicated report calculations with shared projections from replay.

When scorecard and report output cannot be fully trusted because of incomplete legacy evidence, the same warning should appear consistently across the affected outputs. A report should not hide uncertainty that the scorecard exposes.

<!-- MARK: - 39. Printed Scorecard Design -->
## 39. Printed Scorecard Design

Printed scorecards are generated snapshots from current saved facts and replay. They are not editable source records. Printing must not mutate source records, repair compatibility evidence, update stored scores, or mark a game complete.

Printed output should include page identity, game identity, home and visiting teams, date and location, lineup rows, substitution history, inning columns, extra innings, large lineups, score and line score, pitcher participation, notes, warnings or incomplete data, and readable pagination.

Print readability must not depend on color alone. Symbols, text, line weight, labels, and accessible print summaries should preserve meaning for black-and-white output and photocopies.

<!-- MARK: - 40. PDF Scorecard Design -->
## 40. PDF Scorecard Design

PDF scorecards are generated snapshots from the same projection as live and historical scorecards. A PDF reflects the source game at generation time and remains external output after sharing. Later corrections regenerate future PDFs but cannot change already shared files.

PDF output should include page identity, game identity, teams, date, location, lineup rows, substitution history, inning columns, extra innings, large lineups, score, line score, pitcher participation, notes, warnings, media inclusion where selected, pagination, and source-record immutability.

Existing PDF generation draws scorecard grids, base paths, outs, totals, box score, and pitcher summaries directly from legacy at-bats and stored relationships. That is observed behavior and compatibility evidence. The rewritten design should feed PDF generation from canonical projections so PDF, screen, and reports agree.

<!-- MARK: - 41. Media in Scorecards -->
## 41. Media in Scorecards

Media may include team logos, player photos, or other supported game-time images. Media can improve recognition but is not identity by itself. Missing, invalid, oversized, or omitted media must not make baseball facts unusable.

Scorecard media should respect the media policy from persistence and import/export design: historical display must remain understandable after current media changes, and sharing should include only selected scope. A printed or PDF scorecard should indicate game meaning through text even when media is absent.

Media inclusion should not alter source records or repair media evidence. If a logo or photo cannot be rendered, the scorecard should use a fallback and preserve the warning without blocking baseball review unless the output purpose explicitly requires media.

<!-- MARK: - 42. Accessibility Design -->
## 42. Accessibility Design

Scorecard accessibility must support VoiceOver, larger text, increased contrast, reduced motion, color-independent notation, external keyboards, focus order, event selection, correction workflows, reports, PDF previews, and print previews where the platform allows.

The accessible experience should expose baseball meaning rather than only grid geometry. Users should be able to navigate by team, inning, batting slot, player, event, scoring play, warning, substitution, pitcher change, or current state.

Interactive elements should have clear focus order and actions. Selecting an event should not change records. Correction actions should be explicit, reviewable, and reachable with VoiceOver and keyboard input.

<!-- MARK: - 43. VoiceOver Scorecard Description -->
## 43. VoiceOver Scorecard Description

VoiceOver should be able to describe a scorecard entry in meaningful baseball language rather than merely reading a coordinate. An accessible entry description may include batter, batting slot, inning, result, bases reached, runner movement, outs, runs, RBIs, pitcher, substitution context, and warning state.

The description should distinguish empty cells, incomplete events, unsupported legacy results, unknown players, unknown pitchers, and corrected or superseded events. It should not imply certainty where the projection has warnings.

This design does not prescribe exact UI strings. It requires that accessible descriptions derive from the same projection and warning model used by visible scorecard presentation.

<!-- MARK: - 44. Larger Text and Constrained Layouts -->
## 44. Larger Text and Constrained Layouts

Larger text should preserve core actions and baseball meaning even when the traditional grid becomes too dense. The scorecard may switch to focused entries, row summaries, detail panels, pagination, or alternate navigation when cell text cannot fit.

Constrained layouts must not overlap text, hide warnings, truncate player identity in a misleading way, or make current scoring controls unreachable. Duplicate names and numbers require enough context to avoid wrong-player corrections.

Print and PDF layouts should use readable scale, pagination, and summaries rather than shrinking content until it becomes inaccessible. Large lineups and extra innings may require additional pages.

<!-- MARK: - 45. Color-Independent Meaning -->
## 45. Color-Independent Meaning

Color must not be the only signal for scoring state, warnings, selected cells, outs, runs, current batter, substitutions, pitcher changes, destructive actions, or purchase-gated output. Meaning should also be expressed with text, symbols, shape, position, labels, or accessibility metadata.

Current scorecard drawing uses color for base paths, outs, and end-of-inning lines. Those visual conventions can remain as presentation choices, but each meaning needs a color-independent counterpart for print, PDF, VoiceOver, increased contrast, and color-blind users.

Warnings and incomplete data should remain visible in grayscale output. A printed scorecard should still identify unsupported results, missing participants, and score mismatches.

<!-- MARK: - 46. Error and Warning Presentation -->
## 46. Error and Warning Presentation

Scorecard warnings should be product-language classifications, not raw storage errors. Categories include unknown pitcher, missing player, missing lineup, unsupported result, `Sacrifise` compatibility, stored-score mismatch, incomplete runner movement, ambiguous substitution, invalid legacy column, duplicate event order, incomplete pitcher period, and compatibility-limited game.

Warnings should appear near affected entries where useful and in a summary for navigation, print, PDF, and accessibility. The user should understand whether the game remains usable, requires repair, or has output limitations.

Errors that block projection should preserve source records and offer review or repair. The scorecard should not hide a failed replay behind an empty grid that looks like an unscored game.

<!-- MARK: - 47. Incomplete and Compatibility-Limited Games -->
## 47. Incomplete and Compatibility-Limited Games

Incomplete games may still have useful scorecards. The projection should identify draft, in-progress, interrupted, suspended, shortened, completed, imported historical, and compatibility-limited states where available.

Compatibility-limited games should show what is known and what is uncertain. For example, a legacy game may have batter results and stored score but incomplete runner outcomes; it may show event entries while warning that runner paths or score reconciliation are limited.

The scorecard should avoid inventing missing innings, fake outs, guessed participants, or reconstructed runner movement without evidence. Repair workflows can improve the facts later and regenerate the projection.

<!-- MARK: - 48. Legacy Scorecard Mapping -->
## 48. Legacy Scorecard Mapping

Observed legacy scorecard concepts should be classified by their role. `Atbat.result`, batter identity, team side, RBIs, stolen bases, earned-run flag, play notes, and clear supported destination or out evidence can be canonical fact evidence when coherent. `Atbat.col`, `Atbat.seq`, legacy `inning`, placeholder rows, `Pitch Hitter` rows, fixed drawing positions, and current base-path drawings are compatibility or presentation evidence.

`maxbase` and `outAt` are mixed evidence: they can describe batter destination or a base-path out, but they may be ambiguous for existing runner movement, multiple outs, multiple runs, and third-out cases. `endOfInning` is derived or presentation evidence. `Game.hscore` and `Game.vscore` are derived value or stored compatibility evidence unless explicitly reviewed.

`Game.replaced`, `Game.incomings`, substitution sequence indexing, and player `batOrder` changes are compatibility evidence for substitution reconstruction. Ambiguous or mismatched values are repair-required evidence, not verified substitution facts.

<!-- MARK: - 49. Legacy Column and Sequence Interpretation -->
## 49. Legacy Column and Sequence Interpretation

Legacy `col` and `seq` values help preserve old visual scorecards and reconstruct display order, especially for files created by current ScoreKeep. They should be retained as compatibility evidence and used when they agree with replay and event order.

They should not be the sole authority for canonical event placement. A corrected event, inserted event, deleted event, substituted batter, extra inning, or large lineup may require a regenerated presentation coordinate that differs from legacy values.

If `col`, `seq`, inning, and replay order conflict, the projection should identify the conflict and choose the interpretation policy defined by scoring-engine and compatibility rules. Silent visual reordering that changes baseball meaning is not acceptable.

<!-- MARK: - 50. Fixed-Size Assumption Retirement -->
## 50. Fixed-Size Assumption Retirement

The rewritten scorecard architecture must retire fixed-size inning, column, row, and substitution assumptions. It should support scorecard projections sized by actual game facts and output constraints.

Repository evidence includes fixed `colbox` and `batbox` arrays in live scorecard state, finite inning abbreviation lists, drawing loops with fixed ranges, and regression catalog risks for fixed-size scorecard and substitution indexing. These are compatibility risks to verify, not requirements to preserve.

Scale behavior should be fixture-backed. Extra-inning games, large lineups, substitution-heavy games, pitcher-heavy games, and fixed-size crash regressions must prove that scorecard display, reports, PDFs, exports, and reopened state remain coherent.

<!-- MARK: - 51. Performance and Scale -->
## 51. Performance and Scale

Scorecard generation should feel immediate for ordinary live scoring and remain usable for long games, large lineups, extra innings, many substitutions, many pitchers, media-heavy teams, and historical review. Longer work should show progress without weakening correctness.

Optimization may use cached projections, layout measurements, or pagination hints, but these caches cannot become authorities. Any change to source facts, interpretation policy, or relevant presentation settings must invalidate affected projections.

Live scoring should prioritize fast current-state updates. Historical reports, print, and PDF generation may perform more complete pagination or layout work, but they must consume the same replay result.

<!-- MARK: - 52. State Preservation and Recovery -->
## 52. State Preservation and Recovery

Scorecard presentation state may include selected event, scroll position, zoom level, visible side, active warning filter, print preview page, and detail panel state. Preserving this state improves usability but must remain separate from baseball facts.

After app backgrounding, device sleep, interruption, correction replay, or window resizing, the app should restore meaningful scorecard context where practical. Completed plays remain completed; incomplete plays remain unfinished or safely discarded according to scoring workflow rules.

If projection generation fails, source records remain unchanged. Recovery should allow retry, repair review, or return to scoring without presenting a misleading empty or final scorecard.

<!-- MARK: - 53. Privacy and Sharing -->
## 53. Privacy and Sharing

Scorecards may contain youth-player names, numbers, photos, team logos, locations, notes, and game history. Sharing, printing, and PDF generation must be deliberate and scoped to the selected game or report output.

Generated scorecards should avoid exposing unrelated teams, players, local filesystem paths, account details, purchase state, or hidden diagnostics. Warning summaries should include enough context for the selected game without leaking unrelated records.

Sharing a generated scorecard does not transfer editing authority back into the app. A PDF or printout is output, not a source record. Compatible game export remains the supported source-data sharing path.

<!-- MARK: - 54. Verification Strategy -->
## 54. Verification Strategy

Verification should compare canonical facts, scoring-engine replay, live scorecard, historical scorecard, reports, PDFs, exports, reopened game state, warnings, and repair outcomes. The same facts should produce consistent meaning across every output.

Required scenarios include regulation completed game, in-progress game, extra-inning game, large lineup, Everyone Hits, substitution-heavy game, pinch hitters and runners, pitcher-change-heavy game, double play, triple play, multiple runs, third-out run cases, unknown pitcher, missing player, unsupported result, `Sacrifise`, stored-score mismatch, duplicate events, corrections, interrupted scoring, legacy seeded game, PDF generation, iPhone and iPad layouts, VoiceOver live scoring, larger text, and fixed-size crash regressions.

Expected evidence should include scores, inning columns, event placement, runner paths, outs, RBIs, earned-run decisions, substitution history, pitcher context, warnings, print/PDF pagination, accessible descriptions, export agreement, and source-record preservation.

<!-- MARK: - 55. Migration and Coexistence -->
## 55. Migration and Coexistence

The new scorecard projection can coexist with legacy scorecard views while compatibility adapters and scoring-engine projections are verified. Legacy views remain behavior references and compatibility evidence, but they should not remain hidden second authorities after replacement.

Early migration can compare legacy scorecards, canonical projections, reports, and PDFs for the same fixtures. Differences should be classified as accepted improvement, legacy limitation, defect, warning, or required repair.

Routing should change only after fixture evidence proves that the rewritten scorecard preserves supported behavior, handles warnings honestly, avoids fixed-size failures, and agrees with reports, PDFs, exports, and reopened game state.

<!-- MARK: - 56. Risks and Open Questions -->
## 56. Risks and Open Questions

Risks include incomplete runner evidence, legacy `maxbase` and `outAt` ambiguity, stored-score mismatch, unsupported result round trip, substitution reconstruction from parallel arrays, pitcher responsibility around mid-inning changes, fixed-size layout assumptions, duplicated report calculations, and accessibility gaps in dense grids.

Open questions remain around the exact canonical representation of runner-only events, how much legacy visual placement to preserve when it conflicts with replay, how to label compatibility-limited entries in user-facing language, media snapshot policy for historical scorecards, practical scale thresholds, and whether retained generated PDFs need stale-output indicators.

These questions should be resolved through fixtures, application-service design, implementation spikes, and acceptance evidence rather than by weakening the projection boundary.

<!-- MARK: - 57. Success Criteria -->
## 57. Success Criteria

This design succeeds when live scorecards, historical scorecards, printed scorecards, PDF scorecards, accessible descriptions, reports, exports, and reopened game state all derive from the same canonical facts and replay result.

A successful scorecard preserves batter sequence, inning progression, runner movement, outs, runs, RBIs, substitutions, pitcher context, warnings, and compatibility evidence without becoming a separate source of truth. Corrections modify underlying facts, replay downstream state, and regenerate projections.

It should support iPhone, iPad, adaptive windows, large lineups, Everyone Hits, extra innings, print, PDF, VoiceOver, larger text, color-independent meaning, legacy records, and fixed-size regression fixtures without corrupting source records.

<!-- MARK: - 58. Recommended Next Design Document -->
## 58. Recommended Next Design Document

The recommended next design document is `23-ApplicationServicesAndWorkflowDesign.md`.

Documents 18 through 22 will then define canonical baseball meaning, scoring replay, persistence, compatibility exchange, and scorecard presentation. Application services should follow because they coordinate user actions across those boundaries without putting business rules into SwiftUI views.

That document should define how scoring, correction, import, export, report generation, PDF generation, printing, purchase-gated actions, recovery, and warning review are orchestrated as application workflows while preserving the boundaries established here.

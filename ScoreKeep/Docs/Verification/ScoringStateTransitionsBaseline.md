# Scoring State Transitions Baseline

<!-- MARK: - 1. Scope -->
## 1. Scope

This baseline records the non-routed Phase 2 foundation for implementation-catalog tasks `2.4 Count transition handling`, `2.5 Out transition handling`, `2.6 Base-runner transition handling`, `2.7 Run and score calculation`, and `2.8 Inning transition calculation`.

The foundation introduces deterministic value-only transition types for count classification, outs, base-runner movement, score projection, inning transitions, and one-command composed application. It does not route production scoring, create or edit `Atbat` rows, save SwiftData records, update `Game.hscore` or `Game.vscore`, alter runner controls, change scorekeeping views, modify correction workflows, touch imports or exports, change reports or PDFs, or begin tasks `2.9` and later.

<!-- MARK: - 2. Count Transition Conclusion -->
## 2. Count Transition Conclusion

Repository evidence still shows no persisted or fully supported ball-and-strike count model. Count transition handling therefore remains explicit and unsupported by default. Raw count evidence can be preserved, invalid and contradictory count evidence can be classified, and reset boundaries remain representable, but this run does not add persisted count fields or invent pitch-by-pitch tracking.

<!-- MARK: - 3. Out Transitions -->
## 3. Out Transitions

Out transitions accept immutable current outs, aggregate outs requested by one event, participant-out evidence, and end-of-half evidence. They produce resulting outs, participant runner-out evidence, third-out context, end-half requirements, and run-validity review requirements when runner-out third-out context exists.

Rejected out transitions leave the input outs unchanged. Negative out changes, missing or invalid current outs, fourth-or-greater resulting outs, too many requested outs, duplicate participant outs, missing participant identity, and conflicting aggregate participant evidence are classified rather than normalized.

<!-- MARK: - 4. Base-Runner Transitions -->
## 4. Base-Runner Transitions

Base-runner transitions apply explicit batter outcomes and runner destinations against immutable base occupancy. They support batter reaching first, second, or third; batter scoring; runner advancement; runner scoring; runner outs; coordinated movement where an occupied destination is vacated by explicit movement; and preservation of unrelated runners.

The transition rejects occupied destination conflicts, duplicate runner outcomes, multiple runners assigned to one base, backward movement, missing or invalid runner identity, disappearing runners when expected resulting occupancy is supplied, and contradictory resulting occupancy. Rejections return the original base occupancy and no partial runner outcomes.

<!-- MARK: - 5. Score Calculation -->
## 5. Score Calculation

Score calculation derives score changes from scored-runner evidence and batting side. It preserves explicit RBI and earned-run evidence without inventing either value. Duplicate scored-runner evidence is counted once with a warning. Missing or unresolved team side and negative input score prevent score mutation.

Stored score evidence can be compared diagnostically with the projected score, but it is not treated as canonical truth and is not overwritten. Third-out run-validity policy remains review-required where the approved evidence is insufficient to count or discard a run automatically.

<!-- MARK: - 6. Inning Transitions -->
## 6. Inning Transitions

Inning transitions advance top half to bottom half of the same inning and bottom half to top half of the next inning when third-out context or an explicit end-half command supports the transition. A supported half-inning transition resets outs to zero, clears bases, preserves score, retains expected-inning configuration, and represents extra innings without automatically completing the game.

Missing inning evidence, invalid inning evidence, missing or unresolved half evidence, and contradictory end-half evidence reject the transition and leave inning, outs, bases, and score unchanged. Completion, shortened-game finality, walk-off rules, mercy rules, and automatic extra-inning runners remain deferred.

<!-- MARK: - 7. Composed Application -->
## 7. Composed Application

The composed non-routed applicator builds on `CanonicalEventApplication`. It validates one command, applies the existing event application foundation, then composes count classification, base-runner transition, out transition, score calculation, and inning transition where supported.

The pipeline is deterministic and atomic. A failed runner, out, score, or inning stage returns no accepted event and leaves the supplied input state unchanged. It generates no random identity, uses no current date, performs no persistence, and preserves unrelated game, lineup, pitcher, and roster evidence.

<!-- MARK: - 8. Verification Evidence -->
## 8. Verification Evidence

Focused Swift Testing coverage verifies unsupported count boundaries, raw count preservation, bounded out transitions, third-out context, participant-out evidence, duplicate and missing out participants, coordinated runner movement, collision rejection, duplicate runner outcomes, disappearing runner rejection, score projection, RBI and earned-run evidence preservation, stored-score comparison, inning advancement, outs reset, bases cleared, extra-inning representation, atomic composed application, deterministic output, no random event identity, and unchanged unrelated evidence.

Read-only fixture evidence includes `CompletedGame.ScoreKeep_Games`, `InProgressGame.ScoreKeep_Games`, `MultipleAtbats.ScoreKeep_Games`, `BrokenAtbatRelationship.ScoreKeep_Games`, and `DuplicateAtbatID.ScoreKeep_Games`. Fixtures were not modified.

<!-- MARK: - 9. Deferred Behavior -->
## 9. Deferred Behavior

This run explicitly defers current-batter projection, next-batter projection, active-pitcher projection, pitcher statistics, substitution application, full-game replay, correction replay, undo, duplicate-command suppression, complete third-out run legality, walk-off rules, mercy rules, automatic extra-inning runners, production cutover, persistence migration, reports, imports, exports, and all UI behavior.

The next consolidated implementation run is `2.9–2.10 Batter and Pitcher Projection`.

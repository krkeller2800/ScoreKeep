# Scoring Command and Event Application Baseline

<!-- MARK: - 1. Scope -->
## 1. Scope

This baseline records the non-routed Phase 2 foundation for implementation-catalog tasks `2.1 Accepted scoring command vocabulary`, `2.2 Scoring command validation`, and `2.3 Deterministic event application`.

The foundation introduces value-only command, validation, and one-event application types. It does not route production scoring, create `Atbat` records, save SwiftData records, update stored scores, advance production innings, change runner UI, select the next batter, change pitchers, modify reports, alter imports or exports, or consume purchases or allowances.

<!-- MARK: - 2. Command Vocabulary -->
## 2. Command Vocabulary

Supported command evidence is limited to repository-confirmed scoring behavior: batter reaches first, second, third, home run, batter out, strikeout and strikeout-looking out results, walk and equivalent reach-base results, fielder's-choice and error reach-base evidence, sacrifice fly and sacrifice bunt evidence, runner advance, runner score, runner out, stolen-base marker evidence, multiple-out evidence, end-half evidence, and unsupported legacy preservation.

The command identity is not a UI label, picker title, display abbreviation, report row, or persisted `Atbat`. Raw legacy values remain preserved when they are unsupported, unknown, ambiguous, or contradictory. The known legacy spelling issue `Sacrifise` remains recognized unsupported evidence rather than being coerced to supported sacrifice commands.

<!-- MARK: - 3. Validation Boundary -->
## 3. Validation Boundary

Validation consumes immutable canonical game, inning, outs, base occupancy, batter, lineup-participant, team-side, and pitcher-responsibility evidence. It returns `CanonicalValidationResult` findings for accepted, accepted-with-warnings, incomplete, unsupported, rejected, contradictory, unresolved, and repair-required cases.

Validation performs no writes, repairs, SwiftData access, UI changes, score updates, inning advancement, runner mutation, batter progression, pitcher changes, substitutions, purchase changes, or allowance changes. Rejected, unsupported, contradictory, and unresolved results leave the supplied input state unchanged and block in-memory application.

<!-- MARK: - 4. Event Application -->
## 4. Event Application

Application is one accepted command against one immutable input state. It returns an optional canonical scoring event, a resulting in-memory state projection, validation findings, changed-fact tags, and preserved unsupported evidence.

No event identity is generated. The event identity is either supplied by the caller or remains missing. The same input and command produce the same output. Rejected or unsupported commands produce no accepted event and return the unchanged input state.

<!-- MARK: - 5. Deferred Behavior -->
## 5. Deferred Behavior

This foundation intentionally defers the transition authority assigned to tasks `2.4` through `2.8`: ball and strike transitions, complete double-play and triple-play handling, full runner-advancement matrices, third-out run-validity rules, complete score calculation, inning progression, walk-off behavior, mercy rules, extra-inning runners, current and next batter projection, active-pitcher projection, replay of a complete game, correction replay, and production routing.

Legacy scoring views, `Atbat` creation, score updates, runner handling, inning handling, corrections, reports, persistence, imports, and exports remain the active production authorities.

<!-- MARK: - 6. Verification Evidence -->
## 6. Verification Evidence

Focused Swift Testing coverage verifies supported vocabulary, unsupported and ambiguous legacy handling, deterministic construction, accepted validation, warning-only missing pitcher evidence, missing or invalid game and batter evidence, side conflicts, inning and outs rejection, third-out context, fourth-out prevention, runner source-base and destination conflicts, unsupported results, unchanged input state, one-command application, RBI, sacrifice, stolen-base, earned-run, ordering evidence, no random event identity, and representative fixture evidence.

Fixtures referenced include `CompletedGame.ScoreKeep_Games`, `MultipleAtbats.ScoreKeep_Games`, `InProgressGame.ScoreKeep_Games`, `BrokenAtbatRelationship.ScoreKeep_Games`, and `DuplicateAtbatID.ScoreKeep_Games`. Fixtures are read only and are not modified.

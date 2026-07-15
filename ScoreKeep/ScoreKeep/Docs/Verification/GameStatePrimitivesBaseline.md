# Game State Primitives Baseline

<!-- MARK: 1. Evidence Reviewed -->
## 1. Evidence Reviewed

Reviewed Documents 17-23 and 27-29, current `Game` and `Atbat` models, game creation/editing/list/detail workflows, scoring views, scorecard/PDF/report code, import behavior, seeded/sample hints, and representative fixtures.

<!-- MARK: 2. Canonical Boundary -->
## 2. Canonical Boundary

This baseline introduces only non-routed semantic primitives for game identity/status, inning and half-inning, optional count evidence, outs, and base occupancy. It does not change SwiftData models, production scoring, imports, exports, reports, UI, routing, or persistence.

<!-- MARK: 3. Repository Findings -->
## 3. Repository Findings

`Game.ident` is the stable game identity evidence. Team/date matching, score, location, expected innings, display order, and completion text are not identity. `Game.numInnings` is expected-inning configuration. `Game.everyOneHits` is lineup-mode configuration. Import and seed paths provide origin evidence, but origin does not redefine identity.

`Atbat.inning`, `Atbat.outs`, `Atbat.maxbase`, `Atbat.outAt`, `Atbat.rbis`, `Atbat.stolenBases`, `Atbat.earnedRun`, and `Atbat.endOfInning` are compatibility evidence for later interpretation. `maxbase == "Home"` is used by current reports and summaries as run-like evidence, but stored scores remain reconciliation evidence rather than identity or lifecycle authority.

No persisted or clearly supported ball/strike count fields were found. Count support is therefore represented as an optional unsupported repository-evidence boundary, not pitch-by-pitch tracking.

<!-- MARK: 4. Fixture Coverage -->
## 4. Fixture Coverage

Compatibility tests use `MinimalValid.ScoreKeep_Games`, `CompletedGame.ScoreKeep_Games`, `InProgressGame.ScoreKeep_Games`, `MultipleAtbats.ScoreKeep_Games`, `LineupGame.ScoreKeep_Games`, `PitcherGame.ScoreKeep_Games`, `DuplicateConflict.ScoreKeep_Games`, `MissingOptionalValues.ScoreKeep_Games`, `BrokenAtbatRelationship.ScoreKeep_Games`, `DuplicateAtbatID.ScoreKeep_Games`, and `UnsupportedScoreValue.ScoreKeep_Games`.

<!-- MARK: 5. Accessibility -->
## 5. Accessibility

This run has no user-facing route. No accessibility labels, focus behavior, Dynamic Type behavior, colors, touch targets, keyboard behavior, or iPhone/iPad layout are changed.

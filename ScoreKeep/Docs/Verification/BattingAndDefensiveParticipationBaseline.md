# Batting Order and Defensive Participation Baseline

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This note completes implementation-catalog tasks `1.6 Batting-order semantics` and `1.7 Defensive position semantics` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The run introduces non-routed canonical authority for batting-slot evidence, batting-order classification, progression hints, defensive-position evidence, and pitcher-only participation boundaries. It does not route production workflows through the new types and does not change SwiftData models, persistence, migrations, imports, exports, scorekeeping, current batter, next batter, lineup editing, player editing, pitcher workflows, substitutions, reports, PDFs, fixtures, StoreKit, purchases, allowances, UI, navigation, seed behavior, deployment targets, build settings, or compatibility schemas.

<!-- MARK: - 2. Source Location -->
## 2. Source Location

Production source paths:

`ScoreKeep/Common/CanonicalBattingOrderSemantics.swift`

`ScoreKeep/Common/CanonicalDefensivePositionSemantics.swift`

Focused tests live in `ScoreKeepTests/CanonicalBattingOrderSemanticsTests.swift` and `ScoreKeepTests/CanonicalDefensivePositionSemanticsTests.swift`.

The new files are siblings of the existing non-routed foundation files and build on `CanonicalLineupMeaning`, `CanonicalPlayerMeaning`, `CanonicalRosterMembership`, and `StableIdentityAndOrdering` without replacing them.

<!-- MARK: - 3. Batting-Order Evidence -->
## 3. Batting-Order Evidence

Batting-order meaning is represented as game- and lineup-specific evidence. Known slots, missing slots, invalid raw slots, unsupported raw slots, the confirmed `99` non-hitting sentinel, duplicate slots, conflicting slot evidence, player-without-slot evidence, unresolved participant-with-slot evidence, historical slot evidence, source-order evidence, traditional context, Everyone Hits context, and unknown mode context are all explicit.

Batting slot remains separate from reusable player identity, roster membership, roster order, display sorting, jersey-number sorting, source-file order, defensive position, current batter, next batter, scoring-event sequence, and player `batOrder` hints.

<!-- MARK: - 4. Progression Hint Boundary -->
## 4. Progression Hint Boundary

The foundation can produce progression hints from ordered known slots, expected forward direction, wraparound expectation, unknown progression for incomplete evidence, ambiguous progression for duplicates or conflicts, and historical progression context after lineup changes.

It does not select a current batter, select a next batter, advance a batting order, apply substitutions, mutate scoring rows, repair missing slots, normalize duplicate slots, or implement batter projection.

<!-- MARK: - 5. Sentinel and Imported Values -->
## 5. Sentinel and Imported Values

Repository evidence confirms `99` as the non-hitting sentinel in player creation, edit pickers, scorecard filtering, and pitcher fixtures. Current roster editing exposes picker values `0...19` plus `99`, and roster creation converts a new-player `0` selection to `99`. Fixture evidence also preserves imported values beyond traditional nine-player slots, including `10` for Everyone Hits and `51` in a missing-optional roster fixture.

The new semantics preserve raw compatibility values without rewriting `Player.batOrder`, fixtures, import behavior, export behavior, current lineup arrays, or scorecard rows.

<!-- MARK: - 6. Defensive-Position Evidence -->
## 6. Defensive-Position Evidence

Defensive-position meaning is represented as contextual evidence. Recognized values are based on repository evidence from `Common.position`, `Common.posAbbrev`, player editor free-text behavior, and fixtures: `P`, `SP`, `RP`, `C`, `1B`, `2B`, `SS`, `3B`, `LF`, `CF`, `RF`, `DH`, and their supported display names where present in `Common.position`.

Blank position, missing position, unknown raw text such as `??`, unsupported raw text, raw imported text, conflicting evidence, historical position evidence, participant-without-position evidence, and unresolved lineup participant evidence remain representable.

<!-- MARK: - 7. Pitcher Boundary -->
## 7. Pitcher Boundary

Pitcher-related participation is represented only enough to distinguish recognized pitcher position evidence, pitcher-only participation, batter-and-pitcher participation, pitcher records, and unknown pitcher relationships.

The foundation does not implement pitcher responsibility, active pitcher projection, pitching statistics, pitching changes, pitcher appearance validation, or task `1.13`.

<!-- MARK: - 8. Compatibility Evidence -->
## 8. Compatibility Evidence

Focused tests read existing fixtures through the established fixture loader without mutation. Fixtures used include `CompleteRoster.ScoreKeep_Players`, `MinimalValid.ScoreKeep_Players`, `MissingOptionalValues.ScoreKeep_Players`, `LineupGame.ScoreKeep_Games`, `PitcherGame.ScoreKeep_Games`, and `BrokenPitcherRelationship.ScoreKeep_Games`.

Compatibility evidence is interpreted as raw imported values, historical evidence, recognized values, blank values, sentinel values, unknown relationships, or unsupported evidence only. No fixture records, transport schemas, import routes, export routes, or persistence writers were changed.

<!-- MARK: - 9. Production Routing Status -->
## 9. Production Routing Status

No active production workflow references the new batting-order or defensive-position semantic types after this task. Current `Player.batOrder`, `Player.position`, lineup arrays, sorting, starting-lineup setup, edit-lineup behavior, Everyone Hits behavior, current-batter logic, next-batter logic, scoring progression, pitcher records, pitcher workflows, substitutions, imports, exports, reports, PDFs, and persistence remain legacy-owned.

The new files contain no SwiftData annotations, model-container access, file writes, import/export entry points, StoreKit access, Keychain access, UI, routing, random identifier generation during classification, production adapter, migration, or current-record mutation.

<!-- MARK: - 10. Limitations Risks and Next Tasks -->
## 10. Limitations Risks and Next Tasks

Limitations: this task does not implement game identity or status, inning semantics, outs semantics, base occupancy, recorded play participants, scoring-event meaning, batter projection, pitcher responsibility, defensive legality validation, substitution authority, persistence adapters, compatibility routing, reports, UI, production services, repair behavior, or historical snapshot persistence.

Risks: later routing must preserve the separation between game-specific batting slots, current roster `batOrder`, source order, display sorting, defensive position, pitcher participation, and scoring progression. Free-text position entry remains a legacy compatibility source until a future workflow task accepts a new authority.

Recommended next consolidated run: `1.8–1.11 Game State Primitives`.

Recommended following consolidated run: `1.12–1.14 Recorded Play Participants`.

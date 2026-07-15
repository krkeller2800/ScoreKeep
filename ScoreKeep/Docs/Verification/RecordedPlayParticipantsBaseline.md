# Recorded Play Participants Baseline

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This note completes implementation-catalog tasks `1.12 Scoring-event meaning`, `1.13 Pitcher responsibility meaning`, and `1.14 Substitution meaning` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The run introduces non-routed canonical authority for recorded scoring-event evidence, batter and runner participation, event outcome markers, pitcher appearance and responsibility evidence, substitution relationships, and ambiguity classification. It does not route production workflows through the new types and does not change SwiftData models, persistence, imports, exports, scoring, replay, correction, pitcher workflows, substitution workflows, reports, PDFs, UI, accessibility, fixtures, StoreKit, purchases, allowances, seed behavior, deployment targets, or build settings.

<!-- MARK: - 2. Source Location -->
## 2. Source Location

Production source paths:

`ScoreKeep/Common/CanonicalScoringEventMeaning.swift`

`ScoreKeep/Common/CanonicalPitcherResponsibilityMeaning.swift`

`ScoreKeep/Common/CanonicalSubstitutionMeaning.swift`

Focused tests live in `ScoreKeepTests/CanonicalScoringEventMeaningTests.swift`, `ScoreKeepTests/CanonicalPitcherResponsibilityMeaningTests.swift`, and `ScoreKeepTests/CanonicalSubstitutionMeaningTests.swift`.

The files are siblings of the existing non-routed Phase 1 canonical foundations and build on stable identity, ordering, team side, player participation, lineup, batting slot, defensive position, inning, outs, and base-occupancy semantics.

<!-- MARK: - 3. Repository Evidence Reviewed -->
## 3. Repository Evidence Reviewed

Reviewed Documents 17-23 and 27-29, the existing verification notes for stable identity and ordering, player meaning, lineup meaning, batting and defensive participation, game-state primitives, compatibility evidence tests, current `Game`, `Atbat`, `Pitcher`, `Player`, and `Lineup` records, current scoring views, scorecard drawing, reports, pitcher reporting, replacement arrays, import/export transport types, and representative fixtures.

Confirmed recorded-play fields include `Atbat.ident`, `game`, `team`, `player`, `result`, `maxbase`, `batOrder`, `outAt`, `inning`, `seq`, `col`, `rbis`, `outs`, `sacFly`, `sacBunt`, `stolenBases`, `earnedRun`, `playRec`, and `endOfInning`.

Confirmed pitcher fields include `Pitcher.ident`, `player`, `team`, `game`, `startInn`, `sOuts`, `sBats`, `endInn`, `eOuts`, `eBats`, `strikeOuts`, `walks`, `hits`, `runs`, and `won`.

Confirmed substitution evidence includes `Game.replaced`, `Game.incomings`, transport `ShareGame.replaced`, transport `ShareGame.incomings`, lineup context, player `batOrder` evidence, and pitcher-change context. Parallel array positions are preserved as compatibility evidence only.

<!-- MARK: - 4. Scoring-Event Evidence -->
## 4. Scoring-Event Evidence

Recorded scoring events are represented as evidence, not mutable game state. Event identity remains separate from sequence, inning, scorecard column, batter name, result string, array position, score, and display order.

The foundation represents valid, missing, invalid, duplicate, conflicting, visually identical, and unresolved event identity evidence. It also represents known sequence, missing sequence, duplicate sequence, conflicting sequence and scorecard-column evidence, source-file order, stable tie evidence, and unresolved order without forcing a total order.

Repository-confirmed result evidence is limited to current `Common` result strings and observed legacy values: batter reaches base, batter out, runner advances, runner scores, runner out, placeholder or unknown result, unsupported raw result, and conflicting result evidence. Batter and runner advancement, outs recorded, runs, RBIs, earned-run markers, sacrifice markers, stolen-base markers, end-of-inning markers, historical display evidence, missing relationships, and unsupported raw legacy values are representable without applying transitions.

<!-- MARK: - 5. Pitcher Responsibility Evidence -->
## 5. Pitcher Responsibility Evidence

Pitcher meaning is contextual. A reusable player identity and a game-specific pitcher appearance are distinct. The same player can pitch in multiple games, start one game, relieve in another, bat and pitch in the same game, and carry historical display evidence without redefining reusable-player identity.

The foundation represents pitcher appearance identity, reusable pitcher identity, game identity, team side, appearance order, starting-pitcher evidence, relief-pitcher evidence, active-pitcher evidence where observed as current-state evidence, pitcher-only participation, batter-and-pitcher participation, start and end boundary evidence, event responsibility evidence, run and earned-run responsibility markers, team-side conflicts, missing relationships, invalid identities, duplicate appearance identities, duplicate appearance order, multiple pitchers claiming one event, unresolved relationships, and current active pitcher state differing from historical event evidence.

It does not infer responsibility solely from current active pitcher state and does not calculate pitching statistics, active-pitcher projection, earned runs, wins, losses, or pitching changes.

<!-- MARK: - 6. Substitution Evidence -->
## 6. Substitution Evidence

Substitution meaning is represented as incoming and outgoing participant evidence with game identity, optional team side, effective order, batting-slot context, defensive-position context, pitcher-change context, historical lineup context, role evidence, unsupported raw evidence, and legacy parallel-array evidence.

The foundation represents known incoming and outgoing participants, missing incoming participant, missing outgoing participant, same participant incoming and outgoing, duplicate substitution identities, conflicting batting-slot context, conflicting defensive-position context, pitcher-change evidence, unknown role, batter replacement, runner replacement, defensive replacement, lineup-entry replacement, unsupported evidence, unresolved evidence, and same participant appearing on both team sides.

Legacy `replaced` and `incomings` arrays classify equal counts as plausible index pairing evidence, not certainty. Unequal counts, missing arrays, duplicate participants, same participant in both roles, ambiguous ordering, missing timing, and inability to establish offensive, defensive, pitching, or administrative role remain explicit ambiguity or conflict evidence. Array order alone does not fabricate inning, role, timing, or legality.

<!-- MARK: - 7. Compatibility Fixtures -->
## 7. Compatibility Fixtures

Focused tests use checked-in fixtures through the established simulator-safe fixture loader. Fixtures used include `CompletedGame.ScoreKeep_Games`, `MultipleAtbats.ScoreKeep_Games`, `LineupGame.ScoreKeep_Games`, `PitcherGame.ScoreKeep_Games`, `MissingOptionalValues.ScoreKeep_Games`, `BrokenAtbatRelationship.ScoreKeep_Games`, `BrokenPitcherRelationship.ScoreKeep_Games`, and `DuplicateAtbatID.ScoreKeep_Games`.

Fixture evidence is decoded and inspected only. No fixture, compatibility structure, import route, export route, persisted record, or seed data is modified.

<!-- MARK: - 8. Production Routing Status -->
## 8. Production Routing Status

No active production workflow references the new recorded-play participant semantic types after this task. Current `Atbat`, `Pitcher`, `Game.replaced`, `Game.incomings`, scoring actions, correction behavior, runner advancement, out calculation, inning advancement, current batter, next batter, pitcher statistics, pitcher changes, substitution workflows, imports, exports, reports, PDFs, and UI remain legacy-owned.

The new files contain no SwiftData annotations, model-container access, file writes, import/export entry points, StoreKit access, Keychain access, UI, routing, random identifier generation during classification, production adapter, migration, replay engine, scoring engine, or current-record mutation.

<!-- MARK: - 9. Accessibility -->
## 9. Accessibility

This run has no user-facing route. No accessibility labels, focus behavior, Dynamic Type behavior, colors, touch targets, keyboard behavior, VoiceOver behavior, or iPhone/iPad layouts are changed.

<!-- MARK: - 10. Limitations Risks and Next Work -->
## 10. Limitations Risks and Next Work

Limitations: this task does not implement domain validation, legacy-to-canonical mapping adapters, scoring command vocabulary, event application, replay, correction, state transitions, active-pitcher projection, pitcher statistics, substitution legality, substitution application, persistence mapping, import/export replacement, reporting replacement, or production routing.

Risks: later mapping must preserve the distinction between canonical evidence and compatibility-only evidence. In particular, `maxbase`, `outAt`, `Atbat.outs`, `Atbat.col`, current active pitcher state, stored pitcher totals, and legacy substitution arrays must not be silently promoted to verified facts without validation and fixture-backed interpretation.

Recommended next consolidated run: `1.15–1.16 Validation and Legacy Interpretation`.

Recommended following work: begin the consolidated Phase 2 execution plan only after Phase 1 validation and mapping complete.

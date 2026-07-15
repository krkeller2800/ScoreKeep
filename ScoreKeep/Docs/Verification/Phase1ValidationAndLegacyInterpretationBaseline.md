# Phase 1 Validation and Legacy Interpretation Baseline

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This note completes implementation-catalog tasks `1.15 Domain validation boundary` and `1.16 Legacy-to-canonical mapping for verification` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The run introduces a non-routed validation authority and a non-routed read-only legacy interpretation authority. It does not change SwiftData models, production persistence, migrations, import/export schemas, scoring, replay, reports, PDFs, UI, purchases, allowances, seed behavior, accessibility behavior, deployment targets, or production routing.

<!-- MARK: - 2. Validation Vocabulary -->
## 2. Validation Vocabulary

`CanonicalDomainValidation.swift` defines validation dispositions for valid, valid-with-warnings, incomplete, repair-recommended, repair-required, unsupported, rejected, contradictory, and unresolved evidence.

Validation results carry deterministic findings with a stable code, concept, severity, summary, optional source location, read-only continuation status, future-write stop status, explicit repair requirement, and unsupported-versus-malformed classification. The vocabulary is diagnostic and testable; it is not production UI wording and is not localized.

<!-- MARK: - 3. Cross-Domain Validation -->
## 3. Cross-Domain Validation

The validation boundary composes Phase 1 canonical classifiers for stable identity, ordering, teams, game sides, players, roster memberships, lineups, batting order, defensive positions, game identity, innings, count, outs, base occupancy, scoring events, pitcher responsibility, and substitutions.

Cross-concept coverage includes duplicate and conflicting identifiers, same reusable team on both game sides, player and roster relationship gaps, mixed-team roster evidence, duplicate lineup participants and slots, unknown lineup modes, impossible base occupancy, invalid outs and innings, missing batters, unsupported result strings, missing or conflicting pitcher evidence, unequal substitution arrays, and same participant incoming and outgoing.

<!-- MARK: - 4. Repair Boundary -->
## 4. Repair Boundary

Validation may report warning, repair-recommended, repair-required, rejected, unsupported, contradictory, or unresolved evidence, but it performs no repair. It never generates replacement identifiers, merges records, reorders events, normalizes unsupported values, changes relationships, writes records, or changes fixtures.

Read-only interpretation may continue for warning, incomplete, unsupported, and unresolved evidence where safe. Future writes or imports must stop for unsupported, unresolved, repair-required, rejected, and contradictory evidence until a later explicit review or repair authority exists.

<!-- MARK: - 5. Legacy Mapping Coverage -->
## 5. Legacy Mapping Coverage

`LegacyCanonicalVerificationMapping.swift` maps SwiftData-style snapshots, current model records, and compatibility transports into canonical evidence for verification. Supported evidence includes teams, players, roster memberships, games, game sides, lineups, at-bats as scoring events, pitcher appearances, and legacy incoming/replaced substitution arrays.

Mapping results preserve canonical value or partial value, validation findings, raw evidence, unsupported raw values, source identity, source location, mapping completeness, relationship-resolution status, comparison continuation status, write/import stop status, and explicit repair requirement.

<!-- MARK: - 6. Fixture Evidence -->
## 6. Fixture Evidence

Focused tests cover representative roster fixtures: `MinimalValid.ScoreKeep_Players`, `CompleteRoster.ScoreKeep_Players`, `MissingOptionalValues.ScoreKeep_Players`, `DuplicatePlayerID.ScoreKeep_Players`, `BrokenTeamRelationship.ScoreKeep_Players`, and `EmptyArray.ScoreKeep_Players`.

Focused tests cover representative game fixtures: `MinimalValid.ScoreKeep_Games`, `CompletedGame.ScoreKeep_Games`, `InProgressGame.ScoreKeep_Games`, `MultipleAtbats.ScoreKeep_Games`, `LineupGame.ScoreKeep_Games`, `PitcherGame.ScoreKeep_Games`, `DuplicateConflict.ScoreKeep_Games`, `DuplicateAtbatID.ScoreKeep_Games`, `BrokenAtbatRelationship.ScoreKeep_Games`, `BrokenLineupRelationship.ScoreKeep_Games`, `BrokenPitcherRelationship.ScoreKeep_Games`, `ConflictingTeamIdentity.ScoreKeep_Games`, and `UnsupportedScoreValue.ScoreKeep_Games`.

Tests compare fixture bytes before and after mapping to confirm that source records and fixtures are not mutated.

<!-- MARK: - 7. Mapping Limitations -->
## 7. Mapping Limitations

The mapper is not a production persistence adapter, import replacement, export replacement, migration engine, repair engine, scoring engine, replay engine, or report source. It does not access the production SwiftData store. It does not claim replay equivalence for stored scores. It preserves stored score evidence without deriving final score authority.

Malformed files that cannot decode remain later Phase 4 decode and review work. Relationship classification is conservative and limited to evidence available in decoded transport and snapshots.

<!-- MARK: - 8. Production Routing Status -->
## 8. Production Routing Status

No production workflow references the new validation or mapping authority. Startup, SwiftData model setup, team and player workflows, roster workflows, lineup workflows, scoring, corrections, pitchers, substitutions, imports, exports, reports, PDFs, seed import, purchases, allowances, navigation, and deep links remain legacy-owned.

The new files contain no SwiftData annotations, no model-container setup, no save calls, no file writes, no import confirmation, no export generation, no StoreKit or Keychain access, no UI, no migration, and no random identifier generation.

<!-- MARK: - 9. Phase 1 Exit Assessment -->
## 9. Phase 1 Exit Assessment

Phase 1 exit criteria are met for non-routed foundations: all canonical concepts from tasks `1.1` through `1.14` can be validated through a common result boundary; legacy and compatibility evidence can be mapped read-only; unsupported and contradictory evidence remain distinguishable; broken relationships are classified rather than repaired; mapping performs no mutation; and no production route uses the new authorities.

Phase 2 can consume canonical validation and mapping evidence without depending directly on live SwiftData behavior. Phase 2 must still define accepted scoring commands, event application, replay, derived state, and correction behavior before any scoring route changes.

<!-- MARK: - 10. Phase 2 Readiness -->
## 10. Phase 2 Readiness

No blocker was found that makes Phase 2 unsafe to begin as non-routed scoring foundation work. Phase 2 must remain read-only or in-memory until its own acceptance gates pass and must not double-write legacy `Atbat`, `Game`, lineup, pitcher, or substitution records.

The exact recommended next consolidated run is `2.1–2.3 Scoring Command and Event Application Foundation`.

<!-- MARK: - 11. Remaining Risks -->
## 11. Remaining Risks

Remaining risks include incomplete decode-failure classification for non-decodable malformed files, limited stored-score reconciliation, no replay-derived score comparison, no authoritative runner transition application, no production import preview, no migration status persistence, and no user-facing repair workflow.

These are Phase 2 through Phase 4 concerns and should not be solved by routing the Phase 1 mapper into production.

<!-- MARK: - 12. Recommended Following Run -->
## 12. Recommended Following Run

After `2.1–2.3 Scoring Command and Event Application Foundation`, the recommended following consolidated run is `2.4–2.8 Count, Outs, Bases, Score, and Inning Transitions`.

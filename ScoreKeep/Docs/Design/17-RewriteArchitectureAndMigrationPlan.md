# ScoreKeep Technical Design — 17 Rewrite Architecture and Migration Plan

## 1. Purpose

This document defines the architecture, migration strategy, and implementation roadmap for rewriting ScoreKeep while maintaining compatibility with the existing application. It is a technical design document. It describes how the rewritten product should be organized, how existing behavior should coexist with replacement behavior, and how replacement work should proceed without putting user-owned baseball records at risk.

The rewrite exists because the current application has accumulated technical debt that makes future change risky. Baseball rules are spread across views, scoring screens, lineup tools, substitution tools, report generation, import code, and export code. Similar calculations are performed in multiple places, and those calculations can drift apart. SwiftUI views currently perform presentation, persistence access, scoring mutation, compatibility decisions, and report-oriented calculations in the same workflows. This coupling makes defects harder to isolate and makes product behavior harder to verify.

The current implementation also carries legacy compatibility concerns. Existing SwiftData records, `.ScoreKeep_Players` files, `.ScoreKeep_Games` files, the seeded game, deep links, document-opening behavior, website roster downloads, purchase state, photos, logos, and historical reports all represent user expectations that must remain understandable. A rewrite that improves internal structure but loses supported records would fail the product.

The rewrite therefore prioritizes preservation of baseball meaning over preservation of existing implementation. Existing code is a compatibility source and behavioral reference, not an architectural target. Preserving user-owned baseball records, supported file formats, and release compatibility is more important than preserving current view structure, current calculation locations, or current persistence access patterns.

## 2. Rewrite Goals

The rewritten architecture should establish a single authoritative baseball model. Teams, players, games, lineups, plate appearances, runner movement, substitutions, pitchers, scores, statistics, and historical participation should have one product meaning that is shared across the application.

The application should have a single scoring engine. Live scoring, corrections, scoreboard state, scorecard output, statistics, reports, PDFs, exports, and reopened games should derive from the same saved baseball facts instead of recalculating separate versions of the game.

Presentation should be independent from calculations. SwiftUI screens should display state, collect choices, navigate, show progress, and present errors. Baseball rules, statistical calculations, compatibility decisions, persistence repair, and report derivation should live outside views.

Compatibility preservation is a primary goal. Existing supported records and exchange formats must remain accessible or intentionally migrated with clear verification. Compatibility is not a cleanup task after the rewrite; it is a release requirement throughout the rewrite.

The rewrite should proceed through incremental replacement. Rewritten components should be introduced beside legacy components, verified against accepted fixtures and regression scenarios, and routed into production only after they satisfy the relevant acceptance evidence.

Maintainability should improve by reducing duplicated logic, clarifying ownership boundaries, and making baseball behavior explainable from authoritative records. A future maintainer should be able to locate the source of a rule, understand its inputs and outputs, and verify the affected workflows without reading multiple unrelated screens.

Testability should improve by moving baseball decisions into components that can be exercised without full UI navigation. The scoring engine, compatibility adapters, import/export behavior, report derivation, and migration behavior should be verifiable from controlled fixtures.

Release safety should remain visible at every step. The production application must remain maintainable while the rewrite is in progress, and each replacement should have an explicit acceptance path before legacy behavior is retired.

## 3. Rewrite Principles

Preserve user data. Teams, players, games, lineups, scoring events, pitcher records, substitutions, photos, logos, reports, preferences, and purchase-related state are user-owned product data.

Preserve compatibility. Existing local records, `.ScoreKeep_Players`, `.ScoreKeep_Games`, deep links, document types, the seeded game, website roster downloads, and established user workflows must remain release requirements unless a later specification deliberately changes them.

Never rewrite history silently. Historical games and participation records should not change meaning because a current roster changed, a player was edited, a report was regenerated, or a compatibility adapter repaired an old record. Repairs and migrations should be intentional, reviewable where practical, and verified.

Use one source of baseball truth. Saved baseball facts should be the authority for scores, statistics, scorecards, reports, PDFs, exports, and correction results.

Do not duplicate calculations. If two screens need the same baseball answer, they should receive it from the same domain or application service rather than repeating the calculation.

The user interface should display state rather than calculate it. Views may format and arrange data for the screen, but they should not own scoring rules, pitcher attribution, lineup history, statistics, or compatibility repair.

Business rules belong outside SwiftUI views. SwiftUI should remain responsible for interaction and presentation, while scoring, validation, import/export decisions, purchase gating decisions, and data integrity checks are performed by testable application and domain components.

Reports and PDFs should derive from the same authoritative model as the rest of the app. A report should not contain a separate interpretation of a game that can disagree with live scoring or score summaries.

Prefer incremental replacement over a big-bang rewrite. The safest rewrite is one that allows existing workflows to remain operational while one bounded feature at a time is replaced, verified, released, and cleaned up.

## 4. Overall Architecture

The desired architecture separates product responsibilities into conceptual layers. These layers describe ownership and dependency direction. They do not require a specific folder structure, database implementation, or type design.

Presentation contains SwiftUI views, navigation, forms, lists, scoring controls, report screens, import review screens, purchase prompts, settings screens, and error presentation. Presentation displays prepared state and collects user intent. It should not be the authority for baseball rules or persisted record structure.

View Models prepare presentation state and translate user intent into application actions. They should coordinate loading states, validation messages, selection state, navigation readiness, and screen-specific formatting. They should not duplicate scoring calculations or directly encode compatibility formats.

Application Services coordinate workflows that cross domain boundaries. Examples include creating a game, preparing a lineup, recording a play, correcting a play, importing a file, exporting a game, generating a report, checking purchase-gated access, and migrating compatible records. Services define transaction boundaries and failure behavior in product terms.

The Scoring Engine is the authoritative baseball calculation layer. It interprets saved baseball facts, applies scoring rules, advances game state, validates corrections, derives scoreboard state, attributes pitcher responsibility, and produces reportable statistical state.

The Domain Model represents baseball concepts independent of screens. It should express games, teams, players, lineup participation, plate appearances, runners, outs, innings, pitcher appearances, substitutions, scoring events, corrections, and derived statistics in a way that can be reasoned about consistently.

Persistence stores and retrieves records. It preserves existing user data while allowing internal redesign. Persistence should expose product records and migration outcomes to the rest of the app without forcing SwiftUI views to know storage details.

Compatibility translates between legacy representations and the authoritative domain. It protects `.ScoreKeep_Players`, `.ScoreKeep_Games`, seeded game records, deep links, document-open behavior, website roster content, and older saved data from accidental reinterpretation.

Import/Export handles reviewable file exchange. It should decode, validate, report conflicts, preserve supported meaning, reject unsafe records, and produce compatible output from the authoritative model.

Reports derive on-screen reports, scorecards, PDFs, box scores, batting reports, pitching reports, and export summaries from the same authoritative game state used by live scoring and statistics.

A simplified conceptual dependency direction is:

```text
Presentation
View Models
Application Services
Scoring Engine + Domain Model
Persistence + Compatibility + Import/Export + Reports
```

This diagram is illustrative. The important design requirement is that baseball truth is not owned by views and is not recalculated independently by each output.

## 5. Legacy Coexistence Strategy

Legacy code and rewritten code should coexist during the migration. Existing views remain operational until their replacement workflows have passed the relevant acceptance checks. This keeps production behavior available while the replacement is still being proven.

New views and services should be built beside legacy views. They should use controlled routing, explicit feature boundaries, and fixture-backed verification before replacing existing entry points. Routing changes should occur only after the replacement behavior has been checked against the functional specifications, acceptance fixtures, regression catalog, and compatibility expectations.

Legacy code should be retired only after the replacement passes acceptance for the same workflow and affected adjacent workflows. For example, replacing live scoring requires more than checking a scoring screen. It also requires checking saved game state, correction behavior, reports, PDFs, exports, reopened games, and compatibility with old records.

This coexistence strategy minimizes release risk because it avoids forcing every rewritten component to be ready at the same time. Production can continue to receive fixes, compatibility work can remain visible, and each replacement can be evaluated against concrete product behavior before users depend on it.

## 6. Incremental Migration Strategy

The application should be replaced feature-by-feature where feature boundaries better match baseball behavior than screen boundaries. A screen-by-screen rewrite can leave the same baseball rule split between old and new code. A feature-oriented migration should identify the product behavior being replaced, the records it owns, the workflows it touches, and the acceptance evidence required before routing changes.

Migration phases should begin with inventory and fixture definition. The current-state inventory identifies existing behavior and known risks. Acceptance fixtures define representative records, expected results, malformed inputs, compatibility files, and regression cases. Each replacement should begin from those references rather than from visual parity alone.

Team management should be migrated without destabilizing game history. Current roster edits, team details, logos, sorting, deletion rules, duplicate handling, and historical participation must be separated so that editing a current team does not silently rewrite past games.

Player management should preserve identity, roster membership, photos, batting information, and historical participation. Duplicate names and duplicate numbers should be handled as compatibility and identity problems rather than simple list problems.

Game setup should be migrated around draft state, team selection, inning configuration, lineup readiness, pitcher readiness, purchase gating where applicable, and safe transition into scoring. Incomplete setup should not create misleading playable records.

Live scoring should be migrated around the scoring engine. Plate appearances, runner movement, outs, innings, batting order, score changes, pitcher attribution, substitutions, corrections, and resume behavior should be verified as one baseball feature even if multiple screens present the workflow.

Reports should be migrated after authoritative derived state is available. Score summaries, box scores, batting reports, pitching reports, scorecards, PDFs, and historical reports should use the same scoring engine outputs or report derivation services.

Imports should be migrated around compatibility review and safe record creation. Roster imports, game imports, malformed files, duplicate records, missing references, unsupported values, media, and security-scoped document behavior should be tested without changing unrelated local data.

Exports should be migrated around round-trip baseball meaning. Exported files should preserve supported identities, teams, players, lineups, substitutions, pitcher records, scoring events, media, and reportable totals as defined by compatibility specifications.

Purchases should be migrated without coupling entitlement uncertainty to data ownership. Purchase status may gate selected actions, but it must not delete, rewrite, hide, or corrupt existing baseball records.

Settings should be migrated as product preferences, not baseball records. Preference changes should not alter historical baseball meaning, import/export compatibility, purchase ownership, or saved scoring state except where a specification explicitly defines presentation-only effects.

## 7. Domain Layer

The domain layer represents baseball meaning independently from SwiftUI and storage details. It should define the concepts and relationships needed to understand a ScoreKeep baseball record over time.

Baseball rules belong in the domain and scoring engine, not in views. Scoring decisions, lineup history, substitutions, pitcher attribution, runner movement, outs, innings, batting order progression, statistics, corrections, and historical identity should be expressed as domain behavior or domain state.

The domain layer should distinguish current roster information from historical participation. A player in a completed game should remain understandable even if the current roster changes later. A substitution should preserve who left, who entered, when the change occurred, and how later plate appearances should be interpreted.

The domain layer should also distinguish recorded facts from derived results. A saved scoring event is a fact. A score, line score, batting total, pitcher line, and report row are derived from facts. This distinction allows corrections to update derived results consistently without rewriting unrelated history.

## 8. Scoring Engine

The scoring engine is the authoritative interpreter of saved baseball facts. It should accept a game record and produce coherent baseball state: score, inning, half inning, outs, base occupancy, current batter, next batter, current pitcher, lineup context, substitutions, event sequence, statistics, and reportable summaries.

Every presentation should derive from the same saved baseball facts. Live scoring, scoreboard display, reports, PDF output, statistics, exports, corrections, and scorecard presentation should not each invent their own interpretation of the game.

The scoring engine should become the source for live scoring, scoreboard state, reports, PDFs, statistics, exports, corrections, and scorecards. When a play is recorded or corrected, the engine should produce the updated state or a clear validation failure. When a report is generated, it should use the same interpreted state that the scoring screen and game list use.

The engine should make impossible or unsupported states visible. Duplicate base occupancy, fourth-out states, missing required participants, ambiguous pitcher attribution, unsupported result strings, inconsistent substitution history, and scoring records that cannot be safely interpreted should produce explicit validation, repair, warning, or rejection outcomes rather than silent reinterpretation.

## 9. Presentation Layer

The rewritten presentation layer should use modern SwiftUI to present product workflows clearly while leaving baseball authority outside views. Views should be responsible for display, input, navigation, progress, and errors.

Views should display prepared state such as team lists, player lists, game summaries, scoring state, lineup choices, report previews, import conflicts, purchase status, settings, and recovery messages. They may format values for readability, but they should not decide how runs, outs, pitcher records, substitutions, or statistics are calculated.

Views should collect user input and pass intent to view models or application services. Examples include creating a team, editing a player, selecting lineups, recording a scoring result, changing a pitcher, correcting a play, choosing an import conflict resolution, exporting a file, or starting a purchase.

Views should navigate between workflows, show pending work, present errors, and keep the user oriented. They should avoid direct persistence logic, file-format decisions, compatibility repair, and baseball calculations.

A presentation bug should not be able to corrupt baseball truth. If a view is replaced, restyled, or split for iPhone and iPad, the underlying scoring state, report output, import behavior, and exported meaning should remain unchanged.

## 10. Persistence Strategy

Persistence must preserve existing SwiftData records while allowing internal redesign. The rewrite should not assume that a cleaner internal structure permits existing records to be discarded or silently reinterpreted.

Migration philosophy should be conservative. Existing records should remain readable before any destructive transformation occurs. Where migration is required, it should be deliberate, version-aware where practical, and verified against canonical fixtures and historical records. If a record cannot be migrated safely, the product should preserve what can be preserved and explain the unsupported condition instead of pretending the record is complete.

The architecture should separate persisted storage shape from domain meaning. The domain model may become more explicit than the legacy storage model, but compatibility adapters and persistence services should bridge old records into authoritative baseball state. The rest of the app should not depend on legacy storage quirks as the source of baseball truth.

This document does not specify a database implementation, schema versioning mechanism, migration API, or storage technology. Those choices belong in a dedicated persistence design. The requirement here is that persistence redesign must not break supported records, import/export compatibility, seeded data, media, or release verification.

## 11. Compatibility Strategy

Compatibility remains a release requirement throughout the rewrite. The rewritten app must preserve compatibility with `.ScoreKeep_Players`, `.ScoreKeep_Games`, deep links, existing reports where supported, the existing seeded game, the website roster manifest, and existing users.

`.ScoreKeep_Players` compatibility should preserve supported roster meaning, including teams, players, roster fields, batting information, photos, logos where represented, duplicate handling, malformed-file handling, and round-trip expectations.

`.ScoreKeep_Games` compatibility should preserve supported game meaning, including teams, players, date, location, inning configuration, lineups, at-bats, pitcher records, substitutions, scoring results, media references, and reportable totals.

Deep links and document-opening behavior should continue to route users to understandable workflows. If a link or file cannot be handled safely, the app should explain the limitation and avoid modifying unrelated records.

Existing reports and PDFs define visible expectations that should be reconciled with the authoritative scoring engine. The rewrite should eliminate inconsistent report calculations while preserving supported user-visible meaning.

The existing seeded game should remain a canonical compatibility fixture. It should continue to import, display, score/report where applicable, and demonstrate first-launch behavior according to the current product requirements.

The website roster manifest and downloadable roster files should remain compatible. Because remote content can change, release verification should use pinned fixtures where practical while preserving the live contract.

Existing users are the most important compatibility target. Their local records, historical games, imported files, exported files, photos, logos, preferences, and purchase-related expectations must be protected through verification, migration planning, and safe fallback behavior.

## 12. Verification Integration

The acceptance fixtures, regression catalog, functional specifications, current-state inventory, and baseline verification should drive development. They define what the rewritten system must preserve, what risks must be retired, and what evidence is required before replacement.

Rewritten components should replace legacy components only after verification. Verification should include the direct feature being replaced and the downstream outputs that depend on it. A scoring replacement must verify reports and exports. An import replacement must verify local records and round trips. A persistence replacement must verify existing records, fixtures, seeded data, media, and failure behavior.

Acceptance evidence should be specific. Expected scores, innings, outs, runners, lineups, pitcher records, substitutions, reports, exported fields, warnings, conflict decisions, and recovery outcomes should be documented before a component is accepted.

Regression scenarios should remain active after a defect is fixed. A rewritten component that fixes one duplicated calculation should not be allowed to reintroduce it through a new presentation path or report path.

## 13. Development Workflow

A recommended development flow is design, fixture, implementation, verification, replacement, and cleanup.

Design defines the product behavior, architectural boundary, compatibility obligations, and affected workflows. It should identify which existing documents are authoritative for the work and which unresolved questions must be answered before release.

Fixture work creates or adopts controlled records, malformed inputs, expected outputs, and regression cases. Fixtures should exist before implementation is considered accepted, especially for scoring, import/export, persistence, reports, and compatibility work.

Implementation builds the replacement behind a bounded product entry point. It should use the new architecture boundaries and avoid moving unrelated legacy code unless required for the feature.

Verification compares the replacement against expected product behavior. It should include fixture checks, regression scenarios, compatibility files, report agreement, failure behavior, and any affected adjacent workflow.

Replacement changes routing or production entry points only after verification. The legacy path should remain available until the replacement is accepted for the release scope.

Cleanup removes obsolete code, duplicated calculations, compatibility shims, or dead views only after equivalent behavior has been verified. Cleanup should not be mixed with unverified behavior changes when that increases release risk.

This workflow does not prescribe a detailed Git process. The important requirement is incremental, reviewable development with acceptance evidence attached to each replacement.

## 14. Technical Debt Retirement

The rewrite should identify and retire duplicated baseball logic, obsolete code, fixed-size assumptions, force unwraps, duplicated calculations, inconsistent report generation, fragile identity matching, view-local persistence decisions, and compatibility behavior that silently loses meaning.

Debt should be retired only after equivalent or intentionally improved behavior is verified. A duplicated report calculation can be removed after the authoritative report path produces accepted results. A legacy import path can be retired after the replacement accepts, warns, repairs, or rejects canonical fixtures as specified. A fixed-size assumption can be removed after large-lineup and extra-inning fixtures pass.

Force unwraps and unsafe assumptions should be replaced by explicit validation, repair, warning, or rejection outcomes. The product should preserve prior state when an operation cannot complete safely.

Obsolete code should not remain as a hidden second implementation of baseball truth. Once a replacement is accepted and routed, legacy logic should be removed or isolated as compatibility-only code so future changes do not accidentally update one path while leaving another path stale.

## 15. Release Strategy

Releases should continue during the rewrite. The existing production branch remains maintainable, and user-impacting fixes should not be blocked by the long-running architecture effort.

Rewritten features should enter production incrementally after acceptance. Each release should state which rewritten workflows are active, which legacy workflows remain, and which compatibility expectations were verified for the changed area.

A release should not depend on unfinished rewrite scope. If live scoring has not been accepted, legacy scoring remains the production path. If reports have not been accepted, legacy reports remain the production path. If persistence redesign has not been accepted for existing records, existing record access must remain protected.

This document does not define CI/CD, deployment automation, branch policy, or App Store release mechanics. It defines the architectural release rule: replacement is allowed only when the affected product behavior has verified compatibility, data preservation, and user-visible correctness.

## 16. Documentation Synchronization

Architecture, functional specifications, verification documents, compatibility expectations, and implementation notes should remain synchronized as the rewrite progresses.

When a design decision changes baseball meaning, compatibility behavior, fixture expectations, report output, import/export handling, persistence migration, or release acceptance, the related documents should be updated in the same product context. Documentation should not describe a safer architecture than the one being implemented, and implementation should not quietly change behavior that the specifications still require.

The current-state inventory should remain a reference for legacy behavior until the related legacy component is retired. Functional specifications should define product requirements. Verification documents should define acceptance evidence. Design documents should define architecture and migration decisions. Implementation should conform to all of them or record the approved change.

Documentation synchronization is part of release safety. It prevents knowledge drift during a long-running rewrite and gives future maintainers a clear path from requirement to architecture to verification evidence.

## 17. Risks

Partial migration can leave baseball behavior split between old and new paths. If the same game is interpreted differently depending on screen, report, export, or correction path, the rewrite has duplicated the original problem.

Mixed legacy and new behavior can confuse users and maintainers. Routing must be deliberate, and shared records must not be mutated by incompatible assumptions.

Compatibility regressions can make supported records unreadable, misreported, merged incorrectly, or silently changed. `.ScoreKeep_Players`, `.ScoreKeep_Games`, seeded data, deep links, website rosters, media, and existing local records require fixture-backed verification.

Duplicate logic can reappear if replacement screens calculate their own summaries before the domain and scoring engine are complete. Temporary presentation calculations should not become permanent authorities.

Historical data is fragile because current edits can accidentally change past meaning. Team, player, lineup, substitution, and pitcher identity must be handled explicitly.

A long-running rewrite can become a second application inside the first. The coexistence plan should include retirement points so accepted replacements actually replace legacy behavior.

Knowledge drift can occur when architecture, specifications, fixtures, and implementation move at different speeds. Documentation synchronization and acceptance evidence are required to keep decisions visible.

## 18. Success Criteria

The rewrite is architecturally successful when ScoreKeep has a single baseball truth for saved games, scoring state, reports, PDFs, exports, statistics, corrections, and scorecards.

The codebase should show clear separation of concerns. SwiftUI views display state and collect intent. Application services coordinate workflows. The scoring engine and domain model own baseball rules. Persistence and compatibility protect records without leaking storage details into every screen.

Compatibility should be stable. Existing local records, `.ScoreKeep_Players`, `.ScoreKeep_Games`, seeded data, deep links, website roster downloads, media, and established user workflows should remain supported according to release specifications.

The scoring engine should be testable from fixtures. Representative games, corrections, substitutions, pitcher changes, imports, exports, reports, and malformed records should produce repeatable acceptance evidence.

Presentation should be independently replaceable. iPhone, iPad, report, import, and scoring screens should be able to evolve without changing baseball meaning.

Releases should remain incremental. Users should receive accepted improvements without waiting for the entire rewrite, and legacy behavior should be retired only after replacement evidence exists.

The resulting codebase should be maintainable. Future changes should have obvious ownership, limited blast radius, shared calculations, and clear verification paths.

## 19. Future Design Documents

Likely follow-on design documents include:

- Canonical Domain Model: defines authoritative baseball entities, identity, history, recorded facts, derived state, and compatibility mapping.
- Scoring Engine Design: defines scoring inputs, outputs, validation, correction behavior, runner state, pitcher attribution, lineup progression, and report derivation.
- Persistence Design: defines storage strategy, migration policy, existing SwiftData preservation, versioning approach, repair behavior, and failure recovery.
- Import/Export Design: defines `.ScoreKeep_Players`, `.ScoreKeep_Games`, website roster compatibility, conflict review, malformed-file handling, round-trip expectations, and future-format tolerance.
- Scorecard Presentation Design: defines how authoritative game state becomes live scorecard display, correction UI, printed/PDF scorecards, and accessible presentation.
- Implementation Roadmap: defines migration order, acceptance gates, fixture dependencies, replacement routing, cleanup sequence, and release checkpoints.

The recommended next document is Canonical Domain Model. The domain model is the foundation for the scoring engine, persistence migration, import/export compatibility, and report consistency. Without an agreed canonical model, later design documents risk recreating duplicated baseball truth under new names.

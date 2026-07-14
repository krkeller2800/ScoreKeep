# ScoreKeep Technical Design — 27 Verification, Fixture, and Release Acceptance Design

<!-- MARK: - 1. Purpose -->
## 1. Purpose

Verification, fixtures, and release acceptance need a dedicated design because ScoreKeep's rewrite changes internal architecture while preserving user-owned baseball records, scoring meaning, legacy compatibility, purchase honesty, accessibility, and release trust. Verification is not a side effect of implementation. It is a product and architectural responsibility that proves the rewritten application still behaves correctly at observable boundaries.

Documents 17 through 26 define the approved architectural direction for canonical baseball meaning, scoring replay, persistence, compatibility, presentation, application services, generated output, purchases, allowances, and accessibility. Those documents, together with the completed functional specifications and approved fixture catalog, define expected behavior. Legacy code, current tests, StoreKit configuration, seeded files, generated output, and current app behavior are evidence and regression inputs. They do not automatically become the architecture to reproduce.

This design defines how ScoreKeep verifies behavior without making tests the owners of product meaning. It describes evidence, responsibilities, scenario structure, fixture ownership, release acceptance, blockers, risks, and unresolved questions. It does not prescribe a concrete test framework, test target layout, Swift type hierarchy, fixture schema, CI provider, source-file organization, implementation plan, baseball rule expansion, persistence schema, product identifier, URL, analytics system, or release role.

<!-- MARK: - 2. Repository Evidence and Scope -->
## 2. Repository Evidence and Scope

The tracked design-document path is `ScoreKeep/Docs/Design`. Existing sibling documents use filenames such as `25-PurchaseEntitlementAndAllowanceDesign.md` and `26-AccessibilityAndInclusiveInteractionDesign.md`, so this document belongs beside them as `27-VerificationFixtureAndReleaseAcceptanceDesign.md`.

Confirmed repository evidence includes placeholder automated tests in `ScoreKeepTests/ScoreKeepTests.swift`, basic UI launch and launch-performance tests in `ScoreKeepUITests`, a shared scheme at `ScoreKeep.xcodeproj/xcshareddata/xcschemes/ScoreKeep.xcscheme`, a StoreKit configuration at `ScoreKeep.storekit`, one checked-in game fixture at `ScoreKeep/Seed/seededGame.ScoreKeep_Games`, no checked-in `.ScoreKeep_Players` fixture found during inspection, a bundled manual at `ScoreKeep/Reporting/Manual.pdf`, URL and compatibility documentation, and an acceptance fixture catalog in `ScoreKeep/Docs/Verification/16-AcceptanceFixturesAndRegressionScenarios.md`.

Current repository evidence also includes compatibility extensions and UTIs in `Info.plist` and `Common/Extensions.swift`, source export paths for `.ScoreKeep_Players` and `.ScoreKeep_Games`, MLB roster and announcement endpoints at `https://komakode.com/Teams/index.json` and `https://komakode.com/Teams/message.json`, seasonal StoreKit products `com.komakode.ScoreKeep.SeasonPass2025` and `com.komakode.ScoreKeep.SeasonPass2026`, Keychain-backed free counters named `freeGameCreatesRemainingKC` and `mlbDownloadCountKC`, SwiftData persistence evidence, generated report and PDF paths, screenshot and share workflows, debug-only free-counter reset evidence, and limited explicit accessibility labels. These facts are evidence for verification needs, not future implementation requirements unless the design documents make them product contracts.

<!-- MARK: - 3. Architectural Position -->
## 3. Architectural Position

Design documents and approved product specifications define expected behavior. Repository evidence establishes current behavior, compatibility obligations, regression risks, and fixture inputs. Legacy code is evidence, not automatically the expected implementation. A current view, model property, file layout, counter key, or calculation path should be preserved only when it represents an approved product contract or compatibility obligation.

Fixtures describe meaningful scenarios and expected observable outcomes. Tests verify product boundaries but do not redefine baseball rules, product policy, purchase policy, accessibility obligations, or compatibility meaning. A test may expose a failure; it cannot make an incorrect score acceptable or make an unsupported purchase gate valid.

Canonical data, scoring results, replay results, persistence results, compatibility results, presentation projections, generated output, purchases, allowances, and accessibility outcomes require verification at their proper architectural boundaries. One passing UI path cannot substitute for domain, persistence, compatibility, or application-service evidence. Snapshot or visual verification cannot substitute for semantic correctness. Unit tests alone cannot prove end-to-end workflow preservation, and manual testing alone cannot provide deterministic regression protection.

<!-- MARK: - 4. Verification Principles -->
## 4. Verification Principles

Behavior comes before implementation. Each verification scenario starts from a product requirement, design source, compatibility obligation, known regression, or approved fixture purpose before it chooses any technical mechanism. The same expected baseball result should survive changes to storage, presentation, source files, view hierarchy, and calculation internals.

Evidence must be deterministic enough to support release decisions. Scenarios require stable identity, explicit initial state, explicit user intent, explicit expected result, separation of source facts from derived projections, independent verification at architectural boundaries, repeatability, idempotency, failure preservation, and privacy-conscious diagnostics.

Fixture drift is not silent. Expected results change only when an approved product or compatibility decision changes. Verification must not add test-only product behavior, production dependence on fixtures, debug-only resets in release behavior, or hidden shortcuts that make tests pass while users receive different outcomes. Nondeterministic external services are treated honestly: a live service check may prove availability at a moment in time, but it cannot be the sole proof of import, purchase, or scoring correctness.

Verifying an outcome is different from freezing an implementation. A scenario may require that a corrected game produce a specific score, inning, out count, runner state, batting statistic, pitching statistic, compatibility export, and accessible status. It should not require a particular Swift function, storage table, view structure, task ordering, or object identity unless that detail is itself a compatibility or product contract.

<!-- MARK: - 5. Responsibility Boundaries -->
## 5. Responsibility Boundaries

The canonical domain owns baseball identity and meaning: teams, players, rosters, lineups, game identity, game status, inning, half-inning, outs, count where represented, base occupancy, runs, hits, errors where supported, plate appearances, scoring events, pitcher responsibility, substitutions, and final or in-progress state. Domain verification proves those meanings independent from SwiftUI presentation.

The scoring engine owns calculation, replay, correction, deterministic progression, invalid transition rejection, downstream recomputation, batter and pitcher statistics, and replay-derived projections. Persistence and migration own durable round trips, identity, relationships, ordering, recovery, schema change, media references, and separation from purchase state. Compatibility codecs own decoding, encoding, warning, malformed input handling, legacy field preservation, and round-trip meaning for `.ScoreKeep_Players` and `.ScoreKeep_Games`.

Application services own user intent, workflow transaction boundaries, validation coordination, idempotency, interruption, retry, purchase-gated action preservation, and no-duplicate side effects. Presentation owns prepared state, visible status, enabled and disabled actions, error and pending states, import conflicts, correction effects, purchase and allowance display, and device adaptation without owning business rules. Generated-output services own derived reports, PDFs, scorecards, summaries, reading order, pagination, and output failure behavior. Purchase, entitlement, and allowance services own product discovery, entitlement classification, seasonal policy, allowance state, and purchase honesty without owning baseball data.

Network roster acquisition owns manifest loading, roster download classification, timeout and offline behavior, stale response handling, and routing into import review. Accessibility owns equivalent workflow access, semantic labels and values, focus, announcements, keyboard and alternate input, color-independent meaning, and large-text reflow without alternate baseball logic. Platform infrastructure owns build, configuration, StoreKit test infrastructure, device context, local files, lifecycle, and controlled environment state. Release coordination owns traceable evidence and known-risk classification without inventing organizational sign-off roles.

<!-- MARK: - 6. Verification Taxonomy -->
## 6. Verification Taxonomy

Domain rule verification proves canonical baseball meaning from explicit states and commands. It does not prove persistence, UI navigation, or export compatibility. Scoring calculation verification proves representative and boundary results for supported scoring choices. Replay and correction verification proves that event streams can be recalculated after approved edits and that invalid corrections are rejected.

Persistence round-trip verification proves that saved records reload with identity, relationships, ordering, media references, optional fields, and derived-source separation intact. Migration verification proves that existing installed-app data and legacy storage can move or coexist without data loss, fabrication, or purchase-state mutation. Compatibility fixture verification proves known `.ScoreKeep_Players` and `.ScoreKeep_Games` behavior, malformed input safety, export compatibility, and round-trip meaning.

Import review verification proves file selection, decode, validation, conflict review, confirmation, cancellation, retry, and existing-record protection. Export verification proves source scope, validation, encoding, destination handoff, failure, cancellation, retry, and privacy-conscious output. Application-service workflow verification proves complete user workflows such as create team, edit player, build roster, set lineup, create game, score game, correct game, substitute player, finish game, reopen game, import, export, download MLB roster, generate reports, purchase access, restore access, and continue with free allowance.

Presentation-state verification proves prepared user-facing state without making SwiftUI the business-rule owner. Accessibility workflow verification proves equivalent workflows through assistive settings and alternate input. Generated-output verification proves statistical correctness, scope, reading order, page content, long names, empty data, sharing, saving, failure, and cancellation. Purchase and allowance policy verification proves product, entitlement, restore, offline, allowance, duplicate, and failure outcomes. Offline, interruption and resume, device-class, manual exploratory, and release acceptance verification each prove the product boundaries that narrower checks cannot prove by themselves.

<!-- MARK: - 7. Scenario Model -->
## 7. Scenario Model

A verification scenario is a reviewed description of an initial state, requested intent, expected result, and evidence boundary. It identifies the scenario purpose, requirement or design source, initial canonical baseball state, initial persistence state, initial entitlement and allowance state, external service state, requested user intent or command, interaction method, device-class context, and whether retry or repetition should be idempotent.

Expected results identify the canonical result, derived projections, persistence changes, compatibility output, visible state, accessibility state, purchase or allowance effect, diagnostics, and records or state that must remain unchanged. The unchanged-record assertion is essential: many ScoreKeep failures are not only wrong outputs, but unintended mutation of teams, players, games, imports, exports, purchases, allowances, media, or unrelated records.

The scenario model is conceptual. This design does not invent a serialized schema, file naming convention, directory layout, or fixture-storage format. Those choices remain implementation and fixture-data decisions that must preserve the scenario meaning defined here.

<!-- MARK: - 8. Fixture Architecture -->
## 8. Fixture Architecture

Fixtures are stable, reviewed evidence representing meaningful product states. They should be minimal enough to understand and complete enough to exercise the requirement. A fixture may represent teams, players, rosters, lineups, games, plate appearances, pitching appearances, substitutions, corrections, completed games, incomplete games, imported legacy files, malformed files, conflict cases, purchase states, allowance states, offline states, accessibility states, or generated-output expectations.

Source fixtures preserve facts that the product must interpret. Expected-output fixtures preserve outcomes that should be observed after applying approved behavior. Generated expected results may be useful, but generated output from the same code being verified is not independent proof. Where practical, expected baseball meaning should be authored or reviewed independently from the implementation that produces it.

Repository evidence establishes one checked-in `.ScoreKeep_Games` seed and no checked-in `.ScoreKeep_Players` fixture found during inspection. Therefore the rewrite needs curated roster, malformed, historical, import, export, accessibility, purchase, offline, and expected-output fixtures before release, but this document does not create those files or choose their storage format.

<!-- MARK: - 9. Fixture Ownership and Review -->
## 9. Fixture Ownership and Review

Fixture meaning is owned by the architectural area whose behavior the fixture represents. Baseball fixtures are owned by domain and scoring meaning. Compatibility fixtures are owned by import/export compatibility. Purchase and allowance fixtures are owned by product access policy. Accessibility fixtures are owned by inclusive interaction requirements. Release fixtures are owned by release acceptance criteria. These are responsibility categories, not employee titles.

Each fixture should link to a requirement, design document, compatibility obligation, repository evidence item, known regression, or unresolved question. Intentional behavior changes update expected outcomes with an explanation of the product decision. Accidental fixture rewrites are detected by reviewing changed source facts, changed expected results, and changed generated evidence separately.

Production behavior must not be changed merely to satisfy an incorrect fixture. If a fixture asserts a wrong baseball result, unsafe import, misleading export, false entitlement, or inaccessible workflow, the fixture is corrected through review. The implementation should not encode fixture mistakes as product policy.

<!-- MARK: - 10. Golden and Expected-Output Evidence -->
## 10. Golden and Expected-Output Evidence

Golden evidence may be appropriate for compatible exported files, generated reports, PDFs, scorecards, statistical summaries, prepared presentation state, and user-visible messages where wording is contractually important. The evidence must state whether byte identity, semantic identity, compatibility identity, visual identity, or wording identity is required.

Byte-for-byte comparison is fragile when output contains timestamps, identifiers, locale-sensitive formatting, sort-order assumptions, fonts, page layout, operating-system rendering, metadata, or PDF generator differences. Semantic comparison is more appropriate when the product requirement is that totals, roster membership, lineups, scoring events, reading order, warnings, or compatibility fields remain equivalent.

Visual snapshots can catch layout regressions, clipping, missing content, and device differences, but they cannot prove score correctness, import safety, purchase honesty, or accessibility equivalence. Generated reports and PDFs should be verified for source-record scope, statistical correctness, headings, repeated headers, long names, empty data, pagination, sharing, saving, failure, cancellation, high contrast, and color-independent meaning before any visual golden is treated as release evidence.

<!-- MARK: - 11. Canonical Baseball Verification -->
## 11. Canonical Baseball Verification

Canonical baseball verification proves that ScoreKeep represents baseball facts consistently before presentation. Required meanings include team and player identity, roster membership, batting order, defensive positions, game identity, game status, inning, half-inning, outs, balls and strikes where represented, base occupancy, runs, hits and errors where supported, plate appearances, scoring events, pitcher responsibility, substitutions, and final or in-progress state.

The same accepted scenario should produce equivalent baseball results across supported device classes and interaction methods. A user scoring through touch, VoiceOver, keyboard, pointer, or another supported input path must not receive different validation or different baseball results from the same state and intent.

Verification must not invent new baseball rules. Where existing design documents or current specifications do not establish a scoring category, earned-run treatment, substitution rule, or game-status rule, the scenario records the gap as an unresolved product question rather than silently expanding the product.

<!-- MARK: - 12. Scoring Calculation Verification -->
## 12. Scoring Calculation Verification

Scoring calculation verification covers supported outcomes such as singles, doubles, triples, home runs, walks and other existing supported batter outcomes, outs, strikeouts, runner advancement, runs scored, inning transitions, third-out behavior, score changes, batter statistics, pitcher statistics, and existing supported scoring choices. Earned or unearned treatment is verified only where current specifications establish it.

Boundary scenarios include bases empty, every occupied-base combination, forced and optional advancement, runner put out, batter out at a base, multiple runs, no run on a third out where applicable, inning transition after the third out, extra-inning state where supported, invalid duplicate occupancy, impossible outs, duplicate command prevention, and deterministic replay.

Repository evidence and the fixture catalog identify historical risks such as fixed-size scoring assumptions, substitution indexing, stored score mismatch, duplicate scoring records, sacrifice spelling mismatch, and pitching calculation differences. These risks require regression scenarios expressed as product outcomes, not preservation of the legacy implementation that caused the risk.

<!-- MARK: - 13. Replay and Correction Verification -->
## 13. Replay and Correction Verification

Replay verification proves that a complete event stream can regenerate the accepted game state. Correction verification proves that an approved early-event edit, deletion, or replacement recalculates downstream score, inning, outs, count, base occupancy, batter statistics, pitcher statistics, substitutions, reports, scorecards, and presentation projections.

Scenarios must include valid correction, invalid correction rejection, canceled correction, interrupted correction, repeated idempotent correction request, event identity preservation where required, presentation refresh after replay, and accessibility focus and explanation after correction. If a correction has cascading effects, the user-facing expected result must distinguish source facts changed by the correction from derived projections regenerated by replay.

The correction path must preserve the last confirmed state when a correction is canceled or interrupted. It must not double-apply side effects, strand focus, consume allowances, mutate purchase state, or make unrelated records inconsistent.

<!-- MARK: - 14. Persistence Verification -->
## 14. Persistence Verification

Persistence verification proves successful save, failed save, partial or interrupted save, fetch and reload, application restart, background and foreground transitions, record identity, relationship integrity, ordering, optional and missing values, media references, photos, logos, deletion, repair, corrupted or unreadable persisted state, and schema migration behavior.

Persistence outcomes must show whether the baseball record changed, whether a prior usable state remains available, and whether the app can determine the last confirmed state. A failed save must not be reported as success. A partial write must not appear as coherent baseball truth unless an approved recovery policy says how it is completed or repaired.

Purchase and allowance state remain separate from baseball persistence. A baseball save failure must not consume an allowance when policy requires successful persistence first, and baseball persistence operations must not mutate entitlement or purchase state.

<!-- MARK: - 15. Migration Verification -->
## 15. Migration Verification

Migration verification covers existing installed-app data, legacy persistence models, new persistence models when later approved, incremental migration, repeated migration, interrupted migration, failed migration, recovery or rollback expectations, missing optional fields, unknown legacy values, duplicate identities, photos, logos, existing preferences, and purchase and allowance state kept separate from baseball data.

The rewrite must require preservation evidence before legacy storage is retired. Existing records cannot be declared migrated merely because a new schema exists. Verification must prove that supported teams, players, rosters, games, lineups, scoring events, substitutions, pitcher records, media references, preferences, and compatibility evidence remain understandable after upgrade.

Migration must not fabricate records, fabricate entitlement, reset allowances, hide existing data, or convert uncertainty into definitive loss. Repeated migration should be idempotent: running the same approved migration path again must not duplicate games, players, media, purchase access, or allowance consumption.

<!-- MARK: - 16. Compatibility Verification -->
## 16. Compatibility Verification

Compatibility verification applies the boundaries established by Documents 20 and 21. It covers decoding known `.ScoreKeep_Players` fixtures, decoding known `.ScoreKeep_Games` fixtures, encoding compatible roster files, encoding compatible game files, round-trip behavior, optional or missing legacy fields, unknown values, team and player relationships, photos, logos, ordering, IDs, malformed input, unsupported input, user cancellation, conflict review, and source-data ownership.

The repository currently contains `seededGame.ScoreKeep_Games` as a game compatibility fixture and does not contain a checked-in `.ScoreKeep_Players` fixture found during inspection. The release fixture set must therefore adopt or create roster fixtures deliberately before claiming roster compatibility evidence.

Compatible user-owned source data must not be blocked by purchase gates. Import, review, repair where supported, and compatible source-data export preserve ownership. Generated reports, PDFs, screenshots, and premium convenience workflows are separate from source-data compatibility.

<!-- MARK: - 17. Import Workflow Verification -->
## 17. Import Workflow Verification

Import workflow verification covers file selection, security-scoped access where applicable, decode, validation, review, conflict presentation, confirmation, cancellation, persistence, duplicate detection, retry, interruption, malformed input, unsupported files, partial data, existing-record protection, accessible review, and purchase and allowance separation.

A scenario must verify both the final canonical state and preservation of existing records. Canceling before confirmation leaves local records unchanged. A failed decode or malformed file leaves unrelated teams, players, games, media, purchase state, and allowances unchanged. A confirmed import identifies what was created, updated, skipped, preserved, warned about, or rejected.

Conflict verification must prove that duplicate names, duplicate numbers, same-team same-date games, third-team references, missing players, missing teams, invalid media, unknown result strings, and unsupported future fields are handled through review or safe rejection rather than silent destructive merging.

<!-- MARK: - 18. Export Workflow Verification -->
## 18. Export Workflow Verification

Export workflow verification covers export scope, canonical record load, validation, encoding, destination handoff, cancellation, failure, retry, compatible output, stable source-data meaning, existing-data access without current entitlement, generated reports kept separate from source-data export, and privacy-conscious output.

Roster and game export require compatibility identity or semantic identity depending on the contract. Byte identity is not assumed unless a specific compatibility requirement establishes it. Export must not alter source teams, players, games, media, stored scores, provenance, purchase state, allowance state, or migration warnings.

Round-trip scenarios should compare the original canonical meaning, exported transport meaning, decoded import evidence, reimported canonical meaning, and regenerated reports. Required preserved meaning includes team identity, player identity, lineup state, substitutions, pitcher history, plate appearances, scoring results, outs, runners, inning state, media where applicable, warnings, and reportable totals.

<!-- MARK: - 19. Application-Service Workflow Verification -->
## 19. Application-Service Workflow Verification

Application-service workflow verification proves complete product workflows rather than isolated calculations. Required workflows include create team, edit team, create player, edit player, build roster, set batting order, configure lineup, create game, score game, correct game, substitute player, finish game, reopen existing game, import roster, import game, export source records, download MLB roster, generate reports, purchase access, restore access, and continue with free allowance.

Each workflow scenario verifies preserved pending state, validation, transaction boundary, idempotency, retry behavior, cancellation, interruption, diagnostics, and unchanged unrelated records. A workflow may call domain, persistence, compatibility, generated-output, purchase, allowance, network, and presentation boundaries, but the expected result remains a product outcome.

Application services should be verified for duplicate prevention across repeated taps, delayed callbacks, multiple scene updates, duplicate transaction updates, repeated import confirmation, repeated export requests, parallel saves, repeated game creation, repeated allowance consumption, repeated correction, and status refresh racing with cached entitlement. This design does not prescribe a concurrency framework; it requires observable guarantees.

<!-- MARK: - 20. Presentation-State Verification -->
## 20. Presentation-State Verification

Presentation-state verification proves prepared user-facing state without making SwiftUI the owner of business rules. It covers current game status, score, inning, count, outs, base occupancy, batter, pitcher, enabled and disabled actions, validation, empty states, loading, failure, pending, offline, purchase state, allowance state, import conflicts, correction effects, and generated-output readiness.

Device layout may differ, but product meaning must remain equivalent. A compact iPhone layout, iPad split view, portrait layout, landscape layout, keyboard-attached iPad, pointer interaction, large text, dark appearance, and light appearance may arrange controls differently; they must not change baseball results, validation, purchase policy, allowance results, or compatibility behavior.

Prepared state should explain unavailable actions where the reason matters, especially validation-blocked scoring, gated purchase actions, unavailable downloads, pending imports, interrupted correction, and generated-output failure. Visual presentation can supplement meaning but cannot replace semantic state.

<!-- MARK: - 21. Accessibility Verification -->
## 21. Accessibility Verification

Accessibility verification applies Document 26 directly and must be workflow-based. Required coverage includes VoiceOver, Dynamic Type, Increased Contrast, Differentiate Without Color, Reduced Motion, Full Keyboard Access where applicable, hardware keyboard, pointer or trackpad where applicable, Switch Control or Voice Control considerations for essential workflows, iPhone and iPad layouts, portrait, and landscape.

Verification must check semantic labels and values, logical navigation and focus, meaningful state announcements, no keyboard or focus traps, accessible alternatives to gestures, color-independent meaning, large-text reflow, preserved baseball correctness, no duplicate commands from focus or repeated activation, accessible correction and destructive confirmation, and paywall and import workflow preservation.

Static label inspection is insufficient. A labeled control can still fail if focus order is wrong, a scorecard has no semantic equivalent, large text clips core actions, a required action is swipe-only or drag-only, alternate input produces different baseball results, or a paywall loses pending work.

<!-- MARK: - 22. Generated-Output Verification -->
## 22. Generated-Output Verification

Generated-output verification covers statistical correctness, source-record scope, derived nature of reports, stable reading order, table meaning, page content, headers and repeated headers, long names, empty data, pagination, localization, large text where applicable, high contrast, color-independent meaning, sharing, saving, failure, cancellation, purchase gating, existing generated output, and separation from compatible source-data export.

Reports, PDFs, scorecards, screenshots, and share artifacts are derived from source records. They do not become source facts and must not repair, mutate, or reinterpret canonical baseball records. A generated output failure or canceled share must leave source records unchanged.

Pixel-identical output across operating-system versions is not assumed. Semantic comparison is preferred for baseball totals, names, table structure, warnings, and selected scope. Visual or snapshot evidence is useful for layout, clipping, missing pages, and readability, but it must be paired with semantic checks when the output carries baseball facts.

<!-- MARK: - 23. Purchase, Entitlement, and Allowance Verification -->
## 23. Purchase, Entitlement, and Allowance Verification

Purchase, entitlement, and allowance verification applies Document 25. Required scenarios include product loading, current-season product, prior-season product, wrong-season product, localized price, product unavailable, price unavailable, purchase success, entitlement recognition, purchase pending, purchase cancellation, purchase failure, restore success, restore with no applicable purchase, status unavailable, offline-known entitlement, offline-uncertain entitlement, expiration, Apple account or storefront uncertainty, and existing data remaining accessible.

Allowance scenarios include free game allowance, MLB download allowance, successful qualifying action, failed action, canceled action, duplicate action, interrupted action, invalid persisted allowance state, reinstall or device-change uncertainty, and no allowance consumption when the qualifying action does not complete. Repository evidence identifies `freeGameCreatesRemainingKC` with default two remaining game creates and `mlbDownloadCountKC` with a four-download limit as legacy evidence, not future schema.

No verification should require a real paid production transaction where safe controlled purchase infrastructure is available. StoreKit configuration is product-state evidence for configured identifiers and local test behavior. Live App Store or account behavior may still require exploratory or release-candidate checks, but live responses cannot be the sole proof of purchase correctness.

<!-- MARK: - 24. Network and External-Service Verification -->
## 24. Network and External-Service Verification

Network and external-service verification covers MLB manifest availability, valid roster download, missing file, invalid file, HTML response instead of roster content, timeout, offline state, interrupted download, retry, duplicate callback, stale data, wrong URL, product-service unavailability, and StoreKit status delay.

Controlled deterministic evidence must be distinguished from live-service health checks. Pinned local roster files, mocked or controlled responses, and reviewed fixtures prove import and download behavior. Live checks prove only that a specific external service responded during the check.

A live network response must not be the sole proof of import, purchase, or compatibility correctness. If `https://komakode.com/Teams/index.json` or a team URL changes, verification should classify whether the app handles the observed response safely and whether compatibility obligations require server-side preservation.

<!-- MARK: - 25. Offline Verification -->
## 25. Offline Verification

Offline verification proves that local baseball ownership is preserved. Scenarios include opening local records, scoring an existing game, correcting an existing game, managing local teams and players, importing local compatible files, exporting compatible files, generating local output where policy permits, previously confirmed entitlement, unknown entitlement, network roster unavailability, purchase unavailability, app restart while offline, and resumption after connectivity returns.

Network-only features may be unavailable offline, but their failure must not damage local records, consume allowances, hide existing data, or convert purchase uncertainty into definitive loss. Previously confirmed access should be classified according to the approved cached-access policy; unknown access remains uncertainty.

Returning online must refresh external state without overwriting offline scoring work, duplicating downloads, duplicating purchases, duplicating imports, or changing local baseball facts without a separate confirmed command.

<!-- MARK: - 26. Interruption and Resume Verification -->
## 26. Interruption and Resume Verification

Interruption and resume verification covers game creation, live scoring, correction, persistence, import, export, download, generated output, purchase, restore, allowance consumption, modal presentation, backgrounding, foregrounding, scene changes, and app termination.

The expected result is based on the last confirmed state. Completed work remains completed. Incomplete work is recoverable, canceled, or explained without corrupting records. Unknown completion is classified as uncertainty and must not make the user's state worse.

Resume must preserve user context where practical: selected game, selected team, selected roster, report scope, form values, validation warnings, paywall state, import review, correction focus, and current accessible focus. It must not duplicate side effects or consume allowances more than once.

<!-- MARK: - 27. Device-Class and Locale Verification -->
## 27. Device-Class and Locale Verification

Device-class verification covers supported iPhone sizes, supported iPad sizes, compact and regular width, portrait and landscape, keyboard-attached iPad, pointer interaction, large text, dark appearance, and light appearance. This design does not invent a device matrix unsupported by the project's deployment targets; it requires the matrix to be derived from approved platform support.

Layout may differ, but baseball results, validation, purchase policy, allowance results, compatibility behavior, import interpretation, export meaning, and accessibility outcomes must not differ. A device-specific presentation failure is a release concern when it changes product meaning, blocks core workflow completion, or hides essential state.

Localization and locale verification covers dates, times, numbers, prices, seasons, team and player names, long translated strings, baseball abbreviations, generated reports, VoiceOver pronunciation, and machine-readable compatibility formats independent of display locale. Right-to-left layout remains an unresolved consideration unless supported languages or requirements establish it. The repository shows English strings and localized StoreKit price evidence, but it does not establish non-English language support.

<!-- MARK: - 28. Privacy and Test Data -->
## 28. Privacy and Test Data

Verification data should be synthetic or deliberately approved. It must avoid real youth-player information, private user files, full player records from support cases, photos, logos, purchase credentials, receipts, account details, and unrelated files unless a user explicitly chooses to share diagnostic material.

Screenshots, logs, test artifacts, generated reports, and failure diagnostics should avoid exposing unnecessary baseball records. Production analytics are not invented by this design and must remain separate from verification if later approved.

Temporary imported or exported files should be isolated and disposed of safely after verification. No verification mechanism may alter production records, consume real purchases, corrupt user files, leak private baseball data, or silently broaden sharing beyond the user's chosen action.

<!-- MARK: - 29. Diagnostic Evidence -->
## 29. Diagnostic Evidence

Failed scenarios should produce privacy-conscious diagnostic evidence sufficient to understand the product failure. Useful fields include scenario identity, requirement source, app version, platform version, device class, initial-state classification, command classification, expected result, observed result, last confirmed persistence state, entitlement classification, allowance classification, error category, whether source baseball records changed, whether purchase state changed, and whether allowance changed.

Diagnostics should classify records rather than dump full private content by default. They should not expose full player records, photos, logos, receipts, credentials, account identifiers, unrelated file paths, or unrelated app data unless a user explicitly chooses that support path.

Diagnostic evidence is not acceptance by itself. It explains failure, supports triage, and helps determine whether the issue is a release blocker, accepted limitation, compatibility limitation, accessibility limitation, external-service limitation, cosmetic defect, diagnostic gap, or deferred enhancement.

<!-- MARK: - 30. Manual Exploratory Verification -->
## 30. Manual Exploratory Verification

Manual exploratory verification remains necessary for live scoring efficiency, accessibility with actual assistive technologies, dense scorecard readability, correction comprehension, gesture alternatives, iPad popovers and keyboard navigation, purchase messaging, generated PDF quality, external share and print sheets, app interruption, real-world roster files, device rotation, long sessions, and storefront or account behavior where controlled testing cannot fully reproduce reality.

Manual verification supplements deterministic tests; it does not replace them. A manual pass may discover usability, workflow, accessibility, or external-service issues that fixtures did not predict, but the highest-risk findings should become deterministic scenarios or regression catalog entries when practical.

Exploratory results should identify the build, source revision, device class, system settings, data set, workflow, observed result, expected product meaning, data risk, and whether the issue threatens correctness, ownership, accessibility, compatibility, or purchase honesty.

<!-- MARK: - 31. Regression Catalog -->
## 31. Regression Catalog

ScoreKeep needs a traceable regression catalog containing important historical and architectural failures. Categories include incorrect score, incorrect inning transition, incorrect outs or base state, incorrect batter or pitcher statistics, broken replay, lost substitution, failed file compatibility, data loss, duplicate records, import overwrite, export corruption, purchase-driven data lock, incorrect allowance decrement, duplicate gated action, offline access loss, paywall losing pending work, accessibility focus loss, Dynamic Type clipping, color-only meaning, generated-output mismatch, device-class behavioral divergence, and debug behavior leaking into release.

Specific historical defects should be cited only when repository evidence or existing documentation supports them. Confirmed catalog evidence includes the fixture catalog's historical risks such as fixed-size scoring indexes, force-unwrapped import references, lost lineup player lists on export, name-based matching risks, stored-score mismatch, duplicate scoring records, sacrifice spelling mismatch, pitching calculation differences, document UTI risks, deep-link routing differences, and debug free-counter reset risk.

Every new defect that threatens product meaning should produce a scenario with expected safe behavior. Retiring a regression requires proof that the behavioral obligation is represented elsewhere, not merely deletion of an old test.

<!-- MARK: - 32. Requirement Traceability -->
## 32. Requirement Traceability

Each major verification scenario should connect to at least one numbered design document, functional requirement, compatibility obligation, repository evidence item, known regression, release blocker, or unresolved question. Traceability allows a failure to be understood in product terms rather than as an isolated test failure.

The design document number explains architectural authority. The functional requirement explains user-facing obligation. The compatibility obligation explains legacy or external data expectations. Repository evidence explains current behavior or risk. The regression entry explains why the scenario must continue to exist. The release-blocker link explains release impact.

This design does not prescribe a tracking system. It requires enough traceability that a reviewer can answer what product promise failed, what records may be affected, what evidence is trustworthy, and what decision is required before release.

<!-- MARK: - 33. Coverage and Confidence -->
## 33. Coverage and Confidence

Numerical code coverage alone is insufficient for ScoreKeep acceptance. High coverage can still miss wrong baseball results, unsafe import merges, broken replay, data loss, purchase dishonesty, inaccessible workflows, malformed files, interrupted saves, or unsupported device layouts.

Confidence is measured by critical baseball rules exercised, boundary conditions, compatibility files, migration paths, failure paths, interruption paths, accessibility workflows, purchase outcomes, allowance outcomes, device classes, offline behavior, historical regressions, and unchanged-record assertions.

Code coverage may be useful implementation evidence once a test architecture exists, but it is not the product acceptance standard. A release candidate with lower numerical coverage and strong product-boundary evidence may be more trustworthy than one with broad coverage over implementation details and missing scenario evidence.

<!-- MARK: - 34. Test Isolation and State Reset -->
## 34. Test Isolation and State Reset

Verification must isolate persistence, Keychain-backed purchase or allowance state, files, network responses, current date and season, locale, time zone, device class, accessibility settings, app lifecycle, transaction updates, and external callbacks. Shared state must not allow test ordering to affect product evidence.

Reset behavior must be confined to verification or debug environments and must never silently affect release users. Repository evidence includes debug-only free-counter reset behavior, which must be verified not to leak into release behavior.

This design does not define concrete dependency-injection APIs, storage containers, clock abstractions, network stubs, or StoreKit harnesses. It defines the isolation outcomes that later implementation must provide.

<!-- MARK: - 35. Time and Season Control -->
## 35. Time and Season Control

ScoreKeep behavior can depend on date, season, game date, purchase product year, entitlement expiration, report dates, local time zone, and end-of-year boundaries. Verification must cover current year, prior year, future year, end-of-year boundary, local time-zone boundary, daylight-saving changes where relevant, game dates, product-season classification, expiration, and report dates.

Tests must not become unreliable merely because the real calendar year changes. A scenario that verifies the current-season product must state the intended season classification and expected product behavior rather than relying blindly on today's date.

This design does not invent a concrete clock abstraction. It requires controlled time evidence wherever date-sensitive behavior is being accepted.

<!-- MARK: - 36. Determinism and Flaky Verification -->
## 36. Determinism and Flaky Verification

Nondeterminism can come from network timing, StoreKit timing, async callbacks, date and time, random IDs, file ordering, collection ordering, fonts, rendering, OS-specific PDF layout, animation, accessibility announcement timing, app lifecycle, and parallel tests.

Flaky verification is unresolved evidence, not a passing result to ignore. A scenario that sometimes passes and sometimes fails has not proven release readiness. Arbitrary retry counts may hide timing issues but do not establish deterministic product behavior.

Where nondeterminism is inherent, the scenario should verify stable classifications and observable guarantees. For example, a live network health check may produce available or unavailable, but both outcomes should leave local records unchanged and produce clear diagnostics.

<!-- MARK: - 37. Continuous and Local Verification -->
## 37. Continuous and Local Verification

Verification should support fast local checks during development, focused scenario verification for changed behavior, broader regression verification before integration, documentation validation, build verification, compatibility fixture verification, accessibility review, and release-candidate verification.

This design does not require a specific CI service, GitHub workflow, hosted runner, or paid tool. Repository inspection did not identify a current GitHub workflow. Cost-conscious verification should prefer built-in or free capabilities where they provide adequate confidence, while leaving room for later approved infrastructure decisions.

Local verification should make it easy to run the scenarios relevant to a changed boundary without requiring live purchase transactions, real user files, or network availability. Release verification should broaden the evidence set and record known unresolved risks.

<!-- MARK: - 38. Documentation Verification -->
## 38. Documentation Verification

Future design and implementation documentation should be verified for exact title, sequential sections, MARK comments where required, real repository path, supported claims, no invented implementation details, no unrelated changes, traceable decisions, open questions, accurate commit verification, and accurate remote verification.

Documentation verification must distinguish formatting from content truth. Automation may detect missing section numbers or MARK comments, but it must not silently modify content merely to satisfy formatting rules without review.

Documentation-only changes should leave production source code, tests, fixtures, seeded data, StoreKit configuration, project settings, schemes, build configurations, existing documents, and Git configuration untouched unless the task explicitly approves those changes.

<!-- MARK: - 39. Release Acceptance Model -->
## 39. Release Acceptance Model

A release candidate should have an identified build and source revision, known migration path, completed critical scenario set, completed compatibility verification, completed scoring and replay verification, completed persistence verification, completed purchase and allowance verification, completed accessibility workflow verification, completed offline and interruption verification, completed generated-output review, classified known issues, resolved release blockers, protected user-owned data, no unexplained fixture changes, no debug resets or test behavior active in release, and reproducible evidence sufficient to explain the decision.

Release acceptance is traceable to explicit requirements and known unresolved risks. It is not a vague confidence statement, a single successful build, a clean launch screenshot, a passing UI smoke test, or a manual impression that the app seems fine.

The acceptance model does not invent a formal sign-off role or organization. It defines the evidence required for a responsible release decision.

<!-- MARK: - 40. Release Blockers -->
## 40. Release Blockers

Release blockers include incorrect baseball result, nondeterministic replay, data loss or corruption, failed migration of supported records, broken legacy file compatibility, existing records inaccessible, import overwriting unrelated data, export producing invalid compatible records, failed or canceled action consuming allowance, duplicate purchase or allowance effect, wrong-season entitlement, purchase uncertainty treated as definitive loss, paywall discarding pending work, and verification unable to establish the last confirmed state.

Accessibility blockers include a core workflow inaccessible through supported assistive technology, essential meaning communicated only by color, core Dynamic Type failure, keyboard or focus trap, inaccessible correction or destructive confirmation, and duplicate scoring caused by interruption or alternate input.

Other blockers include debug or fixture behavior leaking into release, unexplained regression fixture changes, duplicate side effects from resume or concurrency, source-data import or export blocked by purchase status, and generated output that contradicts source records in a way that threatens correctness. Lower-priority defects may be accepted only when they do not threaten correctness, ownership, accessibility of core workflows, compatibility, or purchase honesty.

<!-- MARK: - 41. Known-Issue Classification -->
## 41. Known-Issue Classification

Known issues should be classified conceptually as release blocker, high-risk accepted limitation, compatibility limitation, accessibility limitation, external-service limitation, cosmetic defect, diagnostic gap, or deferred enhancement. These labels are product-risk categories, not a new issue-tracking system.

Every accepted issue should state affected workflows, user impact, data risk, recovery path, verification evidence, and why release remains acceptable. An accepted limitation cannot contradict the release blockers in this design.

External-service limitations should separate product behavior from service health. A roster endpoint outage may be an external limitation if local records remain safe and the app explains the failure. An import routine that corrupts records after receiving HTML instead of roster content is a product blocker.

<!-- MARK: - 42. Legacy Mapping -->
## 42. Legacy Mapping

Relevant existing tests are limited to a placeholder Swift Testing test and basic XCTest UI launch and launch-performance tests. They are repository evidence that test targets exist, but they do not currently prove baseball rules, scoring replay, persistence, migration, compatibility, purchase policy, accessibility workflows, or release readiness.

Relevant fixtures and assets include `ScoreKeep/Seed/seededGame.ScoreKeep_Games`, `ScoreKeep.storekit`, `ScoreKeep/Reporting/Manual.pdf`, document type declarations, URL inventory, and the acceptance fixture catalog. The repository search did not find a checked-in `.ScoreKeep_Players` fixture.

Relevant legacy behavior evidence includes SwiftData models, import and export code, `ShareTeam`, `SharePlayer`, `ShareGame`, `ShareAtbat`, `ShareLineup`, `SharePitcher`, roster downloads, deep links, generated reports and PDFs, screenshot and share paths, StoreKit product loading, Keychain-backed entitlement and counters, debug counter reset, limited accessibility labels, and device-specific SwiftUI navigation. These should be preserved as regression coverage where they represent product or compatibility obligations. Implementation-specific expectations should not constrain the rewrite unless they are accepted contracts.

<!-- MARK: - 43. Legacy Verification Risks -->
## 43. Legacy Verification Risks

Confirmed repository risks include placeholder tests that do not assert critical behavior, missing checked-in roster fixtures, reliance on a single checked-in game fixture, live network endpoint dependence, hard-coded seasonal product prefix behavior, Keychain-backed counters with debug reset evidence, generated-output and report duplication risks documented in prior designs, limited accessibility labels, color and dense layout risks, drag or swipe interaction risks, custom drawings without broad semantic equivalents, and device-specific navigation differences.

Migration risks to inspect include tests asserting implementation instead of product behavior, fixtures generated from the same code being tested, visual snapshots masking semantic errors, hidden locale or device assumptions, shared persistence state, missing malformed-file fixtures, missing interruption cases, missing accessibility workflow tests, passing tests that do not assert unchanged records, migration tested only from empty data, golden files updated without independent review, and Xcode or Git source-control status mistaken for direct remote state.

These risks should be classified carefully. A risk is claimed as current only when repository evidence supports it. Otherwise it remains a migration risk that must be investigated before release.

<!-- MARK: - 44. Migration and Coexistence -->
## 44. Migration and Coexistence

Verification supports incremental rewriting while legacy and rewritten components coexist. The same scenario should be evaluated against accepted behavior, with clear authority for each replaced workflow and no double execution of legacy and rewritten side effects.

Compatibility fixtures remain until replacement is proven. Migration fixtures remain through supported upgrade paths. Old tests are retired only after their behavioral obligation is represented elsewhere. New tests must not depend on inaccessible legacy internals. Release gates tighten as rewritten boundaries become authoritative.

During coexistence, a legacy view may still present a workflow while a rewritten application service becomes the authority for command validation, idempotency, purchase gating, or persistence. Verification must prove that only one boundary writes each side effect. No production source change should be included merely to make documentation verification pass.

<!-- MARK: - 45. Risks and Open Questions -->
## 45. Risks and Open Questions

Unresolved questions include exact fixture storage format, exact test-target organization, whether existing fixtures are sufficient or need curated replacements, how much historical compatibility must remain byte-identical, exact generated-PDF comparison strategy, accessibility automation capabilities versus manual testing, supported OS and device verification matrix, required performance thresholds, long-running game-session verification, StoreKit test-environment limitations, network contract testing, migration sources from released app versions, fixture review process, CI service and cost, and retention of release evidence.

Additional open questions include how to collect sanitized historical compatibility files, whether live remote roster downloads should be pinned into local fixtures, how to compare locale-sensitive generated output, how to preserve expected-output history, how to verify real assistive-technology workflows at release scale, and how to classify generated screenshots versus source-data export.

This document does not settle those questions. They require repository evidence, product approval, implementation readiness decisions, or fixture-data work before release.

<!-- MARK: - 46. Success Criteria -->
## 46. Success Criteria

Document 27 succeeds when verification is treated as product architecture, when fixtures describe meaningful scenarios rather than implementation internals, and when release acceptance can be explained from explicit evidence.

The rewritten ScoreKeep should be able to prove canonical baseball meaning, scoring correctness, replay and correction, persistence and recovery, legacy file compatibility, import and export ownership, application-service workflows, presentation projections, generated output, purchases, entitlements, allowances, accessibility, offline behavior, interruption recovery, migration safety, device-class consistency, and release readiness.

Success also requires honest boundaries: tests do not define baseball rules, snapshots do not prove semantics, UI smoke tests do not prove persistence or compatibility, manual testing does not replace deterministic regression evidence, and internal implementation details remain free to change unless they are product or compatibility contracts.

<!-- MARK: - 47. Recommended Next Design Document -->
## 47. Recommended Next Design Document

The recommended next design document is `ScoreKeep Technical Design — 28 Implementation Readiness and Phased Rewrite Plan`.

Documents 17 through 27 now define the rewrite architecture, canonical baseball model, scoring engine, persistence, compatibility, scorecard presentation, application services, generated output, purchase and allowance policy, accessibility, fixtures, verification, and release acceptance. The next architectural need is to convert those approved boundaries into ordered migration stages, dependency gates, coexistence rules, readiness criteria, replacement sequencing, and completion criteria.

Document 28 should remain implementation-readiness architecture rather than production code. It should identify which boundaries must be built first, which legacy workflows may coexist temporarily, what evidence gates each replacement, how fixture and release requirements tighten over time, and when the rewrite can safely retire legacy behavior.

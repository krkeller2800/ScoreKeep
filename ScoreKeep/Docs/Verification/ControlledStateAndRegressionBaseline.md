# Controlled State and Regression Run Baseline

<!-- MARK: - 1. Purpose and Scope -->
## 1. Purpose and Scope

This document completes implementation-catalog task `0.14 Controlled date, season, debug, and regression run baseline` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

Scope is Phase 0 verification infrastructure only. The task added deterministic test-only controlled-state support and focused unit tests. It did not begin Phase 1 canonical-domain implementation and did not change production purchase, entitlement, allowance, seed, persistence, StoreKit, fixture, scoring, import, export, routing, or Git configuration behavior.

Governing evidence inspected: Documents 25, 27, 28, and 29; `ScoreKeep/Docs/Verification/ScoringRegressionScenarioCatalog.md`; `PurchaseManager`; `ScoreKeep.storekit`; `KeychainBackedCounter`; `ScoreKeepApp`; `ScoreContentView`; `ShareContentView`; `GameView`; existing `ScoreKeepTests`; `ScoreKeep.xctestplan`; isolated persistence test support; existing fixture catalogs; and `ScoreKeep/Docs/BaselineVerification.md`.

<!-- MARK: - 2. Date-Dependent Source Inventory -->
## 2. Date-Dependent Source Inventory

Product policy:

| Source | Current behavior | Classification |
| --- | --- | --- |
| `PurchaseManager.currentSeasonPassProductID()` | Builds `com.komakode.ScoreKeep.SeasonPass` plus `Calendar.current.component(.year, from: Date())`. | Product policy |
| `PurchaseManager.refreshEntitlements()` | Treats locally stored max expiration as active only when it is greater than `Date()`. | Product policy |
| `PurchaseManager.endOfYear(for:)` | Computes December 31, 23:59:59 with `Calendar.current`, intentionally using the user's local calendar and time zone. | Product policy |
| `PurchaseManager.saveLocalMaxExpiration(_:)` and `loadLocalMaxExpiration()` | Stores and reads ISO8601 strings under `seasonPassMaxExpirationISO8601`. | Product policy / persistence evidence |
| `PaywallView.productYear` | Uses loaded product ID suffix when available; otherwise falls back to `Calendar.current` year from `Date()`. | Product policy / presentation |

Baseball record data and presentation:

| Source | Current behavior | Classification |
| --- | --- | --- |
| `GameView` | New-game date state defaults to `Date()` and writes ISO8601 strings; seeded-game hint compares a fixed 2025-11-01 day with `Calendar.current`. | Baseball record data / seed presentation |
| `EditGameView` | Parses `game.date`, falling back to `Date()` for edit display and writing ISO8601 on change. | Baseball record data |
| `EditScoreView` | Date state defaults to `Date.now`; game dates are parsed for display and screenshot filename generation with fallback `Date()`. | Presentation formatting / generated-output filename |
| `ShareContentView` | Parses game date strings for picker labels and export filenames, falling back to `Date()`. | Presentation formatting / generated-output filename |
| `BaselineVerification.md` and fixture files | Contain fixed documented or fixture dates. | Test-only and documentation evidence |

Logging and diagnostics include startup document-directory `print` calls and error logs, but no controlled-date product policy is derived from those logs. Current production intentionally uses `Calendar.current` for season selection and local end-of-year expiration; task `0.14` records that behavior without redefining it.

<!-- MARK: - 3. Seasonal Product Baseline -->
## 3. Seasonal Product Baseline

Current product identifier construction is `com.komakode.ScoreKeep.SeasonPass` plus the current local calendar year.

Configured StoreKit non-renewing subscription products remain unchanged:

| Product ID | Display price | Name evidence |
| --- | ---: | --- |
| `com.komakode.ScoreKeep.SeasonPass2025` | `4.99` | `ScoreKeep 2025 Season Pass` |
| `com.komakode.ScoreKeep.SeasonPass2026` | `4.99` | `ScoreKeep 2026 Season Pass` |

Current source parses a season year from the last four product-ID characters. It does not validate the stable prefix in the private parsing helper. Current purchase initiation blocks a loaded `Product` whose ID is not exactly the current-year product ID, but transaction-update handling will compute expiration for any verified transaction whose product ID ends in four digits. This is legacy evidence and a Phase 9 risk, not a task `0.14` production change.

Current expiration behavior is local end of the parsed season year, stored as the maximum observed expiration. Entitlement is active only when stored expiration is strictly greater than the current instant, so the exact expiration instant is inactive.

Focused tests establish fixed expectations for:

| Fixed case | Test evidence |
| --- | --- |
| Current configured season | July 14, 2026 local policy date maps to `com.komakode.ScoreKeep.SeasonPass2026`. |
| Prior season | Product year 2025 classified as prior when current year input is 2026. |
| Current season | Product year 2026 classified as current when current year input is 2026. |
| Future season | Product year 2027 classified as future when current year input is 2026. |
| End of season | 2026 local expiration is December 31, 2026 23:59:59 in `America/New_York`. |
| UTC boundary | That same instant is January 1, 2027 04:59:59 UTC. |
| Immediately before expiration | Active. |
| Exact expiration instant | Inactive because production uses `>` rather than `>=`. |
| Immediately after expiration | Inactive. |
| Missing product | Distinct from loaded product with no active entitlement. |
| Invalid suffix | Non-numeric or too-short suffix parses as nil. |

<!-- MARK: - 4. Controlled Date and Time-Zone Support -->
## 4. Controlled Date and Time-Zone Support

Test-only support lives in `ScoreKeepTests/TestSupport/ControlledStateBaselineSupport.swift`.

The support uses explicit `Calendar(identifier: .gregorian)`, explicit `Locale(identifier: "en_US_POSIX")`, and explicit time zones. The product-policy local calendar uses `America/New_York`, which matches the current Eastern-time season boundary expectation for this baseline. UTC helpers are used to record instant boundaries without depending on the machine time zone.

The support provides fixed constructors for:

| Date case | Representation |
| --- | --- |
| Current configured season | `2026-07-14 12:00:00 America/New_York` |
| End of season year | `2026-12-31 23:59:59 America/New_York` |
| First instant after season expiration | `2027-01-01 00:00:00 America/New_York` |
| Prior season | Explicit input year `2025` |
| Future season | Explicit input year `2027` |
| Fixed game date | Existing isolated test graph date `2026-07-14T12:00:00Z` remains fixed. |
| Time-zone boundary | `2026-12-31 23:59:59 America/New_York` equals `2027-01-01 04:59:59 UTC`. |

No existing fixture dates were changed.

<!-- MARK: - 5. Seed-State Baseline -->
## 5. Seed-State Baseline

Seed production behavior remains unchanged:

| Source | Current behavior |
| --- | --- |
| `ScoreKeepApp` | Creates the production SwiftData model container and attaches `SeederView` in the app root background. |
| `SeederView` | If `hasSeededInitialGame` is false and `seededGame.ScoreKeep_Games` exists in the main bundle, decodes and imports it, then sets the preference true. |
| `GameView` | Uses `hasSeededInitialGame` and `hasDismissedSeedHint_Game` for seed hint presentation. |

Seed-state tests use the existing in-memory `IsolatedPersistenceEnvironment`. They do not initialize `ScoreKeepApp`, `SeederView`, `ImportService` seed import, `Bundle.main` seed lookup, or production `UserDefaults.standard`.

Executable seed baseline:

| Evidence | Result |
| --- | --- |
| Fresh isolated store starts empty | Passing existing test. |
| Isolated store creation does not import production seed | Passing existing test. |
| Repeated isolated test environments remain seed-free | Passing new task `0.14` test. |
| Controlled test preferences use a named test suite only | Passing new task `0.14` test. |

Production seed files remain unchanged and outside the test baseline except as existing app resources and prior fixture evidence.

<!-- MARK: - 6. Allowance Baseline -->
## 6. Allowance Baseline

Current allowance evidence remains unchanged:

| Allowance | Source | Current durable state |
| --- | --- | --- |
| Free user-created games | `ScoreContentView` | `KeychainBackedCounter(key: "freeGameCreatesRemainingKC", defaultValue: 2)` stores remaining creates. |
| MLB roster downloads | `ShareContentView` | `KeychainBackedCounter(key: "mlbDownloadCountKC", defaultValue: 0)` stores used downloads; free limit is 4. |

Current write paths:

| Path | Current behavior |
| --- | --- |
| User-created non-premium game | Creates game, then sets free remaining to `value - 1`. |
| Seeded game creation path | Creates game without decrementing free game allowance. |
| Non-premium game at zero remaining | Shows paywall without creating a game. |
| Successful MLB roster download | After file download and import URL setup, increments used-download count if not premium. |
| Failed or blocked MLB download | Does not increment in the inspected path. |
| `KeychainBackedCounter.set(_:)` | Clamps stored values to zero or greater. |

The focused baseline tests do not instantiate `KeychainBackedCounter` because its initializer reads the real Keychain. They assert repository-backed constants and pure policy expectations only: default free games is two, MLB free limit is four, successful qualifying action consumes once, failed or canceled action consumes none, counters do not drop below zero, and game/download categories remain distinct.

Real Keychain state was not read, reset, or mutated by this task.

<!-- MARK: - 7. Debug and Release Baseline -->
## 7. Debug and Release Baseline

Repository-confirmed debug-only behavior affecting controlled state:

| Source | Debug-only behavior | Release expectation |
| --- | --- | --- |
| `ScoreContentView.onAppear` | Under `#if DEBUG`, resets `freeGameCreatesRemainingKC` to 2 when the score screen appears and the value differs. | Excluded from Release by conditional compilation. |

Repository-confirmed compile-time or runtime behavior that is not debug-only:

| Area | Current behavior |
| --- | --- |
| Purchases and entitlements | `PurchaseManager` is app-scoped, loads StoreKit products, listens for transactions, refreshes local Keychain expiration on launch/foreground. |
| Seeding | `SeederView` is production startup behavior gated by `hasSeededInitialGame`, not by `#if DEBUG`. |
| Allowances | Game and download counters are production Keychain-backed counters; only the free-game reset is debug-only. |
| Persistence | Production app uses `.modelContainer(for: Game.self)`; tests use a separate in-memory harness. |
| Navigation, reports, imports | No debug-only reset behavior was found in the inspected paths; logging and `print` diagnostics exist but do not reset state. |

The task added test-only support and tests under `ScoreKeepTests`. No app-target source was changed. The active test plan contains only `ScoreKeepTests`; UI tests remain outside the current plan. The successful production build reported no warning entries through the Xcode build log query.

Release evidence is source inspection plus attempted Release builds. Explicit Release simulator and generic-device command-line builds were blocked by `CompileStoryboard` with `iOS 26.5 Platform Not Installed` after CoreSimulator and Interface Builder service failures. This matches the environment class already documented in `BaselineVerification.md`; it is not evidence of a production source regression from task `0.14`.

<!-- MARK: - 8. Regression Run Baseline -->
## 8. Regression Run Baseline

Environment:

| Item | Value |
| --- | --- |
| Date | July 14, 2026 |
| Xcode | Xcode 26.5, build 17F42 |
| Scheme | `ScoreKeep` |
| Test plan | `ScoreKeep.xctestplan`, active plan name `ScoreKeep` |
| Test target | `ScoreKeepTests` |
| Simulator destination | Xcode MCP active run destination; command-line simulator services log CoreSimulator failures. |

Test discovery:

| Item | Count |
| --- | ---: |
| Tests discovered | 19 |
| Enabled | 19 |
| Disabled | 0 |

Runs:

| Run | Executed | Passed | Failed | Skipped | Not run | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Full unit-test plan, first run | 19 | 19 | 0 | 0 | 0 | Passed |
| Full unit-test plan, second run | 19 | 19 | 0 | 0 | 0 | Passed |
| Active production build | N/A | N/A | N/A | N/A | N/A | Passed |
| Explicit Release simulator build | N/A | N/A | N/A | N/A | N/A | Blocked by `CompileStoryboard` / `iOS 26.5 Platform Not Installed` |
| Explicit Release generic iOS build | N/A | N/A | N/A | N/A | N/A | Blocked by `CompileStoryboard` / `iOS 26.5 Platform Not Installed` |

Warnings and failures:

| Area | Result |
| --- | --- |
| Successful Xcode build warnings | No warning entries returned by `GetBuildLog(severity: warning)`. |
| Command-line Release warnings | CoreSimulatorService, simdiskimaged, Interface Builder, and plist type-detection warnings occurred before storyboard failure. |
| Preexisting failures | Release command-line builds are blocked by local Xcode/simulator platform tooling, consistent with prior baseline environment evidence. |

<!-- MARK: - 9. Limitations Risks and Next Task -->
## 9. Limitations Risks and Next Task

Limitations:

| Area | Limitation |
| --- | --- |
| PurchaseManager private helpers | Current product ID, suffix parsing, and expiration helpers are private and coupled to StoreKit/Keychain through `PurchaseManager`, so executable tests use test-only pure mirrors of observed behavior rather than invoking production purchase code. |
| StoreKit | Tests do not query live StoreKit, purchase, restore, access transaction history, or require an Apple account. |
| Keychain | Tests do not instantiate real counters or entitlement storage, so they prove constants and pure allowance expectations without reading or mutating real durable state. |
| Release build | Explicit Release builds are blocked by local storyboard/platform tooling. |
| Prefix validation | Current transaction-update year parsing does not validate the product ID prefix before saving expiration. This remains Phase 9 risk evidence. |
| Production seeding | Seeding remains a production startup side effect gated by app storage; this task verifies test isolation, not a production seed redesign. |

Risks:

| Risk | Disposition |
| --- | --- |
| Calendar-year StoreKit product selection can become wrong if the current-year product is missing from StoreKit/App Store Connect. | Captured as baseline evidence; no StoreKit configuration changed. |
| Local end-of-year expiration depends on the user's calendar/time zone. | Captured with explicit local and UTC boundary tests. |
| Debug reset can mask real free-game counter state during Debug UI runs. | Captured as debug-only source evidence; Release exclusion verified by source inspection and attempted Release build. |
| Test-only mirrors could drift from production private helpers. | Acceptable for Phase 0 baseline; Phase 9 should introduce testable purchase/allowance authority before routing. |

Recommended next task: `1.1 Stable identity and ordering semantics`.

Phase 0 evidence is sufficient because the branch, tracking discrepancy, deterministic test support, controlled date/season expectations, seed isolation, allowance baseline, debug-only reset inventory, full repeated test plan, and production build baseline have been recorded without changing production authorities or user data. Task `1.1` will prepare canonical authority for stable identity and ordering of teams, players, games, participants, events, lineups, pitchers, and substitutions. Legacy SwiftData models, views, scoring, persistence, import/export, purchase, allowance, seed, and generated-output paths remain the active production authorities. Task `1.1` must not change baseball rules, persistence schemas, file formats, product identifiers, StoreKit configuration, purchase state, allowance counters, seed behavior, production routing, or user data.

Recommended following task: continue Phase 1 only after `1.1` passes; do not perform Phase 9 purchase or allowance architecture work until its catalog prerequisites are reached.

# Scoring Regression Scenario Catalog

<!-- MARK: - 1. Purpose and Authority -->
## 1. Purpose and Authority

This catalog completes implementation-catalog task `0.12 Scoring regression scenario capture` from `ScoreKeep/Docs/Design/29-ImplementationTaskCatalogAndDependencyMatrix.md`.

The catalog is documentation and verification evidence only. It captures accepted current scoring evidence, approved rewrite requirements, compatibility obligations, known regression expectations, proposed verification expectations, and unresolved baseball or product questions that later executable tests and fixtures can implement. It changes no production scoring behavior, replay behavior, correction behavior, persistence behavior, import/export behavior, seeded data, project settings, StoreKit configuration, existing design document, existing verification document, existing fixture, or executable test.

Governing evidence inspected: Functional Document 15; Verification Document 16; Design Documents 18, 19, 20, 22, 23, 27, 28, and 29; `ScoreKeep/Docs/CompatibilityRouteInventory.md`; curated `.ScoreKeep_Games` fixture catalogs and files under `ScoreKeep/Docs/Verification/Fixtures/ScoreKeep_Games`; malformed and unsupported fixture catalog and files under `ScoreKeep/Docs/Verification/Fixtures/MalformedAndUnsupported`; `ScoreKeep/Common/CommonData.swift`; `ScoreKeep/Objects/Game.swift`; `ScoreKeep/Objects/Atbat.swift`; `ScoreKeep/Objects/Lineup.swift`; `ScoreKeep/Objects/Pitcher.swift`; `ScoreKeep/Disply graphics/PlayersToScoreView.swift`; `ScoreKeep/Disply graphics/ScoreGameView.swift`; `ScoreKeep/Edit Data/EditScoreView.swift`; `ScoreKeep/Player org/ReplacementView.swift`; `ScoreKeep/Content Views/PitcherContentView.swift`; `ScoreKeep/Edit Data/EditPitcherView.swift`; `ScoreKeep/Reporting/ReportView.swift`; `ScoreKeep/Reporting/PitcherRptView.swift`; and `ScoreKeep/Drawing/drawAtbatView.swift`.

Legacy behavior is evidence. It is not architecture to reproduce unless it also represents an approved product requirement or compatibility obligation. The scenarios below do not settle new baseball policy, do not define a serialized test schema, and do not approve unsupported outcomes merely because they appear in future design documents as categories the rewrite should be able to classify.

<!-- MARK: - 2. Catalog Location Decision -->
## 2. Catalog Location Decision

Catalog path: `ScoreKeep/Docs/Verification/ScoringRegressionScenarioCatalog.md`.

Exact filename: `ScoringRegressionScenarioCatalog.md`.

Repository evidence supports this location because Document 27 identifies `ScoreKeep/Docs/Verification/16-AcceptanceFixturesAndRegressionScenarios.md` as the acceptance fixture and regression catalog, while tasks 0.9 through 0.11 place fixture files and fixture-specific catalogs under `ScoreKeep/Docs/Verification/Fixtures/...`. Task 0.12 is a scenario-capture task, not a fixture-data task, and the prompt explicitly prohibits fixture changes. Placing this file directly under `ScoreKeep/Docs/Verification` keeps it beside the existing acceptance/regression catalog while avoiding production source, test targets, seeded data, and fixture directories.

The existing fixture directories remain unchanged. This catalog references them as evidence and future inputs only.

<!-- MARK: - 3. Scenario Field Contract -->
## 3. Scenario Field Contract

Every scenario below uses the same conceptual field contract. The tables keep fields compact so the catalog remains reviewable; `N/A`, `unchanged`, `not serialized`, `not currently persisted`, and `unresolved` are explicit values rather than omissions.

Required fields for every scenario:

| Field | Meaning in this catalog |
| --- | --- |
| Scenario ID | Stable identifier grouped by category, such as `BASE-01` or `REPLAY-01`. |
| Title | Human-readable scenario name. |
| Governing requirement or design section | Functional or design source that authorizes the expectation. |
| Repository evidence | Source, model, fixture, or catalog evidence inspected for current behavior or risk. |
| Initial game state | Game setup, event history, current inning or half inning, score, outs, count, base occupancy, batting side, current batter, current pitcher, lineup state, and prior events where relevant. |
| User intent or scoring command | Touch, equivalent input, replay request, correction request, import/reopen state, or workflow command. |
| Expected accepted or rejected result | Whether the action is accepted, rejected, warning-limited, proposed, or unresolved. |
| Expected event record | `Atbat`, pitcher, lineup, substitution, correction, lifecycle, or no-event effect expected. |
| Expected derived state | Expected score, inning, outs, count, base occupancy, next batter, pitcher effect, batter effect, presentation effect, and replay result. |
| Expected persistence effect | Save, no save, isolated future save expectation, unchanged prior state, or unresolved current evidence. |
| Expected correction implications | Downstream recalculation, cancellation, rejection, or not applicable. |
| State that must remain unchanged | Teams, players, unrelated games, purchase state, allowances, fixtures, source files, unrelated rows, or prior accepted events. |
| Open questions or uncertainty | Explicit unresolved baseball or product decision. |
| Fixture relevance | Existing fixture reference or future fixture need. |
| Future executable-test category | Domain, scoring engine, replay, correction, persistence, application service, compatibility, presentation, accessibility, UI, or exploratory. |
| Evidence classification | One of: confirmed current repository behavior, approved design requirement, compatibility obligation, known regression requirement, proposed verification expectation, or unresolved question. |
| Release importance | Release-blocking correctness, high-risk migration or replay, important workflow regression, accessibility-critical, or lower-risk presentation or diagnostic behavior. |

This catalog intentionally does not define Swift types, test data builders, JSON schemas, fixture file names, UI automation selectors, concurrency APIs, transaction APIs, or correction command implementations.

<!-- MARK: - 4. Evidence Classification and Priority Legend -->
## 4. Evidence Classification and Priority Legend

Evidence classifications:

| Classification | Meaning |
| --- | --- |
| Confirmed current repository behavior | Directly supported by current source or curated fixture evidence. |
| Approved design requirement | Required by approved functional or technical documents, but not necessarily implemented. |
| Compatibility obligation | Required to preserve or safely classify existing `.ScoreKeep_Games`, `.ScoreKeep_Players`, seeded, or legacy stored evidence. |
| Known regression requirement | Captures a previously identified risk, defect class, or fragile current behavior that must be prevented later. |
| Proposed verification expectation | Reasonable future expectation derived from requirements, but requiring later implementation detail before executable tests. |
| Unresolved question | Requires product or baseball-policy decision before a passing result can be asserted. |

Release importance:

| Importance | Meaning |
| --- | --- |
| Release-blocking correctness | Wrong behavior would make scoring, replay, migration, or data preservation unsafe for release. |
| High-risk migration or replay | Needed to preserve existing records or trust deterministic replay. |
| Important workflow regression | Needed to prevent realistic user-facing workflow failures. |
| Accessibility-critical | Equivalent input or assistive workflow must not produce different baseball meaning. |
| Lower-risk presentation or diagnostic behavior | Important for clarity but less likely to corrupt baseball facts. |

<!-- MARK: - 5. Current Scoring Evidence Summary -->
## 5. Current Scoring Evidence Summary

Current confirmed evidence:

| Area | Current evidence | Classification |
| --- | --- | --- |
| Scoring entry point | `EditScoreView` opens `PlayersToScoreView` for the selected home or visiting team. | Confirmed current repository behavior |
| Event storage | `Atbat` persists `result`, `maxbase`, `outAt`, `inning`, `seq`, `col`, `rbis`, `outs`, `sacFly`, `sacBunt`, `stolenBases`, `earnedRun`, `playRec`, and `endOfInning`. | Confirmed current repository behavior |
| Supported result strings | `Common` lists singles, doubles, triples, home runs, walks, hit by pitch, dropped third strike, catcher interference, fielder's choice, errors, ground/fly/line/foul outs, strikeouts, strikeout looking, sacrifice fly, and sacrifice bunt. | Confirmed current repository behavior |
| Current count | No current source evidence persists balls or strikes. Count scenarios are future requirements or unresolved where they refer to pitch-by-pitch count. | Approved design requirement / unresolved question |
| Base state | Current live display derives occupancy from accepted on-base at-bats and `maxbase`; it does not persist explicit runner identities per base. | Confirmed current repository behavior |
| Runs | Current display and reports count runs primarily from `Atbat.maxbase == "Home"`. | Confirmed current repository behavior |
| Hits | Current display and reports count hits from `Common.hitresults`. | Confirmed current repository behavior |
| Outs | Current display increments outs for `Common.outresults` or `outAt != "Safe"`, stores `Atbat.outs`, and uses `endOfInning` evidence. | Confirmed current repository behavior |
| Event ordering | Current scoring sorts and mutates by `col` and `seq`; approved design requires explicit deterministic ordering independent from presentation coordinates. | Confirmed current repository behavior / approved design requirement |
| Persistence | Scoring and marker updates call `modelContext.save()` in view code and often log failures without a user-visible transaction boundary. | Confirmed current repository behavior |
| Correction | Current `ScoreGameView` can reopen and mutate an existing `Atbat`, reset/delete at-bats, and update derived fields; approved design requires explicit correction workflow and replay. | Confirmed current repository behavior / approved design requirement |
| Substitution | `ReplacementView` appends players to `game.replaced` and `game.incomings`, mutates `Player.batOrder`, shifts at-bat sequences, and inserts `Pitch Hitter` marker at-bats. | Confirmed current repository behavior |
| Pitchers | `Pitcher` persists player, team, game, start/end inning, outs, batter markers, aggregate fields, and win flag; `PlayersToScoreView` updates pitcher markers from scoring position. | Confirmed current repository behavior |
| Reports | Hitting and pitching reports independently derive totals from saved at-bats and pitcher markers, including known sacrifice spelling mismatch risk. | Confirmed current repository behavior / known regression requirement |
| Fixtures | Curated game fixtures cover minimal, in-progress, completed, ordered at-bat, lineup, pitcher, duplicate-conflict, missing optional, seed-compatibility, malformed, and wrong-content inputs. | Compatibility obligation |

<!-- MARK: - 6. Summary Tables by Category -->
## 6. Summary Tables by Category

Baseline and count scenarios:

| ID | Category | Initial state | Action | Expected high-level outcome | Classification | Fixture reference | Future test level | Importance |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BASE-01 | Baseline | New configured game, no at-bats | Open scoring | Top first, visitors batting, 0-0, 0 outs, empty bases, leadoff due | Approved design requirement | `MinimalValid.ScoreKeep_Games` | Domain/replay | Release-blocking correctness |
| BASE-02 | Baseline | Existing first-column placeholder rows | Open scorecard | Placeholders are setup/presentation evidence, not completed scoring events | Confirmed current repository behavior | Future scoring setup fixture | Presentation/replay | Important workflow regression |
| BASE-03 | Baseline | Two completed outs, empty bases | Open scoring | Current half inning remains active with two outs and next batter due | Approved design requirement | Future two-out fixture | Domain/replay | Release-blocking correctness |
| BASE-04 | Baseline | Imported in-progress event history | Reopen game | Current state is derived or warning-limited from event history, not guessed from stored score alone | Compatibility obligation | `InProgressGame.ScoreKeep_Games` | Compatibility/replay | High-risk migration or replay |
| BASE-05 | Baseline | Completed-like imported file with no explicit completed flag | Reopen or replay | Completion status remains unresolved unless lifecycle evidence or user decision exists | Unresolved question | `CompletedGame.ScoreKeep_Games` | Lifecycle/replay | Important workflow regression |
| COUNT-01 | Count | No persisted count fields | Enter first ball | Future scorer may track count if implemented; current repository has no durable ball field | Unresolved question | Future count fixture | Domain/scoring | Important workflow regression |
| COUNT-02 | Count | No persisted count fields | Enter first strike | Future scorer may track count if implemented; current repository has no durable strike field | Unresolved question | Future count fixture | Domain/scoring | Important workflow regression |
| COUNT-03 | Count | Full count future state | Walk | Walk completes plate appearance, resets count in replay projection | Approved design requirement | Future count fixture | Scoring engine | Release-blocking correctness |
| COUNT-04 | Count | Two-strike future state | Strikeout | Strikeout completes plate appearance, adds out, resets count in replay projection | Approved design requirement | Future count fixture | Scoring engine | Release-blocking correctness |
| COUNT-05 | Count | Completed plate appearance | Extra ball or strike | Reject or ignore without creating duplicate event; exact current UI behavior unresolved | Proposed verification expectation | Future invalid-count fixture | Application service | Important workflow regression |

Outcome, base, and run scenarios:

| ID | Category | Initial state | Action | Expected high-level outcome | Classification | Fixture reference | Future test level | Importance |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| OUT-01 | Outs | 0 outs, empty bases | Ground out to first | One accepted at-bat, outs becomes 1, count reset, bases unchanged | Confirmed current repository behavior / approved design requirement | `MultipleAtbats.ScoreKeep_Games` | Scoring engine | Release-blocking correctness |
| OUT-02 | Outs | 1 out | Fly out | Outs becomes 2, no run unless explicit runner outcome supports it | Approved design requirement | Future out fixture | Scoring engine | Release-blocking correctness |
| OUT-03 | Outs | 2 outs | Strikeout | Third out ends half inning, bases clear, next side bats | Approved design requirement | Future third-out fixture | Replay | Release-blocking correctness |
| OUT-04 | Outs | 3 outs already projected | Additional out command | Fourth out rejected or classified invalid, no new accepted state | Approved design requirement | Future invalid-out fixture | Validation | Release-blocking correctness |
| OUT-05 | Outs | Existing out at-bat | Repeated out tap or delayed callback | Same intent must not create duplicate at-bat or duplicate out | Known regression requirement | Future duplicate-tap fixture | Application service | Important workflow regression |
| HIT-01 | Hit | Empty bases, no outs | Single, default base | Batter reaches first, one hit, no run, next batter due | Confirmed current repository behavior | `MultipleAtbats.ScoreKeep_Games` | Scoring engine | Release-blocking correctness |
| HIT-02 | Hit | Empty bases | Double | Batter reaches second, one hit, no run, next batter due | Confirmed current repository behavior | `CompletedGame.ScoreKeep_Games` | Scoring engine | Release-blocking correctness |
| HIT-03 | Hit | Empty bases | Triple | Batter reaches third, one hit, no run, next batter due | Confirmed current repository behavior | Future triple fixture | Scoring engine | Release-blocking correctness |
| HIT-04 | Hit | Empty bases | Home run | Batter reaches home, one run, one hit, one HR, RBI per scorer choice | Confirmed current repository behavior | `CompletedGame.ScoreKeep_Games` | Scoring/report | Release-blocking correctness |
| HIT-05 | Hit | Runner choices required | Hit with optional runner movement | Additional-choice boundary must preserve explicit runner outcomes; do not assume automatic advancement beyond current evidence | Proposed verification expectation | Future runner-choice fixture | Scoring engine/UI | Release-blocking correctness |
| WALK-01 | Walk | Empty bases | Walk | Batter reaches first, walk counted, no hit, no run | Confirmed current repository behavior | `InProgressGame.ScoreKeep_Games` | Scoring/report | Release-blocking correctness |
| WALK-02 | Walk | Bases loaded | Walk | Forced run and forced runner movement only after explicit supported policy; current source lacks runner identity model | Approved design requirement / unresolved question | Future bases-loaded walk fixture | Scoring engine | Release-blocking correctness |
| OTHER-01 | Other on-base | Empty bases | Hit by pitch | Batter reaches first where supported, HBP counted in reports, no hit | Confirmed current repository behavior | Future HBP fixture | Scoring/report | Important workflow regression |
| OTHER-02 | Other on-base | Empty bases | Error | Batter reaches first, earned-run flag defaults false in current sheet, hit not counted | Confirmed current repository behavior | Future error fixture | Scoring/report | Important workflow regression |
| OTHER-03 | Other on-base | Empty bases | Fielder's choice | Batter reaches first in current base default, runner/out policy unresolved | Confirmed current repository behavior / unresolved question | Future FC fixture | Scoring engine | Important workflow regression |

Base occupancy and run-scoring scenarios:

| ID | Category | Initial state | Action | Expected high-level outcome | Classification | Fixture reference | Future test level | Importance |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BASEOCC-01 | Bases | Empty bases | On-base result to first | First occupied by batter; no duplicate runner | Confirmed current repository behavior | `MultipleAtbats.ScoreKeep_Games` | Domain/replay | Release-blocking correctness |
| BASEOCC-02 | Bases | Runner on first | Next safe batter reaches first | Prior runner must advance, hold, score, or be out explicitly; no two runners on first | Approved design requirement | Future runner fixture | Scoring engine | Release-blocking correctness |
| BASEOCC-03 | Bases | Runner on second | Single or runner choice | Runner movement and score are explicit; current `maxbase` alone is insufficient for runner identity | Approved design requirement | Future runner fixture | Scoring engine | Release-blocking correctness |
| BASEOCC-04 | Bases | Runner on third | Home run or runner scores | Run counted only for accepted scoring outcome; scored runner removed from bases | Approved design requirement | Future run fixture | Scoring engine | Release-blocking correctness |
| BASEOCC-05 | Bases | First and second | Safe result | Advancement must prevent duplicate occupancy and preserve runner identities | Approved design requirement | Future runner fixture | Scoring engine | Release-blocking correctness |
| BASEOCC-06 | Bases | First and third | Safe result or out | Runner movement choices determine score and remaining bases | Proposed verification expectation | Future runner fixture | Scoring engine | Release-blocking correctness |
| BASEOCC-07 | Bases | Second and third | Safe result | Multiple runners can score or remain only through explicit runner outcomes | Approved design requirement | Future runner fixture | Scoring engine | Release-blocking correctness |
| BASEOCC-08 | Bases | Bases loaded | Any force or hit | Forced and optional movements must preserve one runner per base | Approved design requirement | Future bases-loaded fixture | Scoring engine | Release-blocking correctness |
| RUN-01 | Runs | Empty bases | Home run | Score increases by one for batting side; event and presentation agree | Confirmed current repository behavior | `CompletedGame.ScoreKeep_Games` | Scoring/report | Release-blocking correctness |
| RUN-02 | Runs | Runners on base | Home run | Multiple runs counted for batter and active runners only when runner outcomes support them | Approved design requirement | Future multi-run HR fixture | Scoring engine | Release-blocking correctness |
| RUN-03 | Runs | Bases loaded | Walk or hit | One or more runs scored according to accepted runner outcomes | Approved design requirement | Future bases-loaded scoring fixture | Scoring engine | Release-blocking correctness |
| RUN-04 | Runs | Two outs, runner crossing home | Third-out timing play | Count or reject run according to explicit third-out context; unresolved where policy not defined | Unresolved question | Future third-out run fixture | Scoring engine | Release-blocking correctness |
| RUN-05 | Runs | Stored score differs from event-derived score | Replay/reopen | Disagreement becomes warning, repair, or compatibility classification, not silent truth selection | Approved design requirement | Future mismatch fixture / existing stored-score fixtures | Replay/compatibility | High-risk migration or replay |

Inning, lineup, pitcher, and substitution scenarios:

| ID | Category | Initial state | Action | Expected high-level outcome | Classification | Fixture reference | Future test level | Importance |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| INNING-01 | Inning | Top first, two outs | Third out | Bottom first begins, bases clear, home lineup leadoff due | Approved design requirement | Future third-out fixture | Replay | Release-blocking correctness |
| INNING-02 | Inning | Bottom first, two outs | Third out | Top second begins, bases clear, visiting next batter preserved | Approved design requirement | Future inning fixture | Replay | Release-blocking correctness |
| INNING-03 | Inning | End of half inning in legacy rows | Recalculate `endOfInning` | Current code mutates marker from counted outs; rewrite derives marker from replay | Confirmed current repository behavior / approved design requirement | Future marker fixture | Replay/presentation | High-risk migration or replay |
| INNING-04 | Inning | Final scheduled inning complete | Complete game | Completion rule requires lifecycle policy; ordinary completion should not fabricate missing innings | Approved design requirement / unresolved question | `CompletedGame.ScoreKeep_Games` | Lifecycle | Important workflow regression |
| INNING-05 | Inning | Beyond scheduled innings | Continue scoring | Extra innings supported by design; current fixed-size arrays and inning labels are regression risks | Known regression requirement | Future extra-inning fixture | Replay/presentation | Release-blocking correctness |
| LINEUP-01 | Lineup | New game lineup | First scoring open | Leadoff batter for batting side appears in first slot | Confirmed current repository behavior | `MinimalValid.ScoreKeep_Games` / future lineup fixture | UI/domain | Release-blocking correctness |
| LINEUP-02 | Lineup | Last batting slot completed | Next PA | Batter order wraps to first active slot | Approved design requirement | Future wrap fixture | Scoring engine | Release-blocking correctness |
| LINEUP-03 | Lineup | Incomplete lineup | Score attempt | Ready with warning, repair required, or rejected according to explicit readiness policy | Unresolved question | `LineupGame.ScoreKeep_Games` / future incomplete fixture | Validation | Release-blocking correctness |
| LINEUP-04 | Lineup | Duplicate batting-order values | Open or replay | Warn or repair; do not silently choose by mutable roster order alone | Approved design requirement | Future duplicate-lineup fixture | Domain/replay | High-risk migration or replay |
| LINEUP-05 | Lineup | Correction changes earlier batter | Replay | Downstream current batter and scorecard rows recalculate from revised facts | Approved design requirement | Future correction fixture | Correction/replay | Release-blocking correctness |
| PITCHER-01 | Pitcher | One opposing pitcher added before scoring | First PA | Starting pitcher markers initialize to inning 1, 0 outs, 0 batters | Confirmed current repository behavior | `PitcherGame.ScoreKeep_Games` / future live fixture | Pitcher/replay | Important workflow regression |
| PITCHER-02 | Pitcher | Current pitcher active | Strikeout | Strikeout attributed to active pitcher projection where pitcher period covers event | Approved design requirement | Future pitcher event fixture | Pitcher/report | Release-blocking correctness |
| PITCHER-03 | Pitcher | Current pitcher active | Walk or hit | Walks, hits, runs, HR, HBP projections derive from covered at-bats | Confirmed current repository behavior / approved design requirement | `PitcherGame.ScoreKeep_Games` | Pitcher/report | Release-blocking correctness |
| PITCHER-04 | Pitcher | New pitcher added mid-inning | Update markers | Previous pitcher end and new pitcher start use current inning/out/batter context | Confirmed current repository behavior | Future mid-inning pitcher fixture | Pitcher/replay | High-risk migration or replay |
| PITCHER-05 | Pitcher | No pitcher known | Score event | Scoring can continue with unknown pitcher warning where approved; no blank real pitcher fabricated | Approved design requirement | Future unknown-pitcher fixture | Domain/replay | Important workflow regression |
| SUB-01 | Substitution | Starter active, bench player available | Replace player | Current source mutates bat order, appends replaced/incoming, inserts `Pitch Hitter` marker | Confirmed current repository behavior | Future substitution fixture | Compatibility/replay | High-risk migration or replay |
| SUB-02 | Substitution | Substitution before later PA | Replay through substitution | Earlier PAs remain attached to original participant; later PAs use incoming participant | Approved design requirement | Future substitution fixture | Replay/correction | Release-blocking correctness |
| SUB-03 | Substitution | Parallel replaced/incoming arrays mismatch | Import or replay | Warn, repair, or preserve compatibility-only evidence; do not invent pairing | Compatibility obligation | Future malformed substitution fixture | Compatibility/replay | High-risk migration or replay |
| SUB-04 | Substitution | Correction before substitution | Replay | Substitution effective point remains historical unless corrected explicitly | Approved design requirement | Future correction-substitution fixture | Correction/replay | Release-blocking correctness |

Replay, correction, persistence, duplicate, interruption, accessibility, and device scenarios:

| ID | Category | Initial state | Action | Expected high-level outcome | Classification | Fixture reference | Future test level | Importance |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| REPLAY-01 | Replay | Empty initial state | Replay no events | Produces 0-0, top first, 0 outs, empty bases, leadoff due | Approved design requirement | `MinimalValid.ScoreKeep_Games` | Replay | Release-blocking correctness |
| REPLAY-02 | Replay | One single event | Replay | Same score, base state, batter progression, report totals each time | Approved design requirement | `MultipleAtbats.ScoreKeep_Games` | Replay | Release-blocking correctness |
| REPLAY-03 | Replay | Multiple ordered events | Replay | `seq` and inning evidence produce deterministic ordered result or warnings | Compatibility obligation | `MultipleAtbats.ScoreKeep_Games` | Replay/compatibility | High-risk migration or replay |
| REPLAY-04 | Replay | App relaunched after saved game | Reopen | Derived state agrees with saved event history and stored score warning policy | Approved design requirement | `InProgressGame.ScoreKeep_Games` | Persistence/replay | High-risk migration or replay |
| REPLAY-05 | Replay | Invalid event in sequence | Replay | Reject, repair required, or unsupported state; no partial trusted projection | Approved design requirement | Malformed relationship fixtures | Replay/validation | Release-blocking correctness |
| REPLAY-06 | Replay | Long compact sequence | Replay twice | Repeated replay has no side effects and produces same projections | Known regression requirement | Future long-game fixture | Replay/performance | Release-blocking correctness |
| CORRECTION-01 | Correction | Most recent event completed | Edit result | Accepted correction replaces event outcome and downstream projections refresh | Approved design requirement | Future correction fixture | Correction | Release-blocking correctness |
| CORRECTION-02 | Correction | Early event completed | Edit early event | Downstream score, inning, outs, bases, batter, pitcher projections recalculate | Approved design requirement | Future correction fixture | Correction/replay | Release-blocking correctness |
| CORRECTION-03 | Correction | Existing event selected | Delete/remove event | Supported only if correction workflow defines deletion; current row delete is evidence, not approved mechanism | Confirmed current repository behavior / unresolved question | Future correction fixture | Correction | Important workflow regression |
| CORRECTION-04 | Correction | Correction sheet open | Cancel | Last confirmed state remains unchanged; focus and visible context restored later | Approved design requirement | Future correction UI fixture | Application service/UI | Important workflow regression |
| CORRECTION-05 | Correction | Invalid correction requested | Confirm | Reject without partial save or projection mutation | Approved design requirement | Future invalid-correction fixture | Correction/validation | Release-blocking correctness |
| PERSIST-01 | Persistence | Valid scoring command | Save succeeds | Accepted event is durable and replay agrees after reload | Approved design requirement | Future isolated persistence fixture | Persistence | Release-blocking correctness |
| PERSIST-02 | Persistence | Valid command, save fails before acceptance | Save fails | No event accepted; prior state remains usable | Approved design requirement | Future failure harness | Persistence | Release-blocking correctness |
| PERSIST-03 | Persistence | Save outcome uncertain | Relaunch | Last confirmed state identified; no duplicate event after retry | Approved design requirement | Future failure harness | Persistence/app service | Release-blocking correctness |
| PERSIST-04 | Persistence | Baseball scoring action | Complete action | No purchase entitlement or allowance state changes from scoring | Approved design requirement | Future persistence harness | Persistence/purchase separation | Release-blocking correctness |
| DUP-01 | Duplicate input | Same scoring cell/action | Double tap | One accepted event or reopen existing event, not duplicate scoring rows | Known regression requirement | Future duplicate-tap fixture | Application service/UI | Important workflow regression |
| DUP-02 | Duplicate input | Delayed callback repeats | Retry | Same idempotency context resolves to existing result | Proposed verification expectation | Future idempotency fixture | Application service | Important workflow regression |
| DUP-03 | Duplicate input | Rapid different actions | Two separate intents | Accept only valid ordered commands; reject incoherent overlap | Proposed verification expectation | Future rapid-input fixture | Application service | Important workflow regression |
| DUP-04 | Duplicate input | Intentional next batter PA | Second completed PA | Separate plate appearance accepted when context has advanced | Approved design requirement | Future workflow fixture | Scoring engine | Release-blocking correctness |
| INVALID-01 | Invalid state | No active game | Score command | Reject safely, no rows or records mutated | Approved design requirement | Future invalid-state fixture | Application service | Release-blocking correctness |
| INVALID-02 | Invalid state | No current batter or batting team | Score command | Reject or repair required; no guessed player | Approved design requirement | Broken relationship fixtures | Domain/validation | Release-blocking correctness |
| INVALID-03 | Invalid state | Duplicate runner or player on multiple bases | Replay | Reject, repair, or warning-limited; no silent normalization | Approved design requirement | Future base-state fixture | Replay/validation | Release-blocking correctness |
| INVALID-04 | Invalid state | Completed game | New score action | Block or require explicit reopen policy; current behavior unresolved | Unresolved question | `CompletedGame.ScoreKeep_Games` | Lifecycle/UI | Important workflow regression |
| INTERRUPT-01 | Interruption | Count entry in progress | Background/terminate | Last confirmed state preserved; incomplete count recoverable or discarded explicitly | Approved design requirement | Future interruption fixture | Application service | Important workflow regression |
| INTERRUPT-02 | Interruption | Completed PA saving | Background/terminate | Accepted durable event appears once, or prior state remains if not accepted | Approved design requirement | Future persistence harness | Persistence | Release-blocking correctness |
| INTERRUPT-03 | Interruption | Third-out transition pending | Background/resume | Return to last confirmed half-inning state without duplicate transition | Approved design requirement | Future inning interruption fixture | Application service | Release-blocking correctness |
| INTERRUPT-04 | Interruption | Runner-choice or correction sheet open | Background/resume | Pending choice restored, canceled, or explained without partial event | Approved design requirement | Future UI fixture | Application service/UI | Important workflow regression |
| ACCESS-01 | Accessibility | Same valid scoring state | Touch and VoiceOver activate same command | Equivalent validated baseball result and persistence effect | Approved design requirement | Future accessibility live-scoring fixture | Accessibility/UI | Accessibility-critical |
| ACCESS-02 | Accessibility | Same valid scoring state | Keyboard, Switch Control, Voice Control, pointer where supported | Equivalent command outcome; no alternate baseball logic | Approved design requirement | Future accessibility fixture | Accessibility/UI | Accessibility-critical |
| DEVICE-01 | Device class | iPhone compact scoring | Same scoring command | Same baseball result as iPad; layout may differ | Approved design requirement | Future device fixture | UI/scoring | Important workflow regression |
| DEVICE-02 | Device class | iPad regular-width scoring | Portrait/landscape or popover/sheet variant | Same scoring meaning, validation, and saved event | Approved design requirement | Future device fixture | UI/scoring | Important workflow regression |

<!-- MARK: - 7. Detailed Scenario Notes -->
## 7. Detailed Scenario Notes

Baseline scenarios `BASE-01` through `BASE-05` establish the difference between canonical state and derived state. The approved canonical initial state is zero score, first inning, top half, zero outs, empty bases, visiting side batting, and the first eligible visiting batter due up. Current compatibility files do not serialize live count, explicit current batter, explicit current pitcher, base occupancy, completed status, or lifecycle state as first-class game fields, so imported in-progress and completed-like files must be replayed or warning-classified.

Count scenarios `COUNT-01` through `COUNT-05` are intentionally classified as approved requirements or unresolved questions rather than confirmed current behavior. Current source evidence does not show durable ball or strike fields. Later tests should not claim current support for first ball, first strike, full count, foul-ball count behavior, invalid extra ball, or invalid extra strike until an approved scorer represents those states.

Out scenarios `OUT-01` through `OUT-05` combine current source evidence with approved replay requirements. Current code treats `Common.outresults` and `outAt != "Safe"` as out evidence, stores `Atbat.outs`, and recalculates `endOfInning`. The rewrite requirement is stricter: third out must transition the half inning, prevent fourth-out states, preserve batter order, clear bases, and avoid duplicate outs from repeated input.

Hit, walk, and other on-base scenarios `HIT-01` through `OTHER-03` capture supported current result strings without inventing runner advancement. Current code can default batter `maxbase` to first, second, third, or home for supported result strings and counts hits, walks, strikeouts, HBP, fielder's choice, errors, HR, singles, doubles, and triples in reports. Current code does not provide a canonical runner outcome model, so runner movement is a required future boundary rather than an automatic assumption.

Base occupancy and run scenarios `BASEOCC-01` through `RUN-05` are release-blocking because replay, score display, reports, and persistence must agree. Current `maxbase == "Home"` evidence is enough to identify legacy run evidence, but not enough to resolve all runner identities or third-out timing plays. Future executable tests need purpose-built runner-state fixtures because the existing `.ScoreKeep_Games` files do not cover all eight occupied-base combinations.

Inning scenarios `INNING-01` through `INNING-05` preserve current evidence while following approved design. Current source mutates `inning`, `seq`, `col`, `outs`, and `endOfInning` from view-local calculations. Future replay must derive baseball time deterministically and must not depend on fixed-size `colbox`, `batbox`, or finite inning-label assumptions.

Lineup, pitcher, and substitution scenarios `LINEUP-01` through `SUB-04` preserve the current evidence that lineup order is stored partly in player `batOrder`, `Lineup.players`, first-column at-bats, pitcher marker rows, and `Game.replaced`/`Game.incomings`. The approved requirement is that lineup, substitution, and pitcher state become historical facts or compatibility evidence, not mutable presentation shortcuts that rewrite prior plays.

Replay scenarios `REPLAY-01` through `REPLAY-06` assert that event sequence is the future scoring authority. Opening a scorecard, report, or export preview must not repair records automatically. Replaying the same facts repeatedly must produce the same output and no extra side effect.

Correction scenarios `CORRECTION-01` through `CORRECTION-05` distinguish current row editing and deletion evidence from approved correction authority. Current code can mutate or delete `Atbat` rows through a scoring sheet, but future tests should verify an explicit correction workflow with stable event identity, confirmation, cancelation, rejection, downstream recalculation, and unchanged unrelated records.

Persistence, duplicate, invalid-state, interruption, accessibility, and device-class scenarios are mostly approved design requirements or proposed expectations because task 0.13 has not yet established isolated persistence. They are included now as verification requirements so later harnesses can prove no duplicate scoring event, no partial save presented as truth, no purchase/allowance mutation from scoring, no accessibility-specific baseball behavior, and no device-class scoring divergence.

<!-- MARK: - 8. Fixture Mapping and Future Fixture Needs -->
## 8. Fixture Mapping and Future Fixture Needs

Existing `.ScoreKeep_Games` fixture mappings:

| Fixture | Scenario relevance | Limitation |
| --- | --- | --- |
| `MinimalValid.ScoreKeep_Games` | `BASE-01`, `REPLAY-01`, setup and empty-event baseline. | Does not contain lineups for both sides, current batter state, pitcher state, count, or base occupancy. |
| `InProgressGame.ScoreKeep_Games` | `BASE-04`, `WALK-01`, `REPLAY-04`, stored-score and partial-history evidence. | Does not serialize live current count, explicit current batter, explicit current pitcher, or base occupancy as independent fields. |
| `CompletedGame.ScoreKeep_Games` | `BASE-05`, `HIT-02`, `HIT-04`, `RUN-01`, `INNING-04`, completed-like compatibility evidence. | No explicit completed flag; completion is inferred only from stored score, highlights, expected innings, and event evidence. |
| `MultipleAtbats.ScoreKeep_Games` | `OUT-01`, `HIT-01`, `BASEOCC-01`, `REPLAY-02`, `REPLAY-03`, ordering and repeated batter evidence. | Compact event sequence does not cover all runner states, third-out transitions, or long-game boundaries. |
| `LineupGame.ScoreKeep_Games` | `LINEUP-01`, `LINEUP-03`, lineup transport with player list. | Does not include completed scoring through the lineup or substitution timing. |
| `PitcherGame.ScoreKeep_Games` | `PITCHER-01`, `PITCHER-03`, pitcher identity and aggregate evidence. | Pitcher aggregates are serialized, but event attribution and replay-derived responsibility are not fully proven. |
| `MissingOptionalValues.ScoreKeep_Games` | Invalid/missing optional replay and compatibility warning scenarios. | Does not prove current-state reconstruction. |
| `DuplicateConflict.ScoreKeep_Games` | Duplicate game identity, duplicate-prevention, and import conflict setup. | Requires destination state to trigger duplicate behavior. |
| `SeedCompatibility.ScoreKeep_Games` | Seed route and historical compatibility evidence. | Synthetic seed-pattern fixture, not the production seed file. |

Malformed and unsupported fixture mappings:

| Fixture category | Scenario relevance |
| --- | --- |
| Broken at-bat, lineup, and pitcher relationships | `REPLAY-05`, `INVALID-02`, compatibility validation, no unsafe import application. |
| Duplicate at-bat ID and duplicate player ID | Duplicate identity and duplicate-event validation. |
| Conflicting team identity | Team-side identity warnings before replay or import. |
| Unsupported score value and unsupported batting direction | Unsupported semantic value classification. |
| Wrong root, missing required key, wrong type, invalid UUID, invalid date | Decode rejection before persistence or replay. |
| Wrong extension, cross-format, lowercase, and double-extension files | Route classification, not scoring replay inputs. |

Future purpose-built scoring fixtures needed:

| Need | Scenario IDs |
| --- | --- |
| Two-out and third-out transitions for both top and bottom halves | `BASE-03`, `OUT-03`, `INNING-01`, `INNING-02`, `INTERRUPT-03` |
| All eight base-occupancy states with explicit runner identities | `BASEOCC-01` through `BASEOCC-08` |
| Bases-loaded walk, forced movement, and multi-run scoring | `WALK-02`, `RUN-02`, `RUN-03` |
| Third-out run validation and timing-play policy | `RUN-04` |
| Extra-inning and long-game replay | `INNING-05`, `REPLAY-06` |
| Count progression if count becomes supported | `COUNT-01` through `COUNT-05` |
| Correction game with early, recent, invalid, canceled, and repeated correction requests | `CORRECTION-01` through `CORRECTION-05` |
| Pitcher-change-heavy game with mid-inning and between-inning changes | `PITCHER-02` through `PITCHER-05` |
| Substitution-heavy game with ambiguous and corrected substitutions | `SUB-01` through `SUB-04` |
| Persistence failure and interruption harness data | `PERSIST-01` through `PERSIST-04`, `INTERRUPT-01` through `INTERRUPT-04` |
| Duplicate-tap and rapid-input workflow data | `DUP-01` through `DUP-04` |
| Accessibility and device-class scoring scenarios | `ACCESS-01`, `ACCESS-02`, `DEVICE-01`, `DEVICE-02` |

No fixture content was modified or created by this task.

<!-- MARK: - 9. Current Behavior Versus Approved Rewrite Requirements -->
## 9. Current Behavior Versus Approved Rewrite Requirements

Confirmed current behaviors captured:

| Behavior | Evidence |
| --- | --- |
| Scorecard cell tap creates or reopens an `Atbat` for a specific team, player, batting order, and column. | `PlayersToScoreView.doAtbat` |
| Result pickers can set on-base or out results and mutate the same `Atbat`. | `ScoreGameView` |
| Max base values are `No Bases`, `First`, `Second`, `Third`, and `Home`. | `ScoreGameView`, `PlayersToScoreView` |
| Base-path out values are `Safe`, `First`, `Second`, `Third`, and `Home`. | `ScoreGameView` |
| RBI and stolen-base pickers store integer values on the at-bat. | `ScoreGameView` |
| Dropped third strike and error set `earnedRun` false in the current scoring sheet. | `ScoreGameView` |
| Fielding notation can be recorded in `playRec` for selected out contexts. | `ScoreGameView`, `drawAtbatView` |
| Sequence, inning, outs, score boxes, hits, runs, walks, strikeouts, stolen bases, and pitcher markers are recalculated in view code. | `PlayersToScoreView` |
| Deleting or resetting an at-bat is possible in the current sheet, with special first-column behavior. | `ScoreGameView` |
| Replacement workflow mutates player batting orders, appends replacement arrays, and inserts `Pitch Hitter` marker at-bats. | `ReplacementView` |
| Hitting and pitching reports calculate from stored rows and pitcher markers. | `ReportView`, `PitcherRptView` |

Approved rewrite requirements captured:

| Requirement | Source |
| --- | --- |
| One scoring engine derives score, inning, outs, bases, batter, pitcher, lineup, substitutions, reports, and corrections. | Document 19 |
| Recorded facts and derived projections must remain separate. | Documents 18, 19, 20, 22 |
| Replay from ordered events is authoritative for corrections and reports. | Document 19 |
| Corrections replay downstream state and preserve unaffected facts. | Documents 19, 23, 27 |
| Persistence writes complete accepted fact sets or preserve prior usable state. | Documents 20, 23, 27 |
| Duplicate scoring events from repeated taps, retries, and interruptions must be prevented. | Documents 23, 27 |
| Accessibility-equivalent input must produce equivalent baseball outcomes. | Document 27 |
| Device-class presentation may differ but baseball meaning must remain equivalent. | Documents 22, 27 |

Compatibility obligations captured:

| Obligation | Evidence |
| --- | --- |
| Existing `.ScoreKeep_Games` at-bat fields are compatibility evidence. | `CommonData.ShareAtbat`, fixture catalogs |
| Stored `hscore` and `vscore` must be reconciled with replay-derived runs, not silently treated as independent truth. | Documents 18, 19, 20; fixture catalogs |
| Unsupported or ambiguous legacy result strings must be preserved or classified. | Documents 18, 19, 27 |
| Broken relationships and duplicate identifiers must fail safely before persistence. | Malformed fixture catalog |
| Pitcher, lineup, and substitution transport evidence must be classified before migration or replay trust. | Fixture catalogs and Documents 19, 20 |

Known regression expectations captured:

| Risk | Scenario IDs |
| --- | --- |
| Duplicate scoring rows from repeated input | `OUT-05`, `DUP-01`, `DUP-02`, `DUP-03` |
| Fixed-size inning, column, and batting-order assumptions | `INNING-05`, `REPLAY-06`, `DEVICE-01`, `DEVICE-02` |
| Stored score disagreement | `RUN-05`, `REPLAY-04` |
| Sacrifice spelling mismatch | Future sacrifice scenario need; not asserted as current supported spelling beyond source evidence |
| Pitching report disagreement | `PITCHER-02`, `PITCHER-03`, `PITCHER-04` |
| Force-unwrapped or broken imported relationships | `REPLAY-05`, `INVALID-02` |
| View-owned saves and best-effort persistence | `PERSIST-01` through `PERSIST-04` |

<!-- MARK: - 10. Risks and Gaps -->
## 10. Risks and Gaps

Evidence-backed risks:

| Risk | Evidence | Scenario impact |
| --- | --- | --- |
| Scoring logic is distributed through SwiftUI views. | `PlayersToScoreView`, `ScoreGameView`, `EditScoreView`. | Replay, correction, duplicate, persistence, and accessibility scenarios require later service and engine boundaries. |
| Derived and persisted state can disagree. | `Game.hscore`, `Game.vscore`, `Atbat.maxbase`, report calculations, and fixture stored scores. | `RUN-05`, `REPLAY-04`. |
| Saves are best effort and often logged only. | `try? modelContext.save()` and caught print-only failures in scoring and setup paths. | `PERSIST-01` through `PERSIST-04`. |
| Duplicate scoring from repeated taps is not protected by a documented idempotency boundary. | Cell tap and sheet state in `PlayersToScoreView`. | `DUP-01` through `DUP-04`. |
| Replay is not clearly separated from presentation. | Scorecard drawing and sequencing mutate rows and presentation markers. | `REPLAY-01` through `REPLAY-06`. |
| Substitutions are ambiguous. | Parallel `Game.replaced` and `Game.incomings`, `Pitch Hitter` rows, player bat-order mutation. | `SUB-01` through `SUB-04`. |
| Current compatibility files lack live current-state fields. | Game fixture catalog confirms no serialized count, current batter, current pitcher, base occupancy, or completed flag. | `BASE-04`, `BASE-05`, `COUNT-*`. |
| Relationship failures can be unsafe in import paths. | Malformed fixture catalog records broken relationship risks. | `REPLAY-05`, `INVALID-02`. |
| Limited behavioral tests exist. | Document 27 and 28 identify placeholder unit tests and basic UI launch tests. | All future executable-test categories. |
| Fixtures are not executable through isolated persistence yet. | Task 0.13 remains next. | Persistence, import, replay, and correction scenarios cannot be safely executed yet. |
| Pitcher and lineup restoration are incomplete. | Current source uses marker updates and mutable arrays, while compatibility files serialize aggregate and partial lineup evidence. | `LINEUP-*`, `PITCHER-*`. |
| Correction effects are not independently verified. | Current edit/delete behavior exists in UI code, but no explicit replay correction authority exists. | `CORRECTION-*`. |

Gaps that require future fixture or harness work:

| Gap | Required later work |
| --- | --- |
| Full runner identity and all base states | Purpose-built canonical scoring fixtures and engine tests. |
| Count progression | Product decision and durable or projected count representation. |
| Third-out run treatment | Baseball-policy decision and third-out fixtures. |
| Game completion | Lifecycle policy and completion fixtures. |
| Save failure and uncertain save outcome | Isolated persistence harness from task 0.13. |
| Accessibility live scoring | Accessible prepared-state and UI automation scenarios. |
| Device-class consistency | iPhone and iPad scenario execution. |

<!-- MARK: - 11. Unresolved Questions -->
## 11. Unresolved Questions

Unresolved baseball or product questions:

| Question | Affected scenarios |
| --- | --- |
| Exact supported count behavior, including balls, strikes, full count, foul balls, and invalid extra pitch commands. | `COUNT-01` through `COUNT-05` |
| Exact runner-advancement policy for hits, walks, fielder's choice, errors, optional holds, and bases-loaded situations. | `HIT-05`, `WALK-02`, `BASEOCC-*`, `RUN-02`, `RUN-03` |
| Third-out run treatment and scorer override or warning policy. | `RUN-04` |
| Extra-inning behavior and completion readiness for tied or shortened games. | `INNING-04`, `INNING-05` |
| Whether a completed game blocks scoring, supports reopen, or requires explicit lifecycle command. | `BASE-05`, `INVALID-04` |
| Pitcher responsibility for inherited runners, earned/unearned handling, and unknown pitcher state. | `PITCHER-*`, `RUN-*` |
| Error and hit classification beyond current result strings and report counters. | `OTHER-02`, `OTHER-03` |
| Whether sacrifice, fielder's choice, dropped third strike, catcher interference, hit by pitch, and errors are supported in current live scoring, future replay, or compatibility-only contexts. | `OTHER-*`, future sacrifice scenarios |
| Substitution timing, role, pairing, and correction vocabulary. | `SUB-*` |
| Correction command vocabulary: edit, replace, delete, supersede, insert, cancel, and repeat. | `CORRECTION-*` |
| Event identity and idempotency context for repeated scoring or correction requests. | `DUP-*`, `CORRECTION-05` |
| Which current state values are stored facts versus derived projections in future persistence. | `BASE-*`, `REPLAY-*`, `PERSIST-*` |
| Fixture needs for long-game replay and large-lineup verification. | `INNING-05`, `REPLAY-06` |
| Exact current behavior under save failure. | `PERSIST-*` |

No unresolved question is answered by this catalog. Future implementation must resolve them through approved product policy, design update, fixture expectation, or task-specific scope before executable tests assert a concrete pass result.

<!-- MARK: - 12. Verification Readiness Checklist -->
## 12. Verification Readiness Checklist

Task 0.12 completion checks:

| Check | Result |
| --- | --- |
| H1 is exactly `# Scoring Regression Scenario Catalog`. | Yes |
| Every numbered H2 has an immediately preceding HTML MARK comment. | Yes |
| Section numbering is sequential. | Yes |
| Stable scenario identifiers are used. | Yes |
| Each scenario has one primary purpose. | Yes |
| Each scenario identifies evidence classification. | Yes |
| Current behavior and approved future behavior are distinguished. | Yes |
| Unsupported scoring outcomes are not invented as current support. | Yes |
| Initial and expected states are explicit or explicitly unresolved. | Yes |
| Replay and correction scenarios are included. | Yes |
| Persistence, duplicate, interruption, accessibility, and device-class expectations are included. | Yes |
| Existing fixtures are mapped without modification. | Yes |
| Risks and unresolved questions are explicit. | Yes |
| Task 0.13 is recommended unless blocked. | Yes |

Build and test expectation: a full build or test run is not required for this documentation-only task. The current baseline build status from Document 28 records a successful Xcode build at the time that document was written. This catalog does not repair or change build, test, source, fixture, or project behavior.

<!-- MARK: - 13. Recommended Next Catalog Task -->
## 13. Recommended Next Catalog Task

Recommended next task: `0.13 Test persistence isolation setup`.

Why it should follow: the scoring scenarios above require safe execution of accepted events, failed saves, uncertain saves, replay after reload, duplicate prevention, correction, import application, and no-persistence assertions. Without isolated persistence, running these scenarios against production SwiftData routes could mutate user records, duplicate sample data, consume unrelated state, or make fixture verification unsafe. Task 0.13 prepares a controlled persistence environment so later scoring, replay, correction, import, malformed-file, and migration tests can prove unchanged-record guarantees.

Scenarios it will eventually support: roster fixture import and no-persistence assertions from tasks 0.9 and 0.11; game fixture decode and isolated import assertions from task 0.10; malformed relationship rejection from task 0.11; scoring acceptance and save-failure scenarios from this catalog; correction replay; duplicate-event prevention; interruption and resume; stored-score reconciliation; and no purchase or allowance mutation from baseball persistence operations.

Authority it prepares: verification infrastructure for persistence isolation. It prepares tests to prove that future domain, scoring, replay, correction, compatibility, migration, and application-service code can run without mutating user-owned data. It does not introduce production persistence authority and does not route rewritten scoring.

Files or infrastructure it may change: test target files, test persistence setup helpers, SwiftData in-memory or isolated container setup, fixture-loading helpers, and documentation of test-persistence boundaries, as approved by that future task. It may need to inspect schemes and test targets but should not change production routing.

What production behavior it must not change: scoring, replay, correction, persistence routes, migration, import/export, purchase state, allowances, seeded data, StoreKit configuration, project settings, schemes, build configurations, compatibility formats, and existing fixtures unless a future task explicitly authorizes a narrow non-production test-support change.

Recommended following task according to Document 29: `0.14 Controlled date, season, debug, and regression run baseline`.

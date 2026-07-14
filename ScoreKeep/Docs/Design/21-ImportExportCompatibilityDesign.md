# ScoreKeep Technical Design — 21 Import, Export, and Compatibility Design

<!-- MARK: - 1. Purpose -->
## 1. Purpose

Import, export, and compatibility need a dedicated design because they sit at the boundary between user-owned baseball records and untrusted transport data. ScoreKeep already exchanges rosters, games, media, reports, PDFs, downloaded roster files, seeded data, and deep-link state through several current workflows. Those workflows are important product contracts, but they also carry risks: compatibility structs are close to persisted models, imports can match by names, game imports can depend on force-unwrapped references, lineups can lose player lists during export, substitutions are represented through parallel arrays, stored scores can disagree with replayed events, and document-opening routes differ by entry point.

This design defines how the rewritten application should exchange baseball records without allowing file formats, legacy identifiers, generated reports, remote resources, or name-based matches to become competing sources of truth. It builds on the canonical domain model, scoring engine, persistence and migration boundary, functional import/export requirements, media requirements, error and privacy specifications, and the acceptance fixture catalog.

The central goal is that import and export preserve baseball meaning. A compatible file may carry useful evidence, but the canonical record remains the authority after review and persistence. A generated report may communicate a game, but it is not an editable source record. A remote roster may simplify acquisition, but it must still enter the same validation and review workflow as any other untrusted file.

<!-- MARK: - 2. Design Principles -->
## 2. Design Principles

Compatibility files are transport contracts, not the canonical domain model. `.ScoreKeep_Players`, `.ScoreKeep_Games`, `ShareTeam`, `SharePlayer`, `ShareGame`, `ShareAtbat`, `ShareLineup`, and `SharePitcher` describe exchange behavior for released ScoreKeep versions. They do not define the rewritten application's internal baseball truth.

Import is staged, reviewable, and non-destructive until final confirmation. Decoding, classification, compatibility adaptation, validation, conflict analysis, preview, and user resolution must happen before local baseball records change.

Export reads canonical records and must never mutate source records. It may project canonical meaning into an established compatibility format, omit optional unsupported data with warning, or block export when the resulting file would be misleading. It must not repair, merge, rewrite, consume purchase allowances, or change media as a side effect.

Existing `.ScoreKeep_Players` and `.ScoreKeep_Games` behavior remains a compatibility requirement. Valid legacy identifiers should be preserved when safe, but names, team names, dates, locations, and jersey numbers are matching hints rather than reliable identity.

Unsupported data should be handled honestly. Optional future data can be tolerated when omission does not change baseball meaning. Required future data must be rejected when the current app cannot safely understand the record. Legacy values that cannot be mapped safely should be preserved as evidence rather than converted into misleading canonical facts.

File opening, share sheets, website downloads, seeded files, and deep links must route through consistent validation and review behavior. No network, purchase, document, or compatibility failure may damage unrelated local records.

<!-- MARK: - 3. Scope and Responsibilities -->
## 3. Scope and Responsibilities

The import/export subsystem owns source acquisition, file classification, transport decoding, compatibility adaptation, import validation, conflict analysis, preview data, user-selected resolution choices, import-plan creation, export projection, file generation, destination handoff, completion summaries, and compatibility provenance.

Persistence owns coherent reads and writes of accepted canonical records, transaction behavior, migration status, historical snapshots, and recovery after interrupted writes. The scoring engine owns replay, score derivation, lineup progression, runner state, pitcher attribution, score mismatch diagnostics, and reportable projections. The canonical domain model owns baseball identity, game participation, recorded facts, derived state, and historical boundaries.

Reports and PDF generation own visual or printable output derived from canonical records. They do not own game reconstruction. SwiftUI owns presentation, navigation, selection, progress, conflict-review screens, and error display. Purchase services own entitlement state and allowance policy, but they do not own user data. System file interfaces own external document selection, open-in delivery, share destinations, printing, and cancellation signals.

<!-- MARK: - 4. Compatibility Contracts -->
## 4. Compatibility Contracts

Repository evidence identifies these established contracts:

| Contract | Repository evidence | Compatibility meaning |
| --- | --- | --- |
| `.ScoreKeep_Players` | `ScoreKeep/Info.plist`, `ShareContentView.savePlayers`, `DownloadFiles`, `ImportPlayersView`, `ImportService` | JSON roster transport decoded as `[SharePlayer]`; exported and downloaded files use this extension. |
| `.ScoreKeep_Games` | `ScoreKeep/Info.plist`, `ShareContentView.saveGame`, `ScoreKeepApp.SeederView`, `ImportPlayersView`, `ImportService` | JSON game transport decoded as a single `ShareGame`; seeded game uses `seededGame.ScoreKeep_Games`. |
| Players document type | `ScoreKeep/Info.plist` | `ScoreKeep Players`, UTI `com.komakode.scorekeep`, role `Editor`, rank `Owner`, extension `ScoreKeep_Players`. |
| Games document type | `ScoreKeep/Info.plist` | `ScoreKeep Games`, UTI `com.komakode.scorekeep.games`, role `Editor`, rank `Owner`, extension `ScoreKeep_Games`. |
| Additional UTType declaration | `Common/Extensions.swift` | `UTType.myCustomFile` exports `com.komakode.scorekeep.ScoreKeep_Players`, which differs from the plist players UTI and must be treated as compatibility evidence. |
| System open-in | `StartView`, `StartPhoneView`, `ShareContentView`, `ImportPlayersView` | Files with ScoreKeep roster/game extensions route to import review; current matching differs by entry point. |
| Seeded game | `ScoreKeep/Seed/seededGame.ScoreKeep_Games`, `ScoreKeepApp.SeederView` | Bundle seed decoded as one `ShareGame` and imported once with `hasSeededInitialGame`. |
| Website roster manifest | `ShareContentView.getFileNames`, `DownloadFiles.fetchTeamsIndex`, URL inventory | `https://komakode.com/Teams/index.json`, with optional `updated`, `divisions`, and team `name` and `url`. |
| Downloadable roster URLs | `DownloadFiles.downloadFile`, URL inventory | Manifest team URLs must be directly downloadable roster files, usually ending in `.ScoreKeep_Players`. |
| Announcement endpoint | `AnnouncementCenter` | `https://komakode.com/Teams/message.json`, with `messages`, optional `version`, `id`, CTA fields, title, body, start, and end. |
| Deep link | `ScoreKeepApp`, `StartView`, `StartPhoneView`, `ShareContentView` | `scorekeep://share?tab=download&prefill=...` opens the share/download route and may preselect a manifest team. |
| Share-sheet workflows | `ShareContentView`, report views, PDF views | `ShareLink` hands roster files, game files, reports, and PDFs to system destinations without source mutation. |

These are observed contracts. This design does not invent new public extensions, UTIs, URLs, routes, or transport fields.

<!-- MARK: - 5. Transport Model Boundary -->
## 5. Transport Model Boundary

`ShareTeam`, `SharePlayer`, `ShareGame`, `ShareAtbat`, `ShareLineup`, and `SharePitcher` are transport models. They are Codable compatibility shapes used to exchange records with released ScoreKeep files. They should be decoded as evidence, adapted into canonical concepts, validated, and later projected from canonical records during export.

They must not become canonical entities. `SharePlayer.batOrder` is roster or lineup evidence, not permanent batting-order authority. `ShareAtbat.maxbase`, `outAt`, `inning`, `seq`, and `col` are scoring and scorecard evidence, not a full runner model. `ShareGame.hscore` and `vscore` are stored score evidence, not automatically authoritative score. `ShareLineup.players` may be absent because current export can omit player lists. `ShareGame.replaced` and `incomings` are substitution evidence, not complete substitution events.

The adapter boundary protects both sides: legacy files remain readable, and the rewritten model is not weakened to fit every legacy ambiguity.

<!-- MARK: - 6. Import Architecture -->
## 6. Import Architecture

Import follows a staged conceptual pipeline:

1. Source acquisition receives a file, download, seed resource, or deep-link-selected source.
2. File classification identifies candidate roster, game, generated output, wrong type, future format, or corrupted content.
3. Decode reads the transport structure without creating or updating local records.
4. Compatibility adaptation converts transport fields into canonical evidence and preserves raw legacy values where needed.
5. Validation checks baseball meaning, required references, media, identities, scoring evidence, lineups, substitutions, pitchers, and future-version requirements.
6. Conflict analysis compares incoming evidence with local records using confidence-based matching.
7. Preview presents incoming records, warnings, conflicts, and proposed effects.
8. User resolution records explicit choices for ambiguous matches and conflicts.
9. Persistence planning produces a complete import plan before confirmation.
10. Final confirmation applies the plan coherently or leaves prior state usable.
11. Completion summary explains created, updated, skipped, detached, warned, rejected, or unresolved records.

No stage before final confirmation may perform a permanent baseball-data write.

<!-- MARK: - 7. Import Stages and State Model -->
## 7. Import Stages and State Model

Observable import states should include selected, accessed, classified, decoded, adapted, validated, awaiting review, awaiting conflict resolution, ready to apply, applying, completed, completed with warnings, canceled, failed safely, and recovery required.

Selected means the app knows the source the user chose or received. Accessed means the app has permission or local availability sufficient to read it. Classified means the app has determined candidate file family. Decoded means the transport structure has been read. Adapted means compatibility evidence has been mapped into canonical import evidence. Validated means baseball and safety checks are complete. Awaiting review or conflict resolution means no permanent write has occurred. Ready to apply means the plan is complete and awaiting final confirmation.

Applying is the only state that may write local records. Completed and completed with warnings must describe what changed. Canceled and failed safely must leave local records unchanged unless the user had already confirmed a coherent plan that completed partially under an explicitly safe partial-import policy. Recovery required means the app must present a usable prior state plus the affected import status.

<!-- MARK: - 8. File Acquisition and Document Opening -->
## 8. File Acquisition and Document Opening

Files may arrive from Files, Mail, Messages, Safari, AirDrop, system document picker, another application, local Documents storage after download, or bundled seed resources. Every external source is untrusted until validated. The same source file should enter the same classification, decode, review, conflict, confirmation, and completion behavior regardless of entry point.

Security-scoped external access is an acquisition concern, not a baseball rule. If scoped access is denied, expires, or the file disappears, the import fails safely before records change. If a file can be copied into an app-controlled temporary review area without changing records, the review may continue from that copy while retaining source identity only at a privacy-conscious level.

System open-in delivery should distinguish custom `scorekeep` URLs from file URLs. Deep links route to navigation or prefill state. File URLs route to import review only after extension and content checks. Neither route may bypass validation or confirmation.

<!-- MARK: - 9. File Classification and Type Validation -->
## 9. File Classification and Type Validation

Classification considers extension, declared document type, apparent content, root JSON shape, required transport keys, media fields, and compatibility version evidence when available. Extension alone is not enough. A wrong extension with valid ScoreKeep content can be offered for cautious import with warning when the user clearly selected it. A valid extension with invalid content must be rejected or held for repair before any write.

Roster detection expects `.ScoreKeep_Players` content compatible with `[SharePlayer]`. Game detection expects `.ScoreKeep_Games` content compatible with a single `ShareGame`. A file that looks like website HTML, a server error page, an empty file, truncated JSON, unrelated JSON, a generated report, or a PDF is not source baseball data.

Future files should be classified by whether unsupported content is optional or required. Optional unknown fields can be preserved or ignored when supported meaning is intact. Required unknown structure must block import because the app cannot safely understand the baseball record.

<!-- MARK: - 10. Roster Import Mapping -->
## 10. Roster Import Mapping

Roster import maps transport team and player evidence into canonical reusable teams and reusable players. A valid incoming identifier may support matching when it is syntactically valid and consistent with the visible record. Missing identity creates detached incoming records for review rather than forcing name-based merging.

Names, jersey numbers, positions, batting direction, batting order, media, team names, and coach/details are matching hints. Duplicate names and duplicate numbers are normal and require preservation or user choice. A matching hint can increase confidence, but it cannot authorize destructive update.

Media maps as optional evidence attached to incoming team or player records. Missing media is normal. Corrupted or oversized media can be skipped with warning when roster meaning remains understandable. Batting information and active or inactive state should be preserved where supported, but incomplete optional fields should not block import.

Incoming records remain detached until the import plan states whether they create new reusable records, update selected local records, stay compatibility-only, or are skipped. Updating current roster values must not silently alter historical game participants.

<!-- MARK: - 11. Game Import Mapping -->
## 11. Game Import Mapping

Game import maps a full game file into canonical game identity, game sides, game-time snapshots, participants, lineups, substitutions, pitcher appearances, scoring events, runner evidence, stored scores, lifecycle state, provenance, and warnings.

The game's reusable team and player relationships are optional outcomes of review. The game must remain understandable even when incoming sides or participants cannot safely attach to local reusable records. Game-time snapshots preserve team names, player names, numbers, positions, batting direction, side roles, and media context needed for historical review.

Scoring events are the core imported facts. They should map from `ShareAtbat` values into recorded scoring-event evidence where supported, with legacy result strings, destinations, outs, RBIs, stolen bases, earned-run decisions, inning, sequence, column, notes, and end-of-inning markers preserved. Stored `hscore` and `vscore` are compared with replay-derived score and classified as agreement, mismatch, incomplete-event evidence, or possible reviewed final score.

Lifecycle state should distinguish draft, in-progress, interrupted, completed, imported historical, and compatibility-limited games where evidence allows. Import must not mark an incomplete game final or invent missing events just to reconcile totals.

<!-- MARK: - 12. Compatibility Interpretation -->
## 12. Compatibility Interpretation

`ShareTeam` preserves team name, coach, details, nested players, nested games where present, logo, and legacy identifier evidence. In a roster file it primarily represents reusable team evidence. In a game file it also represents game-side evidence.

`SharePlayer` preserves player name, number, position, batting direction, batting order, team reference, nested at-bats, photo, and legacy identifier evidence. In a roster file it maps to reusable player evidence. In a game file it may map to a game participant, reusable player hint, pitcher, substitute, runner, or lineup occupant.

`ShareGame` preserves date, location, highlights, stored scores, Everyone Hits flag, inning count, home and visiting teams, players, at-bats, lineups, pitchers, replaced players, and incoming players. It is the game transport envelope.

`ShareAtbat` preserves result, `maxbase`, `outAt`, inning, sequence, scorecard column, RBIs, outs, sacrifice markers, stolen bases, earned-run flag, notes or play record, and end-of-inning state. Legacy result strings, including the `Sacrifise` spelling, must be preserved while mapping to supported categories where clear.

`ShareLineup` preserves Everyone Hits, team, inning, and player list when present. Missing players must produce lineup warnings rather than invented membership.

`SharePitcher` preserves pitcher, team, game evidence, start and end inning/out/batter markers, strikeouts, walks, hits, runs, and win flag. Appearance boundaries are evidence; aggregate totals are derived or compatibility evidence.

`maxbase`, `outAt`, inning values, sequence, columns, `hscore`, `vscore`, `replaced`, and `incomings` are interpreted conservatively. They can support canonical reconstruction when coherent and must remain warnings, repair inputs, or compatibility evidence when ambiguous.

<!-- MARK: - 13. Identity Matching and Duplicate Detection -->
## 13. Identity Matching and Duplicate Detection

Identity matching uses layered evidence and confidence. Strong evidence includes valid preserved legacy identifiers that do not collide, explicit canonical identity where available, and exact provenance from a known prior export. Moderate evidence includes same selected local record during user-driven update, same team context plus consistent player attributes, or same game file provenance. Weak evidence includes names, team names, dates, locations, jersey numbers, score, batting order, photos, or logo similarity.

Automatic destructive merging is allowed only for exact compatible identity with no conflicting meaning. Likely matches require review. Ambiguous matches require explicit choice. Conflicting matches must preserve both sides until resolved.

Teams with the same name, players with the same name, reused jersey numbers, renamed records, doubleheaders, same-team same-date games, imported identifiers, detached participants, and historical games all require duplicate detection that helps the user without collapsing identity. A doubleheader is not a duplicate merely because teams and dates match. An imported game is not the same game merely because the score and location match.

<!-- MARK: - 14. Conflict Model -->
## 14. Conflict Model

Conflict categories include exact compatible identity, likely match, ambiguous match, conflicting values, duplicate incoming record, duplicate local record, missing reference, unsupported value, media conflict, score mismatch, lineup conflict, substitution conflict, and pitcher conflict.

An exact compatible identity has strong matching evidence and no baseball disagreement. A likely match has enough evidence to suggest a relationship but still needs user confirmation before update. An ambiguous match has multiple plausible targets or insufficient evidence. Conflicting values occur when the same intended record has different names, numbers, batting details, media, team assignment, date, location, score, or game history.

Missing references, unsupported values, score mismatches, lineup conflicts, substitution conflicts, and pitcher conflicts are baseball-integrity conflicts. They may prevent trusted replay or export even when the file decodes correctly.

<!-- MARK: - 15. Conflict Resolution Plan -->
## 15. Conflict Resolution Plan

Resolution choices are conceptual and should fit the affected record. Choices include use existing record, create separate record, keep current values, apply incoming values, select values individually, skip record, preserve detached historical participant, mark compatibility-only, repair required evidence, or cancel import.

Roster conflicts can choose current or incoming values for names, numbers, positions, batting information, photos, logos, coach/details, and membership. Game conflicts can choose whether teams and participants attach to local reusable records or remain game-specific historical participants. Score, lineup, substitution, and pitcher conflicts may require preserving the game with warnings or rejecting the import if safe meaning cannot be maintained.

Every resolution selection becomes part of an explicit import plan. The plan must show intended changes before persistence.

<!-- MARK: - 16. Import Plan -->
## 16. Import Plan

The import plan is the reviewable record of intended changes. It lists records to create, update, preserve, skip, detach, repair, warn about, reject, or mark compatibility-only. It identifies affected teams, players, games, media, lineups, substitutions, pitchers, scoring events, provenance, and warnings.

The plan should distinguish local record updates from game-specific historical preservation. It should identify whether imported media will be attached, skipped, or left for later replacement. It should identify whether stored scores are accepted as agreement, preserved as mismatch evidence, or blocked pending repair.

The plan must be complete before confirmation. If the plan cannot identify all intended changes, import is not ready to apply.

<!-- MARK: - 17. Import Transaction Boundary -->
## 17. Import Transaction Boundary

Cancellation before final confirmation leaves local records unchanged. A confirmed import should apply coherently from the user's perspective or preserve a usable prior state.

For a roster, coherent application means accepted teams, players, roster membership, media choices, and provenance are applied together. For a game, coherent application means game identity, sides, participants, lineups, substitutions, pitchers, scoring events, stored-score evidence, media decisions, and warnings are preserved together. A game must not be created without enough context to identify its teams and participants unless it is explicitly marked review-required or compatibility-only.

If storage fails, the completion state must not imply success. Recovery should identify whether no changes occurred, the plan completed, or a limited safe partial import occurred under the partial-import policy.

<!-- MARK: - 18. Partial Import Policy -->
## 18. Partial Import Policy

Partial import is safe when omitted content is optional or explicitly skipped and the remaining record is not misleading. Examples include skipping corrupted optional media, omitting an optional note, skipping an unwanted player from a roster after review, or importing a historical game with preserved warning that an optional future field was ignored.

Partial import requires warnings when the result is usable but limited, such as unknown pitcher, incomplete lineup, unsupported optional result evidence, missing media, or stored-score mismatch with otherwise coherent events.

Partial import must be rejected when the resulting baseball record would be misleading. Examples include a game with scoring events attached to unresolved participants, a third-team reference that cannot be reconciled, a lineup that would falsely identify batters, substitutions that would rewrite historical participation, or unsupported required future structure.

<!-- MARK: - 19. Import Provenance -->
## 19. Import Provenance

Import should retain privacy-conscious provenance and compatibility evidence. Useful evidence includes visible file name, format family, extension, declared document type where available, source category, import date, interpretation version, compatibility adapter version, original legacy identifiers, warning classifications, conflict choices, and imported-history status.

Provenance should avoid unnecessary personal or filesystem details. Full local paths, unrelated directory names, account identifiers, network request metadata, and private support details are not needed for ordinary record understanding.

Provenance is not authority by itself. It explains where evidence came from, how it was interpreted, and what warnings or choices affect later reports, exports, migration, and support.

<!-- MARK: - 20. Export Architecture -->
## 20. Export Architecture

Export follows a separate pipeline: source selection, canonical record load, validation, compatibility projection, user-visible scope review, file generation, destination handoff, and completion or cancellation.

Source selection identifies the roster, game, report, or PDF scope. Canonical load retrieves the authoritative record and compatibility evidence needed for projection. Validation checks whether the selected record can be exported without misleading meaning. Compatibility projection maps canonical data into `.ScoreKeep_Players`, `.ScoreKeep_Games`, or generated output. Scope review confirms what will be included, especially media and historical records. File generation creates output without source mutation. Destination handoff uses system sharing or file interfaces. Completion reports success, cancellation, or destination failure.

Export must not change source teams, players, games, media, stored scores, provenance, purchase state, or migration warnings.

<!-- MARK: - 21. Roster Export Mapping -->
## 21. Roster Export Mapping

Roster export maps selected canonical teams and players into compatible roster files. The current contract writes a `.ScoreKeep_Players` file containing JSON compatible with `[SharePlayer]`, where each player can carry nested team evidence.

Export should preserve identity evidence when supported by existing fields and retain original compatibility identifiers when safe. Required legacy fields should be populated from canonical records or compatible preserved evidence. Optional details include team coach/details, player number, position, batting direction, batting order or roster lineup hint, photo, and logo.

Photos and logos may be included when the selected export scope and media policy allow it. Duplicate player names and duplicate numbers must remain distinct in the exported player list as far as the transport format supports. Nested team structure should remain understandable even where legacy exports use simplified team references.

<!-- MARK: - 22. Game Export Mapping -->
## 22. Game Export Mapping

Game export maps one canonical game into a `.ScoreKeep_Games` file compatible with `ShareGame`. It should include home and visiting teams, participants, game-time snapshots, date, location, highlights, inning count, Everyone Hits, lineups, substitutions, pitchers, scoring events, score evidence, and supported media.

Participants should represent the players needed to understand the game at game time, not merely the current roster after later edits. Lineups should preserve starting order and available player lists where supported. Substitutions should preserve incoming and outgoing evidence, timing where available, role where known, and warnings where legacy fields cannot express full meaning.

Scoring events should preserve inning and sequence meaning, result strings, destinations, outs, RBIs, steals, earned-run decisions, scorecard columns, notes, and unsupported values as compatibility evidence. Interrupted or incomplete games should export their status or warnings where supported rather than forcing completion.

<!-- MARK: - 23. Legacy Field Preservation -->
## 23. Legacy Field Preservation

Required compatibility fields should be preserved when original values remain safe and meaningful. When a canonical record was imported from a legacy file, exporting back to the same compatibility family should prefer preserved legacy evidence for fields that cannot be regenerated exactly, provided doing so does not contradict the accepted canonical meaning.

Generated compatibility values are appropriate when the canonical record has clear meaning and the legacy field is required. Optional unsupported fields may be omitted when omission does not alter supported baseball meaning. Export should block when a required field cannot be populated without inventing misleading data.

This design does not add new file fields. Future metadata, version markers, or compatibility annotations may be considered later, but any new field must be additive and explicitly version-aware.

<!-- MARK: - 24. Lineup Round-Trip Design -->
## 24. Lineup Round-Trip Design

The fixture catalog identifies a known issue: exported lineup player lists can be lost. Round-trip meaning requires that a game exported with complete lineups can be reimported with the batting order, Everyone Hits setting, team association, lineup inning, and lineup participants still understandable.

When canonical lineup membership is known, export should include the player list in the compatible `ShareLineup` evidence rather than exporting only team and inning. When a legacy imported lineup lacks players, import should preserve the missing-list warning and must not invent membership from current roster order. Exporting such a record may preserve the warning or compatibility evidence, but it should not create false certainty.

Lineup reconstruction should use explicit lineup facts first, then scoring-event participation as evidence, and only then matching hints. If evidence remains incomplete, the record is usable with warnings or blocked from trusted export depending on the selected export purpose.

<!-- MARK: - 25. Substitution Round-Trip Design -->
## 25. Substitution Round-Trip Design

Legacy substitution transport uses parallel `replaced` and `incomings` arrays. These arrays can preserve outgoing and incoming participants but may not preserve timing, role, batting slot, base-running context, or exact pairing when counts differ.

Exact round trip is possible when canonical substitution facts can be projected into paired outgoing and incoming arrays without ambiguity and when timing is represented elsewhere in compatible scoring or lineup evidence. Compatibility evidence is required when the legacy arrays came from an imported file and exact timing or role was not known.

Ambiguous substitutions should produce warnings. Export must not present an inferred substitution as verified when incoming and outgoing participants, side, effective point, role, or slot cannot be identified safely. Such substitutions may be preserved as compatibility-only evidence or require user repair before full-game export.

<!-- MARK: - 26. Pitcher Round-Trip Design -->
## 26. Pitcher Round-Trip Design

Pitcher export and import must preserve pitcher appearance boundaries: pitcher participant, defensive team, start inning, start outs, start batter marker, end inning, end outs, end batter marker, unknown pitcher states, aggregate compatibility fields, and win marker where supported.

Derived pitching statistics should come from scoring-engine replay when canonical events and appearance boundaries are coherent. Legacy aggregate values such as strikeouts, walks, hits, and runs can be preserved as compatibility evidence, especially when event history is incomplete.

Unknown pitchers and incomplete histories must remain visible. Export should not attach a pitching period to the wrong player merely to satisfy the transport shape. If a pitcher period cannot be expressed without losing meaning, export should warn, mark limitations, or block depending on impact.

<!-- MARK: - 27. Scoring Event Round-Trip Design -->
## 27. Scoring Event Round-Trip Design

Scoring events must preserve result categories, original legacy strings, `Sacrifise` compatibility, destinations, outs, RBIs, stolen bases, earned-run values, inning, sequence, scorecard columns, notes, runner limitations, unsupported values, and correction history where supported.

Canonical categories should project into legacy result strings only when the mapping is clear. The original legacy string should be retained when it matters for round trip or support. `maxbase` can represent batter destination and legacy run evidence; it cannot represent every runner movement. `outAt` can preserve base-path out evidence but may be insufficient for multiple runner outs. Scorecard columns help display compatibility but should not replace event order.

Unsupported values should not be silently collapsed into ordinary outs, hits, or safe states. They can be exported as preserved legacy evidence when the receiving compatibility contract supports them, or they can block export when no safe representation exists.

<!-- MARK: - 28. Stored Score Export Policy -->
## 28. Stored Score Export Policy

Replay-derived scores are authoritative when scoring events are complete and coherent. Legacy `hscore` and `vscore` are compatibility evidence and may agree with replay, disagree because events are incomplete, or represent a possible user-authored final score.

Export should write score fields from the authoritative reviewed source for the selected game. If replay is complete, exported stored scores should match replay. If events are incomplete but a reviewed stored final score is accepted, export should preserve that score with warnings or provenance where possible. If scores mismatch and no reviewed policy resolves the mismatch, full-game export should warn or block rather than choose silently.

Generated reports and PDFs should identify current derived score meaning but must not update the source game or stored compatibility evidence merely by being generated.

<!-- MARK: - 29. Media Import and Export -->
## 29. Media Import and Export

Photos and logos are optional media. Missing media must not block otherwise valid roster or game import/export. Base64 or binary data in JSON transport should be decoded as untrusted media evidence and validated before display or persistence.

Corrupted, unsupported, or oversized media should be skipped, warned, replaced through user choice, or omitted from export while preserving baseball records. Media conflicts require review when incoming media differs from existing local media or when media would attach to an ambiguous team or player.

Export should make include-media behavior understandable. If media is included, the selected scope should exclude unrelated records. If media is omitted, the exported file remains valid when names and baseball context preserve meaning. Historical media and current media may differ; export should prefer game-time or accepted historical media where that is part of the canonical record, otherwise current media is presentation support rather than identity.

<!-- MARK: - 30. Version Compatibility -->
## 30. Version Compatibility

Older files in newer apps should remain readable when their baseball meaning can be safely understood. Newer files in older apps may fail, so format evolution should preserve established fields and extensions whenever possible.

Additive optional data is preferred. Unsupported optional future data may be preserved or ignored with warning. Unsupported required data must be rejected when the current app cannot safely reconstruct teams, players, game identity, lineups, substitutions, pitchers, scoring events, or scores.

Import and migration should record an interpretation version and compatibility classification. User-facing classifications should distinguish supported, supported with warnings, partially understood, unsupported future file, corrupted file, and unsafe to import. Unknown fields should be preserved where practical without making them canonical.

<!-- MARK: - 31. Future Format Evolution -->
## 31. Future Format Evolution

Format evolution should be additive, version-aware, optional-compatible, and fixture-backed. Existing `.ScoreKeep_Players` and `.ScoreKeep_Games` documents should remain supported unless a future migration deliberately supports both old and new behavior.

Future fields should describe new evidence without changing the meaning of existing fields. New required fields should be introduced only when the app can provide a clear compatibility error for older clients. Migrations should be explicit and should preserve original evidence when practical.

This task does not design a replacement file format. It defines principles for evolving current contracts without breaking existing documents.

<!-- MARK: - 32. Website Roster Download Design -->
## 32. Website Roster Download Design

The website roster workflow starts with the roster manifest at `https://komakode.com/Teams/index.json`. The current expected manifest contains optional `updated`, `divisions`, and teams with `name` and `url`. The visible team selection should use manifest names, display freshness when available, and preserve a stable mapping from selected name to direct roster URL.

Downloading retrieves the selected direct URL, saves a local `.ScoreKeep_Players` file, validates that the response is a compatible roster file, and routes it into roster import review. A response that is HTML, an error page, wrong content, truncated data, or a non-roster file must fail before local records change.

Offline and retry behavior should preserve selected team context and avoid consuming allowances or showing success until a compatible file is available for review. Remote content can change, so release verification should use pinned local compatibility fixtures while also checking the live manifest contract separately.

<!-- MARK: - 33. Deep-Link Design -->
## 33. Deep-Link Design

The established route is `scorekeep://share?tab=download&prefill=...`. It should open the share/download workflow, activate the Download MLB Teams tab, and optionally preselect a manifest team when the prefill value matches an available manifest name.

Malformed parameters, unsupported hosts, unsupported tabs, missing prefill values, and unavailable manifest teams should fail safely or open the download workflow without automatic import. iPhone and iPad should route consistently through the shared router behavior.

Deep links never bypass import review or confirmation. A deep link may navigate, prefill, or start visible download selection. It must not silently download, import, overwrite, purchase, share, or delete records.

<!-- MARK: - 34. Sharing and System Handoff -->
## 34. Sharing and System Handoff

Share sheet, Files, Mail, Messages, AirDrop, print, and PDF destinations are external handoff mechanisms. ScoreKeep prepares the selected output, identifies scope, and gives the item to the system. The destination decides whether the user completes, cancels, or fails the handoff.

Cancellation is not an error and must leave source records unchanged. Destination failure should identify that output was not delivered or saved while preserving source records and export scope for retry or alternate destination.

Source context should be preserved after handoff. Returning from a share, save, print, or PDF workflow should return to the selected roster, game, report, or export scope without implying that files already shared outside the app can be recalled by later local edits.

<!-- MARK: - 35. Generated Reports and PDFs -->
## 35. Generated Reports and PDFs

Reports and PDFs derive from canonical records. They are generated output for review, printing, sharing, and archiving. They are not authoritative source records for game reconstruction unless a future specification explicitly adds such support.

Report and PDF export should use current canonical projections and selected scope. It should respect privacy, media inclusion, stale-output behavior, and failure recovery. Regenerating a report after corrections should reflect current saved facts, but older shared output remains outside the app.

Importing a PDF or generated report as a roster or game should be rejected as wrong source type. A future optical or structured report import would require a separate design because it would create new reconstruction risks.

<!-- MARK: - 36. Purchase and Ownership Boundary -->
## 36. Purchase and Ownership Boundary

Import and export of compatible user-owned source data remain separate from premium ownership. Opening, reviewing, importing, correcting, preserving, and exporting supported `.ScoreKeep_Players` and `.ScoreKeep_Games` data should remain available according to the functional specifications regardless of active premium status.

Premium may gate network conveniences, expanded report generation, PDFs, or allowance-sensitive downloads where specified. Failed downloads, invalid downloaded files, canceled imports, failed exports, and purchase uncertainty must not consume allowances or alter baseball records.

Purchase state must never delete, hide, rewrite, or claim ownership of local teams, players, games, media, imports, exports, or compatibility evidence.

<!-- MARK: - 37. Security and Privacy -->
## 37. Security and Privacy

All imported files, downloaded rosters, deep-link parameters, and shared files are untrusted. Validation must protect against malformed content, hostile structure, oversized media, unsupported future data, duplicate identities, missing references, and attempts to bypass review.

ScoreKeep records may contain youth-player names, numbers, photos, team logos, locations, notes, and game history. Sharing must be deliberate and scoped. Export must include only selected records and selected media behavior. Import previews and support diagnostics should avoid exposing unrelated teams, players, photos, logos, purchase details, or full filesystem paths.

No unnecessary upload should occur. Website downloads and announcements are network conveniences, not prerequisites for local import/export. Support diagnostics should be scoped summaries unless the user voluntarily shares a file.

<!-- MARK: - 38. Error and Recovery Model -->
## 38. Error and Recovery Model

Errors include wrong type, corrupted file, unsupported future file, missing file, permission denial, file disappearing, interrupted import, interrupted export, failed write, failed destination, invalid manifest, network failure, app termination, retry exhaustion, invalid media, and unsafe compatibility evidence.

Before confirmation, failures leave local records unchanged and preserve review context where practical. After confirmation, failures must either leave the prior state usable or report a coherent safe partial outcome under the partial-import policy. Failed export and share never alter source records.

Retry is appropriate only when it cannot create duplicate imports, duplicate exports, repeated allowance consumption, or contradictory state. Recovery should offer product-language actions such as choose another file, retry download, keep current values, skip record, cancel import, return to game, or contact support with scoped details.

<!-- MARK: - 39. Determinism and Repeatability -->
## 39. Determinism and Repeatability

The same canonical record and compatibility policy should produce the same export meaning. File names may include user-facing labels, but the baseball content should not depend on current screen, current sort order, network state, purchase status, or incidental fetch order.

The same incoming file, local state, and selected conflict choices should produce the same import plan. Matching should be deterministic for identical evidence and should classify ambiguity rather than relying on nondeterministic list order.

Determinism supports fixture verification, support diagnostics, round-trip testing, and safe retry after interruption.

<!-- MARK: - 40. Performance and Scale -->
## 40. Performance and Scale

Large rosters, large games, long histories, many substitutions, many pitchers, extra innings, and large media must remain reviewable. Longer operations should show progress, allow cancellation before confirmation where safe, and avoid blocking unrelated local work.

Validation should prevent duplicate records and repeated work without relying on expensive global scans for every row. Media processing should be bounded so optional photos and logos do not make baseball facts unusable.

Network retries should be bounded. Import and export should avoid holding broad locks on unrelated records. Optimization must not weaken correctness, provenance, or transaction recovery.

<!-- MARK: - 41. Verification Strategy -->
## 41. Verification Strategy

Verification maps directly to the fixture and regression catalog. Required coverage includes valid roster, full roster with media, duplicate names, duplicate numbers, malformed roster, regulation game, in-progress game, extra-inning game, substitution-heavy game, pitcher-heavy game, missing lineup players, missing participant, third-team reference, score mismatch, invalid media, unsupported result, `Sacrifise`, duplicate game, doubleheader, round-trip export, document opening, deep links, website downloads, interrupted import/export, and seeded game.

Each fixture should verify decode, classification, warnings, conflict choices, import plan, applied result, export projection, round trip where applicable, and source-record preservation. Document-opening fixtures should verify extension and declared type behavior. Website fixtures should include pinned local copies of downloaded rosters plus live manifest contract checks. Seeded game verification should preserve `ScoreKeep/Seed/seededGame.ScoreKeep_Games` and compare import/export meaning without modifying the fixture.

Acceptance evidence should compare canonical meaning, scoring-engine replay, reports, exported files, imported result, and warnings.

<!-- MARK: - 42. Migration and Coexistence -->
## 42. Migration and Coexistence

Compatibility adapters can support legacy files while new canonical import/export paths are introduced incrementally. Early phases may decode existing `Share*` transport and adapt to canonical evidence without changing persisted records. Later phases can route import review, conflict resolution, and export projection through the canonical path after fixture acceptance.

Uncontrolled duplicate writers must be avoided. A workflow should have one accepted import writer and one accepted export interpretation for each file family. Legacy `ImportPlayersView` behavior and newer `ImportService` behavior should not both remain active for the same confirmed write without an explicit routing and verification policy.

Legacy paths should be retired only after the canonical path preserves supported behavior, warnings, document opening, website downloads, seeded data, and round-trip export.

<!-- MARK: - 43. Risks and Open Questions -->
## 43. Risks and Open Questions

Open questions remain around whether formats need explicit version metadata, how much unknown future-field preservation is practical, exact repair-versus-reject policy, unsupported result round trips, user-authored final scores, lineup reconstruction, substitution reconstruction, pitcher responsibility, media inclusion choices, legacy identifier collisions, exact canonical fixture ownership, and whether live remote files are pinned for release verification.

Additional risks include the plist and `Extensions.swift` UTI mismatch, duplicated deep-link parsing, different file-extension checks across iPhone, iPad, and share workflows, current name-based import matching, older force-unwrapped game import code, and current lineup export that can omit `ShareLineup.players`.

These issues should be resolved through focused implementation tasks, fixture creation, and acceptance evidence rather than by weakening the canonical model.

<!-- MARK: - 44. Success Criteria -->
## 44. Success Criteria

The design succeeds when compatible files remain readable, exports preserve supported baseball meaning, imports are reviewable and non-destructive until confirmation, generated output remains derived rather than authoritative, and transport models stay outside canonical truth.

A successful architecture protects duplicate names, reused numbers, doubleheaders, media conflicts, unsupported legacy values, future files, malformed files, website failures, deep-link mistakes, share cancellations, and purchase uncertainty without damaging unrelated local records.

Round-trip compatibility should preserve supported roster and game meaning. Verification should prove document opening, website downloads, seeded game behavior, import plans, export projections, reports, and recovery behavior are consistent with Documents 17 through 20 and the functional and verification specifications.

<!-- MARK: - 45. Recommended Next Design Document -->
## 45. Recommended Next Design Document

The recommended next design document is `22-ScorecardPresentationDesign.md`.

Documents 18 through 21 establish canonical baseball meaning, scoring-engine replay, persistence and migration boundaries, and import/export compatibility. Scorecard presentation should follow because it is the next major consumer of the same authoritative game state. It needs to define how replayed events, lineups, substitutions, pitcher changes, runner outcomes, warnings, corrections, generated PDFs, and legacy scorecard columns become a coherent live, historical, printed, and accessible scorecard without creating another source of baseball truth.

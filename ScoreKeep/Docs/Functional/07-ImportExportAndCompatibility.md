# ScoreKeep Functional Specification — 07 Import, Export, and Compatibility

## 1. Overview

Import, export, sharing, opening, and compatibility describe how ScoreKeep moves roster, game, and generated output between devices, users, application versions, and supported external sources. These capabilities let users preserve their baseball records, share team information, exchange scored games, open files received from others, download supported roster data, and keep existing ScoreKeep files useful over time.

These workflows must protect the user's local records. Receiving or selecting a file should not automatically change saved teams, players, games, lineups, substitutions, pitcher participation, scoring events, photos, logos, reports, or historical data. Imported data should become permanent only after the user has enough information to understand what will be created, updated, skipped, or left unresolved.

Export and sharing are non-destructive. A user should be able to create a roster file, game file, report, or PDF without changing the source records. Exported output should preserve compatible meaning so that another ScoreKeep user, another device, or a future version of the app can understand the baseball record as well as the supported format allows.

Compatibility is a product requirement, not an implementation detail. Existing ScoreKeep roster files, game files, document-opening behavior, deep links, website-hosted roster downloads, and user expectations around shared files should remain stable unless a future migration explicitly supports both old and new behavior.

## 2. Compatibility Principles

Existing compatible ScoreKeep files should remain readable whenever their contents can be safely understood. Users may have roster files, full game files, generated output, or historical exports created by earlier versions of the application, and those records should not become unusable simply because the app has evolved.

Older data should be preserved whenever it can be interpreted without misleading the user. When a file contains supported teams, players, scoring events, lineups, substitutions, pitcher history, photos, logos, or notes, ScoreKeep should retain that meaning through import, review, reporting, and later export where supported.

Unsupported content should be identified rather than silently discarded when the omission affects user understanding. If a file contains newer, older, incomplete, or inconsistent information that the current app cannot fully use, the user should be told what can be imported, what cannot be imported, and how the imported record may differ from the source.

Import must never silently damage local records. It must not merge unrelated teams, overwrite player details, replace photos, remove roster entries, attach a game to the wrong team, or alter historical records without explicit user confirmation.

Export must never alter the source data. Creating a shareable file, report, PDF, or generated output should not change local teams, players, games, scoring records, statistics, purchase state, or import history.

Compatibility behavior should remain predictable across application versions. Existing document extensions, file-opening workflows, supported URL routes, and website download contracts should continue to work. If new formats or routes are added, they should be additive and should not remove support for established ScoreKeep files.

User ownership of existing data takes priority over premium restrictions. Premium gating may limit creation of new gated output or network-dependent conveniences, but it must not prevent users from opening, reviewing, correcting, importing, exporting, or preserving their own existing compatible ScoreKeep records when those records are otherwise supported.

## 3. Supported Data Types

Team and player roster files represent portable roster information. They help a user move a team and its players to another device, send a lineup or roster to another ScoreKeep user, import downloaded roster data, or preserve a roster for later reuse. Roster files should preserve meaningful team and player identity, visible roster details, photos, logos, and compatibility with established ScoreKeep roster-sharing behavior.

Full game files represent a scored or partially scored baseball game. They may include teams, players, lineups, substitutions, pitcher participation, scoring events, game details, and historical context needed to review or continue the game. A game file should be treated as a baseball record, not merely as a list of teams and players.

Generated reports summarize saved game or roster data for review. They may include scorecards, batting summaries, pitching summaries, box-score style information, or other report views. Reports are generated output and must not be treated as the authoritative source for later import unless a future feature explicitly supports that behavior.

PDF output is a shareable or printable representation of a saved report, scorecard, or supported documentation. A PDF should reflect the saved source data at the time it is generated. Importing a PDF should not be expected to reconstruct a full ScoreKeep game or roster unless a future specification defines that capability.

Downloaded roster files are compatible roster files obtained through the supported KomaKode roster-download workflow. They should be handled like other compatible roster imports while preserving the established website download expectations and existing roster-file extension behavior.

Imported historical records are files created by older ScoreKeep versions or by earlier exports from the same user. They should remain understandable after import, even when the current application supports newer workflows or detects incomplete legacy data.

Deep-link navigation may open an import, sharing, or roster-download workflow when the link uses a supported ScoreKeep route. Deep links should guide the user to the intended workflow but should not bypass validation, review, conflict resolution, or final confirmation.

## 4. Import Sources

A user may import compatible ScoreKeep data by selecting a file from the system document picker. The document picker should accept supported ScoreKeep roster and game files and should reject or explain unsupported file types before local records are changed.

A user may open a compatible file from Mail, Messages, Files, Safari, or another application. When ScoreKeep is launched from such a file, it should route the user into the same import review workflow used by files selected from inside the app.

Shared files received from another ScoreKeep user should be treated as untrusted until validated. The sender may have a different app version, edited data, duplicate names, incomplete games, or unsupported content. Import review should make the proposed effect clear before anything is saved.

Downloaded MLB roster files should enter the roster import workflow after the selected file is downloaded and validated. The fact that a file came from the supported website does not remove the need to protect local data or resolve conflicts.

Bundled sample or seed data should be treated as compatible ScoreKeep data. First-run or sample import behavior should not overwrite user-created records unintentionally, and repeated attempts to load the same sample should avoid accidental duplicates.

Compatible game files should open into a game import review workflow. A game import should preserve game history, teams, players, lineups, substitutions, pitchers, scoring events, and reportable statistics where supported.

Compatible roster files should open into a roster import review workflow. A roster import should preserve team and player information while letting the user choose how imported records relate to existing teams and players.

Supported deep links may open the sharing area, preselect the download workflow, or prefill a roster-download selection. If the same file or roster can enter through more than one path, the validation, preview, conflict resolution, confirmation, and completion behavior should remain consistent.

## 5. Import Review Workflow

The import workflow begins when the user selects, receives, downloads, or opens a file. ScoreKeep should identify the source clearly enough that the user knows which file or download is being reviewed.

The application should verify the apparent file type before attempting to apply it. Unsupported files, wrong extensions, missing files, or files that do not appear to contain compatible ScoreKeep data should be rejected with user-facing language and without changing local records.

Compatibility validation should occur before permanent changes. The application should determine whether the file appears to contain a supported roster, supported game, older compatible data, newer unsupported data, or corrupted content.

The user should be able to preview the contents before confirming import. A roster preview should show the incoming team, players, visible roster details, and likely conflicts. A game preview should show the teams, date or game identity, game status, lineups, players, scoring record summary, pitcher participation, and warnings that affect the user's decision.

The workflow should show additions, updates, conflicts, removals, skipped records, and unsupported portions before final confirmation. The user should not need to infer these effects from technical messages or hidden matching rules.

The user should be able to choose create, update, skip, or cancel when those choices are relevant. Creating preserves the incoming record as a separate local record. Updating applies selected incoming values to a chosen existing record. Skipping leaves the incoming record out of the import. Canceling leaves all local records unchanged.

Conflict review should be explicit for teams, players, games, photos, logos, and historical relationships. If automatic matching would be unsafe, the user must choose the intended action.

Final confirmation is required before imported data becomes permanent. The confirmation should summarize the proposed result in ordinary language, including how many teams, players, or games will be created or updated and whether any warnings remain.

After import completes, ScoreKeep should present a completion summary. The summary should identify what was imported, what was skipped, what requires attention, and whether any unsupported data was preserved only partially.

## 6. Roster Import Behavior

Importing a roster may create a new team when no safe existing match is selected or when the user chooses to keep the imported team separate. The imported team should retain compatible team identity, coach or descriptive details, logo, and players where supported.

Importing a roster may update an existing team only after user confirmation. The user should understand which current values will be kept, which imported values will be applied, and whether players will be added, updated, skipped, or left unresolved.

The user should be able to keep current values when imported information conflicts with existing local information. This choice should preserve local names, numbers, positions, batting information, photos, logos, and notes for the affected record.

The user should be able to apply imported values when they intentionally trust the incoming roster. Applying imported values should affect only the selected team or player records and should not silently alter unrelated historical game participation.

The user should be able to create separate players or teams when similar names or numbers do not represent the same real-world record. Duplicate names, reused jersey numbers, and shared family names are normal baseball situations and must not force a merge.

The user should be able to skip imported records that are unwanted, incomplete, duplicated, or unsafe to merge. Skipped records should be listed in the completion summary when their omission matters.

Photos and logos should be preserved when compatible. Replacing an existing photo or logo requires a clear user choice when the existing local image differs from the imported image. If an image cannot be read, the rest of the compatible roster should remain reviewable where safe.

Duplicate names should trigger review rather than automatic destructive behavior. Duplicate jersey numbers should be allowed when confirmed, because numbers may be reused or may be unknown during roster preparation.

Missing information should be handled in context. Missing optional details should not block import. Missing required identity, such as an unusable team name or player name, should require correction, skipping, or cancellation before that record becomes active.

Partial roster files may be imported only when the result remains understandable. A partial roster should not be treated as a command to delete local players unless the user explicitly chooses a supported replacement behavior after reviewing the impact.

Existing historical game references must be protected. Updating a roster should not make past scorecards, substitutions, pitcher appearances, or reports appear to belong to different players or teams unless the user is intentionally correcting those historical records.

## 7. Game Import Behavior

Importing a full game should create a new local game unless the user explicitly chooses a safe duplicate-resolution action. Imported games must remain understandable and must not silently merge into unrelated local games.

Duplicate game detection should look for likely matches such as the same teams, date, location, score, or other visible game identity. A likely duplicate should pause for user review rather than automatically overwriting or merging the local game.

Team and player matching should preserve baseball meaning. Imported teams and players may match existing records, create new records, or remain game-specific participants depending on user choice and supported workflow. Matching by name alone is not sufficient when ambiguity exists.

Lineups should be preserved when compatible. The imported batting order, everyone-hits state, lineup timing, and lineup participants should remain tied to the imported game. If lineup information is missing or inconsistent, the game should show that uncertainty instead of inventing a clean lineup.

Substitutions should be preserved when compatible. The relationship between outgoing and incoming players, substitution timing, and scorecard meaning should survive import. Unsupported substitution history should be identified because it affects game review and reports.

Pitcher participation should be preserved when compatible. Starting pitchers, relief pitchers, pitcher timing, unknown pitchers, and pitching statistics should remain understandable after import. Missing or inconsistent pitcher data should not be silently assigned to the wrong player.

Scoring events should be preserved as the core of the imported game. Plate appearances, results, bases, outs, RBIs, stolen bases, earned-run decisions, notes, inning context, and sequence should remain consistent enough for reports and scorecards to derive from the imported record.

Reports and statistics for imported games should derive from the imported scoring record after validation. Precomputed totals from the file may help preserve context, but generated reports inside ScoreKeep should not become independent sources of truth.

Unknown or missing participants should remain visible. If the file refers to a player, pitcher, team, substitute, or runner that cannot be matched or identified, ScoreKeep should preserve the unknown state or require user resolution rather than attaching the event to an unrelated participant.

Completed, interrupted, suspended, in-progress, shortened, or historical game status should remain understandable. Import should not mark an interrupted game as final or require fake scoring events to make an imported game appear complete.

Imported games containing unsupported or inconsistent data should be handled with warnings, repair choices, or rejection. The user should know whether the imported game is fully usable, usable with warnings, partially preserved, or unsafe to import.

## 8. Conflict Resolution

Conflict resolution should show the user enough context to make a baseball decision. It should avoid technical labels when ordinary labels such as existing team, imported team, current value, imported value, create separate, update, keep current, skip, or cancel are clearer.

An existing team with the same or similar name should not automatically receive imported data. The user should be able to use the existing team, create a separate team, rename the imported team, skip the team, or cancel the import.

An existing player with the same or similar name should not automatically receive imported data when ambiguity exists. The user should be able to compare team, number, position, batting information, photo, and game history before deciding.

Different jersey numbers should be treated as a conflict when an imported player appears to match an existing player. The user may keep the current number, apply the imported number, create a separate player, or skip the imported player.

Different positions should be treated as a conflict when the difference affects roster identity, lineup preparation, or reports. The user should be able to decide whether the imported position is a correction, a seasonal change, or a different player.

Different batting information should be reviewable before update. The user should be able to preserve current batting side or order details unless they choose to apply the imported values.

Different photos or logos should not be replaced silently. When both local and imported images exist and differ, the user should choose which image to keep or whether to leave the imported image unused.

An existing game with the same teams and date should be treated as a likely duplicate, not as proof of the same game. The user should be able to keep both games, skip the imported game, replace or update only through a supported explicit action, or cancel.

Duplicate imported records inside the same file should be identified. The user should not have to discover after import that two incoming players, teams, or games were ambiguous.

Missing imported identifiers should not force unsafe name-based merging. If identifiers are missing, invalid, or unusable, the application should rely on visible context and user choice.

Ambiguous matches require explicit user choice. If ScoreKeep cannot determine safely whether two records represent the same team, player, or game, it should preserve local data and ask the user.

## 9. Export Behavior

Exporting team rosters should create a compatible roster file that preserves the selected team and player information supported by ScoreKeep. The export should include enough visible identity for another user to understand the team, review conflicts, and import the roster safely.

Exporting full games should create a compatible game file that preserves the selected game, teams, players, lineups, substitutions, pitchers, scoring events, game details, and historical context where supported. Export should preserve the meaning of incomplete, interrupted, corrected, or historical games rather than forcing them into a completed-game shape.

Exporting generated reports should create output that reflects the current saved game or reporting scope at generation time. Reports should identify enough context for the receiver to understand what game, team, players, or statistics are represented.

Exporting PDF scorecards should produce generated output suitable for sharing, printing, or archiving. A PDF scorecard should not become the editable source for a ScoreKeep game unless a future specification explicitly supports reconstructing game data from PDFs.

Historical records may be exported where supported. Export should preserve historical meaning, including older teams, player names, numbers, substitutions, pitcher history, corrections, and unknown data that affect the record.

Export naming should help users recognize the file without requiring technical knowledge. Established user-visible filename extensions and document-opening conventions should be preserved for compatible roster and game files. Exact filename syntax should remain flexible unless compatibility depends on a specific convention.

Exported files should preserve compatible meaning rather than implementation details. A receiving user should be able to understand the baseball record and make informed import choices even when local record identities differ.

Sharing should use standard Apple workflows where appropriate, including the share sheet, Files, Mail, Messages, AirDrop, and other system-supported destinations. Share completion or cancellation should not modify the source data.

Exporting incomplete or interrupted games should be supported when the saved game is meaningful. The exported file should preserve the in-progress or interrupted status so the receiver does not mistake it for a final record.

Exporting data containing unknown or unsupported values should preserve or disclose those values where supported. The export should not silently discard information that would change the meaning of a game, roster, or report.

Exporting after corrections should use the corrected saved data. Previously exported files may still exist outside the app, but new exports should reflect the current authoritative local record.

## 10. Sharing and Opening Files

Share sheet behavior should present compatible files or generated output to the system without changing the source records. If the user cancels the share sheet, the local roster, game, report, and export state should remain unchanged.

Opening exported files on another device should route the receiving user to the appropriate import review workflow when ScoreKeep is installed. The receiver should be able to preview, validate, resolve conflicts, and confirm before local data changes.

Opening files from another application should behave consistently with opening files from inside ScoreKeep. Mail, Messages, Files, Safari, AirDrop, or another app should not bypass validation or conflict resolution.

When ScoreKeep is already installed, compatible roster and game files should be offered to ScoreKeep through the established document-opening behavior. If multiple apps can open the file, the user's system choice should be respected.

When a file cannot be opened, the user should receive a clear message. The explanation should distinguish unsupported file type, corrupted file, missing file, inaccessible file, incompatible future file, and failed download when practical.

Reopening a previously exported file should not automatically duplicate local data. ScoreKeep should detect likely duplicate rosters and games and let the user choose whether to skip, keep separate, or intentionally update supported records.

Accidental duplicate imports should be avoided. If the same file is opened more than once, the app should show likely existing matches and make the duplicate risk clear before creating additional records.

Success and failure messages should be clear. After a successful import, export, share, or open operation, the user should know what happened. After a failure, the user should know that local source data remains protected and whether retrying, choosing a different file, or contacting the sender is appropriate.

## 11. Website and Download Compatibility

ScoreKeep should read the supported KomaKode roster manifest used for downloadable roster data. The roster manifest is an app-facing compatibility resource and should be treated separately from the public website's visual layout.

The download workflow should display available teams from the supported manifest. The user should be able to choose a roster by visible team name and understand when the roster list was last updated if that information is available.

Downloading a selected roster should retrieve the compatible roster file referenced by the manifest and route it into the roster import workflow. Downloading should not automatically overwrite an existing local team.

Offline and retry behavior should be understandable. If the roster list or selected roster cannot be downloaded because the network is unavailable, the server cannot be reached, or the file is temporarily unavailable, local data should remain unchanged and the user should be able to retry later.

Invalid or unavailable roster files should be rejected before import. A roster URL that returns website HTML, an error page, a wrong file, a corrupted file, or an unsupported file should produce a user-facing error rather than a partial import.

Existing website paths and compatibility expectations should be preserved. The supported roster manifest path, message path where relevant to the application, roster-file extension, document-opening behavior, and direct roster file availability should not be broken by website redesigns or hosting changes.

Deep links may preselect or open the roster-download workflow when they use a supported ScoreKeep route. A deep link should help the user reach the intended team or download screen, but it should not force a download or import without review.

The roster-download workflow should not rely on unrelated website HTML. Compatibility should depend on the supported roster manifest and compatible roster files, not on parsing a human-facing web page whose layout may change.

## 12. Version Compatibility

Older files opened by newer ScoreKeep versions should remain readable whenever their data can be safely understood. The newer app should preserve compatible team, player, game, scoring, lineup, substitution, pitcher, photo, logo, and reportable meaning.

Newer files opened by older ScoreKeep versions may contain unsupported data. Where possible, exported files should remain compatible with older supported versions by using additive changes and preserving established document types. When older versions cannot understand newer data, the user should receive an understandable compatibility error rather than silent truncation.

Unsupported future data should be identified. If the current app opens a file from a future version and cannot safely interpret part of it, it should explain the limitation and avoid presenting incomplete data as fully verified.

Additive changes are preferred. New fields, new optional values, new report types, or new compatibility metadata should be introduced in ways that preserve existing roster and game import behavior wherever practical.

Required legacy field preservation matters because existing files and workflows depend on established ScoreKeep meaning. Future versions should avoid removing or renaming user-visible compatibility concepts unless a migration preserves old files and explains the change.

Compatibility errors should be user-readable. Messages should explain that the file is unsupported, too new, too old, corrupted, incomplete, or unsafe to import, rather than exposing implementation terms.

Silent data truncation is not acceptable. If ScoreKeep cannot preserve part of a file that affects baseball meaning, identity, history, or reports, the user should be warned and allowed to cancel when practical.

Established document extensions and opening behavior must remain supported. Compatible roster and game files should continue to use and accept the established ScoreKeep file extensions and system document routes even if future formats are added.

## 13. Import and Export Corrections

Correcting an imported roster should behave like correcting any local roster. The user should be able to fix names, numbers, positions, batting information, photos, logos, team details, and duplicate records without needing to re-import the original file.

Correcting an imported game should behave like correcting any saved game. The user should be able to correct teams, players, lineups, substitutions, pitcher assignments, scoring events, RBIs, stolen bases, earned-run decisions, notes, and game status where supported.

Re-importing after correction should avoid accidental duplicates. If a corrected roster or game is imported again, ScoreKeep should detect likely matches and show whether the incoming file appears to replace, update, duplicate, or conflict with existing local records.

Exporting corrected data should use the current corrected record. A new export after correction should not rely on stale generated output, old imported totals, or previous exported files.

Stale generated output should be avoided. Reports, PDFs, and summaries generated before corrections may exist outside the app, but newly generated output should reflect the current saved data.

Duplicate records should be prevented where practical. The app should help the user avoid creating multiple copies of the same imported roster or game unless the user intentionally chooses to keep separate records.

After a failed import, local data should remain usable and understandable. The user should know whether no changes were made, some safe changes completed with warnings, or the operation requires attention.

After a failed export, source data should remain unchanged. The user should know that the roster, game, report, or PDF was not successfully shared or saved and should be able to try again where appropriate.

## 14. Validation Requirements

Wrong file types should be rejected before import. The user should be told that the selected file is not a supported ScoreKeep roster or game file, or that the selected generated output cannot be imported as source data.

Corrupted files should not change local data. If a file cannot be read as compatible ScoreKeep data, the user should receive a clear error and, where useful, guidance to request a new file.

Missing required data should be detected before import. Records lacking usable team identity, player identity, game identity, scoring context, or other required information should require correction, skipping, cancellation, or a warning that the imported record is incomplete.

Unsupported values should be preserved or identified when they affect meaning. ScoreKeep should not silently convert unsupported scoring results, game states, player states, or report values into misleading defaults.

Invalid team relationships should be detected. A game should not silently attach a visiting team, home team, lineup, player, or scorecard to an unrelated team because the imported relationships are incomplete or ambiguous.

Invalid player relationships should be detected. At-bats, pitcher records, substitutions, and lineups should not be assigned to the wrong player when imported player references are missing, duplicated, or ambiguous.

Invalid lineup history should be detected when lineups cannot be reconciled with the imported game. Missing batting order, duplicate lineup slots, incomplete participants, or unsupported lineup rules should be shown to the user.

Invalid substitution history should be detected when replacement relationships are missing or impossible. The app should preserve what can be understood and identify uncertainty rather than rewriting substitutions silently.

Invalid pitcher history should be detected when pitcher assignments, participation periods, or pitcher statistics cannot be reconciled with the scoring record. Unknown pitcher states should remain visible.

Impossible scoring data should be detected when practical. Examples include impossible inning transitions, outs that exceed baseball limits without explanation, scores that cannot be reconciled with scoring events, duplicated plate appearances that appear accidental, or runner states that cannot exist.

Duplicate games should be detected and reviewed. A likely duplicate should not be silently imported as a new unrelated game or merged into an existing game without user confirmation.

Duplicate rosters should be detected and reviewed. A likely duplicate team or player list should not silently overwrite current roster information.

Oversized or incomplete files should be handled safely. If the file is too large, incomplete, interrupted during transfer, or missing expected content, import should fail or proceed only with explicit warnings and user confirmation.

Unsafe partial import should be prevented. If importing only part of a file would make local records misleading, the app should leave local data unchanged and explain why the import cannot safely proceed.

Validation should protect local data and explain problems in user-facing language. The goal is not merely to reject invalid files, but to help the user understand whether the file can be trusted and what action is safe.

## 15. Data Integrity Requirements

ScoreKeep must protect local data throughout import, export, sharing, download, opening, validation, correction, and compatibility workflows.

- Canceling before final confirmation leaves local data unchanged.
- A confirmed import either completes coherently or preserves a usable prior state.
- Export never modifies local records.
- Import never silently merges unrelated teams, players, or games.
- Historical game meaning remains preserved.
- Existing file compatibility remains protected.
- Photos, logos, lineups, substitutions, pitchers, and scoring data are not silently discarded.
- Unsupported information is disclosed when it affects user understanding.
- Generated reports are not treated as source data.
- Import and export never bypass user ownership of existing data.
- Premium restrictions must not block access to the user's existing compatible records.
- Duplicate detection must assist the user without forcing unsafe automatic choices.
- Failed downloads, failed imports, failed exports, and failed shares must leave source data usable.
- Re-importing compatible files must not create accidental duplicates without warning.
- Future compatibility changes must be additive or provide an understandable migration path.

## 16. Exceptional Situations

**User cancels import:** Canceling before final confirmation should leave all local teams, players, games, reports, photos, logos, and historical records unchanged.

**App closes during import:** If the app closes before final confirmation, the import should not become permanent. If the app closes after confirmation while work is in progress, the next launch should leave local data usable and explain whether the import completed or needs attention.

**Device restarts during import:** A device restart should not leave local data in a misleading state. The user should be able to reopen ScoreKeep and understand whether no changes occurred, the import completed, or the import failed safely.

**Network fails during download:** A roster download interrupted by network failure should not change local records. The user should see that the download failed and should be able to retry when network access returns.

**File disappears before import:** If a selected or received file is no longer available, ScoreKeep should explain that it cannot be opened and should leave local data unchanged.

**File is corrupted:** A corrupted roster or game file should be rejected or held for review without changing local data. The user should be told that the file cannot be safely imported.

**File contains only partial data:** Partial data should import only when the resulting records remain understandable and the user confirms the warnings. Unsafe partial data should be rejected.

**Duplicate game import:** A game that appears to already exist should trigger duplicate review. The user should be able to skip, keep separate, intentionally update through a supported path, or cancel.

**Duplicate roster import:** A roster that appears to match an existing team or players should trigger conflict review. The user should be able to keep current values, apply imported values, create separate records, skip records, or cancel.

**Newer unsupported file:** A file created by a newer ScoreKeep version should explain that some or all content is unsupported. The app should avoid importing unsupported future data as if it were fully understood.

**Older malformed file:** An older file with missing or malformed content should preserve what can be safely understood only after warning the user. If the file cannot be made understandable, it should be rejected without local changes.

**Export destination unavailable:** If Files, Mail, Messages, AirDrop, or another destination is unavailable or rejects the export, source data should remain unchanged and the user should be told the export did not complete.

**Share sheet fails:** A share failure should not mark the file, report, or PDF as successfully shared. The user should be able to try another destination where practical.

**Re-import of a corrected file:** Re-importing a corrected roster or game should show likely matches and prevent accidental duplicates. The user should decide whether the corrected file updates an existing record or remains separate.

**Import succeeds with warnings:** A successful import with warnings should clearly list unresolved, skipped, unsupported, or incomplete content. The imported records should remain usable and should show uncertainty where it affects review or reporting.

**Import fails after user confirmation:** If a confirmed import fails, ScoreKeep should preserve a usable prior state whenever possible and provide a completion or failure message that explains what happened in user-facing terms.

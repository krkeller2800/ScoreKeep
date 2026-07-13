# ScoreKeep Functional Specification — 11 Photos, Logos, and Media

## 1. Overview

Photos, logos, and related media help ScoreKeep users recognize teams, players, reports, scorecards, and shared roster records more quickly. A team logo can make a roster or report easier to identify. A player photo can help distinguish similar names, confirm lineup choices, and support faster scorekeeping during preparation or live play.

Media is presentation support. It is not required baseball data, and it must never become the authority for team identity, player identity, scoring, statistics, lineup membership, substitutions, pitcher use, game status, purchases, imports, or exports. A team without a logo and a player without a photo must remain fully usable anywhere the team or player is otherwise valid.

The media experience should preserve existing ScoreKeep expectations for team logos, player photos, imported image data, exported roster and game files, scorecards, reports, and historical records while making replacement, removal, import review, and failure behavior more predictable.

## 2. Media Principles

Photos and logos are optional. Missing media should never block creating a team, adding a player, setting a lineup, scoring a game, correcting a game, generating a report, exporting a record, or importing otherwise valid baseball data.

Media improves recognition but does not determine identity by itself. Names, teams, game participation, roster membership, dates, numbers, and other visible baseball context remain available when media is missing, unreadable, changed, or removed.

Replacing or removing an image changes only the intended visual presentation. It must not change baseball history, scoring facts, statistics, lineup order, team membership, pitcher records, purchase status, free allowances, or saved game status.

Invalid, unsupported, missing, corrupted, or unexpectedly large image data must not crash ScoreKeep or make live scorekeeping unusable. The user should receive understandable fallback behavior and, where appropriate, a choice to remove, replace, skip, or retry the affected image.

Import and export should preserve compatible media where practical. When incoming media conflicts with existing local media, ScoreKeep should ask before replacing local images. Media operations must not silently delete, merge, corrupt, or reassign teams, players, games, reports, or historical records.

Historical reports should remain understandable without images. If media is unavailable or no longer matches current records, the report should still identify teams and players through text and saved baseball context.

## 3. Team Logos

A user should be able to add a logo to a team from the team creation or team editing workflow where logo support is offered. The workflow should make the receiving team clear before the user confirms the image.

A team logo may be shown in team lists, team detail, game setup, live scoring, scorecards, reports, import review, export preview, and sharing workflows when it helps recognition and space allows. The team name must remain visible or available through an accessible label.

Replacing a team logo should require a deliberate action. If the team already has a logo, the user should understand that the new image will replace the current logo for that team while leaving the team, players, games, and scorekeeping history intact.

Removing a team logo should leave the team record and all related baseball records in place. The team should return to a clear placeholder or text-only presentation.

Teams without logos should be normal. They should not look broken, incomplete, or unavailable for scoring. Placeholders should be visually distinct from actual logos and should not imply a specific team identity.

Imported, downloaded, or shared roster logos should be preserved when compatible. If an imported logo would replace an existing local logo, ScoreKeep should show the current and incoming choices clearly enough for the user to keep the current logo, use the imported logo, skip the logo, or keep records separate when appropriate.

A current team logo may appear in historical views when ScoreKeep does not preserve a game-time logo. Historical screens and reports should avoid implying that a later logo was necessarily used at the time of an older game. Where the difference matters, text identity and game context should keep the record understandable.

## 4. Player Photos

A user should be able to add a photo to a player from player creation or player editing workflows where photo support is offered. The workflow should identify the receiving player and team context before confirmation.

A player photo may be shown in player lists, player detail, lineup selection, pitcher selection, substitution selection, live scoring, reports, import review, export preview, and sharing workflows when it improves recognition. The player name must remain visible or available through an accessible label.

Replacing a player photo should require deliberate confirmation. A replacement should affect only that player's visual presentation and should not change the player's past game participation, statistics, lineup positions, substitutions, pitcher appearances, or team history.

Removing a player photo should leave the player intact and available everywhere the player was already valid. The player should return to a clear placeholder or text-only presentation.

Players without photos should be normal, including temporary players, guest players, unknown players, late additions, and players created during game setup. Missing photos should not slow lineup or scoring workflows.

Imported and shared roster photos should be preserved when compatible. If a local player already has a different photo, ScoreKeep should require review before applying the incoming photo. A photo helps recognition but is not proof that two player records represent the same person.

Historical games and reports should remain understandable after a photo changes or disappears. If current photos are used in regenerated historical output, the report should still derive player identity from saved game and roster context rather than from the image.

## 5. Image Selection Workflow

When selecting an image, the user should always understand which team or player will receive it. The originating form should identify the team or player before the selection starts and again before the choice is confirmed.

The user may choose an image from supported system sources available on the device. If a source is unavailable, restricted, or denied, ScoreKeep should explain the situation without changing the team or player.

After selection, ScoreKeep should show a preview where practical. The preview should make it clear whether the user is adding a new image or replacing an existing one. Confirming applies the selected image to the named team or player. Canceling returns to the originating form with the prior image unchanged.

When replacing an existing image, the workflow should show enough context to prevent accidental replacement. When removing an existing image, the workflow should state that the team or player will remain and only the image will be removed.

If permission is denied, the source is unavailable, or the selected image cannot be read, the user should be able to return to the originating form, choose another source where available, continue without media, or keep the existing image.

## 6. Image Editing and Presentation

Where cropping or adjustment is offered, it should be understandable as presentation editing for the selected image. The user should be able to confirm the visible result or cancel without changing the prior image.

ScoreKeep should present images with sensible orientation, scale, and aspect-ratio behavior for the current context. A thumbnail in a list, a larger preview on a detail screen, and an image in a report may use different presentation sizes while preserving the same team or player meaning.

Team logos may be presented in rectangular or badge-like areas. Player photos may be presented in circular, square, or rectangular areas depending on the screen. The presentation style should not imply extra baseball meaning.

Placeholder images or text-only presentations should be clear, accessible, and stable. They should identify missing media without making the record appear invalid.

Extremely large source images should not make the interface unusable. Very small images may appear less detailed but should not block saving if they can be presented safely. Transparent images should remain understandable against the surrounding interface. Animated or unsupported media should be accepted only when ScoreKeep can present them predictably; otherwise the user should receive a safe rejection or fallback.

## 7. Media in Lists and Forms

Team lists, player lists, team detail, player detail, game setup, lineup selection, pitcher selection, substitution selection, search results, import review, and conflict resolution may use media to improve recognition.

Text identity remains required. A logo must not replace the team name. A photo must not replace the player name. Where numbers, positions, batting details, teams, or game context matter, those details should remain visible or reachable.

Missing images should use a clear placeholder or text-only presentation. Large images should not make lists hard to scan, distort row heights unpredictably, or push required actions offscreen.

Import review and conflict resolution should show media differences when those differences affect the user's choice. The comparison should not treat image similarity or difference as definitive proof that records are the same or different.

Images do not replace accessible labels. Users who cannot see images should still be able to identify teams, players, actions, conflicts, and destinations.

## 8. Media During Live Scoring

During live scorekeeping, media should support speed and clarity. Team logos may help identify home and visiting teams. Player photos may help identify the current batter, current pitcher, runners, lineup choices, substitution candidates, and players with similar names.

Media should not obstruct the current baseball state. Score, inning, outs, runners, batter, pitcher, lineup position, scoring controls, and confirmation actions should remain more important than decorative presentation.

Missing images during live scoring should fall back immediately to names, numbers, teams, positions, or placeholders. The user should not be forced to select media before scoring can continue.

Media loading, previewing, or fallback behavior should not make scoring feel delayed or unstable. If an image cannot be displayed during live play, ScoreKeep should continue with text identity and preserve scoring progress.

Substitution and pitcher selection workflows may use photos to distinguish players, especially with similar names or reused jersey numbers. The final selection should still be confirmed by text identity and baseball context.

## 9. Media in Reports and Scorecards

Reports and scorecards may include team logos in headers, summaries, printable output, generated documents, and scorecard-style presentations when supported. Player photos may appear in reports where they add recognition without crowding the baseball facts.

Reports derive baseball facts from saved game data. Media is presentation only. Missing, changed, removed, or unreadable images must not change scores, at-bats, pitcher statistics, batting statistics, substitutions, lineups, or game status.

If media is missing, the report should remain printable and understandable through team names, player names, game date, location, score, and report labels. A report should not fail solely because an optional logo or photo is unavailable when a safe text presentation can be used.

If a report is regenerated after a logo or photo changes, ScoreKeep should avoid misleading historical identity. The user should be able to understand whether the report is using current media or saved historical context where that distinction is visible in the product.

If media cannot be rendered in a generated document, the user should receive a clear fallback or warning when the omission affects the expected output. The source records must remain unchanged.

## 10. Import Behavior

When importing team roster files, full game files, downloaded rosters, older ScoreKeep files, or shared files, ScoreKeep should preserve compatible photos and logos where practical and safe.

Files with missing images should remain importable when the baseball records are otherwise understandable. Missing media should be shown as absent, not treated as a command to delete local media unless the user explicitly chooses a replacement or removal behavior.

Files with corrupted, unreadable, unsupported, or oversized images should not crash import review. ScoreKeep should identify the affected media, preserve the rest of the compatible import where safe, and let the user skip, replace, keep current media, or cancel as appropriate.

Files containing media conflicts should require review before imported media replaces existing local media. A conflict may exist when a team logo differs, a player photo differs, one side has an image and the other does not, or the incoming image cannot be displayed reliably.

Partial imports should keep media behavior aligned with the accepted records. If a player is skipped, the player's photo should be skipped with that player. If a team is kept separate, its logo should remain attached to the imported team where compatible.

## 11. Export Behavior

When exporting team rosters, full games, historical records, reports, or generated documents, ScoreKeep should preserve compatible image meaning where practical without altering the source records.

A roster export may include team logos and player photos when supported by the export format. A game export may include media needed to make the participating teams and players recognizable where compatible.

Files containing no images should remain valid exports. A user should be able to share a team, game, report, or document even when every team and player lacks media.

Large images, unknown media, or unsupported media should not cause source records to change. If ScoreKeep cannot include an image in an export, it should either omit the image with an understandable warning when needed or require the user to choose a supported export outcome.

Export is non-destructive. It must not remove local media, replace local media, rewrite historical records, reduce image quality in local records, or change baseball facts.

## 12. Media Conflict Resolution

Media conflict resolution should be user-visible when an existing team logo differs from an imported logo, an existing player photo differs from an imported photo, one record has an image and the other does not, or an imported image is unreadable.

The user should be able to choose the current image, choose the imported image, keep records separate, skip media replacement, or cancel the affected import when those choices fit the workflow.

Duplicate teams or players with different images should not be automatically merged or separated based on the images alone. Media differences may signal a need for review, but they are not proof of identity or non-identity.

If an imported image is unreadable, the user should not be asked to trust an invisible replacement. The workflow should preserve the current image unless the user explicitly removes it or continues with no imported media.

Conflict choices should describe the affected team or player by name and context. The user should not have to infer which record will receive a logo or photo.

## 13. Historical Behavior

A team may change its logo over time. A player may change their photo, change teams, change jersey numbers, or share a number later reused by another player. These changes should not make older games misleading or unusable.

When an old game is reopened, ScoreKeep should identify teams and players through saved game context. Current media may be used for presentation where supported, but text identity and game context should keep the historical record clear.

When a historical report is regenerated, changed or removed media should not change the baseball facts. If current media differs from game-time media, the report should remain understandable and should avoid implying that the current image was necessarily present at the time of the game.

Imported historical data may include older logos or photos. ScoreKeep should preserve compatible historical media where practical, and should ask before replacing current local media with older imported media.

If a current player photo differs from the photo included in imported historical data, the difference should be treated as a presentation conflict, not as proof that the player is different. The same applies to team logos.

## 14. Accessibility Requirements

Media should enhance recognition without becoming the only means of understanding the interface. Team names, player names, numbers, positions, game labels, and action labels should remain available to users who do not rely on images.

Informative images should have meaningful accessible descriptions, such as identifying the team logo or player photo by the associated record. Decorative images should not distract from the accessible reading order.

Placeholder descriptions should indicate missing media without implying an error, such as a team without a logo or a player without a photo.

Images should have enough contrast or surrounding structure to remain distinguishable in common display conditions. Color-independent identification is required; logos, uniform colors, or photo appearance must not be the only way to choose a team or player.

Larger text settings should preserve names, actions, warnings, and conflict choices even if media is reduced or omitted. Image replacement and removal actions should be accessible, labeled, reversible before confirmation, and distinguishable from destructive record deletion.

Reports and generated documents should remain understandable when printed, viewed without color, viewed with missing media, or interpreted from text labels.

## 15. Privacy Expectations

User-selected local images may include personal photos, team marks, school marks, youth players, or other sensitive context. ScoreKeep should make it clear when such images are attached to teams or players and when they will be included in shared output.

Images received through imported files or downloaded rosters should be treated as part of the incoming record until the user chooses what to keep. The user should be able to review imported media before it replaces local media.

Sharing rosters, games, reports, or generated documents may share team logos and player photos when those images are included in the chosen output. The user should have enough awareness of that sharing effect before sending files outside the app.

Removing an image should stop that image from appearing in future uses of the affected local team or player where current media is used. Previously shared files or generated documents are outside the app's control after the user shares them.

ScoreKeep should not require unnecessary network upload of user-selected photos or logos for local scorekeeping. Users are responsible for choosing images they have permission to use and for deciding whether to share photos, especially photos of minors.

## 16. Validation Requirements

Unsupported image type, corrupted image data, empty image data, unreadable imported image, missing image permission, unavailable source, canceled selection, oversized image, duplicate replacement, export omission, report rendering failure, and imported media conflict should each have safe user-visible behavior.

If image selection is canceled, the prior image or missing-image state should remain unchanged and the user should return to the originating workflow.

If an image cannot be read or presented, ScoreKeep should reject or skip that image without deleting the team, player, game, or prior image. The user should be able to retry, choose another image, continue without media, or cancel where appropriate.

If there is a risk that an image is attached to the wrong record, the workflow should stop before confirmation and identify the intended team or player. Applying media to the wrong record should be recoverable through ordinary replacement or removal actions.

If export or report generation cannot include media, ScoreKeep should preserve the source records and explain the effect on the output when it matters. The baseball facts should remain valid.

If imported media conflicts with local media, local media should remain unchanged until the user chooses otherwise.

## 17. Data Integrity Requirements

Image operations must never delete teams, players, games, lineups, substitutions, pitchers, at-bats, reports, purchases, free allowances, or scoring records.

Replacing an image changes only the intended media for the intended team or player. Removing an image leaves the team or player intact.

Invalid media must never crash scorekeeping, corrupt reports, or make saved baseball records unusable. Missing images must never change baseball identity.

Imported media must never replace local media without confirmation. Export must never modify local media. Reports must remain valid without images.

Historical game records should remain understandable after image changes. Media changes must never affect statistics, batting order, pitcher history, game status, purchase state, free-use counters, import history, or generated baseball facts.

A media operation should either complete coherently or leave the prior image state unchanged. If the user cannot tell whether an image was changed, ScoreKeep should provide a clear final state before the workflow ends.

## 18. Exceptional Situations

If the user denies photo permission, ScoreKeep should explain that the selected source cannot be used and return the user to a safe choice without changing records.

If the image picker is canceled, the previous image state should remain unchanged and the originating form should remain usable.

If the selected image cannot be read, ScoreKeep should leave the prior image unchanged and offer a clear way to choose another image or continue without one.

If the app closes, backgrounds, rotates, resizes, or changes presentation during image selection or preview, the user should not lose saved team, player, game, or scoring data. On return, the user should see either the prior stable state or a clear confirmation path.

If an imported image is corrupted, extremely large, unsupported, or conflicts with an existing local image, import review should identify the issue and protect local records until the user chooses an action.

If a team logo or player photo is removed, future screens should use a placeholder or text-only presentation and continue to show the team or player normally.

If a historical report is regenerated after an image change, the report should remain understandable and should not change baseball facts.

If export cannot include an image or document generation fails on an image, ScoreKeep should preserve source records and provide a safe output option where practical.

If a user shares a roster containing player photos, the sharing workflow should make the scope of the shared roster understandable. If a downloaded roster has no logo or an unknown player has no photo, the absence of media should not be treated as an error.

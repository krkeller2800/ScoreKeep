# ScoreKeep Technical Design — 18 Canonical Domain Model

## 1. Purpose

This document defines the canonical domain model for the ScoreKeep rewrite. It is a technical design document. It describes the baseball concepts, identities, relationships, recorded facts, derived state, and historical boundaries that the rewritten architecture should use when interpreting ScoreKeep records.

ScoreKeep needs a canonical domain model because the current implementation mixes several meanings in the same objects and workflows. Reusable roster data, game-specific participation, scoring facts, derived statistics, persistence relationships, display names, UUID fields, and view state are often updated together. A player record may describe a current roster member, a lineup slot, a batter in one game, a substituted player, a report row, and an import match candidate. A game record stores teams, players, at-bats, lineups, pitchers, substitutions, scores, and presentation-oriented values without a single domain boundary that says which values are facts and which values are calculations.

The result is that baseball meaning is not always owned by one layer. Views create and mutate scoring rows. Reports recalculate statistics from saved rows. Import code interprets file records and attaches them to local teams or players. Score screens use names, batting order, dates, locations, sequence values, and stored totals as practical identifiers. This makes it difficult to know whether a value is the authority, a cached result, a compatibility artifact, or a temporary screen choice.

The canonical model defines baseball meaning independently from SwiftUI, SwiftData, report layouts, PDF rendering, and compatibility file structures. It does not prescribe Swift type declarations, database tables, property wrappers, migrations, UI state, or Codable structures. It defines the product concepts the rewritten architecture should preserve so that scoring, correction, reporting, import, export, and migration can all interpret the same saved baseball facts.

The model must support existing ScoreKeep users and saved records. Current SwiftData data, `.ScoreKeep_Players` files, `.ScoreKeep_Games` files, the seeded game, live scoring, corrections, lineups, substitutions, pitcher participation, reports, scorecards, PDFs, statistics, imports, exports, duplicate names, reused jersey numbers, and historical games all remain in scope. The rewrite may improve internal structure, but it must not lose the baseball meaning users have already recorded.

## 2. Domain Modeling Principles

Each baseball concept should have one authoritative meaning. A team, player, game, participant, lineup slot, substitution, pitcher appearance, scoring event, runner outcome, score, and report total should not mean different things depending on which screen or report produced it.

Identity should be stable and explicit. Names, team names, dates, locations, jersey numbers, batting order, and roster position are display or classification values. They may help users recognize records, but they are not reliable identity.

Recorded facts should be separated from derived state. A recorded play, runner outcome, lineup decision, substitution, pitcher change, note, or user-entered scoring decision is a fact. A current score, current runners, next batter, box score, batting total, pitching total, scorecard cell, and PDF row are derived from facts.

Reusable roster records should be separated from game-specific participation. A player can exist on a current roster without appearing in a game. A player can appear in a historical game even if the current roster later changes. A guest, temporary, imported, or unknown participant can appear in a game without becoming a normal reusable roster member.

Historical records should be protected from later roster edits. Editing a current team name, player name, jersey number, position, photo, logo, coach, or roster membership should not silently change the meaning of a completed game.

Optional and unknown information should be represented honestly. Unknown is different from empty, zero, default, guessed, or not applicable. A missing pitcher should not become a real player named blank. An unknown jersey number should not become jersey number zero. An unsupported legacy result should not become an ordinary out simply because the application needs a value.

Imported legacy information should be preserved without becoming authoritative merely because it exists in a file. Legacy files may contain useful identities, names, scores, result strings, lineup records, pitcher markers, substitutions, and media. They may also contain ambiguous references, missing fields, stale totals, or implementation-specific values. Import should preserve evidence and classify uncertainty instead of treating every decoded field as canonical truth.

Presentation state should be excluded from the baseball domain. Selected tabs, sort criteria, expanded sections, highlighted cells, temporary sheet choices, navigation state, screenshot settings, paywall presentation, and progress indicators are not baseball records.

Purchase state and preferences should be excluded from baseball records. Entitlements, free counters, product availability, app settings, and display preferences may influence which actions are available or how data is shown, but they must not define team identity, player identity, scoring facts, or game history.

## 3. Identity Strategy

Teams require stable identity so that two teams with the same name can remain distinct, one team can be renamed without becoming a different team, and historical games can keep referencing the team that participated at game time.

Players require stable identity so that duplicate names, blank names, reused jersey numbers, roster changes, photos, positions, batting directions, and imports do not merge unrelated people or split one person accidentally.

Games require stable identity so that a doubleheader, a rematch on the same date, an imported historical file, and a local game with the same teams and location can remain separate records.

Game participants require stable identity within the game. A game participant is the baseball person or side member that scoring events, lineup entries, substitutions, runner appearances, and pitcher appearances should reference. The participant may reference a reusable player, but it must remain understandable even if that reusable player changes later.

Lineup entries require identity because a batting slot can have history. The starting occupant, later replacements, corrections, and unknown occupants should be distinguishable from the reusable player record and from the current presentation order.

Plate appearances and scoring events require identity so corrections, deletion, replay, scorecard cells, reports, and exported records can refer to one recorded baseball event without relying only on inning, column, batter name, or sequence.

Runner appearances require identity because one batter record cannot safely describe every runner movement on a play. A runner who begins on first, advances to third, scores, is put out, is replaced by a pinch runner, or is affected by a third-out rule needs a specific recorded outcome tied to that runner's game participant and source.

Pitcher appearances require identity because a pitcher can enter, leave, re-enter where supported, be corrected, or have responsibility adjusted. A pitcher period should not be inferred only from player name and inning markers when multiple pitchers or corrections exist.

Substitutions require identity because they are historical events. The incoming participant, outgoing participant, batting slot, side, timing, and correction status must remain traceable after later roster edits or report regeneration.

Imports and compatibility references require identity handling that distinguishes valid legacy identifiers from matching hints. A decoded UUID or identifier should be preserved when it is syntactically valid and safely associated with the same conceptual record. If a legacy record lacks a reliable identifier, import or migration should assign a stable local identity and preserve the legacy evidence that was used to create it.

Names, dates, locations, jersey numbers, batting order, and team names cannot serve as reliable unique identity. Players can share names. Jersey numbers can be reused within a season or across seasons. Teams can share names across leagues, years, or imported files. Doubleheaders can share teams and dates. Locations can be blank or informal. Batting order changes through substitutions and Everyone Hits rules. These values are important for display, search, and conflict review, but they are not enough to attach historical facts silently.

The canonical strategy is to preserve valid legacy UUIDs where they are already part of a supported record, to assign stable local identity where legacy identity is missing or unreliable, and to record compatibility references separately from authoritative identity. This document does not prescribe a specific UUID API, database constraint, or persistence key format.

## 4. Reusable Records and Historical Snapshots

A reusable team record represents a team as it is managed outside any one game. It owns stable team identity, current display information, current roster relationship, optional logo, coach or descriptive information, and presentation concepts such as active, inactive, or archived status where those concepts are supported.

A reusable player record represents a player as managed outside any one game. It owns stable player identity, current name, current jersey number, current position, batting direction, photo, roster membership, and availability status.

A game identity represents one baseball game record. It is distinct from the current team records and current player records used to create the game.

Team participation in one game represents one side in that game. It may reference a reusable team, but it also preserves game-time display information such as the team name, role, and logo context needed to understand the historical game.

Player participation in one game represents a person or unknown participant in that game. It may reference a reusable player, but it also preserves game-time display information such as name, number, position, batting direction, side, role, and status needed to understand scoring facts.

Historical display information captured for a game is the snapshot information needed to keep the game understandable after current records change. This does not require freezing every current field forever. It does require freezing enough game-time information that a report, scorecard, export, or correction does not depend solely on mutable roster data.

Later changes to team name, player name, number, position, photo, logo, coach, or roster membership should affect current roster records and future games. They should not silently rewrite historical game meaning. A historical game may reference current information when the value is clearly presentation-only or when the user intentionally chooses to refresh display metadata. A historical game needs game-time snapshot information when the value identifies who participated, which side they were on, which jersey or name was used in the game, or what the scorecard/report needs to remain readable.

## 5. Team Concept

A canonical team is a reusable baseball organization or roster grouping with stable identity. It has current display information such as name, coach, details, and optional logo. It has a current roster relationship to reusable players. It may have presentation status such as active, inactive, or archived when the product needs to hide old teams from default lists without deleting their history.

Team names are not unique. Two teams may be named Tigers, two imported files may contain a team named Blue Jays, and one real team may change its name over time. The canonical model must allow duplicate names and should treat name conflicts as reviewable identity questions rather than automatic merge instructions.

A team can represent the same team across seasons or a separate seasonal record depending on user intent and product workflow. If the user treats one roster as a continuing team, current edits should remain current roster edits. If the user creates separate seasonal teams, those records should remain distinct even when they share a name, coach, or players.

Historical participation in games is not the same as the reusable team. A game side records that a team, or an imported/unknown team-like side, participated as home or visiting in one game. It preserves the game-time name and display context. This prevents an old game from changing meaning because the reusable team is renamed, archived, merged, or replaced.

## 6. Player Concept

A canonical player is a reusable person record with stable identity. It has current display information such as name, jersey number, position, batting direction, photo, roster membership, and availability. A player may be active on a roster, inactive but preserved for history, a guest or temporary player, or a record imported from a compatibility file that still needs review.

Player names and numbers are not unique. Two players may share a name. One player may change numbers. A number may be reused by another player. Blank names, nicknames, shortened names, and last-name-only import matching are not reliable identity. The canonical model must keep duplicate names and reused numbers distinct unless a user or verified migration outcome deliberately merges them.

Team membership is a current roster relationship, not the only definition of who a player is. A player can leave a roster while remaining a participant in old games. A guest can participate in a game without becoming a normal roster member. An unknown player can occupy a lineup slot, reach base, pitch, or substitute when the scorer does not know the real identity yet.

A reusable player is distinct from the player's role and recorded identity in one game. Scoring events should refer to game player participation. Reports and scorecards for a historical game should be able to show the game-time name, number, and side even if the reusable player's current name, number, team, photo, or position changes.

## 7. Game Concept

A canonical game is one baseball record with stable identity, home and visiting sides, date, location, expected inning count, lineup rules such as Everyone Hits, notes or highlights, lifecycle status, recorded baseball events, lineup history, pitcher participation, substitution history, and completion or interruption state.

The game record should preserve settings and facts needed to replay or explain the game. Date, location, expected innings, selected lineup rule, home side, visiting side, starting lineups, substitutions, pitcher appearances, scoring events, user-entered notes, and lifecycle decisions are recorded facts.

Values such as current score, inning totals, outs, current runners, current batter, hits, errors, batting statistics, pitching statistics, box score, and scorecard cells should normally be derived. They may be cached for performance or preserved for compatibility review, but they should not become competing authorities that can disagree silently with recorded scoring events.

A game may be draft, configured, ready, in progress, interrupted, completed, archived, imported historical, or sample-origin where useful. This document does not assume the current application already persists those lifecycle states. It defines the domain need so future workflows can make game status explicit instead of inferring everything from incomplete rows or stored scores.

## 8. Game Team Participation

Game team participation represents one side in one game. It includes the side role, such as home or visiting, and the information needed to display and interpret that side historically.

When available, game team participation should reference the reusable team that was selected or imported. It should also preserve game-time team name and display context so that reports and scorecards remain understandable after the reusable team changes. If supported, game-specific logo behavior should distinguish between a snapshot logo used for the historical game and the current reusable team logo used in current roster views.

The game side owns or references the game-specific participant collection for that side. These participants are the players, guests, temporary participants, unknown participants, and pitcher-only or bench participants available for that game.

Imported teams can be unknown or detached. A `.ScoreKeep_Games` file may contain team data that does not safely attach to a local reusable team. In that case the canonical game should preserve the imported side and warn or require review rather than silently attaching the game to an unrelated team with the same name.

This model prevents an old game from changing meaning when a team is renamed, deleted from active lists, merged, recreated, or replaced. The historical game still has two distinguishable sides with game-time names and roles.

## 9. Game Player Participation

Game player participation represents one participant in one game. It may reference a reusable player when that relationship is known and safe. It also preserves game-time identity and display information such as name, jersey number, position, batting direction, team side, lineup eligibility, batting-order participation, pitching participation, and substitute status.

Participants may be starters, bench players, pitchers, pinch hitters, pinch runners, defensive replacements, guests, temporary players, unknown players, or imported compatibility participants. A participant can be eligible for the lineup without appearing in the batting order yet. A participant can pitch without batting where the game rules and ScoreKeep workflow support that. A participant can be known only by number or role during live scoring and corrected later.

Scoring events should refer to game participants rather than mutable current roster records. A plate appearance by a participant, a runner outcome by another participant, a substitution, or a pitcher assignment must remain historically tied to the game participant that existed at that time.

If a reusable player is edited after the game, the game participant can still show the game-time name and number that were recorded. If an imported game cannot safely attach a participant to a local reusable player, it remains usable as a detached historical participant with warnings where needed.

## 10. Lineup Model

The lineup model defines batting participation for one game independently from the current `Player.batOrder` field. Batting order is a game-specific fact, not a permanent player attribute.

A starting lineup records the initial batting slots for a side. A batting slot represents a position in the offensive order. The slot can have a starting occupant and later occupants through substitutions. The active occupant of each slot changes over time, but prior occupants remain part of game history.

Everyone Hits lineups and traditional lineups are both game-specific rules. In Everyone Hits, more roster participants may be batting-order occupants and defensive substitution may not change batting eligibility in the same way. In traditional lineups, bench players may not bat until they enter a slot. The canonical model should represent the selected rule without assuming one fixed roster size or one fixed inning grid.

Bench players are participants who are available for substitution or other game roles but are not currently active batting-slot occupants. Pitchers, defensive players, guest players, and unknown players may or may not be batting participants depending on the lineup rule and scoring decisions.

Lineup revisions before scoring are setup changes. They may replace the intended starting lineup because no historical scoring facts have depended on it yet. After scoring begins, lineup changes become historical events or corrections. A change to a player in a batting slot after completed plays exist must not rewrite those earlier plate appearances as if a different participant had taken them.

Unknown or incomplete lineups are valid product states when the user intentionally begins scoring before every detail is known. The model should preserve uncertainty and make it correctable. Lineup order differs from roster order, import order, alphabetical sorting, jersey-number sorting, and presentation filtering.

## 11. Substitution Model

A substitution is a historical game event. It records an incoming participant, an outgoing participant when known, the team side, the effective inning and game context, the batting slot when applicable, and the role of the change.

Substitution roles include pinch hitter, pinch runner, permanent lineup replacement, defensive replacement, pitcher-related change, and re-entry where supported by the selected rules. A substitution can affect batting order, base running, fielding context, pitching context, or only historical participation depending on the actual baseball situation.

Pitcher changes can interact with substitutions but are not always the same event. A new pitcher may enter defensively without batting. A pinch hitter may later stay in the game defensively. A pinch runner may replace an active runner on a base. The domain should preserve the actual participation effect rather than forcing every change into one simplified row.

Corrections and cancellations must be explicit. If a substitution was entered incorrectly, the corrected history should show that the prior event was removed, replaced, or superseded in a way that allows the game to replay. Substitutions modify current and future participation without rewriting previous plate appearances, runner outcomes, or pitcher responsibility that occurred before the effective point.

## 12. Pitcher Appearance Model

Pitcher participation is a game-specific historical period. A pitcher appearance records the pitcher participant, defensive team side, start point, end point when known, partial inning and outs context, and batter context where needed.

A start point may be before the first batter of an inning, between batters, during an inning after a number of outs, or as part of a correction. An end point may be inferred when another pitcher enters, when the game ends, or when the appearance is corrected. Partial innings and zero-out appearances must remain expressible because recreational and historical games can include mid-inning changes and incomplete responsibility.

An unknown pitcher should be a valid participant state. The scorer may not know the defensive pitcher during live play. The model should let scoring continue while preserving the missing assignment for later correction and warning reports not to present it as verified.

Multiple appearances or re-entry should be supported where the product rules allow it. A pitcher appearance is not merely a player plus aggregate totals. It is the period through which batting events and runner responsibility are interpreted.

Pitcher appearances relate to earned and unearned runs, pitcher responsibility, inherited runners, and winning-pitcher designation where supported. This document intentionally avoids defining statistical formulas. The next scoring engine design should define how appearances are applied, validated, and transformed into pitching projections.

## 13. Scoring Event Model

The authoritative recorded baseball event should be able to represent the existing ScoreKeep `Atbat` concept safely while also separating runner outcomes from the batter record. The recommended canonical concept is a recorded play event whose ordinary case is a plate appearance and whose contents include batter result plus one or more runner outcomes. This preserves ScoreKeep's plate-appearance-oriented workflow while avoiding the ambiguity of using one batter row to represent every movement on the bases.

A scoring event should identify the batter, batting team, defensive team, inning, half inning, event sequence, result, batter destination, batter out if any, runner outs, runner advancement, runs, RBIs, stolen bases, earned-run decisions, fielding or play notation, end-of-inning meaning, pitcher responsibility, correction status, imported legacy values, and any incomplete or unsupported values.

The event's sequence should define ordering within the game. Inning and half inning locate the event in baseball time. Column or grid values from legacy ScoreKeep records may help reconstruct presentation, but the canonical order should not depend solely on a scorecard column.

The batter destination should describe the batter's own outcome: no base, first, second, third, home, or out at a base-path context where needed. Runner outcomes should describe other participants who were already on base or became runners through the play. A play with the bases loaded and three runners moving should not require duplicate batter records to record those movements.

Result strings from existing records should be preserved as compatibility evidence. Supported results should map to canonical result categories. Unsupported result strings should be preserved with warning or compatibility-only classification rather than coerced into a misleading supported result.

Corrections should produce a revised event history that can be replayed. The model should be able to identify a corrected, deleted, superseded, or incomplete event without losing the original import evidence where that evidence is needed for review.

## 14. Runner and Base-State Model

Runner identity and movement should be represented explicitly. At the start of a play, base occupancy is derived from the ordered prior events: runner on first, runner on second, runner on third, or bases empty. Each active runner has a source, usually a prior batter reaching base or a pinch runner substitution.

A runner outcome records what happened to one runner during one play. It can represent advance, score, out, stolen base, forced advancement, base-path out, defensive indifference where supported, or no movement where that must be preserved for clarity. Multiple runners can have outcomes on the same play.

Pinch runners should replace the active runner on a base at a specific historical point. The replaced runner's prior participation remains intact, and the incoming runner becomes the active runner source for later outcomes from that base.

Third-out run handling must be representable. A runner may appear to cross home on a play, but the run may or may not count depending on the third-out context. The model should preserve the scorer's run and RBI decisions and allow the scoring engine to validate them against the recorded outs.

Impossible duplicate occupancy should be impossible in completed derived state. One active runner cannot occupy two bases. Two active runners cannot occupy one base. A scored or retired runner cannot remain active on a base. If imported records or a correction create such a state, the game should be warning, repair, or rejection eligible rather than silently normalized.

Base occupancy is derived from ordered recorded events. It is not an unrelated mutable total. Corrections should replay downstream state so current runners, score, outs, inning, next batter, and pitcher responsibility remain coherent.

## 15. Recorded Facts and Derived State

Recorded facts may include game identity and settings, team identity, participant identity, game-time snapshots, starting lineup, scoring events, runner outcomes, pitcher appearances, substitutions, user-entered RBI decisions, earned-run decisions, notes, lifecycle decisions, import provenance, and compatibility evidence.

Derived state may include current score, inning totals, outs, current runners, current and next batter, hits, errors, batting statistics, pitching statistics, box score, scorecard cells, reports, PDFs, export summaries, game list summaries, and accessibility descriptions.

Derived values should not become competing authorities. If two reports need a final score, both should derive it from the same recorded run events and scoring engine interpretation. If performance requires caching, cached values should be invalidatable and reviewable as derived projections, not independent baseball truth.

Legacy `Game.hscore` and `Game.vscore` fields should be treated as compatibility and migration-review values unless a later design proves a specific authoritative role. Current baseline evidence shows scores are often recalculated from `Atbat.maxbase == "Home"` in display and report paths. During migration, stored score fields should be compared against derived runs. Agreement can increase confidence. Disagreement should create a warning, repair decision, or compatibility classification rather than silently choosing whichever value is convenient for the current screen.

## 16. Game Lifecycle State

The canonical domain needs lifecycle state so the product can distinguish an incomplete setup from an active game and an interrupted game from a completed game.

Draft or created means a game record exists but may not yet have both sides, settings, or lineups. Configured means the essential game setup is present. Ready means the game is prepared enough for live scoring, even if some optional information such as a starting pitcher is unknown. In progress means scoring has begun and current game state is derived from recorded events.

Interrupted or suspended means the game has a preserved non-final baseball state and may be resumed later. Completed means the user or scoring flow has declared the game finished. Archived is a presentation or retention concept for games that should remain preserved but may not appear in ordinary active lists. Imported historical game and sample game are origin classifications that can explain provenance, warnings, or first-launch behavior.

Some lifecycle changes are explicit user decisions: marking a game complete, suspending a game, accepting incomplete setup, archiving a game, importing a historical game, or deleting a draft. Other state can be derived from recorded events: scoring has begun, current inning, current outs, or whether the expected inning count has been reached. The model should avoid assuming the current application already persists these states.

## 17. Unknown, Missing, and Unsupported Data

Unknown team means the side participated but the team identity or display name is not known. Unknown player means a participant exists but the person's identity is not known. Unknown pitcher means the defensive pitcher for a period or event is not known. These states are valid uncertainty, not empty strings or guessed records.

Missing lineup means scoring can be attached to participants or unknown slots while the initial order is incomplete. Missing participant reference means a legacy or corrupted record references a player that cannot be resolved. Unsupported scoring result means the result string or encoded play cannot yet be interpreted into a supported canonical category. A legacy value that cannot yet be interpreted should be preserved as evidence.

Corrupted optional media, such as invalid photo or logo data, should not make baseball facts unusable. The media can be omitted, warned, repaired, or replaced with presentation fallback while preserving the team, player, or game record. A partially imported historical game may remain usable if its teams, participants, events, and warnings are coherent enough for review.

Unknown is different from empty, zero, or guessed. Empty may mean a user intentionally left an optional note blank. Zero may mean no RBIs, no outs, or no runs. Unknown means the information is not available or not yet trusted.

A record may remain usable with warnings when the uncertain value does not prevent the game from being identified, displayed, corrected, or safely exported with limitations. A record must be rejected or repaired before use when it would attach events to unrelated teams or players, create impossible base state, lose participant history, crash reporting, or present unsupported values as verified baseball facts.

## 18. Validation and Invariants

The domain should define invariants in baseball terms, not as implementation assertions.

Two game sides must be distinguishable. A game participant must belong to an understandable side. A completed scoring event must have coherent participant, side, inning, half-inning, and sequence context.

One active runner cannot occupy two bases. Two active runners cannot occupy one base. A scored runner cannot remain active on a base. A retired runner cannot remain active on a base. A completed play cannot leave the base state incoherent without warning, repair, or rejection.

Batting slots cannot have ambiguous simultaneous occupants for the same effective period. Substitutions must preserve prior participation and affect only current and future participation unless explicitly entered as a correction.

Pitcher appearances should not silently overlap incompatibly for the same defensive side and event period. Unknown or incomplete pitcher periods are allowed, but they must remain visible.

Historical events must not depend solely on mutable names. Derived scores should reconcile with recorded run events or expose a mismatch. Imported records must not attach to unrelated teams or players silently.

The scoring engine and validation layer should make impossible or unsupported states visible to application services. This document does not define assertion syntax, exception types, database constraints, or UI error text.

## 19. Legacy Model Mapping

The following mappings describe conceptual legacy records, not required code changes.

| Legacy concept | Meaning to preserve | Ambiguity or risk | Likely canonical destination | Classification |
| --- | --- | --- | --- | --- |
| `Game` | One saved game with teams, date, location, settings, players, at-bats, lineups, pitchers, substitutions, and stored scores. | Combines facts, relationships, derived values, compatibility state, and lifecycle inference. | Canonical game plus game team participation, game participants, facts, projections, and compatibility evidence. | Fact container plus migration concern. |
| `Team` | Reusable team with name, coach, details, players, games, and logo. | Names are used for matching; current edits can affect historical interpretation. | Reusable team record and game-time team snapshots. | Fact when current roster record; migration concern for history. |
| `Player` | Reusable player with name, number, position, batting direction, bat order, team, at-bats, and photo. | `batOrder` mixes current roster data with game lineup meaning; names and numbers are not identity. | Reusable player plus game player participation and lineup entries. | Fact for roster fields; migration concern for game participation. |
| `Atbat` | Plate-appearance-oriented scoring row with batter, team, result, base, outs, RBIs, stolen bases, earned-run flag, notes, inning, sequence, and scorecard column. | One row can ambiguously stand for batter outcome, runner state, placeholder lineup row, pinch hitter marker, and derived score effects. | Scoring event containing batter outcome, runner outcomes, order, notation, and compatibility evidence. | Recorded fact with compatibility risk. |
| `Lineup` | Game/team lineup record with Everyone Hits flag, inning, and players. | Export may omit player lists; lineups may be revised by deleting at-bats; historical timing is not fully explicit. | Starting lineup, batting slots, lineup history, and game participant membership. | Recorded fact plus migration concern. |
| `Pitcher` | Pitcher record with player, team, game, start/end inning/out/batter markers, stats, and win flag. | Mixes appearance boundaries and aggregate statistics; marker interpretation can drift. | Pitcher appearance periods plus derived pitching projections. | Appearance fact plus derived-value risk. |
| `Game.replaced` | Outgoing players for substitutions. | Parallel array relationship can lose timing, slot, and pairing clarity. | Substitution events with outgoing participant references. | Compatibility value and migration concern. |
| `Game.incomings` | Incoming players for substitutions. | Parallel array relationship can mismatch replaced players or miss role/timing. | Substitution events with incoming participant references. | Compatibility value and migration concern. |
| `hscore` | Stored home score. | May disagree with runs derived from at-bats. | Compatibility evidence, possible cached projection after validation. | Derived value or migration concern. |
| `vscore` | Stored visiting score. | May disagree with runs derived from at-bats. | Compatibility evidence, possible cached projection after validation. | Derived value or migration concern. |
| `Player.batOrder` | Current batting order or lineup availability, with special values such as non-hitting. | Batting order is game-specific and changes through substitutions. | Lineup slot assignment or roster default preference where intentionally supported. | Migration concern. |
| Result strings | User-visible scoring terminology such as hits, outs, walks, errors, and special markers. | Spelling variants, unsupported strings, and substitution markers can be interpreted inconsistently. | Canonical result category plus preserved legacy string. | Fact with compatibility evidence. |
| `maxbase` | Batter or row base destination, including Home for runs. | May represent batter destination only and not all runner movement; Home currently drives score derivation. | Batter outcome and runner outcome records. | Recorded fact with derived-score implications. |
| `outAt` | Base-path out or safe marker. | One field cannot describe multiple runner outs on a play. | Batter out and runner out outcomes. | Recorded fact with ambiguity. |
| Inning values | Inning and half-inning context, sometimes represented by numeric/fractional values. | Fractional or presentation-oriented encoding can be brittle. | Explicit inning number and half inning. | Recorded fact and migration concern. |
| Sequence values | Order within inning/team scoring flow. | Can be affected by fixed-size assumptions and duplicate placeholder rows. | Event order and batting-order progression evidence. | Recorded fact and migration concern. |
| Column values | Scorecard grid placement. | Presentation grid can be confused with authoritative event order. | Derived scorecard projection or compatibility evidence. | Presentation/compatibility value. |

## 20. Compatibility File Mapping

Compatibility structures are transport contracts rather than the canonical domain model. `ShareTeam`, `SharePlayer`, `ShareGame`, `ShareAtbat`, `ShareLineup`, and `SharePitcher` describe how ScoreKeep exchanges supported records through `.ScoreKeep_Players` and `.ScoreKeep_Games`. They should be mapped into and out of the canonical model through compatibility adapters.

`ShareTeam` maps to reusable team evidence and, inside a game file, game-time team participation evidence. Its name, coach, details, players, games, and logo should be preserved where supported, but a nested team reference should not automatically become the authoritative current team record.

`SharePlayer` maps to reusable player evidence in roster files and game participant evidence in game files. Name, number, position, batting direction, batting order, team reference, at-bats, and photo should be preserved. Name-based matching should be treated as a conflict-review hint rather than identity.

`ShareGame` maps to canonical game evidence, including game identity, date, location, highlights, stored scores, Everyone Hits setting, inning count, visiting side, home side, players, at-bats, lineups, pitchers, replaced players, and incoming players.

`ShareAtbat` maps to scoring event evidence. Its result, maxbase, outAt, inning, sequence, column, RBIs, outs, sacrifices, stolen bases, earned-run flag, play record, and end-of-inning flag should be preserved while being interpreted into batter and runner outcomes where possible.

`ShareLineup` maps to lineup evidence. Existing limitations require careful handling because exported lineup player lists may be missing. A decoded lineup without players may still establish team, inning, and Everyone Hits evidence, but it should not invent lineup membership.

`SharePitcher` maps to pitcher appearance evidence. Player, team, game, start and end markers, strikeouts, walks, hits, runs, and win flag should be preserved, with aggregate values treated carefully when they can be derived from scoring events.

Known limitations require careful mapping: missing exported lineup player lists, simplified nested team references, name-based matching, required synthesized Codable fields, missing or ambiguous historical identity, substitutions represented through `replaced` and `incomings` arrays, and stored scores that may disagree with derived runs. These limitations are compatibility obligations, not reasons to weaken the canonical model.

## 21. Persistence Boundary

The domain expects persistence to preserve stable identity, retrieve a complete game record, preserve ordered facts, support safe updates, preserve historical references, record migration outcomes, store unknown or unsupported legacy records safely, maintain media references, and report failures in product terms.

Retrieving a complete game means loading enough information to replay the game: game identity, sides, participants, lineups, substitutions, pitcher appearances, scoring events, runner outcomes, notes, lifecycle state, compatibility evidence, and media references where needed for display or export.

Safe updates should preserve prior valid state when an operation fails. Recording a play, correcting a play, changing a lineup, importing a game, repairing a record, or updating media should not leave unrelated records partially rewritten.

Migration outcomes should be persisted or reportable. A record may be fully canonical, accepted with warnings, compatibility-only, partially imported, repaired, rejected, or awaiting user conflict resolution. Unsupported legacy records should remain understandable enough for review when practical.

The domain must not depend on SwiftUI queries, view lifecycle, selected tabs, sheet presentation, or direct view mutation of persistence objects. Persistence can use SwiftData, a future schema, files, caches, or adapters, but the baseball model should depend only on product records and explicit transaction outcomes.

## 22. Reporting and Presentation Projections

The canonical model should produce projections for game list summaries, live scoreboard, current game state, scorecard grid, batting report, pitching report, box score, PDF, export, and accessibility descriptions.

A game list summary should derive team names, date, location, lifecycle state, warning status, and score summary from canonical facts and validated projections. It should not depend on stale stored score fields without reconciliation.

A live scoreboard should derive current inning, half inning, outs, base occupancy, score, current batter, next batter, current pitcher, and warnings from replayed ordered facts. It should be a view of the game, not a separate mutable game state.

The scorecard grid should be a projection from events, lineup slots, substitutions, and runner outcomes. Grid cells should not become the only authority for event order or base state.

Batting reports, pitching reports, box scores, PDFs, and export summaries should all use the same interpreted game state. If an event is unsupported or a pitcher is unknown, every projection should expose that uncertainty consistently according to its presentation needs.

Accessibility descriptions are projections too. Spoken descriptions of score, runners, batting order, substitutions, warnings, and report rows should be derived from the same facts used by visual screens.

None of these projections should mutate the game. Corrections and repairs should be explicit application actions, not side effects of opening a report or generating a PDF.

## 23. Migration Implications

Existing records may need adapters before physical schema migration. The rewrite can introduce canonical interpretation around legacy SwiftData records and compatibility files before changing stored shapes. This supports incremental replacement and reduces big-bang migration risk.

Stable canonical identity may need to be assigned during migration or import. When legacy UUIDs are valid and safely associated, they should be preserved. When records lack reliable identity, migration should create stable local identity and preserve the matching evidence that led to it.

Historical participant snapshots may need to be reconstructed where possible from teams, players, game player arrays, lineups, at-bats, pitchers, and compatibility files. Reconstruction should be conservative. If the evidence is ambiguous, the record should carry warnings rather than inventing unsupported certainty.

Ambiguous records may require compatibility-only preservation. A game with unsupported result strings, missing participant references, mismatched scores, or unclear substitutions can still be valuable historical data. It should be preserved when safe, but the product should make limitations visible.

Migration must be fixture-backed and reversible or recoverable where practical. Fixtures should cover duplicate names, reused numbers, substitutions, pitcher changes, stored-score mismatches, unsupported results, missing lineup lists, invalid media, and the seeded game. A failed migration should not destroy the original record.

No big-bang transformation is required before the new domain can be used. Rewritten services can adapt legacy data into canonical records for scoring, reports, import review, or export while the physical persistence design is still being developed.

## 24. Risks and Open Questions

Recommendation: freeze enough historical team and player information per game to keep reports, scorecards, exports, and corrections understandable. Open question: whether photos and logos should be frozen per game, referenced live from current records, or stored as optional historical media snapshots.

Recommendation: model the authoritative event as a recorded play event whose ordinary case is a plate appearance with runner outcomes. Open question: how broad the event model should become for non-plate-appearance events such as steals, administrative corrections, or defensive changes that occur between batters.

Open question: how much runner responsibility and pitcher responsibility should be recorded directly by the scorer versus derived by the scoring engine. Earned-run and RBI decisions are current workflow concepts, but inherited-run responsibility may require more explicit modeling than legacy records provide.

Open question: how to migrate substitutions represented by parallel `replaced` and `incomings` arrays plus special at-bat strings. The canonical model needs historical substitution events, but legacy evidence may not always identify timing, role, or slot safely.

Open question: how to distinguish identical players or teams in old name-based data when valid identifiers are missing or when import code previously merged by names. Some records may need user review or compatibility-only preservation.

Recommendation: treat stored score fields as compatibility evidence until reconciled. Open question: whether any workflow should intentionally preserve stored `hscore` and `vscore` as user-entered final scores when event-level scoring is incomplete.

Open question: how unsupported legacy result strings should be preserved in exports after canonical import. They must not be lost, but exporting unsupported values may require compatibility metadata or warnings.

Open question: how much domain complexity is justified for ScoreKeep's practical users. The model should preserve real baseball meaning and compatibility risks without turning every recreational scoring workflow into professional-grade official scoring software.

## 25. Success Criteria

The canonical domain model succeeds when ScoreKeep has one consistent baseball meaning for teams, players, games, participants, lineups, substitutions, pitcher appearances, scoring events, runner outcomes, and derived projections.

Stable identity should protect duplicate names, reused jersey numbers, doubleheaders, renamed teams, edited players, imported records, and historical game references.

Historical preservation should keep old games understandable after current roster changes, media changes, imports, exports, corrections, and report regeneration.

Recorded facts and derived state should be clearly separated. Scores, statistics, scorecards, PDFs, and reports should derive from the same ordered facts rather than competing stored totals or duplicated calculations.

The model should support live scoring, corrections, lineups, substitutions, pitcher participation, reports, scorecards, imports, exports, and compatibility with existing SwiftData records and `.ScoreKeep_Players` and `.ScoreKeep_Games` files.

Unknown, malformed, ambiguous, and unsupported data should be handled safely. The product should warn, repair, preserve, or reject records in product terms rather than guessing silently or crashing.

The model should be testable through canonical fixtures. Fixture-backed replay should be able to verify identity, historical snapshots, scoring events, runner outcomes, pitcher appearances, substitutions, report projections, compatibility mapping, and migration outcomes.

The model should remain independent from SwiftUI and persistence implementation. UI and storage choices can change without changing the underlying baseball meaning.

## 26. Recommended Next Design Document

The recommended next design document is `19-ScoringEngineDesign.md`.

The scoring engine design should define how ordered canonical facts are validated, applied, corrected, replayed, and transformed into current game state and reportable projections. It should describe event application, lineup progression, runner advancement, outs, inning transitions, pitcher responsibility, substitution effects, correction replay, validation outcomes, and projection generation without tying those rules to SwiftUI views or legacy persistence shapes.

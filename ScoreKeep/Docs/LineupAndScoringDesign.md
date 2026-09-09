# Lineup and Scoring Design

This document is the durable ScoreKeep 6.1 product and architecture record for lineup setup, lineup correction, and scoring safety. It captures the decisions from the Starting Lineup persistence investigation, safe single-player correction investigation, slot-based lineup investigation, live scorecard player-identification investigation, and Phase 1 lineup-slot safety foundation.

## Direction

The lineup workflow is changing because real games often reveal that an imported or pre-entered lineup contains the wrong Player in a batting slot. The current whole-lineup `Upd Lineup` path is too destructive for ordinary scored-game correction because it can rebuild lineup-related scoring records instead of changing only the single incorrect identity.

ScoreKeep 6.1 should support a simpler user model:

A lineup slot's Player identity remains editable only while persisted game evidence proves changing it is safe. Once participation makes that identity historical, the slot locks.

Users are not required to construct a perfect lineup before scoring. The supported workflow is:

1. Accept the imported/default lineup.
2. Optionally prepare or correct the lineup before the game.
3. Correct Players on the fly as batters appear, while each slot remains individually safe.

There is no separate "on-the-fly lineup mode." There should also be no fake or persisted "Unknown Player" records for lineup slots. If the correct Player is not on the roster, the user should add a real Player through the standardized Add Player workflow.

## Default Lineup Source

When a game has no game-specific lineup, existing roster/import `Player.batOrder` is the default lineup source. This lets live scoring eventually obtain a valid lineup without requiring the user to manually open Starting Lineup and save first.

The minimum materialized state for live scoring is:

- A game/team `Lineup` in batting-order order.
- First-column pristine placeholder `Atbat` records for the batting slots.
- Those placeholder atbats attached to `Game.atbats`.
- The lineup Players represented in `Game.players`.
- Everyone-hits rosters represented beyond the first nine slots when the roster/default order indicates them.

Existing game-specific lineup and scoring evidence has priority over roster fallback. Ambiguous duplicate or conflicting persisted state must fail closed, not be silently repaired.

## Shared Authority

The Phase 1 implementation is `ScoreKeep/Common/LineupSlotSafetyCoordinator.swift`.

Future Starting Lineup and live scorecard UI must use this coordinator as the single authority for:

- Resolving a game's batting lineup slots.
- Materializing a game-specific lineup from roster/default `Player.batOrder` when no game lineup exists.
- Deriving whether an individual slot is editable or locked from persisted evidence.
- Safely reassigning an eligible slot to another roster Player.
- Failing closed on ambiguous or unsafe persisted state.

`resolvedSlots` is the authoritative slot ordering. Future code should not infer batting order from raw SwiftData relationship-array order.

Phase 1 materialization source priority is:

1. Existing non-empty game/team `Lineup`.
2. Existing first-column placeholder `Atbat` records when they can define the lineup.
3. Ordered eligible roster Players from current `Player.batOrder`.

For an eligible Player correction, the coordinator reassigns the existing pristine placeholder `Atbat` rather than deleting or recreating unrelated scoring. It updates the target lineup slot, batting-order ownership, and `Game.players` while preserving unrelated atbats, score, inning, outs, bases, pitchers, substitutions, and accepted scoring evidence.

Phase 1 currently has 16 focused tests passing.

## Editability and Locking

Editability is derived from persistent identities and persisted game evidence, not view state or Player names.

A slot locks when the coordinator finds evidence that changing the Player identity could rewrite history or detach scoring. Locking evidence includes:

- Missing, duplicate, or ambiguous lineup/slot/placeholder state.
- A placeholder atbat that is no longer pristine.
- Any other atbat participation by that Player in the game.
- Accepted scoring operation evidence.
- Substitution or replacement participation involving the Player.
- Pitcher participation involving the Player.
- Current-game or historical state that makes the Player identity unsafe to rewrite.

The UI should expose this as a simple editable/locked state with a concise lock reason from the coordinator. The model should continue to fail closed even when a future UI tries to offer a correction.

## Starting Lineup

Starting Lineup remains the full pregame lineup preparation surface.

Current 6.1 implementation status:

- Eligible Player fields are roster Player pickers when `LineupSlotSafetyCoordinator` reports the slot is editable.
- Locked slots display non-editable Player text with user-facing lock explanation.
- `Add Player…` appears first in the Player picker with the plus icon so the capability is obvious.
- Saving a newly added Player returns to the originating slot and selects that Player if the slot remains eligible.
- Number, position, and batting direction continue deriving from the selected Player.
- Pregame batting-order drag/reorder remains supported through the currently resolved coordinator slots.
- General batting-order reorder locks once any resolved slot is no longer editable.
- Player-identity correction and batting-order reordering use different safety rules.
- Useful resumable partial-lineup behavior is preserved before scoring.

The existing behavior where partial lineup edits persist on Back is valuable. It should remain available before scoring as a draft/resume behavior, but it must not become a path to silently rewrite scored history.

## Live Scorecard

The final 6.1 UX decision is that eligible Player identity must be directly selectable from the live scorecard. The scorer should not be forced through an intermediate trip to Starting Lineup when the wrong Player is discovered at the plate.

Both Starting Lineup and the live scorecard must use `LineupSlotSafetyCoordinator`. The live scorecard must not duplicate safety or mutation logic.

Future live scorecard Player dropdown behavior:

- Available only while that slot is eligible.
- `Add Player…` appears first with the plus icon.
- Eligible roster Players follow.
- Choosing a Player performs the shared safe slot reassignment.
- Add Player uses the existing standardized Add Player workflow.
- Save returns to the originating scorecard slot and selects the new Player if the slot remains eligible.
- Once locked, Player identity becomes non-editable text.

The current scorecard displays only jersey number and name. The planned Player-identification hierarchy is:

1. Name
2. Jersey number
3. Batting direction
4. Position
5. Batting-order slot as context

Planned presentation:

- iPhone landscape: Name, number, and batting direction. Omit position by default if space requires.
- iPad landscape: Name, number, batting direction, and position.
- Player picker rows use the reusable `PlayerMenuRowLabel` format: name gets flexible single-line space, while jersey number and batting direction stay together as trailing metadata.
- Preserve scoring-cell dimensions and usability.
- Preserve substitution distinction and accessibility information.

## Replacement and Pitcher Workflows

Replacement represents an actual substitution. It does not rewrite the original starting-lineup slot.

Lineup correction must not be represented as Replacement. Pitcher selection and pitcher changes remain separate workflows. Do not conflate lineup correction, substitution, and pitching participation.

## Upd Lineup

The existing destructive whole-lineup `Upd Lineup` behavior is not the desired normal correction mechanism once scoring exists.

The 6.1 direction is safe per-slot Player correction. After replacement paths are proven, remove or retire the destructive operation from normal scored-game use. Any future whole-lineup recovery mechanism must be designed separately and must prove how it preserves or intentionally remaps historical scoring.

Sophisticated preservation/remapping of historical scoring across a destructive whole-lineup rewrite is deferred. The current priority is safe per-slot correction, which solves the common wrong-Player case without rebuilding historical scoring.

## Deferred Work

### ScoreKeep 6.5: Dual MLB Default Lineups

Deferred to 6.5:

- Team-level default lineup versus RHP.
- Team-level default lineup versus LHP.
- Persistence/model design.
- Selection/materialization based on opposing starting pitcher handedness.
- UI for maintaining both templates.
- Import/export schema implications.
- Changes to the external MLB roster research/generation workflow.

Current 6.1 work should avoid unnecessary assumptions that would make this difficult later, but it should not implement or reshape architecture specifically for dual MLB defaults.

### Post-6.1: MLB Internet-Assisted Entry

Deferred post-6.1:

- Find MLB Player assistance in standardized Add Player.
- Populate reliable available data such as name, jersey number, position, and batting direction.
- User reviews and explicitly saves through the existing standardized draft workflow.
- MLB-assisted Add Team.
- Investigate Team/roster retrieval where appropriate.
- Internet lookup assists existing Add forms; it must not create another Player/Team creation path.
- Investigate eventually supplementing or replacing the external `.ScoreKeep_Players` roster-generation workflow with direct MLB data retrieval.

## Implementation Roadmap

1. Phase 1: completed locally. Shared lineup-slot materialization, safety, reassignment foundation, and focused tests.
2. Starting Lineup integration: completed locally for editable Player picker, locked Player text, safe coordinator reassignment, pre-scoring reorder, and Starting Lineup Add Player return-to-slot.
3. Automatic default lineup materialization into the live-scoring entry path.
4. Live scorecard richer Player identification and direct eligible-Player dropdown.
5. Add Player return-to-origin integration for live scorecard.
6. Accessibility and layout verification.
7. Retire normal destructive `Upd Lineup` behavior once replacements are proven.
8. Manual verification on iPad and real iPhone 16e before acceptance.

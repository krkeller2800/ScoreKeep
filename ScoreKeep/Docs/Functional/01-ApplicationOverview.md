# ScoreKeep Functional Specification

## 01. Application Overview

## 1. Purpose

ScoreKeep is a baseball scorekeeping application for recording games, managing teams and players, producing baseball statistics, and sharing game and roster data. Its primary purpose is to let a user keep an accurate scorebook during a live baseball game while still supporting preparation before the game and review after the game.

The application is intended for parents, coaches, volunteers, recreational teams, and small baseball organizations that need practical scorekeeping without the overhead of a league-management platform. ScoreKeep should support common amateur and recreational workflows: building rosters, setting lineups, scoring plate appearances, tracking pitchers, reviewing batting and pitching statistics, generating scorecards, and moving roster or game files between devices.

The overall design philosophy is speed, reliability, and clarity. Live scoring must remain efficient under game conditions, where the user has limited time and may need to make corrections quickly. The product should favor durable user data, understandable workflows, offline operation, and compatibility with existing ScoreKeep files over visual complexity or broad feature expansion.

## 2. Product Goals

- Provide fast scorekeeping during live baseball games, with common scoring actions available in as few steps as practical.
- Make team and player management simple enough for casual users while still supporting lineups, substitutions, photos, logos, and player details.
- Produce accurate baseball statistics from scored games, including game scores, batting summaries, pitching summaries, and scorecard-style reports.
- Preserve long-term compatibility with existing user data, exported roster files, exported game files, document types, and relevant purchase state.
- Work reliably without an Internet connection for core workflows such as team management, game setup, live scoring, reports based on local data, and importing local files.
- Support sharing and transfer of ScoreKeep roster and game files through standard Apple document workflows.
- Maintain a short learning curve for users who understand baseball but are not necessarily technical users or experienced official scorers.
- Protect user data during editing, deletion, import, lineup changes, and scoring corrections.
- Clearly distinguish free and premium capabilities so users understand when a purchase is required.

## 3. Non-Goals

ScoreKeep is not intended to become a full league operations system. The following capabilities are outside the product scope unless a future specification explicitly changes that boundary:

- League scheduling, field scheduling, standings, or season administration.
- Tournament bracket management.
- Live Internet score broadcasting or real-time spectator feeds.
- Team messaging, chat, email campaigns, or parent communication tools.
- Practice planning, drills, attendance, or player development plans.
- Financial management, registration fees, dues, fundraising, or payment collection.
- Social networking, public profiles, comments, likes, or follower systems.
- Umpire assignment, referee coordination, or official league compliance workflows.
- Advanced video capture, streaming, tagging, or highlight editing.
- General-purpose statistics platforms for sports other than baseball.

## 4. Target Users

**Parents and family scorekeepers** need a quick way to create teams, enter players, keep score from the stands, correct mistakes, and share results or scorecards with others. They benefit from an interface that assumes baseball knowledge but does not require professional scorekeeping expertise.

**Coaches and assistant coaches** need reliable rosters, lineups, substitutions, pitcher tracking, and post-game statistics. They may use the application repeatedly across a season and need data to remain available over time.

**Volunteer scorekeepers** need a focused workflow that can be learned quickly before or during a game. They need clear scoring choices, predictable correction behavior, and minimal navigation during live play.

**Small organizations and recreational leagues** need lightweight roster and game-file sharing without adopting a complete league-management system. They may rely on exported files to move data between organizers, coaches, and scorekeepers.

**Fans or informal record keepers** need a practical scorebook for individual games, MLB roster downloads, and generated reports without committing to team administration workflows.

## 5. Supported Platforms

ScoreKeep supports Apple mobile devices, including iPhone and iPad. The product should provide appropriate navigation and layout for both device classes while preserving the same core capabilities across them.

The application should support portrait-oriented use as the primary expectation for iPhone. iPad layouts may take advantage of the larger screen and should support efficient landscape or wide-screen use where practical. The scoring interface must remain usable on supported screen sizes without hiding essential controls.

Core workflows must operate offline. Users must be able to create and edit teams, create and score games, manage lineups, enter pitching information, view locally stored statistics, generate reports from local data, and open compatible local ScoreKeep files without Internet access.

Internet access is required only for network-dependent capabilities, including MLB roster downloads, remote announcements, StoreKit purchase activity, purchase status checks that require Apple services, and opening external web links. Network failures must not prevent access to local scorekeeping data.

ScoreKeep must continue to recognize compatible external roster and game files created by earlier versions of the application. It must also continue to export files that can be shared through standard Apple document, share sheet, and file-opening workflows.

## 6. Major Functional Areas

- Team management: create, edit, search, sort, and delete teams; maintain team details and visual identity.
- Player management: create, edit, import, organize, and delete players; maintain player numbers, positions, batting details, photos, and team membership.
- Game management: create games, select home and visiting teams, edit game details, review existing games, and continue scoring saved games.
- Lineups: build and update batting orders, support everyone-hits rules, and prepare a game for scoring.
- Live scoring: record plate appearances, results, bases reached, outs, runs, RBIs, stolen bases, earned-run state, and fielding notes.
- Pitching: assign pitchers, record pitcher participation, track pitching markers, and support pitching reports.
- Substitutions: record replacement players and preserve the visible relationship between outgoing and incoming players.
- Statistics: calculate game scores, batting performance, pitching performance, box scores, and scorecard totals from scored game data.
- Reports: provide scorecards, batting summaries, pitching summaries, and shareable PDF-style output where supported.
- Import and export: read and write compatible ScoreKeep roster and game files; support user-selected import behavior for roster conflicts.
- Sharing: share roster files, game files, generated reports, and compatible documents through Apple sharing workflows.
- MLB roster downloads: retrieve available roster files from the supported online manifest and import downloaded roster data.
- Purchases: support current-season premium access for gated capabilities such as expanded game creation, report generation, PDF generation, and MLB download limits.

## 7. Core Design Principles

- User data must never be lost silently.
- Existing ScoreKeep roster and game files must remain readable.
- Existing exported file formats, document extensions, URL behavior, and purchase expectations must remain compatible where they are part of user workflows.
- Core scorekeeping must continue working without Internet access.
- Live scoring workflows should require minimal taps and should not depend on hidden setup once a game is underway.
- Corrections must be understandable, recoverable where practical, and limited to the intended game, team, player, or scoring event.
- Data integrity is more important than animation, decoration, or visual effects.
- Baseball terminology should be clear and consistent across scoring, reports, imports, exports, and help material.
- Duplicate names, renamed teams, imported files, and partial data must be handled carefully so unrelated records are not merged or damaged.
- Premium gating must not block users from accessing their existing local data.
- Reports and statistics should be derived consistently from the same scored game facts.
- The application should prefer explicit user confirmation for destructive actions, especially deletion, lineup replacement, and import overwrite choices.

## 8. Product Boundaries

ScoreKeep is a focused baseball scorebook and team roster utility. It helps a user prepare for a baseball game, keep score during the game, review baseball statistics after the game, and share ScoreKeep-compatible roster and game records with other devices or users.

ScoreKeep is not a league platform, communications system, scheduling product, social network, financial tool, video product, or general sports-management suite. Features should be accepted only when they strengthen the core scorekeeping, roster, reporting, sharing, or compatibility mission.

When evaluating new work, the default question should be whether the feature improves baseball scorekeeping or protects existing ScoreKeep data. Features that primarily serve administration, promotion, communication, or unrelated sports workflows should remain outside the product unless they are explicitly approved as a new product direction.

## 9. Success Criteria

The rewritten ScoreKeep application will be considered successful when users can rely on it for the full baseball scorekeeping lifecycle without losing trust in their data, their workflows, or their existing files.

- Existing ScoreKeep users can upgrade without losing teams, players, games, scoring records, photos, logos, purchase-related access, or user preferences that are part of the supported product experience.
- Existing ScoreKeep roster and game files remain readable, and users can continue sharing compatible roster and game files with other ScoreKeep users.
- Core scorekeeping workflows function without an Internet connection, including team selection, lineup management, live scoring, corrections, pitching, substitutions, statistics, reports based on local data, and local file import.
- Live scoring is fast enough for a user to keep pace with a real baseball game without abandoning the app for paper notes.
- Common scoring actions require minimal navigation and user effort during game play.
- Statistics and reports are internally consistent regardless of where the same game information is displayed.
- User data is protected during editing, importing, lineup changes, substitutions, scoring corrections, and deletion.
- The application behaves predictably throughout the game lifecycle, from setup through scoring, correction, reporting, sharing, and later review.
- Premium feature restrictions never prevent users from accessing, reviewing, correcting, importing, or exporting their own existing data.
- New functionality can be added without breaking compatibility with existing ScoreKeep data, exported files, or established scorekeeping workflows.

## 10. Future Expansion

The product should allow future growth without committing to those capabilities in the current scope. Potential expansion areas include:

- Cloud synchronization for a user's own ScoreKeep data.
- Controlled team collaboration where multiple trusted users can share scorekeeping responsibilities.
- Additional report types based on the same scored game data.
- More advanced batting, pitching, and fielding analytics.
- Improved import validation and compatibility tooling.
- Expanded roster sources beyond the current downloadable roster manifest.
- Additional baseball variants or rule options for recreational play.
- Support for additional sports only if the core baseball product remains stable and the product direction explicitly expands.

Future expansion must not compromise offline scorekeeping, existing file compatibility, data integrity, or the speed of live scoring.

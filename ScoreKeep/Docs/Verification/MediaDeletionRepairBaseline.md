# Media Persistence and Deletion/Repair Baseline

<!-- MARK: - 1. Media Inventory -->
## 1. Media Inventory

Current persisted media is limited to reusable player photos and reusable team logos. Player.photo and Team.logo are optional Data properties using SwiftData external storage. They are embedded in the SwiftData model as externally stored bytes, not managed by a production media repository or file-manager service.

Production-active media entry points include PhotosPicker assignment for player photos and team logos, pasteboard image conversion to PNG data in player and team edit screens, display reads in list/edit/score views, compatibility transport through SharePlayer and ShareTeam byte arrays, and report or score display reads of team logos. No game-specific image model, media owner relationship model, media cache table, app Documents media folder, bundled logo catalog, or authoritative derived image store is currently defined.

Generated screenshots and PDFs are generated output, not source media authority. Placeholder and default presentation behavior is derived by views when optional bytes are nil or cannot be decoded.

<!-- MARK: - 2. Storage Representations -->
## 2. Storage Representations

Player photos are optional Data on Player.photo with SwiftData external storage. Team logos are optional Data on Team.logo with SwiftData external storage. Compatibility files may carry player photo and team logo bytes in transport objects, where empty data is interpreted as missing media evidence by the canonical verification mapping.

The current model has no explicit media size limit, format limit, compression rule, resizing rule, transcoding rule, checksum, media identifier, historical game-time media snapshot, or media-specific transaction log. Replacement and removal are direct field mutations followed by the caller's ordinary SwiftData save behavior.

<!-- MARK: - 3. Test Media Method -->
## 3. Test Media Method

Verification uses deterministic test-owned byte arrays only. The tests do not access Photos, camera, clipboard, network, production assets, user files, app Documents media, or checked-in binary image fixtures. Representative valid media uses tiny fixed PNG byte sequences. Empty and malformed media use fixed Data values.

All media tests use isolated in-memory SwiftData stores created by test support. The stores use the current production model types but do not initialize ScoreKeepApp, seeding, StoreKit, Keychain counters, app storage, import routing, or production persistence locations.

<!-- MARK: - 4. Media Round-Trip Results -->
## 4. Media Round-Trip Results

Focused media verification proved player photo and team logo save and reload through a fresh context. Nil media remains optional. Empty data and malformed bytes are classified rather than promoted to trusted image evidence. Distinct owners retain distinct byte sequences. Repeated reloads are deterministic.

Byte counts and byte contents are preserved for representative player photos and team logos. Owner identities, unrelated game identities, unrelated team names, unrelated player names, and unrelated media remain unchanged during isolated media replacement and removal.

<!-- MARK: - 5. Replacement and Failure Results -->
## 5. Replacement and Failure Results

Successful media replacement persists and reloads as direct field mutation. Successful media removal persists as nil optional media while preserving the owning player or team record. A deterministic injected save failure during player-photo replacement is classified through CanonicalPersistenceTransactionResult as a save failure requiring reload and review; after rollback, the prior accepted media remains usable in the isolated evidence.

Malformed, unsupported, empty, missing-owner, duplicate-owner, and missing-media cases are classified with the established transaction and validation vocabulary. Baseball facts remain usable when media is malformed or unavailable. Allowance and entitlement probes remain unchanged.

<!-- MARK: - 6. Actual Delete Rules Discovered -->
## 6. Actual Delete Rules Discovered

The current SwiftData model declares relationships implicitly without explicit @Relationship delete rules. Effective delete behavior is therefore treated as current SwiftData relationship behavior plus production manual cleanup where current views perform it.

Game references home team, visiting team, players, at-bats, lineups, pitchers, replaced players, and incoming players. Team references players and games. Player references team and at-bats. Atbat, Lineup, and Pitcher have non-optional game, team, and player references. Replacement evidence is represented by parallel Game.replaced and Game.incomings arrays. Media is direct optional Data on the owning Player or Team, not a related record.

GameView has a manual game-delete route that deletes at-bats, pitchers, lineups, then the game. Other list and edit views contain direct deletes for teams, players, pitchers, and at-bats. These production routes were inspected but not changed.

<!-- MARK: - 7. Deletion Effects Verified -->
## 7. Deletion Effects Verified

Isolated deletion tests verified explicit deletion of a game, team, player, at-bat event, lineup, pitcher record, participant relationship removal, substitution evidence removal, player photo removal, and team logo removal. The tests verify deleted records by stable identifiers after fresh-context refetch rather than by reading deleted model instances.

The initial combined destructive test retained or traversed invalidated SwiftData references after deletion. It was corrected by splitting the scenario into smaller tests, capturing immutable UUID and count evidence before deletion, saving, then verifying surviving state from fresh post-delete fetches. No production deletion behavior was changed.

Unrelated teams, players, games, media, ordering evidence, allowances, and entitlement probes remain unchanged in the focused scenarios. No duplicate records appear.

<!-- MARK: - 8. Orphan and Ambiguity Risks -->
## 8. Orphan and Ambiguity Risks

Because relationship delete rules are implicit and several references are non-optional, deletion of referenced records is not treated as a fully safe success merely because the initiating object disappears. Referenced player and team deletion are classified as relationship repair or orphan-candidate evidence requiring explicit review.

Post-delete relationship effects are inspected only through newly fetched surviving records when safe. Where dereferencing a deleted related model could invalidate the instance, tests avoid that access and classify the dependent relationship outcome as review-required or ambiguous rather than silently repaired.

<!-- MARK: - 9. Repair Assessment Vocabulary -->
## 9. Repair Assessment Vocabulary

CanonicalPersistenceRepairAssessment introduces non-routed assessment-only vocabulary. It can classify no repair required, reload required, review required, relationship repair candidate, ordering repair candidate, media cleanup candidate, duplicate identity candidate, orphan candidate, unsupported repair, unsafe automatic repair, explicit user decision required, migration required, record should remain preserved, and cannot be interpreted canonically.

The assessment type records that it does not modify a model, save, delete, merge, generate identity, reorder, replace media, consume allowances, change entitlements, or route production behavior. It is not a repair executor.

<!-- MARK: - 10. Proof Reads Do Not Repair -->
## 10. Proof Reads Do Not Repair

Focused repair-boundary tests verified persisted-to-canonical interpretation, canonical mapping, replay-adjacent ordering validation, report-derived run counting, export-style snapshot creation, relationship validation, ordering validation, and media validation without store mutation. The tests compare immutable pre-read and post-read inventory snapshots and verify the read context has no changes.

Broken relationship, duplicate identity, ordering conflict, malformed media, orphan candidate, and unsupported automatic repair evidence remain diagnostic. Ordinary reads do not delete, nullify, merge, generate identities, resequence events, remove media, rewrite arrays, or save the store.

<!-- MARK: - 11. Allowance and Entitlement Separation -->
## 11. Allowance and Entitlement Separation

The isolated verification harness does not initialize StoreKit, Keychain counters, PurchaseManager, ScoreKeepApp, or app storage. Tests use deterministic probe values to prove media, deletion, and repair assessments do not consume a free game allowance, change an MLB download count, or change entitlement markers.

Purchase and allowance state remains outside baseball persistence in this verification run.

<!-- MARK: - 12. Remaining Migration Prerequisites -->
## 12. Remaining Migration Prerequisites

No migration-source inventory, migration fixture, empty-store migration, existing-store migration, interrupted migration, repeated migration, failed migration recovery, purchase migration, schema change, production repair executor, production delete coordinator, production media repository, or routing change was introduced.

Remaining prerequisites include the next planned migration-source inventory, privacy-safe representative migration fixtures, empty-store migration verification, and later existing/interrupted/repeated/failed migration verification with purchase separation.

import Foundation

enum RosterImportBoss {
    case imported
    case current
}

enum ManualDuplicatePlayerChoice {
    case useExistingPlayer
    case updateExistingPlayer
    case createNewPlayerAnyway
    case cancel
}

struct ManualDuplicatePlayerChoiceResult {
    let shouldUseExistingPlayer: Bool
    let shouldCreateNewPlayer: Bool
    let didUpdateExistingPlayer: Bool
    let skippedUpdateForHistoricalReferences: Bool
}

enum RosterImportReconciler {
    static func activeSlot(_ order: Int) -> Int? {
        (1...9).contains(order) ? order : nil
    }

    static func matchingPlayer(for sharePlayer: SharePlayer, in players: [Player]) -> Player? {
        let importedIdentity = PlayerImportIdentity(name: sharePlayer.name, number: sharePlayer.number)

        return players.first {
            importedIdentity.stronglyMatches(PlayerImportIdentity(name: $0.name, number: $0.number))
        }
    }

    static func likelyMatchingPlayer(name: String, number: String, in players: [Player], excluding excludedPlayer: Player? = nil) -> Player? {
        let candidateIdentity = PlayerImportIdentity(name: name, number: number)

        return players.first {
            if let excludedPlayer, $0 === excludedPlayer {
                return false
            }

            return candidateIdentity.isLikelyManualMatch(for: PlayerImportIdentity(name: $0.name, number: $0.number))
        }
    }

    @discardableResult
    static func resolveManualDuplicatePlayerChoice(
        _ choice: ManualDuplicatePlayerChoice,
        matchedPlayer: Player,
        name: String,
        number: String,
        position: String,
        batDir: String,
        preserveHistoricalEvidence _: Bool
    ) -> ManualDuplicatePlayerChoiceResult {
        switch choice {
        case .useExistingPlayer:
            return ManualDuplicatePlayerChoiceResult(
                shouldUseExistingPlayer: true,
                shouldCreateNewPlayer: false,
                didUpdateExistingPlayer: false,
                skippedUpdateForHistoricalReferences: false
            )
        case .updateExistingPlayer:
            let didUpdate = updateNonblankPlayerFields(
                matchedPlayer,
                name: name,
                number: number,
                position: position,
                batDir: batDir
            )
            return ManualDuplicatePlayerChoiceResult(
                shouldUseExistingPlayer: true,
                shouldCreateNewPlayer: false,
                didUpdateExistingPlayer: didUpdate,
                skippedUpdateForHistoricalReferences: false
            )
        case .createNewPlayerAnyway:
            return ManualDuplicatePlayerChoiceResult(
                shouldUseExistingPlayer: false,
                shouldCreateNewPlayer: true,
                didUpdateExistingPlayer: false,
                skippedUpdateForHistoricalReferences: false
            )
        case .cancel:
            return ManualDuplicatePlayerChoiceResult(
                shouldUseExistingPlayer: false,
                shouldCreateNewPlayer: false,
                didUpdateExistingPlayer: false,
                skippedUpdateForHistoricalReferences: false
            )
        }
    }

    @discardableResult
    static func apply(
        sharedPlayers: [SharePlayer],
        existingPlayers: [Player],
        boss: RosterImportBoss,
        updateMatched: (Player, SharePlayer) -> Void,
        insertUnmatched: (SharePlayer, Int) -> Player
    ) -> [Player] {
        var insertedPlayers: [Player] = []
        var matchedExistingIDs = Set<ObjectIdentifier>()
        var preferredActiveIDs = Set<ObjectIdentifier>()
        var activeOwners = initialActiveOwners(from: existingPlayers, boss: boss, preferredActiveIDs: &preferredActiveIDs)

        for sharePlayer in sharedPlayers {
            if let currentPlayer = matchingPlayer(for: sharePlayer, in: existingPlayers) {
                let currentID = ObjectIdentifier(currentPlayer)
                matchedExistingIDs.insert(currentID)
                updateMatched(currentPlayer, sharePlayer)
                claimActiveSlotIfAvailable(for: currentPlayer, activeOwners: &activeOwners, preferredActiveIDs: &preferredActiveIDs)
            } else {
                let importedOrder = reconciledOrderForUnmatchedIncoming(
                    sharePlayer.batOrder,
                    boss: boss,
                    activeOwners: activeOwners
                )
                let insertedPlayer = insertUnmatched(sharePlayer, importedOrder)
                insertedPlayers.append(insertedPlayer)
                claimActiveSlotIfAvailable(for: insertedPlayer, activeOwners: &activeOwners, preferredActiveIDs: &preferredActiveIDs)
            }
        }

        if boss == .imported {
            demoteOldOnlyPlayersDisplacedByImportedSlots(
                existingPlayers,
                sharedPlayers: sharedPlayers,
                matchedExistingIDs: matchedExistingIDs
            )
        }

        enforceUniqueActiveSlots(existingPlayers + insertedPlayers, preferredActiveIDs: preferredActiveIDs)
        return insertedPlayers
    }

    private static func initialActiveOwners(
        from existingPlayers: [Player],
        boss: RosterImportBoss,
        preferredActiveIDs: inout Set<ObjectIdentifier>
    ) -> [Int: ObjectIdentifier] {
        guard boss == .current else { return [:] }

        var activeOwners: [Int: ObjectIdentifier] = [:]
        for player in existingPlayers {
            guard let slot = activeSlot(player.batOrder) else { continue }
            let playerID = ObjectIdentifier(player)
            if activeOwners[slot] == nil {
                activeOwners[slot] = playerID
                preferredActiveIDs.insert(playerID)
            }
        }
        return activeOwners
    }

    private static func reconciledOrderForUnmatchedIncoming(
        _ incomingOrder: Int,
        boss: RosterImportBoss,
        activeOwners: [Int: ObjectIdentifier]
    ) -> Int {
        guard boss == .current, let incomingSlot = activeSlot(incomingOrder) else {
            return incomingOrder
        }
        return activeOwners[incomingSlot] == nil ? incomingOrder : 99
    }

    private static func claimActiveSlotIfAvailable(
        for player: Player,
        activeOwners: inout [Int: ObjectIdentifier],
        preferredActiveIDs: inout Set<ObjectIdentifier>
    ) {
        guard let slot = activeSlot(player.batOrder) else { return }
        let playerID = ObjectIdentifier(player)
        if activeOwners[slot] == nil {
            activeOwners[slot] = playerID
            preferredActiveIDs.insert(playerID)
        }
    }

    private static func demoteOldOnlyPlayersDisplacedByImportedSlots(
        _ existingPlayers: [Player],
        sharedPlayers: [SharePlayer],
        matchedExistingIDs: Set<ObjectIdentifier>
    ) {
        let importedSlots = Set(sharedPlayers.compactMap { activeSlot($0.batOrder) })
        guard importedSlots.isEmpty == false else { return }

        for player in existingPlayers {
            guard
                let slot = activeSlot(player.batOrder),
                importedSlots.contains(slot),
                matchedExistingIDs.contains(ObjectIdentifier(player)) == false
            else { continue }

            player.batOrder = 99
        }
    }

    private static func enforceUniqueActiveSlots(_ players: [Player], preferredActiveIDs: Set<ObjectIdentifier>) {
        var owners: [Int: Player] = [:]

        for player in players {
            guard let slot = activeSlot(player.batOrder) else { continue }

            if let currentOwner = owners[slot] {
                let playerIsPreferred = preferredActiveIDs.contains(ObjectIdentifier(player))
                let currentOwnerIsPreferred = preferredActiveIDs.contains(ObjectIdentifier(currentOwner))

                if playerIsPreferred && !currentOwnerIsPreferred {
                    currentOwner.batOrder = 99
                    owners[slot] = player
                } else {
                    player.batOrder = 99
                }
            } else {
                owners[slot] = player
            }
        }
    }

    @discardableResult
    private static func updateNonblankPlayerFields(
        _ player: Player,
        name: String,
        number: String,
        position: String,
        batDir: String
    ) -> Bool {
        var didUpdate = false

        if applyNonblank(name, to: &player.name) {
            didUpdate = true
        }
        if applyNonblank(number, to: &player.number) {
            didUpdate = true
        }
        if applyNonblank(position, to: &player.position) {
            didUpdate = true
        }
        if applyNonblank(batDir, to: &player.batDir) {
            didUpdate = true
        }

        return didUpdate
    }

    @discardableResult
    private static func applyNonblank(_ newValue: String, to currentValue: inout String) -> Bool {
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false, currentValue != trimmedValue else {
            return false
        }

        currentValue = trimmedValue
        return true
    }
}

private struct PlayerImportIdentity {
    private static let terminalSuffixes: Set<String> = ["jr", "sr", "ii", "iii", "iv", "v"]

    let originalName: String
    let normalizedName: String
    let suffixStrippedName: String
    let normalizedNumber: String

    init(name: String, number: String) {
        let normalizedTokens = Self.normalizedTokens(from: name)

        originalName = name
        normalizedName = normalizedTokens.joined(separator: " ")
        suffixStrippedName = Self.strippingTerminalSuffix(from: normalizedTokens).joined(separator: " ")
        normalizedNumber = number.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func stronglyMatches(_ other: PlayerImportIdentity) -> Bool {
        if originalName == other.originalName {
            return true
        }

        if normalizedName == other.normalizedName {
            return true
        }

        return hasMatchingUniformNumber(with: other) &&
            suffixStrippedName == other.suffixStrippedName
    }

    func isLikelyManualMatch(for other: PlayerImportIdentity) -> Bool {
        stronglyMatches(other) ||
            suffixStrippedName == other.suffixStrippedName
    }

    private func hasMatchingUniformNumber(with other: PlayerImportIdentity) -> Bool {
        normalizedNumber.isEmpty == false && normalizedNumber == other.normalizedNumber
    }

    private static func normalizedTokens(from name: String) -> [String] {
        let folded = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
    }

    private static func strippingTerminalSuffix(from tokens: [String]) -> [String] {
        guard let lastToken = tokens.last, terminalSuffixes.contains(lastToken) else {
            return tokens
        }

        return Array(tokens.dropLast())
    }
}

import Foundation

struct TeamDefaultBattingOrderDraft {
    struct Entry: Identifiable, Equatable {
        let player: Player
        let originalBattingOrder: Int
        var draftBattingOrder: Int

        var id: UUID { player.identifier }
        var playerIdentifier: UUID { player.identifier }
        var name: String { player.name }
        var number: String { player.number }
        var position: String { player.position }
        var battingDirection: String { player.batDir }
        var isInOrder: Bool { draftBattingOrder != PlayerRosterBattingOrder.notHitting }

        static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.playerIdentifier == rhs.playerIdentifier &&
                lhs.originalBattingOrder == rhs.originalBattingOrder &&
                lhs.draftBattingOrder == rhs.draftBattingOrder
        }
    }

    private(set) var orderedEntries: [Entry]
    private(set) var benchEntries: [Entry]

    var entries: [Entry] {
        orderedEntries + benchEntries
    }

    init(players: [Player]) {
        let activePlayers = players
            .filter { Self.isActiveBattingOrder($0.batOrder) }
            .sorted(by: Self.activePlayerSort)
        orderedEntries = activePlayers.enumerated().map { index, player in
            Entry(player: player, originalBattingOrder: player.batOrder, draftBattingOrder: index + 1)
        }

        benchEntries = players
            .filter { Self.isActiveBattingOrder($0.batOrder) == false }
            .sorted(by: Self.deterministicPlayerSort)
            .map { player in
                Entry(
                    player: player,
                    originalBattingOrder: player.batOrder,
                    draftBattingOrder: PlayerRosterBattingOrder.notHitting
                )
            }
    }

    mutating func reorderActive(fromOffsets offsets: IndexSet, toOffset: Int) {
        guard offsets.isEmpty == false else { return }
        Self.move(&orderedEntries, fromOffsets: offsets, toOffset: toOffset)
        compactActiveOrder()
    }

    mutating func moveRosterEntries(fromOffsets offsets: IndexSet, toOffset: Int) {
        let activeCount = orderedEntries.count
        var combinedEntries = entries
        let movedIdentifiers = offsets
            .filter { combinedEntries.indices.contains($0) }
            .map { combinedEntries[$0].playerIdentifier }
        guard movedIdentifiers.isEmpty == false else { return }

        Self.move(&combinedEntries, fromOffsets: offsets, toOffset: toOffset)

        let movedInCount = movedIdentifiers.filter { identifier in
            let wasBench = entries.firstIndex(where: { $0.playerIdentifier == identifier }).map { $0 >= activeCount } ?? false
            let isActive = combinedEntries.firstIndex(where: { $0.playerIdentifier == identifier }).map { $0 < activeCount } ?? false
            return wasBench && isActive
        }.count
        let movedOutCount = movedIdentifiers.filter { identifier in
            let wasActive = entries.firstIndex(where: { $0.playerIdentifier == identifier }).map { $0 < activeCount } ?? false
            let isBench = combinedEntries.firstIndex(where: { $0.playerIdentifier == identifier }).map { $0 >= activeCount } ?? false
            return wasActive && isBench
        }.count
        let newActiveCount = max(0, min(combinedEntries.count, activeCount + movedInCount - movedOutCount))

        orderedEntries = Array(combinedEntries.prefix(newActiveCount))
        benchEntries = Array(combinedEntries.dropFirst(newActiveCount))
        benchEntries.sort(by: Self.entryDeterministicSort)
        compactActiveOrder()
    }

    mutating func movePlayerToOrder(playerIdentifier: UUID, at index: Int? = nil) {
        guard var entry = removeEntry(playerIdentifier: playerIdentifier) else { return }
        let targetIndex = max(0, min(index ?? orderedEntries.count, orderedEntries.count))
        entry.draftBattingOrder = targetIndex + 1
        orderedEntries.insert(entry, at: targetIndex)
        compactActiveOrder()
    }

    mutating func movePlayerOutOfOrder(playerIdentifier: UUID) {
        guard var entry = removeEntry(playerIdentifier: playerIdentifier) else { return }
        entry.draftBattingOrder = PlayerRosterBattingOrder.notHitting
        benchEntries.append(entry)
        benchEntries.sort(by: Self.entryDeterministicSort)
        compactActiveOrder()
    }

    mutating func synchronizeRosterPlayers(_ players: [Player]) {
        let currentPlayersByIdentifier = Dictionary(uniqueKeysWithValues: players.map { ($0.identifier, $0) })
        orderedEntries = orderedEntries.compactMap { entry in
            guard let player = currentPlayersByIdentifier[entry.playerIdentifier] else { return nil }
            return Entry(
                player: player,
                originalBattingOrder: player.batOrder,
                draftBattingOrder: entry.draftBattingOrder
            )
        }

        var representedIdentifiers = Set(orderedEntries.map(\.playerIdentifier))
        benchEntries = benchEntries.compactMap { entry in
            guard let player = currentPlayersByIdentifier[entry.playerIdentifier],
                  representedIdentifiers.contains(player.identifier) == false else {
                return nil
            }
            representedIdentifiers.insert(player.identifier)
            return Entry(
                player: player,
                originalBattingOrder: player.batOrder,
                draftBattingOrder: PlayerRosterBattingOrder.notHitting
            )
        }

        let newBenchEntries = players
            .filter { representedIdentifiers.contains($0.identifier) == false }
            .sorted(by: Self.deterministicPlayerSort)
            .map {
                Entry(
                    player: $0,
                    originalBattingOrder: $0.batOrder,
                    draftBattingOrder: PlayerRosterBattingOrder.notHitting
                )
            }

        benchEntries.append(contentsOf: newBenchEntries)
        benchEntries.sort(by: Self.entryDeterministicSort)
        compactActiveOrder()
    }

    func proposedBattingOrdersByPlayerIdentifier() -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.playerIdentifier, $0.draftBattingOrder) })
    }

    private mutating func removeEntry(playerIdentifier: UUID) -> Entry? {
        if let index = orderedEntries.firstIndex(where: { $0.playerIdentifier == playerIdentifier }) {
            return orderedEntries.remove(at: index)
        }
        if let index = benchEntries.firstIndex(where: { $0.playerIdentifier == playerIdentifier }) {
            return benchEntries.remove(at: index)
        }
        return nil
    }

    private mutating func compactActiveOrder() {
        orderedEntries = orderedEntries.enumerated().map { index, entry in
            var compactedEntry = entry
            compactedEntry.draftBattingOrder = index + 1
            return compactedEntry
        }
        benchEntries = benchEntries.map { entry in
            var benchEntry = entry
            benchEntry.draftBattingOrder = PlayerRosterBattingOrder.notHitting
            return benchEntry
        }
    }

    private static func isActiveBattingOrder(_ order: Int) -> Bool {
        (1..<PlayerRosterBattingOrder.notHitting).contains(order)
    }

    private static func activePlayerSort(lhs: Player, rhs: Player) -> Bool {
        if lhs.batOrder != rhs.batOrder {
            return lhs.batOrder < rhs.batOrder
        }
        return deterministicPlayerSort(lhs: lhs, rhs: rhs)
    }

    private static func deterministicPlayerSort(lhs: Player, rhs: Player) -> Bool {
        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        let numberComparison = lhs.number.localizedStandardCompare(rhs.number)
        if numberComparison != .orderedSame {
            return numberComparison == .orderedAscending
        }
        return lhs.identifier.uuidString < rhs.identifier.uuidString
    }

    private static func entryDeterministicSort(lhs: Entry, rhs: Entry) -> Bool {
        deterministicPlayerSort(lhs: lhs.player, rhs: rhs.player)
    }

    private static func move<T>(_ array: inout [T], fromOffsets offsets: IndexSet, toOffset: Int) {
        let validOffsets = offsets.filter { array.indices.contains($0) }.sorted()
        guard validOffsets.isEmpty == false else { return }
        let movingEntries = validOffsets.map { array[$0] }
        for offset in validOffsets.reversed() {
            array.remove(at: offset)
        }
        let removedBeforeTarget = validOffsets.filter { $0 < toOffset }.count
        let adjustedTarget = max(0, min(array.count, toOffset - removedBeforeTarget))
        array.insert(contentsOf: movingEntries, at: adjustedTarget)
    }
}

//
//  KeychainBackedCounter.swift
//  ScoreKeep
//
//  Created by Karl Keller on 11/25/25.
//

import Foundation
import Combine

@MainActor
final class KeychainBackedCounter: ObservableObject {
    @Published private(set) var value: Int

    private let key: String
    private let defaultValue: Int
    private let keychain: KeychainService
    private var saveDebounceTask: Task<Void, Never>?

    init(key: String,
         defaultValue: Int,
         keychainService: KeychainService = KeychainService()) {
        self.key = key
        self.defaultValue = defaultValue
        self.keychain = keychainService
        self.value = defaultValue

        // Load from Keychain on init
        if let loaded = try? load() {
            self.value = loaded
        }
    }

    func increment(by delta: Int = 1) {
        set(value + delta)
    }

    func reset(to newValue: Int? = nil) {
        set(newValue ?? defaultValue)
    }

    func set(_ newValue: Int) {
        value = max(0, newValue)
        scheduleSave()
    }

    // MARK: - Persistence

    private func scheduleSave() {
        // Coalesce rapid updates to avoid multiple writes
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            await self?.persist()
        }
    }

    private func persist() async {
        do {
            let data = try JSONEncoder().encode(value)
            try keychain.set(data, for: key)
        } catch {
            // You can add logging if desired
        }
    }

    private func load() throws -> Int {
        guard let data = try keychain.get(key) else {
            return defaultValue
        }
        return (try? JSONDecoder().decode(Int.self, from: data)) ?? defaultValue
    }
}


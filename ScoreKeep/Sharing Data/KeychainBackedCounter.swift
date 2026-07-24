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
    enum StorageInterpretation: Equatable, Sendable {
        case missingDefault
        case validStored
        case invalidStored
    }

    @Published private(set) var value: Int
    @Published private(set) var storageInterpretation: StorageInterpretation = .missingDefault

    private let key: String
    private let defaultValue: Int
    private let invalidStoredValue: Int
    private let keychain: KeychainService
    private var saveDebounceTask: Task<Void, Never>?

    init(key: String,
         defaultValue: Int,
         invalidStoredValue: Int = 0,
         keychainService: KeychainService = KeychainService()) {
        self.key = key
        self.defaultValue = defaultValue
        self.invalidStoredValue = max(0, invalidStoredValue)
        self.keychain = keychainService
        self.value = defaultValue

        // Load from Keychain on init
        if let loaded = try? load() {
            switch loaded {
            case .missing:
                self.value = defaultValue
                self.storageInterpretation = .missingDefault
            case .valid(let value):
                self.value = value
                self.storageInterpretation = .validStored
            case .invalid:
                self.value = self.invalidStoredValue
                self.storageInterpretation = .invalidStored
            }
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
        storageInterpretation = .validStored
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

    private func load() throws -> StoredCounterInterpretation {
        guard let data = try keychain.get(key) else {
            return .missing
        }

        guard let decoded = try? JSONDecoder().decode(Int.self, from: data), decoded >= 0 else {
            return .invalid
        }

        return .valid(decoded)
    }

    private enum StoredCounterInterpretation {
        case missing
        case valid(Int)
        case invalid
    }
}

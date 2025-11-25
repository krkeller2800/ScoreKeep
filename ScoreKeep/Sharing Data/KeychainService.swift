//
//  KeychainService.swift
//  ScoreKeep
//
//  Created by Karl Keller on 11/25/25.
//

import Foundation
import Security

struct KeychainService {
    let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.komakode.ScoreKeep") {
        self.service = service
    }

    func set(_ data: Data, for key: String, accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly) throws {
        let query: [String: Any] = [
            kSecClass as String:             kSecClassGenericPassword,
            kSecAttrService as String:       service,
            kSecAttrAccount as String:       key
        ]

        let attributes: [String: Any] = [
            kSecAttrAccessible as String:    accessible,
            kSecValueData as String:         data
        ]

        // Try update first
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            // Add if not exists
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = accessible
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandled(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unhandled(status)
        }
    }

    func get(_ key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String:             kSecClassGenericPassword,
            kSecAttrService as String:       service,
            kSecAttrAccount as String:       key,
            kSecReturnData as String:        kCFBooleanTrue as Any,
            kSecMatchLimit as String:        kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
        return item as? Data
    }

    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String:             kSecClassGenericPassword,
            kSecAttrService as String:       service,
            kSecAttrAccount as String:       key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    enum KeychainError: Error, LocalizedError {
        case unhandled(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unhandled(let status):
                if let message = SecCopyErrorMessageString(status, nil) as String? {
                    return "Keychain error: \(message) (\(status))"
                } else {
                    return "Keychain error code \(status)"
                }
            }
        }
    }
}


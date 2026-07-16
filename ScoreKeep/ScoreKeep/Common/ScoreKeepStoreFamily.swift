import CryptoKit
import Foundation

struct ScoreKeepStoreFamilyMember: Codable, Hashable, Sendable {
    enum Role: String, Codable, Hashable, Sendable {
        case primary
        case wal
        case shm
        case unexpectedRelated
    }

    let fileName: String
    let role: Role
    let byteCount: UInt64
    let fingerprint: String
}

struct ScoreKeepStoreFamilyDescriptor: Codable, Hashable, Sendable {
    let sourceDirectoryIdentity: String
    let storeFileName: String
    let members: [ScoreKeepStoreFamilyMember]
    let missingPrimary: Bool
    let missingOptionalSidecars: [String]
    let unexpectedRelatedFiles: [String]
    let diagnosticIdentity: String

    var isComplete: Bool {
        missingPrimary == false
    }

    var fileNames: [String] {
        members.map(\.fileName).sorted()
    }

    func member(named fileName: String) -> ScoreKeepStoreFamilyMember? {
        members.first { $0.fileName == fileName }
    }
}

enum ScoreKeepStoreFamilyError: Error, Equatable {
    case sourceDirectoryUnavailable
    case primaryStoreMissing
    case backupDirectoryMatchesSource
    case backupDirectoryNotFresh
}

enum ScoreKeepStoreFamilyDiscovery {
    static func discover(storeURL: URL, fileManager: FileManager = .default) throws -> ScoreKeepStoreFamilyDescriptor {
        let directory = storeURL.deletingLastPathComponent()
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            throw ScoreKeepStoreFamilyError.sourceDirectoryUnavailable
        }

        let baseName = storeURL.lastPathComponent
        let relatedNames = names
            .filter { $0 == baseName || $0.hasPrefix(baseName + "-") }
            .sorted()

        var members: [ScoreKeepStoreFamilyMember] = []
        for name in relatedNames {
            let url = directory.appendingPathComponent(name, isDirectory: false)
            let role = role(for: name, baseName: baseName)
            members.append(try member(for: url, role: role, fileManager: fileManager))
        }

        let missingPrimary = relatedNames.contains(baseName) == false
        let optionalNames = ["\(baseName)-wal", "\(baseName)-shm"]
        let missingOptional = optionalNames.filter { relatedNames.contains($0) == false }
        let unexpected = relatedNames.filter { role(for: $0, baseName: baseName) == .unexpectedRelated }
        let identitySeed = [
            baseName,
            members.map { "\($0.fileName):\($0.byteCount):\($0.fingerprint)" }.joined(separator: "|")
        ].joined(separator: "|")

        return ScoreKeepStoreFamilyDescriptor(
            sourceDirectoryIdentity: redactedDirectoryIdentity(directory),
            storeFileName: baseName,
            members: members,
            missingPrimary: missingPrimary,
            missingOptionalSidecars: missingOptional,
            unexpectedRelatedFiles: unexpected,
            diagnosticIdentity: digest(Data(identitySeed.utf8))
        )
    }

    static func validateBackup(
        source: ScoreKeepStoreFamilyDescriptor,
        backup: ScoreKeepStoreFamilyDescriptor,
        sourceURL: URL,
        backupURL: URL
    ) throws -> Bool {
        guard sourceURL.deletingLastPathComponent().standardizedFileURL != backupURL.deletingLastPathComponent().standardizedFileURL else {
            throw ScoreKeepStoreFamilyError.backupDirectoryMatchesSource
        }
        guard source.storeFileName == backup.storeFileName,
              source.fileNames == backup.fileNames else {
            return false
        }
        for sourceMember in source.members {
            guard let backupMember = backup.member(named: sourceMember.fileName),
                  backupMember.byteCount == sourceMember.byteCount,
                  backupMember.fingerprint == sourceMember.fingerprint else {
                return false
            }
        }
        return true
    }

    private static func role(for name: String, baseName: String) -> ScoreKeepStoreFamilyMember.Role {
        switch name {
        case baseName:
            return .primary
        case "\(baseName)-wal":
            return .wal
        case "\(baseName)-shm":
            return .shm
        default:
            return .unexpectedRelated
        }
    }

    private static func member(
        for url: URL,
        role: ScoreKeepStoreFamilyMember.Role,
        fileManager: FileManager
    ) throws -> ScoreKeepStoreFamilyMember {
        let data = try Data(contentsOf: url)
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.uint64Value ?? UInt64(data.count)
        return ScoreKeepStoreFamilyMember(
            fileName: url.lastPathComponent,
            role: role,
            byteCount: size,
            fingerprint: digest(data)
        )
    }

    private static func redactedDirectoryIdentity(_ directory: URL) -> String {
        digest(Data(directory.lastPathComponent.utf8))
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

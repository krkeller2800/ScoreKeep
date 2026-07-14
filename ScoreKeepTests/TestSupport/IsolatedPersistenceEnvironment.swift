import Foundation
import SwiftData
import Testing
@testable import ScoreKeep

/// Test-only persistence harness for verification tasks.
///
/// Each instance creates a fresh in-memory SwiftData container using the current
/// production model types. It does not initialize ScoreKeepApp, seeding,
/// import application, StoreKit, Keychain-backed counters, or app storage, and
/// it must never be redirected to production storage.
@MainActor
struct IsolatedPersistenceEnvironment {
    static let modelTypesDescription = "Game, Team, Player, Atbat, Lineup, Pitcher"

    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([
            Game.self,
            Team.self,
            Player.self,
            Atbat.self,
            Lineup.self,
            Pitcher.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            context = ModelContext(container)
        } catch {
            throw IsolatedPersistenceError.containerCreationFailed(
                mode: "in-memory SwiftData ModelConfiguration",
                modelTypes: Self.modelTypesDescription,
                underlying: error
            )
        }
    }

    func save() throws {
        do {
            try context.save()
        } catch {
            throw IsolatedPersistenceError.saveFailed(underlying: error)
        }
    }

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            throw IsolatedPersistenceError.fetchFailed(modelType: String(describing: T.self), underlying: error)
        }
    }

    func delete<T: PersistentModel>(_ model: T) {
        context.delete(model)
    }

    static func bundledFixtureURL(named name: String, extension fileExtension: String) throws -> URL {
        let testBundle = Bundle(for: IsolatedPersistenceBundleToken.self)

        guard let url = testBundle.url(forResource: name, withExtension: fileExtension) else {
            throw IsolatedPersistenceError.fixtureResourceNotFound(name: name, fileExtension: fileExtension)
        }

        return url
    }
}

private final class IsolatedPersistenceBundleToken {}

enum IsolatedPersistenceError: Error, CustomStringConvertible {
    case containerCreationFailed(mode: String, modelTypes: String, underlying: Error)
    case saveFailed(underlying: Error)
    case fetchFailed(modelType: String, underlying: Error)
    case fixtureResourceNotFound(name: String, fileExtension: String)

    var description: String {
        switch self {
        case .containerCreationFailed(let mode, let modelTypes, let underlying):
            "Could not create isolated persistence container using \(mode) for models [\(modelTypes)]: \(underlying)"
        case .saveFailed(let underlying):
            "Could not save isolated persistence context: \(underlying)"
        case .fetchFailed(let modelType, let underlying):
            "Could not fetch \(modelType) from isolated persistence context: \(underlying)"
        case .fixtureResourceNotFound(let name, let fileExtension):
            "Missing verification fixture resource in test bundle: \(name).\(fileExtension)"
        }
    }
}

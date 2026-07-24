//
//  ScoreKeepTests.swift
//  ScoreKeepTests
//
//  Created by Karl Keller on 3/15/25.
//

import Testing
import SwiftData
import Foundation
@testable import ScoreKeep

@Suite("Sample Data Seeding Tests")
struct ScoreKeepTests {

    @MainActor
    @Test("An empty store with hasSeededInitialGame == false imports the sample data")
    func testEmptyStoreFlagFalseImportsData() async throws {
        let container = try ModelContainer(for: Game.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        
        var flag = false
        SeedManager.seedIfNeeded(modelContext: context, hasSeededInitialGame: &flag)
        
        // Assert the flag is set to true
        #expect(flag == true)
        
        // Assert the data was imported
        let fetchDescriptor = FetchDescriptor<Game>(predicate: #Predicate { $0.date == "2025-11-01T22:00:00Z" })
        let count = try context.fetchCount(fetchDescriptor)
        #expect(count > 0, "Seed data should be imported")
    }
    
    @MainActor
    @Test("An empty store with hasSeededInitialGame == true recovers and imports the sample data")
    func testEmptyStoreFlagTrueRecovers() async throws {
        let container = try ModelContainer(for: Game.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        
        var flag = true
        SeedManager.seedIfNeeded(modelContext: context, hasSeededInitialGame: &flag)
        
        // The flag should remain true (it transitions false -> true during recovery)
        #expect(flag == true)
        
        let fetchDescriptor = FetchDescriptor<Game>(predicate: #Predicate { $0.date == "2025-11-01T22:00:00Z" })
        let count = try context.fetchCount(fetchDescriptor)
        #expect(count > 0, "Seed data should be imported even if flag was true but store was empty")
    }
    
    @MainActor
    @Test("A store that already contains the seeded sample game does not import a duplicate")
    func testExistingDataDoesNotDuplicate() async throws {
        let container = try ModelContainer(for: Game.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        
        // First seed
        var flag = false
        SeedManager.seedIfNeeded(modelContext: context, hasSeededInitialGame: &flag)
        
        let fetchDescriptor = FetchDescriptor<Game>(predicate: #Predicate { $0.date == "2025-11-01T22:00:00Z" })
        let initialCount = try context.fetchCount(fetchDescriptor)
        #expect(initialCount == 1, "Should have exactly one seed game initially")
        
        // Reset flag to false to simulate an out-of-sync state where data exists but flag is false
        flag = false
        SeedManager.seedIfNeeded(modelContext: context, hasSeededInitialGame: &flag)
        
        // The flag should be corrected to true without duplicating data
        #expect(flag == true)
        let newCount = try context.fetchCount(fetchDescriptor)
        #expect(newCount == 1, "Should still have exactly one seed game (no duplicate)")
    }
    
    @MainActor
    @Test("A second seeding attempt remains idempotent")
    func testSecondSeedingIsIdempotent() async throws {
        let container = try ModelContainer(for: Game.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        
        var flag = false
        SeedManager.seedIfNeeded(modelContext: context, hasSeededInitialGame: &flag)
        let initialCount = try context.fetchCount(FetchDescriptor<Game>())
        
        // Second attempt with flag true
        SeedManager.seedIfNeeded(modelContext: context, hasSeededInitialGame: &flag)
        let finalCount = try context.fetchCount(FetchDescriptor<Game>())
        
        #expect(initialCount == finalCount, "Store counts should not change on second idempotent call")
    }
    
    @Test("The seed resource is available to the relevant built target")
    func testSeedResourceIsAvailable() throws {
        let url = Bundle.main.url(forResource: "seededGame", withExtension: "ScoreKeep_Games")
        #expect(url != nil, "The seededGame.ScoreKeep_Games file must be included in the bundle")
    }
}

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
    @Test("Startup sample seeding policy distinguishes empty, sample-present, populated, and blocked stores")
    func testStartupSampleSeedingPolicyDecisionTable() {
        #expect(StartupSampleSeedingPolicy.decision(for: .init(
            startupVerified: true,
            sampleGameExists: false,
            containsBaseballData: false
        )) == .importSample)

        #expect(StartupSampleSeedingPolicy.decision(for: .init(
            startupVerified: true,
            sampleGameExists: true,
            containsBaseballData: true
        )) == .markComplete)

        #expect(StartupSampleSeedingPolicy.decision(for: .init(
            startupVerified: true,
            sampleGameExists: false,
            containsBaseballData: true
        )) == .markComplete)

        #expect(StartupSampleSeedingPolicy.decision(for: .init(
            startupVerified: false,
            sampleGameExists: false,
            containsBaseballData: false
        )) == .doNothing)
    }

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
    @Test("A populated store without the sample marks seeding complete without backfilling")
    func testPopulatedStoreWithoutSampleDoesNotBackfill() async throws {
        let container = try ModelContainer(for: Game.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.insert(Team(name: "Existing Team", coach: "Coach", details: "Legacy data"))
        try context.save()

        var flag = false
        var importAttempts = 0
        SeedManager.seedIfNeeded(modelContext: context, hasSeededInitialGame: &flag) { _ in
            importAttempts += 1
        }

        #expect(flag == true)
        #expect(importAttempts == 0)
        let fetchDescriptor = FetchDescriptor<Game>(predicate: #Predicate { $0.date == "2025-11-01T22:00:00Z" })
        let count = try context.fetchCount(fetchDescriptor)
        #expect(count == 0, "Populated stores without the sample should not receive a backfilled sample game")
    }

    @MainActor
    @Test("A blocked or recovery-required startup does not seed or mark complete")
    func testBlockedStartupDoesNotSeedOrMarkComplete() async throws {
        let container = try ModelContainer(for: Game.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        var flag = false
        var importAttempts = 0
        SeedManager.seedIfNeeded(modelContext: context, hasSeededInitialGame: &flag, startupVerified: false) { _ in
            importAttempts += 1
        }

        #expect(flag == false)
        #expect(importAttempts == 0)
        #expect(try context.fetchCount(FetchDescriptor<Game>()) == 0)
    }

    @MainActor
    @Test("An eligible first-install seed failure retries on a later successful attempt")
    func testEligibleSeedFailureRetries() async throws {
        let container = try ModelContainer(for: Game.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        struct SeedFailure: Error {}

        var flag = false
        var failedAttempts = 0
        SeedManager.seedIfNeeded(modelContext: context, hasSeededInitialGame: &flag) { _ in
            failedAttempts += 1
            throw SeedFailure()
        }

        #expect(flag == false)
        #expect(failedAttempts == 1)

        var successfulAttempts = 0
        SeedManager.seedIfNeeded(modelContext: context, hasSeededInitialGame: &flag) { context in
            successfulAttempts += 1
            context.insert(Game(
                date: "2025-11-01T22:00:00Z",
                location: "Sample",
                highLights: "Sample",
                hscore: 0,
                vscore: 0
            ))
            try context.save()
        }

        #expect(flag == true)
        #expect(successfulAttempts == 1)
        let fetchDescriptor = FetchDescriptor<Game>(predicate: #Predicate { $0.date == "2025-11-01T22:00:00Z" })
        #expect(try context.fetchCount(fetchDescriptor) == 1)
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

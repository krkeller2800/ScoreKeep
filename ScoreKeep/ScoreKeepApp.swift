//
//  ScoreKeepApp.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/15/25.
//

import SwiftUI
import SwiftData
import os.log

@main
struct ScoreKeepApp: App {
    // Shared purchase manager for the entire app
    @StateObject private var purchaseManager = PurchaseManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeededInitialGame") private var hasSeededInitialGame = false

    var body: some Scene {
        WindowGroup {
            Group {
                if UIDevice.type == "iPad" {
                    StartView()
                        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                } else if UIDevice.type == "iPhone" {
                    StartPhoneView()
                        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                }
            }
            .environmentObject(purchaseManager)
            .task {
                await purchaseManager.loadProducts()
                await purchaseManager.refreshEntitlements()
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    Task {
                        await purchaseManager.refreshEntitlements()
                        if purchaseManager.seasonPassProduct == nil {
                            await purchaseManager.loadProducts()
                        }
                    }
                }
            }
            // Inject a hidden seeding runner once the modelContext exists
            .background(SeederView(hasSeededInitialGame: $hasSeededInitialGame))
        }
        .modelContainer(for: Game.self)
        .handlesExternalEvents(matching: ["*"])
    }
}

private struct SeederView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var hasSeededInitialGame: Bool

    var body: some View {
        Color.clear
            .task {
                guard hasSeededInitialGame == false else { return }
                // Ensure the resource name and extension match exactly in your bundle.
                // Add the file to the app target: seededGame.ScoreKeep_Games
                if let url = Bundle.main.url(forResource: "seededGame", withExtension: "ScoreKeep_Games") {
                    do {
                        let importer = ImportService(modelContext: modelContext)
                        let shareGames = try importer.decodeSeededGame(from: url)
                        try importer.importShareGames(shareGames)
                        hasSeededInitialGame = true
                    } catch {
                        // If seeding fails, we won't reattempt until next launch; adjust as needed.
                        os_log("Initial game seeding failed: %{public}@", type: .error, error.localizedDescription)
                    }
                } else {
                    os_log("seededGame.ScoreKeep_Games not found in bundle.", type: .error)
                }
            }
    }
}

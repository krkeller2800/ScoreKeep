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
            // Inject the purchase manager into the environment so all child views can access it
            .environmentObject(purchaseManager)
            .task {
                // Load StoreKit products and refresh entitlement state on launch
                await purchaseManager.loadProducts()
                await purchaseManager.refreshEntitlements()
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    // Keep entitlements fresh when returning to foreground
                    Task {
                        await purchaseManager.refreshEntitlements()
                        // Also (re)load products if missing — important on iPad scene reactivation
                        if purchaseManager.seasonPassProduct == nil {
                            await purchaseManager.loadProducts()
                        }
                    }
                }
            }
        }
        .modelContainer(for: Game.self)
        .handlesExternalEvents(matching: ["*"])
    }
}

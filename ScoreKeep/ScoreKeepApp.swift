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
    private static var launchMode: ScoreKeepLaunchMode {
        ScoreKeepLaunchIsolation.mode()
    }

    // Shared purchase manager for the entire app
    @StateObject private var purchaseManager = PurchaseManager()
    @StateObject private var router = AppRouter()
    @StateObject private var announcements = AnnouncementCenter()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeededInitialGame") private var hasSeededInitialGame = false
    @AppStorage("scoreKeepAppearance") private var scoreKeepAppearance = ScoreKeepAppearanceOption.system.rawValue

    var body: some Scene {
        WindowGroup {
            switch Self.launchMode {
            case .unitTestHostIsolation:
                ScoreKeepUnitTestHostIsolationView()
            case .schemaDiagnostic:
                ScoreKeepSchemaDiagnosticView()
            case .uiTestDynamicTypeSeam:
                ScoreKeepUITestDynamicTypeSeamView()
            case .production, .internalRouting:
                ScoreKeepProductionStartupHost {
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
                    .environmentObject(router)
                    .environmentObject(announcements)
                    .preferredColorScheme(selectedColorScheme)
                    .task {
                        await purchaseManager.loadProducts()
                        await purchaseManager.refreshEntitlements()
                        await announcements.refresh()
                    }
                    .onChange(of: scenePhase) {
                        if scenePhase == .active {
                            Task {
                                await purchaseManager.refreshEntitlements()
                                if purchaseManager.seasonPassProduct == nil {
                                    await purchaseManager.loadProducts()
                                }
                                await announcements.refresh()
                            }
                        }
                    }
                    .onOpenURL { url in
                        if let dest = parseDeepLink(url) {
                            router.destination = dest
                        }
                    }
                    .sheet(isPresented: $announcements.isPresenting) {
                        AnnouncementSheet()
                            .environmentObject(announcements)
                    }
                    // Inject a hidden seeding runner once the modelContext exists
                    .background(SeederView(hasSeededInitialGame: $hasSeededInitialGame))
                    #if SCOREKEEP_MIGRATION_TEST
                    .modifier(ScoreKeepPhysicalMigrationTestOverlay())
                    #endif
                    .onAppear {
                        let fm = FileManager.default
                        if let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
                            #if DEBUG
                            print("Documents directory path: \(documents.path)")
                            #endif
                        }
                    }
                }
            }
        }
        .environmentObject(purchaseManager)
        .handlesExternalEvents(matching: ["*"])
    }

    private var selectedColorScheme: ColorScheme? {
        ScoreKeepAppearanceOption(rawValue: scoreKeepAppearance)?.colorScheme
    }
}

private struct ScoreKeepUnitTestHostIsolationView: View {
    var body: some View {
        Color.clear
            .accessibilityHidden(true)
    }
}

struct SeedManager {
    static let seededSampleGameDate = "2025-11-01T22:00:00Z"

    @MainActor
    static func seedIfNeeded(
        modelContext: ModelContext,
        hasSeededInitialGame: inout Bool,
        startupVerified: Bool = true,
        importSample: ((ModelContext) throws -> Void)? = nil
    ) {
        let snapshot = StartupSampleSeedingPolicy.Snapshot(
            startupVerified: startupVerified,
            sampleGameExists: seededSampleGameExists(in: modelContext),
            containsBaseballData: containsBaseballData(in: modelContext)
        )

        switch StartupSampleSeedingPolicy.decision(for: snapshot) {
        case .doNothing:
            return
        case .markComplete:
            hasSeededInitialGame = true
        case .importSample:
            importSeededSample(modelContext: modelContext, hasSeededInitialGame: &hasSeededInitialGame, importSample: importSample)
        }
    }

    @MainActor
    private static func seededSampleGameExists(in modelContext: ModelContext) -> Bool {
        let fetchDescriptor = FetchDescriptor<Game>(predicate: #Predicate { $0.date == seededSampleGameDate })
        return ((try? modelContext.fetchCount(fetchDescriptor)) ?? 0) > 0
    }

    @MainActor
    private static func containsBaseballData(in modelContext: ModelContext) -> Bool {
        let gameCount = (try? modelContext.fetchCount(FetchDescriptor<Game>())) ?? 0
        let teamCount = (try? modelContext.fetchCount(FetchDescriptor<Team>())) ?? 0
        let playerCount = (try? modelContext.fetchCount(FetchDescriptor<Player>())) ?? 0
        let atbatCount = (try? modelContext.fetchCount(FetchDescriptor<Atbat>())) ?? 0
        let lineupCount = (try? modelContext.fetchCount(FetchDescriptor<Lineup>())) ?? 0
        let pitcherCount = (try? modelContext.fetchCount(FetchDescriptor<Pitcher>())) ?? 0
        return gameCount + teamCount + playerCount + atbatCount + lineupCount + pitcherCount > 0
    }

    @MainActor
    private static func importSeededSample(
        modelContext: ModelContext,
        hasSeededInitialGame: inout Bool,
        importSample: ((ModelContext) throws -> Void)?
    ) {
        if let importSample {
            do {
                try importSample(modelContext)
                hasSeededInitialGame = true
            } catch {
                os_log("Initial game seeding failed: %{public}@", type: .error, error.localizedDescription)
            }
            return
        }

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

private struct SeederView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var hasSeededInitialGame: Bool

    var body: some View {
        Color.clear
            .task {
                SeedManager.seedIfNeeded(modelContext: modelContext, hasSeededInitialGame: &hasSeededInitialGame)
            }
    }
}
private func parseDeepLink(_ url: URL) -> AppRouter.Destination? {
    #if DEBUG
    print("parseDeepLink received:", url.absoluteString)
    #endif
    guard url.scheme == "scorekeep" else { return nil }
    let host = url.host ?? ""
    guard host == "share" else { return nil }
    let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let tab = comps?.queryItems?.first(where: { $0.name == "tab" })?.value
    let prefill = comps?.queryItems?.first(where: { $0.name == "prefill" })?.value
    if tab == "download" {
        return .shareDownloadTeams(prefill: prefill)
    }
    return nil
}

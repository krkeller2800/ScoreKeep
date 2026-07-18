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
    private static let schemaDiagnosticArgument = "-ScoreKeepSchemaDiagnostic"
    private static var isSchemaDiagnosticMode: Bool {
        ProcessInfo.processInfo.arguments.contains(schemaDiagnosticArgument)
            || CommandLine.arguments.contains(schemaDiagnosticArgument)
    }

    // Shared purchase manager for the entire app
    @StateObject private var purchaseManager = PurchaseManager()
    @StateObject private var router = AppRouter()
    @StateObject private var announcements = AnnouncementCenter()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeededInitialGame") private var hasSeededInitialGame = false

    init() {
        print("SCHEMA_DIAGNOSTIC appInit launchArgumentPresent=\(Self.isSchemaDiagnosticMode)")
    }

    var body: some Scene {
        WindowGroup {
            if Self.isSchemaDiagnosticMode {
                ScoreKeepSchemaDiagnosticView()
            } else {
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
                            print("Documents directory path: \(documents.path)")
                        }
                    }
                }
            }
        }
        .handlesExternalEvents(matching: ["*"])
    }
}

private struct ScoreKeepSchemaDiagnosticView: View {
    init() {
        print("SCHEMA_DIAGNOSTIC entered")
    }

    var body: some View {
        Text("ScoreKeep Schema Diagnostic")
            .onAppear {
                print("SCHEMA_DIAGNOSTIC appeared")
            }
            .task {
                ScoreKeepSchemaDiagnosticReporter.report()
            }
    }
}

private enum ScoreKeepSchemaDiagnosticReporter {
    static func report() {
        reportSchema("V2", ScoreKeepProposedVersionedSchema.V2.self)
        reportSchema("V3", ScoreKeepProposedVersionedSchema.V3.self)
        print("SCHEMA_DIAGNOSTIC stageEvaluationBegin")
        let planSchemas = ScoreKeepProposedCanonicalScoringStorageMigrationPlan.schemas.map {
            "\(String(describing: $0)):\($0.versionIdentifier.description)"
        }.joined(separator: ",")
        print("SCHEMA_DIAGNOSTIC planSchemasEvaluated=\(planSchemas)")
        let stages = ScoreKeepProposedCanonicalScoringStorageMigrationPlan.stages
        print("SCHEMA_DIAGNOSTIC stageEvaluationSucceeded stageCount=\(stages.count)")
        print("SCHEMA_DIAGNOSTIC freshV2ToV3MigrationSkipped reason=currentTargetV2AndV3DuplicateEffectiveChecksums")
        reportProductionMetadataClassification()
    }

    private static func reportSchema(_ label: String, _ schemaType: any VersionedSchema.Type) {
        let schema = Schema(versionedSchema: schemaType)
        print("SCHEMA_DIAGNOSTIC schema=\(label) version=\(schemaType.versionIdentifier.description) entityCount=\(schema.entities.count) schemaInventoryOnly=true")
        for entity in schema.entities.sorted(by: { $0.name < $1.name }) {
            let properties = entity.properties
                .map { String(describing: $0) }
                .sorted()
                .joined(separator: "|")
            print("SCHEMA_DIAGNOSTIC entity=\(label).\(entity.name) properties=\(properties)")
        }
    }

    private static func reportProductionMetadataClassification() {
        let root = ScoreKeepPhysicalDeviceDiagnostics.applicationSupportRoot()
        let layout = ScoreKeepProductionMigrationLayout.resolve(applicationSupportRoot: root)
        let assessment = ScoreKeepProductionStoreMetadataAssessment.assess(storeURL: layout.activeStore)
        let journal = ScoreKeepMigrationJournalStore(directory: layout.journal.deletingLastPathComponent()).load()
        let journalStatus: String
        if let record = journal.record {
            journalStatus = "\(record.phase.rawValue):\(record.sourceClassification.rawValue)"
        } else if journal.error != nil {
            journalStatus = "unreadable"
        } else {
            journalStatus = "absent"
        }
        let matchingVersions = assessment.matchingRegisteredVersions.joined(separator: "+")
        print("SCHEMA_DIAGNOSTIC productionSourceClassification=\(assessment.sourceClassification.rawValue) hashEntryCount=\(assessment.hashEntryCount) versionIdentifierCount=\(assessment.versionIdentifierCount) matchingRegisteredVersions=\(matchingVersions) selectedStartupRoute=\(assessment.selectedStartupRoute) journal=\(journalStatus)")
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
private func parseDeepLink(_ url: URL) -> AppRouter.Destination? {
    print("parseDeepLink received:", url.absoluteString)
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

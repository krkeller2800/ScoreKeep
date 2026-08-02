//
//  StartView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/23/25.
//

import SwiftUI

struct StartView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: AppRouter
    @Environment(\.colorScheme) private var colorScheme
    @State private var didLogPaths = false
    @State var columnVisibility = NavigationSplitViewVisibility.doubleColumn
    @State private var flagNames = ["presentGames","presentTeams","presentPlayers","presentScoreGame","presentPaste","presentHelp","presentShareLineup","importPlayers","presentScreenShot"]
    @State private var flags:[Bool] = [true,false,false,false,false,false,false,false,false]
    @State private var navigationPath = NavigationPath()
    @State private var importUrl: URL?
    @State private var isShowingSettings = false
    @State    var showImport = false

    private var sidebarForeground: Color {
        colorScheme == .dark ? .white.opacity(0.92) : .black
    }

    private var sidebarIconBrightness: Double {
        colorScheme == .dark ? 0.5 : 0
    }

    private var sidebarShareIconForeground: Color {
        colorScheme == .dark ? .white.opacity(0.82) : .black.opacity(0.78)
    }
  
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack {
                Button("\n\n\n\n\nGames") {
                    setFlags(flag: "presentGames")
                    columnVisibility = .doubleColumn
                }
                .foregroundStyle(sidebarForeground).bold().italic().font(.caption)
                .background {
                    Image("bgame")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 75, height: 75)
                    .brightness(sidebarIconBrightness)
                    }
                Spacer()
                Button("\n\n\n\n\nTeams") {
                    setFlags(flag: "presentTeams")
                    columnVisibility = .doubleColumn
                }
                .foregroundStyle(sidebarForeground).bold().italic().font(.caption)
                .background {
                    Image("bteam")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 75, height: 75)
                    .brightness(sidebarIconBrightness)
                    }
                Spacer()
//                Button("\n\n\n\n\nScore Games") {
//                    setFlags(flag: "presentScoreGame")
//                    columnVisibility = .detailOnly
//                }
//                .foregroundColor(.black).bold().italic().font(.caption)
//                .background {
//                    Image("score")
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 75, height: 75)
//                    }
//                Spacer()
                Button("\n\n\n\n\nPaste in Players") {
                    setFlags(flag: "presentPaste")
                    columnVisibility = .doubleColumn
                }
                .foregroundStyle(sidebarForeground).bold().italic().font(.caption)
                .background {
                    Image("Paste")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 75, height: 75)
                    .brightness(sidebarIconBrightness)
                    }
                Spacer()
                Button("\n\n\n\n\nHelp Documentation") {
                    setFlags(flag: "presentHelp")
                    columnVisibility = .doubleColumn
                }
                .foregroundStyle(sidebarForeground).bold().italic().font(.caption)
                .background {
                    Image("bhelp")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 75, height: 75)
                    .brightness(sidebarIconBrightness)
                    }
                Spacer()
                Button("\n\n\n\n\nShare Data") {
                    setFlags(flag: "presentShareLineup")
                    columnVisibility = .doubleColumn
                }
                .foregroundStyle(sidebarForeground).bold().italic().font(.caption)
                .background {
                    Image(systemName: "square.and.arrow.up")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(sidebarShareIconForeground)
                    }
                Spacer()
//                Button("\n\n\n\n\nScreen Shot") {
//                    setFlags(flag: "presentScreenShot")
//                    columnVisibility = .doubleColumn
//                }
//                .foregroundColor(.black).bold().italic().font(.caption)
//                .background {
//                    Image("Paste")
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 50, height: 50)
//                    }
//                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) {
                ScoreKeepSettingsGearButton(isShowingSettings: $isShowingSettings)
                    .padding(.trailing, 15)
                    .padding(.bottom, 15)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom )
        } detail: {
            if flags[0] {
                ScoreContentView(columnVisability: $columnVisibility)
            } else if flags[1] {
                TeamContentView()
            } else if flags[2] {
                PlayerContentView()
            } else if flags[3] {
                ScoreContentView(columnVisability: $columnVisibility)
            } else if flags[4] {
                PasteView()
            } else if flags[5] {
                PdfView()
            } else if flags[6] {
                ShareContentView()
            } else if flags[7] {
                if let url = importUrl {
                    ImportPlayersView(showingImport: $showImport, iURL: url,columnVisibility: $columnVisibility )
                }
            } else if flags[8] {
                ScreenShotView()
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            ScoreKeepSettingsView(
                onOpenImportFlow: { openShareDataFromSettings() },
                onOpenExportFlow: { openShareDataFromSettings() },
                onOpenHelp: { openHelpFromSettings() }
            )
        }
        .onOpenURL { url in
            // Route custom deep links to the shared router; do NOT treat as file import
            if url.scheme == "scorekeep" {
                if let dest = parseDeepLink(url) {
                    router.destination = dest
                }
                return
            }
            // Only treat as import when the URL looks like one of our supported files
            if isImportFileURL(url) {
                importUrl = url
                setFlags(flag: "importPlayers")
                columnVisibility = .detailOnly
            }
        }
        .onReceive(router.$destination) { dest in
            guard let dest = dest else { return }
            switch dest {
            case .shareDownloadTeams:
                // Show the Share view in the detail when deep link requests downloads
                setFlags(flag: "presentShareLineup")
                columnVisibility = .doubleColumn
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom )
        .task {
            guard !didLogPaths else { return }
            didLogPaths = true
            print("SQL Dir = \(modelContext.sqliteCommand) \nFolders Dir = \(NSHomeDirectory())")
        }
    }

    private func openShareDataFromSettings() {
        setFlags(flag: "presentShareLineup")
        columnVisibility = .doubleColumn
    }

    private func openHelpFromSettings() {
        setFlags(flag: "presentHelp")
        columnVisibility = .doubleColumn
    }

    func setFlags(flag flagName: String) {
        if let nameIndex = flagNames.firstIndex(of: flagName) {
            for (flagIndex, _ ) in flags.enumerated() {
                if flagIndex == nameIndex {
                    flags[flagIndex] = true
                } else {
                    flags[flagIndex] = false
                }
            }
        }
    }
    
    private func isImportFileURL(_ url: URL) -> Bool {
        // Primary: extension check (case-insensitive)
        let ext = url.pathExtension.lowercased()
        if ext == "scorekeep_players" || ext == "scorekeep_games" {
            return true
        }
        // Fallback: lastPathComponent contains (case-insensitive)
        let name = url.lastPathComponent.lowercased()
        return name.contains("scorekeep_players") || name.contains("scorekeep_games")
    }

    private func parseDeepLink(_ url: URL) -> AppRouter.Destination? {
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
}
//#Preview {
//    do {
//        let previewer = try Previewer()
//        return ContentGameView()
//            .modelContainer(previewer.container)
//    } catch {
//        return Text("Failed to create preview: \(error.localizedDescription)")
//    }
//}

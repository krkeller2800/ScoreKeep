//
//  StartPhoneView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 7/25/25.
//

import SwiftUI

struct StartPhoneView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var router: AppRouter
    @State var columnVisibility = NavigationSplitViewVisibility.detailOnly

    @State private var selectedTab = 0
    @State private var showImport = false
    @State private var importURL:URL?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScoreContentView(columnVisability: $columnVisibility)
            }
            .tabItem {
                Image("pgame")
                Text("Games").padding(.horizontal,5)
            }
            .tag(0)
            
            NavigationStack {
                TeamContentView()
            }
            .tabItem {
                Image("pteam")
                Text("Teams").padding(.horizontal,5)
            }
            .tag(1)
            
//            NavigationStack {
//                ScoreContentView()
//            }
//            .tabItem {
//                Image("pscore")
//                Text("Score").padding(.horizontal,5)
//            }
//            .tag(2)
            NavigationStack {
                PasteView()
            }
            .tabItem {
                Image("pPaste")
                Text("Paste").padding(.horizontal,5)
            }
            .tag(2)
            NavigationStack {
                PdfView()
            }
            .tabItem {
                Image("phelp")
                Text("Help").padding(.horizontal,5)
            }
            .tag(3)
            NavigationStack {
                ShareContentView()
            }
            .tabItem {
                Image(systemName: "square.and.arrow.up")
                Text("Share").padding(.horizontal,5)
            }
            .tag(4)
//            NavigationStack {
//                if let url = importURL {
//                    ImportPlayersView(iURL: url)
//                }
//            }
//            .tabItem {
//
//            }
//            .tag(5)
 
       }
        .onOpenURL { url in
            // Route custom deep links (scorekeep://...) via shared router; do NOT treat as file import
            if url.scheme == "scorekeep" {
                if let dest = parseDeepLink(url) {
                    router.destination = dest
                }
                return
            }
            // Only import when the URL is one of our supported file types
            if isImportFileURL(url) {
                importURL = url
                showImport = true
            }
        }
        .fullScreenCover(isPresented: $showImport) {
            if let url = importURL {
                ImportPlayersView(showingImport: $showImport, iURL: url, columnVisibility: $columnVisibility)
            } else {
                Text("Bad URL")
            }
        }
        .onReceive(router.$destination) { dest in
            guard let dest = dest else { return }
            switch dest {
            case .shareDownloadTeams:
                // Ensure the Share tab is visible on iPhone
                selectedTab = 4
            }
        }
    }
    func handleIncomingURL(_ url: URL) {
        let dataType = url.lastPathComponent.components(separatedBy: ".").last ?? ""
        if dataType.localizedStandardContains("ScoreKeep_Players") ||
           dataType.localizedStandardContains("ScoreKeep_Games") {
            print(url)
            importURL = url
            showImport = true
            }
        }
    
    private func isImportFileURL(_ url: URL) -> Bool {
        let ext = url.pathExtension
        return ext == "ScoreKeep_Players" || ext == "ScoreKeep_Games"
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

#Preview {
    StartPhoneView()
}

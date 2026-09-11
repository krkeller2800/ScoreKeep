//
//  StartPhoneView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 7/25/25.
//

import SwiftUI

struct StartPhoneView: View {
    @EnvironmentObject var router: AppRouter
    @State var columnVisibility = NavigationSplitViewVisibility.detailOnly

    private struct ImportPayload: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var importPayload: ImportPayload?

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScoreContentView(
                columnVisability: $columnVisibility,
                onOpenImportFlow: { selectedTab = 4 },
                onOpenExportFlow: { selectedTab = 4 },
                onOpenHelp: { selectedTab = 3 }
            )
            .tabItem {
                Image("pgame")
                Text("Games").padding(.horizontal,5)
            }
            .tag(0)

            TeamContentView()
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
            PasteView()
            .tabItem {
                Image("pPaste")
                Text("Paste").padding(.horizontal,5)
            }
            .tag(2)
            ScoreKeepHelpRoute()
            .tabItem {
                if let scaledHelp = Self.phoneHelpTabImage {
                    Image(uiImage: scaledHelp)
                } else {
                    Image("phelp").renderingMode(.original)
                }
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
            guard isImportFileURL(url) else { return }
            // Ensure main-actor state updates and avoid races by driving presentation from the URL item
            Task { @MainActor in
                _ = url.startAccessingSecurityScopedResource()
                importPayload = ImportPayload(url: url)
            }
        }
        .fullScreenCover(item: $importPayload) { payload in
            ImportPlayersView(
                showingImport: Binding(
                    get: { importPayload != nil },
                    set: { isPresented in
                        if !isPresented {
                            importPayload?.url.stopAccessingSecurityScopedResource()
                            importPayload = nil
                        }
                    }
                ),
                iURL: payload.url,
                columnVisibility: $columnVisibility
            )
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

    private static var phoneHelpTabImage: UIImage? {
        guard let source = UIImage(named: "phelp") else { return nil }
        let size = CGSize(width: 50, height: 50)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in
                source.draw(in: CGRect(origin: .zero, size: size))
            }
            .withRenderingMode(.alwaysOriginal)
    }
}

#Preview {
    StartPhoneView()
}

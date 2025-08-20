//
//  StartPhoneView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 7/25/25.
//

import SwiftUI

struct StartPhoneView: View {
    @Environment(\.openURL) private var openURL
    @State var columnVisibility = NavigationSplitViewVisibility.detailOnly

    @State private var selectedTab = 0
    @State private var showImport = false
    @State private var importURL:URL?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScoreContentView(columnVisibility: $columnVisibility)
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
            handleIncomingURL(url)
        }
        .fullScreenCover(isPresented: $showImport) {
            if let url = importURL {
                ImportPlayersView(showingImport: $showImport, iURL: url, columnVisibility: $columnVisibility)
            } else {
                Text("Bad URL")
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
}

#Preview {
    StartPhoneView()
}

//
//  StartView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/23/25.
//

import SwiftUI

struct StartView: View {
    @Environment(\.modelContext) var modelContext
    @State var columnVisibility = NavigationSplitViewVisibility.doubleColumn
    @State private var flagNames = ["presentGames","presentTeams","presentPlayers","presentScoreGame","presentPaste","presentHelp","presentShareLineup","importPlayers","presentScreenShot"]
    @State private var flags:[Bool] = [true,false,false,false,false,false,false,false,false]
    @State private var navigationPath = NavigationPath()
    @State private var importUrl: URL?
    @State    var showImport = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack {
                Button("\n\n\n\n\nGames") {
                    setFlags(flag: "presentGames")
                    columnVisibility = .doubleColumn
                }
                .foregroundColor(.black).bold().italic().font(.caption)
                .background {
                    Image("bgame")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 75, height: 75)
                    }
                Spacer()
                Button("\n\n\n\n\nTeams") {
                    setFlags(flag: "presentTeams")
                    columnVisibility = .doubleColumn
                }
                .foregroundColor(.black).bold().italic().font(.caption)
                .background {
                    Image("bteam")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 75, height: 75)
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
                .foregroundColor(.black).bold().italic().font(.caption)
                .background {
                    Image("Paste")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 75, height: 75)
                    }
                Spacer()
                Button("\n\n\n\n\nHelp Documentation") {
                    setFlags(flag: "presentHelp")
                    columnVisibility = .doubleColumn
                }
                .foregroundColor(.black).bold().italic().font(.caption)
                .background {
                    Image("bhelp")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 75, height: 75)
                    }
                Spacer()
                Button("\n\n\n\n\nShare Lineup") {
                    setFlags(flag: "presentShareLineup")
                    columnVisibility = .doubleColumn
                }
                .foregroundColor(.black).bold().italic().font(.caption)
                .background {
                    Image(systemName: "square.and.arrow.up")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
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
            .ignoresSafeArea(.keyboard, edges: .bottom )
            .onOpenURL { url in
                print(url)
                importUrl = url
                setFlags(flag: "importPlayers")
                columnVisibility = .detailOnly
            }
        } detail: {
            if flags[0] {
                ScoreContentView(columnVisibility: $columnVisibility)
            } else if flags[1] {
                TeamContentView()
            } else if flags[2] {
                PlayerContentView()
            } else if flags[3] {
                ScoreContentView(columnVisibility: $columnVisibility)
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
        .ignoresSafeArea(.keyboard, edges: .bottom )
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

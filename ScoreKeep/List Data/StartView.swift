//
//  StartView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/23/25.
//

import SwiftUI

struct StartView: View {
    @Environment(\.modelContext) var modelContext
    @State private var columnVisibility = NavigationSplitViewVisibility.doubleColumn
    @State private var flagNames = ["presentGames","presentTeams","presentPlayers","presentScoreGame","presentPaste","presentHelp"]
    @State private var flags:[Bool] = [true,false,false,false,false,false]

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack {
            Button("\n\n\n\nGames") {
                setFlags(flag: "presentGames")
                columnVisibility = .doubleColumn
            }
            .foregroundColor(.black).bold().italic().font(.caption)
            .background {
            Image("game 1")
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            }
            Spacer()
            Button("\n\n\n\nTeams") {
                setFlags(flag: "presentTeams")
                columnVisibility = .doubleColumn
            }
            .foregroundColor(.black).bold().italic().font(.caption)
            .background {
            Image("team")
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            }
            Spacer()
            Button("\n\n\n\nPlayers") {
                setFlags(flag: "presentPlayers")
                columnVisibility = .doubleColumn
            }
            .foregroundColor(.black).bold().italic().font(.caption)
            .background {
            Image("Player 1")
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            }
            Spacer()
            Button("\n\n\n\nScore Games") {
                setFlags(flag: "presentScoreGame")
                columnVisibility = .detailOnly
            }
            .foregroundColor(.black).bold().italic().font(.caption)
            .background {
            Image("score")
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            }
            Spacer()
            Button("\n\n\n\nPaste in Players") {
                setFlags(flag: "presentPaste")
                columnVisibility = .doubleColumn
            }
            .foregroundColor(.black).bold().italic().font(.caption)
            .background {
            Image("Paste")
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            }
            Spacer()
            Button("\n\n\n\nHelp Documentation") {
                setFlags(flag: "presentHelp")
                columnVisibility = .doubleColumn
            }
            .foregroundColor(.black).bold().italic().font(.caption)
            .background {
            Image("help")
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            }
            Spacer()
            }
        } detail: {
            if flags[0] {
                ContentView()
            } else if flags[1] {
                TeamContentView()
            } else if flags[2] {
                PlayerContentView()
            } else if flags[3] {
                ScoreContentView()
            } else if flags[4] {
                PasteView()
            } else if flags[5] {
                PdfView()
            }
        }
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
//        NavigationView {
//            VStack {
//                Button("\n\n\n\nGames") {
//                    presentGames.toggle()
//                }
//                .foregroundColor(.black).bold().italic().font(.caption)
//                .background {
//                    Image("game 1")
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 50, height: 50)
//                }
//                .fullScreenCover(isPresented: $presentGames, content: ContentView.init)
//
//                NavigationLink(destination: ContentView()) {
//                    Text("Edit/Add Game")
//                        .frame(width: 300, height: 50)
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                        .font(.title)
//                }
//                Spacer()
//                Button("\n\n\n\nTeams") {
//                    presentTeams.toggle()
//                }
//                .foregroundColor(.black).bold().italic().font(.caption)
//                .background {
//                    Image("team")
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 50, height: 50)
//                }
//                .fullScreenCover(isPresented: $presentTeams, content: TeamContentView.init)
//
//                Spacer()
//                Button("\n\n\n\nPlayers") {
//                    presentPlayers.toggle()
//                }
//                .foregroundColor(.black).bold().italic().font(.caption)
//                .background {
//                    Image("Player 1")
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 50, height: 50)
//                }
//                .fullScreenCover(isPresented: $presentPlayers, content: PlayerContentView.init)
//                Spacer()
//                Button("\n\n\n\nScore Games") {
//                    presentScoreGame.toggle()
//                }
//                .foregroundColor(.black).bold().italic().font(.caption)
//                .background {
//                    Image("score")
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 50, height: 50)
//                }
//                .fullScreenCover(isPresented: $presentScoreGame, content: ScoreContentView.init)
//                Spacer()
//                Button("\n\n\n\nPaste in Players") {
//                    presentPaste.toggle()
//                }
//                .foregroundColor(.black).bold().italic().font(.caption)
//                .background {
//                    Image("Paste")
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 50, height: 50)
//                }
//                .fullScreenCover(isPresented: $presentPaste, content: PasteView.init)
//                Spacer()
//            }
//        }
//    }
//
//}
//
//#Preview {
//    StartView()
//}

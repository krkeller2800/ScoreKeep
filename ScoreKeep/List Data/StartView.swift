//
//  StartView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/23/25.
//

import SwiftUI

struct StartView: View {
    @State private var presentScoreGame = false
    @State private var presentPlayers = false
    @State private var presentTeams = false
    @State private var presentGames = false
    @State private var presentPaste = false

    var body: some View {
        NavigationView {
            VStack {
                Button("\n\n\n\nGames") {
                    presentGames.toggle()
                }
                .foregroundColor(.black).bold().italic().font(.caption)
                .background {
                    Image("game 1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                }
                .fullScreenCover(isPresented: $presentGames, content: ContentView.init)

//                NavigationLink(destination: ContentView()) {
//                    Text("Edit/Add Game")
//                        .frame(width: 300, height: 50)
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                        .font(.title)
//                }
                Spacer()
                Button("\n\n\n\nTeams") {
                    presentTeams.toggle()
                }
                .foregroundColor(.black).bold().italic().font(.caption)
                .background {
                    Image("team")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                }
                .fullScreenCover(isPresented: $presentTeams, content: TeamContentView.init)

                Spacer()
                Button("\n\n\n\nPlayers") {
                    presentPlayers.toggle()
                }
                .foregroundColor(.black).bold().italic().font(.caption)
                .background {
                    Image("Player 1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                }
                .fullScreenCover(isPresented: $presentPlayers, content: PlayerContentView.init)
                Spacer()
                Button("\n\n\n\nScore Games") {
                    presentScoreGame.toggle()
                }
                .foregroundColor(.black).bold().italic().font(.caption)
                .background {
                    Image("score")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                }
                .fullScreenCover(isPresented: $presentScoreGame, content: ScoreContentView.init)
                Spacer()
                Button("\n\n\n\nPaste in Players") {
                    presentPaste.toggle()
                }
                .foregroundColor(.black).bold().italic().font(.caption)
                .background {
                    Image("Paste")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                }
                .fullScreenCover(isPresented: $presentPaste, content: PasteView.init)
                Spacer()
            }
               PdfView()
        }
    }

}

#Preview {
    StartView()
}

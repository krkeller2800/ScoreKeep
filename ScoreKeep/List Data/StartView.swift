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
                Button("Edit/Add Games") {
                    presentGames.toggle()
                }
                .frame(width: 300, height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.title)
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
                Button("Edit/Add Teams") {
                    presentTeams.toggle()
                }
                .frame(width: 300, height: 50)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.title)
                .fullScreenCover(isPresented: $presentTeams, content: TeamContentView.init)
                Spacer()
                Button("Edit/Add Players") {
                    presentPlayers.toggle()
                }
                .frame(width: 300, height: 50)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.title)
                .fullScreenCover(isPresented: $presentPlayers, content: PlayerContentView.init)
                Spacer()
                Button("Score Games") {
                    presentScoreGame.toggle()
                }
                .frame(width: 300, height: 50)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.title)
                .fullScreenCover(isPresented: $presentScoreGame, content: ScoreContentView.init)
                Spacer()
                Button("Paste Players") {
                    presentPaste.toggle()
                }
                .frame(width: 300, height: 50)
                .background(Color.pink)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.title)
                .fullScreenCover(isPresented: $presentPaste, content: PasteView.init)

                Spacer()
                Spacer()

            }
               PdfView()
        }
    }

}

#Preview {
    StartView()
}

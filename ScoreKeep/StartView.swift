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
//                NavigationLink(destination: TeamContentView()) {
//                    Text("Edit/Add Teams")
//                        .frame(width: 300, height: 50)
//                        .background(Color.green)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                        .font(.title)
//                }
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
//                NavigationLink(destination: PlayerContentView()) {
//                    Text("Edit/Add Players")
//                        .frame(width: 300, height: 50)
//                        .background(Color.red)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                        .font(.title)
//
//                }
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
//                NavigationLink(destination: ScoreContentView()) {
//                Text("Score Games")
//                    .frame(width: 300, height: 50)
//                    .background(Color.red)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//                    .font(.title)
//                }
                Spacer()
                Spacer()

            }

            HStack {
                Text("ScoreKeep")
                    .font(.largeTitle)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview {
    StartView()
}

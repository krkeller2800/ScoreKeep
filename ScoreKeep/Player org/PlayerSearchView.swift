//
//  PlayerSearchView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/9/25.
//
import SwiftData
import SwiftUI

struct PlayerSearchView: View {
        @Binding var selectPlayers: [Player]
        @Query private var players: [Player] = []
        
    init(searchTeam: Team, selPlayers:Binding<[Player]>) {

        let teamName = searchTeam.name
                  
        let fetchDescriptor = FetchDescriptor<Player>(
            predicate: #Predicate { $0.team?.name == teamName } // Use the local variable
            )
        
        _players = Query(fetchDescriptor)
        _selectPlayers = selPlayers
        }
        
        var body: some View {
            Section {
                if players.count > 0 {
                    Text("Found \(players.count) players on the \(players[0].team?.name ?? "(team name not found)") team.").foregroundColor(.red)
                } else {
                    Text("")
                }
            }.onAppear() {
                selectPlayers = players
            }
        }
    }

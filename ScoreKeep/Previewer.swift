//
//  Previewer.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/16/25.
//


import Foundation
import SwiftData

@MainActor
struct Previewer {
    let container: ModelContainer
    let game: Game
    let team: Team
    let player: Player

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Game.self, configurations: config)

        game = Game(date: "Karl", location: "Here",highLights: "non",vscore:0, hscore:0)
        team = Team(name: "Dimension Jump", coach: "Joe", details: "hello")
        player = Player(name: "Dave Lister", number: "00", position: "1b", batOrder: 99, team: team)
        container.mainContext.insert(game)
    }
}

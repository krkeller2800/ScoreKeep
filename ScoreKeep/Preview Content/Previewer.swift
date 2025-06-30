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
    let atbat: Atbat
    let pitcher: Pitcher
    let lineup: Lineup

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Game.self, configurations: config)

        game = Game(date: "Karl", location: "Here",highLights: "non",hscore:0, vscore:0)
        team = Team(name: "Dimension Jump", coach: "Joe", details: "hello")
        player = Player(name: "Dave Lister", number: "00", position: "1b", batDir: "", batOrder: 99, team: team)
        atbat = Atbat(game: game, team: team, player: player, result: "Result", maxbase: "None", batOrder: 99, outAt: "Safe", inning: 0.0, seq: 0, col: 0, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
        pitcher = Pitcher(player: player, team: team, game: game, startInn: 0, sOuts: 0, endInn: 0, eOuts: 0, strikeOuts: 0, walks: 0, hits: 0, runs: 0, won: false)
        lineup = Lineup(everyoneHits: false, game: game, team: team, inning: 0)
        container.mainContext.insert(game)
        container.mainContext.insert(team)
        container.mainContext.insert(player)
        container.mainContext.insert(atbat)
        container.mainContext.insert(pitcher)
        container.mainContext.insert(lineup)
    }
}

//
//  Pitcher.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/26/25.
//

import Foundation
import SwiftData

@Model
class Pitcher {
    var player: Player
    var team: Team
    var game: Game
    var startinn: Int
    var sBatIn: Int
    var endinn: Int
    var eBatIn: Int
    var strikeOuts: Int
    var walks: Int
    var hits: Int
    var runs: Int
    var won: Bool

    init(player: Player, team: Team, game: Game, startinn: Int, sBatIn: Int, endinn: Int, eBatIn: Int, strikeOuts: Int, walks: Int, hits: Int, runs: Int, won: Bool) {
        self.player = player
        self.team = team
        self.game = game
        self.startinn = startinn
        self.sBatIn = sBatIn
        self.endinn = endinn
        self.eBatIn = eBatIn
        self.strikeOuts = strikeOuts
        self.walks = walks
        self.hits = hits
        self.runs = runs
        self.won = won
    }
}

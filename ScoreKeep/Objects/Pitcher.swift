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
    var ident: UUID
    var player: Player
    var team: Team
    var game: Game
    var startInn: Int
    var sOuts: Int
    var endInn: Int
    var eOuts: Int
    var strikeOuts: Int
    var walks: Int
    var hits: Int
    var runs: Int
    var won: Bool

    init(ident: UUID = UUID(), player: Player, team: Team, game: Game, startInn: Int, sOuts: Int, endInn: Int, eOuts: Int, strikeOuts: Int, walks: Int, hits: Int, runs: Int, won: Bool) {
        self.ident = ident
        self.player = player
        self.team = team
        self.game = game
        self.startInn = startInn
        self.sOuts = sOuts
        self.endInn = endInn
        self.eOuts = eOuts
        self.strikeOuts = strikeOuts
        self.walks = walks
        self.hits = hits
        self.runs = runs
        self.won = won
    }
}

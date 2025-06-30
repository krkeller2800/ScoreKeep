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
    var sBats: Int
    var endInn: Int
    var eOuts: Int
    var eBats: Int
    var strikeOuts: Int
    var walks: Int
    var hits: Int
    var runs: Int
    var won: Bool

    init(ident: UUID = UUID(), player: Player, team: Team, game: Game, startInn: Int = 0, sOuts: Int = 0, sBats: Int = 0, endInn: Int = 0,
         eOuts: Int = 0, eBats: Int = 0, strikeOuts: Int = 0, walks: Int = 0, hits: Int = 0, runs: Int = 0, won: Bool = false) {
        self.ident = ident
        self.player = player
        self.team = team
        self.game = game
        self.startInn = startInn
        self.sOuts = sOuts
        self.sBats = sBats
        self.endInn = endInn
        self.eOuts = eOuts
        self.eBats = eBats
        self.strikeOuts = strikeOuts
        self.walks = walks
        self.hits = hits
        self.runs = runs
        self.won = won
    }
}

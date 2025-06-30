//
//  Atbats.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/15/25.
//

import Foundation
import SwiftData
@Model

class Atbat {
    var ident: UUID
    var game: Game
    var team: Team
    var player: Player
    var result: String
    var maxbase: String
    var batOrder: Int
    var outAt: String
    var inning: CGFloat
    var seq: Int
    var col: Int
    var rbis: Int
    var outs: Int
    var sacFly: Int
    var sacBunt: Int
    var stolenBases: Int
    var earnedRun: Bool
    var playRec: String
    var endOfInning: Bool

    init(ident: UUID = UUID(), game: Game, team: Team, player: Player, result: String, maxbase: String, batOrder: Int, outAt: String, inning: CGFloat, seq: Int, col: Int, rbis: Int, outs: Int, sacFly: Int, sacBunt: Int, stolenBases: Int, earnedRun: Bool = true, playRec: String = "", endOfInning:Bool = false) {
        self.ident = ident
        self.game = game
        self.team = team
        self.player = player
        self.result = result
        self.maxbase = maxbase
        self.batOrder = batOrder
        self.outAt = outAt
        self.inning = inning
        self.seq = seq
        self.col = col
        self.rbis = rbis
        self.outs = outs
        self.sacFly = sacFly
        self.sacBunt = sacBunt
        self.stolenBases = stolenBases
        self.earnedRun = earnedRun
        self.playRec = playRec
        self.endOfInning = endOfInning
    }
        
        
}

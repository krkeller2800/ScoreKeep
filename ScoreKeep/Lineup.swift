//
//  Lineup.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/3/25.
//

import Foundation
import SwiftData
@Model

class Lineup {
    var everyoneHits: Bool
    var game: Game
    var team: Team
    var inning: Int
    var players = [Player]()

    init(everyoneHits: Bool, game: Game, team: Team, inning: Int) {
        self.everyoneHits = everyoneHits
        self.game = game
        self.team = team
        self.inning = inning
    }
}

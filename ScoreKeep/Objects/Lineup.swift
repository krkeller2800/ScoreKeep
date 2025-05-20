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
    var ident: UUID
    var everyoneHits: Bool
    var game: Game
    var team: Team
    var inning: Int
    var players = [Player]()

    init(ident: UUID = UUID(), everyoneHits: Bool, game: Game, team: Team, inning: Int, players: [Player] = [Player]()) {
        self.ident = ident
        self.everyoneHits = everyoneHits
        self.game = game
        self.team = team
        self.inning = inning
        self.players = players
    }
}

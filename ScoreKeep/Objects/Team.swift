//
//  Teams.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/15/25.
//

import Foundation
import SwiftData
@Model

class Team {
    var ident: UUID
    var name: String
    var coach: String
    var details: String
    var players = [Player]()
    var games = [Game]()
    @Attribute(.externalStorage) var logo: Data?

    init(ident: UUID = UUID(), name: String, coach: String, details: String, players: [Player] = [Player](), games: [Game] = [Game](), logo:Data? = nil) {
        self.ident = ident
        self.name = name
        self.coach = coach
        self.details = details
        self.players = players
        self.games = games
        self.logo = logo
    }
}

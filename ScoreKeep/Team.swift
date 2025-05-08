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
    var name: String
    var coach: String
    var details: String
    var players = [Player]()
    var games = [Game]()

    init(name: String, coach: String, details: String) {
        self.name = name
        self.coach = coach
        self.details = details
     }
}

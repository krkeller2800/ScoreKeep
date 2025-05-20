//
//  Players.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/15/25.
//

import Foundation
import SwiftData

@Model
class Player {
    var identifier: UUID
    var name: String
    var number: String
    var position: String
    var batDir: String
    var batOrder: Int
    var team: Team?
    var atbat = [Atbat]()
    var game = [Game]()
    @Attribute(.externalStorage) var photo: Data?

    init(identifier: UUID = UUID(), name: String, number: String, position: String, batDir: String, batOrder: Int, team: Team? = nil, atbat: [Atbat] = [Atbat](), game: [Game] = [Game](), photo: Data? = nil) {
        self.identifier = identifier
        self.name = name
        self.number = number
        self.position = position
        self.batDir = batDir
        self.batOrder = batOrder
        self.team = team
        self.atbat = atbat
        self.game = game
        self.photo = photo
    }
}


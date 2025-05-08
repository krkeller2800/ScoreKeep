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
    var name: String
    var number: String
    var position: String
    var batOrder: CGFloat
    var team: Team?
    var atbat = [Atbat]()
    var game = [Game]()
    @Attribute(.externalStorage) var photo: Data?

    init(name: String, number: String, position: String, batOrder: CGFloat, team: Team? = nil) {
        self.name = name
        self.number = number
        self.position = position
        self.batOrder = batOrder
        self.team = team
    }
}


//
//  Game.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/15/25.
//

import Foundation
import SwiftData
@Model

class Game {
    var date: String
    var location: String
    var highLights: String
    var hscore: Int
    var vscore: Int
    var everyOneHits: Bool
    var numInnings: Int
    var vteam: Team?
    var hteam: Team?
    var players = [Player]()
    var atbats = [Atbat]()
    var lineups = [Lineup]()
    var pitchers = [Pitcher]()

    init(date: String, location: String, highLights: String, vscore: Int,hscore: Int, everyOneHits: Bool = false, numInnings: Int = 9,vteam: Team? = nil, hteam: Team? = nil,atbats: [Atbat] = [], lineups: [Lineup] = [], pitchers: [Pitcher] = []) {
        self.date = date
        self.location = location
        self.highLights = highLights
        self.vscore = vscore
        self.hscore = hscore
        self.everyOneHits = everyOneHits
        self.numInnings = numInnings
        self.vteam = vteam
        self.hteam = hteam
        self.atbats = atbats
        self.lineups = lineups
        self.pitchers = pitchers
    }
}

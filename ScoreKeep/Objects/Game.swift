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
    var ident: UUID
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
    var replaced = [Player]()
    var incomings = [Player]()

    init(ident: UUID = UUID(), date: String, location: String, highLights: String, hscore: Int, vscore: Int, everyOneHits: Bool = false, numInnings: Int = 9, vteam: Team? = nil, hteam: Team? = nil, players: [Player] = [Player](), atbats: [Atbat] = [Atbat](), lineups: [Lineup] = [Lineup](), pitchers: [Pitcher] = [Pitcher](), replaced: [Player] = [Player](), incomings: [Player] = [Player]()) {
        self.ident = ident
        self.date = date
        self.location = location
        self.highLights = highLights
        self.hscore = hscore
        self.vscore = vscore
        self.everyOneHits = everyOneHits
        self.numInnings = numInnings
        self.vteam = vteam
        self.hteam = hteam
        self.players = players
        self.atbats = atbats
        self.lineups = lineups
        self.pitchers = pitchers
        self.replaced = replaced
        self.incomings = incomings
    }
}

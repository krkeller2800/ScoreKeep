//
//  CommonData.swift
//  ScoreKeep
//
//  Created by Karl Keller on 4/20/25.
//

import SwiftUI
import SwiftData
import Foundation

struct Common {
    var hitresults:[String]
    var onresults:[String]
    var outresults:[String]
    var outabs:[String]
    var battings:[String]
    var batAbbrevs:[String]
    var innAbr:[String]
    init(
        hitresults:[String] = ["","Single", "Double", "Triple", "Home Run"],
        onresults:[String] = ["","Hit By Pitch","Dropped 3rd Strike","Walk","Single", "Double", "Triple", "Home Run"],
        outresults:[String] = ["", "Ground Out", "Fly Out", "Strikeout", "Strikeout Looking", "Fielder's Choice","Sacrifice"],
        outabs:[String] = ["", "GO", "FO", "K","FC","SAC","ꓘ"],
        battings:[String] = ["","Hit By Pitch","Dropped 3rd Strike","Walk","Single", "Double", "Triple", "Home Run", "Ground Out", "Fly Out", "Strikeout","Strikeout Looking","Fielder's Choice","Sacrifise fly","Sacrifice Bunt","Error"],
        batAbbrevs:[String] = ["","HP","DK3","BB","1b", "2b", "3b", "hr", "GO", "FO", "K","ꓘ","FC","SF","SB","E"],
        innAbr:[String] = ["","1st","2nd","3rd","4th","5th","6th","7th","8th","9th","10th","11th","12th","13th","14th","15th","16th","17th","18th"]
    ) {
        self.hitresults = hitresults
        self.onresults = onresults
        self.outresults = outresults
        self.outabs = outabs
        self.battings = battings
        self.batAbbrevs = batAbbrevs
        self.innAbr = innAbr   
    }
}
    
struct BoxScore {
    var type:String = ""
    var runs:Int = 0
    var hits:Int = 0
    var errors:Int = 0
    var strikeouts:Int = 0
    var walks:Int = 0
    var HR:Int = 0
}
extension UIScreen{
   static let screenWidth = UIScreen.main.bounds.size.width
   static let screenHeight = UIScreen.main.bounds.size.height
   static let screenSize = UIScreen.main.bounds.size
}
struct PitchStats {
    var runs:Int = 0
    var hits:Int = 0
    var HR:Int = 0
    var Ks:Int = 0
    var BB:Int = 0
    var singles:Int = 0
    var doubles:Int = 0
    var triples:Int = 0
    var innings:Int = 0
    var ERA:CGFloat = 0
    init(runs: Int, hits: Int, HR: Int, Ks: Int, BB: Int, singles: Int, doubles: Int, triples: Int, innings: Int, ERA: CGFloat) {
        self.runs = runs
        self.hits = hits
        self.HR = HR
        self.Ks = Ks
        self.BB = BB
        self.singles = singles
        self.doubles = doubles
        self.triples = triples
        self.innings = innings
        self.ERA = ERA
    }
}
//extension Pitcher: Hashable {
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(player)
//        hasher.combine(team)
//        hasher.combine(game)
//    }
//}
//extension Atbat: Hashable {
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(player)
//        hasher.combine(team)
//        hasher.combine(game)
//        hasher.combine(result)
//        hasher.combine(col)
//        hasher.combine(seq)
//    }
//}

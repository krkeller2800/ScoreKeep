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
    var atBats:[String]
    var hitresults:[String]
    var onresults:[String]
    var outresults:[String]
    var outabs:[String]
    var battings:[String]
    var batAbbrevs:[String]
    var innAbr:[String]
    var outAbr:[String]
    var keySym:[String]
    var keyWord:[String]
    var recOuts:[String]
    init(
        atBats:[String] = ["","Single", "Double", "Triple", "Home Run","Fielder's Choice", "Ground Out", "Fly Out", "Line Out", "Foul Out", "Strikeout", "Strikeout Looking","Error"],
        hitresults:[String] = ["","Single", "Double", "Triple", "Home Run"],
        onresults:[String] = ["","Hit By Pitch","Dropped 3rd Strike","Walk","Single", "Double", "Triple", "Home Run","Fielder's Choice"],
        outresults:[String] = ["", "Ground Out", "Fly Out", "Line Out", "Foul Out","Strikeout", "Strikeout Looking", "Sacrifice Fly","Strikeout Looking","Sacrifice Bunt"],
        recOuts:[String] = ["", "Ground Out", "Fly Out", "Line Out","Foul Out", "Sacrifice Fly","Sacrifice Bunt","Fielder's Choice"],
        outabs:[String] = ["", "GO", "F", "L", "F","FO", "K","SF","ꓘ","SB"],
        battings:[String] = ["","Hit By Pitch","Dropped 3rd Strike","Walk","Single", "Double", "Triple", "Home Run", "Ground Out", "Fly Out", "Line Out", "Foul Out", "Strikeout","Strikeout Looking","Fielder's Choice","Sacrifice Fly","Sacrifice Bunt","Error"],
        batAbbrevs:[String] = ["","HP","DK3","BB","1B", "2B", "3B", "HR", "GO", "F", "L", "FO","K","ꓘ","FC","SF","SB","E"],
        innAbr:[String] = ["0","1st","2nd","3rd","4th","5th","6th","7th","8th","9th","10th","11th","12th","13th","14th","15th","16th","17th","18th"],
        outAbr:[String] = ["0","1 Out","2 Out","3 out"],
        keySym:[String] = ["`","~","!","@","#","$","%","^","&","*","(",")","( )","-","_","=","+","[]","[","]","{ }","{","}","\\","/","|",";",":",#"'"#,#"""#,",",".","<>","<",">","?"],
        keyWord:[String] = ["Grave","Tilde","Exclamation","At sign","Pound","Dollar sign","Percent","Carat","Ampersand","Asterisk","Open paren","Close paren","Round brackets","Hyphen","Underscore","Equal sign","Plus sign","Square brackets","Open bracket","Close bracket","Curly brackets","Open brace","Close brace","Backslash","Slash","Pipe","Semicolon","Colon","Apostrophe","Double quotes","Comma","Period","Angle brackets","Less than","Greater than","Question mark"]
    ) {
        self.atBats = atBats
        self.hitresults = hitresults
        self.onresults = onresults
        self.outresults = outresults
        self.outabs = outabs
        self.battings = battings
        self.batAbbrevs = batAbbrevs
        self.innAbr = innAbr
        self.outAbr = outAbr
        self.keySym = keySym
        self.keyWord = keyWord
        self.recOuts = recOuts
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
struct PitchStats {
    var runs:Int = 0
    var uruns:Int = 0
    var hits:Int = 0
    var HR:Int = 0
    var Ks:Int = 0
    var BB:Int = 0
    var singles:Int = 0
    var doubles:Int = 0
    var triples:Int = 0
    var innings:Int = 0
    var ERA:CGFloat = 0
    init(runs: Int = 0,uruns: Int = 0, hits: Int = 0, HR: Int = 0, Ks: Int = 0, BB: Int = 0, singles: Int = 0, doubles: Int = 0, triples: Int = 0, innings: Int = 0, ERA: CGFloat) {
        self.runs = runs
        self.uruns = uruns
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
struct PlayerStats: Identifiable {
    let id = UUID()
    var player:Player?
    var atbats:Int
    var runs:Int
    var hits:Int
    var errors:Int
    var strikeouts:Int
    var strikeoutl:Int
    var HR:Int
    var single:Int
    var double:Int
    var triple:Int
    var BB:Int
    var sacBunt:Int
    var sacFly:Int
    var hbp:Int
    var dts:Int
    var fc:Int

    init(player: Player? = nil,atbats:Int = 0,runs: Int = 0, hits: Int = 0, errors: Int = 0, strikeouts: Int = 0, strikeoutl: Int = 0, HR: Int = 0, single: Int = 0, double: Int = 0, triple: Int = 0, BB: Int = 0, sacBunt: Int = 0, sacFly: Int = 0, hbp: Int = 0, dts: Int = 0, fc: Int = 0) {
        self.player = player
        self.atbats = atbats
        self.runs = runs
        self.hits = hits
        self.errors = errors
        self.strikeouts = strikeouts
        self.strikeoutl = strikeoutl
        self.HR = HR
        self.single = single
        self.double = double
        self.triple = triple
        self.BB = BB
        self.sacBunt = sacBunt
        self.sacFly = sacFly
        self.hbp = hbp
        self.dts = dts
        self.fc = fc
    }
}
struct LoadingView: View {
    var body: some View {
        Section {
            ProgressView() {
                Text("Processing...").font(.system(size: 8))
            }
            .progressViewStyle(CircularProgressViewStyle(tint: .red))
            .scaleEffect (1.3)
            .padding()
            .foregroundStyle(.black)
//            .border(.red, width: 2)
        }
    }
}

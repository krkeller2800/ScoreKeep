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
    var position:[String]
    var posAbbrev:[String]
    init(
        atBats:[String] = ["","Single", "Double", "Triple", "Home Run","Fielder's Choice", "Ground Out", "Fly Out", "Line Out", "Foul Out", "Strikeout", "Strikeout Looking","Error"],
        hitresults:[String] = ["","Single", "Double", "Triple", "Home Run"],
        onresults:[String] = ["","Hit By Pitch","Dropped 3rd Strike","Catcher Interference","Walk","Single", "Double", "Triple", "Home Run","Fielder's Choice","Error"],
        outresults:[String] = ["", "Ground Out", "Fly Out", "Line Out", "Foul Out","Strikeout", "Strikeout Looking", "Sacrifice Fly","Sacrifice Bunt"],
        recOuts:[String] = ["", "Ground Out", "Fly Out", "Line Out","Foul Out", "Sacrifice Fly","Sacrifice Bunt","Fielder's Choice"],
        outabs:[String] = ["", "GO", "F", "L", "F","FO", "K","SF","ꓘ","SB"],
        battings:[String] = ["","Hit By Pitch","Dropped 3rd Strike","Catcher Interference","Walk","Single", "Double", "Triple", "Home Run", "Ground Out", "Fly Out", "Line Out", "Foul Out", "Strikeout","Strikeout Looking","Fielder's Choice","Sacrifice Fly","Sacrifice Bunt","Error"],
        batAbbrevs:[String] = ["","HP","DK3","CI","BB","1B", "2B", "3B", "HR", "GO", "F", "L", "FO","K","ꓘ","FC","SF","SB","E"],
        innAbr:[String] = ["0","1st","2nd","3rd","4th","5th","6th","7th","8th","9th","10th","11th","12th","13th","14th","15th","16th","17th","18th"],
        outAbr:[String] = ["0","1 Out","2 Out","3 out"],
        keySym:[String] = ["`","~","!","@","#","$","%","^","&","*","(",")","( )","-","_","=","+","[]","[","]","{ }","{","}","\\","/","|",";",":",#"'"#,#"""#,",",".","<>","<",">","?"],
        keyWord:[String] = ["Grave","Tilde","Exclamation","At sign","Pound","Dollar sign","Percent","Carat","Ampersand","Asterisk","Open paren","Close paren","Round brackets","Hyphen","Underscore","Equal sign","Plus sign","Square brackets","Open bracket","Close bracket","Curly brackets","Open brace","Close brace","Backslash","Slash","Pipe","Semicolon","Colon","Apostrophe","Double quotes","Comma","Period","Angle brackets","Less than","Greater than","Question mark"],
        position:[String] = ["Pitcher", "Starting Pitcher", "Relief Pitcher", "Catcher", "First Baseman", "Second Baseman", "Shortstop", "Third Baseman", "Left Fielder", "Center Fielder", "Right Fielder","Designated Hitter"],
        posAbbrev:[String] = ["P","SP","RP","C","1B","2B","SS","3B","LF","CF","RF","DH","??"]
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
        self.position = position
        self.posAbbrev = posAbbrev
    }
}
    
struct BoxScore: Hashable {
    var type:String = ""
    var runs:Int = 0
    var hits:Int = 0
    var error:Int = 0
    var stoleBase:Int = 0
    var strikeouts:Int = 0
    var walks:Int = 0
    var HR:Int = 0
    var inning:Int = 0
}
struct PitchStats: Identifiable {
    var id = UUID()
    var pitcher:Pitcher?
    var wins:Int = 0
    var runs:Int = 0
    var uruns:Int = 0
    var hits:Int = 0
    var HR:Int = 0
    var Ks:Int = 0
    var Ksl:Int = 0
    var BB:Int = 0
    var singles:Int = 0
    var doubles:Int = 0
    var triples:Int = 0
    var innings:CGFloat = 0
    var pitchingOuts:Int = 0
    var hbp:Int = 0
    var ERA:CGFloat = 0
    init(pitcher: Pitcher? = nil, wins: Int = 0, runs: Int = 0,uruns: Int = 0, hits: Int = 0, HR: Int = 0, Ks: Int = 0, Ksl: Int = 0, BB: Int = 0, singles: Int = 0, doubles: Int = 0, triples: Int = 0, innings: CGFloat = 0, pitchingOuts: Int = 0, hbp: Int = 0, ERA: CGFloat) {
        self.pitcher = pitcher
        self.wins = wins
        self.runs = runs
        self.uruns = uruns
        self.hits = hits
        self.HR = HR
        self.Ks = Ks
        self.Ksl = Ksl
        self.BB = BB
        self.singles = singles
        self.doubles = doubles
        self.triples = triples
        self.innings = innings
        self.pitchingOuts = pitchingOuts
        self.hbp = hbp
        self.ERA = ERA
    }
}

public enum PitchingInningsCalculator {
    public static func recordedOuts(startInn: Int, sOuts: Int, endInn: Int, eOuts: Int) -> Int {
        max(0, ((endInn - startInn) * 3) + (eOuts - sOuts))
    }

    static func recordedOuts(for pitcher: Pitcher) -> Int {
        recordedOuts(
            startInn: pitcher.startInn,
            sOuts: pitcher.sOuts,
            endInn: pitcher.endInn,
            eOuts: pitcher.eOuts
        )
    }

    public static func decimalInnings(fromOuts outs: Int) -> CGFloat {
        CGFloat(max(0, outs)) / 3.0
    }

    public static func baseballNotation(fromOuts outs: Int) -> CGFloat {
        let safeOuts = max(0, outs)
        return CGFloat(safeOuts / 3) + (CGFloat(safeOuts % 3) / 10.0)
    }

    public static func displayString(fromOuts outs: Int) -> String {
        let safeOuts = max(0, outs)
        let wholeInnings = safeOuts / 3
        let remainingOuts = safeOuts % 3
        switch (wholeInnings, remainingOuts) {
        case (_, 0):
            return "\(wholeInnings)"
        case (0, 1):
            return "⅓"
        case (0, 2):
            return "⅔"
        case (_, 1):
            return "\(wholeInnings)⅓"
        default:
            return "\(wholeInnings)⅔"
        }
    }
}
struct PlayerStats: Identifiable {
    var id = UUID()
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

extension PlayerStats {
    var battingAverageThousandths: Int {
        atbats == 0 ? 0 : (1000 * hits) / atbats
    }

    static func statisticsReportSort(_ lhs: PlayerStats, _ rhs: PlayerStats) -> Bool {
        if lhs.battingAverageThousandths != rhs.battingAverageThousandths {
            return lhs.battingAverageThousandths > rhs.battingAverageThousandths
        }

        if lhs.atbats != rhs.atbats {
            return lhs.atbats > rhs.atbats
        }

        if lhs.hits != rhs.hits {
            return lhs.hits > rhs.hits
        }

        return ReportPlayerIdentitySort.precedes(
            lhsName: lhs.player?.name ?? "",
            lhsNumber: lhs.player?.number ?? "",
            lhsID: lhs.id,
            rhsName: rhs.player?.name ?? "",
            rhsNumber: rhs.player?.number ?? "",
            rhsID: rhs.id
        )
    }
}

extension PitchStats {
    static func statisticsReportSort(_ lhs: PitchStats, _ rhs: PitchStats) -> Bool {
        if lhs.ERA != rhs.ERA {
            return lhs.ERA < rhs.ERA
        }

        if lhs.pitchingOuts != rhs.pitchingOuts {
            return lhs.pitchingOuts > rhs.pitchingOuts
        }

        if lhs.wins != rhs.wins {
            return lhs.wins > rhs.wins
        }

        return ReportPlayerIdentitySort.precedes(
            lhsName: lhs.pitcher?.player.name ?? "",
            lhsNumber: lhs.pitcher?.player.number ?? "",
            lhsID: lhs.id,
            rhsName: rhs.pitcher?.player.name ?? "",
            rhsNumber: rhs.pitcher?.player.number ?? "",
            rhsID: rhs.id
        )
    }
}

private enum ReportPlayerIdentitySort {
    static func precedes(
        lhsName: String,
        lhsNumber: String,
        lhsID: UUID,
        rhsName: String,
        rhsNumber: String,
        rhsID: UUID
    ) -> Bool {
        let nameComparison = lhsName.localizedCaseInsensitiveCompare(rhsName)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        if lhsName != rhsName {
            return lhsName < rhsName
        }

        let numberComparison = lhsNumber.localizedStandardCompare(rhsNumber)
        if numberComparison != .orderedSame {
            return numberComparison == .orderedAscending
        }

        return lhsID.uuidString < rhsID.uuidString
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
struct MyPreferenceKey: PreferenceKey {
    static var defaultValue: String = ""

    static func reduce(value: inout String, nextValue: () -> String) {
        value = nextValue()
    }
}
struct InnStatus {
    var outs:Int = 0
    var onFirst:Bool = false
    var onSecond:Bool = false
    var onThird:Bool = false
}

enum DataError: Error, LocalizedError {
    case savingData (dataType: String = "")
    case insertingData (dataType: String = "")
    case deletingData (dataType: String = "")
    case SwiftDataError (error: Error)
    var errorDescription: String? {
        switch self {
        case .savingData(dataType: let dataType):
            return "Error while saving \(dataType)"
        case .insertingData(dataType: let dataType):
            return "Error Inserting \(dataType)"
        case .deletingData(dataType: let dataType):
            return "Error Deleting \(dataType)"
        case .SwiftDataError(error: let error):
            return "Swift Data Error: \(error.localizedDescription)"
        }
    }
}
struct SharePlayer: Identifiable, Codable {
    var id = UUID()
    var name: String = ""
    var number: String = ""
    var position: String = ""
    var batDir: String = ""
    var batOrder: Int = 0
    var team: ShareTeam?
    var atbats: [ShareAtbat] = []
    var photo: Data = Data()
}
struct ShareGame: Identifiable, Codable {
    var id = UUID()
    var date: String = ""
    var location: String = ""
    var highLights: String = ""
    var hscore: Int = 0
    var vscore: Int = 0
    var everyOneHits: Bool = false
    var numInnings: Int = 0
    var vteam: ShareTeam
    var hteam: ShareTeam
    var players: [SharePlayer] = []
    var atbats: [ShareAtbat] = []
    var lineups: [ShareLineup] = []
    var pitchers: [SharePitcher] = []
    var replaced: [SharePlayer] = []
    var incomings: [SharePlayer] = []
}
struct ShareTeam: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String = ""
    var coach: String = ""
    var details: String = ""
    var players = [SharePlayer]()
    var games = [ShareGame]()
    var logo: Data = Data()
}
struct ShareAtbat: Identifiable, Codable {
    var id: UUID = UUID()
    var game: ShareGame?
    var team: ShareTeam
    var player: SharePlayer
    var result: String
    var maxbase: String
    var batOrder: Int
    var outAt: String
    var inning: CGFloat
    var seq: Int
    var col: Int
    var rbis: Int
    var outs: Int
    var sacFly: Int
    var sacBunt: Int
    var stolenBases: Int
    var earnedRun: Bool
    var playRec: String
    var endOfInning: Bool
}
struct ShareLineup: Identifiable, Codable {
    var id: UUID = UUID()
    var everyoneHits: Bool
    var game: ShareGame?
    var team: ShareTeam
    var inning: Int
    var players: [SharePlayer] = []
}
struct SharePitcher: Identifiable, Codable {
    var id: UUID = UUID()
    var player: SharePlayer
    var team: ShareTeam
    var game: ShareGame?
    var startInn: Int
    var sOuts: Int
    var sBats: Int
    var endInn: Int
    var eOuts: Int
    var eBats: Int
    var strikeOuts: Int
    var walks: Int
    var hits: Int
    var runs: Int
    var won: Bool
}

extension SharePitcher: CanonicalPitcherAppearance {
    var canonicalIdentString: String { id.uuidString }
}

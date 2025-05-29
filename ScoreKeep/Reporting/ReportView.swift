//
//  ReportView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/14/25.
//

import SwiftUI
import SwiftData
struct ReportView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State  var navigationPath = NavigationPath()
    @State  var sortAtbat = [SortDescriptor(\Atbat.col), SortDescriptor(\Atbat.seq)]
    @State  var tName:String
    @State  var alertMessage = ""
    @State  var showingAlert = false

    
    @Query var atbats: [Atbat]
    
    var com:Common = Common()

    var body: some View {
        Section {
            VStack(spacing:0) {
                HStack {
                    Spacer()
                    Text("\(tName) Hitting").font(.largeTitle).foregroundColor(.black).bold().italic().frame(alignment: .center).padding()
                    Spacer()
                }
                HStack {
                    Text("Num").foregroundColor(.red).bold().frame(width: 40)
                    Text("Name").foregroundColor(.red).bold().frame(width: 150, alignment: .leading)
                    Text("Bats").foregroundColor(.red).bold().frame(width: 40)
                    Text("AVG").foregroundColor(.red).bold().frame(width: 40)
                    Text("OBP").foregroundColor(.red).bold().frame(width: 40)
                    Text("SLG").foregroundColor(.red).bold().frame(width: 40)
                    Text("OPS").foregroundColor(.red).bold().frame(width: 40)
                    Text("Run").foregroundColor(.red).bold().frame(width: 40)
                    Text("Hit").foregroundColor(.red).bold().frame(width: 40)
                    Text("K").foregroundColor(.red).bold().frame(width: 40)
                    Text("ꓘ").foregroundColor(.red).bold().frame(width: 40)
                    Text("BB").foregroundColor(.red).bold().frame(width: 40)
                    Text("HR").foregroundColor(.red).bold().frame(width: 40)
                    Text("1B").foregroundColor(.red).bold().frame(width: 40)
                    Text("2B").foregroundColor(.red).bold().frame(width: 40)
                    Text("3B").foregroundColor(.red).bold().frame(width: 40)
                    Text("SAC").foregroundColor(.red).bold().frame(width: 40)
                    Text("SF").foregroundColor(.red).bold().frame(width: 40)
                    Text("HBP").foregroundColor(.red).bold().frame(width: 40)
                    Text("K23").foregroundColor(.red).bold().frame(width: 40)
                    Text("FC").foregroundColor(.red).bold().frame(width: 40)
                    Spacer()
                }
                ForEach(atbats) { atbat in
                    HStack {
                        let stats = doStats(player: atbat.player)
                        let avg:Int = stats.atbats == 0 ? 0 : Int(Double(1000 * stats.hits / stats.atbats))
                        let obp:Int = stats.atbats == 0 ? 0 : Int(Double(1000 * (stats.hits + stats.BB + stats.hbp) /
                                                                         (stats.atbats + stats.BB + stats.hbp + stats.sacFly)))
                        let slg:Int = stats.atbats == 0 ? 0 :Int(Double(1000 * (stats.single + (2 * stats.double) + (3 * stats.triple) + (4 * stats.HR)) /
                                                                        stats.atbats))
                        Text(atbat.player.number).foregroundColor(.black).bold().frame(width: 40,alignment: .leading)
                        Text(atbat.player.name).foregroundColor(.black).bold().frame(width: 150,alignment: .leading)
                        Text("\(stats.atbats)").foregroundColor(.black).bold().frame(width: 40)
                        Text(String(format: "%03d", avg)).foregroundColor(.black).bold().frame(width: 41,alignment: .center)
                        Text(String(format: "%03d", obp)).foregroundColor(.black).bold().frame(width: 41,alignment: .center)
                        Text(String(format: "%03d", slg)).foregroundColor(.black).bold().frame(width: 41,alignment: .center)
                        Text(String(format: "%03d", obp + slg)).foregroundColor(.black).bold().frame(width: 41,alignment: .center)
                        Text("\(stats.runs)").foregroundColor(.black).bold().frame(width: 35,alignment: .center)
                        Text("\(stats.hits)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.strikeouts)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.strikeoutl)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.BB)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.HR)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.single)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.double)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.triple)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.sacBunt)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.sacFly)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.hbp)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.dts)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Text("\(stats.fc)").foregroundColor(.black).bold().frame(width: 40,alignment: .center)
                        Spacer()
                    }
                }
                .drawingGroup()
            }
            Spacer()
        }
        header: {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Text("< Back").padding(.leading,10)
                }
                Spacer()
                Text("Player Statistics").frame(width:225, alignment:.leading).font(.title3).foregroundColor(.black).bold()
                Spacer()
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
    
    init(teamName: String, sortOrder: [SortDescriptor<Atbat>] = [SortDescriptor(\Atbat.player.name)]) {
        
        tName = teamName
        _atbats = Query(filter: #Predicate { atbat in
                atbat.team.name == teamName
        },  sort: sortOrder)
    }
    func doStats(player:Player)->PlayerStats {
        let com = Common()
        let atb = atbats.filter({ com.atBats.contains($0.result) && $0.player == player }).count
        let runs = atbats.filter({$0.maxbase == "Home" && $0.player == player }).count
        let hits = atbats.filter({com.hitresults.contains($0.result) && $0.player == player }).count
        let single = atbats.filter({$0.result == "Single" && $0.player == player }).count
        let double = atbats.filter({$0.result == "Doble" && $0.player == player }).count
        let triple = atbats.filter({$0.result == "Triple" && $0.player == player }).count
        let hr = atbats.filter({$0.result == "Home Run" && $0.player == player }).count
        let bb = atbats.filter({$0.result == "Walk" && $0.player == player }).count
        let hbp = atbats.filter({$0.result == "Hit By Pitch" && $0.player == player }).count
        let dts = atbats.filter({$0.result == "Dropped 3rd Strike" && $0.player == player }).count
        let fc = atbats.filter({$0.result == "Fielder's Choice" && $0.player == player }).count
        let sacf = atbats.filter({$0.result == "Sacrifise fly" && $0.player == player }).count
        let sacb = atbats.filter({$0.result == "Sacrifise Bunt" && $0.player == player}).count
        let ks = atbats.filter({$0.result == "Strikeout" && $0.player == player}).count
        let kl = atbats.filter({$0.result == "Strikeout Looking" && $0.player == player}).count

        return PlayerStats(atbats: atb, runs: runs, hits: hits, strikeouts: ks, strikeoutl: kl, HR: hr, single: single, double: double, triple: triple, BB: bb, sacBunt: sacf, sacFly: sacb, hbp: hbp, dts: dts, fc: fc)
     }
}


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
    @Binding var isLoading: Bool
    @State  var alertMessage = ""
    @State  var showingAlert = false
    @State var sumedStats:[PlayerStats] = []

    
    @Query var atbats: [Atbat]
    
    var com:Common = Common()

    var body: some View {
        ScrollView {
            Section {
                GeometryReader { geometry in
                    VStack(spacing:50) {
                        HStack {
                            Text("\(Date.now.formatted(date: .long, time: .omitted))").padding(.leading,5)
                            Spacer()
                            if atbats.count > 0 {
                                if let imageData = atbats[0].team.logo, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .scaleImage(iHeight: 50, imageData: imageData)
                                }
                                Text("\(tName) Hitting").font(.largeTitle).foregroundColor(.black).bold().italic().frame(alignment: .center)
                            }
                            Spacer()
                            Text("\(Date.now.formatted(date: .long, time: .omitted))").foregroundColor(.white).padding(.trailing,5)                        }
                        let avgSize = geometry.size.width / 31
                        VStack(spacing:0) {
                            HStack {
                                Text("").frame(maxWidth:5)
                                Text("Num").frame(width: avgSize,height: 30).border(.gray).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.75)
                                Text("Name").frame(width: avgSize * 5,height: 30, alignment: .leading).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("Bats").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("AVG").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.75)
                                Text("OBP").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.75)
                                Text("SLG").frame(width: avgSize + 10,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.75)
                                Text("OPS").frame(width: avgSize + 10,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.75)
                                Text("Run").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.75)
                                Text("Hit").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.75)
                                Text("K").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("ꓘ").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("BB").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("HR").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("1B").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("2B").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("3B").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("SAC").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("SF").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("HBP").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("K23").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text("FC").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Spacer()
                            }
                            let summedStats = sumedStats.sorted { $0.player?.batOrder ?? 0 < $1.player?.batOrder ?? 0 }
                            ForEach(summedStats) { stats in
                                HStack {
                                    let avg:Int = stats.atbats == 0 ? 0 : Int(Double(1000 * stats.hits / stats.atbats))
                                    let obp:Int = stats.atbats == 0 ? 0 : Int(Double(1000 * (stats.hits + stats.BB + stats.hbp) /
                                                                                     (stats.atbats + stats.BB + stats.hbp + stats.sacFly)))
                                    let slg:Int = stats.atbats == 0 ? 0 :Int(Double(1000 * (stats.single + (2 * stats.double) + (3 * stats.triple) + (4 * stats.HR)) /
                                                                                    stats.atbats))
                                    Text("").frame(maxWidth:10)
                                    Text(stats.player?.number ?? "").foregroundColor(.black).bold().frame(width: avgSize - 5,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text(stats.player?.name ?? "").foregroundColor(.black).bold().frame(width: avgSize * 5,height: 30,alignment: .leading).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.atbats)").foregroundColor(.black).bold().frame(width: avgSize,height: 30).lineLimit(1).minimumScaleFactor(0.75)
                                    Text(String(format: "%03d", avg)).foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text(String(format: "%03d", obp)).foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text(String(format: "%03d", slg)).foregroundColor(.black).bold().frame(width: avgSize + 10,height: 30,alignment: .center)
                                        .lineLimit(1).minimumScaleFactor(0.75)
                                    Text(String(format: "%03d", obp + slg)).foregroundColor(.black).bold().frame(width: avgSize + 15,height: 30,alignment: .center)
                                        .lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.runs)").foregroundColor(.black).bold().frame(width: avgSize - 5,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.hits)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.strikeouts)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.strikeoutl)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.BB)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.HR)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.single)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.double)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.triple)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.sacBunt)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.sacFly)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.hbp)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.dts)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Text("\(stats.fc)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.75)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .drawingGroup()
                    .onAppear() {
                        sumData()
                        isLoading = false
                    }
                    Spacer()
                }
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
    }
    
    init(teamName: String, isLoading: Binding<Bool> ,sortOrder: [SortDescriptor<Atbat>] = [SortDescriptor(\Atbat.player.name)]) {
        
        tName = teamName
        _isLoading = isLoading
        
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
        let double = atbats.filter({$0.result == "Double" && $0.player == player }).count
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

        return PlayerStats(player: player, atbats: atb, runs: runs, hits: hits, strikeouts: ks, strikeoutl: kl, HR: hr, single: single, double: double, triple: triple, BB: bb, sacBunt: sacf, sacFly: sacb, hbp: hbp, dts: dts, fc: fc)
     }
    func sumData() {
        var prevPlayer = Player(name: "", number: "", position: "", batDir: "", batOrder: 0)
        for atbat in atbats {
            if atbat.player != prevPlayer && prevPlayer.name != "" {
                sumedStats.append(doStats(player:prevPlayer))
            }
            prevPlayer = atbat.player
        }
        sumedStats.append(doStats(player:prevPlayer))
    }
}


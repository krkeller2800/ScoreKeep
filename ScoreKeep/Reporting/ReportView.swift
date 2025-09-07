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
    
    @State  var sortAtbat = [SortDescriptor(\Atbat.col), SortDescriptor(\Atbat.seq)]
    @State  var tName:String
    @Binding var isLoading: Bool
    @State  var alertMessage = ""
    @State  var showingAlert = false
    @State var sumedStats:[PlayerStats] = []
    @State var screenshotMaker: ScreenshotMaker?
    @State var doShot = false
    @State var hasChanged = false
    @State var url:URL?

    @Query var atbats: [Atbat]
    
    var com:Common = Common()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ScrollView {
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
                        let avgSize = geometry.size.width / 32
                        VStack(spacing:0) {
                            HStack {
                                Text("Num").frame(width: avgSize + 10,height: 30, alignment: .center).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3), ignoresSafeAreaEdges: [])
                                    .lineLimit(1).minimumScaleFactor(0.50).padding(.leading,5)
                                Text("Name").frame(width: avgSize * 4,height: 30, alignment: .leading).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("Bats").frame(width: avgSize + 10,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("AVG").frame(width: avgSize + 10,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.50)
                                Text("OBP").frame(width: avgSize + 10,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.50)
                                Text("SLG").frame(width: avgSize + 10,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.50)
                                Text("OPS").frame(width: avgSize + 10,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.50)
                                Text("R").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.50)
                                Text("H").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3)).lineLimit(1).minimumScaleFactor(0.50)
                                Text("K").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("ꓘ").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("BB").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("HR").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("1B").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("2B").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("3B").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("SAC").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("SF").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("HBP").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("K23").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50)
                                Text("FC").frame(width: avgSize,height: 30).border(.gray).lineLimit(1).foregroundColor(.red).background(.yellow.opacity(0.3))
                                    .lineLimit(1).minimumScaleFactor(0.50).padding(.trailing,5)
                            }
                            let summedStats = sumedStats.sorted { $0.player?.batOrder ?? 0 < $1.player?.batOrder ?? 0 }
                            ForEach(summedStats) { stats in
                                HStack {
                                    let avg:Int = stats.atbats == 0 ? 0 : Int(Double(1000 * stats.hits / stats.atbats))
                                    let obp:Int = stats.atbats == 0 ? 0 : Int(Double(1000 * (stats.hits + stats.BB + stats.hbp) /
                                                                                            (stats.atbats + stats.BB + stats.hbp + stats.sacFly)))
                                    let slg:Int = stats.atbats == 0 ? 0 :Int(Double(1000 * (stats.single + (2 * stats.double) + (3 * stats.triple) +
                                                                                           (4 * stats.HR)) / stats.atbats))
                                    let nm = (stats.player?.name ?? "").components(separatedBy: " ")
                                    let name = nm.count > 1 && UIDevice.type == "iPhone" ? nm[1] : nm.count == 1 ? nm[0] : nm.count > 1 ? nm[0] + " " + nm[1] : "Unknown"
                                    Text(stats.player?.number ?? "").foregroundColor(.black).bold().frame(width: avgSize + 10,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50).padding(.leading,5)
                                    Text(name).foregroundColor(.black).bold().frame(width: avgSize * 4,height: 30,alignment: .leading).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.atbats)").foregroundColor(.black).bold().frame(width: avgSize + 10,height: 30).lineLimit(1).minimumScaleFactor(0.50)
                                    Text(String(format: "%03d", avg)).foregroundColor(.black).bold().frame(width: avgSize + 10,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text(String(format: "%03d", obp)).foregroundColor(.black).bold().frame(width: avgSize + 10,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text(String(format: "%03d", slg)).foregroundColor(.black).bold().frame(width: avgSize + 10,height: 30,alignment: .center)
                                        .lineLimit(1).minimumScaleFactor(0.50)
                                    Text(String(format: "%03d", obp + slg)).foregroundColor(.black).bold().frame(width: avgSize + 15,height: 30,alignment: .center)
                                        .lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.runs)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.hits)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.strikeouts)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.strikeoutl)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.BB)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.HR)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.single)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.double)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.triple)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.sacBunt)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.sacFly)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.hbp)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.dts)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50)
                                    Text("\(stats.fc)").foregroundColor(.black).bold().frame(width: avgSize,height: 30,alignment: .center).lineLimit(1).minimumScaleFactor(0.50).padding(.trailing,5)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        }
                        .onAppear() {
                            sumData()
                            isLoading = false
                        }
                        .onChange(of: doShot) {
                            if doShot {
                                if let screenshotMaker = screenshotMaker {
                                    url = saveImage(uiimage: screenshotMaker.screenshot()!)
                                    doShot.toggle()
                                }
                            }
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .topBarLeading) {
                                Button(action: {
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                }
                            }
                            ToolbarItemGroup(placement: .topBarLeading) {
                                if UIDevice.type == "iPad" {
                                    Button {
                                        hasChanged = false
                                        doShot = true
                                    } label: {
                                        Text(" Screenshot")
                                    }
                                    .buttonStyle(ToolBarButtonStyle())
                                    if let shotURL = url {
                                        if hasChanged == false {
                                            ShareLink("Share", item: shotURL)
                                        }
                                    }
                                }
                            }
                            ToolbarItem(placement: .principal) {
                                Text("Player Statistics").font(.title2)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .screenshotMaker { screenshotMaker in
                     self.screenshotMaker = screenshotMaker
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
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
    func saveImage(uiimage: UIImage?)-> URL? {
        
        guard let data = uiimage?.jpegData(compressionQuality: 0.8) else {
            print("Could not convert UIImage to Data.")
            alertMessage = "Could not save image"
            showingAlert = true
            isLoading = false
               return nil
        }
        
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = url.appendingPathComponent("\(tName) Stats.jpg")
        
        do {
            try data.write(to: fileURL)
            print("Image saved successfully to: \(fileURL.path)")
            isLoading = false
            return fileURL
        } catch {
            print("Error saving image: \(error.localizedDescription)")
            alertMessage = "Could not save image"
            showingAlert = true
            isLoading = false
        }
        return nil
    }
}


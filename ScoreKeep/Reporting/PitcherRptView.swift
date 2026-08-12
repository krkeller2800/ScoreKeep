//
//  PitcherRptView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 7/3/25.
//

import SwiftUI
import SwiftData
struct PitcherRptView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State  var navigationPath = NavigationPath()
    @State  var sortAtbat = [SortDescriptor(\Atbat.col), SortDescriptor(\Atbat.seq)]
    @State  var tName:String
    @Binding var isLoading: Bool
    @State  var alertMessage = ""
    @State  var showingAlert = false
    @State var sumedStats:[PitchStats] = []
    @State var atbats:[Atbat] = []
    @State var screenshotMaker: ScreenshotMaker?
    @State var doShot = false
    @State var hasChanged = false
    @State var url:URL?
 
    @Query var pitchers: [Pitcher]
    
    var com:Common = Common()
    private let iPhoneTableWidth: CGFloat = 900

    var body: some View {
        NavigationStack {
            VStack(spacing:10) {
                HStack {
                    Text("Through \(Date.now.formatted(date: .abbreviated, time: .omitted))").padding(.leading,10)
                    Spacer()
                    if pitchers.count > 0 {
                        HStack {
                            if let imageData = pitchers[0].team.logo, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .scaleImage(iHeight: 30, imageData: imageData)
                            }
                            Text("\(tName) Pitching Stats").font(.headline).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold().italic().frame(alignment: .center)
                        }
                    }
                    Spacer()
                    Text("Through \(Date.now.formatted(date: .abbreviated, time: .omitted))").foregroundColor(.white).padding(.trailing,10)
                }
                pitchingStatsTable
                .onAppear() {
                    if !pitchers.isEmpty {
                        var prevPitcher = pitchers[0]
                        var sStats = PitchStats(pitcher: prevPitcher, ERA: 0.0)
                        sumedStats.removeAll()
                        for pitcher in pitchers {
                            if pitcher.player.name == prevPitcher.player.name {
                                sumData(stats:&sStats)
                            }
                            else {
                                sumedStats.append(sStats)
                                sStats = PitchStats(pitcher: pitcher, ERA: 0.0)
                                sumData(stats:&sStats)
                                prevPitcher = pitcher
                            }
                        }
                        sumedStats.append(sStats)
                    }
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
                .alert(alertMessage, isPresented: $showingAlert) {
                    Button("OK", role: .cancel) { }
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
                                Text("Screenshot")
                            }
                            .frame(width: 118)
                            .buttonStyle(ToolBarButtonStyle())
                            if let shotURL = url {
                                if hasChanged == false {
                                    ShareLink("Share", item: shotURL)
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Pitcher Statistics").font(.title2)
                    }
                }

                Spacer()
            }
//            header: {
//                        HStack {
//                            Button(action: {
//                                dismiss()
//                            }) {
//                                Text("< Back").padding(.leading,10)
//                            }
//                            Spacer()
//                            Text("Pitching Statistics").frame(width:225, alignment:.leading).font(.title3).foregroundColor(.black).bold()
//                            Spacer()
//                        }
//                                }
            .screenshotMaker { screenshotMaker in
                 self.screenshotMaker = screenshotMaker
            }
        }
    }

    @ViewBuilder
    private var pitchingStatsTable: some View {
        if UIDevice.type == "iPhone" {
            ScrollView(.horizontal) {
                pitchingStatsContent
                    .frame(width: iPhoneTableWidth)
            }
        } else {
            pitchingStatsContent
        }
    }

    private var pitchingStatsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            pitchingStatsHeader
            pitchingStatsRows
        }
    }

    private var pitchingStatsHeader: some View {
        HStack {
            Text("").frame(maxWidth:5)
            scorebookHeaderCell("#", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("Pitcher", semantic: true, scaleFactor: 0.5)
                .frame(width: 150)
            scorebookHeaderCell("ERA", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("IP", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("ER", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("UER", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("H", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("K", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("ꓘ", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("BB", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("HBP", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("HR", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("1B", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("2B", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("3B", semantic: true, scaleFactor: 0.5)
                .frame(maxWidth:.infinity)
            Text("").frame(maxWidth:5)
        }
        .frame(height: 34)
    }

    private var pitchingStatsRows: some View {
        ScrollView {
            let summedStats = sumedStats.sorted { $0.pitcher?.player.name ?? "" < $1.pitcher?.player.name ?? "" }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(summedStats) { stats in
                    HStack {
                        Text("").frame(maxWidth:5)
                        Text("\(stats.pitcher?.player.number ?? "")")
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text("\(stats.pitcher?.player.name ?? "")")
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(width: 150,alignment: .leading).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.ERA), format: .number.rounded(increment: 0.01))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.innings), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.runs), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.uruns), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.hits), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.Ks), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.Ksl), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.BB), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.hbp), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.HR), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.singles), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.doubles), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Double(stats.triples), format: .number.rounded(increment: 1.0))
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText).frame(maxWidth:.infinity).lineLimit(1).minimumScaleFactor(0.5)
                        Text("").frame(maxWidth:5)
                    }
                }
            }
        }
    }
    
    init(teamName: String, isLoading: Binding<Bool> ,sortOrder: [SortDescriptor<Pitcher>] = [SortDescriptor(\.player.name)]) {
        
        tName = teamName
        _isLoading = isLoading
        
        _pitchers = Query(filter: #Predicate { pitcher in
                pitcher.team.name == teamName
        },  sort: sortOrder)
    }
    func doPitchers(pitcher: Pitcher)->PitchStats {
        if atbats.count > 0 {
            let endinn = pitcher.endInn > 0 ? pitcher.endInn : Int(atbats[(atbats.count - 1)].inning) + 1
            let innings = CGFloat(atbats.filter({com.outresults.contains($0.result) && (10 * (Int($0.inning + 1)) + $0.outs >= (10 * pitcher.startInn) + pitcher.sOuts) &&
                (10 * (Int($0.inning + 1)) + $0.outs <= (10 * endinn) + pitcher.eOuts ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count) / 3
            let runs = atbats.filter({$0.maxbase == "Home" &&  (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3)) && $0.earnedRun}).count
            let uruns = atbats.filter({$0.maxbase == "Home" &&  (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3)) && !$0.earnedRun}).count
            let hits = atbats.filter({com.hitresults.contains($0.result) &&    (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let HR = atbats.filter({$0.result == "Home Run" && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let BB = atbats.filter({$0.result == "Walk" && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let Ks = atbats.filter({$0.result == "Strikeout" && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let Ksl = atbats.filter({$0.result == "Strikeout Looking" && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let hbp = atbats.filter({$0.result == "Hit By Pitch" && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let singles = atbats.filter({$0.result == "Single" &&  (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let doubles = atbats.filter({$0.result == "Double" &&  (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let triples = atbats.filter({$0.result == "Triple" &&  (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            
            let ERA = innings == 0 ? 0 : CGFloat(runs) / innings * 9
            return PitchStats(runs: runs, uruns: uruns, hits: hits, HR: HR, Ks: Ks, Ksl: Ksl, BB: BB, singles: singles, doubles: doubles, triples: triples, innings: Int(innings), hbp: hbp, ERA: ERA)
        } else {
            return PitchStats(ERA: 0.0)
        }
    }
    func sumData(stats: inout PitchStats) {
        if stats.pitcher != nil {
            let tm = stats.pitcher!.team
            atbats = stats.pitcher!.game.atbats.filter {$0.team != tm }
            let thisStats = doPitchers(pitcher: stats.pitcher!)
            stats.runs += thisStats.runs
            stats.uruns += thisStats.uruns
            stats.hits += thisStats.hits
            stats.HR += thisStats.HR
            stats.BB += thisStats.BB
            stats.Ks += thisStats.Ks
            stats.Ksl += thisStats.Ksl
            stats.singles += thisStats.singles
            stats.doubles += thisStats.doubles
            stats.triples += thisStats.triples
            stats.innings += thisStats.innings
            stats.hbp += thisStats.hbp
            stats.ERA = stats.innings == 0 ? 0.0 : (CGFloat(stats.runs) / CGFloat(stats.innings)) * 9
        }
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
        let fileURL = url.appendingPathComponent("\(tName) Pitching Stats.jpg")
        
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

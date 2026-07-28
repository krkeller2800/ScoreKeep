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
    private var sortedStats: [PlayerStats] {
        sumedStats.sorted(by: { (lhs: PlayerStats, rhs: PlayerStats) -> Bool in
            (lhs.player?.batOrder ?? 0) < (rhs.player?.batOrder ?? 0)
        })
    }
    private let iPhoneTableWidth: CGFloat = 900
    private let rateColumnWidth: CGFloat = 42

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
//                let avgSize = geometry.size.width / 32
                VStack (spacing: 10) {
                    HStack {
                        Text(Date.now.formatted(date: .abbreviated, time: .omitted)).padding(.leading,10)
                        Spacer()
                        HStack {
                            if atbats.count > 0 {
                                if let imageData = atbats[0].team.logo, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .scaleImage(iHeight: 30, imageData: imageData)
                                }
                                Text("\(tName) Hitting").font(.headline).foregroundStyle(ScoreKeepVisualStyle.primaryText).bold().italic().frame(alignment: .center)
                            }
                        }
                        Spacer()
                        Text(Date.now.formatted(date: .abbreviated, time: .omitted)).foregroundColor(.white).padding(.trailing,10)
                    }
                    hittingStatsTable
                }
            }
            .onAppear() {
                sumData()
                isLoading = false
            }
            .onChange(of: doShot) { _, newValue in
                if newValue {
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
                    Text("Player Statistics").font(.title2)
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

    @ViewBuilder
    private var hittingStatsTable: some View {
        if UIDevice.type == "iPhone" {
            ScrollView(.horizontal) {
                hittingStatsContent
                    .frame(width: iPhoneTableWidth)
            }
        } else {
            hittingStatsContent
        }
    }

    private var hittingStatsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            hittingStatsHeader
            hittingStatsRows
        }
    }

    private var hittingStatsHeader: some View {
        HStack {
            Text("").frame(maxWidth:5)
            scorebookHeaderCell("Nm", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("Name", semantic: true)
                .frame(width:125)
            scorebookHeaderCell("Bat", semantic: true)
                .frame(maxWidth:.infinity)
            hittingRateHeader("AVG")
                .frame(width: rateColumnWidth)
            hittingRateHeader("OBP")
                .frame(width: rateColumnWidth)
            hittingRateHeader("SLG")
                .frame(width: rateColumnWidth)
            hittingRateHeader("OPS")
                .frame(width: rateColumnWidth)
            scorebookHeaderCell("R", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("H", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("K", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("ꓘ", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("BB", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("HR", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("1B", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("2B", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("3B", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("SB", semantic: true)
                .frame(maxWidth:.infinity)
            scorebookHeaderCell("SF", semantic: true)
                .frame(maxWidth:.infinity)
            Text("").frame(maxWidth:5)
        }
        .frame(height: 34)
    }

    private var hittingStatsRows: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sortedStats) { stats in
                    PlayerStatsRow(stats: stats)
                }
                Spacer()
            }
        }
    }

    private func hittingRateHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ScoreKeepVisualStyle.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(ScoreKeepVisualStyle.elevatedSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
            )
            .padding(2)
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

struct PlayerStatsRow: View {
    let stats: PlayerStats
    private let rateColumnWidth: CGFloat = 42

    var body: some View {
        let atbats = stats.atbats
        let hits = stats.hits
        let walks = stats.BB
        let hbp = stats.hbp
        let sacFly = stats.sacFly
        let singles = stats.single
        let doubles = stats.double
        let triples = stats.triple
        let homers = stats.HR

        let avg: Int
        if atbats == 0 {
            avg = 0
        } else {
            let value = (Double(hits) / Double(atbats)) * 1000.0
            avg = Int(value.rounded(.down))
        }

        let obp: Int
        let obpDenominator = atbats + walks + hbp + sacFly
        if obpDenominator == 0 {
            obp = 0
        } else {
            let numerator = hits + walks + hbp
            let value = (Double(numerator) / Double(obpDenominator)) * 1000.0
            obp = Int(value.rounded(.down))
        }

        let slg: Int
        if atbats == 0 {
            slg = 0
        } else {
            let totalBases = singles + (2 * doubles) + (3 * triples) + (4 * homers)
            let value = (Double(totalBases) / Double(atbats)) * 1000.0
            slg = Int(value.rounded(.down))
        }

        let nameParts = (stats.player?.name ?? "").components(separatedBy: " ")
        let isIPhone = (UIDevice.type == "iPhone")
        let name: String
        if nameParts.count == 0 {
            name = "Unknown"
        } else if nameParts.count == 1 {
            name = nameParts[0]
        } else if isIPhone {
            name = nameParts[1]
        } else {
            name = nameParts[0] + " " + nameParts[1]
        }
        
        return HStack {
            Text("")
                .frame(maxWidth: 5)
            Text(stats.player?.number ?? "")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(name)
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(width: 125, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.atbats)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(Self.battingRateText(avg))
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(width: rateColumnWidth)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(Self.battingRateText(obp))
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(width: rateColumnWidth)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(Self.battingRateText(slg))
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(width: rateColumnWidth)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(Self.battingRateText(obp + slg))
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(width: rateColumnWidth)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.runs)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.hits)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.strikeouts)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.strikeoutl)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.BB)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.HR)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.single)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.double)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.triple)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.sacBunt)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.sacFly)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("")
                .frame(maxWidth: 5)
        }
    }

    private static func battingRateText(_ value: Int) -> String {
        let whole = value / 1000
        let fractional = value % 1000

        if whole == 0 {
            return String(format: ".%03d", fractional)
        }

        return String(format: "%d.%03d", whole, fractional)
    }
}

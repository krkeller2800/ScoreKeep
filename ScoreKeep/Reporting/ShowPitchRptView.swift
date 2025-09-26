//
//  ShowPitchRptView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 7/3/25.
//

import PDFKit
import SwiftUI
import SwiftData

struct ShowPitchRptView: View {
    @Environment(\.modelContext) var modelContext
    @State private var pdfURL: URL?
    @State  var tName = ""
    @State  var alertMessage = ""
    @State  var showingAlert = false
    @Binding  var isLoading:Bool
    @State var sumedStats:[PitchStats] = []
    @State var atbats:[Atbat] = []
    @State var pitchers:[Pitcher] = []
    @State var pagenum = 1
    @State private var thumbnailImage: UIImage?

    var com:Common = Common()

    var body: some View {
        VStack(spacing: 0) {
            PitcherRptView(teamName: tName, isLoading: $isLoading)
            Button("Generate PDF") {
                if let pdfData = generatePDF() {
                    pdfURL = savePDF(data: pdfData, fileName: "pitchStats")
                }
            }
            .padding(0)
            .onAppear() {
                getPitchers()
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
            .padding()
            if let pdfURL = pdfURL {
                ShareLink("Export PDF", item: pdfURL)
            }
        }
    }
    
    func generatePDF() -> Data? {
        let pageWidth: CGFloat = 800
        let pageHeight: CGFloat = 618
        let margin: CGFloat = 50
        let contentWidth = pageWidth - 2 * margin
        let contentHeight = pageHeight - 2 * margin
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        var currentY: CGFloat = margin
        let headAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .paragraphStyle: NSMutableParagraphStyle(),
            .foregroundColor: UIColor.red
        ]
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .paragraphStyle: NSMutableParagraphStyle()
        ]
//        let detailAttributes: [NSAttributedString.Key: Any] = [
//            .font: UIFont.systemFont(ofSize: 10),
//            .paragraphStyle: NSMutableParagraphStyle()
//        ]
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 16),
            .paragraphStyle: NSMutableParagraphStyle()
        ]

        var attributedString = NSAttributedString(string: "", attributes: titleAttributes)
        let data = pdfRenderer.pdfData { context in
            context.beginPage()
            
            let textHeight = NSAttributedString(string: "", attributes: textAttributes).boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height + 5

            doHeader(headAttributes: headAttributes, titleAttributes: titleAttributes, textAttributes: textAttributes, currentY: currentY, contentWidth: contentWidth)
             currentY += 80
            
            sumedStats.sort { $0.pitcher?.player.name ?? "" < $1.pitcher?.player.name ?? "" }
            
            for stats in sumedStats {
                
                if currentY + textHeight > contentHeight + margin {
                    context.beginPage()
                    currentY = margin
                    pagenum += 1
                    doHeader(headAttributes: headAttributes, titleAttributes: titleAttributes, textAttributes: textAttributes, currentY: currentY, contentWidth: contentWidth)
                    currentY += 80
                 }
                attributedString = NSAttributedString(string: String(stats.pitcher?.player.number ?? ""), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 5, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String(stats.pitcher?.player.name ?? ""), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 30, y: currentY, width: 125, height: textHeight))
                
                attributedString = NSAttributedString(string: String(String(format: "%.2f", stats.ERA)), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 160, y: currentY, width: 30, height: textHeight))
                                
                attributedString = NSAttributedString(string: String("\(stats.innings)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 200, y: currentY, width: 30, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.runs)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 230, y: currentY, width: 30, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.uruns)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 260, y: currentY, width: 30, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.hits)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 285, y: currentY, width: 30, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.Ks)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 315, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.Ksl)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 347, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.BB)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 380, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.hbp)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 407, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.HR)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 437, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.singles)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 467, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.doubles)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 497, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.triples)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 527, y: currentY, width: 20, height: textHeight))
                
                currentY += textHeight
            }
        }
        
        return data
    }
    
    func savePDF(data: Data, fileName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentDirectory.appendingPathComponent("\(fileName).pdf")
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving PDF: \(error.localizedDescription)")
            return nil
        }
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
            let hbp = atbats.filter({$0.result == "Hit By Pitch" && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let Ks = atbats.filter({$0.result == "Strikeout" && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
                (10 * (Int($0.inning + 1)) + $0.seq <= (10 * endinn) + pitcher.eBats ||
                 (Int($0.inning) == endinn - 1 && $0.outs == 3))}).count
            let Ksl = atbats.filter({$0.result == "Strikeout Looking" && (10 * (Int($0.inning + 1)) + $0.seq >= (10 * pitcher.startInn) + pitcher.sBats) &&
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
    func getPitchers() {
            
        var fetchDescriptor = FetchDescriptor<Pitcher>(sortBy: [SortDescriptor(\.player.name)])
            
        fetchDescriptor.predicate = #Predicate { $0.team.name == tName }
            
        do {
            pitchers = try self.modelContext.fetch(fetchDescriptor)
  
            } catch {
                print("SwiftData Error getting atbats: \(error)")
            }
    }
    func doHeader (headAttributes: [NSAttributedString.Key : Any], titleAttributes: [NSAttributedString.Key : Any], textAttributes: [NSAttributedString.Key : Any],currentY: CGFloat, contentWidth: CGFloat) {
        
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .paragraphStyle: NSMutableParagraphStyle()
        ]
        let headHeight = NSAttributedString(string: "", attributes: headAttributes).boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height + 5
        let titleHeight = NSAttributedString(string: "", attributes: titleAttributes).boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height + 5
        let topAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .paragraphStyle: NSMutableParagraphStyle()
        ]
        
        var attributedString = NSAttributedString(string: "\(tName) Pitching Stats", attributes: titleAttributes)
        let titleSize: CGSize = "\(tName) Pitching Stats".size(withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
        
        if let imageData = pitchers[0].team.logo, let uiImage = UIImage(data: imageData) {
            let width = 25 * uiImage.size.width / uiImage.size.height
            let thumbnail = uiImage.preparingThumbnail(of: CGSize(width: width, height: 25))
            thumbnail?.draw(at: CGPoint(x: ((800 - titleSize.width) / 2) - (width + 3), y: currentY+25))
        }
        
        let headingSize: CGSize = "Pitching Statistics".size(withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
        attributedString.draw(in: CGRect(x: (800 - titleSize.width) / 2, y: currentY+30, width: contentWidth, height: titleHeight))
        let pNumSize: CGSize = "Page \(pagenum)".size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
        attributedString = NSAttributedString(string: String("Page \(pagenum)"), attributes: detailAttributes)
        attributedString.draw(in: CGRect(x: (800 - pNumSize.width) / 2, y: 575, width: 40, height: headHeight))
        attributedString = NSAttributedString(string: String("Report Created by IOS App ScoreKeep"), attributes: detailAttributes)
        attributedString.draw(in: CGRect(x: 50, y: 575, width: 250, height: headHeight))
        
        attributedString = NSAttributedString(string: "Through", attributes: topAttributes)
        attributedString.draw(in: CGRect(x: 50, y: currentY, width: 35, height: headHeight))
        attributedString = NSAttributedString(string: Date.now.formatted(date: .long, time: .omitted), attributes: topAttributes)
        attributedString.draw(in: CGRect(x: 85, y: currentY, width: 100, height: headHeight))
        attributedString = NSAttributedString(string:"Pitching Statistics", attributes: textAttributes)
        attributedString.draw(in: CGRect(x: (800 - headingSize.width) / 2, y: currentY, width: headingSize.width, height: headHeight))
        
        attributedString = NSAttributedString(string: String("Num"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("Name"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 30, y: currentY + 60, width: 125, height: headHeight))
        
        attributedString = NSAttributedString(string: String(String("ERA")), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 160, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("INN"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 195, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("ER"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 230, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("UER"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 250, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("Hit"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 280, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("Ks"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 310, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("ꓘs"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 340, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("BB"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 375, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("HBP"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 400, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("HR"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 430, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("1B"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 460, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("2B"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 490, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("3B"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 520, y: currentY + 60, width: 20, height: headHeight))
    }
}

//
//  ShowReportView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/16/25.
//

import PDFKit
import SwiftUI
import SwiftData

struct ShowReportView: View {
    @Environment(\.modelContext) var modelContext
    @State private var pdfURL: URL?
    @State var sumedStats:[PlayerStats] = []
    @State var tName:String
    @Binding var isLoading:Bool
    @State var atbats:[Atbat]=[]
    @State var pagenum = 1
    @State private var thumbnailImage: UIImage?

    
    var body: some View {
        VStack {
            ReportView(teamName: tName, isLoading: $isLoading)
            Button("Generate PDF") {
                if let pdfData = generatePDF() {
                    pdfURL = savePDF(data: pdfData, fileName: "Stats")
                }
            }
            .onAppear() {
                getAtBats()
                sumData()
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
            
            sumedStats.sort { $0.player?.batOrder ?? 0 < $1.player?.batOrder ?? 0 }
            
            for stats in sumedStats {
                
                if currentY + textHeight > contentHeight + margin {
                    context.beginPage()
                    currentY = margin
                    pagenum += 1
                    doHeader(headAttributes: headAttributes, titleAttributes: titleAttributes, textAttributes: textAttributes, currentY: currentY, contentWidth: contentWidth)
                    currentY += 80
                 }

                let avg:Int = stats.atbats == 0 ? 0 : Int(Double(1000 * stats.hits / stats.atbats))
                let obp:Int = stats.atbats == 0 ? 0 : Int(Double(1000 * (stats.hits + stats.BB + stats.hbp) /
                                                                 (stats.atbats + stats.BB + stats.hbp + stats.sacFly)))
                let slg:Int = stats.atbats == 0 ? 0 :Int(Double(1000 * (stats.single + (2 * stats.double) + (3 * stats.triple) + (4 * stats.HR)) /
                                                                stats.atbats))
    
                attributedString = NSAttributedString(string: String(stats.player?.number ?? ""), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 5, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String(stats.player?.name ?? ""), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 30, y: currentY, width: 125, height: textHeight))
                
                attributedString = NSAttributedString(string: String(String("\(stats.atbats)")), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 165, y: currentY, width: 30, height: textHeight))
                
                attributedString = NSAttributedString(string: String(String(format: "%03d", avg)), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 190, y: currentY, width: 30, height: textHeight))
                
                attributedString = NSAttributedString(string: String(String(format: "%03d", obp)), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 220, y: currentY, width: 30, height: textHeight))
                
                attributedString = NSAttributedString(string: String(String(format: "%03d", slg)), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 255, y: currentY, width: 30, height: textHeight))
                
                attributedString = NSAttributedString(string: String(String(format: "%03d", obp + slg)), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 290, y: currentY, width: 40, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.runs)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 330, y: currentY, width: 30, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.hits)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 350, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.strikeouts)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 370, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.strikeoutl)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 390, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.BB)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 410, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.HR)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 430, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.single)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 450, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.double)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 470, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.triple)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 490, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.sacBunt)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 510, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.sacFly)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 530, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.hbp)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 555, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.dts)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 585, y: currentY, width: 20, height: textHeight))
                
                attributedString = NSAttributedString(string: String("\(stats.fc)"), attributes: textAttributes)
                attributedString.draw(in: CGRect(x: margin + 615, y: currentY, width: 20, height: textHeight))
                
                currentY += textHeight

 //               attributedString.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: textHeight))
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
    func getAtBats() {
            
        var fetchDescriptor = FetchDescriptor<Atbat>(sortBy: [SortDescriptor(\Atbat.player.name)])
            
        fetchDescriptor.predicate = #Predicate { $0.team.name == tName }
            
        do {
            atbats = try self.modelContext.fetch(fetchDescriptor)
  
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

        var attributedString = NSAttributedString(string: "\(tName) Hitting", attributes: titleAttributes)
        let titleSize: CGSize = "\(tName) Hitting".size(withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
        
        if let imageData = atbats[0].team.logo, let uiImage = UIImage(data: imageData) {
            let width = 25 * uiImage.size.width / uiImage.size.height
            let thumbnail = uiImage.preparingThumbnail(of: CGSize(width: width, height: 25))
            thumbnail?.draw(at: CGPoint(x: ((800 - titleSize.width) / 2) - (width + 3), y: currentY+25))
         }
        
        let headingSize: CGSize = "Player Statistics".size(withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
        attributedString.draw(in: CGRect(x: (800 - titleSize.width) / 2, y: currentY+30, width: contentWidth, height: titleHeight))
        let pNumSize: CGSize = "Page \(pagenum)".size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
        attributedString = NSAttributedString(string: String("Page \(pagenum)"), attributes: detailAttributes)
        attributedString.draw(in: CGRect(x: (800 - pNumSize.width) / 2, y: 575, width: 40, height: headHeight))
        attributedString = NSAttributedString(string: String("Report Created by IOS App ScoreKeep"), attributes: detailAttributes)
        attributedString.draw(in: CGRect(x: 50, y: 575, width: 250, height: headHeight))

        attributedString = NSAttributedString(string: Date.now.formatted(date: .long, time: .omitted), attributes: topAttributes)
        attributedString.draw(in: CGRect(x: 50, y: currentY, width: 100, height: headHeight))
        attributedString = NSAttributedString(string:"Player Statistics", attributes: textAttributes)
        attributedString.draw(in: CGRect(x: (800 - headingSize.width) / 2, y: currentY, width: 100, height: headHeight))

        attributedString = NSAttributedString(string: String("Num"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50, y: currentY + 60, width: 30, height: headHeight))

        attributedString = NSAttributedString(string: String("Name"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 30, y: currentY + 60, width: 125, height: headHeight))
        
        attributedString = NSAttributedString(string: String(String("Bat")), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 160, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("AVG"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 190, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("OBP"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 220, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("SLG"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 255, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("OPS"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 290, y: currentY + 60, width: 40, height: headHeight))
        
        attributedString = NSAttributedString(string: String("Run"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 320, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("Hit"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 345, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("K"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 370, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("ꓘ"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 390, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("BB"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 405, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("HR"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 425, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("1B"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 445, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("2B"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 465, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("3B"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 485, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("SB"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 505, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("SF"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 525, y: currentY + 60, width: 20, height: headHeight))
        
        attributedString = NSAttributedString(string: String("HBP"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 545, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("DTS"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 575, y: currentY + 60, width: 30, height: headHeight))
        
        attributedString = NSAttributedString(string: String("FC"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: 50 + 610, y: currentY + 60, width: 20, height: headHeight))
    }
}

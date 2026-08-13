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

    struct PitchingPDFColumn {
        let identifier: String
        let title: String
        let xOffset: CGFloat
        let width: CGFloat
    }

    private struct PitchingPDFColumnDefinition {
        let identifier: String
        let title: String
        let xOffset: CGFloat
    }

    private static let pitchingPDFTrailingColumnWidth: CGFloat = 20

    private static let pitchingPDFColumnDefinitions: [PitchingPDFColumnDefinition] = [
        PitchingPDFColumnDefinition(identifier: "number", title: "#", xOffset: 0),
        PitchingPDFColumnDefinition(identifier: "name", title: "Name", xOffset: 30),
        PitchingPDFColumnDefinition(identifier: "era", title: "ERA", xOffset: 160),
        PitchingPDFColumnDefinition(identifier: "innings", title: "IP", xOffset: 195),
        PitchingPDFColumnDefinition(identifier: "earnedRuns", title: "ER", xOffset: 230),
        PitchingPDFColumnDefinition(identifier: "unearnedRuns", title: "UER", xOffset: 250),
        PitchingPDFColumnDefinition(identifier: "hits", title: "H", xOffset: 280),
        PitchingPDFColumnDefinition(identifier: "strikeouts", title: "K", xOffset: 310),
        PitchingPDFColumnDefinition(identifier: "lookingStrikeouts", title: "ꓘ", xOffset: 340),
        PitchingPDFColumnDefinition(identifier: "walks", title: "BB", xOffset: 375),
        PitchingPDFColumnDefinition(identifier: "hbp", title: "HBP", xOffset: 400),
        PitchingPDFColumnDefinition(identifier: "homeRuns", title: "HR", xOffset: 430),
        PitchingPDFColumnDefinition(identifier: "singles", title: "1B", xOffset: 460),
        PitchingPDFColumnDefinition(identifier: "doubles", title: "2B", xOffset: 490),
        PitchingPDFColumnDefinition(identifier: "triples", title: "3B", xOffset: 520)
    ]

    static let pitchingPDFColumns: [PitchingPDFColumn] = {
        pitchingPDFColumnDefinitions.enumerated().map { index, column in
            let nextXOffset = pitchingPDFColumnDefinitions.dropFirst(index + 1).first?.xOffset
            let width = (nextXOffset ?? column.xOffset + pitchingPDFTrailingColumnWidth) - column.xOffset

            return PitchingPDFColumn(
                identifier: column.identifier,
                title: column.title,
                xOffset: column.xOffset,
                width: width
            )
        }
    }()

    static var pitchingPDFTableWidth: CGFloat {
        pitchingPDFColumns
            .map { $0.xOffset + $0.width }
            .max() ?? 0
    }

    static func pitchingPDFTableOriginX(margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        margin + max(0, (contentWidth - pitchingPDFTableWidth) / 2)
    }

    static func pitchingPDFCellRect(
        identifier: String,
        tableOriginX: CGFloat,
        currentY: CGFloat,
        height: CGFloat
    ) -> CGRect? {
        guard let column = pitchingPDFColumns.first(where: { $0.identifier == identifier }) else {
            return nil
        }

        return CGRect(
            x: tableOriginX + column.xOffset,
            y: currentY,
            width: column.width,
            height: height
        )
    }

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
            .foregroundColor: UIColor.black
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

        let data = pdfRenderer.pdfData { context in
            context.beginPage()
            
            let textHeight = NSAttributedString(string: "", attributes: textAttributes).boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height + 5

            doHeader(
                headAttributes: headAttributes,
                titleAttributes: titleAttributes,
                textAttributes: textAttributes,
                currentY: currentY,
                margin: margin,
                contentWidth: contentWidth
            )
             currentY += 80
            
            sumedStats.sort { $0.pitcher?.player.name ?? "" < $1.pitcher?.player.name ?? "" }
            
            for stats in sumedStats {
                
                if currentY + textHeight > contentHeight + margin {
                    context.beginPage()
                    currentY = margin
                    pagenum += 1
                    doHeader(
                        headAttributes: headAttributes,
                        titleAttributes: titleAttributes,
                        textAttributes: textAttributes,
                        currentY: currentY,
                        margin: margin,
                        contentWidth: contentWidth
                    )
                    currentY += 80
                 }
                let tableOriginX = Self.pitchingPDFTableOriginX(margin: margin, contentWidth: contentWidth)
                let rowRect = CGRect(
                    x: tableOriginX,
                    y: currentY,
                    width: Self.pitchingPDFTableWidth,
                    height: textHeight
                )
                Self.drawPitchingPDFTableFill(rowRect, fillColor: .white)
                Self.strokePitchingPDFTableLine(
                    from: CGPoint(x: rowRect.minX, y: rowRect.maxY),
                    to: CGPoint(x: rowRect.maxX, y: rowRect.maxY)
                )

                Self.drawPitchingPDFCellText(
                    String(stats.pitcher?.player.number ?? ""),
                    identifier: "number",
                    tableOriginX: tableOriginX,
                    currentY: currentY,
                    height: textHeight,
                    attributes: textAttributes,
                    alignment: .center
                )

                Self.drawPitchingPDFCellText(
                    String(stats.pitcher?.player.name ?? ""),
                    identifier: "name",
                    tableOriginX: tableOriginX,
                    currentY: currentY,
                    height: textHeight,
                    attributes: textAttributes,
                    alignment: .left
                )

                Self.drawPitchingPDFCellText(String(format: "%.2f", stats.ERA), identifier: "era", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText(PitchingInningsCalculator.displayString(fromOuts: stats.pitchingOuts), identifier: "innings", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.runs)", identifier: "earnedRuns", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.uruns)", identifier: "unearnedRuns", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.hits)", identifier: "hits", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.Ks)", identifier: "strikeouts", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.Ksl)", identifier: "lookingStrikeouts", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.BB)", identifier: "walks", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.hbp)", identifier: "hbp", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.HR)", identifier: "homeRuns", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.singles)", identifier: "singles", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.doubles)", identifier: "doubles", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                Self.drawPitchingPDFCellText("\(stats.triples)", identifier: "triples", tableOriginX: tableOriginX, currentY: currentY, height: textHeight, attributes: textAttributes)
                
                currentY += textHeight
            }
        }
        
        return data
    }

    private static func drawPitchingPDFTableFill(_ rect: CGRect, fillColor: UIColor) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.saveGState()
        fillColor.setFill()
        context.fill(rect)
        context.restoreGState()
    }

    private static func strokePitchingPDFTableRect(_ rect: CGRect, lineColor: UIColor = UIColor(white: 0.2, alpha: 1)) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.saveGState()
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(0.6)
        context.stroke(rect)
        context.restoreGState()
    }

    private static func strokePitchingPDFTableLine(from start: CGPoint, to end: CGPoint, lineColor: UIColor = UIColor(white: 0.55, alpha: 1)) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.saveGState()
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(0.4)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
    }

    private static func drawPitchingPDFCellText(
        _ text: String,
        identifier: String,
        tableOriginX: CGFloat,
        currentY: CGFloat,
        height: CGFloat,
        attributes: [NSAttributedString.Key: Any],
        alignment: NSTextAlignment = .center
    ) {
        guard let rect = pitchingPDFCellRect(
            identifier: identifier,
            tableOriginX: tableOriginX,
            currentY: currentY,
            height: height
        ) else {
            return
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byClipping

        var alignedAttributes = attributes
        alignedAttributes[.paragraphStyle] = paragraphStyle

        NSAttributedString(string: text, attributes: alignedAttributes).draw(in: rect)
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
            let pitchingOuts = PitchingInningsCalculator.recordedOuts(for: pitcher)
            let innings = PitchingInningsCalculator.baseballNotation(fromOuts: pitchingOuts)
            let decimalInnings = PitchingInningsCalculator.decimalInnings(fromOuts: pitchingOuts)
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
            
            let ERA = pitchingOuts == 0 ? 0 : CGFloat(runs) / decimalInnings * 9
            return PitchStats(runs: runs, uruns: uruns, hits: hits, HR: HR, Ks: Ks, Ksl: Ksl, BB: BB, singles: singles, doubles: doubles, triples: triples, innings: innings, pitchingOuts: pitchingOuts, hbp: hbp, ERA: ERA)
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
        stats.pitchingOuts += thisStats.pitchingOuts
        stats.innings = PitchingInningsCalculator.baseballNotation(fromOuts: stats.pitchingOuts)
        stats.hbp += thisStats.hbp
        let decimalInnings = PitchingInningsCalculator.decimalInnings(fromOuts: stats.pitchingOuts)
        stats.ERA = stats.pitchingOuts == 0 ? 0.0 : (CGFloat(stats.runs) / decimalInnings) * 9
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
    func doHeader (
        headAttributes: [NSAttributedString.Key : Any],
        titleAttributes: [NSAttributedString.Key : Any],
        textAttributes: [NSAttributedString.Key : Any],
        currentY: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) {
        
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
        let titleSize: CGSize = "\(tName) Pitching Stats".size(withAttributes: [.font: UIFont.italicSystemFont(ofSize: 16)])
        
        var logoWidth: CGFloat = 0
        let spacing: CGFloat = 8
        if let imageData = pitchers.first?.team.logo, let uiImage = UIImage(data: imageData) {
            logoWidth = 25 * uiImage.size.width / uiImage.size.height
        }

        let combinedWidth = (logoWidth > 0 ? logoWidth + spacing : 0) + titleSize.width
        let startX = (800 - combinedWidth) / 2

        if logoWidth > 0, let imageData = pitchers.first?.team.logo, let uiImage = UIImage(data: imageData) {
            let thumbnail = uiImage.preparingThumbnail(of: CGSize(width: logoWidth, height: 25))
            thumbnail?.draw(at: CGPoint(x: startX, y: currentY+25))
        }
        
        let headingSize: CGSize = "Pitching Statistics".size(withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
        let titleX = logoWidth > 0 ? startX + logoWidth + spacing : startX
        attributedString.draw(in: CGRect(x: titleX, y: currentY+30, width: contentWidth - titleX, height: titleHeight))
        let pNumSize: CGSize = "Page \(pagenum)".size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
        attributedString = NSAttributedString(string: String("Page \(pagenum)"), attributes: detailAttributes)
        attributedString.draw(in: CGRect(x: (800 - pNumSize.width) / 2, y: 575, width: 40, height: headHeight))
        
        attributedString = NSAttributedString(string: "Through", attributes: topAttributes)
        attributedString.draw(in: CGRect(x: 50, y: currentY, width: 35, height: headHeight))
        attributedString = NSAttributedString(string: Date.now.formatted(date: .long, time: .omitted), attributes: topAttributes)
        attributedString.draw(in: CGRect(x: 85, y: currentY, width: 100, height: headHeight))
        attributedString = NSAttributedString(string:"Pitching Statistics", attributes: textAttributes)
        attributedString.draw(in: CGRect(x: (800 - headingSize.width) / 2, y: currentY, width: headingSize.width, height: headHeight))
        
        let tableOriginX = Self.pitchingPDFTableOriginX(margin: margin, contentWidth: contentWidth)
        let headerRect = CGRect(x: tableOriginX, y: currentY + 58, width: Self.pitchingPDFTableWidth, height: 19)
        Self.drawPitchingPDFTableFill(headerRect, fillColor: UIColor(white: 0.94, alpha: 1))
        Self.strokePitchingPDFTableRect(headerRect)

        let centerParagraphStyle = NSMutableParagraphStyle()
        centerParagraphStyle.alignment = .center
        var centerHeadAttributes = headAttributes
        centerHeadAttributes[.paragraphStyle] = centerParagraphStyle

        for column in Self.pitchingPDFColumns {
            let dividerX = tableOriginX + column.xOffset
            Self.strokePitchingPDFTableLine(
                from: CGPoint(x: dividerX, y: headerRect.minY),
                to: CGPoint(x: dividerX, y: headerRect.maxY),
                lineColor: UIColor(white: 0.65, alpha: 1)
            )

            attributedString = NSAttributedString(string: column.title, attributes: centerHeadAttributes)
            attributedString.draw(in: CGRect(x: tableOriginX + column.xOffset, y: currentY + 61, width: column.width, height: headHeight))
        }

        Self.strokePitchingPDFTableLine(
            from: CGPoint(x: headerRect.maxX, y: headerRect.minY),
            to: CGPoint(x: headerRect.maxX, y: headerRect.maxY),
            lineColor: UIColor(white: 0.65, alpha: 1)
        )
    }
}

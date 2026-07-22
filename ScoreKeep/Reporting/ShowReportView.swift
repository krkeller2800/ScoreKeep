//
//  ShowReportView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/16/25.
//

import PDFKit
import SwiftUI
import SwiftData

struct AggregateHittingPDFPaginationGeometry {
    let pageWidth: CGFloat = 800
    let pageHeight: CGFloat = 618
    let margin: CGFloat = 50
    let headerHeight: CGFloat = 80
    let playerRowHeight: CGFloat = 18

    var pageSize: CGSize {
        CGSize(width: pageWidth, height: pageHeight)
    }

    var contentWidth: CGFloat {
        pageWidth - (2 * margin)
    }

    var firstRowY: CGFloat {
        margin + headerHeight
    }

    var footerBoundaryY: CGFloat {
        pageHeight - margin
    }

    var usableRowAreaHeight: CGFloat {
        footerBoundaryY - firstRowY
    }

    var rowsPerPage: Int {
        max(1, Int(usableRowAreaHeight / playerRowHeight))
    }

    func pageCount(for rowCount: Int) -> Int {
        guard rowCount > 0 else {
            return 1
        }

        return Int(ceil(Double(rowCount) / Double(rowsPerPage)))
    }

    func rowRanges(for rowCount: Int) -> [Range<Int>] {
        guard rowCount > 0 else {
            return []
        }

        return stride(from: 0, to: rowCount, by: rowsPerPage).map { start in
            start..<min(start + rowsPerPage, rowCount)
        }
    }
}

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
        let orderedStats = Self.finalizedPDFStats(from: sumedStats)

        return Self.renderAggregateHittingPDF(teamName: tName, orderedStats: orderedStats, atbats: atbats)
    }

    static func finalizedPDFStats(from stats: [PlayerStats]) -> [PlayerStats] {
        stats.enumerated()
            .sorted { lhs, rhs in
                let lhsOrder = lhs.element.player?.batOrder ?? 0
                let rhsOrder = rhs.element.player?.batOrder ?? 0

                if lhsOrder == rhsOrder {
                    return lhs.offset < rhs.offset
                }

                return lhsOrder < rhsOrder
            }
            .map(\.element)
    }

    struct AggregateHittingPDFTextFitResult {
        let text: String
        let font: UIFont
        let alignment: NSTextAlignment
        let didTruncate: Bool

        var fontSize: CGFloat {
            font.pointSize
        }

        var attributes: [NSAttributedString.Key: Any] {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment
            paragraphStyle.lineBreakMode = .byClipping

            return [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        }
    }

    struct AggregateHittingPDFHeaderGeometry {
        let logoRect: CGRect?
        let titleRect: CGRect
    }

    static func meaningfulNameComponents(from name: String) -> [String] {
        name.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    static func firstInitialPDFNameFallback(for name: String) -> String? {
        let components = meaningfulNameComponents(from: name)
        guard components.count >= 2, let firstCharacter = components[0].first else {
            return nil
        }

        return ([String(firstCharacter) + "."] + Array(components.dropFirst())).joined(separator: " ")
    }

    static func fittedAggregateHittingPDFText(
        fullText: String,
        fallbackText: String? = nil,
        initialFont: UIFont,
        minimumFontSize: CGFloat,
        constrainedTo rect: CGRect,
        alignment: NSTextAlignment
    ) -> AggregateHittingPDFTextFitResult {
        if aggregateHittingPDFText(fullText, fitsIn: rect, font: initialFont) {
            return AggregateHittingPDFTextFitResult(text: fullText, font: initialFont, alignment: alignment, didTruncate: false)
        }

        let textForScaling: String
        if let fallbackText, aggregateHittingPDFText(fallbackText, fitsIn: rect, font: initialFont) {
            return AggregateHittingPDFTextFitResult(text: fallbackText, font: initialFont, alignment: alignment, didTruncate: false)
        } else {
            textForScaling = fallbackText ?? fullText
        }

        var fontSize = initialFont.pointSize
        while fontSize > minimumFontSize {
            fontSize = max(minimumFontSize, fontSize - 0.25)
            let font = initialFont.withSize(fontSize)
            if aggregateHittingPDFText(textForScaling, fitsIn: rect, font: font) {
                return AggregateHittingPDFTextFitResult(text: textForScaling, font: font, alignment: alignment, didTruncate: false)
            }
        }

        let minimumFont = initialFont.withSize(minimumFontSize)
        let truncatedText = truncatedAggregateHittingPDFText(textForScaling, toFitIn: rect, font: minimumFont)
        return AggregateHittingPDFTextFitResult(text: truncatedText, font: minimumFont, alignment: alignment, didTruncate: truncatedText != textForScaling)
    }

    static func aggregateHittingPDFText(_ text: String, fitsIn rect: CGRect, font: UIFont) -> Bool {
        let size = (text as NSString).size(withAttributes: [.font: font])
        return ceil(size.width) <= rect.width && ceil(size.height) <= rect.height
    }

    static func truncatedAggregateHittingPDFText(_ text: String, toFitIn rect: CGRect, font: UIFont) -> String {
        let ellipsis = "..."
        guard !aggregateHittingPDFText(text, fitsIn: rect, font: font) else {
            return text
        }

        guard aggregateHittingPDFText(ellipsis, fitsIn: rect, font: font) else {
            return ""
        }

        var candidate = text
        while !candidate.isEmpty {
            candidate.removeLast()
            let truncated = candidate + ellipsis
            if aggregateHittingPDFText(truncated, fitsIn: rect, font: font) {
                return truncated
            }
        }

        return ellipsis
    }

    static func aggregateHittingPDFHeaderGeometry(
        geometry: AggregateHittingPDFPaginationGeometry,
        currentY: CGFloat,
        contentWidth: CGFloat,
        titleHeight: CGFloat,
        logoSize: CGSize?
    ) -> AggregateHittingPDFHeaderGeometry {
        let titleLineHeight = UIFont.italicSystemFont(ofSize: 16).lineHeight
        let fullTitleRect = CGRect(
            x: geometry.margin,
            y: currentY + 30,
            width: contentWidth,
            height: max(titleHeight, titleLineHeight)
        )
        guard let logoSize else {
            return AggregateHittingPDFHeaderGeometry(logoRect: nil, titleRect: fullTitleRect)
        }

        let spacing: CGFloat = 8
        let logoWidth = min(max(logoSize.width, 1), fullTitleRect.width)
        let logoHeight = max(logoSize.height, 1)
        let logoRect = CGRect(
            x: geometry.margin,
            y: currentY + 25,
            width: logoWidth,
            height: logoHeight
        )
        let titleX = min(fullTitleRect.maxX, logoRect.maxX + spacing)
        let titleWidth = max(1, fullTitleRect.maxX - titleX)
        let titleRect = CGRect(
            x: titleX,
            y: fullTitleRect.minY,
            width: titleWidth,
            height: fullTitleRect.height
        )

        return AggregateHittingPDFHeaderGeometry(logoRect: logoRect, titleRect: titleRect)
    }

    private static func drawAggregateHittingPDFText(
        _ fitResult: AggregateHittingPDFTextFitResult,
        in rect: CGRect
    ) {
        NSAttributedString(string: fitResult.text, attributes: fitResult.attributes).draw(in: rect)
    }

    static func renderAggregateHittingPDF(teamName: String, orderedStats: [PlayerStats], atbats: [Atbat]) -> Data {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: geometry.pageSize))
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
            let rowRanges = geometry.rowRanges(for: orderedStats.count)
            let rangesToRender = rowRanges.isEmpty ? [0..<0] : rowRanges

            for (pageIndex, rowRange) in rangesToRender.enumerated() {
                context.beginPage()
                let pageNumber = pageIndex + 1
                doHeader(
                    teamName: teamName,
                    atbats: atbats,
                    pageNumber: pageNumber,
                    geometry: geometry,
                    headAttributes: headAttributes,
                    titleAttributes: titleAttributes,
                    textAttributes: textAttributes,
                    currentY: geometry.margin,
                    contentWidth: geometry.contentWidth
                )

                var currentY = geometry.firstRowY

                for stats in orderedStats[rowRange] {
                    let avg:Int = stats.atbats == 0 ? 0 : Int(Double(1000 * stats.hits / stats.atbats))
                    let obp:Int = stats.atbats == 0 ? 0 : Int(Double(1000 * (stats.hits + stats.BB + stats.hbp) /
                                                                     (stats.atbats + stats.BB + stats.hbp + stats.sacFly)))
                    let slg:Int = stats.atbats == 0 ? 0 :Int(Double(1000 * (stats.single + (2 * stats.double) + (3 * stats.triple) + (4 * stats.HR)) /
                                                                    stats.atbats))

                    attributedString = NSAttributedString(string: String(stats.player?.number ?? ""), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 5, y: currentY, width: 20, height: geometry.playerRowHeight))

                    let playerName = String(stats.player?.name ?? "")
                    let playerNameRect = CGRect(x: geometry.margin + 30, y: currentY, width: 125, height: geometry.playerRowHeight)
                    let fittedPlayerName = fittedAggregateHittingPDFText(
                        fullText: playerName,
                        fallbackText: firstInitialPDFNameFallback(for: playerName),
                        initialFont: UIFont.systemFont(ofSize: 12),
                        minimumFontSize: 8,
                        constrainedTo: playerNameRect,
                        alignment: .left
                    )
                    drawAggregateHittingPDFText(fittedPlayerName, in: playerNameRect)

                    attributedString = NSAttributedString(string: String(String("\(stats.atbats)")), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 165, y: currentY, width: 30, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String(String(format: "%03d", avg)), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 190, y: currentY, width: 30, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String(String(format: "%03d", obp)), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 220, y: currentY, width: 30, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String(String(format: "%03d", slg)), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 255, y: currentY, width: 30, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String(String(format: "%03d", obp + slg)), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 290, y: currentY, width: 40, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.runs)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 330, y: currentY, width: 30, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.hits)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 350, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.strikeouts)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 370, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.strikeoutl)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 390, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.BB)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 410, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.HR)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 430, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.single)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 450, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.double)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 470, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.triple)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 490, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.sacBunt)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 510, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.sacFly)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 530, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.hbp)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 555, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.dts)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 585, y: currentY, width: 20, height: geometry.playerRowHeight))

                    attributedString = NSAttributedString(string: String("\(stats.fc)"), attributes: textAttributes)
                    attributedString.draw(in: CGRect(x: geometry.margin + 615, y: currentY, width: 20, height: geometry.playerRowHeight))

                    currentY += geometry.playerRowHeight
                }
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
    static func doHeader (
        teamName: String,
        atbats: [Atbat],
        pageNumber: Int,
        geometry: AggregateHittingPDFPaginationGeometry,
        headAttributes: [NSAttributedString.Key : Any],
        titleAttributes: [NSAttributedString.Key : Any],
        textAttributes: [NSAttributedString.Key : Any],
        currentY: CGFloat,
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

        let logoSize: CGSize?
        if let imageData = atbats.first?.team.logo, let uiImage = UIImage(data: imageData) {
            logoSize = CGSize(width: 25 * uiImage.size.width / uiImage.size.height, height: 25)
        } else {
            logoSize = nil
        }
        let headerGeometry = aggregateHittingPDFHeaderGeometry(
            geometry: geometry,
            currentY: currentY,
            contentWidth: contentWidth,
            titleHeight: titleHeight,
            logoSize: logoSize
        )
        let fittedTitle = fittedAggregateHittingPDFText(
            fullText: "\(teamName) Hitting",
            initialFont: UIFont.italicSystemFont(ofSize: 16),
            minimumFontSize: 8,
            constrainedTo: headerGeometry.titleRect,
            alignment: .center
        )

        if let logoRect = headerGeometry.logoRect,
           let imageData = atbats.first?.team.logo,
           let uiImage = UIImage(data: imageData) {
            let thumbnail = uiImage.preparingThumbnail(of: logoRect.size)
            thumbnail?.draw(at: logoRect.origin)
         }

        let headingSize: CGSize = "Player Statistics".size(withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
        drawAggregateHittingPDFText(fittedTitle, in: headerGeometry.titleRect)
        let pNumSize: CGSize = "Page \(pageNumber)".size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
        var attributedString = NSAttributedString(string: String("Page \(pageNumber)"), attributes: detailAttributes)
        attributedString.draw(in: CGRect(x: (geometry.pageWidth - pNumSize.width) / 2, y: 575, width: 40, height: headHeight))
        attributedString = NSAttributedString(string: String("Report Created by IOS App ScoreKeep"), attributes: detailAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin, y: 575, width: 250, height: headHeight))

        attributedString = NSAttributedString(string: Date.now.formatted(date: .long, time: .omitted), attributes: topAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin, y: currentY, width: 100, height: headHeight))
        attributedString = NSAttributedString(string:"Player Statistics", attributes: textAttributes)
        attributedString.draw(in: CGRect(x: (geometry.pageWidth - headingSize.width) / 2, y: currentY, width: 100, height: headHeight))

        attributedString = NSAttributedString(string: String("Num"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin, y: currentY + 60, width: 30, height: headHeight))

        attributedString = NSAttributedString(string: String("Name"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 30, y: currentY + 60, width: 125, height: headHeight))

        attributedString = NSAttributedString(string: String(String("Bat")), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 160, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("AVG"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 190, y: currentY + 60, width: 30, height: headHeight))

        attributedString = NSAttributedString(string: String("OBP"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 220, y: currentY + 60, width: 30, height: headHeight))

        attributedString = NSAttributedString(string: String("SLG"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 255, y: currentY + 60, width: 30, height: headHeight))

        attributedString = NSAttributedString(string: String("OPS"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 290, y: currentY + 60, width: 40, height: headHeight))

        attributedString = NSAttributedString(string: String("Run"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 320, y: currentY + 60, width: 30, height: headHeight))

        attributedString = NSAttributedString(string: String("Hit"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 345, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("K"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 370, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("ꓘ"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 390, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("BB"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 405, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("HR"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 425, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("1B"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 445, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("2B"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 465, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("3B"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 485, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("SB"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 505, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("SF"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 525, y: currentY + 60, width: 20, height: headHeight))

        attributedString = NSAttributedString(string: String("HBP"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 545, y: currentY + 60, width: 30, height: headHeight))

        attributedString = NSAttributedString(string: String("DTS"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 575, y: currentY + 60, width: 30, height: headHeight))

        attributedString = NSAttributedString(string: String("FC"), attributes: headAttributes)
        attributedString.draw(in: CGRect(x: geometry.margin + 610, y: currentY + 60, width: 20, height: headHeight))
    }
}

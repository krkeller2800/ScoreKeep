import Foundation
import PDFKit
import Testing
import UIKit
@testable import ScoreKeep

@Suite("Task810AggregateHittingPDFTextFittingSuite")
struct Task810AggregateHittingPDFTextFittingSuite {
    @Test("Player names fit using full text, first initial, shrinking, and ellipsis fallbacks")
    func playerNameFittingCasesRenderExpectedPDFText() throws {
        let nameRect = CGRect(x: 0, y: 0, width: 125, height: AggregateHittingPDFPaginationGeometry().playerRowHeight)
        let abbreviatedPreferredName = "Bartholomewlong Christensen"
        let abbreviatedPreferredFit = ShowReportView.fittedAggregateHittingPDFText(
            fullText: abbreviatedPreferredName,
            fallbackText: ShowReportView.firstInitialPDFNameFallback(for: abbreviatedPreferredName),
            initialFont: UIFont.systemFont(ofSize: 12),
            minimumFontSize: 8,
            constrainedTo: nameRect,
            alignment: .left
        )
        let shrinkingName = "Benedict Componentone Cedar"
        let shrinkingFit = ShowReportView.fittedAggregateHittingPDFText(
            fullText: shrinkingName,
            fallbackText: ShowReportView.firstInitialPDFNameFallback(for: shrinkingName),
            initialFont: UIFont.systemFont(ofSize: 12),
            minimumFontSize: 8,
            constrainedTo: nameRect,
            alignment: .left
        )
        let stats = [
            makeStat(name: "Abe Short", number: "1", batOrder: 1),
            makeStat(name: abbreviatedPreferredName, number: "2", batOrder: 2),
            makeStat(name: "Alexandertoken Carlos De La Cruz", number: "3", batOrder: 3),
            makeStat(name: "Solopreservedtoken", number: "4", batOrder: 4),
            makeStat(name: shrinkingName, number: "5", batOrder: 5),
            makeStat(name: "Extreme Componentone Componenttwo Componentthree Componentfour Componentfive Componentsix", number: "6", batOrder: 6)
        ]
        let document = try renderDocument(teamName: "FitNames", stats: stats)
        let text = normalizedExtractedText(from: document)

        #expect(document.pageCount == 1)
        #expect(abbreviatedPreferredFit.text == "B. Christensen")
        #expect(abbreviatedPreferredFit.fontSize == 12)
        #expect(!abbreviatedPreferredFit.didTruncate)
        #expect(shrinkingFit.text == "B. Componentone Cedar")
        #expect(shrinkingFit.fontSize < 12)
        #expect(shrinkingFit.fontSize >= 8)
        #expect(!shrinkingFit.didTruncate)
        #expect(occurrences(of: "Abe Short", in: text).count == 1)
        #expect(occurrences(of: "B. Christensen", in: text).count == 1)
        #expect(!text.contains("Bartholomewlong"))
        #expect(occurrences(of: "A. Carlos De La Cruz", in: text).count == 1)
        #expect(!text.contains("Alexandertoken"))
        #expect(occurrences(of: "Solopreservedtoken", in: text).count == 1)
        #expect(!text.contains("S."))
        #expect(occurrences(of: "B. Componentone Cedar", in: text).count == 1)
        #expect(!text.contains("Benedict"))
        #expect(text.contains("E. Componentone"))
        #expect(text.contains("..."))
        #expect(!text.contains("Componentfive"))
        #expect(!text.contains("Componentsix"))

        assertTokensAppearInOrder(
            [
                "Abe Short",
                "B. Christensen",
                "A. Carlos De La Cruz",
                "Solopreservedtoken",
                "B. Componentone Cedar",
                "E. Componentone"
            ],
            in: text
        )
    }

    @Test("Player fitting reports direct font reduction and truncation decisions")
    func playerFittingReportsFontReductionAndTruncation() {
        let nameRect = CGRect(x: 0, y: 0, width: 125, height: AggregateHittingPDFPaginationGeometry().playerRowHeight)
        let shrinkingName = "Benedict Componentone Cedar"
        let shrinkingFit = ShowReportView.fittedAggregateHittingPDFText(
            fullText: shrinkingName,
            fallbackText: ShowReportView.firstInitialPDFNameFallback(for: shrinkingName),
            initialFont: UIFont.systemFont(ofSize: 12),
            minimumFontSize: 8,
            constrainedTo: nameRect,
            alignment: .left
        )
        let truncatingFit = ShowReportView.fittedAggregateHittingPDFText(
            fullText: "Extreme Componentone Componenttwo Componentthree Componentfour Componentfive Componentsix",
            fallbackText: ShowReportView.firstInitialPDFNameFallback(for: "Extreme Componentone Componenttwo Componentthree Componentfour Componentfive Componentsix"),
            initialFont: UIFont.systemFont(ofSize: 12),
            minimumFontSize: 8,
            constrainedTo: nameRect,
            alignment: .left
        )

        #expect(shrinkingFit.text == "B. Componentone Cedar")
        #expect(shrinkingFit.fontSize < 12)
        #expect(shrinkingFit.fontSize >= 8)
        #expect(!shrinkingFit.didTruncate)
        #expect(truncatingFit.text.hasPrefix("E. Componentone"))
        #expect(truncatingFit.text.hasSuffix("..."))
        #expect(truncatingFit.fontSize == 8)
        #expect(truncatingFit.didTruncate)
    }

    @Test("Title fitting preserves headers, rows, pagination, and deterministic text")
    func titleFittingPreservesRenderedPDFStructure() throws {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let stats = makeStats(count: geometry.rowsPerPage + 1)
        let shortDocument = try renderDocument(teamName: "FitTitle", stats: stats)
        let longDocument = try renderDocument(teamName: "FITLONGTITLE North Valley International Tournament Select Baseball Association", stats: stats)
        let extremeDocument = try renderDocument(teamName: "FITEXTREME " + String(repeating: "Championship ", count: 40), stats: stats)
        let repeatedExtremeDocument = try renderDocument(teamName: "FITEXTREME " + String(repeating: "Championship ", count: 40), stats: stats)
        let shortText = normalizedExtractedText(from: shortDocument)
        let longText = normalizedExtractedText(from: longDocument)
        let extremeText = normalizedExtractedText(from: extremeDocument)
        let repeatedExtremeText = normalizedExtractedText(from: repeatedExtremeDocument)

        #expect(shortDocument.pageCount == geometry.pageCount(for: stats.count))
        #expect(longDocument.pageCount == geometry.pageCount(for: stats.count))
        #expect(extremeDocument.pageCount == geometry.pageCount(for: stats.count))
        #expect(repeatedExtremeDocument.pageCount == extremeDocument.pageCount)
        #expect(repeatedExtremeText == extremeText)
        #expect(occurrences(of: "FitTitle Hitting", in: shortText).count == shortDocument.pageCount)
        #expect(occurrences(of: "FITLONGTITLE", in: longText).count == longDocument.pageCount)
        #expect(occurrences(of: "FITEXTREME", in: extremeText).count == extremeDocument.pageCount)
        #expect(extremeText.contains("..."))

        for pageNumber in 1...extremeDocument.pageCount {
            #expect(extremeText.contains("Page \(pageNumber)"))
        }

        let firstToken = "ROW001TOKEN"
        let boundaryToken = String(format: "ROW%03dTOKEN", geometry.rowsPerPage)
        let afterBoundaryToken = String(format: "ROW%03dTOKEN", geometry.rowsPerPage + 1)
        #expect(occurrences(of: firstToken, in: extremeText).count == 1)
        #expect(occurrences(of: boundaryToken, in: extremeText).count == 1)
        #expect(occurrences(of: afterBoundaryToken, in: extremeText).count == 1)
        #expect(occurrences(of: stats.last?.player?.name ?? "", in: extremeText).count == 1)
        assertTokensAppearInOrder([firstToken, boundaryToken, afterBoundaryToken], in: extremeText)
    }

    @Test("Header geometry reserves logo space before fitting long title")
    func headerGeometryReservesLogoSpaceForTitle() throws {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let titleHeight = UIFont.italicSystemFont(ofSize: 16).lineHeight
        let logoSize = CGSize(width: 50, height: 25)
        let logoHeader = ShowReportView.aggregateHittingPDFHeaderGeometry(
            geometry: geometry,
            currentY: geometry.margin,
            contentWidth: geometry.contentWidth,
            titleHeight: titleHeight,
            logoSize: logoSize
        )
        let noLogoHeader = ShowReportView.aggregateHittingPDFHeaderGeometry(
            geometry: geometry,
            currentY: geometry.margin,
            contentWidth: geometry.contentWidth,
            titleHeight: titleHeight,
            logoSize: nil
        )
        let logoRect = try #require(logoHeader.logoRect)

        #expect(logoRect.minX >= geometry.margin)
        #expect(logoRect.maxX <= geometry.pageWidth - geometry.margin)
        #expect(logoHeader.titleRect.minX >= geometry.margin)
        #expect(logoHeader.titleRect.maxX <= geometry.pageWidth - geometry.margin)
        #expect(logoHeader.titleRect.width > 0)
        #expect(!logoRect.intersects(logoHeader.titleRect))
        #expect(noLogoHeader.logoRect == nil)
        #expect(noLogoHeader.titleRect.minX == geometry.margin)
        #expect(noLogoHeader.titleRect.width == geometry.contentWidth)
    }

    @Test("Logo and long title render deterministically without losing rows")
    func logoAndLongTitleRenderPreservesRowsAndHeaders() throws {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let stats = [
            makeStat(name: "LOGOROW001TOKEN", number: "1", batOrder: 1),
            makeStat(name: "LOGOROW002TOKEN", number: "2", batOrder: 2)
        ]
        let logoData = try #require(makeLogoData())
        let atbats = [makeAtbat(teamName: "LogoTeam", logoData: logoData, player: try #require(stats.first?.player))]
        let teamName = "LOGOTITLE " + String(repeating: "Tournament ", count: 18)
        let firstDocument = try renderDocument(teamName: teamName, stats: stats, atbats: atbats)
        let secondDocument = try renderDocument(teamName: teamName, stats: stats, atbats: atbats)
        let firstText = normalizedExtractedText(from: firstDocument)
        let secondText = normalizedExtractedText(from: secondDocument)

        #expect(!logoData.isEmpty)
        #expect(atbats.first?.team.logo == logoData)
        #expect(firstDocument.pageCount == geometry.pageCount(for: stats.count))
        #expect(secondDocument.pageCount == firstDocument.pageCount)
        #expect(secondText == firstText)
        #expect(occurrences(of: "LOGOTITLE", in: firstText).count == firstDocument.pageCount)
        #expect(occurrences(of: "LOGOROW001TOKEN", in: firstText).count == 1)
        #expect(occurrences(of: "LOGOROW002TOKEN", in: firstText).count == 1)
        assertTokensAppearInOrder(["LOGOROW001TOKEN", "LOGOROW002TOKEN"], in: firstText)
    }

    @Test("Title fitting reports direct font reduction and truncation decisions")
    func titleFittingReportsFontReductionAndTruncation() {
        let shrinkingRect = CGRect(x: 50, y: 80, width: 360, height: UIFont.italicSystemFont(ofSize: 16).lineHeight)
        let truncatingRect = CGRect(x: 50, y: 80, width: 180, height: UIFont.italicSystemFont(ofSize: 16).lineHeight)
        let shrinkingFit = ShowReportView.fittedAggregateHittingPDFText(
            fullText: "FITLONGTITLE North Valley International Tournament Select Baseball Association Hitting",
            initialFont: UIFont.italicSystemFont(ofSize: 16),
            minimumFontSize: 8,
            constrainedTo: shrinkingRect,
            alignment: .center
        )
        let truncatingFit = ShowReportView.fittedAggregateHittingPDFText(
            fullText: "FITEXTREME " + String(repeating: "Championship ", count: 40) + "Hitting",
            initialFont: UIFont.italicSystemFont(ofSize: 16),
            minimumFontSize: 8,
            constrainedTo: truncatingRect,
            alignment: .center
        )

        #expect(shrinkingFit.text.contains("FITLONGTITLE"))
        #expect(shrinkingFit.fontSize < 16)
        #expect(shrinkingFit.fontSize >= 8)
        #expect(!shrinkingFit.didTruncate)
        #expect(truncatingFit.text.hasPrefix("FITEXTREME"))
        #expect(truncatingFit.text.hasSuffix("..."))
        #expect(truncatingFit.fontSize == 8)
        #expect(truncatingFit.didTruncate)
    }

    @Test("Header, footer, and label fitting uses actual one-line font heights")
    func supplementalHeaderFooterAndLabelFittingUsesLineHeights() {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let dateFont = UIFont.systemFont(ofSize: 8)
        let headingFont = UIFont.systemFont(ofSize: 12)
        let footerFont = UIFont.systemFont(ofSize: 10)
        let labelFont = UIFont.systemFont(ofSize: 12)

        let dateRect = ShowReportView.aggregateHittingPDFLineRect(
            x: geometry.margin,
            y: geometry.margin,
            width: 100,
            font: dateFont
        )
        let headingRect = ShowReportView.aggregateHittingPDFLineRect(
            x: geometry.margin,
            y: geometry.margin,
            width: geometry.contentWidth,
            font: headingFont
        )
        let footerRect = ShowReportView.aggregateHittingPDFLineRect(
            x: geometry.margin,
            y: 575,
            width: 250,
            font: footerFont
        )
        let pageNumberRect = ShowReportView.aggregateHittingPDFLineRect(
            x: geometry.margin,
            y: 575,
            width: geometry.contentWidth,
            font: footerFont
        )

        #expect(dateRect.height == ceil(dateFont.lineHeight))
        #expect(headingRect.height == ceil(headingFont.lineHeight))
        #expect(footerRect.height == ceil(footerFont.lineHeight))
        #expect(pageNumberRect.height == ceil(footerFont.lineHeight))

        let fittedLongDate = ShowReportView.fittedAggregateHittingPDFSingleLine(
            "Wednesday, September 30, 2026",
            initialFont: dateFont,
            rect: dateRect,
            alignment: .left
        )
        #expect(fittedLongDate.fontSize >= 8)
        #expect(ShowReportView.aggregateHittingPDFText(fittedLongDate.text, fitsIn: dateRect, font: fittedLongDate.font))

        let fittedHeading = ShowReportView.fittedAggregateHittingPDFSingleLine(
            "Player Statistics",
            initialFont: headingFont,
            rect: headingRect,
            alignment: .center
        )
        #expect(fittedHeading.text == "Player Statistics")
        #expect(fittedHeading.fontSize == 12)
        #expect(!fittedHeading.didTruncate)

        let fittedFooter = ShowReportView.fittedAggregateHittingPDFSingleLine(
            "Report Created by IOS App ScoreKeep",
            initialFont: footerFont,
            rect: footerRect,
            alignment: .left
        )
        #expect(fittedFooter.text == "Report Created by IOS App ScoreKeep")
        #expect(fittedFooter.fontSize == 10)
        #expect(!fittedFooter.didTruncate)

        for pageNumberText in ["Page 1", "Page 12", "Page 100"] {
            let fittedPageNumber = ShowReportView.fittedAggregateHittingPDFSingleLine(
                pageNumberText,
                initialFont: footerFont,
                rect: pageNumberRect,
                alignment: .center
            )
            #expect(fittedPageNumber.text == pageNumberText)
            #expect(fittedPageNumber.fontSize == 10)
            #expect(!fittedPageNumber.didTruncate)
        }

        for label in ShowReportView.aggregateHittingPDFColumnLabels {
            let rect = ShowReportView.aggregateHittingPDFLineRect(
                x: geometry.margin + label.xOffset,
                y: geometry.margin + 60,
                width: label.width,
                font: labelFont
            )
            let fittedLabel = ShowReportView.fittedAggregateHittingPDFSingleLine(
                label.text,
                initialFont: labelFont,
                rect: rect,
                alignment: .left,
                foregroundColor: .red
            )

            #expect(fittedLabel.text == label.text)
            #expect(fittedLabel.fontSize >= 8)
            #expect(!fittedLabel.didTruncate)
            #expect(ShowReportView.aggregateHittingPDFText(fittedLabel.text, fitsIn: rect, font: fittedLabel.font))
            #expect(fittedLabel.attributes[.foregroundColor] as? UIColor == .red)
        }
    }

    @Test("Rendered PDF preserves supplemental header footer labels and page number text")
    func renderedPDFPreservesSupplementalHeaderFooterLabelsAndPageNumberText() throws {
        let document = try renderDocument(
            teamName: "SupplementalFit",
            stats: [makeStat(name: "SUPPLEMENTALROW", number: "1", batOrder: 1)]
        )
        let text = normalizedExtractedText(from: document)

        #expect(text.contains(Date.now.formatted(date: .long, time: .omitted)))
        #expect(text.contains("Player Statistics"))
        #expect(text.contains("Report Created by IOS App ScoreKeep"))
        #expect(text.contains("Page 1"))

        for label in ShowReportView.aggregateHittingPDFColumnLabels {
            #expect(text.contains(label.text))
        }
    }

    private func renderDocument(teamName: String, stats: [PlayerStats], atbats: [Atbat] = []) throws -> PDFDocument {
        let data = ShowReportView.renderAggregateHittingPDF(
            teamName: teamName,
            orderedStats: stats,
            atbats: atbats
        )

        return try #require(PDFDocument(data: data))
    }

    private func normalizedExtractedText(from document: PDFDocument) -> String {
        var pageTexts = [String]()

        for pageIndex in 0..<document.pageCount {
            pageTexts.append(document.page(at: pageIndex)?.string ?? "")
        }

        return pageTexts
            .joined(separator: "\n")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func makeStats(count: Int) -> [PlayerStats] {
        guard count > 0 else {
            return []
        }

        return (1...count).map { index in
            makeStat(
                name: String(format: "ROW%03dTOKEN", index),
                number: "\(index)",
                batOrder: index
            )
        }
    }

    private func makeStat(name: String, number: String, batOrder: Int) -> PlayerStats {
        let player = Player(
            name: name,
            number: number,
            position: "P",
            batDir: "R",
            batOrder: batOrder
        )

        return PlayerStats(
            player: player,
            atbats: 3,
            runs: batOrder % 5,
            hits: 1,
            strikeouts: batOrder % 2,
            strikeoutl: 0,
            HR: 0,
            single: 1,
            double: 0,
            triple: 0,
            BB: 0,
            sacBunt: 0,
            sacFly: 0,
            hbp: 0,
            dts: 0,
            fc: 0
        )
    }

    private func makeAtbat(teamName: String, logoData: Data, player: Player) -> Atbat {
        let team = Team(name: teamName, coach: "Coach", details: "Details", logo: logoData)
        let game = Game(date: "2026-07-21", location: "Field", highLights: "", hscore: 0, vscore: 0, hteam: team)

        return Atbat(
            game: game,
            team: team,
            player: player,
            result: "Single",
            maxbase: "First",
            batOrder: player.batOrder,
            outAt: "",
            inning: 1,
            seq: 1,
            col: 1,
            rbis: 0,
            outs: 0,
            sacFly: 0,
            sacBunt: 0,
            stolenBases: 0
        )
    }

    private func makeLogoData() -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10))
        return renderer.image { context in
            UIColor.red.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
        }.pngData()
    }

    private func occurrences(of token: String, in text: String) -> [String.Index] {
        guard !token.isEmpty else {
            return []
        }

        var matches = [String.Index]()
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(of: token, range: searchStart..<text.endIndex) {
            matches.append(range.lowerBound)
            searchStart = range.upperBound
        }

        return matches
    }

    private func assertTokensAppearInOrder(_ tokens: [String], in text: String) {
        var previousOffset: String.Index?

        for token in tokens {
            let matches = occurrences(of: token, in: text)
            #expect(matches.count == 1, "\(token) should appear exactly once")

            if let currentOffset = matches.first {
                if let previousOffset {
                    #expect(previousOffset < currentOffset, "\(token) should preserve player ordering")
                }
                previousOffset = currentOffset
            }
        }
    }
}

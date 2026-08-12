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
        let titleText = "Logo Geometry Hitting"
        let logoSize = CGSize(width: 50, height: 25)
        let logoHeader = ShowReportView.aggregateHittingPDFHeaderGeometry(
            titleText: titleText,
            geometry: geometry,
            currentY: geometry.margin,
            contentWidth: geometry.contentWidth,
            logoSize: logoSize
        )
        let noLogoHeader = ShowReportView.aggregateHittingPDFHeaderGeometry(
            titleText: titleText,
            geometry: geometry,
            currentY: geometry.margin,
            contentWidth: geometry.contentWidth,
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
        #expect(shrinkingFit.didTruncate)
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
        let pageNumberRect = ShowReportView.aggregateHittingPDFLineRect(
            x: geometry.margin,
            y: 575,
            width: geometry.contentWidth,
            font: footerFont
        )

        #expect(dateRect.height == ceil(dateFont.lineHeight))
        #expect(headingRect.height == ceil(headingFont.lineHeight))
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
                alignment: .center,
                foregroundColor: .red
            )

            #expect(fittedLabel.text == label.text)
            #expect(fittedLabel.fontSize >= 8)
            #expect(!fittedLabel.didTruncate)
            #expect(ShowReportView.aggregateHittingPDFText(fittedLabel.text, fitsIn: rect, font: fittedLabel.font))
            #expect(fittedLabel.attributes[.foregroundColor] as? UIColor == .red)
        }
    }

    @Test("Rendered PDF preserves supplemental header labels and page number text")
    func renderedPDFPreservesSupplementalHeaderLabelsAndPageNumberText() throws {
        let document = try renderDocument(
            teamName: "SupplementalFit",
            stats: [makeStat(name: "SUPPLEMENTALROW", number: "1", batOrder: 1)]
        )
        let text = normalizedExtractedText(from: document)

        #expect(text.contains(Date.now.formatted(date: .long, time: .omitted)))
        #expect(text.contains("Player Statistics"))
        #expect(text.contains("Page 1"))

        for label in ShowReportView.aggregateHittingPDFColumnLabels {
            #expect(text.contains(label.text))
        }
    }

    @Test("Numeric fitting preserves complete values across shared cell widths")
    func numericFittingPreservesCompleteValuesAcrossSharedCellWidths() throws {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let rowY = geometry.firstRowY
        let rect25 = try #require(ShowReportView.aggregateHittingPDFNumericCellRect(identifier: "hits", geometry: geometry, currentY: rowY))
        let rect30 = try #require(ShowReportView.aggregateHittingPDFNumericCellRect(identifier: "atbats", geometry: geometry, currentY: rowY))
        let rect35 = try #require(ShowReportView.aggregateHittingPDFNumericCellRect(identifier: "dts", geometry: geometry, currentY: rowY))
        let opsRect = try #require(ShowReportView.aggregateHittingPDFNumericCellRect(identifier: "ops", geometry: geometry, currentY: rowY))

        let short25 = ShowReportView.fittedAggregateHittingPDFNumericText("7", constrainedTo: rect25)
        #expect(short25.originalText == "7")
        #expect(short25.selectedText == "7")
        #expect(short25.fontSize == 12)
        #expect(short25.fitsCompletely)
        #expect(!short25.reachedMinimumFontSize)

        let fitting25 = ShowReportView.fittedAggregateHittingPDFNumericText("888", constrainedTo: rect25)
        #expect(fitting25.selectedText == "888")
        #expect(fitting25.fontSize == 12)
        #expect(fitting25.fitsCompletely)
        #expect(!fitting25.selectedText.contains("..."))

        let shrinking30 = ShowReportView.fittedAggregateHittingPDFNumericText("88888", constrainedTo: rect30)
        #expect(shrinking30.selectedText == "88888")
        #expect(shrinking30.fontSize < 12)
        #expect(shrinking30.fontSize >= 8)
        #expect(shrinking30.fitsCompletely)
        #expect(!shrinking30.selectedText.contains("..."))

        let shrinking35 = ShowReportView.fittedAggregateHittingPDFNumericText("888888", constrainedTo: rect35)
        let repeatedShrinking35 = ShowReportView.fittedAggregateHittingPDFNumericText("888888", constrainedTo: rect35)
        #expect(shrinking35.selectedText == "888888")
        #expect(shrinking35.fontSize < 12)
        #expect(shrinking35.fontSize >= 8)
        #expect(shrinking35.fitsCompletely)
        #expect(!shrinking35.selectedText.contains("..."))
        #expect(repeatedShrinking35.selectedText == shrinking35.selectedText)
        #expect(repeatedShrinking35.fontSize == shrinking35.fontSize)
        #expect(repeatedShrinking35.fitsCompletely == shrinking35.fitsCompletely)

        for (text, rect) in [("888", rect25), ("8888", rect30), ("8888", rect35), ("6.000", opsRect)] {
            let fit = ShowReportView.fittedAggregateHittingPDFNumericText(text, constrainedTo: rect)
            #expect(fit.selectedText == text)
            #expect(fit.fontSize >= 8)
            #expect(fit.fitsCompletely)
            #expect(!fit.selectedText.contains("..."))
        }

        let negative25 = ShowReportView.fittedAggregateHittingPDFNumericText("-88", constrainedTo: rect25)
        #expect(negative25.selectedText == "-88")
        #expect(negative25.selectedText.hasPrefix("-"))
        #expect(negative25.fitsCompletely)

        let opsAbove999 = ShowReportView.fittedAggregateHittingPDFNumericText("5.000", constrainedTo: opsRect)
        #expect(opsAbove999.selectedText == "5.000")
        #expect(opsAbove999.fitsCompletely)
        #expect(!opsAbove999.selectedText.contains("..."))
    }

    @Test("Unfittable numeric value reports non-fit without truncation")
    func unfittableNumericValueReportsNonFitWithoutTruncation() throws {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let rect = try #require(ShowReportView.aggregateHittingPDFNumericCellRect(identifier: "hits", geometry: geometry, currentY: geometry.firstRowY))
        let extremeText = "12345678901234567890"
        let fit = ShowReportView.fittedAggregateHittingPDFNumericText(extremeText, constrainedTo: rect)

        #expect(fit.originalText == extremeText)
        #expect(fit.selectedText == extremeText)
        #expect(fit.fontSize == 8)
        #expect(fit.reachedMinimumFontSize)
        #expect(!fit.fitsCompletely)
        #expect(!fit.selectedText.contains("..."))
    }

    @Test("Numeric fitting uses shared header cell geometry")
    func numericFittingUsesSharedHeaderCellGeometry() throws {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let rowY = geometry.firstRowY
        let expectedCells: [(String, CGFloat, CGFloat)] = [
            ("number", 50, 30),
            ("name", 80, 130),
            ("atbats", 210, 30),
            ("avg", 240, 30),
            ("obp", 270, 35),
            ("slg", 305, 35),
            ("ops", 340, 30),
            ("runs", 370, 25),
            ("hits", 395, 25),
            ("strikeouts", 420, 20),
            ("lookingStrikeouts", 440, 15),
            ("walks", 455, 20),
            ("homeRuns", 475, 20),
            ("singles", 495, 20),
            ("doubles", 515, 20),
            ("triples", 535, 20),
            ("sbColumnValue", 555, 20),
            ("sacrificeFlies", 575, 20),
            ("hbp", 595, 30),
            ("dts", 625, 35),
            ("fc", 660, 20)
        ]

        for (identifier, expectedX, expectedWidth) in expectedCells {
            let rect = try #require(ShowReportView.aggregateHittingPDFNumericCellRect(identifier: identifier, geometry: geometry, currentY: rowY))
            let fit = ShowReportView.fittedAggregateHittingPDFNumericText("8888", constrainedTo: rect)
            let column = try #require(ShowReportView.aggregateHittingPDFColumnLabels.first { $0.identifier == identifier })

            #expect(rect.minX == expectedX)
            #expect(rect.minY == rowY)
            #expect(rect.width == expectedWidth)
            #expect(rect.height == geometry.playerRowHeight)
            #expect(rect.minX == geometry.margin + column.xOffset)
            #expect(rect.width == column.width)
            #expect(fit.attributes[.foregroundColor] == nil)
        }

        #expect(ShowReportView.aggregateHittingPDFColumnLabels.map(\.text) == [
            "#", "Name", "AB", "AVG", "OBP", "SLG", "OPS", "R", "H", "K", "ꓘ", "BB", "HR", "1B", "2B", "3B", "SH", "SF", "HBP", "DTS", "FC"
        ])
    }

    @Test("Rendered PDF preserves complete distinctive numeric values")
    func renderedPDFPreservesCompleteDistinctiveNumericValues() throws {
        let stats = [
            makeStat(
                name: "NUMERICROWONE",
                number: "7",
                batOrder: 1,
                atbats: 1234,
                runs: 8,
                hits: 123
            ),
            makeStat(
                name: "NUMERICROWTWO",
                number: "22",
                batOrder: 2,
                atbats: 1,
                runs: -12,
                hits: 1,
                HR: 1
            )
        ]
        let document = try renderDocument(teamName: "NumericFit", stats: stats)
        let text = normalizedExtractedText(from: document)

        #expect(text.contains("123"))
        #expect(text.contains("1234"))
        #expect(text.contains("6.000"))
        #expect(text.contains("-12"))
        #expect(text.contains("7"))
        #expect(!text.contains("..."))
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

    private func makeStat(
        name: String,
        number: String,
        batOrder: Int,
        atbats: Int = 3,
        runs: Int = 0,
        hits: Int = 1,
        strikeouts: Int? = nil,
        strikeoutl: Int = 0,
        HR: Int = 0,
        single: Int = 1,
        double: Int = 0,
        triple: Int = 0,
        BB: Int = 0,
        sacBunt: Int = 0,
        sacFly: Int = 0,
        hbp: Int = 0,
        dts: Int = 0,
        fc: Int = 0
    ) -> PlayerStats {
        let player = Player(
            name: name,
            number: number,
            position: "P",
            batDir: "R",
            batOrder: batOrder
        )

        return PlayerStats(
            player: player,
            atbats: atbats,
            runs: runs == 0 ? batOrder % 5 : runs,
            hits: hits,
            strikeouts: strikeouts ?? batOrder % 2,
            strikeoutl: strikeoutl,
            HR: HR,
            single: single,
            double: double,
            triple: triple,
            BB: BB,
            sacBunt: sacBunt,
            sacFly: sacFly,
            hbp: hbp,
            dts: dts,
            fc: fc
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

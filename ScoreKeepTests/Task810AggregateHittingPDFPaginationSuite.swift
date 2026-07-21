import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import ScoreKeep

@Suite("Task810AggregateHittingPDFPaginationSuite")
struct Task810AggregateHittingPDFPaginationSuite {
    @Test("Geometry page counts and row ranges preserve every row index once")
    func geometryPageCountsAndRowRanges() {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let rowsPerPage = geometry.rowsPerPage
        let rowCounts = [
            0,
            1,
            rowsPerPage,
            rowsPerPage + 1,
            rowsPerPage * 2,
            (rowsPerPage * 2) + 1,
            (rowsPerPage * 4) + 7
        ]

        for rowCount in rowCounts {
            let ranges = geometry.rowRanges(for: rowCount)
            let flattened = ranges.flatMap { Array($0) }
            let expectedPageCount = rowCount == 0 ? 1 : ((rowCount - 1) / rowsPerPage) + 1

            #expect(geometry.pageCount(for: rowCount) == expectedPageCount)
            #expect(rowCount == 0 ? ranges.isEmpty : ranges.count == expectedPageCount)
            #expect(flattened == Array(0..<rowCount))
            #expect(Set(flattened).count == flattened.count)
            #expect(ranges.allSatisfy { $0.count <= rowsPerPage })
            #expect(ranges.allSatisfy { $0.lowerBound < $0.upperBound })
        }
    }

    @Test("Rendered PDFs produce expected pages and preserve row text once")
    func renderedPDFPageCountsAndRowTextPreservation() throws {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let cases = [
            geometry.rowsPerPage,
            geometry.rowsPerPage + 1,
            (geometry.rowsPerPage * 3) + 5
        ]

        for rowCount in cases {
            let stats = makeStats(count: rowCount)
            let tokens = stats.map { $0.player?.name ?? "" }
            let document = try renderDocument(stats: stats)
            let combinedText = try extractedText(from: document)

            #expect(document.pageCount == geometry.pageCount(for: rowCount))
            #expect(tokens.first.map { combinedText.contains($0) } == true)
            #expect(tokens.last.map { combinedText.contains($0) } == true)

            var previousOffset: String.Index?
            for token in tokens {
                let occurrences = occurrences(of: token, in: combinedText)
                #expect(occurrences.count == 1, "\(token) should appear exactly once")

                if let currentOffset = occurrences.first {
                    if let previousOffset {
                        #expect(previousOffset < currentOffset, "\(token) should preserve source order")
                    }
                    previousOffset = currentOffset
                }
            }
        }
    }

    @Test("Finalized PDF stats use batting order and preserve source order for ties")
    func finalizedStatsUseStableBattingOrder() {
        let firstTie = makeStat(token: "SKPTIEA", batOrder: 2, index: 0)
        let earliestOrder = makeStat(token: "SKPORD1", batOrder: 1, index: 1)
        let secondTie = makeStat(token: "SKPTIEB", batOrder: 2, index: 2)
        let latestOrder = makeStat(token: "SKPORD3", batOrder: 3, index: 3)

        let finalized = ShowReportView.finalizedPDFStats(from: [
            firstTie,
            earliestOrder,
            secondTie,
            latestOrder
        ])
        let names = finalized.map { $0.player?.name ?? "" }

        #expect(names == ["SKPORD1", "SKPTIEA", "SKPTIEB", "SKPORD3"])
    }

    @Test("Rendered PDFs repeat headers and page numbers on every page")
    func renderedPDFHeaderAndPageNumberRepetition() throws {
        let geometry = AggregateHittingPDFPaginationGeometry()
        let rowCount = geometry.rowsPerPage + 1
        let document = try renderDocument(stats: makeStats(count: rowCount))
        let combinedText = try extractedText(from: document)

        #expect(document.pageCount == 2)
        #expect(occurrences(of: "Task810 Hitting", in: combinedText).count == document.pageCount)
        #expect(occurrences(of: "Num", in: combinedText).count == document.pageCount)

        for pageNumber in 1...document.pageCount {
            #expect(combinedText.contains("Page \(pageNumber)"))
        }
    }

    @Test("Identical renders have deterministic page count and extracted text")
    func identicalRendersAreDeterministic() throws {
        let stats = makeStats(count: AggregateHittingPDFPaginationGeometry().rowsPerPage + 3)
        let firstDocument = try renderDocument(stats: stats)
        let secondDocument = try renderDocument(stats: stats)
        let firstText = try extractedText(from: firstDocument)
        let secondText = try extractedText(from: secondDocument)

        #expect(firstDocument.pageCount == secondDocument.pageCount)
        #expect(firstText == secondText)
    }

    private func renderDocument(stats: [PlayerStats]) throws -> PDFDocument {
        let data = ShowReportView.renderAggregateHittingPDF(
            teamName: "Task810",
            orderedStats: stats,
            atbats: []
        )

        return try #require(PDFDocument(data: data))
    }

    private func extractedText(from document: PDFDocument) throws -> String {
        var pageTexts = [String]()

        for pageIndex in 0..<document.pageCount {
            let page = try #require(document.page(at: pageIndex))
            pageTexts.append(page.string ?? "")
        }

        return pageTexts.joined(separator: "\n")
    }

    private func makeStats(count: Int) -> [PlayerStats] {
        (0..<count).map { index in
            let token = String(format: "SKP%03dX", index + 1)
            return makeStat(token: token, batOrder: index + 1, index: index)
        }
    }

    private func makeStat(token: String, batOrder: Int, index: Int) -> PlayerStats {
        let player = Player(
            name: token,
            number: "\(index + 1)",
            position: "P",
            batDir: "R",
            batOrder: batOrder
        )

        return PlayerStats(
            player: player,
            atbats: 3,
            runs: index % 5,
            hits: 1,
            strikeouts: index % 2,
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

    private func occurrences(of token: String, in text: String) -> [String.Index] {
        var matches = [String.Index]()
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(of: token, range: searchStart..<text.endIndex) {
            matches.append(range.lowerBound)
            searchStart = range.upperBound
        }

        return matches
    }
}

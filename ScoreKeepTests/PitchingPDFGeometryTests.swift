import Testing
import UIKit
@testable import ScoreKeep

@Suite("PitchingPDFGeometryTests")
struct PitchingPDFGeometryTests {
    @Test("Pitching PDF table is centered within printable content")
    func pitchingPDFTableIsCenteredWithinPrintableContent() {
        let pageWidth: CGFloat = 800
        let margin: CGFloat = 50
        let contentWidth = pageWidth - (2 * margin)
        let tableOriginX = ShowPitchRptView.pitchingPDFTableOriginX(margin: margin, contentWidth: contentWidth)

        #expect(ShowPitchRptView.pitchingPDFTableWidth == 540)
        #expect(tableOriginX == 130)
        #expect(tableOriginX - margin == (contentWidth - ShowPitchRptView.pitchingPDFTableWidth) / 2)
        #expect((pageWidth - margin) - (tableOriginX + ShowPitchRptView.pitchingPDFTableWidth) == tableOriginX - margin)
    }

    @Test("Pitching PDF cells use shared column boundaries")
    func pitchingPDFCellsUseSharedColumnBoundaries() throws {
        let tableOriginX: CGFloat = 130
        let rowY: CGFloat = 130
        let rowHeight: CGFloat = 18
        let expectedCells: [(String, CGFloat, CGFloat)] = [
            ("number", 130, 30),
            ("name", 160, 130),
            ("era", 290, 35),
            ("innings", 325, 35),
            ("earnedRuns", 360, 20),
            ("unearnedRuns", 380, 30),
            ("hits", 410, 30),
            ("strikeouts", 440, 30),
            ("lookingStrikeouts", 470, 35),
            ("walks", 505, 25),
            ("hbp", 530, 30),
            ("homeRuns", 560, 30),
            ("singles", 590, 30),
            ("doubles", 620, 30),
            ("triples", 650, 20)
        ]

        #expect(ShowPitchRptView.pitchingPDFColumns.map(\.title) == [
            "#", "Name", "ERA", "IP", "ER", "UER", "H", "K", "ꓘ", "BB", "HBP", "HR", "1B", "2B", "3B"
        ])

        for (identifier, expectedX, expectedWidth) in expectedCells {
            let rect = try #require(ShowPitchRptView.pitchingPDFCellRect(
                identifier: identifier,
                tableOriginX: tableOriginX,
                currentY: rowY,
                height: rowHeight
            ))
            let column = try #require(ShowPitchRptView.pitchingPDFColumns.first { $0.identifier == identifier })

            #expect(rect.minX == expectedX)
            #expect(rect.minY == rowY)
            #expect(rect.width == expectedWidth)
            #expect(rect.height == rowHeight)
            #expect(rect.minX == tableOriginX + column.xOffset)
            #expect(rect.width == column.width)
        }
    }

    @Test("Pitching report stats use ERA with stable statistical tie breakers")
    func pitchingReportStatsUseStableStatisticalOrdering() {
        let higherERA = makePitchStats(name: "SKPERA500", number: "1", era: 5.00, pitchingOuts: 18, wins: 4)
        let lowerERAFewerInnings = makePitchStats(name: "SKPERA200C", number: "2", era: 2.00, pitchingOuts: 9, wins: 3)
        let lowerERAMoreInningsLowerWins = makePitchStats(name: "SKPERA200B", number: "3", era: 2.00, pitchingOuts: 18, wins: 1)
        let lowerERAMoreInningsMoreWins = makePitchStats(name: "SKPERA200A", number: "4", era: 2.00, pitchingOuts: 18, wins: 2)

        let ordered = [
            higherERA,
            lowerERAFewerInnings,
            lowerERAMoreInningsLowerWins,
            lowerERAMoreInningsMoreWins
        ].sorted(by: PitchStats.statisticsReportSort)
        let names = ordered.map { $0.pitcher?.player.name ?? "" }

        #expect(names == ["SKPERA200A", "SKPERA200B", "SKPERA200C", "SKPERA500"])
    }

    private func makePitchStats(name: String, number: String, era: CGFloat, pitchingOuts: Int, wins: Int) -> PitchStats {
        let team = Team(name: "Pitching Sort", coach: "", details: "")
        let game = Game(date: "2026-08-14", location: "", highLights: "", hscore: 0, vscore: 0)
        let player = Player(name: name, number: number, position: "P", batDir: "R", batOrder: 0)
        let pitcher = Pitcher(player: player, team: team, game: game)

        return PitchStats(
            pitcher: pitcher,
            wins: wins,
            innings: PitchingInningsCalculator.baseballNotation(fromOuts: pitchingOuts),
            pitchingOuts: pitchingOuts,
            ERA: era
        )
    }
}

import Testing
import Foundation
import SwiftData
import PDFKit
@testable import ScoreKeep

@Suite("Task810OnePageScorecardSuite")
struct Task810OnePageScorecardSuite {
    
    // MARK: - Geometry helper testing
    
    @Test("Test geometry calculation")
    func testGeometryCalculation() {
        let physicalSize = CGSize(width: 841.8, height: 595.2)
        let pitcherRows = 5
        
        let rowCounts = [0, 9, 12, 15, 18, 20]
        var previousScale: CGFloat = 1.0
        
        for rowCount in rowCounts {
            let geometry = OnePageScorecardGeometry(
                physicalPageSize: physicalSize,
                renderedBattingRowCount: rowCount,
                renderedPitcherRowCount: pitcherRows
            )
            
            // Positive scale
            #expect(geometry.scale > 0)
            
            // No greater than 1.0
            #expect(geometry.scale <= 1.0)
            
            // Decreases monotonically only as logical content height increases
            #expect(geometry.scale <= previousScale)
            previousScale = geometry.scale
            
            // Scaled content does not exceed physical page height
            #expect(geometry.scaledContentHeight <= physicalSize.height + 0.1) // 0.1 for floating point precision
            
            if geometry.fitsOnPhysicalPage {
                #expect(geometry.scale == 1.0)
            }
        }
        
        // Equivalent inputs produce equal geometry
        let geom1 = OnePageScorecardGeometry(physicalPageSize: physicalSize, renderedBattingRowCount: 12, renderedPitcherRowCount: 2)
        let geom2 = OnePageScorecardGeometry(physicalPageSize: physicalSize, renderedBattingRowCount: 12, renderedPitcherRowCount: 2)
        #expect(geom1.scale == geom2.scale)
        #expect(geom1.logicalContentHeight == geom2.logicalContentHeight)
    }
    
    // MARK: - Rendered one-page preservation
    
    @Test("Test rendered one-page preservation for various row counts")
    func testRenderedOnePagePreservation() throws {
        let rowCounts = [9, 12, 15, 18, 20]
        
        for rowCount in rowCounts {
            let generator = PDFGenerator()
            let (game, team, players) = try buildFixture(rowCount: rowCount, pitcherCount: 2)
            
            let url = generator.generatePDFData(game: game, team: team, title: "Test", body: "Test")
            let pdfURL = try #require(url)
            
            defer { try? FileManager.default.removeItem(at: pdfURL) }
            
            let document = try #require(PDFDocument(url: pdfURL))
            
            // PDFKit reports exactly one page
            #expect(document.pageCount == 1)
            guard document.pageCount == 1 else {
                Issue.record("PDF page count is not exactly 1")
                continue
            }
            
            let page = try #require(document.page(at: 0))
            guard let text = page.string else {
                Issue.record("Failed to extract text from PDF page")
                continue
            }
            
            guard let firstPlayer = players.first, let lastPlayer = players.last else {
                Issue.record("No players generated")
                continue
            }
            
            let firstToken = firstPlayer.name
            let lastToken = lastPlayer.name
            let firstOccurrences = extractOccurrences(of: firstToken, in: text)
            let lastOccurrences = extractOccurrences(of: lastToken, in: text)
            
            #expect(firstOccurrences.count == 1, "First token should appear exactly once")
            #expect(lastOccurrences.count == 1, "Last token should appear exactly once")
            
            var previousIndex: String.Index? = nil
            var allTokensFoundAndOrdered = true
            var tokenCount = 0
            var collectedOffsets = [String.Index]()
            
            for player in players {
                let token = player.name
                let occurrences = extractOccurrences(of: token, in: text)
                
                #expect(occurrences.count == 1, "Token \(token) should appear exactly once, found \(occurrences.count)")
                
                guard let firstOccurrence = occurrences.first, occurrences.count == 1 else {
                    allTokensFoundAndOrdered = false
                    continue
                }
                
                tokenCount += 1
                collectedOffsets.append(firstOccurrence)
                
                if let prev = previousIndex {
                    #expect(firstOccurrence > prev, "Token \(token) appeared out of order")
                    if firstOccurrence <= prev {
                        allTokensFoundAndOrdered = false
                    }
                }
                previousIndex = firstOccurrence
            }
            
            // Confirm first and last tokens were checked
            #expect(tokenCount == players.count, "Not all tokens were verified")
            #expect(allTokensFoundAndOrdered, "Tokens were missing, duplicated, or out of order")
            #expect(firstOccurrences.first == collectedOffsets.first, "First token offset mismatch")
            #expect(lastOccurrences.first == collectedOffsets.last, "Last token offset mismatch")
            
            // Pitching content remains present exactly once
            let pitchingOccurrences = extractOccurrences(of: "Pitching Stats For This Game", in: text)
            #expect(pitchingOccurrences.count == 1, "Pitching stats header should appear exactly once")
        }
    }
    
    // MARK: - Long-text fitting verification

    @Test("Test long text fitting policy")
    func testLongTextFitting() throws {
        let generator = PDFGenerator()

        let team = Team(name: "VTZ7_ExtremelyLongVisitingTeamNameThatForcesShrinkageAndTruncation", coach: "Coach", details: "Details")
        let otherTeam = Team(name: "HTQ8_ExtremelyLongHomeTeamNameThatForcesShrinkageAndTruncation", coach: "", details: "")
        let game = Game(date: "2026-07-21T12:00:00Z", location: "LOC9_ExtremelyLongLocationNameThatForcesShrinkageAndTruncation", highLights: "", hscore: 0, vscore: 0)
        game.vteam = team
        game.hteam = otherTeam

        let p1 = Player(name: "Michael Robertson-WithALongLastName", number: "1", position: "P", batDir: "R", batOrder: 1, team: team)
        let p2 = Player(name: "Juan Carlos Pérez-WithALongLastName", number: "2", position: "P", batDir: "R", batOrder: 2, team: team)
        let p3 = Player(name: "SGL1_SuperLongSingleWordNameThatForcesShrinkageAndTruncation", number: "3", position: "P", batDir: "R", batOrder: 3, team: team)

        team.players = [p1, p2, p3]
        game.players = [p1, p2, p3]

        var atbats = [Atbat]()
        for (i, p) in [p1, p2, p3].enumerated() {
            atbats.append(Atbat(game: game, team: team, player: p, result: "Single", maxbase: "First", batOrder: i + 1, outAt: "Safe", inning: 1, seq: i + 1, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0))
        }
        game.atbats = atbats

        let pt1 = Player(name: "LongPitcherFirstName ExtremelyLongPitcherLastName", number: "P1", position: "P", batDir: "R", batOrder: 1, team: otherTeam)
        game.pitchers = [Pitcher(player: pt1, team: otherTeam, game: game, startInn: 1, sOuts: 0, sBats: 0, endInn: 2, eOuts: 0, eBats: 0)]

        let url = try #require(generator.generatePDFData(game: game, team: team, title: "Test", body: "Test"))
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try #require(PDFDocument(url: url))
        #expect(document.pageCount == 1)

        let rawText = try #require(document.page(at: 0)?.string)
        let components = rawText.components(separatedBy: .whitespacesAndNewlines)
        let text = components.filter { !$0.isEmpty }.joined(separator: " ")
        let textNoSpaces = components.filter { !$0.isEmpty }.joined()

        #expect(extractOccurrences(of: "VTZ7", in: text).count > 0)
        #expect(extractOccurrences(of: "HTQ8", in: text).count > 0)
        #expect(extractOccurrences(of: "LOC9", in: text).count > 0)

        #expect(extractOccurrences(of: "M.Robertson-WithALong", in: textNoSpaces).count > 0)
        #expect(extractOccurrences(of: "MichaelRobertson-", in: textNoSpaces).count == 0)

        #expect(extractOccurrences(of: "J.CarlosPérez-WithALong", in: textNoSpaces).count > 0)
        #expect(extractOccurrences(of: "JuanCarlosPérez-", in: textNoSpaces).count == 0)

        #expect(extractOccurrences(of: "SGL1", in: textNoSpaces).count > 0)
        #expect(extractOccurrences(of: "S.SGL1", in: textNoSpaces).count == 0)

        #expect(extractOccurrences(of: "L. ExtremelyLongPitcher", in: text).count > 0)
        #expect(extractOccurrences(of: "LongPitcherFirstName", in: text).count == 0)

        #expect(extractOccurrences(of: "HTQ8_ExtremelyLongHomeTeamNameThatForcesShrinkageAndTruncation Pitching Stats For This Game", in: text).count > 0)
    }

    // MARK: - Independent-render determinism
    
    @Test("Test independent render determinism")
    func testIndependentRenderDeterminism() throws {
        let generator1 = PDFGenerator()
        let (game1, team1, players1) = try buildFixture(rowCount: 20, pitcherCount: 2)
        let url1 = try #require(generator1.generatePDFData(game: game1, team: team1, title: "Test", body: "Test"))
        defer { try? FileManager.default.removeItem(at: url1) }
        
        let generator2 = PDFGenerator()
        let (game2, team2, players2) = try buildFixture(rowCount: 20, pitcherCount: 2)
        let url2 = try #require(generator2.generatePDFData(game: game2, team: team2, title: "Test", body: "Test"))
        defer { try? FileManager.default.removeItem(at: url2) }
        
        #expect(url1 != url2, "Independent scorecard renders must not share output file lifecycle")

        let doc1 = try #require(PDFDocument(url: url1))
        let doc2 = try #require(PDFDocument(url: url2))
        
        #expect(doc1.pageCount == 1)
        #expect(doc2.pageCount == 1)
        
        guard doc1.pageCount == 1, doc2.pageCount == 1 else {
            Issue.record("PDF page counts are not 1")
            return
        }
        
        guard let text1 = doc1.page(at: 0)?.string, let text2 = doc2.page(at: 0)?.string else {
            Issue.record("Failed to extract text from PDF pages")
            return
        }
        
        var offsets1 = [Int]()
        var offsets2 = [Int]()
        
        guard players1.count == players2.count else {
            Issue.record("Player counts do not match")
            return
        }
        
        for (player1, player2) in zip(players1, players2) {
            let token1 = player1.name
            let token2 = player2.name
            
            let occ1 = extractOccurrences(of: token1, in: text1)
            let occ2 = extractOccurrences(of: token2, in: text2)
            
            #expect(occ1.count == 1)
            #expect(occ2.count == 1)
            
            if let f1 = occ1.first {
                offsets1.append(text1.distance(from: text1.startIndex, to: f1))
            }
            if let f2 = occ2.first {
                offsets2.append(text2.distance(from: text2.startIndex, to: f2))
            }
        }
        
        #expect(offsets1.count == players1.count)
        #expect(offsets2.count == players2.count)
        #expect(offsets1 == offsets2, "Extracted expected-token order is not identical")
        
        let physicalSize = CGSize(width: 841.8, height: 595.2)
        let geom1 = OnePageScorecardGeometry(physicalPageSize: physicalSize, renderedBattingRowCount: 20, renderedPitcherRowCount: 2)
        let geom2 = OnePageScorecardGeometry(physicalPageSize: physicalSize, renderedBattingRowCount: 20, renderedPitcherRowCount: 2)
        
        #expect(geom1.scale == geom2.scale)
        #expect(geom1.logicalContentHeight == geom2.logicalContentHeight)
    }
    
    // MARK: - Helper Methods
    
    private func extractOccurrences(of token: String, in text: String) -> [String.Index] {
        var indices = [String.Index]()
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: token, options: [], range: searchRange) {
            indices.append(range.lowerBound)
            if range.upperBound < text.endIndex {
                searchRange = range.upperBound..<text.endIndex
            } else {
                break
            }
        }
        return indices
    }
    
    private func buildFixture(rowCount: Int, pitcherCount: Int) throws -> (Game, Team, [Player]) {
        let team = Team(name: "TestTeam", coach: "Coach", details: "Details")
        let game = Game(date: "2026-07-21T12:00:00Z", location: "Field", highLights: "", hscore: 0, vscore: 0)
        game.hteam = team
        let otherTeam = Team(name: "OtherTeam", coach: "", details: "")
        game.vteam = otherTeam
        
        var players = [Player]()
        var atbats = [Atbat]()
        for i in 0..<rowCount {
            let token = String(format: "PX%03dQ", i + 1)
            let player = Player(name: token, number: "\(i)", position: "P", batDir: "R", batOrder: i + 1, team: team)
            players.append(player)
            let atbat = Atbat(game: game, team: team, player: player, result: "Single", maxbase: "First", batOrder: i + 1, outAt: "Safe", inning: 1, seq: i + 1, col: 1, rbis: 0, outs: 0, sacFly: 0, sacBunt: 0, stolenBases: 0)
            atbats.append(atbat)
        }
        
        team.players = players
        game.players = players
        game.atbats = atbats
        
        var pitchers = [Pitcher]()
        for i in 0..<pitcherCount {
            let token = String(format: "PTX%03dQ", i + 1)
            let pPlayer = Player(name: token, number: "P\(i)", position: "P", batDir: "R", batOrder: i + 1, team: otherTeam)
            let pitcher = Pitcher(player: pPlayer, team: otherTeam, game: game, startInn: 1, sOuts: 0, sBats: 0, endInn: 2, eOuts: 0, eBats: 0)
            pitchers.append(pitcher)
        }
        game.pitchers = pitchers
        
        return (game, team, players)
    }
}

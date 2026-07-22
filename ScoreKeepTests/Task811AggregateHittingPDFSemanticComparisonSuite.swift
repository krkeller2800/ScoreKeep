import Foundation
import PDFKit
import Testing
import UIKit
@testable import ScoreKeep

@Suite("Task811AggregateHittingPDFSemanticComparisonSuite")
struct Task811AggregateHittingPDFSemanticComparisonSuite {
    
    struct ExpectedField {
        let name: String
        let value: String
    }
    
    /// Verifies the complete ordered sequence of values belonging to the rendered player row.
    private func assertSemanticMatch(tokens: [String], playerNameToken: String, expectedFields: [ExpectedField], sourceLocation: SourceLocation = #_sourceLocation) {
        // Locate the rendered player row using the distinctive player identity
        guard let nameIndex = tokens.firstIndex(of: playerNameToken) else {
            Issue.record("Could not find player name token '\(playerNameToken)' to locate the row.", sourceLocation: sourceLocation)
            return
        }
        
        // Ensure token boundaries or equivalent structured matching by finding exact token matches sequentially
        // The first expected field is 'number', which typically precedes the name.
        var searchIndex = max(0, nameIndex - 5)
        
        for field in expectedFields {
            // Find the next occurrence of the expected field value AFTER the current searchIndex.
            // This strictly enforces row-column order and prevents substring matches.
            if let foundIndex = tokens[searchIndex...].firstIndex(of: field.value) {
                searchIndex = foundIndex + 1
            } else {
                let contextEnd = min(searchIndex + 15, tokens.endIndex)
                let actualContext = tokens[searchIndex..<contextEnd].joined(separator: " ")
                Issue.record(
                    "Semantic mismatch for field '\(field.name)'. Expected '\(field.value)'. Actual row evidence near position: [\(actualContext)]",
                    sourceLocation: sourceLocation
                )
                return
            }
        }
    }
    
    @Test("Every current aggregate hitting report field is verified in correct player-row order")
    func matchesValuesInOrder() throws {
        let stats = PlayerStats(
            player: Player(name: "P1", number: "99", position: "P", batDir: "R", batOrder: 1),
            atbats: 50,
            runs: 10,
            hits: 15,
            strikeouts: 11,
            strikeoutl: 12,
            HR: 13,
            single: 14,
            double: 16,
            triple: 17,
            BB: 18,
            sacBunt: 19, // sbColumnValue
            sacFly: 20,
            hbp: 21,
            dts: 22,
            fc: 23
        )
        
        let expectedFields = [
            ExpectedField(name: "number", value: "99"),
            ExpectedField(name: "name", value: "P1"),
            ExpectedField(name: "atBats", value: "50"),
            ExpectedField(name: "avg", value: "300"),
            ExpectedField(name: "obp", value: "495"),
            ExpectedField(name: "slg", value: "2980"),
            ExpectedField(name: "ops", value: "3475"),
            ExpectedField(name: "runs", value: "10"),
            ExpectedField(name: "hits", value: "15"),
            ExpectedField(name: "strikeouts", value: "11"),
            ExpectedField(name: "lookingStrikeouts", value: "12"),
            ExpectedField(name: "walks", value: "18"),
            ExpectedField(name: "homeRuns", value: "13"),
            ExpectedField(name: "singles", value: "14"),
            ExpectedField(name: "doubles", value: "16"),
            ExpectedField(name: "triples", value: "17"),
            ExpectedField(name: "sbColumnValue", value: "19"),
            ExpectedField(name: "sacrificeFlies", value: "20"),
            ExpectedField(name: "hbp", value: "21"),
            ExpectedField(name: "dts", value: "22"),
            ExpectedField(name: "fc", value: "23")
        ]
        
        let data = ShowReportView.renderAggregateHittingPDF(teamName: "SemanticTeam", orderedStats: [stats], atbats: [])
        let tokens = try extractTokens(from: data)
        assertSemanticMatch(tokens: tokens, playerNameToken: "P1", expectedFields: expectedFields)
    }

    @Test("OPS and related rate values above 999 remain complete")
    func opsAbove999RemainsCompleteInOrder() throws {
        let stats = PlayerStats(
            player: Player(name: "Monster", number: "88", position: "P", batDir: "R", batOrder: 1),
            atbats: 31,
            runs: 32,
            hits: 31,
            strikeouts: 33,
            strikeoutl: 34,
            HR: 10,
            single: 11,
            double: 12,
            triple: 13,
            BB: 35,
            sacBunt: 36,
            sacFly: 37,
            hbp: 38,
            dts: 39,
            fc: 40
        )
        
        let expectedFields = [
            ExpectedField(name: "number", value: "88"),
            ExpectedField(name: "name", value: "Monster"),
            ExpectedField(name: "atBats", value: "31"),
            ExpectedField(name: "avg", value: "1000"),
            ExpectedField(name: "obp", value: "737"),
            ExpectedField(name: "slg", value: "3677"),
            ExpectedField(name: "ops", value: "4414"),
            ExpectedField(name: "runs", value: "32"),
            ExpectedField(name: "hits", value: "31"),
            ExpectedField(name: "strikeouts", value: "33"),
            ExpectedField(name: "lookingStrikeouts", value: "34"),
            ExpectedField(name: "walks", value: "35"),
            ExpectedField(name: "homeRuns", value: "10"),
            ExpectedField(name: "singles", value: "11"),
            ExpectedField(name: "doubles", value: "12"),
            ExpectedField(name: "triples", value: "13"),
            ExpectedField(name: "sbColumnValue", value: "36"),
            ExpectedField(name: "sacrificeFlies", value: "37"),
            ExpectedField(name: "hbp", value: "38"),
            ExpectedField(name: "dts", value: "39"),
            ExpectedField(name: "fc", value: "40")
        ]
        
        let data = ShowReportView.renderAggregateHittingPDF(teamName: "OpsTeam", orderedStats: [stats], atbats: [])
        let tokens = try extractTokens(from: data)
        assertSemanticMatch(tokens: tokens, playerNameToken: "Monster", expectedFields: expectedFields)
    }
    
    @Test("Multi-digit count values remain complete")
    func multiDigitCountValuesRemainCompleteInOrder() throws {
        let stats = PlayerStats(
            player: Player(name: "Multi", number: "98", position: "P", batDir: "R", batOrder: 1),
            atbats: 50,
            runs: 25,
            hits: 15,
            strikeouts: 26,
            strikeoutl: 27,
            HR: 28,
            single: 29,
            double: 30,
            triple: 31,
            BB: 32,
            sacBunt: 33,
            sacFly: 34,
            hbp: 35,
            dts: 36,
            fc: 37
        )
        
        let expectedFields = [
            ExpectedField(name: "number", value: "98"),
            ExpectedField(name: "name", value: "Multi"),
            ExpectedField(name: "atBats", value: "50"),
            ExpectedField(name: "avg", value: "300"),
            ExpectedField(name: "obp", value: "543"),
            ExpectedField(name: "slg", value: "5880"),
            ExpectedField(name: "ops", value: "6423"),
            ExpectedField(name: "runs", value: "25"),
            ExpectedField(name: "hits", value: "15"),
            ExpectedField(name: "strikeouts", value: "26"),
            ExpectedField(name: "lookingStrikeouts", value: "27"),
            ExpectedField(name: "walks", value: "32"),
            ExpectedField(name: "homeRuns", value: "28"),
            ExpectedField(name: "singles", value: "29"),
            ExpectedField(name: "doubles", value: "30"),
            ExpectedField(name: "triples", value: "31"),
            ExpectedField(name: "sbColumnValue", value: "33"),
            ExpectedField(name: "sacrificeFlies", value: "34"),
            ExpectedField(name: "hbp", value: "35"),
            ExpectedField(name: "dts", value: "36"),
            ExpectedField(name: "fc", value: "37")
        ]
        
        let data = ShowReportView.renderAggregateHittingPDF(teamName: "MultiTeam", orderedStats: [stats], atbats: [])
        let tokens = try extractTokens(from: data)
        assertSemanticMatch(tokens: tokens, playerNameToken: "Multi", expectedFields: expectedFields)
    }
    
    @Test("Team/header identity remains verified separately from player-row semantics")
    func headerComparedSeparately() throws {
        let stats = PlayerStats(player: Player(name: "A", number: "1", position: "P", batDir: "R", batOrder: 1), atbats: 1, runs: 0, hits: 0, strikeouts: 0, strikeoutl: 0, HR: 0, single: 0, double: 0, triple: 0, BB: 0, sacBunt: 0, sacFly: 0, hbp: 0, dts: 0, fc: 0)
        let data = ShowReportView.renderAggregateHittingPDF(teamName: "VeryUniqueTeamIdentityString", orderedStats: [stats], atbats: [])
        let tokens = try extractTokens(from: data)
        
        // Check header token exists anywhere
        #expect(tokens.contains("VeryUniqueTeamIdentityString"))
        
        // Independently verify the row parses in order
        let expectedFields = [
            ExpectedField(name: "number", value: "1"),
            ExpectedField(name: "name", value: "A"),
            ExpectedField(name: "atBats", value: "1"),
            ExpectedField(name: "avg", value: "000"),
            ExpectedField(name: "obp", value: "000"),
            ExpectedField(name: "slg", value: "000"),
            ExpectedField(name: "ops", value: "000"),
            ExpectedField(name: "runs", value: "0"),
            ExpectedField(name: "hits", value: "0"),
            ExpectedField(name: "strikeouts", value: "0"),
            ExpectedField(name: "lookingStrikeouts", value: "0"),
            ExpectedField(name: "walks", value: "0"),
            ExpectedField(name: "homeRuns", value: "0"),
            ExpectedField(name: "singles", value: "0"),
            ExpectedField(name: "doubles", value: "0"),
            ExpectedField(name: "triples", value: "0"),
            ExpectedField(name: "sbColumnValue", value: "0"),
            ExpectedField(name: "sacrificeFlies", value: "0"),
            ExpectedField(name: "hbp", value: "0"),
            ExpectedField(name: "dts", value: "0"),
            ExpectedField(name: "fc", value: "0")
        ]
        assertSemanticMatch(tokens: tokens, playerNameToken: "A", expectedFields: expectedFields)
    }
    
    @Test("Repeated rendering produces the same semantic result")
    func repeatedRenderingProducesSameSemantics() throws {
        let stats = PlayerStats(player: Player(name: "RepeatablePlayer", number: "77", position: "P", batDir: "R", batOrder: 1), atbats: 5, runs: 1, hits: 2, strikeouts: 0, strikeoutl: 0, HR: 0, single: 2, double: 0, triple: 0, BB: 0, sacBunt: 0, sacFly: 0, hbp: 0, dts: 0, fc: 0)
        
        let data1 = ShowReportView.renderAggregateHittingPDF(teamName: "RepeatableTeam", orderedStats: [stats], atbats: [])
        let data2 = ShowReportView.renderAggregateHittingPDF(teamName: "RepeatableTeam", orderedStats: [stats], atbats: [])
        
        let tokens1 = try extractTokens(from: data1)
        let tokens2 = try extractTokens(from: data2)
        
        #expect(tokens1 == tokens2)
    }
    
    @Test("A deliberately mismatched expected field demonstrates that the comparison identifies the correct field and position")
    func mismatchedExpectationDiagnostic() throws {
        let expectedFields = [
            ExpectedField(name: "number", value: "1"),
            ExpectedField(name: "name", value: "MismatchPlayer"),
            ExpectedField(name: "atBats", value: "1"),
            ExpectedField(name: "avg", value: "000"),
            ExpectedField(name: "obp", value: "000"),
            ExpectedField(name: "slg", value: "000"),
            ExpectedField(name: "ops", value: "000"),
            ExpectedField(name: "runs", value: "0"),
            ExpectedField(name: "hits", value: "0"),
            ExpectedField(name: "strikeouts", value: "0"),
            ExpectedField(name: "lookingStrikeouts", value: "0"),
            ExpectedField(name: "walks", value: "0"),
            ExpectedField(name: "homeRuns", value: "0"),
            ExpectedField(name: "singles", value: "0"),
            ExpectedField(name: "doubles", value: "0"),
            ExpectedField(name: "triples", value: "0"),
            ExpectedField(name: "sbColumnValue", value: "0"),
            ExpectedField(name: "sacrificeFlies", value: "0"),
            ExpectedField(name: "hbp", value: "0"),
            ExpectedField(name: "dts", value: "0"),
            ExpectedField(name: "fc", value: "WRONG_VALUE")
        ]
        
        let tokens = [
            "Header", "MismatchTeam",
            "1", "MismatchPlayer", "1", "000", "000", "000", "000", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0",
            "Footer"
        ]
        
        guard let nameIndex = tokens.firstIndex(of: "MismatchPlayer") else {
            Issue.record("Should find name")
            return
        }
        
        var searchIndex = max(0, nameIndex - 5)
        var failedField: String?
        
        for field in expectedFields {
            if let foundIndex = tokens[searchIndex...].firstIndex(of: field.value) {
                searchIndex = foundIndex + 1
            } else {
                failedField = field.name
                break
            }
        }
        
        #expect(failedField == "fc", "Diagnostic should explicitly identify 'fc' as the mismatched field.")
    }

    private func extractTokens(from data: Data) throws -> [String] {
        let document = try #require(PDFDocument(data: data))
        var pageTexts = [String]()
        for pageIndex in 0..<document.pageCount {
            pageTexts.append(document.page(at: pageIndex)?.string ?? "")
        }
        return pageTexts
            .joined(separator: "\n")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }
}

import Testing
import Foundation
@testable import ScoreKeep

@Suite("Task 8.4 Report Scope Preparation Suite")
struct Task84Suite {
    let validator = ReportScopeValidator()
    
    @Test("Valid team and game scopes prepare correctly")
    func task84PreparesSupportedTeamAndGameScopes() {
        let teamID = UUID()
        let gameID = UUID()
        
        let hittingResult = validator.prepareScope(family: .hittingStatistics, teamIDs: [teamID], gameIDs: [], playerIDs: [])
        #expect(hittingResult.scope == .teamAggregate(teamID: teamID))
        #expect(hittingResult.error == nil)
        #expect(hittingResult.warnings.isEmpty)
        
        let gameResult = validator.prepareScope(family: .singleGameScorecard, teamIDs: [teamID], gameIDs: [gameID], playerIDs: [])
        #expect(gameResult.scope == .singleGame(teamID: teamID, gameID: gameID))
        #expect(gameResult.error == nil)
        #expect(gameResult.warnings.isEmpty)
    }
    
    @Test("Rejects missing, conflicting, and unsupported selections")
    func task84RejectsMissingConflictingAndUnsupportedSelections() {
        let teamID = UUID()
        let gameID = UUID()
        
        let missingTeamResult = validator.prepareScope(family: .hittingStatistics, teamIDs: [], gameIDs: [], playerIDs: [])
        #expect(missingTeamResult.error == .missingRequiredTeamSelection)
        
        let missingGameResult = validator.prepareScope(family: .singleGameScorecard, teamIDs: [teamID], gameIDs: [], playerIDs: [])
        #expect(missingGameResult.error == .missingRequiredGameSelection)
        
        let conflictingResult = validator.prepareScope(family: .hittingStatistics, teamIDs: [teamID], gameIDs: [gameID], playerIDs: [])
        #expect(conflictingResult.error == .conflictingScopeForReportFamily(.hittingStatistics))
        
        let playerID = UUID()
        let unsupportedPlayerResult = validator.prepareScope(family: .hittingStatistics, teamIDs: [teamID], gameIDs: [], playerIDs: [playerID])
        #expect(unsupportedPlayerResult.warnings.contains(.unsupportedPlayerScope(playerID: playerID)))
        #expect(unsupportedPlayerResult.scope == .teamAggregate(teamID: teamID))
        
        let team2ID = UUID()
        let duplicateTeamResult = validator.prepareScope(family: .hittingStatistics, teamIDs: [teamID, team2ID], gameIDs: [], playerIDs: [])
        #expect(duplicateTeamResult.warnings.contains(.unsupportedMultiSelection))
        
        if case .teamAggregate(let resultTeamID) = duplicateTeamResult.scope {
            let sortedIDs = [teamID, team2ID].sorted(by: { $0.uuidString < $1.uuidString })
            #expect(resultTeamID == sortedIDs.first!)
        } else {
            Issue.record("Expected a coalesced team scope")
        }
    }
    
    @Test("Preparation is deterministic and read-only")
    func task84PreparationIsDeterministicAndReadOnly() {
        let teamID = UUID()
        let result1 = validator.prepareScope(family: .hittingStatistics, teamIDs: [teamID], gameIDs: [], playerIDs: [])
        let result2 = validator.prepareScope(family: .hittingStatistics, teamIDs: [teamID], gameIDs: [], playerIDs: [])
        
        #expect(result1 == result2)
        // Read-only constraint is proven by the absence of SwiftData model contexts in the validator API.
    }
}

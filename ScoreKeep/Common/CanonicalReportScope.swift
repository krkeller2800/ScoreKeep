import Foundation

public enum ReportFamily: Equatable {
    case hittingStatistics
    case pitchingStatistics
    case singleGameScorecard
}

public enum ReportScopeWarning: Error, Equatable {
    case unsupportedPlayerScope(playerID: UUID)
    case unsupportedMultiSelection
}

public enum ReportScopeError: Error, Equatable {
    case missingRequiredTeamSelection
    case missingRequiredGameSelection
    case conflictingScopeForReportFamily(ReportFamily)
}

public enum PreparedReportScope: Equatable {
    case teamAggregate(teamID: UUID)
    case singleGame(teamID: UUID, gameID: UUID)
}

public struct ReportScopePreparationResult: Equatable {
    public let scope: PreparedReportScope?
    public let warnings: [ReportScopeWarning]
    public let error: ReportScopeError?
    
    public init(scope: PreparedReportScope?, warnings: [ReportScopeWarning], error: ReportScopeError?) {
        self.scope = scope
        self.warnings = warnings
        self.error = error
    }
}

public struct ReportScopeValidator {
    
    public init() {}
    
    public func prepareScope(
        family: ReportFamily,
        teamIDs: Set<UUID>,
        gameIDs: Set<UUID>,
        playerIDs: Set<UUID>
    ) -> ReportScopePreparationResult {
        
        var warnings: [ReportScopeWarning] = []
        
        if let playerID = playerIDs.sorted(by: { $0.uuidString < $1.uuidString }).first {
            warnings.append(.unsupportedPlayerScope(playerID: playerID))
        }
        
        if teamIDs.count > 1 || gameIDs.count > 1 || playerIDs.count > 1 {
            warnings.append(.unsupportedMultiSelection)
        }
        
        let teamIDToUse = teamIDs.sorted(by: { $0.uuidString < $1.uuidString }).first
        let gameIDToUse = gameIDs.sorted(by: { $0.uuidString < $1.uuidString }).first
        
        switch family {
        case .hittingStatistics, .pitchingStatistics:
            guard let teamID = teamIDToUse else {
                return ReportScopePreparationResult(scope: nil, warnings: warnings, error: .missingRequiredTeamSelection)
            }
            if gameIDToUse != nil {
                return ReportScopePreparationResult(scope: nil, warnings: warnings, error: .conflictingScopeForReportFamily(family))
            }
            return ReportScopePreparationResult(
                scope: .teamAggregate(teamID: teamID),
                warnings: warnings,
                error: nil
            )
            
        case .singleGameScorecard:
            guard let teamID = teamIDToUse else {
                return ReportScopePreparationResult(scope: nil, warnings: warnings, error: .missingRequiredTeamSelection)
            }
            guard let gameID = gameIDToUse else {
                return ReportScopePreparationResult(scope: nil, warnings: warnings, error: .missingRequiredGameSelection)
            }
            return ReportScopePreparationResult(
                scope: .singleGame(teamID: teamID, gameID: gameID),
                warnings: warnings,
                error: nil
            )
        }
    }
}

import Foundation

public enum SeasonClassification: Equatable, Sendable {
    case current
    case prior
    case future
    case wrong
    case missingSeason
}

public struct SeasonClassifier: Sendable {
    private let prefix = "com.komakode.ScoreKeep.SeasonPass"
    
    public init() {}
    
    public func classify(identifier: String, currentYear: Int) -> SeasonClassification {
        guard !identifier.isEmpty, identifier.hasPrefix(prefix) else {
            return .wrong
        }
        
        guard let parsedSeason = seasonYear(identifier: identifier) else {
            return .missingSeason
        }
        
        if parsedSeason == currentYear {
            return .current
        } else if parsedSeason < currentYear {
            return .prior
        } else {
            return .future
        }
    }

    public func seasonYear(identifier: String) -> Int? {
        guard !identifier.isEmpty, identifier.hasPrefix(prefix) else {
            return nil
        }

        let suffix = identifier.dropFirst(prefix.count)
        let suffixArray = Array(suffix)

        guard suffixArray.count == 4 else {
            return nil
        }

        for c in suffixArray {
            if c < "0" || c > "9" {
                return nil
            }
        }

        if suffixArray[0] == "0" {
            return nil
        }

        return Int(String(suffixArray))
    }
}

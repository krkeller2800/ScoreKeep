import Foundation

enum PlayerCompactPositionDisplay {
    static func string(for rawPosition: String) -> String {
        let trimmed = rawPosition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }
        guard let position = CanonicalDefensivePosition.recognized(rawValue: trimmed) else {
            return trimmed
        }

        switch position {
        case .pitcher:
            return "P"
        case .startingPitcher:
            return "SP"
        case .reliefPitcher:
            return "RP"
        case .catcher:
            return "C"
        case .firstBase:
            return "1B"
        case .secondBase:
            return "2B"
        case .shortstop:
            return "SS"
        case .thirdBase:
            return "3B"
        case .leftField:
            return "LF"
        case .centerField:
            return "CF"
        case .rightField:
            return "RF"
        case .designatedHitter:
            return "DH"
        }
    }
}

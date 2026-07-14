import Foundation

/// Test-only support for task 0.14 baseline evidence.
///
/// These helpers mirror current repository-observed policy calculations without
/// becoming production authority. They intentionally avoid StoreKit, Keychain,
/// UserDefaults.standard, ScoreKeepApp, and the production model container.
enum ControlledStateBaselineSupport {
    static let seasonPassProductIDPrefix = "com.komakode.ScoreKeep.SeasonPass"
    static let seasonPassEntitlementKey = "seasonPassMaxExpirationISO8601"
    static let freeGameCreatesCounterKey = "freeGameCreatesRemainingKC"
    static let freeGameCreatesDefault = 2
    static let mlbDownloadCounterKey = "mlbDownloadCountKC"
    static let mlbDownloadFreeLimit = 4
    static let seedPreferenceKey = "hasSeededInitialGame"
    static let seedHintDismissedPreferenceKey = "hasDismissedSeedHint_Game"

    static let policyTimeZone = TimeZone(identifier: "America/New_York")!
    static let utcTimeZone = TimeZone(secondsFromGMT: 0)!

    static var policyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = policyTimeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func fixedDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0,
        second: Int = 0,
        calendar: Calendar = policyCalendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components)!
    }

    static func productIdentifier(forSeasonYear year: Int) -> String {
        "\(seasonPassProductIDPrefix)\(year)"
    }

    static func productIdentifier(for date: Date, calendar: Calendar = policyCalendar) -> String {
        productIdentifier(forSeasonYear: calendar.component(.year, from: date))
    }

    static func parsedSeasonYear(from productID: String) -> Int? {
        guard productID.count >= 4 else { return nil }
        return Int(String(productID.suffix(4)))
    }

    static func endOfSeasonYear(_ year: Int, calendar: Calendar = policyCalendar) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = 12
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components)!
    }

    static func isEntitlementActive(expiration: Date?, at now: Date) -> Bool {
        (expiration ?? .distantPast) > now
    }

    static func seasonClassification(productYear: Int, currentYear: Int) -> SeasonClassification {
        if productYear == currentYear { return .current }
        if productYear < currentYear { return .prior }
        return .future
    }

    static func productAvailability(productWasLoaded: Bool, entitlementExpiration: Date?, now: Date) -> ProductAvailabilityBaseline {
        if productWasLoaded == false {
            return .missingProduct
        }
        return isEntitlementActive(expiration: entitlementExpiration, at: now) ? .entitled : .notEntitled
    }

    static func remainingAllowance(after action: AllowanceAction, startingAt remaining: Int) -> Int {
        switch action {
        case .successfulQualifyingAction:
            return max(0, remaining - 1)
        case .failedAction, .canceledAction, .blockedBeforeStart:
            return max(0, remaining)
        }
    }

    static func usedDownloadCount(after action: AllowanceAction, startingAt used: Int) -> Int {
        switch action {
        case .successfulQualifyingAction:
            return max(0, used + 1)
        case .failedAction, .canceledAction, .blockedBeforeStart:
            return max(0, used)
        }
    }
}

enum SeasonClassification: Equatable {
    case current
    case prior
    case future
}

enum ProductAvailabilityBaseline: Equatable {
    case missingProduct
    case entitled
    case notEntitled
}

enum AllowanceAction {
    case successfulQualifyingAction
    case failedAction
    case canceledAction
    case blockedBeforeStart
}

enum BuildConfigurationBaseline {
    #if DEBUG
    static let isDebugBuild = true
    #else
    static let isDebugBuild = false
    #endif
}

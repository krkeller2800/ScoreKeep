import Foundation

enum ScoreKeepLaunchMode: Hashable {
    case unitTestHostIsolation
    case schemaDiagnostic
    case uiTestDynamicTypeSeam
    case production
}

enum ScoreKeepLaunchIsolation {
    static let schemaDiagnosticArgument = "-ScoreKeepSchemaDiagnostic"
    static let uiTestDynamicTypeSeamArgument = "-ScoreKeepUITestDynamicTypeSeam"

    static func mode(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        commandLineArguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ScoreKeepLaunchMode {
        if isUnitTestHost(environment: environment) {
            return .unitTestHostIsolation
        }
        if arguments.contains(uiTestDynamicTypeSeamArgument) || commandLineArguments.contains(uiTestDynamicTypeSeamArgument) {
            return .uiTestDynamicTypeSeam
        }
        if arguments.contains(schemaDiagnosticArgument) || commandLineArguments.contains(schemaDiagnosticArgument) {
            return .schemaDiagnostic
        }
        return .production
    }

    static func isUnitTestHost(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        let testHostKeys = [
            "XCTestConfigurationFilePath",
            "XCTestSessionIdentifier"
        ]
        return testHostKeys.contains { key in
            guard let value = environment[key] else { return false }
            return value.isEmpty == false
        }
    }
}

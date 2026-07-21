import Foundation

public enum PrintHandoffPayload: Equatable, Sendable {
    case pdfData(Data)
    case fileURL(URL)
}

public enum PrintHandoffInternalError: Error, Equatable, Sendable {
    case missingOrInvalidPayload
    case presenterFailure
}

public enum PrintHandoffOutcome: Equatable, Sendable {
    case completed
    case canceled
    case failed(PrintHandoffInternalError)
    case unavailable
}

public enum PrintHandoffCoordinatorState: Equatable, Sendable {
    case idle
    case presenting
    case completed
    case canceled
    case failed(PrintHandoffInternalError)
    case unavailable
}

public enum PrintHandoffRequestFailure: Error, Equatable, Sendable {
    case requestAlreadyInProgress
}

public typealias PrintHandoffPresenter = @Sendable (PrintHandoffPayload) async -> PrintHandoffOutcome

public actor PrintHandoffCoordinator {
    public private(set) var state: PrintHandoffCoordinatorState = .idle
    private let presenter: PrintHandoffPresenter

    public init(presenter: @escaping PrintHandoffPresenter) {
        self.presenter = presenter
    }

    public func submit(payload: PrintHandoffPayload) async -> Result<PrintHandoffCoordinatorState, PrintHandoffRequestFailure> {
        if state == .presenting {
            return .failure(.requestAlreadyInProgress)
        }
        
        state = .presenting
        
        let outcome = await presenter(payload)
        
        switch outcome {
        case .completed:
            state = .completed
        case .canceled:
            state = .canceled
        case .failed(let error):
            state = .failed(error)
        case .unavailable:
            state = .unavailable
        }
        
        return .success(state)
    }
}

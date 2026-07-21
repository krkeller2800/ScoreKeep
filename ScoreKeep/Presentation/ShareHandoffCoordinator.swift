import Foundation

public enum ShareHandoffPayload: Equatable, Sendable {
    case fileURL(URL)
    case data(Data)
}

public enum ShareHandoffInternalError: Error, Equatable, Sendable {
    case missingOrInvalidPayload
    case presenterFailure
}

public enum ShareHandoffOutcome: Equatable, Sendable {
    case completed
    case canceled
    case failed(ShareHandoffInternalError)
    case unavailable
}

public enum ShareHandoffCoordinatorState: Equatable, Sendable {
    case idle
    case presenting
    case completed
    case canceled
    case failed(ShareHandoffInternalError)
    case unavailable
}

public enum ShareHandoffRequestFailure: Error, Equatable, Sendable {
    case requestAlreadyInProgress
    case invalidPayload
}

public typealias ShareHandoffPresenter = @Sendable (ShareHandoffPayload) async -> ShareHandoffOutcome

public actor ShareHandoffCoordinator {
    public private(set) var state: ShareHandoffCoordinatorState = .idle
    private let presenter: ShareHandoffPresenter

    public init(presenter: @escaping ShareHandoffPresenter) {
        self.presenter = presenter
    }

    public func submit(payload: ShareHandoffPayload) async -> Result<ShareHandoffCoordinatorState, ShareHandoffRequestFailure> {
        if state == .presenting {
            return .failure(.requestAlreadyInProgress)
        }
        
        if case .data(let d) = payload, d.isEmpty {
            return .failure(.invalidPayload)
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

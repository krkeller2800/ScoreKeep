import Testing
import Foundation
@testable import ScoreKeep

@Suite("Task 8.7 Share Handoff Coordinator")
struct Task87Suite {
    
    actor FakeSharePresenter {
        var callCount = 0
        var lastPayload: ShareHandoffPayload?
        var outcomeToReturn: ShareHandoffOutcome = .completed
        let delayNanoseconds: UInt64

        init(delayNanoseconds: UInt64 = 0) {
            self.delayNanoseconds = delayNanoseconds
        }

        func present(_ payload: ShareHandoffPayload) async -> ShareHandoffOutcome {
            callCount += 1
            lastPayload = payload
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            return outcomeToReturn
        }

        func setOutcome(_ outcome: ShareHandoffOutcome) {
            self.outcomeToReturn = outcome
        }
    }

    @Test("task87ShareHandoffCompletesAndPreservesPreparedPayloads")
    func task87ShareHandoffCompletesAndPreservesPreparedPayloads() async throws {
        let presenter = FakeSharePresenter()
        let coordinator = ShareHandoffCoordinator { await presenter.present($0) }
        
        let initialState = await coordinator.state
        #expect(initialState == .idle)
        
        // Data Payload
        let dataPayload = ShareHandoffPayload.data(Data([0x01, 0x02, 0x03]))
        let result1 = await coordinator.submit(payload: dataPayload)
        
        #expect(result1 == .success(.completed))
        
        let finalState1 = await coordinator.state
        #expect(finalState1 == .completed)
        
        let callCount1 = await presenter.callCount
        #expect(callCount1 == 1)
        
        let lastPayload1 = await presenter.lastPayload
        #expect(lastPayload1 == dataPayload)
        
        // File URL Payload (restartable terminal state)
        let urlPayload = ShareHandoffPayload.fileURL(URL(fileURLWithPath: "/tmp/fake_share.pdf"))
        let result2 = await coordinator.submit(payload: urlPayload)
        
        #expect(result2 == .success(.completed))
        
        let finalState2 = await coordinator.state
        #expect(finalState2 == .completed)
        
        let callCount2 = await presenter.callCount
        #expect(callCount2 == 2)
        
        let lastPayload2 = await presenter.lastPayload
        #expect(lastPayload2 == urlPayload)
        
        // Empty Data Payload (rejected before presenter)
        let emptyDataPayload = ShareHandoffPayload.data(Data())
        let result3 = await coordinator.submit(payload: emptyDataPayload)
        
        #expect(result3 == .failure(.invalidPayload))
        
        let callCount3 = await presenter.callCount
        #expect(callCount3 == 2) // unchanged
    }

    @Test("task87CancellationFailureAndUnavailableRemainDistinct")
    func task87CancellationFailureAndUnavailableRemainDistinct() async throws {
        let presenter = FakeSharePresenter()
        let coordinator = ShareHandoffCoordinator { await presenter.present($0) }
        
        let payload = ShareHandoffPayload.data(Data([0x10]))
        
        // Cancellation
        await presenter.setOutcome(.canceled)
        let cancelResult = await coordinator.submit(payload: payload)
        #expect(cancelResult == .success(.canceled))
        #expect(await coordinator.state == .canceled)
        
        // Presenter Failure
        await presenter.setOutcome(.failed(.presenterFailure))
        let failResult = await coordinator.submit(payload: payload)
        #expect(failResult == .success(.failed(.presenterFailure)))
        #expect(await coordinator.state == .failed(.presenterFailure))
        
        // Unavailable
        await presenter.setOutcome(.unavailable)
        let unavailResult = await coordinator.submit(payload: payload)
        #expect(unavailResult == .success(.unavailable))
        #expect(await coordinator.state == .unavailable)
    }

    @Test("task87RepeatedPresentationDoesNotDuplicateHandoff")
    func task87RepeatedPresentationDoesNotDuplicateHandoff() async throws {
        let presenter = FakeSharePresenter(delayNanoseconds: 50_000_000)
        let coordinator = ShareHandoffCoordinator { await presenter.present($0) }
        let payload = ShareHandoffPayload.data(Data([0x10]))
        
        async let first = coordinator.submit(payload: payload)
        async let second = coordinator.submit(payload: payload)
        
        let results = await [first, second]
        
        let callCount = await presenter.callCount
        #expect(callCount == 1) // Presenter only called once
        
        #expect(results.contains { $0 == .success(.completed) })
        #expect(results.contains { $0 == .failure(.requestAlreadyInProgress) })
    }
}

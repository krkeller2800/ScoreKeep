import Testing
import Foundation
@testable import ScoreKeep

@Suite("Task 8.6 Print Handoff Coordinator")
struct Task86Suite {
    
    actor FakePrintPresenter {
        var callCount = 0
        var lastPayload: PrintHandoffPayload?
        var outcomeToReturn: PrintHandoffOutcome = .completed
        let delayNanoseconds: UInt64

        init(delayNanoseconds: UInt64 = 0) {
            self.delayNanoseconds = delayNanoseconds
        }

        func present(_ payload: PrintHandoffPayload) async -> PrintHandoffOutcome {
            callCount += 1
            lastPayload = payload
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            return outcomeToReturn
        }

        func setOutcome(_ outcome: PrintHandoffOutcome) {
            self.outcomeToReturn = outcome
        }
    }

    @Test("task86PrintHandoffCompletesAndPreservesPayload")
    func task86PrintHandoffCompletesAndPreservesPayload() async throws {
        let presenter = FakePrintPresenter()
        let coordinator = PrintHandoffCoordinator { await presenter.present($0) }
        
        // Idle initial state
        let initialState = await coordinator.state
        #expect(initialState == .idle)
        
        // PDF Data Payload
        let dataPayload = PrintHandoffPayload.pdfData(Data([0x25, 0x50, 0x44, 0x46]))
        let result1 = await coordinator.submit(payload: dataPayload)
        
        #expect(result1 == .success(.completed))
        
        let finalState1 = await coordinator.state
        #expect(finalState1 == .completed)
        
        let callCount1 = await presenter.callCount
        #expect(callCount1 == 1)
        
        let lastPayload1 = await presenter.lastPayload
        #expect(lastPayload1 == dataPayload)
        
        // File URL Payload (restartable terminal state)
        let urlPayload = PrintHandoffPayload.fileURL(URL(fileURLWithPath: "/tmp/fake.pdf"))
        let result2 = await coordinator.submit(payload: urlPayload)
        
        #expect(result2 == .success(.completed))
        
        let finalState2 = await coordinator.state
        #expect(finalState2 == .completed)
        
        let callCount2 = await presenter.callCount
        #expect(callCount2 == 2)
        
        let lastPayload2 = await presenter.lastPayload
        #expect(lastPayload2 == urlPayload)
    }

    @Test("task86CancellationAndFailureRemainDistinct")
    func task86CancellationAndFailureRemainDistinct() async throws {
        let presenter = FakePrintPresenter()
        let coordinator = PrintHandoffCoordinator { await presenter.present($0) }
        
        let payload = PrintHandoffPayload.pdfData(Data())
        
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
        
        // Missing payload failure
        await presenter.setOutcome(.failed(.missingOrInvalidPayload))
        let invalidPayloadResult = await coordinator.submit(payload: payload)
        #expect(invalidPayloadResult == .success(.failed(.missingOrInvalidPayload)))
        #expect(await coordinator.state == .failed(.missingOrInvalidPayload))

        // Unavailable
        await presenter.setOutcome(.unavailable)
        let unavailResult = await coordinator.submit(payload: payload)
        #expect(unavailResult == .success(.unavailable))
        #expect(await coordinator.state == .unavailable)
    }

    @Test("task86RepeatedPresentationDoesNotDuplicateHandoff")
    func task86RepeatedPresentationDoesNotDuplicateHandoff() async throws {
        let presenter = FakePrintPresenter(delayNanoseconds: 50_000_000)
        let coordinator = PrintHandoffCoordinator { await presenter.present($0) }
        let payload = PrintHandoffPayload.pdfData(Data())
        
        async let first = coordinator.submit(payload: payload)
        async let second = coordinator.submit(payload: payload)
        
        let results = await [first, second]
        
        let callCount = await presenter.callCount
        #expect(callCount == 1) // Presenter only called once
        
        #expect(results.contains { $0 == .success(.completed) })
        #expect(results.contains { $0 == .failure(.requestAlreadyInProgress) })
    }
}

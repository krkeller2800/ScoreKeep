import Testing
import Foundation
@testable import ScoreKeep

@Suite("Task 8.8 Failure and Cancellation Test Matrix")
struct Task88Suite {
    
    actor FakeHandoffPresenter {
        var callCount = 0
        var lastPrintPayload: PrintHandoffPayload?
        var lastSharePayload: ShareHandoffPayload?
        
        var printOutcomeToReturn: PrintHandoffOutcome = .completed
        var shareOutcomeToReturn: ShareHandoffOutcome = .completed
        let delayNanoseconds: UInt64
        
        init(delayNanoseconds: UInt64 = 0) {
            self.delayNanoseconds = delayNanoseconds
        }
        
        func presentPrint(_ payload: PrintHandoffPayload) async -> PrintHandoffOutcome {
            callCount += 1
            lastPrintPayload = payload
            if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
            return printOutcomeToReturn
        }
        
        func presentShare(_ payload: ShareHandoffPayload) async -> ShareHandoffOutcome {
            callCount += 1
            lastSharePayload = payload
            if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
            return shareOutcomeToReturn
        }
        
        func setPrintOutcome(_ outcome: PrintHandoffOutcome) {
            self.printOutcomeToReturn = outcome
        }
        func setShareOutcome(_ outcome: ShareHandoffOutcome) {
            self.shareOutcomeToReturn = outcome
        }
    }

    @Test("task88PreHandoffFailuresDoNotInvokePresenters")
    func task88PreHandoffFailuresDoNotInvokePresenters() async throws {
        let presenter = FakeHandoffPresenter()
        let shareCoordinator = ShareHandoffCoordinator { await presenter.presentShare($0) }
        
        let emptySharePayload = ShareHandoffPayload.data(Data())
        let shareResult = await shareCoordinator.submit(payload: emptySharePayload)
        
        #expect(shareResult == .failure(.invalidPayload))
        #expect(await shareCoordinator.state == .idle)
        
        let callCount = await presenter.callCount
        #expect(callCount == 0)
    }

    @Test("task88CancellationUnavailableAndFailureRemainDistinct")
    func task88CancellationUnavailableAndFailureRemainDistinct() async throws {
        let presenter = FakeHandoffPresenter()
        let printCoordinator = PrintHandoffCoordinator { await presenter.presentPrint($0) }
        let shareCoordinator = ShareHandoffCoordinator { await presenter.presentShare($0) }
        
        let printPayload = PrintHandoffPayload.fileURL(URL(fileURLWithPath: "/tmp/fake_print.pdf"))
        let sharePayload = ShareHandoffPayload.fileURL(URL(fileURLWithPath: "/tmp/fake_share.pdf"))
        
        // 1. Failure maps to failed
        await presenter.setPrintOutcome(.failed(.presenterFailure))
        await presenter.setShareOutcome(.failed(.presenterFailure))
        
        let printFailResult = await printCoordinator.submit(payload: printPayload)
        let shareFailResult = await shareCoordinator.submit(payload: sharePayload)
        
        #expect(printFailResult == .success(.failed(.presenterFailure)))
        #expect(await printCoordinator.state == .failed(.presenterFailure))
        #expect(shareFailResult == .success(.failed(.presenterFailure)))
        #expect(await shareCoordinator.state == .failed(.presenterFailure))
        
        // 2. Unavailable maps to unavailable
        await presenter.setPrintOutcome(.unavailable)
        await presenter.setShareOutcome(.unavailable)
        
        let printUnavailResult = await printCoordinator.submit(payload: printPayload)
        let shareUnavailResult = await shareCoordinator.submit(payload: sharePayload)
        
        #expect(printUnavailResult == .success(.unavailable))
        #expect(await printCoordinator.state == .unavailable)
        #expect(shareUnavailResult == .success(.unavailable))
        #expect(await shareCoordinator.state == .unavailable)
        
        // 3. Canceled maps to canceled
        await presenter.setPrintOutcome(.canceled)
        await presenter.setShareOutcome(.canceled)
        
        let printCancelResult = await printCoordinator.submit(payload: printPayload)
        let shareCancelResult = await shareCoordinator.submit(payload: sharePayload)
        
        #expect(printCancelResult == .success(.canceled))
        #expect(await printCoordinator.state == .canceled)
        #expect(shareCancelResult == .success(.canceled))
        #expect(await shareCoordinator.state == .canceled)
        
        // 4. Completed maps to completed
        await presenter.setPrintOutcome(.completed)
        await presenter.setShareOutcome(.completed)
        
        let printCompletedResult = await printCoordinator.submit(payload: printPayload)
        let shareCompletedResult = await shareCoordinator.submit(payload: sharePayload)
        
        #expect(printCompletedResult == .success(.completed))
        #expect(await printCoordinator.state == .completed)
        #expect(shareCompletedResult == .success(.completed))
        #expect(await shareCoordinator.state == .completed)
        
        // Assert payloads match input exactly (unmodified)
        let capturedPrintPayload = await presenter.lastPrintPayload
        #expect(capturedPrintPayload == printPayload)
        
        let capturedSharePayload = await presenter.lastSharePayload
        #expect(capturedSharePayload == sharePayload)

        // Confirm partial/unsupported canonical projection does not mutate into presenter failure
        let diag = CanonicalProjectionDiagnostic(
            "test.code",
            disposition: .unsupported,
            concept: .scoringEvent,
            severity: .unsupported,
            validationDisposition: .unsupported,
            summary: "Test summary"
        )
        let doc = CanonicalPDFDocument(
            family: .hittingStatistics,
            scope: .teamAggregate(teamID: UUID()),
            disposition: .unsupported,
            sections: [.unsupported(reason: .deferredHittingMetrics)],
            diagnostics: [CanonicalPDFDocumentDiagnostic(projectionDiagnostic: diag)]
        )
        #expect(doc.disposition == .unsupported)
        #expect(doc.sections.count == 1)
        #expect(doc.diagnostics.count == 1)
    }

    @Test("task88BusyAndCompletedStatesRemainDeterministic")
    func task88BusyAndCompletedStatesRemainDeterministic() async throws {
        let presenter = FakeHandoffPresenter(delayNanoseconds: 50_000_000)
        let printCoordinator = PrintHandoffCoordinator { await presenter.presentPrint($0) }
        
        let validDataPayload = PrintHandoffPayload.pdfData(Data([0x25, 0x50, 0x44, 0x46]))
        
        // Concurrent requests map to busy
        async let first = printCoordinator.submit(payload: validDataPayload)
        async let second = printCoordinator.submit(payload: validDataPayload)
        
        let results = await [first, second]
        
        // Active presenter invoked exactly once
        let callCount = await presenter.callCount
        #expect(callCount == 1)
        
        #expect(results.contains { $0 == .success(.completed) })
        #expect(results.contains { $0 == .failure(.requestAlreadyInProgress) })
        
        // Later request after terminal state is accepted
        let third = await printCoordinator.submit(payload: validDataPayload)
        #expect(third == .success(.completed))
        
        let finalCallCount = await presenter.callCount
        #expect(finalCallCount == 2)
        
        // Payload values remain exactly unchanged
        let lastPayload = await presenter.lastPrintPayload
        #expect(lastPayload == validDataPayload)
        
        // Repeated runs with identical inputs produce identical states
        let fourth = await printCoordinator.submit(payload: validDataPayload)
        #expect(fourth == .success(.completed))
        
        let finalState = await printCoordinator.state
        #expect(finalState == .completed)
    }
}

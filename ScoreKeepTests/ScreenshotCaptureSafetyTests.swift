import Testing
import UIKit
@testable import ScoreKeep

@Suite("Screenshot capture safety")
struct ScreenshotCaptureSafetyTests {
    @MainActor
    @Test("Detached capture uses the save failure path without crashing")
    func detachedCaptureUsesSaveFailurePath() {
        let maker = ScreenshotMakerUIView(frame: .zero)
        var saveWasCalled = false

        let result = maker.saveScreenshot { image in
            saveWasCalled = true
            #expect(image == nil)
            return nil
        }

        #expect(saveWasCalled)
        #expect(result == nil)
    }
}

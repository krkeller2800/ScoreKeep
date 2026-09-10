import Foundation
import Testing
@testable import ScoreKeep

@Suite("ScoreKeep video help")
struct ScoreKeepHelpTests {
    @Test("manifest decodes DebtScope-style top-level array")
    func manifestDecodesDebtScopeStyleTopLevelArray() throws {
        let videos = try JSONDecoder().decode([ScoreKeepHelpVideo].self, from: validManifestData)

        #expect(videos.count == 1)
        #expect(videos[0].id == "getting-started")
        #expect(videos[0].title == "ScoreKeep Overview")
        #expect(videos[0].subtitle == "A quick tour of scoring, scorecards, statistics, and reports.")
        #expect(videos[0].url(for: .phone)?.absoluteString == "https://media.komakode.com/scorekeep/ScoreKeep-App-Preview-iPhone.mp4")
        #expect(videos[0].url(for: .pad)?.absoluteString == "https://media.komakode.com/scorekeep/ScoreKeep-App-Preview-iPad.mp4")
    }

    @Test("device URL selection follows DebtScope fallback order")
    func deviceURLSelectionFollowsDebtScopeFallbackOrder() throws {
        let allVariants = try decodeVideo("""
        {
            "id": "overview",
            "title": "Overview",
            "url": "https://media.komakode.com/scorekeep/universal.mp4",
            "urls": {
                "iphone": "https://media.komakode.com/scorekeep/iphone.mp4",
                "ipad": "https://media.komakode.com/scorekeep/ipad.mp4"
            }
        }
        """)

        #expect(allVariants.url(for: .phone)?.lastPathComponent == "iphone.mp4")
        #expect(allVariants.url(for: .pad)?.lastPathComponent == "ipad.mp4")
        #expect(allVariants.url(for: .other)?.lastPathComponent == "universal.mp4")

        let ipadOnly = try decodeVideo("""
        {
            "id": "ipad-only",
            "title": "iPad Only",
            "urls": {
                "ipad": "https://media.komakode.com/scorekeep/ipad.mp4"
            }
        }
        """)

        #expect(ipadOnly.url(for: .phone)?.lastPathComponent == "ipad.mp4")
        #expect(ipadOnly.url(for: .pad)?.lastPathComponent == "ipad.mp4")
    }

    @Test("loader returns videos for valid HTTP response")
    func loaderReturnsVideosForValidHTTPResponse() async throws {
        let loader = ScoreKeepHelpManifestLoader(fetch: { url in
            (validManifestData, try httpResponse(url: url, statusCode: 200))
        })

        let state = await loader.loadVideos(device: .phone)

        guard case .loaded(let videos) = state else {
            Issue.record("Expected loaded videos, got \(state)")
            return
        }
        #expect(videos.count == 1)
        #expect(videos[0].title == "ScoreKeep Overview")
    }

    @Test("loader returns empty when no video is playable for device")
    func loaderReturnsEmptyWhenNoVideoIsPlayableForDevice() async throws {
        let data = Data("""
        [
            {
                "id": "missing-url",
                "title": "Missing URL"
            }
        ]
        """.utf8)
        let loader = ScoreKeepHelpManifestLoader(fetch: { url in
            (data, try httpResponse(url: url, statusCode: 200))
        })

        let state = await loader.loadVideos(device: .phone)

        #expect(state == .empty)
    }

    @Test("loader returns failure for network error, HTTP error, and invalid JSON")
    func loaderReturnsFailureForNetworkHTTPAndInvalidJSON() async throws {
        struct TestError: Error {}

        let networkFailure = ScoreKeepHelpManifestLoader(fetch: { _ in
            throw TestError()
        })
        #expect(await networkFailure.loadVideos(device: .phone) == .failed(ScoreKeepHelpManifestLoader.genericFailureMessage))

        let httpFailure = ScoreKeepHelpManifestLoader(fetch: { url in
            (validManifestData, try httpResponse(url: url, statusCode: 503))
        })
        #expect(await httpFailure.loadVideos(device: .phone) == .failed(ScoreKeepHelpManifestLoader.genericFailureMessage))

        let invalidJSON = ScoreKeepHelpManifestLoader(fetch: { url in
            (Data("not json".utf8), try httpResponse(url: url, statusCode: 200))
        })
        #expect(await invalidJSON.loadVideos(device: .phone) == .failed(ScoreKeepHelpManifestLoader.genericFailureMessage))
    }

    @Test("root Help route resolves to video Help")
    func rootHelpRouteResolvesToVideoHelp() {
        #expect(ScoreKeepHelpRoute.destination == .videoHelp)
    }

    @Test("video Help uses landscape preview aspect")
    func videoHelpUsesLandscapePreviewAspect() {
        #expect(ScoreKeepHelpView.landscapeVideoAspectRatio > 2.0)
    }

    @Test("video Help presents full screen above root navigation with one Done exit")
    func videoHelpPresentsFullScreenAboveRootNavigationWithOneDoneExit() throws {
        let helpView = try sourceText(at: "ScoreKeep/Common/ScoreKeepHelpView.swift")

        #expect(ScoreKeepHelpView.enterFullScreenSystemImage == "arrow.up.left.and.arrow.down.right")
        #expect(helpView.contains(".fullScreenCover(isPresented: $isShowingFullScreenPlayer)"))
        #expect(helpView.contains("private struct ScoreKeepFullScreenHelpPlayer: View"))
        #expect(helpView.contains("Button(\"Done\")"))
        #expect(!helpView.contains("Label(\"Exit Full Screen\""))
        #expect(helpView.contains("PlayerViewControllerWrapper(player: player)"))
        #expect(!helpView.contains(".aspectRatio(ScoreKeepHelpView.landscapeVideoAspectRatio, contentMode: .fit)"))
        #expect(helpView.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)"))
        #expect(helpView.contains("controller.videoGravity = .resizeAspect"))
    }

    @Test("existing root Help routes use video Help instead of the PDF manual")
    func existingRootHelpRoutesUseVideoHelpInsteadOfPDFManual() throws {
        let startView = try sourceText(at: "ScoreKeep/List Data/StartView.swift")
        let startPhoneView = try sourceText(at: "ScoreKeep/List Data/StartPhoneView.swift")
        let settingsView = try sourceText(at: "ScoreKeep/Common/ScoreKeepSettingsEntryPoint.swift")

        #expect(startView.contains("ScoreKeepHelpRoute()"))
        #expect(startPhoneView.contains("ScoreKeepHelpRoute()"))
        #expect(settingsView.contains("Button(\"Help\")"))
        #expect(!startView.contains("PdfView()"))
        #expect(!startPhoneView.contains("PdfView()"))
        #expect(!settingsView.contains("Help Documentation"))
    }

    @Test("production endpoint is the published ScoreKeep manifest")
    func productionEndpointIsPublishedScoreKeepManifest() {
        #expect(ScoreKeepHelpManifestLoader.productionFeedURL.absoluteString == "https://komakode.com/videos/ScoreKeep-help-videos.json")
    }

    @Test("iPad navigation policy separates sidebar roots from full-width workflows")
    func iPadNavigationPolicySeparatesSidebarRootsFromFullWidthWorkflows() throws {
        let startView = try sourceText(at: "ScoreKeep/List Data/StartView.swift")
        let scoreContentView = try sourceText(at: "ScoreKeep/Content Views/ScoreContentView.swift")

        #expect(ScoreKeepIPadNavigationPolicy.sidebarRootVisibility == .doubleColumn)
        #expect(ScoreKeepIPadNavigationPolicy.fullWidthWorkflowVisibility == .detailOnly)
        #expect(startView.contains("@State var columnVisibility = ScoreKeepIPadNavigationPolicy.sidebarRootVisibility"))
        #expect(startView.contains("private var sidebarToggleRemoval: ToolbarDefaultItemKind?"))
        #expect(startView.contains("columnVisibility == ScoreKeepIPadNavigationPolicy.sidebarRootVisibility ? .sidebarToggle : nil"))
        #expect(startView.contains(".toolbar(removing: sidebarToggleRemoval)"))
        #expect(startView.contains("columnVisibility = ScoreKeepIPadNavigationPolicy.sidebarRootVisibility"))
        #expect(startView.contains("columnVisibility = ScoreKeepIPadNavigationPolicy.fullWidthWorkflowVisibility"))
        #expect(scoreContentView.contains("hideSidebarForLiveScoringIfNeeded()"))
        #expect(scoreContentView.contains("restoreSidebarAtRootIfNeeded()"))
        #expect(scoreContentView.contains("columnVisability = ScoreKeepIPadNavigationPolicy.fullWidthWorkflowVisibility"))
        #expect(scoreContentView.contains("columnVisability = ScoreKeepIPadNavigationPolicy.sidebarRootVisibility"))
    }

    private var validManifestData: Data {
        Data("""
        [
            {
                "id": "getting-started",
                "title": "ScoreKeep Overview",
                "subtitle": "A quick tour of scoring, scorecards, statistics, and reports.",
                "urls": {
                    "iphone": "https://media.komakode.com/scorekeep/ScoreKeep-App-Preview-iPhone.mp4",
                    "ipad": "https://media.komakode.com/scorekeep/ScoreKeep-App-Preview-iPad.mp4"
                }
            }
        ]
        """.utf8)
    }

    private func decodeVideo(_ json: String) throws -> ScoreKeepHelpVideo {
        try JSONDecoder().decode(ScoreKeepHelpVideo.self, from: Data(json.utf8))
    }

    private func httpResponse(url: URL, statusCode: Int) throws -> HTTPURLResponse {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        return try #require(response)
    }

    private func sourceText(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

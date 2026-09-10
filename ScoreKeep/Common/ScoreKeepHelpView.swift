import SwiftUI
import AVKit
#if canImport(UIKit)
import UIKit
#endif

struct ScoreKeepHelpVideo: Identifiable, Hashable, Decodable {
    let id: String
    let title: String
    let subtitle: String?
    let durationSeconds: TimeInterval?
    let iphoneURL: URL?
    let ipadURL: URL?
    let universalURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, duration, durationSeconds, seconds, url, urls, iphoneURL, ipadURL
    }

    enum URLKeys: String, CodingKey {
        case iphone, ipad
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        durationSeconds = Self.decodeDuration(from: container)
        universalURL = try container.decodeIfPresent(URL.self, forKey: .url)

        if let urlsContainer = try? container.nestedContainer(keyedBy: URLKeys.self, forKey: .urls) {
            iphoneURL = try urlsContainer.decodeIfPresent(URL.self, forKey: .iphone)
            ipadURL = try urlsContainer.decodeIfPresent(URL.self, forKey: .ipad)
        } else {
            iphoneURL = try container.decodeIfPresent(URL.self, forKey: .iphoneURL)
            ipadURL = try container.decodeIfPresent(URL.self, forKey: .ipadURL)
        }
    }

    func url(for device: ScoreKeepHelpDevice) -> URL? {
        switch device {
        case .phone:
            iphoneURL ?? universalURL ?? ipadURL
        case .pad:
            ipadURL ?? universalURL ?? iphoneURL
        case .other:
            universalURL ?? ipadURL ?? iphoneURL
        }
    }

    var urlForCurrentDevice: URL? {
        url(for: .current)
    }

    var isAvailableOnCurrentDevice: Bool {
        urlForCurrentDevice != nil
    }

    private static func decodeDuration(from container: KeyedDecodingContainer<CodingKeys>) -> TimeInterval? {
        for key in [CodingKeys.durationSeconds, .seconds, .duration] {
            if let seconds = try? container.decode(TimeInterval.self, forKey: key), seconds.isFinite, seconds > 0 {
                return seconds
            }

            if let text = try? container.decode(String.self, forKey: key),
               let seconds = parseDuration(text),
               seconds.isFinite,
               seconds > 0 {
                return seconds
            }
        }

        return nil
    }

    private static func parseDuration(_ text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = TimeInterval(trimmed) {
            return seconds
        }

        let parts = trimmed.split(separator: ":").compactMap { TimeInterval($0) }
        guard parts.count == trimmed.split(separator: ":").count else { return nil }

        switch parts.count {
        case 2:
            return parts[0] * 60 + parts[1]
        case 3:
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default:
            return nil
        }
    }
}

enum ScoreKeepHelpDevice {
    case phone
    case pad
    case other

    static var current: ScoreKeepHelpDevice {
        #if canImport(UIKit)
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return .phone
        case .pad:
            return .pad
        default:
            return .other
        }
        #else
        return .other
        #endif
    }
}

enum ScoreKeepHelpLoadState: Equatable {
    case loading
    case loaded([ScoreKeepHelpVideo])
    case empty
    case failed(String)

    var videos: [ScoreKeepHelpVideo] {
        if case .loaded(let videos) = self {
            return videos
        }
        return []
    }
}

struct ScoreKeepHelpManifestLoader {
    static let productionFeedURL = URL(string: "https://komakode.com/videos/ScoreKeep-help-videos.json")!
    static let genericFailureMessage = "Couldn't load help videos."

    let feedURL: URL
    let fetch: @Sendable (URL) async throws -> (Data, URLResponse)

    init(
        feedURL: URL = Self.productionFeedURL,
        fetch: @escaping @Sendable (URL) async throws -> (Data, URLResponse) = { url in
            try await URLSession.shared.data(from: url)
        }
    ) {
        self.feedURL = feedURL
        self.fetch = fetch
    }

    func loadVideos(device: ScoreKeepHelpDevice = .current) async -> ScoreKeepHelpLoadState {
        do {
            let (data, response) = try await fetch(feedURL)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return .failed(Self.genericFailureMessage)
            }

            let decoded = try JSONDecoder().decode([ScoreKeepHelpVideo].self, from: data)
            let available = decoded.filter { $0.url(for: device) != nil }
            return available.isEmpty ? .empty : .loaded(available)
        } catch {
            return .failed(Self.genericFailureMessage)
        }
    }
}

enum ScoreKeepHelpDestination: Equatable {
    case videoHelp
}

struct ScoreKeepHelpRoute: View {
    static let destination = ScoreKeepHelpDestination.videoHelp

    var body: some View {
        ScoreKeepHelpView()
    }
}

struct ScoreKeepHelpView: View {
    static let landscapeVideoAspectRatio: CGFloat = 720.0 / 332.0
    static let enterFullScreenSystemImage = "arrow.up.left.and.arrow.down.right"

    @Environment(\.dismiss) private var dismiss
    @State private var loadState: ScoreKeepHelpLoadState = .loading
    @State private var selectedVideo: ScoreKeepHelpVideo?
    @State private var player: AVPlayer?
    @State private var playerItemStatusObservation: NSKeyValueObservation?
    @State private var isShowingFullScreenPlayer = false
    @State private var isPlaying = false
    @State private var playbackErrorMessage: String?

    private let loader: ScoreKeepHelpManifestLoader

    init(loader: ScoreKeepHelpManifestLoader = ScoreKeepHelpManifestLoader()) {
        self.loader = loader
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Help")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            isShowingFullScreenPlayer = true
                        } label: {
                            Image(systemName: Self.enterFullScreenSystemImage)
                        }
                        .accessibilityLabel("Enter Full Screen")
                        .disabled(player == nil)

                        Button {
                            restartSelectedVideo()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .accessibilityLabel("Restart Video")
                        .disabled(player == nil)

                        Button {
                            togglePlayback()
                        } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        }
                        .accessibilityLabel(isPlaying ? "Pause" : "Play")
                        .disabled(player == nil)
                    }
                }
                .task {
                    if case .loading = loadState {
                        await loadVideos()
                    }
                }
                .onDisappear {
                    player?.pause()
                    player = nil
                    playerItemStatusObservation = nil
                    isShowingFullScreenPlayer = false
                    isPlaying = false
                }
                .fullScreenCover(isPresented: $isShowingFullScreenPlayer) {
                    ScoreKeepFullScreenHelpPlayer(
                        player: player,
                        isPlaying: $isPlaying,
                        onRestart: restartSelectedVideo
                    )
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView("Loading videos...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Help Videos Unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await loadVideos() }
                }
            }
        case .empty:
            ContentUnavailableView(
                "No Videos",
                systemImage: "play.rectangle.on.rectangle",
                description: Text("No help videos are available for this device yet.")
            )
        case .loaded(let videos):
            VStack(spacing: 0) {
                playerPanel
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))

                Divider()

                List(videos) { video in
                    Button {
                        select(video)
                    } label: {
                        HelpVideoRow(
                            video: video,
                            isSelected: selectedVideo?.id == video.id,
                            durationText: durationText(for: video)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .refreshable {
                    await loadVideos()
                }
            }
        }
    }

    @ViewBuilder
    private var playerPanel: some View {
        if player != nil {
            VStack(spacing: 8) {
                PlayerViewControllerWrapper(player: player)
                    .aspectRatio(Self.landscapeVideoAspectRatio, contentMode: .fit)
                    .background(Color(.secondarySystemBackground))

                if let playbackErrorMessage {
                    Text(playbackErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
        } else {
            ContentUnavailableView(
                "No Video Selected",
                systemImage: "play.rectangle",
                description: Text("Choose a tutorial below.")
            )
            .aspectRatio(Self.landscapeVideoAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
        }
    }

    private func loadVideos() async {
        loadState = .loading
        playbackErrorMessage = nil
        selectedVideo = nil
        player?.pause()
        player = nil
        playerItemStatusObservation = nil
        isShowingFullScreenPlayer = false
        isPlaying = false

        let nextState = await loader.loadVideos()
        loadState = nextState

        if case .loaded(let videos) = nextState, let firstVideo = videos.first {
            select(firstVideo)
        }
    }

    private func select(_ video: ScoreKeepHelpVideo) {
        guard let url = video.urlForCurrentDevice else { return }
        selectedVideo = video
        playbackErrorMessage = nil
        player?.pause()
        playerItemStatusObservation = nil

        let item = AVPlayerItem(url: url)
        playerItemStatusObservation = item.observe(\.status, options: [.new]) { item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in
                playbackErrorMessage = "This video could not be played."
                isPlaying = false
            }
        }
        player = AVPlayer(playerItem: item)
        player?.play()
        isPlaying = true
    }

    private func restartSelectedVideo() {
        player?.seek(to: .zero)
        player?.play()
        isPlaying = player != nil
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func durationText(for video: ScoreKeepHelpVideo) -> String? {
        guard let seconds = video.durationSeconds else { return nil }
        let totalSeconds = max(1, Int(seconds.rounded()))
        if totalSeconds < 60 {
            return "\(totalSeconds) sec"
        }
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

}

private struct ScoreKeepFullScreenHelpPlayer: View {
    @Environment(\.dismiss) private var dismiss

    let player: AVPlayer?
    @Binding var isPlaying: Bool
    let onRestart: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            PlayerViewControllerWrapper(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .ignoresSafeArea()

            HStack(spacing: 12) {
                Button {
                    onRestart()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Restart Video")
                .disabled(player == nil)

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                .disabled(player == nil)

                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
}

private struct PlayerViewControllerWrapper: UIViewControllerRepresentable {
    let player: AVPlayer?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = .resizeAspect
        controller.showsPlaybackControls = true
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .clear
    }
}

private struct HelpVideoRow: View {
    let video: ScoreKeepHelpVideo
    let isSelected: Bool
    let durationText: String?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "play.rectangle.fill")
                .font(.title3)
                .foregroundStyle(isSelected ? .green : .blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if video.subtitle != nil || durationText != nil {
                    HStack(spacing: 4) {
                        if let subtitle = video.subtitle {
                            Text(subtitle)
                                .lineLimit(2)
                        }
                        if let durationText {
                            if video.subtitle != nil {
                                Text("-")
                            }
                            Text(durationText)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "speaker.wave.2" : "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
    }
}

#Preview {
    ScoreKeepHelpRoute()
}

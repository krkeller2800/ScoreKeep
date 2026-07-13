import Foundation
import SwiftUI

// MARK: - Models

struct RemoteMessageEnvelope: Codable {
    let messages: [RemoteMessage]
    let version: Int?
}

struct RemoteMessage: Codable, Identifiable, Equatable {
    let id: String
    let ctaTitle: String?
    let ctaURL: String?
    let title: String
    let body: String
    let start: Date
    let end: Date
}

// MARK: - Announcement Center

@MainActor
final class AnnouncementCenter: ObservableObject {
    @Published var currentMessage: RemoteMessage?
    @Published var isPresenting: Bool = false

    // Persist dismissed IDs so a message is only shown until dismissed
    @AppStorage("dismissedMessageIDsData") private var dismissedIDsData: Data = Data()
    private var dismissedIDs: Set<String> = []

    // Compatibility endpoint used by released ScoreKeep versions.
    // Keep /Teams/message.json and its expected JSON shape stable; website routing must not replace it with HTML.
    private let messagesURL = URL(string: "https://komakode.com/Teams/message.json")!

    init() {
        loadDismissedIDs()
    }

    // MARK: - Public API

    func refresh() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: messagesURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(RemoteMessageEnvelope.self, from: data)
            let now = Date()
            // Pick the first active, non-dismissed message
            let active = envelope.messages.first { msg in
                msg.start <= now && now <= msg.end && !dismissedIDs.contains(msg.id)
            }
            currentMessage = active
            isPresenting = (active != nil)
        } catch {
            // Silently ignore failures; we simply won't present a message
        }
    }

    func dismissCurrent() {
        guard let id = currentMessage?.id else {
            isPresenting = false
            return
        }
        dismissedIDs.insert(id)
        saveDismissedIDs()
        currentMessage = nil
        isPresenting = false
    }

    // MARK: - Persistence

    private func loadDismissedIDs() {
        if dismissedIDsData.isEmpty {
            dismissedIDs = []
            return
        }
        if let arr = try? JSONDecoder().decode([String].self, from: dismissedIDsData) {
            dismissedIDs = Set(arr)
        } else {
            dismissedIDs = []
        }
    }

    private func saveDismissedIDs() {
        if let data = try? JSONEncoder().encode(Array(dismissedIDs)) {
            dismissedIDsData = data
        }
    }
}

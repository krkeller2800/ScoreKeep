import SwiftUI

struct AnnouncementSheet: View {
    @EnvironmentObject var announcements: AnnouncementCenter
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let msg = announcements.currentMessage {
            content(for: msg)
        } else {
            // Safety: should not happen while presented, but keep an empty view
            Color.clear
        }
    }

    @ViewBuilder
    private func content(for msg: RemoteMessage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "megaphone.fill").foregroundStyle(.blue)
                Text(msg.title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                Text(msg.body)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if let cta = msg.ctaURL, let url = URL(string: cta), let title = msg.ctaTitle, !title.isEmpty {
                    Button(title) {
                        openURL(url)
                        announcements.dismissCurrent()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                Button("Dismiss") {
                    announcements.dismissCurrent()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

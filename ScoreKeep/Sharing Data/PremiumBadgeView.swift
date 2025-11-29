import SwiftUI

struct PremiumBadgeView: View {
    // Use isCompact to adapt sizing for iPhone toolbars vs iPad
    var isCompact: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .imageScale(isCompact ? .small : .medium)
                .foregroundStyle(.green)

            Text("Season Pass")
                .font(isCompact ? .caption2 : .caption)
                .foregroundStyle(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.15), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("Season Pass active")
    }
}

#Preview {
    VStack(spacing: 12) {
        PremiumBadgeView(isCompact: true)
        PremiumBadgeView(isCompact: false)
    }
    .padding()
}

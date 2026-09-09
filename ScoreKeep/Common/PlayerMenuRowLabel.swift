import SwiftUI

struct PlayerMenuRowLabel: View {
    let player: Player
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isSelected {
                Image(systemName: "checkmark")
                    .frame(width: 16)
            } else {
                Color.clear
                    .frame(width: 16, height: 16)
            }

            Text(player.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)

            Spacer(minLength: 8)

            Text(Self.trailingText(for: player))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityDescription(for: player, isSelected: isSelected))
    }

    static func trailingText(for player: Player) -> String {
        [numberText(for: player), player.batDir]
            .filter { $0.isEmpty == false }
            .joined(separator: " | ")
    }

    static func accessibilityDescription(for player: Player, isSelected: Bool) -> String {
        var parts: [String] = []
        if isSelected {
            parts.append("Selected")
        }
        parts.append(player.name)
        if player.number.isEmpty == false {
            parts.append("number \(player.number)")
        }
        if player.batDir.isEmpty == false {
            parts.append("bats \(player.batDir)")
        }
        return parts.joined(separator: ", ")
    }

    private static func numberText(for player: Player) -> String {
        player.number.isEmpty ? "" : "#\(player.number)"
    }
}

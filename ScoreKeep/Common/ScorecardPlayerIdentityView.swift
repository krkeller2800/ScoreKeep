import SwiftUI

enum ScorecardPlayerIdentityDeviceClass {
    case iPhoneLandscape
    case iPadLandscape
}

struct ScorecardPlayerIdentityPresentation: Equatable {
    let name: String
    let metadata: String
    let accessibilityLabel: String
}

enum ScorecardPlayerIdentityPolicy {
    static func presentation(
        for player: Player,
        battingOrder: Int,
        deviceClass: ScorecardPlayerIdentityDeviceClass,
        isIncoming: Bool,
        isReplaced: Bool,
        isEditable: Bool,
        isLocked: Bool
    ) -> ScorecardPlayerIdentityPresentation {
        ScorecardPlayerIdentityPresentation(
            name: player.name,
            metadata: metadata(for: player, deviceClass: deviceClass),
            accessibilityLabel: accessibilityDescription(
                for: player,
                battingOrder: battingOrder,
                isIncoming: isIncoming,
                isReplaced: isReplaced,
                isEditable: isEditable,
                isLocked: isLocked
            )
        )
    }

    static func metadata(for player: Player, deviceClass: ScorecardPlayerIdentityDeviceClass) -> String {
        var parts: [String] = []
        if player.number.isEmpty == false {
            parts.append("#\(player.number)")
        }
        if player.batDir.isEmpty == false {
            parts.append("Bats \(player.batDir)")
        }
        if deviceClass == .iPadLandscape, player.position.isEmpty == false {
            parts.append(player.position)
        }
        return parts.joined(separator: "  ")
    }

    static func accessibilityDescription(
        for player: Player,
        battingOrder: Int,
        isIncoming: Bool,
        isReplaced: Bool,
        isEditable: Bool,
        isLocked: Bool
    ) -> String {
        var parts = [player.name]
        if player.number.isEmpty == false {
            parts.append("number \(player.number)")
        }
        if player.batDir.isEmpty == false {
            parts.append("bats \(player.batDir)")
        }
        if player.position.isEmpty == false {
            parts.append("position \(player.position)")
        }
        parts.append("batting order \(battingOrder)")
        if isIncoming {
            parts.append("substitute")
        }
        if isReplaced {
            parts.append("replaced")
        }
        if isEditable {
            parts.append("Player can be corrected")
        }
        if isLocked {
            parts.append("Locked after game participation")
        }
        return parts.joined(separator: ", ")
    }
}

struct ScorecardPlayerIdentityView: View {
    let presentation: ScorecardPlayerIdentityPresentation
    let isIncoming: Bool
    let isReplaced: Bool
    let showsMenuIndicator: Bool

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .strikethrough(isReplaced)

                Text(presentation.metadata)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsMenuIndicator {
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, isIncoming ? 14 : 5)
        .padding(.trailing, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

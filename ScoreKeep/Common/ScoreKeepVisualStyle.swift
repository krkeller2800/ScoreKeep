import SwiftUI

struct ScoreKeepVisualStyle {
    static let background = Color(.systemGroupedBackground)
    static let contentSurface = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(white: 0.16, alpha: 1.0) : UIColor.systemBackground
    })
    static let elevatedSurface = Color(.tertiarySystemGroupedBackground)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let disabledText = Color.secondary.opacity(0.62)
    static let accent = Color.accentColor
    static let selectedFill = Color.accentColor.opacity(0.16)
    static let disabledFill = Color(.tertiarySystemFill)
    static let separator = Color(.separator).opacity(0.72)
    static let tableHeaderBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.systemOrange.withAlphaComponent(0.22) : UIColor.systemYellow.withAlphaComponent(0.18)
    })
    static let tableHeaderForeground = Color(.label)
    static let infoBannerBackground = Color.accentColor.opacity(0.14)
    static let infoBannerForeground = Color.accentColor
    static let logoSurface = Color(.secondarySystemBackground)
    static let adaptiveLogoTile = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(white: 0.35, alpha: 1.0) : UIColor(white: 0.95, alpha: 1.0)
    })
    static let logoTileBorder = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.separator.withAlphaComponent(0.72) : UIColor.separator.withAlphaComponent(0.58)
    })
}

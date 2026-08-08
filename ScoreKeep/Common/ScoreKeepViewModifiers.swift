import SwiftUI

public extension View {
    func scorebookSingleLineText() -> some View {
        self
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .truncationMode(.tail)
    }

    func scorebookMultiLineText() -> some View {
        self
            .lineLimit(nil)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)
    }

    func scorebookTrailingSeparator() -> some View {
        overlay(alignment: .trailing) {
            Rectangle()
                .fill(ScoreKeepVisualStyle.separator)
                .frame(width: 1)
        }
    }

    func scorebookInputField() -> some View {
        self
            .foregroundStyle(ScoreKeepVisualStyle.primaryText)
            .tint(ScoreKeepVisualStyle.accent)
    }

    func scorebookNameField() -> some View {
        self
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.words)
    }

    func scorebookInputPromptOverlay(_ title: String, isVisible: Bool) -> some View {
        overlay(alignment: .leading) {
            if isVisible {
                scorebookInputPrompt(title)
                    .padding(.leading, scorebookInputPromptOverlayLeadingInset)
                    .allowsHitTesting(false)
            }
        }
    }
}

public func scorebookInputPrompt(_ title: String) -> Text {
    Text(title)
        .foregroundStyle(scorebookInputPromptColor)
}

private let scorebookInputPromptColor = Color(UIColor { traitCollection in
    traitCollection.userInterfaceStyle == .dark
        ? UIColor(white: 0.72, alpha: 1.0)
        : UIColor.secondaryLabel
})

private let scorebookInputPromptOverlayLeadingInset: CGFloat = 6

public func scorebookHeaderCell(_ title: String, semantic: Bool = true, lineLimit: Int? = 1, scaleFactor: CGFloat = 0.75) -> some View {
    Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(ScoreKeepVisualStyle.primaryText)
        .lineLimit(lineLimit)
        .minimumScaleFactor(scaleFactor)
        .truncationMode(.tail)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ScoreKeepVisualStyle.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
        )
        .padding(2)
}

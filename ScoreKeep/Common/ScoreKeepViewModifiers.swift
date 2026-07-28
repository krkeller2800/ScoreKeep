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
}

public func scorebookHeaderCell(_ title: String, semantic: Bool = true) -> some View {
    Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(ScoreKeepVisualStyle.primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
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

import PhotosUI
import SwiftData
import SwiftUI

struct PlayerFormDraft: Hashable {
    var name: String
    var number: String
    var position: String
    var batDir: String
    var batOrder: Int
    var teamIdentity: UUID?
    var teamName: String
    var photoData: Data?

    static func empty(for team: Team) -> PlayerFormDraft {
        PlayerFormDraft(
            name: "",
            number: "",
            position: "",
            batDir: "",
            batOrder: 99,
            teamIdentity: team.ident,
            teamName: team.name,
            photoData: nil
        )
    }

    init(
        name: String,
        number: String,
        position: String,
        batDir: String,
        batOrder: Int,
        teamIdentity: UUID?,
        teamName: String,
        photoData: Data? = nil
    ) {
        self.name = name
        self.number = number
        self.position = position
        self.batDir = batDir
        self.batOrder = PlayerRosterBattingOrder.normalizedRosterOrder(batOrder)
        self.teamIdentity = teamIdentity
        self.teamName = teamName
        self.photoData = photoData
    }

    init(player: Player, fallbackTeam: Team) {
        let selectedTeam = player.team ?? fallbackTeam
        self.init(
            name: player.name,
            number: player.number,
            position: player.position,
            batDir: player.batDir,
            batOrder: player.batOrder,
            teamIdentity: selectedTeam.ident,
            teamName: selectedTeam.name,
            photoData: player.photo
        )
    }

    var hasMeaningfulChanges: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
        number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
        position.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
        batDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
        batOrder != 99 ||
        photoData != nil
    }

    var normalizedPosition: String {
        CanonicalDefensivePosition.normalizedDisplayValue(for: position)
    }
}

struct PlayerDraftValidation: Hashable {
    let trimmedName: String
    let message: String?

    var canSave: Bool { message == nil }

    static func validate(playerName: String) -> PlayerDraftValidation {
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            return PlayerDraftValidation(trimmedName: trimmedName, message: "Enter a player name before saving the player.")
        }
        return PlayerDraftValidation(trimmedName: trimmedName, message: nil)
    }
}

enum PlayerRosterBattingOrder {
    static let notHitting = 99

    static func normalizedRosterOrder(_ order: Int) -> Int {
        (1...19).contains(order) ? order : notHitting
    }

    static func nextRosterOrder(after players: [Player]) -> Int {
        let maxOrder = players.map(\.batOrder).filter { (1...18).contains($0) }.max() ?? 0
        return maxOrder + 1
    }

    static func resolvedOrderForSave(requestedOrder: Int, existingPlayers: [Player]) -> Int {
        if (1...19).contains(requestedOrder) {
            return requestedOrder
        }
        return nextRosterOrder(after: existingPlayers)
    }
}

@MainActor
struct PlayerFormContent: View {
    @Binding var draft: PlayerFormDraft
    let teams: [Team]
    let allowsTeamSelection: Bool

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoErrorMessage = ""
    @State private var showingPhotoError = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let orders = [
        "Not Hitting", "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th",
        "10th", "11th", "12th", "13th", "14th", "15th", "16th", "17th", "18th", "19th"
    ]

    var body: some View {
        Group {
            if useWideLayout {
                wideLayout
            } else {
                compactLayout
            }
        }
        .alert(photoErrorMessage, isPresented: $showingPhotoError) {
            Button("OK", role: .cancel) { }
        }
        .onChange(of: selectedPhotoItem, loadSelectedPhoto)
    }

    private var useWideLayout: Bool {
        UIDevice.type != "iPhone" && horizontalSizeClass != .compact
    }

    private var compactLayout: some View {
        GeometryReader { geometry in
            if useCompactHorizontalLayout(for: geometry.size) {
                compactHorizontalLayout
            } else {
                compactStackedLayout
            }
        }
    }

    private func useCompactHorizontalLayout(for size: CGSize) -> Bool {
        size.width >= 560 && size.width > size.height
    }

    private var compactStackedLayout: some View {
        Form {
            fieldsSection
            compactPhotoSection
        }
        .scrollContentBackground(.hidden)
        .background(ScoreKeepVisualStyle.background)
    }

    private var compactHorizontalLayout: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 8) {
                        photoPreview
                            .frame(width: 88, height: 88)
                        compactPhotoControls
                    }
                    .frame(width: 190)

                    compactHorizontalFieldsContent
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ScoreKeepVisualStyle.background)
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .center, spacing: 12) {
                photoPreview
                    .frame(width: 190, height: 190)
                photoControls
            }
            .frame(width: 240)

            VStack(spacing: 14) {
                fieldsSectionContent
            }
            .frame(maxWidth: 560)
        }
        .padding(24)
        .frame(maxWidth: 860, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ScoreKeepVisualStyle.background)
    }

    private var fieldsSection: some View {
        Section {
            fieldsSectionContent
        }
    }

    private var fieldsSectionContent: some View {
        Group {
            nameField
            numberField
            positionField
            battingDirectionField
            battingOrderPicker
            teamControl
        }
    }

    private var compactHorizontalFieldsContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                nameField
                numberField
                    .frame(width: 112)
            }

            HStack(spacing: 10) {
                positionField
                battingDirectionField
                    .frame(width: 160)
            }

            HStack(spacing: 10) {
                battingOrderPicker
                teamControl
            }
        }
    }

    private var nameField: some View {
        TextField("Name", text: $draft.name, prompt: scorebookInputPrompt("Name"))
            .playerEditableTextField()
            .textInputAutocapitalization(.words)
            .textContentType(.name)
            .accessibilityLabel("Player name")
            .accessibilityIdentifier("player_name_field")
    }

    private var numberField: some View {
        TextField("Number", text: $draft.number, prompt: scorebookInputPrompt("Number"))
            .playerEditableTextField()
            .accessibilityLabel("Player number")
            .accessibilityIdentifier("player_number_field")
    }

    private var positionField: some View {
        TextField("Position", text: $draft.position, prompt: scorebookInputPrompt("Position"))
            .playerEditableTextField()
            .textInputAutocapitalization(.characters)
            .textContentType(.none)
            .accessibilityLabel("Player position")
            .accessibilityIdentifier("player_position_field")
    }

    private var battingDirectionField: some View {
        TextField("Batting Direction", text: $draft.batDir, prompt: scorebookInputPrompt("Batting Direction"))
            .playerEditableTextField()
            .textInputAutocapitalization(.characters)
            .textContentType(.none)
            .accessibilityLabel("Batting direction")
            .accessibilityIdentifier("player_batting_direction_field")
    }

    private var battingOrderPicker: some View {
        Picker("Batting Order", selection: $draft.batOrder) {
            ForEach(Array(orders.enumerated()), id: \.offset) { index, order in
                Text(order).tag(index == 0 ? PlayerRosterBattingOrder.notHitting : index)
            }
        }
        .pickerStyle(.menu)
        .tint(ScoreKeepVisualStyle.accent)
        .accessibilityLabel("Batting Order")
        .accessibilityIdentifier("player_batting_order_picker")
    }

    @ViewBuilder
    private var teamControl: some View {
        if allowsTeamSelection {
            Picker("Team", selection: $draft.teamIdentity) {
                Text("Unknown Team").tag(Optional<UUID>.none)
                if teams.isEmpty == false {
                    Divider()
                    ForEach(teams) { team in
                        if team.name.isEmpty == false {
                            Text(team.name).tag(Optional(team.ident))
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .tint(ScoreKeepVisualStyle.accent)
            .onChange(of: draft.teamIdentity) { _, newValue in
                draft.teamName = teams.first { $0.ident == newValue }?.name ?? ""
            }
        } else {
            LabeledContent("Team", value: draft.teamName.isEmpty ? "Unknown Team" : draft.teamName)
        }
    }

    private var compactPhotoSection: some View {
        Section {
            HStack(spacing: 14) {
                photoPreview
                    .frame(width: 84, height: 84)
                compactPhotoControls
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
    }

    private var photoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(ScoreKeepVisualStyle.logoSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ScoreKeepVisualStyle.logoTileBorder, lineWidth: 1)
                )

            if let photoData = draft.photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: "person.crop.square")
                    .font(.system(size: 40))
                    .foregroundStyle(ScoreKeepVisualStyle.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(draft.photoData == nil ? "No player photo" : "Player photo preview")
    }

    private var photoControls: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Photos", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Choose player photo from Photos")

            Button {
                pastePhoto()
            } label: {
                Label("Paste", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Paste player photo")
        }
    }

    private var compactPhotoControls: some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Photos", systemImage: "photo.on.rectangle")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(minWidth: 82)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Choose player photo from Photos")

            Button {
                pastePhoto()
            } label: {
                Label("Paste", systemImage: "doc.on.doc")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(minWidth: 82)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Paste player photo")
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func loadSelectedPhoto() {
        guard let selectedPhotoItem else { return }
        Task { @MainActor in
            do {
                if let data = try await selectedPhotoItem.loadTransferable(type: Data.self) {
                    draft.photoData = data
                }
            } catch {
                photoErrorMessage = "ScoreKeep could not load that image."
                showingPhotoError = true
            }
        }
    }

    private func pastePhoto() {
        guard let image = UIPasteboard.general.image, let data = image.pngData() else {
            photoErrorMessage = "No image found on the clipboard."
            showingPhotoError = true
            return
        }
        draft.photoData = data
    }
}

private extension View {
    func playerEditableTextField() -> some View {
        self
            .textFieldStyle(.roundedBorder)
            .scorebookInputField()
            .frame(maxWidth: .infinity)
    }
}

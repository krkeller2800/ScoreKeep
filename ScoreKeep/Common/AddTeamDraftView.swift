import PhotosUI
import SwiftData
import SwiftUI

struct TeamFormDraft: Hashable {
    var name: String
    var coach: String
    var details: String
    var logoData: Data?

    static let empty = TeamFormDraft(name: "", coach: "", details: "", logoData: nil)

    init(name: String, coach: String, details: String, logoData: Data? = nil) {
        self.name = name
        self.coach = coach
        self.details = details
        self.logoData = logoData
    }

    init(team: Team) {
        self.name = team.name
        self.coach = team.coach
        self.details = team.details
        self.logoData = team.logo
    }

    var hasMeaningfulChanges: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
        coach.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
        details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
        logoData != nil
    }
}

struct AddTeamDraftValidation: Hashable {
    let trimmedName: String
    let message: String?

    var canSave: Bool { message == nil }

    static func validate(teamName: String, existingTeamNames: [String]) -> AddTeamDraftValidation {
        validate(teamName: teamName, existingNames: existingTeamNames)
    }

    static func validate(teamName: String, existingTeams: [Team], excluding excludedTeamIdentity: UUID? = nil) -> AddTeamDraftValidation {
        let existingNames = existingTeams.compactMap { team -> String? in
            if team.ident == excludedTeamIdentity { return nil }
            return team.name
        }
        return validate(teamName: teamName, existingNames: existingNames)
    }

    private static func validate(teamName: String, existingNames: [String]) -> AddTeamDraftValidation {
        let trimmedName = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return AddTeamDraftValidation(trimmedName: trimmedName, message: "Enter a team name before saving the team.")
        }

        if existingNames.contains(trimmedName) {
            return AddTeamDraftValidation(trimmedName: trimmedName, message: "\(trimmedName) has already been created.")
        }

        return AddTeamDraftValidation(trimmedName: trimmedName, message: nil)
    }
}

@MainActor
struct TeamFormContent: View {
    @Binding var draft: TeamFormDraft
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var logoErrorMessage = ""
    @State private var showingLogoError = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if useWideLayout {
                wideLayout
            } else {
                compactLayout
            }
        }
        .alert(logoErrorMessage, isPresented: $showingLogoError) {
            Button("OK", role: .cancel) { }
        }
        .onChange(of: selectedLogoItem, loadSelectedLogo)
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
            compactStackedLogoSection
        }
        .scrollContentBackground(.hidden)
        .background(ScoreKeepVisualStyle.background)
    }

    private var compactHorizontalLayout: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 8) {
                        logoPreview
                            .frame(width: 88, height: 88)
                        compactLogoControls
                    }
                    .frame(width: 190)

                    VStack(spacing: 10) {
                        fieldsSectionContent
                    }
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
                logoPreview
                    .frame(width: 190, height: 190)
                logoControls
            }
            .frame(width: 240)

            VStack(spacing: 14) {
                fieldsSectionContent
            }
            .frame(maxWidth: 520)
        }
        .padding(24)
        .frame(maxWidth: 820, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ScoreKeepVisualStyle.background)
    }

    private var compactStackedLogoSection: some View {
        Section {
            HStack(spacing: 14) {
                logoPreview
                    .frame(width: 84, height: 84)
                compactLogoControls
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
    }

    private var fieldsSection: some View {
        Section {
            fieldsSectionContent
        }
    }

    private var fieldsSectionContent: some View {
        Group {
            TextField("Name", text: $draft.name, prompt: scorebookInputPrompt("Name"))
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Team name")

            TextField("Coach", text: $draft.coach, prompt: scorebookInputPrompt("Coach"))
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Coach")

            TextField("Details", text: $draft.details, prompt: scorebookInputPrompt("Details"), axis: .vertical)
                .lineLimit(4...8)
                .accessibilityLabel("Team details")
        }
    }

    private var logoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(ScoreKeepVisualStyle.logoSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ScoreKeepVisualStyle.logoTileBorder, lineWidth: 1)
                )

            if let logoData = draft.logoData, let image = UIImage(data: logoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(ScoreKeepVisualStyle.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(draft.logoData == nil ? "No team logo" : "Team logo preview")
    }

    private var logoControls: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedLogoItem, matching: .images) {
                Label("Photos", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Choose team logo from Photos")

            Button {
                pasteLogo()
            } label: {
                Label("Paste", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Paste team logo")
        }
    }

    private var compactLogoControls: some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $selectedLogoItem, matching: .images) {
                Label("Photos", systemImage: "photo.on.rectangle")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(minWidth: 82)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Choose team logo from Photos")

            Button {
                pasteLogo()
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
            .accessibilityLabel("Paste team logo")
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func loadSelectedLogo() {
        guard let selectedLogoItem else { return }
        Task { @MainActor in
            do {
                if let data = try await selectedLogoItem.loadTransferable(type: Data.self) {
                    draft.logoData = data
                }
            } catch {
                logoErrorMessage = "ScoreKeep could not load that image."
                showingLogoError = true
            }
        }
    }

    private func pasteLogo() {
        guard let image = UIPasteboard.general.image, let data = image.pngData() else {
            logoErrorMessage = "No image found on the clipboard."
            showingLogoError = true
            return
        }
        draft.logoData = data
    }
}

@MainActor
struct AddTeamDraftView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var teamCreationRoutes: SimpleTeamCreationRoutingService

    let dismissAfterCreation: Bool
    let onCreated: (Team) -> Void

    @State private var draft = TeamFormDraft.empty
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingUnsavedNewTeamAlert = false
    @State private var pendingSubmission: SimpleTeamCreationSubmission?
    @State private var submittingSimpleTeam = false

    @Query private var teams: [Team]

    init(dismissAfterCreation: Bool = true, onCreated: @escaping (Team) -> Void = { _ in }) {
        self.dismissAfterCreation = dismissAfterCreation
        self.onCreated = onCreated
        _teams = Query(sort: [SortDescriptor(\Team.name)])
    }

    var body: some View {
        TeamFormContent(draft: $draft)
            .navigationTitle("Add Team")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        dismissOrConfirmDiscard()
                    }
                    .accessibilityLabel("Back")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveTeam)
                        .disabled(submittingSimpleTeam || currentValidation.canSave == false)
                        .accessibilityLabel("Save team")
                }
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("Discard New Team?", isPresented: $showingUnsavedNewTeamAlert) {
                Button("Discard New Team", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("Your new Team draft has unsaved changes.")
            }
    }

    private var currentValidation: AddTeamDraftValidation {
        AddTeamDraftValidation.validate(teamName: draft.name, existingTeams: teams)
    }

    private var hasUnsavedNewTeamDraft: Bool {
        draft.hasMeaningfulChanges
    }

    private func dismissOrConfirmDiscard() {
        if hasUnsavedNewTeamDraft {
            showingUnsavedNewTeamAlert = true
        } else {
            dismiss()
        }
    }

    private func saveTeam() {
        let validation = currentValidation
        guard validation.canSave else {
            alertMessage = validation.message ?? "Team could not be saved."
            showingAlert = true
            return
        }

        guard submittingSimpleTeam == false else { return }
        let submission = submissionForCurrentValues(trimmedName: validation.trimmedName)
        submittingSimpleTeam = true

        Task {
            let outcome = await teamCreationRoutes.submit(submission)
            await MainActor.run {
                submittingSimpleTeam = false
                if outcome.shouldClearFields, let createdTeam = fetchTeam(identity: submission.teamIdentity) {
                    onCreated(createdTeam)
                    if dismissAfterCreation {
                        dismiss()
                    }
                } else if outcome.shouldClearFields {
                    if dismissAfterCreation {
                        dismiss()
                    }
                } else {
                    alertMessage = outcome.userMessage ?? "ScoreKeep could not save this team. Your entries are still here."
                    showingAlert = true
                }
            }
        }
    }

    private func submissionForCurrentValues(trimmedName: String) -> SimpleTeamCreationSubmission {
        if let pendingSubmission,
           pendingSubmission.teamName == trimmedName,
           pendingSubmission.coach == draft.coach,
           pendingSubmission.details == draft.details,
           pendingSubmission.logoData == draft.logoData {
            return pendingSubmission
        }

        let submission = SimpleTeamCreationSubmission(
            operationIdentity: CanonicalTeamCreationOperationIdentity(UUID().uuidString),
            teamIdentity: UUID(),
            teamName: trimmedName,
            coach: draft.coach,
            details: draft.details,
            logoData: draft.logoData
        )
        pendingSubmission = submission
        return submission
    }

    private func fetchTeam(identity: UUID) -> Team? {
        let descriptor = FetchDescriptor<Team>(predicate: #Predicate { team in
            team.ident == identity
        })
        return try? modelContext.fetch(descriptor).first
    }
}

struct AddTeamNavigationDestination: Hashable { }

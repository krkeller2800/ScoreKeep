import SwiftData
import SwiftUI

@MainActor
struct TeamDefaultBattingOrderNavigationDestination: Hashable {
    let teamIdentity: UUID
}

@MainActor
struct TeamDefaultBattingOrderDestinationView: View {
    @Binding var navigationPath: NavigationPath
    @Query private var teams: [Team]

    init(destination: TeamDefaultBattingOrderNavigationDestination, navigationPath: Binding<NavigationPath>) {
        _navigationPath = navigationPath
        let teamIdentity = destination.teamIdentity
        _teams = Query(filter: #Predicate<Team> { team in
            team.ident == teamIdentity
        })
    }

    var body: some View {
        if let team = teams.first {
            TeamDefaultBattingOrderView(team: team, navigationPath: $navigationPath)
        } else {
            Text("Team not found")
        }
    }
}

@MainActor
struct TeamDefaultBattingOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var team: Team
    @Binding var navigationPath: NavigationPath

    @Query private var players: [Player]

    @State private var draft = TeamDefaultBattingOrderDraft(players: [])
    @State private var savedDraft = TeamDefaultBattingOrderDraft(players: [])
    @State private var hasLoadedDraft = false
    @State private var showingAddPlayerDraft = false
    @State private var showingUnsavedChangesAlert = false
    @State private var showingSaveErrorAlert = false
    @State private var saveErrorMessage = ""
    @State private var editMode: EditMode = .active

    init(team: Team, navigationPath: Binding<NavigationPath>) {
        self.team = team
        _navigationPath = navigationPath
        let teamIdentity = team.ident
        _players = Query(
            filter: #Predicate { player in
                player.team?.ident == teamIdentity
            },
            sort: [SortDescriptor(\Player.batOrder), SortDescriptor(\Player.name), SortDescriptor(\Player.number)]
        )
    }

    var body: some View {
        GeometryReader { geometry in
            List {
                Section {
                    tableHeader(width: geometry.size.width)

                    if draft.entries.isEmpty {
                        Text("No Players are on this Team roster.")
                            .foregroundStyle(ScoreKeepVisualStyle.secondaryText)
                    } else {
                        ForEach(draft.entries) { entry in
                            rosterRow(for: entry, width: geometry.size.width)
                        }
                        .onMove { offsets, newOffset in
                            draft.moveRosterEntries(fromOffsets: offsets, toOffset: newOffset)
                        }
                    }
                } header: {
                    Text("Batting Order")
                }
            }
            .listRowSpacing(0)
            .scrollContentBackground(.hidden)
            .background(ScoreKeepVisualStyle.background)
            .environment(\.editMode, .constant(editMode))
        }
        .navigationTitle("Default Batting Order")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasUnsavedChanges)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                if hasUnsavedChanges {
                    Button("Back") {
                        showingUnsavedChangesAlert = true
                    }
                    .accessibilityLabel("Back")
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingAddPlayerDraft = true
                } label: {
                    Label("Add Player", systemImage: "plus")
                }
                .accessibilityLabel("Add player")

                Button("Save") {
                    saveDraft(dismissAfterSave: false)
                }
                .disabled(hasUnsavedChanges == false)
                .accessibilityLabel("Save default batting order")
            }
        }
        .onAppear {
            loadDraftIfNeeded()
        }
        .onChange(of: players) {
            synchronizeDraftWithRoster()
        }
        .sheet(isPresented: $showingAddPlayerDraft) {
            NavigationStack {
                AddPlayerDraftView(team: team) { savedPlayer in
                    savedPlayer.batOrder = PlayerRosterBattingOrder.notHitting
                    try? modelContext.save()
                    var currentPlayers = players
                    if currentPlayers.contains(where: { $0.identifier == savedPlayer.identifier }) == false {
                        currentPlayers.append(savedPlayer)
                    }
                    draft.synchronizeRosterPlayers(currentPlayers)
                    savedDraft = TeamDefaultBattingOrderDraft(players: currentPlayers)
                }
            }
            .standardAddPlayerPresentation()
        }
        .alert("Unsaved Changes", isPresented: $showingUnsavedChangesAlert) {
            Button("Save Changes") {
                saveDraft(dismissAfterSave: true)
            }
            Button("Discard Changes", role: .destructive) {
                discardChangesAndExit()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("Save changes to this default batting order before leaving?")
        }
        .alert(saveErrorMessage, isPresented: $showingSaveErrorAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private var hasUnsavedChanges: Bool {
        draft.proposedBattingOrdersByPlayerIdentifier() != savedDraft.proposedBattingOrdersByPlayerIdentifier()
    }

    private func tableHeader(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            headerText("Order", width: max(44, width * 0.08))
            headerText("Name", alignment: .leading, width: width * 0.34)
            headerText("Num", width: width * 0.16)
            headerText("Pos", width: width * 0.16)
            headerText("Dir", width: width * 0.12)
            Spacer(minLength: 4)
        }
    }

    @ViewBuilder
    private func rosterRow(for entry: TeamDefaultBattingOrderDraft.Entry, width: CGFloat) -> some View {
        HStack(spacing: 8) {
            orderText(entry.isInOrder ? "\(entry.draftBattingOrder)" : "99", width: width)
            playerText(entry.name, alignment: .leading, width: width * 0.34)
            playerText(entry.number.isEmpty ? "--" : "#\(entry.number)", width: width * 0.16)
            playerText(compactPositionText(for: entry.position), width: width * 0.16)
            playerText(entry.battingDirection.isEmpty ? "--" : entry.battingDirection, width: width * 0.12)
            Spacer(minLength: 4)
        }
        .accessibilityElement(children: .combine)
    }

    private func headerText(_ text: String, alignment: Alignment = .center, width: CGFloat) -> some View {
        scorebookHeaderCell(text)
            .frame(width: max(48, width), alignment: alignment)
    }

    private func orderText(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .frame(width: max(44, width * 0.08), alignment: .center)
            .foregroundStyle(ScoreKeepVisualStyle.primaryText)
            .scorebookTrailingSeparator()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func playerText(_ text: String, alignment: Alignment = .center, width: CGFloat) -> some View {
        Text(text)
            .frame(width: max(48, width), alignment: alignment)
            .foregroundStyle(ScoreKeepVisualStyle.primaryText)
            .scorebookTrailingSeparator()
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.7)
    }

    private func compactPositionText(for position: String) -> String {
        let compactPosition = PlayerCompactPositionDisplay.string(for: position)
        return compactPosition.isEmpty ? "--" : compactPosition
    }

    private func loadDraftIfNeeded() {
        guard hasLoadedDraft == false else { return }
        let loadedDraft = TeamDefaultBattingOrderDraft(players: players)
        draft = loadedDraft
        savedDraft = loadedDraft
        hasLoadedDraft = true
    }

    private func synchronizeDraftWithRoster() {
        guard hasLoadedDraft else {
            loadDraftIfNeeded()
            return
        }
        draft.synchronizeRosterPlayers(players)
        savedDraft = TeamDefaultBattingOrderDraft(players: players)
    }

    private func saveDraft(dismissAfterSave: Bool) {
        do {
            try Self.save(draft: draft, modelContext: modelContext)
            let updatedDraft = TeamDefaultBattingOrderDraft(players: players)
            draft = updatedDraft
            savedDraft = updatedDraft
            if dismissAfterSave {
                exitView()
            }
        } catch {
            saveErrorMessage = "ScoreKeep could not save this default batting order. Your edits are still here."
            showingSaveErrorAlert = true
        }
    }

    private func discardChangesAndExit() {
        draft = savedDraft
        exitView()
    }

    private func exitView() {
        if navigationPath.isEmpty {
            dismiss()
        } else {
            navigationPath.removeLast()
        }
    }

    static func save(draft: TeamDefaultBattingOrderDraft, modelContext: ModelContext) throws {
        let proposedOrders = draft.proposedBattingOrdersByPlayerIdentifier()
        for entry in draft.entries {
            entry.player.batOrder = proposedOrders[entry.playerIdentifier] ?? PlayerRosterBattingOrder.notHitting
        }
        try modelContext.save()
    }
}

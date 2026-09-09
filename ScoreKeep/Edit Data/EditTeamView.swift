//
//  EditTeamView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/16/25.
//
import SwiftData
import SwiftUI

struct EditTeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    @Bindable var team: Team

    @State private var draft: TeamFormDraft
    @State private var initialDraft: TeamFormDraft
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingUnsavedChangesAlert = false
    @State private var presentPlayers = false
    @AppStorage("selectedPlayerTCriteria") var selectedPlayerTCriteria: SortCriteria = .orderAsc

    @Query(sort: [SortDescriptor(\Team.name)]) private var teams: [Team]

    enum SortCriteria: String, CaseIterable, Identifiable {
        case nameAsc, nameDec, orderAsc, numAsc
        var id: String { self.rawValue }
    }

    init(navigationPath: Binding<NavigationPath>, team: Team) {
        _navigationPath = navigationPath
        self.team = team
        let snapshot = TeamFormDraft(team: team)
        _draft = State(initialValue: snapshot)
        _initialDraft = State(initialValue: snapshot)
    }

    var sortDescriptor: [SortDescriptor<Player>] {
        switch selectedPlayerTCriteria {
        case .nameAsc:
            return [SortDescriptor(\Player.name, order: .forward)]
        case .nameDec:
            return [SortDescriptor(\Player.name, order: .reverse)]
        case .orderAsc:
            return [SortDescriptor(\Player.batOrder, order: .forward)]
        case .numAsc:
            return [SortDescriptor(\Player.number, order: .forward)]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TeamFormContent(draft: $draft)
                .frame(maxHeight: UIDevice.type != "iPhone" ? 260 : nil, alignment: .top)

            if UIDevice.type != "iPhone" {
                VStack(alignment: .leading, spacing: 6) {
                    PlayersOnTeamView(
                        team: team,
                        searchString: searchText,
                        sortOrder: sortDescriptor,
                        usesStandardPlayerAdd: true,
                        openDefaultBattingOrder: openDefaultBattingOrder
                    )
                        .navigationDestination(for: Player.self) { player in
                            EditPlayerView(player: player, team: team, navigationPath: $navigationPath)
                        }
                }
                .padding(.top, 4)
            }
        }
        .background(ScoreKeepVisualStyle.background)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                if hasUnsavedChanges {
                    Button("Back") {
                        showingUnsavedChangesAlert = true
                    }
                    .accessibilityLabel("Back")
                }

                if UIDevice.type != "iPhone" {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort", selection: $selectedPlayerTCriteria) {
                            ForEach(SortCriteria.allCases) { criteria in
                                if criteria == .nameAsc {
                                    Text("Name (A-Z)").tag(criteria)
                                } else if criteria == .nameDec {
                                    Text("Name (Z-A)").tag(criteria)
                                } else if criteria == .numAsc {
                                    Text("Number (A-Z)").tag(criteria)
                                } else if criteria == .orderAsc {
                                    Text("order (A-Z)").tag(criteria)
                                }
                            }
                        }
                    }
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if UIDevice.type == "iPhone" {
                    Button("Players") {
                        presentPlayers.toggle()
                    }
                }

                Button("Save") {
                    saveTeam(dismissAfterSave: false)
                }
                .disabled(hasUnsavedChanges == false || currentValidation.canSave == false)
                .accessibilityLabel("Save team")
            }

            ToolbarItem(placement: .principal) {
                Text(draft.name.isEmpty ? "Team" : draft.name)
                    .font(.title2)
            }
        }
        .navigationBarBackButtonHidden(hasUnsavedChanges)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: "Player name or number")
        .onAppear {
            if UIDevice.type == "iPhone" {
               isSearching = false
            } else {
                isSearching = true
            }
        }
        .onChange(of: isSearching) {
            if isSearching == false {
                searchText = ""
            }
        }
        .onChange(of: sortDescriptor) {
            sortOrder = sortDescriptor
        }
        .alert(alertMessage, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("Unsaved Changes", isPresented: $showingUnsavedChangesAlert) {
            Button("Save Changes") {
                saveTeam(dismissAfterSave: true)
            }
            Button("Discard Changes", role: .destructive) {
                discardChangesAndExit()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("Save changes to this team before leaving?")
        }
        .fullScreenCover(isPresented: $presentPlayers) {
            PlayerView(team: team, navigationPath: $navigationPath, searchString: $searchText, openDefaultBattingOrder: openDefaultBattingOrder)
        }
    }

    private var hasUnsavedChanges: Bool {
        draft != initialDraft
    }

    private var currentValidation: AddTeamDraftValidation {
        AddTeamDraftValidation.validate(teamName: draft.name, existingTeams: teams, excluding: team.ident)
    }

    private func saveTeam(dismissAfterSave: Bool) {
        let validation = currentValidation
        guard validation.canSave else {
            alertMessage = validation.message ?? "Team could not be saved."
            showingAlert = true
            return
        }

        team.name = validation.trimmedName
        team.coach = draft.coach
        team.details = draft.details
        team.logo = draft.logoData

        do {
            try modelContext.save()
            initialDraft = TeamFormDraft(team: team)
            draft = initialDraft
            if dismissAfterSave {
                exitEditView()
            }
        } catch {
            alertMessage = "ScoreKeep could not save this team. Your edits are still here."
            showingAlert = true
        }
    }

    private func discardChangesAndExit() {
        draft = initialDraft
        exitEditView()
    }

    private func exitEditView() {
        if navigationPath.isEmpty {
            dismiss()
        } else {
            navigationPath.removeLast()
        }
    }

    private func openDefaultBattingOrder() {
        navigationPath.append(TeamDefaultBattingOrderNavigationDestination(teamIdentity: team.ident))
    }
}

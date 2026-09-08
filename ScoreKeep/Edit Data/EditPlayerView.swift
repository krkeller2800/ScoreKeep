//
//  EditPlayerView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/17/25.
//
import SwiftData
import SwiftUI

struct EditPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var player: Player
    let team: Team
    @Binding var navigationPath: NavigationPath

    @State private var draft: PlayerFormDraft
    @State private var initialDraft: PlayerFormDraft
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingUnsavedChangesAlert = false
    @State private var likelyDuplicatePlayer: Player?
    @State private var showingDuplicatePlayerAlert = false
    @State private var pendingDismissAfterSave = false

    @Query(sort: [SortDescriptor(\Team.name)]) private var teams: [Team]
    @Query private var players: [Player]

    init(player: Player, team: Team, navigationPath: Binding<NavigationPath>) {
        self.player = player
        self.team = team
        _navigationPath = navigationPath
        let snapshot = PlayerFormDraft(player: player, fallbackTeam: team)
        _draft = State(initialValue: snapshot)
        _initialDraft = State(initialValue: snapshot)
        let fallbackTeamIdentity = team.ident
        _players = Query(filter: #Predicate { candidate in
            candidate.team?.ident == fallbackTeamIdentity
        }, sort: [SortDescriptor(\Player.batOrder), SortDescriptor(\Player.name)])
    }

    var body: some View {
        PlayerFormContent(draft: $draft, teams: teams, allowsTeamSelection: true)
            .navigationTitle("Update a Player")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(hasUnsavedChanges)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if hasUnsavedChanges {
                        Button("Back") {
                            showingUnsavedChangesAlert = true
                        }
                        .accessibilityLabel("Back")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlayer(dismissAfterSave: false)
                    }
                    .disabled(currentValidation.canSave == false || hasUnsavedChanges == false)
                    .accessibilityLabel("Save player")
                }
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("Unsaved Changes", isPresented: $showingUnsavedChangesAlert) {
                Button("Save Changes") {
                    savePlayer(dismissAfterSave: true)
                }
                Button("Discard Changes", role: .destructive) {
                    discardChangesAndExit()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("Save changes to this player before leaving?")
            }
            .alert("Possible Duplicate Player", isPresented: $showingDuplicatePlayerAlert, presenting: likelyDuplicatePlayer) { matchedPlayer in
                Button("Use Existing Player") {
                    useExistingPlayer()
                }
                Button("Update Existing Player") {
                    updateExistingPlayer(matchedPlayer)
                }
                Button("Create New Player Anyway") {
                    applyDraftToCurrentPlayer(dismissAfterSave: pendingDismissAfterSave)
                }
                Button("Cancel", role: .cancel) { }
            } message: { matchedPlayer in
                Text("A similar player already exists on \(draft.teamName.isEmpty ? team.name : draft.teamName): \(duplicatePlayerSummary(matchedPlayer)).")
            }
    }

    private var hasUnsavedChanges: Bool {
        draft != initialDraft
    }

    private var currentValidation: PlayerDraftValidation {
        PlayerDraftValidation.validate(playerName: draft.name)
    }

    private func savePlayer(dismissAfterSave: Bool) {
        let validation = currentValidation
        guard validation.canSave else {
            alertMessage = validation.message ?? "Player could not be saved."
            showingAlert = true
            return
        }

        if let duplicate = findLikelyDuplicatePlayer() {
            pendingDismissAfterSave = dismissAfterSave
            likelyDuplicatePlayer = duplicate
            showingDuplicatePlayerAlert = true
            return
        }

        applyDraftToCurrentPlayer(dismissAfterSave: dismissAfterSave)
    }

    private func findLikelyDuplicatePlayer() -> Player? {
        RosterImportReconciler.likelyMatchingPlayer(
            name: draft.name,
            number: draft.number,
            in: candidatePlayersForDraftTeam,
            excluding: player
        )
    }

    private var candidatePlayersForDraftTeam: [Player] {
        players.filter { $0.team?.ident == draft.teamIdentity }
    }

    private func applyDraftToCurrentPlayer(dismissAfterSave: Bool) {
        let validation = currentValidation
        player.name = validation.trimmedName
        player.number = draft.number
        player.position = draft.normalizedPosition
        player.batDir = draft.batDir
        player.batOrder = PlayerRosterBattingOrder.normalizedRosterOrder(draft.batOrder)
        player.team = selectedTeamForDraft()
        player.photo = draft.photoData

        do {
            try modelContext.save()
            initialDraft = PlayerFormDraft(player: player, fallbackTeam: team)
            draft = initialDraft
            likelyDuplicatePlayer = nil
            pendingDismissAfterSave = false
            if dismissAfterSave {
                exitEditView()
            }
        } catch {
            alertMessage = "ScoreKeep could not save this player. Your edits are still here."
            showingAlert = true
        }
    }

    private func selectedTeamForDraft() -> Team? {
        guard let teamIdentity = draft.teamIdentity else { return nil }
        if team.ident == teamIdentity { return team }
        return teams.first { $0.ident == teamIdentity }
    }

    private func useExistingPlayer() {
        draft = initialDraft
        likelyDuplicatePlayer = nil
        pendingDismissAfterSave = false
        exitEditView()
    }

    private func updateExistingPlayer(_ matchedPlayer: Player) {
        RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .updateExistingPlayer,
            matchedPlayer: matchedPlayer,
            name: draft.name,
            number: draft.number,
            position: draft.normalizedPosition,
            batDir: draft.batDir,
            preserveHistoricalEvidence: false
        )
        do {
            try modelContext.save()
            useExistingPlayer()
        } catch {
            alertMessage = "ScoreKeep could not update the existing player. Your edits are still here."
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

    private func duplicatePlayerSummary(_ player: Player) -> String {
        let number = player.number.isEmpty ? "no number" : "#\(player.number)"
        let position = player.position.isEmpty ? "no position" : player.position
        return "\(player.name), \(number), \(position)"
    }
}

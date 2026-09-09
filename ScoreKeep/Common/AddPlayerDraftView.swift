import SwiftData
import SwiftUI

@MainActor
struct AddPlayerDraftView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let team: Team
    let onSave: ((Player) -> Void)?

    @State private var draft: PlayerFormDraft
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingUnsavedNewPlayerAlert = false
    @State private var likelyDuplicatePlayer: Player?
    @State private var showingDuplicatePlayerAlert = false

    @Query(sort: [SortDescriptor(\Team.name)]) private var teams: [Team]
    @Query private var players: [Player]

    init(team: Team, onSave: ((Player) -> Void)? = nil) {
        self.team = team
        self.onSave = onSave
        _draft = State(initialValue: PlayerFormDraft.empty(for: team))
        let teamIdentity = team.ident
        _players = Query(filter: #Predicate { player in
            player.team?.ident == teamIdentity
        }, sort: [SortDescriptor(\Player.batOrder), SortDescriptor(\Player.name)])
    }

    var body: some View {
        PlayerFormContent(draft: $draft, teams: teams, allowsTeamSelection: false)
            .navigationTitle("Add Player")
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
                    Button("Save", action: savePlayer)
                        .disabled(currentValidation.canSave == false)
                        .accessibilityLabel("Save player")
                }
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("Discard New Player?", isPresented: $showingUnsavedNewPlayerAlert) {
                Button("Discard New Player", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("Your new Player draft has unsaved changes.")
            }
            .alert("Possible Duplicate Player", isPresented: $showingDuplicatePlayerAlert, presenting: likelyDuplicatePlayer) { matchedPlayer in
                Button("Use Existing Player") {
                    clearPendingDuplicateAndExit()
                }
                Button("Update Existing Player") {
                    updateExistingPlayer(matchedPlayer)
                }
                Button("Create New Player Anyway") {
                    createDraftPlayer()
                }
                Button("Cancel", role: .cancel) { }
            } message: { matchedPlayer in
                Text("A similar player already exists on \(team.name): \(duplicatePlayerSummary(matchedPlayer)).")
            }
    }

    private var currentValidation: PlayerDraftValidation {
        PlayerDraftValidation.validate(playerName: draft.name)
    }

    private var hasUnsavedNewPlayerDraft: Bool {
        draft.hasMeaningfulChanges
    }

    private func dismissOrConfirmDiscard() {
        if hasUnsavedNewPlayerDraft {
            showingUnsavedNewPlayerAlert = true
        } else {
            dismiss()
        }
    }

    private func savePlayer() {
        let validation = currentValidation
        guard validation.canSave else {
            alertMessage = validation.message ?? "Player could not be saved."
            showingAlert = true
            return
        }

        if let duplicate = RosterImportReconciler.likelyMatchingPlayer(name: draft.name, number: draft.number, in: players) {
            likelyDuplicatePlayer = duplicate
            showingDuplicatePlayerAlert = true
            return
        }

        createDraftPlayer()
    }

    private func createDraftPlayer() {
        let validation = currentValidation
        guard validation.canSave else {
            alertMessage = validation.message ?? "Player could not be saved."
            showingAlert = true
            return
        }

        let orderToAssign = PlayerRosterBattingOrder.normalizedRosterOrder(draft.batOrder)
        let player = Player(
            name: validation.trimmedName,
            number: draft.number,
            position: draft.normalizedPosition,
            batDir: draft.batDir,
            batOrder: orderToAssign,
            team: team,
            photo: draft.photoData
        )
        modelContext.insert(player)

        do {
            try modelContext.save()
            likelyDuplicatePlayer = nil
            onSave?(player)
            dismiss()
        } catch {
            modelContext.delete(player)
            alertMessage = "ScoreKeep could not save this player. Your entries are still here."
            showingAlert = true
        }
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
            clearPendingDuplicateAndExit()
        } catch {
            alertMessage = "ScoreKeep could not update the existing player. Your entries are still here."
            showingAlert = true
        }
    }

    private func clearPendingDuplicateAndExit() {
        if let likelyDuplicatePlayer {
            onSave?(likelyDuplicatePlayer)
        }
        likelyDuplicatePlayer = nil
        dismiss()
    }

    private func duplicatePlayerSummary(_ player: Player) -> String {
        let number = player.number.isEmpty ? "no number" : "#\(player.number)"
        let position = player.position.isEmpty ? "no position" : player.position
        return "\(player.name), \(number), \(position)"
    }
}

extension View {
    @ViewBuilder
    func standardAddPlayerPresentation() -> some View {
        if #available(iOS 18.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }
}

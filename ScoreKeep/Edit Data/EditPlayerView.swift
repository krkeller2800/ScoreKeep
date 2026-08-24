//
//  EditPlayerView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/17/25.
//
import PhotosUI
import SwiftUI
import SwiftData

struct EditPlayerView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @Bindable var player: Player
    @Bindable var team: Team
    @Binding var navigationPath: NavigationPath
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var playerName = ""
    @State private var playerNumber = ""
    @State private var playerPosition = ""
    @State private var playerBatDir = ""
    @State private var prevPName = ""
    @State private var originalPlayerName = ""
    @State private var originalPlayerNumber = ""
    @State private var originalPlayerPosition = ""
    @State private var originalPlayerBatDir = ""
    @State private var dups = false
    @State private var checkForDups = true
    @State private var likelyDuplicatePlayer: Player?
    @State private var showingDuplicatePlayerAlert = false
    @State private var removedPlaceholderForExisting = false

    enum FocusField: Hashable {case field}

    @FocusState private var focusedField: FocusField?

    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]

    var formatter: NumberFormatter {
        let formatter = NumberFormatter ()
        formatter.minimumIntegerDigits = 0
        formatter.maximumFractionDigits = 3

        return formatter
    }
    var body: some View {
        Form {
            VStack {
                HStack(spacing: 0) {
                    scorebookHeaderCell("Name")
                        .frame(width:150)
                    scorebookHeaderCell("Number")
                        .frame(maxWidth:.infinity)
                    scorebookHeaderCell("Position")
                        .frame(maxWidth:.infinity)
                    scorebookHeaderCell("Bat Dir")
                        .frame(maxWidth:.infinity)
                    scorebookHeaderCell("Bat Order")
                        .frame(maxWidth:.infinity)
                    scorebookHeaderCell("Team")
                        .frame(maxWidth:.infinity)
                    }
                .accessibilityHidden(true)

                HStack {
                    TextField(" ", text: $playerName, onEditingChanged: { (editingChanged) in
                        if !editingChanged {
                            checkForDup(pname: playerName)
                        }})
                        .frame(width: 150)
                        .textFieldStyle(.roundedBorder).scorebookInputField().scorebookNameField().bold()
                        .scorebookInputPromptOverlay("Player", isVisible: playerName.isEmpty)
                        .accessibilityLabel("Player")
                        .focused($focusedField, equals: .field)
                        .onChange(of: focusedField) { checkForDup(pname: playerName)}
//                        .onAppear {self.focusedField = .field}
                        .textContentType(.none)
                        .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                    TextField("Number", text: $playerNumber, prompt: scorebookInputPrompt("Number")).frame(maxWidth:.infinity)
                        .textFieldStyle(.roundedBorder).scorebookInputField().bold()
                    TextField("Pos", text: $playerPosition, prompt: scorebookInputPrompt("Pos")).frame(maxWidth:.infinity)
                        .textFieldStyle(.roundedBorder).scorebookInputField().bold()
                    TextField("Bat Dir", text: $playerBatDir, prompt: scorebookInputPrompt("Bat Dir")).frame(maxWidth:.infinity)
                        .textFieldStyle(.roundedBorder).scorebookInputField().bold()
                    Picker("Bat Order", selection: $player.batOrder) {

                        let orders = ["None","1st","2nd","3rd","4th",
                                       "5th","6th","7th","8th","9th",
                                       "10th","11th","12th","13th","14th",
                                       "15th","16th","17th","18th","19th"]
                        ForEach(Array(orders.enumerated()), id: \.1) { index, order in
                            Text(order).tag(index)
                        }
                    Text("Not Hitting").tag(99)
                    }
                    .frame(maxWidth:.infinity).labelsHidden().pickerStyle(.menu).tint(ScoreKeepVisualStyle.accent)

                    Picker("Player Team", selection: $player.team) {
                        Text("Unknown Team").tag(Optional<Team>.none)
                        if teams.isEmpty == false {
                            Divider()
                            ForEach(teams) { nteam in
                                if nteam.name != "" {
                                    Text(nteam.name).tag(Optional(nteam))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .labelsHidden().pickerStyle(.menu).tint(ScoreKeepVisualStyle.accent)
                    }


            }
            HStack {
                Spacer()
                if let imageData = player.photo, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .scaleImage(iHeight: 400, imageData: imageData)
                        .cornerRadius(25)
//                        .resizable()
//                        .frame(maxWidth: 400, maxHeight: 400, alignment: .center)
//                        .scaledToFit()
                }
                Spacer()
            }
            Text("\n\n")
            HStack {
                Spacer()
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing:0) {
                        Image(systemName: "person")
                        Text("Photos").padding(.leading,5)
                    }
                }
                .frame(width: 100, alignment:.center).tint(ScoreKeepVisualStyle.primaryText).background(ScoreKeepVisualStyle.selectedFill).cornerRadius(10).buttonStyle(.borderless)
                .onChange(of: selectedItem, loadPhoto)

                Text(" or ")
                Button {
                    let pasteboard = UIPasteboard.general
                    if let image = pasteboard.image {
                        player.photo = image.pngData()
                    }
                } label: {
                    HStack(spacing:0) {
                        Image(systemName: "doc.on.doc")
                        Text("Paste").padding(.leading,5)
                    }
                }
                .frame(width: 100, alignment:.center).tint(ScoreKeepVisualStyle.primaryText).background(ScoreKeepVisualStyle.selectedFill).cornerRadius(10).buttonStyle(.borderless)
                Spacer()

                .onDisappear() {
                    guard !removedPlaceholderForExisting else { return }

                    if playerName.isEmpty {
                        modelContext.delete(player)
                    } else if dups {
                        if originalPlayerName.isEmpty {
                            modelContext.delete(player)
                        } else {
                            restoreOriginalPlayerFields()
                        }
                    } else {
                        applyBufferedFields(to: player)
                    }
                }
                .onAppear() {
                    playerName = player.name
                    playerNumber = player.number
                    playerPosition = player.position
                    playerBatDir = player.batDir
                    originalPlayerName = player.name
                    originalPlayerNumber = player.number
                    originalPlayerPosition = player.position
                    originalPlayerBatDir = player.batDir
                    prevPName = player.name
                    if !playerName.isEmpty {
                        checkForDups = false
                    }

                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollContentBackground(.hidden)
        .background(ScoreKeepVisualStyle.background)
        .alert("Possible Duplicate Player", isPresented: $showingDuplicatePlayerAlert, presenting: likelyDuplicatePlayer) { matchedPlayer in
            Button("Use Existing Player") {
                useExistingPlayer(matchedPlayer)
            }
            Button("Update Existing Player") {
                updateExistingPlayer(matchedPlayer)
            }
            Button("Create New Player Anyway") {
                createNewPlayerAnyway()
            }
            Button("Cancel", role: .cancel) { }
        } message: { matchedPlayer in
            Text("A similar player already exists on \(team.name): \(duplicatePlayerSummary(matchedPlayer)).")
        }
        .toolbar {

            ToolbarItem(placement: .principal) {
                Text("Update a Player")
                    .font(.title2)
            }
        }

    }
    func loadPhoto() {
        Task { @MainActor in
            player.photo = try await selectedItem?.loadTransferable(type: Data.self)
        }
    }
    func checkForDup(pname:String) {

        if prevPName == pname {
            checkForDups = false
        } else {
            checkForDups = true
        }
        let teamName = team.name
        let playName = pname
        prevPName = playName

        if !teamName.isEmpty && !playName.isEmpty && checkForDups{
            if let likelyDuplicate = findLikelyDuplicatePlayer(for: playName) {
                likelyDuplicatePlayer = likelyDuplicate
                dups = true
                showingDuplicatePlayerAlert = true
            } else {
                dups = false
            }
        } else {
            if teamName.isEmpty && !playerName.isEmpty {
                showingAlert = true
                alertMessage = "Please select a team so we can check if \(pname) is on already on it."
            }
        }
    }

    func findLikelyDuplicatePlayer(for name: String) -> Player? {
        let teamName = team.name
        guard !teamName.isEmpty, !name.isEmpty else { return nil }

        var fetchDescriptor = FetchDescriptor<Player>()
        fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName }

        do {
            let teamPlayers = try self.modelContext.fetch(fetchDescriptor)
            return RosterImportReconciler.likelyMatchingPlayer(
                name: name,
                number: playerNumber,
                in: teamPlayers,
                excluding: player
            )
        } catch {
            print("SwiftData Error: \(error)")
            return nil
        }
    }

    func useExistingPlayer(_ matchedPlayer: Player) {
        likelyDuplicatePlayer = matchedPlayer

        if originalPlayerName.isEmpty {
            removedPlaceholderForExisting = true
            modelContext.delete(player)
            try? modelContext.save()
            dismiss()
        } else {
            playerName = originalPlayerName
            restoreOriginalPlayerFields()
            dups = false
            likelyDuplicatePlayer = nil
        }
    }

    func updateExistingPlayer(_ matchedPlayer: Player) {
        RosterImportReconciler.resolveManualDuplicatePlayerChoice(
            .updateExistingPlayer,
            matchedPlayer: matchedPlayer,
            name: playerName,
            number: playerNumber,
            position: CanonicalDefensivePosition.normalizedDisplayValue(for: playerPosition),
            batDir: playerBatDir,
            preserveHistoricalEvidence: false
        )
        try? modelContext.save()
        useExistingPlayer(matchedPlayer)
    }

    func createNewPlayerAnyway() {
        dups = false
        likelyDuplicatePlayer = nil
        applyBufferedFields(to: player)
        try? modelContext.save()
    }

    func duplicatePlayerSummary(_ player: Player) -> String {
        let number = player.number.isEmpty ? "no number" : "#\(player.number)"
        let position = player.position.isEmpty ? "no position" : player.position
        return "\(player.name), \(number), \(position)"
    }

    func applyBufferedFields(to player: Player) {
        player.name = playerName
        player.number = playerNumber
        player.position = CanonicalDefensivePosition.normalizedDisplayValue(for: playerPosition)
        player.batDir = playerBatDir
    }

    func restoreOriginalPlayerFields() {
        playerName = originalPlayerName
        playerNumber = originalPlayerNumber
        playerPosition = originalPlayerPosition
        playerBatDir = originalPlayerBatDir
        player.name = originalPlayerName
        player.number = originalPlayerNumber
        player.position = originalPlayerPosition
        player.batDir = originalPlayerBatDir
    }
}

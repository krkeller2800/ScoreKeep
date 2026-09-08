//
//  ReplacementView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/10/25.
//

import SwiftUI
import SwiftData



struct ReplacementView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State var navigationPath: NavigationPath = NavigationPath()
    @State private var selectPlayers: [Player] = []
    @State private var atbats: [Atbat] = []
    @State private var showingAlert: Bool = false
    @State private var reviewState: LiveScoringShellPresentation.SubstitutionReviewState?
    let presenter = LiveScoringShellPresentation()
    @State private var doSubstitution: Bool = false
    @State private var team: Team
    @State private var game: Game
    @State private var alertMessage = ""
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State private var replacedIdx: Int = 0
    @State private var incomingIdx: Int = 0
    @State private var rplPlayers: [Player] = []
    @State private var incPlayers: [Player] = []
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showingAddPlayerDraft = false

    @Query var players: [Player]

    private var replacementPickerBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.secondarySystemBackground
            : UIColor.systemBlue.withAlphaComponent(0.2)
        })
    }

    private var replacementPickerBorder: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.separator.withAlphaComponent(0.72)
            : UIColor.gray
        })
    }

    private var replacementPickerForeground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.label
            : UIColor.black
        })
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                HStack {
                    Spacer()
                    Picker("Replaced", selection: $replacedIdx) {
                        Text("Playing Players").tag(0)
                        ForEach(Array(rplPlayers.enumerated()), id: \.1) { index, rplPlayer in
                            Text(rplPlayer.name)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .tag(index+1)
                        }
                    }
                    .frame(maxWidth: 200, minHeight: 30, alignment:.center).foregroundStyle(replacementPickerForeground).background(replacementPickerBackground)
                    .border(replacementPickerBorder).cornerRadius(10).accentColor(replacementPickerForeground).padding(.leading, 15)
                    Text("  Replaced by ").font(.title)
                    Picker("incoming", selection: $incomingIdx) {
                        Text("Incoming Players").tag(0)
                        ForEach(Array(incPlayers.enumerated()), id: \.1) { index, incPlayer in
                            Text(incPlayer.name)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .tag(index+1)
                        }
                    }
                    .frame(maxWidth: 200, minHeight: 30, alignment:.center).foregroundStyle(replacementPickerForeground).background(replacementPickerBackground)
                    .border(replacementPickerBorder).cornerRadius(10).accentColor(replacementPickerForeground).padding(.leading, 15)
                    Spacer()
                    Button("Do it!") {
                        if replacedIdx > 0 && incomingIdx > 0 {
                            reviewState = presenter.prepareSubstitutionReview(
                                gameIdentity: game.ident,
                                outgoingPlayerIdentity: rplPlayers[replacedIdx-1].identifier,
                                incomingPlayerIdentity: incPlayers[incomingIdx-1].identifier,
                                summaryOutgoingName: rplPlayers[replacedIdx-1].name,
                                summaryIncomingName: incPlayers[incomingIdx-1].name
                            )
                        } else {
                            alertMessage = "Please select a player to replace and an incoming player."
                            showingAlert = true
                        }
                    }
                    .frame(maxWidth: 100,maxHeight: 30, alignment:.center).foregroundStyle(replacementPickerForeground).background(.blue.opacity(0.2))
                    .border(.gray).cornerRadius(10).accentColor(replacementPickerForeground).padding(.leading, 0)
                    .alert("Confirm Substitution", isPresented: Binding(
                        get: { reviewState != nil && reviewState!.outcome == .pending },
                        set: { if !$0 { _ = presenter.cancelSubstitutionReview(&reviewState) } }
                    )) {
                        Button("Cancel", role: .cancel) {
                            _ = presenter.cancelSubstitutionReview(&reviewState)
                        }
                        Button("Confirm") {
                            getAtbats()
                            let coordinator = LiveScoringWorkflowCoordinator()
                            let presentation = presenter.confirmSubstitutionReview(&reviewState) { gameId, outgoingId, incomingId in
                                coordinator.submitSubstitution(
                                    gameIdentity: gameId,
                                    outgoingParticipant: outgoingId,
                                    incomingParticipant: incomingId,
                                    displayedAtbats: atbats,
                                    pitchers: game.pitchers,
                                    modelContext: modelContext,
                                    save: { try modelContext.save() }
                                )
                            }
                            if presentation.outcome == .accepted {
                                dismiss()
                            } else {
                                alertMessage = presentation.message ?? "Substitution failed."
                                showingAlert = true
                            }
                        }
                    } message: {
                        if let review = reviewState {
                            Text("Substitute \(review.summaryIncomingName) for \(review.summaryOutgoingName)?")
                        }
                    }
                    .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
                    Spacer()
                }
                HStack {
                    Spacer()
                    PlayersOnTeamView(team: team, searchString: searchText, sortOrder: sortOrder, showsQuickAddRow: false)
                        .navigationDestination(for: Player.self) { player in
                            EditPlayerView( player: player, team: team, navigationPath: $navigationPath)
                        }
                    Spacer()
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .onAppear {
                    updateReplacementLists()
                }
                .onChange(of: players) {
                    updateReplacementLists()
                }
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Choose Player Substitutions").font(.title2)
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort", selection: $sortOrder) {
                            Text("Name (A-Z)")
                                .tag([SortDescriptor(\Player.name)])
                            Text("Name (Z-A)")
                                .tag([SortDescriptor(\Player.name, order: .reverse)])
                            Text("Order (1-99)")
                                .tag([SortDescriptor(\Player.batOrder)])
                            Text("Number (1-99)")
                                .tag([SortDescriptor(\Player.number)])
                            Text("Team then Order (1-99)")
                                .tag([SortDescriptor(\Player.team?.name),SortDescriptor(\Player.batOrder)])
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if UIDevice.type == "iPhone" {
                        Button(action: {
                            withAnimation {
                                isSearching.toggle()
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Player name or number", text: $searchText)
                                .textFieldStyle(.plain)
                                .frame(width: 260)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Player name or number")
                    }

                    Button("Add Player", systemImage: "plus", action: addPlayers)
                        .accessibilityLabel("Add player")
                }
            }
            .searchable(if: UIDevice.type == "iPhone" && isSearching, text: $searchText, placement: .toolbar, prompt: "Player name or number")
            .sheet(isPresented: $showingAddPlayerDraft) {
                NavigationStack {
                    AddPlayerDraftView(team: team)
                }
            }
            .onAppear {
                if UIDevice.type == "iPhone" {
                    isSearching = false
                } else {
                    isSearching = false
                }
            }
        }
    }
    init (game:Game, team:Team) {
        self.team = team
        self.game = game
        let tname = team.name

        _players = Query(filter: #Predicate { player in
            player.team?.name == tname
        },  sort: sortOrder)
    }
    func getPlayers () {

        let teamName = team.name

        if !teamName.isEmpty {

            var fetchDescriptor = FetchDescriptor<Player>(sortBy: [SortDescriptor(\.batOrder)])

            fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName }

            do {
                selectPlayers = try self.modelContext.fetch(fetchDescriptor)
            } catch {
                print("SwiftData Error: \(error)")
            }
        } else {
            showingAlert = true
            alertMessage = "Please select a team."
        }
    }
    func addPlayers() {
        showingAddPlayerDraft = true
    }

    func updateReplacementLists() {
        let startAtbats = game.atbats.filter { $0.col == 1 && $0.batOrder < 50 && $0.team.id == team.id}
        var newRplPlayers: [Player] = []
        var newIncPlayers: [Player] = []

        for player in players {
            var isPlaying = false
            for atbat in startAtbats {
                if player.id == atbat.player.id {
                    if player.batOrder != atbat.batOrder {
                        player.batOrder = atbat.batOrder
                    }
                    newRplPlayers.append(player)
                    isPlaying = true
                }
            }
            if !isPlaying {
                if player.batOrder != 99 {
                    player.batOrder = 99
                }
                newIncPlayers.append(player)
            }
        }

        let rplChanged = rplPlayers.map { $0.id } != newRplPlayers.map { $0.id }
        let incChanged = incPlayers.map { $0.id } != newIncPlayers.map { $0.id }

        if rplChanged {
            rplPlayers = newRplPlayers
        }

        if incChanged {
            incPlayers = newIncPlayers
        }

    }
    func getAtbats () {

        let gloc = game.location
        let gdate = game.date
        let tname = team.name


        var fetchDescriptor = FetchDescriptor<Atbat>(sortBy: [SortDescriptor(\.col), SortDescriptor(\.seq)])

        fetchDescriptor.predicate = #Predicate { $0.game.location == gloc && $0.game.date == gdate && $0.team.name == tname }

        do {
            atbats = try self.modelContext.fetch(fetchDescriptor)
        } catch {
            print("SwiftData Error fetching atbats: \(error)")
        }
    }
}

//
//  ScoreGameView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/26/25.
//

import SwiftUI
import SwiftData

struct ScoreContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Binding var columnVisability: NavigationSplitViewVisibility

    @State private var path = NavigationPath()
    @State private var addAGame: Bool = false
    @State private var isSearching: Bool = false
    @State var doGame = "Score"
    @State var title = "Edit a Game"
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Game.date, order: .reverse)]
    @AppStorage("selectedGameCriteria") var selectedSortCriteria: SortCriteria = .dateAsc

    // Free tier: remaining game creations for non‑premium users (Keychain-backed)
    @StateObject private var freeCreates = KeychainBackedCounter(key: "freeGameCreatesRemainingKC", defaultValue: 2)
    @State private var showPaywall: Bool = false
    @State private var paywallContext: PaywallContext = .general
    @State private var pendingCreation: PendingCreation?

    enum SortCriteria: String, CaseIterable, Identifiable {
        case dateAsc, dateDec, homeTeam, visitorTeam
        var id: String { self.rawValue }
    }

    // Used to pass a create intent from GameView back to here so we can enforce limits
    struct PendingCreation {
        let dateISO: String
        let field: String
        let everyOneHits: Bool
        let vTeam: Team
        let hTeam: Team
    }

    var sortDescriptor: [SortDescriptor<Game>] {
        switch selectedSortCriteria {
        case .dateAsc:
            return [SortDescriptor(\Game.date, order: .forward)]
        case .dateDec:
            return [SortDescriptor(\Game.date, order: .reverse)]
        case .homeTeam, .visitorTeam:
            return []
        }
    }

    var isPremium: Bool { purchaseManager.isSeasonPassActive }

    // Small extracted pieces to reduce type-checking pressure
    private var scoreEditOptions: [String] { ["Score", "Edit"] }

    private var freeCounterView: some View {
        Text(hSizeClass == .compact ? "Free games: \(freeCreates.value)" : "Free games: \(freeCreates.value)")
            .font(hSizeClass == .compact ? .caption2 : .caption)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .foregroundColor(.black)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
            .accessibilityLabel("Free games remaining \(freeCreates.value)")
    }

    var body: some View {
        // Precompute arguments to help the compiler
        let currentSearchText: String = searchText
        let currentSortOrder: [SortDescriptor<Game>] = sortDescriptor
        let titleBinding: Binding<String> = $title
        let navBinding: Binding<NavigationPath> = $path
        let columnBinding: Binding<NavigationSplitViewVisibility> = $columnVisability
        let requestUpgrade: () -> Void = {
            paywallContext = .gameLimit
            showPaywall = true
        }
        let requestCreateGame: (String, String, Bool, Team, Team, Bool) -> Void = { dateISO, field, everyOneHits, vTeam, hTeam, isSeeded in
            handleCreateGame(dateISO: dateISO, field: field, everyOneHits: everyOneHits, vTeam: vTeam, hTeam: hTeam, isSeeded: isSeeded)
        }
        let currentSortMode: GameView.GameSort = {
            switch selectedSortCriteria {
            case .dateAsc:     return .dateAsc
            case .dateDec:     return .dateDec
            case .homeTeam:    return .homeTeam
            case .visitorTeam: return .visitorTeam
            }
        }()

        NavigationStack(path: $path) {
            GameView(
                searchString: currentSearchText,
                sortOrder: currentSortOrder,
                sortMode: currentSortMode,
                title: titleBinding,
                navigationPath: navBinding,
                columnVisability: columnBinding,
                createGame: requestCreateGame
            )
            .navigationDestination(for: Game.self) { game in
                destinationView(for: game)
            }
            .onAppear {
                addAGame = false
                // DEBUG-only: give ourselves a budget for testing
                #if DEBUG
                if freeCreates.value != 2 {
                    freeCreates.set(2)
                }
                #endif
            }
            .toolbar {
                // Leading: Sort menu
                ToolbarItemGroup(placement: .topBarLeading) {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort", selection: $selectedSortCriteria) {
                            ForEach(SortCriteria.allCases) { criteria in
                                if criteria == .dateAsc {
                                    Text("Date (A-Z)").tag(criteria)
                                } else if criteria == .dateDec {
                                    Text("Date (Z-A)").tag(criteria)
                                } else if criteria == .homeTeam {
                                    Text("Home Team (A-Z)").tag(criteria)
                                } else if criteria == .visitorTeam {
                                    Text("Visitor Team (A-Z)").tag(criteria)
                                }
                            }
                        }
                    }
                }

                // Leading: Add Team
                ToolbarItem(placement: .topBarLeading) {
                    addTeamToolbarButton()
                }

                // Leading: Score/Edit segmented control placed immediately to the right of Add Team
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Select Option", selection: $doGame) {
                        ForEach(scoreEditOptions, id: \.self) { option in
                            Text(option)
                        }
                    }
                    .modifier(SegmentedSizingModifier())
                }

                // Trailing: search icon on iPhone only
                ToolbarItem(placement: .topBarTrailing) {
                    if UIDevice.type == "iPhone" {
                        Button(action: {
                            withAnimation {
                                isSearching.toggle()
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel("Search")
                    }
                }

                // Trailing: Always-visible premium counter (compact-aware)
                ToolbarItem(placement: .topBarTrailing) {
                    Group {
                        if isPremium {
                            PremiumBadgeView(isCompact: hSizeClass == .compact)
                        } else {
                            freeCounterView
                        }
                    }
                }

                // Trailing: Upgrade button (only show when not premium)
                ToolbarItem(placement: .topBarTrailing) {
                    if !isPremium {
                        Button {
                            requestUpgrade()
                        } label: {
                            Text("Upgrade")
                        }
                        .buttonStyle(ToolBarButtonStyle())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                        .accessibilityLabel("Upgrade to Season Pass")
                    }
                }
            }
            .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: "YYYY-MM-DD or any text")
            .onAppear {
                UISegmentedControl.appearance().selectedSegmentTintColor = .systemBlue.withAlphaComponent(0.2)
                title = "\(doGame) a Game"
                if doGame == "Score" {
                    columnVisability = .detailOnly
                } else {
                    columnVisability = .doubleColumn
                }
            }
            .onChange(of: sortDescriptor) {
                sortOrder = sortDescriptor
            }
            .onChange(of: doGame) {
                title = "\(doGame) a Game"
                if doGame == "Score" {
                    columnVisability = .detailOnly
                } else {
                    columnVisability = .doubleColumn
                }
            }
            .navigationDestination(for: Team.self) { team in
                EditTeamView(navigationPath: $path, team: team)
            }
            .onChange(of: isSearching) {
                if isSearching == false {
                    searchText = ""
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            paywallSheetContent()
        }
    }

    // Extracted to reduce type-checking pressure
    @ViewBuilder
    private func destinationView(for game: Game) -> some View {
        if addAGame || game.date == "" || game.hteam?.name ?? "" == "" || game.hteam?.name ?? "" == "" || doGame == "Edit" {
            EditGameView(game: game, navigationPath: $path)
        } else {
            EditScoreView(pgame: game, pnavigationPath: $path, ateam: game.vteam?.name ?? "", columnVisability: columnVisabilityProxy)
        }
    }

    // Proxy binding to match EditScoreView’s expected name in init
    private var columnVisabilityProxy: Binding<NavigationSplitViewVisibility> {
        $columnVisability
    }

    @ViewBuilder
    private func addTeamToolbarButton() -> some View {
        if #available(iOS 26.0, *) {
            Button {
                addBlankTeam()
            } label: {
                Text("Add Team")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
            .buttonStyle(.glassProminent)
            .tint(.blue.opacity(0.075))
        } else {
            Button("Add Team") {
                addBlankTeam()
            }
            .buttonStyle(ToolBarButtonStyle())
        }
    }

    private func addBlankTeam() {
        let team = Team(name: "", coach: "", details: "")
        modelContext.insert(team)
        try? modelContext.save()
        path.append(team)
    }

    // MARK: - Paywall sheet content (extracted)
    @ViewBuilder
    private func paywallSheetContent() -> some View {
        PaywallView(context: paywallContext)
            .environmentObject(purchaseManager)
            // Force the largest detent so the sheet opens tall and avoids cramped scrolling
            .presentationDetents([.large])
            // Optional: hide the drag indicator to reduce accidental collapsing (iOS 16+)
            .modifier(PresentationDragIndicatorHidden())
    }

    // MARK: - Creation gating

    private func handleCreateGame(dateISO: String, field: String, everyOneHits: Bool, vTeam: Team, hTeam: Team, isSeeded: Bool) {
        if isPremium {
            createGame(dateISO: dateISO, field: field, everyOneHits: everyOneHits, vTeam: vTeam, hTeam: hTeam)
            return
        }

        // If this is a seeded creation, do not decrement free counter
        if isSeeded {
            createGame(dateISO: dateISO, field: field, everyOneHits: everyOneHits, vTeam: vTeam, hTeam: hTeam)
            return
        }

        guard freeCreates.value > 0 else {
            paywallContext = .gameLimit
            showPaywall = true
            return
        }

        createGame(dateISO: dateISO, field: field, everyOneHits: everyOneHits, vTeam: vTeam, hTeam: hTeam)
        // Decrement remaining free creates for non-premium (user-initiated only)
        freeCreates.set(freeCreates.value - 1)
    }

    private func createGame(dateISO: String, field: String, everyOneHits: Bool, vTeam: Team, hTeam: Team) {
        let theGame = Game(date: dateISO, location: field, highLights: "", hscore: 0, vscore: 0, everyOneHits: everyOneHits, vteam: vTeam, hteam: hTeam)
        modelContext.insert(theGame)
        try? self.modelContext.save()
    }

    func addGame() {
        let game = Game(date: "" ,location: "",highLights: "",hscore: 0, vscore: 0)
        modelContext.insert(game)
        path.append(game)
        addAGame = true
        print(addAGame)
        try? modelContext.save()
    }
}

// A small modifier to encapsulate the iOS-version-conditional sizing/styling
private struct SegmentedSizingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .pickerStyle(.segmented)
                .controlSize(.regular)
                .frame(minWidth: 120) // ensure “Score” and “Edit” fit
        } else {
            content
                .pickerStyle(SegmentedPickerStyle())
        }
    }
}

// Wrap the drag indicator to avoid availability and inference issues
private struct PresentationDragIndicatorHidden: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            // Use SwiftUI.Visibility
            return content.presentationDragIndicator(Visibility.hidden)
        } else {
            return content
        }
    }
}

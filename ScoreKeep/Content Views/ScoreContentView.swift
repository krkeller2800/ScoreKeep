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
    @EnvironmentObject private var wakeRestoration: ActiveScoringWakeRestorationCoordinator
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Binding var columnVisability: NavigationSplitViewVisibility

    var onOpenImportFlow: () -> Void = {}
    var onOpenExportFlow: () -> Void = {}
    var onOpenHelp: () -> Void = {}

    @State private var path = NavigationPath()
    @SceneStorage("activeScoringGameID") private var activeScoringGameID: String?
    @SceneStorage("activeScoringSessionNeedsRestore") private var activeScoringSessionNeedsRestore = false
    @SceneStorage("activeScoringColumnVisibility") private var activeScoringColumnVisibility: String?
    @State private var addAGame: Bool = false
    @State private var isSearching: Bool = false
    @State var doGame = "Score"
    @State var title = "Edit a Game"
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Game.date, order: .reverse)]
    @AppStorage("selectedGameCriteria") var selectedSortCriteria: SortCriteria = .dateAsc

    // Free tier: remaining game creations for non‑premium users (Keychain-backed)
    @StateObject private var freeCreates = KeychainBackedCounter(
        key: FreeGameAllowanceState.counterKey,
        defaultValue: FreeGameAllowanceState.defaultRemaining,
        invalidStoredValue: FreeGameAllowanceState.invalidStoredRemaining
    )
    @State private var showPaywall: Bool = false
    @State private var paywallContext: PaywallContext = .general
    @State private var pendingCreation: PendingCreation?
    @State private var interruptedWorkflow: PaywallInterruptedWorkflow?
    @State private var gameCreationAllowanceTransaction = GameCreationAllowanceTransaction()
    private let paywallResumePolicy = PaywallResumePolicy()
    private let purchaseDecisionAuthority = PurchaseDecisionAuthority()

    enum SortCriteria: String, CaseIterable, Identifiable {
        case dateAsc, dateDec, homeTeam, visitorTeam
        var id: String { self.rawValue }
    }

    // Used to pass a create intent from GameView back to here so we can enforce limits
    struct PendingCreation {
        let dateISO: String
        let field: String
        let everyOneHits: Bool
        let numInnings: Int
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

    var isPremium: Bool {
        purchaseDecisionAuthority
            .decision(for: purchaseManager.entitlementState)
            .permitsCurrentSeasonAccess
    }

    private var freeGameAllowance: FreeGameAllowanceState {
        FreeGameAllowanceState(
            remaining: freeCreates.value,
            storageInterpretation: freeCreates.storageInterpretation
        )
    }

    init(
        columnVisability: Binding<NavigationSplitViewVisibility>,
        onOpenImportFlow: @escaping () -> Void = {},
        onOpenExportFlow: @escaping () -> Void = {},
        onOpenHelp: @escaping () -> Void = {}
    ) {
        _columnVisability = columnVisability
        self.onOpenImportFlow = onOpenImportFlow
        self.onOpenExportFlow = onOpenExportFlow
        self.onOpenHelp = onOpenHelp
    }

    // Small extracted pieces to reduce type-checking pressure
    private var scoreEditOptions: [String] { ["Score", "Edit"] }

    private var freeCounterView: some View {
        Text(freeGameAllowance.displayText)
            .font(hSizeClass == .compact ? .caption2 : .caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .foregroundStyle(ScoreKeepVisualStyle.secondaryText)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
            .accessibilityLabel(freeGameAllowance.accessibilityLabel)
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
        let requestCreateGame: (String, String, Bool, Int, Team, Team, Bool) -> Void = { dateISO, field, everyOneHits, numInnings, vTeam, hTeam, isSeeded in
            handleCreateGame(dateISO: dateISO, field: field, everyOneHits: everyOneHits, numInnings: numInnings, vTeam: vTeam, hTeam: hTeam, isSeeded: isSeeded)
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
            Group {
                if isResolvingPendingActiveScoringRestore {
                    activeScoringRestorePlaceholder
                } else {
                    GameView(
                        searchString: currentSearchText,
                        sortOrder: currentSortOrder,
                        sortMode: currentSortMode,
                        title: titleBinding,
                        navigationPath: navBinding,
                        columnVisability: columnBinding,
                        createGame: requestCreateGame
                    )
                    .phoneSettingsGearIfRoot(
                        onOpenImportFlow: onOpenImportFlow,
                        onOpenExportFlow: onOpenExportFlow,
                        onOpenHelp: onOpenHelp
                    )
                }
            }
            .navigationDestination(for: Game.self) { game in
                destinationView(for: game)
            }
            .onAppear {
                addAGame = false
                applyDebugFreeGameAllowanceResetIfNeeded()
            }
            .onChange(of: path) {
                if path.isEmpty {
                    activeScoringGameID = nil
                    activeScoringSessionNeedsRestore = false
                    activeScoringColumnVisibility = nil
                    wakeRestoration.clearCurrentProcessWakeRestore()
                }
            }
            .toolbar {
                // Leading: Sort menu
                ToolbarItemGroup(placement: .topBarLeading) {
                    if !isResolvingPendingActiveScoringRestore {
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
                }

                // Leading: Score/Edit segmented control
                ToolbarItem(placement: .topBarLeading) {
                    if !isResolvingPendingActiveScoringRestore {
                        Picker("Select Option", selection: $doGame) {
                            ForEach(scoreEditOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .modifier(SegmentedSizingModifier())
                    }
                }

                // Trailing: search icon on iPhone only
                ToolbarItem(placement: .topBarTrailing) {
                    if !isResolvingPendingActiveScoringRestore && UIDevice.type == "iPhone" {
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
                    if !isResolvingPendingActiveScoringRestore {
                        Group {
                            if isPremium {
                                PremiumBadgeView(isCompact: hSizeClass == .compact)
                            } else {
                                freeCounterView
                            }
                        }
                    }
                }

                // Trailing: Upgrade button (only show when not premium)
                ToolbarItem(placement: .topBarTrailing) {
                    if !isResolvingPendingActiveScoringRestore && !isPremium {
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
            .searchable(if: isSearching && !isResolvingPendingActiveScoringRestore, text: $searchText, placement: .toolbar, prompt: "YYYY-MM-DD or any text")
            .onAppear {
                UISegmentedControl.appearance().selectedSegmentTintColor = .systemBlue.withAlphaComponent(0.2)
                title = "\(doGame) a Game"
            }
            .onChange(of: sortDescriptor) {
                sortOrder = sortDescriptor
            }
            .onChange(of: doGame) {
                title = "\(doGame) a Game"
            }
            .navigationDestination(for: TeamNavigationDestination.self) { destination in
                TeamNavigationDestinationView(destination: destination, navigationPath: $path)
            }
            .onChange(of: isSearching) {
                if isSearching == false {
                    searchText = ""
                }
            }
        }
        .sheet(isPresented: $showPaywall, onDismiss: cancelPendingCreationIfPaywallStillUnresolved) {
            paywallSheetContent()
        }
        .onReceive(purchaseManager.$entitlementState) { entitlementState in
            if purchaseDecisionAuthority.decision(for: entitlementState).permitsCurrentSeasonAccess {
                resumePendingCreationIfAllowed()
            }
        }
        .onChange(of: freeCreates.value) {
            resumePendingCreationIfAllowed()
        }
        .onChange(of: scenePhase) {
            handleScenePhaseChange(scenePhase)
        }
        .task {
            restoreActiveScoringSessionIfNeeded()
        }
    }

    private var isResolvingPendingActiveScoringRestore: Bool {
        ActiveScoringWakeRestorationPolicy.shouldShowRestoreProgress(
            hasPersistentRestoreIntent: activeScoringSessionNeedsRestore,
            isCurrentProcessWakeRestore: wakeRestoration.isRestoringFromCurrentProcessWake,
            pathIsEmpty: path.isEmpty,
            hasValidGameID: activeScoringGameID.flatMap(UUID.init(uuidString:)) != nil
        )
    }

    private var activeScoringRestorePlaceholder: some View {
        ZStack {
            ScoreKeepVisualStyle.background
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("Restoring game...")
                    .font(.callout)
                    .foregroundStyle(ScoreKeepVisualStyle.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Restoring game")
        }
    }

    // Extracted to reduce type-checking pressure
    @ViewBuilder
    private func destinationView(for game: Game) -> some View {
        if addAGame || game.date == "" || game.hteam?.name ?? "" == "" || game.hteam?.name ?? "" == "" || doGame == "Edit" {
            EditGameView(game: game, navigationPath: $path)
        } else {
            EditScoreView(pgame: game, pnavigationPath: $path, ateam: game.vteam?.name ?? "", columnVisability: columnVisabilityProxy)
                .onAppear {
                    rememberActiveScoringSession(for: game)
                }
        }
    }

    // Proxy binding to match EditScoreView’s expected name in init
    private var columnVisabilityProxy: Binding<NavigationSplitViewVisibility> {
        $columnVisability
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

    private func handleCreateGame(dateISO: String, field: String, everyOneHits: Bool, numInnings: Int, vTeam: Team, hTeam: Team, isSeeded: Bool) {
        if isPremium {
            _ = createGame(dateISO: dateISO, field: field, everyOneHits: everyOneHits, numInnings: numInnings, vTeam: vTeam, hTeam: hTeam)
            return
        }

        // If this is a seeded creation, do not decrement free counter
        if isSeeded {
            _ = createGame(dateISO: dateISO, field: field, everyOneHits: everyOneHits, numInnings: numInnings, vTeam: vTeam, hTeam: hTeam)
            return
        }

        guard freeGameAllowance.canCreateWithAllowance else {
            pendingCreation = PendingCreation(
                dateISO: dateISO,
                field: field,
                everyOneHits: everyOneHits,
                numInnings: numInnings,
                vTeam: vTeam,
                hTeam: hTeam
            )
            interruptedWorkflow = .gameCreation
            paywallContext = .gameLimit
            showPaywall = true
            return
        }

        guard let game = createGame(dateISO: dateISO, field: field, everyOneHits: everyOneHits, numInnings: numInnings, vTeam: vTeam, hTeam: hTeam) else {
            return
        }

        applySuccessfulGameCreationAllowanceTransaction(for: game.ident)
    }

    private func applyDebugFreeGameAllowanceResetIfNeeded() {
        #if DEBUG
        if freeCreates.value != FreeGameAllowanceState.defaultRemaining {
            freeCreates.set(FreeGameAllowanceState.defaultRemaining)
        }
        #endif
    }

    private func rememberActiveScoringSession(for game: Game) {
        guard doGame == "Score" else { return }
        activeScoringGameID = game.ident.uuidString
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .inactive, .background:
            if activeScoringGameID != nil, !path.isEmpty {
                wakeRestoration.markCurrentProcessWakeRestoreNeeded()
                activeScoringSessionNeedsRestore = true
                activeScoringColumnVisibility = ActiveScoringSidebarVisibilityRestoration.token(for: columnVisability)
            }
        case .active:
            restoreActiveScoringSessionIfNeeded()
        @unknown default:
            break
        }
    }

    private func restoreActiveScoringSessionIfNeeded() {
        switch ActiveScoringWakeRestorationPolicy.resolution(
            hasPersistentRestoreIntent: activeScoringSessionNeedsRestore,
            isCurrentProcessWakeRestore: wakeRestoration.isRestoringFromCurrentProcessWake,
            pathIsEmpty: path.isEmpty,
            hasValidGameID: activeScoringGameID.flatMap(UUID.init(uuidString:)) != nil
        ) {
        case .noRestoreNeeded:
            return
        case .clearStalePersistentRestore:
            activeScoringSessionNeedsRestore = false
            activeScoringColumnVisibility = nil
            return
        case .preserveExistingPath:
            return
        case .clearFailedRestore:
            activeScoringSessionNeedsRestore = false
            activeScoringGameID = nil
            activeScoringColumnVisibility = nil
            wakeRestoration.clearCurrentProcessWakeRestore()
            return
        case .rebuildPath:
            break
        }

        guard let gameIDString = activeScoringGameID, let uuid = UUID(uuidString: gameIDString) else { return }
        let fetchDescriptor = FetchDescriptor<Game>(predicate: #Predicate { $0.ident == uuid })
        guard let gameToRestore = try? modelContext.fetch(fetchDescriptor).first else {
            activeScoringSessionNeedsRestore = false
            activeScoringGameID = nil
            wakeRestoration.clearCurrentProcessWakeRestore()
            return
        }

        doGame = "Score"
        path.append(gameToRestore)
        if let restoredColumnVisibility = ActiveScoringSidebarVisibilityRestoration.visibility(for: activeScoringColumnVisibility) {
            columnVisability = restoredColumnVisibility
        }
        wakeRestoration.clearCurrentProcessWakeRestore()
    }

    private func applySuccessfulGameCreationAllowanceTransaction(for gameID: UUID) {
        let result = gameCreationAllowanceTransaction.successfulPersistedCreation(
            gameID: gameID,
            allowance: freeGameAllowance
        )

        if case .consume = result {
            freeCreates.set(freeCreates.value - 1)
        }
    }

    private func resumePendingCreationIfAllowed() {
        guard let pendingCreation else { return }

        let decision = paywallResumePolicy.decision(
            for: interruptedWorkflow,
            isEntitled: isPremium,
            hasAllowance: freeGameAllowance.canCreateWithAllowance
        )

        guard case .resume = decision else { return }

        self.pendingCreation = nil
        interruptedWorkflow = nil
        showPaywall = false

        handleCreateGame(
            dateISO: pendingCreation.dateISO,
            field: pendingCreation.field,
            everyOneHits: pendingCreation.everyOneHits,
            numInnings: pendingCreation.numInnings,
            vTeam: pendingCreation.vTeam,
            hTeam: pendingCreation.hTeam,
            isSeeded: false
        )
    }

    private func cancelPendingCreationIfPaywallStillUnresolved() {
        guard pendingCreation != nil else { return }

        let decision = paywallResumePolicy.decision(
            for: interruptedWorkflow,
            isEntitled: isPremium,
            hasAllowance: freeGameAllowance.canCreateWithAllowance
        )

        switch decision {
        case .resume:
            resumePendingCreationIfAllowed()
        case .blocked, .canceled:
            _ = gameCreationAllowanceTransaction.nonQualifying(.canceled)
            pendingCreation = nil
            interruptedWorkflow = nil
        }
    }

    private func createGame(dateISO: String, field: String, everyOneHits: Bool, numInnings: Int, vTeam: Team, hTeam: Team) -> Game? {
        let theGame = Game(date: dateISO, location: field, highLights: "", hscore: 0, vscore: 0, everyOneHits: everyOneHits, numInnings: numInnings, vteam: vTeam, hteam: hTeam)
        modelContext.insert(theGame)
        do {
            try self.modelContext.save()
            return theGame
        } catch {
            return nil
        }
    }

    func addGame() {
        let game = Game(date: "" ,location: "",highLights: "",hscore: 0, vscore: 0)
        modelContext.insert(game)
        path.append(game)
        addAGame = true
        #if DEBUG
        print(addAGame)
        #endif
        try? modelContext.save()
    }
}

// A small modifier to encapsulate the iOS-version-conditional sizing/styling
private struct SegmentedSizingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 108)
        } else {
            content
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 108)
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

extension View {
    @ViewBuilder
    func phoneSettingsGearIfRoot(
        onOpenImportFlow: @escaping () -> Void,
        onOpenExportFlow: @escaping () -> Void,
        onOpenHelp: @escaping () -> Void
    ) -> some View {
        if UIDevice.type == "iPhone" {
            self.scoreKeepPhoneSettingsEntryPoint(
                onOpenImportFlow: onOpenImportFlow,
                onOpenExportFlow: onOpenExportFlow,
                onOpenHelp: onOpenHelp
            )
        } else {
            self
        }
    }
}

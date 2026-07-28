//
//  GameView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/16/25.
//

import SwiftUI
import SwiftData
import Foundation
@MainActor
struct GameView: View {
    @Environment(\.modelContext) var modelContext
    @Binding var navigationPath: NavigationPath
    @Binding private var title: String
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @State private var showingValidationAlert = false
    @State private var alertMessage = ""
    @State private var gamePendingDeletion: Game?
    @State private var date: Date = Date()
    @State private var theDate:  String = ""
    @State private var field: String = ""
    @State private var everyOneHits = false
    @State private var vTeam: Team?
    @State private var hTeam: Team?

    // New: closure to delegate creation to parent (ScoreContentView)
    // Updated to include isSeeded flag so parent can skip decrementing free counter for seeded creations.
    var createGame: (String, String, Bool, Team, Team, Bool) -> Void

    // Seed hint flags
    @AppStorage("hasSeededInitialGame") private var hasSeededInitialGame: Bool = false
    @AppStorage("hasDismissedSeedHint_Game") private var hasDismissedSeedHint_Game: Bool = false

    enum FocusField: Hashable {case field}

    enum GameSort {
        case dateAsc, dateDec, homeTeam, visitorTeam
    }

    @FocusState private var focusedField: FocusField?
    
    let com = Common()
    let sortMode: GameSort
    
    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]
    
    @Query var games: [Game]
    @Query var atbats: [Atbat]
    @Query var pitchers: [Pitcher]
    @Query var lineups: [Lineup]
    
    // In-memory sorted view of games for team-based sorts
    var displayedGames: [Game] {
        switch sortMode {
        case .homeTeam:
            return games.sorted { ($0.hteam?.name ?? "") < ($1.hteam?.name ?? "") }
        case .visitorTeam:
            return games.sorted { ($0.vteam?.name ?? "") < ($1.vteam?.name ?? "") }
        case .dateAsc, .dateDec:
            return games
        }
    }
    
    // Hide seed hint if the user has added their own content
    private var hasUserContent: Bool {
        // Heuristics: if there's more than the initial seeded game or more than the initial seeded teams
        // Adjust thresholds if your seed data differs
        let userHasExtraGames = games.count > 1
        let userHasExtraTeams = teams.count > 2
        return userHasExtraGames || userHasExtraTeams
    }
    
    // If there is exactly one game and it's not the seeded date (Dec 15, 2025), suppress the banner
    private var singleNonSeededGameExists: Bool {
        guard games.count == 1, let only = games.first else { return false }
        let formatter = ISO8601DateFormatter()
        guard let gameDate = formatter.date(from: only.date) else { return false }

        var comps = DateComponents()
        comps.year = 2025
        comps.month = 11
        comps.day = 1
        let cal = Calendar.current
        var tzComps = comps
        tzComps.calendar = cal
        tzComps.timeZone = cal.timeZone
        guard let target = cal.date(from: tzComps) else { return false }

        // Compare by just the calendar day in the user's locale/time zone
        return !cal.isDate(gameDate, inSameDayAs: target)
    }
    
    private var dateWidth: CGFloat { UIDevice.type == "iPhone" && title.isEmpty ? 100 : 265 }

    var body: some View {
        ZStack {
            ScoreKeepVisualStyle.background
                .ignoresSafeArea()

            VStack(spacing: 8) {
                // NOTE: Hint removed from layout — now shown via overlay below.

                Form {
                    if games.count > 0 {
                        if self.title == "Edit a Game" && UIDevice.type == "iPad" {
                            Text("Select a Game to edit or swipe to delete")
                                .frame(maxWidth:.infinity, alignment:.leading)
                                .font(.title3.bold())
                                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                        } else if self.title == "Score a Game" && UIDevice.type == "iPad" {
                            Text("Select a Game to score or swipe to delete")
                                .frame(maxWidth:.infinity, alignment:.leading)
                                .font(.title3.bold())
                                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                        }
                    }
                    headerRow()
                    if !title.isEmpty {
                        inputRow()
                    }
                    ForEach(displayedGames, id: \.ident) { game in
                        NavigationLink(value: game) {
                            gameRow(for: game)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                gamePendingDeletion = game
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(gameCardBackground)
                    .listRowSeparatorTint(Color(UIColor.opaqueSeparator))
                }
                .shadow(color: Color.primary.opacity(0.08), radius: 4, x: 0, y: 2)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .alert(alertMessage, isPresented: $showingValidationAlert) {
                    Button("OK", role: .cancel) { }
                }
                .alert(
                    "Deleting a Game",
                    isPresented: Binding(
                        get: { gamePendingDeletion != nil },
                        set: { if !$0 { gamePendingDeletion = nil } }
                    ),
                    presenting: gamePendingDeletion
                ) { game in
                    Button("Delete", role: .destructive) {
                        delete(game)
                    }
                    Button("Cancel", role: .cancel) {
                        gamePendingDeletion = nil
                    }
                } message: { _ in
                    Text("If a game is deleted all associated at bats and pitches will also be deleted and removed from the stats")
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(self.title)
                            .font(.title2)
                            .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                        }
                }
            }
        }
        // Top overlay banner (no layout space taken)
        .overlay(alignment: .topTrailing) {
//            let _ = print(" \(hasSeededInitialGame) \(!hasDismissedSeedHint_Game) \(!hasUserContent) \(!singleNonSeededGameExists)")
            if hasSeededInitialGame && !hasDismissedSeedHint_Game && !hasUserContent && !singleNonSeededGameExists {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .imageScale(.small)
                    Text("Sample game added — try scoring it and check out the stats.")
                        .font(.caption)
                        .scorebookMultiLineText()
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasDismissedSeedHint_Game = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(ScoreKeepVisualStyle.infoBannerForeground)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(ScoreKeepVisualStyle.infoBannerBackground, in: Capsule())
                .foregroundStyle(ScoreKeepVisualStyle.infoBannerForeground)
                .padding(.top, -4)
                .padding(.trailing, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.25), value: hasDismissedSeedHint_Game)
            }
        }
    }
    init(searchString: String = "", sortOrder: [SortDescriptor<Game>] = [], sortMode: GameSort, title:Binding<String>, navigationPath: Binding<NavigationPath>, columnVisability: Binding<NavigationSplitViewVisibility>, createGame: @escaping (String, String, Bool, Team, Team, Bool) -> Void) {
        
        _title = title
        _navigationPath = navigationPath
        _columnVisibility = columnVisability
        self.sortMode = sortMode
        self.createGame = createGame
        
        let effectiveSort: [SortDescriptor<Game>] = {
            switch sortMode {
            case .homeTeam, .visitorTeam:
                // Avoid passing relationship-based sorts to SwiftData on device
                return []
            case .dateAsc, .dateDec:
                return sortOrder
            }
        }()
        
        _games = Query(filter: #Predicate { game in
            if !searchString.isEmpty {
                return game.hteam?.name.localizedStandardContains(searchString) ?? false ||
                       game.vteam?.name.localizedStandardContains(searchString) ?? false ||
                       game.location.localizedStandardContains(searchString) ||
                       game.date.localizedStandardContains(searchString)
            } else {
                return true
            }
        },  sort: effectiveSort)
    }
    private func scoreSummary(for game: Game, homeTeamName: String, visitingTeamName: String) -> (homeRuns: Int, visitingRuns: Int, outs: Int) {
        let gameAtbats = atbats.filter { $0.game == game }
        let homeRuns = gameAtbats.filter { $0.maxbase == "Home" && $0.team.name == homeTeamName }.count
        let visitingRuns = gameAtbats.filter { $0.maxbase == "Home" && $0.team.name == visitingTeamName }.count
        let outs = gameAtbats.filter {
            $0.team.name == visitingTeamName &&
            (com.outresults.contains($0.result) || $0.outAt != "Safe")
        }.count

        return (homeRuns, visitingRuns, outs)
    }

    private func delete(_ game: Game) {
        for atbat in atbats.filter({ $0.game == game }) {
            modelContext.delete(atbat)
        }
        for pitcher in pitchers.filter({ $0.game == game }) {
            modelContext.delete(pitcher)
        }
        for lineup in lineups.filter({ $0.game == game }) {
            modelContext.delete(lineup)
        }
        modelContext.delete(game)
        gamePendingDeletion = nil
    }

    @ViewBuilder
    private func headerRow() -> some View {
        HStack(spacing: 0) {
            scorebookHeaderCell("Game Date", semantic: true)
                .gameFixedColumn(width: dateWidth)
                .gameTrailingSeparator()
            if !title.isEmpty {
                scorebookHeaderCell("Field", semantic: true)
                    .gameFlexibleColumn()
                    .gameTrailingSeparator()
                scorebookHeaderCell("All Hit", semantic: true)
                    .gameFixedColumn(width: 58)
                    .gameTrailingSeparator()
            }

            scorebookHeaderCell("Visiting", semantic: true)
                .gameFlexibleColumn()
                .gameTrailingSeparator()
            scorebookHeaderCell("Home", semantic: true)
                .gameFlexibleColumn()
                .gameTrailingSeparator()
            if !title.isEmpty {
                scorebookHeaderCell("Score", semantic: true)
                    .gameFlexibleColumn()
                    .gameTrailingSeparator()
            }
            Color.clear.gameFixedColumn(width: title.isEmpty ? 0 : 34)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 6)
        .background(ScoreKeepVisualStyle.contentSurface)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(ScoreKeepVisualStyle.contentSurface)
    }

    @ViewBuilder
    private func inputRow() -> some View {
        HStack(spacing: 0) {
            DatePicker("", selection: $date)
                .onAppear {
                    date = ISO8601DateFormatter().date(from: theDate) ?? Date()
                }
                .onChange(of: date) {
                    theDate = date.ISO8601Format()
                }
                .labelsHidden()
                .padding(.horizontal, 4)
                .gameFixedColumn(width: dateWidth, alignment: .leading)
                .clipped()
                .gameTrailingSeparator()
            TextField("Field", text: $field)
                .foregroundStyle(ScoreKeepVisualStyle.accent)
                .fontWeight(.semibold)
                .focused($focusedField, equals: .field)
                .autocapitalization(.words)
                .textContentType(.none)
                .padding(.horizontal, 8)
                .gameFlexibleColumn(alignment: .leading)
                .gameTrailingSeparator()
            Button(action:{everyOneHits.toggle()}){
                Text(everyOneHits ? "True" : "False")
                    .frame(height: 30)
                    .gameFixedColumn(width: 58)
                    .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                    .fontWeight(.semibold)
                    .background(everyOneHits ? ScoreKeepVisualStyle.selectedFill : ScoreKeepVisualStyle.disabledFill, in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(PlainButtonStyle())
                .gameTrailingSeparator()
            Picker("Visiting Team", selection: $vTeam) {
                Text("Pick").tag(Optional<Team>.none)
                if teams.isEmpty == false {
                    Divider()
                    ForEach(teams, id: \.ident) { team in
                        if team.name != "" {
                            Text(team.name).tag(Optional(team))
                        }
                    }
                }
            }
            .labelsHidden().pickerStyle(.menu).tint(ScoreKeepVisualStyle.accent)
            .gameFlexibleColumn()
            .gameTrailingSeparator()
            Picker("Home Team", selection: $hTeam) {
                Text("Pick").tag(Optional<Team>.none)
                if teams.isEmpty == false {
                    Divider()
                    ForEach(teams, id: \.ident) { team in
                        if team.name != "" {
                            Text(team.name).tag(Optional(team))
                        }
                    }
                }
            }
            .labelsHidden().pickerStyle(.menu).tint(ScoreKeepVisualStyle.accent)
            .gameFlexibleColumn()
            .gameTrailingSeparator()
            Text("Not Played")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .fontWeight(.medium)
                .scorebookMultiLineText()
                .padding(.horizontal, 8)
                .gameFlexibleColumn()
                .gameTrailingSeparator()
            Button {
                if let vTeam, let hTeam {
                    createGame(theDate, field, everyOneHits, vTeam, hTeam, false)
                    field = ""; self.hTeam = nil; self.vTeam = nil; everyOneHits = false
                } else {
                    alertMessage = "You must select a Home and Visiting Team!"
                    showingValidationAlert = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ScoreKeepVisualStyle.accent)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                    }
            .buttonStyle(.plain)
            .gameFixedColumn(width: 34)
        }
        .padding(.vertical, 8)
        .background(ScoreKeepVisualStyle.contentSurface)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(ScoreKeepVisualStyle.contentSurface)
    }

    @ViewBuilder
    private func gameRow(for game: Game) -> some View {
        HStack(spacing: 0) {
            let dateVal = ISO8601DateFormatter().date(from: game.date) ?? Date()
            Text(dateVal.formatted(date:.abbreviated, time: .shortened))
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .scorebookMultiLineText()
                .gameFixedColumn(width: dateWidth, alignment: .leading)
                .gameTrailingSeparator()
            if !title.isEmpty {
                Text(game.location)
                    .foregroundStyle(game.location.isEmpty ? ScoreKeepVisualStyle.disabledText : ScoreKeepVisualStyle.primaryText)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .scorebookMultiLineText()
                    .gameFlexibleColumn(alignment: .leading)
                    .gameTrailingSeparator()
                Text(game.everyOneHits ? "True" : "False")
                    .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                    .fontWeight(.semibold)
                    .scorebookSingleLineText()
                    .gameFixedColumn(width: 58)
                    .gameTrailingSeparator()
            }
            teamCell(name: game.vteam?.name ?? "", logoData: game.vteam?.logo)
                .gameFlexibleColumn(alignment: .leading)
                .gameTrailingSeparator()
            teamCell(name: game.hteam?.name ?? "", logoData: game.hteam?.logo)
                .gameFlexibleColumn(alignment: .leading)
                .gameTrailingSeparator()
            if !title.isEmpty {
                gameRowScoreSummary(for: game)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func gameRowScoreSummary(for game: Game) -> some View {
        if let hName = game.hteam?.name, let vName = game.vteam?.name {
            let summary = scoreSummary(for: game, homeTeamName: hName, visitingTeamName: vName)
            let inning = max(1, (summary.outs / 3) + 1)
            let inningText: String = {
                if com.innAbr.indices.contains(inning) {
                    return com.innAbr[inning]
                } else {
                    return "Inning \(inning)"
                }
            }()

            let hShort = hName.components(separatedBy: " ").last ?? hName
            let vShort = vName.components(separatedBy: " ").last ?? vName
            let winner = summary.visitingRuns > summary.homeRuns ? vShort : (summary.visitingRuns < summary.homeRuns ? hShort : "")
            let isFinal = inning >= 9 && !winner.isEmpty
            let suffix = isFinal ? " Final" : " in \(inningText)"

            Text("\(summary.visitingRuns) to \(summary.homeRuns) \(winner)\(suffix)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .scorebookMultiLineText()
                .gameFlexibleColumn(alignment: .leading)
                .gameTrailingSeparator()
        } else {
            Text("Game teams not set")
                .foregroundStyle(ScoreKeepVisualStyle.secondaryText)
                .padding(.horizontal, 8)
                .gameFlexibleColumn(alignment: .leading)
                .gameTrailingSeparator()
        }
    }

    private func teamCell(name: String, logoData: Data?) -> some View {
        HStack(spacing: 8) {
            logoThumbnail(logoData)

            teamNameText(name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func teamNameText(_ name: String) -> some View {
        if name.contains(" ") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(teamNameLines(for: name).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .scorebookSingleLineText()
                }
            }
            .foregroundStyle(name.isEmpty ? ScoreKeepVisualStyle.disabledText : ScoreKeepVisualStyle.primaryText)
            .fontWeight(.semibold)
        } else {
            Text(name)
                .scorebookSingleLineText()
                .foregroundStyle(name.isEmpty ? ScoreKeepVisualStyle.disabledText : ScoreKeepVisualStyle.primaryText)
                .fontWeight(.semibold)
        }
    }

    private func teamNameLines(for name: String) -> [String] {
        let words = name.split(separator: " ").map(String.init)
        guard words.count > 2 else { return words }

        let splitIndex = Int(ceil(Double(words.count) / 2.0))
        return [
            words[..<splitIndex].joined(separator: " "),
            words[splitIndex...].joined(separator: " ")
        ]
    }

    @ViewBuilder
    private func logoThumbnail(_ logoData: Data?) -> some View {
        if let logoData, let uiImage = UIImage(data: logoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .padding(3)
                .frame(width: 38, height: 34)
                .background(ScoreKeepVisualStyle.adaptiveLogoTile, in: RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ScoreKeepVisualStyle.logoTileBorder, lineWidth: 0.75)
                )
                .accessibilityHidden(true)
        } else {
            Image(systemName: "baseball")
                .font(.caption)
                .foregroundStyle(ScoreKeepVisualStyle.secondaryText)
                .frame(width: 38, height: 34)
                .background(ScoreKeepVisualStyle.adaptiveLogoTile, in: RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ScoreKeepVisualStyle.logoTileBorder, lineWidth: 0.75)
                )
                .accessibilityHidden(true)
        }
    }

    private var gameCardBackground: Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.16, alpha: 1.0) : UIColor.white
        })
    }
}

private extension View {
    func gameFixedColumn(width: CGFloat, alignment: Alignment = .center) -> some View {
        self.frame(width: width, alignment: alignment)
    }

    func gameFlexibleColumn(alignment: Alignment = .center) -> some View {
        self.frame(minWidth: 0, maxWidth: .infinity, alignment: alignment)
    }

    func gameTrailingSeparator() -> some View {
        overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(UIColor.opaqueSeparator))
                .frame(width: 1)
        }
    }
}

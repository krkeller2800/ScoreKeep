//
//  GameView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/16/25.
//

import SwiftUI
import SwiftData
import Foundation
import UIKit
@MainActor
struct GameView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var navigationPath: NavigationPath
    @Binding private var title: String
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @State private var showingValidationAlert = false
    @State private var alertMessage = ""
    @State private var gamePendingDeletion: Game?
    @State private var showingNewGameSheet = false

    // New: closure to delegate creation to parent (ScoreContentView)
    // Updated to include isSeeded flag so parent can skip decrementing free counter for seeded creations.
    var createGame: (String, String, Bool, Int, Team, Team, Bool) -> Void

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

    private var tableHorizontalInset: CGFloat { 12 }
    var body: some View {
        ZStack {
            ScoreKeepVisualStyle.background
                .ignoresSafeArea()

            GeometryReader { proxy in
                let isGamesTableAvailable = shouldShowGamesTable(for: proxy.size.width)

                VStack(spacing: 8) {
                    if isGamesTableAvailable {
                        gamesTable
                    } else {
                        narrowRegularWidthMessage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    if isGamesTableAvailable && shouldShowSampleGameBanner {
                        sampleGameBanner
                    }
                }
            }
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
                ToolbarItem(placement: .topBarTrailing) {
                    if !title.isEmpty {
                        Button {
                            showingNewGameSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("New Game")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(self.title)
                        .font(.title2)
                        .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                }
            }
            .sheet(isPresented: $showingNewGameSheet) {
                NavigationStack {
                    EditGameView(navigationPath: $navigationPath) { dateISO, field, everyOneHits, numInnings, vTeam, hTeam, isSeeded in
                        createGame(dateISO, field, everyOneHits, numInnings, vTeam, hTeam, isSeeded)
                        showingNewGameSheet = false
                    }
                }
                .modifier(GameEditorSheetPresentationModifier())
            }
        }
    }

    private func shouldShowGamesTable(for availableWidth: CGFloat) -> Bool {
        let tableContentWidth = max(0, availableWidth - (tableHorizontalInset * 2))
        return GameColumnWidths.isTableAvailable(
            for: tableContentWidth,
            titleIsEmpty: title.isEmpty,
            isPhone: UIDevice.type == "iPhone",
            isCompact: horizontalSizeClass == .compact
        )
    }

    private var shouldShowSampleGameBanner: Bool {
        hasSeededInitialGame && !hasDismissedSeedHint_Game && !hasUserContent && !singleNonSeededGameExists
    }

    private var gamesTable: some View {
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
            ForEach(displayedGames, id: \.ident) { game in
                gameRow(for: game)
                    .background(
                        NavigationLink(value: game) {
                            EmptyView()
                        }
                        .opacity(0)
                    )
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
    }

    private var narrowRegularWidthMessage: some View {
        VStack(spacing: 8) {
            Text("More room needed")
                .font(.title3.bold())
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
            Text("Hide the sidebar or rotate your iPad to landscape to view games.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ScoreKeepVisualStyle.secondaryText)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sampleGameBanner: some View {
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
    init(searchString: String = "", sortOrder: [SortDescriptor<Game>] = [], sortMode: GameSort, title:Binding<String>, navigationPath: Binding<NavigationPath>, columnVisability: Binding<NavigationSplitViewVisibility>, createGame: @escaping (String, String, Bool, Int, Team, Team, Bool) -> Void) {

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

    private func gameOverflowHeaderCell(_ title: String) -> some View {
        scorebookHeaderCell("", semantic: true)
            .overlay {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                    .scorebookSingleLineText()
                    .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private func headerRow() -> some View {
        HStack(spacing: 0) {
            GameTableRowLayout(titleIsEmpty: title.isEmpty) {
                scorebookHeaderCell("Game Date", semantic: true)
                    .gameTrailingSeparator()
                if !title.isEmpty {
                    scorebookHeaderCell("Field", semantic: true)
                        .gameTrailingSeparator()
                    gameOverflowHeaderCell("All Hit")
                        .gameTrailingSeparator()
                }

                scorebookHeaderCell("Visiting", semantic: true)
                    .gameTrailingSeparator()
                scorebookHeaderCell("Home", semantic: true)
                    .gameTrailingSeparator()
                if !title.isEmpty {
                    scorebookHeaderCell("Status", semantic: true)
                        .gameTrailingSeparator()
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .opacity(0)
                .padding(.leading, 8)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, tableHorizontalInset)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 6)
        .background(ScoreKeepVisualStyle.contentSurface)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(ScoreKeepVisualStyle.contentSurface)
    }

    @ViewBuilder
    private func gameRow(for game: Game) -> some View {
        HStack(spacing: 0) {
            GameTableRowLayout(titleIsEmpty: title.isEmpty) {
                let dateVal = ISO8601DateFormatter().date(from: game.date) ?? Date()
                Text(dateVal.formatted(date:.abbreviated, time: .shortened))
                    .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .scorebookMultiLineText()
                    .gameColumnSlot(alignment: .leading)
                    .gameTrailingSeparator()
                if !title.isEmpty {
                    fieldNameText(game.location)
                        .padding(.horizontal, 8)
                        .gameColumnSlot(alignment: .leading)
                        .gameTrailingSeparator()
                    Text(game.everyOneHits ? "Yes" : "No")
                        .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .scorebookSingleLineText()
                        .gameColumnSlot(alignment: .leading)
                        .gameTrailingSeparator()
                }
                teamCell(name: game.vteam?.name ?? "", logoData: game.vteam?.logo)
                    .gameColumnSlot(alignment: .leading)
                    .gameTrailingSeparator()
                teamCell(name: game.hteam?.name ?? "", logoData: game.hteam?.logo)
                    .gameColumnSlot(alignment: .leading)
                    .gameTrailingSeparator()
                if !title.isEmpty {
                    gameRowScoreSummary(for: game)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
                .padding(.leading, 8)
        }
        .padding(.horizontal, tableHorizontalInset)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func gameRowScoreSummary(for game: Game) -> some View {
        if let hName = game.hteam?.name, let vName = game.vteam?.name {
            let summary = scoreSummary(for: game, homeTeamName: hName, visitingTeamName: vName)
            let inning = max(1, (summary.outs / 3) + 1)
            let hasWinner = summary.visitingRuns != summary.homeRuns
            let isFinal = inning >= 9 && hasWinner
            let gameAtbats = atbats.filter { $0.game == game }
            let stateText: String = {
                if gameAtbats.isEmpty {
                    return "Scheduled"
                } else if isFinal {
                    return "Final"
                } else {
                    return "Top \(inning)"
                }
            }()
            let scoreText = gameAtbats.isEmpty ? "—" : "\(summary.visitingRuns)–\(summary.homeRuns)"
            let accessibilityLabel = gameAtbats.isEmpty
                ? "Visiting score unavailable, home score unavailable, game state Scheduled"
                : "Visiting score \(summary.visitingRuns), home score \(summary.homeRuns), game state \(stateText)"

            Text("\(scoreText)\n\(stateText)")
                .foregroundStyle(ScoreKeepVisualStyle.primaryText)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .scorebookMultiLineText()
                .gameColumnSlot(alignment: .leading)
                .gameTrailingSeparator()
                .accessibilityLabel(accessibilityLabel)
        } else {
            Text("—\nScheduled")
                .foregroundStyle(ScoreKeepVisualStyle.secondaryText)
                .padding(.horizontal, 8)
                .scorebookMultiLineText()
                .gameColumnSlot(alignment: .leading)
                .gameTrailingSeparator()
                .accessibilityLabel("Visiting score not started, home score not started, game state scheduled")
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

    @ViewBuilder
    private func fieldNameText(_ name: String) -> some View {
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

    func gameColumnSlot(alignment: Alignment = .center) -> some View {
        self.frame(maxWidth: .infinity, alignment: alignment)
    }

    func gameTrailingSeparator() -> some View {
        overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(UIColor.opaqueSeparator))
                .frame(width: 1)
        }
    }

}

struct GameColumnWidths: Equatable {
    let date: CGFloat
    let field: CGFloat
    let allHit: CGFloat
    let team: CGFloat
    let status: CGFloat

    static let regularDateWidth: CGFloat = 150
    static let regularAllHitWidth: CGFloat = 42
    static let regularStatusWidth: CGFloat = 112
    static let minimumRegularFieldWidth: CGFloat = 120
    static let minimumRegularTeamWidth: CGFloat = 165
    static let compactRegularDateWidth: CGFloat = 100
    static let compactRegularTeamWidth: CGFloat = 135

    static let minimumRegularGameTableContentWidth: CGFloat = 675

    static var minimumRegularCompactTableContentWidth: CGFloat {
        compactRegularDateWidth + (compactRegularTeamWidth * 2)
    }

    static func resolved(for proposedContentWidth: CGFloat?, titleIsEmpty: Bool) -> GameColumnWidths {
        resolved(for: proposedContentWidth, titleIsEmpty: titleIsEmpty, isPhone: UIDevice.type == "iPhone")
    }

    static func isTableAvailable(for proposedContentWidth: CGFloat?, titleIsEmpty: Bool, isPhone: Bool, isCompact: Bool) -> Bool {
        guard !isPhone, !isCompact else { return true }

        let fallbackWidth = UIScreen.main.bounds.width
        let contentWidth = max(0, proposedContentWidth ?? fallbackWidth)
        let minimumWidth = titleIsEmpty ? minimumRegularCompactTableContentWidth : minimumRegularGameTableContentWidth
        return contentWidth >= minimumWidth
    }

    static func resolved(for proposedContentWidth: CGFloat?, titleIsEmpty: Bool, isPhone: Bool) -> GameColumnWidths {
        let fallbackWidth = UIScreen.main.bounds.width
        let contentWidth = max(0, proposedContentWidth ?? fallbackWidth)

        guard isPhone else {
            if !titleIsEmpty {
                let date = regularDateWidth
                let allHit = regularAllHitWidth
                let status = regularStatusWidth
                let fixedUtilityWidth = date + allHit + status
                let flexibleWidth = max(0, contentWidth - fixedUtilityWidth)
                let minimumField = minimumRegularFieldWidth
                let minimumTeam = minimumRegularTeamWidth
                let minimumFlexibleWidth = minimumField + (minimumTeam * 2)

                if flexibleWidth < minimumFlexibleWidth {
                    let scale = minimumFlexibleWidth > 0 ? flexibleWidth / minimumFlexibleWidth : 1
                    return GameColumnWidths(
                        date: date,
                        field: minimumField * scale,
                        allHit: allHit,
                        team: minimumTeam * scale,
                        status: status
                    )
                }

                let proportionalTeam = flexibleWidth * 0.25
                if proportionalTeam < minimumTeam {
                    return GameColumnWidths(
                        date: date,
                        field: flexibleWidth - (minimumTeam * 2),
                        allHit: allHit,
                        team: minimumTeam,
                        status: status
                    )
                }

                return GameColumnWidths(
                    date: date,
                    field: flexibleWidth * 0.5,
                    allHit: allHit,
                    team: flexibleWidth * 0.25,
                    status: status
                )
            }

            let fixedWidth = compactRegularDateWidth + (compactRegularTeamWidth * 2)
            return GameColumnWidths(
                date: compactRegularDateWidth,
                field: max(0, contentWidth - fixedWidth),
                allHit: 0,
                team: compactRegularTeamWidth,
                status: 0
            )
        }

        let usableWidth = contentWidth
        if titleIsEmpty {
            let date = min(100, max(80, usableWidth * 0.35))
            let team = max(0, (usableWidth - date) / 2)
            return GameColumnWidths(date: date, field: 0, allHit: 0, team: team, status: 0)
        }

        let target = GameColumnWidths(date: 145, field: 100, allHit: 42, team: 150, status: 116)
        let minimum = GameColumnWidths(date: 108, field: 82, allHit: 40, team: 118, status: 108)
        let targetWidth = target.date + target.field + target.allHit + (target.team * 2) + target.status
        let minimumWidth = minimum.date + minimum.field + minimum.allHit + (minimum.team * 2) + minimum.status

        if usableWidth >= targetWidth {
            return GameColumnWidths(
                date: target.date,
                field: usableWidth - target.date - target.allHit - (target.team * 2) - target.status,
                allHit: target.allHit,
                team: target.team,
                status: target.status
            )
        }

        if usableWidth >= minimumWidth {
            let deficit = targetWidth - usableWidth
            let shrinkCapacity = (target.date - minimum.date)
                + (target.allHit - minimum.allHit)
                + ((target.team - minimum.team) * 2)
                + (target.status - minimum.status)
            let shrinkRatio = shrinkCapacity > 0 ? min(1, deficit / shrinkCapacity) : 1
            let date = target.date - ((target.date - minimum.date) * shrinkRatio)
            let allHit = target.allHit - ((target.allHit - minimum.allHit) * shrinkRatio)
            let team = target.team - ((target.team - minimum.team) * shrinkRatio)
            let status = target.status - ((target.status - minimum.status) * shrinkRatio)
            return GameColumnWidths(date: date, field: minimum.field, allHit: allHit, team: team, status: status)
        }

        let scale = minimumWidth > 0 ? usableWidth / minimumWidth : 1
        return GameColumnWidths(
            date: minimum.date * scale,
            field: minimum.field * scale,
            allHit: minimum.allHit * scale,
            team: minimum.team * scale,
            status: minimum.status * scale
        )
    }

    var visibleWidths: [CGFloat] {
        [date, field, allHit, team, team, status]
    }

    var compactWidths: [CGFloat] {
        [date, team, team]
    }
}

private struct GameTableRowLayout: Layout {
    let titleIsEmpty: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposedWidth = proposal.width ?? UIScreen.main.bounds.width
        let widths = columnWidths(for: proposedWidth, subviewCount: subviews.count)
        let height = subviews.enumerated().reduce(0) { result, pair in
            let width = widths[pair.offset]
            let size = pair.element.sizeThatFits(ProposedViewSize(width: width, height: proposal.height))
            return max(result, size.height)
        }

        return CGSize(width: proposedWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = columnWidths(for: bounds.width, subviewCount: subviews.count)
        var x = bounds.minX

        for index in subviews.indices {
            let width = widths[index]
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width
        }
    }

    private func columnWidths(for proposedWidth: CGFloat, subviewCount: Int) -> [CGFloat] {
        let widths = GameColumnWidths.resolved(for: proposedWidth, titleIsEmpty: titleIsEmpty)
        let orderedWidths = titleIsEmpty ? widths.compactWidths : widths.visibleWidths
        if subviewCount <= orderedWidths.count {
            return Array(orderedWidths.prefix(subviewCount))
        }

        let fallback = orderedWidths.last ?? 0
        return orderedWidths + Array(repeating: fallback, count: subviewCount - orderedWidths.count)
    }

}

private struct GameEditorSheetPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.type == "iPad" {
            if #available(iOS 18.0, *) {
                content
                    .presentationSizing(.page)
            } else {
                content
                    .presentationDetents([.large])
            }
        } else {
            content
        }
    }
}

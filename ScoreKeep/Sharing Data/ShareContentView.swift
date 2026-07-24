//
//  ShareContentView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 7/18/25.
//
import MessageUI
import SwiftUI
import SwiftData

final class AppRouter: ObservableObject {
    enum Destination: Equatable {
        case shareDownloadTeams(prefill: String?)
    }
    @Published var destination: Destination?
}

struct ShareContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var router: AppRouter
    @State private var pendingPrefill: String?
    
    // Keychain-backed MLB download counter
    @StateObject private var mlbCounter = KeychainBackedCounter(
        key: MLBDownloadAllowanceState.counterKey,
        defaultValue: MLBDownloadAllowanceState.defaultUsedCount,
        invalidStoredValue: MLBDownloadAllowanceState.invalidStoredUsedCount
    )
    
    @State private var team:Team?
    @State private var game:Game?
    @State private var sortOrder = [SortDescriptor(\Player.batOrder)]
    @State var columnVisibility = NavigationSplitViewVisibility.doubleColumn
    @State var showImport = false
    @State var path = NavigationPath()
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var importPlayers = false
    @State private var showSearch = false
    @State private var showText = true
    @State private var isSearching = true
    @State private var searchText = ""
    @State private var playerURL: URL?
    @State private var gameURL: URL?
    @State private var players:[Player] = []
    @State private var sharePlayers:[SharePlayer] = []
    @State var doShare = "Share Your Teams"
    @State var doTeam = false
    @State var doGame = false
    @State var doDown = true
    @State var doImport = false
    @State var fNames:[String] = []
    @State private var teamURLMap: [String: String] = [:]
    @State var down:String = "Select Team"
    @State var newTeam = ""
    @State var url:URL?
    @Query var teams: [Team]
    @Query var games: [Game]
    @State var isLoading = false
    @State var errorMessage: String?
    @State private var lastUpdated: String? // Formatted MM/dd/yyyy from index.json

    enum FocusField: Hashable {case field}
    @FocusState private var focusedField: FocusField?
    
    @AppStorage("selectedShareCriteria") var selectedShareCriteria: SortCriteria = .orderAsc
    @State private var showPaywall: Bool = false
    @State private var paywallContext: PaywallContext = .general
    @State private var rosterDownloadAllowanceTransaction = RosterDownloadAllowanceTransaction()
    
    enum SortCriteria: String, CaseIterable, Identifiable {
        case nameAsc, nameDec, orderAsc, numAsc
        var id: String { self.rawValue }
    }
    
    var sortDescriptor: [SortDescriptor<Player>] {
        switch selectedShareCriteria {
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
    
    var isPremium: Bool { purchaseManager.isSeasonPassActive }

    private var mlbDownloadAllowance: MLBDownloadAllowanceState {
        MLBDownloadAllowanceState(
            usedCount: mlbCounter.value,
            storageInterpretation: mlbCounter.storageInterpretation
        )
    }
    
    var body: some View {
        VStack {
            let options = ["Download MLB Teams","Share Your Games","Share Your Teams"]
            Picker("Select Option", selection: $doShare) {
                ForEach(options, id: \.self) { option in
                    Text(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle()).frame(maxWidth: 450)
            
            let shareTeamTxt = "Select a team from the dropdown below. If you want to share these players so they can be added to the ScoreKeep app on another iPad/iPhone - hit the share button.  A share pane will displayed so the lineup file can be sent to another ios device.  Once received, the saved file can be touched and it will be sent to ScoreKeep's import screen."
            
            let shareGameTxt = "Select a game from the dropdown below. If you want to share a game so it can be added to the ScoreKeep app on another iPad/iPhone - hit the share button.  A share pane will displayed so the lineup file can be sent to another ios device.  Once received, the saved file can be touched and it will be sent to ScoreKeep's import screen."
            
            let downloadTxt = "Players on downloaded teams are not guaranteed to be up to date or complete. Please review the downloaded file and make any necessary adjustments before using."
            
            if showText {
                Text(doShare == "Share Your Teams" ? shareTeamTxt : doShare == "Share Your Games" ? shareGameTxt : doShare == "Download MLB Teams" ? downloadTxt : "")
                    .padding().italic()
            }
            HStack {
                Spacer()
                VStack {
                    if doTeam {
                        Picker("Team", selection: $team) {
                            Text("Select Team").tag(Optional<Team>.none)
                            if teams.isEmpty == false {
                                Divider()
                                ForEach(teams) { team in
                                    if team.name != "" {
                                        Text(team.name).tag(Optional(team))
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 175,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                        .border(.gray).cornerRadius(10).accentColor(.black)
                    }
                    if doGame {
                        let srtedGames = games.sorted { $0.date > $1.date }
                        Picker("Game", selection: $game) {
                            Text("Select Game").tag(Optional<Game>.none)
                            if games.isEmpty == false {
                                Divider()
                                ForEach(srtedGames) { game in
                                    if game.location != "" {
                                        let vTeam = game.vteam?.name ?? "Unkown"
                                        let hTeam = game.hteam?.name ?? "Unkown"
                                        let theDate = ISO8601DateFormatter().date(from: game.date) ?? Date()
                                        Text("\(vTeam) at \(hTeam) on \(theDate.formatted(date:.abbreviated, time: .omitted))").tag(Optional(game))
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 225,maxHeight: 50, alignment:.center).background(.blue.opacity(0.2))
                        .border(.gray).cornerRadius(10).accentColor(.black)
                    }
                    if doDown {
                        if isLoading {
                            ProgressView("Loading teams…")
                                .padding(.bottom, 6)
                        } else if let errorMessage = errorMessage {
                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                    Text(errorMessage)
                                        .font(.footnote)
                                }
                                Button("Retry") {
                                    getFileNames()
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 6)
                        }
                        HStack {
                            Spacer()
                            Picker("Down", selection: $down) {
                                Text("Select Team").tag("Select Team")
                                let fileNames = fNames.sorted{($0 < $1)}
                                if fileNames.isEmpty == false {
                                    ForEach (fileNames, id: \.self) { name in
                                        (name != "") ? Text(name).tag(name): nil
                                    }
                                }
                            }
                            .frame(maxWidth: 150,maxHeight: 30, alignment:.center).background(.blue.opacity(0.2))
                            .border(.gray).cornerRadius(10).accentColor(.black)
                            .disabled(!isPremium && !mlbDownloadAllowance.canDownloadWithAllowance)
                            Spacer()
                        }
                        if let lastUpdated = lastUpdated {
                            Text("Updated on: \(lastUpdated)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                        }
                        // Counter or Unlimited text based on upgrade status
                        if isPremium {
                            PremiumBadgeView(isCompact: false)
                            Text("Unlimited downloads active")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        } else {
                            // Hint
                            HStack {
                                Image(systemName: "info.circle")
                                    .imageScale(.small)
                                Text("Tip: Pick a MLB team, it will be added to your teams to score.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 6)
                            }
                            Text(mlbDownloadAllowance.displayText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                                .accessibilityLabel(mlbDownloadAllowance.accessibilityLabel)
                        }
                        // Upgrade button: only show when not premium
                        if !isPremium {
                            Button("Upgrade") {
                                paywallContext = .downloadLimit
                                showPaywall = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .padding(.top, 4)
                            .overlay(alignment: .topTrailing) {
                                if !mlbDownloadAllowance.canDownloadWithAllowance {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 10, height: 10)
                                        .offset(x: 6, y: -6)
                                        .accessibilityLabel("Limit reached")
                                }
                            }
                        }
                        
                        if url != nil {
                            Text("Importing \(url!.lastPathComponent)")
                        }
                        Spacer()
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: doShare) {
                gameURL = nil
                playerURL = nil
                url = nil
                if doShare == "Share Your Games" {
                    doTeam = false
                    doGame = true
                    doDown = false
                } else if doShare == "Share Your Teams" {
                    doTeam = true
                    doGame = false
                    doDown = false
                } else if doShare == "Download MLB Teams" {
                    doTeam = false
                    doGame = false
                    doDown = true
                    getFileNames()
                }
            }
            .onChange(of: team) {
                if team == nil {
                    showingAlert = true
                    alertMessage = "Please select a team"
                } else {
                    showText = UIDevice.type == "iPad" ? true : false
                    if let playerData = generatePlayers() {
                        playerURL = savePlayers(playerData: playerData, fileName: team!.name)
                    }
                    players.removeAll()
                    sharePlayers.removeAll()
                }
            }
            .onChange(of: game) {
                if game == nil {
                    showingAlert = true
                    alertMessage = "Please select a game"
                } else {
                    if let gameData = generateGame() {
                        let vTeam = game?.vteam?.name ?? "Unkown"
                        let hTeam = game?.hteam?.name ?? "Unkown"
                        let gDate = game?.date ?? ""
                        let theDate = ISO8601DateFormatter().date(from: gDate) ?? Date()
                        gameURL = saveGame(gameData: gameData, fileName: "\(vTeam) at \(hTeam) on \(theDate.formatted(date:.abbreviated, time: .omitted))")
                    }
                }
            }
            .onChange(of: down) {
                guard down != "Select Team" else { return }
                let downTeam = DownloadFiles()
                Task {
                    // Gate: block if free limit reached
                    if !isPremium && !mlbDownloadAllowance.canDownloadWithAllowance {
                        showingAlert = true
                        alertMessage = "You’ve reached your 4 free downloads. Upgrade to continue."
                        paywallContext = .downloadLimit
                        showPaywall = true
                        return
                    }
                    
                    do {
                        // Resolve direct URL for the selected team from the locally stored map
                        guard let directURLString = teamURLMap[down] else {
                            throw URLError(.fileDoesNotExist)
                        }

                        // .ScoreKeep_Players is part of the import contract used by released versions.
                        // Keep manifest roster URLs and downloaded filenames compatible.
                        let destinationFileName = "\(down).ScoreKeep_Players"
                        try await downTeam.downloadFile(from: directURLString, to: destinationFileName)

                        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        url = documentsDirectory.appendingPathComponent(destinationFileName)
                        if url != nil {
                            doImport = true
                            if !isPremium {
                                applySuccessfulRosterDownloadAllowanceTransaction(for: destinationFileName)
                            }
                        }
                    } catch {
                        print("Error downloading file: \(error.localizedDescription)")
                    }
                }
            }
            if team != nil && doTeam {
                PlayersOnTeamView(team: team!, searchString: searchText, sortOrder: sortOrder)
            }
            Spacer()
        }
        .onChange(of: doImport) {
            if !doImport {
                url = nil
            }
        }
        /*
        .onOpenURL { url in
            if let dest = parseDeepLink(url) {
                router.destination = dest
            }
        }
        */
        .fullScreenCover(isPresented: $doImport) {
            if let url1 = url, isValidImportURL(url1) {
                ImportPlayersView(showingImport: $showImport, iURL: url1, columnVisibility: $columnVisibility)
            } else {
                Color.clear
                    .task {
                        doImport = false
                        url = nil
                        showingAlert = true
                        alertMessage = "No valid import file found."
                    }
            }
        }
        .onAppear{
            doShare = "Download MLB Teams"
            doTeam = false
            doGame = false
            doDown = true
            if fNames.isEmpty { getFileNames() }
            // Apply any already-set destination so we react even if the router was set before appearance
            applyDestination(router.destination)
        }
        // Paywall presentation:
        // - iPhone: full screen
        // - iPad: largest sheet possible
        .modifier(PaywallPresentation(isPresented: $showPaywall, context: paywallContext))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Share")
                    .font(.title2).bold()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    
                }) {
                    
                }
                .alert(alertMessage, isPresented: $showingAlert) {
                    Button("OK", role: .cancel) { }
                }
            }
            ToolbarItemGroup(placement: .topBarLeading) {
                Menu("Sort", systemImage: "arrow.up.arrow.down") {
                    Picker("Sort", selection: $selectedShareCriteria) {
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
            ToolbarItem(placement: .navigationBarTrailing) {
                if UIDevice.type == "iPhone" {
                    Button(action: {
                        withAnimation {
                            isSearching.toggle()
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                if let playerURL = playerURL {
                    ShareLink(item: playerURL) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share \(team!.name)")
                        }
                    }
                } else if let gameURL = gameURL {
                    ShareLink(item: gameURL) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Game")
                        }
                    }
                }
            }
        }
        .onChange(of: sortDescriptor) {
            sortOrder = sortDescriptor
        }
        .onReceive(router.$destination) { dest in
            print("Router destination:", String(describing: dest))
            applyDestination(dest)
        }
        .onChange(of: teamURLMap) {
            if let prefill = pendingPrefill, teamURLMap[prefill] != nil {
                down = prefill
                pendingPrefill = nil
            }
        }
        // Optional: auto-dismiss paywall if premium flips true
        .onReceive(purchaseManager.$isSeasonPassActive) { active in
            if active {
                showPaywall = false
            }
        }
        .searchable(if: isSearching, text: $searchText, placement: .toolbar, prompt: "Player name or number")
        .onAppear {
            if UIDevice.type == "iPhone" {
                isSearching = false
            } else {
                isSearching = true
            }
            UISegmentedControl.appearance().selectedSegmentTintColor = .systemBlue.withAlphaComponent(0.1)
        }
        .onChange(of: isSearching) {
            if isSearching == false {
                searchText = "" // Clear the search text when the search field is dismissed
            }
        }
    }
    init() {
        
        _teams = Query(filter: #Predicate { team in
            true
        })
        _games = Query(filter: #Predicate { game in
            true
        })
    }
    func generatePlayers() -> Data? {
        getPlayers()
        for player in players {
            if player.team != nil {
                let shareTeam = ShareTeam(name: player.team!.name,coach: player.team!.coach, details: player.team!.details, logo: player.team!.logo ?? Data())
                let shareplayer = SharePlayer(name: player.name, number: player.number, position: player.position, batDir: player.batDir,
                                              batOrder: player.batOrder, team: shareTeam, photo: player.photo ?? Data())
                sharePlayers.append(shareplayer)
            }
        }
        let encoder = JSONEncoder()
        // Error handling for encoding
        if let encodedData = try? encoder.encode(sharePlayers) {
            return encodedData
        } else {
            return Data() // Return empty data on error
        }
    }
    func savePlayers(playerData: Data, fileName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let route = CompatibleSourceDataExportRoute(kind: .players, fileBaseName: fileName)
        let fileURL = documentDirectory.appendingPathComponent(route.fileName)
        
        do {
            try playerData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving Players: \(error.localizedDescription)")
            return nil
        }
    }
    func getPlayers () {
        
        let teamName = team?.name ?? ""
        
        if !teamName.isEmpty {
            var fetchDescriptor = FetchDescriptor<Player>()
            
            fetchDescriptor.predicate = #Predicate { $0.team?.name == teamName }
            
            do {
                players = try self.modelContext.fetch(fetchDescriptor)
            } catch {
                print("SwiftData Error: \(error)")
            }
        } else {
            showingAlert = true
            alertMessage = "Please select a team."
        }
    }
    func generateGame() -> Data? {
        if let theGame = game {
            if theGame.vteam != nil && theGame.hteam != nil {
                let shareGame = ShareGame(date: theGame.date, location: theGame.location, highLights: theGame.highLights, hscore:theGame.hscore, vscore:theGame.vscore, everyOneHits:theGame.everyOneHits,
                                          numInnings:theGame.numInnings, vteam: shareTeam(team: theGame.vteam!), hteam: shareTeam(team: theGame.hteam!), players: getPlayers(players: theGame.players),
                                          atbats: getAtbats(atbats: theGame.atbats), lineups: getLineups(lineups: theGame.lineups), pitchers: getPitchers(pitchers: theGame.pitchers),
                                          replaced: getPlayers(players: theGame.replaced), incomings: getPlayers(players: theGame.incomings))
                let encoder = JSONEncoder()
                // Error handling for encoding
                if let encodedData = try? encoder.encode(shareGame) {
                    return encodedData
                } else {
                    return Data() // Return empty data on error
                }
            }
        }
        return Data()
    }
    func saveGame(gameData: Data, fileName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let route = CompatibleSourceDataExportRoute(kind: .game, fileBaseName: fileName)
        let fileURL = documentDirectory.appendingPathComponent(route.fileName)
        
        do {
            try gameData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving Game: \(error.localizedDescription)")
            return nil
        }
    }
    func shareTeam (team: Team) -> ShareTeam {
        let shareTeam = ShareTeam(name: team.name, coach: team.coach, details: team.details, players: getPlayers(players: team.players), logo: team.logo ?? Data())
        return shareTeam
    }
    func getPlayers (players: [Player]) -> [SharePlayer] {
        var sharePlayers: [SharePlayer] = []
        for player in players {
            if player.team != nil {
                let sharePlayer = SharePlayer(name: player.name, number: player.number, position: player.position, batDir: player.batDir, batOrder: player.batOrder,
                                              team: getTempTeam(team: player.team!), photo: player.photo ?? Data())
                sharePlayers.append(sharePlayer)
            }
        }
        return sharePlayers
    }
    func getAtbats (atbats: [Atbat]) -> [ShareAtbat] {
        var shareAtbats: [ShareAtbat] = []
        for atbat in atbats {
            let shareAtbat = ShareAtbat(team: shareTeam(team: atbat.team), player: getPlayers(players: [atbat.player])[0], result: atbat.result, maxbase: atbat.maxbase, batOrder: atbat.batOrder,
                                        outAt: atbat.outAt, inning: atbat.inning, seq: atbat.seq, col: atbat.col, rbis: atbat.rbis, outs: atbat.outs, sacFly: atbat.sacFly, sacBunt: atbat.sacBunt,
                                        stolenBases: atbat.stolenBases, earnedRun: atbat.earnedRun, playRec: atbat.playRec, endOfInning: atbat.endOfInning)
            shareAtbats.append(shareAtbat)
        }
        return shareAtbats
    }
    func getLineups (lineups: [Lineup]) -> [ShareLineup] {
        var sharelineups: [ShareLineup] = []
        for lineup in lineups {
            let sharelineup = ShareLineup(everyoneHits: lineup.everyoneHits, team: shareTeam(team: lineup.team),inning: lineup.inning)
            sharelineups.append(sharelineup)
        }
        return sharelineups
    }
    func getPitchers (pitchers: [Pitcher]) -> [SharePitcher] {
        var sharePitchers: [SharePitcher] = []
        for pitcher in pitchers {
            let sharePitcher = SharePitcher(player: getPlayers(players: [pitcher.player])[0], team: shareTeam(team: pitcher.team), startInn: pitcher.startInn, sOuts: pitcher.sOuts, sBats: pitcher.sBats,
                                            endInn: pitcher.endInn, eOuts: pitcher.eOuts, eBats: pitcher.eBats, strikeOuts: pitcher.strikeOuts, walks: pitcher.walks, hits: pitcher.hits,
                                            runs: pitcher.runs, won: pitcher.won)
            sharePitchers.append(sharePitcher)
        }
        return sharePitchers
    }
    func getTempTeam (team: Team) -> ShareTeam {
        let shareTeam = ShareTeam(name: team.name)
        return shareTeam
    }
    func getFileNames () {
        isLoading = true
        errorMessage = nil
        fNames = []

        let downloadFiles = DownloadFiles()

        // Compatibility endpoint used by released ScoreKeep versions.
        // Keep /Teams/index.json and its expected JSON schema stable; website redirects must not replace it with HTML.
        guard let indexURL = URL(string: "https://komakode.com/Teams/index.json") else { return }
        // Fetch and display the last updated date from the index
        fetchIndexUpdated(from: indexURL)
        downloadFiles.fetchTeamsIndex(from: indexURL) { pairs, error in
            if let _ = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to load teams. Please check your connection and try again."
                    self.isLoading = false
                }
                return
            }
            guard let pairs = pairs else { return }

            DispatchQueue.main.async {
                // Populate the picker names and the local name→URL map
                self.fNames = pairs.map { $0.name }
                self.fNames.sort(by: <)
                self.teamURLMap = Dictionary(uniqueKeysWithValues: pairs.map { ($0.name, $0.url) })
                self.isLoading = false
                self.errorMessage = nil
            }
        }
    }

    private func applySuccessfulRosterDownloadAllowanceTransaction(for rosterID: String) {
        let result = rosterDownloadAllowanceTransaction.successfulDownloadImportBoundary(
            rosterID: rosterID,
            allowance: mlbDownloadAllowance
        )

        if case .consume = result {
            mlbCounter.increment()
        }
    }

    private func fetchIndexUpdated(from url: URL) {
        struct TeamsIndex: Decodable {
            let updated: String?
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            do {
                let index = try JSONDecoder().decode(TeamsIndex.self, from: data)
                guard let updatedString = index.updated else { return }
                let iso = ISO8601DateFormatter()
                if let date = iso.date(from: updatedString) {
                    let fmt = DateFormatter()
                    fmt.locale = Locale(identifier: "en_US_POSIX")
                    fmt.dateFormat = "MM/dd/yyyy"
                    let formatted = fmt.string(from: date)
                    DispatchQueue.main.async {
                        self.lastUpdated = formatted
                    }
                }
            } catch {
                // Ignore parsing errors for updated field
            }
        }
        task.resume()
    }
    func sendEmail(openUrl: OpenURLAction) {
        let urlString = "mailto:comment@KomaKode.com?subject=Additional%20download%20request&body=Please%20make%20\(newTeam)%20available%20for%20download"
        guard let url = URL(string: urlString) else { return }
        
        openUrl(url) { accepted in
            if !accepted {
                showingAlert = true
                alertMessage = "Unable to send Email"
            }
        }
    }
    
    private func applyDestination(_ dest: AppRouter.Destination?) {
        guard let dest = dest else { return }
        switch dest {
        case .shareDownloadTeams(let prefill):
            // Ensure the Download MLB Teams segment is active
            doShare = "Download MLB Teams"
            doTeam = false
            doGame = false
            doDown = true

            // Load team list if needed
            if fNames.isEmpty { getFileNames() }

            // Optional: preselect a team if provided
            if let prefill, !prefill.isEmpty {
                if teamURLMap[prefill] != nil {
                    down = prefill
                } else {
                    pendingPrefill = prefill
                }
            }
        }
    }

    private func isValidImportURL(_ url: URL) -> Bool {
        let ext = url.pathExtension
        let ok = (ext == "ScoreKeep_Players" || ext == "ScoreKeep_Games")
        if ok {
            return FileManager.default.fileExists(atPath: url.path)
        }
        return false
    }
    
    private func parseDeepLink(_ url: URL) -> AppRouter.Destination? {
        guard url.scheme == "scorekeep" else { return nil }
        let host = url.host ?? ""
        guard host == "share" else { return nil }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let tab = comps?.queryItems?.first(where: { $0.name == "tab" })?.value
        let prefill = comps?.queryItems?.first(where: { $0.name == "prefill" })?.value
        if tab == "download" {
            return .shareDownloadTeams(prefill: prefill)
        }
        return nil
    }
}

// Helper view modifier to present Paywall as sheet on iPad, full screen on iPhone
private struct PaywallPresentation: ViewModifier {
    @Binding var isPresented: Bool
    let context: PaywallContext

    func body(content: Content) -> some View {
        if UIDevice.type == "iPad" {
            content
                .sheet(isPresented: $isPresented) {
                    PaywallView(context: context)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
        } else {
            content
                .fullScreenCover(isPresented: $isPresented) {
                    PaywallView(context: context)
                }
        }
    }
}

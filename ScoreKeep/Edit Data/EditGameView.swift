//
//  EditGameView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/16/25.
//
import SwiftUI
import SwiftData

struct EditGameView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath

    private let game: Game?
    private let onCreate: ((String, String, Bool, Int, Team, Team, Bool) -> Void)?

    @State private var date: Date
    @State private var draftField: String
    @State private var draftEveryOneHits: Bool
    @State private var draftNumInnings: Int
    @State private var draftVisitingTeam: Team?
    @State private var draftHomeTeam: Team?
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingAddTeam = false
    @State private var pendingAddTeamSelectionRole: AddGameTeamSelectionRole?

    enum FocusField: Hashable { case field }
    enum AddGameTeamSelectionRole: Hashable {
        case visiting
        case home
    }

    @FocusState private var focusedField: FocusField?

    @Query(sort: [
        SortDescriptor(\Team.name)
    ]) var teams: [Team]

    init(game: Game, navigationPath: Binding<NavigationPath>) {
        self.game = game
        self.onCreate = nil
        _navigationPath = navigationPath
        _date = State(initialValue: ISO8601DateFormatter().date(from: game.date) ?? Date())
        _draftField = State(initialValue: game.location)
        _draftEveryOneHits = State(initialValue: game.everyOneHits)
        _draftNumInnings = State(initialValue: game.numInnings)
        _draftVisitingTeam = State(initialValue: game.vteam)
        _draftHomeTeam = State(initialValue: game.hteam)
    }

    init(
        navigationPath: Binding<NavigationPath>,
        onCreate: @escaping (String, String, Bool, Int, Team, Team, Bool) -> Void
    ) {
        self.game = nil
        self.onCreate = onCreate
        _navigationPath = navigationPath
        _date = State(initialValue: Date())
        _draftField = State(initialValue: "")
        _draftEveryOneHits = State(initialValue: false)
        _draftNumInnings = State(initialValue: 9)
        _draftVisitingTeam = State(initialValue: nil)
        _draftHomeTeam = State(initialValue: nil)
    }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    compactField("Date", width: 145) {
                        DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                            .labelsHidden()
                            .accessibilityLabel("Date")
                    }

                    compactField("Time", width: 105) {
                        DatePicker("Time", selection: dateBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .accessibilityLabel("Time")
                    }

                    compactField("Field", maxWidth: 300) {
                        TextField("Field", text: fieldBinding, prompt: scorebookInputPrompt("Field"))
                            .focused($focusedField, equals: .field)
                            .autocapitalization(.words)
                            .textContentType(.none)
                            .textFieldStyle(.roundedBorder)
                    }

                    compactField("Regulation Innings", width: 170) {
                        compactInningsControl()
                    }
                }
                .controlSize(.small)
            } header: {
                sectionHeader("Game")
            }

            Section {
                HStack(alignment: .top, spacing: 10) {
                    compactField("Visiting Team", width: 300) {
                        HStack(spacing: 6) {
                            Picker("Visiting Team", selection: visitingTeamBinding) {
                                Text("Select Team").tag(Optional<Team>.none)
                                if !teams.isEmpty {
                                    Divider()
                                    ForEach(teams) { team in
                                        if !team.name.isEmpty {
                                            Text(team.name).tag(Optional(team))
                                        }
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .lineLimit(1)
                            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, UIDevice.type == "iPad" ? 0 : 10)

                            addTeamRoleButton(for: .visiting, accessibilityLabel: "Add visiting team")
                        }
                    }

                    verticalSeparator()

                    compactField("Home Team", width: 300) {
                        HStack(spacing: 6) {
                            Picker("Home Team", selection: homeTeamBinding) {
                                Text("Select Team").tag(Optional<Team>.none)
                                if !teams.isEmpty {
                                    Divider()
                                    ForEach(teams) { team in
                                        if !team.name.isEmpty {
                                            Text(team.name).tag(Optional(team))
                                        }
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .lineLimit(1)
                            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, UIDevice.type == "iPad" ? 0 : 10)

                            addTeamRoleButton(for: .home, accessibilityLabel: "Add home team")
                        }
                    }

                    verticalSeparator()

                    compactField("All Hit", width: 105) {
                        Toggle("All Hit", isOn: everyOneHitsBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
                .controlSize(.small)
            } header: {
                sectionHeader("Details")
            }

            if game != nil {
                Section("Highlights") {
                    TextField(
                        "Comment",
                        text: highlightsBinding,
                        prompt: scorebookInputPrompt("Please input game highlights"),
                        axis: .vertical
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ScoreKeepVisualStyle.background)
        .navigationTitle(game == nil ? "New Game" : "Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if game == nil {
                    Button("Cancel") { dismiss() }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if game == nil {
                    Button("Save", action: saveNewGame)
                        .disabled(!canSaveNewGame)
                }
            }
        }
        .onDisappear {
            guard let game, !showingAddTeam else { return }
            if game.hteam == nil || game.vteam == nil {
                modelContext.delete(game)
                alertMessage = "You must select a Home and Visiting Team! Game deleted."
                showingAlert = true
            }
        }
        .alert(alertMessage, isPresented: $showingAlert) { Button("OK", role: .cancel) { } }
        .sheet(isPresented: $showingAddTeam, onDismiss: {
            pendingAddTeamSelectionRole = nil
        }) {
            NavigationStack {
                AddTeamDraftView { createdTeam in
                    assignCreatedTeam(createdTeam)
                }
            }
        }
    }

    private func presentAddTeam(for role: AddGameTeamSelectionRole? = nil) {
        pendingAddTeamSelectionRole = role
        showingAddTeam = true
    }

    private func addTeamRoleButton(for role: AddGameTeamSelectionRole, accessibilityLabel: String) -> some View {
        Button {
            presentAddTeam(for: role)
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactField<Content: View>(_ label: String, width: CGFloat? = nil, maxWidth: CGFloat? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(ScoreKeepVisualStyle.secondaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            content()
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(width: width, alignment: .center)
        .frame(maxWidth: width == nil ? (maxWidth ?? .infinity) : width, alignment: .center)
    }

    private func compactInningsControl() -> some View {
        HStack(spacing: 4) {
            Text("\(inningsBinding.wrappedValue)")
                .monospacedDigit()
                .frame(width: 20, alignment: .trailing)

            Stepper("Regulation Innings", value: inningsBinding, in: 1...20)
                .labelsHidden()
                .fixedSize()
        }
    }

    private func verticalSeparator() -> some View {
        Rectangle()
            .fill(Color(UIColor.separator))
            .frame(width: 1, height: 44)
            .padding(.top, 18)
    }

    private var dateBinding: Binding<Date> {
        Binding {
            date
        } set: { newDate in
            date = newDate
            game?.date = newDate.ISO8601Format()
        }
    }

    private var fieldBinding: Binding<String> {
        Binding {
            game?.location ?? draftField
        } set: { newField in
            if let game {
                game.location = newField
            } else {
                draftField = newField
            }
        }
    }

    private var everyOneHitsBinding: Binding<Bool> {
        Binding {
            game?.everyOneHits ?? draftEveryOneHits
        } set: { newValue in
            if let game {
                game.everyOneHits = newValue
            } else {
                draftEveryOneHits = newValue
            }
        }
    }

    private var inningsBinding: Binding<Int> {
        Binding {
            game?.numInnings ?? draftNumInnings
        } set: { newValue in
            if let game {
                game.numInnings = newValue
            } else {
                draftNumInnings = newValue
            }
        }
    }

    private var visitingTeamBinding: Binding<Team?> {
        Binding {
            game?.vteam ?? draftVisitingTeam
        } set: { newTeam in
            if let game {
                game.vteam = newTeam
            } else {
                draftVisitingTeam = newTeam
            }
        }
    }

    private var homeTeamBinding: Binding<Team?> {
        Binding {
            game?.hteam ?? draftHomeTeam
        } set: { newTeam in
            if let game {
                game.hteam = newTeam
            } else {
                draftHomeTeam = newTeam
            }
        }
    }

    private var highlightsBinding: Binding<String> {
        Binding {
            game?.highLights ?? ""
        } set: { newHighlights in
            game?.highLights = newHighlights
        }
    }

    private var canSaveNewGame: Bool {
        game != nil || (draftVisitingTeam != nil && draftHomeTeam != nil)
    }

    private func saveNewGame() {
        guard let draftVisitingTeam, let draftHomeTeam else {
            alertMessage = "You must select a Home and Visiting Team!"
            showingAlert = true
            return
        }

        onCreate?(
            date.ISO8601Format(),
            draftField,
            draftEveryOneHits,
            draftNumInnings,
            draftVisitingTeam,
            draftHomeTeam,
            false
        )
        dismiss()
    }

    private func assignCreatedTeam(_ team: Team) {
        guard let persistedTeam = fetchTeam(identity: team.ident) else {
            alertMessage = "ScoreKeep saved this team, but Edit Game could not load it for selection yet."
            showingAlert = true
            return
        }

        switch pendingAddTeamSelectionRole {
        case .visiting:
            visitingTeamBinding.wrappedValue = persistedTeam
        case .home:
            homeTeamBinding.wrappedValue = persistedTeam
        case nil:
            if game?.vteam == nil && draftVisitingTeam == nil {
                visitingTeamBinding.wrappedValue = persistedTeam
            } else if game?.hteam == nil && draftHomeTeam == nil {
                homeTeamBinding.wrappedValue = persistedTeam
            }
        }

        do {
            try modelContext.save()
        } catch {
            alertMessage = "ScoreKeep saved this team, but could not assign it to this game yet."
            showingAlert = true
        }
    }

    private func fetchTeam(identity: UUID) -> Team? {
        let descriptor = FetchDescriptor<Team>(predicate: #Predicate { team in
            team.ident == identity
        })
        return try? modelContext.fetch(descriptor).first
    }
}

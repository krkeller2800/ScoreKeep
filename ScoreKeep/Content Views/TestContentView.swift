//
//  TestContentView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 5/31/25.
//

import SwiftUI
import SwiftData
//@Query var gamess: [Game]

struct TestContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var path = NavigationPath()
    
    @State private var searchText = ""
    @State private var sortOrder = [SortDescriptor(\Team.name)]
    
    var body: some View {
        NavigationStack(path: $path) {
            TeamView(searchString: searchText, sortOrder: sortOrder)
                .navigationDestination(for: Team.self) { team in
                    EditTeamView(navigationPath: $path, team: team)
                }
        }
    }
}

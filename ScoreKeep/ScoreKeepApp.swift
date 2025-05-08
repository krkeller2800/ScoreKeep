//
//  ScoreKeepApp.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/15/25.
//

import SwiftUI
import SwiftData

@main
struct ScoreKeepApp: App {
    var body: some Scene {
        WindowGroup {
            StartView()
        }
        .modelContainer(for: Game.self)
    }
}

//
//  ScoreKeepApp.swift
//  ScoreKeep
//
//  Created by Karl Keller on 3/15/25.
//

import SwiftUI
import SwiftData
import os.log

@main
struct ScoreKeepApp: App {
    var body: some Scene {
        WindowGroup {
            if UIDevice.type == "iPad" {
                StartView()
                    .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
            } else if UIDevice.type == "iPhone" {
                StartPhoneView()
                    .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
             }
        }
        .modelContainer(for: Game.self)
        .handlesExternalEvents(matching: ["*"])
    }
}

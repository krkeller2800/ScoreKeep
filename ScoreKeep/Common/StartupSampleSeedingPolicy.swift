//
//  StartupSampleSeedingPolicy.swift
//  ScoreKeep
//
//  Created by Codex on 7/29/26.
//

import Foundation

enum StartupSampleSeedingPolicy {
    enum Decision: Equatable {
        case importSample
        case markComplete
        case doNothing
    }

    struct Snapshot: Equatable {
        let startupVerified: Bool
        let sampleGameExists: Bool
        let containsBaseballData: Bool

        init(startupVerified: Bool, sampleGameExists: Bool, containsBaseballData: Bool) {
            self.startupVerified = startupVerified
            self.sampleGameExists = sampleGameExists
            self.containsBaseballData = containsBaseballData
        }
    }

    static func decision(for snapshot: Snapshot) -> Decision {
        guard snapshot.startupVerified else {
            return .doNothing
        }

        if snapshot.sampleGameExists || snapshot.containsBaseballData {
            return .markComplete
        }

        return .importSample
    }
}

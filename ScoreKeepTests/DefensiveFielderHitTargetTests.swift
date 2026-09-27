import CoreGraphics
import SwiftUI
import Testing
@testable import ScoreKeep

@Suite("Defensive fielder hit targets")
struct DefensiveFielderHitTargetTests {
    private let phoneCenters: [Int: UnitPoint] = [
        1: .init(x: 0.50, y: 0.77),
        2: .init(x: 0.50, y: 0.93),
        3: .init(x: 0.60, y: 0.70),
        4: .init(x: 0.54, y: 0.64),
        5: .init(x: 0.40, y: 0.68),
        6: .init(x: 0.46, y: 0.64),
        7: .init(x: 0.33, y: 0.59),
        8: .init(x: 0.50, y: 0.50),
        9: .init(x: 0.67, y: 0.59)
    ]

    private let padCenters: [Int: UnitPoint] = [
        1: .init(x: 0.50, y: 0.70),
        2: .init(x: 0.50, y: 0.94),
        3: .init(x: 0.75, y: 0.59),
        4: .init(x: 0.64, y: 0.46),
        5: .init(x: 0.25, y: 0.59),
        6: .init(x: 0.36, y: 0.46),
        7: .init(x: 0.15, y: 0.40),
        8: .init(x: 0.50, y: 0.35),
        9: .init(x: 0.85, y: 0.40)
    ]

    @Test("all nine defensive controls record their own position")
    func allControlsRecordTheirOwnPosition() {
        for position in 1...9 {
            let actual = DefensiveFielderHitTargetLayout.updatedPlayRecord(
                "",
                position: position,
                isOutfielder: position >= 7,
                result: "Ground Out"
            )
            #expect(actual == String(position))
        }
    }

    @Test("out result prefixes and repeated selections preserve legacy notation")
    func resultPrefixesAndRepeatedSelectionsPreserveLegacyNotation() {
        #expect(DefensiveFielderHitTargetLayout.updatedPlayRecord("", position: 6, isOutfielder: false, result: "Fly Out") == "P6")
        #expect(DefensiveFielderHitTargetLayout.updatedPlayRecord("", position: 7, isOutfielder: true, result: "Fly Out") == "F7")
        #expect(DefensiveFielderHitTargetLayout.updatedPlayRecord("", position: 9, isOutfielder: true, result: "Line Out") == "L9")
        #expect(DefensiveFielderHitTargetLayout.updatedPlayRecord("6", position: 3, isOutfielder: false, result: "Ground Out") == "6-3")
    }

    @Test("iPhone defensive hit frames are bounded and do not overlap")
    func phoneFramesDoNotOverlap() {
        verifyFramesDoNotOverlap(
            centers: phoneCenters,
            containerSize: CGSize(width: 874, height: 402),
            isPhone: true
        )
    }

    @Test("iPad defensive hit frames are bounded and do not overlap")
    func padFramesDoNotOverlap() {
        verifyFramesDoNotOverlap(
            centers: padCenters,
            containerSize: CGSize(width: 1194, height: 834),
            isPhone: false
        )
    }

    private func verifyFramesDoNotOverlap(
        centers: [Int: UnitPoint],
        containerSize: CGSize,
        isPhone: Bool
    ) {
        let bounds = CGRect(origin: .zero, size: containerSize)
        let frames = centers.mapValues {
            DefensiveFielderHitTargetLayout.frame(center: $0, in: containerSize, isPhone: isPhone)
        }

        #expect(frames.count == 9)
        for position in 1...9 {
            let frame = frames[position]
            #expect(frame != nil)
            if let frame {
                #expect(bounds.contains(frame))
            }
        }

        for firstPosition in 1..<9 {
            for secondPosition in (firstPosition + 1)...9 {
                if let first = frames[firstPosition], let second = frames[secondPosition] {
                    #expect(!first.intersects(second), "Positions \(firstPosition) and \(secondPosition) must not overlap")
                }
            }
        }
    }
}

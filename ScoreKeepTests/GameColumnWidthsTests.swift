import Testing
import CoreGraphics
@testable import ScoreKeep

struct GameColumnWidthsTests {
    @Test func regularWidthTableAvailabilityUsesDerivedMinimum() {
        let minimum = GameColumnWidths.minimumRegularGameTableContentWidth

        #expect(minimum == 675)
        #expect(GameColumnWidths.isTableAvailable(for: 674, titleIsEmpty: false, isPhone: false, isCompact: false) == false)
        #expect(GameColumnWidths.isTableAvailable(for: 675, titleIsEmpty: false, isPhone: false, isCompact: false))
        #expect(GameColumnWidths.isTableAvailable(for: 676, titleIsEmpty: false, isPhone: false, isCompact: false))
    }

    @Test func phoneAndCompactAvailabilityRemainAllowedBelowRegularMinimum() {
        let narrowWidth = GameColumnWidths.minimumRegularGameTableContentWidth - 1

        #expect(GameColumnWidths.isTableAvailable(for: narrowWidth, titleIsEmpty: false, isPhone: true, isCompact: false))
        #expect(GameColumnWidths.isTableAvailable(for: narrowWidth, titleIsEmpty: false, isPhone: false, isCompact: true))
    }

    @Test func regularWidthEditRowsUseEntireProposedContentWidth() {
        for proposedWidth in [828.0, 1_146.0, 1_300.0] {
            let widths = GameColumnWidths.resolved(for: proposedWidth, titleIsEmpty: false, isPhone: false)

            #expect(approximately(widths.visibleWidths.reduce(0, +), proposedWidth))
        }
    }

    @Test func regularWidthUtilityColumnsRemainStable() {
        for proposedWidth in [828.0, 1_146.0, 1_300.0] {
            let widths = GameColumnWidths.resolved(for: proposedWidth, titleIsEmpty: false, isPhone: false)

            #expect(widths.date == 150)
            #expect(widths.allHit == 42)
            #expect(widths.status == 112)
        }
    }

    @Test func regularWidthFlexibleColumnsShareAvailableSpaceDeterministically() {
        let sidebarVisible = GameColumnWidths.resolved(for: 828, titleIsEmpty: false, isPhone: false)
        let sidebarHidden = GameColumnWidths.resolved(for: 1_146, titleIsEmpty: false, isPhone: false)
        let wider = GameColumnWidths.resolved(for: 1_300, titleIsEmpty: false, isPhone: false)
        let repeatedSidebarHidden = GameColumnWidths.resolved(for: 1_146, titleIsEmpty: false, isPhone: false)

        #expect(sidebarHidden == repeatedSidebarHidden)
        #expect(sidebarVisible.field < sidebarHidden.field)
        #expect(sidebarHidden.field < wider.field)
        #expect(sidebarVisible.team < sidebarHidden.team)
        #expect(sidebarHidden.team < wider.team)

        for widths in [sidebarVisible, sidebarHidden, wider] {
            #expect(approximately(widths.team, widths.visibleWidths[4]))
            #expect(widths.field > widths.team)
        }

        #expect(approximately(sidebarVisible.field, 194))
        #expect(approximately(sidebarVisible.team, 165))
        #expect(approximately(sidebarHidden.field, 421))
        #expect(approximately(sidebarHidden.team, 210.5))
        #expect(approximately(wider.field, 498))
        #expect(approximately(wider.team, 249))
    }

    @Test func phoneColumnMathUsesExistingCompactBehavior() {
        let widths = GameColumnWidths.resolved(for: 1_000, titleIsEmpty: false, isPhone: true)

        #expect(approximately(widths.visibleWidths.reduce(0, +), 1_000))
        #expect(widths.date == 145)
        #expect(widths.allHit == 42)
        #expect(widths.team == 150)
        #expect(widths.status == 116)
        #expect(widths.field == 397)
    }

    private func approximately(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}

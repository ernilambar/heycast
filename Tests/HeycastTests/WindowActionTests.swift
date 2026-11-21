import CoreGraphics
import Testing

@testable import Heycast

@Suite struct WindowActionTests {
    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let current = CGRect(x: 100, y: 100, width: 200, height: 100)

    @Test func halvesTileTheVisibleFrame() {
        #expect(
            WindowAction.left.frame(current: current, visible: visible)
                == CGRect(x: 0, y: 0, width: 500, height: 800)
        )
        #expect(
            WindowAction.right.frame(current: current, visible: visible)
                == CGRect(x: 500, y: 0, width: 500, height: 800)
        )
        #expect(
            WindowAction.top.frame(current: current, visible: visible)
                == CGRect(x: 0, y: 400, width: 1000, height: 400)
        )
        #expect(
            WindowAction.bottom.frame(current: current, visible: visible)
                == CGRect(x: 0, y: 0, width: 1000, height: 400)
        )
    }

    @Test func quartersTileTheVisibleFrame() {
        #expect(
            WindowAction.topLeft.frame(current: current, visible: visible)
                == CGRect(x: 0, y: 400, width: 500, height: 400)
        )
        #expect(
            WindowAction.topRight.frame(current: current, visible: visible)
                == CGRect(x: 500, y: 400, width: 500, height: 400)
        )
        #expect(
            WindowAction.bottomLeft.frame(current: current, visible: visible)
                == CGRect(x: 0, y: 0, width: 500, height: 400)
        )
        #expect(
            WindowAction.bottomRight.frame(current: current, visible: visible)
                == CGRect(x: 500, y: 0, width: 500, height: 400)
        )
    }

    @Test func thirdsTileTheVisibleFrame() {
        #expect(
            WindowAction.leftThird.frame(current: current, visible: visible)
                == CGRect(x: 0, y: 0, width: visible.width / 3, height: 800)
        )
        #expect(
            WindowAction.leftTwoThirds.frame(current: current, visible: visible)
                == CGRect(x: 0, y: 0, width: visible.width * 2 / 3, height: 800)
        )
        #expect(
            WindowAction.rightThird.frame(current: current, visible: visible)
                == CGRect(
                    x: visible.width * 2 / 3,
                    y: 0,
                    width: visible.width / 3,
                    height: 800
                )
        )
        #expect(
            WindowAction.rightTwoThirds.frame(current: current, visible: visible)
                == CGRect(
                    x: visible.width / 3,
                    y: 0,
                    width: visible.width * 2 / 3,
                    height: 800
                )
        )
    }

    @Test func thirdsAndUndoHaveNoDefaultShortcut() {
        for action: WindowAction in [
            .leftThird, .leftTwoThirds, .rightThird, .rightTwoThirds, .undo,
        ] {
            #expect(action.defaultShortcut == nil)
        }
    }

    @Test func undoDoesNotComputeALayout() {
        #expect(
            WindowAction.undo.frame(current: current, visible: visible) == current
        )
    }

    @Test func fullscreenIsDetectedByScreenCoverage() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

        #expect(WindowCoordinates.fillsScreen(screen, on: screen))
        // Maximized: stops at the visible frame above the Dock/menu bar.
        #expect(
            !WindowCoordinates.fillsScreen(
                CGRect(x: 0, y: 0, width: 1000, height: 770),
                on: screen
            )
        )
        #expect(
            !WindowCoordinates.fillsScreen(
                CGRect(x: 100, y: 100, width: 800, height: 600),
                on: screen
            )
        )
    }

    @Test func maximizeUsesTheVisibleFrame() {
        #expect(
            WindowAction.maximize.frame(current: current, visible: visible)
                == visible
        )
    }

    @Test func centerPreservesSizeAndClampsOversizedWindows() {
        #expect(
            WindowAction.center.frame(current: current, visible: visible)
                == CGRect(x: 400, y: 350, width: 200, height: 100)
        )
        #expect(
            WindowAction.center.frame(
                current: CGRect(x: 0, y: 0, width: 2000, height: 1600),
                visible: visible
            ) == visible
        )
    }

    @Test func largestIntersectionChoosesTheScreen() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1000, height: 800),
            CGRect(x: 1000, y: 0, width: 1000, height: 800),
        ]

        #expect(
            WindowAction.targetScreenIndex(
                for: CGRect(x: 1200, y: 100, width: 200, height: 200),
                in: screens
            ) == 1
        )
        #expect(
            WindowAction.targetScreenIndex(
                for: CGRect(x: -100, y: 100, width: 200, height: 200),
                in: screens
            ) == 0
        )
    }

    @Test func offscreenWindowUsesTheFallbackScreen() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1000, height: 800),
            CGRect(x: 1000, y: 0, width: 1000, height: 800),
        ]

        #expect(
            WindowAction.targetScreenIndex(
                for: CGRect(x: 5000, y: 5000, width: 100, height: 100),
                in: screens,
                fallback: 1
            ) == 1
        )
    }

    @Test func axCoordinatesFlipAroundThePrimaryHeight() {
        let appKit = CGRect(x: 10, y: 20, width: 300, height: 200)
        let ax = WindowCoordinates.toAX(appKit, primaryHeight: 1000)

        #expect(ax == CGRect(x: 10, y: 780, width: 300, height: 200))
        #expect(
            WindowCoordinates.fromAX(ax, primaryHeight: 1000) == appKit
        )
    }
}

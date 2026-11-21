import Testing

@testable import Heycast

@Suite struct SystemShortcutsTests {
    @Test func reservedCombinationsAreOwned() {
        #expect(SystemShortcuts.owner(of: .default) == nil)
        #expect(SystemShortcuts.owner(of: HotKey.parse("cmd+space")!) == .spotlight)
        #expect(SystemShortcuts.owner(of: HotKey.parse("ctrl+space")!) == .inputSource)
        #expect(SystemShortcuts.owner(of: HotKey.parse("ctrl+up")!) == .missionControl)
        #expect(SystemShortcuts.owner(of: HotKey.parse("shift+cmd+4")!) == .screenshot)
    }

    @Test func shippedWindowDefaultsAreFree() {
        for action in WindowAction.allCases {
            guard let hotKey = action.defaultShortcut else { continue }
            #expect(SystemShortcuts.owner(of: hotKey) == nil)
        }
    }
}

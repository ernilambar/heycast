import Testing

@testable import Heycast

@Suite struct SystemShortcutsTests {
    @Test func reservedCombinationsAreOwned() {
        let reserved = SystemShortcuts.reservations(from: nil)
        #expect(reserved[.default] == nil)
        #expect(reserved[HotKey.parse("cmd+space")!] == .spotlight)
        #expect(reserved[HotKey.parse("ctrl+space")!] == .inputSource)
        #expect(reserved[HotKey.parse("ctrl+up")!] == .missionControl)
        #expect(reserved[HotKey.parse("shift+cmd+4")!] == .screenshot)
    }

    @Test func shippedWindowDefaultsAreFree() {
        let reserved = SystemShortcuts.reservations(from: nil)
        for action in WindowAction.allCases {
            guard let hotKey = action.defaultShortcut else { continue }
            #expect(reserved[hotKey] == nil)
        }
    }

    @Test func disabledShortcutIsFree() {
        let reserved = SystemShortcuts.reservations(from: [
            "64": ["enabled": false, "value": ["parameters": [32, 49, 1_048_576], "type": "standard"]],
        ])
        #expect(reserved[HotKey.parse("cmd+space")!] == nil)
        #expect(reserved[HotKey.parse("alt+cmd+space")!] == .finderSearch)
    }

    @Test func reboundShortcutMovesReservation() {
        // Spotlight rebound to ⌃⌥⌘S.
        let reserved = SystemShortcuts.reservations(from: [
            "64": ["enabled": true, "value": ["parameters": [115, 1, 0x1C0000], "type": "standard"]],
        ])
        #expect(reserved[HotKey.parse("cmd+space")!] == nil)
        #expect(reserved[HotKey.parse("ctrl+alt+cmd+s")!] == .spotlight)
    }

    @Test func unassignedShortcutIsFree() {
        let reserved = SystemShortcuts.reservations(from: [
            "64": ["enabled": true, "value": ["parameters": [65535, 65535, 0], "type": "standard"]],
        ])
        #expect(reserved[HotKey.parse("cmd+space")!] == nil)
    }

    @Test func entryWithoutValueKeepsDefault() {
        let reserved = SystemShortcuts.reservations(from: ["79": ["enabled": true]])
        #expect(reserved[HotKey.parse("ctrl+left")!] == .moveLeftSpace)
    }

    @Test func fixedShortcutsIgnoreSettings() {
        let reserved = SystemShortcuts.reservations(from: ["64": ["enabled": false]])
        #expect(reserved[HotKey.parse("cmd+tab")!] == .applicationSwitcher)
    }
}

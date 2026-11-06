import AppKit
import Testing

@testable import Heycast

@Suite @MainActor struct ClipboardTests {
    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("heycast-test-\(UUID().uuidString)"))
    }

    @Test func restoreBringsBackThePreviousClipboard() {
        let pasteboard = makePasteboard()
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("snippet text", forType: .string)
        let snippetChangeCount = pasteboard.changeCount

        snapshot.restore(to: pasteboard, ifChangeCountIs: snippetChangeCount)

        #expect(pasteboard.string(forType: .string) == "original")
    }

    @Test func restoreLeavesNewerContentsAlone() {
        let pasteboard = makePasteboard()
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("snippet text", forType: .string)
        let snippetChangeCount = pasteboard.changeCount

        pasteboard.clearContents()
        pasteboard.setString("copied later", forType: .string)
        snapshot.restore(to: pasteboard, ifChangeCountIs: snippetChangeCount)

        #expect(pasteboard.string(forType: .string) == "copied later")
    }
}

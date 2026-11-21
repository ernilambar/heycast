import Carbon.HIToolbox
import CoreGraphics

/// Synthesizes the keyboard events snippets need: backspaces to remove a
/// typed keyword, then ⌘V to insert the body.
enum SyntheticKeyboard {
    static func postPaste() {
        post(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
    }

    static func postBackspaces(_ count: Int) {
        guard count > 0 else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<count {
            post(keyCode: CGKeyCode(kVK_Delete), source: source)
        }
    }

    private static func post(
        keyCode: CGKeyCode,
        flags: CGEventFlags = [],
        source: CGEventSource? = CGEventSource(stateID: .combinedSessionState)
    ) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }

        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
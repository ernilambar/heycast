import AppKit
import ApplicationServices
import Carbon.HIToolbox
@preconcurrency import CoreGraphics
import Darwin
import Dispatch

/// Matches typed text against snippet keywords. Kept pure so the expansion
/// trigger has tests without an event tap or Accessibility permission.
struct SnippetIndex: Sendable {
    private let snippets: [Snippet]
    let count: Int
    let maxKeywordLength: Int

    init(snippets: [Snippet]) {
        let snippets = snippets.filter { !$0.keyword.isEmpty }
        self.snippets = snippets
        count = snippets.count
        maxKeywordLength = snippets.map(\.keyword.count).max() ?? 0
    }

    /// The snippet whose keyword ends the buffer, or `nil` while a longer
    /// keyword that extends the match could still be typed.
    func expansion(for buffer: String) -> Snippet? {
        var best: Snippet?
        for snippet in snippets where buffer.hasSuffix(snippet.keyword) {
            if best == nil || snippet.keyword.count > best!.keyword.count {
                best = snippet
            }
        }

        guard let best else { return nil }

        let hasLongerPendingKeyword = snippets.contains { other in
            other.keyword.count > best.keyword.count && other.keyword.hasPrefix(best.keyword)
        }
        return hasLongerPendingKeyword ? nil : best
    }
}

/// Watches typed text and replaces a matched snippet keyword with its body.
///
/// The tap can modify events, so the window server requires Accessibility;
/// without it `startIfNeeded` does nothing and the palette paste path keeps
/// working on its own.
@MainActor
final class SnippetExpander {
    private let directory: URL
    private let isEnabled: () -> Bool

    private var index = SnippetIndex(snippets: [])
    private var buffer = ""
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var directorySource: DispatchSourceFileSystemObject?
    private var isExpanding = false
    private var loggedMissingPermission = false

    init(directory: URL, isEnabled: @escaping () -> Bool) {
        self.directory = directory
        self.isEnabled = isEnabled
        reload()
        watchDirectory()
    }

    func startIfNeeded() {
        if let eventTap {
            if !CGEvent.tapIsEnabled(tap: eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        guard AXIsProcessTrusted() else {
            if !loggedMissingPermission {
                NSLog("Heycast: snippet expansion needs Accessibility")
                loggedMissingPermission = true
            }
            return
        }
        loggedMissingPermission = false

        let mask =
            CGEventMask(1 << CGEventType.keyDown.rawValue) |
            CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue) |
            CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: snippetEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("Heycast: could not create the snippet expansion event tap")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            NSLog("Heycast: could not create the snippet expansion run-loop source")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        NSLog("Heycast: snippet expansion active (%d snippets)", index.count)
    }

    func reload() {
        index = SnippetIndex(snippets: SnippetLibrary.load(from: directory))
    }

    private func watchDirectory() {
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.reload()
            }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        directorySource = source
    }

    fileprivate func handle(_ event: CGEvent) {
        guard isEnabled(), !isExpanding else {
            buffer.removeAll()
            return
        }

        guard let nsEvent = NSEvent(cgEvent: event) else { return }
        let flags = event.flags
        guard flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else {
            buffer.removeAll()
            return
        }

        let keyCode = CGKeyCode(nsEvent.keyCode)
        if keyCode == CGKeyCode(kVK_Delete) {
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            return
        }

        if Self.navigationKeyCodes.contains(keyCode) {
            buffer.removeAll()
            return
        }

        guard let characters = nsEvent.characters,
              !characters.isEmpty,
              !characters.unicodeScalars.allSatisfy({ $0.value < 32 })
        else {
            buffer.removeAll()
            return
        }

        buffer.append(characters)
        let maxLength = max(64, index.maxKeywordLength * 2)
        if buffer.count > maxLength {
            buffer = String(buffer.suffix(maxLength))
        }

        guard let snippet = index.expansion(for: buffer) else { return }

        let keywordLength = snippet.keyword.count
        buffer.removeAll()
        isExpanding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.expand(snippet, keywordLength: keywordLength)
        }
    }

    private func expand(_ snippet: Snippet, keywordLength: Int) {
        guard AXIsProcessTrusted() else {
            NSLog("Heycast: snippet expansion needs Accessibility")
            isExpanding = false
            return
        }

        // Scripts run before the keyword is removed: if one fails, the typed
        // keyword stays put instead of vanishing with nothing in its place.
        Task { [weak self] in
            guard let text = await SnippetRunner.text(for: snippet) else {
                NSSound.beep()
                self?.isExpanding = false
                return
            }
            self?.paste(text, replacingKeywordOfLength: keywordLength)
        }
    }

    private func paste(_ text: String, replacingKeywordOfLength keywordLength: Int) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        SyntheticKeyboard.postBackspaces(keywordLength)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            SyntheticKeyboard.postPaste()
            self?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                self?.isExpanding = false
            }
        }
    }

    fileprivate func reenableTap() {
        guard AXIsProcessTrusted(), let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private static let navigationKeyCodes: Set<CGKeyCode> = [
        CGKeyCode(kVK_Return),
        CGKeyCode(kVK_ANSI_KeypadEnter),
        CGKeyCode(kVK_Tab),
        CGKeyCode(kVK_Escape),
        CGKeyCode(kVK_LeftArrow),
        CGKeyCode(kVK_RightArrow),
        CGKeyCode(kVK_UpArrow),
        CGKeyCode(kVK_DownArrow),
        CGKeyCode(kVK_Home),
        CGKeyCode(kVK_End),
        CGKeyCode(kVK_PageUp),
        CGKeyCode(kVK_PageDown),
        CGKeyCode(kVK_ForwardDelete),
    ]
}

/// Carbon and CoreGraphics callbacks are C function pointers, so the expander
/// arrives through `userInfo`; the tap runs on the main run loop.
private func snippetEventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let expander = Unmanaged<SnippetExpander>.fromOpaque(userInfo).takeUnretainedValue()

    MainActor.assumeIsolated {
        switch type {
        case .keyDown:
            expander.handle(event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            expander.reenableTap()
        default:
            break
        }
    }

    return Unmanaged.passUnretained(event)
}
import AppKit
import Carbon.HIToolbox

/// Global hotkey through Carbon's `RegisterEventHotKey`.
///
/// Unlike a `CGEventTap`, this needs neither Accessibility nor Input
/// Monitoring: the window server delivers the hotkey to this process only.
/// The handler fires while another app is frontmost, which is the whole point
/// of a launcher shortcut.
@MainActor
final class HotKeyController {
    static let defaultKeyCode = UInt32(kVK_Space)
    static let defaultModifiers = UInt32(optionKey)

    private static let signature: OSType = 0x4845_5943 // 'HEYC'
    private static let identifier: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(
        keyCode: UInt32 = HotKeyController.defaultKeyCode,
        modifiers: UInt32 = HotKeyController.defaultModifiers,
        action: @escaping () -> Void
    ) {
        self.action = action
        install(keyCode: keyCode, modifiers: modifiers)
        register(keyCode: keyCode, modifiers: modifiers)
    }

    fileprivate func perform() {
        action()
    }

    private func install(keyCode: UInt32, modifiers: UInt32) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        if status != noErr {
            NSLog("Heycast: hotkey handler installation failed (\(status))")
        }
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.identifier)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("Heycast: ⌥Space is unavailable, another app holds it (\(status))")
        }
    }
}

/// Carbon callbacks are C function pointers, so this cannot capture the
/// controller; the instance arrives through `userData`. Hotkey events are
/// delivered on the main thread.
private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { controller.perform() }
    return noErr
}

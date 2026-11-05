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
    private static let signature: OSType = 0x4845_5943 // 'HEYC'
    private static var nextIdentifier: UInt32 = 1

    /// Every controller installs its own handler on the application target,
    /// so each one sees every hotkey press; the ID tells them apart.
    fileprivate let identifier: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(hotKey: HotKey = .default, action: @escaping () -> Void) {
        self.action = action
        identifier = Self.nextIdentifier
        Self.nextIdentifier += 1
        install()
        register(hotKey: hotKey)
    }

    fileprivate func perform() {
        action()
    }

    private func install() {
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

    private func register(hotKey: HotKey) {
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog(
                "Heycast: %@ is unavailable, another app or system shortcut holds it (\(status))",
                hotKey.displayString
            )
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
    guard let userData, let event else { return OSStatus(eventNotHandledErr) }
    let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    // Not ours: pass it on so the controller that registered it can run.
    guard status == noErr,
          hotKeyID.id == MainActor.assumeIsolated({ controller.identifier })
    else { return OSStatus(eventNotHandledErr) }

    MainActor.assumeIsolated { controller.perform() }
    return noErr
}

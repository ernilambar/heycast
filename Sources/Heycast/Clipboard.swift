import AppKit

/// A copy of the general pasteboard taken before Heycast puts snippet text on
/// it, so the user's own clipboard comes back after the paste.
///
/// Items are copied by data, not by reference: writing new contents
/// invalidates the pasteboard's own items.
///
/// `@unchecked Sendable` because `NSPasteboardItem` is not, but every
/// instance is captured and restored on the main thread only.
struct ClipboardSnapshot: @unchecked Sendable {
    private let items: [NSPasteboardItem]

    static func capture(from pasteboard: NSPasteboard = .general) -> ClipboardSnapshot {
        let copied = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
        return ClipboardSnapshot(items: copied)
    }

    /// Puts the snapshot back, but only while the pasteboard still holds what
    /// Heycast wrote. A user copy or another app's write in between wins: the
    /// restore must never clobber newer content.
    func restore(
        to pasteboard: NSPasteboard = .general,
        ifChangeCountIs expectedChangeCount: Int
    ) {
        guard pasteboard.changeCount == expectedChangeCount else { return }
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}

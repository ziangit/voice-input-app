import AppKit
import Carbon

final class TextInjector {

    // kVK_ANSI_V = 0x09
    private let vKeyCode: CGKeyCode = 0x09

    func inject(text: String, completion: (() -> Void)? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion?()
            return
        }

        let pasteboard = NSPasteboard.general

        // 1. Save current clipboard
        let savedContents = savedClipboard()

        // 2. Detect current input source; switch to ASCII if CJK
        let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        let needsSwitch = !isASCIICapable(currentSource)
        var asciiSource: TISInputSource?

        if needsSwitch {
            asciiSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
            if let src = asciiSource { TISSelectInputSource(src) }
        }

        // 3. Place text on clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 4. Small pause to let input source switch propagate, then paste
        let pasteDelay: TimeInterval = needsSwitch ? 0.08 : 0.02
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) { [weak self] in
            self?.simulateCmdV()

            // 5. Restore input source and clipboard after paste lands
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if needsSwitch, let original = currentSource {
                    TISSelectInputSource(original)
                }
                // Restore clipboard
                pasteboard.clearContents()
                for (type, data) in savedContents {
                    pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type))
                }
                completion?()
            }
        }
    }

    // MARK: - Private

    private func simulateCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
        else { return }

        down.flags = .maskCommand
        up.flags   = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func isASCIICapable(_ source: TISInputSource?) -> Bool {
        guard let source else { return true }
        guard let val = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable) else {
            return false
        }
        return CFBooleanGetValue(unsafeBitCast(val, to: CFBoolean.self))
    }

    private func savedClipboard() -> [(String, Data)] {
        let pb = NSPasteboard.general
        guard let items = pb.pasteboardItems else { return [] }
        var result: [(String, Data)] = []
        for item in items {
            for type in item.types {
                if let data = item.data(forType: type) {
                    result.append((type.rawValue, data))
                }
            }
        }
        return result
    }
}

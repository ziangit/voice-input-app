import Cocoa
import ApplicationServices

// CGEventFlags raw value for the Fn / Globe modifier key
private let kFnFlagMask: CGEventFlags = CGEventFlags(rawValue: 0x00800000)

final class KeyMonitor {
    var onFnDown: (() -> Void)?
    var onFnUp:   (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnIsDown = false

    // MARK: - Start / Stop

    func start() {
        guard AXIsProcessTrusted() else {
            promptForAccessibility()
            return
        }
        installTap()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Private

    private func installTap() {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        )

        guard let tap else {
            // Accessibility permission may have been granted but tap creation failed; try prompting again.
            promptForAccessibility()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .flagsChanged else { return Unmanaged.passUnretained(event) }

        let flags = event.flags
        let fnNowDown = flags.contains(kFnFlagMask)

        if fnNowDown && !fnIsDown {
            fnIsDown = true
            DispatchQueue.main.async { [weak self] in self?.onFnDown?() }
            return nil   // suppress → prevents emoji picker
        } else if !fnNowDown && fnIsDown {
            fnIsDown = false
            DispatchQueue.main.async { [weak self] in self?.onFnUp?() }
            return nil   // suppress
        }

        return Unmanaged.passUnretained(event)
    }

    private func promptForAccessibility() {
        let opts: [String: Any] = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }
}

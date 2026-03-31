import AppKit

final class FloatingWindowController {

    private var panel: NSPanel?
    private var waveformView: WaveformView?
    private var textLabel: NSTextField?
    private var blurView: NSVisualEffectView?
    private var contentContainer: NSView?

    // Layout constants
    private let panelH: CGFloat = 56
    private let cornerR: CGFloat = 28
    private let leftPad: CGFloat = 20
    private let rightPad: CGFloat = 20
    private let waveW: CGFloat = 44
    private let waveH: CGFloat = 32
    private let gap: CGFloat = 12
    private let labelMinW: CGFloat = 160
    private let labelMaxW: CGFloat = 560

    private var currentLabelW: CGFloat = 0
    private var isVisible = false

    // MARK: - Public

    func show() {
        if panel == nil { buildPanel() }
        guard let panel else { return }

        currentLabelW = labelMinW
        applyPanelFrame(animated: false)
        textLabel?.stringValue = ""

        // Start invisible and slightly small for spring-in
        panel.alphaValue = 0
        contentContainer?.layer?.transform = CATransform3DMakeScale(0.88, 0.88, 1)
        panel.orderFrontRegardless()
        isVisible = true

        waveformView?.startAnimating()

        // Alpha fade
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        // Spring scale
        animateScale(from: CATransform3DMakeScale(0.88, 0.88, 1),
                     to: CATransform3DIdentity,
                     duration: 0.35,
                     damping: 18, stiffness: 350)
    }

    func hide() {
        guard isVisible, let panel else { return }
        isVisible = false
        waveformView?.stopAnimating()

        animateScale(from: CATransform3DIdentity,
                     to: CATransform3DMakeScale(0.88, 0.88, 1),
                     duration: 0.22,
                     damping: 30, stiffness: 500)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    func updateText(_ text: String) {
        guard isVisible else { return }
        textLabel?.stringValue = text
        updateLabelWidth(for: text)
    }

    func updateLevel(_ level: Float) {
        waveformView?.updateLevel(level)
    }

    func showRefining() {
        guard isVisible else { return }
        textLabel?.stringValue = "Refining…"
        updateLabelWidth(for: "Refining…")
    }

    // MARK: - Build

    private func buildPanel() {
        let initialW = leftPad + waveW + gap + labelMinW + rightPad
        let initialFrame = NSRect(x: 0, y: 0, width: initialW, height: panelH)

        let p = NSPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovable = false
        p.acceptsMouseMovedEvents = false

        // Root content view
        let root = NSView(frame: NSRect(origin: .zero, size: initialFrame.size))
        root.wantsLayer = true
        p.contentView = root

        // Blur / frost background
        let blur = NSVisualEffectView(frame: root.bounds)
        blur.autoresizingMask = [.width, .height]
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = cornerR
        blur.layer?.masksToBounds = true
        root.addSubview(blur)
        blurView = blur

        // Container that carries the spring animation (same frame as root)
        let container = NSView(frame: root.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        root.addSubview(container)
        contentContainer = container

        // Waveform
        let wv = WaveformView()
        wv.frame = NSRect(
            x: leftPad,
            y: (panelH - waveH) / 2,
            width: waveW,
            height: waveH
        )
        wv.wantsLayer = true
        container.addSubview(wv)
        waveformView = wv

        // Text label
        let label = NSTextField(labelWithString: "")
        label.textColor = NSColor.white.withAlphaComponent(0.95)
        label.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        label.wantsLayer = true
        label.frame = labelFrame(width: labelMinW)
        container.addSubview(label)
        textLabel = label

        currentLabelW = labelMinW
        panel = p
    }

    // MARK: - Frame helpers

    private func labelFrame(width: CGFloat) -> NSRect {
        let h: CGFloat = 24
        return NSRect(
            x: leftPad + waveW + gap,
            y: (panelH - h) / 2,
            width: width,
            height: h
        )
    }

    private func panelWidth(labelW: CGFloat) -> CGFloat {
        return leftPad + waveW + gap + labelW + rightPad
    }

    private func applyPanelFrame(animated: Bool) {
        guard let panel, let screen = NSScreen.main else { return }
        let w = panelWidth(labelW: currentLabelW)
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - w / 2
        let y = screenFrame.minY + 32
        let newFrame = NSRect(x: x, y: y, width: w, height: panelH)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: false)
        }
    }

    private func updateLabelWidth(for text: String) {
        guard let label = textLabel else { return }

        let measured = measureText(text, font: label.font!)
        let target = min(max(measured + 8, labelMinW), labelMaxW)
        guard abs(target - currentLabelW) > 2 else { return }

        currentLabelW = target

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            label.animator().frame = labelFrame(width: target)
        }
        applyPanelFrame(animated: true)
    }

    private func measureText(_ text: String, font: NSFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attrs)
        return ceil(size.width)
    }

    // MARK: - Core Animation helpers

    private func animateScale(from: CATransform3D, to: CATransform3D,
                               duration: CFTimeInterval,
                               damping: CGFloat, stiffness: CGFloat) {
        guard let layer = contentContainer?.layer else { return }

        // Set model value first so there is no snap-back after animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = to
        CATransaction.commit()

        let anim = CASpringAnimation(keyPath: "transform")
        anim.damping = damping
        anim.stiffness = stiffness
        anim.mass = 1
        anim.initialVelocity = 0
        anim.fromValue = from
        anim.toValue = to
        anim.duration = max(duration, anim.settlingDuration)
        layer.add(anim, forKey: "scaleSpring")
    }
}

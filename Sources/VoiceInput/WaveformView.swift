import AppKit

// Five-bar animated waveform driven by real-time RMS audio levels.
// Uses a 60 fps Timer (macOS-compatible) for smooth rendering.
final class WaveformView: NSView {

    // Bar relative weights: center-high, sides-low
    private let weights: [Float] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private var smoothed: [Float] = [0, 0, 0, 0, 0]

    private var animTimer: Timer?
    private var isDecaying = false

    // Latest raw level fed from the audio callback
    private var targetLevel: Float = 0

    // MARK: - Layout constants
    private let barW:   CGFloat = 4
    private let barGap: CGFloat = 5
    private let maxH:   CGFloat = 26
    private let minH:   CGFloat = 4
    private let barColor = NSColor.white.withAlphaComponent(0.92)

    override var intrinsicContentSize: NSSize { NSSize(width: 44, height: 32) }

    // MARK: - Public

    func startAnimating() {
        isDecaying = false
        guard animTimer == nil else { return }
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(animTimer!, forMode: .common)
    }

    func stopAnimating() {
        isDecaying = true
        targetLevel = 0
        // Keep the timer alive so bars decay to zero gracefully
    }

    func updateLevel(_ level: Float) {
        targetLevel = level
    }

    // MARK: - Timer callback

    private func tick() {
        updateSmoothed(target: isDecaying ? 0 : targetLevel)
        needsDisplay = true

        if isDecaying && smoothed.allSatisfy({ $0 < 0.005 }) {
            animTimer?.invalidate()
            animTimer = nil
            // Zero out and do one final redraw so bars disappear cleanly
            smoothed = [0, 0, 0, 0, 0]
            needsDisplay = true
        }
    }

    // MARK: - Smoothing (envelope with attack / release coefficients)

    private func updateSmoothed(target: Float) {
        for i in 0..<5 {
            let jitter = Float.random(in: -0.04...0.04)
            let desired = target * weights[i] * (1 + jitter)
            let alpha: Float = desired > smoothed[i] ? 0.40 : 0.15
            smoothed[i] += alpha * (desired - smoothed[i])
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let totalW = CGFloat(5) * barW + CGFloat(4) * barGap
        let startX = (bounds.width - totalW) / 2
        let centerY = bounds.midY

        barColor.setFill()

        for i in 0..<5 {
            let h = max(minH, CGFloat(smoothed[i]) * maxH)
            let x = startX + CGFloat(i) * (barW + barGap)
            let y = centerY - h / 2
            let rect = CGRect(x: x, y: y, width: barW, height: h)
            let path = CGPath(roundedRect: rect,
                              cornerWidth: barW / 2,
                              cornerHeight: barW / 2,
                              transform: nil)
            ctx.addPath(path)
            ctx.fillPath()
        }
    }
}

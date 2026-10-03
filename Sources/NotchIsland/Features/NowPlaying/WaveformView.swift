import AppKit
import SwiftUI

/// Waveform driven by Core Animation: the animation is rendered in WindowServer,
/// so the app uses almost no CPU even though it runs continuously (unlike a repeating SwiftUI animation).
struct WaveformView: NSViewRepresentable {
    let color: NSColor

    func makeNSView(context: Context) -> WaveformNSView {
        WaveformNSView(color: color)
    }

    func updateNSView(_ nsView: WaveformNSView, context: Context) {}
}

final class WaveformNSView: NSView {
    private let bars: [CALayer]
    private static let durations: [CFTimeInterval] = [0.45, 0.62, 0.5, 0.7]

    init(color: NSColor) {
        bars = Self.durations.map { _ in
            let bar = CALayer()
            bar.backgroundColor = color.cgColor
            bar.cornerRadius = 1.25
            return bar
        }
        super.init(frame: .zero)
        wantsLayer = true
        bars.forEach { layer?.addSublayer($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let barWidth: CGFloat = 2.5
        let spacing = (bounds.width - barWidth * CGFloat(bars.count)) / CGFloat(bars.count - 1)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            bar.frame = CGRect(x: CGFloat(index) * (barWidth + spacing), y: 0, width: barWidth, height: bounds.height)
        }
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        for (index, bar) in bars.enumerated() {
            bar.removeAllAnimations()
            guard window != nil else { continue }
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = 0.3
            animation.toValue = 1
            animation.duration = Self.durations[index]
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(animation, forKey: "wave")
        }
    }
}

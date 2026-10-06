import AppKit
import SwiftUI

/// What the pet is doing. It only reads state the app already has (music, battery), so it adds no monitoring.
enum PetMood: Equatable {
    case idle       // blinks and breathes
    case dancing    // music is playing
    case happy      // charging
    case tired      // battery low and not plugged in
}

/// The pet, animated with Core Animation: the frames and movement are played by WindowServer,
/// so the app itself uses no CPU while it moves.
struct PetView: NSViewRepresentable {
    let kind: PetKind
    let mood: PetMood

    func makeNSView(context: Context) -> PetNSView { PetNSView() }

    func updateNSView(_ view: PetNSView, context: Context) {
        view.kind = kind
        view.mood = mood
    }
}

final class PetNSView: NSView {
    var kind: PetKind = .cat {
        didSet { if kind != oldValue { startAnimations() } }
    }
    var mood: PetMood = .idle {
        didSet { if mood != oldValue { startAnimations() } }
    }

    private let sprite = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        sprite.magnificationFilter = .nearest   // keep the pixels crisp
        sprite.contentsGravity = .resizeAspect
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)   // breathe / hop from the feet
        layer?.addSublayer(sprite)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sprite.bounds = bounds
        sprite.position = CGPoint(x: bounds.midX, y: 0)
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startAnimations()
    }

    private func startAnimations() {
        sprite.removeAllAnimations()
        guard window != nil else { return }
        let sprites = kind.sprites

        switch mood {
        case .idle:
            sprite.contents = sprites.open
            sprite.add(frames([sprites.open, sprites.blink, sprites.open], at: [0, 0.94, 0.975], duration: 4), forKey: "frames")
            sprite.add(breathing(amount: 0.04, duration: 1.6), forKey: "breathe")

        case .dancing:
            sprite.contents = sprites.happy
            sprite.add(frames([sprites.open, sprites.happy], at: [0, 0.5], duration: 1), forKey: "frames")
            let sway = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            sway.values = [-0.12, 0.12, -0.12]
            sway.keyTimes = [0, 0.5, 1]
            sway.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut)]
            sway.duration = 1
            sway.repeatCount = .infinity
            sprite.add(sway, forKey: "sway")
            sprite.add(hop(height: 1.5, duration: 0.5, at: 0.5), forKey: "hop")

        case .happy:
            sprite.contents = sprites.happy
            sprite.add(breathing(amount: 0.04, duration: 1.6), forKey: "breathe")
            sprite.add(hop(height: 3, duration: 3, at: 0.85), forKey: "hop")

        case .tired:
            sprite.contents = sprites.sleepy
            sprite.add(breathing(amount: 0.06, duration: 3), forKey: "breathe")
        }
    }

    /// Flip-book through `images`; `times` are the start times (0...1) of each image.
    private func frames(_ images: [CGImage], at times: [Double], duration: CFTimeInterval) -> CAAnimation {
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = images
        animation.keyTimes = (times + [1]).map { NSNumber(value: $0) }   // discrete needs one more key time
        animation.calculationMode = .discrete
        animation.duration = duration
        animation.repeatCount = .infinity
        return animation
    }

    private func breathing(amount: CGFloat, duration: CFTimeInterval) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "transform.scale.y")
        animation.fromValue = 1
        animation.toValue = 1 + amount
        animation.duration = duration / 2
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }

    /// A small jump once per `duration`, starting at `at` (0...1).
    private func hop(height: CGFloat, duration: CFTimeInterval, at start: Double) -> CAAnimation {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        let peak = min(start + (1 - start) / 2, 1)
        animation.values = [0, 0, height, 0]
        animation.keyTimes = [0, NSNumber(value: start), NSNumber(value: peak), 1]
        animation.duration = duration
        animation.repeatCount = .infinity
        return animation
    }
}

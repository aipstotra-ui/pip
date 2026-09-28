import Foundation

/// Plays Pip's frames for the current state. Sleeps between frames (no polling, no display link),
/// and stops completely while paused (Pip hidden, covered, or the screen asleep).
@MainActor
final class PetAnimator {
    /// didSet (not @Observable/Observation) so a frame change is a direct call into the view layer,
    /// not a SwiftUI invalidation + re-layout of a hosting view tree.
    private(set) var frame: PixelArt = PipSprites.idle0 {
        didSet { onFrameChange?() }
    }
    private(set) var machine = PetStateMachine()
    private(set) var isPaused = false

    /// Notifies the view to redraw. Set by whatever displays `frame`/`state`.
    var onFrameChange: (() -> Void)?

    private var lastInteraction = Date()
    private var task: Task<Void, Never>?

    var state: PetState { machine.state }

    deinit { task?.cancel() }

    func start() { restart() }

    func send(_ event: PetEvent) {
        if event == .interaction || event == .summoned { lastInteraction = Date() }
        let before = machine.state
        machine.handle(event)
        if machine.state != before { restart() }
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        if paused {
            task?.cancel()
            task = nil
        } else {
            restart()
        }
    }

    private func restart() {
        task?.cancel()
        task = nil
        guard !isPaused else { return }
        let state = machine.state
        let frames = PetAnimations.frames(for: state)
        task = Task { [weak self] in
            while !Task.isCancelled {
                for next in frames {
                    guard let self, !Task.isCancelled else { return }
                    self.frame = next.art
                    try? await Task.sleep(for: .seconds(next.duration))
                }
                guard let self, !Task.isCancelled else { return }
                if !PetAnimations.loops(state) {
                    self.send(.animationFinished)
                    return
                }
                if state == .idle {
                    self.send(.idleFor(Date().timeIntervalSince(self.lastInteraction)))
                    if self.machine.state != .idle { return }   // fell asleep; a new task took over
                }
            }
        }
    }
}

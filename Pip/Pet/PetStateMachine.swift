import Foundation

enum PetState: Equatable, Sendable {
    case idle, happy, sleeping, listening
}

enum PetEvent: Equatable, Sendable {
    case interaction                      // hover, click or drag on Pip
    case summoned                         // an AI app was opened
    case animationFinished                // a one-shot animation (happy) ended
    case idleFor(TimeInterval)            // seconds since the last interaction
    case listeningStarted, listeningEnded // push-to-talk (M5)
}

/// Pip's mood rules. Pure, so it's easy to test.
struct PetStateMachine: Equatable, Sendable {
    static let sleepAfter: TimeInterval = 300

    private(set) var state: PetState = .idle

    mutating func handle(_ event: PetEvent) {
        switch (event, state) {
        case (.listeningStarted, _): state = .listening
        case (.listeningEnded, .listening): state = .idle
        case (_, .listening): break                                // listening wins until it ends
        case (.summoned, _): state = .happy
        case (.animationFinished, .happy): state = .idle
        case (.interaction, .sleeping): state = .idle              // wake up
        case (.idleFor(let seconds), .idle) where seconds >= Self.sleepAfter: state = .sleeping
        default: break
        }
    }
}

struct PetFrame: Equatable, Sendable {
    let art: PixelArt
    let duration: Double   // seconds
}

/// Frame timing for each state. Low frame rates keep idle energy use tiny.
enum PetAnimations {
    static func frames(for state: PetState) -> [PetFrame] {
        switch state {
        case .idle:
            // Breathe in and out, then blink.
            [PetFrame(art: PipSprites.idle0, duration: 1.6),
             PetFrame(art: PipSprites.idle1, duration: 0.25),
             PetFrame(art: PipSprites.idle0, duration: 0.25),
             PetFrame(art: PipSprites.idle3, duration: 0.25),
             PetFrame(art: PipSprites.idle0, duration: 1.8),
             PetFrame(art: PipSprites.idle2, duration: 0.14),
             PetFrame(art: PipSprites.idle0, duration: 1.2)]
        case .happy:
            [PetFrame(art: PipSprites.happy0, duration: 0.09),
             PetFrame(art: PipSprites.happy1, duration: 0.11),
             PetFrame(art: PipSprites.happy2, duration: 0.18),
             PetFrame(art: PipSprites.happy1, duration: 0.11),
             PetFrame(art: PipSprites.happy3, duration: 0.11),
             PetFrame(art: PipSprites.idle0, duration: 0.1)]
        case .sleeping:
            [PetFrame(art: PipSprites.sleep0, duration: 1.0),
             PetFrame(art: PipSprites.sleep1, duration: 1.0)]
        case .listening:
            [PetFrame(art: PipSprites.listening0, duration: 0.35),
             PetFrame(art: PipSprites.listening1, duration: 0.35)]
        }
    }

    /// One-shot animations end with `.animationFinished`; the rest loop.
    static func loops(_ state: PetState) -> Bool { state != .happy }
}

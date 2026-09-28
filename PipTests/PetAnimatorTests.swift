import XCTest
@testable import Pip

@MainActor
final class PetAnimatorTests: XCTestCase {

    func testStartThenSummonedGoesHappy() {
        let animator = PetAnimator()
        animator.start()
        animator.send(.summoned)
        XCTAssertEqual(animator.state, .happy)
    }

    func testSetPausedKeepsStateAndStopsFrameChanges() async throws {
        let animator = PetAnimator()
        animator.start()
        animator.send(.listeningStarted)   // fast-changing frames (0.35s each)
        XCTAssertEqual(animator.state, .listening)

        // Let the animation get going before pausing.
        try await Task.sleep(for: .milliseconds(50))
        animator.setPaused(true)
        let capturedFrame = animator.frame
        let capturedState = animator.state

        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(animator.state, capturedState, "paused animator must not change state")
        XCTAssertEqual(animator.frame, capturedFrame, "paused animator must not advance frames")
    }

    func testHappyAnimationReturnsToIdle() async throws {
        let animator = PetAnimator()
        animator.start()
        animator.send(.summoned)
        XCTAssertEqual(animator.state, .happy)

        let deadline = Date().addingTimeInterval(1.5)
        while animator.state != .idle && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(animator.state, .idle, "happy animation (~0.7s) should finish and return to idle")
    }

    func testListeningStartedProducesAListeningFrameQuickly() async throws {
        let animator = PetAnimator()
        animator.start()
        animator.send(.listeningStarted)
        XCTAssertEqual(animator.state, .listening)

        let deadline = Date().addingTimeInterval(0.5)
        var sawListeningFrame = false
        while Date() < deadline {
            if PipSprites.listening.contains(animator.frame) {
                sawListeningFrame = true
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(sawListeningFrame, "frame should become one of PipSprites.listening within 0.5s")
    }
}

import XCTest
@testable import Pip

final class PetStateMachineTests: XCTestCase {

    // MARK: - transitions

    func testIdlePlusSummonedGoesHappy() {
        var m = PetStateMachine()
        m.handle(.summoned)
        XCTAssertEqual(m.state, .happy)
    }

    func testHappyPlusAnimationFinishedGoesIdle() {
        var m = PetStateMachine()
        m.handle(.summoned)
        m.handle(.animationFinished)
        XCTAssertEqual(m.state, .idle)
    }

    func testIdleFor299StaysIdle() {
        var m = PetStateMachine()
        m.handle(.idleFor(299))
        XCTAssertEqual(m.state, .idle)
    }

    func testIdleFor300GoesSleeping() {
        var m = PetStateMachine()
        m.handle(.idleFor(300))
        XCTAssertEqual(m.state, .sleeping)
    }

    func testSleepingPlusInteractionGoesIdle() {
        var m = PetStateMachine()
        m.handle(.idleFor(300))
        XCTAssertEqual(m.state, .sleeping)
        m.handle(.interaction)
        XCTAssertEqual(m.state, .idle)
    }

    func testSleepingPlusSummonedGoesHappy() {
        var m = PetStateMachine()
        m.handle(.idleFor(300))
        XCTAssertEqual(m.state, .sleeping)
        m.handle(.summoned)
        XCTAssertEqual(m.state, .happy)
    }

    func testListeningStartedFromAnyStateGoesListening() {
        let starts: [PetState] = [.idle, .happy, .sleeping]
        for start in starts {
            var m = PetStateMachine()
            switch start {
            case .idle: break
            case .happy: m.handle(.summoned)
            case .sleeping: m.handle(.idleFor(300))
            case .listening: m.handle(.listeningStarted)
            }
            XCTAssertEqual(m.state, start, "setup failed for \(start)")
            m.handle(.listeningStarted)
            XCTAssertEqual(m.state, .listening, "from \(start)")
        }
    }

    func testWhileListeningOtherEventsAreIgnored() {
        var m = PetStateMachine()
        m.handle(.listeningStarted)
        XCTAssertEqual(m.state, .listening)

        m.handle(.summoned)
        XCTAssertEqual(m.state, .listening, "summoned should be ignored while listening")

        m.handle(.interaction)
        XCTAssertEqual(m.state, .listening, "interaction should be ignored while listening")

        m.handle(.idleFor(1000))
        XCTAssertEqual(m.state, .listening, "idleFor should be ignored while listening")
    }

    func testListeningEndedGoesIdle() {
        var m = PetStateMachine()
        m.handle(.listeningStarted)
        m.handle(.listeningEnded)
        XCTAssertEqual(m.state, .idle)
    }

    func testListeningEndedWhileNotListeningDoesNothing() {
        var idleMachine = PetStateMachine()
        idleMachine.handle(.listeningEnded)
        XCTAssertEqual(idleMachine.state, .idle)

        var happyMachine = PetStateMachine()
        happyMachine.handle(.summoned)
        happyMachine.handle(.listeningEnded)
        XCTAssertEqual(happyMachine.state, .happy)

        var sleepingMachine = PetStateMachine()
        sleepingMachine.handle(.idleFor(300))
        sleepingMachine.handle(.listeningEnded)
        XCTAssertEqual(sleepingMachine.state, .sleeping)
    }

    func testHappyPlusIdleForStaysHappy() {
        var m = PetStateMachine()
        m.handle(.summoned)
        m.handle(.idleFor(1000))
        XCTAssertEqual(m.state, .happy)
    }

    // MARK: - PetAnimations

    func testEveryStateHasAtLeastTwoFrames() {
        for state: PetState in [.idle, .happy, .sleeping, .listening] {
            XCTAssertGreaterThanOrEqual(PetAnimations.frames(for: state).count, 2, "\(state)")
        }
    }

    func testAllDurationsArePositiveAndAtMostTwoSeconds() {
        for state: PetState in [.idle, .happy, .sleeping, .listening] {
            for frame in PetAnimations.frames(for: state) {
                XCTAssertGreaterThan(frame.duration, 0, "\(state)")
                XCTAssertLessThanOrEqual(frame.duration, 2.0, "\(state)")
            }
        }
    }

    func testOnlyHappyDoesNotLoop() {
        XCTAssertFalse(PetAnimations.loops(.happy))
        XCTAssertTrue(PetAnimations.loops(.idle))
        XCTAssertTrue(PetAnimations.loops(.sleeping))
        XCTAssertTrue(PetAnimations.loops(.listening))
    }

    func testIdleCycleIsAtLeastFourSeconds() {
        let total = PetAnimations.frames(for: .idle).reduce(0) { $0 + $1.duration }
        XCTAssertGreaterThanOrEqual(total, 4.0)
    }

    func testNoFrameChangeFasterThan008Seconds() {
        for state: PetState in [.idle, .happy, .sleeping, .listening] {
            for frame in PetAnimations.frames(for: state) {
                XCTAssertGreaterThanOrEqual(frame.duration, 0.08, "\(state) frame changes faster than ~12fps")
            }
        }
    }
}

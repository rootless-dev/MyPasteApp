//
//  PauseTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

@Suite("Pause state")
struct PauseStateTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Active is never paused")
    func activeIsNotPaused() {
        #expect(PauseState.active.isPaused(at: now) == false)
    }

    @Test("An indefinite pause holds at any instant")
    func indefiniteAlwaysPaused() {
        #expect(PauseState.pausedIndefinitely.isPaused(at: now))
        #expect(PauseState.pausedIndefinitely.isPaused(at: now.addingTimeInterval(86_400)))
    }

    @Test("A timed pause holds before its deadline")
    func timedPauseBeforeDeadline() {
        let state = PauseState.pausedUntil(now.addingTimeInterval(900))
        #expect(state.isPaused(at: now))
        #expect(state.isPaused(at: now.addingTimeInterval(899)))
    }

    @Test("A timed pause is over at the deadline and after it")
    func timedPauseAtAndAfterDeadline() {
        // Decided against the clock rather than against the timer having
        // fired: a machine that sleeps through the pause must wake up
        // collecting again, and its Timer comes back late.
        let deadline = now.addingTimeInterval(900)
        let state = PauseState.pausedUntil(deadline)
        #expect(state.isPaused(at: deadline) == false)
        #expect(state.isPaused(at: deadline.addingTimeInterval(1)) == false)
        #expect(state.isPaused(at: deadline.addingTimeInterval(86_400)) == false)
    }
}

@Suite("Pause durations")
struct PauseDurationTests {
    @Test("The menu offers 15min, 30min, 1h, 3h and 8h, in that order")
    func offeredDurations() {
        let expected: [TimeInterval] = [15 * 60, 30 * 60, 60 * 60, 3 * 60 * 60, 8 * 60 * 60]
        #expect(PauseDuration.offered.map(\.seconds) == expected)
    }

    private static let titleCases: [(seconds: TimeInterval, expected: String)] = [
        (TimeInterval(15 * 60), "15 minutes"),
        (TimeInterval(30 * 60), "30 minutes"),
        (TimeInterval(60 * 60), "1 hour"),
        (TimeInterval(3 * 60 * 60), "3 hours"),
        (TimeInterval(8 * 60 * 60), "8 hours"),
    ]

    @Test("Titles read naturally", arguments: titleCases)
    func titles(seconds: TimeInterval, expected: String) {
        #expect(PauseDuration(seconds: seconds).title == expected)
    }
}

@MainActor
@Suite("Pause controller")
struct PauseControllerTests {
    // MARK: - Stale-timer regression

    // `resumeIfStillCurrent` is the guard added after review: a Timer's
    // callback fires synchronously, but the `resume()` it wants runs behind
    // a `Task` hop onto MainActor. `transition(to:)` invalidating the old
    // Timer does nothing to a Task an already-fired Timer already enqueued,
    // so a stale one must not be allowed to undo a newer pause. These tests
    // call it directly with a Timer that stands in for that stale one,
    // rather than racing a real Timer's fire against a Task hop, which
    // can't be made to interleave deterministically.

    @Test("A stale timer's resume is ignored once an indefinite pause replaced it")
    func staleTimerIgnoredAfterIndefinitePause() {
        let controller = PauseController()
        controller.pauseIndefinitely()

        let staleTimer = Timer(timeInterval: 1, repeats: false) { _ in }
        controller.resumeIfStillCurrent(staleTimer)

        #expect(controller.state == .pausedIndefinitely)
    }

    @Test("A stale timer's resume is ignored once a newer timed pause replaced it")
    func staleTimerIgnoredAfterNewerTimedPause() {
        let controller = PauseController()
        controller.pause(for: PauseDuration(seconds: 900))

        let staleTimer = Timer(timeInterval: 1, repeats: false) { _ in }
        controller.pause(for: PauseDuration(seconds: 1_800))
        controller.resumeIfStillCurrent(staleTimer)

        #expect(controller.isPaused)
    }

    @Test("A pause still resumes on its own once its own timer elapses")
    func timedPauseResumesAutomatically() async throws {
        let controller = PauseController()
        controller.pause(for: PauseDuration(seconds: 0.05))

        try await Task.sleep(for: .seconds(0.3))

        #expect(controller.state == .active)
    }
}

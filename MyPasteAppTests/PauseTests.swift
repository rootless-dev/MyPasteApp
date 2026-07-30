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

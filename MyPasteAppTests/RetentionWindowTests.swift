//
//  RetentionWindowTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

@Suite("Retention window")
struct RetentionWindowTests {
    @Test("The stops are ordered from shortest to forever")
    func stopsAreOrdered() {
        #expect(RetentionWindow.allCases.map(\.days) == [1, 7, 30, 365, 0])
    }

    @Test("Each stop maps to its stored value")
    func exactMatches() {
        #expect(RetentionWindow(days: 1) == .day)
        #expect(RetentionWindow(days: 7) == .week)
        #expect(RetentionWindow(days: 30) == .month)
        #expect(RetentionWindow(days: 365) == .year)
        #expect(RetentionWindow(days: 0) == .forever)
    }

    @Test("A value off the stops has no exact match")
    func noExactMatchForArbitraryValue() {
        #expect(RetentionWindow(days: 45) == nil)
    }

    @Test("An off-stop value is displayed at the closest stop",
          arguments: [(2, RetentionWindow.day), (5, .week), (20, .month),
                      (45, .month), (200, .year), (9000, .year)])
    func nearestStop(value: Int, expected: RetentionWindow) {
        // Display only — nothing is rewritten until the user drags the slider,
        // so an existing 45-day setting isn't silently rounded to 30.
        #expect(RetentionWindow.nearest(toDays: value) == expected)
    }

    @Test("Forever is never the nearest stop for a finite value")
    func foreverIsNotNearestForFiniteValues() {
        // Its stored value is 0, which would otherwise look like the closest
        // stop to any small number.
        #expect(RetentionWindow.nearest(toDays: 1) == .day)
        #expect(RetentionWindow.nearest(toDays: 0) == .forever)
    }
}

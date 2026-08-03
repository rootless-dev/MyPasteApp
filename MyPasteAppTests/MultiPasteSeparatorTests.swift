//
//  MultiPasteSeparatorTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

@Suite("Multi-paste separator")
struct MultiPasteSeparatorTests {
    @Test("Each case carries the text it inserts")
    func textPerCase() {
        #expect(MultiPasteSeparator.newline.text == "\n")
        #expect(MultiPasteSeparator.blankLine.text == "\n\n")
        #expect(MultiPasteSeparator.space.text == " ")
        #expect(MultiPasteSeparator.comma.text == ", ")
    }

    @Test("Every case has a label and they're all distinct")
    func labelsAreDistinct() {
        let labels = MultiPasteSeparator.allCases.map(\.label)
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == labels.count)
    }

    @Test("A stored value round-trips")
    func roundTrips() {
        for separator in MultiPasteSeparator.allCases {
            #expect(MultiPasteSeparator.resolve(separator.rawValue) == separator)
        }
    }

    @Test("Missing or unknown values fall back to a new line")
    func fallsBackToDefault() {
        // The unknown case isn't hypothetical: a rawValue written by a later
        // version and then rolled back lands here, and must not crash or
        // silently produce an empty separator.
        #expect(MultiPasteSeparator.resolve(nil) == .newline)
        #expect(MultiPasteSeparator.resolve("") == .newline)
        #expect(MultiPasteSeparator.resolve("semicolon") == .newline)
    }
}

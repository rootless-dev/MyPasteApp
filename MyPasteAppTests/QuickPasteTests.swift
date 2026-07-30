//
//  QuickPasteTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

@Suite("Quick paste")
struct QuickPasteTests {
    @Test("Digits 1 through 9 map onto zero-based positions", arguments: [
        (Character("1"), 0),
        (Character("2"), 1),
        (Character("5"), 4),
        (Character("9"), 8),
    ])
    func digitsMapToPositions(character: Character, expected: Int) {
        #expect(QuickPaste.index(for: character) == expected)
    }

    @Test("Zero has no card")
    func zeroIsRejected() {
        // ⌘0 must not paste the ninth card, nor crash on index -1.
        #expect(QuickPaste.index(for: "0") == nil)
    }

    @Test("Non-digits are rejected", arguments: [
        Character("a"), Character("-"), Character(" "), Character("½"),
    ])
    func nonDigitsAreRejected(character: Character) {
        #expect(QuickPaste.index(for: character) == nil)
    }

    @Test("The first nine positions get a label", arguments: [
        (0, "⌘1"), (1, "⌘2"), (8, "⌘9"),
    ])
    func labelsForReachablePositions(index: Int, expected: String) {
        #expect(QuickPaste.label(forIndex: index) == expected)
    }

    @Test("Positions past the ninth get no label", arguments: [9, 10, 500])
    func noLabelPastCapacity(index: Int) {
        #expect(QuickPaste.label(forIndex: index) == nil)
    }

    @Test("A negative position gets no label")
    func noLabelForNegative() {
        #expect(QuickPaste.label(forIndex: -1) == nil)
    }

    @Test("index and label agree on every reachable position")
    func indexAndLabelRoundTrip() {
        // Guards the off-by-one that would make ⌘3 paste the card labelled ⌘4.
        for position in 0..<QuickPaste.capacity {
            let label = QuickPaste.label(forIndex: position)
            #expect(label != nil)
            let digit = Character(String(position + 1))
            #expect(QuickPaste.index(for: digit) == position)
        }
    }
}

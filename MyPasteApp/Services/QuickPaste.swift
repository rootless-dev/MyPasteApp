//
//  QuickPaste.swift
//  MyPasteApp
//
//  Maps the ⌘1–⌘9 shortcuts onto visible card positions.
//

import Foundation

enum QuickPaste {
    /// How many cards a numbered shortcut can reach.
    static let capacity = 9

    /// Zero-based position for a pressed digit, or `nil` when the character
    /// isn't one this feature answers to.
    ///
    /// "0" is deliberately excluded: there is no zeroth card, and accepting it
    /// would index at -1.
    static func index(for character: Character) -> Int? {
        guard let digit = character.wholeNumberValue,
              (1...capacity).contains(digit)
        else { return nil }
        return digit - 1
    }

    /// Label for the chip drawn on the card at `index`, or `nil` when the
    /// position is out of reach.
    static func label(forIndex index: Int) -> String? {
        guard (0..<capacity).contains(index) else { return nil }
        return "⌘\(index + 1)"
    }
}

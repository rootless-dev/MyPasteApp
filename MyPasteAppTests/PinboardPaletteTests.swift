//
//  PinboardPaletteTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

/// The palette is a storage format as much as a visual choice: `colorHex` is
/// persisted per pinboard, so changing an entry silently recolours boards that
/// already exist. These tests freeze it, the same way `PreferenceKeysTests`
/// freezes the defaults keys.
@Suite("Pinboard palette")
struct PinboardPaletteTests {
    @Test("Has exactly eight colours")
    func hasEightColours() {
        #expect(PinboardPalette.colors.count == 8)
    }

    @Test("Every colour is six hex digits, with no leading hash")
    func coloursAreSixHexDigits() {
        for hex in PinboardPalette.colors {
            #expect(hex.count == 6)
            #expect(UInt32(hex, radix: 16) != nil)
        }
    }

    @Test("With nothing in use, picks the first colour")
    func firstColourWhenNoneUsed() {
        #expect(PinboardPalette.nextColor(usedBy: []) == PinboardPalette.colors[0])
    }

    @Test("Skips colours already in use")
    func skipsUsedColours() {
        let used = [PinboardPalette.colors[0], PinboardPalette.colors[1]]
        #expect(PinboardPalette.nextColor(usedBy: used) == PinboardPalette.colors[2])
    }

    @Test("Wraps back to the first colour once all eight are taken")
    func wrapsWhenAllUsed() {
        #expect(PinboardPalette.nextColor(usedBy: PinboardPalette.colors)
                == PinboardPalette.colors[0])
    }

    @Test("Matching ignores case")
    func matchingIgnoresCase() {
        // A hex written by hand, or round-tripped through a different code
        // path, can come back lowercased. Treating "ff3b30" as a different
        // colour from "FF3B30" would hand two boards the same colour.
        let used = [PinboardPalette.colors[0].lowercased()]
        #expect(PinboardPalette.nextColor(usedBy: used) == PinboardPalette.colors[1])
    }
}

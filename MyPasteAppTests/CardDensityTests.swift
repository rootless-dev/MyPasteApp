//
//  CardDensityTests.swift
//  MyPasteAppTests
//

// CoreFoundation is what makes CGFloat comparable to an integer literal, and
// SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY requires saying so.
import CoreFoundation
import Testing

@testable import MyPasteApp

@Suite("Card density")
struct CardDensityTests {
    @Test("Every case survives a rawValue round trip")
    func rawValueRoundTrip() {
        for density in CardDensity.allCases {
            #expect(CardDensity(rawValue: density.rawValue) == density)
        }
    }

    @Test("An unknown rawValue decodes to nil so callers fall back to a default")
    func unknownRawValue() {
        // ClipboardCardView relies on this being nil to fall back to
        // .comfortable when the stored preference is stale or hand-edited.
        #expect(CardDensity(rawValue: "gigantic") == nil)
    }

    @Test("Cases are uniquely identifiable, as the Picker needs")
    func uniqueIdentifiers() {
        let ids = Set(CardDensity.allCases.map(\.id))
        #expect(ids.count == CardDensity.allCases.count)
    }

    @Test("Every case has a non-empty label")
    func labels() {
        for density in CardDensity.allCases {
            #expect(!density.label.isEmpty)
        }
    }

    @Test("Sizes grow monotonically from compact to spacious")
    func sizesGrow() {
        #expect(CardDensity.compact.width < CardDensity.comfortable.width)
        #expect(CardDensity.comfortable.width < CardDensity.spacious.width)
        #expect(CardDensity.compact.height < CardDensity.comfortable.height)
        #expect(CardDensity.comfortable.height < CardDensity.spacious.height)
    }

    @Test("Comfortable keeps the card size the app shipped with")
    func comfortableMatchesLegacySize() {
        #expect(CardDensity.comfortable.width == 200)
        #expect(CardDensity.comfortable.height == 220)
    }

    @Test("Cards fit inside the overlay window")
    func cardsFitTheOverlay() {
        // OverlayWindowController.overlayHeight is 320pt and the cards share
        // that space with the search bar and padding. A density taller than
        // the window would silently clip.
        for density in CardDensity.allCases {
            #expect(density.height < 320)
        }
    }
}

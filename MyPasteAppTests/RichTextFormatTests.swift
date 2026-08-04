//
//  RichTextFormatTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing
@testable import MyPasteApp

@Suite("Rich text formatting")
struct RichTextFormatTests {

    private let base = NSAttributedString(
        string: "hello world",
        attributes: [.font: NSFont.systemFont(ofSize: 13)])

    private func isBold(_ text: NSAttributedString, at location: Int) -> Bool {
        guard let font = text.attribute(.font, at: location, effectiveRange: nil) as? NSFont
        else { return false }
        return font.fontDescriptor.symbolicTraits.contains(.bold)
    }

    @Test("bold applies to the selected range only")
    func boldsTheRange() {
        let result = RichText.toggling(.bold, in: base, range: NSRange(location: 0, length: 5))
        #expect(isBold(result, at: 0))
        #expect(!isBold(result, at: 6))
        // The text itself must survive untouched — this is the failure mode
        // that silently destroys an item.
        #expect(result.string == "hello world")
    }

    @Test("bolding twice returns to plain")
    func boldIsAToggle() {
        let once = RichText.toggling(.bold, in: base, range: NSRange(location: 0, length: 5))
        let twice = RichText.toggling(.bold, in: once, range: NSRange(location: 0, length: 5))
        #expect(!isBold(twice, at: 0))
    }

    @Test("a mixed selection becomes uniformly bold")
    func mixedSelectionBecomesBold() {
        // Half bold, half not: the first press should make it all bold, not
        // flip each half independently.
        let half = RichText.toggling(.bold, in: base, range: NSRange(location: 0, length: 5))
        let all = RichText.toggling(.bold, in: half, range: NSRange(location: 0, length: 11))
        #expect(isBold(all, at: 0))
        #expect(isBold(all, at: 6))
    }

    @Test("underline toggles")
    func underlineToggles() {
        let range = NSRange(location: 0, length: 5)
        let on = RichText.togglingUnderline(in: base, range: range)
        #expect(on.attribute(.underlineStyle, at: 0, effectiveRange: nil) != nil)
        let off = RichText.togglingUnderline(in: on, range: range)
        #expect(off.attribute(.underlineStyle, at: 0, effectiveRange: nil) == nil)
    }

    @Test("strikethrough toggles")
    func strikethroughToggles() {
        let range = NSRange(location: 0, length: 5)
        let on = RichText.togglingStrikethrough(in: base, range: range)
        #expect(on.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) != nil)
        let off = RichText.togglingStrikethrough(in: on, range: range)
        #expect(off.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) == nil)
    }

    @Test("clearing formatting keeps the text and drops the attributes")
    func stripsFormatting() {
        let font = NSFont.systemFont(ofSize: 13)
        let bold = RichText.toggling(.bold, in: base, range: NSRange(location: 0, length: 11))
        let underlined = RichText.togglingUnderline(in: bold,
                                                    range: NSRange(location: 0, length: 11))
        let stripped = RichText.stripped(underlined, font: font)

        #expect(stripped.string == "hello world")
        #expect(!isBold(stripped, at: 0))
        #expect(stripped.attribute(.underlineStyle, at: 0, effectiveRange: nil) == nil)
        #expect(stripped.attribute(.font, at: 0, effectiveRange: nil) as? NSFont == font)
    }

    @Test("an empty range changes nothing")
    func emptyRangeIsANoOp() {
        let result = RichText.toggling(.bold, in: base, range: NSRange(location: 3, length: 0))
        #expect(result.isEqual(to: base))
    }

    @Test("a mixed underline selection becomes uniformly underlined")
    func mixedSelectionBecomesUniformlyUnderlined() {
        // Half underlined, half not: the first press should extend underline
        // to the whole range, not remove it because the first character
        // already had it — the same rule bold already follows.
        let half = RichText.togglingUnderline(in: base, range: NSRange(location: 0, length: 5))
        let all = RichText.togglingUnderline(in: half, range: NSRange(location: 0, length: 11))
        #expect(all.attribute(.underlineStyle, at: 0, effectiveRange: nil) != nil)
        #expect(all.attribute(.underlineStyle, at: 6, effectiveRange: nil) != nil)

        let none = RichText.togglingUnderline(in: all, range: NSRange(location: 0, length: 11))
        #expect(none.attribute(.underlineStyle, at: 0, effectiveRange: nil) == nil)
        #expect(none.attribute(.underlineStyle, at: 6, effectiveRange: nil) == nil)
    }

    @Test("a mixed strikethrough selection becomes uniformly struck through")
    func mixedSelectionBecomesUniformlyStruckThrough() {
        let half = RichText.togglingStrikethrough(in: base, range: NSRange(location: 0, length: 5))
        let all = RichText.togglingStrikethrough(in: half, range: NSRange(location: 0, length: 11))
        #expect(all.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) != nil)
        #expect(all.attribute(.strikethroughStyle, at: 6, effectiveRange: nil) != nil)

        let none = RichText.togglingStrikethrough(in: all, range: NSRange(location: 0, length: 11))
        #expect(none.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) == nil)
        #expect(none.attribute(.strikethroughStyle, at: 6, effectiveRange: nil) == nil)
    }

    @Test("a run with an explicit zero underline style counts as not underlined")
    func explicitZeroStyleCountsAsAbsent() {
        // The empty NSUnderlineStyle option set rawValue is 0. A run carrying
        // that value has the attribute key present but styled as "no line" —
        // it must not block the rest of the range from being seen as "not
        // yet styled".
        let withExplicitZero = NSMutableAttributedString(attributedString: base)
        withExplicitZero.addAttribute(.underlineStyle,
                                      value: NSUnderlineStyle([]).rawValue,
                                      range: NSRange(location: 0, length: 11))

        let result = RichText.togglingUnderline(in: withExplicitZero,
                                                 range: NSRange(location: 0, length: 11))
        #expect(result.attribute(.underlineStyle, at: 0, effectiveRange: nil) != nil)
        let style = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        #expect(style == NSUnderlineStyle.single.rawValue)
    }
}

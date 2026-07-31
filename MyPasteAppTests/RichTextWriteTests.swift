//
//  RichTextWriteTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing

@testable import MyPasteApp

@Suite("Rich text — writing")
struct RichTextWriteTests {
    private let rtf = Data("{\\rtf1 hello}".utf8)

    private func payload(plainOnly: Bool,
                         richTextData: Data?,
                         format: RichTextFormat?) -> [(type: NSPasteboard.PasteboardType, data: Data)] {
        RichText.payload(text: "hello",
                         richTextData: richTextData,
                         format: format,
                         plainOnly: plainOnly)
    }

    @Test("Rich first, plain second, when formatting exists")
    func richComesFirst() {
        // Order is what tells the destination app which representation to
        // prefer.
        let result = payload(plainOnly: false, richTextData: rtf, format: .rtf)
        #expect(result.map(\.type) == [.rtf, .string])
    }

    @Test("Plain only when asked for plain")
    func plainOnlyDropsTheRichPart() {
        let result = payload(plainOnly: true, richTextData: rtf, format: .rtf)
        #expect(result.map(\.type) == [.string])
    }

    @Test("Plain only when the item has no formatting")
    func plainItemStaysPlain() {
        let result = payload(plainOnly: false, richTextData: nil, format: nil)
        #expect(result.map(\.type) == [.string])
    }

    @Test("Rich data without a format is ignored")
    func inconsistentItemDegradesToPlain() {
        // Defensive: a half-written row shouldn't produce a pasteboard entry
        // under an unknown type.
        let result = payload(plainOnly: false, richTextData: rtf, format: nil)
        #expect(result.map(\.type) == [.string])
    }

    @Test("Plain text is always present", arguments: [true, false])
    func plainIsAlwaysIncluded(plainOnly: Bool) {
        // A pasteboard carrying only RTF breaks pasting into any plain text
        // field — address bars, terminals, search boxes.
        let result = payload(plainOnly: plainOnly, richTextData: rtf, format: .rtf)
        #expect(result.contains { $0.type == .string })
    }

    @Test("The plain entry carries the text itself")
    func plainEntryHoldsTheText() {
        let result = payload(plainOnly: true, richTextData: nil, format: nil)
        #expect(result.first?.data == Data("hello".utf8))
    }
}

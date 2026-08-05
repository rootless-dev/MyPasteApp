//
//  PasteFlavourTests.swift
//  MyPasteAppTests
//

import AppKit
import Foundation
import SwiftData
import Testing
@testable import MyPasteApp

/// What the paste path actually puts on the pasteboard.
///
/// Written during the Phase 6 manual verification, to settle a report that
/// dragging a formatted item delivered its formatting while clicking it
/// pasted plain text. Both paths read the same fields through
/// `RichText.payload`, so this exercises the real `ClipboardWriter` against a
/// real pasteboard rather than reasoning about it.
@Suite("Paste flavours", .serialized)
@MainActor
struct PasteFlavourTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    /// A text item carrying real RTF, shaped like one the editor saves.
    private func makeFormattedItem(in context: ModelContext) -> ClipboardItem {
        let attributed = NSMutableAttributedString(string: "teste black italico")
        attributed.addAttribute(.font,
                                value: NSFont.boldSystemFont(ofSize: 13),
                                range: NSRange(location: 6, length: 5))
        let rtf = attributed.rtf(from: NSRange(location: 0, length: attributed.length),
                                 documentAttributes: [:])
        let item = ClipboardItem(type: .text,
                                 preview: attributed.string,
                                 contentHash: ClipboardMonitor.hash(attributed.string),
                                 textContent: attributed.string,
                                 richTextData: rtf,
                                 richTextFormat: .rtf)
        context.insert(item)
        return item
    }

    @Test("pasting a formatted item puts RTF on the pasteboard")
    func pasteCarriesRichText() throws {
        let context = try makeContext()
        let item = makeFormattedItem(in: context)
        let monitor = ClipboardMonitor(modelContext: context)
        let writer = ClipboardWriter(monitor: monitor)

        writer.write(item, plainText: false)

        let pb = NSPasteboard.general
        #expect(pb.data(forType: .rtf) != nil,
                "the destination has no formatted flavour to paste")
        #expect(pb.string(forType: .string) == "teste black italico")
        // A destination asking for its preferred flavour must be offered the
        // formatted one, not the plain fallback.
        #expect(pb.availableType(from: [.rtf, .string]) == .rtf)
    }

    @Test("plain-text paste offers no formatted flavour")
    func plainPasteDropsRichText() throws {
        let context = try makeContext()
        let item = makeFormattedItem(in: context)
        let monitor = ClipboardMonitor(modelContext: context)
        let writer = ClipboardWriter(monitor: monitor)

        writer.write(item, plainText: true)

        let pb = NSPasteboard.general
        #expect(pb.data(forType: .rtf) == nil)
        #expect(pb.string(forType: .string) == "teste black italico")
    }

    @Test("the drag payload and the paste path agree on the formatted flavour")
    func dragAndPasteAgree() throws {
        let context = try makeContext()
        let item = makeFormattedItem(in: context)
        let monitor = ClipboardMonitor(modelContext: context)
        let writer = ClipboardWriter(monitor: monitor)

        writer.write(item, plainText: false)
        let pasted = NSPasteboard.general.data(forType: .rtf)

        guard case .text(_, let formatted) = DragPayload.kind(for: item) else {
            Issue.record("expected a text payload")
            return
        }

        #expect(formatted?.format == .rtf)
        #expect(formatted?.data == pasted,
                "drag and paste must hand over the same bytes")
    }
}

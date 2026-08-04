//
//  DragPayloadTests.swift
//  MyPasteAppTests
//

import AppKit
import Foundation
import Testing
@testable import MyPasteApp

@Suite("Drag payload")
@MainActor
struct DragPayloadTests {

    private func textItem(_ text: String) -> ClipboardItem {
        ClipboardItem(type: .text,
                      preview: text,
                      contentHash: ClipboardMonitor.hash(text),
                      textContent: text)
    }

    @Test("text drags as text")
    func textDragsAsText() {
        let kind = DragPayload.kind(for: textItem("hello"))
        guard case .text(let string, let formatted) = kind else {
            Issue.record("expected text, got \(kind)")
            return
        }
        #expect(string == "hello")
        // A plain item has no rich flavour to lose.
        #expect(formatted == nil)
    }

    @Test("formatted text carries its RTF too")
    func richTextDragsBoth() throws {
        let attributed = NSAttributedString(
            string: "hello",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        let rtfData = try #require(try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]))

        let item = textItem("hello")
        item.richTextData = rtfData
        item.richTextFormat = .rtf

        guard case .text(let string, let formatted) = DragPayload.kind(for: item) else {
            Issue.record("expected text")
            return
        }
        // Dragging and pasting must not disagree about what the item is.
        #expect(string == "hello")
        #expect(formatted?.format == .rtf)
        #expect(formatted?.data != nil)
    }

    @Test("an HTML-only capture drags its HTML too, not silently as plain text")
    func htmlTextDragsBoth() throws {
        // A browser copy that never puts RTF on the pasteboard falls back to
        // HTML (RichText.preferredFormat). The drag must not lose that
        // formatting just because it isn't RTF — ⌘V on the same item pastes
        // it, so dragging has to be able to as well.
        let htmlData = try #require("<b>hello</b>".data(using: .utf8))

        let item = textItem("hello")
        item.richTextData = htmlData
        item.richTextFormat = .html

        guard case .text(let string, let formatted) = DragPayload.kind(for: item) else {
            Issue.record("expected text")
            return
        }
        #expect(string == "hello")
        #expect(formatted?.format == .html)
        #expect(formatted?.data == htmlData)
    }

    @Test("a file drags as the urls that still exist")
    func fileDragsExistingURLs() {
        let item = ClipboardItem(type: .file,
                                 preview: "two files",
                                 contentHash: "hash",
                                 fileURLStrings: ["/tmp/here.txt", "/tmp/gone.txt"])
        let kind = DragPayload.kind(for: item, fileExists: { $0 == "/tmp/here.txt" })
        guard case .files(let urls) = kind else {
            Issue.record("expected files, got \(kind)")
            return
        }
        // A path that no longer exists is filtered here rather than discovered
        // by the destination, which would just fail with nothing to show.
        #expect(urls.map(\.path) == ["/tmp/here.txt"])
    }

    @Test("a file item whose paths are all gone drags nothing")
    func fileWithNoExistingPaths() {
        let item = ClipboardItem(type: .file,
                                 preview: "one file",
                                 contentHash: "hash",
                                 fileURLStrings: ["/tmp/gone.txt"])
        #expect(DragPayload.kind(for: item, fileExists: { _ in false }) == .none)
    }

    @Test("an image drags as png bytes plus a name")
    func imageDragsAsFile() throws {
        let data = try #require(ImagePixelTests.quadrantPNG())
        let item = ClipboardItem(type: .image,
                                 preview: "Imagem 2×2",
                                 contentHash: "hash",
                                 imageData: data)
        guard case .image(let png, let name) = DragPayload.kind(for: item) else {
            Issue.record("expected image")
            return
        }
        #expect(png == data)
        #expect(name.hasSuffix(".png"))
    }

    // MARK: - File names

    @Test("the label becomes the file name")
    func labelBecomesName() {
        let name = DragPayload.imageFileName(label: "Logo final", date: .distantPast)
        #expect(name == "Logo final.png")
    }

    @Test("characters a file name can't hold are replaced")
    func sanitisesName() {
        // A slash makes the Finder reject the drop outright, and a colon is
        // still a path separator as far as the file system is concerned.
        let name = DragPayload.imageFileName(label: "before/after: v2", date: .distantPast)
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(name.hasSuffix(".png"))
    }

    @Test("a very long label is cut short")
    func truncatesName() {
        let name = DragPayload.imageFileName(label: String(repeating: "a", count: 300),
                                             date: .distantPast)
        #expect(name.count <= 64)
        #expect(name.hasSuffix(".png"))
    }

    @Test("a label of nothing but punctuation falls back to the date")
    func fallsBackWhenLabelIsUseless() {
        let date = Date(timeIntervalSince1970: 1_770_000_000)
        let fromNil = DragPayload.imageFileName(label: nil, date: date)
        let fromSlashes = DragPayload.imageFileName(label: "///", date: date)
        #expect(fromNil == fromSlashes)
        #expect(fromNil.hasPrefix("Image "))
        #expect(fromNil.hasSuffix(".png"))
    }

    @Test("the fallback name is stable no matter the device's calendar, and honours the injected zone")
    func fallbackNameIsCalendarIndependent() throws {
        // Left unpinned, a device set to a non-Gregorian calendar (Thai
        // Buddhist, Japanese era) would stamp that calendar's year into the
        // name with nothing explaining why. Pinning `timeZone` too (rather
        // than leaving it at the device default) is what makes this
        // assertion reproduce on any CI runner, in any zone: the literal
        // below is the Gregorian, en_US_POSIX, UTC rendering of this
        // timestamp.
        let date = Date(timeIntervalSince1970: 1_770_000_000)
        let utc = try #require(TimeZone(identifier: "UTC"))
        let name = DragPayload.imageFileName(label: nil, date: date, timeZone: utc)
        #expect(name == "Image 2026-02-02 02-40-00.png")

        // Proves the parameter is actually honoured rather than ignored: the
        // same instant, rendered in a zone 14 hours further east, lands on a
        // different local time and therefore a different name.
        let elsewhere = try #require(TimeZone(identifier: "Pacific/Kiritimati"))
        let otherName = DragPayload.imageFileName(label: nil, date: date, timeZone: elsewhere)
        #expect(otherName != name)
    }
}

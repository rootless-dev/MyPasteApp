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
        guard case .text(let string, let rtf) = kind else {
            Issue.record("expected text, got \(kind)")
            return
        }
        #expect(string == "hello")
        #expect(rtf == nil)
    }

    @Test("formatted text carries its formatting too")
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

        guard case .text(let string, let rtf) = DragPayload.kind(for: item) else {
            Issue.record("expected text")
            return
        }
        // Dragging and pasting must not disagree about what the item is.
        #expect(string == "hello")
        #expect(rtf != nil)
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
}

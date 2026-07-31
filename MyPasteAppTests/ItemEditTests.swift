//
//  ItemEditTests.swift
//  MyPasteAppTests
//

import AppKit
import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Item editing")
final class ItemEditTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeItem(text: String) -> ClipboardItem {
        let item = ClipboardItem(
            type: .text,
            preview: text,
            contentHash: ClipboardMonitor.hash(text),
            textContent: text
        )
        container.mainContext.insert(item)
        return item
    }

    @Test("Saving rewrites the plain text")
    func rewritesPlainText() {
        let item = makeItem(text: "before")
        ItemEdit.apply(to: item,
                       attributed: NSAttributedString(string: "after"),
                       label: nil,
                       previewLength: 200)
        #expect(item.textContent == "after")
    }

    @Test("The hash is recomputed from the plain text")
    func recomputesHash() {
        // Without this the edited item collides with the original in
        // deduplication and disappears on the next identical copy.
        let item = makeItem(text: "before")
        ItemEdit.apply(to: item,
                       attributed: NSAttributedString(string: "after"),
                       label: nil,
                       previewLength: 200)
        #expect(item.contentHash == ClipboardMonitor.hash("after"))
    }

    @Test("The preview honours the configured length")
    func previewRespectsLength() {
        // Not a hardcoded 200: the length is a preference, and a card showing
        // the old text while the paste hands over the new one is hard to
        // diagnose later.
        let item = makeItem(text: "before")
        let long = String(repeating: "x", count: 500)
        ItemEdit.apply(to: item,
                       attributed: NSAttributedString(string: long),
                       label: nil,
                       previewLength: 80)
        #expect(item.preview.count == 80)
    }

    @Test("Editing promotes the item to the top")
    func promotesToTop() {
        let item = makeItem(text: "before")
        item.createdAt = .distantPast
        ItemEdit.apply(to: item,
                       attributed: NSAttributedString(string: "after"),
                       label: nil,
                       previewLength: 200)
        #expect(item.createdAt.timeIntervalSinceNow > -5)
    }

    @Test("An empty label is stored as no label")
    func emptyLabelBecomesNil() {
        let item = makeItem(text: "text")
        ItemEdit.apply(to: item,
                       attributed: NSAttributedString(string: "text"),
                       label: "   ",
                       previewLength: 200)
        #expect(item.label == nil)
    }

    @Test("Saving keeps the formatting as RTF")
    func storesRichText() {
        let item = makeItem(text: "before")
        let attributed = NSAttributedString(
            string: "after",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        ItemEdit.apply(to: item,
                       attributed: attributed,
                       label: nil,
                       previewLength: 200)
        #expect(item.richTextData != nil)
        #expect(item.richTextFormat == .rtf)
    }

    // MARK: - applyLabel

    @Test("applyLabel stores the label")
    func applyLabelStoresLabel() {
        let item = makeItem(text: "before")
        ItemEdit.applyLabel(to: item, label: "Deploy key")
        #expect(item.label == "Deploy key")
    }

    @Test("applyLabel normalizes an empty label to nil")
    func applyLabelEmptyBecomesNil() {
        let item = makeItem(text: "before")
        item.label = "old name"
        ItemEdit.applyLabel(to: item, label: "   ")
        #expect(item.label == nil)
    }

    @Test("applyLabel leaves content-derived fields untouched")
    func applyLabelPreservesContent() {
        // This is the test that guards the corruption bug applyLabel exists
        // to prevent: renaming an image or file must never touch the fields
        // that hold its actual identity. A test that only checks the label
        // (like the two above) wouldn't catch a regression here — this one
        // does. If a future refactor folds applyLabel back into apply, this
        // fails instead of silently blanking every image and file that gets
        // renamed.
        let item = makeItem(text: "original text")
        item.richTextData = "rtf-stand-in".data(using: .utf8)
        let originalText = item.textContent
        let originalPreview = item.preview
        let originalHash = item.contentHash
        let originalRichText = item.richTextData

        ItemEdit.applyLabel(to: item, label: "My Image")

        #expect(item.textContent == originalText)
        #expect(item.preview == originalPreview)
        #expect(item.contentHash == originalHash)
        #expect(item.richTextData == originalRichText)
    }

    @Test("applyLabel promotes the item to the top")
    func applyLabelPromotesToTop() {
        let item = makeItem(text: "before")
        item.createdAt = .distantPast
        ItemEdit.applyLabel(to: item, label: "New name")
        #expect(item.createdAt.timeIntervalSinceNow > -5)
    }
}

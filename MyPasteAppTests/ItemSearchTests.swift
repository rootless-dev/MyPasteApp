//
//  ItemSearchTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Item search")
final class ItemSearchTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func item(preview: String, text: String?, label: String?) -> ClipboardItem {
        let item = ClipboardItem(
            type: .text,
            preview: preview,
            contentHash: preview,
            textContent: text
        )
        item.label = label
        container.mainContext.insert(item)
        return item
    }

    @Test("Finds by content")
    func findsByContent() {
        let subject = item(preview: "hello world", text: "hello world", label: nil)
        #expect(OverlayView.matches(item: subject, query: "world"))
    }

    @Test("Finds by label")
    func findsByLabel() {
        // A label that isn't searchable defeats the point of naming an item.
        let subject = item(preview: "xyzzy", text: "xyzzy", label: "Deploy key")
        #expect(OverlayView.matches(item: subject, query: "deploy"))
    }

    @Test("Matching ignores case")
    func caseInsensitive() {
        let subject = item(preview: "xyzzy", text: "xyzzy", label: "Deploy Key")
        #expect(OverlayView.matches(item: subject, query: "DEPLOY"))
    }

    @Test("An unrelated query matches nothing")
    func noFalsePositives() {
        let subject = item(preview: "hello", text: "hello", label: "Greeting")
        #expect(!OverlayView.matches(item: subject, query: "goodbye"))
    }

    @Test("An item with no label is still searchable by content")
    func labelIsOptional() {
        let subject = item(preview: "hello", text: "hello", label: nil)
        #expect(OverlayView.matches(item: subject, query: "hell"))
    }
}

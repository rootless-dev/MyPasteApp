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
    /// Fixed instant every date test is written against. Reading the real
    /// clock here would make the suite fail around midnight.
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func item(preview: String,
                      text: String? = nil,
                      label: String? = nil,
                      ocr: String? = nil,
                      type: ClipboardItemType = .text,
                      app: String? = "com.apple.Safari",
                      createdAt: Date? = nil) -> ClipboardItem {
        let item = ClipboardItem(
            type: type,
            preview: preview,
            contentHash: preview,
            textContent: text,
            sourceAppBundleID: app
        )
        item.label = label
        item.ocrText = ocr
        if let createdAt { item.createdAt = createdAt }
        container.mainContext.insert(item)
        return item
    }

    // MARK: - Text

    @Test("Finds by content")
    func findsByContent() {
        let subject = item(preview: "hello world", text: "hello world")
        #expect(ItemSearch.matches(item: subject, query: "world", now: now))
    }

    @Test("Finds by label")
    func findsByLabel() {
        // A label that isn't searchable defeats the point of naming an item.
        let subject = item(preview: "xyzzy", text: "xyzzy", label: "Deploy key")
        #expect(ItemSearch.matches(item: subject, query: "deploy", now: now))
    }

    @Test("Finds by recognised text inside an image")
    func findsByOCRText() {
        // The whole point of roadmap item 11: a screenshot is a dead end until
        // its text is searchable.
        let subject = item(preview: "Imagem 800×600",
                           ocr: "Invoice #4471 — total R$ 1.280,00", type: .image)
        #expect(ItemSearch.matches(item: subject, query: "4471", now: now))
    }

    @Test("Matching ignores case")
    func caseInsensitive() {
        let subject = item(preview: "xyzzy", text: "xyzzy", label: "Deploy Key")
        #expect(ItemSearch.matches(item: subject, query: "DEPLOY", now: now))
    }

    @Test("Matching ignores diacritics")
    func diacriticInsensitive() {
        // Typing "cao" has to find "cão" — in Portuguese this is the common
        // case, not an edge case.
        let subject = item(preview: "o cão da vizinha", text: "o cão da vizinha")
        #expect(ItemSearch.matches(item: subject, query: "cao", now: now))
    }

    @Test("An unrelated query matches nothing")
    func noFalsePositives() {
        let subject = item(preview: "hello", text: "hello", label: "Greeting")
        #expect(!ItemSearch.matches(item: subject, query: "goodbye", now: now))
    }

    @Test("An item with no label is still searchable by content")
    func labelIsOptional() {
        let subject = item(preview: "hello", text: "hello")
        #expect(ItemSearch.matches(item: subject, query: "hell", now: now))
    }

    // MARK: - Filters

    @Test("An empty filter restricts nothing")
    func emptyFilterMatchesEverything() {
        let subject = item(preview: "hello", type: .image)
        #expect(ItemSearch.matches(item: subject, query: "", filter: SearchFilter(), now: now))
    }

    @Test("Type filter keeps only the chosen types")
    func typeFilter() {
        let image = item(preview: "shot", type: .image)
        let text = item(preview: "note", type: .text)
        let filter = SearchFilter(types: [.image])
        #expect(ItemSearch.matches(item: image, query: "", filter: filter, now: now))
        #expect(!ItemSearch.matches(item: text, query: "", filter: filter, now: now))
    }

    @Test("Two types in one axis are a union")
    func typeFilterIsUnionWithinAxis() {
        let image = item(preview: "shot", type: .image)
        let text = item(preview: "note", type: .text)
        let file = item(preview: "doc.pdf", type: .file)
        let filter = SearchFilter(types: [.image, .text])
        #expect(ItemSearch.matches(item: image, query: "", filter: filter, now: now))
        #expect(ItemSearch.matches(item: text, query: "", filter: filter, now: now))
        #expect(!ItemSearch.matches(item: file, query: "", filter: filter, now: now))
    }

    @Test("Different axes intersect")
    func axesIntersect() {
        let subject = item(preview: "shot", type: .image, app: "com.apple.Safari")
        let matching = SearchFilter(types: [.image], apps: [.bundle("com.apple.Safari")])
        let conflicting = SearchFilter(types: [.image], apps: [.bundle("com.apple.Notes")])
        #expect(ItemSearch.matches(item: subject, query: "", filter: matching, now: now))
        #expect(!ItemSearch.matches(item: subject, query: "", filter: conflicting, now: now))
    }

    @Test("Items with no source app are reachable through the unknown facet")
    func unknownAppFacet() {
        // Without this facet, items created by hand (roadmap item 10) would be
        // invisible whenever any app filter is active.
        let subject = item(preview: "handwritten", app: nil)
        #expect(ItemSearch.matches(item: subject, query: "",
                                   filter: SearchFilter(apps: [.unknown]), now: now))
        #expect(!ItemSearch.matches(item: subject, query: "",
                                    filter: SearchFilter(apps: [.bundle("com.apple.Safari")]),
                                    now: now))
    }

    @Test("Today keeps only items from the current day")
    func todayWindow() {
        let today = item(preview: "today", createdAt: now.addingTimeInterval(-3600))
        let old = item(preview: "old", createdAt: now.addingTimeInterval(-60 * 60 * 48))
        let filter = SearchFilter(dateWindow: .today)
        #expect(ItemSearch.matches(item: today, query: "", filter: filter, now: now))
        #expect(!ItemSearch.matches(item: old, query: "", filter: filter, now: now))
    }

    @Test("The seven-day window includes six days ago and excludes eight")
    func sevenDayWindow() {
        let day = 60.0 * 60 * 24
        let inside = item(preview: "in", createdAt: now.addingTimeInterval(-6 * day))
        let outside = item(preview: "out", createdAt: now.addingTimeInterval(-8 * day))
        let filter = SearchFilter(dateWindow: .last7Days)
        #expect(ItemSearch.matches(item: inside, query: "", filter: filter, now: now))
        #expect(!ItemSearch.matches(item: outside, query: "", filter: filter, now: now))
    }

    @Test("Text and filter must both hold")
    func textAndFilterIntersect() {
        let subject = item(preview: "invoice", ocr: "invoice 4471", type: .image)
        let filter = SearchFilter(types: [.image])
        #expect(ItemSearch.matches(item: subject, query: "4471", filter: filter, now: now))
        #expect(!ItemSearch.matches(item: subject, query: "nothing", filter: filter, now: now))
    }

    // MARK: - Facets

    @Test("Facets come from the history, in canonical order")
    func facetsFromHistory() {
        let items = [
            item(preview: "a", type: .image, app: "com.apple.Safari"),
            item(preview: "b", type: .text, app: "com.apple.Notes"),
            item(preview: "c", type: .text, app: nil),
        ]
        let facets = ItemSearch.facets(in: items)
        // Canonical order, and only the types actually present — a filter for
        // a type nobody has would be a button that always returns nothing.
        #expect(facets.types == [.text, .image])
        #expect(facets.apps == [.bundle("com.apple.Notes"), .bundle("com.apple.Safari"), .unknown])
    }

    @Test("The canonical order lists every type exactly once")
    func canonicalOrderCoversEveryType() {
        // The compiler already forces a new case to be ranked — `canonicalRank`
        // is an exhaustive switch. This is the other half: that the ranked list
        // is complete, so a new case can't be ranked and still be missing from
        // the filter panel and the token list.
        #expect(ClipboardItemType.canonicalOrder.count == ClipboardItemType.allCases.count)
        #expect(Set(ClipboardItemType.canonicalOrder) == Set(ClipboardItemType.allCases))
        #expect(ClipboardItemType.canonicalOrder == [.text, .url, .image, .file])
    }

    @Test("Tokens are listed in the same canonical order as the panel")
    func tokensFollowCanonicalOrder() {
        let filter = SearchFilter(types: [.file, .text, .url])
        #expect(SearchToken.tokens(from: filter) == [.type(.text), .type(.url), .type(.file)])
    }
}

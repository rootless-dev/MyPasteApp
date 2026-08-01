//
//  LinkMetadataRefreshTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

/// Re-copying a URL used to destroy its stored link metadata.
///
/// `insertIfNotDuplicate` returns the persisted item, so a duplicate capture
/// hands `fetchLinkMetadata` the card the user is already looking at — and an
/// offline fetch returns an all-nil `LinkMetadata`. Both halves of the fix live
/// in pure statics so they can be stated here without a network or a window.
@MainActor
@Suite("Link metadata refresh")
struct LinkMetadataRefreshTests {
    private func urlItem(imageData: Data? = nil,
                         faviconData: Data? = nil,
                         backgroundHex: String? = nil,
                         title: String? = nil) -> ClipboardItem {
        ClipboardItem(type: .url,
                      preview: "https://example.com",
                      contentHash: "hash",
                      textContent: "https://example.com",
                      linkTitle: title,
                      linkImageData: imageData,
                      linkFaviconData: faviconData,
                      linkBackgroundHex: backgroundHex)
    }

    // MARK: - Whether to fetch at all

    @Test("A URL with no visual metadata is fetched")
    func bareURLNeedsFetch() {
        #expect(ClipboardMonitor.needsLinkMetadata(urlItem()))
    }

    @Test("A URL that already has a banner is left alone")
    func bannerSkipsFetch() {
        #expect(ClipboardMonitor.needsLinkMetadata(urlItem(imageData: Data([1]))) == false)
    }

    @Test("A URL that already has a favicon is left alone")
    func faviconSkipsFetch() {
        #expect(ClipboardMonitor.needsLinkMetadata(urlItem(faviconData: Data([1]))) == false)
    }

    @Test("Non-URL items are never fetched")
    func nonURLNeedsNothing() {
        let item = ClipboardItem(type: .text, preview: "hello", contentHash: "hash")
        #expect(ClipboardMonitor.needsLinkMetadata(item) == false)
    }

    // MARK: - What a fetch is allowed to overwrite

    @Test("An empty result never erases stored metadata")
    func emptyResultPreservesEverything() {
        // Exactly what `LinkMetadataService.fetch` returns when `downloadHTML`
        // fails: offline, past the 5s timeout, or a non-HTML response.
        let item = urlItem(imageData: Data([1]),
                           faviconData: Data([2]),
                           backgroundHex: "#112233",
                           title: "Invoice")
        ClipboardMonitor.apply(LinkMetadata(), to: item)
        #expect(item.linkImageData == Data([1]))
        #expect(item.linkFaviconData == Data([2]))
        #expect(item.linkBackgroundHex == "#112233")
        #expect(item.linkTitle == "Invoice")
    }

    @Test("A partial result fills only what it found")
    func partialResultFillsOnlyItsOwnFields() {
        let item = urlItem(imageData: Data([1]),
                           faviconData: Data([2]),
                           backgroundHex: "#112233",
                           title: "Invoice")
        ClipboardMonitor.apply(LinkMetadata(title: "Invoice #7", faviconData: Data([9])),
                               to: item)
        #expect(item.linkTitle == "Invoice #7")
        #expect(item.linkFaviconData == Data([9]))
        #expect(item.linkImageData == Data([1]))
        #expect(item.linkBackgroundHex == "#112233")
    }

    @Test("A full result populates an item that had nothing")
    func fullResultPopulatesEmptyItem() {
        let item = urlItem()
        ClipboardMonitor.apply(LinkMetadata(title: "Example",
                                            imageData: Data([1]),
                                            faviconData: Data([2]),
                                            backgroundHex: "#445566"),
                               to: item)
        #expect(item.linkTitle == "Example")
        #expect(item.linkImageData == Data([1]))
        #expect(item.linkFaviconData == Data([2]))
        #expect(item.linkBackgroundHex == "#445566")
    }
}

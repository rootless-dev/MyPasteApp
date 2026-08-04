//
//  ImageEditTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing
@testable import MyPasteApp

@Suite("ImageEdit")
@MainActor
struct ImageEditTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func makeImageItem(data: Data) -> ClipboardItem {
        ClipboardItem(type: .image,
                      preview: "Imagem 2×2",
                      contentHash: ClipboardMonitor.hash(data),
                      imageData: data)
    }

    @Test("applying new bytes rewrites the data, the hash and the preview")
    func rewritesDerivedFields() throws {
        let context = try makeContext()
        let original = try #require(ImageRotationTests.stripePNG(width: 4, height: 2))
        let item = makeImageItem(data: original)
        context.insert(item)

        let rotated = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        ImageEdit.apply(to: item, imageData: rotated)

        #expect(item.imageData == rotated)
        #expect(item.contentHash == ClipboardMonitor.hash(rotated))
        // The preview is the string the card falls back to, and it names the
        // dimensions — which just swapped.
        #expect(item.preview == "Imagem 2×4")
    }

    @Test("the hash actually changes, so deduplication doesn't collide")
    func hashChanges() throws {
        let context = try makeContext()
        let original = try #require(ImageRotationTests.stripePNG(width: 4, height: 2))
        let item = makeImageItem(data: original)
        context.insert(item)
        let before = item.contentHash

        let rotated = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        ImageEdit.apply(to: item, imageData: rotated)

        #expect(item.contentHash != before)
    }

    @Test("editing an image promotes it, like editing text does")
    func promotesTheItem() throws {
        let context = try makeContext()
        let original = try #require(ImagePixelTests.quadrantPNG())
        let item = makeImageItem(data: original)
        item.createdAt = .distantPast
        context.insert(item)

        let rotated = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        ImageEdit.apply(to: item, imageData: rotated)

        #expect(item.createdAt.timeIntervalSinceNow > -5)
        #expect(item.lastUsedAt != nil)
    }

    @Test("the cached thumbnail is dropped")
    func dropsTheThumbnail() async throws {
        let context = try makeContext()
        let original = try #require(ImagePixelTests.quadrantPNG())
        let item = makeImageItem(data: original)
        context.insert(item)

        _ = await ImageThumbnailCache.shared.thumbnail(for: original, id: item.id, maxPixel: 64)
        #expect(ImageThumbnailCache.shared.cached(id: item.id, maxPixel: 64) != nil)

        let rotated = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        ImageEdit.apply(to: item, imageData: rotated)

        #expect(ImageThumbnailCache.shared.cached(id: item.id, maxPixel: 64) == nil)
    }
}

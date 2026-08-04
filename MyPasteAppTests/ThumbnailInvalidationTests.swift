//
//  ThumbnailInvalidationTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing
@testable import MyPasteApp

@Suite("Thumbnail invalidation")
@MainActor
struct ThumbnailInvalidationTests {

    @Test("an invalidated id has no cached thumbnail at any size")
    func invalidateDropsEverySize() async throws {
        // The cache is keyed by (id, maxPixel), and the card and the preview
        // panel ask for different sizes. Dropping only the size you happen to
        // know about leaves the other one drawing the image before the edit.
        let cache = ImageThumbnailCache()
        let data = try #require(ImagePixelTests.quadrantPNG())
        let id = UUID()

        _ = await cache.thumbnail(for: data, id: id, maxPixel: 64)
        _ = await cache.thumbnail(for: data, id: id, maxPixel: 256)
        #expect(cache.cached(id: id, maxPixel: 64) != nil)
        #expect(cache.cached(id: id, maxPixel: 256) != nil)

        cache.invalidate(id: id)

        #expect(cache.cached(id: id, maxPixel: 64) == nil)
        #expect(cache.cached(id: id, maxPixel: 256) == nil)
    }

    @Test("invalidating one id leaves the others alone")
    func invalidateIsScoped() async throws {
        let cache = ImageThumbnailCache()
        let data = try #require(ImagePixelTests.quadrantPNG())
        let kept = UUID()
        let dropped = UUID()

        _ = await cache.thumbnail(for: data, id: kept, maxPixel: 64)
        _ = await cache.thumbnail(for: data, id: dropped, maxPixel: 64)

        cache.invalidate(id: dropped)

        #expect(cache.cached(id: kept, maxPixel: 64) != nil)
        #expect(cache.cached(id: dropped, maxPixel: 64) == nil)
    }
}

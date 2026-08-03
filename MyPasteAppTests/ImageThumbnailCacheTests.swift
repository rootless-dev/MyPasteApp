//
//  ImageThumbnailCacheTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing
@testable import MyPasteApp

struct ImageThumbnailCacheTests {

    private func makePNG(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        )!
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func downsamplesToTheRequestedLongestSide() {
        let data = makePNG(width: 400, height: 200)
        let thumb = ImageThumbnailCache.downsample(data: data, maxPixel: 100)
        #expect(thumb?.width == 100)
        #expect(thumb?.height == 50)
    }

    /// The point of the whole exercise: a card-sized request must not hand
    /// back a screenshot-sized bitmap.
    @Test func largeImageIsNotDecodedAtFullSize() {
        let data = makePNG(width: 3024, height: 1964)
        let thumb = ImageThumbnailCache.downsample(data: data, maxPixel: 520)
        #expect(thumb?.width == 520)
        #expect((thumb?.height ?? 0) < 400)
    }

    /// ImageIO doesn't upscale, and neither should we — asking for a thumbnail
    /// bigger than the source returns the source's own size.
    @Test func smallImageIsNotUpscaled() {
        let data = makePNG(width: 50, height: 50)
        let thumb = ImageThumbnailCache.downsample(data: data, maxPixel: 200)
        #expect(thumb?.width == 50)
        #expect(thumb?.height == 50)
    }

    @Test func garbageDataReturnsNil() {
        let data = Data("not an image".utf8)
        #expect(ImageThumbnailCache.downsample(data: data, maxPixel: 100) == nil)
    }

    @Test func zeroMaxPixelReturnsNil() {
        let data = makePNG(width: 100, height: 100)
        #expect(ImageThumbnailCache.downsample(data: data, maxPixel: 0) == nil)
    }

    @Test func keyDistinguishesSizesOfTheSameItem() {
        let id = UUID()
        #expect(ImageThumbnailCache.key(id: id, maxPixel: 100)
                != ImageThumbnailCache.key(id: id, maxPixel: 200))
    }

    @Test func keyDistinguishesItemsAtTheSameSize() {
        #expect(ImageThumbnailCache.key(id: UUID(), maxPixel: 100)
                != ImageThumbnailCache.key(id: UUID(), maxPixel: 100))
    }

    /// Points in, pixels out: a 260pt card on a 2x display needs 520px.
    ///
    /// The scale is passed in rather than read from `NSScreen`: a test that
    /// reads the display scale from the same place the implementation does
    /// asserts nothing, and would give a different answer on a non-Retina
    /// machine than in CI.
    @Test func pixelsAccountForTheDisplayScale() {
        #expect(ImageThumbnailCache.pixels(for: CGSize(width: 260, height: 180),
                                           scale: 2) == 520)
        #expect(ImageThumbnailCache.pixels(for: CGSize(width: 260, height: 180),
                                           scale: 1) == 260)
    }

    /// The longest side wins regardless of which one it is.
    @Test func pixelsUseTheLongestSide() {
        #expect(ImageThumbnailCache.pixels(for: CGSize(width: 100, height: 400),
                                           scale: 2) == 800)
    }
}

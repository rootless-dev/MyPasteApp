//
//  ImageMetadataTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing
@testable import MyPasteApp

struct ImageMetadataTests {

    /// A PNG of known dimensions, built in-process so the test carries no
    /// fixture file.
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

    @Test func readsDimensionsFromHeader() {
        let data = makePNG(width: 300, height: 200)
        let size = ImageMetadata.pixelSize(of: data)
        #expect(size == CGSize(width: 300, height: 200))
    }

    @Test func nonSquareDimensionsKeepTheirOrder() {
        let data = makePNG(width: 64, height: 512)
        let size = ImageMetadata.pixelSize(of: data)
        #expect(size?.width == 64)
        #expect(size?.height == 512)
    }

    @Test func garbageDataReturnsNil() {
        let data = Data("not an image".utf8)
        #expect(ImageMetadata.pixelSize(of: data) == nil)
    }

    @Test func emptyDataReturnsNil() {
        #expect(ImageMetadata.pixelSize(of: Data()) == nil)
    }
}

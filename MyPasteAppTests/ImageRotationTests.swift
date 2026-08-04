//
//  ImageRotationTests.swift
//  MyPasteAppTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MyPasteApp

@Suite("Image rotation")
struct ImageRotationTests {

    @Test("a quarter turn swaps width and height")
    func swapsDimensions() throws {
        let original = try #require(ImagePixelTests.quadrantPNG())
        let wide = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        let size = try #require(ImageMetadata.pixelSize(of: wide))
        // The fixture is square, so this alone proves nothing — see
        // `rectangularImageSwapsDimensions` below, which is the real check.
        #expect(size == CGSize(width: 2, height: 2))
    }

    @Test("a rectangular image comes back transposed")
    func rectangularImageSwapsDimensions() throws {
        let original = try #require(ImageRotationTests.stripePNG(width: 4, height: 2))
        let turned = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        let size = try #require(ImageMetadata.pixelSize(of: turned))
        #expect(size == CGSize(width: 2, height: 4))
    }

    @Test("one turn clockwise moves the top-left pixel to the top-right")
    func turnsClockwise() throws {
        // The direction is the thing that silently inverts. Red starts at
        // top-left; after one clockwise turn it must be at top-right.
        let original = try #require(ImagePixelTests.quadrantPNG())
        let turned = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        #expect(ImagePixel.color(in: turned, x: 1, y: 0)?.formatted(as: .hex) == "#FF0000")
        #expect(ImagePixel.color(in: turned, x: 1, y: 1)?.formatted(as: .hex) == "#00FF00")
        #expect(ImagePixel.color(in: turned, x: 0, y: 0)?.formatted(as: .hex) == "#0000FF")
        #expect(ImagePixel.color(in: turned, x: 0, y: 1)?.formatted(as: .hex) == "#FFFFFF")
    }

    @Test("a negative turn goes the other way")
    func turnsCounterClockwise() throws {
        let original = try #require(ImagePixelTests.quadrantPNG())
        let turned = try #require(ImageRotation.rotate(original, quarterTurns: -1))
        // Red top-left goes to bottom-left when turning left.
        #expect(ImagePixel.color(in: turned, x: 0, y: 1)?.formatted(as: .hex) == "#FF0000")
    }

    @Test("four turns come back to the original, pixel by pixel")
    func fourTurnsAreIdentity() throws {
        let original = try #require(ImagePixelTests.quadrantPNG())
        var data = original
        for _ in 0..<4 {
            data = try #require(ImageRotation.rotate(data, quarterTurns: 1))
        }
        // Compares pixels, not bytes: re-encoding a PNG is allowed to produce
        // different bytes for the same image, so a data equality check here
        // would fail for a reason that doesn't matter.
        for x in 0..<2 {
            for y in 0..<2 {
                #expect(ImagePixel.color(in: data, x: x, y: y)
                        == ImagePixel.color(in: original, x: x, y: y))
            }
        }
    }

    @Test("zero turns returns the data untouched")
    func zeroTurnsIsANoOp() throws {
        let original = try #require(ImagePixelTests.quadrantPNG())
        #expect(ImageRotation.rotate(original, quarterTurns: 0) == original)
    }

    @Test("turn counts wrap around")
    func wrapsTurnCounts() throws {
        let original = try #require(ImagePixelTests.quadrantPNG())
        let five = try #require(ImageRotation.rotate(original, quarterTurns: 5))
        let one = try #require(ImageRotation.rotate(original, quarterTurns: 1))
        for x in 0..<2 {
            for y in 0..<2 {
                #expect(ImagePixel.color(in: five, x: x, y: y)
                        == ImagePixel.color(in: one, x: x, y: y))
            }
        }
    }

    @Test("data that isn't an image rotates to nothing")
    func notAnImage() {
        #expect(ImageRotation.rotate(Data("not a png".utf8), quarterTurns: 1) == nil)
    }

    /// A PNG whose left half is red and right half is blue, for dimension
    /// checks on non-square images.
    static func stripePNG(width: Int, height: Int) -> Data? {
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        guard let image = context.makeImage() else { return nil }
        return ImageRotation.encodePNG(image)
    }
}

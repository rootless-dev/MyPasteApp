//
//  ImagePixelTests.swift
//  MyPasteAppTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MyPasteApp

@Suite("Image pixel sampling")
struct ImagePixelTests {

    // MARK: - Mapping

    @Test("a click in the centre maps to the centre pixel")
    func centre() throws {
        let pixel = try #require(ImagePixel.pixel(at: CGPoint(x: 100, y: 100),
                                                  viewSize: CGSize(width: 200, height: 200),
                                                  imageSize: CGSize(width: 100, height: 50)))
        #expect(pixel.x == 50)
        #expect(pixel.y == 25)
    }

    @Test("a click in the letterbox maps to nothing")
    func letterbox() {
        // A 100×50 image inside a 200×200 view is drawn at 200×100, leaving
        // 50pt of empty space above and below. A click there is a click on the
        // panel's background, not on a pixel.
        #expect(ImagePixel.pixel(at: CGPoint(x: 100, y: 10),
                                 viewSize: CGSize(width: 200, height: 200),
                                 imageSize: CGSize(width: 100, height: 50)) == nil)
        #expect(ImagePixel.pixel(at: CGPoint(x: 100, y: 190),
                                 viewSize: CGSize(width: 200, height: 200),
                                 imageSize: CGSize(width: 100, height: 50)) == nil)
    }

    @Test("the top-left corner of the drawn image is pixel zero")
    func topLeft() throws {
        let pixel = try #require(ImagePixel.pixel(at: CGPoint(x: 0, y: 50),
                                                  viewSize: CGSize(width: 200, height: 200),
                                                  imageSize: CGSize(width: 100, height: 50)))
        #expect(pixel.x == 0)
        #expect(pixel.y == 0)
    }

    @Test("the last pixel is inside the image, not one past it")
    func bottomRight() throws {
        let pixel = try #require(ImagePixel.pixel(at: CGPoint(x: 199.9, y: 149.9),
                                                  viewSize: CGSize(width: 200, height: 200),
                                                  imageSize: CGSize(width: 100, height: 50)))
        #expect(pixel.x == 99)
        #expect(pixel.y == 49)
    }

    @Test("an image smaller than the view is scaled up, not centred at 1:1")
    func scalesUp() throws {
        let pixel = try #require(ImagePixel.pixel(at: CGPoint(x: 150, y: 150),
                                                  viewSize: CGSize(width: 200, height: 200),
                                                  imageSize: CGSize(width: 10, height: 10)))
        #expect(pixel.x == 7)
        #expect(pixel.y == 7)
    }

    // MARK: - Reading

    @Test("reads the colour of a known pixel, right way up")
    func readsQuadrants() throws {
        // A 2×2 image: red top-left, green top-right, blue bottom-left,
        // white bottom-right. Four different colours in four corners is what
        // makes this catch a flipped or transposed axis — a symmetric test
        // image would pass with the y axis upside down.
        let data = try #require(ImagePixelTests.quadrantPNG())

        #expect(ImagePixel.color(in: data, x: 0, y: 0)?.formatted(as: .hex) == "#FF0000")
        #expect(ImagePixel.color(in: data, x: 1, y: 0)?.formatted(as: .hex) == "#00FF00")
        #expect(ImagePixel.color(in: data, x: 0, y: 1)?.formatted(as: .hex) == "#0000FF")
        #expect(ImagePixel.color(in: data, x: 1, y: 1)?.formatted(as: .hex) == "#FFFFFF")
    }

    @Test("a pixel outside the image reads as nothing")
    func outOfBounds() throws {
        let data = try #require(ImagePixelTests.quadrantPNG())
        #expect(ImagePixel.color(in: data, x: 2, y: 0) == nil)
        #expect(ImagePixel.color(in: data, x: 0, y: -1) == nil)
    }

    @Test("data that isn't an image reads as nothing")
    func notAnImage() {
        #expect(ImagePixel.color(in: Data("not a png".utf8), x: 0, y: 0) == nil)
    }

    // MARK: - Fixture

    /// A 2×2 PNG with one distinct colour per pixel, built without touching
    /// the disk. Shared with `ImageRotationTests`.
    static func quadrantPNG() -> Data? {
        let width = 2, height = 2
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // CGContext's origin is bottom-left, so the "top" row is drawn last.
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))          // bottom-left
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))          // bottom-right
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 1, width: 1, height: 1))          // top-left
        context.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 1, y: 1, width: 1, height: 1))          // top-right

        guard let image = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

//
//  ImageRotation.swift
//  MyPasteApp
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns an image by quarter turns, bytes in and bytes out.
///
/// Always writes PNG, whatever the input was: that's the format
/// `ClipboardMonitor` already stores images in, so a rotated image stays
/// interchangeable with a captured one.
enum ImageRotation {

    /// - Parameter quarterTurns: positive turns clockwise, negative
    ///   anticlockwise. Wraps, so 5 is the same as 1.
    /// - Returns: nil when the data isn't an image ImageIO recognises.
    static func rotate(_ data: Data, quarterTurns: Int) -> Data? {
        let turns = ((quarterTurns % 4) + 4) % 4
        // Zero is not "re-encode with no change": handing back the same bytes
        // keeps the hash, the blob on disk and the cached thumbnail exactly as
        // they were, which is what "the user turned it and turned it back"
        // should mean.
        guard turns != 0 else { return data }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let width = image.width
        let height = image.height
        let swapped = turns % 2 == 1
        let outWidth = swapped ? height : width
        let outHeight = swapped ? width : height

        guard let context = CGContext(data: nil,
                                      width: outWidth,
                                      height: outHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        // Rotate about the centre of the output, then draw the original
        // centred on that same point. CGContext rotates anticlockwise for a
        // positive angle, and its y axis points up — so a clockwise turn on
        // screen is a negative angle here.
        context.translateBy(x: CGFloat(outWidth) / 2, y: CGFloat(outHeight) / 2)
        context.rotate(by: -CGFloat(turns) * .pi / 2)
        context.draw(image, in: CGRect(x: -CGFloat(width) / 2,
                                       y: -CGFloat(height) / 2,
                                       width: CGFloat(width),
                                       height: CGFloat(height)))

        guard let rotated = context.makeImage() else { return nil }
        return encodePNG(rotated)
    }

    /// PNG bytes for a `CGImage`. Internal rather than private: the rotation
    /// tests build their fixtures with it, and a second copy there would be a
    /// second thing to keep in step.
    static func encodePNG(_ image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

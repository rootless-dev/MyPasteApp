//
//  ImagePixel.swift
//  MyPasteApp
//

import CoreGraphics
import Foundation
import ImageIO

/// Reads a single pixel out of a stored image.
///
/// The preview panel draws a *downsampled* thumbnail (see
/// `ImageThumbnailCache`), so sampling what's on screen would return an
/// interpolated value rather than the colour that's actually in the file.
/// Everything here works against the original data; the only thing the view
/// contributes is where the click landed.
enum ImagePixel {

    /// Maps a point in a view to a pixel in the image that view is drawing.
    ///
    /// Assumes aspect-fit — the image scaled to fit and centred, which is what
    /// `ItemPreviewView` does. Returns nil when the point falls in the empty
    /// space beside or above the image: that's a click on the panel, not on a
    /// pixel, and pretending otherwise would copy the colour of the nearest
    /// edge.
    static func pixel(at point: CGPoint,
                      viewSize: CGSize,
                      imageSize: CGSize) -> (x: Int, y: Int)? {
        guard imageSize.width > 0, imageSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else { return nil }

        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let drawnWidth = imageSize.width * scale
        let drawnHeight = imageSize.height * scale
        let originX = (viewSize.width - drawnWidth) / 2
        let originY = (viewSize.height - drawnHeight) / 2

        let x = Int(((point.x - originX) / scale).rounded(.down))
        let y = Int(((point.y - originY) / scale).rounded(.down))

        guard x >= 0, y >= 0,
              x < Int(imageSize.width), y < Int(imageSize.height) else { return nil }
        return (x, y)
    }

    /// The colour of one pixel, in sRGB.
    ///
    /// Draws the image into a 1×1 context positioned so the wanted pixel lands
    /// on it, instead of decoding the whole bitmap and indexing into it: the
    /// image may be a 24 MB screenshot, and this runs on every sample.
    static func color(in data: Data, x: Int, y: Int) -> ColorCode? {
        guard x >= 0, y >= 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              x < image.width, y < image.height
        else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = pixel.withUnsafeMutableBytes({ buffer -> CGContext? in
            CGContext(data: buffer.baseAddress,
                      width: 1,
                      height: 1,
                      bitsPerComponent: 8,
                      bytesPerRow: 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }) else { return nil }

        // CGContext counts rows from the bottom, the image's y counts from the
        // top: row `y` of the image sits at `height - 1 - y` in context space.
        context.draw(image,
                     in: CGRect(x: -x,
                                y: -(image.height - 1 - y),
                                width: image.width,
                                height: image.height))

        let alpha = Double(pixel[3]) / 255
        guard alpha > 0 else {
            return ColorCode(red: 0, green: 0, blue: 0, alpha: 0)
        }
        // The context is premultiplied; undo it so a translucent pixel reports
        // the colour it was authored as rather than a darkened version of it.
        return ColorCode(red: Double(pixel[0]) / 255 / alpha,
                         green: Double(pixel[1]) / 255 / alpha,
                         blue: Double(pixel[2]) / 255 / alpha,
                         alpha: alpha)
    }
}

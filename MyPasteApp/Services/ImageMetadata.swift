//
//  ImageMetadata.swift
//  MyPasteApp
//

import CoreGraphics
import Foundation
import ImageIO

/// Facts about an image that can be read without decoding it.
///
/// The card and the preview panel both show "3024×1964" in their footer, and
/// both used to build a whole `NSImage` to get those two numbers — decoding
/// every pixel of a screenshot to write a caption. `CGImageSource` reads the
/// header only.
enum ImageMetadata {

    /// The image's size in pixels, read from the file header.
    ///
    /// Returns nil when the data isn't an image ImageIO recognises.
    static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double
        else { return nil }
        return CGSize(width: width, height: height)
    }
}

//
//  ImageThumbnailCache.swift
//  MyPasteApp
//

import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// Decodes clipboard images already scaled to the size they'll be drawn at,
/// and keeps a bounded cache of the results.
///
/// The card used to build `NSImage(data:)` inside its `body`, which decodes a
/// screenshot at full resolution — ~24 MB for a 3024×1964 image — to fill a
/// 260×180pt card, and did it again on every re-render. Navigating the history
/// measured +138 MB of ImageIO. `CGImageSourceCreateThumbnailAtIndex` decodes
/// straight to the target size instead: the full-resolution bitmap never
/// exists.
@MainActor
final class ImageThumbnailCache {
    static let shared = ImageThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    /// - Parameter totalCostLimit: bytes of decoded bitmap to keep. 32 MB
    ///   holds a screen's worth of cards comfortably; `NSCache` also evicts on
    ///   its own under memory pressure. Injectable for tests.
    init(totalCostLimit: Int = 32 * 1024 * 1024) {
        cache.totalCostLimit = totalCostLimit
    }

    /// The cached thumbnail, if there is one. Synchronous on purpose: views
    /// call this while building their body so a warm entry draws on the first
    /// frame instead of flashing a placeholder.
    func cached(id: UUID, maxPixel: Int) -> NSImage? {
        cache.object(forKey: Self.key(id: id, maxPixel: maxPixel))
    }

    /// The thumbnail, decoding it off the main thread if it isn't cached yet.
    func thumbnail(for data: Data, id: UUID, maxPixel: Int) async -> NSImage? {
        if let hit = cached(id: id, maxPixel: maxPixel) { return hit }

        // Only the CGImage crosses back to the main actor — NSImage is built
        // here, where it will be used.
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.downsample(data: data, maxPixel: maxPixel)
        }.value
        guard let decoded else { return nil }

        let image = NSImage(cgImage: decoded,
                            size: NSSize(width: decoded.width, height: decoded.height))
        cache.setObject(image,
                        forKey: Self.key(id: id, maxPixel: maxPixel),
                        cost: decoded.bytesPerRow * decoded.height)
        return image
    }

    // MARK: - Pure helpers

    /// Decodes `data` with its longest side capped at `maxPixel`.
    ///
    /// ImageIO never upscales: a source smaller than `maxPixel` comes back at
    /// its own size.
    nonisolated static func downsample(data: Data, maxPixel: Int) -> CGImage? {
        guard maxPixel > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    nonisolated static func key(id: UUID, maxPixel: Int) -> NSString {
        "\(id.uuidString)#\(maxPixel)" as NSString
    }

    /// Longest side of `size`, in points, converted to pixels for this display.
    nonisolated static func pixels(for size: CGSize) -> Int {
        pixels(for: size, scale: NSScreen.main?.backingScaleFactor ?? 2)
    }

    /// The arithmetic on its own, with the display scale as a parameter, so a
    /// test can pin it without depending on the machine it runs on.
    nonisolated static func pixels(for size: CGSize, scale: CGFloat) -> Int {
        Int(max(size.width, size.height) * scale)
    }
}

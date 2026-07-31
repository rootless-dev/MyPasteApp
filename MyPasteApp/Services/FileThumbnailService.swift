//
//  FileThumbnailService.swift
//  MyPasteApp
//

import AppKit
import QuickLookThumbnailing

@MainActor
final class FileThumbnailService {
    static let shared = FileThumbnailService()

    private let cache = NSCache<NSString, NSImage>()

    init() {
        // Same reason as ImageThumbnailCache: an unbounded dictionary of
        // ~2 MB thumbnails is the very problem this phase corrects.
        cache.totalCostLimit = 16 * 1024 * 1024
    }

    func cached(for path: String, size: CGSize) -> NSImage? {
        cache.object(forKey: key(path: path, size: size) as NSString)
    }

    func thumbnail(for path: String, size: CGSize) async -> NSImage? {
        let cacheKey = key(path: path, size: size)
        if let hit = cache.object(forKey: cacheKey as NSString) { return hit }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .all
        )

        do {
            let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let img = rep.nsImage
            // img.size is in points; totalCostLimit bounds bytes of bitmap. On a
            // 2x display a 360x360pt thumbnail backs a 720x720 bitmap (~2 MB),
            // not the ~0.5 MB this would declare without scaling both axes.
            cache.setObject(img, forKey: cacheKey as NSString,
                            cost: Int(img.size.width * scale * img.size.height * scale * 4))
            return img
        } catch {
            let icon = NSWorkspace.shared.icon(forFile: path)
            cache.setObject(icon, forKey: cacheKey as NSString,
                            cost: Int(icon.size.width * scale * icon.size.height * scale * 4))
            return icon
        }
    }

    private func key(path: String, size: CGSize) -> String {
        "\(path)#\(Int(size.width))x\(Int(size.height))"
    }
}

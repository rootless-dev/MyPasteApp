//
//  FileThumbnailService.swift
//  MyPasteApp
//

import AppKit
import QuickLookThumbnailing

@MainActor
final class FileThumbnailService {
    static let shared = FileThumbnailService()

    private var cache: [String: NSImage] = [:]

    func cached(for path: String, size: CGSize) -> NSImage? {
        cache[key(path: path, size: size)]
    }

    func thumbnail(for path: String, size: CGSize) async -> NSImage? {
        let cacheKey = key(path: path, size: size)
        if let hit = cache[cacheKey] { return hit }

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
            cache[cacheKey] = img
            return img
        } catch {
            let icon = NSWorkspace.shared.icon(forFile: path)
            cache[cacheKey] = icon
            return icon
        }
    }

    private func key(path: String, size: CGSize) -> String {
        "\(path)#\(Int(size.width))x\(Int(size.height))"
    }
}

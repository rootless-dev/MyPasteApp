//
//  ThumbnailImage.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// An image from a clipboard item, decoded at the size it's drawn at.
///
/// The one place that knows the cache-then-load dance, so the card, the link
/// banner and the preview panel don't each grow their own copy of it.
struct ThumbnailImage: View {
    let data: Data?
    let id: UUID
    /// Longest side, in pixels. Use `ImageThumbnailCache.pixels(for:)`.
    let maxPixel: Int
    var contentMode: ContentMode = .fit

    @State private var loaded: NSImage?

    /// Prefers the cache over `@State` so a warm entry draws on the very first
    /// frame — `.task` wouldn't have run yet, and the placeholder would flash
    /// on every scroll that recycles this view.
    private var image: NSImage? {
        loaded ?? ImageThumbnailCache.shared.cached(id: id, maxPixel: maxPixel)
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.clear
            }
        }
        .task(id: ImageThumbnailCache.key(id: id, maxPixel: maxPixel)) {
            guard image == nil, let data else { return }
            loaded = await ImageThumbnailCache.shared.thumbnail(
                for: data, id: id, maxPixel: maxPixel
            )
        }
    }
}

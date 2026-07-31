//
//  ThumbnailImage.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// An image from a clipboard item, decoded at the size it's drawn at.
///
/// The one place that knows the cache-then-load dance, so the card, the link
/// banner, the favicon badge and the preview panel don't each grow their own
/// copy of it.
///
/// `fallback` is shown only once a decode has actually been attempted and has
/// failed — never while the load is still in flight, since a placeholder
/// shown during a normal decode would flash before the real thumbnail
/// appears, which is worse than the brief wait. Nesting a `ThumbnailImage`
/// inside another one's `fallback` reproduces a multi-step chain — see
/// `LinkPreviewView`, which falls from banner to favicon to plain text.
struct ThumbnailImage<Fallback: View>: View {
    /// Styling applied to the decoded image only — never to `fallback`,
    /// never to the still-loading state. There are exactly two shapes in the
    /// app: the card, the preview panel and the link banner draw the image
    /// plain; the link favicon adds a fixed 64x64 frame and a shadow.
    ///
    /// This exists as a switch inside `body` rather than as a modifier
    /// applied to `ThumbnailImage` from outside because `body` renders the
    /// decoded image and `fallback()` as alternatives of the same `Group` —
    /// a `.frame`/`.shadow` applied from outside would land on whichever
    /// branch is showing, including `fallback`. That clipped a full-size
    /// `textFallback` into a 64x64 shadowed box whenever a favicon was
    /// present but failed to decode, instead of letting the fallback chain
    /// reach its last link at full size.
    enum Chrome {
        case plain
        case favicon
    }

    let data: Data?
    let id: UUID
    /// Longest side, in pixels. Use `ImageThumbnailCache.pixels(for:)`.
    let maxPixel: Int
    var contentMode: ContentMode = .fit
    var chrome: Chrome = .plain
    @ViewBuilder var fallback: () -> Fallback

    /// The image this view decoded for `currentKey`, held as a strong
    /// reference of its own.
    ///
    /// `NSCache` may evict any entry at any time, with no guarantee about
    /// which — at the 32 MB budget that starts happening after roughly 38
    /// decoded thumbnails, which is routine, not exotic. Without this, the
    /// view's only path to its image was the cache lookup in `image` below;
    /// once evicted, a re-render (e.g. from `ClipboardCardView`'s hover
    /// state) would read nil and go permanently blank, since `.task(id:)`
    /// only re-fires when the key itself changes. The key travels with the
    /// value so a stale image from a previous `maxPixel` (a card density
    /// change, while `item.id` stays the same) is never mistaken for current.
    @State private var loaded: (key: NSString, image: NSImage)?
    /// The key a decode attempt failed for. Distinguishes "still loading"
    /// (show nothing yet) from "decode failed" (show `fallback`), and stops
    /// a doomed decode from being retried on every re-render.
    @State private var failed: NSString?

    private var currentKey: NSString {
        ImageThumbnailCache.key(id: id, maxPixel: maxPixel)
    }

    /// Prefers `loaded` over the cache so a warm entry, once pinned by this
    /// view, survives the cache evicting it later. Falls back to the cache so
    /// a *first* render with a warm cache draws immediately, before `.task`
    /// has had a chance to run.
    private var image: NSImage? {
        if let loaded, loaded.key == currentKey { return loaded.image }
        return ImageThumbnailCache.shared.cached(id: id, maxPixel: maxPixel)
    }

    var body: some View {
        let key = currentKey
        Group {
            if let image {
                let base = Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                switch chrome {
                case .plain:
                    base
                case .favicon:
                    base
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                }
            } else if failed == key {
                fallback()
            } else {
                Color.clear
            }
        }
        .task(id: key) {
            // Guarding on `loaded` rather than on `image`: a cache hit alone
            // must not be treated as "done" — this view still needs to pin
            // its own strong reference for this key. `thumbnail(for:)` checks
            // the cache itself first, so re-running it on a warm hit is cheap.
            if let loaded, loaded.key == key { return }
            guard let data else { return }
            if let decoded = await ImageThumbnailCache.shared.thumbnail(
                for: data, id: id, maxPixel: maxPixel
            ) {
                loaded = (key, decoded)
            } else {
                failed = key
            }
        }
    }
}

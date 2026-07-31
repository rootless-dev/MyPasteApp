//
//  LinkPreviewView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

struct LinkPreviewView: View {
    let item: ClipboardItem

    // A three-step chain — banner, then favicon, then plain text — exactly
    // what the old `NSImage(data:) != nil` checks fell through to.
    // `ThumbnailImage` only calls its `fallback` once ImageIO has actually
    // failed to decode, not just when the data is missing, so a banner that
    // IS present but is e.g. an HTML error page or an SVG still falls
    // through to the favicon instead of leaving a blank rectangle.
    var body: some View {
        if let data = item.linkImageData {
            ThumbnailImage(data: data, id: item.id,
                           maxPixel: ImageThumbnailCache.pixels(
                               for: CGSize(width: 320, height: 240)),
                           contentMode: .fill) {
                faviconOrText
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else {
            faviconOrText
        }
    }

    @ViewBuilder
    private var faviconOrText: some View {
        if let data = item.linkFaviconData {
            ZStack {
                background
                FaviconBadge(data: data, id: item.id) {
                    textFallback
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            textFallback
        }
    }

    private var textFallback: some View {
        Text(item.preview)
            .font(.system(size: 12))
            .foregroundStyle(.primary)
            .lineLimit(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var background: some View {
        Group {
            if let hex = item.linkBackgroundHex, let color = Color(hex: hex) {
                color
            } else {
                Color.gray.opacity(0.15)
            }
        }
    }
}

/// The 64x64 favicon, shadowed — but only once it has actually decoded.
///
/// `ThumbnailImage` renders its image and its `fallback()` inside the same
/// `Group`, so a `.frame`/`.shadow` applied to the whole thing lands on
/// whichever branch is showing — including the fallback. That clipped the
/// full-card `textFallback` into a 64x64 shadowed box whenever a favicon was
/// present but undecodable, instead of letting the fallback chain reach its
/// last link at full size. Tracking load state here, the same way
/// `ThumbnailImage` does internally, lets each branch carry its own styling.
private struct FaviconBadge<Fallback: View>: View {
    let data: Data
    let id: UUID
    @ViewBuilder var fallback: () -> Fallback

    @State private var loaded: (key: NSString, image: NSImage)?
    @State private var failed: NSString?

    private var maxPixel: Int {
        ImageThumbnailCache.pixels(for: CGSize(width: 64, height: 64))
    }
    private var currentKey: NSString {
        ImageThumbnailCache.key(id: id, maxPixel: maxPixel)
    }
    private var image: NSImage? {
        if let loaded, loaded.key == currentKey { return loaded.image }
        return ImageThumbnailCache.shared.cached(id: id, maxPixel: maxPixel)
    }

    var body: some View {
        let key = currentKey
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            } else if failed == key {
                fallback()
            } else {
                Color.clear
            }
        }
        .task(id: key) {
            if let loaded, loaded.key == key { return }
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

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

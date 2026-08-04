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
            // `item.contentHash` here is the hash of the *URL text*, not of the
            // banner bytes — and that is the right identity for them: link
            // metadata is fetched only when the item has none at all (see
            // `ClipboardMonitor.needsLinkMetadata`), so a banner that exists is
            // never replaced in place. Banner and favicon stay apart in the
            // cache by `maxPixel`, as they always have.
            ThumbnailImage(data: data, id: item.id,
                           contentHash: item.contentHash,
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
                // `.favicon` chrome — see `ThumbnailImage.Chrome` — draws the
                // 64x64 shadowed badge only once decoded; an undecodable
                // favicon still falls through to `textFallback` at full size.
                ThumbnailImage(data: data, id: item.id,
                               contentHash: item.contentHash,
                               maxPixel: ImageThumbnailCache.pixels(
                                   for: CGSize(width: 64, height: 64)),
                               chrome: .favicon) {
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

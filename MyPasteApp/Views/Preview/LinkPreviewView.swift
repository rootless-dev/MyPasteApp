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
                ThumbnailImage(data: data, id: item.id,
                               maxPixel: ImageThumbnailCache.pixels(
                                   for: CGSize(width: 64, height: 64))) {
                    textFallback
                }
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
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

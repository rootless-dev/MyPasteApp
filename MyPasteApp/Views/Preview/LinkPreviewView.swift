//
//  LinkPreviewView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

struct LinkPreviewView: View {
    let item: ClipboardItem

    var body: some View {
        if let data = item.linkImageData, let img = NSImage(data: data) {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if let data = item.linkFaviconData, let img = NSImage(data: data) {
            ZStack {
                background
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text(item.preview)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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

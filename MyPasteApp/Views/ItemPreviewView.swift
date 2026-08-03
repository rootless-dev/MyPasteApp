//
//  ItemPreviewView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// The contents of the preview panel.
///
/// Follows design-refs/03-preview-web.png and 04-preview-imagem.png: a title
/// bar of its own with a circular close button, the type beside it, and the
/// item filling the rest.
struct ItemPreviewView: View {
    let item: ClipboardItem
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 380)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Text(typeLabel)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch item.type {
        case .text, .url:
            // The whole thing, scrollable. This is the limitation the item exists to
            // fix: the card truncates at previewTextLength and eight lines, so long
            // text simply isn't readable in the app.
            TextPreviewView(text: item.textContent ?? "")
        case .image:
            if let data = item.imageData {
                // Scaled to fit the panel rather than shown at natural size in
                // a ScrollView: a 1920x1080 screenshot filled the panel with
                // its top-left corner and made the reader scroll to see any of
                // it. The point of the preview is seeing the whole thing at
                // once — the dimensions in the header say what was given up.
                ThumbnailImage(
                    data: data,
                    id: item.id,
                    maxPixel: ImageThumbnailCache.pixels(for: ItemPreviewPanel.defaultSize)
                ) {
                    Text(item.preview).font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CheckerboardBackground())
                .padding(12)
            } else {
                Text(item.preview).font(.caption)
            }
        case .file:
            if let path = item.fileURLStrings?.first {
                VStack(spacing: 8) {
                    FilePreviewView(path: path)
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(12)
            }
        }
    }

    private var typeLabel: String {
        switch item.type {
        case .text:  return "Texto"
        case .url:   return "URL"
        case .image: return "Imagem"
        case .file:  return "Arquivo"
        }
    }

    private var footnote: String? {
        switch item.type {
        case .text, .url:
            return "\(item.textContent?.count ?? 0) caracteres"
        case .image:
            guard let data = item.imageData,
                  let size = ImageMetadata.pixelSize(of: data) else { return nil }
            return "\(Int(size.width)) × \(Int(size.height))"
        case .file:
            return nil
        }
    }
}

/// The conventional way to show that an image has transparency.
struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 8
            let rows = Int(size.height / square) + 1
            let columns = Int(size.width / square) + 1
            for row in 0..<rows {
                for column in 0..<columns {
                    guard (row + column).isMultiple(of: 2) else { continue }
                    let rect = CGRect(x: CGFloat(column) * square,
                                      y: CGFloat(row) * square,
                                      width: square,
                                      height: square)
                    context.fill(Path(rect), with: .color(.gray.opacity(0.25)))
                }
            }
        }
    }
}

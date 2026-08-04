//
//  ItemPreviewView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI
import VisionKit

/// Which mode the image preview is in.
///
/// One at a time, always: two modes armed over the same image would leave a
/// click on it with two meanings. `.liveText` gets the exclusivity for free
/// from this being one value rather than two booleans.
enum PreviewImageMode {
    case none
    case sampler
    case liveText
}

/// The contents of the preview panel.
///
/// Follows design-refs/03-preview-web.png and 04-preview-imagem.png: a title
/// bar of its own with a circular close button, the type beside it, and the
/// item filling the rest.
struct ItemPreviewView: View {
    let item: ClipboardItem
    let onClose: () -> Void
    /// Copies a sampled colour. Owned by `OverlayWindowController`, which is
    /// what holds the `ClipboardWriter` — this view has no business knowing
    /// about pasteboards.
    var onCopyColor: (ColorCode) -> Void = { _ in }
    /// Opens the item editor. Only offered for images: text and URL already
    /// have ⌘E, and a second path to the same window is a second thing to
    /// keep in step.
    var onEdit: (() -> Void)? = nil

    @State private var mode: PreviewImageMode = .none
    @State private var copiedText: String?

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
            if item.type == .image, let onEdit {
                Button("Edit") { onEdit() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
            }
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
            if let code = item.textContent, let color = ColorCode.parse(code) {
                ColorSwatchView(color: color, code: code)
                    .padding(12)
            } else {
                // The whole thing, scrollable. This is the limitation the item exists to
                // fix: the card truncates at previewTextLength and eight lines, so long
                // text simply isn't readable in the app. Rich text data goes along too,
                // so an item with formatting renders formatted here the same way the
                // editor already shows it — see TextPreviewView.content.
                TextPreviewView(text: item.textContent ?? "",
                                 richTextData: item.richTextData,
                                 richTextFormat: item.richTextFormat)
            }
        case .image:
            if let data = item.imageData {
                // Scaled to fit the panel rather than shown at natural size in
                // a ScrollView: a 1920x1080 screenshot filled the panel with
                // its top-left corner and made the reader scroll to see any of
                // it. The point of the preview is seeing the whole thing at
                // once — the dimensions in the header say what was given up.
                GeometryReader { geometry in
                    Group {
                        if mode == .liveText {
                            // Draws its own image rather than sitting on top of
                            // ThumbnailImage's — see LiveTextOverlay's doc comment
                            // for why that's what keeps the selection boxes aligned.
                            LiveTextOverlay(data: data)
                        } else {
                            ThumbnailImage(
                                data: data,
                                id: item.id,
                                contentHash: item.contentHash,
                                maxPixel: ImageThumbnailCache.pixels(for: ItemPreviewPanel.defaultSize)
                            ) {
                                Text(item.preview).font(.caption)
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(CheckerboardBackground())
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        // `set()`, never `push()`/`pop()`: those two are a
                        // manually balanced global stack, and this view has
                        // no reliable moment to pop — a click that disarms
                        // the mode fires no hover event, and a re-render can
                        // re-enter a session that was already entered.
                        // `set()` owns the cursor for as long as the pointer
                        // keeps moving over this view and needs no matching
                        // call, so nothing can leak out to the rest of the
                        // app.
                        guard case .active = phase, mode == .sampler else { return }
                        NSCursor.crosshair.set()
                    }
                    .onTapGesture { location in
                        sample(at: location, in: geometry.size, data: data)
                    }
                }
                .padding(12)
                .overlay(alignment: .bottomTrailing) { modeButtons }
                .overlay(alignment: .top) { copiedBanner }
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

    // MARK: - Sampling

    /// Turns a click into a colour, then turns the mode off.
    ///
    /// One sample per arming, on purpose: a mode that stays on is a mode the
    /// user forgets is on, and every later click silently replaces the
    /// pasteboard.
    private func sample(at location: CGPoint, in viewSize: CGSize, data: Data) {
        guard mode == .sampler else { return }
        guard let size = ImageMetadata.pixelSize(of: data),
              let pixel = ImagePixel.pixel(at: location, viewSize: viewSize, imageSize: size),
              let color = ImagePixel.color(in: data, x: pixel.x, y: pixel.y)
        else { return }

        onCopyColor(color)
        mode = .none
        show(copied: color.formatted(as: .hex))
    }

    private func show(copied text: String) {
        copiedText = text
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if copiedText == text { copiedText = nil }
        }
    }

    // MARK: - Overlays

    private var modeButtons: some View {
        HStack(spacing: 6) {
            modeButton(systemName: "eyedropper",
                       help: "Sample a colour from this image",
                       isOn: mode == .sampler) {
                mode = mode == .sampler ? .none : .sampler
            }
            if ImageAnalyzer.isSupported {
                modeButton(systemName: "text.viewfinder",
                           help: "Select text in this image",
                           isOn: mode == .liveText) {
                    mode = mode == .liveText ? .none : .liveText
                }
            }
        }
        .padding(18)
    }

    private func modeButton(systemName: String,
                            help: String,
                            isOn: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? .white : .primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(isOn ? Color.accentColor : Color.black.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var copiedBanner: some View {
        if let copiedText {
            Text("Copied \(copiedText)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.7)))
                .foregroundStyle(.white)
                .padding(.top, 18)
                .transition(.opacity)
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

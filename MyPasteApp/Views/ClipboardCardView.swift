//
//  ClipboardCardView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

struct ClipboardCardView: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        let appColor = AppColorExtractor.color(for: item.sourceAppBundleID)

        VStack(spacing: 0) {
            coloredHeader(baseColor: appColor)
            previewArea
        }
        .frame(width: 200, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.black.opacity(0.08),
                              lineWidth: isSelected ? 2.5 : 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
    }

    // MARK: - Header

    private func coloredHeader(baseColor: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(typeLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(relativeTime)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: 52)
        .background(
            LinearGradient(
                colors: [baseColor, baseColor.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .topTrailing) {
            if let bundleID = item.sourceAppBundleID,
               let appIcon = Self.appIcon(for: bundleID) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.30), radius: 4, y: 2)
                    .padding(.trailing, 12)
                    .offset(x:21,y: -3)
            }
        }
        .clipped()
        .zIndex(1)
    }

    // MARK: - Preview area

    @ViewBuilder
    private var previewArea: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            content
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch item.type {
        case .text, .url:
            Text(item.preview)
                .font(.system(size: 12, design: item.type == .text ? .monospaced : .default))
                .foregroundStyle(.primary)
                .lineLimit(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .image:
            if let data = item.imageData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(item.preview).font(.caption)
            }
        case .file:
            VStack(alignment: .center, spacing: 6) {
                if let first = item.fileURLStrings?.first {
                    if Self.isImageFile(first),
                       let img = NSImage(contentsOf: URL(fileURLWithPath: first)) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: first))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                        Text(item.preview)
                            .font(.system(size: 11))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Helpers

    private var typeLabel: String {
        switch item.type {
        case .text: return "Texto"
        case .url:  return "URL"
        case .image: return "Imagem"
        case .file: return "Arquivo"
        }
    }

    private var relativeTime: String {
        item.createdAt.formatted(.relative(presentation: .numeric))
    }

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "tif", "bmp", "webp"
    ]
    private static func isImageFile(_ path: String) -> Bool {
        imageExtensions.contains((path as NSString).pathExtension.lowercased())
    }

    private static var iconCache: [String: NSImage] = [:]
    private static func appIcon(for bundleID: String) -> NSImage? {
        if let cached = iconCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[bundleID] = icon
        return icon
    }
}

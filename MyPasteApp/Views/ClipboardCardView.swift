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
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
        }
        .frame(width: 200, height: 220)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                              lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(typeLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
            if let bundleID = item.sourceAppBundleID,
               let appIcon = Self.appIcon(for: bundleID) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch item.type {
        case .text, .url:
            Text(item.preview)
                .font(.system(size: 12, design: item.type == .text ? .monospaced : .default))
                .foregroundStyle(.primary)
                .lineLimit(10)
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
            VStack(alignment: .leading, spacing: 6) {
                if let first = item.fileURLStrings?.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: first))
                        .resizable()
                        .frame(width: 48, height: 48)
                }
                Text(item.preview)
                    .font(.system(size: 11))
                    .lineLimit(3)
            }
        }
    }

    private var iconName: String {
        switch item.type {
        case .text: return "text.alignleft"
        case .url:  return "link"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    private var typeLabel: String {
        switch item.type {
        case .text: return "TEXTO"
        case .url:  return "URL"
        case .image: return "IMAGEM"
        case .file: return "ARQUIVO"
        }
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

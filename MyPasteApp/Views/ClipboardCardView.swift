//
//  ClipboardCardView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

struct ClipboardCardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    /// Shown when this card is within reach of a ⌘1–⌘9 shortcut.
    var quickPasteLabel: String? = nil
    var onDelete: () -> Void = {}
    @AppStorage(PreferenceKeys.cardDensity) private var densityRaw: String = CardDensity.comfortable.rawValue
    @State private var isHoveringCard = false
    @State private var isHoveringDelete = false

    var body: some View {
        let appColor = AppColorExtractor.color(for: item.sourceAppBundleID)
        let density = CardDensity(rawValue: densityRaw) ?? .comfortable

        VStack(spacing: 0) {
            coloredHeader(baseColor: appColor)
            previewArea
            footer
        }
        .frame(width: density.width, height: density.height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topTrailing) { deleteButton }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.black.opacity(0.08),
                              lineWidth: isSelected ? 2.5 : 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
        .onHover { hovering in
            isHoveringCard = hovering
            if !hovering { isHoveringDelete = false }
        }
    }

    // MARK: - Delete button

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(
                    Circle().fill(isHoveringDelete ? Color.red : Color.black.opacity(0.55))
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(isHoveringDelete ? 0.9 : 0.55),
                                          lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Excluir item do histórico")
        .onHover { isHoveringDelete = $0 }
        .opacity(isHoveringCard ? 1 : 0)
        .allowsHitTesting(isHoveringCard)
        .animation(.easeOut(duration: 0.12), value: isHoveringCard)
        .animation(.easeOut(duration: 0.12), value: isHoveringDelete)
        .padding(6)
        .zIndex(2)
    }

    // MARK: - Header

    private func coloredHeader(baseColor: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if let label = item.label {
                    // Takes over the space of type + relative time rather than
                    // competing with it — see design-refs/13-pinboard-links-uteis.png.
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(typeLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(relativeTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.85))
                }
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
        case .text:
            Text(item.preview)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .url:
            LinkPreviewView(item: item)
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
            if let first = item.fileURLStrings?.first {
                FilePreviewView(path: first)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 0) {
            footerContent
            Spacer(minLength: 0)
            if let quickPasteLabel {
                Text(quickPasteLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                    .accessibilityLabel("Atalho \(quickPasteLabel)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.05))
    }

    @ViewBuilder
    private var footerContent: some View {
        switch item.type {
        case .text:
            Text("\(item.textContent?.count ?? 0) characters")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        case .image:
            if let size = Self.imageDimensions(item.imageData) {
                Text("\(Int(size.width))×\(Int(size.height))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("—").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .file:
            if let path = item.fileURLStrings?.first {
                Text(Self.truncatedPath(path))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        case .url:
            VStack(alignment: .leading, spacing: 1) {
                Text(item.linkTitle ?? Self.hostFallback(item.textContent ?? ""))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(Self.hostFallback(item.textContent ?? ""))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private static func truncatedPath(_ path: String, maxComponents: Int = 3) -> String {
        let comps = (path as NSString).pathComponents.filter { $0 != "/" }
        guard comps.count > maxComponents else { return path }
        return "…/" + comps.suffix(maxComponents).joined(separator: "/")
    }

    private static func hostFallback(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let host = URL(string: trimmed)?.host else { return trimmed }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func imageDimensions(_ data: Data?) -> CGSize? {
        guard let data, let img = NSImage(data: data) else { return nil }
        return img.size
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

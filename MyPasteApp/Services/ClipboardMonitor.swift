//
//  ClipboardMonitor.swift
//  MyPasteApp
//

import AppKit
import CryptoKit
import Foundation
import SwiftData

@MainActor
final class ClipboardMonitor {
    private let modelContext: ModelContext
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    /// Quando true, ignora a próxima mudança detectada (usado pelo ClipboardWriter
    /// para não recapturar itens que ele mesmo escreveu de volta).
    var ignoreNextChange = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        guard let item = readCurrentItem() else { return }
        insertIfNotDuplicate(item)
    }

    // MARK: - Reading

    private func readCurrentItem() -> ClipboardItem? {
        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // Prioridade: file URLs > image > URL > string
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let strings = urls.map { $0.path }
            let preview = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) arquivos"
            return ClipboardItem(
                type: .file,
                preview: preview,
                contentHash: Self.hash(strings.joined(separator: "\n")),
                fileURLStrings: strings,
                sourceAppBundleID: sourceApp
            )
        }

        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return ClipboardItem(
                type: .image,
                preview: "Imagem \(Int(image.size.width))×\(Int(image.size.height))",
                contentHash: Self.hash(png),
                imageData: png,
                sourceAppBundleID: sourceApp
            )
        }

        if let str = pasteboard.string(forType: .string) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            let isURL = URL(string: trimmed).map { $0.scheme != nil } ?? false
            return ClipboardItem(
                type: isURL ? .url : .text,
                preview: String(str.prefix(200)),
                contentHash: Self.hash(str),
                textContent: str,
                sourceAppBundleID: sourceApp
            )
        }

        return nil
    }

    // MARK: - Persist

    private func insertIfNotDuplicate(_ item: ClipboardItem) {
        let hash = item.contentHash
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.contentHash == hash },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.createdAt = .now
            return
        }

        modelContext.insert(item)
        try? modelContext.save()
    }

    // MARK: - Hash helpers

    static func hash(_ string: String) -> String {
        hash(Data(string.utf8))
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

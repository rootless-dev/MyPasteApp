//
//  ClipboardWriter.swift
//  MyPasteApp
//

import AppKit
import Foundation
import SwiftData

@MainActor
final class ClipboardWriter {
    private weak var monitor: ClipboardMonitor?

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
    }

    /// Writes the item to the pasteboard.
    ///
    /// `plainText` drops any formatting for this paste only; the item keeps
    /// what it captured. The caller resolves it from the preference and the ⇧
    /// modifier together.
    func write(_ item: ClipboardItem, plainText: Bool = false) {
        let pb = NSPasteboard.general
        monitor?.ignoreNextChange = true
        pb.clearContents()

        item.createdAt = .now
        item.lastUsedAt = .now
        try? item.modelContext?.save()

        switch item.type {
        case .text, .url:
            guard let text = item.textContent else { break }
            for entry in RichText.payload(text: text,
                                          richTextData: item.richTextData,
                                          format: item.richTextFormat,
                                          plainOnly: plainText) {
                pb.setData(entry.data, forType: entry.type)
            }
        case .image:
            if let data = item.imageData, let img = NSImage(data: data) {
                pb.writeObjects([img])
            }
        case .file:
            if let strings = item.fileURLStrings {
                let urls = strings.map { URL(fileURLWithPath: $0) as NSURL }
                pb.writeObjects(urls)
            }
        }
    }
}

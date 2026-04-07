//
//  ClipboardWriter.swift
//  MyPasteApp
//

import AppKit
import Foundation

@MainActor
final class ClipboardWriter {
    private weak var monitor: ClipboardMonitor?

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
    }

    func write(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        monitor?.ignoreNextChange = true
        pb.clearContents()

        switch item.type {
        case .text, .url:
            if let text = item.textContent {
                pb.setString(text, forType: .string)
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

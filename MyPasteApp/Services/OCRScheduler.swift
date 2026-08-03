//
//  OCRScheduler.swift
//  MyPasteApp
//

import Foundation

/// Decides whether an item is worth handing to `OCRQueue`.
///
/// Deliberately does **not** look at `imageData`. That field is
/// `.externalStorage`: merely touching it loads the bytes off disk, and
/// deciding whether it's worth looking at an image can't cost loading the
/// image. An `.image` item with no bytes is handled by the queue, which marks
/// it processed and moves on.
enum OCRScheduler {
    static func needsOCR(type: ClipboardItemType,
                         ocrProcessedAt: Date?,
                         enabled: Bool) -> Bool {
        guard enabled else { return false }
        guard type == .image else { return false }
        return ocrProcessedAt == nil
    }
}

//
//  ClipboardItem.swift
//  MyPasteApp
//

import Foundation
import SwiftData

enum ClipboardItemType: String, Codable {
    case text
    case url
    case image
    case file
}

@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var lastUsedAt: Date?
    var typeRaw: String
    var preview: String
    var textContent: String?
    /// The formatted representation of a text item, when the source app
    /// offered one. Kept out of the store like `imageData`, since RTF from a
    /// long document isn't small.
    @Attribute(.externalStorage) var richTextData: Data?
    /// Which format `richTextData` holds. See `RichTextFormat`.
    var richTextTypeRaw: String?
    @Attribute(.externalStorage) var imageData: Data?
    var fileURLStrings: [String]?
    var linkTitle: String?
    @Attribute(.externalStorage) var linkImageData: Data?
    @Attribute(.externalStorage) var linkFaviconData: Data?
    var linkBackgroundHex: String?
    var sourceAppBundleID: String?
    var isPinned: Bool
    /// Hash of the raw content, used for deduplication.
    var contentHash: String
    /// A user-given name for the item. Only written by `ItemEdit.apply` for
    /// now — the card and search UI arrive in Task 17.
    var label: String?
    /// Text recognised inside an image, filled in asynchronously by
    /// `OCRQueue`. Never part of `contentHash` or `preview` — see Task 2.
    var ocrText: String?
    /// When this item was last put through OCR, whatever the result.
    ///
    /// Separate from `ocrText` on purpose: a nil `ocrText` can't tell "there
    /// was no text in this image" apart from "nobody has looked yet", and
    /// without that distinction every image without text would be reprocessed
    /// on every launch, forever.
    var ocrProcessedAt: Date?

    var type: ClipboardItemType {
        get { ClipboardItemType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    var richTextFormat: RichTextFormat? {
        get { richTextTypeRaw.flatMap(RichTextFormat.init(rawValue:)) }
        set { richTextTypeRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        type: ClipboardItemType,
        preview: String,
        contentHash: String,
        textContent: String? = nil,
        richTextData: Data? = nil,
        richTextFormat: RichTextFormat? = nil,
        imageData: Data? = nil,
        fileURLStrings: [String]? = nil,
        linkTitle: String? = nil,
        linkImageData: Data? = nil,
        linkFaviconData: Data? = nil,
        linkBackgroundHex: String? = nil,
        sourceAppBundleID: String? = nil,
        isPinned: Bool = false,
        label: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.typeRaw = type.rawValue
        self.preview = preview
        self.contentHash = contentHash
        self.textContent = textContent
        self.richTextData = richTextData
        self.richTextTypeRaw = richTextFormat?.rawValue
        self.imageData = imageData
        self.fileURLStrings = fileURLStrings
        self.linkTitle = linkTitle
        self.linkImageData = linkImageData
        self.linkFaviconData = linkFaviconData
        self.linkBackgroundHex = linkBackgroundHex
        self.sourceAppBundleID = sourceAppBundleID
        self.isPinned = isPinned
        self.label = label
    }
}

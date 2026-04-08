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

    var type: ClipboardItemType {
        get { ClipboardItemType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        type: ClipboardItemType,
        preview: String,
        contentHash: String,
        textContent: String? = nil,
        imageData: Data? = nil,
        fileURLStrings: [String]? = nil,
        linkTitle: String? = nil,
        linkImageData: Data? = nil,
        linkFaviconData: Data? = nil,
        linkBackgroundHex: String? = nil,
        sourceAppBundleID: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.typeRaw = type.rawValue
        self.preview = preview
        self.contentHash = contentHash
        self.textContent = textContent
        self.imageData = imageData
        self.fileURLStrings = fileURLStrings
        self.linkTitle = linkTitle
        self.linkImageData = linkImageData
        self.linkFaviconData = linkFaviconData
        self.linkBackgroundHex = linkBackgroundHex
        self.sourceAppBundleID = sourceAppBundleID
        self.isPinned = isPinned
    }
}

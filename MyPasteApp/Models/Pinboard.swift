//
//  Pinboard.swift
//  MyPasteApp
//

import Foundation
import SwiftData

/// A named, coloured collection of history items.
///
/// Distinct from `ClipboardItem.isPinned`, which stays exactly as it was:
/// pinning is "favourite this quickly" (⌘P, sorted first, spared by the
/// pruner) and a pinboard is "file this under a theme". Phase 5 deliberately
/// kept the two rather than migrating one into the other — see the phase spec.
///
/// The delete rule is the whole promise of the feature: removing a board
/// releases its items back into the history, and never deletes them.
@Model
final class Pinboard {
    @Attribute(.unique) var id: UUID
    var name: String
    /// One of `PinboardPalette.colors`, without a leading "#".
    var colorHex: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ClipboardItem.pinboard)
    var items: [ClipboardItem] = []

    init(id: UUID = UUID(),
         name: String,
         colorHex: String,
         createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    /// The name shown when the user never typed one.
    static let untitledName = "Untitled"
}

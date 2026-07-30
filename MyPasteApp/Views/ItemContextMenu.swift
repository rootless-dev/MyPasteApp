//
//  ItemContextMenu.swift
//  MyPasteApp
//

import SwiftUI

/// The right-click menu of a card.
///
/// Presentation only — the behaviour lives in `ItemActions`. The shortcut shown
/// next to each entry is how the user discovers it; an entry whose shortcut
/// doesn't actually work is worse than no entry at all, so nothing is listed
/// here before it works.
///
/// `⌘O Open` belongs above the paste group and arrives with roadmap item 21.
struct ItemContextMenu: View {
    let item: ClipboardItem
    let actions: ItemActions
    /// Name of the app the paste would land in, when it's known.
    let destinationAppName: String?

    var body: some View {
        Button(pasteTitle) { actions.paste(item, plainText: false) }
        if item.type == .text || item.type == .url {
            Button("Paste as Plain Text") { actions.paste(item, plainText: true) }
        }
        Button("Copy") { actions.copy(item) }

        if item.type == .text || item.type == .url {
            Divider()
            // Image and file items aren't editable as text — task 20 gives
            // images a different kind of editing in Phase 6.
            Button("Edit") { actions.edit(item) }
        }

        Divider()

        Button("Delete") { actions.delete(item) }

        Divider()

        Button(item.isPinned ? "Unpin" : "Pin") { actions.togglePin(item) }
    }

    /// Naming the destination says exactly what will happen; the app is already
    /// known by the time the drawer opens.
    private var pasteTitle: String {
        guard let destinationAppName else { return "Paste" }
        return "Paste in \(destinationAppName)"
    }
}

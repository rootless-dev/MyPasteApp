//
//  ItemContextMenu.swift
//  MyPasteApp
//

import AppKit
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

    @AppStorage(PreferenceKeys.alwaysPastePlainText) private var alwaysPastePlainText = false

    var body: some View {
        // Resolves "Always paste as plain text" the same way every other
        // paste path does (see `ItemActions.resolvePastePlainText`) — this
        // entry used to hardcode `false`, so turning the preference on still
        // pasted formatting from here, contradicting its own description
        // ("every paste hands over plain text").
        Button(pasteTitle) {
            actions.paste(item, plainText: ItemActions.resolvePastePlainText(
                alwaysPlainText: alwaysPastePlainText,
                shiftHeld: NSEvent.modifierFlags.contains(.shift)
            ))
        }
        if item.type == .text || item.type == .url {
            Button("Paste as Plain Text") { actions.paste(item, plainText: true) }
        }
        // "Copy" deliberately ignores `alwaysPastePlainText`: the preference
        // is scoped to pasting (its own label and description in Settings
        // both say "paste"), and copying the formatted representation to the
        // system pasteboard doesn't hand anything to a destination app the
        // way a paste does. "Paste as Plain Text" above remains the explicit
        // way to get plain text out of this menu.
        Button("Copy") { actions.copy(item) }

        Divider()
        if item.type == .text || item.type == .url {
            // Image and file items aren't editable as text — task 20 gives
            // images a different kind of editing in Phase 6.
            Button("Edit") { actions.edit(item) }
        }
        // Unlike "Edit", renaming applies to every type.
        Button("Rename") { actions.rename(item) }

        Divider()

        Button("Delete") { actions.delete(item) }

        Divider()

        // ␣ matches Finder's Quick Look convention, which this panel is
        // modeled after. The real ␣ trigger over the card list itself is
        // roadmap item 21 — this is just the menu entry, always available.
        Button("Preview") { actions.preview(item) }
            .keyboardShortcut(.space, modifiers: [])
        Button(item.isPinned ? "Unpin" : "Pin") { actions.togglePin(item) }
    }

    /// Naming the destination says exactly what will happen; the app is already
    /// known by the time the drawer opens.
    private var pasteTitle: String {
        guard let destinationAppName else { return "Paste" }
        return "Paste in \(destinationAppName)"
    }
}

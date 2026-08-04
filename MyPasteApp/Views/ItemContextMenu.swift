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
///
/// **Why the shortcut glyphs are plain trailing text, not `.keyboardShortcut`.**
/// `OverlayView` already handles every one of these keys itself
/// (`onKeyPress`), so the menu and the overlay would have two independent
/// paths to the same action. Classic AppKit gives a contextual `NSMenu`
/// (which is what `.contextMenu` builds, as opposed to a menu-bar item) key
/// equivalents that only ever fire while that menu is open and tracking —
/// never through the normal responder chain while it's closed — which would
/// make the two paths mutually exclusive and safe to combine. The `␣`
/// "Preview" entry below already relies on exactly that (it keeps a real
/// `.keyboardShortcut(.space, modifiers: [])` alongside `OverlayView`'s own
/// `onKeyPress(.space)`, shipped and working). But SwiftUI doesn't document
/// that its own `.contextMenu` + `.keyboardShortcut` bridging follows that
/// classic behaviour rather than registering the shortcut more broadly, and
/// this can't be exercised here — no GUI run available in this task. A wrong
/// guess on ⌘E/⌘R/⌘C/⌫/↵/⇧↵ risks a double-fire (e.g. two paste events),
/// which is destructive; a wrong guess on plain trailing text risks nothing
/// worse than an unaligned, non-gray label. So new entries spell out the
/// shortcut as part of the title string instead of wiring one — teaches the
/// combination without touching the responder chain. `␣` is left exactly as
/// it was; this file doesn't touch its existing, already-verified shortcut.
struct ItemContextMenu: View {
    let item: ClipboardItem
    let actions: ItemActions
    /// Name of the app the paste would land in, when it's known.
    let destinationAppName: String?
    /// Whether a search or filter is narrowing the list right now.
    let isSearchNarrowed: Bool
    /// Whether this item is currently marked for a multi-item paste.
    let isMarked: Bool
    let onToggleMark: () -> Void
    /// Deletes the item. Not `actions.delete(item)` directly — `OverlayView`'s
    /// own `delete(_:)` also unmarks the item and hands off `selectedID` to
    /// its neighbour, bookkeeping this view has no notion of and shouldn't.
    let onDelete: () -> Void
    /// Every board, in strip order, for the "Add to Pinboard" submenu.
    let boards: [Pinboard]
    /// Creates a board and files this item into it, without changing the scope.
    let onFileInNewBoard: () -> Void

    @AppStorage(PreferenceKeys.alwaysPastePlainText) private var alwaysPastePlainText = false

    var body: some View {
        // Resolves "Always paste as plain text" the same way every other
        // paste path does (see `ItemActions.resolvePastePlainText`) — this
        // entry used to hardcode `false`, so turning the preference on still
        // pasted formatting from here, contradicting its own description
        // ("every paste hands over plain text").
        Button(titled(pasteTitle, "↵")) {
            actions.paste(item, plainText: ItemActions.resolvePastePlainText(
                alwaysPlainText: alwaysPastePlainText,
                shiftHeld: NSEvent.modifierFlags.contains(.shift)
            ))
        }
        if item.type == .text || item.type == .url {
            Button(titled("Paste as Plain Text", "⇧↵")) { actions.paste(item, plainText: true) }
        }
        // "Copy" deliberately ignores `alwaysPastePlainText`: the preference
        // is scoped to pasting (its own label and description in Settings
        // both say "paste"), and copying the formatted representation to the
        // system pasteboard doesn't hand anything to a destination app the
        // way a paste does. "Paste as Plain Text" above remains the explicit
        // way to get plain text out of this menu. `OverlayView`'s ⌘C handler
        // mirrors this same choice.
        Button(titled("Copy", "⌘C")) { actions.copy(item) }

        if MultiPaste.isMarkable(item.type) {
            // Same trailing-text glyph as every other entry here — see the
            // type-level doc comment for why these aren't `.keyboardShortcut`.
            Button(titled(isMarked ? "Unmark" : "Mark for Multi-Paste", "⌘M")) {
                onToggleMark()
            }
        }

        Divider()
        if item.type == .text || item.type == .url {
            // Image and file items aren't editable as text — task 20 gives
            // images a different kind of editing in Phase 6.
            Button(titled("Edit", "⌘E")) { actions.edit(item) }
        }
        // Unlike "Edit", renaming applies to every type.
        Button(titled("Rename", "⌘R")) { actions.rename(item) }

        if isSearchNarrowed {
            // Only meaningful while something is hiding the rest of the
            // history — with the full list on screen it would do nothing.
            Button(titled("Show in History", "⌘J")) { actions.jumpToHistory(item) }
        }

        Divider()

        Menu(item.pinboard == nil ? "Add to Pinboard" : "Move to Pinboard") {
            ForEach(boards) { board in
                Button(board.name) { ItemActions.assign(item, to: board) }
            }
            if !boards.isEmpty { Divider() }
            Button("New Pinboard…") { onFileInNewBoard() }
        }

        if item.pinboard != nil {
            Button("Remove from Pinboard") { ItemActions.assign(item, to: nil) }
        }

        Menu(keepTitle) {
            Button(checked("Follow global policy", when: currentRetention == .global)) {
                ItemActions.setRetention(.global, on: item)
            }
            Button(checked("Never expire", when: currentRetention == .forever)) {
                ItemActions.setRetention(.forever, on: item)
            }
            Divider()
            ForEach(RetentionOffer.allCases, id: \.self) { offer in
                Button(offer.title) {
                    ItemActions.setRetention(.until(offer.date(from: .now)), on: item)
                }
            }
        }

        Divider()

        Button(titled("Delete", "⌫")) { onDelete() }

        Divider()

        // ␣ matches Finder's Quick Look convention, which this panel is
        // modeled after. The real ␣ trigger over the card list itself is
        // roadmap item 21 — this is just the menu entry, always available.
        // Unlike every other entry here, this one keeps a real
        // `.keyboardShortcut` — pre-existing, shipped, and left untouched;
        // see the type-level doc comment for why the others don't follow it.
        Button("Preview") { actions.preview(item) }
            .keyboardShortcut(.space, modifiers: [])
        Button(titled(item.isPinned ? "Unpin" : "Pin", "⌘P")) { actions.togglePin(item) }
    }

    /// Naming the destination says exactly what will happen; the app is already
    /// known by the time the drawer opens.
    private var pasteTitle: String {
        guard let destinationAppName else { return "Paste" }
        return "Paste in \(destinationAppName)"
    }

    /// Appends a shortcut glyph to a menu entry's title as plain text.
    ///
    /// Not `.keyboardShortcut` — see the type-level doc comment. This is
    /// display only: it teaches the combination without registering it, so
    /// it can never double-fire alongside `OverlayView`'s `onKeyPress`
    /// handler for the same key.
    private func titled(_ title: String, _ shortcut: String) -> String {
        "\(title)    \(shortcut)"
    }

    private var currentRetention: ItemRetention {
        ItemRetention.of(keepForever: item.keepForever, expiresAt: item.expiresAt)
    }

    /// Names the current state on the parent entry, so the menu can be read as
    /// an answer to "what happens to this item?" without opening the submenu.
    /// A duration chosen yesterday says nothing today, which is why the date
    /// is resolved rather than echoed back as "in 1 hour".
    private var keepTitle: String {
        switch currentRetention {
        case .global: return "Keep"
        case .forever: return "Keep — never expires"
        case .until(let date):
            let formatted = date.formatted(date: .abbreviated, time: .shortened)
            return "Keep — expires \(formatted)"
        }
    }

    /// A leading checkmark as plain text, for the same reason the shortcut
    /// glyphs here are plain text — see the type-level doc comment.
    private func checked(_ title: String, when isCurrent: Bool) -> String {
        isCurrent ? "✓ \(title)" : "   \(title)"
    }
}

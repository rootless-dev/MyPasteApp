//
//  PinboardContextMenu.swift
//  MyPasteApp
//

import SwiftUI

/// The right-click menu of a pinboard pill: rename, delete, recolour.
///
/// **No confirmation dialog, deliberately.** `OverlayWindowController`
/// dismisses the drawer on `windowDidResignKey`, so an `NSAlert` — which
/// becomes key — would close the overlay out from under the user, taking the
/// search, the marks and the scope with it. The consequence goes in the label
/// instead, which is honest because `.nullify` really does hand the items
/// back rather than delete them.
struct PinboardContextMenu: View {
    let board: Pinboard
    let actions: PinboardActions
    /// Puts the pill into inline rename — the same path the `+` button uses.
    let onRename: () -> Void
    /// Lets the caller drop the scope if the deleted board was the active one.
    let onDeleted: () -> Void

    var body: some View {
        Button("Rename") { onRename() }

        Button(deleteTitle) {
            actions.delete(board)
            onDeleted()
        }

        Divider()

        ForEach(PinboardPalette.colors, id: \.self) { hex in
            Button {
                actions.recolor(board, to: hex)
            } label: {
                // A swatch and its name: a colour-only row is unusable to
                // anyone who can't tell these eight apart, and SwiftUI menus
                // don't render a bare shape reliably anyway.
                Label {
                    Text(colorName(hex))
                } icon: {
                    Image(systemName: board.colorHex == hex
                          ? "largecircle.fill.circle" : "circle.fill")
                        .foregroundStyle(Color(hex: hex) ?? .gray)
                }
            }
        }
    }

    private var deleteTitle: String {
        let count = board.items.count
        guard count > 0 else { return "Delete" }
        return count == 1
            ? "Delete — 1 item returns to the history"
            : "Delete — \(count) items return to the history"
    }

    /// Index-based, so the names track `PinboardPalette.colors` by position
    /// rather than by a second hardcoded mapping of hex to word.
    private func colorName(_ hex: String) -> String {
        let names = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Grey"]
        guard let index = PinboardPalette.colors.firstIndex(of: hex),
              index < names.count else { return "Colour" }
        return names[index]
    }
}

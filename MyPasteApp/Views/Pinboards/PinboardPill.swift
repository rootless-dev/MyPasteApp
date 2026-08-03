//
//  PinboardPill.swift
//  MyPasteApp
//

import SwiftUI

/// One entry in the scope strip: the history, or a pinboard.
///
/// Collapses to just its dot or glyph while the search is open — the strip and
/// the search field share the same horizontal band, and this is how the
/// reference resolves the conflict (`design-refs/12-busca-ativa.png`): nothing
/// disappears, it only loses its label.
struct PinboardPill: View {
    let title: String
    /// nil means the history pill, which shows a clock instead of a dot.
    let colorHex: String?
    let isSelected: Bool
    let isCollapsed: Bool
    /// Where the drawer's keyboard is pointed, so the rename field can hand it
    /// back on the way out. Same contract as `SearchFieldView` — see the
    /// `onDisappear` below.
    @FocusState.Binding var focusTarget: OverlayFocusTarget?
    let action: () -> Void
    /// While true, the pill shows a text field instead of its label.
    var isEditing: Bool = false
    var onCommitName: (String) -> Void = { _ in }

    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                marker
                if isEditing {
                    TextField("", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 90)
                        .focused($isFieldFocused)
                        .onSubmit { onCommitName(draft) }
                        .onAppear {
                            draft = title
                            isFieldFocused = true
                        }
                        // Escape leaves the field without renaming. The board
                        // stays exactly as it was — cancelling a rename must
                        // never delete a board that was just created.
                        .onExitCommand { onCommitName(title) }
                        // Gives the keyboard back on the way out, and this is
                        // load-bearing for exactly the reason it is on
                        // `SearchFieldView`'s field: this `TextField` leaving
                        // the tree takes the focus with it, and SwiftUI does
                        // not re-home focus on its own. Measured without it,
                        // committing a name with `↵` left the drawer deaf —
                        // `⎋` didn't close it, `←`/`→` didn't move the
                        // selection, `⌘1`–`⌘9` pasted nothing — until a click
                        // landed on a card. Phase 1's bug verbatim, through a
                        // second door. `onDisappear` runs after the removal,
                        // which is what makes the write stick; the same write
                        // from `onSubmit`, in the turn of the removal itself,
                        // is the one that gets dropped.
                        .onDisappear { focusTarget = .list }
                } else if !isCollapsed {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 120, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, isCollapsed ? 8 : 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.primary.opacity(isSelected ? 0.15 : 0.06))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    @ViewBuilder
    private var marker: some View {
        if let colorHex {
            Circle()
                .fill(Color(hex: colorHex) ?? .gray)
                .frame(width: 8, height: 8)
        } else {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .medium))
        }
    }
}

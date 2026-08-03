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
                        // Gives the keyboard back on the way out. Same
                        // mechanism as `SearchFieldView`'s field, which
                        // carries this line for the same reason: a `TextField`
                        // leaving the tree takes the focus with it, and
                        // SwiftUI does not re-home focus on its own — the
                        // drawer then answers nothing until a click lands on a
                        // card, which is Phase 1's bug.
                        //
                        // **Not measured here.** That failure was measured on
                        // the search field (see the comment on
                        // `SearchFieldView`'s `.onDisappear`), and this field
                        // is removed by the same kind of event — committing
                        // with `↵`, cancelling with `⎋`, or the drawer
                        // reopening. Whether it actually reproduced on this
                        // pill is unverified: nothing in `Views/` has a test,
                        // and steps B9 and B10 of `VERIFICACAO-FASE-5.md` are
                        // what will exercise it.
                        //
                        // `onDisappear` rather than a write from `onSubmit`
                        // for the same reason given there: it runs after the
                        // removal, so the write survives it. That is a reading
                        // of documented SwiftUI ordering plus the measurement
                        // on the search field — it was not re-measured on this
                        // view.
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

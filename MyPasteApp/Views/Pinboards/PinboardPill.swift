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
    /// Where the drawer's keyboard is pointed. The rename field tags itself
    /// `.boardName` on this, the drawer's one focus system, and hands the
    /// keyboard back to `.list` on the way out.
    ///
    /// It used to drive a private `@FocusState` of its own instead, and the
    /// two systems did not merge: this one stayed at `.list` while the pill
    /// believed its field had the keyboard, so the letters typed into a new
    /// board's name reached `OverlayView`'s handlers and opened the search.
    /// See the note on `OverlayFocusTarget`.
    @FocusState.Binding var focusTarget: OverlayFocusTarget?
    let action: () -> Void
    /// While true, the pill shows a text field instead of its label.
    var isEditing: Bool = false
    var onCommitName: (String) -> Void = { _ in }
    /// Double-clicking the name asks to rename it. The history pill leaves this
    /// at its no-op default: it has no name to change.
    var onBeginRename: () -> Void = {}

    @State private var draft = ""

    var body: some View {
        pill
            // Declared before the single-click gesture so SwiftUI gives the
            // double click first refusal — the other order lets the first
            // click win and the second never arrives. A double click only
            // renames: it deliberately does not also switch scope, so
            // reaching for the name doesn't move the drawer under you.
            .onTapGesture(count: 2) { onBeginRename() }
            .onTapGesture(count: 1) { action() }
            .help(title)
    }

    /// The pill's own drawing, with no gesture attached.
    ///
    /// Was a `Button` until the double click arrived: a `Button` swallows the
    /// click before any `onTapGesture` can count it, so telling one click from
    /// two is impossible while it is in the way.
    private var pill: some View {
            HStack(spacing: 6) {
                marker
                if isEditing {
                    TextField("", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 90)
                        // The tag goes on the field itself, never on a
                        // container that merely holds it — the same rule
                        // `SearchFieldView` follows, and for the same reason:
                        // a `@FocusState` written to a value no view in the
                        // tree claims is dropped and reverts.
                        .focused($focusTarget, equals: .boardName)
                        .onSubmit { onCommitName(draft) }
                        .onAppear {
                            draft = title
                            focusTarget = .boardName
                        }
                        // Losing focus commits, the way renaming does in
                        // Finder. Without this the field had no way out other
                        // than ↵ or ⎋: clicking anywhere else left it open,
                        // and since the pill keeps showing a text field where
                        // its name should be, the next click on that pill
                        // looked like the click had *started* an edit.
                        //
                        // Committing rather than cancelling because the text
                        // is already typed and visible — dropping it on a
                        // stray click would discard work the user can see.
                        // Only this pill carries the modifier — it lives inside
                        // `if isEditing`, and `PinboardScope.renamingBoardID`
                        // is a single optional, so no second pill is ever
                        // watching the same transition.
                        .onChange(of: focusTarget) { _, target in
                            guard target != .boardName else { return }
                            onCommitName(draft)
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

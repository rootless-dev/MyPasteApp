//
//  OverlayTopBar.swift
//  MyPasteApp
//

import SwiftUI

/// The strip above the cards, in its two states.
///
/// At rest it's just the magnifier, as in the Paste reference
/// (`design-refs/01-barra-principal.png`); searching, it becomes a wide field
/// (`12-busca-ativa.png`). The `PinboardBar` scope strip sits to the right in
/// both states, collapsing to markers only while the search field is open.
struct OverlayTopBar: View {
    @Bindable var state: SearchState
    /// Passed in rather than declared here, and forwarded to the two views
    /// that own a text field: `SearchFieldView`, which puts `.focused` on the
    /// `SearchTextField` itself, and `PinboardBar`, whose pills hold the
    /// inline rename field. Applying it to a container that merely *contains*
    /// a field doesn't move the keyboard into it — and for the search field
    /// the tag is what gives `focusTarget = .search` somewhere to land at all.
    /// The rename field never takes the tag; it only hands the keyboard back
    /// to `.list` when it leaves.
    @FocusState.Binding var focusTarget: OverlayFocusTarget?
    var onActivate: () -> Void
    var onOpenFilters: () -> Void
    /// How many items are marked for a multi-item paste, or zero.
    var markedCount: Int = 0
    /// The pinboards to offer as scopes, ordered by creation.
    var boards: [Pinboard] = []
    /// The active scope, or nil for the history.
    var activeScopeID: UUID?
    var onSelectScope: (UUID?) -> Void = { _ in }
    var onCreateBoard: () -> Void = {}
    var boardContextMenu: (Pinboard) -> AnyView = { _ in AnyView(EmptyView()) }
    var editingBoardID: UUID?
    var onCommitBoardName: (Pinboard, String) -> Void = { _, _ in }

    var body: some View {
        HStack(spacing: 12) {
            if state.isActive {
                SearchFieldView(state: state,
                                focusTarget: $focusTarget,
                                onOpenFilters: onOpenFilters)
                    .frame(maxWidth: 470)
                PinboardBar(boards: boards,
                            activeID: activeScopeID,
                            isCollapsed: true,
                            focusTarget: $focusTarget,
                            onSelect: onSelectScope,
                            onCreate: onCreateBoard,
                            contextMenu: boardContextMenu,
                            editingID: editingBoardID,
                            onCommitName: onCommitBoardName)
            } else {
                Button(action: onActivate) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Search history")

                PinboardBar(boards: boards,
                            activeID: activeScopeID,
                            isCollapsed: false,
                            focusTarget: $focusTarget,
                            onSelect: onSelectScope,
                            onCreate: onCreateBoard,
                            contextMenu: boardContextMenu,
                            editingID: editingBoardID,
                            onCommitName: onCommitBoardName)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            // An overlay, not a stack sibling: a `Spacer` here would give this
            // `HStack` a flexible child, making the stack itself greedy along
            // its axis. With no other flexible child today, the stack sizes to
            // its content and this `.frame(maxWidth: .infinity)` centers that
            // content — which is what keeps the magnifier (at rest) and the
            // search field (searching) positioned as the reference design
            // shows them. A `Spacer` sibling would flip that to pinned-left
            // and shift both the instant `markedCount` crossed 0↔1. The
            // overlay sits outside the `HStack`'s own layout entirely, so
            // neither state's content ever moves, marked or not.
            if markedCount > 0 {
                // Marks survive the search by design, so some of them can be
                // off-screen. Without this the user would be assembling a
                // block they can't see — the invisible-state failure the
                // roadmap flags for the pause feature.
                Text("\(markedCount) marked    ↵ paste    ⎋ clear")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor))
                    .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.15), value: state.isActive)
    }
}

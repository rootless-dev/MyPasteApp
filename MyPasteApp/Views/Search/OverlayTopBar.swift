//
//  OverlayTopBar.swift
//  MyPasteApp
//

import SwiftUI

/// The strip above the cards, in its two states.
///
/// At rest it's just the magnifier, as in the Paste reference
/// (`design-refs/01-barra-principal.png`); searching, it becomes a wide field
/// (`12-busca-ativa.png`). The empty stack to the right is where Phase 5's
/// pinboard pills go — reserving it now is what keeps that phase from having
/// to redraw this layout.
struct OverlayTopBar: View {
    @Bindable var state: SearchState
    /// Passed in rather than declared here, and forwarded straight to
    /// `SearchFieldView`, which puts `.focused` on the `SearchTextField`
    /// itself. Applying it to a container that merely *contains* a field
    /// doesn't move the keyboard into it — and for that field the tag is what
    /// gives `focusTarget = .search` somewhere to land at all.
    @FocusState.Binding var focusTarget: OverlayFocusTarget?
    var onActivate: () -> Void
    var onOpenFilters: () -> Void
    /// How many items are marked for a multi-item paste, or zero.
    var markedCount: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            if state.isActive {
                SearchFieldView(state: state,
                                focusTarget: $focusTarget,
                                onOpenFilters: onOpenFilters)
                    .frame(maxWidth: 470)
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

                // Reserved for Phase 5's pinboard pills.
                HStack(spacing: 8) {}
            }

            if markedCount > 0 {
                Spacer(minLength: 8)
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.15), value: state.isActive)
    }
}

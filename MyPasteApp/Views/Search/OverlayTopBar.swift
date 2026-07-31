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
    /// `SearchFieldView`, which puts `.focused` on the `TextField` itself.
    /// Applying it to a container that merely *contains* a field doesn't move
    /// the keyboard into it.
    @FocusState.Binding var focusTarget: OverlayFocusTarget?
    var onActivate: () -> Void
    var onOpenFilters: () -> Void

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
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.15), value: state.isActive)
    }
}

//
//  SearchFieldView.swift
//  MyPasteApp
//

import SwiftUI

/// The wide search field of `12-busca-ativa.png`: magnifier, active filters as
/// tokens, the text, and the filter button.
///
/// Replaces the old full-width `SearchBar`.
struct SearchFieldView: View {
    @Bindable var state: SearchState
    /// Bound to the `TextField` itself, never to a container: `.focused` on a
    /// view that merely *contains* a field does not move the keyboard into it.
    @FocusState.Binding var focusTarget: OverlayFocusTarget?
    var onOpenFilters: () -> Void

    /// How many tokens are drawn before the rest are summarised.
    ///
    /// Measured, not chosen: rendering the field at its real 470pt showed the
    /// `TextField` collapsing to zero width from eight tokens on, and the
    /// capsule overflowing its own frame from nine. `SearchFilter` accepts four
    /// types plus one date plus as many apps as the history happens to contain,
    /// so nothing else caps this. Text search is the field's main job, so the
    /// filters give way first — they have the panel as a home of their own.
    private static let visibleTokenLimit = 3

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            // The full list, not the visible prefix: `⌫` on an empty field
            // still removes the last token of *all* of them, which is what
            // `OverlayView`'s handler reads.
            let tokens = SearchToken.tokens(from: state.filter)
            ForEach(tokens.prefix(Self.visibleTokenLimit)) { token in
                SearchTokenView(token: token) {
                    state.filter = token.removed(from: state.filter)
                }
            }
            if tokens.count > Self.visibleTokenLimit {
                // Opens the panel rather than removing anything: with the rest
                // of the filters hidden behind a counter, the panel becomes the
                // only place they can all be seen and changed.
                Button("+\(tokens.count - Self.visibleTokenLimit)") { onOpenFilters() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .help("Show all active filters")
            }

            TextField("Search", text: $state.text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($focusTarget, equals: .search)

            if !state.text.isEmpty {
                Button { state.text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: onOpenFilters) {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(state.filter.isEmpty ? .secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("Filter by type, app or date")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        // The stroke is the field's only focus affordance, so it has to track
        // focus rather than mere presence. `OverlayView` applies
        // `focusEffectDisabled()` at the root, which suppresses the system
        // ring for everything below it — this field included — and the field
        // can be on screen while the keyboard is on the cards (a click on the
        // drawer chrome, or the turn between `activate` and the deferred focus
        // write). Stroking in accent unconditionally would claim the keyboard
        // in exactly the state where the overlay doesn't have it.
        .background(
            Capsule()
                .fill(.quaternary)
                .overlay(
                    Capsule().stroke(
                        focusTarget == .search
                            ? Color.accentColor
                            : Color.secondary.opacity(0.4),
                        lineWidth: 2
                    )
                )
        )
    }
}

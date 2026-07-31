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
                // Reveals the hidden filters rather than removing anything:
                // once they are behind a counter, the panel is the only place
                // they can all be seen and changed. Strictly this *toggles* the
                // panel, but the click-catcher behind an open panel swallows
                // the press first, so from here it only ever opens.
                Button { onOpenFilters() } label: {
                    // Carries the same capsule as a token: bare accent text
                    // reads as a label, and this is the only route to the
                    // filters it stands for. Sized to match a token's chrome
                    // exactly, which costs the `TextField` ~14pt — measured,
                    // and it still holds its width at the cap of three.
                    Text("+\(tokens.count - Self.visibleTokenLimit)")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor.opacity(0.22)))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
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

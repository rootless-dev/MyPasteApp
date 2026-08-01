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
    /// Bound to the field itself, never to a container: `.focused` on a view
    /// that merely *contains* a field does not move the keyboard into it.
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

            // AppKit-backed, not SwiftUI's `TextField`: focus has to arrive
            // with a caret at the end rather than with the query selected. See
            // `SearchTextField` — the `.focused` tag below is what makes
            // `focusTarget = .search` have somewhere to land.
            SearchTextField(text: $state.text,
                            placeholder: "Search",
                            focusTarget: $focusTarget)
                // A `TextField` is flexible by nature; a representable is only
                // as wide as it says it is, and rendered without this the
                // capsule shrank to fit the text instead of spanning the bar.
                .frame(maxWidth: .infinity)
                .focused($focusTarget, equals: .search)
                // Gives the keyboard back on the way out, and this is
                // load-bearing: closing the search takes an AppKit first
                // responder out of the tree, and SwiftUI does not re-home its
                // own focus when the view holding it was one it did not build.
                // Measured without this: Escape closed the search and the
                // drawer stopped answering `←`, `→`, `↵` — everything —
                // silently, which is Phase 1's bug verbatim. `onDisappear` runs
                // after the removal, which is what makes the write stick; the
                // same write from `closeSearch`, in the turn of the removal
                // itself, is the one that gets dropped.
                .onDisappear { focusTarget = .list }

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
        // The stroke is the field's only focus affordance, so it tracks focus
        // rather than mere presence. `OverlayView` applies
        // `focusEffectDisabled()` at the root, which suppresses the system ring
        // for everything below it — this field included.
        //
        // Measured on this build, `focusTarget` is `.search` for as long as the
        // field is on screen: nothing detaches an AppKit field editor short of
        // removing it, and a posted click on the drawer chrome leaves it in
        // place. So the conditional never picks the secondary colour today. It
        // is written conditionally regardless, because the alternative — an
        // unconditional accent stroke — would be a claim about the keyboard
        // that goes stale the moment anything moves focus off the field, and
        // that is a lie the user cannot see through: a field that looks focused
        // and eats nothing.
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

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

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            ForEach(SearchToken.tokens(from: state.filter)) { token in
                SearchTokenView(token: token) {
                    state.filter = token.removed(from: state.filter)
                }
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
        // The accent stroke is the field's own focus signal. `OverlayView`
        // applies `focusEffectDisabled()` at the root, which suppresses the
        // system focus ring for everything below it — including this field —
        // so relying on the ring would leave the open search looking inert.
        .background(
            Capsule()
                .fill(.quaternary)
                .overlay(Capsule().stroke(Color.accentColor, lineWidth: 2))
        )
    }
}

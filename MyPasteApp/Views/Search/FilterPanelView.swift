//
//  FilterPanelView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// Type, app and date, opened from the button inside the search field.
///
/// Drawn as a layer inside the overlay rather than as a `.popover`: a popover
/// is a new window, and this overlay is `.transient` — it disappears when it
/// loses focus. Phase 2 already paid that bill once, with a whole `NSPanel`
/// and an exception in the click-outside monitor, just to let the preview
/// coexist with the drawer.
struct FilterPanelView: View {
    @Bindable var state: SearchState
    let facets: ItemSearch.Facets

    /// Never taller than the room it is given, and no taller than it needs.
    ///
    /// Measured, not reasoned (see the task-9 report): the drawer is 320pt, of
    /// which the panel gets 258 once the top bar is accounted for — and this
    /// content is 265pt with a *single* app in the list and 685pt with twenty.
    /// The app list comes from the history and has no ceiling, so its height is
    /// not something the layout can assume anything about.
    ///
    /// Left to grow it did not merely spill: an oversized child makes the
    /// enclosing `ZStack` report a height larger than the window, and the
    /// root's `.frame(maxHeight: .infinity)` then *centres* that stack inside
    /// the drawer — dragging the search field and the cards up and off the top
    /// edge along with it.
    ///
    /// `ViewThatFits` rather than a plain `ScrollView`: a `ScrollView` accepts
    /// whatever height is proposed, so a short panel would be as tall as a
    /// twenty-app one with the remainder left as dead space. This takes the
    /// plain stack whenever it fits and only falls back to scrolling when it
    /// genuinely doesn't.
    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView(.vertical) { content }
        }
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            section("Type") {
                ForEach(facets.types, id: \.self) { type in
                    row(label: type.filterLabel,
                        symbol: type.filterSymbol,
                        isOn: state.filter.types.contains(type)) {
                        toggle(type)
                    }
                }
            }

            if !facets.apps.isEmpty {
                Divider()
                section("App") {
                    ForEach(facets.apps, id: \.self) { facet in
                        row(label: AppFacetDisplay.name(for: facet),
                            icon: AppFacetDisplay.icon(for: facet),
                            symbol: "questionmark.app",
                            isOn: state.filter.apps.contains(facet)) {
                            toggle(facet)
                        }
                    }
                }
            }

            Divider()
            section("Date") {
                ForEach(DateWindow.allCases, id: \.self) { window in
                    row(label: window.label,
                        symbol: "calendar",
                        isOn: state.filter.dateWindow == window) {
                        // Tapping the active window again clears it: a single
                        // choice with no way back would need a fourth "any"
                        // row that means nothing.
                        state.filter.dateWindow = state.filter.dateWindow == window ? nil : window
                    }
                }
            }

            if !state.filter.isEmpty {
                Divider()
                Button("Clear filters") { state.filter = SearchFilter() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(12)
    }

    private func toggle(_ type: ClipboardItemType) {
        if state.filter.types.contains(type) {
            state.filter.types.remove(type)
        } else {
            state.filter.types.insert(type)
        }
    }

    private func toggle(_ facet: AppFacet) {
        if state.filter.apps.contains(facet) {
            state.filter.apps.remove(facet)
        } else {
            state.filter.apps.insert(facet)
        }
    }

    @ViewBuilder
    private func section(_ title: String,
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func row(label: String,
                     icon: NSImage? = nil,
                     symbol: String,
                     isOn: Bool,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(nsImage: icon).resizable().frame(width: 14, height: 14)
                } else {
                    Image(systemName: symbol).font(.system(size: 11)).frame(width: 14)
                }
                Text(label).font(.system(size: 12)).lineLimit(1)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

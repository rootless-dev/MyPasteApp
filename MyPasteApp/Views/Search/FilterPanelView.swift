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
///
/// Laid out in two columns, which is what makes it fit at all. Three of the
/// four axes are bounded — four types, three date windows, one "clear" — and
/// only the app list can grow, because it comes from the history. Stacked in
/// one column the bounded three alone measure 248pt against the 250pt the
/// drawer has to give, which leaves the unbounded one nothing: measured, a
/// twenty-app list rendered as a blank 20pt strip. Side by side the bounded
/// three measure 222pt and the app list gets a full-height column of its own.
struct FilterPanelView: View {
    @Bindable var state: SearchState
    let facets: ItemSearch.Facets

    /// Wide enough for "Last 30 days" with its symbol and its checkmark.
    private static let bandWidth: CGFloat = 140
    private static let columnGap: CGFloat = 20
    private static let contentPadding: CGFloat = 12
    private static let width: CGFloat = 400

    /// Two candidates, and the choice between them is the whole height policy.
    ///
    /// The first lets the app list run at its natural height, and is taken
    /// whenever the panel fits — so a short list still hugs its content instead
    /// of being padded out to fill the drawer. The second puts *only* the app
    /// list in a `ScrollView`, so it absorbs the overflow while the bounded
    /// sections beside it stay pinned and always visible.
    ///
    /// The cap is never written down: `ViewThatFits` derives it from whatever
    /// space the overlay actually proposes, so nothing here has to know the
    /// drawer's height.
    var body: some View {
        ViewThatFits(in: .vertical) {
            columns(scrollingApps: false)
            columns(scrollingApps: true)
        }
        // With no apps there is no second column, and a full-width panel would
        // be mostly empty air.
        .frame(width: facets.apps.isEmpty
               ? Self.bandWidth + 2 * Self.contentPadding
               : Self.width)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        )
    }

    private func columns(scrollingApps: Bool) -> some View {
        HStack(alignment: .top, spacing: Self.columnGap) {
            // The bounded axes. Never scrolled, so the way to undo a filter is
            // always on screen — including "Clear filters", which is the way
            // back from a filter that has hidden everything.
            VStack(alignment: .leading, spacing: 12) {
                // Guarded like the app section below: an empty history has no
                // types either, and an unguarded header would draw "TYPE" with
                // nothing under it.
                if !facets.types.isEmpty {
                    section("Type") {
                        ForEach(facets.types, id: \.self) { type in
                            row(label: type.filterLabel,
                                symbol: type.filterSymbol,
                                isOn: state.filter.types.contains(type)) {
                                toggle(type)
                            }
                        }
                    }
                }

                section("Date") {
                    ForEach(DateWindow.allCases, id: \.self) { window in
                        row(label: window.label,
                            symbol: "calendar",
                            isOn: state.filter.dateWindow == window) {
                            // Tapping the active window again clears it: a
                            // single choice with no way back would need a
                            // fourth "any" row that means nothing.
                            state.filter.dateWindow =
                                state.filter.dateWindow == window ? nil : window
                        }
                    }
                }

                if !state.filter.isEmpty {
                    Button("Clear filters") { state.filter = SearchFilter() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: Self.bandWidth, alignment: .leading)

            // The one axis with no ceiling.
            if !facets.apps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    header("App")
                    if scrollingApps {
                        ScrollView(.vertical) { appRows }
                    } else {
                        appRows
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Self.contentPadding)
    }

    private var appRows: some View {
        VStack(alignment: .leading, spacing: 4) {
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

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func section(_ title: String,
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header(title)
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

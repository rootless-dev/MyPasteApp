//
//  ItemSearch.swift
//  MyPasteApp
//

import Foundation

/// Which source app an item is filtered by.
///
/// `unknown` is a first-class facet, not a corner case to tolerate: items with
/// no `sourceAppBundleID` — including every item written by hand in the editor
/// — would be unreachable while any app filter is active without it.
enum AppFacet: Hashable {
    case bundle(String)
    case unknown

    init(bundleID: String?) {
        self = bundleID.map(AppFacet.bundle) ?? .unknown
    }

    /// Orders facets deterministically, with `unknown` last.
    ///
    /// Sorts by bundle ID rather than by the app's display name on purpose:
    /// the display name needs `NSWorkspace`, which belongs in the view layer
    /// and would make this untestable.
    static func sortKey(_ facet: AppFacet) -> String {
        switch facet {
        case .bundle(let id): return "0\(id)"
        case .unknown: return "1"
        }
    }
}

/// A window of time, always relative to a caller-supplied `now`.
enum DateWindow: Hashable, CaseIterable {
    case today
    case last7Days
    case last30Days

    func contains(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        switch self {
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .last7Days:
            return date >= now.addingTimeInterval(-7 * 24 * 60 * 60)
        case .last30Days:
            return date >= now.addingTimeInterval(-30 * 24 * 60 * 60)
        }
    }
}

/// The structured half of a search. The text half is passed alongside it.
struct SearchFilter: Equatable {
    var types: Set<ClipboardItemType> = []
    var apps: Set<AppFacet> = []
    var dateWindow: DateWindow?

    var isEmpty: Bool { types.isEmpty && apps.isEmpty && dateWindow == nil }
}

/// Whether an item satisfies a search.
///
/// Pure and free-standing so the rule is testable without rendering the
/// overlay — it used to live in `OverlayView.matches`, which meant every new
/// axis made the view harder to reason about.
enum ItemSearch {
    /// Union within an axis, intersection between axes: type ∈ {image, text}
    /// *and* app ∈ {Safari} *and* the text matches. An empty axis restricts
    /// nothing.
    static func matches(item: ClipboardItem,
                        query: String,
                        filter: SearchFilter = SearchFilter(),
                        now: Date,
                        calendar: Calendar = .current) -> Bool {
        guard matchesText(item: item, query: query) else { return false }

        if !filter.types.isEmpty, !filter.types.contains(item.type) { return false }

        if !filter.apps.isEmpty,
           !filter.apps.contains(AppFacet(bundleID: item.sourceAppBundleID)) {
            return false
        }

        if let window = filter.dateWindow,
           !window.contains(item.createdAt, now: now, calendar: calendar) {
            return false
        }

        return true
    }

    private static func matchesText(item: ClipboardItem, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        return contains(item.preview, needle)
            || contains(item.textContent, needle)
            || contains(item.label, needle)
            || contains(item.ocrText, needle)
    }

    /// `range(of:options:)` rather than `lowercased().contains()`: it avoids
    /// allocating a copy of every string on every keystroke, and
    /// `.diacriticInsensitive` makes "cao" find "cão" — in Portuguese that's
    /// the common case, not a nicety.
    private static func contains(_ haystack: String?, _ needle: String) -> Bool {
        guard let haystack else { return false }
        return haystack.range(of: needle,
                              options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

extension ItemSearch {
    struct Facets: Equatable {
        var types: [ClipboardItemType]
        var apps: [AppFacet]
    }

    /// The facets worth offering, derived from the items currently in the
    /// history — never from the list of installed apps. A filter for something
    /// nobody has is a button that always returns nothing.
    static func facets(in items: [ClipboardItem]) -> Facets {
        let presentTypes = Set(items.map(\.type))
        let apps = Set(items.map { AppFacet(bundleID: $0.sourceAppBundleID) })
        return Facets(
            types: ClipboardItemType.canonicalOrder.filter(presentTypes.contains),
            apps: apps.sorted { AppFacet.sortKey($0) < AppFacet.sortKey($1) }
        )
    }
}

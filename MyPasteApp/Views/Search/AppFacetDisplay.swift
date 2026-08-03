//
//  AppFacetDisplay.swift
//  MyPasteApp
//

import AppKit

/// Turns a facet into something showable.
///
/// Lives in the view layer on purpose: `ItemSearch` sorts by bundle ID
/// precisely so the pure rule never needs `NSWorkspace`.
///
/// `@MainActor` for the two caches: they're plain mutable statics, read and
/// written only while building views, and the isolation is what keeps that
/// honest.
@MainActor
enum AppFacetDisplay {
    private static var nameCache: [String: String] = [:]
    /// Optional values on purpose: "this bundle id resolves to no app" is a
    /// result worth remembering, not a reason to ask again. `iconCache[id]`
    /// therefore reads as a hit even when what was cached is nil.
    private static var iconCache: [String: NSImage?] = [:]

    /// The app's display name, falling back to the bundle ID.
    ///
    /// An uninstalled app resolves to nothing through `NSWorkspace`, and the
    /// bundle ID is still a usable label — a filter row with no name would be
    /// an invisible button.
    ///
    /// That fallback is cached like any other answer. Both lookups are
    /// synchronous LaunchServices calls, and this runs from `body` — which
    /// re-runs on every keystroke while the filter panel is open, for every
    /// app facet on screen. Returning the fallback without caching it made an
    /// uninstalled app the one case that paid that cost forever.
    static func name(for facet: AppFacet) -> String {
        switch facet {
        case .unknown:
            return "Unknown"
        case .bundle(let id):
            if let cached = nameCache[id] { return cached }
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            let name = url.map { FileManager.default.displayName(atPath: $0.path) } ?? id
            nameCache[id] = name
            return name
        }
    }

    /// The app's icon, or nil when the app isn't installed — cached either way,
    /// for the reason spelled out on `name(for:)`.
    static func icon(for facet: AppFacet) -> NSImage? {
        guard case .bundle(let id) = facet else { return nil }
        if let cached = iconCache[id] { return cached }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        iconCache[id] = icon
        return icon
    }
}

extension ClipboardItemType {
    var filterLabel: String {
        switch self {
        case .text: return "Text"
        case .url: return "Link"
        case .image: return "Image"
        case .file: return "File"
        }
    }

    var filterSymbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}

extension DateWindow {
    var label: String {
        switch self {
        case .today: return "Today"
        case .last7Days: return "Last 7 days"
        case .last30Days: return "Last 30 days"
        }
    }
}

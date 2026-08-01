//
//  SearchState.swift
//  MyPasteApp
//

import Foundation
import SwiftUI

/// Everything the overlay's search is, in one place: whether it's open, what
/// was typed, and which filters are on.
///
/// The rules that decide behaviour are static and pure, right below — the
/// instance methods only apply them. That's what makes a keyboard contract
/// this branchy testable at all, given the suite never renders a view.
@Observable
@MainActor
final class SearchState {
    private(set) var isActive = false
    var text = ""
    var filter = SearchFilter()
    var isFilterPanelOpen = false

    /// Bumped on every opening of the drawer. Exists only to give the view an
    /// observable value that changes **every** time, including when `close()`
    /// has nothing to clear — it's the trigger for the unconditional re-focus.
    private(set) var openCount = 0

    /// Whether there's anything to let go of before closing the overlay.
    var hasContent: Bool { !text.isEmpty || !filter.isEmpty }

    func activate(seeding character: Character? = nil) {
        isActive = true
        if let character { text.append(character) }
    }

    func close() {
        isActive = false
        isFilterPanelOpen = false
        text = ""
        filter = SearchFilter()
    }

    func markOpened() {
        openCount += 1
    }
}

extension SearchState {
    enum EscapeAction: Equatable {
        case closeFilterPanel
        case hidePreview
        case closeSearch
        case dismissOverlay
    }

    enum BackspaceAction: Equatable {
        case removeLastToken
        /// Let the field have the key.
        case passThrough
        case deleteItem
    }

    /// Dismiss what's on top first, as the system does everywhere else.
    ///
    /// An empty search is skipped on purpose: making the user press escape
    /// twice to close a field they never typed into would tax the common case
    /// to serve the rare one.
    static func escapeAction(isFilterPanelOpen: Bool,
                             isPreviewOpen: Bool,
                             isActive: Bool,
                             hasContent: Bool) -> EscapeAction {
        if isFilterPanelOpen { return .closeFilterPanel }
        if isPreviewOpen { return .hidePreview }
        if isActive, hasContent { return .closeSearch }
        return .dismissOverlay
    }

    /// With the search open, backspace never deletes an item.
    ///
    /// The field can now be open and empty, and deleting a letter that isn't
    /// there must not destroy a history item.
    static func backspaceAction(isActive: Bool,
                                textIsEmpty: Bool,
                                hasTokens: Bool) -> BackspaceAction {
        guard isActive else { return .deleteItem }
        if textIsEmpty, hasTokens { return .removeLastToken }
        return .passThrough
    }

    /// The character that should open the search, or nil when the key isn't
    /// one that opens it.
    ///
    /// ⌘, ⌃ and ⌥ are excluded so the existing shortcuts stay unambiguous —
    /// without that guard ⌘E would open the editor *and* seed the field with
    /// an "e". ⇧ is deliberately allowed: it's how capitals are typed, and
    /// Phase 2 learned the hard way that a shifted key arrives uppercased.
    /// Space is excluded because it's the preview toggle and a leading space
    /// in a query has no use.
    static func activationCharacter(_ character: Character,
                                    modifiers: EventModifiers,
                                    isActive: Bool) -> Character? {
        guard !isActive else { return nil }
        guard !modifiers.contains(.command),
              !modifiers.contains(.control),
              !modifiers.contains(.option) else { return nil }
        guard character.isLetter || character.isNumber
                || character.isPunctuation || character.isSymbol else { return nil }
        return character
    }
}

/// Where the overlay's keyboard is pointed.
///
/// Top-level rather than nested in `OverlayView`, because `OverlayTopBar` has
/// to name the same type to take the focus binding.
enum OverlayFocusTarget: Hashable {
    case list
    case search
}

/// One active filter, as shown inside the search field.
///
/// Derived from `SearchFilter` rather than stored beside it: two parallel
/// collections would diverge on the first "clear all".
enum SearchToken: Hashable, Identifiable {
    case type(ClipboardItemType)
    case app(AppFacet)
    case date(DateWindow)

    var id: Self { self }

    static func tokens(from filter: SearchFilter) -> [SearchToken] {
        // Same order as the filter panel's rows — one home, see
        // `ClipboardItemType.canonicalOrder`.
        var result = ClipboardItemType.canonicalOrder
            .filter(filter.types.contains)
            .map(SearchToken.type)
        result += filter.apps
            .sorted { AppFacet.sortKey($0) < AppFacet.sortKey($1) }
            .map(SearchToken.app)
        if let window = filter.dateWindow { result.append(.date(window)) }
        return result
    }

    func removed(from filter: SearchFilter) -> SearchFilter {
        var copy = filter
        switch self {
        case .type(let type): copy.types.remove(type)
        case .app(let facet): copy.apps.remove(facet)
        case .date: copy.dateWindow = nil
        }
        return copy
    }
}

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

    /// Opens the search, and nothing else.
    ///
    /// It deliberately takes no seed character: `OverlayView.activateSearch`
    /// writes the seed straight into `text` in the same turn, next to the focus
    /// write it belongs with. Nothing here would be able to place the caret,
    /// which is the half of that job that decides whether the seed survives —
    /// see `SearchTextField`.
    func activate() {
        isActive = true
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
        /// Drop the multi-paste marks, leaving the drawer open.
        case clearMarks
        /// Go back to the history, leaving the drawer open.
        case leaveScope
        case dismissOverlay
    }

    enum BackspaceAction: Equatable {
        case removeLastToken
        /// Let the field have the key.
        case passThrough
        case deleteItem
        /// Swallow the key: a block is being assembled, and with the
        /// selection border gone (see `ClipboardCardView.anyMarked`) there's
        /// no on-screen target left for ⌫ to name.
        case blockedByMarks
    }

    /// Dismiss what's on top first, as the system does everywhere else.
    ///
    /// An empty search is skipped on purpose: making the user press escape
    /// twice to close a field they never typed into would tax the common case
    /// to serve the rare one.
    ///
    /// Marks come after the search, and the scope after the marks: with all
    /// three live, the first escape lets go of the search, the second clears
    /// the marks, the third returns to the history, the fourth closes the
    /// drawer — most volatile first, all the way down.
    static func escapeAction(isFilterPanelOpen: Bool,
                             isPreviewOpen: Bool,
                             isActive: Bool,
                             hasContent: Bool,
                             hasMarks: Bool,
                             hasScope: Bool) -> EscapeAction {
        if isFilterPanelOpen { return .closeFilterPanel }
        if isPreviewOpen { return .hidePreview }
        if isActive, hasContent { return .closeSearch }
        if hasMarks { return .clearMarks }
        if hasScope { return .leaveScope }
        return .dismissOverlay
    }

    /// With the search open, backspace never deletes an item.
    ///
    /// The field can now be open and empty, and deleting a letter that isn't
    /// there must not destroy a history item.
    ///
    /// `hasMarks` is only consulted once the search is closed — the guard
    /// below returns before it's ever read, so the two search-open branches
    /// (`.removeLastToken` and `.passThrough`) are untouched by marks by
    /// construction, matching the "must not change" half of this rule.
    static func backspaceAction(isActive: Bool,
                                textIsEmpty: Bool,
                                hasTokens: Bool,
                                hasMarks: Bool) -> BackspaceAction {
        guard isActive else { return hasMarks ? .blockedByMarks : .deleteItem }
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
///
/// Every field in the drawer takes its focus from this one enum, and no view
/// below `OverlayView` may declare a `@FocusState` of its own. `PinboardPill`
/// did, and the two systems did not merge: `+` pointed the pill's private
/// `@FocusState` at the rename field while this one still said `.list`, so the
/// letters typed next went to the overlay's handlers, which opened the search
/// and typed into it. Same class of failure as the one described on
/// `SearchTextField.focusTarget` — a focus value nothing in the tree claims is
/// dropped — reached by a second door.
enum OverlayFocusTarget: Hashable {
    /// The card strip: the drawer's root container, which is `focusable()` so
    /// that `onKeyPress` has somewhere to fire from at rest. Every field hands
    /// the keyboard back here on the way out.
    case list
    /// The search field. The tag lives on `SearchTextField` itself, applied by
    /// `SearchFieldView` — see the note there on tagging the field and not a
    /// container that merely contains it.
    case search
    /// The inline rename field on a pinboard pill.
    ///
    /// No board id attached, and none needed: `PinboardScope.renamingBoardID`
    /// is a single optional, so at most one pill shows the field at a time and
    /// there is never a second one for a value to disambiguate.
    case boardName
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

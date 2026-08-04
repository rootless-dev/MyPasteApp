//
//  PinboardScope.swift
//  MyPasteApp
//

import Foundation
import SwiftData

/// Which shelf the overlay is showing: the history, or one pinboard.
///
/// Exclusive by design — one scope at a time, the way `design-refs/13` shows
/// it. A pinboard is not another axis of `SearchFilter`: filters combine and
/// narrow, a scope replaces. Making it a filter axis would give the pills and
/// the filter panel two ways to do overlapping things, and the history would
/// never leave the screen.
///
/// Owned by `OverlayWindowController` and reset on every `show()`, for the
/// same reason `SearchState` and `MarkedSelection` are: `OverlayView` is built
/// once in `prepare()` and reused for the life of the process, so `@State`
/// here would outlive the drawer closing.
@Observable
@MainActor
final class PinboardScope {
    /// The active pinboard, or nil for the history.
    private(set) var activeID: UUID?

    /// The board whose pill is in inline rename, if any.
    ///
    /// Here rather than in `OverlayView.@State` for the same reason `activeID`
    /// is: the view is built once and reused, so a `@State` id survived the
    /// drawer closing. Pressing `+` and closing the drawer before confirming
    /// the name brought the pill back in edit mode — a text field where the
    /// board's name should be — on that opening and every one after it. Sharing
    /// `reset()` with `activeID` is what keeps that from needing its own
    /// separate teardown path in `show()`.
    private(set) var renamingBoardID: UUID?

    var isScoped: Bool { activeID != nil }

    func select(_ id: UUID?) {
        activeID = id
    }

    func beginRenaming(_ id: UUID) {
        renamingBoardID = id
    }

    func endRenaming() {
        renamingBoardID = nil
    }

    func reset() {
        activeID = nil
        renamingBoardID = nil
    }
}

extension PinboardScope {
    /// Whether an item belongs on the shelf currently on screen.
    ///
    /// Applied before `ItemSearch.matches`, never inside it: "is this on this
    /// shelf?" and "does this match what I typed?" are separate questions, and
    /// folding the first into `SearchFilter` would put an exclusive,
    /// non-combinable axis next to three combinable ones.
    static func contains(item: ClipboardItem, activeID: UUID?) -> Bool {
        guard let activeID else { return true }
        return item.pinboard?.id == activeID
    }
}

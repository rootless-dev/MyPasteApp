//
//  MarkedSelection.swift
//  MyPasteApp
//

import Foundation
import SwiftUI

/// The items marked for a multi-item paste, in the order they were marked.
///
/// Owned by `OverlayWindowController`, not by `OverlayView` — the same
/// arrangement, and for the same reason, as `SearchState`: the overlay is
/// built once in `prepare()` and reused for the life of the process, so state
/// held in `@State` would outlive the drawer being closed and the next opening
/// would come back with last time's marks still on.
///
/// Holds ids rather than `ClipboardItem` references on purpose. Those are
/// `@Model` objects the context can delete at any time; a strong reference
/// here would keep a deleted item alive inside an invisible list. With ids, an
/// item deleted while marked simply isn't found at resolve time and drops out
/// of the block on its own — see `MultiPaste.resolve`.
@Observable
@MainActor
final class MarkedSelection {
    /// Ids in the order they were marked. That order is the contract: it's
    /// what the pasted block respects, and where the card's chip number comes
    /// from.
    private(set) var ids: [UUID] = []

    var isEmpty: Bool { ids.isEmpty }
    var count: Int { ids.count }

    func contains(_ id: UUID) -> Bool { ids.contains(id) }

    /// Marks at the end of the queue, or unmarks.
    ///
    /// Unmarking from the middle renumbers everything after it, which is the
    /// correct behaviour: position 2 always means the second item that will be
    /// pasted, never a frozen label.
    func toggle(_ id: UUID) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
    }

    /// Drops an id, marked or not.
    ///
    /// Unlike `toggle`, this never marks: it is what a *deletion* calls, and a
    /// deleted item must not become marked because it happened not to be.
    /// Renumbers what follows, for the same reason unmarking from the middle
    /// does.
    ///
    /// `MultiPaste.resolve` already drops ids with no item left, and that stays
    /// as the backstop for everything that deletes without going through the
    /// view — retention pruning, for one. But the backstop only covers the
    /// paste itself: the count pill keeps reading the raw `count`, and with
    /// every marked item deleted, ↵ hits the mark branch, resolves to nothing
    /// and returns `.ignored`, so the key does nothing at all while the pill
    /// says "1 marked ↵ paste".
    func remove(_ id: UUID) {
        guard let index = ids.firstIndex(of: id) else { return }
        ids.remove(at: index)
    }

    /// 1-based position for the card's chip, or nil when not marked.
    func order(of id: UUID) -> Int? {
        ids.firstIndex(of: id).map { $0 + 1 }
    }

    func clear() { ids.removeAll() }
}

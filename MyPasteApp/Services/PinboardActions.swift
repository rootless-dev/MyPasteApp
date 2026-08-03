//
//  PinboardActions.swift
//  MyPasteApp
//

import Foundation
import SwiftData

/// Everything that can be done to a pinboard, with no interface attached.
///
/// The same shape as `ItemActions`, and for the same reason: the pill's
/// context menu and the `+` button are two callers of one set of rules, and
/// keeping the rules here is what stops them from drifting apart.
@MainActor
struct PinboardActions {
    let modelContext: ModelContext

    /// Every board, in creation order — the order the strip shows them in.
    func allBoards() -> [Pinboard] {
        let descriptor = FetchDescriptor<Pinboard>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Creates an untitled board in the first colour nobody is using.
    ///
    /// The caller selects it and puts its pill straight into inline rename —
    /// see `PinboardBar`. Naming is not required: a board left as "Untitled"
    /// is a board, and cancelling a rename must never delete what was just
    /// created.
    @discardableResult
    func create() -> Pinboard {
        let board = Pinboard(name: Pinboard.untitledName,
                             colorHex: PinboardPalette.nextColor(usedBy: allBoards().map(\.colorHex)))
        modelContext.insert(board)
        try? modelContext.save()
        return board
    }

    func rename(_ pinboard: Pinboard, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        pinboard.name = trimmed.isEmpty ? Pinboard.untitledName : trimmed
        try? modelContext.save()
    }

    func recolor(_ pinboard: Pinboard, to hex: String) {
        pinboard.colorHex = hex
        try? modelContext.save()
    }

    /// Deletes the board. Its items stay in the history — the relationship's
    /// `.nullify` rule does that, and `PinboardActionsTests` holds it down.
    func delete(_ pinboard: Pinboard) {
        modelContext.delete(pinboard)
        try? modelContext.save()
    }
}

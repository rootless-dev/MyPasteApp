//
//  PinboardBar.swift
//  MyPasteApp
//

import SwiftUI

/// The scope strip: History first, then one pill per pinboard, then `+`.
///
/// History is always present and always first — it's where the drawer opens
/// and where every escape eventually returns to. Boards are ordered by
/// creation; reordering by drag is deliberately out of scope for Phase 5.
struct PinboardBar: View {
    let boards: [Pinboard]
    let activeID: UUID?
    /// True while the search field is open, so the pills give up their labels.
    let isCollapsed: Bool
    let onSelect: (UUID?) -> Void
    let onCreate: () -> Void
    /// Right-clicking a board pill. Wired in Task 5; a no-op until then.
    var contextMenu: (Pinboard) -> AnyView = { _ in AnyView(EmptyView()) }

    var body: some View {
        HStack(spacing: 8) {
            PinboardPill(title: "History",
                         colorHex: nil,
                         isSelected: activeID == nil,
                         isCollapsed: isCollapsed) { onSelect(nil) }

            ForEach(boards) { board in
                PinboardPill(title: board.name,
                             colorHex: board.colorHex,
                             isSelected: board.id == activeID,
                             isCollapsed: isCollapsed) { onSelect(board.id) }
                    .contextMenu { contextMenu(board) }
            }

            Button(action: onCreate) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New pinboard")
        }
    }
}

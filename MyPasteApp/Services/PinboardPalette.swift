//
//  PinboardPalette.swift
//  MyPasteApp
//

import Foundation

/// The eight colours a pinboard can take.
///
/// Fixed, and deliberately not a free colour picker: every one of these has to
/// stay legible as a card header over the dark overlay, and a picker would let
/// the set drift into something that no longer reads as one family. Taken from
/// `design-refs/15-pinboard-menu-contexto.png`, in the order shown there.
///
/// These strings are persisted in `Pinboard.colorHex`. Changing an entry
/// recolours every board already using it — `PinboardPaletteTests` freezes the
/// list for that reason.
enum PinboardPalette {
    static let colors: [String] = [
        "FF3B30", // red
        "FF9500", // orange
        "FFCC00", // yellow
        "34C759", // green
        "007AFF", // blue
        "AF52DE", // purple
        "FF2D55", // pink
        "8E8E93", // grey
    ]

    /// The first colour not already taken, or the first of the palette once
    /// all eight are in use.
    ///
    /// Deterministic on purpose: two boards created in a row should never come
    /// up the same colour while a free one exists.
    static func nextColor(usedBy existing: [String]) -> String {
        let used = Set(existing.map { $0.uppercased() })
        return colors.first { !used.contains($0) } ?? colors[0]
    }
}

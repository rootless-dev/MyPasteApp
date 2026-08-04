//
//  Color+Hex.swift
//  MyPasteApp
//

import SwiftUI

/// Moved out of `LinkPreviewView.swift` in Phase 5: pinboard pills and card
/// headers now decode `Pinboard.colorHex` through this, and a shared helper
/// living inside one view's file is a helper nobody finds.
extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

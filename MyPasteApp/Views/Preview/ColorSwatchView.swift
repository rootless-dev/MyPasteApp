//
//  ColorSwatchView.swift
//  MyPasteApp
//

import SwiftUI

/// A recognised colour, filling the space it's given, with its code on top.
///
/// Used by the card and by the preview panel, so the two can't drift on what
/// "this item is a colour" looks like. The checkerboard shows through a
/// translucent colour, the same way it does behind an image with transparency.
struct ColorSwatchView: View {
    let color: ColorCode
    /// The text to print over the swatch — the item's own code, as written.
    let code: String

    var body: some View {
        ZStack {
            CheckerboardBackground()
            Color(.sRGB,
                  red: color.red,
                  green: color.green,
                  blue: color.blue,
                  opacity: color.alpha)
            Text(code)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(legibleForeground)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(legibleForeground == .white ? .black.opacity(0.25) : .white.opacity(0.55))
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Black text on light colours, white on dark ones.
    ///
    /// Relative luminance, not plain brightness: pure green reads far lighter
    /// than pure blue at the same numeric value, and averaging the channels
    /// would put white text on a colour nobody can read it against.
    private var legibleForeground: Color {
        let luminance = 0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
        return luminance > 0.55 ? .black : .white
    }
}

//
//  ColorCode.swift
//  MyPasteApp
//

import AppKit
import Foundation

/// The formats a colour can be written back out as.
enum ColorFormat: String, CaseIterable {
    case hex
    case rgb
    case hsl

    var title: String {
        switch self {
        case .hex: return "Hex"
        case .rgb: return "RGB"
        case .hsl: return "HSL"
        }
    }
}

/// A colour the app recognised in an item's text, or sampled from the screen.
///
/// Components are sRGB, 0...1. Nothing is stored on the model: an item is a
/// colour item when — and only when — its whole text parses as one, the same
/// way `typeLabel` is derived rather than persisted.
struct ColorCode: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Reads a colour, converting to sRGB first.
    ///
    /// Returns nil when the conversion isn't possible (pattern colours, for
    /// instance). Reading components off a colour in another space would give
    /// numbers that don't match what the user saw on screen.
    init?(_ color: NSColor) {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        self.init(red: Double(srgb.redComponent),
                  green: Double(srgb.greenComponent),
                  blue: Double(srgb.blueComponent),
                  alpha: Double(srgb.alphaComponent))
    }

    // MARK: - Parsing

    /// Reads a colour out of text, or returns nil.
    ///
    /// The trimmed string has to be a colour from end to end. Searching for a
    /// colour *inside* the text would turn every stylesheet in the history
    /// into a colour item, and leave "Copy Color as" with no single answer.
    static func parse(_ text: String) -> ColorCode? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("#") { return parseHex(trimmed) }
        return parseFunction(trimmed)
    }

    private static func parseHex(_ text: String) -> ColorCode? {
        let digits = String(text.dropFirst())
        guard digits.allSatisfy({ $0.isHexDigit }) else { return nil }

        func value(_ substring: Substring) -> Double {
            Double(Int(substring, radix: 16) ?? 0) / 255.0
        }

        switch digits.count {
        case 3, 4:
            // #RGB and #RGBA: each digit stands for the pair it repeats.
            let doubled = digits.map { "\($0)\($0)" }.joined()
            return parseHex("#" + doubled)
        case 6, 8:
            let chars = Array(digits)
            let pairs = stride(from: 0, to: chars.count, by: 2).map {
                Substring(String(chars[$0...$0 + 1]))
            }
            return ColorCode(red: value(pairs[0]),
                             green: value(pairs[1]),
                             blue: value(pairs[2]),
                             alpha: pairs.count == 4 ? value(pairs[3]) : 1)
        default:
            return nil
        }
    }

    private static func parseFunction(_ text: String) -> ColorCode? {
        guard let open = text.firstIndex(of: "("), text.hasSuffix(")") else { return nil }
        let name = text[text.startIndex..<open].lowercased()
        let inside = text[text.index(after: open)..<text.index(before: text.endIndex)]
        // Commas and spaces are both accepted as separators: CSS allows both,
        // and a pasted colour arrives in whichever style its source used.
        let parts = inside
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map(String.init)

        switch name {
        case "rgb", "rgba":
            guard parts.count == (name == "rgb" ? 3 : 4) else { return nil }
            guard let r = channel(parts[0]), let g = channel(parts[1]), let b = channel(parts[2])
            else { return nil }
            let a = parts.count == 4 ? Double(parts[3]) : 1
            guard let alpha = a, (0...1).contains(alpha) else { return nil }
            return ColorCode(red: r, green: g, blue: b, alpha: alpha)
        case "hsl", "hsla":
            guard parts.count == (name == "hsl" ? 3 : 4) else { return nil }
            guard let h = Double(parts[0]),
                  let s = percentage(parts[1]),
                  let l = percentage(parts[2])
            else { return nil }
            let a = parts.count == 4 ? Double(parts[3]) : 1
            guard let alpha = a, (0...1).contains(alpha) else { return nil }
            return ColorCode(hue: h, saturation: s, lightness: l, alpha: alpha)
        default:
            return nil
        }
    }

    /// A 0...255 channel as 0...1, rejecting out-of-range values.
    private static func channel(_ text: String) -> Double? {
        guard let value = Double(text), (0...255).contains(value) else { return nil }
        return value / 255.0
    }

    /// A `50%` string as 0...1. The percent sign is required: `hsl(217, 100, 61%)`
    /// isn't valid CSS, and accepting it would make the parser guess.
    private static func percentage(_ text: String) -> Double? {
        guard text.hasSuffix("%"),
              let value = Double(text.dropLast()),
              (0...100).contains(value)
        else { return nil }
        return value / 100.0
    }

    // MARK: - HSL

    private init(hue: Double, saturation: Double, lightness: Double, alpha: Double) {
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let hp = hue.truncatingRemainder(dividingBy: 360) / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let m = lightness - c / 2

        let (r, g, b): (Double, Double, Double)
        switch hp {
        case ..<1: (r, g, b) = (c, x, 0)
        case ..<2: (r, g, b) = (x, c, 0)
        case ..<3: (r, g, b) = (0, c, x)
        case ..<4: (r, g, b) = (0, x, c)
        case ..<5: (r, g, b) = (x, 0, c)
        default:   (r, g, b) = (c, 0, x)
        }
        self.init(red: r + m, green: g + m, blue: b + m, alpha: alpha)
    }

    private var hsl: (hue: Double, saturation: Double, lightness: Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        let lightness = (maxValue + minValue) / 2

        guard delta > 0 else { return (0, 0, lightness) }

        let saturation = delta / (1 - abs(2 * lightness - 1))
        let hue: Double
        switch maxValue {
        case red:   hue = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
        case green: hue = 60 * (((blue - red) / delta) + 2)
        default:    hue = 60 * (((red - green) / delta) + 4)
        }
        return (hue < 0 ? hue + 360 : hue, saturation, lightness)
    }

    // MARK: - Formatting

    func formatted(as format: ColorFormat) -> String {
        let opaque = alpha >= 1
        switch format {
        case .hex:
            let base = String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
            return opaque ? base : base + String(format: "%02X", byte(alpha))
        case .rgb:
            let base = "\(byte(red)), \(byte(green)), \(byte(blue))"
            return opaque ? "rgb(\(base))" : "rgba(\(base), \(alphaText))"
        case .hsl:
            let (h, s, l) = hsl
            // Rounding can push a hue right up to 360, which is the same
            // angle as 0 — wrap it back so "hsl(360, ...)" never appears.
            let hueDegrees = Int(h.rounded()) % 360
            let base = "\(hueDegrees), \(percent(s))%, \(percent(l))%"
            return opaque ? "hsl(\(base))" : "hsla(\(base), \(alphaText))"
        }
    }

    private func byte(_ value: Double) -> Int { Int((value * 255).rounded()) }
    private func percent(_ value: Double) -> Int { Int((value * 100).rounded()) }

    /// Alpha with at most two decimals and no trailing zeros — `0.5`, not `0.50`.
    private var alphaText: String {
        let rounded = (alpha * 100).rounded() / 100
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%g", rounded)
    }
}

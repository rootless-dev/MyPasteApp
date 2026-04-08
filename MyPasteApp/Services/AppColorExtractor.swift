//
//  AppColorExtractor.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// Extrai a cor dominante (vibrante) do ícone de um app a partir do seu bundleID.
/// Usado para colorir o header dos tiles de acordo com o app de origem do clipboard.
enum AppColorExtractor {
    private static var cache: [String: NSColor] = [:]
    private static let fallback = NSColor.controlAccentColor

    static func nsColor(for bundleID: String?) -> NSColor {
        guard let bundleID, !bundleID.isEmpty else { return fallback }
        if let cached = cache[bundleID] { return cached }

        guard
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else {
            cache[bundleID] = fallback
            return fallback
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let color = dominantColor(of: icon) ?? fallback
        cache[bundleID] = color
        return color
    }

    static func color(for bundleID: String?) -> Color {
        Color(nsColor: nsColor(for: bundleID))
    }

    // MARK: - Algorithm

    private static func dominantColor(of image: NSImage) -> NSColor? {
        let size = NSSize(width: 32, height: 32)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = ctx
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.bitmapData else { return nil }
        let bytesPerRow = rep.bytesPerRow
        let width = Int(size.width)
        let height = Int(size.height)

        var rSum: Double = 0
        var gSum: Double = 0
        var bSum: Double = 0
        var count: Double = 0

        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * 4
                let r = Double(data[i])     / 255.0
                let g = Double(data[i + 1]) / 255.0
                let b = Double(data[i + 2]) / 255.0
                let a = Double(data[i + 3]) / 255.0
                guard a > 0.5 else { continue }

                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                guard luminance > 0.15, luminance < 0.85 else { continue }

                // Pondera pela saturação para favorecer cores vibrantes
                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
                let weight = 0.2 + saturation

                rSum += r * weight
                gSum += g * weight
                bSum += b * weight
                count += weight
            }
        }

        guard count > 0 else { return nil }

        var r = CGFloat(rSum / count)
        var g = CGFloat(gSum / count)
        var b = CGFloat(bSum / count)

        // Garante uma cor com saturação mínima razoável para o header não ficar acinzentado
        let nsColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        nsColor.usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        if s < 0.35 { s = 0.55 }
        if v < 0.55 { v = 0.65 }
        if v > 0.85 { v = 0.85 }
        let boosted = NSColor(hue: h, saturation: s, brightness: v, alpha: 1.0)
        boosted.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

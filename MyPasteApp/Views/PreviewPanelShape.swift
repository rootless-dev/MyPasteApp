//
//  PreviewPanelShape.swift
//  MyPasteApp
//

import SwiftUI

/// The preview panel's own outline: a rounded rectangle with an optional
/// triangular beak hanging off the bottom edge, pointing at whatever card the
/// panel is previewing.
///
/// `path(in:)` is handed the *whole window's* rect, beak included — the
/// rounded body occupies that rect minus `beakHeight` at the base, and the
/// beak (when present) fills the strip below it. Drawn as one continuous
/// `Path` rather than a rounded rect plus a separate triangle: two
/// overlapping shapes seam visibly where they meet once this is filled with
/// a translucent material, which is exactly how `ItemPreviewView` uses it.
struct PreviewPanelShape: Shape {
    /// x-position (in the same rect passed to `path(in:)`) the beak's tip
    /// points at. `nil` draws just the rounded body, leaving the `beakHeight`
    /// strip at the base empty — this shape doesn't shrink the window to
    /// match; that's the caller's job (Task 5, when the panel can be
    /// detached and loses its beak).
    let beakOffset: CGFloat?
    let beakHeight: CGFloat
    let cornerRadius: CGFloat

    /// Width of the beak's base. A local constant for this spike; Task 4
    /// replaces it with `PreviewPlacement.beakWidth` once that type exists.
    private let beakWidth: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY,
                           width: rect.width, height: rect.height - beakHeight)
        let left = body.minX
        let right = body.maxX
        let top = body.minY
        let bottom = body.maxY
        let radius = cornerRadius

        var path = Path()
        path.move(to: CGPoint(x: left + radius, y: top))
        path.addLine(to: CGPoint(x: right - radius, y: top))
        path.addArc(center: CGPoint(x: right - radius, y: top + radius), radius: radius,
                    startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: right, y: bottom - radius))
        path.addArc(center: CGPoint(x: right - radius, y: bottom - radius), radius: radius,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

        // Bottom edge, right corner to left corner — the beak, when present,
        // is spliced into the middle of this single line rather than added
        // as a separate move, which is what keeps the path continuous.
        if let beakOffset {
            let half = beakWidth / 2
            path.addLine(to: CGPoint(x: beakOffset + half, y: bottom))
            path.addLine(to: CGPoint(x: beakOffset, y: rect.maxY))
            path.addLine(to: CGPoint(x: beakOffset - half, y: bottom))
        }
        path.addLine(to: CGPoint(x: left + radius, y: bottom))

        path.addArc(center: CGPoint(x: left + radius, y: bottom - radius), radius: radius,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: left, y: top + radius))
        path.addArc(center: CGPoint(x: left + radius, y: top + radius), radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

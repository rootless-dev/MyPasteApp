//
//  PreviewPlacement.swift
//  MyPasteApp
//

import CoreGraphics
import Foundation

/// Where the preview panel goes, and whether its beak can point at the card
/// it's previewing.
///
/// Pure geometry — no `NSScreen`/`NSWindow`/`NSView` — on purpose:
/// `PreviewPanelController.positionPreviewPanel(_:)` still owns converting
/// `previewAnchorFrame` to screen coordinates and calling `panel.setFrame`,
/// because those genuinely need a live window to convert against. Everything
/// downstream of "here's the card's frame in screen coordinates" is just
/// arithmetic, and arithmetic is what a test can actually pin down — this is
/// the edge-clamping behaviour that's existed since Phase 2 and never had
/// one.
enum PreviewPlacement {
    /// Gap between the top of the card and the bottom of the panel.
    static let margin: CGFloat = 12
    /// How close the panel is allowed to get to the edge of the screen.
    static let edgeInset: CGFloat = 8
    /// Width of the beak's base.
    static let beakWidth: CGFloat = 22

    struct Result: Equatable {
        let frame: CGRect
        /// The beak's tip, in the panel's own coordinates, or nil when the
        /// panel can't point at the card.
        let beakOffset: CGFloat?
    }

    /// - Parameters:
    ///   - anchor: the card's frame, in screen coordinates.
    ///   - panelSize: `ItemPreviewPanel.windowSize` — the whole window,
    ///     beak included.
    ///   - visibleFrame: the target screen's `visibleFrame` (menu bar and
    ///     Dock already excluded).
    ///   - cornerRadius: `ItemPreviewPanel.cornerRadius` — how much of the
    ///     base the rounded corners themselves occupy, and so how far the
    ///     beak's tip has to stay from either end.
    ///   - beakWidth: the beak's base width, passed rather than read from
    ///     `Self.beakWidth` so a caller (and the test suite) can vary it
    ///     without this type reaching back into `ItemPreviewPanel`.
    static func solve(anchor: CGRect,
                      panelSize: CGSize,
                      visibleFrame: CGRect,
                      cornerRadius: CGFloat,
                      beakWidth: CGFloat) -> Result {
        var x = anchor.midX - panelSize.width / 2
        var y = anchor.maxY + margin

        x = max(visibleFrame.minX + edgeInset,
                min(x, visibleFrame.maxX - panelSize.width - edgeInset))
        if y + panelSize.height > visibleFrame.maxY - edgeInset {
            y = visibleFrame.maxY - panelSize.height - edgeInset
        }
        if y < visibleFrame.minY + edgeInset {
            y = visibleFrame.minY + edgeInset
        }

        let frame = CGRect(x: x, y: y, width: panelSize.width, height: panelSize.height)

        // The panel didn't end up above the card — either it was pushed down
        // for lack of room, or (once a caller passes an anchor taller than
        // the screen) something stranger. Either way a beak here would point
        // into the panel's own body rather than at the card, so there's
        // nothing legal to draw.
        guard frame.minY >= anchor.maxY else {
            return Result(frame: frame, beakOffset: nil)
        }

        let tip = anchor.midX - frame.minX
        let minTip = cornerRadius + beakWidth / 2
        let maxTip = panelSize.width - cornerRadius - beakWidth / 2
        guard tip >= minTip, tip <= maxTip else {
            return Result(frame: frame, beakOffset: nil)
        }

        return Result(frame: frame, beakOffset: tip)
    }
}

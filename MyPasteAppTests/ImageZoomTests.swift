//
//  ImageZoomTests.swift
//  MyPasteAppTests
//

import CoreGraphics
import Testing
@testable import MyPasteApp

@Suite("Image zoom geometry")
struct ImageZoomTests {

    // MARK: - unzoomed

    @Test("at fit scale, unzoomed is the identity")
    func identityAtFit() {
        let point = CGPoint(x: 37, y: 122)
        let viewSize = CGSize(width: 200, height: 200)
        #expect(ImageZoom.unzoomed(point, viewSize: viewSize, scale: 1, offset: .zero) == point)
    }

    @Test("the view's centre maps to the centre at any scale, with no pan")
    func centreStaysCentreAtAnyScale() {
        let viewSize = CGSize(width: 200, height: 200)
        let centre = CGPoint(x: 100, y: 100)
        for scale: CGFloat in [1, 2, 5, 8] {
            let mapped = ImageZoom.unzoomed(centre, viewSize: viewSize, scale: scale, offset: .zero)
            #expect(mapped == centre)
        }
    }

    @Test("a known off-centre point maps correctly at 2x")
    func offCentreAtDoubleScale() {
        // 50pt right of centre on screen, at 2x, is 25pt right of centre in
        // the space ImagePixel reads — half the on-screen distance, because
        // the image is drawn twice as large.
        let viewSize = CGSize(width: 200, height: 200)
        let point = CGPoint(x: 150, y: 100)
        let mapped = ImageZoom.unzoomed(point, viewSize: viewSize, scale: 2, offset: .zero)
        #expect(mapped == CGPoint(x: 125, y: 100))
    }

    @Test("panning shifts the mapping by exactly the pan")
    func panningShiftsTheMapping() {
        // At scale 1, offset alone should subtract straight through: the
        // image moved 20pt right and 10pt down on screen, so the same
        // screen point now sits 20pt/10pt earlier in image space.
        let viewSize = CGSize(width: 200, height: 200)
        let centre = CGPoint(x: 100, y: 100)
        let mapped = ImageZoom.unzoomed(centre, viewSize: viewSize, scale: 1,
                                        offset: CGSize(width: 20, height: 10))
        #expect(mapped == CGPoint(x: 80, y: 90))
    }

    @Test("panning and scale compose")
    func panningComposesWithScale() {
        let viewSize = CGSize(width: 200, height: 200)
        let point = CGPoint(x: 150, y: 100)
        let mapped = ImageZoom.unzoomed(point, viewSize: viewSize, scale: 2,
                                        offset: CGSize(width: 20, height: 0))
        // centre (100) + (150 - 100 - 20) / 2 == 100 + 15 == 115
        #expect(mapped == CGPoint(x: 115, y: 100))
    }

    // MARK: - clamped

    @Test("clamping forces offset to zero at fit scale, even given a stray offset")
    func clampingForcesZeroOffsetAtFit() {
        let zoom = ImageZoom(scale: 1, offset: CGSize(width: 500, height: 500))
            .clamped(viewSize: CGSize(width: 200, height: 200),
                    imageSize: CGSize(width: 100, height: 50))
        #expect(zoom.offset == .zero)
    }

    @Test("clamping keeps the image within its own frame when zoomed")
    func clampingKeepsImageWithinFrame() {
        // 100x50 image in a 200x200 view fits at 2x (200x100 drawn). At a
        // further 3x zoom the drawn size is 600x300, so the image can pan
        // at most (600-200)/2 = 200 horizontally and (300-200)/2 = 50
        // vertically before its own edge would cross the view's.
        let zoom = ImageZoom(scale: 3, offset: CGSize(width: 1000, height: 1000))
            .clamped(viewSize: CGSize(width: 200, height: 200),
                    imageSize: CGSize(width: 100, height: 50))
        #expect(zoom.offset == CGSize(width: 200, height: 50))

        let negative = ImageZoom(scale: 3, offset: CGSize(width: -1000, height: -1000))
            .clamped(viewSize: CGSize(width: 200, height: 200),
                    imageSize: CGSize(width: 100, height: 50))
        #expect(negative.offset == CGSize(width: -200, height: -50))
    }

    @Test("clamping leaves an in-bounds offset untouched")
    func clampingLeavesInBoundsOffsetAlone() {
        let zoom = ImageZoom(scale: 3, offset: CGSize(width: 50, height: 10))
            .clamped(viewSize: CGSize(width: 200, height: 200),
                    imageSize: CGSize(width: 100, height: 50))
        #expect(zoom.offset == CGSize(width: 50, height: 10))
    }

    @Test("scale never goes below fit or above the maximum")
    func scaleBoundsHold() {
        let tooSmall = ImageZoom(scale: 0.2, offset: .zero)
            .clamped(viewSize: CGSize(width: 200, height: 200),
                    imageSize: CGSize(width: 100, height: 50))
        #expect(tooSmall.scale == ImageZoom.minScale)

        let tooBig = ImageZoom(scale: 999, offset: .zero)
            .clamped(viewSize: CGSize(width: 200, height: 200),
                    imageSize: CGSize(width: 100, height: 50))
        #expect(tooBig.scale == ImageZoom.maxScale)
    }

    @Test("a degenerate view or image size clamps to no pan rather than dividing by zero")
    func degenerateSizesClampToNoPan() {
        let zoom = ImageZoom(scale: 4, offset: CGSize(width: 10, height: 10))
            .clamped(viewSize: .zero, imageSize: CGSize(width: 100, height: 50))
        #expect(zoom.offset == .zero)
        #expect(zoom.scale == 4)
    }

    // MARK: - quantizedScale

    @Test("a scale already on a step is returned unchanged")
    func quantizedScaleOnStepIsUnchanged() {
        for step in ImageZoom.thumbnailScaleSteps {
            #expect(ImageZoom.quantizedScale(step) == step)
        }
    }

    @Test("a scale between two steps rounds up to the next one")
    func quantizedScaleRoundsUpBetweenSteps() {
        #expect(ImageZoom.quantizedScale(1.2) == 2)
        #expect(ImageZoom.quantizedScale(2.01) == 4)
        #expect(ImageZoom.quantizedScale(3.99) == 4)
        #expect(ImageZoom.quantizedScale(5) == 8)
    }

    @Test("a scale outside the fit...maxScale range is bounded first")
    func quantizedScaleBoundsBeforeRounding() {
        #expect(ImageZoom.quantizedScale(0.1) == 1)
        #expect(ImageZoom.quantizedScale(999) == 8)
    }

    // MARK: - thumbnailMaxPixel

    @Test("a pinch's continuous scale collapses to one of a handful of requests")
    func maxPixelQuantisesContinuousScale() {
        // 1.2 and 1.9 both land on the same step (2) as an exact 2x request
        // would — this is what keeps a pinch from minting a new decode (and
        // a new cache entry) on every `onChanged` tick.
        let atStep = ImageZoom.thumbnailMaxPixel(base: 1040, scale: 2,
                                                  imageSize: CGSize(width: 4000, height: 3000))
        let justAbove = ImageZoom.thumbnailMaxPixel(base: 1040, scale: 1.2,
                                                     imageSize: CGSize(width: 4000, height: 3000))
        let justBelow = ImageZoom.thumbnailMaxPixel(base: 1040, scale: 1.9,
                                                     imageSize: CGSize(width: 4000, height: 3000))
        #expect(justAbove == atStep)
        #expect(justBelow == atStep)
    }

    @Test("requests grow with scale, up to the image's own size")
    func maxPixelGrowsWithScale() {
        let pixel = ImageZoom.thumbnailMaxPixel(base: 1040, scale: 2,
                                                imageSize: CGSize(width: 4000, height: 3000))
        #expect(pixel == 2080)
    }

    @Test("requests never exceed the image's own pixel size")
    func maxPixelNeverExceedsNativeSize() {
        let pixel = ImageZoom.thumbnailMaxPixel(base: 1040, scale: 8,
                                                imageSize: CGSize(width: 2000, height: 1500))
        #expect(pixel == 2000)
    }

    @Test("requests are bounded by the ceiling even for a huge image at max zoom")
    func maxPixelRespectsCeilingForHugeImages() {
        let pixel = ImageZoom.thumbnailMaxPixel(base: 1040, scale: 8,
                                                imageSize: CGSize(width: 8000, height: 6000))
        #expect(pixel == Int(ImageZoom.pixelCeiling))
    }

    @Test("at fit scale, the request is just the base size — unaffected by a tiny image")
    func maxPixelAtFitMatchesBase() {
        let pixel = ImageZoom.thumbnailMaxPixel(base: 1040, scale: 1,
                                                imageSize: CGSize(width: 50, height: 50))
        #expect(pixel == 1040)
    }
}

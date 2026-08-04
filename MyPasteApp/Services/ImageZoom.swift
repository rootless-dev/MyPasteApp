//
//  ImageZoom.swift
//  MyPasteApp
//

import CoreGraphics
import Foundation

/// The preview panel's zoom-and-pan state, and the geometry it implies.
///
/// `ItemPreviewView` draws the image aspect-fit and centred inside its
/// `GeometryReader`, then — while zoomed — scales that drawing about the
/// view's own centre and shifts it by `offset`. That's exactly the transform
/// `ImagePixel.pixel(at:viewSize:imageSize:)` assumes does NOT happen: it
/// maps a click straight to a pixel as if the image were still at `.fit`.
/// Rather than let the two silently disagree — a zoomed sample would read
/// whatever pixel happens to sit under the untransformed point, no crash, no
/// warning, just the wrong colour — this type is the one place that knows
/// the transform, and `unzoomed` is what lets the sampler keep using
/// `ImagePixel` unmodified: it turns a click in the zoomed view back into
/// the point it would be at `.fit`, then hands that to `ImagePixel` same as
/// before zoom existed.
///
/// A `scaleEffect`/`offset` pair living only in the view would have made
/// this invisible to `ImagePixel` entirely — nothing to call, nothing to
/// test, nothing to remind the next reader that the assumption changed.
struct ImageZoom: Equatable {
    /// 1 = drawn at fit size, centred, no pan.
    var scale: CGFloat
    /// Pan, in view points, applied after scaling about the view's centre.
    var offset: CGSize

    /// The state before any pinch, button press or drag: image at fit,
    /// centred. `unzoomed` is the identity at this value, by construction —
    /// see its own doc comment.
    static let fit = ImageZoom(scale: 1, offset: .zero)

    /// Never smaller than `.fit` — zooming "out" past the image already
    /// fitting the panel has nothing left to reveal.
    static let minScale: CGFloat = 1
    /// High enough to inspect fine detail, low enough that `clamped` and
    /// `thumbnailMaxPixel` never have to reason about a scale that makes a
    /// screenshot's own pixels bigger than the display can show usefully.
    static let maxScale: CGFloat = 8

    /// Undoes zoom and pan: turns a point in the zoomed view into the point
    /// it would be at if `self` were `.fit` — the space
    /// `ImagePixel.pixel(at:viewSize:imageSize:)` already reads correctly.
    ///
    /// Inverts the forward transform the view applies: scale the fit-space
    /// drawing about the view's centre, then shift it by `offset` —
    /// `zoomed = centre + (fit - centre) * scale + offset`. Solved for
    /// `fit`, that's the line below. At `scale == 1, offset == .zero` (i.e.
    /// `.fit`) this reduces to the identity, which is what makes the
    /// pre-zoom sampling path keep working unchanged.
    static func unzoomed(_ point: CGPoint,
                        viewSize: CGSize,
                        scale: CGFloat,
                        offset: CGSize) -> CGPoint {
        guard scale != 0 else { return point }
        let centre = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        return CGPoint(x: centre.x + (point.x - centre.x - offset.width) / scale,
                       y: centre.y + (point.y - centre.y - offset.height) / scale)
    }

    /// Keeps the scale in bounds and the image from panning off its own
    /// frame — called after every gesture update and every button press, so
    /// `zoom` is never observed outside these limits.
    ///
    /// On an axis where the drawn (post-scale) image is no bigger than the
    /// view, there's no image left to reveal by panning that axis — offset
    /// is forced to zero rather than merely bounded to a `[-0, 0]` range
    /// that would compute the same thing while hiding why. That's also what
    /// makes panning impossible at `.fit`: at `scale == minScale` the drawn
    /// image never exceeds the view on either axis, by definition of "fit".
    /// Above that, the offset is bounded so the image's own edge never
    /// crosses the view's — the panel never ends up showing background on a
    /// side the image could still have covered.
    func clamped(viewSize: CGSize, imageSize: CGSize) -> ImageZoom {
        let boundedScale = min(max(scale, Self.minScale), Self.maxScale)
        guard viewSize.width > 0, viewSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return ImageZoom(scale: boundedScale, offset: .zero)
        }

        let fitScale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let drawnWidth = imageSize.width * fitScale * boundedScale
        let drawnHeight = imageSize.height * fitScale * boundedScale

        let maxOffsetX = max(0, (drawnWidth - viewSize.width) / 2)
        let maxOffsetY = max(0, (drawnHeight - viewSize.height) / 2)

        return ImageZoom(scale: boundedScale,
                         offset: CGSize(width: min(max(offset.width, -maxOffsetX), maxOffsetX),
                                       height: min(max(offset.height, -maxOffsetY), maxOffsetY)))
    }

    // MARK: - Decode sizing

    /// Longest side, in pixels, the panel will ever ask `ImageThumbnailCache`
    /// to decode to, no matter how far zoomed in or how large the source is.
    ///
    /// A bitmap this size costs at most 4096×4096×4 bytes ≈ 67 MB (less for
    /// the panel's own non-square aspect) — already well past anything a
    /// 520×380pt panel makes visibly sharper, on any display density
    /// shipping today. Without this, an 8000×5000 scanned document at
    /// `maxScale` would ask for a bitmap bigger than the app decodes that
    /// image to *anywhere* else, for a difference nobody's eye could use.
    static let pixelCeiling: CGFloat = 4096

    /// The thumbnail decode size to request for the panel at a given zoom.
    ///
    /// `ImageThumbnailCache` decodes to the size the bitmap will actually be
    /// drawn at — see its own doc comment on why. At `.fit` that's `base`
    /// (the panel's own pixel size); zoomed in, drawing that same
    /// downsampled bitmap larger just magnifies its own softness, so the
    /// request grows with `scale`. Bounded twice: never past the image's own
    /// pixel size — `ImageIO` wouldn't upscale past it anyway (see
    /// `ImageThumbnailCache.downsample`), but asking would still mint a
    /// distinct, useless cache entry for every scale step past that point —
    /// and never past `pixelCeiling`.
    static func thumbnailMaxPixel(base: Int, scale: CGFloat, imageSize: CGSize) -> Int {
        guard base > 0 else { return 0 }
        let requested = CGFloat(base) * max(scale, minScale)
        let nativeMax = max(imageSize.width, imageSize.height)
        // `max(base, nativeMax)` keeps this from clamping *down* below
        // `base` for an image smaller than the panel's own base request —
        // that's the pre-existing, zoom-independent behaviour (ImageIO
        // just hands back the source's own size, unenlarged) and this
        // function has no business changing it.
        let cap = min(pixelCeiling, max(CGFloat(base), nativeMax))
        return Int(min(requested, cap).rounded())
    }
}

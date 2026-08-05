//
//  ItemPreviewView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI
import VisionKit

/// Which mode the image preview is in.
///
/// One at a time, always: two modes armed over the same image would leave a
/// click on it with two meanings. `.liveText` gets the exclusivity for free
/// from this being one value rather than two booleans.
enum PreviewImageMode {
    case none
    case sampler
    case liveText
}

/// The contents of the preview panel.
///
/// Follows design-refs/03-preview-web.png and 04-preview-imagem.png: a title
/// bar of its own with a circular close button, the type beside it, and the
/// item filling the rest.
struct ItemPreviewView: View {
    let item: ClipboardItem
    /// One instance per panel, owned by `PreviewPanelController` and passed
    /// in unchanged across rebuilds — see `PreviewChrome`'s doc comment for
    /// why `beakOffset` has to arrive this way instead of as a plain
    /// parameter.
    let chrome: PreviewChrome
    let onClose: () -> Void
    /// Copies a sampled colour. Owned by `OverlayWindowController`, which is
    /// what holds the `ClipboardWriter` — this view has no business knowing
    /// about pasteboards.
    var onCopyColor: (ColorCode) -> Void = { _ in }
    /// Opens the item editor. Only offered for images: text and URL already
    /// have ⌘E, and a second path to the same window is a second thing to
    /// keep in step.
    var onEdit: (() -> Void)? = nil

    @State private var mode: PreviewImageMode = .none
    @State private var copiedText: String?
    /// Live value, always the result of the last `.clamped(...)` call — see
    /// `ImageZoom`'s doc comment for why this state doesn't just live as a
    /// `scaleEffect`/`offset` on the view.
    @State private var zoom: ImageZoom = .fit
    /// The value `zoom` had when the current gesture began. A `MagnifyGesture`
    /// and a `DragGesture` each report a *cumulative* delta from wherever
    /// they started, not an increment since the last callback — multiplying
    /// or adding that delta onto `zoom` itself on every `onChanged` would
    /// compound it every frame. Read at the start of a gesture, written back
    /// only at its end (or by a button press, which is itself a complete,
    /// instantaneous gesture).
    @State private var zoomBaseline: ImageZoom = .fit
    /// Mirrors the image `GeometryReader`'s size, so the zoom buttons — built
    /// outside that reader, in `modeButtons`, to keep them positioned exactly
    /// like the sampler/Live Text buttons already there — can still call
    /// `ImageZoom.clamped`/`unzoomed` without threading the size through as a
    /// parameter. Empty until the first layout pass; the zoom buttons are
    /// harmless no-ops until then, same as any button pressed before a frame
    /// has ever been measured.
    @State private var previewViewSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                // The band that drags the window. Laid out *beside* the
                // content rather than over it — see `windowDragSurface`.
                .padding(Self.dragBandWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { windowDragSurface }
        }
        .frame(width: ItemPreviewPanel.contentSize.width, height: ItemPreviewPanel.contentSize.height)
        // Leaves the strip below the rounded body empty for the beak:
        // without it, content would run to the bottom of the window and
        // show through the triangle instead of leaving it as a clean point
        // of translucent material. A detached panel has no beak and no strip
        // — `PreviewPanelController.detachAnchored()` shrinks the window by
        // exactly this much at the same moment, so the two stay in step.
        .padding(.bottom, chrome.isDetached ? 0 : ItemPreviewPanel.beakHeight)
        .background {
            // No `.shadow` here. There used to be one, and it drew nothing at
            // all: the window frame is exactly this shape's bounding box, so a
            // shadow has no transparent margin inside the window to render
            // into, and the `.clipShape` below then clips the composite —
            // background included — to the very outline the shadow would have
            // been cast by. The panel's elevation comes from the *window*
            // shadow instead, which AppKit derives from this fill's alpha and
            // can therefore draw outside the frame. See
            // `ItemPreviewPanel.applyAppearance(to:)`.
            previewShape
                .fill(.regularMaterial)
        }
        // Same shape, same parameters as the background fill — see
        // `previewShape`'s doc comment for why a mismatch here would leak
        // content past the drawn outline.
        .clipShape(previewShape)
        // A zoom level chosen for one image has no business surviving onto
        // the next one the panel shows — arrowing through history at 4x
        // would otherwise keep every subsequent item cropped and blown up.
        .onChange(of: item.id) { resetZoom() }
        // A dimension-changing edit (rotate, then Save) rewrites `imageData`
        // under the same `id` — `OverlayWindowController` only rebuilds the
        // hosted view when the id changes, so this view (and its `zoom`
        // `@State`) survives the edit. Without this, a baseline and offset
        // clamped to the old dimensions could leave a gap on one axis until
        // the next gesture re-clamped it. `contentHash` moves with the bytes
        // (see `ImageThumbnailCache.key`'s doc comment for why it, not `id`,
        // is what tracks "the image actually changed"), so resetting on it
        // catches exactly this case without re-triggering on every
        // unrelated re-render.
        .onChange(of: item.contentHash) { resetZoom() }
    }

    /// The window's outline, shared by the background fill and the clip
    /// shape below so the two can never disagree about where the panel's
    /// edge is. `beakOffset` comes from `chrome`, not a parameter of this
    /// view — reading it here is what lets `PreviewPanelController` move the
    /// beak by mutating `chrome` alone, without this view (and the
    /// `NSHostingView` hosting it) ever being rebuilt. See `PreviewChrome`.
    private var previewShape: PreviewPanelShape {
        PreviewPanelShape(
            beakOffset: chrome.beakOffset,
            // Zero, not just a nil `beakOffset`, once detached:
            // `PreviewPanelShape` always reserves `beakHeight` at the base of
            // whatever rect it's given, so leaving 12 here would draw the body
            // 12pt short of a window that has already shed those 12 points —
            // a transparent gap along the bottom edge.
            beakHeight: chrome.isDetached ? 0 : ItemPreviewPanel.beakHeight,
            cornerRadius: ItemPreviewPanel.cornerRadius
        )
    }

    /// How wide the band that drags the window is, measured in from the
    /// panel's body on all four sides.
    private static let dragBandWidth: CGFloat = 10

    /// An invisible, hit-testable surface that drags the whole window.
    ///
    /// Used as the *background* of a body that has been inset by
    /// `dragBandWidth`, so the band and the previewed content never overlap.
    /// That matters: the image preview claims its whole container with a
    /// `.contentShape(Rectangle())` and two `.simultaneousGesture`s (zoom and
    /// pan), and the text preview hosts a selectable `NSTextView` — anything
    /// laid *over* either of those would have to win a fight for the same
    /// click, and would lose it in at least one of the two. Laid beside them,
    /// there is no fight. Empty space inside the body falls through to this
    /// too, which is the "or an empty part of the background" half of the
    /// gesture the user has to discover.
    ///
    /// `WindowDragGesture` is macOS 15+ and this app targets 26.2, so it needs
    /// no availability check. `ItemPreviewPanel.make()` also sets
    /// `isMovableByWindowBackground`; the two are belt and braces, and they
    /// can't fight because this band carries no other gesture for either of
    /// them to lose to.
    private var windowDragSurface: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Text(typeLabel)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if item.type == .image, let onEdit {
                Button("Edit") { onEdit() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
            }
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // The header is the obvious place to grab a window by, so it drags
        // too — including the gaps between its controls, which is what
        // `.contentShape` is for. The buttons keep working: SwiftUI resolves a
        // child's own gesture before an ancestor's `.gesture`.
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
    }

    @ViewBuilder
    private var content: some View {
        switch item.type {
        case .text, .url:
            if let code = item.textContent, let color = ColorCode.parse(code) {
                ColorSwatchView(color: color, code: code)
                    .padding(12)
            } else {
                // The whole thing, scrollable. This is the limitation the item exists to
                // fix: the card truncates at previewTextLength and eight lines, so long
                // text simply isn't readable in the app. Rich text data goes along too,
                // so an item with formatting renders formatted here the same way the
                // editor already shows it — see TextPreviewView.content.
                TextPreviewView(text: item.textContent ?? "",
                                 richTextData: item.richTextData,
                                 richTextFormat: item.richTextFormat)
            }
        case .image:
            if let data = item.imageData {
                // Scaled to fit the panel rather than shown at natural size in
                // a ScrollView: a 1920x1080 screenshot filled the panel with
                // its top-left corner and made the reader scroll to see any of
                // it. The point of the preview is seeing the whole thing at
                // once — the dimensions in the header say what was given up.
                GeometryReader { geometry in
                    // Non-optional for the gesture/clamp math below, which
                    // already treats `.zero` the same as "unknown" — see
                    // `ImageZoom.clamped`.
                    let pixelSize = imageSize ?? .zero
                    Group {
                        if mode == .liveText {
                            // Draws its own image rather than sitting on top of
                            // ThumbnailImage's — see LiveTextOverlay's doc comment
                            // for why that's what keeps the selection boxes aligned.
                            // Deliberately NOT zoomed: LiveTextOverlay hosts its own
                            // NSImageView as `trackingImageView` so VisionKit's
                            // selection boxes line up with it exactly; scaling this
                            // branch would need the overlay's geometry taught the
                            // same transform ImagePixel had to learn, for a mode
                            // where "zoom in, then select" is already redundant
                            // with VisionKit's own text-relative selection. The
                            // zoom controls hide themselves while this mode is on
                            // (see `modeButtons`) rather than sit there doing
                            // nothing.
                            LiveTextOverlay(data: data)
                        } else {
                            ThumbnailImage(
                                data: data,
                                id: item.id,
                                contentHash: item.contentHash,
                                maxPixel: ImageZoom.thumbnailMaxPixel(
                                    base: ImageThumbnailCache.pixels(for: ItemPreviewPanel.contentSize),
                                    scale: zoom.scale,
                                    imageSize: pixelSize
                                )
                            ) {
                                Text(item.preview).font(.caption)
                            }
                            // About the view's own centre, same as
                            // `ImageZoom.unzoomed` assumes — see its doc comment.
                            .scaleEffect(zoom.scale)
                            .offset(zoom.offset)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // The whole point of zoom is a peephole: a scaled-up
                    // image is deliberately bigger than this frame, with
                    // `offset` choosing which part shows. Without clipping,
                    // SwiftUI draws the overflow anyway — bleeding over the
                    // header and the mode buttons instead of being cropped
                    // to what `clamped` already guarantees is a valid,
                    // fully-covering view of the image.
                    .clipped()
                    .background(CheckerboardBackground())
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        // `set()`, never `push()`/`pop()`: those two are a
                        // manually balanced global stack, and this view has
                        // no reliable moment to pop — a click that disarms
                        // the mode fires no hover event, and a re-render can
                        // re-enter a session that was already entered.
                        // `set()` owns the cursor for as long as the pointer
                        // keeps moving over this view and needs no matching
                        // call, so nothing can leak out to the rest of the
                        // app.
                        guard case .active = phase, mode == .sampler else { return }
                        NSCursor.crosshair.set()
                    }
                    .onTapGesture { location in
                        sample(at: location, in: geometry.size, data: data)
                    }
                    // Pinch and drag are additive to the tap above, not a
                    // replacement for it: `MagnifyGesture` only recognises an
                    // actual pinch, and the drag below needs 2pt of movement
                    // before it recognises anything, so a plain click still
                    // reaches `onTapGesture` for sampling. `.simultaneousGesture`
                    // rather than `.gesture` is what keeps them from competing
                    // over the same click in the first place.
                    //
                    // Attached here, on the shared `Group`, rather than only
                    // inside the `mode != .liveText` branch above: the
                    // recognizers still need to exist while Live Text is
                    // armed so a drag or pinch that starts there doesn't leak
                    // through to whatever's behind the panel. What must not
                    // happen while Live Text is armed is `zoom` itself
                    // changing — each gesture's own `mode != .liveText` guard
                    // (see `magnifyGesture`/`panGesture`) is what holds that.
                    .simultaneousGesture(magnifyGesture(viewSize: geometry.size, imageSize: pixelSize))
                    .simultaneousGesture(panGesture(viewSize: geometry.size, imageSize: pixelSize))
                    .onAppear { previewViewSize = geometry.size }
                    .onChange(of: geometry.size) { _, newSize in previewViewSize = newSize }
                }
                .padding(12)
                .overlay(alignment: .bottomTrailing) { modeButtons }
                .overlay(alignment: .top) { copiedBanner }
            } else {
                Text(item.preview).font(.caption)
            }
        case .file:
            if let path = item.fileURLStrings?.first {
                VStack(spacing: 8) {
                    FilePreviewView(path: path)
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(12)
            }
        }
    }

    private var typeLabel: String {
        switch item.type {
        case .text:  return "Texto"
        case .url:   return "URL"
        case .image: return "Imagem"
        case .file:  return "Arquivo"
        }
    }

    private var footnote: String? {
        switch item.type {
        case .text, .url:
            return "\(item.textContent?.count ?? 0) caracteres"
        case .image:
            guard let size = imageSize else { return nil }
            return "\(Int(size.width)) × \(Int(size.height))"
        case .file:
            return nil
        }
    }

    /// Pixel size of the current image, read from the file header — cheap,
    /// see `ImageMetadata.pixelSize`. `nil` when `item` isn't an image or the
    /// data can't be read; every zoom call site treats that the same as
    /// `.zero`, which `ImageZoom.clamped`/`thumbnailMaxPixel` both already
    /// handle without dividing by it.
    private var imageSize: CGSize? {
        guard let data = item.imageData else { return nil }
        return ImageMetadata.pixelSize(of: data)
    }

    // MARK: - Sampling

    /// Turns a click into a colour, then turns the mode off.
    ///
    /// One sample per arming, on purpose: a mode that stays on is a mode the
    /// user forgets is on, and every later click silently replaces the
    /// pasteboard.
    private func sample(at location: CGPoint, in viewSize: CGSize, data: Data) {
        guard mode == .sampler else { return }
        // The click lands in the *zoomed* view; ImagePixel only knows how to
        // read a point in the fit-and-centred one. Without this, sampling
        // while zoomed in would silently read whatever pixel happens to sit
        // under the untransformed coordinate — see ImageZoom's doc comment.
        let point = ImageZoom.unzoomed(location, viewSize: viewSize,
                                       scale: zoom.scale, offset: zoom.offset)
        guard let size = ImageMetadata.pixelSize(of: data),
              let pixel = ImagePixel.pixel(at: point, viewSize: viewSize, imageSize: size),
              let color = ImagePixel.color(in: data, x: pixel.x, y: pixel.y)
        else { return }

        onCopyColor(color)
        mode = .none
        show(copied: color.formatted(as: .hex))
    }

    private func show(copied text: String) {
        copiedText = text
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if copiedText == text { copiedText = nil }
        }
    }

    // MARK: - Zoom

    /// How much a single `+`/`−` press changes the scale by. Multiplicative
    /// rather than a fixed increment so it feels like the same-sized step at
    /// any zoom level, the way pinch-to-zoom already does.
    private static let zoomButtonStep: CGFloat = 1.5

    /// Recognises a pinch and updates `zoom.scale` live as it happens.
    ///
    /// `value.magnification` is cumulative from wherever the gesture
    /// started, not incremental — see `zoomBaseline`'s doc comment for why
    /// this multiplies onto the baseline rather than onto `zoom` itself.
    private func magnifyGesture(viewSize: CGSize, imageSize: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // Live Text draws its own un-zoomed image (see the doc
                // comment at the call site) and hides the zoom buttons — a
                // pinch recognised over that overlay must not move `zoom`
                // either, or leaving Live Text would snap the image to
                // whatever silently accumulated while nothing on screen
                // visibly changed. The gesture recognizer itself still lives
                // on the shared `Group`, so this guard is what actually
                // holds the invariant, not the branch in `content`.
                guard mode != .liveText else { return }
                zoom = ImageZoom(scale: zoomBaseline.scale * value.magnification,
                                 offset: zoomBaseline.offset)
                    .clamped(viewSize: viewSize, imageSize: imageSize)
            }
            .onEnded { _ in
                guard mode != .liveText else { return }
                zoomBaseline = zoom
            }
    }

    /// Recognises a drag and pans the image by it.
    ///
    /// No explicit "only while zoomed" guard is needed for correctness:
    /// `clamped` forces `offset` to `.zero` whenever the drawn image is no
    /// bigger than the view on an axis, which is exactly the situation at
    /// `.fit`. The guard here just skips the arithmetic in that case rather
    /// than computing an offset that's going to be clamped straight back to
    /// zero anyway.
    private func panGesture(viewSize: CGSize, imageSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                // Same reasoning as `magnifyGesture`'s guard: a drag
                // recognised over the Live Text overlay must not move
                // `zoom`, or leaving Live Text would silently pan to
                // wherever the drag ended.
                guard mode != .liveText, zoom.scale > ImageZoom.minScale else { return }
                zoom = ImageZoom(
                    scale: zoomBaseline.scale,
                    offset: CGSize(width: zoomBaseline.offset.width + value.translation.width,
                                   height: zoomBaseline.offset.height + value.translation.height)
                ).clamped(viewSize: viewSize, imageSize: imageSize)
            }
            .onEnded { _ in
                guard mode != .liveText else { return }
                zoomBaseline = zoom
            }
    }

    /// Applied by both `+`/`−` buttons — a button press is a complete,
    /// instantaneous gesture, so it writes `zoomBaseline` immediately rather
    /// than waiting for an `onEnded` that will never come.
    private func stepZoom(by factor: CGFloat) {
        let target = ImageZoom(scale: zoom.scale * factor, offset: zoom.offset)
        zoom = target.clamped(viewSize: previewViewSize, imageSize: imageSize ?? .zero)
        zoomBaseline = zoom
    }

    private func resetZoom() {
        zoom = .fit
        zoomBaseline = .fit
    }

    // MARK: - Overlays

    private var modeButtons: some View {
        HStack(spacing: 6) {
            modeButton(systemName: "eyedropper",
                       help: "Sample a colour from this image",
                       isOn: mode == .sampler) {
                mode = mode == .sampler ? .none : .sampler
            }
            if ImageAnalyzer.isSupported {
                modeButton(systemName: "text.viewfinder",
                           help: "Select text in this image",
                           isOn: mode == .liveText) {
                    mode = mode == .liveText ? .none : .liveText
                }
            }
            // Hidden rather than disabled while Live Text is on: that mode
            // draws its own un-zoomed image (see the doc comment where
            // LiveTextOverlay is used), so a zoom control here would look
            // clickable while doing nothing to what's on screen.
            if mode != .liveText {
                zoomButtons
            }
        }
        .padding(18)
    }

    @ViewBuilder
    private var zoomButtons: some View {
        modeButton(systemName: "minus.magnifyingglass",
                   help: "Zoom out",
                   isOn: false,
                   enabled: zoom.scale > ImageZoom.minScale) {
            stepZoom(by: 1 / Self.zoomButtonStep)
        }
        modeButton(systemName: "plus.magnifyingglass",
                   help: "Zoom in",
                   isOn: false,
                   enabled: zoom.scale < ImageZoom.maxScale) {
            stepZoom(by: Self.zoomButtonStep)
        }
        // Only while actually zoomed — a fit-scale image has nothing to
        // reset, and a button that's always there is one more thing on
        // screen for no reason most of the time.
        if zoom.scale > ImageZoom.minScale {
            modeButton(systemName: "arrow.up.left.and.down.right.magnifyingglass",
                       help: "Zoom to fit",
                       isOn: false) {
                resetZoom()
            }
        }
    }

    private func modeButton(systemName: String,
                            help: String,
                            isOn: Bool,
                            enabled: Bool = true,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? .white : .primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(isOn ? Color.accentColor : Color.black.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .help(help)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    @ViewBuilder
    private var copiedBanner: some View {
        if let copiedText {
            Text("Copied \(copiedText)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.7)))
                .foregroundStyle(.white)
                .padding(.top, 18)
                .transition(.opacity)
        }
    }
}

/// The conventional way to show that an image has transparency.
struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 8
            let rows = Int(size.height / square) + 1
            let columns = Int(size.width / square) + 1
            for row in 0..<rows {
                for column in 0..<columns {
                    guard (row + column).isMultiple(of: 2) else { continue }
                    let rect = CGRect(x: CGFloat(column) * square,
                                      y: CGFloat(row) * square,
                                      width: square,
                                      height: square)
                    context.fill(Path(rect), with: .color(.gray.opacity(0.25)))
                }
            }
        }
    }
}

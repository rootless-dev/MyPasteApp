//
//  LiveTextOverlay.swift
//  MyPasteApp
//

import AppKit
import SwiftUI
import VisionKit

/// The system's Live Text layer, and the image it reads.
///
/// Not the same thing as `OCRService`, and not a replacement for it: that one
/// extracts `ocrText` to feed the search — text with no position, good for
/// *finding* an image. This is selection *inside* an image that's already
/// open, and it brings "Copy All", data detectors and translation from the
/// system.
///
/// **It draws the image itself**, rather than sitting on top of the SwiftUI
/// one. `ImageAnalysisOverlayView` aligns its text boxes to a
/// `trackingImageView`; with no tracked view it falls back to its own bounds,
/// and since the preview scales the image to fit, every selection box would
/// land offset by the empty margin. Hosting the `NSImageView` here is what
/// makes the geometry exact. The cost — the original image decoded while the
/// mode is on — is paid only while the mode is on.
struct LiveTextOverlay: NSViewRepresentable {
    /// The original image data, never the downsampled thumbnail: small text
    /// disappears in the downsample, and screenshots are the whole point.
    let data: Data

    func makeNSView(context: Context) -> NSView {
        let container = NSView()

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = NSImage(data: data)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        let overlay = ImageAnalysisOverlayView()
        overlay.trackingImageView = imageView
        overlay.preferredInteractionTypes = [.textSelection]
        overlay.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(overlay)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.analyse(data: data, into: overlay)
        return container
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let overlay = view.subviews.compactMap({ $0 as? ImageAnalysisOverlayView }).first
        else { return }
        // Analysis runs once per image: `updateNSView` fires on every SwiftUI
        // update, and re-analysing each time would throw away the selection
        // the user just made and pay for the analysis again.
        context.coordinator.analyse(data: data, into: overlay)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private let analyzer = ImageAnalyzer()
        private var analysedData: Data?
        private var task: Task<Void, Never>?

        @MainActor
        func analyse(data: Data, into view: ImageAnalysisOverlayView) {
            guard analysedData != data, let image = NSImage(data: data) else { return }
            analysedData = data
            task?.cancel()
            task = Task { [analyzer] in
                let configuration = ImageAnalyzer.Configuration([.text])
                // This SDK's `analyze` has no orientation-less overload — unlike
                // what the brief assumed. `.up` is correct here because NSImage
                // already renders the pixels pre-rotated according to any EXIF
                // orientation; there's no separate orientation left to tell it.
                guard let analysis = try? await analyzer.analyze(
                    image, orientation: .up, configuration: configuration
                ) else { return }
                view.analysis = analysis
            }
        }
    }
}

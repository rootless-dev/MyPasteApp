//
//  PreviewChrome.swift
//  MyPasteApp
//

import Foundation
import SwiftUI

/// The parts of the preview panel's outline that change more often than its
/// content should be rebuilt.
///
/// `PreviewPanelController.applyPreviewContent` deliberately does not rebuild
/// `ItemPreviewView`'s `NSHostingView` on every selection change — see
/// `previewDisplayedItemID`'s doc comment: rebuilding threw away the panel's
/// own scroll position and text selection, and allocated a fresh hosting view
/// per frame. But `beakOffset` has to update on every one of those same
/// moments (selection changes, and every scroll tick besides), because it's
/// the thing that keeps the beak pointing at the card. `PreviewChrome` is how
/// that value reaches the already-built view without a rebuild: the
/// controller holds one instance per panel, passes it into `ItemPreviewView`
/// once, and mutates it afterwards. `@Observable` (not `ObservableObject` —
/// see `SearchState`, which this follows) does the rest: the view's body
/// re-evaluates on the mutation, the hosting view underneath never does.
@Observable
@MainActor
final class PreviewChrome {
    /// Where the beak's tip should point, in the same coordinate space
    /// `PreviewPanelShape` draws in — see `PreviewPlacement.Result.beakOffset`.
    /// `nil` when the panel can't point at the card at all (edge of screen,
    /// card too close to a rounded corner), matching what
    /// `PreviewPanelShape.beakOffset` does with `nil`: draw the body with no
    /// beak.
    var beakOffset: CGFloat?

    /// Whether this panel has been dragged off the drawer into its own
    /// independent window.
    ///
    /// Written once, by `PreviewPanelController.detachAnchored()`, and never
    /// back: a detached panel stays detached for the rest of its life.
    /// `ItemPreviewView` reads it twice, and both readings are about the
    /// 12pt strip the beak used to occupy — the bottom padding that reserved
    /// it, and the `beakHeight` handed to `PreviewPanelShape`. The window
    /// itself sheds those same 12 points in the same call, which is what
    /// keeps the drawn shape and the window's frame agreeing about where the
    /// bottom edge is.
    var isDetached = false
}

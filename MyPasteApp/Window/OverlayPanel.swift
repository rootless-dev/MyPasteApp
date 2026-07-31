//
//  OverlayPanel.swift
//  MyPasteApp
//

import AppKit

/// The overlay's window.
///
/// Exists for one reason: AppKit refuses key-window status to borderless
/// windows, and the overlay is `.borderless` by design. Without this override
/// `makeKey()` silently does nothing, the panel never becomes key, and it
/// receives no keyboard events at all — every keystroke keeps going to the
/// app the user summoned the overlay over. Arrow navigation, Return, Escape,
/// ⌘P, the ⌘1–⌘9 shortcuts and typing in the search field all depend on this.
///
/// `canBecomeMain` is deliberately left alone. Key without main is exactly
/// what a `.nonactivatingPanel` wants: the overlay takes the keystrokes while
/// the app underneath keeps its main window, so the paste still lands where
/// the user expects.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

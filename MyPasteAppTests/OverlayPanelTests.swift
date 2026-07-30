//
//  OverlayPanelTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing

@testable import MyPasteApp

@MainActor
@Suite("Overlay panel")
struct OverlayPanelTests {
    private static let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]

    private func makePanel<P: NSPanel>(_ type: P.Type) -> P {
        P(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 320),
            styleMask: Self.styleMask,
            backing: .buffered,
            defer: false
        )
    }

    @Test("A plain borderless panel refuses to become key")
    func plainPanelCannotBecomeKey() {
        // This is why OverlayPanel exists, and the regression this suite
        // guards: AppKit denies key status to borderless windows, so
        // `makeKey()` silently does nothing and the panel never receives a
        // single keystroke — no arrows, no Return, no ⌘-shortcuts, and no
        // typing in the search field.
        let panel = makePanel(NSPanel.self)
        #expect(panel.canBecomeKey == false)
    }

    @Test("The overlay panel can become key despite being borderless")
    func overlayPanelCanBecomeKey() {
        let panel = makePanel(OverlayPanel.self)
        #expect(panel.canBecomeKey)
    }

    @Test("The overlay panel still refuses to become main")
    func overlayPanelDoesNotBecomeMain() {
        // Key without main is the combination we want: the panel takes
        // keystrokes while the app it was summoned over keeps its main
        // window, so the paste still lands in the right place.
        let panel = makePanel(OverlayPanel.self)
        #expect(panel.canBecomeMain == false)
    }
}

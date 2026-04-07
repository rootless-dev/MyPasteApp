//
//  AppDelegate.swift
//  MyPasteApp
//

import AppKit
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var modelContainer: ModelContainer!
    var monitor: ClipboardMonitor!
    var writer: ClipboardWriter!
    var hotkey: HotkeyManager!
    var overlay: OverlayWindowController!
    var retention: RetentionPolicy!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            modelContainer = try ModelContainer(for: ClipboardItem.self)
        } catch {
            NSLog("Failed to create ModelContainer: \(error)")
            return
        }

        let context = modelContainer.mainContext
        monitor = ClipboardMonitor(modelContext: context)
        writer = ClipboardWriter(monitor: monitor)
        retention = RetentionPolicy(modelContext: context)

        overlay = OverlayWindowController(modelContainer: modelContainer) { [weak self] item in
            self?.writer.write(item)
        }

        hotkey = HotkeyManager { [weak self] in
            self?.overlay.toggle()
        }

        setupStatusItem()

        monitor.start()
        hotkey.register()
        retention.prune()

    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MyPasteApp")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if isRight {
            showStatusMenu()
        } else {
            overlay.toggle()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        let show = NSMenuItem(title: "Mostrar histórico  ⌘⇧V",
                              action: #selector(showHistoryAction),
                              keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let prefs = NSMenuItem(title: "Preferências…",
                               action: #selector(openPreferences),
                               keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Sair",
                              action: #selector(quitAction),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func showHistoryAction() {
        overlay.toggle()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    @objc private func openPreferences() {
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        hotkey?.unregister()
    }
}

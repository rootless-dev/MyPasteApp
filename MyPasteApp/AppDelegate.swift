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
    var pauseController: PauseController!
    var writer: ClipboardWriter!
    var hotkey: HotkeyManager!
    var overlay: OverlayWindowController!
    var retention: RetentionPolicy!
    var statusItem: NSStatusItem!
    private var prefsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests launch this app as their test host. Skip the real setup so
        // they don't open the user's store, grab the global hotkey or start
        // polling the pasteboard.
        if Self.isRunningUnitTests { return }

        do {
            modelContainer = try ModelContainer(for: ClipboardItem.self)
        } catch {
            NSLog("Failed to create ModelContainer: \(error)")
            return
        }

        let context = modelContainer.mainContext
        pauseController = PauseController()
        monitor = ClipboardMonitor(modelContext: context)
        monitor.pauseController = pauseController

        // The pause used to live in UserDefaults. It doesn't survive a
        // restart any more, so the leftover key is cleared instead of being
        // read by nobody.
        UserDefaults.standard.removeObject(forKey: "monitoringPaused")

        writer = ClipboardWriter(monitor: monitor)
        retention = RetentionPolicy(modelContext: context)

        overlay = OverlayWindowController(modelContainer: modelContainer) { [weak self] item in
            self?.writer.write(item)
        }
        // Pre-warm the panel: create the window and force SwiftUI's initial
        // layout now, so that the first hotkey press doesn't pay that cost
        // during the open animation.
        overlay.prepare()

        hotkey = HotkeyManager(id: .overlay,
                               storageKey: KeyCombo.storageKey,
                               fallback: .default) { [weak self] in
            self?.overlay.toggle()
        }

        setupStatusItem()

        monitor.start()
        hotkey.register()
        retention.prune()

        NotificationCenter.default.addObserver(
            forName: .hotkeyChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Older posts carried no key; treat them as the overlay one.
                let key = note.userInfo?["key"] as? String ?? KeyCombo.storageKey
                if key == KeyCombo.storageKey {
                    self.hotkey.register()
                }
            }
        }
    }

    private static var isRunningUnitTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
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
        let show = NSMenuItem(title: "Show history  \(KeyCombo.stored.displayString)",
                              action: #selector(showHistoryAction),
                              keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let pause = NSMenuItem(title: pauseController.isPaused
                                ? "Resume clipboard monitoring"
                                : "Pause clipboard monitoring",
                               action: #selector(togglePauseAction),
                               keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        menu.addItem(.separator())
        let prefs = NSMenuItem(title: "Preferences…",
                               action: #selector(openPreferences),
                               keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit",
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

    @objc private func togglePauseAction() {
        pauseController.toggle()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    @objc private func openPreferences() {
        if prefsWindow == nil {
            let view = PreferencesView()
                .modelContainer(modelContainer)
            let host = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: host)
            window.title = "Preferences"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            prefsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        prefsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        hotkey?.unregister()
    }
}

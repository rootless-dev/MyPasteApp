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
    var pauseHotkey: HotkeyManager!
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

        pauseHotkey = HotkeyManager(id: .pause,
                                    storageKey: KeyCombo.pauseStorageKey,
                                    fallback: .pauseDefault) { [weak self] in
            self?.pauseController.toggle()
        }

        setupStatusItem()

        monitor.start()
        hotkey.register()
        pauseHotkey.register()
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
                switch key {
                case KeyCombo.storageKey: self.hotkey.register()
                case KeyCombo.pauseStorageKey: self.pauseHotkey.register()
                default: break
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
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refreshStatusIcon()

        NotificationCenter.default.addObserver(
            forName: PauseController.stateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshStatusIcon() }
        }
    }

    /// The icon has to say, unmistakably, that nothing is being collected.
    /// Dimming the same glyph would be too easy to miss — and missing it here
    /// costs hours of lost history.
    private func refreshStatusIcon() {
        guard let button = statusItem?.button else { return }
        let paused = pauseController.isPaused
        button.image = NSImage(
            systemSymbolName: paused ? "pause.circle.fill" : "doc.on.clipboard",
            accessibilityDescription: paused ? "MyPasteApp — paused" : "MyPasteApp"
        )
        button.toolTip = paused ? pauseStatusTitle : "MyPasteApp"
    }

    private var pauseStatusTitle: String {
        switch pauseController.state {
        case .active:
            return "MyPasteApp"
        case .pausedIndefinitely:
            return "Paused"
        case .pausedUntil(let deadline):
            return "Paused until \(deadline.formatted(.dateTime.hour().minute()))"
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
        for item in pauseMenuItems() {
            menu.addItem(item)
        }
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

    /// Built fresh on every menu opening — `showStatusMenu` rebuilds the whole
    /// NSMenu each time — so there is no state to keep in sync here.
    private func pauseMenuItems() -> [NSMenuItem] {
        guard !pauseController.isPaused else {
            // No target and no action, so NSMenu's automatic enabling leaves
            // this one greyed out as the status line it is.
            let status = NSMenuItem(title: pauseStatusTitle,
                                    action: nil,
                                    keyEquivalent: "")
            let resume = NSMenuItem(title: "Resume clipboard monitoring",
                                    action: #selector(togglePauseAction),
                                    keyEquivalent: "")
            resume.target = self
            return [status, resume]
        }

        let pause = NSMenuItem(title: "Pause clipboard monitoring",
                               action: nil,
                               keyEquivalent: "")
        let submenu = NSMenu()

        let indefinite = NSMenuItem(title: "Pause",
                                    action: #selector(togglePauseAction),
                                    keyEquivalent: "")
        indefinite.target = self
        submenu.addItem(indefinite)
        submenu.addItem(.separator())

        for duration in PauseDuration.offered {
            let item = NSMenuItem(title: duration.title,
                                  action: #selector(pauseForAction(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = duration.seconds
            submenu.addItem(item)
        }

        pause.submenu = submenu
        return [pause]
    }

    @objc private func pauseForAction(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        pauseController.pause(for: PauseDuration(seconds: seconds))
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
        pauseHotkey?.unregister()
    }
}

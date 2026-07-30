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

    /// Whether `overlay`'s hotkey is actually live right now. `false` when
    /// `HotkeyManager.register()` reports that `RegisterEventHotKey` failed —
    /// most often because another app already owns the combination — so the
    /// menu never advertises a shortcut that won't fire.
    private var overlayHotkeyRegistered = false

    /// Whether `pauseHotkey` is actually live right now. `false` covers two
    /// distinct cases: the two shortcuts collide and
    /// `registerHotkeysCheckingConflict()` left it unregistered on purpose,
    /// or `RegisterEventHotKey` itself failed (e.g. some other app already
    /// owns the combination). Either way the shortcut won't fire, so the menu
    /// reads this single flag to decide whether to advertise it.
    private var pauseHotkeyRegistered = false

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

        overlay = OverlayWindowController(modelContainer: modelContainer) { [weak self] item, plainText in
            self?.writer.write(item, plainText: plainText)
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
        registerHotkeysCheckingConflict()
        retention.prune()

        NotificationCenter.default.addObserver(
            forName: .hotkeyChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // Whichever field changed, re-derive both from what's on disk
                // and (re)register accordingly. That's the same check done at
                // launch, and it's what re-registers the *other* shortcut when
                // this edit is the one that resolved a collision between them
                // — registering a single shortcut here left the other one
                // dead until relaunch.
                self?.registerHotkeysCheckingConflict()
            }
        }

        // The user flips this preference from inside the Preferences window
        // itself; without this the change would only take effect the next time
        // the window opened, which reads as "the toggle did nothing".
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applySharingPolicy() }
        }
    }

    private static var isRunningUnitTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
    }

    /// Registers both global shortcuts, unless they collide.
    ///
    /// `ShortcutsSettingsView.applyHotkeyChange` refuses to save a colliding combo,
    /// but that guard never runs on a combo that was already on disk before
    /// this version existed — e.g. someone who'd bound the overlay shortcut
    /// to ⌘⇧P upgrading into a `pauseHotkey` that, being unset, falls back to
    /// `KeyCombo.pauseDefault`, which is also ⌘⇧P. Registering both anyway
    /// would leave `RegisterEventHotKey` to fail for the second one with
    /// nothing but an `NSLog` to show for it. The overlay shortcut is treated
    /// as the pre-existing one and wins; the pause one is simply left
    /// unregistered. Preferences re-derives this same comparison from what's
    /// on disk every time it's opened (see `ShortcutsSettingsView.refreshHotkeyState`),
    /// so the user is told which shortcut is dead instead of only the log.
    private func registerHotkeysCheckingConflict() {
        overlayHotkeyRegistered = hotkey.register()
        guard !KeyCombo.conflicts(hotkey.storedCombo, with: pauseHotkey.storedCombo) else {
            NSLog("Pause hotkey (\(pauseHotkey.storedCombo.displayString)) collides with the "
                  + "overlay shortcut; leaving it unregistered until Preferences resolves it.")
            pauseHotkeyRegistered = false
            return
        }
        pauseHotkeyRegistered = pauseHotkey.register()
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
            return "Paused indefinitely"
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
        // Only advertise the shortcut when it actually registered. Another app
        // owning the combination leaves it dead, and a menu that still shows it
        // sends the user looking for a bug in the wrong place.
        let showSuffix = overlayHotkeyRegistered ? "  \(KeyCombo.stored.displayString)" : ""
        let show = NSMenuItem(title: "Show history\(showSuffix)",
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
        // Only advertise the shortcut while it's actually registered — during
        // a launch-time collision `registerHotkeysCheckingConflict` leaves it
        // dead, and telling the user to press a combo that won't fire is
        // worse than not mentioning one at all.
        let comboSuffix = pauseHotkeyRegistered ? "  \(KeyCombo.storedPause.displayString)" : ""

        guard !pauseController.isPaused else {
            // No target and no action, so NSMenu's automatic enabling leaves
            // this one greyed out as the status line it is.
            let status = NSMenuItem(title: pauseStatusTitle,
                                    action: nil,
                                    keyEquivalent: "")
            let resume = NSMenuItem(title: "Resume clipboard monitoring\(comboSuffix)",
                                    action: #selector(togglePauseAction),
                                    keyEquivalent: "")
            resume.target = self
            return [status, resume]
        }

        let pause = NSMenuItem(title: "Pause clipboard monitoring",
                               action: nil,
                               keyEquivalent: "")
        let submenu = NSMenu()

        let indefinite = NSMenuItem(title: "Pause\(comboSuffix)",
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
            let view = SettingsView()
                .modelContainer(modelContainer)
            let host = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: host)
            window.title = "Preferences"
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            window.center()
            prefsWindow = window
        }
        prefsWindow?.sharingType = WindowPrivacy.sharingType()
        NSApp.activate(ignoringOtherApps: true)
        prefsWindow?.makeKeyAndOrderFront(nil)
    }

    private func applySharingPolicy() {
        overlay?.applySharingPolicy()
        prefsWindow?.sharingType = WindowPrivacy.sharingType()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        hotkey?.unregister()
        pauseHotkey?.unregister()
    }
}

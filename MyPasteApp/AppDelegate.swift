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
    var itemEditor: ItemEditorWindowController!
    var retention: RetentionPolicy!
    var statusItem: NSStatusItem!
    private var prefsWindow: NSWindow?
    /// Kept so it can be invalidated — see `startRetentionTimer()`.
    private var retentionTimer: Timer?

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
            // Both models, explicitly. SwiftData only infers what it can reach
            // from this list — a `Pinboard` left out here compiles fine and
            // then traps on the first write to the relationship.
            modelContainer = try ModelContainer(for: ClipboardItem.self, Pinboard.self)
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
        itemEditor = ItemEditorWindowController(modelContainer: modelContainer)

        overlay = OverlayWindowController(
            modelContainer: modelContainer,
            writer: writer,
            itemEditor: itemEditor,
            onPick: { [weak self] item, plainText in
                self?.writer.write(item, plainText: plainText)
            },
            onPickMultiple: { [weak self] items, plainText in
                let separator = MultiPasteSeparator.resolve(
                    UserDefaults.standard.string(forKey: PreferenceKeys.multiPasteSeparator))
                self?.writer.writeJoined(items, separator: separator, plainText: plainText)
            }
        )
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
        startRetentionTimer()

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

    /// How often the pruner runs while the app is up.
    ///
    /// The launch pass alone was the whole schedule, which is no schedule at
    /// all for a status-bar app that stays up for weeks: "Expire in 1 hour"
    /// meant "expires at the next relaunch", and an item the user marked to
    /// disappear could sit in the history for days. Five minutes is well
    /// under the shortest expiry the menu offers (1 hour) and cheap — the
    /// pruner fetches at most `maxItems` rows whose heavy fields are
    /// `.externalStorage`, so they aren't loaded.
    private static let retentionInterval: TimeInterval = 5 * 60

    /// Starts the periodic prune, keeping the launch pass as it was.
    ///
    /// `.common` run-loop mode, like `ClipboardMonitor`'s timer: on the
    /// default mode alone the timer stops firing for as long as a menu is
    /// open, which for a status-bar app is exactly when the user is looking.
    private func startRetentionTimer() {
        retentionTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: Self.retentionInterval,
                                         repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.retention?.prune() }
        }
        RunLoop.main.add(timer, forMode: .common)
        retentionTimer = timer
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
        // A plain NSMenuItem keyEquivalent, unlike `hotkey`/`pauseHotkey`: it
        // only needs to fire while this menu is open, so there's no global
        // registration to fail and nothing to gate on here — see
        // `overlayHotkeyRegistered` above for the shortcut that does need it.
        let newItem = NSMenuItem(title: "New Text Item",
                                 action: #selector(newItemAction),
                                 keyEquivalent: "n")
        newItem.target = self
        menu.addItem(newItem)
        let pickColor = NSMenuItem(title: "Pick Color from Screen",
                                   action: #selector(pickColorAction),
                                   keyEquivalent: "")
        pickColor.target = self
        menu.addItem(pickColor)
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

    @objc private func newItemAction() {
        itemEditor.openForNewItem()
    }

    /// Opens the system colour sampler and files the result.
    ///
    /// `NSColorSampler` is the "native color picker": the magnifier runs in
    /// the system's own process, so this needs no screen-recording permission
    /// and no capture code of ours. The handler receives nil when the user
    /// dismisses the loupe with Escape — nothing should happen then.
    @objc private func pickColorAction() {
        NSColorSampler().show { [weak self] picked in
            guard let self, let picked, let color = ColorCode(picked) else { return }
            let text = color.formatted(as: .hex)
            let item = ItemActions.makeCapturedItem(text: text)
            self.modelContainer.mainContext.insert(item)
            try? self.modelContainer.mainContext.save()
            // Silently: the item above is already the history's copy of this
            // colour, and letting the monitor capture the write would file a
            // second one credited to whatever app is frontmost.
            self.writer.writeText(text, silently: true)
        }
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

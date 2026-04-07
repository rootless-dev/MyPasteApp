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

        monitor.start()
        hotkey.register()
        retention.prune()

    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        hotkey?.unregister()
    }
}

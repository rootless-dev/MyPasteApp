//
//  MyPasteAppApp.swift
//  MyPasteApp
//
//  Created by Carlos Eduardo on 07/04/26.
//

import SwiftData
import SwiftUI

@main
struct MyPasteAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty Settings scene: Preferences is opened from AppDelegate via a
        // dedicated NSWindow because SwiftUI's Settings scene cannot be opened
        // programmatically from AppKit on macOS 14+ (requires SettingsLink).
        Settings { EmptyView() }
    }
}

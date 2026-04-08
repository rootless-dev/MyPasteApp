//
//  PreferencesView.swift
//  MyPasteApp
//

import ServiceManagement
import SwiftData
import SwiftUI

struct PreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("maxItems") private var maxItems: Int = 500
    @AppStorage("retentionDays") private var retentionDays: Int = 30
    @AppStorage("enableSoundFeedback") private var enableSoundFeedback: Bool = true
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("History") {
                Stepper("Max items: \(maxItems)",
                        value: $maxItems, in: 50...5000, step: 50)
                Stepper("Retain for: \(retentionDays) days",
                        value: $retentionDays, in: 1...365)
                Toggle("Sound on copy", isOn: $enableSoundFeedback)
                Button("Clear non-pinned history") {
                    clearHistory()
                }
            }
            Section("Global shortcut") {
                Text("⌘⇧V — Show/hide overlay")
                    .foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
    }

    private func clearHistory() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isPinned }
        )
        if let items = try? modelContext.fetch(descriptor) {
            for item in items { modelContext.delete(item) }
            try? modelContext.save()
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Failed to toggle launch at login: \(error)")
        }
    }
}

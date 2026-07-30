//
//  PreferencesView.swift
//  MyPasteApp
//

import AppKit
import ServiceManagement
import SwiftData
import SwiftUI

struct PreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("maxItems") private var maxItems: Int = 500
    @AppStorage("retentionDays") private var retentionDays: Int = 30
    @AppStorage("enableSoundFeedback") private var enableSoundFeedback: Bool = true
    @AppStorage("ignoredAppsRaw") private var ignoredAppsRaw: String = ""
    @AppStorage("autoPasteEnabled") private var autoPasteEnabled: Bool = true
    @AppStorage("pasteDelayMs") private var pasteDelayMs: Int = 50
    @AppStorage("previewTextLength") private var previewTextLength: Int = 200
    @AppStorage("showLinkPreviews") private var showLinkPreviews: Bool = true
    @AppStorage("cardDensity") private var cardDensity: String = CardDensity.comfortable.rawValue
    @AppStorage("showQuickPasteNumbers") private var showQuickPasteNumbers: Bool = true
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var hotkey: KeyCombo = KeyCombo.stored
    @State private var pauseHotkey: KeyCombo = KeyCombo.storedPause
    @State private var hotkeyConflict = false
    /// Guards the reassignment inside `onChange` from re-entering it.
    @State private var isRevertingHotkey = false

    var body: some View {
        Form {
            Section("History") {
                Stepper("Max items: \(maxItems)",
                        value: $maxItems, in: 50...5000, step: 50)
                Stepper("Retain for: \(retentionDays) days",
                        value: $retentionDays, in: 1...365)
                Stepper("Preview text length: \(previewTextLength)",
                        value: $previewTextLength, in: 80...500, step: 20)
                Toggle("Sound on copy", isOn: $enableSoundFeedback)
                Button("Clear non-pinned history") {
                    clearHistory()
                }
            }
            Section("Global shortcuts") {
                HStack {
                    Text("Show/hide overlay")
                    Spacer()
                    HotkeyRecorderView(combo: $hotkey)
                        .frame(width: 160, height: 24)
                    Button("Reset") {
                        hotkey = .default
                    }
                }
                HStack {
                    Text("Pause/resume capture")
                    Spacer()
                    HotkeyRecorderView(combo: $pauseHotkey)
                        .frame(width: 160, height: 24)
                    Button("Reset") {
                        pauseHotkey = .pauseDefault
                    }
                }
                if hotkeyConflict {
                    Text("Both shortcuts can't use the same combination.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("Click the field and press a new shortcut. Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onChange(of: hotkey) { oldValue, newValue in
                applyHotkeyChange(new: newValue,
                                  old: oldValue,
                                  other: pauseHotkey,
                                  key: KeyCombo.storageKey) { hotkey = $0 }
            }
            .onChange(of: pauseHotkey) { oldValue, newValue in
                applyHotkeyChange(new: newValue,
                                  old: oldValue,
                                  other: hotkey,
                                  key: KeyCombo.pauseStorageKey) { pauseHotkey = $0 }
            }
            Section("Appearance") {
                Picker("Card density", selection: $cardDensity) {
                    ForEach(CardDensity.allCases) { d in
                        Text(d.label).tag(d.rawValue)
                    }
                }
                Toggle("Show link previews", isOn: $showLinkPreviews)
                Toggle("Show quick paste numbers", isOn: $showQuickPasteNumbers)
                Text("⌘1–⌘9 paste the first nine visible cards. The shortcuts keep working with the numbers hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Paste behavior") {
                Toggle("Auto-paste on selection (simulate ⌘V)", isOn: $autoPasteEnabled)
                Stepper("Paste delay: \(pasteDelayMs) ms",
                        value: $pasteDelayMs, in: 0...500, step: 10)
                    .disabled(!autoPasteEnabled)
                Text("Increase the delay if some apps drop the simulated ⌘V.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Privacy") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ignore content from these apps")
                    TextEditor(text: $ignoredAppsRaw)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 60, maxHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                    Text("One bundle ID per line (e.g. com.agilebits.onepassword7).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 640)
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

    /// Saves a re-recorded shortcut, or refuses it when it would collide with
    /// the other one — `RegisterEventHotKey` would otherwise leave one of them
    /// silently dead.
    private func applyHotkeyChange(new: KeyCombo,
                                   old: KeyCombo,
                                   other: KeyCombo,
                                   key: String,
                                   revert: (KeyCombo) -> Void) {
        guard !isRevertingHotkey else {
            isRevertingHotkey = false
            return
        }
        if KeyCombo.conflicts(new, with: other) {
            NSSound.beep()
            hotkeyConflict = true
            isRevertingHotkey = true
            revert(old)
            return
        }
        hotkeyConflict = false
        KeyCombo.save(new, key: key)
    }
}

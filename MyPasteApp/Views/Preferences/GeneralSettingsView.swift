//
//  GeneralSettingsView.swift
//  MyPasteApp
//

import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(PreferenceKeys.enableSoundFeedback) private var enableSoundFeedback: Bool = true
    @AppStorage(PreferenceKeys.autoPasteEnabled) private var autoPasteEnabled: Bool = true
    @AppStorage(PreferenceKeys.pasteDelayMs) private var pasteDelayMs: Int = 50
    @AppStorage(PreferenceKeys.alwaysPastePlainText) private var alwaysPastePlainText: Bool = false
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
                Toggle("Sound on copy", isOn: $enableSoundFeedback)
            }
            Section("Paste items") {
                // A radio pair rather than a lone toggle: "auto-paste off"
                // required the user to deduce what happened instead.
                Picker("", selection: $autoPasteEnabled) {
                    Text("To the active app").tag(true)
                    Text("To the clipboard").tag(false)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                Text(autoPasteEnabled
                     ? "The selected item is pasted straight into the app you were using."
                     : "The selected item is copied to the clipboard for you to paste yourself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper("Paste delay: \(pasteDelayMs) ms",
                        value: $pasteDelayMs, in: 0...500, step: 10)
                    .disabled(!autoPasteEnabled)
                Text("Increase the delay if some apps drop the simulated ⌘V.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                SettingsToggle(
                    title: "Always paste as plain text",
                    description: "Formatting is still recorded, but every paste hands over plain text. With this on, ⇧ changes nothing.",
                    isOn: $alwaysPastePlainText
                )
            }
        }
        .formStyle(.grouped)
    }

    /// Copied from the former `PreferencesView.toggleLaunchAtLogin`.
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

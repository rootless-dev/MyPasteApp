//
//  ShortcutsSettingsView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

struct ShortcutsSettingsView: View {
    @State private var hotkey: KeyCombo = KeyCombo.stored
    @State private var pauseHotkey: KeyCombo = KeyCombo.storedPause
    @State private var hotkeyConflict = false

    var body: some View {
        Form {
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
            .onChange(of: hotkey) { _, newValue in
                applyHotkeyChange(new: newValue,
                                  other: pauseHotkey,
                                  key: KeyCombo.storageKey,
                                  fallback: .default) { hotkey = $0 }
            }
            .onChange(of: pauseHotkey) { _, newValue in
                applyHotkeyChange(new: newValue,
                                  other: hotkey,
                                  key: KeyCombo.pauseStorageKey,
                                  fallback: .pauseDefault) { pauseHotkey = $0 }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            refreshHotkeyState()
        }
    }

    /// Reconciles the two @State copies with what's actually persisted and
    /// recomputes whether they collide, instead of trusting whatever
    /// `hotkeyConflict` happened to be left at.
    ///
    /// The window is created once and cached (see `AppDelegate.openPreferences`),
    /// so this view's `@State` — and a stale `hotkeyConflict = true` along with
    /// it — would otherwise survive every close and reopen even after the
    /// field that caused it was already reverted. Re-deriving it here also
    /// surfaces a collision that existed before this window ever opened, e.g.
    /// the pause shortcut falling back to a default that already collides
    /// with the overlay one at launch (see `AppDelegate.registerHotkeysCheckingConflict`).
    private func refreshHotkeyState() {
        hotkey = KeyCombo.stored
        pauseHotkey = KeyCombo.storedPause
        hotkeyConflict = KeyCombo.conflicts(hotkey, with: pauseHotkey)
    }

    /// Saves a re-recorded shortcut, or refuses it when it would collide with
    /// the other one — `RegisterEventHotKey` would otherwise leave one of them
    /// silently dead.
    ///
    /// Stateless by design: rather than a flag to swallow the extra
    /// `onChange` that reverting triggers — which stays dropped, and silently
    /// eats the next legitimate change, if the two writes it depends on ever
    /// get coalesced into one SwiftUI update — this treats "already what's
    /// persisted" as nothing to do. Reverting sets the `@State` back to that
    /// same persisted value, so the extra `onChange` it fires takes this same
    /// early return without any flag to track across the two independent
    /// handlers.
    private func applyHotkeyChange(new: KeyCombo,
                                   other: KeyCombo,
                                   key: String,
                                   fallback: KeyCombo,
                                   revert: (KeyCombo) -> Void) {
        let persisted = KeyCombo.load(key: key, fallback: fallback)
        guard new != persisted else { return }
        if KeyCombo.conflicts(new, with: other) {
            NSSound.beep()
            hotkeyConflict = true
            revert(persisted)
            return
        }
        hotkeyConflict = false
        KeyCombo.save(new, key: key)
    }
}

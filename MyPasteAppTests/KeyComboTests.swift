//
//  KeyComboTests.swift
//  MyPasteAppTests
//

import AppKit
import Carbon.HIToolbox
import Testing

@testable import MyPasteApp

/// Serialized because `KeyCombo.save` posts `.hotkeyChanged` on the shared
/// NotificationCenter, and `savePostsNotification` counts those posts.
@MainActor
@Suite("KeyCombo", .serialized)
struct KeyComboTests {
    private let defaults = TestDefaults("key-combo")

    // MARK: - Default

    @Test("The default combo is ⌘⇧V")
    func defaultCombo() {
        #expect(KeyCombo.default.keyCode == UInt32(kVK_ANSI_V))
        #expect(KeyCombo.default.carbonModifiers == UInt32(cmdKey | shiftKey))
    }

    // MARK: - Modifier translation

    @Test("Each AppKit modifier maps onto its Carbon bit", arguments: [
        (NSEvent.ModifierFlags.command.rawValue, UInt32(cmdKey)),
        (NSEvent.ModifierFlags.shift.rawValue, UInt32(shiftKey)),
        (NSEvent.ModifierFlags.option.rawValue, UInt32(optionKey)),
        (NSEvent.ModifierFlags.control.rawValue, UInt32(controlKey)),
    ])
    func modifierMapping(flagRawValue: UInt, carbonMask: UInt32) {
        let combo = KeyCombo(
            nsKeyCode: UInt16(kVK_ANSI_A),
            nsFlags: NSEvent.ModifierFlags(rawValue: flagRawValue)
        )
        #expect(combo.carbonModifiers == carbonMask)
    }

    @Test("All four modifiers combine into one mask")
    func combinedModifiers() {
        let combo = KeyCombo(
            nsKeyCode: UInt16(kVK_ANSI_A),
            nsFlags: [.command, .shift, .option, .control]
        )
        let expected = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        #expect(combo.carbonModifiers == expected)
    }

    @Test("Flags that can't be part of a shortcut are discarded")
    func ignoresIrrelevantFlags() {
        // Caps Lock and the fn key arrive in modifierFlags but must not end up
        // in the registered mask, or the hotkey would never match.
        let combo = KeyCombo(
            nsKeyCode: UInt16(kVK_ANSI_A),
            nsFlags: [.capsLock, .function, .numericPad, .command]
        )
        #expect(combo.carbonModifiers == UInt32(cmdKey))
    }

    @Test("The AppKit key code is carried over unchanged")
    func keyCodeIsPreserved() {
        let combo = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_9), nsFlags: [.command])
        #expect(combo.keyCode == UInt32(kVK_ANSI_9))
    }

    // MARK: - Display

    @Test("Modifiers are shown in the ⌃⌥⇧⌘ order macOS uses")
    func displayStringOrder() {
        let combo = KeyCombo(
            nsKeyCode: UInt16(kVK_Space),
            nsFlags: [.command, .control, .option, .shift]
        )
        #expect(combo.displayString == "⌃⌥⇧⌘Space")
    }

    @Test("Special keys render as their macOS glyphs", arguments: [
        (UInt32(kVK_Return), "↩"),
        (UInt32(kVK_Tab), "⇥"),
        (UInt32(kVK_Space), "Space"),
        (UInt32(kVK_Delete), "⌫"),
        (UInt32(kVK_Escape), "⎋"),
        (UInt32(kVK_LeftArrow), "←"),
        (UInt32(kVK_F5), "F5"),
        (UInt32(kVK_F12), "F12"),
    ])
    func specialKeyGlyphs(keyCode: UInt32, glyph: String) {
        // Letter and digit keys are deliberately left out: they go through the
        // active keyboard layout, so asserting on them would tie the test to
        // whichever layout the machine happens to be using.
        let combo = KeyCombo(keyCode: keyCode, carbonModifiers: UInt32(cmdKey))
        #expect(combo.displayString == "⌘" + glyph)
    }

    @Test("A combo with no modifiers shows just the key")
    func displayStringWithoutModifiers() {
        let combo = KeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: 0)
        #expect(combo.displayString == "Space")
    }

    // MARK: - Codable

    @Test("Encoding and decoding preserves the combo")
    func codableRoundTrip() throws {
        let combo = KeyCombo(
            nsKeyCode: UInt16(kVK_ANSI_K),
            nsFlags: [.command, .option]
        )
        let data = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)
        #expect(decoded == combo)
    }

    // MARK: - Persistence

    @Test("Loading with nothing stored yields the default")
    func loadWithEmptyStore() {
        #expect(KeyCombo.load(from: defaults.store) == .default)
    }

    @Test("Loading unreadable data falls back to the default instead of throwing")
    func loadWithCorruptData() {
        defaults.store.set(Data("not a combo".utf8), forKey: KeyCombo.storageKey)
        #expect(KeyCombo.load(from: defaults.store) == .default)
    }

    @Test("Loading a value of the wrong type falls back to the default")
    func loadWithWrongType() {
        defaults.store.set("⌘⇧V", forKey: KeyCombo.storageKey)
        #expect(KeyCombo.load(from: defaults.store) == .default)
    }

    @Test("A saved combo is read back identically")
    func saveThenLoad() {
        let combo = KeyCombo(
            nsKeyCode: UInt16(kVK_ANSI_B),
            nsFlags: [.control, .shift]
        )
        KeyCombo.save(combo, to: defaults.store)
        #expect(KeyCombo.load(from: defaults.store) == combo)
    }

    @Test("Saving twice keeps only the newer combo")
    func saveOverwrites() {
        KeyCombo.save(KeyCombo(nsKeyCode: UInt16(kVK_ANSI_B), nsFlags: [.command]),
                      to: defaults.store)
        let newer = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_C), nsFlags: [.option])
        KeyCombo.save(newer, to: defaults.store)
        #expect(KeyCombo.load(from: defaults.store) == newer)
    }

    @Test("Saving posts .hotkeyChanged so the hotkey gets re-registered")
    func savePostsNotification() async {
        await confirmation("hotkeyChanged was posted") { posted in
            let token = NotificationCenter.default.addObserver(
                forName: .hotkeyChanged,
                object: nil,
                queue: nil
            ) { _ in posted() }
            defer { NotificationCenter.default.removeObserver(token) }

            KeyCombo.save(.default, to: defaults.store)
        }
    }

    // MARK: - Multiple hotkeys

    @Test("The pause default is ⌘⇧P")
    func pauseDefaultCombo() {
        #expect(KeyCombo.pauseDefault.keyCode == UInt32(kVK_ANSI_P))
        #expect(KeyCombo.pauseDefault.carbonModifiers == UInt32(cmdKey | shiftKey))
    }

    @Test("Each storage key holds its own combo")
    func keysAreIndependent() {
        let overlay = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_V), nsFlags: [.command, .shift])
        let pause = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_P), nsFlags: [.command, .option])
        KeyCombo.save(overlay, to: defaults.store)
        KeyCombo.save(pause, to: defaults.store, key: KeyCombo.pauseStorageKey)

        #expect(KeyCombo.load(from: defaults.store) == overlay)
        #expect(KeyCombo.load(from: defaults.store, key: KeyCombo.pauseStorageKey) == pause)
    }

    @Test("An empty store yields the fallback that was asked for")
    func loadUsesGivenFallback() {
        // Without a per-call fallback the pause hotkey would come back as ⌘⇧V,
        // silently shadowing the overlay shortcut.
        let loaded = KeyCombo.load(from: defaults.store,
                                   key: KeyCombo.pauseStorageKey,
                                   fallback: .pauseDefault)
        #expect(loaded == .pauseDefault)
    }

    @Test("Identical combos conflict")
    func conflictsWhenIdentical() {
        let a = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_V), nsFlags: [.command, .shift])
        let b = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_V), nsFlags: [.command, .shift])
        #expect(KeyCombo.conflicts(a, with: b))
    }

    @Test("A different key or modifier is not a conflict")
    func doesNotConflictWhenDifferent() {
        let base = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_V), nsFlags: [.command, .shift])
        let otherKey = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_P), nsFlags: [.command, .shift])
        let otherMods = KeyCombo(nsKeyCode: UInt16(kVK_ANSI_V), nsFlags: [.command, .option])
        #expect(!KeyCombo.conflicts(base, with: otherKey))
        #expect(!KeyCombo.conflicts(base, with: otherMods))
    }

    @Test("Saving reports which key changed")
    func savePostsChangedKey() async {
        await confirmation("hotkeyChanged carried the pause key") { posted in
            let token = NotificationCenter.default.addObserver(
                forName: .hotkeyChanged,
                object: nil,
                queue: nil
            ) { note in
                if note.userInfo?["key"] as? String == KeyCombo.pauseStorageKey {
                    posted()
                }
            }
            defer { NotificationCenter.default.removeObserver(token) }

            KeyCombo.save(.pauseDefault, to: defaults.store, key: KeyCombo.pauseStorageKey)
        }
    }
}

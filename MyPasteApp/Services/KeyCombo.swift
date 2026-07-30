//
//  KeyCombo.swift
//  MyPasteApp
//
//  Persisted representation of a global keyboard shortcut.
//

import AppKit
import Carbon.HIToolbox
import Foundation

struct KeyCombo: Codable, Equatable {
    /// Carbon virtual key code (e.g. kVK_ANSI_V)
    var keyCode: UInt32
    /// Carbon modifier mask (cmdKey | shiftKey | optionKey | controlKey)
    var carbonModifiers: UInt32

    static let `default` = KeyCombo(
        keyCode: UInt32(kVK_ANSI_V),
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )

    /// Build from AppKit key event values.
    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init(nsKeyCode: UInt16, nsFlags: NSEvent.ModifierFlags) {
        self.keyCode = UInt32(nsKeyCode)
        var mods: UInt32 = 0
        if nsFlags.contains(.command) { mods |= UInt32(cmdKey) }
        if nsFlags.contains(.shift)   { mods |= UInt32(shiftKey) }
        if nsFlags.contains(.option)  { mods |= UInt32(optionKey) }
        if nsFlags.contains(.control) { mods |= UInt32(controlKey) }
        self.carbonModifiers = mods
    }

    /// Human-readable form like "⌘⇧V".
    var displayString: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += Self.keyName(for: keyCode)
        return s
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Return:       return "↩"
        case kVK_Tab:           return "⇥"
        case kVK_Space:         return "Space"
        case kVK_Delete:        return "⌫"
        case kVK_Escape:        return "⎋"
        case kVK_LeftArrow:     return "←"
        case kVK_RightArrow:    return "→"
        case kVK_UpArrow:       return "↑"
        case kVK_DownArrow:     return "↓"
        case kVK_F1:  return "F1";  case kVK_F2:  return "F2"
        case kVK_F3:  return "F3";  case kVK_F4:  return "F4"
        case kVK_F5:  return "F5";  case kVK_F6:  return "F6"
        case kVK_F7:  return "F7";  case kVK_F8:  return "F8"
        case kVK_F9:  return "F9";  case kVK_F10: return "F10"
        case kVK_F11: return "F11"; case kVK_F12: return "F12"
        default:
            // Try to translate the key code to its current keyboard layout character.
            if let chars = currentLayoutString(for: keyCode), !chars.isEmpty {
                return chars.uppercased()
            }
            return "Key\(keyCode)"
        }
    }

    private static func currentLayoutString(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self) as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { raw -> OSStatus in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return -1
            }
            return UCKeyTranslate(base,
                                  UInt16(keyCode),
                                  UInt16(kUCKeyActionDisplay),
                                  0,
                                  UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeyState,
                                  chars.count,
                                  &length,
                                  &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}

// MARK: - Persistence

extension KeyCombo {
    /// Storage key of the show/hide-overlay shortcut.
    static let storageKey = "globalHotkey"
    /// Storage key of the pause/resume-capture shortcut.
    static let pauseStorageKey = "pauseHotkey"

    static let pauseDefault = KeyCombo(
        keyCode: UInt32(kVK_ANSI_P),
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )

    /// Reads the combo stored under `key`, falling back to `fallback` when
    /// nothing is stored or the stored data can't be decoded.
    ///
    /// The fallback is a parameter rather than always `.default` because each
    /// shortcut has its own: defaulting the pause shortcut to ⌘⇧V would
    /// shadow the overlay one.
    static func load(from defaults: UserDefaults = .standard,
                     key: String = storageKey,
                     fallback: KeyCombo = .default) -> KeyCombo {
        guard let data = defaults.data(forKey: key),
              let combo = try? JSONDecoder().decode(KeyCombo.self, from: data)
        else { return fallback }
        return combo
    }

    /// Persists `combo` under `key` and posts `.hotkeyChanged` carrying that
    /// key, so only the affected shortcut gets re-registered.
    static func save(_ combo: KeyCombo,
                     to defaults: UserDefaults = .standard,
                     key: String = storageKey) {
        if let data = try? JSONEncoder().encode(combo) {
            defaults.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: .hotkeyChanged,
                                        object: nil,
                                        userInfo: ["key": key])
    }

    /// Two shortcuts can't share a combination: `RegisterEventHotKey` would
    /// either refuse the second one or leave it silently dead.
    static func conflicts(_ combo: KeyCombo, with other: KeyCombo) -> Bool {
        combo == other
    }

    static var stored: KeyCombo {
        get { load() }
        set { save(newValue) }
    }

    static var storedPause: KeyCombo {
        get { load(key: pauseStorageKey, fallback: pauseDefault) }
        set { save(newValue, key: pauseStorageKey) }
    }
}

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("MyPasteApp.hotkeyChanged")
}

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
    private static let storageKey = "globalHotkey"

    static var stored: KeyCombo {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let combo = try? JSONDecoder().decode(KeyCombo.self, from: data)
            else { return .default }
            return combo
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("MyPasteApp.hotkeyChanged")
}

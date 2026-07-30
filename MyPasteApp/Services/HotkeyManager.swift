//
//  HotkeyManager.swift
//  MyPasteApp
//
//  Registers a global shortcut through Carbon's RegisterEventHotKey.
//

import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class HotkeyManager {
    /// Identifies each shortcut inside the shared Carbon event handler.
    ///
    /// The Carbon signature is the same for every shortcut of this app; what
    /// tells them apart is this id. Indexing by signature — as an earlier
    /// version did — meant a second shortcut resolved to the first one's
    /// callback.
    enum ID: UInt32 {
        case overlay = 1
        case pause = 2
    }

    private static let signature: UInt32 = 0x4D5053_56 // 'MPSV'

    /// Installed once for the whole process. Installing one handler per
    /// `register()` call would deliver every hotkey press to every handler,
    /// firing each callback as many times as there are handlers.
    private static var sharedHandler: EventHandlerRef?

    /// Keeps a strong reference for the C callback bridge, keyed by `ID`.
    private static var instances: [UInt32: HotkeyManager] = [:]

    private let id: ID
    private let storageKey: String
    private let fallback: KeyCombo
    private let callback: () -> Void
    private var hotKeyRef: EventHotKeyRef?

    init(id: ID,
         storageKey: String,
         fallback: KeyCombo,
         callback: @escaping () -> Void) {
        self.id = id
        self.storageKey = storageKey
        self.fallback = fallback
        self.callback = callback
    }

    /// The combination this manager is configured with.
    var storedCombo: KeyCombo {
        KeyCombo.load(key: storageKey, fallback: fallback)
    }

    func register(combo: KeyCombo? = nil) {
        let combo = combo ?? storedCombo
        unregister()

        Self.installSharedHandlerIfNeeded()
        Self.instances[id.rawValue] = self

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id.rawValue)
        let status = RegisterEventHotKey(combo.keyCode,
                                         combo.carbonModifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        if status != noErr {
            // Most often another app already owns the combination. Silence
            // here would leave a shortcut that simply never fires, with
            // nothing to diagnose it by.
            NSLog("Failed to register hotkey \(id) (\(combo.displayString)): OSStatus \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        Self.instances.removeValue(forKey: id.rawValue)
    }

    /// Installs the process-wide Carbon handler on first use. Idempotent, and
    /// deliberately never removed: it is shared by every hotkey.
    private static func installSharedHandlerIfNeeded() {
        guard sharedHandler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hkID)
            let pressedID = hkID.id
            DispatchQueue.main.async {
                HotkeyManager.instances[pressedID]?.callback()
            }
            return noErr
        }, 1, &eventType, nil, &sharedHandler)
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
    }
}

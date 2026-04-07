//
//  HotkeyManager.swift
//  MyPasteApp
//
//  Registra ⌘⇧V global usando Carbon RegisterEventHotKey.
//

import Carbon.HIToolbox
import Foundation

@MainActor
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let callback: () -> Void

    /// keep a strong reference for the C callback bridge
    private static var instances: [UInt32: HotkeyManager] = [:]
    private var signature: UInt32 = 0

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    func register() {
        unregister()

        let sig: UInt32 = 0x4D5053_56 // 'MPSV'
        signature = sig
        Self.instances[sig] = self

        var hotKeyID = EventHotKeyID(signature: sig, id: 1)
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_V)

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
            let sig = hkID.signature
            DispatchQueue.main.async {
                HotkeyManager.instances[sig]?.callback()
            }
            return noErr
        }, 1, &eventType, nil, &eventHandlerRef)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
        if signature != 0 {
            Self.instances.removeValue(forKey: signature)
            signature = 0
        }
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
    }
}

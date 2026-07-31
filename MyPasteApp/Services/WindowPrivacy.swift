//
//  WindowPrivacy.swift
//  MyPasteApp
//
//  Whether this app's windows may be captured by screen sharing.
//

import AppKit
import Foundation

enum WindowPrivacy {
    /// Off by default: the history shouldn't show up in a meeting just
    /// because the user never opened Preferences.
    static func showInScreenSharing(from defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: PreferenceKeys.showInScreenSharing) as? Bool ?? false
    }

    /// `.readWrite` is the system default for windows, so turning the
    /// preference on gives back exactly today's behaviour — nothing beyond
    /// what was asked for changes.
    static func sharingType(from defaults: UserDefaults = .standard) -> NSWindow.SharingType {
        showInScreenSharing(from: defaults) ? .readWrite : .none
    }
}

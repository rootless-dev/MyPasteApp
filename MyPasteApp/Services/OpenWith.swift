//
//  OpenWith.swift
//  MyPasteApp
//

import AppKit
import Foundation

/// Opening an item somewhere else.
///
/// Only file and URL items: an image would have to be written out with nobody
/// asking for the file, and text would want a `.txt` to open in the editor
/// this app already has.
enum OpenWith {

    enum Target: Equatable {
        case openable(URL)
        /// The item points at a path that no longer exists. Carries the path
        /// so the menu can say which one.
        case missing(String)
        case unsupported
    }

    struct Candidate: Equatable, Identifiable {
        let url: URL
        let name: String
        var id: URL { url }
    }

    static func target(for item: ClipboardItem,
                       fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) })
    -> Target {
        switch item.type {
        case .file:
            let paths = item.fileURLStrings ?? []
            guard let first = paths.first else { return .unsupported }
            guard let existing = paths.first(where: fileExists) else { return .missing(first) }
            return .openable(URL(fileURLWithPath: existing))
        case .url:
            guard let text = item.textContent,
                  let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let scheme = url.scheme?.lowercased(),
                  openableSchemes.contains(scheme)
            else { return .unsupported }
            return .openable(url)
        case .text, .image:
            return .unsupported
        }
    }

    /// The schemes ⌘O will hand to `NSWorkspace`.
    ///
    /// An allowlist, not "any scheme with a colon in it". A `.url` item is
    /// only ever *text* somebody copied, and `NSWorkspace.open` acts on
    /// whatever it is handed: copying the literal string
    /// `file:///Applications/Utilities/Terminal.app` classified as a URL and
    /// ⌘O launched Terminal; `smb://host/share` opened an outbound connection
    /// and a credential prompt. Neither is something the user asked this app
    /// to do by pressing ⌘O over a card.
    ///
    /// What's on the list is what a person copies *in order to open it*: web
    /// addresses, and the contact-card schemes — `tel`, `sms`, `facetime` —
    /// which are exactly as ordinary a copy as an email address and whose
    /// worst case is a compose window the user can close. What's off it is
    /// anything that reaches the filesystem, the network stack or another
    /// app's command surface: `file`, `smb`, `javascript`, and app schemes.
    ///
    /// File items are unaffected — they arrive through the `.file` branch
    /// above, from real pasteboard file promises, and are still checked
    /// against the filesystem.
    static let openableSchemes: Set<String> = [
        "http", "https", "mailto", "tel", "sms", "facetime",
    ]

    /// The applications that can open this target, by display name.
    static func candidates(for target: URL) -> [Candidate] {
        var seen = Set<URL>()
        return NSWorkspace.shared.urlsForApplications(toOpen: target).compactMap { url in
            guard seen.insert(url).inserted else { return nil }
            let name = FileManager.default.displayName(atPath: url.path)
            // `displayName` keeps the extension on some systems; the menu
            // wants "Safari", not "Safari.app".
            let trimmed = name.hasSuffix(".app") ? String(name.dropLast(4)) : name
            return Candidate(url: url, name: trimmed)
        }
    }

    /// Opens the target, in a specific app or in the default one.
    static func open(_ target: URL, with application: URL? = nil) {
        guard let application else {
            NSWorkspace.shared.open(target)
            return
        }
        NSWorkspace.shared.open([target],
                                withApplicationAt: application,
                                configuration: NSWorkspace.OpenConfiguration())
    }
}

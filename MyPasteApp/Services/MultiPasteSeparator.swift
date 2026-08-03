//
//  MultiPasteSeparator.swift
//  MyPasteApp
//

import Foundation

/// What goes between two items of a multi-item paste.
///
/// A closed set of named options rather than a free-text field: free text
/// would mean validating input and deciding how to show `\n` in a settings
/// row, for a flexibility nobody asked for yet.
enum MultiPasteSeparator: String, CaseIterable, Identifiable {
    case newline
    case blankLine
    case space
    case comma

    var id: String { rawValue }

    /// What actually gets inserted between two items.
    var text: String {
        switch self {
        case .newline:   return "\n"
        case .blankLine: return "\n\n"
        case .space:     return " "
        case .comma:     return ", "
        }
    }

    var label: String {
        switch self {
        case .newline:   return "New line"
        case .blankLine: return "Blank line"
        case .space:     return "Space"
        case .comma:     return "Comma"
        }
    }

    /// Reads the stored preference, falling back to the default for a missing
    /// or unrecognised value — including a `rawValue` written by a later
    /// version and then rolled back.
    static func resolve(_ raw: String?) -> MultiPasteSeparator {
        raw.flatMap(MultiPasteSeparator.init(rawValue:)) ?? .newline
    }
}

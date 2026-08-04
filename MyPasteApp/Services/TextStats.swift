//
//  TextStats.swift
//  MyPasteApp
//

import Foundation

/// What the editor's footer says about the text being edited.
enum TextStats {

    /// - characters: `Character` count — grapheme clusters, so an accented
    ///   letter counts once however it was encoded.
    /// - words: runs separated by whitespace or newlines, empties discarded.
    /// - lines: newlines plus one, so empty text is one line and a text ending
    ///   in a newline has opened the next one.
    static func counts(_ text: String) -> (characters: Int, words: Int, lines: Int) {
        let words = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        let newlines = text.filter(\.isNewline).count
        return (text.count, words, newlines + 1)
    }

    static func summary(_ text: String) -> String {
        let counts = counts(text)
        return [
            "\(counts.characters) \(counts.characters == 1 ? "character" : "characters")",
            "\(counts.words) \(counts.words == 1 ? "word" : "words")",
            "\(counts.lines) \(counts.lines == 1 ? "line" : "lines")",
        ].joined(separator: " · ")
    }
}

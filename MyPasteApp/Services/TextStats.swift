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

    /// Above this many UTF-8 bytes, the footer stops counting words and lines.
    ///
    /// `summary` runs on every keystroke — `ItemEditorView`'s body evaluates
    /// it, and the editor republishes its text on every change. `counts` walks
    /// the string three times and, worse, `components(separatedBy:)` allocates
    /// one `String` per word: on a 2 MB log that is hundreds of thousands of
    /// allocations between two key presses, which is what made the editor
    /// unusable rather than merely slow.
    ///
    /// 20 KB is far above any text a person types into this editor and far
    /// below the size at which the walk is felt.
    static let exactCountLimit = 20_000

    /// Whether `summary` will report words and lines, or characters alone.
    ///
    /// Measured in UTF-8 bytes because `String.utf8.count` is O(1) for a
    /// native Swift string — the gate itself must not be the thing that costs.
    /// Bytes are an over-estimate of characters for non-ASCII text, which errs
    /// on the safe side: it degrades sooner, never later.
    static func hasExactCounts(_ text: String) -> Bool {
        text.utf8.count <= exactCountLimit
    }

    static func summary(_ text: String) -> String {
        guard hasExactCounts(text) else {
            // Characters only: `text.count` is still O(n), but it walks the
            // string once and allocates nothing, so it costs a fraction of the
            // full summary. Saying less is the honest option — a footer that
            // silently reported *stale* counts, or dropped them with no
            // explanation, would both be worse than one that keeps the number
            // it can afford.
            let characters = text.count
            return "\(characters) \(characters == 1 ? "character" : "characters")"
        }
        let counts = counts(text)
        return [
            "\(counts.characters) \(counts.characters == 1 ? "character" : "characters")",
            "\(counts.words) \(counts.words == 1 ? "word" : "words")",
            "\(counts.lines) \(counts.lines == 1 ? "line" : "lines")",
        ].joined(separator: " · ")
    }
}

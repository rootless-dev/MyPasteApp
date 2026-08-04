//
//  TextStatsTests.swift
//  MyPasteAppTests
//

import Testing
@testable import MyPasteApp

@Suite("Text stats")
struct TextStatsTests {

    @Test("a plain sentence")
    func sentence() {
        let counts = TextStats.counts("Try Paste for free")
        #expect(counts.characters == 18)
        #expect(counts.words == 4)
        #expect(counts.lines == 1)
    }

    @Test("empty text is one empty line")
    func empty() {
        let counts = TextStats.counts("")
        #expect(counts.characters == 0)
        #expect(counts.words == 0)
        #expect(counts.lines == 1)
    }

    @Test("whitespace has characters but no words")
    func whitespaceOnly() {
        let counts = TextStats.counts("   \t ")
        #expect(counts.characters == 5)
        #expect(counts.words == 0)
        #expect(counts.lines == 1)
    }

    @Test("a trailing newline opens a line")
    func trailingNewline() {
        // "one\n" is two lines: the caret sits on the second one, and a footer
        // saying "1 line" while the caret is on line 2 is just wrong.
        let counts = TextStats.counts("one\n")
        #expect(counts.lines == 2)
        #expect(counts.words == 1)
    }

    @Test("several lines and repeated spaces")
    func multiline() {
        let counts = TextStats.counts("one  two\nthree")
        #expect(counts.words == 3)
        #expect(counts.lines == 2)
    }

    @Test("characters count what the user sees, not bytes")
    func graphemeClusters() {
        // "é" as e + combining accent is one character to a reader.
        let counts = TextStats.counts("cafe\u{0301}")
        #expect(counts.characters == 4)
    }

    @Test("the summary reads as a sentence")
    func summary() {
        #expect(TextStats.summary("Try Paste for free") == "18 characters · 4 words · 1 line")
        #expect(TextStats.summary("one\n") == "4 characters · 1 word · 2 lines")
    }

    @Test("text at the limit still gets the full summary")
    func atTheLimit() {
        let text = String(repeating: "a", count: TextStats.exactCountLimit)
        #expect(TextStats.hasExactCounts(text))
        #expect(TextStats.summary(text) == "\(TextStats.exactCountLimit) characters · 1 word · 1 line")
    }

    @Test("past the limit the footer keeps only the character count")
    func pastTheLimit() {
        // The three-pass count runs on every keystroke; past this size the
        // word pass alone allocates a String per word between key presses.
        let size = TextStats.exactCountLimit + 1
        let text = String(repeating: "a", count: size)
        #expect(!TextStats.hasExactCounts(text))
        #expect(TextStats.summary(text) == "\(size) characters")
    }

    @Test("the limit is measured in bytes, not characters")
    func limitCountsBytes() {
        // A multi-byte character crosses the gate sooner than an ASCII one.
        // Erring early is deliberate: the gate exists to stay cheap, and
        // `utf8.count` is the only length that's O(1).
        let text = String(repeating: "é", count: TextStats.exactCountLimit)
        #expect(text.count == TextStats.exactCountLimit)
        #expect(!TextStats.hasExactCounts(text))
    }
}

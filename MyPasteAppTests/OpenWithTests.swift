//
//  OpenWithTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing
@testable import MyPasteApp

@Suite("Open with")
@MainActor
struct OpenWithTests {

    @Test("a file item resolves to its first existing path")
    func fileTarget() {
        let item = ClipboardItem(type: .file,
                                 preview: "two",
                                 contentHash: "hash",
                                 fileURLStrings: ["/tmp/gone.txt", "/tmp/here.txt"])
        let target = OpenWith.target(for: item, fileExists: { $0 == "/tmp/here.txt" })
        #expect(target == .openable(URL(fileURLWithPath: "/tmp/here.txt")))
    }

    @Test("a file whose path is gone says so, with the path")
    func missingFileTarget() {
        // Not `.unsupported`: the entry has to appear and explain itself.
        // Silently hiding the action is the failure the roadmap calls out.
        let item = ClipboardItem(type: .file,
                                 preview: "one",
                                 contentHash: "hash",
                                 fileURLStrings: ["/tmp/gone.txt"])
        #expect(OpenWith.target(for: item, fileExists: { _ in false })
                == .missing("/tmp/gone.txt"))
    }

    @Test("a url item resolves to its url")
    func urlTarget() {
        let item = ClipboardItem(type: .url,
                                 preview: "https://example.com",
                                 contentHash: "hash",
                                 textContent: "https://example.com")
        #expect(OpenWith.target(for: item) == .openable(URL(string: "https://example.com")!))
    }

    @Test("a url item holding something unopenable is unsupported")
    func brokenURLTarget() {
        let item = ClipboardItem(type: .url,
                                 preview: "not a url",
                                 contentHash: "hash",
                                 textContent: "not a url")
        #expect(OpenWith.target(for: item) == .unsupported)
    }

    @Test("an https url is openable, and so is mailto")
    func allowedSchemes() {
        for text in ["https://example.com", "http://example.com", "mailto:someone@example.com"] {
            let item = ClipboardItem(type: .url,
                                     preview: text,
                                     contentHash: "hash",
                                     textContent: text)
            #expect(OpenWith.target(for: item) == .openable(URL(string: text)!),
                    "\(text) should be openable")
        }
    }

    @Test("a scheme outside the allowlist is not opened")
    func disallowedSchemes() {
        // A `.url` item is only ever text somebody copied, and
        // `NSWorkspace.open` acts on whatever it's handed: `file://` pointed
        // at an app bundle launched it, and `smb://` opened an outbound
        // connection and a credential prompt — neither of which is what ⌘O
        // over a card means.
        let dangerous = [
            "file:///Applications/Utilities/Terminal.app",
            "smb://host/share",
            "ftp://example.com/file",
            "javascript:alert(1)",
            "x-apple-shortcuts://run-shortcut?name=Wipe",
        ]
        for text in dangerous {
            let item = ClipboardItem(type: .url,
                                     preview: text,
                                     contentHash: "hash",
                                     textContent: text)
            #expect(OpenWith.target(for: item) == .unsupported, "\(text) must not be openable")
        }
    }

    @Test("the scheme check ignores case")
    func schemeCaseInsensitive() {
        let item = ClipboardItem(type: .url,
                                 preview: "HTTPS://example.com",
                                 contentHash: "hash",
                                 textContent: "HTTPS://example.com")
        #expect(OpenWith.target(for: item) == .openable(URL(string: "HTTPS://example.com")!))
    }

    @Test("text and image items have nothing to open")
    func unsupportedTypes() {
        let text = ClipboardItem(type: .text,
                                 preview: "hi",
                                 contentHash: "hash",
                                 textContent: "hi")
        let image = ClipboardItem(type: .image, preview: "img", contentHash: "hash")
        #expect(OpenWith.target(for: text) == .unsupported)
        #expect(OpenWith.target(for: image) == .unsupported)
    }

    @Test("candidates come back named and deduplicated")
    func candidatesForAKnownType() {
        // Every macOS install can open an http URL with at least one browser,
        // and the names must be app names, not paths.
        let candidates = OpenWith.candidates(for: URL(string: "https://example.com")!)
        #expect(!candidates.isEmpty)
        #expect(candidates.allSatisfy { !$0.name.isEmpty && !$0.name.contains("/") })
        #expect(Set(candidates.map(\.url)).count == candidates.count)
    }
}

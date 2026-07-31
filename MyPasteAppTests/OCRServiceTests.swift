//
//  OCRServiceTests.swift
//  MyPasteAppTests
//

import AppKit
import Foundation
import Testing

@testable import MyPasteApp

@MainActor
@Suite("OCR service")
struct OCRServiceTests {
    enum Failure: Error { case couldNotRenderImage }

    // MARK: - normalize

    @Test("Lines are joined with newlines")
    func joinsLines() {
        #expect(OCRService.normalize(["first", "second"]) == "first\nsecond")
    }

    @Test("Blank lines are dropped")
    func dropsBlankLines() {
        #expect(OCRService.normalize(["first", "   ", "", "second"]) == "first\nsecond")
    }

    @Test("Surrounding whitespace is trimmed off each line")
    func trimsLines() {
        #expect(OCRService.normalize(["  padded  "]) == "padded")
    }

    @Test("The result is capped")
    func truncates() {
        // A full-screen screenshot yields a few KB; the cap is there for the
        // pathological case, which would otherwise be walked on every
        // keystroke by the search filter.
        let long = String(repeating: "a", count: OCRService.maxCharacters + 500)
        #expect(OCRService.normalize([long]).count == OCRService.maxCharacters)
    }

    @Test("No lines means empty string")
    func empty() {
        #expect(OCRService.normalize([]).isEmpty)
    }

    // MARK: - recognize (integration)

    @Test("Recognises text rendered into an image")
    func recognisesRenderedText() async throws {
        let png = try makePNG(text: "HELLO", size: NSSize(width: 600, height: 200))
        let result = try await OCRService.recognize(imageData: png)
        // Deliberately tolerant: this asserts that Vision is wired up and
        // returns our text, not that it transcribes perfectly.
        #expect(result.uppercased().contains("HELLO"))
    }

    @Test("An image with no text yields an empty string")
    func recognisesNothingInBlankImage() async throws {
        let png = try makePNG(text: "", size: NSSize(width: 300, height: 200))
        let result = try await OCRService.recognize(imageData: png)
        #expect(result.isEmpty)
    }

    /// Renders text into a PNG. Throws instead of force-unwrapping: a failure
    /// here should fail this test, not bring down the whole suite.
    private func makePNG(text: String, size: NSSize) throws -> Data {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        if !text.isEmpty {
            (text as NSString).draw(
                at: NSPoint(x: 40, y: size.height / 2 - 40),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 72),
                    .foregroundColor: NSColor.black,
                ]
            )
        }
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw Failure.couldNotRenderImage
        }
        return png
    }
}

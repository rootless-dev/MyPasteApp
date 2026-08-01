//
//  OCRSchedulerTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

@Suite("OCR scheduling")
struct OCRSchedulerTests {
    @Test("A fresh image needs OCR")
    func freshImage() {
        #expect(OCRScheduler.needsOCR(type: .image, ocrProcessedAt: nil, enabled: true))
    }

    @Test("An already processed image is never processed again")
    func alreadyProcessed() {
        // The marker is what stops an image with no text from being run
        // through Vision on every single launch, forever.
        #expect(!OCRScheduler.needsOCR(type: .image, ocrProcessedAt: .now, enabled: true))
    }

    @Test("Non-image types never need OCR")
    func nonImageTypes() {
        #expect(!OCRScheduler.needsOCR(type: .text, ocrProcessedAt: nil, enabled: true))
        #expect(!OCRScheduler.needsOCR(type: .url, ocrProcessedAt: nil, enabled: true))
        #expect(!OCRScheduler.needsOCR(type: .file, ocrProcessedAt: nil, enabled: true))
    }

    @Test("The preference wins over everything")
    func disabled() {
        #expect(!OCRScheduler.needsOCR(type: .image, ocrProcessedAt: nil, enabled: false))
    }
}

//
//  SearchPerformanceTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

/// The roadmap warns that `filtered` runs in memory over every item on every
/// keystroke, and that OCR text makes that worse. This turns the warning into
/// a number.
///
/// The ceiling is deliberately generous: what matters is catching an
/// order-of-magnitude regression, not measuring microseconds on a machine
/// under unknown load.
@MainActor
@Suite("Search performance")
struct SearchPerformanceTests {
    @Test("Filtering 500 items stays inside one frame")
    func staysUnderOneFrame() throws {
        let container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let longOCR = String(repeating: "lorem ipsum dolor sit amet ", count: 370)

        var items: [ClipboardItem] = []
        for index in 0..<500 {
            let item = ClipboardItem(
                type: index % 3 == 0 ? .image : .text,
                preview: "item \(index)",
                contentHash: "hash-\(index)",
                textContent: "item \(index) body text",
                sourceAppBundleID: index % 2 == 0 ? "com.apple.Safari" : "com.apple.Notes"
            )
            // A third of them carry a capped OCR payload — the worst realistic
            // case for the text scan.
            if index % 3 == 0 { item.ocrText = String(longOCR.prefix(OCRService.maxCharacters)) }
            container.mainContext.insert(item)
            items.append(item)
        }

        let filter = SearchFilter(types: [.image], apps: [.bundle("com.apple.Safari")])
        let elapsed = ContinuousClock().measure {
            _ = items.filter {
                ItemSearch.matches(item: $0, query: "amet", filter: filter, now: now)
            }
        }

        #expect(elapsed < .milliseconds(16))
    }
}

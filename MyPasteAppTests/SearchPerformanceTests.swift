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
/// What's timed is a `filtered`-**equivalent**: the same sort followed by the
/// same filter, in that order. Timing `ItemSearch.matches` alone — as this
/// suite originally did — certifies a function the app never calls in
/// isolation: `OverlayView.filtered` sorts the whole history first, and it is a
/// computed property, so every access recomputes both halves. It is accessed by
/// the `ForEach`, by `onChange(of: filtered.first?.id)` and by each key handler
/// that runs, which makes the pair, not the filter, the per-keystroke cost.
///
/// The ceiling is deliberately generous: what matters is catching an
/// order-of-magnitude regression, not measuring microseconds on a machine
/// under unknown load. The median of several runs is what's gated, so one
/// scheduling hiccup doesn't fail the suite.
@MainActor
@Suite("Search performance")
struct SearchPerformanceTests {
    @Test("A full filtered pass over 500 items, measured against one frame")
    func filteredPassAgainstOneFrame() throws {
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
            // Every seventh item pinned, so the sort's first comparison isn't
            // dead weight.
            item.isPinned = index % 7 == 0
            container.mainContext.insert(item)
            items.append(item)
        }

        let filter = SearchFilter(types: [.image], apps: [.bundle("com.apple.Safari")])
        // Halves, for the record: which of the two dominates decides what a
        // future fix would have to attack.
        var sortOnly: [Duration] = []
        var filterOnly: [Duration] = []
        for _ in 0..<5 {
            sortOnly.append(ContinuousClock().measure {
                _ = items.sorted { a, b in
                    if a.isPinned != b.isPinned { return a.isPinned }
                    return a.createdAt > b.createdAt
                }
            })
            filterOnly.append(ContinuousClock().measure {
                _ = items.filter {
                    ItemSearch.matches(item: $0, query: "amet", filter: filter, now: now)
                }
            })
        }
        print("[search-perf] sort only — median \(sortOnly.sorted()[2])")
        print("[search-perf] filter only — median \(filterOnly.sorted()[2])")

        var samples: [Duration] = []
        for _ in 0..<5 {
            samples.append(ContinuousClock().measure {
                // Copied deliberately from `OverlayView.filtered`, sort and
                // all. If that property changes shape, this has to change with
                // it or the gate goes back to certifying the wrong thing.
                let sorted = items.sorted { a, b in
                    if a.isPinned != b.isPinned { return a.isPinned }
                    return a.createdAt > b.createdAt
                }
                _ = sorted.filter {
                    ItemSearch.matches(item: $0, query: "amet", filter: filter, now: now)
                }
            })
        }

        let sorted = samples.sorted()
        let median = sorted[sorted.count / 2]
        print("[search-perf] sort+filter over 500 items — min \(sorted.first!), "
              + "median \(median), max \(sorted.last!)")

        // Measured, Debug build, 500 items: the filter half is ~3.6ms — the
        // number the roadmap used to quote as the whole cost — while the sort
        // that precedes it on every access is ~27ms, for ~31ms together. So a
        // keystroke does NOT fit in a frame at 500 items, and the culprit is
        // the sort over SwiftData-backed properties, not the text scan.
        //
        // Recorded rather than fixed, by instruction: the answer is pagination
        // (or an unsorted/pre-sorted source), which is a roadmap item, not a
        // patch to slip into a bug-fix wave. `isIntermittent` because a faster
        // machine or a Release build may well come in under the frame, and
        // this must not fail either way.
        withKnownIssue("""
            A `filtered` pass over 500 items costs ~31ms in Debug (sort ~27ms \
            + filter ~3.6ms), against a 16ms frame. Pending a pagination item on \
            the roadmap — see the Phase 3 final fix report.
            """, isIntermittent: true) {
            #expect(median < .milliseconds(16))
        }

        // The regression gate that still bites: 4× the measured cost. A change
        // that makes this fail has done something structurally worse, not just
        // run on a busy machine.
        #expect(median < .milliseconds(160))
    }
}

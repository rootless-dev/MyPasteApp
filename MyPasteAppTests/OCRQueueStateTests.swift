//
//  OCRQueueStateTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

@Suite("OCR queue state")
struct OCRQueueStateTests {
    @Test("Items come out in the order they went in")
    func fifo() {
        var state = OCRQueueState()
        let first = UUID(), second = UUID()
        state.enqueue(first)
        state.enqueue(second)
        #expect(state.next() == first)
        #expect(state.next() == second)
    }

    @Test("The same id is never queued twice")
    func deduplicates() {
        // The backfill and a fresh capture can both point at the same item;
        // running Vision twice over it is pure waste.
        var state = OCRQueueState()
        let id = UUID()
        state.enqueue(id)
        state.enqueue(id)
        #expect(state.pending.count == 1)
    }

    @Test("An empty queue yields nil")
    func emptyYieldsNil() {
        var state = OCRQueueState()
        #expect(state.next() == nil)
    }

    @Test("Taking an item removes it")
    func nextRemoves() {
        var state = OCRQueueState()
        state.enqueue(UUID())
        _ = state.next()
        #expect(state.pending.isEmpty)
    }
}

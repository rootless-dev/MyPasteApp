//
//  DuplicateCaptureTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing

@testable import MyPasteApp

/// Covers what `ClipboardMonitor.insertIfNotDuplicate` does to an item it
/// reuses. That method is private and needs a `ModelContext`, so what's tested
/// here is the pure rule it delegates to — the same shape `shouldCapture` and
/// `needsLinkMetadata` already use.
@MainActor
@Suite("Duplicate capture")
struct DuplicateCaptureTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("An expiry that already went by is dropped on re-capture")
    func expiredDateIsCleared() {
        // Otherwise the item comes back to the top of the history as a fresh
        // capture and the next prune deletes it — the user copied something
        // five minutes ago and it vanished, with no visible cause.
        #expect(ClipboardMonitor.expiryAfterRecapture(
            expiresAt: now.addingTimeInterval(-3600), now: now) == nil)
    }

    @Test("An expiry still ahead survives a re-capture")
    func futureDateIsKept() {
        // Copying it again isn't a request to keep it longer: the user asked
        // for this to go away at that time, and it still will.
        let ahead = now.addingTimeInterval(3600)

        #expect(ClipboardMonitor.expiryAfterRecapture(expiresAt: ahead, now: now) == ahead)
    }

    @Test("An item with no expiry stays without one")
    func noDateStaysNil() {
        #expect(ClipboardMonitor.expiryAfterRecapture(expiresAt: nil, now: now) == nil)
    }

    @Test("A date landing exactly on now is dropped")
    func exactlyNowIsCleared() {
        // The same boundary `RetentionPolicy.isProtected` draws: at the
        // instant itself there is no future left to honour.
        #expect(ClipboardMonitor.expiryAfterRecapture(expiresAt: now, now: now) == nil)
    }
}

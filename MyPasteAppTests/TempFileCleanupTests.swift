//
//  TempFileCleanupTests.swift
//  MyPasteAppTests
//

import Foundation
import Testing
@testable import MyPasteApp

@Suite("Temp file cleanup")
struct TempFileCleanupTests {

    private let now = Date(timeIntervalSince1970: 1_770_000_000)

    @Test("files older than the cutoff are expired")
    func expiresOldFiles() {
        let old = URL(fileURLWithPath: "/tmp/old.png")
        let fresh = URL(fileURLWithPath: "/tmp/fresh.png")
        let expired = TempFileCleanup.expired(
            [(old, now.addingTimeInterval(-7200)), (fresh, now.addingTimeInterval(-60))],
            now: now,
            maxAge: 3600)
        #expect(expired == [old])
    }

    @Test("a file exactly at the cutoff is kept")
    func keepsFilesAtTheBoundary() {
        // The drag that wrote it may still be in flight; deleting a file out
        // from under a destination that's copying it is worse than keeping a
        // few kilobytes an hour longer.
        let url = URL(fileURLWithPath: "/tmp/edge.png")
        #expect(TempFileCleanup.expired([(url, now.addingTimeInterval(-3600))],
                                        now: now,
                                        maxAge: 3600).isEmpty)
    }

    @Test("a file dated in the future is kept")
    func keepsFutureFiles() {
        // Clock changes happen. Deleting on a negative age would wipe files
        // that were just written.
        let url = URL(fileURLWithPath: "/tmp/future.png")
        #expect(TempFileCleanup.expired([(url, now.addingTimeInterval(600))],
                                        now: now,
                                        maxAge: 3600).isEmpty)
    }

    @Test("an empty directory expires nothing")
    func handlesEmptyInput() {
        #expect(TempFileCleanup.expired([], now: now, maxAge: 3600).isEmpty)
    }
}

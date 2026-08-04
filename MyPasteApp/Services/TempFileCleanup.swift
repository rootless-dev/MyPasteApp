//
//  TempFileCleanup.swift
//  MyPasteApp
//

import Foundation

/// Decides which dragged-image temporaries can go.
///
/// A safety net, not the mechanism: `DragItemProvider` only writes a file when
/// a destination asks for one, so this usually finds nothing. It exists
/// because there's no documented guarantee that the system removes a file we
/// created ourselves — and an app that leaves files in the temporary directory
/// forever is an app that fills a disk slowly enough that nobody connects the
/// two.
enum TempFileCleanup {
    /// - Parameter maxAge: how old a file must be to go. One hour by default:
    ///   long enough that no in-flight drag can be affected, short enough that
    ///   nothing accumulates across a session.
    static func expired(_ files: [(url: URL, modified: Date)],
                        now: Date,
                        maxAge: TimeInterval = 3600) -> [URL] {
        files
            .filter { now.timeIntervalSince($0.modified) > maxAge }
            .map(\.url)
    }
}

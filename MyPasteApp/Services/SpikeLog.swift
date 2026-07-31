//
//  SpikeLog.swift
//  MyPasteApp
//
//  TEMPORARY — Task 19 spike diagnostics. Delete along with the spike.
//
//  Writes straight to a file rather than using NSLog: NSLog goes to the
//  unified log, not to a redirected stderr, so it can't be read back from a
//  terminal while driving the app by hand.
//

import Foundation

enum SpikeLog {
    private static let url = URL(fileURLWithPath: "/tmp/mypasteapp-spike.log")

    static func write(_ message: String) {
        let line = "\(Date().formatted(date: .omitted, time: .standard)) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}

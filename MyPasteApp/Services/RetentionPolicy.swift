//
//  RetentionPolicy.swift
//  MyPasteApp
//

import Foundation
import SwiftData

@MainActor
final class RetentionPolicy {
    private let modelContext: ModelContext
    private let defaults: UserDefaults

    var maxItems: Int {
        let v = defaults.integer(forKey: PreferenceKeys.maxItems)
        return v > 0 ? v : 500
    }

    /// How many days to keep an item, or `nil` for "keep forever".
    ///
    /// Read through `object(forKey:)` rather than `integer(forKey:)` on
    /// purpose: the latter returns 0 both for a missing key and for a stored
    /// zero, and those two now mean opposite things — unset falls back to 30
    /// days, while a stored 0 is the slider's "Forever" stop. Reading them the
    /// same way would prune exactly the history the user asked to keep.
    var retentionDays: Int? {
        guard let stored = defaults.object(forKey: PreferenceKeys.retentionDays) as? Int else {
            return 30
        }
        if stored == 0 { return nil }
        return stored > 0 ? stored : 30
    }

    init(modelContext: ModelContext, defaults: UserDefaults = .standard) {
        self.modelContext = modelContext
        self.defaults = defaults
    }

    func prune() {
        // 1) Delete old non-pinned items — skipped entirely when the user
        //    asked to keep the history forever.
        if let days = retentionDays {
            let cutoff = Calendar.current.date(
                byAdding: .day, value: -days, to: .now
            ) ?? .now

            let oldDescriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate { !$0.isPinned && $0.createdAt < cutoff }
            )
            if let old = try? modelContext.fetch(oldDescriptor) {
                for item in old { modelContext.delete(item) }
            }
        }

        // 2) Cap at maxItems (keeps the most recent non-pinned ones). This
        //    runs even with "keep forever": that setting is about age, not
        //    about quantity, and without this the store grows without bound.
        let allDescriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isPinned },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let all = try? modelContext.fetch(allDescriptor), all.count > maxItems {
            for item in all[maxItems...] { modelContext.delete(item) }
        }

        try? modelContext.save()
    }
}

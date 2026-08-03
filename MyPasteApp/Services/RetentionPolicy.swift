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

    /// Whether an item survives the two global passes.
    ///
    /// One rule, in one place, consulted by both passes here **and** by the
    /// "Clear history" button in Settings — which used to carry its own
    /// `!isPinned` predicate and would otherwise wipe every pinboard the user
    /// had just filled.
    ///
    /// Deliberately not expressed as a `#Predicate`: `$0.pinboard == nil`
    /// leans on SwiftData's handling of relationships inside predicates, and a
    /// predicate copy of this rule would be a second place for it to drift.
    /// The pruner runs at launch over at most `maxItems` rows (5000 ceiling,
    /// 500 by default), and the heavy fields — `imageData`, `richTextData`,
    /// the link blobs — are `.externalStorage`, so fetching a row doesn't
    /// bring them along.
    static func isProtected(_ item: ClipboardItem) -> Bool {
        item.isPinned || item.keepForever || item.pinboard != nil
    }

    func prune() {
        let now = Date.now
        let all = (try? modelContext.fetch(FetchDescriptor<ClipboardItem>())) ?? []

        // 1) Items the user gave an explicit expiry date, now past. This pass
        //    ignores every shield above: a dated choice outranks pinning,
        //    "keep forever" and pinboard membership alike.
        var survivors: [ClipboardItem] = []
        for item in all {
            if let expiresAt = item.expiresAt, expiresAt < now {
                modelContext.delete(item)
            } else {
                survivors.append(item)
            }
        }

        // 2) Delete old unprotected items — skipped entirely when the user
        //    asked to keep the history forever.
        var prunable = survivors.filter { !Self.isProtected($0) }
        if let days = retentionDays {
            let cutoff = Calendar.current.date(
                byAdding: .day, value: -days, to: now
            ) ?? now
            for item in prunable where item.createdAt < cutoff {
                modelContext.delete(item)
            }
            prunable = prunable.filter { $0.createdAt >= cutoff }
        }

        // 3) Cap at maxItems (keeps the most recent unprotected ones). This
        //    runs even with "keep forever": that setting is about age, not
        //    about quantity, and without this the store grows without bound.
        //    Protected items are outside this count entirely — otherwise a
        //    full pinboard would push the recent history out to make room.
        let ordered = prunable.sorted { $0.createdAt > $1.createdAt }
        if ordered.count > maxItems {
            for item in ordered[maxItems...] { modelContext.delete(item) }
        }

        try? modelContext.save()
    }
}

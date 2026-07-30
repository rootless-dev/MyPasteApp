//
//  RetentionPolicyTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

/// A class suite so the in-memory `ModelContainer` stays owned — and therefore
/// alive — for the whole test. Handing out `container.mainContext` while
/// letting the container go out of scope traps inside `ModelContext.insert`.
/// Swift Testing builds a fresh instance per test, so each one gets an empty
/// store of its own.
@MainActor
@Suite("Retention policy")
final class RetentionPolicyTests {
    private let defaults = TestDefaults("retention-policy")
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - Helpers

    private var context: ModelContext { container.mainContext }

    private var policy: RetentionPolicy {
        RetentionPolicy(modelContext: context, defaults: defaults.store)
    }

    private func insert(tag: String, daysAgo: Int, pinned: Bool = false) {
        let createdAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        context.insert(
            ClipboardItem(
                createdAt: createdAt,
                type: .text,
                preview: tag,
                contentHash: tag,
                textContent: tag,
                isPinned: pinned
            )
        )
    }

    private func remainingTags() throws -> Set<String> {
        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        return Set(items.map(\.preview))
    }

    // MARK: - Settings

    @Test("Falls back to 500 items and 30 days when nothing is configured")
    func defaultLimits() {
        #expect(policy.maxItems == 500)
        #expect(policy.retentionDays == 30)
    }

    @Test("Uses the configured limits")
    func storedLimits() {
        defaults.store.set(42, forKey: "maxItems")
        defaults.store.set(7, forKey: "retentionDays")
        #expect(policy.maxItems == 42)
        #expect(policy.retentionDays == 7)
    }

    @Test("Non-positive maxItems falls back to the default", arguments: [0, -1])
    func nonPositiveMaxItems(value: Int) {
        // Zero would otherwise wipe the entire history on the next prune.
        defaults.store.set(value, forKey: PreferenceKeys.maxItems)
        #expect(policy.maxItems == 500)
    }

    @Test("A stored zero means keep forever")
    func zeroRetentionMeansForever() {
        // Deliberately the opposite of what maxItems does with zero. The
        // retention slider's last stop writes 0, and reading it as "unset"
        // would silently prune the history the user asked to keep.
        defaults.store.set(0, forKey: PreferenceKeys.retentionDays)
        #expect(policy.retentionDays == nil)
    }

    @Test("A negative retention is treated as unset")
    func negativeRetentionFallsBack() {
        defaults.store.set(-1, forKey: PreferenceKeys.retentionDays)
        #expect(policy.retentionDays == 30)
    }

    // MARK: - Age based pruning

    @Test("Deletes items older than the retention window and keeps newer ones")
    func prunesExpiredItems() throws {
        defaults.store.set(10, forKey: "retentionDays")
        insert(tag: "ancient", daysAgo: 40)
        insert(tag: "expired", daysAgo: 11)
        insert(tag: "fresh", daysAgo: 2)

        policy.prune()

        #expect(try remainingTags() == ["fresh"])
    }

    @Test("Keeps an item that is still inside the window")
    func keepsItemInsideWindow() throws {
        defaults.store.set(10, forKey: "retentionDays")
        insert(tag: "borderline", daysAgo: 9)

        policy.prune()

        #expect(try remainingTags() == ["borderline"])
    }

    @Test("Never deletes a pinned item, however old it is")
    func keepsPinnedItemsForever() throws {
        defaults.store.set(10, forKey: "retentionDays")
        insert(tag: "pinned-ancient", daysAgo: 900, pinned: true)
        insert(tag: "unpinned-ancient", daysAgo: 900)

        policy.prune()

        #expect(try remainingTags() == ["pinned-ancient"])
    }

    @Test("Keep forever skips the age pass entirely")
    func keepForeverSkipsAgePruning() throws {
        defaults.store.set(0, forKey: PreferenceKeys.retentionDays)
        insert(tag: "ancient", daysAgo: 9000)
        insert(tag: "fresh", daysAgo: 1)

        policy.prune()

        #expect(try remainingTags() == ["ancient", "fresh"])
    }

    @Test("Keep forever does not disable the maxItems cap")
    func keepForeverStillRespectsTheCap() throws {
        // Otherwise the store grows without bound: "forever" is about age, not
        // about quantity. The Settings screen says this out loud.
        defaults.store.set(0, forKey: PreferenceKeys.retentionDays)
        defaults.store.set(2, forKey: PreferenceKeys.maxItems)
        insert(tag: "newest", daysAgo: 0)
        insert(tag: "second", daysAgo: 1)
        insert(tag: "third", daysAgo: 2)

        policy.prune()

        #expect(try remainingTags() == ["newest", "second"])
    }

    // MARK: - Count based pruning

    @Test("Caps the history at maxItems, keeping the most recent ones")
    func capsAtMaxItems() throws {
        defaults.store.set(2, forKey: "maxItems")
        insert(tag: "newest", daysAgo: 0)
        insert(tag: "second", daysAgo: 1)
        insert(tag: "third", daysAgo: 2)
        insert(tag: "oldest", daysAgo: 3)

        policy.prune()

        #expect(try remainingTags() == ["newest", "second"])
    }

    @Test("Pinned items don't consume the maxItems budget")
    func pinnedItemsAreExemptFromTheCap() throws {
        defaults.store.set(1, forKey: "maxItems")
        insert(tag: "pinned-a", daysAgo: 1, pinned: true)
        insert(tag: "pinned-b", daysAgo: 2, pinned: true)
        insert(tag: "loose-new", daysAgo: 0)
        insert(tag: "loose-old", daysAgo: 3)

        policy.prune()

        #expect(try remainingTags() == ["pinned-a", "pinned-b", "loose-new"])
    }

    @Test("A history already under the cap is left alone")
    func underTheCapIsUntouched() throws {
        defaults.store.set(10, forKey: "maxItems")
        insert(tag: "a", daysAgo: 0)
        insert(tag: "b", daysAgo: 1)

        policy.prune()

        #expect(try remainingTags() == ["a", "b"])
    }

    @Test("Pruning an empty history is harmless")
    func emptyHistory() throws {
        policy.prune()

        #expect(try remainingTags().isEmpty)
    }

    @Test("Pruning twice changes nothing the second time")
    func isIdempotent() throws {
        defaults.store.set(2, forKey: "maxItems")
        defaults.store.set(10, forKey: "retentionDays")
        insert(tag: "keep-a", daysAgo: 0)
        insert(tag: "keep-b", daysAgo: 1)
        insert(tag: "drop", daysAgo: 40)

        policy.prune()
        let afterFirst = try remainingTags()
        policy.prune()

        #expect(afterFirst == ["keep-a", "keep-b"])
        #expect(try remainingTags() == afterFirst)
    }
}

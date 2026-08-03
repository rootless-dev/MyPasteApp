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
            for: ClipboardItem.self, Pinboard.self,
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

    // MARK: - Helpers (Phase 5)

    private func insertProtected(tag: String,
                                 daysAgo: Int,
                                 pinned: Bool = false,
                                 keepForever: Bool = false,
                                 inBoard board: Pinboard? = nil,
                                 expiresAt: Date? = nil) {
        let createdAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let item = ClipboardItem(
            createdAt: createdAt,
            type: .text,
            preview: tag,
            contentHash: tag,
            textContent: tag,
            isPinned: pinned,
            keepForever: keepForever
        )
        item.expiresAt = expiresAt
        item.pinboard = board
        context.insert(item)
    }

    private func makeBoard() -> Pinboard {
        let board = Pinboard(name: "Work", colorHex: PinboardPalette.colors[0])
        context.insert(board)
        return board
    }

    // MARK: - Expiry (roadmap item 17)

    @Test("An item past its expiry date is deleted")
    func expiredItemIsDeleted() throws {
        insertProtected(tag: "expired", daysAgo: 0,
                        expiresAt: Date.now.addingTimeInterval(-60))
        insertProtected(tag: "future", daysAgo: 0,
                        expiresAt: Date.now.addingTimeInterval(3600))

        policy.prune()

        #expect(try remainingTags() == ["future"])
    }

    @Test("Expiry beats pinning")
    func expiryBeatsPinning() throws {
        // An explicit, dated choice by the user outranks an automatic rule.
        // The alternative leaves an item the user marked for deletion alive
        // indefinitely because it happens to be pinned.
        insertProtected(tag: "pinned-expired", daysAgo: 0, pinned: true,
                        expiresAt: Date.now.addingTimeInterval(-60))

        policy.prune()

        #expect(try remainingTags().isEmpty)
    }

    @Test("Expiry beats keep forever")
    func expiryBeatsKeepForever() throws {
        insertProtected(tag: "forever-expired", daysAgo: 0, keepForever: true,
                        expiresAt: Date.now.addingTimeInterval(-60))

        policy.prune()

        #expect(try remainingTags().isEmpty)
    }

    @Test("Expiry beats being in a pinboard")
    func expiryBeatsPinboard() throws {
        let board = makeBoard()
        insertProtected(tag: "board-expired", daysAgo: 0, inBoard: board,
                        expiresAt: Date.now.addingTimeInterval(-60))

        policy.prune()

        #expect(try remainingTags().isEmpty)
    }

    // MARK: - Keep forever

    @Test("Keep forever survives the age pass")
    func keepForeverSurvivesAge() throws {
        defaults.store.set(10, forKey: PreferenceKeys.retentionDays)
        insertProtected(tag: "kept", daysAgo: 900, keepForever: true)
        insertProtected(tag: "dropped", daysAgo: 900)

        policy.prune()

        #expect(try remainingTags() == ["kept"])
    }

    @Test("Keep forever doesn't consume the maxItems budget")
    func keepForeverIsExemptFromTheCap() throws {
        defaults.store.set(1, forKey: PreferenceKeys.maxItems)
        insertProtected(tag: "kept-a", daysAgo: 1, keepForever: true)
        insertProtected(tag: "kept-b", daysAgo: 2, keepForever: true)
        insertProtected(tag: "loose-new", daysAgo: 0)
        insertProtected(tag: "loose-old", daysAgo: 3)

        policy.prune()

        #expect(try remainingTags() == ["kept-a", "kept-b", "loose-new"])
    }

    // MARK: - Pinboards (roadmap item 16)

    @Test("An item in a pinboard survives the age pass")
    func pinboardSurvivesAge() throws {
        // Without this the collection the user curated empties itself in
        // thirty days, with no warning and no undo.
        defaults.store.set(10, forKey: PreferenceKeys.retentionDays)
        let board = makeBoard()
        insertProtected(tag: "filed", daysAgo: 900, inBoard: board)
        insertProtected(tag: "loose", daysAgo: 900)

        policy.prune()

        #expect(try remainingTags() == ["filed"])
    }

    @Test("Items in a pinboard don't push loose items out of the cap")
    func pinboardIsExemptFromTheCap() throws {
        defaults.store.set(3, forKey: PreferenceKeys.maxItems)
        let board = makeBoard()
        insertProtected(tag: "filed-a", daysAgo: 4, inBoard: board)
        insertProtected(tag: "filed-b", daysAgo: 5, inBoard: board)
        insertProtected(tag: "filed-c", daysAgo: 6, inBoard: board)
        insertProtected(tag: "loose-1", daysAgo: 0)
        insertProtected(tag: "loose-2", daysAgo: 1)
        insertProtected(tag: "loose-3", daysAgo: 2)

        policy.prune()

        #expect(try remainingTags() == ["filed-a", "filed-b", "filed-c",
                                        "loose-1", "loose-2", "loose-3"])
    }

    // MARK: - A future expiry date protects (branch-review decision)

    @Test("An item with a future expiry survives the age pass")
    func futureExpirySurvivesAge() throws {
        // The date is a promise in both directions: it says when the item goes
        // away, which also says it doesn't go away before then. Without this
        // the age pass takes it hours early and the user never learns why.
        defaults.store.set(10, forKey: PreferenceKeys.retentionDays)
        insertProtected(tag: "dated", daysAgo: 900,
                        expiresAt: Date.now.addingTimeInterval(3600))
        insertProtected(tag: "loose", daysAgo: 900)

        policy.prune()

        #expect(try remainingTags() == ["dated"])
    }

    @Test("An item with a future expiry doesn't consume the maxItems budget")
    func futureExpiryIsExemptFromTheCap() throws {
        defaults.store.set(1, forKey: PreferenceKeys.maxItems)
        insertProtected(tag: "dated-a", daysAgo: 1,
                        expiresAt: Date.now.addingTimeInterval(3600))
        insertProtected(tag: "dated-b", daysAgo: 2,
                        expiresAt: Date.now.addingTimeInterval(3600))
        insertProtected(tag: "loose-new", daysAgo: 0)
        insertProtected(tag: "loose-old", daysAgo: 3)

        policy.prune()

        #expect(try remainingTags() == ["dated-a", "dated-b", "loose-new"])
    }

    @Test("A past expiry is still deleted by the first pass")
    func pastExpiryStillDies() throws {
        // The shield above must not leak backwards into pass 1: a date that
        // already went by deletes the item however protected it otherwise is.
        let board = makeBoard()
        defaults.store.set(0, forKey: PreferenceKeys.retentionDays)
        insertProtected(tag: "past", daysAgo: 0, pinned: true, inBoard: board,
                        expiresAt: Date.now.addingTimeInterval(-60))
        insertProtected(tag: "future", daysAgo: 0,
                        expiresAt: Date.now.addingTimeInterval(60))

        policy.prune()

        #expect(try remainingTags() == ["future"])
    }

    // MARK: - isProtected

    @Test("isProtected covers exactly the four shields")
    func isProtectedCoversTheFour() throws {
        let board = makeBoard()
        let now = Date.now
        insertProtected(tag: "pinned", daysAgo: 0, pinned: true)
        insertProtected(tag: "forever", daysAgo: 0, keepForever: true)
        insertProtected(tag: "filed", daysAgo: 0, inBoard: board)
        insertProtected(tag: "dated-ahead", daysAgo: 0,
                        expiresAt: now.addingTimeInterval(3600))
        insertProtected(tag: "dated-past", daysAgo: 0,
                        expiresAt: now.addingTimeInterval(-3600))
        insertProtected(tag: "plain", daysAgo: 0)

        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        let protectedTags = Set(
            items.filter { RetentionPolicy.isProtected($0, now: now) }.map(\.preview)
        )

        #expect(protectedTags == ["pinned", "forever", "filed", "dated-ahead"])
    }

    // MARK: - Clear history

    @Test("Clear history keeps everything isProtected protects")
    func clearHistoryKeepsProtected() throws {
        // `HistorySettingsView.clearHistory` is a `View` method, so what runs
        // here is the rule it delegates to — the whole point of that button
        // owning no predicate of its own.
        let board = makeBoard()
        let now = Date.now
        insertProtected(tag: "pinned", daysAgo: 0, pinned: true)
        insertProtected(tag: "forever", daysAgo: 0, keepForever: true)
        insertProtected(tag: "filed", daysAgo: 0, inBoard: board)
        insertProtected(tag: "dated-ahead", daysAgo: 0,
                        expiresAt: now.addingTimeInterval(3600))
        insertProtected(tag: "plain", daysAgo: 0)

        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        for item in items where !RetentionPolicy.isProtected(item, now: now) {
            context.delete(item)
        }

        #expect(try remainingTags() == ["pinned", "forever", "filed", "dated-ahead"])
    }
}

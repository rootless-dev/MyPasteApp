//
//  OCRQueue.swift
//  MyPasteApp
//

import Foundation
import SwiftData

/// The queue's bookkeeping, split out so ordering and de-duplication are
/// testable without a model container or Vision.
struct OCRQueueState {
    private(set) var pending: [UUID] = []

    mutating func enqueue(_ id: UUID) {
        guard !pending.contains(id) else { return }
        pending.append(id)
    }

    mutating func next() -> UUID? {
        pending.isEmpty ? nil : pending.removeFirst()
    }
}

/// Runs OCR over image items, one at a time, off the capture path.
///
/// Serial and low priority by design: the backfill can hand it several hundred
/// images at once on the first launch after the update, and that has to be a
/// background chore rather than a burst of CPU the user feels.
@MainActor
final class OCRQueue {
    private let modelContext: ModelContext
    private let defaults: UserDefaults
    private var state = OCRQueueState()
    private var worker: Task<Void, Never>?

    init(modelContext: ModelContext, defaults: UserDefaults = .standard) {
        self.modelContext = modelContext
        self.defaults = defaults
    }

    /// Queues by id, never by `ClipboardItem` reference. Two reasons: the item
    /// can be deleted while it waits — by retention or by the user — and a
    /// `@Model` isn't `Sendable`, so it has no business crossing an actor
    /// boundary.
    func enqueue(_ id: UUID) {
        state.enqueue(id)
        startIfNeeded()
    }

    /// Queues every image that has never been through OCR.
    ///
    /// Without this, everything captured before the feature existed stays
    /// permanently unsearchable, and the search looks like it "only works
    /// sometimes" — the worst kind of inconsistency.
    func enqueueBacklog() {
        guard Self.isEnabled(from: defaults) else { return }
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.typeRaw == "image" && $0.ocrProcessedAt == nil }
        )
        guard let items = try? modelContext.fetch(descriptor) else { return }
        for item in items { state.enqueue(item.id) }
        startIfNeeded()
    }

    private func startIfNeeded() {
        guard worker == nil else { return }
        worker = Task(priority: .utility) { [weak self] in
            await self?.drain()
            self?.worker = nil
        }
    }

    private func drain() async {
        while let id = state.next() {
            // Re-read every pass: the user can turn OCR off while a long
            // backfill is running, and that has to take effect now, not after
            // the queue empties.
            guard Self.isEnabled(from: defaults) else {
                state = OCRQueueState()
                return
            }
            // Named `existing`, not `item`: a local called `item` would shadow
            // the `item(with:)` lookup below for the rest of this scope, and
            // the re-fetch after the `await` needs that method, not the stale
            // reference this guard captured.
            guard let existing = item(with: id),
                  OCRScheduler.needsOCR(type: existing.type,
                                        ocrProcessedAt: existing.ocrProcessedAt,
                                        enabled: true) else { continue }
            guard let data = existing.imageData else {
                // An image item with no bytes: mark it seen so it doesn't come
                // back around on every launch.
                existing.ocrProcessedAt = .now
                try? modelContext.save()
                continue
            }

            // `recognize` is nonisolated and async, so this hop leaves the
            // main actor; the assignments below are back on it.
            let recognised = try? await OCRService.recognize(imageData: data)

            // Fetched again: the wait above is long enough for the item to
            // have been deleted meanwhile.
            guard let fresh = item(with: id) else { continue }
            fresh.ocrText = (recognised?.isEmpty == false) ? recognised : nil
            fresh.ocrProcessedAt = .now
            try? modelContext.save()
        }
    }

    private func item(with id: UUID) -> ClipboardItem? {
        var descriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// On by default, read with `object(forKey:)` so an explicit `false` on
    /// disk is distinguishable from an absent key — the pattern Phase 2
    /// established for every boolean preference.
    static func isEnabled(from defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: PreferenceKeys.enableImageOCR) as? Bool ?? true
    }
}

//
//  HistorySettingsView.swift
//  MyPasteApp
//

import SwiftData
import SwiftUI

struct HistorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(PreferenceKeys.maxItems) private var maxItems: Int = 500
    @AppStorage(PreferenceKeys.retentionDays) private var retentionDays: Int = 30
    @AppStorage(PreferenceKeys.previewTextLength) private var previewTextLength: Int = 200

    var body: some View {
        Form {
            Section("Keep history") {
                RetentionSlider(days: $retentionDays)
                Text("Forever stops deleting by age. The maximum number of items below still applies, so the store can't grow without bound.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Stepper("Maximum items: \(maxItems)",
                        value: $maxItems, in: 50...5000, step: 50)
                Stepper("Preview text length: \(previewTextLength)",
                        value: $previewTextLength, in: 80...500, step: 20)
            }
            Section {
                Button("Clear history") { clearHistory() }
                Text("Keeps pinned items, items in pinboards, and items set to never expire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Uses the pruner's own rule rather than a predicate of its own.
    ///
    /// It used to carry `#Predicate { !$0.isPinned }`, which since Phase 5
    /// would have emptied every pinboard the user had just filled — the button
    /// promised "non-pinned" and would have deleted curated collections.
    private func clearHistory() {
        let items = (try? modelContext.fetch(FetchDescriptor<ClipboardItem>())) ?? []
        for item in items where !RetentionPolicy.isProtected(item) {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

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
                Button("Clear non-pinned history") { clearHistory() }
            }
        }
        .formStyle(.grouped)
    }

    /// Copied from the former `PreferencesView.clearHistory`.
    private func clearHistory() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isPinned }
        )
        if let items = try? modelContext.fetch(descriptor) {
            for item in items { modelContext.delete(item) }
            try? modelContext.save()
        }
    }
}

//
//  RetentionPolicy.swift
//  MyPasteApp
//

import Foundation
import SwiftData

@MainActor
final class RetentionPolicy {
    private let modelContext: ModelContext

    var maxItems: Int {
        let v = UserDefaults.standard.integer(forKey: "maxItems")
        return v > 0 ? v : 500
    }

    var retentionDays: Int {
        let v = UserDefaults.standard.integer(forKey: "retentionDays")
        return v > 0 ? v : 30
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func prune() {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -retentionDays, to: .now
        ) ?? .now

        // 1) Delete itens antigos não-fixados
        let oldDescriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isPinned && $0.createdAt < cutoff }
        )
        if let old = try? modelContext.fetch(oldDescriptor) {
            for item in old { modelContext.delete(item) }
        }

        // 2) Cap em maxItems (mantém os mais recentes não-fixados)
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

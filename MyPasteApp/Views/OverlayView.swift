//
//  OverlayView.swift
//  MyPasteApp
//

import SwiftData
import SwiftUI

struct OverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.createdAt, order: .reverse)
    private var items: [ClipboardItem]

    @State private var searchText = ""
    @State private var selectedID: UUID?
    @FocusState private var searchFocused: Bool

    let onPick: (ClipboardItem) -> Void
    let onDismiss: () -> Void

    init(onPick: @escaping (ClipboardItem) -> Void,
         onDismiss: @escaping () -> Void) {
        self.onPick = onPick
        self.onDismiss = onDismiss
    }

    private var filtered: [ClipboardItem] {
        let sorted = items.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
        guard !searchText.isEmpty else { return sorted }
        let q = searchText.lowercased()
        return sorted.filter { item in
            item.preview.lowercased().contains(q)
                || (item.textContent?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText)
                .focused($searchFocused)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(filtered) { item in
                            ClipboardCardView(
                                item: item,
                                isSelected: selectedID == item.id
                            )
                            .id(item.id)
                            .onTapGesture { pick(item) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: .infinity)
                .onChange(of: selectedID) { _, newID in
                    if let id = newID {
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(8)
        .onAppear {
            searchFocused = true
            selectedID = filtered.first?.id
        }
        .onChange(of: filtered.first?.id) { _, newID in
            selectedID = newID
        }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress(.return) {
            if let item = filtered.first(where: { $0.id == selectedID }) {
                pick(item)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.leftArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.rightArrow) { moveSelection(1); return .handled }
        .onKeyPress(keys: ["p"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            if let item = filtered.first(where: { $0.id == selectedID }) {
                item.isPinned.toggle()
                try? modelContext.save()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            if let item = filtered.first(where: { $0.id == selectedID }) {
                modelContext.delete(item)
                try? modelContext.save()
                return .handled
            }
            return .ignored
        }
    }

    private func pick(_ item: ClipboardItem) {
        item.lastUsedAt = .now
        try? modelContext.save()
        onPick(item)
    }

    private func moveSelection(_ delta: Int) {
        let list = filtered
        guard !list.isEmpty else { return }
        if let id = selectedID, let idx = list.firstIndex(where: { $0.id == id }) {
            let next = max(0, min(list.count - 1, idx + delta))
            selectedID = list[next].id
        } else {
            selectedID = list.first?.id
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

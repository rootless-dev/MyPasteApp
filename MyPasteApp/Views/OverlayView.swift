//
//  OverlayView.swift
//  MyPasteApp
//

import AppKit
import SwiftData
import SwiftUI

struct OverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.createdAt, order: .reverse)
    private var items: [ClipboardItem]

    @State private var searchText = ""
    @State private var selectedID: UUID?
    @FocusState private var searchFocused: Bool
    @AppStorage(PreferenceKeys.showQuickPasteNumbers) private var showQuickPasteNumbers = true
    @AppStorage(PreferenceKeys.alwaysPastePlainText) private var alwaysPastePlainText = false

    let onPick: (ClipboardItem, Bool) -> Void
    let onDismiss: () -> Void

    init(onPick: @escaping (ClipboardItem, Bool) -> Void,
         onDismiss: @escaping () -> Void) {
        self.onPick = onPick
        self.onDismiss = onDismiss
    }

    /// Whether this paste should hand over plain text.
    ///
    /// `onTapGesture` doesn't report modifiers, so ⇧ is read from the current
    /// event at the moment of the click. With the preference on, ⇧ changes
    /// nothing: it always means "plain", never "the opposite of my default".
    private var pastesPlainText: Bool {
        alwaysPastePlainText
            || NSEvent.modifierFlags.contains(.shift)
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
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            ClipboardCardView(
                                item: item,
                                isSelected: selectedID == item.id,
                                quickPasteLabel: showQuickPasteNumbers
                                    ? QuickPaste.label(forIndex: index)
                                    : nil,
                                onDelete: { delete(item) }
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
        // `phases: .down` is required here: the single-key `onKeyPress(_:action:)`
        // overload only exposes a no-argument closure, so reading
        // `press.modifiers` (for ⇧↵) needs the `phases:` overload instead.
        .onKeyPress(.return, phases: .down) { press in
            guard let item = filtered.first(where: { $0.id == selectedID }) else {
                return .ignored
            }
            pick(item, plainText: alwaysPastePlainText || press.modifiers.contains(.shift))
            return .handled
        }
        .onKeyPress(.leftArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.rightArrow) { moveSelection(1); return .handled }
        .onKeyPress(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) { press in
            // The index follows `filtered`, not the full list: with a search
            // active, ⌘3 has to paste the third card actually on screen.
            guard press.modifiers.contains(.command),
                  let index = QuickPaste.index(for: press.key.character),
                  index < filtered.count
            else { return .ignored }
            // Shift is ignored on purpose, not read via the default resolver:
            // some layouts (e.g. French AZERTY) can't type a digit without
            // holding Shift, so falling back to `pastesPlainText` here would
            // read that as "paste plain" and permanently lock quick paste
            // into plain text on those keyboards. Quick paste has no ⇧
            // variant this phase — see task-12 brief, item 6.
            pick(filtered[index], plainText: alwaysPastePlainText)
            return .handled
        }
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
                delete(item)
                return .handled
            }
            return .ignored
        }
    }

    private func pick(_ item: ClipboardItem, plainText: Bool? = nil) {
        item.lastUsedAt = .now
        try? modelContext.save()
        onPick(item, plainText ?? pastesPlainText)
    }

    private func delete(_ item: ClipboardItem) {
        let deletedID = item.id
        let wasSelected = selectedID == deletedID
        let remaining = filtered.filter { $0.id != deletedID }
        let index = filtered.firstIndex { $0.id == deletedID }

        modelContext.delete(item)
        try? modelContext.save()

        guard wasSelected else { return }
        if let index, !remaining.isEmpty {
            selectedID = remaining[min(index, remaining.count - 1)].id
        } else {
            selectedID = remaining.first?.id
        }
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

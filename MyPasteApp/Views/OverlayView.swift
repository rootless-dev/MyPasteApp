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

    let writer: ClipboardWriter
    let itemEditor: ItemEditorWindowController
    let onPick: (ClipboardItem, Bool) -> Void
    let onDismiss: () -> Void
    /// Resolves the name of the app a paste would land in, read fresh at menu
    /// build time.
    ///
    /// `OverlayView` is constructed once, in `prepare()`, and reused across
    /// every hotkey invocation — but the previously-frontmost app changes on
    /// every `show()`. A plain `String?` captured through `init` would freeze
    /// whatever app was frontmost the first time the panel was built. A
    /// closure defers that read to whenever the context menu is actually
    /// assembled, so it always reflects the current opening.
    let destinationAppName: () -> String?

    init(writer: ClipboardWriter,
         itemEditor: ItemEditorWindowController,
         onPick: @escaping (ClipboardItem, Bool) -> Void,
         onDismiss: @escaping () -> Void,
         destinationAppName: @escaping () -> String? = { nil }) {
        self.writer = writer
        self.itemEditor = itemEditor
        self.onPick = onPick
        self.onDismiss = onDismiss
        self.destinationAppName = destinationAppName
    }

    /// Built fresh on every access: it only wraps references (the model
    /// context, the writer, the pick callback), so there's no state here that
    /// needs to survive across view updates.
    private var itemActions: ItemActions {
        ItemActions(modelContext: modelContext, writer: writer, onPaste: onPick, editorWindow: itemEditor)
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
        return sorted.filter { Self.matches(item: $0, query: searchText) }
    }

    /// Whether an item satisfies the search query.
    ///
    /// Static and pure so the rule is testable without rendering the overlay.
    static func matches(item: ClipboardItem, query: String) -> Bool {
        let q = query.lowercased()
        guard !q.isEmpty else { return true }
        if item.preview.lowercased().contains(q) { return true }
        if item.textContent?.lowercased().contains(q) == true { return true }
        if item.label?.lowercased().contains(q) == true { return true }
        return false
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
                            .contextMenu {
                                ItemContextMenu(item: item,
                                                actions: itemActions,
                                                destinationAppName: destinationAppName())
                            }
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
                itemActions.togglePin(item)
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
        .onKeyPress(keys: ["e"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            // Image and file items aren't editable as text — same gate as
            // `ItemContextMenu`'s "Edit" entry.
            guard let item = filtered.first(where: { $0.id == selectedID }),
                  item.type == .text || item.type == .url else {
                return .ignored
            }
            itemActions.edit(item)
            onDismiss()
            return .handled
        }
        .onKeyPress(keys: ["r"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            // Unlike ⌘E, renaming applies to every type — no gate here.
            guard let item = filtered.first(where: { $0.id == selectedID }) else {
                return .ignored
            }
            itemActions.rename(item)
            onDismiss()
            return .handled
        }
    }

    private func pick(_ item: ClipboardItem, plainText: Bool? = nil) {
        itemActions.paste(item, plainText: plainText ?? pastesPlainText)
    }

    /// Deletes the item, then decides which card takes over the selection.
    ///
    /// The removal itself goes through `ItemActions`, but choosing the next
    /// selected card is view state — `ItemActions` has no notion of
    /// `selectedID` and shouldn't. This preserves the original card ordering
    /// (`filtered`, captured before the delete) so the replacement is the
    /// card that visually sat at the same spot, falling back to the first
    /// card when the deleted one was the last.
    private func delete(_ item: ClipboardItem) {
        let deletedID = item.id
        let wasSelected = selectedID == deletedID
        let remaining = filtered.filter { $0.id != deletedID }
        let index = filtered.firstIndex { $0.id == deletedID }

        itemActions.delete(item)

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

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
    /// Each visible card's frame, keyed by item id, refreshed continuously by
    /// `CardFramePreferenceKey` as cards appear, scroll, or the window
    /// resizes. Read by `notifyPreviewSelection()` to tell
    /// `OverlayWindowController` where to anchor the preview panel.
    @State private var cardFrames: [UUID: CGRect] = [:]
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
    /// Reports the selected item and its on-screen frame every time either
    /// changes, whether or not the preview panel is open.
    ///
    /// The panel is an imperative `NSPanel` owned by
    /// `OverlayWindowController`, built from a `ClipboardItem` — a
    /// `@Model` reference type, not a value the panel can just poll. This
    /// closure is the bridge: `OverlayWindowController` keeps the last
    /// values it received so that whenever the panel is (re)shown, it
    /// already knows what to display and where, instead of only finding out
    /// the moment `onShowPreview` fires.
    let onPreviewSelectionChange: (ClipboardItem?, CGRect?) -> Void
    /// Opens the preview panel unconditionally. Used by `␣` when the panel is
    /// closed, and by the "Preview" context menu entry — where the intent is
    /// always "show me this item", never "toggle closed", since the user just
    /// right-clicked a specific card to ask for it.
    let onShowPreview: () -> Void
    /// Closes just the preview panel, leaving the overlay itself open. Used by
    /// `␣` when the panel is already open (`spaceAction`), and by Escape when
    /// `escapeClosesPreview` says the panel is what should go first.
    let onHidePreview: () -> Void
    /// Whether the preview panel is currently open, read fresh by the Space
    /// and Escape handlers on every press. The panel is an imperative `NSPanel`
    /// owned by `OverlayWindowController`, not SwiftUI state this view
    /// holds itself, so its visibility has to be asked for rather than
    /// observed — the same closure-as-bridge shape as
    /// `onPreviewSelectionChange`.
    let isPreviewOpen: () -> Bool

    init(writer: ClipboardWriter,
         itemEditor: ItemEditorWindowController,
         onPick: @escaping (ClipboardItem, Bool) -> Void,
         onDismiss: @escaping () -> Void,
         destinationAppName: @escaping () -> String? = { nil },
         onPreviewSelectionChange: @escaping (ClipboardItem?, CGRect?) -> Void = { _, _ in },
         onShowPreview: @escaping () -> Void = {},
         onHidePreview: @escaping () -> Void = {},
         isPreviewOpen: @escaping () -> Bool = { false }) {
        self.writer = writer
        self.itemEditor = itemEditor
        self.onPick = onPick
        self.onDismiss = onDismiss
        self.destinationAppName = destinationAppName
        self.onPreviewSelectionChange = onPreviewSelectionChange
        self.onShowPreview = onShowPreview
        self.onHidePreview = onHidePreview
        self.isPreviewOpen = isPreviewOpen
    }

    /// Built fresh on every access: it only wraps references (the model
    /// context, the writer, the pick callback), so there's no state here that
    /// needs to survive across view updates.
    private var itemActions: ItemActions {
        ItemActions(modelContext: modelContext, writer: writer, onPaste: onPick,
                    editorWindow: itemEditor, onPreview: preview)
    }

    /// Whether this paste should hand over plain text.
    ///
    /// `onTapGesture` doesn't report modifiers, so ⇧ is read from the current
    /// event at the moment of the click. With the preference on, ⇧ changes
    /// nothing: it always means "plain", never "the opposite of my default".
    /// See `ItemActions.resolvePastePlainText` for the shared rule.
    private var pastesPlainText: Bool {
        ItemActions.resolvePastePlainText(alwaysPlainText: alwaysPastePlainText,
                                           shiftHeld: NSEvent.modifierFlags.contains(.shift))
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

    /// Whether Space should open the preview rather than type a space.
    ///
    /// The search field holds focus from `onAppear`, so Space can't simply be
    /// claimed by the overlay. A leading space in a search has no use, which
    /// makes an empty field the safe place to take the key; "foo bar" is
    /// unaffected because the field isn't empty by then.
    ///
    /// The key that opens the panel also closes it — anything else would make
    /// the user reach for Escape to undo what Space just did.
    static func spaceAction(searchText: String, isPreviewOpen: Bool) -> SpaceAction {
        guard searchText.isEmpty else { return .type }
        return isPreviewOpen ? .hidePreview : .showPreview
    }

    /// What pressing Space should do, given the search field and the panel.
    enum SpaceAction {
        /// Let the key through to the search field.
        case type
        case showPreview
        case hidePreview
    }

    /// Whether Escape should close the preview instead of the overlay.
    ///
    /// Dismiss what's on top first, as the system does everywhere else.
    /// Without this, closing the panel takes the whole drawer with it.
    static func escapeClosesPreview(isPreviewOpen: Bool) -> Bool {
        isPreviewOpen
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
                            .background(
                                // Reports this card's on-screen frame so the
                                // preview panel can anchor above it. Color.clear
                                // keeps this purely observational — it doesn't
                                // intercept the tap/context-menu gestures below.
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: CardFramePreferenceKey.self,
                                        value: [item.id: proxy.frame(in: .global)]
                                    )
                                }
                            )
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
                    notifyPreviewSelection()
                }
                .onPreferenceChange(CardFramePreferenceKey.self) { frames in
                    cardFrames = frames
                    notifyPreviewSelection()
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
        .onKeyPress(.escape) {
            if Self.escapeClosesPreview(isPreviewOpen: isPreviewOpen()) {
                onHidePreview()
            } else {
                onDismiss()
            }
            return .handled
        }
        .onKeyPress(.space) {
            switch Self.spaceAction(searchText: searchText,
                                    isPreviewOpen: isPreviewOpen()) {
            case .type:
                return .ignored
            case .showPreview:
                onShowPreview()
                return .handled
            case .hidePreview:
                onHidePreview()
                return .handled
            }
        }
        // `phases: .down` is required here: the single-key `onKeyPress(_:action:)`
        // overload only exposes a no-argument closure, so reading
        // `press.modifiers` (for ⇧↵) needs the `phases:` overload instead.
        .onKeyPress(.return, phases: .down) { press in
            guard let item = filtered.first(where: { $0.id == selectedID }) else {
                return .ignored
            }
            pick(item, plainText: ItemActions.resolvePastePlainText(
                alwaysPlainText: alwaysPastePlainText,
                shiftHeld: press.modifiers.contains(.shift)
            ))
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
        .onKeyPress(keys: ["c"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            guard let item = filtered.first(where: { $0.id == selectedID }) else {
                return .ignored
            }
            // Ignores `alwaysPastePlainText` on purpose, matching
            // `ItemContextMenu`'s "Copy" entry: the preference is scoped to
            // pasting (its label and description in Settings both say
            // "paste"), and writing the formatted representation to the
            // system pasteboard isn't handing anything to a destination app
            // the way a paste is. `⇧↵` ("Paste as Plain Text") remains the
            // explicit way to get plain text out of the overlay.
            itemActions.copy(item)
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
        .onKeyPress(keys: ["n"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            // Unlike ⌘E/⌘R, this needs no selected card — it opens an empty
            // editor. The item itself isn't created until Save runs.
            itemActions.newItem()
            onDismiss()
            return .handled
        }
    }

    private func pick(_ item: ClipboardItem, plainText: Bool? = nil) {
        itemActions.paste(item, plainText: plainText ?? pastesPlainText)
    }

    /// Selects the item and opens the preview panel for it.
    ///
    /// Used by the "Preview" context menu entry, where the click can land on
    /// a card that isn't the one arrow-key selection currently points to.
    /// `onPreviewSelectionChange` is called here directly, with `item` and
    /// its already-known frame, instead of relying on the `selectedID`
    /// mutation below to reach `OverlayWindowController` on its own: SwiftUI
    /// delivers `onChange(of: selectedID)` on the next view update, not
    /// synchronously, and `onShowPreview()` — called right after — must not
    /// race that and open the panel on the *previous* selection.
    private func preview(_ item: ClipboardItem) {
        selectedID = item.id
        onPreviewSelectionChange(item, cardFrames[item.id])
        onShowPreview()
    }

    /// Tells `OverlayWindowController` what's selected right now and where
    /// it is on screen.
    ///
    /// Called on every selection change and every card-layout change (a card
    /// appearing, scrolling into a new position, the window resizing) — see
    /// the two call sites above, in `body`. Firing unconditionally, even
    /// while the preview panel is closed, means the controller always has an
    /// up-to-date answer for "what would I show if asked to open right now",
    /// instead of only finding out at the moment it's asked.
    private func notifyPreviewSelection() {
        let item = filtered.first { $0.id == selectedID }
        let anchor = selectedID.flatMap { cardFrames[$0] }
        onPreviewSelectionChange(item, anchor)
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

/// Collects each card's on-screen frame, keyed by item id.
///
/// Reported in the `.global` coordinate space — for SwiftUI content hosted
/// directly by an `NSHostingView` (as `OverlayView` is, in
/// `OverlayWindowController.prepare()`), that's equivalent to the hosting
/// view's own bounds. `OverlayWindowController.positionPreviewPanel(_:)`
/// converts it to window, then screen, coordinates from there.
struct CardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
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

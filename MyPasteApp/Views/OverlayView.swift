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

    @Query(sort: \Pinboard.createdAt, order: .forward)
    private var boards: [Pinboard]

    @State private var selectedID: UUID?
    /// Selection to honour on the next list change, instead of the top card.
    ///
    /// Lives for exactly one turn of the main actor — see `jumpToHistory` and
    /// `closeSearch`, which both drop it in a deferred task so an id that no
    /// list change ever consumed can't stay armed.
    @State private var pendingSelection: UUID?
    /// Set to ask the scroll view to reveal a card once it's rendered.
    @State private var scrollRequest: UUID?
    /// Each visible card's frame, refreshed continuously by
    /// `CardFramePreferenceKey` as cards appear, scroll, or the window
    /// resizes. Read by `notifyPreviewSelection()` to tell
    /// `OverlayWindowController` where to anchor the preview panel. Lives in a
    /// reference type on purpose — see `CardFrameStore`.
    @State private var cardFrames = CardFrameStore()
    /// The board whose pill is in inline rename, if any. View state, not
    /// controller state: it never has to survive the drawer closing.
    @State private var renamingBoardID: UUID?
    /// Where the keyboard is pointed.
    ///
    /// The overlay used to keep the search field focused at all times, which
    /// is also how `onKeyPress` received anything at all: it only fires while
    /// the declaring view or a descendant holds focus. With the field gone at
    /// rest, the card strip has to take focus instead — without that, the
    /// overlay goes back to being exactly what Phase 1 found: a window that
    /// never sees a key.
    @FocusState private var focusTarget: OverlayFocusTarget?
    @AppStorage(PreferenceKeys.showQuickPasteNumbers) private var showQuickPasteNumbers = true
    @AppStorage(PreferenceKeys.alwaysPastePlainText) private var alwaysPastePlainText = false

    let writer: ClipboardWriter
    let itemEditor: ItemEditorWindowController
    /// Owned by `OverlayWindowController`, not by this view.
    ///
    /// The overlay is built once, in `prepare()`, and reused for the life of
    /// the process — so state held here in `@State` would outlive the drawer
    /// being closed, and the next opening would come back mid-search instead
    /// of at rest. The controller resets it on every `show()`. A plain `let`
    /// is enough for updates to arrive: `SearchState` is `@Observable`, so
    /// reading its properties during `body` registers the dependency
    /// regardless of how the reference is stored.
    let search: SearchState
    /// Owned by `OverlayWindowController`, like `search` and for the same
    /// reason. The controller clears it on every `show()`.
    let marked: MarkedSelection
    /// Owned by `OverlayWindowController`, like `search` and `marked`, and for
    /// the same reason. The controller resets it on every `show()`.
    let scope: PinboardScope
    let onPick: (ClipboardItem, Bool) -> Void
    let onPickMultiple: ([ClipboardItem], Bool) -> Void
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
         search: SearchState,
         marked: MarkedSelection,
         scope: PinboardScope,
         onPick: @escaping (ClipboardItem, Bool) -> Void,
         onPickMultiple: @escaping ([ClipboardItem], Bool) -> Void,
         onDismiss: @escaping () -> Void,
         destinationAppName: @escaping () -> String? = { nil },
         onPreviewSelectionChange: @escaping (ClipboardItem?, CGRect?) -> Void = { _, _ in },
         onShowPreview: @escaping () -> Void = {},
         onHidePreview: @escaping () -> Void = {},
         isPreviewOpen: @escaping () -> Bool = { false }) {
        self.writer = writer
        self.itemEditor = itemEditor
        self.search = search
        self.marked = marked
        self.scope = scope
        self.onPick = onPick
        self.onPickMultiple = onPickMultiple
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
                    editorWindow: itemEditor, onPreview: preview, onJump: jumpToHistory)
    }

    private var pinboardActions: PinboardActions {
        PinboardActions(modelContext: modelContext)
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
        let now = Date.now
        // Scope first, search second: two separate questions, asked in the
        // order the user asked them — "show me this shelf", then "find this on
        // it". See `PinboardScope.contains`.
        return sorted
            .filter { PinboardScope.contains(item: $0, activeID: scope.activeID) }
            .filter {
                ItemSearch.matches(item: $0, query: search.text, filter: search.filter, now: now)
            }
    }

    /// Whether Space should open the preview rather than type a space.
    ///
    /// While the search is open the field holds focus, so Space can't simply
    /// be claimed by the overlay. A leading space in a search has no use,
    /// which makes an empty field the safe place to take the key; "foo bar" is
    /// unaffected because the field isn't empty by then. With the search
    /// closed the text is empty by definition, so the same rule already says
    /// "toggle the preview" — no second branch needed.
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
    ///
    /// The live Escape handler now goes through `SearchState.escapeAction`,
    /// which folds this rule in alongside the filter panel and the search
    /// itself; this stays as the isolated statement of the preview half.
    static func escapeClosesPreview(isPreviewOpen: Bool) -> Bool {
        isPreviewOpen
    }

    /// Which card should be selected after the list changes shape.
    ///
    /// The plain behaviour is "follow the top card", which is right when items
    /// are added or removed — and wrong right after a jump or after letting go
    /// of the search, because clearing the query changes the list and would
    /// steal the selection away from the item the user asked to see.
    static func selectionAfterListChange(pending: UUID?, newFirstID: UUID?) -> UUID? {
        pending ?? newFirstID
    }

    /// Where the filter panel starts, measured from the top of the drawer's
    /// content.
    ///
    /// Deliberately *less* than the top bar's full height — rendered, the bar
    /// is 49pt at rest and 52pt once a token widens the field's capsule. This
    /// eats into the bar's 8pt bottom padding, which is empty, so the panel
    /// still clears the capsule itself: by 5pt at rest, and by about 2pt with a
    /// token present. Tight, but the alternative is a visible gap between the
    /// field and the panel it opened.
    private static let filterPanelTopInset: CGFloat = 46

    /// Split out of `body`: with the pinboard wiring added, the compiler
    /// timed out type-checking the top bar and the card list as one
    /// expression. Giving the bar its own typed property is what brought it
    /// back under budget.
    @ViewBuilder
    private var topBar: some View {
        // `activateSearch` takes a defaulted parameter, so it can't be
        // handed over as a bare `() -> Void` — Swift doesn't apply
        // defaults when a function is used as a value.
        OverlayTopBar(state: search,
                      focusTarget: $focusTarget,
                      onActivate: { activateSearch() },
                      onOpenFilters: { search.isFilterPanelOpen.toggle() },
                      markedCount: marked.count,
                      boards: boards,
                      activeScopeID: scope.activeID,
                      onSelectScope: selectScope,
                      onCreateBoard: createBoard,
                      boardContextMenu: { board in
                          AnyView(PinboardContextMenu(
                              board: board,
                              actions: pinboardActions,
                              onRename: { renamingBoardID = board.id },
                              onDeleted: {
                                  if scope.activeID == board.id { scope.select(nil) }
                                  if renamingBoardID == board.id { renamingBoardID = nil }
                              }))
                      },
                      editingBoardID: renamingBoardID,
                      onCommitBoardName: { board, name in
                          pinboardActions.rename(board, to: name)
                          renamingBoardID = nil
                      })
    }

    /// One card in the strip, factored out of `body` for the same reason
    /// `topBar` was: the compiler couldn't type-check the `ForEach` closure
    /// and everything around it as a single expression once the pinboard
    /// wiring landed.
    @ViewBuilder
    private func cardCell(index: Int, item: ClipboardItem) -> some View {
        ClipboardCardView(
            item: item,
            isSelected: selectedID == item.id,
            quickPasteLabel: showQuickPasteNumbers
                ? QuickPaste.label(forIndex: index)
                : nil,
            markOrder: marked.order(of: item.id),
            anyMarked: !marked.isEmpty,
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
        .onTapGesture {
            // `onTapGesture` doesn't report modifiers,
            // so ⌘ is read from the current event at
            // the moment of the click — the same shape
            // `pastesPlainText` already uses for ⇧.
            //
            // Three-way, not two: ⌘-click on a
            // markable item toggles the mark; ⌘-click
            // on one that isn't markable does nothing
            // — it must not fall through to `pick`,
            // which would paste it and close the
            // drawer out from under a block the user
            // is still assembling. Only a plain click,
            // with no ⌘ at all, pastes. Mirrors ⌘M,
            // which returns `.ignored` on the same
            // gate instead of pasting.
            if NSEvent.modifierFlags.contains(.command) {
                if MultiPaste.isMarkable(item.type) {
                    marked.toggle(item.id)
                }
            } else {
                pick(item)
            }
        }
        .contextMenu {
            ItemContextMenu(item: item,
                            actions: itemActions,
                            destinationAppName: destinationAppName(),
                            isSearchNarrowed: search.hasContent,
                            isMarked: marked.contains(item.id),
                            onToggleMark: { marked.toggle(item.id) },
                            onDelete: { delete(item) })
        }
    }

    /// Split from the keyboard handlers below for the same reason `topBar`
    /// and `cardCell` were: the whole thing as one expression was over the
    /// compiler's type-checking budget once the pinboard wiring landed.
    var body: some View {
        keyHandled(contentStack)
    }

    private var contentStack: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                topBar

                if filtered.isEmpty {
                    // Two different empties: a board nobody filled yet, and a
                    // search that found nothing. Saying "no results" inside an
                    // untouched board would send the user hunting for a filter
                    // that isn't there.
                    Text(scope.isScoped && !search.hasContent ? "Empty Pinboard" : "No results")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                                    cardCell(index: index, item: item)
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
                        .onChange(of: scrollRequest) { _, id in
                            guard let id else { return }
                            withAnimation { proxy.scrollTo(id, anchor: .center) }
                            scrollRequest = nil
                        }
                        .onPreferenceChange(CardFramePreferenceKey.self) { frames in
                            cardFrames.update(frames)
                            notifyPreviewSelection()
                        }
                    }
                }
            }

            if search.isFilterPanelOpen {
                // Catches a click anywhere else inside the overlay. Nearly
                // transparent rather than `Color.clear`: a fully clear shape
                // doesn't take hits.
                Color.black.opacity(0.001)
                    .onTapGesture { search.isFilterPanelOpen = false }

                // A layer in this `ZStack`, deliberately not a `.popover`: a
                // popover is a new window, and this overlay is `.transient` —
                // it vanishes the moment it loses focus. Phase 2 already paid
                // that bill once, with a whole `NSPanel` plus an exception in
                // the click-outside monitor, just so the preview could coexist
                // with the drawer.
                //
                // The facets come from `items`, the whole history, never from
                // `filtered`: deriving them from the filtered list would make
                // every other app disappear from the panel the instant one app
                // was picked, leaving no way back.
                FilterPanelView(state: search, facets: ItemSearch.facets(in: items))
                    // Right-aligned inside the same 470pt frame the field
                    // occupies, which is where the filter button that opens it
                    // sits. The bottom inset keeps the panel off the drawer's
                    // rounded corner when it is tall enough to reach it.
                    .frame(maxWidth: 470, alignment: .trailing)
                    .padding(.top, Self.filterPanelTopInset)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(8)
        // Something has to hold the keyboard whenever the search field isn't
        // there to hold it: `onKeyPress` only fires while the declaring view
        // or a descendant is focused, so with nothing focused the overlay
        // sees no keys at all — exactly what Phase 1 found.
        //
        // Deliberately the root container and NOT the `ScrollView`. A focused
        // macOS scroll view handles `←`/`→` and `␣` natively, and the
        // handlers below live on this root: making the focused view and the
        // handlers the same view removes the question of who is consulted
        // first. `focusEffectDisabled` suppresses the ring the system would
        // otherwise draw around the whole drawer — the cards carry their own
        // selection highlight, and the search field its own background.
        .focusable()
        .focusEffectDisabled()
        .focused($focusTarget, equals: .list)
        .onAppear {
            focusTarget = .list
            selectedID = filtered.first?.id
        }
        .onChange(of: filtered.first?.id) { _, newID in
            selectedID = Self.selectionAfterListChange(pending: pendingSelection,
                                                       newFirstID: newID)
            pendingSelection = nil
        }
        // The search can also be closed from outside this view:
        // `OverlayWindowController.show()` resets it on every opening. Either
        // way the `.search`-tagged field leaves the tree, and a focus target
        // that no longer exists focuses nothing — which would leave the
        // reopened drawer keyboard-dead. Reading `search.isActive` here is
        // also what registers this body's dependency on it.
        .onChange(of: search.isActive) { _, isActive in
            if !isActive { focusTarget = .list }
        }
        // `onAppear` runs exactly once, at pre-warm. If anything clears the
        // first responder while the drawer is hidden, the next opening would
        // have focus nowhere and the drawer would ignore every key — no error,
        // no log, nothing on screen. `close()` alone can't cover that: it only
        // moves focus when there was an active search to close.
        //
        // Unconditional on purpose: the drawer reopens with the keyboard
        // pointed at the cards even when nothing about the search changed
        // since last time.
        .onChange(of: search.openCount) { _, _ in
            focusTarget = .list
        }
    }

    /// Every `onKeyPress` handler in the drawer, applied to `contentStack`.
    @ViewBuilder
    private func keyHandled<Content: View>(_ content: Content) -> some View {
        content
        .onKeyPress(.escape) {
            switch SearchState.escapeAction(isFilterPanelOpen: search.isFilterPanelOpen,
                                            isPreviewOpen: isPreviewOpen(),
                                            isActive: search.isActive,
                                            hasContent: search.hasContent,
                                            hasMarks: !marked.isEmpty,
                                            hasScope: scope.isScoped) {
            case .closeFilterPanel:
                search.isFilterPanelOpen = false
            case .hidePreview:
                onHidePreview()
            case .closeSearch:
                closeSearch()
            case .clearMarks:
                marked.clear()
            case .leaveScope:
                selectScope(nil)
            case .dismissOverlay:
                onDismiss()
            }
            return .handled
        }
        // ␣ is the first of three keys that share one rule — see
        // `typesIntoDetachedField` below, and its two other callers on
        // `.delete` and on the generic character handler.
        .onKeyPress(.space) {
            switch Self.spaceAction(searchText: search.text,
                                    isPreviewOpen: isPreviewOpen()) {
            case .type:
                // `.type` only happens with text already in the field, so this
                // never produces a leading space. With the keyboard on the
                // field, `.ignored` hands the key to the field itself, which is
                // where a space belongs.
                if typesIntoDetachedField {
                    focusSearchField { $0.append(" ") }
                    return .handled
                }
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
            let plain = ItemActions.resolvePastePlainText(
                alwaysPlainText: alwaysPastePlainText,
                shiftHeld: press.modifiers.contains(.shift)
            )
            // With marks live, they *are* the selection — the same way ↵ in
            // the Finder acts on what's selected. Resolved against `items`,
            // the full list, never `filtered`: marks survive the search by
            // design, and resolving against the filtered list would make the
            // block shrink on its own as the user typed.
            if !marked.isEmpty {
                let block = MultiPaste.resolve(ids: marked.ids, in: items)
                guard !block.isEmpty else { return .ignored }
                pickMultiple(block, plainText: plain)
                return .handled
            }
            guard let item = filtered.first(where: { $0.id == selectedID }) else {
                return .ignored
            }
            pick(item, plainText: plain)
            return .handled
        }
        .onKeyPress(.leftArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.rightArrow) { moveSelection(1); return .handled }
        // ⌃Tab cycles scopes forward, ⌃⇧Tab back, History included in the
        // cycle. Control rather than Command because the menu bar AppKit
        // builds for the `Settings` scene owns a set of ⌘ keys — Phase 4
        // learned that the hard way with ⌘M. If the system swallows these
        // anyway (step E1 of the manual script), the fallback already chosen
        // is ⌥→ / ⌥←, which is a one-line change here.
        //
        // `phases: .down` is required here for the same reason it is on ⌘↵
        // above: the single-key `onKeyPress(_:action:)` overload only exposes
        // a no-argument closure, and reading `press.modifiers` needs the
        // `phases:` overload instead.
        .onKeyPress(.tab, phases: .down) { press in
            guard press.modifiers.contains(.control) else { return .ignored }
            cycleScope(forward: !press.modifiers.contains(.shift))
            return .handled
        }
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
        // Marks the selected card for a multi-item paste. Only "m" lowercase:
        // with no ⇧ in the combination there's no uppercase variant to
        // register — the trap that left ⌘⇧K silently dead in Phase 2 — and
        // with no ⌥ there's no layout-dependent alternate character either.
        .onKeyPress(keys: ["m"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            guard let item = filtered.first(where: { $0.id == selectedID }),
                  MultiPaste.isMarkable(item.type) else { return .ignored }
            marked.toggle(item.id)
            return .handled
        }
        .onKeyPress(.delete) {
            // Second of the three keys sharing `typesIntoDetachedField`.
            // Only when there's a character to delete: with the text empty the
            // existing rule below already says `.removeLastToken`, which is a
            // real action and not a dropped key.
            if typesIntoDetachedField, !search.text.isEmpty {
                focusSearchField { if !$0.isEmpty { $0.removeLast() } }
                return .handled
            }
            switch SearchState.backspaceAction(isActive: search.isActive,
                                               textIsEmpty: search.text.isEmpty,
                                               hasTokens: !search.filter.isEmpty,
                                               hasMarks: !marked.isEmpty) {
            case .deleteItem:
                if let item = filtered.first(where: { $0.id == selectedID }) {
                    delete(item)
                    return .handled
                }
                return .ignored
            case .removeLastToken:
                if let last = SearchToken.tokens(from: search.filter).last {
                    search.filter = last.removed(from: search.filter)
                }
                return .handled
            case .passThrough:
                return .ignored
            case .blockedByMarks:
                // The key is consumed rather than travel on: with the
                // selection border hidden while marks are live (see
                // `ClipboardCardView.anyMarked`), there's no target left for
                // ⌫ to name, so it must not fall through to anything else.
                return .handled
            }
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
        // Both cases registered, like ⌘F below: with ⇧ held the key arrives
        // uppercased, which is what made ⌘⇧K silently dead in Phase 2.
        //
        // Gated on `hasContent` for the same reason the menu entry is: with
        // the whole history already on screen there is nothing to jump out of.
        .onKeyPress(keys: ["j", "J"]) { press in
            guard press.modifiers.contains(.command), search.hasContent else { return .ignored }
            guard let item = filtered.first(where: { $0.id == selectedID }) else {
                return .ignored
            }
            jumpToHistory(item)
            return .handled
        }
        // Typing with the search closed opens it — the behaviour Paste teaches
        // in its own onboarding card ("Start typing to search"). The character
        // must not be swallowed by the transition.
        //
        // What keeps this from stealing ⌘C/⌘P/⌘E/⌘R/⌘N/⌘1-9/⌘F is not where
        // it sits in the chain — ⌘F is registered after it — but
        // `SearchState.activationCharacter`, which returns nil for anything
        // held with ⌘, ⌃ or ⌥. This handler then returns `.ignored` and the
        // key goes on to whichever handler wants it.
        .onKeyPress(characters: .alphanumerics.union(.punctuationCharacters).union(.symbols),
                    phases: .down) { press in
            guard let character = press.characters.first else { return .ignored }
            // Last of the three keys sharing `typesIntoDetachedField`.
            //
            // The `isActive: false` argument is deliberate: what's being asked
            // here is not "is the search open" but "is this a key that types
            // into the field", and that's the same rule — no ⌘/⌃/⌥, letters,
            // digits, punctuation and symbols only. Skipping it would make an
            // open search with the focus on the cards read ⌘C as the letter
            // "c" and swallow the shortcut, and chain order is no defence
            // against that, for the reason spelled out just above.
            if typesIntoDetachedField,
               SearchState.activationCharacter(character,
                                               modifiers: press.modifiers,
                                               isActive: false) != nil {
                focusSearchField { $0.append(character) }
                return .handled
            }
            guard let seed = SearchState.activationCharacter(character,
                                                             modifiers: press.modifiers,
                                                             isActive: search.isActive)
            else { return .ignored }
            activateSearch(seeding: seed)
            return .handled
        }
        // Both cases registered: with ⇧ held the key arrives uppercased, which
        // is what made ⌘⇧K silently dead in Phase 2.
        .onKeyPress(keys: ["f", "F"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            activateSearch()
            return .handled
        }
    }

    /// Whether a key that belongs to the search field has arrived here instead
    /// of at the field.
    ///
    /// One rule with three keys: ␣, ⌫ and any typed character. With the search
    /// open and the keyboard on the card strip, the handlers on this view are
    /// the only ones that run, and each of the three used to answer `.ignored`:
    /// with no focused field to fall through to, the key vanished with no
    /// error, no log and nothing on screen. So the three handlers apply the key
    /// themselves and pull the keyboard back to the field.
    ///
    /// **That state is currently unreachable, and this guard stays anyway.**
    /// Since the field became `SearchTextField`, nothing detaches it: a posted
    /// click on the drawer chrome leaves the field editor exactly where it was
    /// (measured — the harness logs it as "detach did not detach"), and
    /// `OverlayWindowController.show()` calls `search.close()` before it points
    /// the keyboard at the cards, so the field is out of the tree by then
    /// rather than detached. Both routes that used to produce this state are
    /// therefore closed.
    ///
    /// It is kept because it costs one boolean and it is the only thing
    /// standing between a future change that re-detaches the field and a key
    /// the user typed disappearing in silence — the failure mode this whole
    /// phase exists to make impossible.
    private var typesIntoDetachedField: Bool {
        search.isActive && focusTarget != .search
    }

    /// Opens the search, points the keyboard at it and writes the character
    /// that opened it — all in this turn.
    ///
    /// Synchronous throughout, and that is the change Task 12 exists to make.
    /// Both hazards that used to force deferred turns are gone:
    ///
    /// 1. The focus write no longer has to wait for the field to be inserted.
    ///    `search.activate()` and this write happen before SwiftUI evaluates
    ///    anything, so by the time focus is resolved the `.search` tag exists.
    ///    Measured: the field takes the keyboard on the same key that opens the
    ///    search, which also removes the two-frame grey stroke the deferral
    ///    produced.
    /// 2. The seed no longer has to be written after the focus write to survive
    ///    a select-all. `SearchTextField` places the caret itself, inside
    ///    `becomeFirstResponder`, so there is no selection left to destroy it.
    ///
    /// What that buys is ordering: with every write landing in the turn its key
    /// arrived in, a key handled here and a key taken directly by the field can
    /// no longer swap places. The deferred version reordered `ghi` into `gih`
    /// at a 20ms gap, 10 runs out of 10.
    private func activateSearch(seeding character: Character? = nil) {
        search.activate()
        if let character { search.text.append(character) }
        focusTarget = .search
    }

    /// Points the keyboard at the search field and applies `edit` to the query,
    /// in this turn.
    ///
    /// **Nothing automated covers this path.** `SearchStateTests` pins
    /// `activationCharacter`, which is the rule, not the routing: the suite
    /// never renders a view, never moves focus and never sees a selection, so
    /// it passed throughout while every typed first character was being eaten.
    /// Changes here have to be re-measured by hosting this view in an
    /// `NSHostingView` and posting real `NSEvent`s — the suite will not tell
    /// you.
    private func focusSearchField(applying edit: (inout String) -> Void) {
        focusTarget = .search
        var text = search.text
        edit(&text)
        search.text = text
    }

    /// Closes the search and hands the keyboard back to the root container.
    ///
    /// Synchronous, unlike `activateSearch`: `.list` names the root container,
    /// which is always in the tree, so there's no inserted view to wait for.
    /// The `onChange(of: search.isActive)` above would catch this too — the
    /// explicit write is what keeps the local path from depending on that.
    ///
    /// The pending selection is the same trap the jump exists to avoid:
    /// clearing the query changes the list, and the top card would otherwise
    /// take the selection away from whatever the user had highlighted.
    ///
    /// This arms on *every* close, including one that narrowed nothing — so
    /// the clear below is not an edge case, it's the common path. Deferred
    /// rather than immediate for the reason spelled out in `jumpToHistory`:
    /// clearing in this same turn would run before the list-change handler
    /// could consume it, which is the whole point of arming it.
    ///
    /// The scroll request is armed for the same reason `jumpToHistory` arms
    /// one, and it is not optional: preserving the selection without revealing
    /// it is worse than not preserving it. `selectionAfterListChange` resolves
    /// to the id already in `selectedID`, so `onChange(of: selectedID)` never
    /// fires and nothing scrolls — the full history comes back with the strip
    /// at its head while the selected card sits at, say, index 47, off screen,
    /// with `↵`/`⌘C`/`⌘E`/`⌫` all acting on a card the user cannot see. With
    /// the preview panel open it is worse still: `cardFrames` holds no frame
    /// for an unrendered card and the panel jumps to the centre of the screen.
    ///
    /// Deferred by a turn, like the jump's: the id isn't in the rendered list
    /// until the cleared query has changed it.
    private func closeSearch() {
        let revealed = selectedID
        pendingSelection = revealed
        search.close()
        focusTarget = .list
        Task { @MainActor in
            if let revealed { scrollRequest = revealed }
            pendingSelection = nil
        }
    }

    /// Clears search and filters, then reveals the item in the full history.
    ///
    /// The order matters: clearing first, scrolling second. Asking for the
    /// scroll in the same cycle does nothing — the id isn't in the rendered
    /// list yet, which is why the request is deferred by one turn of the
    /// main actor.
    ///
    /// The pending id is dropped in that same deferred turn, and not before.
    /// It is meant to survive exactly one list change: the list-change handler
    /// consumes it first when the head of the list actually moved, and when it
    /// didn't move — the head of the search results was already the head of the
    /// history — the handler never runs and this is what stops the id from
    /// staying armed indefinitely. Left armed, the next unrelated list change
    /// would honour it, and if the item had been deleted meanwhile the
    /// selection would point at a card that no longer exists. Clearing it
    /// immediately instead would defeat the arming entirely.
    ///
    /// Note this bounds how long a stale id can live; it does not verify that
    /// the id is still in the list. Nothing here does.
    private func jumpToHistory(_ item: ClipboardItem) {
        pendingSelection = item.id
        search.close()
        focusTarget = .list
        selectedID = item.id
        Task { @MainActor in
            scrollRequest = item.id
            pendingSelection = nil
        }
    }

    private func pick(_ item: ClipboardItem, plainText: Bool? = nil) {
        itemActions.paste(item, plainText: plainText ?? pastesPlainText)
    }

    /// The block counterpart of `pick`.
    ///
    /// Doesn't go through `ItemActions`: that type is "everything you can do
    /// to **one** item", and its `paste` records `lastUsedAt` for a single
    /// item. The N-item bookkeeping happens inside `writeJoined`, in one
    /// place — see `MultiPaste.markUsed`.
    private func pickMultiple(_ block: [ClipboardItem], plainText: Bool) {
        onPickMultiple(block, plainText)
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
        onPreviewSelectionChange(item, cardFrames.frame(for: item.id))
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
        let anchor = selectedID.flatMap { cardFrames.frame(for: $0) }
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
    ///
    /// Unmarking is part of the deletion, not housekeeping: the mark branch of
    /// the ↵ handler runs on `marked.isEmpty` alone, so an id left behind here
    /// makes ↵ swallow the key and paste nothing — a card marked and then
    /// deleted turns ↵ into a dead key while the count pill still says "1
    /// marked ↵ paste". `MultiPaste.resolve` dropping the id at paste time
    /// covers what lands in the block, and nothing else.
    private func delete(_ item: ClipboardItem) {
        let deletedID = item.id
        let wasSelected = selectedID == deletedID
        let remaining = filtered.filter { $0.id != deletedID }
        let index = filtered.firstIndex { $0.id == deletedID }

        marked.remove(deletedID)
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

    private func selectScope(_ id: UUID?) {
        scope.select(id)
        // The selection follows the new list's first card, through the same
        // path a search change already takes.
        selectedID = nil
    }

    /// Creates a board, makes it the active scope and opens its pill for
    /// renaming — the one flow `design-refs/14-pinboard-novo-vazio.png` shows.
    private func createBoard() {
        let board = pinboardActions.create()
        scope.select(board.id)
        renamingBoardID = board.id
        selectedID = nil
    }

    /// Steps through History → board 1 → board 2 → … → History.
    private func cycleScope(forward: Bool) {
        let ids: [UUID?] = [nil] + boards.map { Optional($0.id) }
        guard ids.count > 1 else { return }
        let current = ids.firstIndex(of: scope.activeID) ?? 0
        let step = forward ? 1 : -1
        let next = (current + step + ids.count) % ids.count
        selectScope(ids[next])
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

/// Holds each visible card's on-screen frame.
///
/// Deliberately NOT `@Observable` and NOT an `ObservableObject`: `OverlayView`
/// writes here on every card-frame change, which during a scroll animation is
/// every tick. Publishing those writes would invalidate the body — and with it
/// the entire `ForEach` of cards — on every frame, which is what made image
/// decoding run per frame before this phase. A plain reference type kept in
/// `@State` survives view updates without triggering any.
final class CardFrameStore {
    private var frames: [UUID: CGRect] = [:]

    /// Replaces the whole map: `CardFramePreferenceKey.reduce` already merges
    /// every card's contribution before this is called.
    func update(_ frames: [UUID: CGRect]) {
        self.frames = frames
    }

    func frame(for id: UUID) -> CGRect? {
        frames[id]
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

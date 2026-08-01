//
//  SearchTextField.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

/// The overlay's search field, backed by AppKit so the caret can be **placed**
/// instead of raced.
///
/// SwiftUI's `TextField` selects its entire contents whenever focus arrives
/// programmatically, so anything already in the query is destroyed by the next
/// keystroke. Phase 3 worked around that by writing the text one main-actor
/// turn after the focus write and then reaching into `NSApp.windows` for the
/// field editor; measured, that squeezed the race rather than removing it —
/// keys typed 20ms apart came out reordered (`ghi` → `gih`, 10/10).
///
/// An `NSTextField` selects all on focus too (measured: the same `{0,3}` as
/// SwiftUI's). The difference is that here the moment focus lands is a method
/// this file overrides — `SearchNSTextField.becomeFirstResponder()` — so the
/// selection is collapsed to a caret at the end **inside the same call stack**,
/// before any other event can be delivered. Nothing is deferred, so there is no
/// ordering to get wrong.
struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    /// Read to take first responder, and written when AppKit hands the field an
    /// editor by a route SwiftUI didn't start (a click straight into the text).
    ///
    /// The tag itself — `.focused($focusTarget, equals: .search)` — is applied
    /// by `SearchFieldView`, and it is not optional: measured, a `@FocusState`
    /// written to a value no view in the tree claims is dropped and reverts to
    /// its previous value, which would leave the field unfocusable and
    /// `OverlayView.typesIntoDetachedField` permanently true.
    @FocusState.Binding var focusTarget: OverlayFocusTarget?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> SearchNSTextField {
        let field = SearchNSTextField()
        field.delegate = context.coordinator
        // No chrome of its own: the capsule, its stroke and its padding all
        // belong to `SearchFieldView`. The focus ring is off for the same
        // reason `OverlayView` applies `focusEffectDisabled()` at the root —
        // the accent stroke is this field's only focus affordance.
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 14)
        field.placeholderString = placeholder
        field.textColor = .labelColor
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        field.cell?.isScrollable = true
        // Return is `OverlayView`'s (it pastes the selected card) and never
        // reaches the field, but an action left wired would end editing if it
        // ever did.
        field.target = nil
        field.action = nil
        // No content-hugging or compression-resistance priorities here: under
        // SwiftUI this view's size comes from `sizeThatFits` below and the
        // `.frame(maxWidth: .infinity)` at the call site, and Auto Layout
        // priorities are never consulted. Setting them read as if they were
        // what made the field flexible, which they are not — rendered with and
        // without them, the field is the same pixel.
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: SearchNSTextField, context: Context) {
        context.coordinator.parent = self
        if field.placeholderString != placeholder { field.placeholderString = placeholder }

        // Only when it actually differs. While the user types, the field is the
        // source of the value and this is a no-op — writing `stringValue`
        // unconditionally would rebuild the field editor's contents on every
        // keystroke and throw the caret to the end mid-word.
        // Never while a dead key or an input method is mid-composition: `á`
        // typed as `´` then `a` goes through marked text, and replacing the
        // value under it cancels the composition. The guard costs nothing —
        // during composition `text` is whatever the last committed change said,
        // and the commit itself comes back through `controlTextDidChange`.
        let isComposing = (field.currentEditor() as? NSTextView)?.hasMarkedText() ?? false
        if !isComposing, field.stringValue != text {
            field.stringValue = text
            // The writer is always `OverlayView` appending, seeding or clearing
            // — never an edit in the middle — so the end is where the caret
            // belongs. Setting `stringValue` on a field being edited leaves the
            // whole value selected otherwise.
            field.moveCaretToEnd()
        }

        // A fallback, not the main route: measured, SwiftUI moves the first
        // responder into this view itself when `focusTarget` becomes `.search`.
        // It costs one comparison and covers the case this project has already
        // been bitten by twice — a focus write that lands nowhere, leaving the
        // overlay silently keyboard-dead.
        //
        // Deliberately one-directional. There is no matching "resign when
        // focusTarget != .search": SwiftUI delivers a stale update carrying the
        // *old* target right after it moves focus here. That branch was built
        // and measured — typing `ghi` produced `g`, because the stale update
        // pushed the keyboard back out of the field before the second key.
        //
        // What makes the grab safe is that today every route away from
        // `.search` also takes this view out of the tree, so a stale `.search`
        // can never reach a field that should have given the keyboard up. A
        // future phase that moves focus off the field while the search stays
        // open breaks that: this line would then quietly drag the keyboard back
        // every time SwiftUI redraws. Re-measure here if that day comes.
        if focusTarget == .search, field.currentEditor() == nil, let window = field.window {
            window.makeFirstResponder(field)
        }
    }

    /// Fills the row the way the `TextField` it replaces did.
    ///
    /// Without this the representable reports only its intrinsic (content-sized)
    /// width and the capsule collapses around the text. Zero is honest for the
    /// minimum — the field is what gives way when filter tokens crowd the row,
    /// which is the behaviour `SearchFieldView.visibleTokenLimit` was measured
    /// against.
    func sizeThatFits(_ proposal: ProposedViewSize,
                      nsView: SearchNSTextField,
                      context: Context) -> CGSize? {
        let intrinsic = nsView.intrinsicContentSize
        let width: CGFloat
        if let proposed = proposal.width, proposed.isFinite {
            width = proposed
        } else {
            width = intrinsic.width
        }
        return CGSize(width: width, height: intrinsic.height)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchTextField

        init(_ parent: SearchTextField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        /// Keeps `focusTarget` honest when AppKit — not SwiftUI — is what gave
        /// the field its editor, i.e. a click landing straight in the text.
        ///
        /// Measured, SwiftUI does update the binding on such a click by itself,
        /// so this is a safety net rather than the mechanism. It matters
        /// because `focusTarget` is what `OverlayView.typesIntoDetachedField`
        /// reads: were it left on `.list` with the field editing, every typed
        /// character would be applied twice — once by the overlay's handler and
        /// once by the field.
        func controlTextDidBeginEditing(_ notification: Notification) {
            if parent.focusTarget != .search { parent.focusTarget = .search }
        }
    }
}

/// An `NSTextField` that takes focus with the caret at the end instead of with
/// everything selected.
///
/// This override is the entire point of the AppKit detour. `becomeFirstResponder`
/// is where AppKit installs the field editor and selects the whole value; the
/// collapse happens right after `super`, synchronously, so no event can be
/// delivered in between. Compare the deferred write it replaces, which had to
/// guess how many main-actor turns the select-all would take.
final class SearchNSTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { moveCaretToEnd() }
        return accepted
    }

    // There is deliberately no teardown override here. Closing the search does
    // leave AppKit with the *window* as its first responder — measured — but
    // putting the keyboard back on the hosting view from this class was
    // measured not to revive it: what SwiftUI needs is a fresh focus value,
    // which is why the handback lives in `SearchFieldView.onDisappear`.

    /// A no-op unless the field is being edited — with no field editor there is
    /// no selection to collapse, and the next `becomeFirstResponder` will place
    /// the caret anyway.
    func moveCaretToEnd() {
        guard let editor = currentEditor() else { return }
        editor.selectedRange = NSRange(location: (stringValue as NSString).length, length: 0)
    }
}

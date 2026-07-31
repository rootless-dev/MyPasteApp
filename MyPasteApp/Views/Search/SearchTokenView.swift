//
//  SearchTokenView.swift
//  MyPasteApp
//

import SwiftUI

/// One active filter, shown inside the field ahead of the text.
///
/// An active filter the user can't see is the failure mode that makes someone
/// believe their history vanished — so a token is never smaller than its own
/// remove button.
struct SearchTokenView: View {
    let token: SearchToken
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
            // Deliberately uncapped. A `.frame(maxWidth:)` here or on the pill
            // doesn't cap — it *expands* to whatever is proposed, so a short
            // token grew a pill full of dead space while a long one truncated
            // in the same row. `lineLimit(1)` alone is what's wanted: the
            // label takes its ideal width and the enclosing `HStack` truncates
            // it only when the row actually runs out of room, which is both
            // tighter and more legible at every token count.
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.accentColor.opacity(0.22)))
        .foregroundStyle(Color.accentColor)
    }

    /// `@MainActor` because `AppFacetDisplay` is: the app-name lookup reads
    /// `NSWorkspace` through a mutable static cache. Only `body` inherits
    /// isolation from the `View` conformance, so a helper it calls has to say
    /// so itself.
    @MainActor
    private var label: String {
        switch token {
        case .type(let type): return type.filterLabel
        case .app(let facet): return AppFacetDisplay.name(for: facet)
        case .date(let window): return window.label
        }
    }

    private var symbol: String {
        switch token {
        case .type(let type): return type.filterSymbol
        case .app: return "app.badge"
        case .date: return "calendar"
        }
    }
}

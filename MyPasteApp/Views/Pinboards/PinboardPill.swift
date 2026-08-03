//
//  PinboardPill.swift
//  MyPasteApp
//

import SwiftUI

/// One entry in the scope strip: the history, or a pinboard.
///
/// Collapses to just its dot or glyph while the search is open — the strip and
/// the search field share the same horizontal band, and this is how the
/// reference resolves the conflict (`design-refs/12-busca-ativa.png`): nothing
/// disappears, it only loses its label.
struct PinboardPill: View {
    let title: String
    /// nil means the history pill, which shows a clock instead of a dot.
    let colorHex: String?
    let isSelected: Bool
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                marker
                if !isCollapsed {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 120, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, isCollapsed ? 8 : 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.primary.opacity(isSelected ? 0.15 : 0.06))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    @ViewBuilder
    private var marker: some View {
        if let colorHex {
            Circle()
                .fill(Color(hex: colorHex) ?? .gray)
                .frame(width: 8, height: 8)
        } else {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .medium))
        }
    }
}

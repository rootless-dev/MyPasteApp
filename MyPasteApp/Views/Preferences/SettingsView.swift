//
//  SettingsView.swift
//  MyPasteApp
//

import SwiftUI

/// The Settings window: a sidebar of sections plus the selected section's
/// content.
///
/// A sidebar rather than a `TabView` because it scales: the roadmap adds
/// preferences for pinboards, per-app rules, OCR and backup, and tabs would be
/// cramped well before that. It's also what System Settings itself does.
struct SettingsView: View {
    enum Section: String, CaseIterable, Identifiable {
        case general, history, appearance, shortcuts, privacy

        var id: String { rawValue }

        var label: String {
            switch self {
            case .general:    return "General"
            case .history:    return "History"
            case .appearance: return "Appearance"
            case .shortcuts:  return "Shortcuts"
            case .privacy:    return "Privacy"
            }
        }

        var symbol: String {
            switch self {
            case .general:    return "gearshape"
            case .history:    return "clock"
            case .appearance: return "paintbrush"
            case .shortcuts:  return "keyboard"
            case .privacy:    return "hand.raised"
            }
        }
    }

    @State private var selection: Section = .general

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.label, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            detail
                .navigationTitle(selection.label)
                .frame(minWidth: 420, minHeight: 400)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:    GeneralSettingsView()
        case .history:    HistorySettingsView()
        case .appearance: AppearanceSettingsView()
        case .shortcuts:  ShortcutsSettingsView()
        case .privacy:    PrivacySettingsView()
        }
    }
}

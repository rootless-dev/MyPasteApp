//
//  AppearanceSettingsView.swift
//  MyPasteApp
//

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(PreferenceKeys.cardDensity) private var cardDensity: String = CardDensity.comfortable.rawValue
    @AppStorage(PreferenceKeys.showLinkPreviews) private var showLinkPreviews: Bool = true
    @AppStorage(PreferenceKeys.showQuickPasteNumbers) private var showQuickPasteNumbers: Bool = true

    var body: some View {
        Form {
            Section {
                Picker("Card density", selection: $cardDensity) {
                    ForEach(CardDensity.allCases) { d in
                        Text(d.label).tag(d.rawValue)
                    }
                }
                SettingsToggle(
                    title: "Show link previews",
                    description: "Fetches the title, banner and favicon of copied links.",
                    isOn: $showLinkPreviews
                )
                SettingsToggle(
                    title: "Show quick paste numbers",
                    description: "⌘1–⌘9 paste the first nine visible cards. The shortcuts keep working with the numbers hidden.",
                    isOn: $showQuickPasteNumbers
                )
            }
        }
        .formStyle(.grouped)
    }
}

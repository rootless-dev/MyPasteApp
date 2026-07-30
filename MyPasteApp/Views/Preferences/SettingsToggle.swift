//
//  SettingsToggle.swift
//  MyPasteApp
//

import SwiftUI

/// A toggle with a line of explanation under it.
///
/// Every non-obvious preference gets one: a switch whose consequence isn't
/// visible from its label is a setting nobody understands without trying it.
struct SettingsToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: $isOn)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

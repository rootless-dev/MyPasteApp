//
//  RetentionSlider.swift
//  MyPasteApp
//

import SwiftUI

/// Retention as five named stops instead of a day count.
///
/// A value that isn't one of the stops (an existing 45-day setting) shows at
/// the closest one but is only rewritten when the user actually drags — no
/// configuration changes by itself just because the screen was opened.
struct RetentionSlider: View {
    @Binding var days: Int

    private var stops: [RetentionWindow] { RetentionWindow.allCases }

    private var index: Double {
        let window = RetentionWindow(days: days) ?? RetentionWindow.nearest(toDays: days)
        return Double(stops.firstIndex(of: window) ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Slider(
                value: Binding(
                    get: { index },
                    set: { days = stops[Int($0.rounded())].days }
                ),
                in: 0...Double(stops.count - 1),
                step: 1
            )
            HStack {
                ForEach(stops, id: \.self) { stop in
                    Text(stop.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if stop != stops.last { Spacer() }
                }
            }
            if RetentionWindow(days: days) == nil {
                Text("Currently set to \(days) days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

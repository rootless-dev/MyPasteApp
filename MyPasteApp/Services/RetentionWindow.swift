//
//  RetentionWindow.swift
//  MyPasteApp
//

import Foundation

/// The named stops of the retention slider.
///
/// The user thinks in durations, not in day counts, which is why the Settings
/// screen offers five stops instead of a number field. `forever` stores 0 —
/// see `RetentionPolicy.retentionDays` for why that value can't be read with
/// `integer(forKey:)`.
enum RetentionWindow: CaseIterable {
    case day
    case week
    case month
    case year
    case forever

    var days: Int {
        switch self {
        case .day:     return 1
        case .week:    return 7
        case .month:   return 30
        case .year:    return 365
        case .forever: return 0
        }
    }

    var label: String {
        switch self {
        case .day:     return "Day"
        case .week:    return "Week"
        case .month:   return "Month"
        case .year:    return "Year"
        case .forever: return "Forever"
        }
    }

    init?(days: Int) {
        guard let match = Self.allCases.first(where: { $0.days == days }) else {
            return nil
        }
        self = match
    }

    /// The stop to show the slider at for a value that isn't itself a stop —
    /// a setting of 45 days, for instance.
    ///
    /// Display only: nothing is written back until the user drags the slider,
    /// so an existing configuration is never silently rounded.
    ///
    /// `forever` is excluded from the search because its stored value is 0,
    /// which would otherwise measure as the closest stop to every small number.
    static func nearest(toDays days: Int) -> RetentionWindow {
        if days == 0 { return .forever }
        let finite = allCases.filter { $0 != .forever }
        return finite.min { abs($0.days - days) < abs($1.days - days) } ?? .month
    }
}

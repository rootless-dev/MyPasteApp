//
//  ItemRetention.swift
//  MyPasteApp
//

import Foundation

/// What should happen to one item, independently of the global policy.
///
/// Two stored fields (`keepForever`, `expiresAt`) express three states, so
/// reading and writing them go through here rather than being open-coded at
/// each call site — that's what keeps the fourth, meaningless combination
/// (both set) from being written in the first place.
enum ItemRetention: Equatable {
    /// Follow `retentionDays` and `maxItems`, like everything else.
    case global
    case forever
    case until(Date)

    static func of(keepForever: Bool, expiresAt: Date?) -> ItemRetention {
        // A date first: see `ItemRetentionTests.dateWinsOverForever`.
        if let expiresAt { return .until(expiresAt) }
        if keepForever { return .forever }
        return .global
    }

    /// Both fields, always — writing only the one that changed is how the
    /// inconsistent state would be born.
    var fields: (keepForever: Bool, expiresAt: Date?) {
        switch self {
        case .global: return (false, nil)
        case .forever: return (true, nil)
        case .until(let date): return (false, date)
        }
    }
}

/// The durations offered in the card's "Keep" menu.
///
/// Named durations rather than a date picker: the useful choices are coarse,
/// and a picker inside a context menu inside a non-activating panel is a lot
/// of surface for no extra reach.
enum RetentionOffer: CaseIterable {
    case hour
    case day
    case week
    case month

    var title: String {
        switch self {
        case .hour:  return "Expire in 1 hour"
        case .day:   return "Expire in 1 day"
        case .week:  return "Expire in 1 week"
        case .month: return "Expire in 30 days"
        }
    }

    /// Plain interval arithmetic, not `Calendar`: these are "an hour from
    /// now", not "the same wall-clock time tomorrow", so a DST boundary
    /// shouldn't move them.
    func date(from now: Date) -> Date {
        switch self {
        case .hour:  return now.addingTimeInterval(3600)
        case .day:   return now.addingTimeInterval(86_400)
        case .week:  return now.addingTimeInterval(7 * 86_400)
        case .month: return now.addingTimeInterval(30 * 86_400)
        }
    }
}

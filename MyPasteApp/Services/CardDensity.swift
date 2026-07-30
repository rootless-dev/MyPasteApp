//
//  CardDensity.swift
//  MyPasteApp
//

import CoreGraphics
import Foundation

enum CardDensity: String, CaseIterable, Identifiable {
    case compact
    case comfortable
    case spacious

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact:     return "Compact"
        case .comfortable: return "Comfortable"
        case .spacious:    return "Spacious"
        }
    }

    var width: CGFloat {
        switch self {
        case .compact:     return 160
        case .comfortable: return 200
        case .spacious:    return 240
        }
    }

    var height: CGFloat {
        switch self {
        case .compact:     return 180
        case .comfortable: return 220
        case .spacious:    return 260
        }
    }
}

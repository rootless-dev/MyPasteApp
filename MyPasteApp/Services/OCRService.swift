//
//  OCRService.swift
//  MyPasteApp
//

import Foundation
import Vision

/// Local text recognition over an image.
///
/// Nothing here leaves the machine: Vision runs on-device, which is what makes
/// this acceptable to have on by default over the user's clipboard history.
enum OCRService {
    /// Ceiling on the stored result. Documented in the Privacy settings copy.
    static let maxCharacters = 10_000

    /// Portuguese first, then English. Vision's default is English only, which
    /// degrades Portuguese recognition badly enough to be the difference
    /// between finding an item and not finding it.
    static let languages = ["pt-BR", "en-US"]

    /// The bytes go straight from `imageData` into Vision, without an
    /// `NSImage` in between — Phase 2.5 measured what decoding an image you
    /// don't need to display costs.
    static func recognize(imageData: Data) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages.map(Locale.Language.init(identifier:))
        let observations = try await request.perform(on: imageData)
        return normalize(observations.compactMap { $0.topCandidates(1).first?.string })
    }

    /// Joins recognised lines and applies the cap. Pure, so the shape of the
    /// stored text is testable without running Vision.
    static func normalize(_ lines: [String]) -> String {
        let joined = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return String(joined.prefix(maxCharacters))
    }
}

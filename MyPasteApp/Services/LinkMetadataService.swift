//
//  LinkMetadataService.swift
//  MyPasteApp
//

import AppKit
import CoreImage
import Foundation

struct LinkMetadata {
    var title: String?
    var imageData: Data?
    var faviconData: Data?
    var backgroundHex: String?
}

enum LinkMetadataService {

    static func fetch(from url: URL) async -> LinkMetadata {
        var result = LinkMetadata()
        guard let html = await downloadHTML(url: url) else { return result }

        result.title = extractTitle(html: html)

        let metas = extractTags(html: html, name: "meta")
        let links = extractTags(html: html, name: "link")

        // og:image / twitter:image
        let bannerString =
            firstMetaContent(metas, key: "property", value: "og:image")
            ?? firstMetaContent(metas, key: "name", value: "og:image")
            ?? firstMetaContent(metas, key: "name", value: "twitter:image")
            ?? firstMetaContent(metas, key: "property", value: "twitter:image")

        if let bannerString,
           let bannerURL = URL(string: bannerString, relativeTo: url)?.absoluteURL {
            result.imageData = await downloadData(url: bannerURL)
        }

        // favicon / apple-touch-icon (preferir apple-touch-icon — maior)
        let iconString =
            firstLinkHref(links, relMatches: ["apple-touch-icon", "apple-touch-icon-precomposed"])
            ?? firstLinkHref(links, relMatches: ["icon", "shortcut icon"])

        let iconURL = iconString.flatMap { URL(string: $0, relativeTo: url)?.absoluteURL }
            ?? URL(string: "/favicon.ico", relativeTo: url)?.absoluteURL

        if let iconURL {
            result.faviconData = await downloadData(url: iconURL)
        }

        // Dominant color from favicon (preferred) or banner
        if let data = result.faviconData ?? result.imageData,
           let img = NSImage(data: data),
           let hex = dominantColorHex(of: img) {
            result.backgroundHex = hex
        }

        return result
    }

    // MARK: - HTML / network

    private static func downloadHTML(url: URL) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.setValue("Mozilla/5.0 MyPasteApp", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        let slice = data.prefix(128 * 1024)
        return String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .isoLatin1)
    }

    private static func downloadData(url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.setValue("Mozilla/5.0 MyPasteApp", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        guard data.count > 0, data.count < 5 * 1024 * 1024 else { return nil }
        return data
    }

    // MARK: - Parsing

    private static func extractTitle(html: String) -> String? {
        guard let match = firstMatch(in: html, pattern: "<title[^>]*>([\\s\\S]*?)</title>") else { return nil }
        let raw = match
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        return raw.isEmpty ? nil : raw
    }

    private static func firstMatch(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[r])
    }

    /// Extracts all `<name ...>` tags (only the content between `<` and `>`).
    private static func extractTags(html: String, name: String) -> [String] {
        let pattern = "<\(name)\\b[^>]*/?>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap {
            Range($0.range, in: html).map { String(html[$0]) }
        }
    }

    /// Reads the value of an HTML attribute (`name="value"` or `name='value'`).
    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "\\b\(name)\\s*=\\s*[\"']([^\"']*)[\"']"
        return firstMatch(in: tag, pattern: pattern)
    }

    private static func firstMetaContent(_ metas: [String], key: String, value: String) -> String? {
        for tag in metas {
            if let v = attribute(key, in: tag), v.lowercased() == value.lowercased(),
               let content = attribute("content", in: tag), !content.isEmpty {
                return content
            }
        }
        return nil
    }

    private static func firstLinkHref(_ links: [String], relMatches: [String]) -> String? {
        let wanted = Set(relMatches.map { $0.lowercased() })
        for tag in links {
            guard let rel = attribute("rel", in: tag) else { continue }
            let rels = rel.lowercased().split(separator: " ").map(String.init)
            if rels.contains(where: { wanted.contains($0) }) || wanted.contains(rel.lowercased()) {
                if let href = attribute("href", in: tag), !href.isEmpty {
                    return href
                }
            }
        }
        return nil
    }

    // MARK: - Dominant color

    private static func dominantColorHex(of image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation,
              let ciImage = CIImage(data: tiff) else { return nil }

        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let output = filter?.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(output,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())

        return String(format: "#%02X%02X%02X", bitmap[0], bitmap[1], bitmap[2])
    }
}

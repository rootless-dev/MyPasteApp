//
//  ClipboardMonitor.swift
//  MyPasteApp
//

import AppKit
import CryptoKit
import Foundation
import SwiftData

@MainActor
final class ClipboardMonitor {
    private let modelContext: ModelContext
    private let defaults: UserDefaults
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    /// When true, ignores the next detected change (used by ClipboardWriter
    /// to avoid recapturing items it just wrote back to the pasteboard).
    var ignoreNextChange = false

    /// Set by the AppDelegate right after construction. Weak because the
    /// delegate owns the controller.
    weak var pauseController: PauseController?

    init(modelContext: ModelContext, defaults: UserDefaults = .standard) {
        self.modelContext = modelContext
        self.defaults = defaults
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        backfillLinkMetadata()
    }

    /// For URL-type items saved before visual metadata support existed,
    /// kicks off an async background fetch to populate banner/favicon/color.
    private func backfillLinkMetadata() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.typeRaw == "url" }
        )
        guard let items = try? modelContext.fetch(descriptor) else { return }
        for item in items where item.linkImageData == nil && item.linkFaviconData == nil {
            guard let urlString = item.textContent,
                  let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
                  url.scheme?.hasPrefix("http") == true else { continue }
            fetchLinkMetadata(for: item, url: url)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        // Checked *after* lastChangeCount was updated above, so resuming
        // doesn't capture whatever was copied during the pause.
        if pauseController?.isPaused == true {
            return
        }

        // Checked before reading anything: discarding the string afterwards
        // would have let the password travel through the app for no reason.
        if PasteboardPrivacy.shouldIgnore(types: pasteboard.types ?? [],
                                          settings: .current(from: defaults)) {
            return
        }

        guard let item = readCurrentItem() else { return }

        // Skip ignored source apps.
        if let bundleID = item.sourceAppBundleID,
           Self.ignoredBundleIDs(from: defaults).contains(bundleID) {
            return
        }

        insertIfNotDuplicate(item)

        if item.type == .url, let urlString = item.textContent,
           let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme?.hasPrefix("http") == true {
            fetchLinkMetadata(for: item, url: url)
        }
    }

    // MARK: - Link metadata

    private func fetchLinkMetadata(for item: ClipboardItem, url: URL) {
        guard Self.showLinkPreviews(from: defaults) else { return }
        Task { [weak self] in
            let metadata = await LinkMetadataService.fetch(from: url)
            await MainActor.run {
                guard let self else { return }
                if let title = metadata.title { item.linkTitle = title }
                item.linkImageData = metadata.imageData
                item.linkFaviconData = metadata.faviconData
                item.linkBackgroundHex = metadata.backgroundHex
                try? self.modelContext.save()
            }
        }
    }

    // MARK: - Reading

    private func readCurrentItem() -> ClipboardItem? {
        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // Prioridade: file URLs > image > URL > string
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let strings = urls.map { $0.path }
            let preview = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) arquivos"
            return ClipboardItem(
                type: .file,
                preview: preview,
                contentHash: Self.hash(strings.joined(separator: "\n")),
                fileURLStrings: strings,
                sourceAppBundleID: sourceApp
            )
        }

        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return ClipboardItem(
                type: .image,
                preview: "Imagem \(Int(image.size.width))×\(Int(image.size.height))",
                contentHash: Self.hash(png),
                imageData: png,
                sourceAppBundleID: sourceApp
            )
        }

        if let str = pasteboard.string(forType: .string) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            let isURL = URL(string: trimmed).map { $0.scheme != nil } ?? false
            return ClipboardItem(
                type: isURL ? .url : .text,
                preview: String(str.prefix(Self.previewTextLength(from: defaults))),
                contentHash: Self.hash(str),
                textContent: str,
                sourceAppBundleID: sourceApp
            )
        }

        return nil
    }

    // MARK: - Persist

    private func insertIfNotDuplicate(_ item: ClipboardItem) {
        let hash = item.contentHash
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.contentHash == hash },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.createdAt = .now
            return
        }

        modelContext.insert(item)
        try? modelContext.save()

        if Self.soundFeedbackEnabled(from: defaults) {
            NSSound(named: "Tink")?.play()
        }
    }

    // MARK: - Hash helpers

    static func hash(_ string: String) -> String {
        hash(Data(string.utf8))
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Preferences
    //
    // Each reader takes its store explicitly (defaulting to the real one) so
    // tests can pass an isolated suite instead of touching the user's
    // preferences. Views bind these same keys with @AppStorage, which always
    // talks to UserDefaults.standard.

    /// How many characters of a copied string to keep as the card preview.
    static func previewTextLength(from defaults: UserDefaults = .standard) -> Int {
        let v = defaults.integer(forKey: "previewTextLength")
        return v > 0 ? v : 200
    }

    static func showLinkPreviews(from defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: "showLinkPreviews") as? Bool ?? true
    }

    static func soundFeedbackEnabled(from defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: "enableSoundFeedback") as? Bool ?? true
    }

    /// Parses the user's ignored-apps list, stored as a string of bundle IDs
    /// separated by newlines or commas.
    static func ignoredBundleIDs(from defaults: UserDefaults = .standard) -> Set<String> {
        let raw = defaults.string(forKey: "ignoredAppsRaw") ?? ""
        // isNewline rather than == "\n": a CRLF pair is a single Character in
        // Swift, so comparing against "\n" would miss a list pasted out of a
        // Windows file and leave the separator glued to each bundle ID.
        let parts = raw.split(whereSeparator: { $0.isNewline || $0 == "," })
        return Set(
            parts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}

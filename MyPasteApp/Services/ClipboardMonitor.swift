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
    private lazy var ocrQueue = OCRQueue(modelContext: modelContext, defaults: defaults)

    /// Last seen value of the OCR preference, so a flip from off to on can
    /// repopulate the queue. `OCRQueue.drain()` discards everything pending
    /// when it finds the preference off, and only `enqueueBacklog()` puts it
    /// back — without this, turning OCR back on would recognise new captures
    /// while the existing history stayed permanently blank until a relaunch.
    /// Assigned in `init`, not inline: a property initializer can't reach
    /// `self.defaults`, and reading `UserDefaults.standard` here would silently
    /// ignore whatever store this instance was constructed with.
    private var lastSeenOCREnabled: Bool

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
        self.lastSeenOCREnabled = OCRQueue.isEnabled(from: defaults)
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        backfillLinkMetadata()
        ocrQueue.enqueueBacklog()
    }

    /// For URL-type items saved before visual metadata support existed,
    /// kicks off an async background fetch to populate banner/favicon/color.
    private func backfillLinkMetadata() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.typeRaw == "url" }
        )
        guard let items = try? modelContext.fetch(descriptor) else { return }
        for item in items where Self.needsLinkMetadata(item) {
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
        let ocrEnabled = OCRQueue.isEnabled(from: defaults)
        if ocrEnabled, !lastSeenOCREnabled { ocrQueue.enqueueBacklog() }
        lastSeenOCREnabled = ocrEnabled

        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        // `lastChangeCount` above has to be updated before this runs, so
        // resuming doesn't recapture whatever was copied during the pause;
        // and nothing here reads off the pasteboard before this decision
        // either, so a password never travels through the app for a result
        // about to be discarded. Delegated to a pure function so both
        // orderings are covered by a test that doesn't need a real
        // NSPasteboard.
        guard Self.shouldCapture(isPaused: pauseController?.isPaused == true,
                                 types: pasteboard.types ?? [],
                                 settings: .current(from: defaults)) else {
            return
        }

        // The per-app rules, first half: an app the user banned outright is
        // rejected here, before anything is read off the pasteboard. This used
        // to run *after* readCurrentItem(), which meant a password manager's
        // content was read into a ClipboardItem and only then dropped — never
        // stored, but read. `AppRules.ignoresEverything` takes a bundle ID and
        // nothing else, so this decision can't drift back into depending on
        // the content.
        let rules = AppRules.load(from: defaults)
        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if AppRules.ignoresEverything(sourceApp, rules: rules) { return }

        guard let item = readCurrentItem() else { return }

        // Second half: filtering by type needs the type, which needs the read.
        // There is no way to bring this one forward.
        guard AppRules.allows(type: item.type, from: item.sourceAppBundleID, rules: rules) else {
            return
        }

        // Belt-and-braces: `AppRules.load` migrates the legacy `ignoredAppsRaw`
        // format on the fly, and that migration only splits on a bare "\n" —
        // it mishandles comma-separated and CRLF-separated lists (see
        // AppRulesTests's migration coverage, which doesn't exercise either).
        // `ignoredBundleIDs` below still parses those correctly, so it's kept
        // here as a second check rather than deleted per the Task 10 brief.
        // Tracked for follow-up: fix `AppRules.migratedFromLegacy` to match
        // this parser (comma + CRLF + generic newline), then this block, this
        // function and `ClipboardPreferencesTests`'s "Ignored apps" section
        // can be retired together.
        if let bundleID = item.sourceAppBundleID,
           Self.ignoredBundleIDs(from: defaults).contains(bundleID) {
            return
        }

        let stored = insertIfNotDuplicate(item)

        if OCRScheduler.needsOCR(type: stored.type,
                                 ocrProcessedAt: stored.ocrProcessedAt,
                                 enabled: OCRQueue.isEnabled(from: defaults)) {
            ocrQueue.enqueue(stored.id)
        }

        // `stored` is the *persisted* item, which for a duplicate capture is
        // the one already on screen with its banner, favicon and colour — so
        // this asks the same question the backfill asks, through the same
        // rule. Without it, re-copying a URL pays a full HTML fetch, image
        // download and dominant-colour extraction every single time.
        if Self.needsLinkMetadata(stored),
           let urlString = stored.textContent,
           let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme?.hasPrefix("http") == true {
            fetchLinkMetadata(for: stored, url: url)
        }
    }

    /// Whether a pasteboard change should turn into a capture, given the pause
    /// state and the privacy markers on the pasteboard.
    ///
    /// Pure and static so it can be tested directly against `poll()`'s two
    /// guards, in the order that matters: paused wins outright, then a
    /// privacy marker, and only once both are clear does anything get read
    /// off the pasteboard. `poll()` itself stays a thin caller of this —
    /// updating `lastChangeCount` and consuming `ignoreNextChange` happen
    /// before it and are deliberately not folded in here (see the comment at
    /// the call site).
    static func shouldCapture(isPaused: Bool,
                              types: [NSPasteboard.PasteboardType],
                              settings: PasteboardPrivacy.Settings) -> Bool {
        if isPaused { return false }
        if PasteboardPrivacy.shouldIgnore(types: types, settings: settings) { return false }
        return true
    }

    // MARK: - Link metadata

    /// Whether an item still needs a link-metadata fetch.
    ///
    /// One home for a rule with two callers — the backfill at launch and
    /// `poll()` on every capture. `poll()` used to have no such guard, which
    /// only became visible once Task 2 made `insertIfNotDuplicate` return the
    /// *persisted* item: before that the fetch landed on a throwaway object.
    ///
    /// Visual metadata is what's asked about, not the title: a page with no
    /// `og:image` and no favicon has nothing more to give, and asking again on
    /// every re-copy would download its HTML forever.
    static func needsLinkMetadata(_ item: ClipboardItem) -> Bool {
        guard item.type == .url else { return false }
        return item.linkImageData == nil && item.linkFaviconData == nil
    }

    /// Fills in what the fetch actually found, and only that.
    ///
    /// Every assignment is guarded, `linkTitle` included: `LinkMetadataService`
    /// returns an all-nil result whenever the HTML can't be downloaded —
    /// offline, past the 5s timeout, or a non-HTML response — and this can run
    /// against a *persisted* item (the backfill's items always are), so an
    /// unguarded write would erase the banner, favicon and background colour a
    /// previous, successful fetch had stored. A field that came back nil means
    /// "nothing found this time", never "delete what you have".
    static func apply(_ metadata: LinkMetadata, to item: ClipboardItem) {
        if let title = metadata.title { item.linkTitle = title }
        if let imageData = metadata.imageData { item.linkImageData = imageData }
        if let faviconData = metadata.faviconData { item.linkFaviconData = faviconData }
        if let backgroundHex = metadata.backgroundHex { item.linkBackgroundHex = backgroundHex }
    }

    private func fetchLinkMetadata(for item: ClipboardItem, url: URL) {
        guard Self.showLinkPreviews(from: defaults) else { return }
        Task { [weak self] in
            let metadata = await LinkMetadataService.fetch(from: url)
            await MainActor.run {
                guard let self else { return }
                Self.apply(metadata, to: item)
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
            let format = RichText.preferredFormat(in: pasteboard.types ?? [])
            return ClipboardItem(
                type: isURL ? .url : .text,
                // Both derived from the plain string, deliberately. Hashing the
                // RTF instead would break deduplication: the same text copied
                // from two apps carries different formatting bytes and would
                // come back as a new item every time. A preview with markup in
                // it would also be unreadable on the card.
                preview: String(str.prefix(Self.previewTextLength(from: defaults))),
                contentHash: Self.hash(str),
                textContent: str,
                richTextData: format.flatMap { pasteboard.data(forType: $0.pasteboardType) },
                richTextFormat: format,
                sourceAppBundleID: sourceApp
            )
        }

        return nil
    }

    // MARK: - Persist

    @discardableResult
    private func insertIfNotDuplicate(_ item: ClipboardItem) -> ClipboardItem {
        let hash = item.contentHash
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.contentHash == hash },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.createdAt = .now
            return existing
        }

        modelContext.insert(item)
        try? modelContext.save()

        if Self.soundFeedbackEnabled(from: defaults) {
            NSSound(named: "Tink")?.play()
        }
        return item
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
        let v = defaults.integer(forKey: PreferenceKeys.previewTextLength)
        return v > 0 ? v : 200
    }

    static func showLinkPreviews(from defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: PreferenceKeys.showLinkPreviews) as? Bool ?? true
    }

    static func soundFeedbackEnabled(from defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: PreferenceKeys.enableSoundFeedback) as? Bool ?? true
    }

    /// Parses the user's ignored-apps list, stored as a string of bundle IDs
    /// separated by newlines or commas.
    static func ignoredBundleIDs(from defaults: UserDefaults = .standard) -> Set<String> {
        let raw = defaults.string(forKey: PreferenceKeys.ignoredAppsRaw) ?? ""
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

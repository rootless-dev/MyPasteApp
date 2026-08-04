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
        // resuming doesn't recapture whatever was copied during the pause.
        // Everything this decision needs is either state or metadata — the
        // pasteboard's declared types and the frontmost app's bundle ID — so
        // a password's *content* never travels through the app for a result
        // about to be discarded.
        let rules = AppRules.load(from: defaults)
        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard Self.shouldRead(isPaused: pauseController?.isPaused == true,
                              types: pasteboard.types ?? [],
                              settings: .current(from: defaults),
                              sourceApp: sourceApp,
                              rules: rules) else {
            return
        }

        guard let item = readCurrentItem() else { return }

        // The per-app rules, second half: filtering by type needs the type,
        // which needs the read. There is no way to bring this one forward.
        guard AppRules.allows(type: item.type, from: item.sourceAppBundleID, rules: rules) else {
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
    /// Pure and static so it can be tested directly: paused wins outright,
    /// then a privacy marker. `poll()` itself stays a thin caller of
    /// `shouldRead` below — updating `lastChangeCount` and consuming
    /// `ignoreNextChange` happen before it and are deliberately not folded in
    /// here (see the comment at the call site).
    static func shouldCapture(isPaused: Bool,
                              types: [NSPasteboard.PasteboardType],
                              settings: PasteboardPrivacy.Settings) -> Bool {
        if isPaused { return false }
        if PasteboardPrivacy.shouldIgnore(types: types, settings: settings) { return false }
        return true
    }

    /// Everything decided *before* a byte of content is read off the
    /// pasteboard: the pause, the privacy markers, and an app the user banned
    /// outright.
    ///
    /// The banned-app check used to run after `readCurrentItem()`, which meant
    /// a password manager's content was read into a `ClipboardItem` and only
    /// then dropped — never stored, but read. Its home is this signature: the
    /// inputs here are state and metadata only (declared types, a bundle ID),
    /// with no way to express a rule that needs the content, so the decision
    /// cannot drift back into depending on the read.
    ///
    /// **What that does and does not guarantee.** A test can pin that the ban
    /// belongs to this function — move it out and the test fails. Nothing
    /// automated can pin that `poll()` still calls this *before*
    /// `readCurrentItem()`; that is an ordering of side effects, and the suite
    /// never runs `poll()` (it is private and wired to `NSPasteboard.general`).
    /// That half is owned by code review and by step F7 of the manual script.
    static func shouldRead(isPaused: Bool,
                           types: [NSPasteboard.PasteboardType],
                           settings: PasteboardPrivacy.Settings,
                           sourceApp: String?,
                           rules: [AppRule]) -> Bool {
        guard shouldCapture(isPaused: isPaused, types: types, settings: settings) else {
            return false
        }
        return !AppRules.ignoresEverything(sourceApp, rules: rules)
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

    /// The expiry date a reused item keeps after being copied again.
    ///
    /// Copying something again is a new, later intention than a date set on it
    /// before, so a deadline that has already gone by is dropped: the item is
    /// being promoted to the top of the history as a fresh capture, and
    /// leaving the stale date on it meant the next prune deleted something the
    /// user had copied minutes earlier, with nothing on screen to explain it.
    ///
    /// A date still ahead is left alone — the user asked for that item to go
    /// away at that time, and re-copying it is not a request to keep it
    /// longer. It also still protects the item from the age and volume passes
    /// (`RetentionPolicy.isProtected`), which is the other half of the same
    /// rule.
    static func expiryAfterRecapture(expiresAt: Date?, now: Date) -> Date? {
        guard let expiresAt else { return nil }
        return expiresAt > now ? expiresAt : nil
    }

    @discardableResult
    private func insertIfNotDuplicate(_ item: ClipboardItem) -> ClipboardItem {
        let hash = item.contentHash
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.contentHash == hash },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            let now = Date.now
            existing.createdAt = now
            existing.expiresAt = Self.expiryAfterRecapture(expiresAt: existing.expiresAt,
                                                           now: now)
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
}

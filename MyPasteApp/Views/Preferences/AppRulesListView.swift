//
//  AppRulesListView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The per-app capture rules, as an editable list.
///
/// Replaces the bundle-ID `TextEditor`: typing a reverse-DNS string from
/// memory was the part of this feature nobody could use. The rules themselves
/// live in `UserDefaults` through `AppRules` — this view is the only writer.
struct AppRulesListView: View {
    @State private var rules: [AppRule] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($rules) { $rule in
                AppRuleRow(rule: $rule, onRemove: { remove(rule) })
            }

            HStack(spacing: 12) {
                Button("Add App…") { addApp() }
                Button("Add Password Managers") { addPasswordManagers() }
            }
            .padding(.top, 4)

            Text("Nothing is read from an app set to ignore everything — not even into memory. This is the only protection that doesn't depend on the app marking its own content.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { rules = AppRules.load(from: .standard) }
        .onChange(of: rules) { _, newValue in
            AppRules.save(newValue, to: .standard)
        }
    }

    /// The system's own application picker, rather than a scan of
    /// /Applications: scanning means reading an Info.plist per app, and still
    /// misses anything installed elsewhere.
    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }

        insert(bundleID)
    }

    private func addPasswordManagers() {
        for bundleID in AppRules.knownPasswordManagers { insert(bundleID) }
    }

    /// New rules ignore everything — the safe default, and the case that
    /// covers most of the real use.
    private func insert(_ bundleID: String) {
        guard !rules.contains(where: { $0.bundleID == bundleID }) else { return }
        rules.append(AppRule(bundleID: bundleID, allowedTypes: []))
    }

    private func remove(_ rule: AppRule) {
        rules.removeAll { $0.bundleID == rule.bundleID }
    }
}

/// One app's rule: who it is, whether it's blocked outright, and which types
/// survive when it isn't.
private struct AppRuleRow: View {
    @Binding var rule: AppRule
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text(displayName)
                        .font(.system(size: 12, weight: .medium))
                    // Kept visible even when the name resolves: two installed
                    // apps can share a display name, and the bundle ID is what
                    // the rule actually matches on.
                    Text(rule.bundleID)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: modeBinding) {
                    Text("Ignore everything").tag(true)
                    Text("Capture only").tag(false)
                }
                .labelsHidden()
                .frame(width: 160)
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .help("Remove this rule")
            }

            if !rule.ignoresEverything {
                HStack(spacing: 12) {
                    ForEach(ClipboardItemType.canonicalOrder, id: \.self) { type in
                        Toggle(label(for: type), isOn: typeBinding(type))
                            .toggleStyle(.checkbox)
                    }
                }
                .padding(.leading, 26)
            }
        }
    }

    /// Flipping to "Capture only" seeds every type on: the user is narrowing
    /// from there, and a row that starts with nothing checked would be an
    /// "ignore everything" rule wearing the other label.
    private var modeBinding: Binding<Bool> {
        Binding(
            get: { rule.ignoresEverything },
            set: { ignoreAll in
                rule.allowedTypes = ignoreAll ? [] : Set(ClipboardItemType.allCases)
            }
        )
    }

    /// Unchecking the last type would silently mean "ignore everything" while
    /// the picker still says "Capture only" — so the last one can't be
    /// unchecked. The way to block an app entirely is the picker.
    private func typeBinding(_ type: ClipboardItemType) -> Binding<Bool> {
        Binding(
            get: { rule.allowedTypes.contains(type) },
            set: { isOn in
                if isOn {
                    rule.allowedTypes.insert(type)
                } else if rule.allowedTypes.count > 1 {
                    rule.allowedTypes.remove(type)
                }
            }
        )
    }

    private func label(for type: ClipboardItemType) -> String {
        switch type {
        case .text:  return "Text"
        case .url:   return "Links"
        case .image: return "Images"
        case .file:  return "Files"
        }
    }

    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleID)
    }

    private var displayName: String {
        guard let url = appURL else { return rule.bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }

    /// A generic icon when the app isn't installed. The rule stays valid
    /// either way — removing it is the user's call, not the app's.
    private var icon: NSImage {
        guard let url = appURL else {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

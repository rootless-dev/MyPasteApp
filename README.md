# MyPasteApp

A native macOS clipboard manager built with Swift/SwiftUI and SwiftData. Accessible via a global hotkey and a status-bar icon, it shows your clipboard history in an overlay with search, rich previews, and one-click pasting.

## Features

- **Global hotkey** `⌘⇧V` to toggle the history from any app (registered with Carbon `RegisterEventHotKey`).
- **Status-bar icon** — left click to open the overlay, right click for a menu (Show history, Preferences, Quit).
- **Clipboard monitor** that automatically captures text, URLs, images, and files, with content hashing for deduplication.
- **Rich previews**:
  - Links with title, cover image, favicon, and an extracted background color.
  - Files with QuickLook thumbnails.
  - Images stored via SwiftData's `externalStorage`.
- **Animated overlay** with a spring slide-up, window pre-warming for instant first open, and proper multi-display support.
- **Search**, **pinning** (`isPinned`), and an automatic **retention policy**.
- **Simulated paste** (`PasteSimulator`) writes the item back to the pasteboard and dispatches `⌘V` to the source app.
- **Persistence** with SwiftData (`ClipboardItem` `@Model`).
- **Preferences** reachable from the status-bar menu.

## Architecture

```
MyPasteApp/
├── MyPasteAppApp.swift          # @main, Settings scene
├── AppDelegate.swift            # Service bootstrap and status item
├── Models/
│   └── ClipboardItem.swift      # SwiftData @Model (text/url/image/file)
├── Services/
│   ├── ClipboardMonitor.swift   # NSPasteboard polling
│   ├── ClipboardWriter.swift    # Writes an item back to the pasteboard
│   ├── PasteSimulator.swift     # Dispatches ⌘V to the active app
│   ├── HotkeyManager.swift      # Global ⌘⇧V (Carbon)
│   ├── RetentionPolicy.swift    # Periodic history cleanup
│   ├── LinkMetadataService.swift# OpenGraph / favicon / background color
│   ├── FileThumbnailService.swift# QuickLook thumbnails
│   └── AppColorExtractor.swift  # Dominant color of source app
├── Window/
│   └── OverlayWindowController.swift  # Borderless NSPanel, multi-display
└── Views/
    ├── OverlayView.swift        # Card grid + search
    ├── ClipboardCardView.swift  # Individual card
    ├── SearchBar.swift
    ├── PreferencesView.swift
    └── Preview/
        ├── LinkPreviewView.swift
        └── FilePreviewView.swift
```

## Requirements

- macOS 26.2 or later
- Xcode 26+
- Swift 5.9+

## Build

```bash
open MyPasteApp.xcodeproj
```

Build and run from Xcode (`⌘R`). There are no external dependencies — only system frameworks (AppKit, SwiftUI, SwiftData, Carbon, QuickLook).

## Usage

1. Launch the app — a clipboard icon appears in the status bar.
2. Copy any content normally (`⌘C`).
3. Press `⌘⇧V` to open the overlay with your history.
4. Click any card to paste it into the active app.

## License

MIT — see [LICENSE](LICENSE).

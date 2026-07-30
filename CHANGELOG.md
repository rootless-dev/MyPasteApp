# Changelog

## [1.1.0](https://github.com/rootless-dev/MyPasteApp/compare/v1.0.0...v1.1.0) (2026-07-30)


### Features

* add dynamic footer with type-specific metadata to clipboard tiles ([b511d65](https://github.com/rootless-dev/MyPasteApp/commit/b511d65e5d7fd2c38c7e38fdd4828eb12ff909c7))
* delete a history item from its card ([448edc6](https://github.com/rootless-dev/MyPasteApp/commit/448edc660b691fbbdf174abc8e5789f8e694b352))
* initial clipboard manager MVP ([9348df0](https://github.com/rootless-dev/MyPasteApp/commit/9348df0be759ba765e076d4a7e2fa83ae10f194e))
* left/right click status item and auto-hide overlay on outside click ([9f4111f](https://github.com/rootless-dev/MyPasteApp/commit/9f4111fbcd50f55f0c0f27c6628ef8cfecb70d5c))
* play sound feedback when new clipboard item is captured ([35bfcac](https://github.com/rootless-dev/MyPasteApp/commit/35bfcac085e9409ef83f27ca924348349a8bf564))
* promote clicked tile to top and keep overlay open ([ad58a00](https://github.com/rootless-dev/MyPasteApp/commit/ad58a0079ff21144aec1d2bf01a768e7c1936cf6))
* redesign clipboard tiles with Paste-style colored header ([4e108ce](https://github.com/rootless-dev/MyPasteApp/commit/4e108ced4f57a97e71ae5b76d7704a0f7a9e32d9))
* rich type-specific previews for files and links ([b71e251](https://github.com/rootless-dev/MyPasteApp/commit/b71e251c91c57f987e886455b8161935d29b1517))
* user preferences, unit test target and per-card delete ([1971cf3](https://github.com/rootless-dev/MyPasteApp/commit/1971cf3f21ab592558c56703f2a3a65bf2dc0439))
* user-configurable preferences for hotkey, paste, privacy and layout ([f11d65c](https://github.com/rootless-dev/MyPasteApp/commit/f11d65cfe5d54ab9dcf6540c6b87ec002b420486))


### Bug Fixes

* clip overlay scroll content to rounded window shape ([4a85065](https://github.com/rootless-dev/MyPasteApp/commit/4a8506581501bf511eab0af1d071dcb555b56082))
* prevent overlay teleport across displays in multi-monitor setups ([c6a79ca](https://github.com/rootless-dev/MyPasteApp/commit/c6a79ca3fba2881eda808dc5af5a2fc9f58d1471))
* render image thumbnails for file-type clipboard tiles ([0acf583](https://github.com/rootless-dev/MyPasteApp/commit/0acf58379cf4b8328bcaf4df7d24fbe009f11626))
* silence Swift 6 warnings in ClipboardMonitor and HotkeyManager ([4846e34](https://github.com/rootless-dev/MyPasteApp/commit/4846e34bfca4290d62355b560c1c686cd1024bd9))


### Performance

* smoother overlay slide-up with spring, rasterization and prewarm ([f26ede0](https://github.com/rootless-dev/MyPasteApp/commit/f26ede0857d25000c8b285776809db71b5f3c2e5))


### Documentation

* add README and MIT LICENSE, translate code to English ([de32179](https://github.com/rootless-dev/MyPasteApp/commit/de32179c6cd1cdd83ba5824493d92c261125e263))

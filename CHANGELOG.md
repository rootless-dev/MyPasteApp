# Changelog

## [1.2.0](https://github.com/rootless-dev/MyPasteApp/compare/v1.1.0...v1.2.0) (2026-07-31)


### Features

* **clipboard:** keep the formatted version of copied text ([deaf145](https://github.com/rootless-dev/MyPasteApp/commit/deaf14582a7405c59edee58aba84a7cee63e4096))
* **editor:** edit an item without leaving the app ([3028802](https://github.com/rootless-dev/MyPasteApp/commit/30288025c331bb19321dcf2a25806c508221a9b3))
* **editor:** wrap NSTextView for SwiftUI ([69fc8a0](https://github.com/rootless-dev/MyPasteApp/commit/69fc8a00c1924659b7def8baa92707ade2728725))
* fase 1 do roadmap — ganhos rápidos ([2c8662b](https://github.com/rootless-dev/MyPasteApp/commit/2c8662bc36fdbe2d56427262eacf368884e5e797))
* **items:** create an item from scratch ([3d0b726](https://github.com/rootless-dev/MyPasteApp/commit/3d0b726f9aedf1bdd6553774e099cbf7a7cb478e))
* **items:** name an item and find it by that name ([890b07b](https://github.com/rootless-dev/MyPasteApp/commit/890b07b15fe34ec35da9f885f036fc058a2237e6))
* **menu:** timed pause with status bar feedback and its own hotkey ([cf68311](https://github.com/rootless-dev/MyPasteApp/commit/cf68311e4dd4f5e82824b2480b66fe3b498646c8))
* **monitor:** pause and resume clipboard capture ([107f30a](https://github.com/rootless-dev/MyPasteApp/commit/107f30afb2ed4d0b2cb16151a63d14dc56b3600c))
* **overlay:** add ⌘C copy shortcut and menu shortcut glyphs ([46af4ea](https://github.com/rootless-dev/MyPasteApp/commit/46af4ead10dd526fede39a6d6d13ba495a02a5ca))
* **overlay:** add a context menu to the card ([97e267f](https://github.com/rootless-dev/MyPasteApp/commit/97e267ff76fa1fba30f3349f3c7240df7393cc26))
* **overlay:** quick paste with ⌘1–⌘9 ([c31bb5e](https://github.com/rootless-dev/MyPasteApp/commit/c31bb5e6bea3aa096d73db1694c9a411d93e7840))
* **paste:** paste formatted text, with ⇧ for plain ([8ae8071](https://github.com/rootless-dev/MyPasteApp/commit/8ae8071a7b411e4c586fa6b3447f09ae46aa2ac9))
* **preview:** let Space close the panel it opened ([951e083](https://github.com/rootless-dev/MyPasteApp/commit/951e0830e894df531fda07b97f060541b57bb439))
* **preview:** open with Space, close with Escape ([081f4ce](https://github.com/rootless-dev/MyPasteApp/commit/081f4cec7b23488af4c64d6be792aec035c135e2))
* **preview:** show the full item in an anchored panel ([abeb65f](https://github.com/rootless-dev/MyPasteApp/commit/abeb65f5b2044b7fab8957ae9c6e49fcd7bba595))
* **privacy:** hide windows from screen sharing ([e0f6eba](https://github.com/rootless-dev/MyPasteApp/commit/e0f6eba0fe73065b778635b54f3fee417533b578))
* **privacy:** skip concealed and transient pasteboard content ([807dfac](https://github.com/rootless-dev/MyPasteApp/commit/807dfacf47e8045873df60540d5ca0274bb31f26))
* **retention:** add the named stops of the retention slider ([769e024](https://github.com/rootless-dev/MyPasteApp/commit/769e024804aebc390a42d1dc929c3b266c9abaf7))
* **retention:** let the history be kept forever ([8fe59e1](https://github.com/rootless-dev/MyPasteApp/commit/8fe59e16023b0de9e24a0247d69aac2c5a896387))
* **richtext:** decide what goes on the pasteboard when pasting ([1c58fa5](https://github.com/rootless-dev/MyPasteApp/commit/1c58fa5898b5aa729375001c58c1d806d71bd9b6))
* **richtext:** pick which rich format to keep from the pasteboard ([1418691](https://github.com/rootless-dev/MyPasteApp/commit/1418691e5d39a2d4e90399f8a83641af32bcfec0))
* **settings:** move general, history and appearance into the sidebar ([f8c0743](https://github.com/rootless-dev/MyPasteApp/commit/f8c074309025d0ea95ff78240dcfce77904f681b))
* **settings:** move shortcuts and privacy over, drop the old view ([2a90928](https://github.com/rootless-dev/MyPasteApp/commit/2a909286381cd57c15140ec242ec62201fb99ef0))
* **settings:** rebuild the window around a sidebar ([6f4210d](https://github.com/rootless-dev/MyPasteApp/commit/6f4210d9dd4b8683ec1457fa8c30d71a1f432e04))


### Bug Fixes

* **appdelegate:** skip pause hotkey on launch conflict; menu/window fixes ([0cadd72](https://github.com/rootless-dev/MyPasteApp/commit/0cadd725d2a601316c16146711315950343df0fe))
* **editor:** decode rich text by its stored format, not always as RTF ([e5712ee](https://github.com/rootless-dev/MyPasteApp/commit/e5712ee9186af0b6e54c7ef99fd9c67e5b29696d))
* **hotkeys:** re-check both shortcuts on any hotkey change, hide dead one from menu ([dbf8841](https://github.com/rootless-dev/MyPasteApp/commit/dbf884152b98c0e266ab2d4930e5ab570abaea8d))
* **hotkeys:** report registration failures to the caller ([aaa2278](https://github.com/rootless-dev/MyPasteApp/commit/aaa227823864e7e2cd8d88f5e34958efce57fb11))
* **menu:** hide the overlay shortcut when it isn't registered ([bd62fe4](https://github.com/rootless-dev/MyPasteApp/commit/bd62fe4e56b45b8f5a6050dbfe7e5e404bf08d2f))
* **menu:** honor "always paste plain text" in the context menu's Paste entry ([95358fd](https://github.com/rootless-dev/MyPasteApp/commit/95358fdc1ed88fcdaedcf0839b9531199e5d9d89))
* **overlay:** let the panel receive keyboard input at all ([1317143](https://github.com/rootless-dev/MyPasteApp/commit/1317143e3af45eb763b6fd5a986f62bc8f6c0b30))
* **paste:** stop quick paste from leaking global shift into plain text ([58099a4](https://github.com/rootless-dev/MyPasteApp/commit/58099a465094a81e39b5e341464a15bd82b6bd55))
* **pause:** stale timer no longer overrides a newer pause ([6a8706a](https://github.com/rootless-dev/MyPasteApp/commit/6a8706a74a9857e10107d7df06eeeb142835b7d6))
* **preferences:** un-stick hotkey banner; drop fragile revert flag; resizable frame ([f969780](https://github.com/rootless-dev/MyPasteApp/commit/f96978095da0eef66a181329cef4d3e17dbd81b2))
* **preview:** scale images to fit the panel instead of showing them full size ([b8c7e7e](https://github.com/rootless-dev/MyPasteApp/commit/b8c7e7ea712ab5b12d4f69434dbb2480e6877a72))
* **preview:** stop rebuilding the preview panel on every scroll frame ([0a40219](https://github.com/rootless-dev/MyPasteApp/commit/0a402193d073e226e7975de022f209265db89579))
* **spike:** make the preview panel actually reachable and sized ([b02177c](https://github.com/rootless-dev/MyPasteApp/commit/b02177c8efd28681be26209b4348ed6c547d2365))


### Refactoring

* **hotkey:** support more than one global hotkey ([f28ab5c](https://github.com/rootless-dev/MyPasteApp/commit/f28ab5ca99e9accfc1f55abbecbc7ef56c9ce450))
* **overlay:** move item actions out of the view ([2a4b16f](https://github.com/rootless-dev/MyPasteApp/commit/2a4b16f29625723dfbb099cce7ee55dbb37fadcc))
* **preferences:** centralize UserDefaults keys in one type ([fc07fc7](https://github.com/rootless-dev/MyPasteApp/commit/fc07fc75f868eebcbd8bb5b7ef4abb4c9e0fd491))


### Documentation

* **clipboard-monitor:** restore the lastChangeCount ordering rationale ([303a5ac](https://github.com/rootless-dev/MyPasteApp/commit/303a5acdbbf4b3c9276e8fe1aee775db02518ae6))
* **privacy:** say which apps the pasteboard markers don't cover ([bc5705f](https://github.com/rootless-dev/MyPasteApp/commit/bc5705f49222e93cac2149cedd2ee77a511a4555))
* spec and implementation plan for roadmap phase 1 ([71adfb6](https://github.com/rootless-dev/MyPasteApp/commit/71adfb6163baf8a0a61adad3099288d3782b553d))
* spec and implementation plan for roadmap phase 2 ([7aaa563](https://github.com/rootless-dev/MyPasteApp/commit/7aaa563973664974f7f32e745d993e24b90e587c))

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

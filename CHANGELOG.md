# Changelog

## [1.3.0](https://github.com/rootless-dev/MyPasteApp/compare/v1.2.0...v1.3.0) (2026-08-03)


### Features

* **multi-paste:** add the ordered marked selection ([9e2ac8e](https://github.com/rootless-dev/MyPasteApp/commit/9e2ac8ee57379afd0babb305d9b739cfcd3506f3))
* **multi-paste:** add the separator options ([75512b4](https://github.com/rootless-dev/MyPasteApp/commit/75512b488336752321fef1c03c47f6f8de788ded))
* **multi-paste:** add the separator preference ([a434d6f](https://github.com/rootless-dev/MyPasteApp/commit/a434d6fc8c7d058e024998463a7db1f86437c23f))
* **multi-paste:** add the type gate, id resolution and joining ([8d0bc84](https://github.com/rootless-dev/MyPasteApp/commit/8d0bc84945e422614f9892cf03a9b6086544f876))
* **multi-paste:** clear marks before escape closes the drawer ([b92c3cf](https://github.com/rootless-dev/MyPasteApp/commit/b92c3cf2e23766f203b30155f3723dc25ef66e76))
* **multi-paste:** mark with ⌘M or ⌘-click and paste the block with ↵ ([49b21bb](https://github.com/rootless-dev/MyPasteApp/commit/49b21bb7ffcd27589eb2592c0beac43948f66c18))
* **multi-paste:** read rich text per item and record use without promoting ([831d8af](https://github.com/rootless-dev/MyPasteApp/commit/831d8af515a1a28ff8012bfb8d9e2775f1d19de5))
* **multi-paste:** show the mark order on the card ([0c51027](https://github.com/rootless-dev/MyPasteApp/commit/0c5102769e0c2cea05eb3eb9668932001d76f8a8))
* **multi-paste:** show the marked count and add the context menu entry ([0c5021c](https://github.com/rootless-dev/MyPasteApp/commit/0c5021c78689cbaa6514375207170ce3be53a0bd))
* **multi-paste:** write several items to the pasteboard as one block ([1b185c9](https://github.com/rootless-dev/MyPasteApp/commit/1b185c9688b437166d54797b88c40a59f5f865e3))
* **ocr:** add a serial low-priority queue with backlog support ([e36b8e1](https://github.com/rootless-dev/MyPasteApp/commit/e36b8e17c76fecc83881f4115c5f4b48c4f997ec))
* **ocr:** add ocrText/ocrProcessedAt fields and the scheduling rule ([2c41890](https://github.com/rootless-dev/MyPasteApp/commit/2c418902635defff567420343175a4d5a89cd669))
* **ocr:** recognise text in images with Vision, on device ([8895cb0](https://github.com/rootless-dev/MyPasteApp/commit/8895cb0904ec73ae1d75085b2fe4a080bf35541a))
* **ocr:** run OCR on capture and backfill, behind a privacy toggle ([6362855](https://github.com/rootless-dev/MyPasteApp/commit/63628551ac38049e5573f931289f240f71e56654))
* **search:** add SearchState with the keyboard and token rules ([e77fdd9](https://github.com/rootless-dev/MyPasteApp/commit/e77fdd93fac2253137831bacc26c01495b58b015))
* **search:** add Show in History (⌘J) ([339727e](https://github.com/rootless-dev/MyPasteApp/commit/339727ec872bdaff112b122a8c3433ac19c0f47c))
* **search:** collapse the search field into a magnifier at rest ([836c408](https://github.com/rootless-dev/MyPasteApp/commit/836c408c248593095f546c882e9d34466d49e35e))
* **search:** filter by type, source app and date ([6dec751](https://github.com/rootless-dev/MyPasteApp/commit/6dec751c2dd3e8f92c196530bfa8ef13b4a23a55))
* **search:** put the search field in AppKit so the caret can be placed ([5830665](https://github.com/rootless-dev/MyPasteApp/commit/58306657bf2670fb57f4e9991db177ab39167d7e))
* **search:** replace the search bar with a token field ([8d1bd50](https://github.com/rootless-dev/MyPasteApp/commit/8d1bd502d3d767ca164b5a9dde7ef88bbd1a3071))


### Bug Fixes

* **cards:** hide the selection border once a block is being marked ([b5c739d](https://github.com/rootless-dev/MyPasteApp/commit/b5c739dbba84eaa65736b7438d2670b94ce094b5))
* **cards:** pin thumbnails against cache eviction and restore text fallback ([b89597e](https://github.com/rootless-dev/MyPasteApp/commit/b89597ef1b7fc70c1c02bb381b31134c4048f565))
* **links:** stop a re-copy from wiping stored link metadata ([4a6eac2](https://github.com/rootless-dev/MyPasteApp/commit/4a6eac204770a9ccde3ccbabbf4c7f9172f56fe4))
* **multi-paste:** anchor the marked-count pill as an overlay, not a stack sibling ([f180cf6](https://github.com/rootless-dev/MyPasteApp/commit/f180cf6db02d5ab54e6cd3bb5a40547651b36b6b))
* **multi-paste:** don't paste on ⌘-click of a non-markable item ([683fe91](https://github.com/rootless-dev/MyPasteApp/commit/683fe915e360f8785d30e12cb2c841e5a1e1554f))
* **ocr:** read the injected defaults and refresh metadata on the stored item ([240eb48](https://github.com/rootless-dev/MyPasteApp/commit/240eb48fd629c342f2a78342e2adb3878654af74))
* **overlay:** route context-menu delete through OverlayView's delete(_:) ([e89403d](https://github.com/rootless-dev/MyPasteApp/commit/e89403d8cb71d6f29a598f4fe2ddba621a66218c))
* **overlay:** stop backspace from deleting while a block is marked ([1c9c87e](https://github.com/rootless-dev/MyPasteApp/commit/1c9c87ef5546bb7519255da3357e04c553196f99))
* **overlay:** unmark an item when it is deleted ([ba8f109](https://github.com/rootless-dev/MyPasteApp/commit/ba8f1094f347e16f080b81423a12185e97c95f39))
* **paste:** drop the newline the HTML importer appends to each piece ([9329c1b](https://github.com/rootless-dev/MyPasteApp/commit/9329c1b500e1f9adb9f905cf72da71276c03681b))
* **paste:** hand over the captured plain text for a plain block ([4d20e52](https://github.com/rootless-dev/MyPasteApp/commit/4d20e5257224ceb437db7e8d0312ae74570dbc9e))
* **preview:** fix three memory/fallback bugs from the whole-branch review ([f9a361c](https://github.com/rootless-dev/MyPasteApp/commit/f9a361c9810dd01ad10ea4dfc579bbd77c113632))
* **search:** clear the pending selection once the jump settles ([d0470c1](https://github.com/rootless-dev/MyPasteApp/commit/d0470c11f982c36b30dfb9174922719fd78c7623))
* **search:** defer focus to the field and reset search state on open ([1c2c895](https://github.com/rootless-dev/MyPasteApp/commit/1c2c8959082c0552ce21d1e4c5507ebeaa062abf))
* **search:** keep the first character typed into the search ([7f8d6de](https://github.com/rootless-dev/MyPasteApp/commit/7f8d6de278ba6e46c722d4dac5836a283103014d))
* **search:** keep type, date and clear visible while the app list scrolls ([a5a79bc](https://github.com/rootless-dev/MyPasteApp/commit/a5a79bc2cb67a7e2da1117da84e341f5e0db5dea))
* **search:** reveal the selection esc keeps ([2d5a48c](https://github.com/rootless-dev/MyPasteApp/commit/2d5a48cc2aefdd56a95c186972e0e32bec90c78b))
* **search:** scope the field-editor scan to the overlay panel ([9a5209f](https://github.com/rootless-dev/MyPasteApp/commit/9a5209f4a3773a1cea0e7bb1ab3992006c16cf56))
* **search:** size token labels, rescue ⌫ and ␣, tie the stroke to focus ([17ddf30](https://github.com/rootless-dev/MyPasteApp/commit/17ddf30d0bdabbc40ec605777df122f01a226527))


### Performance

* **cards:** decode images at draw size and cache them with a ceiling ([87f150e](https://github.com/rootless-dev/MyPasteApp/commit/87f150e28622bdb2d3905ee7d0d57988c201fc4a))
* **cards:** read image dimensions from the header instead of decoding ([e090fac](https://github.com/rootless-dev/MyPasteApp/commit/e090facbf26a1574e0b095e16bdc375e3c317e98))
* **overlay:** stop invalidating every card when a frame changes ([4fe25aa](https://github.com/rootless-dev/MyPasteApp/commit/4fe25aac6212da0f9a6aa8257cc082e2de50eae5))
* **preview:** lay out long text by viewport instead of rasterizing it whole ([ee0b215](https://github.com/rootless-dev/MyPasteApp/commit/ee0b21575746223cc193331be72758c794f628f4))
* **preview:** release the panel's hosted content when it closes ([7847503](https://github.com/rootless-dev/MyPasteApp/commit/7847503c092ff4942528eaefaa84b045f5f8bbd6))
* **search:** cache app lookups that resolve to nothing ([720f1a7](https://github.com/rootless-dev/MyPasteApp/commit/720f1a7e396f33fef991a03675853e05bf623192))


### Refactoring

* **overlay:** fold the two pick closures into one path ([c7cdde0](https://github.com/rootless-dev/MyPasteApp/commit/c7cdde03e9fe4c2b6a9c00c9e522e45868bedf27))
* **preview:** unify FaviconBadge into ThumbnailImage's chrome switch ([6dac8e1](https://github.com/rootless-dev/MyPasteApp/commit/6dac8e19b62b22e59c26244aff424ecd7cb04a38))
* **search:** extract matching into a pure ItemSearch with filters ([a7f2df7](https://github.com/rootless-dev/MyPasteApp/commit/a7f2df700b59495541cc845dd5777f02530a2717))
* **search:** give the canonical type order one home ([e8bc773](https://github.com/rootless-dev/MyPasteApp/commit/e8bc7738b159a608c0a94c371e363f6306cdfe98))


### Documentation

* add project instructions with the Obsidian board rule ([4812848](https://github.com/rootless-dev/MyPasteApp/commit/48128488658dd15b138b6505db92b00562043ba2))
* **fase-4:** add manual step for delete-via-menu unmark regression ([67db6ee](https://github.com/rootless-dev/MyPasteApp/commit/67db6ee46babeb1cc4eb469c19cc96438873fdc8))
* **multi-paste:** add the manual verification script ([18e99f9](https://github.com/rootless-dev/MyPasteApp/commit/18e99f9b2f2468243076b5d8a75813402e2a4f4b))
* **multi-paste:** add the Phase 4 spec and plan ([cf9c4ba](https://github.com/rootless-dev/MyPasteApp/commit/cf9c4ba08c076eee5499d3a64d00e6911fbea5db))
* **multi-paste:** give E2 and D9 binary pass/fail criteria ([1ffd858](https://github.com/rootless-dev/MyPasteApp/commit/1ffd858bee4b8c73597fb1206f6d7a51d587490a))
* **plan:** authorize commits and drop a tautological test ([5a50b81](https://github.com/rootless-dev/MyPasteApp/commit/5a50b81d94180113a0a15f6a9eeb1bb8758e783e))
* **plan:** split the pixel conversion so the scale can be pinned ([df3bda6](https://github.com/rootless-dev/MyPasteApp/commit/df3bda69cbd32055db347b56b764e3332a0f3577))
* **preview:** fix stale comment and two wrong manual-check lines ([2f3c301](https://github.com/rootless-dev/MyPasteApp/commit/2f3c301ee29543b1c6512df8cd9a3c937239fd28))
* **search:** add the Phase 3 spec, plan and manual verification script ([1592663](https://github.com/rootless-dev/MyPasteApp/commit/1592663006007105f49e9047cba9fa0a962e4e87))
* **search:** correct comments describing the removed workarounds ([8baf194](https://github.com/rootless-dev/MyPasteApp/commit/8baf194c28a182176d90dcb9ee417d7e73844de1))
* spec and implementation plan for roadmap phase 2.5 ([5efc400](https://github.com/rootless-dev/MyPasteApp/commit/5efc4003cc6e4c42a536ce30d53a29c85e1fb666))
* **verify:** add manual steps for the mark/border/backspace fix ([16fb478](https://github.com/rootless-dev/MyPasteApp/commit/16fb4782b3bee9be0bb3590f7532d691d3006b12))

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
